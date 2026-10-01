import Foundation

struct TimelineRow: Identifiable {
    let id: String
    let title: String
    let question: Question?
    let customID: UUID?
    func answer(in record: LogRecord) -> Answer? {
        if let question { return record[question] }
        if let customID { return record.customAnswers?[customID.uuidString]?.answer }
        return nil
    }
    func compactLabel(in record: LogRecord) -> String {
        guard let answer = answer(in: record) else { return "—" }
        if question == .hunger, let value = answer.value, (1...5).contains(Int(value)) {
            return ["なし", "少し", "空腹", "かなり", "とても"][Int(value) - 1]
        }
        if let range = answer.dayRange {
            let label: String
            if range.lower == 0 && range.upper == 0 { label = "今日" }
            else if range.lower == 1 && range.upper == 1 { label = question?.isFuture == true ? "明日" : "昨日" }
            else if range.lower == 2 && range.upper == 2 { label = question?.isFuture == true ? "2日後" : "2日前" }
            else if range.lower == 3 && range.upper == 6 { label = "3–6日" }
            else if range.lower == 7 && range.upper == 14 { label = "1–2週" }
            else if range.lower >= 15 && range.upper == nil { label = question?.isFuture == true ? "もっと先" : "もっと前" }
            else { label = String(answer.label.split(separator: "・").first ?? "") }
            if let amount = answer.amount, (0..<3).contains(amount) {
                let amounts = question?.isSubstance == true ? Choices.substanceAmounts : question == .conversation ? Choices.conversationAmounts : question?.isEvent == true ? ["少し", "かなり", "とても"] : ["少し", "1食", "多め"]
                return label + "\n" + amounts[amount]
            }
            return label
        }
        if let key = answer.calendarDate, let date = CalendarSelection.date(key) {
            let parts = CalendarSelection.calendar.dateComponents([.month, .day], from: date)
            return "\(parts.month!)/\(parts.day!)"
        }
        if question == .sleep, let hours = answer.value { return String(format: "%gh", hours) }
        let days = ["today": "今日", "yesterday": "昨日", "two": "2日前", "three": "3日前", "fourToSix": "4–6日", "weekPlus": "7日+", "working": "勤務中", "later": "後で", "tomorrow": "明日", "threePlus": "3日+", "none": "なし", "noWork": "なし", "unscheduled": "未定", "never": "なし"]
        if let question, (question == .iron || question == .b12 || question.isEvent), let amount = answer.amount {
            let base = String(answer.code.split(separator: "_").first ?? "")
            let amounts = question.isEvent ? ["少し", "かなり", "とても"] : ["少し", "1食", "多め"]
            if let day = days[base], amounts.indices.contains(amount) { return day + "\n" + amounts[amount] }
        }
        if question?.isFuture == true, answer.code == "two" { return "2日後" }
        if question?.isFuture == true, answer.code == "threePlus" { return "3日後+" }
        if let label = days[answer.code] { return label }
        return answer.label
    }
}

enum TimelineModel {
    static let pageSize = 7
    static func window(_ records: [LogRecord], page: Int) -> [LogRecord] {
        let sorted = records.sorted { $0.date > $1.date }
        return Array(sorted.dropFirst(max(0, page) * pageSize).prefix(pageSize).reversed())
    }
    static func rows(customItems: [CustomItem], records: [LogRecord]) -> [TimelineRow] {
        let questions: [Question] = [.hunger, .sleep, .iron, .b12, .exercise, .lastObligation, .nextObligation, .backlog, .conversation, .salientDifficultEvent, .pleasantEvent] + Question.substances.filter { question in records.contains { $0[question] != nil } }
        let legacy = [Question.lastWork, .nextWork].filter { question in records.contains { $0[question] != nil } }
        var rows = (questions + legacy).map { TimelineRow(id: "builtin-\($0.rawValue)", title: $0.short, question: $0, customID: nil) }
        var seen = Set<UUID>()
        let snapshots = records.flatMap { ($0.customAnswers ?? [:]).values.map(\.item) }.sorted { $0.title < $1.title }
        for item in customItems + snapshots where seen.insert(item.id).inserted {
            rows.append(TimelineRow(id: item.id.uuidString, title: item.title, question: nil, customID: item.id))
        }
        return rows
    }
}
