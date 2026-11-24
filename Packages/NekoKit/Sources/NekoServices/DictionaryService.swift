import Foundation
import CoreServices
import NaturalLanguage

public struct OfflineDefinitionItem: Sendable {
    public let definition: String
    public let definitionTranslation: String?
    public let example: String?
    public let exampleTranslation: String?
    public let allExamples: [(example: String, translation: String?)]
    public let synonyms: [String]
    
    public init(
        definition: String,
        definitionTranslation: String? = nil,
        example: String? = nil,
        exampleTranslation: String? = nil,
        allExamples: [(example: String, translation: String?)] = [],
        synonyms: [String] = []
    ) {
        self.definition = definition
        self.definitionTranslation = definitionTranslation
        self.example = example ?? allExamples.first?.example
        self.exampleTranslation = exampleTranslation ?? allExamples.first?.translation
        self.allExamples = allExamples.isEmpty && (example != nil) ? [(example!, exampleTranslation)] : allExamples
        self.synonyms = synonyms
    }
}

public struct OfflineMeaningGroup: Sendable {
    public let partOfSpeech: String
    public let items: [OfflineDefinitionItem]
    
    /// Backward-compatibility accessor for (definitionEn, exampleEn)
    public var definitions: [(definitionEn: String, exampleEn: String?)] {
        items.map { ($0.definition, $0.example) }
    }
    
    public init(partOfSpeech: String, items: [OfflineDefinitionItem]) {
        self.partOfSpeech = partOfSpeech
        self.items = items
    }
    
    public init(partOfSpeech: String, definitions: [(definitionEn: String, exampleEn: String?)]) {
        self.partOfSpeech = partOfSpeech
        self.items = definitions.map {
            OfflineDefinitionItem(definition: $0.definitionEn, example: $0.exampleEn)
        }
    }
}

// MARK: - Advanced Offline Dictionary Parser
public enum OfflineDictionaryParser {
    
    public static let vietnameseDiacritics = CharacterSet(
        charactersIn: "àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđĐ"
    )
    
    public static func containsVietnamese(_ text: String) -> Bool {
        return text.unicodeScalars.contains(where: { vietnameseDiacritics.contains($0) })
    }
    
    private static let compiledPOSRegexes: [(regex: NSRegularExpression, canonical: String)] = {
        let patterns: [(String, String)] = [
            (#"(?i)\b(?:danh từ|dt)\b"#, "noun"),
            (#"(?i)\b(?:động từ|ngoại động từ|nội động từ|đt)\b"#, "verb"),
            (#"(?i)\b(?:tính từ|tt)\b"#, "adjective"),
            (#"(?i)\b(?:phó từ|trạng từ)\b"#, "adverb"),
            (#"(?i)\b(?:đại từ)\b"#, "pronoun"),
            (#"(?i)\b(?:giới từ)\b"#, "preposition"),
            (#"(?i)\b(?:liên từ)\b"#, "conjunction"),
            (#"(?i)\b(?:thán từ)\b"#, "interjection"),
            (#"(?i)\bnoun\b"#, "noun"),
            (#"(?i)\bverb\b"#, "verb"),
            (#"(?i)\badjective\b"#, "adjective"),
            (#"(?i)\badverb\b"#, "adverb"),
            (#"(?i)\bpronoun\b"#, "pronoun"),
            (#"(?i)\bpreposition\b"#, "preposition"),
            (#"(?i)\bconjunction\b"#, "conjunction"),
            (#"(?i)\binterjection\b"#, "interjection")
        ]
        return patterns.compactMap { pattern, canonical in
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            return (regex, canonical)
        }
    }()

    private static let numberedChunkRegex = try? NSRegularExpression(pattern: #"(?:^|\s+)(\d+)[\.\s]+(?=[^\d\s])"#)
    private static let bulletChunkRegex = try? NSRegularExpression(pattern: #"(?:^|\s+)[•▸]\s+"#)
    private static let synonymRegex = try? NSRegularExpression(pattern: #"(?i)\b(?:từ đồng nghĩa|synonyms?)\s*[:]?\s*(.*)$"#)
    private static let bilingualPunctRegex = try? NSRegularExpression(
        pattern: #"(?<=[\?\!\.])\s+(?=[A-ZÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ])"#
    )
    
    public static func parse(rawText: String, term: String) -> [OfflineMeaningGroup] {
        var text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return [] }
        
        // 1. Clean phonetic pipes e.g. | ˈkɑntɛkst |
        text = text.replacingOccurrences(of: #"\|[^\|]+\|"#, with: " ", options: .regularExpression)
        
        // 2. Strip metadata trailers: PHRASES, DERIVATIVES, ORIGIN, THESAURUS
        text = text.replacingOccurrences(of: #"(?si)\b(PHRASES|DERIVATIVES|ORIGIN|THESAURUS)\b.*$"#, with: "", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 3. Find all POS markers
        var posMatches: [(location: Int, length: Int, canonical: String)] = []
        let fullNS = text as NSString
        let fullRange = NSRange(location: 0, length: fullNS.length)
        for (regex, canonical) in compiledPOSRegexes {
            let matches = regex.matches(in: text, range: fullRange)
            for m in matches {
                posMatches.append((location: m.range.location, length: m.range.length, canonical: canonical))
            }
        }
        
        posMatches.sort(by: { $0.location < $1.location })
        
        // Filter overlapping POS matches
        var uniquePOSMatches: [(location: Int, length: Int, canonical: String)] = []
        var lastEnd = -1
        for m in posMatches {
            if m.location >= lastEnd {
                uniquePOSMatches.append(m)
                lastEnd = m.location + m.length
            }
        }
        
        var groups: [OfflineMeaningGroup] = []
        let ns = text as NSString
        
        if !uniquePOSMatches.isEmpty {
            for i in 0..<uniquePOSMatches.count {
                let current = uniquePOSMatches[i]
                let start = current.location + current.length
                let end = (i + 1 < uniquePOSMatches.count) ? uniquePOSMatches[i + 1].location : ns.length
                guard end > start else { continue }
                
                let segmentBody = ns.substring(with: NSRange(location: start, length: end - start))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !segmentBody.isEmpty else { continue }
                
                let items = parseSegmentDefinitions(segmentBody)
                if !items.isEmpty {
                    groups.append(OfflineMeaningGroup(partOfSpeech: current.canonical, items: items))
                }
            }
        }
        
        // Fallback: If no POS matches found or groups is empty, use NLTagger to infer POS
        if groups.isEmpty {
            let tagger = NLTagger(tagSchemes: [.lexicalClass])
            tagger.string = term
            let tag = tagger.tag(at: term.startIndex, unit: .word, scheme: .lexicalClass).0
            let posName: String = {
                switch tag {
                case .noun: return "noun"
                case .verb: return "verb"
                case .adjective: return "adjective"
                case .adverb: return "adverb"
                case .pronoun: return "pronoun"
                case .preposition: return "preposition"
                case .conjunction: return "conjunction"
                default: return "noun"
                }
            }()
            
            let items = parseSegmentDefinitions(text)
            if !items.isEmpty {
                groups.append(OfflineMeaningGroup(partOfSpeech: posName, items: items))
            } else {
                groups.append(OfflineMeaningGroup(partOfSpeech: posName, items: [
                    OfflineDefinitionItem(definition: text)
                ]))
            }
        }
        
        return groups
    }
    
    // MARK: - Parse definitions within a POS segment
    private static func parseSegmentDefinitions(_ segment: String) -> [OfflineDefinitionItem] {
        let chunks = splitDefinitionChunks(segment)
        var items: [OfflineDefinitionItem] = []
        for chunk in chunks {
            if let item = parseDefinitionChunk(chunk) {
                items.append(item)
            }
        }
        return items
    }
    
    public static func splitDefinitionChunks(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        // Pattern: Numbered items like " 1 ", " 2 ", " 3 " or at start of string
        guard let regex = numberedChunkRegex else {
            return [trimmed]
        }
        
        let ns = trimmed as NSString
        let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: ns.length))
        
        guard matches.count > 1 else {
            // Check bullet points if no numbers
            if let bulletRegex = bulletChunkRegex {
                let bulletMatches = bulletRegex.matches(in: trimmed, range: NSRange(location: 0, length: ns.length))
                if bulletMatches.count > 1 {
                    var bulletChunks: [String] = []
                    for i in 0..<bulletMatches.count {
                        let start = bulletMatches[i].range.location
                        let end = (i + 1 < bulletMatches.count) ? bulletMatches[i + 1].range.location : ns.length
                        let c = ns.substring(with: NSRange(location: start, length: end - start)).trimmingCharacters(in: .whitespacesAndNewlines)
                        if !c.isEmpty { bulletChunks.append(c) }
                    }
                    if !bulletChunks.isEmpty { return bulletChunks }
                }
            }
            return [trimmed]
        }
        
        var chunks: [String] = []
        for i in 0..<matches.count {
            let start = matches[i].range.location
            let end = (i + 1 < matches.count) ? matches[i + 1].range.location : ns.length
            let chunk = ns.substring(with: NSRange(location: start, length: end - start))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !chunk.isEmpty {
                chunks.append(chunk)
            }
        }
        
        return chunks.isEmpty ? [trimmed] : chunks
    }
    
    public static func parseDefinitionChunk(_ chunk: String) -> OfflineDefinitionItem? {
        var str = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty else { return nil }
        
        // 1. Strip leading number / bullet (e.g. "1 ", "1. ", "• ")
        str = str.replacingOccurrences(of: #"^(\d+[\.\s]+|[•▸]\s*)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !str.isEmpty else { return nil }
        
        // 2. Extract synonyms (từ đồng nghĩa / synonyms)
        var synonyms: [String] = []
        if let synRegex = synonymRegex {
            let ns = str as NSString
            if let match = synRegex.firstMatch(in: str, range: NSRange(location: 0, length: ns.length)) {
                if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: str) {
                    let synText = String(str[range])
                    synonyms = synText.components(separatedBy: CharacterSet(charactersIn: ",;"))
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty && $0.count < 50 }
                }
                str = ns.substring(to: match.range.location).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // 3. Extract examples: split by [▸•]
        let exampleDelimiters = CharacterSet(charactersIn: "▸•")
        let parts = str.components(separatedBy: exampleDelimiters)
        
        let defText = parts.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? str
        guard !defText.isEmpty else { return nil }
        
        var examples: [(example: String, translation: String?)] = []
        
        if parts.count > 1 {
            let rawExamples = parts.dropFirst()
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            for rawEx in rawExamples {
                let split = splitBilingualExample(rawEx)
                if !split.example.isEmpty {
                    examples.append((example: split.example, translation: split.translation))
                }
            }
        } else if defText.contains(":") && !containsVietnamese(defText) {
            // English dictionary format: "definition text: example sentence."
            let subparts = defText.components(separatedBy: ":")
            if subparts.count >= 2 {
                let actualDef = subparts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let actualEx = subparts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                if !actualDef.isEmpty && !actualEx.isEmpty {
                    return OfflineDefinitionItem(
                        definition: actualDef,
                        example: actualEx,
                        synonyms: synonyms
                    )
                }
            }
        }
        
        return OfflineDefinitionItem(
            definition: defText,
            allExamples: examples,
            synonyms: synonyms
        )
    }
    
    // MARK: - Split English sentence and Vietnamese translation in example
    public static func splitBilingualExample(_ text: String) -> (example: String, translation: String?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ("", nil) }
        
        // 1. Check sentence delimiter (. ! ?) followed by whitespace and uppercase/Vietnamese letter
        if let regex = bilingualPunctRegex {
            let ns = trimmed as NSString
            let matches = regex.matches(in: trimmed, range: NSRange(location: 0, length: ns.length))
            if let first = matches.first {
                let p1 = ns.substring(to: first.range.location).trimmingCharacters(in: .whitespacesAndNewlines)
                let p2 = ns.substring(from: first.range.location + first.range.length).trimmingCharacters(in: .whitespacesAndNewlines)
                if !p1.isEmpty && !p2.isEmpty {
                    return (p1, p2)
                }
            }
        }
        
        // 2. Word boundary check: find where English (ASCII) ends and Vietnamese (with diacritics) begins
        let words = trimmed.components(separatedBy: " ")
        var firstViIndex: Int? = nil
        for (idx, w) in words.enumerated() {
            if w.unicodeScalars.contains(where: { vietnameseDiacritics.contains($0) }) {
                firstViIndex = idx
                break
            }
        }
        
        if let viIdx = firstViIndex, viIdx > 0 {
            // Check if the word right before viIdx was a capitalized start of Vietnamese sentence (e.g. "Trong bối cảnh", "Anh có", "Đừng")
            var splitIdx = viIdx
            let prevWord = words[viIdx - 1]
            if prevWord.first?.isUppercase == true && !prevWord.allSatisfy({ $0.isUppercase }) {
                splitIdx = viIdx - 1
            }
            
            if splitIdx > 0 && splitIdx < words.count {
                let en = words[0..<splitIdx].joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                let vi = words[splitIdx..<words.count].joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                if !en.isEmpty && !vi.isEmpty {
                    return (en, vi)
                }
            }
        }
        
        return (trimmed, nil)
    }
}

// MARK: - DictionaryService Main Class
@MainActor
public final class DictionaryService {
    public static let shared = DictionaryService()

    private static let pipePhoneticRegex = try? NSRegularExpression(pattern: #"\|\s*([^\|]+?)\s*\|"#)
    private static let slashPhoneticRegex = try? NSRegularExpression(pattern: #"\/\s*([^\/]+?)\s*\/"#)

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
        if let regex = Self.pipePhoneticRegex,
           let match = regex.firstMatch(in: def, range: NSRange(location: 0, length: min(def.utf16.count, 200))),
           let range = Range(match.range(at: 1), in: def) {
            let phonetic = String(def[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !phonetic.isEmpty && !phonetic.contains("\n") {
                return IPANormalizer.normalize(phonetic, forWord: term)
            }
        }
        
        // Pattern 2: / ˈæp.əl /
        if let regex = Self.slashPhoneticRegex,
           let match = regex.firstMatch(in: def, range: NSRange(location: 0, length: min(def.utf16.count, 200))),
           let range = Range(match.range(at: 1), in: def) {
            let phonetic = String(def[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !phonetic.isEmpty && !phonetic.contains("\n") {
                return IPANormalizer.normalize(phonetic, forWord: term)
            }
        }
        
        return nil
    }
    
    /// Extracts structured meanings and parts of speech offline from macOS Dictionary & Apple NLP
    public func extractOfflineMeanings(for term: String) -> [OfflineMeaningGroup] {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        
        guard let rawDef = lookup(term: trimmed) else { return [] }
        return OfflineDictionaryParser.parse(rawText: rawDef, term: trimmed)
    }
}
