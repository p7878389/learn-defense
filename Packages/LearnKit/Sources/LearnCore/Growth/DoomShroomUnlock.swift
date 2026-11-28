import Foundation

public extension GrowthState {
    /// 功能道具与外观共用已有拥有记录；购买后不因等级变化而失效。
    var ownsDoomShroom: Bool { owned.contains("defender.doomShroom") }

    func canUseDefender(_ id: String) -> Bool {
        id != AdventureDoom.id || ownsDoomShroom
    }

    @discardableResult
    mutating func purchaseDoomShroom(level: Int) -> PurchaseResult {
        if ownsDoomShroom { return .alreadyOwned }
        guard level >= AdventureDoom.unlockLevel else { return .locked(level: AdventureDoom.unlockLevel) }
        guard coins >= AdventureDoom.unlockPrice else { return .notEnough(short: AdventureDoom.unlockPrice - coins) }
        coins -= AdventureDoom.unlockPrice
        owned.insert("defender.doomShroom")
        appendCoinRecord(
            kind: .purchaseDoomShroom,
            delta: -AdventureDoom.unlockPrice,
            title: "解锁道具 · 毁灭菇",
            detail: "经典与冒险模式通用"
        )
        return .bought
    }
}

public extension GrowthStore {
    /// 积分和拥有记录一同落盘；失败时保持原状态。
    @discardableResult
    func purchaseDoomShroom() throws -> GrowthState.PurchaseResult {
        let currentLevel = level.level
        return try updateAdventureState { $0.purchaseDoomShroom(level: currentLevel) }
    }
}
