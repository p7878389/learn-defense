import Foundation

public struct ParentGate: Codable, Sendable {
    public private(set) var left: Int
    public private(set) var right: Int
    public private(set) var options: [Int]
    public private(set) var failures = 0
    private var lockedUntil: Date?
    public var answer: Int { left * right }

    public init() {
        left = Int.random(in: 6...19)
        right = Int.random(in: 3...9)
        let result = left * right
        options = [result, result + 3, result - 2, result + 10].shuffled()
    }

    public mutating func renewChallenge() {
        let count = failures
        let until = lockedUntil
        self = ParentGate()
        failures = count
        lockedUntil = until
    }

    public func canAnswer(now: Date = Date()) -> Bool {
        lockedUntil.map { now >= $0 } ?? true
    }

    public mutating func submit(_ value: Int, now: Date = Date()) -> Bool {
        guard canAnswer(now: now) else { return false }
        if lockedUntil != nil { failures = 0; lockedUntil = nil }
        if value == answer { failures = 0; return true }
        failures += 1
        if failures >= 3 { lockedUntil = now.addingTimeInterval(60) }
        let count = failures
        let until = lockedUntil
        self = ParentGate()
        failures = count
        lockedUntil = until
        return false
    }
}

public struct ReaderPreferences: Codable, Equatable, Sendable {
    public enum Source: String, Codable, CaseIterable, Sendable { case system, doubao }
    public var source: Source = .doubao
    public var rate = 0.46
    public var pitch = 1.0
    public var volume = 1.0
    public var readQuestions = true
    public var readGuidance = true
    public var readsWhenSilent = true
    public var effectsVolume = 0.45
    public init() {}

    public func validated() -> Self {
        var p = self
        p.rate = p.rate.isFinite ? min(0.65, max(0.25, p.rate)) : 0.46
        p.pitch = p.pitch.isFinite ? min(1.5, max(0.7, p.pitch)) : 1
        p.volume = p.volume.isFinite ? min(1, max(0, p.volume)) : 1
        p.effectsVolume = p.effectsVolume.isFinite ? min(1, max(0, p.effectsVolume)) : 0.45
        return p
    }
}
