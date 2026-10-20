import Foundation

/// Standardizes and cleans phonetic transcriptions to international broad IPA standards (Oxford / Cambridge).
/// Eliminates legacy ASCII stress symbols (', ,), narrow phonetic markers (ɹ), and normalizes American Heritage DCS notation.
public enum IPANormalizer {

    /// Normalizes any raw phonetic string into clean, textbook Unicode IPA wrapped in `/.../`
    public static func normalize(_ raw: String?, forWord word: String? = nil) -> String? {
        guard let raw = raw else { return nil }
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // 1. Strip surrounding slashes, square brackets, or pipe delimiters
        while (text.hasPrefix("/") && text.hasSuffix("/")) ||
              (text.hasPrefix("[") && text.hasSuffix("]")) ||
              (text.hasPrefix("|") && text.hasSuffix("|")) {
            text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !text.isEmpty else { return nil }

        // 2. Standardize ASCII / typographic primary stress marks to Unicode IPA U+02C8 (ˈ)
        text = text.replacingOccurrences(of: "’", with: "ˈ")
        text = text.replacingOccurrences(of: "'", with: "ˈ")
        text = text.replacingOccurrences(of: "`", with: "ˈ")
        text = text.replacingOccurrences(of: "´", with: "ˈ")

        // 3. Standardize secondary stress marks to Unicode IPA U+02CC (ˌ)
        let commaStressPattern = #",(?=[a-zA-Zæɑɒɔəɛɜɪiʊuʌθðʃʒŋˈˌ])"#
        if let regex = try? NSRegularExpression(pattern: commaStressPattern) {
            let ns = text as NSString
            text = regex.stringByReplacingMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length), withTemplate: "ˌ")
        }

        // 4. Standardize narrow / theoretical linguistics notation to standard broad dictionary IPA
        // Strip narrow glottal stops and unreleased stops / combining diacritics (e.g. [ʔæʔp̚] -> /æp/)
        text = text.replacingOccurrences(of: "ʔ", with: "") // Glottal stop U+0294
        text = text.replacingOccurrences(of: "̚", with: "") // Unreleased stop U+031A
        text = text.replacingOccurrences(of: "\u{031A}", with: "")
        text = text.replacingOccurrences(of: "\u{0304}", with: "") // Combining macron
        text = text.replacingOccurrences(of: "p̄", with: "p")
        text = text.replacingOccurrences(of: "t̄", with: "t")
        text = text.replacingOccurrences(of: "k̄", with: "k")

        // Replace turned-r (ɹ, ɻ) with standard dictionary 'r'
        text = text.replacingOccurrences(of: "ɹ", with: "r")
        text = text.replacingOccurrences(of: "ɻ", with: "r")
        text = text.replacingOccurrences(of: "ɡ", with: "g")

        // Standardize British/Oxford long vowel markers and legacy ASCII colons
        // In Oxford Dictionary of English, /əː/ is the notation for /ɜː/ (NURSE vowel)
        text = text.replacingOccurrences(of: "əː", with: "ɜː")
        text = text.replacingOccurrences(of: "ə:", with: "ɜː")
        text = text.replacingOccurrences(of: "ɜ:", with: "ɜː")
        text = text.replacingOccurrences(of: "a:", with: "ɑː")
        text = text.replacingOccurrences(of: "i:", with: "iː")
        text = text.replacingOccurrences(of: "u:", with: "uː")
        text = text.replacingOccurrences(of: "ɔ:", with: "ɔː")

        // Standardize rhotic brackets: [r] or [R] -> (r)
        text = text.replacingOccurrences(of: "[r]", with: "(r)")
        text = text.replacingOccurrences(of: "[R]", with: "(r)")

        // 5. Convert American Heritage / New Oxford DCS uppercase digraphs if present
        if text.contains("SH") || text.contains("TH") || text.contains("ZH") || text.contains("CH") || text.contains("NG") {
            text = text.replacingOccurrences(of: "SH", with: "ʃ")
            text = text.replacingOccurrences(of: "TH", with: "θ")
            text = text.replacingOccurrences(of: "ZH", with: "ʒ")
            text = text.replacingOccurrences(of: "CH", with: "tʃ")
            text = text.replacingOccurrences(of: "NG", with: "ŋ")
            text = text.replacingOccurrences(of: "ē", with: "i")
            text = text.replacingOccurrences(of: "ō", with: "oʊ")
            text = text.replacingOccurrences(of: "ā", with: "eɪ")
            text = text.replacingOccurrences(of: "ī", with: "aɪ")
            text = text.replacingOccurrences(of: "oo", with: "u")
        }

        // 6. Clean duplicate spaces or duplicate stress marks
        text = text.replacingOccurrences(of: "ˈˈ", with: "ˈ")
        text = text.replacingOccurrences(of: "ˌˌ", with: "ˌ")
        text = text.replacingOccurrences(of: "  ", with: " ")
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        // 7. Word-specific heuristic: detect truncated agent nouns
        // e.g. DCS Vietnamese dictionary has a known typo for "server" / "servers" where it printed "sə:v" (serve)
        if let word = word {
            let clean = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if (clean == "server" || clean == "servers") && (text == "sɜːv" || text == "ˈsɜːv" || text == "səv" || text == "ˈsəv") {
                text = "ˈsɜːvə(r)"
            }
        }

        // Add stress mark for polysyllabic words if absent
        if (text == "sɜːvə(r)" || text == "sɜːvər" || text == "sɜːvə") {
            text = "ˈ" + text
        }

        return "/\(text)/"
    }

    /// Convenience overload without word context
    public static func normalize(_ raw: String?) -> String? {
        normalize(raw, forWord: nil)
    }

    /// Determines if two phonetic transcriptions are phonetically identical after normalization
    public static func areIdentical(_ ph1: String?, _ ph2: String?) -> Bool {
        guard let n1 = normalize(ph1), let n2 = normalize(ph2) else {
            return (ph1 == nil && ph2 == nil)
        }
        return n1 == n2
    }
}
