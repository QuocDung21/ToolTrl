import Foundation

public enum PinyinConverter {
    /// Returns `true` if the string contains at least one CJK Unified Ideograph character.
    public static func containsChineseCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x4E00...0x9FFF,   // CJK Unified Ideographs
                 0x3400...0x4DBF,   // CJK Unified Ideographs Extension A
                 0xF900...0xFAFF,   // CJK Compatibility Ideographs
                 0x20000...0x2A6DF: // CJK Unified Ideographs Extension B
                return true
            default:
                return false
            }
        }
    }

    /// Converts Chinese characters in `text` to Mandarin Pinyin with tone marks.
    /// Returns `nil` if `text` is empty or contains no Chinese characters.
    public static func toPinyin(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, containsChineseCharacters(trimmed) else {
            return nil
        }

        let mutable = NSMutableString(string: trimmed) as CFMutableString
        guard CFStringTransform(mutable, nil, kCFStringTransformMandarinLatin, false) else {
            return nil
        }

        let result = (mutable as String)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !result.isEmpty, result != trimmed else {
            return nil
        }
        return result
    }
}
