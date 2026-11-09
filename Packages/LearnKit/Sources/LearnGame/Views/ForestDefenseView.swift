import Combine
import LearnCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 独立的路径塔防试验，不改变原有战斗场景。
@MainActor
private final class ForestSession: ObservableObject {
    @Published var battle = ForestBattle()
    @Published var question: Question?
    @Published var wrongPicks: Set<Int> = []
    @Published var selectedTower: ForestTower = .rapid
    private let generator: QuestionGenerator
    private let progress: ProgressStore
    private let speech: Speech
    private var currentItem: LearningItem?
    private var scheduler = ItemScheduler()
    private var rng = SystemRandomNumberGenerator()

    init(config: GameConfig, model: AppModel) {
        let pool = ItemPool(packs: config.packIDs.compactMap(model.library.pack(id:)), selection: config.selection)
        generator = QuestionGenerator(pool: pool, settings: GameTuning.make(grade: config.grade, difficulty: config.difficulty).generator)
        progress = model.progress(for: config.profileID)
        speech = model.speech
    }
    var isEmpty: Bool { generator.pool.isEmpty }
    func tick(_ elapsed: Double) {
        let previous = battle.phase
        battle.tick(elapsed)
        if previous == .fighting && battle.phase == .question { nextQuestion() }
    }
    func nextQuestion() {
        let items = generator.pool.items
        guard !items.isEmpty else { return }
        let first = scheduler.next(from: items, stats: progress.stats, using: &rng)
        let candidates = (first.map { [$0] } ?? []) + items.shuffled(using: &rng)
        for item in candidates {
            if let next = generator.makeQuestion(for: item, mode: .choice, using: &rng) {
                currentItem = item; question = next; wrongPicks = []
                speech.speak(next.promptSpeech, interrupt: true)
                return
            }
        }
    }
    func answer(_ index: Int) {
        guard let question, let item = currentItem, question.options.indices.contains(index), !wrongPicks.contains(index) else { return }
        if index == question.answerIndex {
            if wrongPicks.isEmpty { progress.record(item, correct: true); progress.save() }
            speech.speak(question.answerSpeech, interrupt: true)
            self.question = nil; currentItem = nil
            battle.answer(correct: true)
        } else {
            if wrongPicks.isEmpty { progress.record(item, correct: false); progress.save() }
            wrongPicks.insert(index)
            speech.speak(question.answerSpeech, interrupt: true)
        }
    }
}


struct ForestDefenseView: View {
    @StateObject private var session: ForestSession
    @State private var baseHit = false
    @State private var selectedHero: ForestHero?
    @State private var focusedSlot: Int?
    private let onExit: () -> Void
    init(config: GameConfig, model: AppModel, onExit: @escaping () -> Void) {
        _session = StateObject(wrappedValue: ForestSession(config: config, model: model))
        self.onExit = onExit
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button("返回", action: onExit)
                Spacer()
                Text("森林守卫 · 第 \(session.battle.wave) / 3 波")
                Spacer()
                Text("☀️ \(session.battle.coins)    ❤️ \(session.battle.lives)")
            }.font(.headline).padding(.horizontal)
            // 跟随屏幕刷新逐帧推进战斗，动画节奏与显示同步
            TimelineView(.animation) { context in
                GeometryReader { geo in
                    let width = min(geo.size.width, geo.size.height * 1376 / 768)
                    let height = width * 768 / 1376
                    ForestBattlefield(battle: session.battle, width: width, height: height, baseHit: baseHit,
                                      canBuild: session.battle.coins >= 50, selectedSlot: focusedSlot) { index in
                        focusedSlot = index
                        guard session.battle.defenses[index] == nil else { return }
                        if let selectedHero { _ = session.battle.deploy(selectedHero, at: index) }
                        else { _ = session.battle.build(session.selectedTower, at: index) }
                    }
                    .frame(width: width, height: height)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .onChange(of: context.date) { oldValue, newValue in
                    session.tick(min(newValue.timeIntervalSince(oldValue), 0.1))
                }
            }
            controls
            defenseControls
        }
        .padding(.vertical, 8)
        .background(Color(red: 0.92, green: 0.96, blue: 0.85))
        .onChange(of: session.battle.lives) { oldValue, newValue in
            guard newValue < oldValue else { return }
            baseHit = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { baseHit = false }
        }
    }
    @ViewBuilder private var controls: some View {
        if session.isEmpty {
            Text("当前选择没有题目，请返回选择题库。")
        } else {
            switch session.battle.phase {
            case .preparing:
                ScrollView(.horizontal, showsIndicators: false) {
                  HStack {
                    Button("🌱 连发塔 50") { selectedHero = nil; session.selectedTower = .rapid }.buttonStyle(.borderedProminent).tint(selectedHero == nil && session.selectedTower == .rapid ? .green : .gray)
                    Button("❄️ 冰冻塔 50") { selectedHero = nil; session.selectedTower = .frost }.buttonStyle(.borderedProminent).tint(selectedHero == nil && session.selectedTower == .frost ? .blue : .gray)
                    ForEach(ForestHero.allCases, id: \.self) { hero in
                        Button("\(hero.name) 50") { selectedHero = hero }
                            .buttonStyle(.borderedProminent).tint(selectedHero == hero ? .orange : .gray)
                            .disabled(session.battle.defenses.values.contains { $0.hero == hero })
                    }
                    Button("开始第 \(session.battle.wave + 1) 波") { session.battle.startWave() }
                        .buttonStyle(.borderedProminent).disabled(!session.battle.defenses.values.contains(where: \.alive))
                  }
                }
                if session.battle.wave == 0 {
                    Picker("最终首领", selection: Binding(get: { session.battle.boss }, set: { session.battle.selectBoss($0) })) {
                        ForEach(ForestEnemyKind.bosses, id: \.self) { Text($0.name).tag($0) }
                    }.pickerStyle(.menu)
                }
                Text("选择守卫后点击空塔位；点击已有守卫可修复。最后一波：\(session.battle.boss.name)").font(.caption)
            case .fighting:
                Text("留意橙色前摇预警，及时修复防线、释放英雄技能").font(.caption)
            case .question:
                if let question = session.question {
                    VStack(spacing: 5) {
                        Text("\(question.instruction)  \(question.prompt)").font(.headline)
                        if let hint = question.hint { Text(hint).font(.caption) }
                        HStack {
                            ForEach(question.options.indices, id: \.self) { index in
                                Button(question.options[index]) { session.answer(index) }
                                    .buttonStyle(.borderedProminent)
                                    .tint(session.wrongPicks.contains(index) ? .gray : (!session.wrongPicks.isEmpty && index == question.answerIndex ? .green : .blue))
                                    .disabled(session.wrongPicks.contains(index))
                            }
                        }
                        if !session.wrongPicks.isEmpty { Text(question.explanation ?? "再选一次正确答案").font(.caption) }
                    }
                } else {
                    Text("当前题库无法生成选择题，请返回更换题库。")
                }
            case .won: Text("守护成功！森林安全了 🌟").font(.title2.bold())
            case .lost: Text("森林防线失守，再试一次吧").font(.title2.bold())
            }
        }
    }

    @ViewBuilder private var defenseControls: some View {
        if session.battle.phase == .preparing || session.battle.phase == .fighting {
            HStack {
                if let slot = focusedSlot, let unit = session.battle.defenses[slot] {
                    Text("塔位 \(slot + 1) · 耐久 \(Int(ceil(unit.health)))/\(Int(unit.maxHealth))").font(.caption)
                    Button("修复 +20 · 15☀️") { _ = session.battle.repair(at: slot) }
                        .buttonStyle(.bordered)
                        .disabled(unit.health >= unit.maxHealth || session.battle.coins < ForestBattle.repairCost)
                }
                ForEach(session.battle.defenses.keys.sorted(), id: \.self) { slot in
                    if let unit = session.battle.defenses[slot], let hero = unit.hero, session.battle.phase == .fighting {
                        Button(unit.skillCooldown > 0 ? "\(hero.skillName) \(Int(ceil(unit.skillCooldown)))s" : hero.skillName) {
                            _ = session.battle.useSkill(at: slot)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(hero == .paladin ? .orange : .green)
                        .disabled(!unit.alive || unit.skillCooldown > 0 || unit.cast != nil)
                    }
                }
            }
        }
    }
}

/// 地图主题：底图与这张地图专用的塔位底座。每张地图的塔位统一用同一种底座，不依赖底图上画的地块。
struct ForestMapTheme {
    let map: String
    let slotPad: String
    /// 空塔位可建造时的提示光颜色
    let glow: Color
    static let forest = ForestMapTheme(map: "forest-map", slotPad: "forest-slot-pad", glow: .green)
}

/// 森林战场画面：地图、塔位、怪物、弹道与击败特效。只读取战斗状态，建造通过回调交给外层。
struct ForestBattlefield: View {
    let battle: ForestBattle
    let width: CGFloat
    let height: CGFloat
    var theme: ForestMapTheme = .forest
    var baseHit = false
    var canBuild = true
    var selectedSlot: Int?
    var build: (Int) -> Void = { _ in }

    var body: some View {
        let stage = ForestStage(width: width, height: height)
        ZStack(alignment: .topLeading) {
            artwork(theme.map).resizable().frame(width: width, height: height)
            ForEach(ForestBattle.slots.indices, id: \.self) { index in
                ForestSlotPad(
                    slot: index, stage: stage, image: artwork(theme.slotPad), glow: theme.glow, time: battle.time,
                    buildable: battle.phase == .preparing && battle.defenses[index] == nil && canBuild,
                    selectable: battle.defenses[index] != nil && (battle.phase == .preparing || battle.phase == .fighting),
                    build: build)
            }
            ForEach(ForestBattle.slots.indices, id: \.self) { index in
                if let tower = battle.towers[index] {
                    ForestTowerSprite(
                        tower: tower, slot: index, stage: stage, angle: battle.angles[index] ?? 0,
                        fireAge: battle.shots.filter { $0.slot == index }.map(\.age).min(),
                        readiness: battle.readiness(of: index), time: battle.time,
                        base: artwork(tower == .rapid ? "forest-tower-rapid-base" : "forest-tower-frost"),
                        head: tower == .rapid ? artwork("forest-tower-rapid-head") : nil,
                        muzzle: artwork("forest-fx-pea-muzzle"), nova: artwork("forest-fx-ice-nova"))
                        .opacity(battle.defenses[index]?.alive == true ? 1 : 0.22)
                        .saturation(battle.defenses[index]?.alive == true ? 1 : 0)
                }
            }
            ForEach(battle.defenses.keys.sorted(), id: \.self) { slot in
                if let unit = battle.defenses[slot], unit.hero != nil {
                    ForestHeroView(unit: unit, slot: slot, width: width, height: height)
                }
            }
            // 越靠下的怪物越靠前绘制，重叠时保持前后关系
            ForEach(battle.enemies.sorted { ForestPath.forest.point(at: $0.distance).y < ForestPath.forest.point(at: $1.distance).y }) { enemy in
                if enemy.kind == .skeleton || enemy.kind == .boar {
                  ForestEnemySprite(
                    enemy: enemy, stage: stage, time: battle.time,
                    frames: ForestArtwork.frames(enemy.fast ? ForestArtwork.boarRun : ForestArtwork.skeletonWalk),
                    dust: artwork("forest-fx-dust"), nova: artwork("forest-fx-ice-nova"))
                } else {
                    ForestRosterEnemyView(enemy: enemy, width: width, height: height, time: battle.time)
                }
            }
            ForEach(battle.defeats) { defeat in
                ForestDefeatSprite(
                    defeat: defeat, stage: stage,
                    image: defeat.kind == .skeleton || defeat.kind == .boar
                        ? ForestArtwork.frames(defeat.fast ? ForestArtwork.boarRun : ForestArtwork.skeletonWalk)[0]
                        : ForestRosterArtwork.image(defeat.kind.rawValue),
                    poof: artwork("forest-fx-poof"), star: artwork("forest-fx-star"))
            }
            ForestCombatOverlay(battle: battle, width: width, height: height)
            ForEach(battle.defenses.keys.sorted(), id: \.self) { slot in
                if let unit = battle.defenses[slot] {
                    ForestDefenseStatusView(unit: unit, slot: slot, width: width, height: height, selected: selectedSlot == slot)
                }
            }
            ForEach(battle.shots) { shot in
                ForestShotSprite(
                    shot: shot, stage: stage,
                    projectile: artwork(shot.tower == .rapid ? "forest-fx-pea" : "forest-fx-ice-spear"),
                    impact: artwork(shot.tower == .rapid ? "forest-fx-pea-hit" : "forest-fx-ice-shatter"),
                    nova: artwork("forest-fx-ice-nova"))
            }
            if baseHit {
                Image(systemName: "burst.fill")
                    .font(.system(size: max(28, width * 0.05)))
                    .foregroundStyle(.red, .yellow)
                    .shadow(color: .orange, radius: 8)
                    .position(x: width * 0.96, y: height * 0.52)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: width, height: height)
    }
    private func artwork(_ name: String) -> Image {
        ForestArtwork.image(name)
    }
}

enum ForestArtwork {
    static let skeletonWalk = (0..<6).map { "forest-enemy-skeleton-walk-\($0)" }
    static let boarRun = (0..<6).map { "forest-enemy-boar-run-\($0)" }
    static let names = ["forest-map", "forest-slot-pad", "forest-tower-rapid-base", "forest-tower-rapid-head", "forest-tower-frost",
                        "forest-fx-pea", "forest-fx-pea-muzzle", "forest-fx-pea-hit", "forest-fx-ice-spear", "forest-fx-ice-shatter",
                        "forest-fx-ice-nova", "forest-fx-dust", "forest-fx-poof", "forest-fx-star"] + skeletonWalk + boarRun
    static let images: [String: Image] = {
        var images: [String: Image] = [:]
        for name in names {
            // 透明 PNG 优先（怪物、塔、特效），没有时回退到 JPG（地图）
            guard let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "Sprites")
                ?? Bundle.module.url(forResource: name, withExtension: "jpg", subdirectory: "Sprites") else { continue }
            #if canImport(UIKit)
            if let image = UIImage(contentsOfFile: url.path) { images[name] = Image(uiImage: image) }
            #elseif canImport(AppKit)
            if let image = NSImage(contentsOf: url) { images[name] = Image(nsImage: image) }
            #endif
        }
        return images
    }()
    static func image(_ name: String) -> Image { images[name] ?? Image(systemName: "questionmark.square") }
    static func frames(_ names: [String]) -> [Image] { names.map(image) }
}

/// 战场像素换算：地图按宽度等比缩放，所有尺寸用地图宽度的比例表示。
private struct ForestStage {
    let width: CGFloat
    let height: CGFloat
    func pixel(_ point: ForestPoint) -> CGPoint { CGPoint(x: point.x * width, y: point.y * height) }
    /// 怪物脚下（贴着路面）的位置。
    func feet(_ point: ForestPoint) -> CGPoint { CGPoint(x: point.x * width, y: point.y * height + width * 0.005) }
    /// 怪物身体中部，弹道瞄准和受击特效都落在这里。
    func body(_ point: ForestPoint) -> CGPoint { CGPoint(x: point.x * width, y: point.y * height - width * 0.022) }
    /// 塔位底座中心与尺寸（底座图 320x236）。
    func padCenter(_ slot: Int) -> CGPoint {
        let point = ForestBattle.slots[slot]
        return CGPoint(x: point.x * width, y: point.y * height + width * 0.004)
    }
    var padSize: CGSize { CGSize(width: width * 0.09, height: width * 0.09 * 236 / 320) }
    /// 塔图底边中点：落在底座中心略靠下，塔像是立在石台上。
    func towerBase(_ slot: Int) -> CGPoint {
        let pad = padCenter(slot)
        return CGPoint(x: pad.x, y: pad.y + width * 0.008)
    }
    /// 塔图高度（透明 PNG 已裁掉白边，按高度适配）。
    var towerSize: CGFloat { width * 0.088 }
    /// 连发塔图（底座、炮头同画布 332x384）的显示宽度。
    var rapidWidth: CGFloat { towerSize * 332 / 384 }
    /// 炮头转轴在塔图中的位置（颈部），与切图脚本一致。
    static let pivot = UnitPoint(x: 0.46, y: 0.37)
    /// 枪管末端在塔图中的位置。
    static let barrelTip = UnitPoint(x: 0.99, y: 0.20)
    func pivot(_ slot: Int) -> CGPoint {
        let base = towerBase(slot)
        return CGPoint(x: base.x + (Self.pivot.x - 0.5) * rapidWidth, y: base.y - towerSize + Self.pivot.y * towerSize)
    }
    /// 炮管角度换算成炮头画法：朝左时镜像，再在 ±55° 内俯仰，避免炮头朝天或朝地。
    /// 返回是否镜像、旋转弧度，以及枪管实际指向（屏幕弧度）。
    static func barrel(_ angle: Double) -> (flipped: Bool, rotation: Double, direction: Double) {
        let limit = 55.0 * .pi / 180
        if cos(angle) >= 0 {
            let rotation = max(-limit, min(limit, remainder(angle, 2 * .pi)))
            return (false, rotation, rotation)
        }
        let rotation = max(-limit, min(limit, remainder(angle - .pi, 2 * .pi)))
        return (true, rotation, .pi + rotation)
    }
    /// 炮口位置：连发塔在枪管末端（随炮头转动），冰晶塔在顶部晶石中心（图高 15% 处）。
    func muzzle(_ tower: ForestTower, slot: Int, angle: Double) -> CGPoint {
        switch tower {
        case .rapid:
            let pivot = pivot(slot)
            let pose = Self.barrel(angle)
            let dx = (Self.barrelTip.x - Self.pivot.x) * rapidWidth * (pose.flipped ? -1 : 1)
            let dy = (Self.barrelTip.y - Self.pivot.y) * towerSize
            return CGPoint(x: pivot.x + dx * cos(pose.rotation) - dy * sin(pose.rotation),
                           y: pivot.y + dx * sin(pose.rotation) + dy * cos(pose.rotation))
        case .frost:
            return CGPoint(x: towerBase(slot).x, y: towerBase(slot).y - towerSize * 0.85)
        }
    }
}

/// 塔位底座：每张地图统一一种底座图；准备阶段可建造时中心符文呼吸发光，点击即建造。
private struct ForestSlotPad: View {
    let slot: Int
    let stage: ForestStage
    let image: Image
    let glow: Color
    let time: Double
    let buildable: Bool
    var selectable = false
    let build: (Int) -> Void

    var body: some View {
        let size = stage.padSize
        let pulse = 0.5 + 0.5 * sin(time * 3 + Double(slot))
        Button {
            build(slot)
        } label: {
            image.resizable()
                .frame(width: size.width, height: size.height)
                .overlay {
                    if buildable {
                        Ellipse()
                            .fill(RadialGradient(colors: [glow.opacity(0.9), glow.opacity(0)], center: .center,
                                                 startRadius: 0, endRadius: size.width * 0.4))
                            .frame(width: size.width * 0.8, height: size.height * 0.7)
                            .opacity(0.25 + 0.45 * pulse)
                            .blendMode(.screen)
                        Ellipse()
                            .stroke(glow.opacity(0.8), lineWidth: max(1.5, stage.width * 0.002))
                            .frame(width: size.width * (0.9 + 0.12 * pulse), height: size.height * (0.85 + 0.12 * pulse))
                            .opacity(0.9 - 0.6 * pulse)
                    }
                }
                .contentShape(Ellipse())
        }
        .buttonStyle(.plain)
        .disabled(!buildable && !selectable)
        .position(stage.padCenter(slot))
    }
}

/// 沿路行走的怪物：按走过的距离切换行走/奔跑帧（减速时步频同步变慢，脚下不打滑），
/// 路掉头时瞬间换向并做一个原地转步（不横向压扁图片），受击闪白后退，减速时泛蓝结霜。
private struct ForestEnemySprite: View {
    let enemy: ForestEnemy
    let stage: ForestStage
    let time: Double
    let frames: [Image]
    let dust: Image
    let nova: Image

    var body: some View {
        let w = stage.width
        let point = ForestPath.forest.point(at: enemy.distance)
        let feet = stage.feet(point)
        // 帧画布尺寸：骷髅 253x256，野猪 320x190
        let size = enemy.fast ? CGSize(width: w * 0.075, height: w * 0.075 * 190 / 320)
                              : CGSize(width: w * 0.062 * 253 / 256, height: w * 0.062)
        // 每走过一段路面播完一个循环：骷髅一个循环两步，野猪一个循环一次跃进
        let cycle = enemy.distance * (enemy.fast ? 22 : 26)
        let progress = cycle - cycle.rounded(.down)
        // 转身动作：定在着地帧，身体先下沉再弹起；pivot 在动作中段最大
        let turning = enemy.turnTimer / ForestEnemy.turnTime
        let pivot = sin((1 - turning) * .pi) * (turning > 0 ? 1 : 0)
        let frame = turning > 0 ? 0 : min(frames.count - 1, Int(progress * Double(frames.count)))
        let hit = enemy.hitTimer / ForestEnemy.hitFlash
        let frost = min(1, enemy.slowed)
        let appear = min(1, enemy.distance / 0.02)
        let ratio = max(0, enemy.health / enemy.maxHealth)
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.3 * appear))
                .frame(width: size.width * (enemy.fast ? 0.7 : 0.6), height: w * 0.01)
                .position(feet)
            if frost > 0 {
                nova.resizable()
                    .frame(width: size.width * 1.2, height: size.width * 0.5)
                    .opacity(0.85 * frost)
                    .position(feet)
            }
            if enemy.fast {
                // 蹄子落地时扬起尘土：每个奔跑循环两次
                // 转身急停时扬尘最浓
                let kick = max(max(0, cos(progress * 4 * .pi)), pivot * 1.6)
                dust.resizable().scaledToFit()
                    .frame(width: size.width * 0.45)
                    .scaleEffect(x: enemy.facing < 0 ? -1 : 1, y: 1)
                    .opacity((0.15 + 0.5 * kick) * appear)
                    .position(x: feet.x - enemy.facing * size.width * 0.45, y: feet.y - w * 0.006)
            }
            sprite(frames[frame], size: size, hit: hit, frost: frost)
                .scaleEffect(x: enemy.facing * (1 + 0.06 * pivot), y: 1 - 0.08 * pivot, anchor: .bottom)
                .scaleEffect(0.6 + 0.4 * appear, anchor: .bottom)
                .opacity(appear)
                .position(x: feet.x - enemy.facing * hit * w * 0.006, y: feet.y - size.height / 2)
            if frost > 0 {
                Image(systemName: "snowflake")
                    .font(.system(size: max(10, w * 0.014), weight: .bold))
                    .foregroundStyle(.white, .cyan)
                    .shadow(color: .cyan, radius: 3)
                    .rotationEffect(.degrees(time * 90))
                    .opacity(frost)
                    .position(x: feet.x + size.width * 0.3, y: feet.y - size.height - w * 0.004)
            }
            if ratio < 1 {
                ZStack(alignment: .leading) {
                    Capsule().fill(.black.opacity(0.5))
                    Capsule().fill(ratio > 0.5 ? Color.green : (ratio > 0.25 ? .yellow : .red))
                        .frame(width: w * 0.036 * ratio)
                }
                .frame(width: w * 0.036, height: max(3, w * 0.005))
                .position(x: feet.x, y: feet.y - size.height - w * 0.012)
            }
        }
        .allowsHitTesting(false)
    }

    /// 本体 + 按透明度蒙版的着色层：受击闪白、减速泛蓝。
    private func sprite(_ image: Image, size: CGSize, hit: Double, frost: Double) -> some View {
        image.resizable()
            .overlay(image.resizable().renderingMode(.template).foregroundStyle(Color.cyan).opacity(0.38 * frost))
            .overlay(image.resizable().renderingMode(.template).foregroundStyle(Color.white).opacity(0.75 * hit))
            .frame(width: size.width, height: size.height)
    }
}

/// 已建造的塔：塔身始终不动。连发塔只有炮头绕颈部转向目标，点射时炮头沿枪管方向后坐并喷出枪火；
/// 冰晶塔随装填进度逐渐蓄满冷光，开火瞬间闪亮并在塔基扩散寒霜。
private struct ForestTowerSprite: View {
    let tower: ForestTower
    let slot: Int
    let stage: ForestStage
    /// 炮管角度（弧度，0 朝右，正值朝下）。
    let angle: Double
    /// 本塔最近一发弹的存活时间，没有在飞的弹时为 nil。
    let fireAge: Double?
    /// 装填进度 0…1。
    let readiness: Double
    let time: Double
    let base: Image
    /// 可旋转的炮头，冰晶塔没有。
    let head: Image?
    let muzzle: Image
    let nova: Image

    var body: some View {
        let w = stage.width
        let size = stage.towerSize
        let foot = stage.towerBase(slot)
        let kick = fireAge.map { max(0, 1 - $0 / (tower == .rapid ? 0.12 : 0.2)) } ?? 0
        let breathe = sin(time * 2.4 + Double(slot) * 1.3)
        let tip = stage.muzzle(tower, slot: slot, angle: angle)
        let center = CGPoint(x: foot.x, y: foot.y - size / 2)
        ZStack {
            switch tower {
            case .rapid:
                let pose = ForestStage.barrel(angle)
                base.resizable()
                    .frame(width: stage.rapidWidth, height: size)
                    .position(center)
                if let head {
                    head.resizable()
                        .frame(width: stage.rapidWidth, height: size)
                        .scaleEffect(x: pose.flipped ? -1 : 1, y: 1, anchor: ForestStage.pivot)
                        .rotationEffect(.radians(pose.rotation), anchor: ForestStage.pivot)
                        // 后坐：沿枪管反方向退一点
                        .offset(x: -cos(pose.direction) * kick * w * 0.005, y: -sin(pose.direction) * kick * w * 0.005)
                        .position(center)
                }
                if kick > 0 {
                    muzzle.resizable().scaledToFit()
                        .frame(width: w * 0.036 * (0.75 + 0.4 * (1 - kick)))
                        .rotationEffect(.radians(pose.direction))
                        .opacity(kick)
                        .position(x: tip.x + cos(pose.direction) * w * 0.01, y: tip.y + sin(pose.direction) * w * 0.01)
                }
            case .frost:
                if kick > 0 {
                    nova.resizable()
                        .frame(width: size * (0.6 + 0.9 * (1 - kick)), height: size * 0.32 * (0.6 + 0.9 * (1 - kick)))
                        .opacity(kick)
                        .position(foot)
                }
                base.resizable().scaledToFit()
                    .frame(width: size, height: size)
                    .position(center)
                // 蓄力：装填越满晶石越亮越大；开火瞬间爆亮后归零重新蓄
                let charge = readiness * readiness
                Circle()
                    .fill(RadialGradient(colors: [.white, .cyan.opacity(0.7), .cyan.opacity(0)], center: .center, startRadius: 0, endRadius: w * 0.03))
                    .frame(width: w * 0.06 * (0.6 + 0.5 * charge + 0.5 * kick), height: w * 0.06 * (0.6 + 0.5 * charge + 0.5 * kick))
                    .opacity(0.15 + 0.45 * charge + 0.08 * breathe + 0.5 * kick)
                    .blendMode(.screen)
                    .position(tip)
            }
        }
        .allowsHitTesting(false)
    }
}

/// 弹道：按距离匀速飞行。豌豆直线追踪；冰锥带弧线，外发光并拖出一串冰雾，
/// 命中时白光一闪、冲击环扩散、冰晶炸开，目标脚下铺开寒霜。
private struct ForestShotSprite: View {
    let shot: ForestShot
    let stage: ForestStage
    let projectile: Image
    let impact: Image
    let nova: Image

    var body: some View {
        let w = stage.width
        let start = stage.muzzle(shot.tower, slot: shot.slot, angle: shot.angle)
        let end = stage.body(shot.target)
        let frost = shot.tower == .frost
        let arcHeight = frost ? w * 0.025 : 0
        ZStack {
            if shot.age < shot.flight {
                let p = shot.age / shot.flight
                if frost {
                    // 冰雾拖尾：沿已飞过的弧线向后排列，越往后越小越淡
                    ForEach(1..<7, id: \.self) { index in
                        let back = max(0, p - Double(index) * 0.06)
                        Circle()
                            .fill(RadialGradient(colors: [.white, .cyan.opacity(0.6), .cyan.opacity(0)], center: .center,
                                                 startRadius: 0, endRadius: w * 0.012))
                            .frame(width: w * 0.024 * (1 - Double(index) / 8), height: w * 0.024 * (1 - Double(index) / 8))
                            .opacity(0.75 * (1 - Double(index) / 7) * min(1, p * 6))
                            .position(point(start, end, back, arcHeight))
                    }
                }
                // 飞行方向 = 位置对 p 的导数，弹头始终指向前进方向
                let angle = atan2(end.y - start.y - cos(p * .pi) * .pi * arcHeight, end.x - start.x)
                let length = frost ? w * 0.07 : w * 0.038
                projectile.resizable().scaledToFit()
                    .frame(width: length)
                    .shadow(color: frost ? .white : .clear, radius: frost ? 2 : 0)
                    .shadow(color: frost ? .cyan : .clear, radius: frost ? 6 : 0)
                    .scaleEffect(min(1, 0.5 + p * 4))
                    // 素材弹头在右端，向后挪让弹头落在弹道位置上
                    .offset(x: -length * 0.3)
                    .rotationEffect(.radians(angle))
                    .position(point(start, end, p, arcHeight))
            } else {
                let q = (shot.age - shot.flight) / shot.impact
                if frost {
                    nova.resizable()
                        .frame(width: w * 0.09 * (0.5 + 0.7 * q), height: w * 0.035 * (0.5 + 0.7 * q))
                        .opacity(0.9 * (1 - q))
                        .position(x: end.x, y: end.y + w * 0.027)
                    Circle()
                        .fill(RadialGradient(colors: [.white, .white.opacity(0)], center: .center, startRadius: 0, endRadius: w * 0.03))
                        .frame(width: w * 0.06, height: w * 0.06)
                        .opacity(max(0, 1 - q * 4))
                        .position(end)
                    Circle()
                        .stroke(Color.white, lineWidth: max(1, w * 0.004 * (1 - q)))
                        .frame(width: w * (0.02 + 0.07 * q), height: w * (0.02 + 0.07 * q))
                        .shadow(color: .cyan, radius: 4)
                        .opacity(1 - q)
                        .position(end)
                }
                impact.resizable().scaledToFit()
                    .frame(width: w * (frost ? 0.065 : 0.03))
                    .shadow(color: frost ? .white.opacity(0.8) : .clear, radius: frost ? 3 : 0)
                    .scaleEffect(frost ? 0.5 + 0.8 * q : 0.6 + 0.7 * q)
                    .rotationEffect(.degrees(frost ? 30 * q : 0))
                    .opacity(1 - q * q)
                    .position(end)
            }
        }
        .allowsHitTesting(false)
    }

    /// 弹道上进度 p 处的位置：直线插值，冰锥再叠加一段上抛弧线。
    private func point(_ start: CGPoint, _ end: CGPoint, _ p: Double, _ arcHeight: CGFloat) -> CGPoint {
        CGPoint(x: start.x + (end.x - start.x) * p, y: start.y + (end.y - start.y) * p - sin(p * .pi) * arcHeight)
    }
}

/// 击败：怪物缩小翻倒淡出，爆出星光和烟尘，并飘出奖励数字。
private struct ForestDefeatSprite: View {
    let defeat: ForestDefeat
    let stage: ForestStage
    let image: Image
    let poof: Image
    let star: Image

    var body: some View {
        let w = stage.width
        let q = defeat.age / ForestDefeat.duration
        let center = stage.body(defeat.point)
        ZStack {
            image.resizable().scaledToFit()
                .frame(width: w * 0.055)
                .scaleEffect(1 - 0.6 * q)
                .rotationEffect(.degrees(-80 * q))
                .opacity(max(0, 1 - q * 2.5))
                .position(center)
            ForEach(0..<3, id: \.self) { index in
                let angle = Double(index) * 2 * .pi / 3 - .pi / 2
                poof.resizable().scaledToFit()
                    .frame(width: w * 0.035 * (0.6 + 0.7 * q))
                    .opacity(0.9 * (1 - q))
                    .position(x: center.x + cos(angle) * w * 0.02 * q, y: center.y + sin(angle) * w * 0.02 * q - w * 0.01 * q)
            }
            star.resizable().scaledToFit()
                .frame(width: w * 0.045 * (0.5 + 0.9 * q))
                .rotationEffect(.degrees(40 * q))
                .opacity(max(0, 1 - q * 1.8))
                .position(center)
            Text("+\(defeat.reward)")
                .font(.system(size: max(14, w * 0.022), weight: .heavy, design: .rounded))
                .foregroundStyle(.yellow)
                .shadow(color: .brown, radius: 0, x: 1, y: 1)
                .shadow(color: .black.opacity(0.8), radius: 2)
                .scaleEffect(min(1, 0.5 + q * 4))
                .opacity(q < 0.7 ? 1 : (1 - q) / 0.3)
                .position(x: center.x, y: center.y - w * 0.035 - w * 0.04 * q)
        }
        .allowsHitTesting(false)
    }
}
