import Foundation

/// 怪物这一帧的移动：向书架方向走多远，身体离地多高（跳起来时）
public struct Motion: Equatable, Sendable {
    public var dx: Double
    public var lift: Double

    public init(dx: Double, lift: Double = 0) {
        self.dx = dx
        self.lift = lift
    }
}

/// 移动策略。平均速度都等于传入的 speed，保证「多少秒走到书架」的难度设定不变，只是走法不同
public protocol MovementStrategy: Sendable {
    mutating func step(dt: Double, speed: Double) -> Motion
}

/// 移动方式的配置，用 makeStrategy() 生成对应的策略
public enum MovementStyle: Hashable, Sendable {
    /// 匀速走
    case steady
    /// 停一下、跳一下
    case hop(pause: Double, airTime: Double, height: Double)
    /// 时快时慢
    case surge(period: Double, amplitude: Double)

    public func makeStrategy() -> any MovementStrategy {
        switch self {
        case .steady:
            SteadyMovement()
        case let .hop(pause, airTime, height):
            HopMovement(pause: pause, airTime: airTime, height: height)
        case let .surge(period, amplitude):
            SurgeMovement(period: period, amplitude: amplitude)
        }
    }
}

public struct SteadyMovement: MovementStrategy {
    public init() {}

    public mutating func step(dt: Double, speed: Double) -> Motion {
        Motion(dx: speed * dt)
    }
}

public struct HopMovement: MovementStrategy {
    let pause: Double
    let airTime: Double
    let height: Double
    private var phase = 0.0

    public init(pause: Double, airTime: Double, height: Double) {
        self.pause = max(0, pause)
        self.airTime = max(0.05, airTime)
        self.height = height
    }

    public mutating func step(dt: Double, speed: Double) -> Motion {
        let cycle = pause + airTime
        // 只在空中前进，所以空中要走得快一些，平均下来和匀速一样
        let airSpeed = speed * cycle / airTime
        var remaining = dt
        var dx = 0.0
        while remaining > 0 {
            let inAir = phase >= pause
            let slice = min(remaining, (inAir ? cycle : pause) - phase)
            if inAir { dx += airSpeed * slice }
            phase += slice
            remaining -= slice
            if phase >= cycle - 1e-9 { phase = 0 }
        }
        let lift = phase >= pause ? sin(.pi * (phase - pause) / airTime) * height : 0
        return Motion(dx: dx, lift: lift)
    }
}

public struct SurgeMovement: MovementStrategy {
    let period: Double
    let amplitude: Double
    private var time = 0.0

    public init(period: Double, amplitude: Double) {
        self.period = max(0.1, period)
        // 超过 1 会倒着走
        self.amplitude = min(max(0, amplitude), 0.9)
    }

    public mutating func step(dt: Double, speed: Double) -> Motion {
        // 速度 = speed × (1 + amplitude × sin(2πt/period))，这里直接积分
        let w = 2 * Double.pi / period
        let start = time
        time += dt
        let dx = speed * (dt + amplitude / w * (cos(w * start) - cos(w * time)))
        return Motion(dx: dx)
    }
}
