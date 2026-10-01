import Foundation

enum Question: Int, CaseIterable, Codable {
    // Persisted keys 0...9 must remain stable across questionnaire revisions.
    case mood, energy, sleep, iron, b12, exercise, lastWork, nextWork, conversation, note
    case sleepStart, sleepEnd, difficultEvent
    // New keys distinguish salient events from the legacy most-recent event.
    case salientDifficultEvent, pleasantEvent
    case hunger
    case caffeine, alcohol, tobacco
    case lastObligation, nextObligation, backlog
    static let flow: [Question] = [.mood, .energy, .hunger, .sleepStart, .sleepEnd, .iron, .b12, .exercise, .lastObligation, .nextObligation, .backlog, .conversation, .salientDifficultEvent, .pleasantEvent, .caffeine, .alcohol, .tobacco, .note]
    static let history: [Question] = [.mood, .energy, .hunger, .sleep, .iron, .b12, .exercise, .lastObligation, .nextObligation, .backlog, .conversation, .salientDifficultEvent, .pleasantEvent, .caffeine, .alcohol, .tobacco]
    static let flowVersion = 7
    static func restoredStep(_ saved: Int, version: Int) -> Int {
        var migrated = version < 2 && saved >= 3 ? saved + 1 : saved
        if version < 3 && migrated >= 10 { migrated += 1 }
        if version < 4 && migrated >= 11 { migrated += 1 }
        if version < 5 && migrated >= 2 { migrated += 1 }
        if version < 6 && migrated >= 13 { migrated += 3 }
        if version < 7 && migrated >= 10 { migrated += 1 }
        return min(max(migrated, 0), flow.count - 1)
    }
    var isEvent: Bool { [.difficultEvent, .salientDifficultEvent, .pleasantEvent].contains(self) }
    var isCalendar: Bool { [.exercise, .lastWork, .nextWork, .lastObligation, .nextObligation, .conversation].contains(self) }
    static let substances: [Question] = [.caffeine, .alcohol, .tobacco]
    var isSubstance: Bool { Self.substances.contains(self) }
    var isRecency: Bool { isCalendar || isEvent || isSubstance || self == .iron || self == .b12 }
    var isFuture: Bool { self == .nextWork || self == .nextObligation }
    var isCurrentScale: Bool { self == .hunger || self == .backlog }
    var isClock: Bool { self == .sleepStart || self == .sleepEnd }
    var symbol: String {
        switch self {
        case .mood: return "face.smiling"
        case .energy: return "bolt.fill"
        case .hunger: return "fork.knife.circle"
        case .sleep, .sleepStart: return "bed.double.fill"
        case .sleepEnd: return "sunrise.fill"
        case .iron, .b12: return "fork.knife"
        case .exercise: return "figure.walk"
        case .lastWork, .lastObligation: return "briefcase.fill"
        case .nextWork, .nextObligation: return "calendar"
        case .backlog: return "tray.full.fill"
        case .conversation: return "bubble.left.and.bubble.right.fill"
        case .difficultEvent, .salientDifficultEvent: return "cloud.rain.fill"
        case .pleasantEvent: return "sun.max.fill"
        case .caffeine: return "cup.and.saucer.fill"
        case .alcohol: return "wineglass.fill"
        case .tobacco: return "smoke.fill"
        case .note: return "checkmark.circle"
        }
    }
    var title: String {
        switch self {
        case .mood: return "今の気分は？"
        case .energy: return "今の気力は？"
        case .hunger: return "今、どれくらい空腹？"
        case .sleep: return "最後の睡眠は何時間？"
        case .sleepStart: return "最後に寝た時刻は？"
        case .sleepEnd: return "起きた時刻は？"
        case .iron: return "鉄分を含む食品、\nいつ・どれくらい？"
        case .b12: return "ビタミンB12を含む食品、\nいつ・どれくらい？"
        case .exercise: return "運動したのは、いつごろ？"
        case .lastWork: return "仕事をしたのは、いつごろ？"
        case .nextWork: return "次の仕事は、いつごろ？"
        case .lastObligation: return "時間を動かしにくい用事、\nいつ終わった？"
        case .nextObligation: return "時間を動かしにくい用事、\n次はいつ？"
        case .backlog: return "やることは、\nどれくらい溜まっている？"
        case .conversation: return "人と話したのは、\nいつ・どのくらい？"
        case .difficultEvent: return "最後のつらい出来事、\nいつ・どれくらい？"
        case .salientDifficultEvent: return "いつ・どれくらい\nつらかった？"
        case .pleasantEvent: return "いつ・どれくらい\n楽しかった？"
        case .caffeine: return "カフェイン、\n最後にいつ・どれくらい？"
        case .alcohol: return "お酒、\n最後にいつ・どれくらい？"
        case .tobacco: return "たばこ、\n最後にいつ・どれくらい？"
        case .note: return "この内容で記録します"
        }
    }
    var short: String {
        ["気分", "気力", "睡眠", "鉄分", "B12", "運動", "前の仕事", "次の仕事", "会話", "メモ", "寝た時刻", "起きた時刻", "最後のつらい出来事", "つらい出来事", "楽しい出来事", "空腹", "カフェイン", "お酒", "たばこ", "前の用事", "次の用事", "溜まった用事"][rawValue]
    }
    var hint: String {
        switch self {
        case .lastObligation, .nextObligation: return "例：勤務・家族に合わせる食事の準備・送迎\n自分の都合で後回しにしにくい用事"
        case .backlog: return "仕事・家事など、まだ片づいていない用事"
        case .hunger: return "今この瞬間のお腹のすき具合を選んでください"
        case .sleep: return "昼寝を除く、最後のまとまった睡眠"
        case .sleepStart: return "短針を動かすか、時計をタップ。数字の間は30分"
        case .sleepEnd: return "短針を動かすか、時計をタップ。数字の間は30分"
        case .iron: return "レバー・牛赤身肉・あさり・かつお\n納豆・木綿豆腐・小松菜・ほうれん草"
        case .b12: return "例：魚・貝・肉・卵・乳製品"
        case .exercise: return "最後にした時期に近い範囲を選択"
        case .lastWork: return "近い時期、または勤務中を選択"
        case .nextWork: return "次に仕事が始まる時期を選択"
        case .conversation: return "最後の会話や通話について、だいたいで選択"
        case .difficultEvent: return "そのとき感じたつらさを選んでください"
        case .salientDifficultEvent: return "今、いちばん印象に残るつらい出来事について"
        case .pleasantEvent: return "今、いちばん印象に残る楽しい出来事について"
        case .caffeine: return "コーヒー・お茶・エナジードリンクなど"
        case .alcohol: return "最後に飲んだ時期と量を、だいたいで選択"
        case .tobacco: return "紙巻き・加熱式など、最後に使った時期と量"
        case .note: return "そのまま保存できます。声での補足は任意です"
        default: return "近いものをひとつ選んでください"
        }
    }
}

struct Choice: Identifiable {
    let id: String
    let label: String
    let value: Double?
    init(_ id: String, _ label: String, _ value: Double? = nil) {
        self.id = id; self.label = label; self.value = value
    }
}

struct Answer: Codable, Equatable {
    var code: String
    var label: String
    var value: Double?
    var amount: Int?
    var calendarDate: String?
    var dayRange: DayRange?
    var rangeReferenceDate: String?
    var inheritedFrom: UUID?
    var reviewLabel: String { label + (inheritedFrom == nil ? "" : "（引継ぎ）") }
    init(_ choice: Choice, amount: Int? = nil) {
        code = choice.id; label = choice.label; value = choice.value; self.amount = amount
    }
}

enum Choices {
    static let recency = ApproximateDates.choices(future: false).map {
        Choice($0.id, $0.label, $0.range.lower == $0.range.upper ? Double($0.range.lower) : nil)
    }
    static let conversationAmounts = ["一言二言", "しばらく", "長時間"]
    static func matrix(day: Choice, amount: Int, suffix: String, on date: Date = Date()) -> Answer {
        var answer = ApproximateDates.choices(future: false).first { $0.id == day.id }!.answer(on: date)
        answer.code += "_\(amount)"; answer.amount = amount; answer.label += "・" + suffix
        return answer
    }
    static func conversation(day: Choice, amount: Int, on date: Date = Date()) -> Answer {
        matrix(day: day, amount: amount, suffix: conversationAmounts[amount], on: date)
    }
    static let intensities = ["少し", "かなり", "とても"]
    static func event(day: Choice, intensity: Int, pleasant: Bool = false) -> Answer {
        let feeling = pleasant ? "楽しかった" : "つらかった"
        return matrix(day: day, amount: intensity, suffix: intensities[intensity] + feeling)
    }
    static let amounts = ["少し", "1食分", "多め"]
    static let substanceAmounts = ["少し", "中くらい", "多め"]
    static func substance(day: Choice, amount: Int) -> Answer {
        matrix(day: day, amount: amount, suffix: substanceAmounts[amount])
    }
    static func forQuestion(_ question: Question) -> [Choice] {
        switch question {
        case .mood: return ["悪い", "やや悪い", "普通", "やや良い", "良い"].enumerated().reversed().map { Choice("mood\($0.offset + 1)", $0.element, Double($0.offset + 1)) }
        case .energy: return ["ない", "少ない", "普通", "ある", "十分ある"].enumerated().reversed().map { Choice("energy\($0.offset + 1)", $0.element, Double($0.offset + 1)) }
        case .hunger: return ["空腹ではない", "少し空腹", "空腹", "かなり空腹", "とても空腹"].enumerated().map { Choice("hunger\($0.offset + 1)", $0.element, Double($0.offset + 1)) }
        case .sleepStart, .sleepEnd:
            return (0..<48).map { n in Choice("clock\(n * 30)", SleepClock.timeLabel(n * 30), Double(n * 30)) }
        case .lastObligation: return [Choice("inProgress", "今やっている")] + recency + [Choice("noObligation", "特にない")]
        case .nextObligation: return ApproximateDates.choices(future: true).map { Choice($0.id, $0.label) } + [Choice("unscheduled", "未定"), Choice("none", "予定なし")]
        case .backlog: return ["なし", "少し", "そこそこ", "多い", "とても多い"].enumerated().map { Choice("backlog\($0.offset)", $0.element, Double($0.offset)) }
        case .exercise: return recency
        case .lastWork: return [Choice("working", "勤務中", 0)] + recency + [Choice("noWork", "仕事をしていない")]
        case .nextWork: return [Choice("later", "このあと", 0), Choice("tomorrow", "明日", 1), Choice("two", "2日後", 2), Choice("threePlus", "3日後以降", 3), Choice("unscheduled", "未定"), Choice("none", "予定なし")]
        case .conversation: return recency
        default: return []
        }
    }
    static func nutrition(day: Choice, amount: Int) -> Answer {
        matrix(day: day, amount: amount, suffix: amounts[amount])
    }
}

enum SleepClock {
    static func timeLabel(_ minutes: Int) -> String { String(format: "%d:%02d", minutes / 60, minutes % 60) }
    static func duration(start: Int, end: Int) -> Int? {
        guard (0..<1440).contains(start), (0..<1440).contains(end), start != end else { return nil }
        return (end - start + 1440) % 1440
    }
    static func durationLabel(_ minutes: Int) -> String {
        if minutes % 60 == 0 { return "\(minutes / 60)時間" }
        if minutes < 60 { return "\(minutes)分" }
        return "\(minutes / 60)時間\(minutes % 60)分"
    }
}

struct LogRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var date = Date()
    var answers: [String: Answer] = [:]
    var note = ""
    var noteUsesHiragana: Bool?
    var customAnswers: [String: CustomResponse]?
    var clearedSteps: [String]?
    mutating func markCleared(_ id: String, cleared: Bool) {
        var ids = Set(clearedSteps ?? [])
        if cleared { ids.insert(id) } else { ids.remove(id) }
        clearedSteps = ids.isEmpty ? nil : ids.sorted()
    }
    var displayedNote: String { noteUsesHiragana == true ? NoteText.hiragana(note) : note }
    subscript(_ question: Question) -> Answer? {
        get { answers[String(question.rawValue)] }
        set { answers[String(question.rawValue)] = newValue }
    }
    // Selecting a new bedtime invalidates the old wake time and derived duration.
    mutating func setSleep(_ answer: Answer?, for question: Question) -> Bool {
        guard question.isClock else { return false }
        if question == .sleepStart {
            self[.sleepStart] = answer; self[.sleepEnd] = nil; self[.sleep] = nil
            if answer?.code == "noSleep" { self[.sleep] = Answer(Choice("noSleep", "寝ていない", 0)) }
            return true
        }
        if let start = self[.sleepStart]?.value, let end = answer?.value {
            guard let minutes = SleepClock.duration(start: Int(start), end: Int(end)) else { return false }
            self[.sleepEnd] = answer
            self[.sleep] = Answer(Choice("clockDuration", SleepClock.durationLabel(minutes), Double(minutes) / 60))
        } else {
            self[.sleepEnd] = answer; self[.sleep] = nil
        }
        return true
    }
    // Recompute elapsed days at save time if a draft crosses midnight.
    mutating func refreshCalendarAnswers(at now: Date, calendar: Calendar = CalendarSelection.calendar, questions: [Question] = Question.allCases) -> Bool {
        var updated = self
        for question in questions where question.isRecency {
            if let answer = self[question], answer.dayRange != nil {
                guard let refreshed = ApproximateDates.refreshed(answer, now: now, future: question.isFuture, calendar: calendar) else { return false }
                updated[question] = refreshed
                continue
            }
            guard let key = self[question]?.calendarDate else { continue }
            guard let date = CalendarSelection.date(key, calendar: calendar),
                  let answer = CalendarSelection.answer(date, now: now, future: question.isFuture, calendar: calendar) else { return false }
            updated[question] = answer
        }
        for (key, response) in customAnswers ?? [:] where response.item.kind == .recency && response.answer.dayRange != nil {
            guard let answer = ApproximateDates.refreshed(response.answer, now: now, future: false, calendar: calendar) else { return false }
            updated.customAnswers?[key]?.answer = answer
        }
        self = updated
        return true
    }
    var sleepHistoryLabel: String {
        if self[.sleepStart]?.value != nil || self[.sleepEnd]?.value != nil {
            let times = "\(self[.sleepStart]?.label ?? "—")→\(self[.sleepEnd]?.label ?? "—")"
            return times + ((self[.sleep]?.label).map { "（\($0)）" } ?? "")
        }
        return self[.sleep]?.label ?? "—"
    }
}

struct DiskRepository {
    let url: URL
    func read() throws -> [LogRecord] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([LogRecord].self, from: Data(contentsOf: url))
    }
    func write(_ records: [LogRecord]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(records)
        try data.write(to: url, options: .atomic)
    }
}

enum Statistics {
    // Compare the actual response categories, without treating a scale as days ago.
    static func choiceSummary(_ records: [LogRecord], outcome: Question, factor: Question, calendar: Calendar = .current) -> [GroupSummary] {
        Choices.forQuestion(factor).map { choice in
            var daily: [Date: [Double]] = [:]
            for record in records {
                guard record[factor]?.code == choice.id, let score = record[outcome]?.value else { continue }
                daily[calendar.startOfDay(for: record.date), default: []].append(score)
            }
            let means = daily.values.map { $0.reduce(0, +) / Double($0.count) }
            return GroupSummary(id: choice.id, label: choice.label, mean: means.isEmpty ? nil : means.reduce(0, +) / Double(means.count), days: means.count)
        }
    }

    // One daily average per group prevents many check-ins on one day dominating a comparison.
    static func summary(_ records: [LogRecord], outcome: Question, factor: Question, recent: Bool, calendar: Calendar = .current) -> (mean: Double?, days: Int) {
        var daily: [Date: [Double]] = [:]
        for record in records {
            guard let score = record[outcome]?.value, let answer = record[factor] else { continue }
            let isRecent: Bool
            if let range = answer.dayRange {
                if let upper = range.upper, upper <= 1 { isRecent = true }
                else if range.lower >= 2 { isRecent = false }
                else { continue }
            } else { switch factor {
            case .hunger, .backlog: continue // Use choiceSummary for this current-state scale.
            case .sleep:
                if answer.code == "over12" { isRecent = true }
                else if let value = answer.value { isRecent = value >= 7 }
                else { continue }
            case .difficultEvent, .salientDifficultEvent, .pleasantEvent:
                if answer.code == "none" { isRecent = false }
                else if let value = answer.value { isRecent = value <= 1 }
                else { continue }
            case .conversation:
                // v1 "yes" means today, but "no" gives no evidence of the last conversation.
                if answer.code == "yes" { isRecent = true }
                else if answer.code == "no" { continue }
                else if let value = answer.value { isRecent = value <= 1 }
                else { continue }
            default:
                guard let value = answer.value else { continue }
                isRecent = value <= 1
            }
            }
            guard isRecent == recent else { continue }
            daily[calendar.startOfDay(for: record.date), default: []].append(score)
        }
        let means = daily.values.map { $0.reduce(0, +) / Double($0.count) }
        return (means.isEmpty ? nil : means.reduce(0, +) / Double(means.count), means.count)
    }
}
