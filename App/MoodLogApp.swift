import SwiftUI

@main struct MoodLogApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            RecorderView().environmentObject(store)
                .tint(Palette.accent)
                .preferredColorScheme(.light)
        }
    }
}

enum Palette {
    static let background = Color(red: 0.96, green: 0.97, blue: 0.95)
    static let accent = Color(red: 0.14, green: 0.39, blue: 0.34)
    static let ink = Color(red: 0.13, green: 0.22, blue: 0.20)
    static let muted = Color(red: 0.39, green: 0.46, blue: 0.43)
    static let pale = Color(red: 0.87, green: 0.92, blue: 0.88)
}

struct ChoiceButton: View {
    let text: String
    var selected = false
    var small = false
    var tiled = false
    var artwork: ChoiceArtwork?
    var iconOnly = false
    var outlined = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Group {
                if let artwork {
                    if iconOnly {
                        ChoiceIcon(artwork: artwork).frame(width: 38, height: 32)
                    } else if small {
                        VStack(spacing: 2) {
                            ChoiceIcon(artwork: artwork).frame(width: 27, height: 22)
                            Text(text).font(.system(size: 15, weight: .medium)).lineLimit(1).minimumScaleFactor(0.75)
                        }.padding(.vertical, 3)
                    } else if tiled {
                        VStack(spacing: 4) {
                            ChoiceIcon(artwork: artwork).frame(width: 36, height: 32)
                            Text(text).font(.system(size: 14, weight: .medium)).lineLimit(1).minimumScaleFactor(0.7)
                        }.padding(.horizontal, 6).padding(.vertical, 5)
                    } else {
                        HStack(spacing: 20) {
                            ChoiceIcon(artwork: artwork).frame(width: 52, height: 42)
                            Text(text).font(.system(size: 17, weight: .medium)).minimumScaleFactor(0.75).lineLimit(2)
                            Spacer(minLength: 0)
                        }.padding(.horizontal, 22)
                    }
                } else {
                    Text(text).font(.system(size: small ? 17 : 21, weight: .medium))
                        .minimumScaleFactor(0.75).multilineTextAlignment(.center)
                }
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(selected ? .white : Palette.ink)
                .background(selected ? Palette.accent : .white, in: Rectangle())
                .overlay(Rectangle().strokeBorder(selected ? Palette.accent : Palette.pale, lineWidth: outlined ? 1 : 0))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(text)
    }
}

struct RecorderView: View {
    @EnvironmentObject var store: Store
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speech = SpeechInput()
    @State private var showReview = false
    @State private var showCustom = false
    @State private var showFoodExamples = false
    @State private var saved = false
    @State private var sleepNotice: String?
    @State private var transitioning = false
    private var question: Question { store.question }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 650
            let matrix = store.currentCustomItem == nil && (question.isEvent || question.isSubstance || [.iron, .b12, .conversation].contains(question))
            let headerHeight: CGFloat = matrix ? 156 : question.isClock ? 100 : (question.isCalendar && store.currentCustomItem == nil) ? 140 : 126
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { goToFirst() } label: {
                        Label("最初へ", systemImage: "backward.end.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 94, height: 44, alignment: .leading)
                    }.disabled(store.step == 0 || transitioning)
                        .accessibilityLabel("最初の質問へ戻る")
                        .accessibilityIdentifier("firstQuestion")
                    Spacer()
                    Button { speech.stop(); store.clearCurrentAnswer() } label: {
                        Image(systemName: "eraser").frame(width: 36, height: 44)
                    }.disabled(!store.canClearCurrentAnswer)
                        .accessibilityLabel(store.isNote ? "補足を消す" : "回答を消す")
                        .accessibilityIdentifier("clearAnswer")
                    Button { speech.stop(); showCustom = true } label: {
                        Image(systemName: "slider.horizontal.3").frame(width: 40, height: 44)
                    }.accessibilityLabel("自分の項目").accessibilityIdentifier("customSettings")
                    Button { speech.stop(); showReview = true } label: {
                        Label("振り返り", systemImage: "chart.xyaxis.line")
                            .font(.system(size: 14, weight: .medium)).padding(.vertical, 12)
                    }.accessibilityIdentifier("review")
                }
                progressIcons
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(String(format: "%02d / %02d", store.step + 1, store.flow.count))
                        Spacer()
                        if store.step + 1 < store.flow.count {
                            Text("次：\(store.flow[store.step + 1].short)").lineLimit(1)
                                .accessibilityIdentifier("nextQuestion")
                        }
                    }.font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.muted)
                    Text(store.currentCustomItem?.title ?? question.title).font(.system(size: compact ? 23 : 25, weight: .semibold))
                        .tracking(-0.5).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("question")
                    Text(store.currentCustomItem.map { $0.kind == .scale ? "1＝小さい・少ない、5＝大きい・多い" : "近いものをひとつ選んでください" } ?? (question == .sleepEnd && store.draft[.sleepStart]?.label != nil
                         ? "\(store.draft[.sleepStart]!.label)に寝たあとの起床。日付またぎも自動計算"
                         : question.hint)).font(.system(size: 13)).foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if question == .iron {
                        Button { showFoodExamples = true } label: {
                            Label("食品の例をもっと見る", systemImage: "info.circle")
                                .font(.system(size: 13, weight: .medium)).frame(height: 28)
                        }.accessibilityIdentifier("ironExamples")
                    }
                }.frame(height: headerHeight, alignment: .top)
                questionContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .id(store.currentStep.id)
                    .allowsHitTesting(!transitioning)
                VStack(spacing: 5) {
                    if let inherited = store.carryPreview {
                        Text("前回：\(inherited.label)")
                            .font(.system(size: 11)).foregroundStyle(Palette.muted)
                            .lineLimit(1).minimumScaleFactor(0.8).accessibilityIdentifier("carryPreview")
                    } else if let date = store.recordedToday {
                        Text("今日 \(date.formatted(.dateTime.hour().minute()))に記録済み")
                            .font(.system(size: 11)).foregroundStyle(Palette.muted)
                            .accessibilityIdentifier("recordedToday")
                    } else { Text(" ").font(.system(size: 11)).accessibilityHidden(true) }
                    HStack(spacing: 12) {
                        Button { back() } label: {
                            Label("戻る", systemImage: "chevron.left").frame(width: 94, height: 52)
                                .background(Palette.pale.opacity(0.6), in: Rectangle())
                        }.disabled(store.step == 0 || transitioning).accessibilityIdentifier("back")
                        if store.isNote {
                            Button {
                                speech.stop()
                                if store.save() { saved = true }
                            } label: {
                                Label("記録する", systemImage: "checkmark").frame(maxWidth: .infinity).frame(height: 52)
                                    .foregroundStyle(.white).background(Palette.accent, in: Rectangle())
                            }.disabled(speech.recording || speech.busy).accessibilityIdentifier("save")
                        } else {
                            Button { choose(nil) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "chevron.right")
                                    if let inherited = store.carryPreview {
                                        VStack(spacing: 2) {
                                            Text(inherited.label)
                                                .font(.system(size: 16, weight: .semibold))
                                                .lineLimit(1).minimumScaleFactor(0.8)
                                            Text("を使って次へ")
                                                .font(.system(size: 14, weight: .medium))
                                        }
                                    } else {
                                        Text("スキップ")
                                    }
                                }.frame(maxWidth: .infinity).frame(height: 52)
                                    .background(.white, in: Rectangle())
                            }.disabled(transitioning)
                                .accessibilityLabel(store.carryPreview.map { "\($0.label)を使って次へ" } ?? "スキップ")
                                .accessibilityIdentifier("skip")
                        }
                    }.font(.system(size: 16, weight: .semibold))
                }

            }.padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
        }
        .background(Palette.background.ignoresSafeArea())
        .sheet(isPresented: $showCustom) { CustomItemsView().environmentObject(store) }
        .sheet(isPresented: $showReview) { ReviewView().environmentObject(store) }
        .sheet(isPresented: $showFoodExamples) { IronExamplesView() }
        .overlay(alignment: .top) {
            if saved {
                Label("記録しました", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 22).padding(.vertical, 14)
                    .background(Palette.accent, in: Capsule()).padding(.top, 8)
                    .allowsHitTesting(false)
                    .task { try? await Task.sleep(for: .seconds(2)); saved = false }
            } else if let sleepNotice {
                Text(sleepNotice).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 20).padding(.vertical, 14)
                    .background(Palette.accent, in: Capsule()).padding(.top, 8)
                    .allowsHitTesting(false)
                    .task(id: sleepNotice) { try? await Task.sleep(for: .seconds(2)); self.sleepNotice = nil }
            }
        }
        .alert("お知らせ", isPresented: Binding(get: { store.error != nil || speech.error != nil }, set: { if !$0 { store.error = nil; speech.error = nil } })) {
            Button("閉じる", role: .cancel) { store.error = nil; speech.error = nil }
        } message: { Text(store.error ?? speech.error ?? "") }
        .onChange(of: scenePhase) { _, phase in if phase == .background || (phase == .inactive && speech.recording) { speech.stop() } }
    }

    @ViewBuilder private var questionContent: some View {
        if let item = store.currentCustomItem {
            choiceGrid(item.choices, selected: store.draft.customAnswers?[item.id.uuidString]?.answer.code)
        } else {
        switch question {
        case .sleepStart, .sleepEnd:
            ClockQuestionView(question: question, selected: store.draft[question], choose: { choose($0) })
        case .exercise, .lastWork, .nextWork, .lastObligation, .nextObligation:
            CalendarQuestionView(question: question, selected: store.draft[question], choose: { choose($0) })
        case .iron, .b12, .conversation, .caffeine, .alcohol, .tobacco:
            RecencyMatrixView(question: question, selected: store.draft[question], choose: { choose($0) })
        case .difficultEvent, .salientDifficultEvent, .pleasantEvent:
            RecencyMatrixView(question: question, selected: store.draft[question], choose: { choose($0) })
        case .note:
            noteContent
        default:
            choiceGrid(Choices.forQuestion(question), selected: store.draft[question]?.code)
        }
        }
    }

    private func choiceGrid(_ choices: [Choice], selected: String?) -> some View {
        let columns = store.currentCustomItem?.kind == .recency ? 1 : choices.count > 5 ? 2 : 1
        let rows = (choices.count + columns - 1) / columns
        return VStack(spacing: 2) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<columns, id: \.self) { column in
                        let index = row * columns + column
                        if index < choices.count {
                            let choice = choices[index]
                            ChoiceButton(text: choice.label, selected: selected == choice.id, tiled: columns > 1, artwork: store.currentCustomItem?.kind == .recency ? nil : ChoiceArtwork.make(question: question, choice: choice, customKind: store.currentCustomItem?.kind, index: index)) { choose(Answer(choice)) }
                                .accessibilityIdentifier("choice_\(choice.id)")
                        } else { Color.clear.frame(maxWidth: .infinity) }
                    }
                }.frame(maxHeight: 82)
            }
        }.frame(maxHeight: .infinity, alignment: .center)
    }

    private var progressIcons: some View {
        let count = store.flow.count
        let start = max(0, min(store.step - 5, count - 12))
        return HStack(spacing: 3) {
            ForEach(start..<min(count, start + 12), id: \.self) { index in
                let entry = store.flow[index]
                VStack(spacing: 4) {
                    Group {
                        if case .builtin(let q) = entry, q == .iron || q == .b12 {
                            Text(q == .iron ? "鉄分" : "B12").font(.system(size: 10, weight: .bold))
                        } else { Image(systemName: entry.symbol).font(.system(size: 13)) }
                    }.frame(maxWidth: .infinity).frame(height: 27)
                        .foregroundStyle(index == store.step ? .white : index < store.step ? Palette.accent : Palette.muted.opacity(0.55))
                        .background(index == store.step ? Palette.accent : .clear, in: RoundedRectangle(cornerRadius: 7))
                    Capsule().fill(index <= store.step ? Palette.accent : Palette.pale).frame(height: 3)
                }.accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(entry.short)、\(index == store.step ? "現在" : index < store.step ? "通過済み" : "これから")")
            }
        }.accessibilityIdentifier("questionProgress")
    }

    private var noteContent: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle").font(.system(size: 44, weight: .light)).foregroundStyle(Palette.accent)
            Button {
                if speech.recording { speech.finish() }
                else {
                    let original = store.draft.note
                    Task { await speech.start { text in store.draft.note = original + (original.isEmpty ? "" : "\n") + text } }
                }
            } label: {
                Label(speech.busy ? "処理中…" : speech.recording ? "音声入力を止める" : "声で補足する（任意）", systemImage: speech.recording ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 15, weight: .medium))
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(.white, in: Rectangle())
            }.disabled(speech.busy).accessibilityIdentifier("voice")
            if !store.draft.note.isEmpty {
                Picker("メモの表示", selection: Binding(get: { store.draft.noteUsesHiragana ?? false }, set: { store.draft.noteUsesHiragana = $0 })) {
                    Text("ひらがな").tag(true); Text("通常").tag(false)
                }.pickerStyle(.segmented).accessibilityIdentifier("noteStyle")
                ScrollView {
                    Text(store.draft.displayedNote).font(.system(size: 16)).foregroundStyle(Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                        .accessibilityIdentifier("memoPreview")
                }.frame(maxHeight: 150).background(.white, in: Rectangle())
                Button("この補足を外す") { store.draft.note = "" }
                    .font(.footnote).disabled(speech.recording || speech.busy)
            }
            Spacer(minLength: 0)
        }
    }

    private func choose(_ answer: Answer?) {
        guard !transitioning else { return }
        transitioning = true
        UISelectionFeedbackGenerator().selectionChanged()
        let current = question
        if store.answer(answer), current == .sleepEnd, let duration = store.draft[.sleep]?.label {
            sleepNotice = "睡眠時間 \(duration)"
        }
        Task { try? await Task.sleep(for: .milliseconds(120)); transitioning = false }
    }
    private func back() {
        navigate { store.goBack() }
    }
    private func goToFirst() {
        navigate { store.goToFirst() }
    }
    private func navigate(_ action: () -> Void) {
        guard !transitioning else { return }
        transitioning = true
        speech.stop(); sleepNotice = nil
        UISelectionFeedbackGenerator().selectionChanged()
        action()
        Task { try? await Task.sleep(for: .milliseconds(120)); transitioning = false }
    }
}

struct IronExamplesView: View {
    @Environment(\.dismiss) private var dismiss
    private let groups: [(String, String)] = [
        ("肉・魚介", "豚レバー・鶏レバー・牛赤身肉\nあさり・かき・かつお・さば"),
        ("豆・大豆食品", "納豆・木綿豆腐・厚揚げ\nがんもどき・高野豆腐"),
        ("野菜", "小松菜・ほうれん草・春菊・水菜"),
        ("その他", "鉄を添加したシリアル（商品表示を確認）")
    ]
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(groups, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.0).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.accent)
                        Text(group.1).font(.system(size: 16)).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
                        .background(.white, in: Rectangle())
                }
                Text("食品や量によって、含まれる鉄分の量は違います。")
                    .font(.system(size: 12)).foregroundStyle(Palette.muted)
                HStack {
                    Link("出典：北九州市", destination: URL(string: "https://www.city.kitakyushu.lg.jp/files/001086549.pdf")!)
                    Link("NIH", destination: URL(string: "https://ods.od.nih.gov/factsheets/Iron-HealthProfessional/")!)
                }.font(.footnote)
                Spacer(minLength: 0)
            }.padding(22).background(Palette.background.ignoresSafeArea())
                .navigationTitle("鉄分を含む食品の例").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("戻る") { dismiss() }.accessibilityIdentifier("closeExamples") } }
        }
    }
}
