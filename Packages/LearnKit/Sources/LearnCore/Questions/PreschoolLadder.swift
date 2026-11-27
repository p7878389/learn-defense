import Foundation

/// 连续答对逐级升阶；答错后从难度允许的最低题阶重新练习。
public enum PreschoolLadder {
    public static func level(_ stats: ItemStats?) -> Int {
        min(3, max(0, stats?.streak ?? 0))
    }
}

enum Radical {
    static func of(_ hint: String?) -> String? {
        guard let hint else { return nil }
        return ["提手旁", "三点水", "虫字旁", "言字旁", "宝盖头", "单人旁", "双人旁",
                "木字旁", "禾木旁", "月字旁", "口字旁", "王字旁", "女字旁", "土字旁",
                "车字旁", "目字旁", "双耳旁", "方字旁", "立刀旁", "示字旁", "火字旁",
                "草字头", "竹字头", "雨字头", "广字头", "父字头", "白字头", "日字头",
                "病字旁", "足字旁", "金字旁", "绞丝旁", "竖心旁", "走之旁", "身字旁",
                "心字底", "四点底", "女字底", "木字底"]
            .first { hint.contains($0) }
    }
}
