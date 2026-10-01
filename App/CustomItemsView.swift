import SwiftUI

struct CustomItemsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var adding = false
    @State private var deleting: CustomItem?
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ScrollView {
                VStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("質問の表示").font(.headline)
                    ForEach(Question.substances, id: \.self) { question in
                        Toggle(question.short, isOn: Binding(get: { !store.hiddenSubstances.contains(question) }, set: { store.setSubstance(question, visible: $0) }))
                            .frame(minHeight: 40).accessibilityIdentifier("substanceVisible_\(question.rawValue)")
                    }
                }.padding(16).background(.white)
                if store.customItems.isEmpty {
                    Spacer()
                    Image(systemName: "slider.horizontal.3").font(.largeTitle).foregroundStyle(Palette.accent)
                    Text("追加項目なし")
                    Text("例：コーヒー、外出、自由に使えた時間")
                        .font(.footnote).foregroundStyle(Palette.muted)
                    Spacer()
                } else {
                    let item = store.customItems[min(index, store.customItems.count - 1)]
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 20) {
                        Text(item.title).font(.title2.weight(.semibold))
                        Text(item.kind.label).foregroundStyle(Palette.muted)
                        Text(item.choices.map(\.label).joined(separator: " ／ "))
                            .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                        Toggle("記録画面に表示", isOn: Binding(get: { item.enabled }, set: { store.setCustomItem(item.id, enabled: $0) }))
                            .accessibilityIdentifier("customEnabled")
                        Button("項目を削除", role: .destructive) { deleting = item }
                            .frame(minHeight: 44).accessibilityIdentifier("deleteCustom")
                    }.padding(22).background(.white, in: Rectangle())
                    Text("非表示にしても過去の回答は残ります。内容を変えるときは、新しい項目を追加します。")
                        .font(.footnote).foregroundStyle(Palette.muted)
                    HStack {
                        Button { index -= 1 } label: { Image(systemName: "chevron.left").frame(width: 48, height: 48) }.disabled(index == 0).accessibilityLabel("前の項目")
                        Spacer()
                        Text("\(index + 1) / \(store.customItems.count)")
                        Spacer()
                        Button { index += 1 } label: { Image(systemName: "chevron.right").frame(width: 48, height: 48) }.disabled(index + 1 >= store.customItems.count).accessibilityLabel("次の項目")
                    }
                    Spacer(minLength: 0)
                }
                }
                }.accessibilityIdentifier("itemSettingsScroll")
                Button { adding = true } label: {
                    Label("項目を追加", systemImage: "plus").frame(maxWidth: .infinity).frame(height: 54)
                        .foregroundStyle(.white).background(Palette.accent, in: Rectangle())
                }.accessibilityIdentifier("addCustom")
            }.padding(24).background(Palette.background.ignoresSafeArea())
                .navigationTitle("項目設定").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() }.accessibilityIdentifier("closeCustom") } }
                .sheet(isPresented: $adding) { CustomItemEditor().environmentObject(store) }
                .confirmationDialog("この項目を削除しますか？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
                    Button("削除する", role: .destructive) { if let item = deleting { store.deleteCustomItem(item.id) }; deleting = nil }
                    Button("キャンセル", role: .cancel) { deleting = nil }
                } message: { Text("過去の記録は残ります。") }
                .onChange(of: store.customItems.count) { _, count in index = max(0, count - 1) }
        }
    }
}

struct CustomItemEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @StateObject private var speech = SpeechInput()
    @State private var title = ""
    @State private var optionsText = ""
    @State private var kind: CustomItem.Kind = .recency
    @State private var page = 0
    @State private var validation: String?
    @FocusState private var editing: Bool
    private var options: [String] { optionsText.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(page == 0 ? "項目名" : page == 1 ? "回答形式" : "選択肢")
                    .font(.title2.weight(.semibold))
                if page == 0 {
                    Text("例：最後にコーヒーを飲んだのは？").font(.footnote).foregroundStyle(Palette.muted)
                    TextField("項目名（40文字以内）", text: $title, axis: .vertical)
                        .lineLimit(2...3).padding(16).background(.white, in: Rectangle())
                        .focused($editing).accessibilityIdentifier("customTitle")
                    Button {
                        editing = false
                        if speech.recording { speech.finish() }
                        else { let original = title; Task { await speech.start { title = original + $0 } } }
                    } label: { Label(speech.recording ? "音声入力を止める" : "声で項目名を入力", systemImage: "mic.fill").frame(height: 48) }
                        .disabled(speech.busy)
                } else if page == 1 {
                    ForEach(CustomItem.Kind.allCases, id: \.self) { value in
                        ChoiceButton(text: value.label, selected: kind == value) { kind = value }
                            .frame(height: 64).accessibilityIdentifier("kind_\(value.rawValue)")
                    }
                    if kind == .scale { Text("1＝小さい・少ない、5＝大きい・多い").font(.footnote).foregroundStyle(Palette.muted) }
                } else {
                    Text("1行に1つ、2〜6個。各24文字以内。\n例：なし／1杯／2杯以上（行を分けて入力）")
                        .font(.footnote).foregroundStyle(Palette.muted)
                    TextEditor(text: $optionsText).focused($editing).frame(height: 180)
                        .padding(12).background(.white, in: Rectangle())
                        .accessibilityIdentifier("customOptions")
                    Button {
                        editing = false
                        if speech.recording { speech.finish() }
                        else {
                            let original = optionsText
                            Task { await speech.start { optionsText = original + (original.isEmpty ? "" : "\n") + $0 } }
                        }
                    } label: { Label(speech.recording ? "音声入力を止める" : "声で選択肢を1つ追加", systemImage: "mic.fill").frame(height: 44) }
                        .font(.footnote).disabled(speech.busy)
                }
                if let validation { Text(validation).font(.footnote).foregroundStyle(.red) }
                Spacer(minLength: 0)
                HStack {
                    if page > 0 { Button("戻る") { speech.stop(); editing = false; validation = nil; page -= 1 }.frame(height: 48) }
                    Spacer()
                    Button(page == 0 || (page == 1 && kind == .options) ? "次へ" : "追加する") {
                        editing = false
                        if page == 0 {
                            let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !clean.isEmpty && clean.count <= 40 else { validation = "項目名は1〜40文字で入力してください。"; return }
                            speech.stop(); title = clean; validation = nil; page = 1
                        } else if page == 1 && kind == .options { page = 2 }
                        else {
                            let item = CustomItem(title: title, kind: kind, options: options)
                            if let error = CustomItem.validation(title: title, kind: kind, options: options) { validation = error }
                            else if store.addCustomItem(item) { dismiss() }
                            else { validation = store.error }
                        }
                    }.buttonStyle(.borderedProminent).disabled(speech.recording || speech.busy).accessibilityIdentifier("customNext")
                }
            }.padding(24).background(Palette.background.ignoresSafeArea())
                .navigationTitle("項目を追加").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("キャンセル") { dismiss() } } }
                .onDisappear { speech.stop() }
                .onChange(of: phase) { _, value in if value == .background || (value == .inactive && speech.recording) { speech.stop() } }
                .alert("音声入力", isPresented: Binding(get: { speech.error != nil }, set: { if !$0 { speech.error = nil } })) { Button("閉じる") { speech.error = nil } } message: { Text(speech.error ?? "") }
        }
    }
}
