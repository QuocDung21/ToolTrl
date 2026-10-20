import Foundation
import NaturalLanguage

/// Query content type classification
public enum QueryContentType: String, Sendable {
    case word
    case sentence
    case code
}

/// Advanced text normalizer and intelligent query classifier for NekoTrans.
/// Inherited and adapted from Easydict's `String+HandleInputText`, `String+Split`, and `AppleLanguageDetector`.
public enum InputTextNormalizer {

    // MARK: - 1. Main Normalization Entry Point

    /// Cleans and prepares raw user/grabbed text for optimal translation and dictionary lookup.
    /// - Strips code comments (//, /* */, #)
    /// - Strips quotes and surrounding delimiters
    /// - Splits camelCase and snake_case identifiers if it looks like code
    public static func normalize(_ rawText: String) -> String {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }

        // 1. Strip surrounding quotes and delimiters
        text = stripSurroundingQuotes(text)

        // 2. Remove code comments if text begins with or consists of comments
        text = stripCommentSymbols(text)

        // 3. If text is a single identifier that looks like code, split it
        if isCodeIdentifier(text) {
            text = splitCodeIdentifiers(text)
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 2. Code Identifier Splitting (camelCase & snake_case)

    /// Splits camelCase, PascalCase, and snake_case identifiers into natural space-separated words.
    /// Examples:
    /// - "getUserProfile" -> "get User Profile"
    /// - "XMLHttpRequest" -> "XML Http Request"
    /// - "is_authenticated_user" -> "is authenticated user"
    /// - "API_KEY_SECRET" -> "API KEY SECRET"
    public static func splitCodeIdentifiers(_ text: String) -> String {
        // First split snake_case
        let snakeSplit = text.replacingOccurrences(of: "_", with: " ")

        // Then split camelCase
        var result = ""
        let chars = Array(snakeSplit)

        for i in 0..<chars.count {
            let current = chars[i]
            if current.isUppercase {
                if i > 0 {
                    let prev = chars[i - 1]
                    if prev.isLowercase {
                        result.append(" ")
                    } else if prev.isUppercase && i + 1 < chars.count && chars[i + 1].isLowercase {
                        result.append(" ")
                    }
                }
            }
            result.append(current)
        }

        // Collapse multiple spaces
        let words = result.split(separator: " ").filter { !$0.isEmpty }
        return words.joined(separator: " ")
    }

    /// Checks if a string looks like a single code identifier (camelCase, snake_case, etc.)
    public static func isCodeIdentifier(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(" "), trimmed.count >= 3 else { return false }

        // Contains underscore
        if trimmed.contains("_") && trimmed.contains(where: \.isLetter) {
            return true
        }

        // Contains camelCase: has at least one uppercase not at the start
        let chars = Array(trimmed)
        if chars.first?.isLetter == true {
            for i in 1..<chars.count {
                if chars[i].isUppercase && (chars[i - 1].isLowercase || (i + 1 < chars.count && chars[i + 1].isLowercase)) {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - 3. Code Comment Stripping

    /// Strips line and block comment markers (`//`, `/*`, `*/`, `#`, `*`) from text
    public static func stripCommentSymbols(_ text: String) -> String {
        var str = text

        // Remove inline block comments /* ... */
        str = str.replacingOccurrences(of: "/*", with: "")
        str = str.replacingOccurrences(of: "*/", with: "")

        // Process line by line for line comments
        let lines = str.components(separatedBy: .newlines)
        let cleanedLines = lines.map { line -> String in
            var l = line.trimmingCharacters(in: .whitespaces)
            // Strip // or ///
            if l.hasPrefix("//") {
                l = l.replacingOccurrences(of: #"^//+\s*"#, with: "", options: .regularExpression)
            }
            // Strip # (Python/Ruby/Bash/Markdown comments)
            else if l.hasPrefix("#") && !l.hasPrefix("##") {
                l = l.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)
            }
            // Strip leading * from docstring blocks
            else if l.hasPrefix("* ") || l == "*" {
                l = l.replacingOccurrences(of: #"^\*+\s*"#, with: "", options: .regularExpression)
            }
            return l
        }

        return cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 4. Surrounding Quotes Stripping

    /// Strips matching surrounding quotes ("...", '...', `...`, (...))
    public static func stripSurroundingQuotes(_ text: String) -> String {
        var str = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (str.hasPrefix("\"") && str.hasSuffix("\"") && str.count >= 2) ||
           (str.hasPrefix("'") && str.hasSuffix("'") && str.count >= 2) ||
           (str.hasPrefix("`") && str.hasSuffix("`") && str.count >= 2) ||
           (str.hasPrefix("“") && str.hasSuffix("”") && str.count >= 2) ||
           (str.hasPrefix("‘") && str.hasSuffix("’") && str.count >= 2) {
            str = String(str.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return str
    }

    // MARK: - 5. Query Content Classification

    /// Classifies text into .word, .sentence, or .code
    public static func classify(_ text: String) -> QueryContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .word }

        if isCodeIdentifier(trimmed) {
            return .code
        }

        let words = trimmed.split(separator: " ").filter { !$0.isEmpty }
        let hasSentencePunctuation = [".", "!", "?", "\n", ";"].contains { trimmed.contains($0) }

        if words.count <= 2 && !hasSentencePunctuation {
            return .word
        }

        return .sentence
    }

    // MARK: - 6. Bi-directional Target Language Auto-Flip

    /// Automatically flips the translation direction based on the detected source language.
    /// - If source is English -> Target is Vietnamese (or user default)
    /// - If source is Vietnamese -> Target is English
    /// - If source is another language -> Target is Vietnamese (or user default)
    public static func resolveTargetLanguage(
        sourceLanguageCode: String,
        configuredTarget: TargetLanguage
    ) -> TargetLanguage {
        let cleanSource = sourceLanguageCode.lowercased()

        // If source matches configured target, automatically flip:
        if cleanSource == configuredTarget.rawValue {
            return configuredTarget == .vietnamese ? .english : .vietnamese
        }

        if cleanSource == "vi" {
            // Source is Vietnamese -> Translate to configured target or default to English
            return configuredTarget == .vietnamese ? .english : configuredTarget
        } else if cleanSource == "en" || cleanSource == "und" || cleanSource.isEmpty {
            // Source is English/Undetermined -> Translate to user's configured target, or default to Vietnamese
            return configuredTarget == .english ? .vietnamese : configuredTarget
        } else {
            // Source is other (Japanese, French, etc.) -> Translate to user's configured target
            return configuredTarget
        }
    }

    // MARK: - 7. Part-of-Speech Standardization (Inherited from Easydict)

    /// Converts a raw part-of-speech string (English or Vietnamese) to its standard abbreviated form (e.g. "n.", "v.", "adj.").
    public static func partAbbreviation(_ rawPart: String) -> String {
        let clean = rawPart.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return "" }

        let map: [(abbr: String, keywords: [String])] = [
            ("adj.", ["adjective", "adj", "tính từ", "tt", "adjectival"]),
            ("adv.", ["adverb", "adv", "phó từ", "trạng từ", "adverbial"]),
            ("v.", ["verb", "v", "động từ", "đt", "nội động từ", "ngoại động từ", "transitive verb", "intransitive verb"]),
            ("linkv.", ["linkv", "linking verb"]),
            ("auxv.", ["auxv", "auxiliary verb", "trợ động từ"]),
            ("modalv.", ["modalv", "modal verb", "động từ tình thái"]),
            ("n.", ["noun", "n", "danh từ", "dt", "danh từ đếm được", "danh từ không đếm được"]),
            ("pron.", ["pronoun", "pron", "đại từ"]),
            ("prep.", ["preposition", "prep", "giới từ"]),
            ("conj.", ["conjunction", "conj", "liên từ"]),
            ("int.", ["interjection", "interj", "int", "thán từ"]),
            ("art.", ["article", "art", "mạo từ"]),
            ("abbr.", ["abbreviation", "abbr", "từ viết tắt", "viết tắt"]),
            ("num.", ["numeral", "num", "số từ"])
        ]

        for item in map {
            if item.keywords.contains(where: { clean == $0 || clean.hasPrefix($0) }) {
                return item.abbr
            }
        }

        if clean.hasSuffix(".") {
            return clean
        }
        return "\(clean)."
    }

    /// Converts a part-of-speech string or abbreviation to its localized human-friendly name.
    public static func partFullName(_ rawPart: String) -> String {
        let abbr = partAbbreviation(rawPart)
        switch abbr {
        case "n.": return "Danh từ"
        case "v.": return "Động từ"
        case "adj.": return "Tính từ"
        case "adv.": return "Phó từ / Trạng từ"
        case "pron.": return "Đại từ"
        case "prep.": return "Giới từ"
        case "conj.": return "Liên từ"
        case "int.": return "Thán từ"
        case "art.": return "Mạo từ"
        case "abbr.": return "Từ viết tắt"
        case "num.": return "Số từ"
        case "auxv.": return "Trợ động từ"
        case "modalv.": return "Động từ tình thái"
        default: return rawPart.capitalized
        }
    }
}
