import SwiftUI

// Visuals are presentation only; stored answers and VoiceOver labels remain unchanged.
enum ChoiceArtwork {
    case tasks(Int), speech(Int), face(Double), battery(Int), plate(Double), hungerPlate(Double), nutrientPlate(Double, String), level(Int), clock(Int)
    case calendar(String, forward: Bool), system(String), option(Int)

    static func make(question: Question, choice: Choice, customKind: CustomItem.Kind?, index: Int) -> ChoiceArtwork {
        if let customKind {
            switch customKind {
            case .scale: return .level(index + 1)
            case .yesNo: return .system(choice.id == "yes" ? "checkmark.circle" : "xmark.circle")
            case .options: return .option(index + 1)
            case .recency: break
            }
        } else {
            switch question {
            case .mood: return .face(((choice.value ?? 3) - 3) / 2)
            case .energy: return .battery(Int(choice.value ?? 3) - 1)
            case .backlog: return .tasks(index)
            case .hunger: return .hungerPlate(Double(4 - index) / 4)
            default: break
            }
        }
        switch choice.id {
        case "working": return .system("briefcase.fill")
        case "noWork": return .system("briefcase")
        case "unscheduled": return .system("questionmark.circle")
        case "none", "never": return .system("minus.circle")
        default:
            let days = ["today": "0", "later": "0", "yesterday": "1", "tomorrow": "1", "two": "2", "three": "3", "fourToSix": "4–6", "weekPlus": "7+", "threePlus": "3+"]
            return .calendar(days[choice.id] ?? "?", forward: customKind == nil && question.isFuture)
        }
    }
}

struct ChoiceIcon: View {
    let artwork: ChoiceArtwork
    var body: some View {
        Group {
            switch artwork {
            case .system(let name): Image(systemName: name).resizable().scaledToFit().padding(3)
            case .calendar(let text, let forward):
                GeometryReader { geometry in
                    let side = min(geometry.size.width, geometry.size.height)
                    VStack(spacing: 0) {
                        Image(systemName: forward ? "arrow.right" : "arrow.left").font(.system(size: side * 0.20, weight: .semibold))
                            .frame(maxWidth: .infinity).frame(height: side * 0.25).background(.primary.opacity(0.10))
                        Text(text).font(.system(size: side * (text.count > 2 ? 0.29 : 0.38), weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }.frame(width: side, height: side)
                        .clipShape(RoundedRectangle(cornerRadius: side * 0.15))
                        .overlay(RoundedRectangle(cornerRadius: side * 0.15).strokeBorder(lineWidth: 1.5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .nutrientPlate(let fraction, let label):
                ZStack {
                    Circle().stroke(lineWidth: 1.5).opacity(0.18)
                    Circle().trim(from: 0, to: fraction)
                        .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                    Text(label).font(.system(size: 12, weight: .semibold))
                }.frame(width: 30, height: 30)
            case .option(let number): Image(systemName: "\(number).circle").resizable().scaledToFit().padding(3)
            default:
                Canvas { context, size in
                    let side = min(size.width, size.height)
                    let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
                    context.translateBy(x: origin.x, y: origin.y)
                    context.scaleBy(x: side / 40, y: side / 40)
                    let ink = GraphicsContext.Shading.foreground
                    let stroke = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    func line(_ a: CGPoint, _ b: CGPoint) {
                        var p = Path(); p.move(to: a); p.addLine(to: b); context.stroke(p, with: ink, style: stroke)
                    }
                    switch artwork {
                    case .tasks(let count):
                        var tray = Path(); tray.move(to: CGPoint(x: 3, y: 31)); tray.addLine(to: CGPoint(x: 3, y: 37))
                        tray.addLine(to: CGPoint(x: 37, y: 37)); tray.addLine(to: CGPoint(x: 37, y: 31))
                        context.stroke(tray, with: ink, style: stroke)
                        for n in 0..<count {
                            context.stroke(Path(CGRect(x: 7, y: 26 - n * 7, width: 26, height: 5)), with: ink, style: stroke)
                        }
                    case .speech(let count):
                        context.stroke(Path(roundedRect: CGRect(x: 3, y: 4, width: 34, height: 27), cornerRadius: 5), with: ink, style: stroke)
                        line(CGPoint(x: 11, y: 31), CGPoint(x: 8, y: 37))
                        line(CGPoint(x: 8, y: 37), CGPoint(x: 20, y: 31))
                        for n in 0..<count { line(CGPoint(x: 11, y: 11 + n * 6), CGPoint(x: 29, y: 11 + n * 6)) }
                    case .face(let feeling):
                        context.stroke(Path(ellipseIn: CGRect(x: 3, y: 3, width: 34, height: 34)), with: ink, style: stroke)
                        for x in [13.0, 25.0] {
                            context.fill(Path(ellipseIn: CGRect(x: x, y: 13, width: 2.5, height: 3)), with: ink)
                        }
                        var mouth = Path(); mouth.move(to: CGPoint(x: 11, y: 25 - feeling * 2))
                        mouth.addQuadCurve(to: CGPoint(x: 29, y: 25 - feeling * 2), control: CGPoint(x: 20, y: 25 + feeling * 12))
                        context.stroke(mouth, with: ink, style: stroke)
                        if feeling <= -0.9 {
                            line(CGPoint(x: 11, y: 11), CGPoint(x: 16, y: 9)); line(CGPoint(x: 24, y: 9), CGPoint(x: 29, y: 11))
                        }
                    case .battery(let level):
                        context.stroke(Path(roundedRect: CGRect(x: 1, y: 11, width: 34, height: 19), cornerRadius: 3), with: ink, style: stroke)
                        context.fill(Path(roundedRect: CGRect(x: 37, y: 17, width: 3, height: 7), cornerRadius: 1), with: ink)
                        for n in 0..<4 {
                            let bar = Path(roundedRect: CGRect(x: 5 + n * 7, y: 15, width: 5, height: 11), cornerRadius: 1)
                            var layer = context; layer.opacity = n < level ? 1 : 0.10
                            layer.fill(bar, with: ink)
                        }
                    case .hungerPlate(let fraction):
                        context.stroke(Path(ellipseIn: CGRect(x: 9, y: 7, width: 24, height: 26)), with: ink, style: stroke)
                        if fraction > 0 {
                            var food = Path(); food.move(to: CGPoint(x: 21, y: 20))
                            food.addArc(center: CGPoint(x: 21, y: 20), radius: 8, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * fraction), clockwise: false)
                            food.closeSubpath(); context.fill(food, with: ink)
                        }
                        for x in [1.0, 4.0, 7.0] { line(CGPoint(x: x, y: 7), CGPoint(x: x, y: 15)) }
                        line(CGPoint(x: 1, y: 15), CGPoint(x: 7, y: 15))
                        line(CGPoint(x: 4, y: 15), CGPoint(x: 4, y: 34))
                        var knife = Path(); knife.move(to: CGPoint(x: 39, y: 7))
                        knife.addQuadCurve(to: CGPoint(x: 35, y: 22), control: CGPoint(x: 34, y: 10))
                        knife.addLine(to: CGPoint(x: 39, y: 22)); knife.addLine(to: CGPoint(x: 39, y: 34))
                        context.stroke(knife, with: ink, style: stroke)
                        line(CGPoint(x: 39, y: 7), CGPoint(x: 39, y: 22))
                    case .plate(let fraction):
                        context.stroke(Path(ellipseIn: CGRect(x: 3, y: 3, width: 34, height: 34)), with: ink, style: stroke)
                        var rim = context; rim.opacity = 0.25
                        rim.stroke(Path(ellipseIn: CGRect(x: 8, y: 8, width: 24, height: 24)), with: ink, lineWidth: 1)
                        if fraction > 0 {
                            var food = Path(); food.move(to: CGPoint(x: 20, y: 20))
                            food.addArc(center: CGPoint(x: 20, y: 20), radius: 10, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * fraction), clockwise: false)
                            food.closeSubpath(); context.fill(food, with: ink)
                        }
                    case .level(let count):
                        for n in 0..<5 {
                            let bar = Path(roundedRect: CGRect(x: 2 + n * 8, y: 31 - n * 5, width: 5, height: 6 + n * 5), cornerRadius: 1)
                            var layer = context; layer.opacity = n < count ? 1 : 0.12
                            layer.fill(bar, with: ink)
                        }
                    case .clock(let minutes):
                        context.stroke(Path(ellipseIn: CGRect(x: 3, y: 3, width: 34, height: 34)), with: ink, style: stroke)
                        let hour = Double(minutes % 720) / 720 * .pi * 2 - .pi / 2
                        let minute = Double(minutes % 60) / 60 * .pi * 2 - .pi / 2
                        line(CGPoint(x: 20, y: 20), CGPoint(x: 20 + cos(hour) * 9, y: 20 + sin(hour) * 9))
                        line(CGPoint(x: 20, y: 20), CGPoint(x: 20 + cos(minute) * 14, y: 20 + sin(minute) * 14))
                    default: break
                    }
                }
            }
        }.accessibilityHidden(true)
    }
}
