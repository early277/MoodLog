import SwiftUI

@MainActor final class Store: ObservableObject {
    @Published private(set) var records: [LogRecord] = []
    @Published var error: String?
    @Published private(set) var customItems: [CustomItem] = []
    @Published private(set) var hiddenSubstances: Set<Question> = []
    private var customReadable = true
    @Published var draft: LogRecord { didSet { persistDraft() } }
    @Published var step: Int { didSet { persistDraft() } }
    private let repository: DiskRepository
    private let defaults: UserDefaults
    private var readable = true
    init() {
        let testing = ProcessInfo.processInfo.arguments.contains("--uitesting")
        defaults = testing ? UserDefaults(suiteName: "MoodLogUITests")! : .standard
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        repository = DiskRepository(url: base.appendingPathComponent(testing ? "MoodLogUITests/records.json" : "MoodLog/records.json"))
        if testing && ProcessInfo.processInfo.arguments.contains("--reset-test-data") {
            defaults.removePersistentDomain(forName: "MoodLogUITests")
            try? FileManager.default.removeItem(at: repository.url)
        }
        draft = defaults.data(forKey: "draft").flatMap { try? JSONDecoder().decode(LogRecord.self, from: $0) } ?? LogRecord()
        if let data = defaults.data(forKey: "customItems") {
            do { customItems = try JSONDecoder().decode([CustomItem].self, from: data) }
            catch { customReadable = false }
        }
        hiddenSubstances = Set((defaults.array(forKey: "hiddenSubstances") as? [Int] ?? []).compactMap(Question.init(rawValue:)).filter(\.isSubstance))
        step = Question.restoredStep(defaults.integer(forKey: "step"), version: defaults.integer(forKey: "flowVersion"))
        if let savedID = defaults.string(forKey: "stepID") {
            let replacements = [RecordingStep.builtin(.lastWork).id: RecordingStep.builtin(.lastObligation).id, RecordingStep.builtin(.nextWork).id: RecordingStep.builtin(.nextObligation).id]
            let target = replacements[savedID] ?? savedID
            if let index = flow.firstIndex(where: { $0.id == target }) { step = index }
        }
        if draft.noteUsesHiragana == nil && draft.note.isEmpty { draft.noteUsesHiragana = true }
        defaults.set(step, forKey: "step")
        defaults.set(Question.flowVersion, forKey: "flowVersion")
        do { records = try repository.read().sorted { $0.date > $1.date } }
        catch { readable = false; self.error = "保存済みの記録を読み込めませんでした。元のデータは保持しています。" }
    }
    var flow: [RecordingStep] {
        Question.flow.dropLast().filter { !hiddenSubstances.contains($0) }.map { .builtin($0) } + customItems.filter(\.enabled).map { .custom($0) } + [.builtin(.note)]
    }
    var currentStep: RecordingStep { flow[min(max(step, 0), flow.count - 1)] }
    var currentCustomItem: CustomItem? { if case .custom(let item) = currentStep { return item }; return nil }
    var isNote: Bool { currentCustomItem == nil && question == .note }
    func addCustomItem(_ item: CustomItem) -> Bool {
        if let message = CustomItem.validation(title: item.title, kind: item.kind, options: item.options) { error = message; return false }
        return updateCustomItems(customItems + [item])
    }
    func setCustomItem(_ id: UUID, enabled: Bool) {
        var updated = customItems
        if let index = updated.firstIndex(where: { $0.id == id }) { updated[index].enabled = enabled; _ = updateCustomItems(updated) }
    }
    func setSubstance(_ question: Question, visible: Bool) {
        guard question.isSubstance else { return }
        let currentID = currentStep.id
        if visible { hiddenSubstances.remove(question) } else { hiddenSubstances.insert(question) }
        defaults.set(hiddenSubstances.map(\.rawValue).sorted(), forKey: "hiddenSubstances")
        if visible && draft[question]?.code == "notUsed" { draft[question] = nil }
        step = flow.firstIndex(where: { $0.id == currentID }) ?? min(step, flow.count - 1)
    }
    func deleteCustomItem(_ id: UUID) {
        guard updateCustomItems(customItems.filter { $0.id != id }) else { return }
        draft.customAnswers?[id.uuidString] = nil
        draft.markCleared("custom-\(id.uuidString)", cleared: false)
    }
    var canClearCurrentAnswer: Bool {
        if let item = currentCustomItem { return draft.customAnswers?[item.id.uuidString] != nil || carryPreview != nil }
        if isNote { return !draft.note.isEmpty }
        return draft[question] != nil || carryPreview != nil
    }
    func clearCurrentAnswer() {
        let id = currentStep.id
        if let item = currentCustomItem { draft.customAnswers?[item.id.uuidString] = nil }
        else if isNote { draft.note = "" }
        else if question.isClock { _ = draft.setSleep(nil, for: question) }
        else { draft[question] = nil }
        draft.markCleared(id, cleared: true)
    }
    private func updateCustomItems(_ updated: [CustomItem]) -> Bool {
        guard customReadable else { error = "追加項目を読み込めないため、元のデータを保持しています。"; return false }
        let currentID = currentStep.id
        do {
            let data = try JSONEncoder().encode(updated)
            defaults.set(data, forKey: "customItems")
            customItems = updated
            step = flow.firstIndex(where: { $0.id == currentID }) ?? min(step, flow.count - 1)
            return true
        } catch { self.error = "項目を保存できませんでした。"; return false }
    }
    private func persistDraft() {
        if let data = try? JSONEncoder().encode(draft) { defaults.set(data, forKey: "draft") }
        defaults.set(step, forKey: "step")
        defaults.set(currentStep.id, forKey: "stepID")
        defaults.set(Question.flowVersion, forKey: "flowVersion")
    }
    var question: Question { if case .builtin(let question) = currentStep { return question }; return .note }
    @discardableResult func answer(_ answer: Answer?) -> Bool {
        if answer != nil { draft.markCleared(currentStep.id, cleared: false) }
        if let item = currentCustomItem {
            var answers = draft.customAnswers ?? [:]
            let dated = answer.map { value in
                item.kind == .recency ? (AnswerCarryForward.normalized(value, recordedAt: Date(), now: Date()) ?? value) : value
            }
            answers[item.id.uuidString] = dated.map { CustomResponse(item: item, answer: $0) }
            draft.customAnswers = answers
            step = min(step + 1, flow.count - 1)
            return true
        }
        guard question != .note else { return false }
        let current = question
        if current.isSubstance && answer?.code == "notUsed" {
            draft[current] = answer
            setSubstance(current, visible: false)
            return true
        }
        if current.isClock {
            guard draft.setSleep(answer, for: current) else {
                error = "寝た時刻と起きた時刻が同じです。時刻を選び直すか、分からない場合はスキップしてください。"
                return false
            }
        } else { draft[current] = answer }
        if current == .lastObligation && answer?.code == "inProgress" {
            draft[.nextObligation] = nil
            draft.markCleared(RecordingStep.builtin(.nextObligation).id, cleared: true)
            step += 2
            return true
        }
        step += current == .sleepStart && answer?.code == "noSleep" ? 2 : 1
        return true
    }
    var recordedToday: Date? {
        guard ![Question.mood, .energy, .hunger, .backlog, .difficultEvent, .salientDifficultEvent, .pleasantEvent, .note].contains(question) || currentCustomItem != nil else { return nil }
        return records.first { record in
            guard Calendar.current.isDateInToday(record.date) else { return false }
            if let item = currentCustomItem { return record.customAnswers?[item.id.uuidString] != nil }
            return record[question] != nil
        }?.date
    }
    func goBack() {
        if question == .backlog && draft[.lastObligation]?.code == "inProgress" { step -= 2 }
        else if question == .iron && draft[.sleepStart]?.code == "noSleep" { step -= 2 }
        else { step = max(0, step - 1) }
    }
    func goToFirst() {
        step = 0
    }
    var carryPreview: Answer? {
        guard !(draft.clearedSteps ?? []).contains(currentStep.id) else { return nil }
        if let item = currentCustomItem { return AnswerCarryForward.customAnswer(for: item, records: records, now: Date()) }
        return AnswerCarryForward.answer(for: question, records: records, now: Date())
    }
    func save() -> Bool {
        guard readable else { error = "既存データを保護するため保存できません。"; return false }
        var record = draft
        record.date = Date()
        guard record.refreshCalendarAnswers(at: record.date, questions: Question.flow) else {
            error = "選択した時期を確認してください。次の用事が過去になっている場合は、選び直すかスキップしてください。"
            if let index = flow.firstIndex(where: { $0.id == RecordingStep.builtin(.nextObligation).id }) { step = index }
            return false
        }
        record = AnswerCarryForward.filling(record, from: records, customItems: customItems, excluding: hiddenSubstances)
        guard !(record.clearedSteps ?? []).isEmpty || !record.answers.isEmpty || !(record.customAnswers ?? [:]).isEmpty || !record.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = "ひとつ回答してから記録してください。"; return false
        }
        let updated = [record] + records
        do {
            try repository.write(updated)
            records = updated; draft = LogRecord(); draft.noteUsesHiragana = true; step = 0
            return true
        } catch { self.error = "保存できませんでした。入力は残っています。"; return false }
    }
    func delete(_ id: UUID) {
        let updated = records.filter { $0.id != id }
        do { try repository.write(updated); records = updated }
        catch { self.error = "削除できませんでした。" }
    }
    @discardableResult func update(_ record: LogRecord) -> Bool {
        guard readable else { error = "既存データを保護するため保存できません。"; return false }
        guard let index = records.firstIndex(where: { $0.id == record.id }) else {
            error = "修正する記録が見つかりませんでした。"; return false
        }
        let original = records[index]
        var replacement = record
        // Editing an answer never changes when the check-in happened or its identity.
        replacement.id = original.id; replacement.date = original.date
        if replacement[.sleepStart] != original[.sleepStart] || replacement[.sleepEnd] != original[.sleepEnd] {
            let start = replacement[.sleepStart], end = replacement[.sleepEnd]
            _ = replacement.setSleep(start, for: .sleepStart)
            if start?.code != "noSleep", !replacement.setSleep(end, for: .sleepEnd) {
                error = "寝た時刻と起きた時刻が同じです。時刻を選び直してください。"; return false
            }
        }
        guard replacement != original else { return true }
        var updated = records
        updated[index] = replacement
        do {
            // Do not fill missing answers from other records while editing history.
            try repository.write(updated)
            records = updated
            return true
        } catch { self.error = "修正を保存できませんでした。入力は残っています。"; return false }
    }
    func export() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("気分ログ.json")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(records).write(to: url, options: .atomic)
        return url
    }
}
