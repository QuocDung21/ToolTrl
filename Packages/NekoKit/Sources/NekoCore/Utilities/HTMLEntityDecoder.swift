import Foundation

/// Fast and comprehensive HTML entity decoder.
public enum HTMLEntityDecoder {
    private static let decimalRegex = try? NSRegularExpression(pattern: #"&#([0-9]{1,6});"#)
    private static let hexRegex = try? NSRegularExpression(pattern: #"&#[xX]([0-9a-fA-F]{1,6});"#)

    public static func decode(_ string: String) -> String {
        guard string.contains("&") else { return string }

        var result = string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&rsquo;", with: "’")
            .replacingOccurrences(of: "&lsquo;", with: "‘")
            .replacingOccurrences(of: "&rdquo;", with: "”")
            .replacingOccurrences(of: "&ldquo;", with: "“")
            .replacingOccurrences(of: "&ndash;", with: "–")
            .replacingOccurrences(of: "&mdash;", with: "—")
            .replacingOccurrences(of: "&hellip;", with: "…")

        // Decode decimal entities &#123;
        if result.contains("&#") {
            if let regex = decimalRegex {
                let matches = regex.matches(in: result, range: NSRange(location: 0, length: result.utf16.count)).reversed()
                for match in matches {
                    if let codeRange = Range(match.range(at: 1), in: result),
                       let code = UInt32(result[codeRange]),
                       let scalar = UnicodeScalar(code),
                       let entityRange = Range(match.range, in: result) {
                        result.replaceSubrange(entityRange, with: String(Character(scalar)))
                    }
                }
            }

            // Decode hex entities &#x1F600;
            if let regex = hexRegex {
                let matches = regex.matches(in: result, range: NSRange(location: 0, length: result.utf16.count)).reversed()
                for match in matches {
                    if let codeRange = Range(match.range(at: 1), in: result),
                       let code = UInt32(result[codeRange], radix: 16),
                       let scalar = UnicodeScalar(code),
                       let entityRange = Range(match.range, in: result) {
                        result.replaceSubrange(entityRange, with: String(Character(scalar)))
                    }
                }
            }
        }

        return result
    }
}
