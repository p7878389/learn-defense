import LearnCore
import SwiftUI

/// 准备阶段的地图预览；选中即更新战场，开始后不再显示入口。
struct BattleMapPicker: View {
    let selection: BattleMap
    let onSelect: (BattleMap) -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("战场地图").font(AppFont.bodyStrong).foregroundStyle(AppColor.ink)
                Text("开战后锁定").font(AppFont.caption).foregroundStyle(AppColor.muted)
            }
            ForEach(BattleMap.allCases) { map in
                let selected = selection == map
                Button { onSelect(map) } label: {
                    VStack(spacing: AppSpacing.xxs) {
                        if let image = BattleMapArtwork.image(map) {
                            Image(decorative: image, scale: 1)
                                .resizable().aspectRatio(2, contentMode: .fit)
                                .frame(width: 112, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
                        }
                        HStack(spacing: AppSpacing.xxs) {
                            Text(map.name).font(AppFont.label)
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(AppFont.rounded(13, weight: .bold))
                                    .foregroundStyle(AppColor.jade)
                            }
                        }
                        .frame(height: 18)
                    }
                    .padding(6)
                    .background(
                        CandyTileBackground(
                            selected: selected,
                            selectedFill: AppColor.goldLight.opacity(0.35),
                            selectedEdge: AppColor.accent,
                            radius: AppRadius.sm
                        )
                    )
                    .foregroundStyle(AppColor.ink)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(map.name)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
    }
}
