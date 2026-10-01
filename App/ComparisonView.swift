import SwiftUI

struct ComparisonView: View {
    let records: [LogRecord]
    let customItems: [CustomItem]
    @State private var factor: Question = .sleep
    @State private var customID: UUID?
    @State private var amount = -1
    @State private var choosingFactor = false
    private var factors: [Question] { TimelineModel.rows(customItems: [], records: records).compactMap(\.question) }
    private var customFactors: [CustomItem] {
        var seen = Set<UUID>()
        let snapshots = records.flatMap { ($0.customAnswers ?? [:]).values.map(\.item) }.sorted { $0.title < $1.title }
        return (customItems + snapshots).filter { seen.insert($0.id).inserted }
    }
    private var custom: CustomItem? { customFactors.first { $0.id == customID } }
    private var groups: [ComparisonGroup] {
        if let custom { return ComparisonModel.groups(records: records, item: custom) }
        return ComparisonModel.groups(records: records, factor: factor, amount: amount < 0 ? nil : amount)
    }
    private var amounts: [String]? {
        guard custom == nil else { return nil }
        if factor.isEvent { return Choices.intensities }
        if factor.isSubstance { return Choices.substanceAmounts }
        if factor == .conversation { return Choices.conversationAmounts }
        if factor == .iron || factor == .b12 { return Choices.amounts }
        return nil
    }
    var body: some View {
        VStack(spacing: 12) {
            Button { choosingFactor = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("比較する項目").font(.system(size: 12)).foregroundStyle(Palette.muted)
                        Text(custom?.title ?? factor.short).font(.system(size: 19, weight: .medium)).foregroundStyle(Palette.ink).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.down").foregroundStyle(Palette.accent)
                }.padding(14).frame(maxWidth: .infinity).background(.white)
            }.buttonStyle(.plain).accessibilityIdentifier("factorMenu")
            if let amounts {
                Picker(factor.isEvent ? "強さ" : "量", selection: $amount) {
                    Text("すべて").tag(-1)
                    ForEach(0..<amounts.count, id: \.self) { index in Text(amounts[index]).tag(index) }
                }.pickerStyle(.segmented).accessibilityIdentifier("comparisonAmount")
            }
            HStack(spacing: 20) {
                Label("気分", systemImage: "circle.fill").foregroundStyle(Palette.accent)
                Label("気力", systemImage: "square.fill").foregroundStyle(.orange)
                Spacer()
                Text("1〜5").foregroundStyle(Palette.muted)
            }.font(.system(size: 12, weight: .medium))
            comparisonGraph.frame(height: 180).accessibilityIdentifier("comparisonGraph")
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        Text("回答").frame(maxWidth: .infinity, alignment: .leading)
                        Text("気分").frame(width: 46)
                        Text("気力").frame(width: 46)
                        Text("日数").frame(width: 52)
                    }.font(.system(size: 11)).foregroundStyle(Palette.muted).padding(.bottom, 6)
                    ForEach(groups) { group in
                        HStack {
                            Text(group.label).frame(maxWidth: .infinity, alignment: .leading).lineLimit(2)
                            Text(score(group.mood.mean)).foregroundStyle(Palette.accent).frame(width: 46)
                            Text(score(group.energy.mean)).foregroundStyle(.orange).frame(width: 46)
                            Text("\(group.mood.days)/\(group.energy.days)").foregroundStyle(Palette.muted).frame(width: 52)
                        }.font(.system(size: 13)).padding(.vertical, 7)
                            .overlay(alignment: .bottom) { Rectangle().fill(Palette.pale).frame(height: 0.5) }
                    }
                }
            }.accessibilityIdentifier("comparisonValues")
            Text("日数は気分／気力の順。日平均を比較。3日未満は記録不足。\n— は未回答。因果関係は示しません。")
                .font(.system(size: 10)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $choosingFactor) {
            NavigationStack {
                List {
                    ForEach(factors, id: \.self) { question in
                        Button { factor = question; customID = nil; amount = -1; choosingFactor = false } label: {
                            Label(question.short, systemImage: question.symbol).foregroundStyle(Palette.ink)
                        }
                    }
                    ForEach(customFactors) { item in
                        Button { customID = item.id; amount = -1; choosingFactor = false } label: {
                            Label(item.title, systemImage: "square.grid.2x2").foregroundStyle(Palette.ink)
                        }
                    }
                }.navigationTitle("比較する項目").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { choosingFactor = false } } }
            }.presentationDetents([.large])
        }
    }
    private func score(_ value: Double?) -> String { value.map { String(format: "%.1f", $0) } ?? "—" }
    private var comparisonGraph: some View {
        GeometryReader { geometry in
            let gutter = 22.0
            let width = max(geometry.size.width - gutter, 1)
            let height = geometry.size.height - 38
            let count = max(groups.count, 1)
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    for value in [1.0, 3, 5] {
                        let y = 8 + (height - 16) * (5 - value) / 4
                        var rule = Path(); rule.move(to: CGPoint(x: gutter, y: y)); rule.addLine(to: CGPoint(x: gutter + width, y: y))
                        context.stroke(rule, with: .color(Palette.pale), lineWidth: 1)
                    }
                    for outcome in 0..<2 {
                        let color = outcome == 0 ? Palette.accent : Color.orange
                        var path = Path(); var connected = false
                        for (position, group) in groups.enumerated() {
                            let summary = outcome == 0 ? group.mood : group.energy
                            guard let value = summary.mean else { connected = false; continue }
                            let point = CGPoint(x: gutter + width * (Double(position) + 0.5) / Double(count), y: 8 + (height - 16) * (5 - value) / 4)
                            if connected { path.addLine(to: point) } else { path.move(to: point) }
                            connected = true
                            let dot = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
                            let shape = outcome == 0 ? Path(ellipseIn: dot) : Path(dot)
                            if summary.days < 3 { context.stroke(shape, with: .color(color), lineWidth: 2) }
                            else { context.fill(shape, with: .color(color)) }
                        }
                        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, dash: outcome == 0 ? [] : [5, 3]))
                    }
                }
                ForEach([1.0, 3, 5], id: \.self) { value in
                    Text(String(Int(value))).font(.system(size: 10)).foregroundStyle(Palette.muted)
                        .position(x: gutter / 2, y: 8 + (height - 16) * (5 - value) / 4)
                }
                HStack(spacing: 0) {
                    Color.clear.frame(width: gutter)
                    ForEach(groups) { group in
                        Text(group.label.replacingOccurrences(of: "日前", with: "日").replacingOccurrences(of: "週間", with: "週"))
                            .font(.system(size: 10)).foregroundStyle(Palette.muted).lineLimit(2).minimumScaleFactor(0.7)
                            .multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    }
                }.frame(height: 32).offset(y: height)
            }.accessibilityElement(children: .ignore)
                .accessibilityLabel("横軸は回答、縦軸は気分と気力の1から5の平均")
        }
    }
}
