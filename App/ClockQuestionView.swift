import SwiftUI

struct ClockQuestionView: View {
    let question: Question
    let choose: (Answer) -> Void
    @State private var alternate: Bool
    @State private var step: Int?
    init(question: Question, selected: Answer?, choose: @escaping (Answer) -> Void) {
        self.question = question; self.choose = choose
        // Bedtime always opens at night, even when an old draft contains a daytime answer.
        // This changes only the picker; the draft is replaced only after an explicit selection.
        let minutes = selected?.value.map(Int.init).flatMap { value in
            question == .sleepStart && !ClockDialSelection.contains(value, start: ClockDialSelection.defaultStart(for: question)) ? nil : value
        }
        _alternate = State(initialValue: minutes.map { !ClockDialSelection.contains($0, start: ClockDialSelection.defaultStart(for: question)) } ?? false)
        _step = State(initialValue: minutes.map { ($0 % 720) / 30 } ?? (question == .sleepStart ? 22 : 14))
    }
    private var windowStart: Int { ClockDialSelection.start(for: question, alternate: alternate) }
    private var time: String {
        step.map { SleepClock.timeLabel(ClockDialSelection.minutes(step: $0, start: windowStart)) } ?? "—:—"
    }
    private func commit(_ step: Int) {
        let minutes = ClockDialSelection.minutes(step: step, start: windowStart)
        choose(Answer(Choice("clock\(minutes)", SleepClock.timeLabel(minutes), Double(minutes))))
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Text(ClockDialSelection.label(start: windowStart))
                    .font(.system(size: 16, weight: .medium)).monospacedDigit()
                    .foregroundStyle(Palette.muted).accessibilityIdentifier("clockWindow")
                Spacer(minLength: 0)
                Button { alternate.toggle() } label: {
                    Label(question == .sleepStart ? (alternate ? "夜の時間帯" : "昼の時間帯") : "別の時間帯", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 12).frame(height: 48)
                        .foregroundStyle(Palette.accent).background(.white)
                }.buttonStyle(.plain)
                    .accessibilityValue(ClockDialSelection.label(start: windowStart))
                    .accessibilityIdentifier("clockWindowToggle")
            }.frame(height: 48)
            Text(time).font(.system(size: 32, weight: .medium)).monospacedDigit()
                .foregroundStyle(Palette.ink).frame(height: 42).accessibilityIdentifier("clockTime")
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                ZStack {
                    Circle().fill(.white)
                    Circle().strokeBorder(Palette.pale, lineWidth: 2)
                    Canvas { context, _ in
                        let center = CGPoint(x: size / 2, y: size / 2)
                        for tick in 0..<24 {
                            let angle = Double(tick) * .pi / 12 - .pi / 2
                            let radius = size * (tick.isMultiple(of: 2) ? 0.465 : 0.415)
                            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                            if !tick.isMultiple(of: 2) {
                                context.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)), with: .color(Palette.muted))
                            } else {
                                let inside = CGPoint(x: center.x + cos(angle) * (radius - 7), y: center.y + sin(angle) * (radius - 7))
                                var mark = Path(); mark.move(to: inside); mark.addLine(to: point)
                                context.stroke(mark, with: .color(Palette.muted), lineWidth: 2)
                            }
                        }
                        if let step {
                            let angle = Double(step) * .pi / 12 - .pi / 2
                            let tip = CGPoint(x: center.x + cos(angle) * size * 0.29, y: center.y + sin(angle) * size * 0.29)
                            var hand = Path(); hand.move(to: center); hand.addLine(to: tip)
                            context.stroke(hand, with: .color(Palette.accent), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            let dot = CGPoint(x: center.x + cos(angle) * size * 0.415, y: center.y + sin(angle) * size * 0.415)
                            context.stroke(Path(ellipseIn: CGRect(x: dot.x - 10, y: dot.y - 10, width: 20, height: 20)), with: .color(Palette.accent), lineWidth: 2)
                        }
                        context.fill(Path(ellipseIn: CGRect(x: center.x - 6, y: center.y - 6, width: 12, height: 12)), with: .color(Palette.accent))
                    }
                    ForEach(1...12, id: \.self) { hour in
                        let angle = Double(hour) * .pi / 6 - .pi / 2
                        Text("\(hour)").font(.system(size: max(18, size * 0.075), weight: .medium)).monospacedDigit()
                            .foregroundStyle(Palette.ink)
                            .position(x: size / 2 + cos(angle) * size * 0.415, y: size / 2 + sin(angle) * size * 0.415)
                    }
                }.frame(width: size, height: size)
                    .contentShape(Circle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            guard hypot(gesture.location.x - size / 2, gesture.location.y - size / 2) > size * 0.14 else { return }
                            let next = ClockDialSelection.step(x: gesture.location.x - size / 2, y: gesture.location.y - size / 2)
                            if next != step { UISelectionFeedbackGenerator().selectionChanged(); step = next }
                        }
                        .onEnded { gesture in
                            guard hypot(gesture.location.x - size / 2, gesture.location.y - size / 2) > size * 0.14 else { return }
                            let next = ClockDialSelection.step(x: gesture.location.x - size / 2, y: gesture.location.y - size / 2)
                            step = next; commit(next)
                        })
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("時刻の時計")
                    .accessibilityValue(time)
                    .accessibilityHint("上下スワイプで30分ずつ変更。この時刻にするアクションで決定")
                    .accessibilityAdjustableAction { direction in
                        let current = step ?? 0
                        if direction == .increment { step = (current + 1) % 24 }
                        else if direction == .decrement { step = (current + 23) % 24 }
                    }
                    .accessibilityAction(named: "この時刻にする") { if let step { commit(step) } }
                    .accessibilityIdentifier("clockDial")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if question == .sleepStart {
                Button("寝ていない") { choose(Answer(Choice("noSleep", "寝ていない"))) }
                    .font(.system(size: 16, weight: .medium)).frame(maxWidth: .infinity).frame(height: 44)
                    .background(.white).accessibilityIdentifier("noSleep")
            } else { Color.clear.frame(height: 44).accessibilityHidden(true) }
        }.frame(maxHeight: .infinity)
    }
}
