import Foundation
import CoreServices
import NaturalLanguage

public struct OfflineMeaningGroup: Sendable {
    public let partOfSpeech: String
    public let definitions: [(definitionEn: String, exampleEn: String?)]
    
    public init(partOfSpeech: String, definitions: [(definitionEn: String, exampleEn: String?)]) {
        self.partOfSpeech = partOfSpeech
        self.definitions = definitions
    }
}

@MainActor
public final class DictionaryService {
    public static let shared = DictionaryService()

    private init() {}

    /// Look up word definition in macOS built-in dictionaries
    public func lookup(term: String) -> String? {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let range = CFRangeMake(0, trimmed.utf16.count)
        guard let defRef = DCSCopyTextDefinition(nil, trimmed as CFString, range) else {
            return nil
        }

        let rawDef = defRef.takeRetainedValue() as String
        let cleaned = rawDef.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
    
    /// Extract IPA phonetic transcription from macOS built-in dictionaries (e.g. | ˈap(ə)l | or / ... /)
    public func extractPhonetic(for term: String) -> String? {
        guard let def = lookup(term: term) else { return nil }
        
        // Pattern 1: | ˈæp.əl |
        let pipePattern = #"\|\s*([^\|]+?)\s*\|"#
        if let regex = try? NSRegularExpression(pattern: pipePattern),
           let match = regex.firstMatch(in: def, range: NSRange(location: 0, length: min(def.utf16.count, 200))),
           let range = Range(match.range(at: 1), in: def) {
            let phonetic = String(def[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !phonetic.isEmpty && !phonetic.contains("\n") {
                return "/\(phonetic)/"
            }
        }
        
        // Pattern 2: / ˈæp.əl /
        let slashPattern = #"\/\s*([^\/]+?)\s*\/"#
        if let regex = try? NSRegularExpression(pattern: slashPattern),
           let match = regex.firstMatch(in: def, range: NSRange(location: 0, length: min(def.utf16.count, 200))),
           let range = Range(match.range(at: 1), in: def) {
            let phonetic = String(def[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !phonetic.isEmpty && !phonetic.contains("\n") {
                return "/\(phonetic)/"
            }
        }
        
        return nil
    }
    
    /// Extracts structured meanings and parts of speech offline from macOS Dictionary & Apple NLP
    public func extractOfflineMeanings(for term: String) -> [OfflineMeaningGroup] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        var groups: [OfflineMeaningGroup] = []
        let cfTerm = trimmed as CFString
        let range = CFRangeMake(0, CFStringGetLength(cfTerm))
        
        if let defRef = DCSCopyTextDefinition(nil, cfTerm, range) {
            let text = defRef.takeRetainedValue() as String
            
            let pattern = #"(?:^|[\|\s])\b(noun|verb|adjective|adverb|pronoun|preposition|conjunction|interjection)\b\s*(?:(?:\([^\)]+\)\s*)*)(.*?)(?=(?:[\|\s])\b(?:noun|verb|adjective|adverb|pronoun|preposition|conjunction|interjection)\b|PHRASES|DERIVATIVES|ORIGIN|$)"#
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let nsString = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: min(nsString.length, 4000)))
                
                var seenPOS = Set<String>()
                for match in matches {
                    guard match.numberOfRanges >= 3 else { continue }
                    let posStr = nsString.substring(with: match.range(at: 1)).lowercased()
                    if seenPOS.contains(posStr) { continue }
                    
                    let bodyStr = nsString.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                    var defItems: [(definitionEn: String, exampleEn: String?)] = []
                    
                    let itemPattern = #"(?:^|\d+\s+|•\s+)([^:•\n]+)(?::\s*([^•\n]+))?"#
                    if let itemRegex = try? NSRegularExpression(pattern: itemPattern, options: []) {
                        let bodyNs = bodyStr as NSString
                        let itemMatches = itemRegex.matches(in: bodyStr, range: NSRange(location: 0, length: min(bodyNs.length, 1000)))
                        for im in itemMatches.prefix(3) {
                            var d = bodyNs.substring(with: im.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                            d = d.replacingOccurrences(of: #"^\[[^\]]+\]\s*"#, with: "", options: .regularExpression)
                            d = d.replacingOccurrences(of: #"^\d+\s+"#, with: "", options: .regularExpression)
                            d = d.replacingOccurrences(of: #"^\[[^\]]+\]\s*"#, with: "", options: .regularExpression)
                            d = d.trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            guard !d.isEmpty, d.count > 3, !d.contains("see also"), !d.hasPrefix("(") else { continue }
                            
                            var ex: String? = nil
                            if im.numberOfRanges > 2 && im.range(at: 2).location != NSNotFound {
                                let candidateEx = bodyNs.substring(with: im.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)
                                if !candidateEx.isEmpty {
                                    ex = candidateEx.components(separatedBy: "|").first?.trimmingCharacters(in: .whitespacesAndNewlines)
                                }
                            }
                            defItems.append((definitionEn: d, exampleEn: ex))
                        }
                    }
                    
                    if !defItems.isEmpty {
                        seenPOS.insert(posStr)
                        groups.append(OfflineMeaningGroup(partOfSpeech: posStr, definitions: defItems))
                    }
                }
            }
        }
        
        // Fallback to Apple NaturalLanguage tagger if no dictionary groups found
        if groups.isEmpty {
            let tagger = NLTagger(tagSchemes: [.lexicalClass])
            tagger.string = trimmed
            let tag = tagger.tag(at: trimmed.startIndex, unit: .word, scheme: .lexicalClass).0
            let posStr: String? = {
                switch tag {
                case .noun: return "noun"
                case .verb: return "verb"
                case .adjective: return "adjective"
                case .adverb: return "adverb"
                case .pronoun: return "pronoun"
                case .preposition: return "preposition"
                case .conjunction: return "conjunction"
                default: return nil
                }
            }()
            if let pos = posStr {
                groups.append(OfflineMeaningGroup(partOfSpeech: pos, definitions: []))
            }
        }
        
        return groups
    }
}
