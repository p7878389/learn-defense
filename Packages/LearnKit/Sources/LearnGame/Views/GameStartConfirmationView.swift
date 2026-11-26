import LearnCore
import SwiftUI

/// 准备完成后的最后核对：升级为 2×3 精致参数徽章网格 + 题库与范围摘要条。
struct GameStartConfirmationView: View {
    @ObservedObject var session: GameSession
    let library: ContentLibrary
    let onConfirm: () -> Void
    let onCancel: () -> Void

    private var packs: [ContentPack] { session.config.packIDs.compactMap(library.pack(id:)) }

    var body: some View {
        AppModalScaffold(
            systemImage: "checkmark.seal.fill",
            iconTint: AppColor.jade,
            title: "准备好开始了吗？",
            subtitle: "核对本局难度与题库。返回后可继续修改配置与布阵，确认后才开始出怪。"
        ) {
            VStack(spacing: AppSpacing.md) {
                // 核心参数 2×3 信息格
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: AppSpacing.sm), GridItem(.flexible(), spacing: AppSpacing.sm)],
                    spacing: AppSpacing.sm
                ) {
                    metricCard(icon: "flame.fill", tint: AppColor.accent, title: "难度", value: session.config.difficulty.displayName)
                    metricCard(icon: "graduationcap.fill", tint: AppColor.adventure, title: "年级 / 学科", value: "\(session.config.grade.displayName) · \(packs.first?.subject.displayName ?? "")")
                    metricCard(icon: "list.number", tint: AppColor.violet, title: "首回合题量", value: "\(session.roundQuestions) 题")
                    metricCard(icon: "map.fill", tint: AppColor.jade, title: "战场地图", value: session.map.name)
                    metricCard(icon: "leaf.fill", tint: AppColor.jadeEdge, title: "当前布阵", value: "\(session.plantedLaneCount) / \(session.tuning.lanes) 路 · \(session.scene.plantedCellCount) 个单位")
                    metricCard(icon: "sun.max.fill", tint: AppColor.goldEdge, title: "当前阳光", value: "\(session.sun)")
                }

                // 题库与单元范围详情块
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    detailRow(icon: "book.closed.fill", title: "所选题库", value: packs.map(QuestionBankChoice.volumeTitle).joined(separator: "、"))
                    Divider()
                    detailRow(icon: "checklist", title: "选择范围", value: unitSummary)
                }
                .padding(AppSpacing.md)
                .appInset(radius: AppRadius.md)
            }
        } footer: {
            VStack(spacing: AppSpacing.xs) {
                if let error = session.startError {
                    Text(error).font(AppFont.label).foregroundStyle(AppColor.dangerText)
                }
                HStack(spacing: AppSpacing.md) {
                    AppButton(title: "返回修改", systemImage: "chevron.left", role: .secondary, size: .large, expands: true, action: onCancel)
                    AppButton(title: "确认开始", systemImage: "play.fill", role: .primary, size: .large, expands: true, action: onConfirm)
                }
            }
        }
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

    private func metricCard(icon: String, tint: Color, title: String, value: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            AppIconBadge(systemImage: icon, tint: tint, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.caption).foregroundStyle(AppColor.muted)
                Text(value).font(AppFont.bodyStrong).foregroundStyle(AppColor.ink).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .frame(minHeight: 64)
        .appInset(radius: AppRadius.md)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(AppFont.rounded(16, weight: .bold))
                .foregroundStyle(AppColor.jade)
                .frame(width: 22)
            Text(title).font(AppFont.label).foregroundStyle(AppColor.muted).frame(width: 72, alignment: .leading)
            Text(value).font(AppFont.body).foregroundStyle(AppColor.ink).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
