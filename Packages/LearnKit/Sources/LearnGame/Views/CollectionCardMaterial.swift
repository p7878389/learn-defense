import LearnCore
import SwiftUI

private enum LocalArt {
    /// 战斗种子卡深海蓝暗色卡面内底，仅用于战斗卡槽背景区分
    static let darkCardInterior = Color(red: 0.07, green: 0.11, blue: 0.18)
}

/// 收藏卡与战斗种子卡共用的金属徽饰；静态图片，不承载玩法和动画。
struct CollectionCardFrame: View {
    let rarity: CosmeticRarity
    let locked: Bool
    var lightInterior = false

    private var rarityColor: Color {
        switch rarity {
        case .common: AppColor.rarityCommon
        case .rare: AppColor.rarityRare
        case .legendary: AppColor.rarityLegendary
        }
    }

    var body: some View {
        Group {
            if let image = HeraldicArtwork.image(for: rarity, lightInterior: lightInterior) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: AppRadius.sm)
                    .fill(lightInterior ? AppColor.surface : LocalArt.darkCardInterior)
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.sm).stroke(rarityColor, lineWidth: 2))
            }
        }
        .saturation(locked ? 0.3 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
