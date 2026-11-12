import LearnCore
import SwiftUI

/// 准备阶段的地图预览；选中即更新战场，开始后不再显示入口。
struct BattleMapPicker: View {
    let selection: BattleMap
    let onSelect: (BattleMap) -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("战场地图").font(.headline.weight(.heavy))
                Text("开战后锁定").font(.caption).foregroundStyle(Theme.muted)
            }
            ForEach(BattleMap.allCases) { map in
                Button { onSelect(map) } label: {
                    VStack(spacing: 4) {
                        if let image = BattleMapArtwork.image(map) {
                            Image(decorative: image, scale: 1)
                                .resizable().aspectRatio(2, contentMode: .fit)
                                .frame(width: 112, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        HStack(spacing: 4) {
                            Text(map.name).font(.system(size: 13, weight: .bold))
                            if selection == map { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.jade) }
                        }
                        .frame(height: 18)
                    }
                    .padding(6)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(selection == map ? Theme.accent : Theme.muted.opacity(0.3), lineWidth: selection == map ? 3 : 1))
                    .foregroundStyle(Theme.ink)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(map.name)
                .accessibilityAddTraits(selection == map ? [.isSelected] : [])
            }
            Spacer(minLength: 0)
        }
    }
}
