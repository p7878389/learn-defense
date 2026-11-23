import SpriteKit
import Testing
@testable import LearnGame

@MainActor
@Suite("首领预警生命周期")
struct BossWarningLifecycleTests {
    @Test func leavingAPausedSceneDoesNotWaitForItsPendingWarningActions() {
        var released = false
        autoreleasepool {
            let scene = ReleaseProbeScene { released = true }
            scene.isPaused = true
            BossWarningEffect(name: "首领", laneY: 100, laneHeight: 80).play(in: scene)
        }
        #expect(released, "暂停时退出，尚未执行的预警回调不能持有整个场景")
    }

    @Test func warningFlashesWaitDuringPauseAndCleanUpAfterResume() throws {
        let clock = try SceneClock()
        clock.scene.isPaused = true
        BossWarningEffect(name: "首领", laneY: 100, laneHeight: 80).play(in: clock.scene)
        try clock.advance(seconds: 1)
        #expect(clock.scene.children.filter { $0.zPosition == 100 }.isEmpty)
        clock.scene.isPaused = false
        try clock.advance(seconds: 0.1)
        #expect(clock.scene.children.filter { $0.zPosition == 100 }.count == 1)
        try clock.advance(seconds: 2)
        #expect(clock.scene.children.filter { $0.zPosition == 100 }.isEmpty)
        #expect(clock.scene.childNode(withName: BossWarningEffect.bannerName) == nil)
        #expect(clock.scene.childNode(withName: BossWarningEffect.laneName) == nil)
    }
}

@MainActor
private final class ReleaseProbeScene: SKScene {
    let onRelease: () -> Void
    init(onRelease: @escaping () -> Void) {
        self.onRelease = onRelease
        super.init(size: CGSize(width: 900, height: 360))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { onRelease() }
}
