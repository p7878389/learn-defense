import LearnCore
import SwiftUI

/// 准备完成后的最后核对；关闭弹窗不会改变布阵或自动开始。
struct GameStartConfirmationView: View {
    @ObservedObject var session: GameSession
    let library: ContentLibrary
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var packs: [ContentPack] { session.config.packIDs.compactMap(library.pack(id:)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("准备好开始了吗？", systemImage: "checkmark.seal.fill")
                .font(.system(size: 28, weight: .heavy, design: .rounded)).foregroundStyle(Theme.ink)
            Text("核对本局难度与题库。返回后可以继续修改配置和布阵，确认后才开始出怪。")
                .font(.callout).foregroundStyle(Theme.muted)
            ScrollView {
                VStack(spacing: 14) {
                    row("难度", value: session.config.difficulty.displayName)
                    row("年级 / 学科", value: "\(session.config.grade.displayName) · \(packs.first?.subject.displayName ?? "")")
                    row("题库", value: packs.map(QuestionBankChoice.volumeTitle).joined(separator: "、"))
                    row("选择范围", value: unitSummary)
                    row("首回合题量", value: "\(session.roundQuestions) 题")
                    row("战场地图", value: session.map.name)
                    row("当前布阵", value: "\(session.plantedLaneCount) / \(session.tuning.lanes) 路 · \(session.scene.plantedCellCount) 个单位")
                    row("当前阳光", value: "☀️ \(session.sun)")
                }
                .padding(20).candyCard().padding(.bottom, 6)
            }
            .scrollBounceBehavior(.basedOnSize)
            if let error = session.startError {
                Text(error).font(.callout).foregroundStyle(Theme.wrong)
            }
            HStack(spacing: 18) {
                Button(action: onCancel) {
                    CandyButtonLabel(title: "返回修改", icon: "←", fill: GrowthColors.surface, edge: GrowthColors.cardEdge,
                                     foreground: Theme.ink, font: .title3.bold(), height: 52, expands: true)
                }
                Button(action: onConfirm) {
                    CandyButtonLabel(title: "确认开始", icon: "▶", font: .title3.bold(), height: 52, expands: true)
                }
            }.buttonStyle(PressableStyle())
        }
        .padding(24)
        .background(GrowthPageBackground())
        .interactiveDismissDisabled()
        #if os(macOS)
        .frame(width: 760, height: 640)
        #endif
    }

    private var unitSummary: String {
        switch session.config.selection {
        case .review: return "错题复习 · 当前待复习的知识点"
        case .units(let keys):
            return packs.flatMap { pack in
                pack.units.filter { keys.contains(QuestionBankChoice.unitKey(pack: pack, unit: $0)) }.map(\.title)
            }.joined(separator: "、")
        default: return "全部单元"
        }
    }

    private func row(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title).font(.headline).foregroundStyle(Theme.muted).frame(width: 110, alignment: .leading)
            Text(value).font(.headline).foregroundStyle(Theme.ink).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
