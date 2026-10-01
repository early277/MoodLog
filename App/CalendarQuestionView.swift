import SwiftUI

// One column of six shared date ranges. No calendar or category colors.
struct CalendarQuestionView: View {
    let question: Question
    let selected: Answer?
    let choose: (Answer) -> Void
    private var future: Bool { question.isFuture }
    private var special: [Choice] {
        if question == .lastWork { return Choices.forQuestion(question).filter { ["working", "noWork"].contains($0.id) } }
        if question == .lastObligation { return Choices.forQuestion(question).filter { ["inProgress", "noObligation"].contains($0.id) } }
        if future { return Choices.forQuestion(question).filter { ["unscheduled", "none"].contains($0.id) } }
        return []
    }
    var body: some View {
        let now = Date()
        VStack(spacing: 5) {
            ForEach(ApproximateDates.choices(future: future)) { group in
                let isSelected = selected?.dayRange == group.range && selected?.rangeReferenceDate == CalendarSelection.key(now)
                ChoiceButton(text: group.label, selected: isSelected, artwork: .system(question == .exercise ? "figure.run" : "briefcase.fill")) { choose(group.answer(on: now)) }
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityIdentifier("range_\(group.id)")
                    .frame(maxHeight: 64)
            }
            if !special.isEmpty {
                HStack(spacing: 5) {
                    ForEach(special) { option in
                        ChoiceButton(text: option.label, selected: selected?.code == option.id, small: true) { choose(Answer(option)) }
                            .accessibilityIdentifier("choice_\(option.id)")
                    }
                }.frame(height: 44)
            } else { Color.clear.frame(height: 44).accessibilityHidden(true) }
        }.frame(maxHeight: .infinity, alignment: .center)
    }
}
