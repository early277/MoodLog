import AppKit

let url = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

// Draw into an explicit bitmap context before exporting the icon.
let side = 1024
let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                        bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let paper = CGColor(srgbRed: 0.96, green: 0.97, blue: 0.95, alpha: 1)
let green = CGColor(srgbRed: 0.14, green: 0.39, blue: 0.34, alpha: 1)
context.setFillColor(paper)
context.fill(CGRect(x: 0, y: 0, width: side, height: side))
context.setStrokeColor(green)
context.setFillColor(green)
context.setLineWidth(40)
context.setLineCap(.round)
context.strokeEllipse(in: CGRect(x: 242, y: 382, width: 540, height: 540))

for x in [416.0, 582.0] {
    context.fillEllipse(in: CGRect(x: x, y: 684, width: 26, height: 36))
}
context.move(to: CGPoint(x: 400, y: 570))
context.addQuadCurve(to: CGPoint(x: 624, y: 570), control: CGPoint(x: 512, y: 466))
context.strokePath()

// Two lines suggest the saved log beneath the mood symbol.
for (y, end) in [(270.0, 724.0), (174.0, 620.0)] {
    context.move(to: CGPoint(x: 300, y: y))
    context.addLine(to: CGPoint(x: end, y: y))
    context.strokePath()
}
context.flush()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
try bitmap.representation(using: .png, properties: [:])!.write(to: url.appendingPathComponent("AppIcon.png"))
try "{\"images\":[{\"filename\":\"AppIcon.png\",\"idiom\":\"universal\",\"platform\":\"ios\",\"size\":\"1024x1024\"}],\"info\":{\"author\":\"xcode\",\"version\":1}}".write(to: url.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
