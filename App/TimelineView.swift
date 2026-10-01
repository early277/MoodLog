import SwiftUI

struct TimelineView: View {
    let records: [LogRecord]
    let customItems: [CustomItem]
    var edit: (LogRecord, TimelineRow?) -> Void = { _, _ in }
    @State private var page = 0
    @State private var selectedID: UUID?
    @State private var selectedRow: String?
    private let gutter: CGFloat = 48
    private var window: [LogRecord] { TimelineModel.window(records, page: page) }
    private var rows: [TimelineRow] { TimelineModel.rows(customItems: customItems, records: records) }
    private var shownRows: [TimelineRow] { rows }
    private var selected: LogRecord? { window.first { $0.id == selectedID } ?? window.last }

    var body: some View {
        GeometryReader { geometry in
            let lineHeight = 100.0
            ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Button { page += 1; selectedID = nil } label: { Image(systemName: "chevron.left").frame(width: 40, height: 36) }
                        .disabled((page + 1) * TimelineModel.pageSize >= records.count).accessibilityLabel("前の7件").accessibilityIdentifier("olderChart")
                    Spacer()
                    Text(page == 0 ? "直近\(window.count)回の記録" : "過去の\(window.count)回の記録").font(.headline)
                    Spacer()
                    Button { page = max(0, page - 1); selectedID = nil } label: { Image(systemName: "chevron.right").frame(width: 40, height: 36) }
                        .disabled(page == 0).accessibilityLabel("次の7件").accessibilityIdentifier("newerChart")
                }
                HStack(spacing: 22) {
                    Label("気分", systemImage: "circle.fill").foregroundStyle(Palette.accent)
                    Label("気力", systemImage: "square.fill").foregroundStyle(.orange)
                    Spacer()
                    Text("1〜5").foregroundStyle(Palette.muted)
                }.font(.system(size: 12, weight: .medium))
                VStack(spacing: 4) {
                    HStack(spacing: 0) {
                        ZStack {
                            ForEach([1.0, 3, 5], id: \.self) { value in
                                Text(String(Int(value))).font(.system(size: 10)).foregroundStyle(Palette.muted)
                                    .position(x: gutter / 2, y: 8 + (lineHeight - 16) * (5 - value) / 4)
                            }
                        }.frame(width: gutter, height: lineHeight)
                        scoreGraph.frame(height: lineHeight)
                    }.frame(height: lineHeight)
                    HStack(spacing: 0) {
                        Text("日時").font(.system(size: 10)).frame(width: gutter, alignment: .leading)
                        ForEach(window) { record in
                            VStack(spacing: 2) {
                                Text(record.date.formatted(.dateTime.month(.defaultDigits).day()))
                                Text(record.date.formatted(.dateTime.hour().minute()))
                            }.font(.system(size: 9, weight: record.id == selected?.id ? .bold : .regular))
                                .frame(maxWidth: .infinity).foregroundStyle(Palette.muted)
                        }
                    }.frame(height: 30)
                    ForEach(shownRows) { row in
                        HStack(spacing: 0) {
                            Text(row.title).font(.system(size: 10, weight: .medium)).lineLimit(2).minimumScaleFactor(0.75)
                                .foregroundStyle(Palette.muted).frame(width: gutter, alignment: .leading)
                            ForEach(window) { record in
                                let shade = AnswerShade.opacity(of: row.answer(in: record), question: row.question,
                                                                customKind: row.customID.flatMap { record.customAnswers?[$0.uuidString]?.item.kind },
                                                                recordedAt: record.date)
                                Button {
                                    selectedID = record.id; selectedRow = row.id
                                } label: {
                                    Text(row.compactLabel(in: record)).font(.system(size: 10, weight: .medium))
                                        .lineLimit(2).minimumScaleFactor(0.7).multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity).frame(height: 27)
                                        .foregroundStyle(row.answer(in: record) == nil ? Palette.muted : Palette.ink)
                                        .background(Palette.accent.opacity(shade), in: RoundedRectangle(cornerRadius: 5))
                                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(selectedID == record.id && selectedRow == row.id ? Palette.accent : .clear))
                                        .padding(.horizontal, 1)
                                }.buttonStyle(.plain)
                                    .accessibilityLabel("\(row.title)、\(record.date.formatted())、\(row.answer(in: record)?.reviewLabel ?? "未回答")")
                                    .accessibilityIdentifier("timeline_\(row.id)_\(record.id)")
                            }
                        }
                    }
                }
                if let selected {
                    HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selected.date.formatted(.dateTime.month().day().hour().minute())).font(.system(size: 11)).foregroundStyle(Palette.muted)
                        if let row = rows.first(where: { $0.id == selectedRow }) {
                            Text("\(row.title)：\(row.answer(in: selected)?.reviewLabel ?? "未回答")").font(.system(size: 13, weight: .medium)).lineLimit(2)
                        } else {
                            Text("気分 \(selected[.mood]?.label ?? "—") ／ 気力 \(selected[.energy]?.label ?? "—")").font(.system(size: 13, weight: .medium))
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).accessibilityElement(children: .combine).accessibilityIdentifier("timelineDetail")
                    Button { edit(selected, rows.first { $0.id == selectedRow }) } label: {
                        Label("修正", systemImage: "pencil").font(.system(size: 13, weight: .medium)).padding(10).background(.white)
                    }.accessibilityIdentifier("timelineEdit")
                    }
                }
                Text("濃いほど量・強さが大きい。時期だけの項目は近いほど濃い。\n横軸は記録順。— は未回答。マスを押すと詳細。")
                    .font(.system(size: 10)).foregroundStyle(Palette.muted).frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("timelineShadeLegend")
                Spacer(minLength: 0)
            }
            }
        }
    }

    private var scoreGraph: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height - 16
            let count = max(window.count, 1)
            ZStack {
                Canvas { context, size in
                    for value in [1.0, 3, 5] {
                        let y = 8 + height * (5 - value) / 4
                        var rule = Path(); rule.move(to: CGPoint(x: 0, y: y)); rule.addLine(to: CGPoint(x: width, y: y))
                        context.stroke(rule, with: .color(Palette.pale), lineWidth: 1)
                    }
                    for (index, outcome) in [Question.mood, .energy].enumerated() {
                        let color = index == 0 ? Palette.accent : Color.orange
                        var path = Path(); var connected = false
                        for (position, record) in window.enumerated() {
                            guard let score = record[outcome]?.value else { connected = false; continue }
                            let point = CGPoint(x: width * (Double(position) + 0.5) / Double(count), y: 8 + height * (5 - score) / 4)
                            if connected { path.addLine(to: point) } else { path.move(to: point) }
                            connected = true
                            let dot = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
                            context.fill(index == 0 ? Path(ellipseIn: dot) : Path(dot), with: .color(color))
                        }
                        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, dash: index == 0 ? [] : [5, 3]))
                    }
                }
                HStack(spacing: 0) {
                    ForEach(window) { record in
                        Button { selectedID = record.id; selectedRow = nil } label: {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityLabel("\(record.date.formatted())、気分\(record[.mood]?.label ?? "未回答")、気力\(record[.energy]?.label ?? "未回答")")
                    }
                }
            }
        }
    }
}
