import SwiftUI

struct RecencyMatrixView: View {
    let question: Question
    let selected: Answer?
    let choose: (Answer) -> Void
    private var event: Bool { question.isEvent }
    private var columns: [String] { question.isSubstance ? Choices.substanceAmounts : event ? Choices.intensities : question == .conversation ? Choices.conversationAmounts : ["少し", "1食分くらい", "多め"] }
    private var prefix: String { question.isSubstance ? "substance" : event ? (question == .pleasantEvent ? "pleasant" : "event") : question == .conversation ? "conversation" : "nutrition" }
    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Text("いつ").frame(width: 78, alignment: .leading)
                ForEach(columns, id: \.self) { Text($0).frame(maxWidth: .infinity) }
            }.font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.muted).frame(height: 28)
            VStack(spacing: 0) {
                ForEach(Choices.recency) { day in
                    HStack(spacing: 8) {
                        Text(day.label)
                            .font(.system(size: 15, weight: .medium))
                            .lineLimit(2).minimumScaleFactor(0.8).frame(width: 78, alignment: .leading)
                        ForEach(0..<3, id: \.self) { index in
                            let answer = question.isSubstance ? Choices.substance(day: day, amount: index) : event ? Choices.event(day: day, intensity: index, pleasant: question == .pleasantEvent) : question == .conversation ? Choices.conversation(day: day, amount: index) : Choices.nutrition(day: day, amount: index)
                            let icon: ChoiceArtwork? = question.isSubstance ? .level(index * 2 + 1) : question == .conversation ? .speech(index + 1) : event ? .face((question == .pleasantEvent ? 1 : -1) * Double(index + 1) / 3) : .nutrientPlate([0.25, 0.6, 1.0][index], question == .iron ? "鉄分" : "B12")
                            ChoiceButton(text: columns[index], selected: selected?.dayRange == answer.dayRange && selected?.amount == answer.amount && selected?.rangeReferenceDate == answer.rangeReferenceDate, small: true, artwork: icon, iconOnly: true, outlined: false) { choose(answer) }
                                .accessibilityLabel(answer.label).accessibilityIdentifier("\(prefix)_\(day.id)_\(index)")
                        }
                    }.padding(.vertical, 5).frame(maxHeight: 66)
                        .overlay(alignment: .bottom) { Rectangle().fill(Palette.muted.opacity(0.3)).frame(height: 1) }
                }
            }
            Group {
                if question.isSubstance {
                    Button { choose(Answer(Choice("notUsed", "普段は取らない"))) } label: {
                        Text("普段は取らない（以後の質問から外す）")
                            .font(.system(size: 13)).frame(maxWidth: .infinity).frame(height: 44).background(.white)
                    }.accessibilityIdentifier("substanceNotUsed")
                } else if event {
                    Button { choose(Answer(Choice("none", "特にない"))) } label: {
                        Label("特にない", systemImage: "minus.circle").frame(maxWidth: .infinity).frame(height: 44).background(.white)
                    }.accessibilityIdentifier("\(prefix)None")
                } else if question != .conversation {
                    Text("その食品を食べた量の目安です。だいたいで選択。")
                        .font(.system(size: 11)).foregroundStyle(Palette.muted)
                } else { Color.clear.accessibilityHidden(true) }
            }.frame(height: 44)

        }.frame(maxHeight: .infinity, alignment: .center)
    }
}
