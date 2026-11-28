import AVFoundation
import Foundation
import LearnCore
import Speech

/// 端侧语音输入：封装 iOS/macOS 原生 SFSpeechRecognizer + AVAudioEngine。
/// 用于「开口暴击答题」「大招念咒语」「冒险语音口令」等场景，支持离线优先与实时音量反馈。
@MainActor
final class VoiceInput: ObservableObject {
    enum State: Equatable {
        case idle
        case listening
        case matched
        case unavailable(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var transcript = ""
    @Published private(set) var level: Double = 0

    private let audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var timeoutTask: Task<Void, Never>?
    private var sessionID = UUID()

    var isListening: Bool { state == .listening }

    /// 开始监听孩子朗读。识别到匹配 expected 时自动回调 onMatch 并停止监听。
    func start(expected: String, english: Bool, onMatch: @escaping @MainActor () -> Void) {
        stop()
        let currentSession = UUID()
        sessionID = currentSession
        transcript = ""
        level = 0

        Task { @MainActor in
            let authorized = await Self.requestPermissions()
            guard sessionID == currentSession else { return }
            guard authorized else {
                state = .unavailable("请在系统设置中允许麦克风和语音识别")
                return
            }
            beginRecognition(sessionID: currentSession, expected: expected, english: english, onMatch: onMatch)
        }
    }

    func stop() {
        sessionID = UUID()
        timeoutTask?.cancel()
        timeoutTask = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        level = 0
        if case .listening = state { state = .idle }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        #endif
    }

    private func beginRecognition(
        sessionID: UUID,
        expected: String,
        english: Bool,
        onMatch: @escaping @MainActor () -> Void
    ) {
        let locale = Locale(identifier: english ? "en-US" : "zh-CN")
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            state = .unavailable("当前设备暂不支持该语言语音识别")
            return
        }

        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .unavailable("麦克风启动失败，请重试")
            return
        }
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self, weak request] buffer, _ in
            request?.append(buffer)
            let rms = Self.rmsLevel(buffer)
            Task { @MainActor [weak self] in
                guard let self, self.sessionID == sessionID else { return }
                self.level = rms
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            stop()
            state = .unavailable("无法打开麦克风，请检查权限")
            return
        }

        state = .listening
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let spoken = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            let hasError = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.sessionID == sessionID else { return }
                if let spoken {
                    self.transcript = spoken
                    if SpeechMatcher.matches(spoken: spoken, expected: expected) {
                        self.state = .matched
                        self.stop()
                        onMatch()
                        return
                    }
                }
                if isFinal || hasError {
                    self.stop()
                }
            }
        }

        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard let self, self.sessionID == sessionID else { return }
            self.stop()
        }
    }

    private static func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechStatus else { return false }
        #if os(iOS)
        return await AVAudioApplication.requestRecordPermission()
        #else
        return await AVCaptureDevice.requestAccess(for: .audio)
        #endif
    }

    private nonisolated static func rmsLevel(_ buffer: AVAudioPCMBuffer) -> Double {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<count { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(count))
        return min(1, max(0, Double(rms) * 8))
    }
}
