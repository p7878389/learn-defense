import Foundation
import LearnCore

/// 一局游戏的规则和状态：出题、判题、血量、能量、大招、道具、结算
@MainActor
final class GameSession: ObservableObject {
    enum Phase: Equatable {
        case preparing, playing, paused, resting, won, lost, abandoned
    }

    struct Mistake: Identifiable {
        let id = UUID()
        let prompt: String
        let answer: String
        let explanation: String?
        /// 没来得及答，怪物就走到了书架
        let missed: Bool
    }

    let config: GameConfig
    /// 首次进入可预览和布阵，但必须先手动确认题库才能开战。
    let bankConfirmed: Bool
    let rules: GameRules
    let feedback = AnswerFeedback()
    let tuning: GameTuning
    let scene: GameScene
    let isEmpty: Bool

    @Published var phase: Phase = .preparing
    @Published private(set) var map: BattleMap
    @Published var isUnleashing = false
    @Published var hearts: Int?
    /// 模块内可写，方便测试直接攒满能量
    @Published var energy = 0
    @Published var score = 0
    @Published var sun: Int
    @Published var defeated = 0
    @Published var totalEnemies: Int
    /// 当前瞄准的怪物的题目
    @Published var current: Question?
    /// 当前题目已经点错的选项
    /// 选择题是答错的选项；输入题是第几次答错（1、2、3…），个数就是答错次数
    @Published var wrongPicks: Set<Int> = []
    /// 正在拼字块题：战场放慢，瞄准的怪物停下
    @Published var typing = false
    @Published var ultimate: Question?
    @Published var ultimateWrongPicks: Set<Int> = []
    @Published private(set) var inventory = Inventory(capacity: 3)
    /// 场上已经有一道铁栅门；碎了才能再放
    @Published var barricadeDown = false
    @Published var doomCooldown = 0

    var plantable: [DefenderKind] {
        tuning.plantable + UnitCatalog.consumables.filter { growth?.state.canUseDefender($0.id) == true }
    }

    /// 普通题和大招题都只统计第一次有效作答，与学习记录和对局明细一致。
    var attempted = 0
    var firstTryCorrect = 0
    var mistakes: [Mistake] = []
    /// 通关或失败时的成长结算（经验、积分、升级、徽章）；没有成长档案时为 nil
    @Published var growthResult: GrowthResult?
    @Published var settlementError: String?
    @Published private(set) var startError: String?
    var settlementReport: GameReport?

    // 成长系统用的本局统计
    var bossesDefeated = 0
    var itemsUsed = 0
    var ultimatesCast = 0
    var battleStartedAt: Date?
    var accumulatedPlayTime: TimeInterval = 0
    var clockNow: () -> Date = Date.init
    /// 从开始闯关到结束的活跃战斗秒数（不含暂停、后台与回合休息），结算页显示
    var playSeconds = 0

    var generator: QuestionGenerator
    var scheduler = ItemScheduler()
    var tuner = AdaptiveTuner()
    var rng = SystemRandomNumberGenerator()
    /// 准备阶段给答题区预留高度用的样题：按本局出题方式出一道，不计入进度，也不影响出题顺序
    private(set) lazy var layoutSample: Question? = {
        var sampleRng = SystemRandomNumberGenerator()
        // 这一档会出字块题时按字块题量高度（比选择题高），切换题型时战场不会忽大忽小
        let mix = generator.settings.answerMix
        let mode: AnswerMode = mix.multi > 0 ? .multi : (mix.single > 0 ? .single : .choice)
        let items = generator.pool.items.shuffled(using: &sampleRng).prefix(12)
        for item in items {
            if let question = generator.makeQuestion(for: item, mode: mode, using: &sampleRng),
               mode == .choice || question.input != nil { return question }
        }
        for item in items {
            if let question = generator.makeQuestion(for: item, mode: .choice, using: &sampleRng) { return question }
        }
        return nil
    }()
    let progress: ProgressStore
    let speech: Speech
    let growth: GrowthStore?
    /// 对局记录和答题明细；为 nil 时不记录
    let recorder: GameRecorder?
    /// 题目、错选和首次展示时间只能通过同一个集合更新。
    var questions = SessionQuestions()
    var newItemGrace: TimeInterval { TimeInterval(rules.newItemGraceSeconds) }
    var ultimateShownAt: Date?
    /// 本局装备的外观（子弹、退场特效、道具皮肤）
    let loadout: Loadout

    /// 这一局依次出场的怪物种类
    var spawnPlan: [EnemyKind]
    let initialQuestions: Int
    @Published var round = 1
    @Published var roundQuestions: Int
    @Published var roundResolved = 0
    @Published var completedRounds = 0
    @Published var roundScore = 0
    @Published var roundAccuracy = 0.0
    @Published var restRemaining = 0
    @Published var questionIDs: [Int] = []
    var restUntil: Date?
    var roundStartScore = 0
    var roundStartAttempted = 0
    var roundStartCorrect = 0
    var enemyKinds: [Int: EnemyKind] = [:]
    var lastEnemyID = 0
    var spawned = 0
    var resolved = 0
    var targetID: Int?
    var ultimateItem: LearningItem?

    init(config: GameConfig, library: ContentLibrary, progress: ProgressStore, speech: Speech, growth: GrowthStore? = nil,
         recorder: GameRecorder? = nil, map: BattleMap = .courtyard, bankConfirmed: Bool = true) {
        let packs = config.packIDs.compactMap(library.pack(id:))
        let pool = ItemPool(packs: packs, selection: config.selection)
        let pacing = growth?.catalog.pacing ?? GrowthCatalog.bundled.pacing
        let tuning = GameTuning.make(grade: config.grade, difficulty: config.difficulty, pacing: pacing)
        self.config = config
        self.bankConfirmed = bankConfirmed
        self.map = map
        rules = growth?.rules ?? .defaults
        self.tuning = tuning
        self.progress = progress
        self.speech = speech
        self.growth = growth
        self.recorder = recorder
        loadout = growth?.loadout ?? .standard
        generator = QuestionGenerator(pool: pool, settings: tuning.generator)
        hearts = tuning.hearts
        sun = tuning.startingSun
        // 首回合按年级/难度定题量，随后递增；怪物血量之和就是题数
        var questions = tuning.questions
        if case .review = config.selection {
            questions = pacing.reviewBudget(itemCount: pool.items.count, cap: questions)
        }
        initialQuestions = questions
        roundQuestions = questions
        var planRNG = SystemRandomNumberGenerator()
        spawnPlan = tuning.waves.kinds(questions: questions, using: &planRNG)
        totalEnemies = spawnPlan.count
        isEmpty = pool.isEmpty
        scene = GameScene(
            tuning: tuning,
            theme: SceneTheme.choose(packs: packs, selection: config.selection, grade: config.grade),
            loadout: loadout, map: map)
        scene.gameDelegate = self
        scene.setPreparing(true)
        if isEmpty {
            scene.setGamePaused(true)
        } else {
            UnitSprites.preloadCombat(defenders: plantable, enemies: spawnPlan, loadout: loadout)
        }
    }

    /// 准备阶段只更换背景，战斗开始后锁定本局地图。
    func selectMap(_ map: BattleMap) {
        guard phase == .preparing, self.map != map else { return }
        scene.setMap(map)
        self.map = map
    }

    /// 能不能用道具栏里的道具
    var canUseItems: Bool {
        phase == .playing && ultimate == nil
    }

    var ultimateReady: Bool {
        energy >= tuning.ultimateEnergy && phase == .playing && ultimate == nil
    }

    var canUseShop: Bool {
        (phase == .preparing || phase == .playing || phase == .resting) && ultimate == nil
    }

    var plantedLaneCount: Int {
        scene.plantedLaneCount
    }

    var canStartBattle: Bool {
        phase == .preparing && bankConfirmed && plantedLaneCount > 0
    }

    var accuracy: Double {
        attempted == 0 ? 0 : Double(firstTryCorrect) / Double(attempted)
    }

    var stars: Int {
        guard phase == .won else { return 0 }
        if accuracy >= 0.9 && hearts == tuning.hearts { return 3 }
        return accuracy >= 0.7 ? 2 : 1
    }

    // MARK: - 道具

    func startBattle() {
        guard canStartBattle else { return }
        // 先保存成长基线，避免未结算的学习进度在重启后被当作旧档补发奖励。
        do {
            if growth?.loadError != nil { try growth?.reload() }
            try growth?.save()
            startError = nil
        } catch {
            startError = "无法开始闯关，请重试或返回主页检查存档：\(error.localizedDescription)"
            return
        }
        phase = .playing
        resumePlayTimer()
        scene.setPreparing(false)
        speech.speak(SpeechText.Line.battleStart, interrupt: true)
    }

    /// 拖动卡牌时在草坪上标出落点格，point 为 nil 时收起
    func previewSeed(at point: CGPoint?) {
        scene.showPlantPreview(at: canUseShop ? point : nil)
    }

    /// 把拖到战场上的卡牌落到对应草坪；成功后立即扣除阳光
    func dropSeed(id: String, at point: CGPoint) -> Bool {
        guard canUseShop, let kind = plantable.first(where: { $0.id == id }) else { return false }
        if id == AdventureDoom.id, scene.doomCooldown > 0 { return false }
        guard sun >= kind.sunCost else {
            scene.play(FloatingTextEffect(text: "阳光不够", color: Palette.hurt, fontSize: 30))
            speech.speak(SpeechText.Line.notEnoughSun, interrupt: true)
            return false
        }
        guard scene.plant(kind, at: point) else {
            if scene.hasDoomCrater(at: point) {
                scene.play(FloatingTextEffect(text: "焦坑恢复后才能种植", color: Palette.hurt, fontSize: 26))
                return false
            }
            if scene.isPlantable(point) {
                scene.play(FloatingTextEffect(text: "这里已经有植物了", color: Palette.hurt, fontSize: 26))
                speech.speak(SpeechText.Line.cellTaken, interrupt: true)
            } else {
                scene.play(FloatingTextEffect(text: "只能种在战场的空位", color: Palette.hurt, fontSize: 26))
                speech.speak(SpeechText.Line.cellBlocked, interrupt: true)
            }
            return false
        }
        // 种下成功只有画面上的「种下了」，不再语音播报
        sun -= kind.sunCost
        return true
    }

    /// 铁栅门卡能不能点：战斗中、场上还没有门、有正在答题的僵尸（阳光不够时卡片变灰，由界面判断）
    var canDropBarricade: Bool {
        tuning.barricade != nil && phase == .playing && ultimate == nil && !barricadeDown && targetID != nil
    }

    /// 花阳光在正在答题的僵尸面前放一道铁栅门，同一时间场上只有一道
    @discardableResult
    func dropBarricade() -> Bool {
        guard let kind = tuning.barricade, phase == .playing, ultimate == nil else { return false }
        guard !barricadeDown else {
            speech.speak(SpeechText.Line.gateBusy, interrupt: true)
            return false
        }
        guard let id = targetID else {
            speech.speak(SpeechText.Line.gateNoTarget, interrupt: true)
            return false
        }
        guard sun >= kind.sunCost else {
            scene.play(FloatingTextEffect(text: "阳光不够", color: Palette.hurt, fontSize: 30))
            speech.speak(SpeechText.Line.notEnoughSun, interrupt: true)
            return false
        }
        guard scene.dropBarricade(kind, before: id) else { return false }
        sun -= kind.sunCost
        barricadeDown = true
        speech.speak(SpeechText.Line.gateDown, interrupt: true)
        return true
    }

    func useItem(at index: Int) {
        guard canUseItems, let item = inventory.take(at: index) else { return }
        itemsUsed += 1
        speech.speak(item.name, interrupt: true)
        scene.play(FloatingTextEffect(text: "\(item.icon) \(item.name)", fontSize: 40))
        item.use(on: self)
    }

    /// 打败怪物时按概率掉落道具
    func rollDrop(from kind: EnemyKind, at point: CGPoint) {
        // 道具皮肤只换图标和名字，效果不变
        guard let item = kind.drop?.roll(using: &rng).map(loadout.skin) else { return }
        // 不会失败的模式里回血没用
        if !tuning.canLose && item.onlyHeals { return }
        guard inventory.add(item) else { return }
        scene.play(FloatingTextEffect(text: "\(item.icon) +1", color: Palette.jadeDark), at: point)
    }
}
