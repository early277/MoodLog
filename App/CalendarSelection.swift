import Foundation

enum CalendarSelection {
    static var calendar: Calendar { Calendar(identifier: .gregorian) }
    static func key(_ date: Date, calendar: Calendar = CalendarSelection.calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
    static func date(_ key: String, calendar: Calendar = CalendarSelection.calendar) -> Date? {
        let pieces = key.split(separator: "-").compactMap { Int($0) }
        guard pieces.count == 3, let value = calendar.date(from: DateComponents(year: pieces[0], month: pieces[1], day: pieces[2])), self.key(value, calendar: calendar) == key else { return nil }
        return value
    }
    static func answer(_ date: Date, now: Date, future: Bool, calendar: Calendar = CalendarSelection.calendar) -> Answer? {
        let today = calendar.startOfDay(for: now), selected = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: selected).day!
        guard future ? days >= 0 : days <= 0 else { return nil }
        let key = key(selected, calendar: calendar)
        let p = calendar.dateComponents([.year, .month, .day, .weekday], from: selected)
        let weekday = ["日", "月", "火", "水", "木", "金", "土"][p.weekday! - 1]
        var answer = Answer(Choice("date-\(key)", "\(p.year!)/\(p.month!)/\(p.day!)（\(weekday)）", Double(abs(days))))
        answer.calendarDate = key
        return answer
    }
    static func month(_ date: Date, calendar: Calendar = CalendarSelection.calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)!.start
    }
    // Sunday-first, fixed six weeks; empty adjacent-month cells keep dates aligned.
    static func cells(_ month: Date, calendar: Calendar = CalendarSelection.calendar) -> [Date?] {
        let first = self.month(month, calendar: calendar)
        let offset = calendar.component(.weekday, from: first) - 1
        let count = calendar.range(of: .day, in: .month, for: first)!.count
        return (0..<42).map { index in
            let day = index - offset
            return (0..<count).contains(day) ? calendar.date(byAdding: .day, value: day, to: first) : nil
        }
    }
}
