import Foundation

struct ComparisonGroup: Identifiable {
    let id: String
    let label: String
    let mood: GroupSummary
    let energy: GroupSummary
}

enum ComparisonModel {
    static func groups(records: [LogRecord], factor: Question, amount: Int? = nil, calendar: Calendar = .current) -> [ComparisonGroup] {
        if let amount, !(0...2).contains(amount) { return [] }
        let filtered = amount.map { value in records.filter { $0[factor]?.amount == value } } ?? records
        if factor.isCurrentScale {
            return paired(Statistics.choiceSummary(filtered, outcome: .mood, factor: factor, calendar: calendar),
                          Statistics.choiceSummary(filtered, outcome: .energy, factor: factor, calendar: calendar))
        }
        if factor == .sleep {
            return [("under7", "7時間未満"), ("sevenPlus", "7時間以上")].map { id, label in
                group(id: id, label: label, records: filtered, calendar: calendar) { record in
                    guard let answer = record[.sleep] else { return false }
                    let enough: Bool
                    if answer.code == "over12" { enough = true }
                    else if answer.code == "noSleep" { enough = false }
                    else if let hours = answer.value, hours.isFinite, hours >= 0 { enough = hours >= 7 }
                    else { return false }
                    return enough == (id == "sevenPlus")
                }
            }
        }
        guard factor.isRecency else { return [] }
        let buckets = ApproximateDates.choices(future: factor.isFuture)
        var result = buckets.map { bucket in
            group(id: bucket.id, label: bucket.label, records: filtered, calendar: calendar) { record in
                guard let answer = record[factor],
                      let range = AnswerCarryForward.normalized(answer, recordedAt: record.date, now: record.date, future: factor.isFuture, calendar: calendar)?.dayRange else { return false }
                return contains(range, in: bucket.range)
            }
        }
        // These are actual answers, rather than invented dates for undated states.
        let specialCodes = ["inProgress", "working", "noObligation", "noWork", "none", "unscheduled", "notUsed", "never", "no"]
        for code in specialCodes {
            guard let answer = filtered.compactMap({ $0[factor] }).first(where: { $0.code == code && $0.dayRange == nil && $0.calendarDate == nil }) else { continue }
            result.append(group(id: code, label: answer.label, records: filtered, calendar: calendar) {
                $0[factor]?.code == code && $0[factor]?.dayRange == nil && $0[factor]?.calendarDate == nil
            })
        }
        return result
    }

    static func groups(records: [LogRecord], item: CustomItem, calendar: Calendar = .current) -> [ComparisonGroup] {
        guard item.kind == .recency else {
            return paired(Statistics.customSummary(records, outcome: .mood, item: item, calendar: calendar),
                          Statistics.customSummary(records, outcome: .energy, item: item, calendar: calendar))
        }
        return item.choices.map { choice in
            group(id: choice.id, label: choice.label, records: records, calendar: calendar) { record in
                guard let answer = record.customAnswers?[item.id.uuidString]?.answer else { return false }
                if choice.id == "never" {
                    return answer.code == choice.id && answer.dayRange == nil && answer.calendarDate == nil
                }
                guard let bucket = ApproximateDates.choices(future: false).first(where: { $0.id == choice.id }),
                      let range = AnswerCarryForward.normalized(answer, recordedAt: record.date, now: record.date, calendar: calendar)?.dayRange else { return false }
                return contains(range, in: bucket.range)
            }
        }
    }

    private static func contains(_ range: DayRange, in bucket: DayRange) -> Bool {
        guard range.lower >= 0, range.upper.map({ $0 >= range.lower }) ?? true,
              range.lower >= bucket.lower else { return false }
        guard let upper = bucket.upper else { return true }
        return range.upper.map { $0 <= upper } ?? false
    }

    private static func paired(_ moods: [GroupSummary], _ energies: [GroupSummary]) -> [ComparisonGroup] {
        moods.compactMap { mood in
            guard let energy = energies.first(where: { $0.id == mood.id }) else { return nil }
            return ComparisonGroup(id: mood.id, label: mood.label, mood: mood, energy: energy)
        }
    }

    private static func group(id: String, label: String, records: [LogRecord], calendar: Calendar, matches: (LogRecord) -> Bool) -> ComparisonGroup {
        let matched = records.filter(matches)
        func summary(_ outcome: Question) -> GroupSummary {
            var daily: [Date: [Double]] = [:]
            for record in matched {
                guard let value = record[outcome]?.value, value.isFinite else { continue }
                daily[calendar.startOfDay(for: record.date), default: []].append(value)
            }
            let means = daily.values.map { $0.reduce(0, +) / Double($0.count) }
            return GroupSummary(id: id, label: label, mean: means.isEmpty ? nil : means.reduce(0, +) / Double(means.count), days: means.count)
        }
        return ComparisonGroup(id: id, label: label, mood: summary(.mood), energy: summary(.energy))
    }
}
