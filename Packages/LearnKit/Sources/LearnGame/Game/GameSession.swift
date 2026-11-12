import Foundation
import LearnCore

/// 一局游戏的规则和状态：出题、判题、血量、能量、大招、道具、结算
@MainActor
final class GameSession: ObservableObject {
    enum Phase: Equatable {
        case preparing, playing, paused, resting, won, lost
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
    let rules: GameRules
    private let feedback = AnswerFeedback()
    let tuning: GameTuning
    let scene: GameScene
    let isEmpty: Bool

    @Published private(set) var phase: Phase = .preparing
    @Published private(set) var map: BattleMap
    @Published private(set) var isUnleashing = false
    @Published private(set) var hearts: Int?
    /// 模块内可写，方便测试直接攒满能量
    @Published internal(set) var energy = 0
    @Published private(set) var score = 0
    @Published private(set) var sun: Int
    @Published private(set) var defeated = 0
    @Published private(set) var totalEnemies: Int
    /// 当前瞄准的怪物的题目
    @Published private(set) var current: Question?
    /// 当前题目已经点错的选项
    /// 选择题是答错的选项；输入题是第几次答错（1、2、3…），个数就是答错次数
    @Published private(set) var wrongPicks: Set<Int> = []
    /// 正在拼字块题：战场放慢，瞄准的怪物停下
    @Published private(set) var typing = false
    @Published private(set) var ultimate: Question?
    @Published private(set) var ultimateWrongPicks: Set<Int> = []
    @Published private(set) var inventory = Inventory(capacity: 3)
    /// 场上已经有一道铁栅门；碎了才能再放
    @Published private(set) var barricadeDown = false

    private(set) var attempted = 0
    private(set) var firstTryCorrect = 0
    private(set) var mistakes: [Mistake] = []
    /// 通关或失败时的成长结算（经验、积分、升级、徽章）；没有成长档案时为 nil
    @Published private(set) var growthResult: GrowthResult?

    // 成长系统用的本局统计
    private(set) var bossesDefeated = 0
    private(set) var itemsUsed = 0
    private(set) var ultimatesCast = 0
    private var battleStartedAt: Date?
    /// 从开始闯关到结束的秒数，结算页显示
    private(set) var playSeconds = 0

    private var generator: QuestionGenerator
    private var scheduler = ItemScheduler()
    private var tuner = AdaptiveTuner()
    private var rng = SystemRandomNumberGenerator()
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
    private let progress: ProgressStore
    private let speech: Speech
    private let growth: GrowthStore?
    /// 对局记录和答题明细；为 nil 时不记录
    private let recorder: GameRecorder?
    /// 每个怪物当前这道题第一次成为瞄准目标的时间，算作答用时
    private var shownAt: [Int: Date] = [:]
    /// 正在给哪道新题留缓冲时间，以及从战场时钟的哪一刻算起
    private var graceMark: (question: Question.ID, start: TimeInterval)?
    private var newItemGrace: TimeInterval { TimeInterval(rules.newItemGraceSeconds) }
    private var ultimateShownAt: Date?
    /// 本局装备的外观（子弹、退场特效、道具皮肤）
    let loadout: Loadout

    /// 这一局依次出场的怪物种类
    private var spawnPlan: [EnemyKind]
    private let initialQuestions: Int
    @Published private(set) var round = 1
    @Published private(set) var roundQuestions: Int
    @Published private(set) var roundResolved = 0
    @Published private(set) var completedRounds = 0
    @Published private(set) var roundScore = 0
    @Published private(set) var roundAccuracy = 0.0
    @Published private(set) var restRemaining = 0
    @Published private(set) var questionIDs: [Int] = []
    private var restUntil: Date?
    private var roundStartScore = 0
    private var roundStartAttempted = 0
    private var roundStartCorrect = 0
    private var enemyKinds: [Int: EnemyKind] = [:]
    private var lastEnemyID = 0
    private var spawned = 0
    private var resolved = 0
    private var enemyQuestions: [Int: (item: LearningItem, question: Question)] = [:]
    private var enemyWrongPicks: [Int: Set<Int>] = [:]
    private var targetID: Int?
    private var ultimateItem: LearningItem?

    init(config: GameConfig, library: ContentLibrary, progress: ProgressStore, speech: Speech, growth: GrowthStore? = nil,
         recorder: GameRecorder? = nil, map: BattleMap = .courtyard) {
        let packs = config.packIDs.compactMap(library.pack(id:))
        let pool = ItemPool(packs: packs, selection: config.selection)
        let pacing = growth?.catalog.pacing ?? GrowthCatalog.bundled.pacing
        let tuning = GameTuning.make(grade: config.grade, difficulty: config.difficulty, pacing: pacing)
        self.config = config
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
        if isEmpty { scene.setGamePaused(true) }
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
        phase == .preparing && plantedLaneCount > 0
    }

    var accuracy: Double {
        attempted == 0 ? 0 : Double(firstTryCorrect) / Double(attempted)
    }

    var stars: Int {
        guard phase == .won else { return 0 }
        if accuracy >= 0.9 && hearts == tuning.hearts { return 3 }
        return accuracy >= 0.7 ? 2 : 1
    }

    // MARK: - 答题

    func answer(_ index: Int) {
        guard phase == .playing, ultimate == nil, let id = targetID, let entry = enemyQuestions[id] else { return }
        let question = entry.question
        guard question.input == nil, question.options.indices.contains(index) else { return }
        submit(id: id, entry: entry, correct: index == question.answerIndex, pick: index) { [recorder] shownAt in
            recorder?.recordAnswer(question, chosenIndex: index, shownAt: shownAt)
        }
    }

    /// 字块题交卷：texts 依次是每个空放进去的字块
    func answerInput(_ texts: [String]) {
        guard phase == .playing, ultimate == nil, let id = targetID, let entry = enemyQuestions[id],
              let spec = entry.question.input else { return }
        let question = entry.question
        let correct = spec.accepts(texts)
        let typedText = spec.compose(texts)
        submit(id: id, entry: entry, correct: correct, pick: (enemyWrongPicks[id]?.count ?? 0) + 1) { [recorder] shownAt in
            recorder?.recordAnswer(question, typed: typedText, correct: correct, shownAt: shownAt)
        }
    }

    /// 孩子开始点字块：战场放慢、瞄准的怪物停下；交卷或换目标后恢复
    func setTyping(_ on: Bool) {
        typing = on && phase == .playing && ultimate == nil && current?.input != nil
    }

    /// 选择题和输入题共用的判题：pick 是这次作答的标记（选项序号或第几次输入），
    /// record 只在第一次作答时调用，记下这一题的成绩
    private func submit(id: Int, entry: (item: LearningItem, question: Question), correct: Bool, pick index: Int,
                        record: (Date?) -> Void) {
        let question = entry.question
        var picks = enemyWrongPicks[id] ?? []

        if correct {
            guard scene.canAttack(id) else {
                scene.play(FloatingTextEffect(text: "先选卡片，再点战场空位", color: Palette.hurt, fontSize: 28))
                speech.speak(SpeechText.Line.plantFirst, interrupt: true)
                return
            }
            if picks.isEmpty {
                attempted += 1
                firstTryCorrect += 1
                score += 10
                let wasFull = energy >= tuning.ultimateEnergy
                energy = min(energy + 1, tuning.ultimateEnergy)
                if !wasFull && energy >= tuning.ultimateEnergy {
                    feedback.play(.ultimateReady, volume: speech.effectsVolume)
                }
                tuner.record(correct: true)
                progress.record(entry.item, correct: true)
                record(shownAt[id])
            } else {
                score += 2
            }
            feedback.play(correct: true, volume: speech.effectsVolume)
            typing = false
            scene.noteCorrectAnswer()

            enemyQuestions[id] = nil
            enemyWrongPicks[id] = nil
            shownAt[id] = nil
            questionIDs = enemyQuestions.keys.sorted()
            // 打败时场景会马上瞄准下一个怪物，并回调 targetChanged
            if scene.fire(at: id) == false {
                // 还没打倒（血量多的怪物）：换一道题继续打它
                if let next = makeQuestion() {
                    enemyQuestions[id] = next
                    questionIDs = enemyQuestions.keys.sorted()
                    shownAt[id] = Date()
                    scene.setSign(id, next.question.signText)
                    current = next.question
                    wrongPicks = []
                    speech.speak(next.question.promptSpeech, interrupt: false, channel: .question)
                } else {
                    scene.fire(at: id, overwhelming: true)
                }
            }
        } else {
            guard !picks.contains(index) else { return }
            if picks.isEmpty {
                attempted += 1
                tuner.record(correct: false)
                progress.record(entry.item, correct: false)
                progress.save()
                mistakes.append(Mistake(question: question, missed: false))
                record(shownAt[id])
            }
            picks.insert(index)
            enemyWrongPicks[id] = picks
            wrongPicks = picks
            feedback.play(correct: false, volume: speech.effectsVolume)
            scene.penalize(id)
        }
    }

    func replayPrompt() {
        speech.speak((ultimate ?? current)?.promptSpeech, interrupt: true, channel: .preview)
    }

    // MARK: - 大招

    func startUltimate() {
        guard ultimateReady, let pair = generator.makeUltimateQuestion(using: &rng) else { return }
        ultimateItem = pair.0
        ultimate = pair.1
        typing = false
        ultimateWrongPicks = []
        ultimateShownAt = Date()
        scene.setGamePaused(true)
        speech.speak(pair.1.promptSpeech, interrupt: true, channel: .question)
    }

    /// 不放大招了：关掉题目、继续战斗。还没作答就取消，能量留着下次再放；
    /// 已经答错过再取消，和「答错后再点对只是关掉」一样清空能量，免得靠取消换一道题
    func cancelUltimate() {
        guard ultimate != nil else { return }
        if !ultimateWrongPicks.isEmpty { energy = 0 }
        ultimate = nil
        ultimateItem = nil
        ultimateWrongPicks = []
        ultimateShownAt = nil
        speech.stop()
        if phase == .playing { scene.setGamePaused(false) }
    }

    func answerUltimate(_ index: Int) {
        guard phase == .playing, let question = ultimate, let item = ultimateItem, question.options.indices.contains(index) else { return }
        if index == question.answerIndex {
            let firstTry = ultimateWrongPicks.isEmpty
            if firstTry {
                progress.record(item, correct: true)
                recorder?.recordAnswer(question, chosenIndex: index, ultimate: true, shownAt: ultimateShownAt)
            }
            feedback.play(correct: true, volume: speech.effectsVolume)
            ultimate = nil
            ultimateItem = nil
            energy = 0
            if phase == .playing { scene.setGamePaused(false) }
            // 第一次就答对才放大招；答错后再点对只是关掉

            if firstTry {
                score += 30
                ultimatesCast += 1
                feedback.play(.ultimateCast, volume: speech.effectsVolume)
                speech.speak(SpeechText.Line.ultimateCast(tuning.ultimate.name), interrupt: true)
                tuning.ultimate.use(on: self)
            }
        } else {
            guard !ultimateWrongPicks.contains(index) else { return }
            if ultimateWrongPicks.isEmpty {
                progress.record(item, correct: false)
                progress.save()
                mistakes.append(Mistake(question: question, missed: false))
                recorder?.recordAnswer(question, chosenIndex: index, ultimate: true, shownAt: ultimateShownAt)
            }
            ultimateWrongPicks.insert(index)
            feedback.play(correct: false, volume: speech.effectsVolume)
        }
    }

    // MARK: - 道具

    func startBattle() {
        guard canStartBattle else { return }
        phase = .playing
        battleStartedAt = Date()
        scene.setPreparing(false)
        speech.speak(SpeechText.Line.battleStart, interrupt: true)
    }

    /// 拖动卡牌时在草坪上标出落点格，point 为 nil 时收起
    func previewSeed(at point: CGPoint?) {
        scene.showPlantPreview(at: canUseShop ? point : nil)
    }

    /// 把拖到战场上的卡牌落到对应草坪；成功后立即扣除阳光
    func dropSeed(id: String, at point: CGPoint) -> Bool {
        guard canUseShop, let kind = tuning.plantable.first(where: { $0.id == id }) else { return false }
        guard sun >= kind.sunCost else {
            scene.play(FloatingTextEffect(text: "阳光不够", color: Palette.hurt, fontSize: 30))
            speech.speak(SpeechText.Line.notEnoughSun, interrupt: true)
            return false
        }
        guard scene.plant(kind, at: point) else {
            if scene.isPlantable(point) {
                scene.play(FloatingTextEffect(text: "这里已经有植物了", color: Palette.hurt, fontSize: 26))
                speech.speak(SpeechText.Line.cellTaken, interrupt: true)
            } else {
                scene.play(FloatingTextEffect(text: "只能种在战场的空位", color: Palette.hurt, fontSize: 26))
                speech.speak(SpeechText.Line.cellBlocked, interrupt: true)
            }
            return false
        }
        sun -= kind.sunCost
        speech.speak(SpeechText.Line.planted(kind.name), interrupt: true)
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
    private func rollDrop(from kind: EnemyKind, at point: CGPoint) {
        // 道具皮肤只换图标和名字，效果不变
        guard let item = kind.drop?.roll(using: &rng).map(loadout.skin) else { return }
        // 不会失败的模式里回血没用
        if !tuning.canLose && item.onlyHeals { return }
        guard inventory.add(item) else { return }
        scene.play(FloatingTextEffect(text: "\(item.icon) +1", color: Palette.jadeDark), at: point)
    }

    // MARK: - 暂停与结束

    func togglePause() {
        switch phase {
        case .playing:
            phase = .paused
            scene.setGamePaused(true)
        case .paused:
            phase = .playing
            if ultimate == nil { scene.setGamePaused(false) }
        default:
            break
        }
    }

    /// 离开游戏界面时调用
    func end() {
        scene.setGamePaused(true)
        speech.stop()
        progress.save()
        finishGame()
        speech.stop()
    }

    private func checkFinished() {
        guard phase == .playing, totalEnemies > 0,
              spawned >= totalEnemies, resolved >= spawned else { return }
        completedRounds += 1
        roundScore = score - roundStartScore
        let answered = attempted - roundStartAttempted
        roundAccuracy = answered == 0 ? 0 : Double(firstTryCorrect - roundStartCorrect) / Double(answered)
        restRemaining = rules.restSeconds(afterRound: round)
        restUntil = Date().addingTimeInterval(Double(restRemaining))
        phase = .resting
        typing = false
        ultimate = nil
        ultimateItem = nil
        current = nil
        targetID = nil
        questionIDs = []
        scene.setGamePaused(true)
        progress.save()
        speech.stop()
    }

    /// 明确结束整局才结算；回合结束不发成长奖励。
    func finishGame() {
        finish(won: completedRounds > 0)
    }

    func updateRest(now: Date = Date()) {
        guard phase == .resting, let restUntil else { return }
        restRemaining = max(0, Int(ceil(restUntil.timeIntervalSince(now))))
        if restRemaining == 0 { self.restUntil = nil }
    }

    func continueRound() {
        updateRest()
        guard phase == .resting, restRemaining == 0 else { return }
        round += 1
        roundQuestions = initialQuestions + (round - 1) * rules.questionIncrement[config.difficulty]
        spawnPlan = tuning.waves.kinds(questions: roundQuestions, using: &rng)
        totalEnemies = spawnPlan.count
        spawned = 0
        resolved = 0
        roundResolved = 0
        enemyQuestions.removeAll()
        enemyWrongPicks.removeAll()
        shownAt.removeAll()
        wrongPicks = []
        roundStartScore = score
        roundStartAttempted = attempted
        roundStartCorrect = firstTryCorrect
        restUntil = nil
        phase = .playing
        scene.beginRound()
    }

    var selectedQuestionID: Int? { targetID }

    func selectQuestion(_ id: Int) {
        guard phase == .playing, ultimate == nil, enemyQuestions[id] != nil else { return }
        scene.selectTarget(id)
    }

    private func finish(won: Bool) {
        guard phase == .playing || phase == .paused || phase == .resting else { return }
        phase = won ? .won : .lost
        typing = false
        ultimate = nil
        scene.setGamePaused(true)
        progress.save()
        playSeconds = battleStartedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
        speech.speak(won ? SpeechText.Line.won : SpeechText.Line.lost, interrupt: false)
        settleGrowth()
        recordGame(won ? .won : .lost)
    }

    /// 把这一局和答题明细写进数据库（每局只写一次）
    private func recordGame(_ outcome: GameOutcome) {
        guard let recorder, !isEmpty else { return }
        let seconds = outcome == .quit
            ? battleStartedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
            : playSeconds
        recorder.finish(outcome, summary: GameSummary(
            questions: attempted,
            firstTryCorrect: firstTryCorrect,
            stars: stars,
            score: score,
            enemiesDefeated: defeated,
            bossesDefeated: bossesDefeated,
            itemsUsed: itemsUsed,
            ultimatesCast: ultimatesCast,
            seconds: seconds,
            xp: growthResult?.xp,
            coins: growthResult?.totalCoins))
    }

    /// 整局只结算一次；所有积分来源受成长系统的每日硬上限约束
    private func settleGrowth() {
        guard let growth, growthResult == nil, !isEmpty else { return }
        let result = growth.settle(GameReport(
            won: phase == .won,
            difficulty: config.difficulty,
            questions: attempted,
            firstTryCorrect: firstTryCorrect,
            stars: stars,
            bossesDefeated: bossesDefeated,
            enemiesDefeated: defeated,
            itemsUsed: itemsUsed,
            ultimatesCast: ultimatesCast,
            seconds: playSeconds))
        growthResult = result
        if result.leveledUp {
            speech.speak("升到第\(result.after.level)级啦！", interrupt: false)
        }
    }
}

extension GameSession: GameSceneDelegate {
    func ultimateAnimationStarted() { isUnleashing = true }
    func ultimateAnimationFinished() { isUnleashing = false }

    /// 拼字块题时战场放慢到一半
    var speedFactor: Double { tuner.speedFactor * (typing ? 0.5 : 1) }
    var holdsTarget: Bool { typing || inNewItemGrace }

    /// 瞄准的这道题是孩子第一次见的知识点（还没有作答记录）：从瞄准它起的几秒内，
    /// 这只怪物原地等着。答过一次（对或错）就有了记录，之后照常逼近。
    /// 按战场时钟计时，暂停时不走
    private var inNewItemGrace: Bool {
        guard newItemGrace > 0, let id = targetID, let entry = enemyQuestions[id],
              progress.stats[entry.item.key] == nil else { return false }
        if graceMark?.question != entry.question.id {
            graceMark = (entry.question.id, scene.clock)
        }
        return scene.clock - (graceMark?.start ?? scene.clock) < newItemGrace
    }

    func nextEnemy() -> EnemySpawn? {
        guard phase == .playing, spawned < totalEnemies else { return nil }
        guard let entry = makeQuestion() else {
            // 题库无法继续出题时结束，不能卡在空回合。
            finishGame()
            return nil
        }
        let kind = spawned < spawnPlan.count ? spawnPlan[spawned] : .blob
        lastEnemyID += 1
        spawned += 1
        enemyQuestions[lastEnemyID] = entry
        enemyKinds[lastEnemyID] = kind
        questionIDs = enemyQuestions.keys.sorted()
        if tuning.waves.isBoss(kind) {
            // 画面上的预警由场景在怪物出场时播放，这里配上号角和一句提醒
            feedback.play(.bossArrive, volume: speech.effectsVolume)
            speech.speak(SpeechText.Line.bossArrive(kind.name), interrupt: false)
        }
        return EnemySpawn(id: lastEnemyID, sign: entry.question.signText, kind: kind)
    }

    private func makeQuestion() -> (item: LearningItem, question: Question)? {
        // 个别知识点可能凑不齐干扰项，换一个再试
        for _ in 0..<8 {
            guard let item = scheduler.next(from: generator.pool.items, stats: progress.stats, using: &rng, reviewEvery: rules.reviewEvery) else { break }
            if let question = generator.makeQuestion(for: item, using: &rng) {
                return (item, question)
            }
        }
        return nil
    }

    func targetChanged(to id: Int?) {
        guard phase == .playing else { return }
        targetID = id
        typing = false
        current = id.flatMap { enemyQuestions[$0]?.question }
        if let id, current != nil, shownAt[id] == nil { shownAt[id] = Date() }
        wrongPicks = id.flatMap { enemyWrongPicks[$0] } ?? []
        speech.speak(current?.promptSpeech, interrupt: false, channel: .question)
    }

    func enemyReachedBase(_ id: Int) -> Bool {
        guard phase == .playing, enemyKinds[id] != nil, let hearts else { return false }
        if let entry = enemyQuestions[id] {
            mistakes.append(Mistake(question: entry.question, missed: true))
            // 已经答错过的那次作答已记录；一次都没答的记为没来得及答
            if (enemyWrongPicks[id] ?? []).isEmpty {
                attempted += 1
                progress.record(entry.item, correct: false)
                recorder?.recordAnswer(entry.question, chosenIndex: nil, shownAt: shownAt[id])
            }
        }
        enemyQuestions[id] = nil
        enemyWrongPicks[id] = nil
        shownAt[id] = nil
        enemyKinds[id] = nil
        resolved += 1
        roundResolved = resolved
        questionIDs = enemyQuestions.keys.sorted()
        self.hearts = hearts - 1
        if hearts - 1 <= 0 {
            finish(won: false)
        } else {
            checkFinished()
        }
        return true
    }

    func enemyDefeated(_ id: Int, at point: CGPoint) {
        guard phase == .playing, let kind = enemyKinds.removeValue(forKey: id) else { return }
        enemyQuestions[id] = nil
        enemyWrongPicks[id] = nil
        shownAt[id] = nil
        questionIDs = enemyQuestions.keys.sorted()
        if tuning.waves.isBoss(kind) {
            bossesDefeated += 1
            feedback.play(.bossDefeated, volume: speech.effectsVolume)
            scene.play(ScreenFlashEffect(color: Palette.bullet, alpha: 0.5, duration: 0.6))
            scene.play(FloatingTextEffect(text: "🏆 打败首领！", color: Palette.target, fontSize: 40),
                       at: CGPoint(x: point.x, y: point.y + 100))
            speech.speak(SpeechText.Line.bossDefeated, interrupt: false)
        }
        if kind.bonus > 0 {
            score += kind.bonus
            scene.play(FloatingTextEffect(text: "+\(kind.bonus)"), at: CGPoint(x: point.x, y: point.y + 30))
        }
        sun += kind.sunReward
        scene.play(
            FloatingTextEffect(text: "☀️ +\(kind.sunReward)", color: Palette.bullet, fontSize: 32),
            at: CGPoint(x: point.x, y: point.y + 62))
        rollDrop(from: kind, at: point)
        defeated += 1
        resolved += 1
        roundResolved = resolved
        checkFinished()
    }
}

extension GameSession {
    func bossEnraged(_ id: Int) {
        guard phase == .playing else { return }
        feedback.play(.bossEnrage, volume: speech.effectsVolume)
        speech.speak(SpeechText.Line.bossEnraged, interrupt: false)
    }

    func barricadeRemoved() {
        barricadeDown = false
    }
}

extension GameSession: Battlefield {
    func clearField() {
        scene.unleash()
    }

    func freezeField(seconds: Double) {
        scene.freeze(seconds: seconds)
    }

    func heal(hearts gained: Int) {
        guard let hearts, let maxHearts = tuning.hearts else { return }
        self.hearts = min(maxHearts, hearts + gained)
    }

    func addScore(_ points: Int) {
        score += points
    }
}

private extension GameSession.Mistake {
    init(question: Question, missed: Bool) {
        self.init(prompt: question.prompt, answer: question.answer, explanation: question.explanation, missed: missed)
    }
}
