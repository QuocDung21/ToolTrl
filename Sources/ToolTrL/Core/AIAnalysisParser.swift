import SwiftUI
import AppKit

// MARK: - Parsed Structured AI Analysis Models
public struct ParsedWordFamilyItem: Identifiable {
    public var id = UUID()
    public let pos: String // Noun, Verb, Adj, Adv, etc.
    public let words: String
    public let meaning: String
}

public struct ParsedCollocationItem: Identifiable {
    public var id = UUID()
    public let phrase: String
    public let meaning: String
    public let example: String?
}

public struct ParsedAIAnalysis {
    public var meanings: [String] = []
    public var wordFamily: [ParsedWordFamilyItem] = []
    public var collocations: [ParsedCollocationItem] = []
    public var nuances: [String] = []
    public var examples: [(en: String, vi: String)] = []
    public var mnemonic: String? = nil
    public var rawContent: String = ""
    
    public var isEmpty: Bool {
        meanings.isEmpty && wordFamily.isEmpty && collocations.isEmpty && nuances.isEmpty && examples.isEmpty && mnemonic == nil
    }
}

// MARK: - Smart AI Analysis Text Parser
public enum AIAnalysisParser {
    public static func parse(_ rawText: String) -> ParsedAIAnalysis {
        var result = ParsedAIAnalysis()
        result.rawContent = rawText
        
        let lines = rawText.components(separatedBy: .newlines)
        var currentSection = 0 // 1: Meanings, 2: Word Family, 3: Collocations, 4: Nuances, 5: Examples, 6: Mnemonic
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            
            let lower = line.lowercased()
            
            // Section Headers Detection
            if lower.contains("từ loại") || lower.contains("tầng nghĩa") || lower.contains("định nghĩa") {
                currentSection = 1
                continue
            } else if lower.contains("họ từ") || lower.contains("word family") {
                currentSection = 2
                continue
            } else if lower.contains("collocation") || lower.contains("thành ngữ") || lower.contains("cụm từ") {
                currentSection = 3
                continue
            } else if lower.contains("sắc thái") || lower.contains("phân biệt") || lower.contains("nuance") || lower.contains("lưu ý") {
                currentSection = 4
                continue
            } else if lower.contains("ví dụ") || lower.contains("example") {
                currentSection = 5
                continue
            } else if lower.contains("mẹo ghi nhớ") || lower.contains("mnemonic") || lower.contains("gốc từ") || lower.contains("etymology") {
                currentSection = 6
                continue
            }
            
            // Content processing by active section
            switch currentSection {
            case 1:
                let cleaned = cleanBullet(line)
                if !cleaned.isEmpty {
                    result.meanings.append(cleaned)
                }
                
            case 2:
                // Parse "Danh từ (Noun): annual — ấn phẩm..."
                let cleaned = cleanBullet(line)
                if cleaned.contains(":") || cleaned.contains("—") || cleaned.contains("-") {
                    let parts = cleaned.components(separatedBy: CharacterSet(charactersIn: ":—-"))
                    if parts.count >= 2 {
                        let pos = parts[0].trimmingCharacters(in: .whitespaces)
                        let rest = parts.dropFirst().joined(separator: " — ").trimmingCharacters(in: .whitespaces)
                        result.wordFamily.append(ParsedWordFamilyItem(pos: pos, words: rest, meaning: ""))
                    } else {
                        result.wordFamily.append(ParsedWordFamilyItem(pos: "Từ liên quan", words: cleaned, meaning: ""))
                    }
                } else if !cleaned.isEmpty {
                    result.wordFamily.append(ParsedWordFamilyItem(pos: "Liên quan", words: cleaned, meaning: ""))
                }
                
            case 3:
                // Parse Collocations
                let cleaned = cleanBullet(line)
                if cleaned.contains("—") || cleaned.contains("->") || cleaned.contains("→") || cleaned.contains(":") {
                    let parts = cleaned.components(separatedBy: CharacterSet(charactersIn: "—->→:"))
                    let phrase = parts[0].trimmingCharacters(in: .whitespaces)
                    let rest = parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    result.collocations.append(ParsedCollocationItem(phrase: phrase, meaning: rest, example: nil))
                } else if !cleaned.isEmpty {
                    result.collocations.append(ParsedCollocationItem(phrase: cleaned, meaning: "", example: nil))
                }
                
            case 4:
                let cleaned = cleanBullet(line)
                if !cleaned.isEmpty {
                    result.nuances.append(cleaned)
                }
                
            case 5:
                let cleaned = cleanBullet(line)
                if cleaned.contains("->") || cleaned.contains("→") || cleaned.contains("—") {
                    let parts = cleaned.components(separatedBy: CharacterSet(charactersIn: "->→—"))
                    let en = parts[0].trimmingCharacters(in: .whitespaces)
                    let vi = parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespaces)
                    result.examples.append((en: en, vi: vi))
                } else if !cleaned.isEmpty {
                    result.examples.append((en: cleaned, vi: ""))
                }
                
            case 6:
                let cleaned = cleanBullet(line)
                if !cleaned.isEmpty {
                    if let existing = result.mnemonic {
                        result.mnemonic = existing + "\n" + cleaned
                    } else {
                        result.mnemonic = cleaned
                    }
                }
                
            default:
                break
            }
        }
        
        return result
    }
    
    private static func cleanBullet(_ text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespaces)
        // Remove leading numbers or bullets like "1.", "2.", "•", "-", "*"
        if let match = s.range(of: #"^(\d+\.|\*|-|•|\+)\s*"#, options: .regularExpression) {
            s.removeSubrange(match)
        }
        return s.trimmingCharacters(in: .whitespaces)
    }
}
