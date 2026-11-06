import Foundation

/// 徽章判定和校准题量用的累计数据。所有字段缺省为 0，旧文件少字段也能读
public struct GrowthStats: Codable, Sendable, Equatable {
    /// 可以写进 badges.json 的统计项
    public enum Key: String, CaseIterable, Sendable {
        case gamesPlayed, gamesWon, threeStarGames, perfectGames
        case firstTryCorrect, questionsAnswered
        case bossesDefeated, enemiesDefeated, itemsUsed, ultimatesCast
        case easyWins, normalWins, hardWins
        case playSeconds
    }

    public var gamesPlayed = 0
    public var gamesWon = 0
    public var threeStarGames = 0
    public var perfectGames = 0
    public var firstTryCorrect = 0
    public var questionsAnswered = 0
    public var bossesDefeated = 0
    public var enemiesDefeated = 0
    public var itemsUsed = 0
    public var ultimatesCast = 0
    public var easyWins = 0
    public var normalWins = 0
    public var hardWins = 0
    /// 累计对局秒数，配合 questionsAnswered 校准每局题量
    public var playSeconds = 0
    /// 「今天」是哪一天（yyyy-MM-dd，按设备时区），跨天时清零下面两项
    public var day: String?
    public var gamesToday = 0
    public var wonToday = false
    /// 当日各来源已领取积分；独立于余额，消费不会恢复额度
    public var coinsToday: [String: Int] = [:]

    public init() {}

    public subscript(_ key: Key) -> Int {
        switch key {
        case .gamesPlayed: gamesPlayed
        case .gamesWon: gamesWon
        case .threeStarGames: threeStarGames
        case .perfectGames: perfectGames
        case .firstTryCorrect: firstTryCorrect
        case .questionsAnswered: questionsAnswered
        case .bossesDefeated: bossesDefeated
        case .enemiesDefeated: enemiesDefeated
        case .itemsUsed: itemsUsed
        case .ultimatesCast: ultimatesCast
        case .easyWins: easyWins
        case .normalWins: normalWins
        case .hardWins: hardWins
        case .playSeconds: playSeconds
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func int(_ key: CodingKeys) -> Int { (try? c.decodeIfPresent(Int.self, forKey: key)) ?? 0 }
        gamesPlayed = int(.gamesPlayed)
        gamesWon = int(.gamesWon)
        threeStarGames = int(.threeStarGames)
        perfectGames = int(.perfectGames)
        firstTryCorrect = int(.firstTryCorrect)
        questionsAnswered = int(.questionsAnswered)
        bossesDefeated = int(.bossesDefeated)
        enemiesDefeated = int(.enemiesDefeated)
        itemsUsed = int(.itemsUsed)
        ultimatesCast = int(.ultimatesCast)
        easyWins = int(.easyWins)
        normalWins = int(.normalWins)
        hardWins = int(.hardWins)
        playSeconds = int(.playSeconds)
        day = try? c.decodeIfPresent(String.self, forKey: .day)
        coinsToday = (try? c.decodeIfPresent([String: Int].self, forKey: .coinsToday)) ?? [:]
        gamesToday = int(.gamesToday)
        wonToday = (try? c.decodeIfPresent(Bool.self, forKey: .wonToday)) ?? false
    }
}

/// 一个孩子的成长档案，单独存成 growth/<档案id>.json，不动档案和学习记录的格式
public struct GrowthState: Codable, Sendable, Equatable {
    public var version = 1
    /// 累计经验，等级由它算出
    public var xp = 0
    /// 当前积分，不会小于 0
    public var coins = 0
    /// 已获得的徽章 id → 获得时间
    public var badges: [String: Date] = [:]
    /// 用积分买下的外观 id（免费外观到等级自动拥有，不记在这里）
    public var owned: Set<String> = []
    /// 位置（`CosmeticKind.equipKey`）→ 装备的外观 id；没有记录就是原版
    public var equipped: [String: String] = [:]
    public var stats = GrowthStats()

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decodeIfPresent(Int.self, forKey: .version)) ?? 1
        xp = max(0, (try? c.decodeIfPresent(Int.self, forKey: .xp)) ?? 0)
        coins = max(0, (try? c.decodeIfPresent(Int.self, forKey: .coins)) ?? 0)
        badges = (try? c.decodeIfPresent([String: Date].self, forKey: .badges)) ?? [:]
        owned = (try? c.decodeIfPresent(Set<String>.self, forKey: .owned)) ?? []
        equipped = (try? c.decodeIfPresent([String: String].self, forKey: .equipped)) ?? [:]
        stats = (try? c.decodeIfPresent(GrowthStats.self, forKey: .stats)) ?? GrowthStats()
    }

    public func level(_ curve: LevelCurve) -> LevelProgress {
        curve.progress(totalXP: xp)
    }

    // MARK: 外观

    public enum CosmeticStatus: Equatable, Sendable {
        /// 等级不够
        case locked(level: Int)
        /// 已解锁，还没买
        case forSale(price: Int)
        case owned
        case equipped
    }

    public func owns(_ item: CosmeticKind, level: Int) -> Bool {
        guard level >= item.unlockLevel else { return false }
        return item.price == 0 || owned.contains(item.id)
    }

    public func isEquipped(_ item: CosmeticKind) -> Bool {
        if item.isOriginal { return equipped[item.equipKey] == nil }
        return equipped[item.equipKey] == item.id
    }

    public func status(of item: CosmeticKind, level: Int) -> CosmeticStatus {
        if level < item.unlockLevel { return .locked(level: item.unlockLevel) }
        if !owns(item, level: level) { return .forSale(price: item.price) }
        return isEquipped(item) ? .equipped : .owned
    }

    public enum PurchaseResult: Equatable, Sendable {
        case bought
        case alreadyOwned
        case locked(level: Int)
        /// 积分不够，还差多少
        case notEnough(short: Int)
    }

    /// 买一件外观。不成功时不扣积分
    @discardableResult
    public mutating func purchase(_ item: CosmeticKind, level: Int) -> PurchaseResult {
        if level < item.unlockLevel { return .locked(level: item.unlockLevel) }
        if owns(item, level: level) { return .alreadyOwned }
        guard coins >= item.price else { return .notEnough(short: item.price - coins) }
        coins -= item.price
        owned.insert(item.id)
        return .bought
    }

    /// 装备一件已拥有的外观；装「原版」等于卸下这个位置
    @discardableResult
    public mutating func equip(_ item: CosmeticKind, level: Int) -> Bool {
        guard owns(item, level: level) else { return false }
        equipped[item.equipKey] = item.isOriginal ? nil : item.id
        return true
    }

    /// 换回原版
    public mutating func unequip(key: String) {
        equipped[key] = nil
    }

    /// 本局实际使用的外观：未知或没拥有的 id 一律忽略，回到原版
    public func loadout(_ catalog: GrowthCatalog) -> Loadout {
        let current = self.level(catalog.pacing.levelCurve).level
        var loadout = Loadout()
        for (key, id) in equipped {
            guard let item = catalog.cosmetic(id: id), item.equipKey == key, owns(item, level: current) else { continue }
            if item.slot == .defenderSkin { loadout.defenderSkins[item.shooterID] = item.characterSkin }
            if item.slot == .enemySkin { loadout.enemySkin = item.characterSkin }
            if let p = item.projectile { loadout.projectile = p.look }
            if let d = item.defeat { loadout.defeat = d }
            if let s = item.itemSkin { loadout.itemSkins[s.item] = s }
        }
        return loadout
    }
}

/// 一局里用到的外观。场景照旧走子弹、退场特效和道具的现有接口，只是先问这里用哪一款
public struct Loadout: Sendable, Equatable {
    /// 射手 id → 穿的皮肤；没有记录就是原版
    public var defenderSkins: [String: CharacterSkin] = [:]
    public var enemySkin: CharacterSkin?
    /// 替换普通豌豆类（orb）子弹；寒冰射手、杨桃的子弹保持原样，免得孩子分不清哪个会减速
    public var projectile: ProjectileLook?
    /// 替换所有僵尸的退场特效
    public var defeat: DefeatEffect?
    /// 道具 id → 换上的图标和名字
    public var itemSkins: [String: ItemSkin] = [:]

    public init(projectile: ProjectileLook? = nil, defeat: DefeatEffect? = nil, itemSkins: [String: ItemSkin] = [:],
                defenderSkins: [String: CharacterSkin] = [:], enemySkin: CharacterSkin? = nil) {
        self.defenderSkins = defenderSkins
        self.enemySkin = enemySkin
        self.projectile = projectile
        self.defeat = defeat
        self.itemSkins = itemSkins
    }

    public static let standard = Loadout()

    public func projectile(for kind: DefenderKind) -> ProjectileLook {
        guard let projectile, kind.projectile.shape == .orb else { return kind.projectile }
        return projectile
    }

    public func defeat(for kind: EnemyKind) -> DefeatEffect {
        defeat ?? kind.look.defeat
    }

    /// 只换图标和名字，id 和效果不变
    public func skin(_ item: ItemKind) -> ItemKind {
        guard let skin = itemSkins[item.id] else { return item }
        var copy = item
        copy.icon = skin.icon
        copy.name = skin.name
        return copy
    }
}
