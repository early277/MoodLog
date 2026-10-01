import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var section = 0
    @State private var editingRecord: LogRecord?
    @State private var editingQuestion: Question?
    @State private var editingCustomID: UUID?
    @State private var showFullMemo = false
    @State private var historyIndex = 0
    @State private var confirmingDelete = false
    @State private var exportURL: URL?
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("表示", selection: $section) {
                    Text("グラフ").tag(0); Text("比較").tag(1); Text("記録").tag(2)
                }.pickerStyle(.segmented).accessibilityIdentifier("reviewTabs")
                if store.records.isEmpty {
                    Spacer()
                    Image(systemName: "chart.xyaxis.line").font(.system(size: 42)).foregroundStyle(Palette.accent)
                    Text("記録がありません") .font(.headline)
                    Text("保存すると、ここに表示されます").font(.subheadline).foregroundStyle(Palette.muted)
                    Spacer()
                } else {
                    switch section {
                    case 0: trend
                    case 1: ComparisonView(records: store.records, customItems: store.customItems)
                    default: history
                    }
                }
            }.padding(24).background(Palette.background.ignoresSafeArea())
                .navigationTitle("振り返り").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        if let exportURL { ShareLink(item: exportURL) { Image(systemName: "square.and.arrow.up") }.accessibilityLabel("記録を書き出す") }
                    }
                    ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() }.accessibilityIdentifier("closeReview") }
                }
                .sheet(item: $editingRecord) { record in
                    RecordEditorView(record: record, initialQuestion: editingQuestion, initialCustomID: editingCustomID).environmentObject(store)
                }
                .onAppear { exportURL = try? store.export() }
                .onChange(of: store.records) { _, _ in exportURL = try? store.export() }
                .confirmationDialog("この記録を削除しますか？", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("削除する", role: .destructive) {
                        if store.records.indices.contains(historyIndex) { store.delete(store.records[historyIndex].id); historyIndex = min(historyIndex, max(0, store.records.count - 1)) }
                    }
                }
        }
    }
    private var trend: some View {
        TimelineView(records: store.records, customItems: store.customItems) { record, row in
            editingQuestion = row?.question == .sleep ? .sleepStart : row?.question
            editingCustomID = row?.customID
            editingRecord = record
        }
    }
    private var history: some View {
        VStack(spacing: 12) {
            if store.records.indices.contains(historyIndex) {
                let record = store.records[historyIndex]
                HStack {
                    Button { historyIndex = min(historyIndex + 1, store.records.count - 1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.disabled(historyIndex >= store.records.count - 1).accessibilityLabel("前の記録")
                    Spacer()
                    Text(record.date.formatted(.dateTime.month().day().hour().minute())).font(.headline).accessibilityIdentifier("historyDate")
                    Spacer()
                    Button { historyIndex = max(0, historyIndex - 1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.disabled(historyIndex == 0).accessibilityLabel("次の記録")
                }
                let questions = Question.history.filter { !$0.isSubstance || record[$0] != nil } + [Question.lastWork, .nextWork].filter { record[$0] != nil }
                let entries = questions.map { ($0.short, $0 == .sleep ? record.sleepHistoryLabel : record[$0]?.reviewLabel ?? "—") }
                    + (record.customAnswers ?? [:]).values.sorted { $0.item.title < $1.item.title }.map { ($0.item.title, $0.answer.reviewLabel) }
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.offset) { entry in
                            HStack {
                                Text(entry.element.0).foregroundStyle(Palette.muted).lineLimit(1)
                                Spacer()
                                Text(entry.element.1).foregroundStyle(Palette.ink).lineLimit(2).minimumScaleFactor(0.85)
                            }.font(.system(size: 14)).padding(.vertical, 7)
                                .overlay(alignment: .bottom) { Rectangle().fill(Palette.pale).frame(height: 0.5) }
                        }
                    }.padding(.horizontal, 12).background(.white)
                }.accessibilityIdentifier("historyItems")
                if !record.note.isEmpty {
                    Text(record.displayedNote).font(.system(size: 14)).frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(2).accessibilityIdentifier("savedMemo")
                    Button("メモを開く") { showFullMemo = true }.font(.footnote).accessibilityIdentifier("openMemo")
                        .sheet(isPresented: $showFullMemo) { SavedMemoView(record: record) }
                }
                Spacer(minLength: 0)
                HStack {
                    Text("\(store.records.count - historyIndex) / \(store.records.count)件").font(.footnote).foregroundStyle(Palette.muted)
                    Spacer()
                    Button("修正") { editingQuestion = nil; editingCustomID = nil; editingRecord = record }
                        .font(.footnote).frame(height: 44).accessibilityIdentifier("editRecord")
                    Button("この記録を削除", role: .destructive) { confirmingDelete = true }.font(.footnote).frame(height: 44).accessibilityIdentifier("deleteRecord")
                }
            }
        }
    }
}

struct SavedMemoView: View {
    let record: LogRecord
    @Environment(\.dismiss) private var dismiss
    @State private var hiragana = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("表示", selection: $hiragana) {
                    Text("ひらがな（試用）").tag(true); Text("通常").tag(false)
                }.pickerStyle(.segmented)
                ScrollView {
                    Text(hiragana ? NoteText.hiragana(record.note) : record.note)
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }
            }.padding(24).background(Palette.background.ignoresSafeArea())
                .navigationTitle("メモ").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } } }
                .onAppear { hiragana = record.noteUsesHiragana ?? false }
        }
    }
}
