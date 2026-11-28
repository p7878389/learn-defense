import Foundation
import LearnCore

extension GameSession {
    /// 换到答案不同的知识点，避免记住已排除的选项；小题库保留原知识点，重新生成完整选项。
    func retryQuestion(after entry: SessionQuestions.QuestionEntry, ultimate: Bool = false) -> SessionQuestions.QuestionEntry {
        let candidates = ultimate && !generator.settings.preschool && !generator.pool.ultimateItems.isEmpty
            ? generator.pool.ultimateItems : generator.pool.items
        func generate(_ item: LearningItem, _ rng: inout SystemRandomNumberGenerator) -> Question? {
            if ultimate { return generator.makeQuestion(for: item, mode: .choice, using: &rng) }
            if case .review = config.selection { return generator.makeQuestion(for: item, using: &rng) }
            return generator.makeQuestion(for: item, stats: progress.stats[item.key], using: &rng)
        }
        for item in candidates.shuffled(using: &rng) where item.key != entry.item.key {
            if let question = generate(item, &rng), question.answer != entry.question.answer {
                return (item, question)
            }
        }
        let question = generate(entry.item, &rng) ?? entry.question
        return (entry.item, question.shuffledForRetry(comparedTo: entry.question, using: &rng))
    }

    func replaceWrongQuestion(_ entry: SessionQuestions.QuestionEntry, for id: Int) {
        recordRoundReviewCard(entry.question, wasWrong: true)
        let tipTarget = entry.question.explanation ?? entry.question.card?.text ?? entry.question.answer
        lastMistakeTip = "刚才那题：\(tipTarget)"
        let next = retryQuestion(after: entry)
        questions.insert(next, for: id, isRetry: true)
        questions.markShown(id)
        scene.setSign(id, next.question.signText)
        typing = false
        wrongPicks = []
        current = next.question
        if let wrongAudio = entry.question.answerSpeech {
            speech.speak(wrongAudio, interrupt: true, channel: .question)
            speech.speak(next.question.promptSpeech, interrupt: false, channel: .question)
        } else {
            speech.speak(next.question.promptSpeech, interrupt: true, channel: .question)
        }
    }
}

extension Question {
    /// 即使原题无法再生成，也给出新 ID 和不同的完整排列，不沿用旧题按钮/输入状态。
    func shuffledForRetry<R: RandomNumberGenerator>(comparedTo old: Question, using rng: inout R) -> Question {
        func shuffled(_ values: [String], previous: [String]?, _ rng: inout R) -> [String] {
            var result = values.shuffled(using: &rng)
            if result == previous, Set(result).count > 1 {
                result.append(result.removeFirst())
            }
            return result
        }
        let options = shuffled(options, previous: old.options, &rng)
        var input = input
        if var spec = input {
            for i in spec.groups.indices {
                let previous = old.input.flatMap { $0.groups.indices.contains(i) ? $0.groups[i].tiles : nil }
                spec.groups[i].tiles = shuffled(spec.groups[i].tiles, previous: previous, &rng)
            }
            input = spec
        }
        return Question(kind: kind, itemKey: itemKey, instruction: instruction, prompt: prompt, signText: signText,
                        hint: hint, options: options, optionStyle: optionStyle, answerIndex: options.firstIndex(of: answer)!,
                        promptSpeech: promptSpeech, answerSpeech: answerSpeech, explanation: explanation, card: card, input: input)
    }
}
