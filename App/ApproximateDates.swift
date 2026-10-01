import Foundation

struct DayRange: Codable, Equatable {
    var lower: Int
    var upper: Int?
}

struct DateRangeChoice: Identifiable {
    let id: String
    let label: String
    let range: DayRange
    func answer(on date: Date, calendar: Calendar = CalendarSelection.calendar) -> Answer {
        var answer = Answer(Choice(id, label))
        answer.dayRange = range
        answer.rangeReferenceDate = CalendarSelection.key(date, calendar: calendar)
        return answer
    }
    func dateLabel(on date: Date, future: Bool, calendar: Calendar = CalendarSelection.calendar) -> String {
        func label(_ days: Int) -> String {
            let day = calendar.date(byAdding: .day, value: future ? days : -days, to: date)!
            return "\(calendar.component(.month, from: day))/\(calendar.component(.day, from: day))"
        }
        guard let upper = range.upper else { return label(range.lower) + (future ? "以降" : "以前") }
        if upper == range.lower { return label(range.lower) }
        return future ? "\(label(range.lower))〜\(label(upper))" : "\(label(upper))〜\(label(range.lower))"
    }
}

enum ApproximateDates {
    static func choices(future: Bool) -> [DateRangeChoice] {
        let labels = future ? ["今日", "明日", "2日後", "3〜6日後", "1〜2週間後", "もっと先"] : ["今日", "昨日", "2日前", "3〜6日前", "1〜2週間前", "もっと前"]
        let ids = future ? ["today", "tomorrow", "two", "threeToSix", "weekToTwo", "older"] : ["today", "yesterday", "two", "threeToSix", "weekToTwo", "older"]
        let ranges = [DayRange(lower: 0, upper: 0), DayRange(lower: 1, upper: 1), DayRange(lower: 2, upper: 2), DayRange(lower: 3, upper: 6), DayRange(lower: 7, upper: 14), DayRange(lower: 15, upper: nil)]
        return ranges.enumerated().map { DateRangeChoice(id: ids[$0.offset], label: labels[$0.offset], range: $0.element) }
    }
    static func group(for date: Date, now: Date, future: Bool, calendar: Calendar = CalendarSelection.calendar) -> Int? {
        let delta = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day!
        let days = future ? delta : -delta
        return choices(future: future).firstIndex { days >= $0.range.lower && ($0.range.upper.map { days <= $0 } ?? true) }
    }
    // Three consecutive weeks across month boundaries. Dates are a reference, not controls.
    static func visibleDates(now: Date, future: Bool, calendar: Calendar = CalendarSelection.calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let sunday = calendar.date(byAdding: .day, value: 1 - calendar.component(.weekday, from: today), to: today)!
        let start = calendar.date(byAdding: .day, value: future ? 0 : -14, to: sunday)!
        return (0..<21).map { calendar.date(byAdding: .day, value: $0, to: start)! }
    }
    static func refreshed(_ answer: Answer, now: Date, future: Bool, calendar: Calendar = CalendarSelection.calendar) -> Answer? {
        guard var range = answer.dayRange, let key = answer.rangeReferenceDate, let reference = CalendarSelection.date(key, calendar: calendar) else { return nil }
        let elapsed = calendar.dateComponents([.day], from: reference, to: calendar.startOfDay(for: now)).day!
        let shift = future ? -elapsed : elapsed
        range.lower += shift; range.upper = range.upper.map { $0 + shift }
        guard range.lower >= 0 else { return nil }
        var updated = answer
        updated.dayRange = range; updated.rangeReferenceDate = CalendarSelection.key(now, calendar: calendar)
        let detail = answer.label.split(separator: "・", maxSplits: 1).dropFirst().first.map { "・" + $0 } ?? ""
        let choice = choices(future: future).first { $0.range == range }
        let suffix = future ? "日後" : "日前"
        let label: String
        if let choice { label = choice.label }
        else if let upper = range.upper {
            label = range.lower == upper ? "\(range.lower)\(suffix)" : "\(range.lower)〜\(upper)\(suffix)"
        } else { label = "\(range.lower)\(suffix)" + (future ? "以降" : "以前") }
        updated.label = label + detail
        updated.code = (choice?.id ?? "elapsed\(range.lower)-\(range.upper.map(String.init) ?? "plus")") + (answer.amount.map { "_\($0)" } ?? "")
        updated.value = nil
        return updated
    }
}

enum ClockPeriods {
    static let names = ["夜", "朝", "昼"]
    static let labels = ["20〜翌3時", "4〜11時", "12〜19時"]
    static let starts = [20, 4, 12]
    static func hours(_ period: Int) -> [Int] { (0..<8).map { (starts[period] + $0) % 24 } }
    static func period(for minutes: Int) -> Int { ((minutes / 60 + 4) % 24) / 8 }
}

// Only elapsed-time answers can be carried. The newest explicit special answer
// acts as a barrier; older dated answers must not reappear behind it.
enum AnswerCarryForward {
    static func normalized(_ answer: Answer, recordedAt: Date, now: Date, future: Bool = false, calendar: Calendar = CalendarSelection.calendar) -> Answer? {
        var dated = answer
        if dated.dayRange == nil {
            let key = String(answer.code.split(separator: "_").first ?? "")
            if let dateKey = answer.calendarDate, let date = CalendarSelection.date(dateKey, calendar: calendar) {
                let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: recordedAt), to: date).day!
                let elapsed = future ? days : -days
                guard elapsed >= 0 else { return nil }
                dated.dayRange = DayRange(lower: elapsed, upper: elapsed)
            } else if let choice = ApproximateDates.choices(future: future).first(where: { $0.id == key }) {
                dated.dayRange = choice.range
            } else {
                switch key {
                case "three": dated.dayRange = DayRange(lower: 3, upper: 3)
                case "fourToSix": dated.dayRange = DayRange(lower: 4, upper: 6)
                case "weekPlus": dated.dayRange = DayRange(lower: 7, upper: nil)
                case "threePlus" where future: dated.dayRange = DayRange(lower: 3, upper: nil)
                case "later" where future: dated.dayRange = DayRange(lower: 0, upper: 0)
                case "yes" where !future: dated.dayRange = DayRange(lower: 0, upper: 0)
                default: return nil
                }
            }
            dated.calendarDate = nil; dated.value = nil
            dated.rangeReferenceDate = CalendarSelection.key(recordedAt, calendar: calendar)
        }
        return ApproximateDates.refreshed(dated, now: now, future: future, calendar: calendar)
    }

    static func answer(for question: Question, records: [LogRecord], now: Date, calendar: Calendar = CalendarSelection.calendar) -> Answer? {
        guard question.isRecency,
              let source = records.filter({ $0.date <= now && ($0[question] != nil || ($0.clearedSteps ?? []).contains(RecordingStep.builtin(question).id)) }).max(by: { $0.date < $1.date }),
              let original = source[question],
              var answer = normalized(original, recordedAt: source.date, now: now, future: question.isFuture, calendar: calendar) else { return nil }
        answer.inheritedFrom = answer.inheritedFrom ?? source.id
        return answer
    }

    static func customAnswer(for item: CustomItem, records: [LogRecord], now: Date, calendar: Calendar = CalendarSelection.calendar) -> Answer? {
        guard item.kind == .recency,
              let source = records.filter({ $0.date <= now && ($0.customAnswers?[item.id.uuidString] != nil || ($0.clearedSteps ?? []).contains(RecordingStep.custom(item).id)) }).max(by: { $0.date < $1.date }),
              let original = source.customAnswers?[item.id.uuidString]?.answer,
              var answer = normalized(original, recordedAt: source.date, now: now, calendar: calendar) else { return nil }
        answer.inheritedFrom = answer.inheritedFrom ?? source.id
        return answer
    }

    static func filling(_ record: LogRecord, from records: [LogRecord], customItems: [CustomItem] = [], excluding: Set<Question> = [], calendar: Calendar = CalendarSelection.calendar) -> LogRecord {
        var filled = record
        for question in Question.flow where question.isRecency && !excluding.contains(question) && filled[question] == nil && !(filled.clearedSteps ?? []).contains(RecordingStep.builtin(question).id) {
            filled[question] = answer(for: question, records: records, now: record.date, calendar: calendar)
        }
        for item in customItems where item.enabled && item.kind == .recency && filled.customAnswers?[item.id.uuidString] == nil && !(filled.clearedSteps ?? []).contains(RecordingStep.custom(item).id) {
            if let answer = customAnswer(for: item, records: records, now: record.date, calendar: calendar) {
                if filled.customAnswers == nil { filled.customAnswers = [:] }
                filled.customAnswers?[item.id.uuidString] = CustomResponse(item: item, answer: answer)
            }
        }
        return filled
    }
}

// Twelve hours, with one stop at each hour and each half-hour.
enum ClockDialSelection {
    static func step(x: Double, y: Double) -> Int {
        let angle = atan2(y, x) + .pi / 2
        return (Int((angle / (.pi / 12)).rounded()) % 24 + 24) % 24
    }
    static func defaultStart(for question: Question) -> Int { question == .sleepStart ? 18 * 60 : 3 * 60 }
    static func start(for question: Question, alternate: Bool) -> Int {
        (defaultStart(for: question) + (alternate ? 720 : 0)) % 1440
    }
    static func contains(_ minutes: Int, start: Int) -> Bool { (minutes - start + 1440) % 1440 < 720 }
    static func minutes(step: Int, start: Int) -> Int {
        (start + (step * 30 - start + 1440) % 720) % 1440
    }
    static func label(start: Int) -> String {
        let end = (start + 690) % 1440
        return SleepClock.timeLabel(start) + "〜" + (end < start ? "翌" : "") + SleepClock.timeLabel(end)
    }
}
