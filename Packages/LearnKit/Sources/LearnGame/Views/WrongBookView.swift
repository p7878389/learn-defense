import Combine
import LearnCore
import SwiftUI

struct WrongBookView: View {
    enum Filter: String, CaseIterable {
        case all = "全部"
        case review = "待复习"
        case mastered = "已掌握"
    }

    @Environment(\.dismiss) private var dismiss
    let profile: Profile
    let progress: ProgressStore
    var speech: Speech? = nil
    var onStartReview: (() -> Void)? = nil
    @State private var filter: Filter = .all
    @State private var playingKey: String?
    @State private var listenTask: Task<Void, Never>?
    @State private var speechBusy = false

    private var entries: [(key: String, stats: ItemStats)] {
        progress.stats
            .filter { $0.value.wrong > 0 }
            .map { (key: $0.key, stats: $0.value) }
            .sorted {
                if $0.stats.needsReview != $1.stats.needsReview { return $0.stats.needsReview }
                return $0.stats.wrong > $1.stats.wrong
            }
    }

    private var filteredEntries: [(key: String, stats: ItemStats)] {
        switch filter {
        case .all: entries
        case .review: entries.filter(\.stats.needsReview)
        case .mastered: entries.filter { !$0.stats.needsReview }
        }
    }

    private var reviewCount: Int { entries.filter(\.stats.needsReview).count }

    var body: some View {
        AppModalScaffold(
            systemImage: "book.closed.fill",
            iconTint: AppColor.jade,
            title: "\(profile.name)的错题本",
            subtitle: "连续答对 2 次即可转为已掌握 · 待复习 \(reviewCount) 题 / 共 \(entries.count) 题",
            scrollable: false
        ) {
            if entries.isEmpty {
                emptyState(
                    emoji: "🌟",
                    title: "还没有错题，真棒！",
                    subtitle: "在闯关中答错的知识点会自动记在这里，方便随时温习。"
                )
            } else {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack {
                        GrowthSegmentedPicker(options: Filter.allCases, title: \.rawValue, selection: $filter)
                        Spacer()
                        if speech != nil, !filteredEntries.isEmpty {
                            AppButton(
                                title: listenTask == nil ? "连播磨耳朵" : "停止连播",
                                systemImage: listenTask == nil ? "headphones" : "stop.circle.fill",
                                role: listenTask == nil ? .adventure : .destructive,
                                size: .small
                            ) {
                                toggleListenAll()
                            }
                        }
                    }
                    if filteredEntries.isEmpty {
                        emptyState(
                            emoji: filter == .review ? "🎉" : "🌱",
                            title: filter == .review ? "所有错题都已掌握啦！" : "还没有转为已掌握的错题",
                            subtitle: filter == .review ? "继续保持，遇到新错题会出现在这里。" : "去「错题复习」连续答对 2 次即可点亮掌握标记。"
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: AppSpacing.xs) {
                                ForEach(filteredEntries, id: \.key) { entry in
                                    entryRow(entry)
                                }
                            }
                        }
                        .scrollBounceBehavior(.basedOnSize)
                    }
                }
                .padding(AppSpacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .appPanel()
            }
        } footer: {
            HStack(spacing: AppSpacing.md) {
                AppButton(title: "完成", systemImage: "checkmark", role: .secondary, size: .large, expands: reviewCount > 0 && onStartReview != nil) {
                    dismiss()
                }
                if reviewCount > 0, let onStartReview {
                    AppButton(title: "立即复习（\(reviewCount)）", systemImage: "target", role: .primary, size: .large, expands: true) {
                        dismiss()
                        onStartReview()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 620, idealWidth: 780, minHeight: 460, idealHeight: 620)
        #endif
        .onChange(of: filter) { _, _ in stopListenAll() }
        .onReceive(speech?.$isSpeaking.eraseToAnyPublisher() ?? Just(false).eraseToAnyPublisher()) { speechBusy = $0 }
        .onDisappear { stopListenAll() }
    }

    private func emptyState(emoji: String, title: String, subtitle: String) -> some View {
        VStack(spacing: AppSpacing.sm) {
            PictureView(emoji: emoji, size: 60)
            Text(title)
                .font(AppFont.heading)
                .foregroundStyle(AppColor.ink)
            Text(subtitle)
                .font(AppFont.body)
                .foregroundStyle(AppColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.lg)
        .appPanel()
    }

    private func entryRow(_ entry: (key: String, stats: ItemStats)) -> some View {
        let display = entry.stats.summary ?? entry.key
        let speakable = Self.speakableText(from: display)
        return HStack(spacing: AppSpacing.sm) {
            Label(entry.stats.needsReview ? "待复习" : "已掌握",
                  systemImage: entry.stats.needsReview ? "flame.fill" : "checkmark.circle.fill")
                .font(AppFont.label)
                .foregroundStyle(entry.stats.needsReview ? AppColor.accentEdge : AppColor.jadeEdge)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(entry.stats.needsReview ? AppColor.gold.opacity(0.32) : AppColor.jade.opacity(0.16))
                )
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(display)
                    .font(AppFont.bodyStrong)
                    .foregroundStyle(AppColor.ink)
                Text("答错 \(entry.stats.wrong) 次 · 连续答对 \(entry.stats.streak) 次")
                    .font(AppFont.label)
                    .foregroundStyle(AppColor.muted)
            }
            Spacer(minLength: 0)
            if let speech, let speakable {
                AppButton(title: playingKey == entry.key ? "正在读…" : "听读音",
                          systemImage: playingKey == entry.key ? "speaker.wave.3.fill" : "speaker.wave.2.fill",
                          role: .secondary, size: .small) {
                    stopListenAll()
                    speech.speak(speakable, interrupt: true, channel: .preview)
                }
                .disabled(speechBusy || listenTask != nil)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .appInset(radius: AppRadius.md, tint: playingKey == entry.key ? AppColor.jade : nil)
    }

    private func toggleListenAll() {
        if listenTask != nil {
            stopListenAll()
            return
        }
        guard let speech else { return }
        let items = filteredEntries.compactMap { entry -> (String, String)? in
            guard let text = Self.speakableText(from: entry.stats.summary ?? entry.key) else { return nil }
            return (entry.key, text)
        }
        guard !items.isEmpty else { return }
        listenTask = Task { @MainActor in
            for (key, text) in items {
                guard !Task.isCancelled else { break }
                playingKey = key
                speech.speak(text, interrupt: true, channel: .preview)
                // 留出跟读停顿，让小朋友听一遍、跟读一遍
                try? await Task.sleep(for: .seconds(2.6))
            }
            playingKey = nil
            listenTask = nil
        }
    }

    private func stopListenAll() {
        listenTask?.cancel()
        listenTask = nil
        playingKey = nil
    }

    private static func speakableText(from summary: String) -> String? {
        let token = summary.components(separatedBy: CharacterSet(charactersIn: " （(")).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !token.isEmpty, !token.contains(":") else { return nil }
        return token
    }
}
