import Foundation
import CoreFoundation

enum NoteText {
    // A reversible display conversion, not a second speech recognizer.
    // Preserve punctuation, whitespace, numbers, Latin text and unknown words.
    static func hiragana(_ text: String) -> String {
        let source = text as NSString
        let tokenizer = CFStringTokenizerCreate(nil, text as CFString,
            CFRange(location: 0, length: source.length),
            kCFStringTokenizerUnitWord | kCFStringTokenizerAttributeLatinTranscription,
            Locale(identifier: "ja") as CFLocale)
        var output = ""
        var end = 0
        while !CFStringTokenizerAdvanceToNextToken(tokenizer).isEmpty {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            guard range.location >= end, range.length > 0 else { continue }
            output += source.substring(with: NSRange(location: end, length: range.location - end))
            let original = source.substring(with: NSRange(location: range.location, length: range.length))
            let containsKanji = original.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) }
            if containsKanji, let latin = CFStringTokenizerCopyCurrentTokenAttribute(tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String,
               let reading = latin.applyingTransform(StringTransform("Latin-Hiragana"), reverse: false) {
                output += reading
            } else {
                output += String(String.UnicodeScalarView(original.unicodeScalars.map { scalar in
                    if (0x30A1...0x30F6).contains(scalar.value) || (0x30FD...0x30FE).contains(scalar.value) {
                        return UnicodeScalar(scalar.value - 0x60)!
                    }
                    return scalar
                }))
            }
            end = range.location + range.length
        }
        output += source.substring(from: end)
        return output
    }
}
