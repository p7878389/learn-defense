import LearnCore
import SwiftUI

/// 收藏卡与战斗种子卡共用的金属徽饰；静态图片，不承载玩法和动画。
struct CollectionCardFrame: View {
    let rarity: CosmeticRarity
    let locked: Bool
    var lightInterior = false

    var body: some View {
        Group {
            if let image = HeraldicArtwork.image(for: rarity, lightInterior: lightInterior) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(lightInterior ? GrowthColors.surface : Color(red: 0.07, green: 0.11, blue: 0.18))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(GrowthColors.rarity(rarity), lineWidth: 2))
            }
        }
        .saturation(locked ? 0.3 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
