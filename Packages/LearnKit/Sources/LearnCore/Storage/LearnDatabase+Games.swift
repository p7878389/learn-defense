import Foundation
import SwiftData

/// 某种题型的作答统计
public struct KindAccuracy: Sendable, Equatable {
    public var kind: QuestionKind
    /// 作答过的题数（不含没来得及答的）
    public var answered: Int
    public var correct: Int
    public var missed: Int
    /// 首答平均用时（毫秒）；没有用时数据时为 nil
    public var averageMs: Int?

    public var accuracy: Double { answered == 0 ? 0 : Double(correct) / Double(answered) }
}

/// 某道题上最常选错成的选项
public struct Confusion: Sendable, Equatable {
    public var itemKey: String
    public var answer: String
    public var chosen: String
    public var count: Int
}

// 对局记录与答题明细
extension LearnDatabase {
    public func saveGame(_ record: GameRecord, answers: [AnswerRecord]) throws {
        let game = StoredGame(record: record)
        context.insert(game)
        for (index, answer) in answers.enumerated() {
            context.insert(StoredAnswer(answer: answer, gameID: game.id, profileID: game.profileID, index: index))
        }
        try context.save()
    }

    /// 最近的对局（新的在前）；since 不为 nil 时只看这之后开始的
    public func games(profileID: UUID, since: Date? = nil, limit: Int? = nil) throws -> [StoredGame] {
        let pid = profileID.uuidString
        let from = since ?? .distantPast
        var descriptor = FetchDescriptor<StoredGame>(
            predicate: #Predicate { $0.profileID == pid && $0.startedAt >= from },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    /// 首页卡片用的游玩概况：最近一次游玩时间、连续游玩天数（含中途退出的对局）
    public func playActivity(profileID: UUID, now: Date = Date(), calendar: Calendar = .current) throws -> PlayActivity {
        PlayActivity(playedAt: try games(profileID: profileID).map(\.startedAt), now: now, calendar: calendar)
    }

    /// 一局的答题明细，按出题顺序
    public func answers(gameID: UUID) throws -> [StoredAnswer] {
        let gid = gameID.uuidString
        return try context.fetch(FetchDescriptor<StoredAnswer>(
            predicate: #Predicate { $0.gameID == gid },
            sortBy: [SortDescriptor(\.index)]
        ))
    }

    /// 某个知识点的全部作答（新的在前）
    public func answers(profileID: UUID, itemKey: String) throws -> [StoredAnswer] {
        let pid = profileID.uuidString
        return try context.fetch(FetchDescriptor<StoredAnswer>(
            predicate: #Predicate { $0.profileID == pid && $0.itemKey == itemKey },
            sortBy: [SortDescriptor(\.answeredAt, order: .reverse)]
        ))
    }

    /// 各题型的正确率和平均用时，正确率低的在前
    public func kindAccuracy(profileID: UUID, since: Date? = nil) throws -> [KindAccuracy] {
        var byKind: [QuestionKind: (answered: Int, correct: Int, missed: Int, ms: [Int])] = [:]
        for a in try fetchAnswers(profileID: profileID, since: since) {
            guard let kind = QuestionKind(rawValue: a.kind) else { continue }
            var s = byKind[kind] ?? (0, 0, 0, [])
            if a.missed {
                s.missed += 1
            } else {
                s.answered += 1
                if a.correct { s.correct += 1 }
                if let ms = a.responseMs { s.ms.append(ms) }
            }
            byKind[kind] = s
        }
        return byKind.map { kind, s in
            KindAccuracy(kind: kind, answered: s.answered, correct: s.correct, missed: s.missed,
                         averageMs: s.ms.isEmpty ? nil : s.ms.reduce(0, +) / s.ms.count)
        }
        .sorted { ($0.accuracy, $0.kind.rawValue) < ($1.accuracy, $1.kind.rawValue) }
    }

    /// 最常见的「把 A 选成 B」，次数多的在前
    public func confusions(profileID: UUID, since: Date? = nil, limit: Int = 20) throws -> [Confusion] {
        var counts: [String: Confusion] = [:]
        for a in try fetchAnswers(profileID: profileID, since: since) where !a.correct {
            guard let chosen = a.chosen else { continue }
            let key = "\(a.itemKey)\u{1F}\(a.answer)\u{1F}\(chosen)"
            counts[key, default: Confusion(itemKey: a.itemKey, answer: a.answer, chosen: chosen, count: 0)].count += 1
        }
        return Array(counts.values
            .sorted { ($1.count, $0.itemKey, $0.chosen) < ($0.count, $1.itemKey, $1.chosen) }
            .prefix(limit))
    }

    private func fetchAnswers(profileID: UUID, since: Date?) throws -> [StoredAnswer] {
        let pid = profileID.uuidString
        let from = since ?? .distantPast
        return try context.fetch(FetchDescriptor<StoredAnswer>(
            predicate: #Predicate { $0.profileID == pid && $0.answeredAt >= from }
        ))
    }
}
