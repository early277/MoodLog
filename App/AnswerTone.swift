import Foundation

// Shade encodes the recorded amount or distance in time. It does not judge
// whether an answer is good, bad, or a cause of the person's mood.
enum AnswerShade {
    static let neutralOpacity = 0.08
    static let absentOpacity = 0.03
    private static let strongestOpacity = 0.34

    static func opacity(of answer: Answer?, question: Question?, customKind: CustomItem.Kind? = nil,
                        recordedAt: Date, calendar: Calendar = CalendarSelection.calendar) -> Double {
        guard let answer else { return 0 }
        if ["none", "notUsed", "noObligation", "noWork", "never", "no", "noSleep"].contains(answer.code) {
            return absentOpacity
        }
        if ["inProgress", "working"].contains(answer.code) { return strongestOpacity }
        if answer.code == "unscheduled" { return neutralOpacity }

        // A combined date/amount answer has one visual scale: amount. Its date
        // remains written in the cell instead of being mixed into a new score.
        if let amount = answer.amount {
            guard (0...2).contains(amount) else { return neutralOpacity }
            return [0.08, 0.21, strongestOpacity][amount]
        }
        if question == .hunger || question == .backlog {
            let lower = question == .hunger ? 1.0 : 0.0
            guard let value = answer.value, value.isFinite, (lower...(lower + 4)).contains(value) else { return neutralOpacity }
            if value == lower { return absentOpacity }
            return scaled(value - lower, maximum: 4)
        }
        if question == .mood || question == .energy || customKind == .scale {
            guard let value = answer.value, value.isFinite, (1...5).contains(value) else { return neutralOpacity }
            return scaled(value - 1, maximum: 4)
        }
        if customKind == .yesNo {
            return answer.code == "yes" ? strongestOpacity : neutralOpacity
        }
        if question?.isRecency == true || customKind == .recency {
            guard let range = AnswerCarryForward.normalized(answer, recordedAt: recordedAt, now: recordedAt,
                                                          future: question?.isFuture == true, calendar: calendar)?.dayRange,
                  range.lower >= 0, range.upper.map({ $0 >= range.lower }) ?? true else { return neutralOpacity }
            let buckets = ApproximateDates.choices(future: question?.isFuture == true)
            guard let index = buckets.firstIndex(where: { bucket in
                guard range.lower >= bucket.range.lower else { return false }
                guard let upper = bucket.range.upper else { return true }
                return range.upper.map { $0 <= upper } ?? false
            }) else { return neutralOpacity }
            return [strongestOpacity, 0.29, 0.24, 0.18, 0.13, 0.08][index]
        }
        // Sleep hours and user-created options have no shared amount scale.
        return neutralOpacity
    }

    private static func scaled(_ value: Double, maximum: Double) -> Double {
        neutralOpacity + (strongestOpacity - neutralOpacity) * value / maximum
    }
}
