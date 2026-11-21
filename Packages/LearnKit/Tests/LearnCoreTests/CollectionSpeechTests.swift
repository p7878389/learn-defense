import Testing
@testable import LearnCore

@Suite("收藏购买语音清单")
struct CollectionSpeechTests {
    @Test func purchaseLinesAreIncludedInDoubaoGenerationCatalog() {
        let clips = SpeechCatalog.clips(packs: [], includeGameLines: true)
        #expect(clips.contains { $0.text == "买到掷石斥候啦，已经加入怪物队伍！" })
        #expect(clips.contains { $0.text == SpeechText.Line.bought("星轨魔导书") })
    }
    @Test func everyVisibleSkinUsesTheSamePurchaseTextAsTheCatalog() {
        let clips = SpeechCatalog.clips(packs: [], includeGameLines: true)
        for item in GrowthCatalog.bundled.cosmetics where !item.isOriginal {
            let text = SpeechText.Line.purchaseSuccess(item)
            #expect(clips.contains { $0.text == text && $0.path.hasPrefix("game/收藏购买/") })
            if item.slot == .enemySkin { #expect(!text.contains("已经换上")) }
        }
    }

}
