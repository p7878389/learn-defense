import LearnCore
import SwiftUI

struct UltimateButton: View {
    let energy: Int
    let maxEnergy: Int
    let ready: Bool
    let action: () -> Void
    var casting = false
    /// 已点开挑战题、还没答完：能量是满的，但既不是“蓄力中”，也还没释放。
    var challenging = false
    @State private var glow = false
    /// 刚获得的那一格，弹亮约 0.25 秒。
    @State private var popped: Int?
    /// 充满瞬间的一圈光波：0 刚出现，1 已散尽。
    @State private var ring = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 按钮的四种状态；文字各不相同，不只靠颜色区分。
    enum Status: CaseIterable {
        case charging, ready, challenging, casting

        init(ready: Bool, challenging: Bool, casting: Bool) {
            self = casting ? .casting : challenging ? .challenging : ready ? .ready : .charging
        }

        var title: String {
            switch self {
            case .charging: "蓄力中"
            case .ready: "雷霆就绪"
            case .challenging: "挑战中"
            case .casting: "释放中"
            }
        }

        var hint: String {
            switch self {
            case .charging: "答对一题 +1 能量"
            case .ready: "点按挑战"
            case .challenging: "首次答对即释放"
            case .casting: "雷霆降临"
            }
        }

        var accessibilityState: String {
            switch self {
            case .charging: "蓄力中"
            case .ready: "已就绪"
            case .challenging: "挑战中"
            case .casting: "释放中"
            }
        }

        var accessibilityHint: String {
            switch self {
            case .charging: "答对题目积攒能量"
            case .ready: "点按进入挑战，首次答对释放雷霆"
            case .challenging: "正在回答挑战题"
            case .casting: "雷霆演出进行中"
            }
        }
    }

    /// 能量增加时，新亮起的最后一格的下标；没有增加（含释放后归零）时为 nil。
    static func gainedSegment(from old: Int, to new: Int) -> Int? {
        new > old ? new - 1 : nil
    }

    private var status: Status { Status(ready: ready, challenging: challenging, casting: casting) }
    private var shownEnergy: Int { min(max(0, energy), max(0, maxEnergy)) }
    /// 只差一格就满：能量条先亮一档，提示快好了。
    private var nearlyFull: Bool { maxEnergy > 1 && shownEnergy == maxEnergy - 1 }
    private var lightning: Color { Color(red: 0.12, green: 0.72, blue: 0.95) }

    private let bronze = Color(red: 0.54, green: 0.28, blue: 0.08)

    private var meter: some View {
        HStack(spacing: 1.5) {
            ForEach(0..<max(0, maxEnergy), id: \.self) { i in
                Capsule()
                    .fill(LinearGradient(colors: i < shownEnergy
                        ? [Color(red: 0.58, green: 1, blue: 1), lightning, Color(red: 0, green: 0.68, blue: 0.82)]
                        : [.white.opacity(0.85), Color(red: 0.7, green: 0.69, blue: 0.66)],
                        startPoint: .top, endPoint: .bottom))
                    .overlay(alignment: .top) {
                        Capsule().fill(.white.opacity(0.6)).frame(height: 3).padding(.horizontal, 2).padding(.top, 2)
                    }
                    .overlay(Capsule().stroke(i < shownEnergy ? Color(red: 0, green: 0.48, blue: 0.6) : bronze.opacity(0.4), lineWidth: 0.8))
                    .brightness(popped == i ? 0.35 : nearlyFull && i < shownEnergy ? 0.08 : 0)
                    .scaleEffect(x: 1, y: popped == i ? 1.5 : 1)
            }
        }
        .padding(2)
        .frame(height: 12)
        .background(Color(red: 0.25, green: 0.32, blue: 0.32), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.9), lineWidth: 1))
        .shadow(color: shownEnergy >= maxEnergy && maxEnergy > 0 ? lightning.opacity(0.55)
                : nearlyFull ? lightning.opacity(0.3) : .clear, radius: 4)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: shownEnergy)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: popped)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                ZStack(alignment: .topLeading) {
                    if let image = ThunderArtwork.image(.button) {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .frame(width: 160, height: 160 / 3)
                    }
                    VStack(spacing: 3) {
                        HStack(spacing: 2) {
                            Text(status.title)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                            Spacer(minLength: 0)
                            Text("\(shownEnergy)/\(max(0, maxEnergy))")
                                .font(.system(size: 10, weight: .heavy).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4).padding(.vertical, 1)
                                .background(bronze, in: Capsule())
                        }
                        .foregroundStyle(Color(red: 0.31, green: 0.12, blue: 0.04))
                        meter
                    }
                    .frame(width: 97)
                    .offset(x: 49, y: 11)
                }
                .frame(width: 160, height: 160 / 3)
                .overlay {
                    // 充满的一瞬间向外散开一圈光，之后交给呼吸光。
                    Capsule().stroke(lightning, lineWidth: 3)
                        .scaleEffect(1 + 0.18 * ring)
                        .opacity(1 - ring)
                        .allowsHitTesting(false)
                }
                Text(status.hint)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ready ? Theme.ink : bronze)
                    .fixedSize()
                    .frame(height: 14)
                    .padding(.top, 1)
            }
            .compositingGroup()
            .shadow(color: ready ? lightning.opacity(glow ? 0.6 : 0.2) : .clear, radius: ready ? 7 : 0)
            .scaleEffect(ready && glow && !reduceMotion ? 1.025 : 1)
        }
        .buttonStyle(PressableStyle())
        .disabled(!ready || casting)
        .accessibilityLabel("雷霆大招")
        .accessibilityValue("能量 \(shownEnergy)/\(max(0, maxEnergy))，\(status.accessibilityState)")
        .accessibilityHint(status.accessibilityHint)
        .onChange(of: ready, initial: true) { _, isReady in
            glow = false
            if isReady && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { glow = true }
            }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { glow = false }
        }
        .onChange(of: shownEnergy) { old, new in
            // 只在真的多了一格时反馈；释放后归零、读档等不触发。
            guard !reduceMotion, let segment = Self.gainedSegment(from: old, to: new) else { return }
            popped = segment
            let filled = new >= maxEnergy
            if filled { ring = 0 }
            Task { @MainActor in
                if filled { withAnimation(.easeOut(duration: 0.5)) { ring = 1 } }
                try? await Task.sleep(for: .seconds(0.25))
                if popped == segment { popped = nil }
            }
        }
    }
}
