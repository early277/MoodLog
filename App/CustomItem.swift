import Foundation

struct CustomItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable {
        case recency, scale, yesNo, options
        var label: String {
            switch self {
            case .recency: return "最後にいつ"
            case .scale: return "5段階"
            case .yesNo: return "はい・いいえ"
            case .options: return "自分で選択肢を作る"
            }
        }
    }
    var id = UUID()
    var title: String
    var kind: Kind
    var options: [String] = []
    var enabled = true
    var choices: [Choice] {
        switch kind {
        case .recency: return Choices.recency + [Choice("never", "該当なし")]
        case .scale: return (1...5).map { Choice("level\($0)", "\($0)", Double($0)) }
        case .yesNo: return [Choice("yes", "はい", 1), Choice("no", "いいえ", 0)]
        case .options: return options.enumerated().map { Choice("option\($0.offset)", $0.element) }
        }
    }
    static func validation(title: String, kind: Kind, options: [String]) -> String? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 40 else { return "項目名は1〜40文字で入力してください。" }
        if kind == .options {
            guard (2...6).contains(options.count), options.allSatisfy({ !$0.isEmpty && $0.count <= 24 }) else {
                return "選択肢は2〜6個、各24文字以内で入力してください。"
            }
            guard Set(options).count == options.count else { return "同じ選択肢が重複しています。" }
        }
        return nil
    }
}

// Keep the question and its choices with each answer, even after hiding an item.
struct CustomResponse: Codable, Equatable {
    var item: CustomItem
    var answer: Answer
}

enum RecordingStep: Identifiable {
    case builtin(Question)
    case custom(CustomItem)
    var short: String {
        switch self {
        case .builtin(let question): return question == .note ? "保存" : question.short
        case .custom(let item): return item.title
        }
    }
    var symbol: String {
        switch self {
        case .builtin(let question): return question.symbol
        case .custom: return "square.grid.2x2.fill"
        }
    }
    var id: String {
        switch self {
        case .builtin(let question): return "builtin-\(question.rawValue)"
        case .custom(let item): return "custom-\(item.id.uuidString)"
        }
    }
}

struct GroupSummary: Identifiable {
    let id: String
    let label: String
    let mean: Double?
    let days: Int
}

extension Statistics {
    static func customSummary(_ records: [LogRecord], outcome: Question, item: CustomItem, calendar: Calendar = .current) -> [GroupSummary] {
        item.choices.map { choice in
            var daily: [Date: [Double]] = [:]
            for record in records {
                guard let response = record.customAnswers?[item.id.uuidString], let score = record[outcome]?.value else { continue }
                if item.kind == .recency, let range = AnswerCarryForward.normalized(response.answer, recordedAt: record.date, now: record.date, calendar: calendar)?.dayRange {
                    guard let bucket = ApproximateDates.choices(future: false).first(where: { $0.id == choice.id }),
                          range.lower >= bucket.range.lower,
                          bucket.range.upper == nil || (range.upper != nil && range.upper! <= bucket.range.upper!) else { continue }
                } else if response.answer.code != choice.id { continue }
                daily[calendar.startOfDay(for: record.date), default: []].append(score)
            }
            let means = daily.values.map { $0.reduce(0, +) / Double($0.count) }
            return GroupSummary(id: choice.id, label: choice.label, mean: means.isEmpty ? nil : means.reduce(0, +) / Double(means.count), days: means.count)
        }
    }
}
