import LearnCore
import SpriteKit
import Testing
@testable import LearnGame

@Suite("射手主题外观语义", .serialized)
@MainActor
struct PlantThemeSkinTests {
    @Test func frostAppearanceDoesNotSlowAnEnemy() throws {
        let skin = try #require(CharacterSkin(rawValue: "frost"))
        let scene = GameScene(tuning: .make(grade: .g3,difficulty: .normal),theme: .academy,
                              loadout: Loadout(defenderSkins: ["inkling": skin]))
        let clock = try ThemeClock(scene: scene)
        scene.setGamePaused(true,keepingAnimations: true)
        #expect(scene.plant(.inkling,in: DefenderCell(lane: 0,column: 0)))
        let enemy = scene.spawn(EnemySpawn(id: 701,sign: "霜",kind: .armored),lane: 0,x: 620)
        try clock.advance(0.2)
        #expect(scene.fire(at: 701) == false)
        #expect(scene.childNode(withName: "themeProjectile") != nil)
        try clock.advance(1.5)
        #expect(enemy.health.current == 1)
        #expect(!enemy.isHeld)
        #expect(enemy.chewRate == 1, "冰蓝外观不得改变敌人移速或啃咬速度")
        let baseline = EnemyNode(id: 702,kind: .armored,sign: "原",lane: 0,scale: 1)
        let expected = baseline.advance(dt: 0.5,speed: 1)
        let actual = enemy.advance(dt: 0.5,speed: 1)
        #expect(abs(actual-expected) < 0.001)
    }
}
