import LearnCore
import SwiftUI

/// 准备阶段的地图预览；选中即更新战场，开始后不再显示入口。
struct BattleMapPicker: View {
    let selection: BattleMap
    let onSelect: (BattleMap) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("战场地图").font(AppFont.bodyStrong).foregroundStyle(Theme.ink)
                Text("开战后锁定").font(AppFont.caption).foregroundStyle(Theme.muted)
            }
            ForEach(BattleMap.allCases) { map in
                let selected = selection == map
                Button { onSelect(map) } label: {
                    VStack(spacing: 4) {
                        if let image = BattleMapArtwork.image(map) {
                            Image(decorative: image, scale: 1)
                                .resizable().aspectRatio(2, contentMode: .fit)
                                .frame(width: 112, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: AppRadius.xs))
                        }
                        HStack(spacing: 4) {
                            Text(map.name).font(AppFont.label)
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Theme.jade)
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
                    .foregroundStyle(Theme.ink)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(map.name)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
    }
}
