import Foundation
import LearnCore

/// 一局游戏的规则和状态：出题、判题、血量、能量、大招、道具、结算
@MainActor
final class GameSession: ObservableObject {
    enum Phase: Equatable {
        case preparing, playing, paused, won, lost
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
    let tuning: GameTuning
    let scene: GameScene
    let isEmpty: Bool

    @Published private(set) var phase: Phase = .preparing
    @Published private(set) var hearts: Int?
    @Published private(set) var energy = 0
    @Published private(set) var score = 0
    @Published private(set) var sun: Int
    @Published private(set) var defeated = 0
    @Published private(set) var totalEnemies: Int
    /// 当前瞄准的怪物的题目
    @Published private(set) var current: Question?
    /// 当前题目已经点错的选项
    @Published private(set) var wrongPicks: Set<Int> = []
    @Published private(set) var ultimate: Question?
    @Published private(set) var ultimateWrongPicks: Set<Int> = []
    @Published private(set) var inventory = Inventory(capacity: 3)

    private(set) var attempted = 0
    private(set) var firstTryCorrect = 0
    private(set) var mistakes: [Mistake] = []

    private var generator: QuestionGenerator
    private var scheduler = ItemScheduler()
    private var tuner = AdaptiveTuner()
    private var rng = SystemRandomNumberGenerator()
    private let progress: ProgressStore
    private let speech: Speech

    /// 这一局依次出场的怪物种类
    private let spawnPlan: [EnemyKind]
    private var enemyKinds: [Int: EnemyKind] = [:]
    private var lastEnemyID = 0
    private var spawned = 0
    private var resolved = 0
    private var enemyQuestions: [Int: (item: LearningItem, question: Question)] = [:]
    private var enemyWrongPicks: [Int: Set<Int>] = [:]
    private var targetID: Int?
    private var ultimateItem: LearningItem?

    init(config: GameConfig, library: ContentLibrary, progress: ProgressStore, speech: Speech) {
        let packs = config.packIDs.compactMap(library.pack(id:))
        let pool = ItemPool(packs: packs, selection: config.selection)
        let tuning = GameTuning.make(grade: config.grade, difficulty: config.difficulty)
        self.config = config
        self.tuning = tuning
        self.progress = progress
        self.speech = speech
        generator = QuestionGenerator(pool: pool, settings: tuning.generator)
        hearts = tuning.hearts
        sun = tuning.startingSun
        totalEnemies = tuning.enemyCount
        var planRNG = SystemRandomNumberGenerator()
        spawnPlan = tuning.waves.kinds(count: tuning.enemyCount, using: &planRNG)
        isEmpty = pool.isEmpty
        scene = GameScene(tuning: tuning, theme: SceneTheme.choose(packs: packs, selection: config.selection, grade: config.grade))
        scene.gameDelegate = self
        scene.setPreparing(true)
        if isEmpty { scene.setGamePaused(true) }
    }

    /// 能不能用道具栏里的道具
    var canUseItems: Bool {
        phase == .playing && ultimate == nil
    }

    var ultimateReady: Bool {
        energy >= tuning.ultimateEnergy && phase == .playing && ultimate == nil
    }

    var canUseShop: Bool {
        (phase == .preparing || phase == .playing) && ultimate == nil
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
        var picks = enemyWrongPicks[id] ?? []

        if index == question.answerIndex {
            guard scene.canAttack(id) else {
                scene.play(FloatingTextEffect(text: "先选卡片，再点草坪", color: Palette.hurt, fontSize: 28))
                speech.speak("先种下一个字灵，再答题打僵尸", interrupt: true)
                return
            }
            if picks.isEmpty {
                attempted += 1
                firstTryCorrect += 1
                score += 10
                energy = min(energy + 1, tuning.ultimateEnergy)
                tuner.record(correct: true)
                progress.record(entry.item, correct: true)
            } else {
                score += 2
            }
            speech.speak(question.answerSpeech, interrupt: true)
            if let card = question.card { scene.showCard(card, near: id) }
            enemyQuestions[id] = nil
            enemyWrongPicks[id] = nil
            // 打败时场景会马上瞄准下一个怪物，并回调 targetChanged
            if scene.fire(at: id) == false {
                // 还没打倒（血量多的怪物）：换一道题继续打它
                if let next = makeQuestion() {
                    enemyQuestions[id] = next
                    scene.setSign(id, next.question.signText)
                    current = next.question
                    wrongPicks = []
                    speech.speak(next.question.promptSpeech, interrupt: false)
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
            }
            picks.insert(index)
            enemyWrongPicks[id] = picks
            wrongPicks = picks
            // 揭晓正确答案并读出来，孩子再点一次正确的才能发射
            speech.speak(question.answerSpeech, interrupt: true)
            scene.penalize(id)
        }
    }

    func replayPrompt() {
        speech.speak(current?.promptSpeech, interrupt: true)
    }

    // MARK: - 大招

    func startUltimate() {
        guard ultimateReady, let pair = generator.makeUltimateQuestion(using: &rng) else { return }
        ultimateItem = pair.0
        ultimate = pair.1
        ultimateWrongPicks = []
        scene.setGamePaused(true)
        speech.speak(pair.1.promptSpeech, interrupt: true)
    }

    func answerUltimate(_ index: Int) {
        guard let question = ultimate, let item = ultimateItem else { return }
        if index == question.answerIndex {
            let firstTry = ultimateWrongPicks.isEmpty
            if firstTry { progress.record(item, correct: true) }
            speech.speak(question.answerSpeech, interrupt: true)
            ultimate = nil
            ultimateItem = nil
            energy = 0
            if phase == .playing { scene.setGamePaused(false) }
            // 第一次就答对才放大招；答错后再点对只是关掉
            if let card = question.card { scene.showCard(card, near: nil) }
            if firstTry {
                score += 30
                tuning.ultimate.use(on: self)
            }
        } else {
            guard !ultimateWrongPicks.contains(index) else { return }
            if ultimateWrongPicks.isEmpty {
                progress.record(item, correct: false)
                progress.save()
                mistakes.append(Mistake(question: question, missed: false))
            }
            ultimateWrongPicks.insert(index)
            speech.speak(question.answerSpeech, interrupt: true)
        }
    }

    // MARK: - 道具

    func startBattle() {
        guard canStartBattle else { return }
        phase = .playing
        scene.setPreparing(false)
        speech.speak("准备完成，第一只僵尸来了！", interrupt: true)
    }

    /// 拖动卡牌时在草坪上标出落点格，point 为 nil 时收起
    func previewSeed(at point: CGPoint?) {
        scene.showPlantPreview(at: canUseShop ? point : nil)
    }

    /// 把拖到战场上的卡牌落到对应草坪；成功后立即扣除阳光
    func dropSeed(id: String, at point: CGPoint) -> Bool {
        guard canUseShop, let kind = tuning.lineup.first(where: { $0.id == id }) else { return false }
        guard sun >= kind.sunCost else {
            scene.play(FloatingTextEffect(text: "阳光不够", color: Palette.hurt, fontSize: 30))
            speech.speak("阳光不够", interrupt: true)
            return false
        }
        guard scene.plant(kind, at: point) else {
            if scene.isPlantable(point) {
                scene.play(FloatingTextEffect(text: "这里已经有植物了", color: Palette.hurt, fontSize: 26))
                speech.speak("这里已经有植物了，换个空格吧", interrupt: true)
            } else {
                scene.play(FloatingTextEffect(text: "只能种在空的草坪位置", color: Palette.hurt, fontSize: 26))
                speech.speak("这里不能种，换个空的草坪位置", interrupt: true)
            }
            return false
        }
        sun -= kind.sunCost
        speech.speak("\(kind.name)种下了", interrupt: true)
        return true
    }

    func useItem(at index: Int) {
        guard canUseItems, let item = inventory.take(at: index) else { return }
        speech.speak(item.name, interrupt: true)
        scene.play(FloatingTextEffect(text: "\(item.icon) \(item.name)", fontSize: 40))
        item.use(on: self)
    }

    /// 打败怪物时按概率掉落道具
    private func rollDrop(from kind: EnemyKind, at point: CGPoint) {
        guard let item = kind.drop?.roll(using: &rng) else { return }
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
    }

    private func checkFinished() {
        if spawned >= totalEnemies && resolved >= spawned {
            finish(won: true)
        }
    }

    private func finish(won: Bool) {
        guard phase == .playing || phase == .paused else { return }
        phase = won ? .won : .lost
        ultimate = nil
        scene.setGamePaused(true)
        progress.save()
        speech.speak(won ? "太棒了，书本守住了！" : "没关系，再来一次吧！", interrupt: false)
    }
}

extension GameSession: GameSceneDelegate {
    var speedFactor: Double { tuner.speedFactor }

    func nextEnemy() -> EnemySpawn? {
        guard spawned < totalEnemies else { return nil }
        guard let entry = makeQuestion() else {
            totalEnemies = spawned
            checkFinished()
            return nil
        }
        let kind = spawned < spawnPlan.count ? spawnPlan[spawned] : .blob
        lastEnemyID += 1
        spawned += 1
        enemyQuestions[lastEnemyID] = entry
        enemyKinds[lastEnemyID] = kind
        return EnemySpawn(id: lastEnemyID, sign: entry.question.signText, kind: kind)
    }

    private func makeQuestion() -> (item: LearningItem, question: Question)? {
        // 个别知识点可能凑不齐干扰项，换一个再试
        for _ in 0..<8 {
            guard let item = scheduler.next(from: generator.pool.items, stats: progress.stats, using: &rng) else { break }
            if let question = generator.makeQuestion(for: item, using: &rng) {
                return (item, question)
            }
        }
        return nil
    }

    func targetChanged(to id: Int?) {
        targetID = id
        current = id.flatMap { enemyQuestions[$0]?.question }
        wrongPicks = id.flatMap { enemyWrongPicks[$0] } ?? []
        speech.speak(current?.promptSpeech, interrupt: false)
    }

    func enemyReachedBase(_ id: Int) -> Bool {
        guard let hearts else { return false }
        if let entry = enemyQuestions[id] {
            mistakes.append(Mistake(question: entry.question, missed: true))
        }
        enemyQuestions[id] = nil
        enemyWrongPicks[id] = nil
        enemyKinds[id] = nil
        resolved += 1
        self.hearts = hearts - 1
        if hearts - 1 <= 0 {
            finish(won: false)
        } else {
            checkFinished()
        }
        return true
    }

    func enemyDefeated(_ id: Int, at point: CGPoint) {
        if let kind = enemyKinds.removeValue(forKey: id) {
            if kind.bonus > 0 {
                score += kind.bonus
                scene.play(FloatingTextEffect(text: "+\(kind.bonus)"), at: CGPoint(x: point.x, y: point.y + 30))
            }
            sun += kind.sunReward
            scene.play(
                FloatingTextEffect(text: "☀️ +\(kind.sunReward)", color: Palette.bullet, fontSize: 32),
                at: CGPoint(x: point.x, y: point.y + 62))
            rollDrop(from: kind, at: point)
        }
        defeated += 1
        resolved += 1
        checkFinished()
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
