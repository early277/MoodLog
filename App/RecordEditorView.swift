import SwiftUI

// Historical answers are edited locally. The live recorder draft is never used.
struct RecordEditorView: View {
    @EnvironmentObject private var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speech = SpeechInput()
    @State private var edited: LogRecord
    @State private var steps: [RecordingStep] = []
    @State private var index = 0
    @State private var error: String?
    @State private var keyboard = false
    @State private var transitioning = false
    private let initialQuestion: Question?
    private let initialCustomID: UUID?

    init(record: LogRecord, initialQuestion: Question? = nil, initialCustomID: UUID? = nil) {
        _edited = State(initialValue: record)
        self.initialQuestion = initialQuestion
        self.initialCustomID = initialCustomID
    }

    private var current: RecordingStep { steps.isEmpty ? .builtin(.mood) : steps[min(index, steps.count - 1)] }
    private var question: Question { if case .builtin(let value) = current { return value }; return .note }
    private var customItem: CustomItem? { if case .custom(let item) = current { return item }; return nil }
    private var isNote: Bool { customItem == nil && question == .note }
    private var selected: Answer? {
        if let item = customItem { return edited.customAnswers?[item.id.uuidString]?.answer }
        return edited[question]
    }
    // Shared controls construct their display using today. Only their highlight gets
    // today's reference; choosing is re-anchored to this check-in before storage.
    private var displaySelection: Answer? {
        guard var answer = selected else { return nil }
        if answer.dayRange != nil { answer.rangeReferenceDate = CalendarSelection.key(Date()) }
        return answer
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(edited.date.formatted(.dateTime.year().month().day().hour().minute()))
                        Spacer()
                        Text("\(index + 1) / \(max(1, steps.count))")
                    }.font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
                    VStack(alignment: .leading, spacing: 6) {
                        Label(customItem?.title ?? (isNote ? "メモ" : question.title), systemImage: current.symbol)
                            .font(.system(size: geometry.size.height < 650 ? 22 : 25, weight: .semibold))
                            .foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("editQuestion")
                        if (customItem?.kind == .recency) || (customItem == nil && question.isRecency) {
                            Text("この記録の日から見た時期を選択")
                                .font(.system(size: 13)).foregroundStyle(Palette.muted)
                        } else if !isNote {
                            Text(customItem.map { $0.kind == .scale ? "1＝小さい・少ない、5＝大きい・多い" : "近いものをひとつ選んでください" } ?? question.hint)
                                .font(.system(size: 13)).foregroundStyle(Palette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }.frame(height: question.isClock ? 96 : 112, alignment: .top)
                    questionContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(current.id).allowsHitTesting(!transitioning)
                    HStack(spacing: 10) {
                        Button { speech.stop(); previous() } label: {
                            Label("戻る", systemImage: "chevron.left").frame(width: 94, height: 52)
                                .background(Palette.pale.opacity(0.6))
                        }.disabled(index == 0).accessibilityIdentifier("editBack")
                        Button { speech.stop(); next() } label: {
                            Label(index == steps.count - 1 ? "最初へ" : "次へ", systemImage: "chevron.right")
                                .frame(maxWidth: .infinity).frame(height: 52).background(.white)
                        }.accessibilityIdentifier("editNext")
                    }.font(.system(size: 16, weight: .semibold))
                }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
            }.background(Palette.background.ignoresSafeArea())
                .navigationTitle("記録を修正").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("取消") { speech.stop(); dismiss() }.accessibilityIdentifier("editCancel")
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button { speech.stop(); clear() } label: { Image(systemName: "eraser") }
                            .accessibilityLabel(isNote ? "メモを消す" : "回答を消す")
                            .disabled(isNote ? edited.note.isEmpty : selected == nil)
                            .accessibilityIdentifier("editClear")
                        Button("保存") {
                            speech.stop()
                            if store.update(edited) { dismiss() }
                            else { error = store.error; store.error = nil }
                        }.disabled(speech.recording || speech.busy).accessibilityIdentifier("editSave")
                    }
                }
                .onAppear { prepare() }
                .onDisappear { speech.stop() }
                .onChange(of: scenePhase) { _, phase in if phase == .background || (phase == .inactive && speech.recording) { speech.stop() } }
                .alert("お知らせ", isPresented: Binding(get: { error != nil || speech.error != nil }, set: { if !$0 { error = nil; speech.error = nil } })) {
                    Button("閉じる", role: .cancel) { error = nil; speech.error = nil }
                } message: { Text(error ?? speech.error ?? "") }
        }
    }

    private func prepare() {
        guard steps.isEmpty else { return }
        let builtin = Question.flow.dropLast().filter { !$0.isSubstance || !store.hiddenSubstances.contains($0) || edited[$0] != nil }
        let legacy = [Question.lastWork, .nextWork].filter { edited[$0] != nil }
        var seen = Set<UUID>()
        let snapshots = (edited.customAnswers ?? [:]).values.map(\.item).sorted { $0.title < $1.title }
        let items = (snapshots + store.customItems.filter(\.enabled)).filter { seen.insert($0.id).inserted }
        steps = (builtin + legacy).map { .builtin($0) } + items.map { .custom($0) } + [.builtin(.note)]
        let target: String?
        if let id = initialCustomID { target = RecordingStep.custom(CustomItem(id: id, title: "", kind: .scale)).id }
        else if let initialQuestion {
            var resolved = initialQuestion == .sleep ? Question.sleepStart : initialQuestion
            if resolved == .sleepEnd && edited[.sleepStart]?.code == "noSleep" { resolved = .sleepStart }
            if resolved == .nextObligation && edited[.lastObligation]?.code == "inProgress" { resolved = .lastObligation }
            target = RecordingStep.builtin(resolved).id
        } else { target = nil }
        if let target, let selectedIndex = steps.firstIndex(where: { $0.id == target }) { index = selectedIndex }
    }

    @ViewBuilder private var questionContent: some View {
        if let item = customItem {
            choices(item.choices)
        } else if question.isClock {
            ClockQuestionView(question: question, selected: edited[question], choose: choose)
        } else if question.isSubstance {
            // Hiding a question is a setting, not an effect of changing a historical answer.
            RecencyMatrixView(question: question, selected: displaySelection, choose: choose)
        } else {
            switch question {
            case .exercise, .lastWork, .nextWork, .lastObligation, .nextObligation:
                CalendarQuestionView(question: question, selected: displaySelection, choose: choose)
            case .iron, .b12, .conversation, .salientDifficultEvent, .pleasantEvent:
                RecencyMatrixView(question: question, selected: displaySelection, choose: choose)
            case .note: noteContent
            default: choices(Choices.forQuestion(question))
            }
        }
    }

    private func choices(_ options: [Choice]) -> some View {
        VStack(spacing: 3) {
            ForEach(Array(options.enumerated()), id: \.element.id) { entry in
                ChoiceButton(text: entry.element.label, selected: selected?.code == entry.element.id,
                             artwork: customItem?.kind == .recency ? nil : ChoiceArtwork.make(question: question, choice: entry.element, customKind: customItem?.kind, index: entry.offset)) {
                    choose(Answer(entry.element))
                }.frame(maxHeight: 78).accessibilityIdentifier("editChoice_\(entry.element.id)")
            }
        }.frame(maxHeight: .infinity, alignment: .center)
    }

    private var noteContent: some View {
        VStack(spacing: 14) {
            Button {
                if speech.recording { speech.finish() }
                else {
                    let original = edited.note
                    Task { await speech.start { text in edited.note = original + (original.isEmpty ? "" : "\n") + text } }
                }
            } label: {
                Label(speech.busy ? "処理中…" : speech.recording ? "音声入力を止める" : "声で補足する", systemImage: speech.recording ? "stop.circle.fill" : "mic.fill")
                    .frame(maxWidth: .infinity).frame(height: 52).background(.white)
            }.disabled(speech.busy).accessibilityIdentifier("editVoice")
            if keyboard {
                TextEditor(text: $edited.note).font(.system(size: 16)).padding(8)
                    .background(.white).accessibilityIdentifier("editMemoEditor")
            } else {
                Text(edited.note.isEmpty ? "メモなし" : edited.displayedNote)
                    .font(.system(size: 16)).foregroundStyle(edited.note.isEmpty ? Palette.muted : Palette.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .lineLimit(8).padding(14).background(.white)
                Button("文字を修正") { keyboard = true }.font(.system(size: 14))
                    .accessibilityIdentifier("editMemoKeyboard")
            }
            if !edited.note.isEmpty {
                Picker("メモの表示", selection: Binding(get: { edited.noteUsesHiragana ?? false }, set: { edited.noteUsesHiragana = $0 })) {
                    Text("ひらがな").tag(true); Text("通常").tag(false)
                }.pickerStyle(.segmented)
            }
        }.frame(maxHeight: .infinity)
    }

    private func choose(_ answer: Answer) {
        guard !transitioning else { return }
        var value = answer
        value.inheritedFrom = nil
        if customItem?.kind == .recency {
            if let range = ApproximateDates.choices(future: false).first(where: { $0.id == answer.code }) {
                value = range.answer(on: edited.date)
            }
        } else if question.isRecency, value.dayRange != nil {
            value.rangeReferenceDate = CalendarSelection.key(edited.date)
            value.calendarDate = nil
        }
        if let item = customItem {
            if edited.customAnswers == nil { edited.customAnswers = [:] }
            edited.customAnswers?[item.id.uuidString] = CustomResponse(item: item, answer: value)
        } else if question.isClock {
            var updated = edited
            let priorEnd = edited[.sleepEnd]
            guard updated.setSleep(value, for: question),
                  question != .sleepStart || value.code == "noSleep" || updated.setSleep(priorEnd, for: .sleepEnd) else {
                error = "寝た時刻と起きた時刻が同じです。時刻を選び直してください。"; return
            }
            edited = updated
        } else {
            edited[question] = value
            if question == .lastObligation && value.code == "inProgress" {
                edited[.nextObligation] = nil
                edited.markCleared(RecordingStep.builtin(.nextObligation).id, cleared: true)
            }
        }
        edited.markCleared(current.id, cleared: false)
        UISelectionFeedbackGenerator().selectionChanged()
        transitioning = true
        next()
        Task { try? await Task.sleep(for: .milliseconds(120)); transitioning = false }
    }

    private func clear() {
        if let item = customItem { edited.customAnswers?[item.id.uuidString] = nil }
        else if isNote { edited.note = "" }
        else if question.isClock { _ = edited.setSleep(nil, for: question) }
        else { edited[question] = nil }
        edited.markCleared(current.id, cleared: true)
    }

    private func skipped(_ step: RecordingStep) -> Bool {
        if case .builtin(let question) = step {
            return (question == .sleepEnd && edited[.sleepStart]?.code == "noSleep") ||
                (question == .nextObligation && edited[.lastObligation]?.code == "inProgress")
        }
        return false
    }
    private func next() {
        guard !steps.isEmpty else { return }
        if index == steps.count - 1 { index = 0; keyboard = false; return }
        var target = index + 1
        while target < steps.count - 1 && skipped(steps[target]) { target += 1 }
        index = min(target, steps.count - 1); keyboard = false
    }
    private func previous() {
        var target = max(0, index - 1)
        while target > 0 && skipped(steps[target]) { target -= 1 }
        index = target; keyboard = false
    }
}
