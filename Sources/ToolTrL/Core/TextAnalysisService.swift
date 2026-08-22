import Foundation
import NaturalLanguage
import SwiftUI

public enum VocabImportance: String, Codable, Sendable, CaseIterable {
    case core = "Cốt lõi"
    case collocation = "Cụm từ"
    case advanced = "Nâng cao"
    
    public var displayName: String {
        switch self {
        case .core: return "🌟 Từ Vựng Cốt Lõi"
        case .collocation: return "💡 Cụm Từ & Thành Ngữ"
        case .advanced: return "📖 Từ Vựng Nâng Cao"
        }
    }
    
    public var badgeColor: Color {
        switch self {
        case .core: return .orange
        case .collocation: return .purple
        case .advanced: return .blue
        }
    }
}

public enum POSCategory: String, Codable, Sendable, CaseIterable {
    case noun = "Danh từ"
    case verb = "Động từ"
    case adjective = "Tính từ"
    case adverb = "Trạng từ"
    case phrase = "Cụm từ"
    case other = "Khác"
    
    public var color: Color {
        switch self {
        case .noun: return .blue
        case .verb: return .green
        case .adjective: return .orange
        case .adverb: return .pink
        case .phrase: return .purple
        case .other: return .secondary
        }
    }
}

public struct ExtractedVocabulary: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var word: String
    public var partOfSpeech: String
    public var posCategory: POSCategory
    public var importance: VocabImportance
    public var phonetic: String?
    public var vietnameseMeaning: String
    public var contextSentence: String
    public var orderIndex: Int
    public var isSelected: Bool = true
    
    public init(
        id: UUID = UUID(),
        word: String,
        partOfSpeech: String,
        posCategory: POSCategory = .other,
        importance: VocabImportance = .core,
        phonetic: String? = nil,
        vietnameseMeaning: String,
        contextSentence: String,
        orderIndex: Int = 0,
        isSelected: Bool = true
    ) {
        self.id = id
        self.word = word
        self.partOfSpeech = partOfSpeech
        self.posCategory = posCategory
        self.importance = importance
        self.phonetic = phonetic
        self.vietnameseMeaning = vietnameseMeaning
        self.contextSentence = contextSentence
        self.orderIndex = orderIndex
        self.isSelected = isSelected
    }
}

public struct ExtractedGrammarFormula: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var formula: String
    public var title: String
    public var meaningVi: String
    public var exampleSentence: String
    public var isSelected: Bool = true
    
    public init(
        id: UUID = UUID(),
        formula: String,
        title: String,
        meaningVi: String,
        exampleSentence: String,
        isSelected: Bool = true
    ) {
        self.id = id
        self.formula = formula
        self.title = title
        self.meaningVi = meaningVi
        self.exampleSentence = exampleSentence
        self.isSelected = isSelected
    }
}

public struct TextAnalysisResult: Identifiable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var originalParagraph: String
    public var vocabularies: [ExtractedVocabulary]
    public var grammars: [ExtractedGrammarFormula]
    
    public init(
        id: UUID = UUID(),
        originalParagraph: String,
        vocabularies: [ExtractedVocabulary],
        grammars: [ExtractedGrammarFormula]
    ) {
        self.id = id
        self.originalParagraph = originalParagraph
        self.vocabularies = vocabularies
        self.grammars = grammars
    }
}

@MainActor
public final class TextAnalysisService: ObservableObject {
    public static let shared = TextAnalysisService()
    
    @Published public var isAnalyzing: Bool = false
    @Published public var lastResult: TextAnalysisResult? = nil
    
    private init() {}
    
    // MARK: - Grammar Rule Definitions
    private struct GrammarRule {
        let patternRegex: String
        let formula: String
        let title: String
        let meaningVi: String
    }
    
    private let grammarRules: [GrammarRule] = [
        GrammarRule(
            patternRegex: "(?i)\\bif\\b.*\\b(had|hadn't)\\s+[a-z]+(ed|en|t)\\b.*\\bwould\\s+have\\s+[a-z]+(ed|en|t)\\b",
            formula: "If + S + had + V3/ed, S + would have + V3/ed",
            title: "Câu điều kiện loại 3 (Conditional Type 3)",
            meaningVi: "Diễn tả sự việc trái ngược với thực tế trong quá khứ."
        ),
        GrammarRule(
            patternRegex: "(?i)\\bif\\b.*\\b(were|weren't|[a-z]+ed)\\b.*\\b(would|could|might)\\b",
            formula: "If + S + V2/ed (were), S + would/could + V-bare",
            title: "Câu điều kiện loại 2 (Conditional Type 2)",
            meaningVi: "Diễn tả điều kiện không có thật ở hiện tại hoặc tương lai."
        ),
        GrammarRule(
            patternRegex: "(?i)\\bif\\b.*\\b(will|can|may)\\b",
            formula: "If + S + V(s/es), S + will/can + V-bare",
            title: "Câu điều kiện loại 1 (Conditional Type 1)",
            meaningVi: "Diễn tả sự việc có thể xảy ra ở hiện tại hoặc tương lai."
        ),
        GrammarRule(
            patternRegex: "(?i)\\b(wish|wishes|wished)\\b.*\\b(had|hadn't)\\s+[a-z]+(ed|en|t)\\b",
            formula: "S + wish(es) + (that) + S + had + V3/ed",
            title: "Cấu trúc Ước trong quá khứ (Wish in Past)",
            meaningVi: "Diễn tả sự tiếc nuối về một việc đã xảy ra hoặc không xảy ra trong quá khứ."
        ),
        GrammarRule(
            patternRegex: "(?i)\\b(wish|wishes)\\b.*\\b(were|[a-z]+ed|could)\\b",
            formula: "S + wish(es) + (that) + S + V2/ed (were)",
            title: "Cấu trúc Ước ở hiện tại (Wish in Present)",
            meaningVi: "Diễn tả mong muốn một điều trái ngược với thực tế hiện tại."
        ),
        GrammarRule(
            patternRegex: "(?i)\\bwould\\s+rather\\b.*\\b(than|that)\\b",
            formula: "S + would rather (+ V-bare) + than (+ V-bare)",
            title: "Cấu trúc Thích hơn (Would rather)",
            meaningVi: "Diễn đạt sở thích hoặc mong muốn giữa hai lựa chọn."
        ),
        GrammarRule(
            patternRegex: "(?i)\\bused\\s+to\\s+[a-z]+\\b",
            formula: "S + used to + V-bare",
            title: "Cấu trúc Đã từng (Used to)",
            meaningVi: "Diễn tả thói quen hoặc trạng thái trong quá khứ nhưng nay không còn nữa."
        ),
        GrammarRule(
            patternRegex: "(?i)\\b(am|is|are|was|were|get|got)\\s+used\\s+to\\s+[a-z]+ing\\b",
            formula: "S + be/get used to + V-ing / Noun",
            title: "Cấu trúc Quen với việc gì (Be/Get used to)",
            meaningVi: "Diễn tả việc đã quen dần hoặc cảm thấy bình thường với một hành động."
        ),
        GrammarRule(
            patternRegex: "(?i)\\bso\\s+[a-z]+\\s+that\\b",
            formula: "S + be/V + so + Adj/Adv + that + Clause",
            title: "Cấu trúc Quá... đến mức mà...",
            meaningVi: "Chỉ nguyên nhân và kết quả có mức độ mạnh."
        ),
        GrammarRule(
            patternRegex: "(?i)\\bsuch\\s+(a|an)?\\s*[a-z]+\\s+[a-z]+\\s+that\\b",
            formula: "S + V + such + (a/an) + Adj + N + that + Clause",
            title: "Cấu trúc Such... that...",
            meaningVi: "Nhấn mạnh tính chất của danh từ dẫn đến một kết quả."
        ),
        GrammarRule(
            patternRegex: "(?i)\\b(in spite of|despite)\\b",
            formula: "Despite / In spite of + Noun / V-ing, Clause",
            title: "Cấu trúc Mặc dù (Despite / In spite of)",
            meaningVi: "Chỉ sự nhượng bộ, tương phản giữa hai mệnh đề."
        ),
        GrammarRule(
            patternRegex: "(?i)\\b(although|even though|though)\\b",
            formula: "Although / Even though + S + V, Clause",
            title: "Mệnh đề nhượng bộ (Although / Even though)",
            meaningVi: "Mặc dù... nhưng..."
        ),
        GrammarRule(
            patternRegex: "(?i)\\b(prefer|prefers|preferred)\\b.*\\bto\\b.*ing",
            formula: "S + prefer + V-ing + to + V-ing",
            title: "Cấu trúc Thích làm gì hơn làm gì (Prefer V-ing to V-ing)",
            meaningVi: "Thể hiện sở thích so sánh giữa 2 hoạt động."
        ),
        GrammarRule(
            patternRegex: "(?i)\\blook(s|ed|ing)?\\s+forward\\s+to\\b",
            formula: "S + look forward to + V-ing / Noun",
            title: "Cụm thành ngữ Mong đợi (Look forward to)",
            meaningVi: "Háo hức, trông đợi một điều gì đó trong tương lai."
        ),
        GrammarRule(
            patternRegex: "(?i)\\b(suggest|recommend|insist|demand)(s|ed|ing)?\\s+that\\s+[a-z]+\\s+([a-z]+|be)\\b",
            formula: "S + suggest/recommend + that + S + (should) + V-bare",
            title: "Cấu trúc Giả định thức với Động từ khuyên bảo (Subjunctive)",
            meaningVi: "Đưa ra lời khuyên, đề xuất hoặc yêu cầu trang trọng."
        ),
        GrammarRule(
            patternRegex: "(?i)\\bit\\s+is\\s+(necessary|important|vital|essential|crucial)\\s+that\\b",
            formula: "It is + Adj + that + S + (should) + V-bare",
            title: "Thể giả định sau Tính từ bắt buộc (It is vital/essential that...)",
            meaningVi: "Nhấn mạnh tính cấp thiết và quan trọng của hành động."
        ),
        GrammarRule(
            patternRegex: "(?i)\\b(am|is|are|was|were|been|being)\\s+[a-z]+(ed|en|t)\\b",
            formula: "S + be + V3/ed + (by O)",
            title: "Cấu trúc Câu bị động (Passive Voice)",
            meaningVi: "Nhấn mạnh vào đối tượng chịu tác động của hành động."
        ),
        GrammarRule(
            patternRegex: "(?i)\\b(take|takes|took|taken)\\s+(advantage|care|into account|for granted)\\b",
            formula: "Take advantage of / Take into account / Take for granted",
            title: "Cụm động từ & Thành ngữ thông dụng với Take",
            meaningVi: "Tận dụng / Cân nhắc tính đến / Xem điều gì là hiển nhiên."
        ),
        GrammarRule(
            patternRegex: "(?i)\\b(make|makes|made)\\s+(use of|sense|sure|progress|an effort)\\b",
            formula: "Make use of / Make sure / Make an effort / Make sense",
            title: "Cụm Collocation thông dụng với Make",
            meaningVi: "Tận dụng / Đảm bảo / Nỗ lực cố gắng / Hợp lý có lý."
        )
    ]
    
    // Stop words to filter out trivial words
    private let stopWords: Set<String> = [
        "the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for",
        "of", "with", "by", "from", "as", "is", "are", "was", "were", "be",
        "been", "being", "have", "has", "had", "do", "does", "did", "can",
        "could", "will", "would", "shall", "should", "may", "might", "must",
        "it", "its", "it's", "this", "that", "these", "those", "i", "you",
        "he", "she", "we", "they", "me", "him", "her", "us", "them", "my",
        "your", "his", "her", "our", "their", "so", "if", "than", "then",
        "there", "here", "what", "which", "who", "whom", "whose", "when",
        "where", "why", "how", "all", "any", "both", "each", "few", "more",
        "most", "other", "some", "such", "no", "nor", "not", "only", "own",
        "same", "very", "just", "also", "into", "through", "during", "before",
        "after", "above", "below", "up", "down", "out", "off", "over", "under"
    ]
    
    // MARK: - Main Analysis Function
    public func analyzeText(_ text: String) async -> TextAnalysisResult {
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            let empty = TextAnalysisResult(originalParagraph: "", vocabularies: [], grammars: [])
            self.lastResult = empty
            return empty
        }
        
        // 1. Split text into sentences
        let sentences = extractSentences(from: trimmed)
        
        // 2. Extract Grammar Formulas across all sentences
        var extractedGrammars: [ExtractedGrammarFormula] = []
        var matchedRuleTitles = Set<String>()
        
        for sentence in sentences {
            for rule in grammarRules {
                if !matchedRuleTitles.contains(rule.title),
                   let regex = try? NSRegularExpression(pattern: rule.patternRegex, options: []),
                   regex.firstMatch(in: sentence, options: [], range: NSRange(location: 0, length: sentence.utf16.count)) != nil {
                    matchedRuleTitles.insert(rule.title)
                    extractedGrammars.append(
                        ExtractedGrammarFormula(
                            formula: rule.formula,
                            title: rule.title,
                            meaningVi: rule.meaningVi,
                            exampleSentence: sentence.trimmingCharacters(in: .whitespacesAndNewlines),
                            isSelected: true
                        )
                    )
                }
            }
        }
        
        // 3. Extract Key Vocabularies using NaturalLanguage
        var extractedWords: [ExtractedVocabulary] = []
        var seenWords = Set<String>()
        var wordOrder = 0
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = trimmed
        
        tagger.enumerateTags(in: trimmed.startIndex..<trimmed.endIndex, unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { tag, tokenRange in
            let rawWord = String(trimmed[tokenRange]).lowercased().trimmingCharacters(in: .punctuationCharacters)
            
            if rawWord.count >= 3 && !stopWords.contains(rawWord) && !seenWords.contains(rawWord) {
                // Determine part of speech
                var posName = "Từ vựng"
                var posCat: POSCategory = .other
                if let t = tag {
                    switch t {
                    case .noun:
                        posName = "Danh từ (Noun)"
                        posCat = .noun
                    case .verb:
                        posName = "Động từ (Verb)"
                        posCat = .verb
                    case .adjective:
                        posName = "Tính từ (Adj)"
                        posCat = .adjective
                    case .adverb:
                        posName = "Trạng từ (Adv)"
                        posCat = .adverb
                    default:
                        posName = "Từ vựng"
                        posCat = .other
                    }
                }
                
                // Determine Importance by word length & characteristics
                var importance: VocabImportance = .core
                if rawWord.count >= 8 || rawWord.contains("-") {
                    importance = .advanced
                } else if posCat == .verb || posCat == .noun {
                    importance = .core
                } else {
                    importance = .collocation
                }
                
                // Find context sentence
                let context = sentences.first(where: { $0.localizedCaseInsensitiveContains(rawWord) }) ?? trimmed
                
                seenWords.insert(rawWord)
                extractedWords.append(
                    ExtractedVocabulary(
                        word: rawWord.capitalized,
                        partOfSpeech: posName,
                        posCategory: posCat,
                        importance: importance,
                        vietnameseMeaning: "Đang tra cứu nghĩa...",
                        contextSentence: context.trimmingCharacters(in: .whitespacesAndNewlines),
                        orderIndex: wordOrder,
                        isSelected: true
                    )
                )
                wordOrder += 1
            }
            return true
        }
        
        // Limit to 15 most relevant words
        let topWords = Array(extractedWords.prefix(15))
        
        // Translate words in parallel
        var finalizedWords: [ExtractedVocabulary] = []
        for wordItem in topWords {
            var item = wordItem
            if let meaning = await TranslationService.shared.translate(text: item.word, from: "en", to: "vi") {
                item.vietnameseMeaning = meaning
            }
            finalizedWords.append(item)
        }
        
        let result = TextAnalysisResult(
            originalParagraph: trimmed,
            vocabularies: finalizedWords,
            grammars: extractedGrammars
        )
        
        self.lastResult = result
        return result
    }
    
    // MARK: - Save to Vocabulary Notebook
    public func saveSelectedToNotebook(result: TextAnalysisResult) -> Int {
        var count = 0
        
        // Save selected vocabularies
        for vocab in result.vocabularies where vocab.isSelected {
            VocabularyService.shared.addWord(
                word: vocab.word,
                phonetic: vocab.phonetic,
                translation: "\(vocab.vietnameseMeaning) (\(vocab.partOfSpeech))",
                exampleEn: vocab.contextSentence,
                exampleVi: nil
            )
            count += 1
        }
        
        // Save selected grammar formulas
        for grammar in result.grammars where grammar.isSelected {
            VocabularyService.shared.addWord(
                word: "📐 \(grammar.title)",
                phonetic: grammar.formula,
                translation: "\(grammar.meaningVi)\nCông thức: \(grammar.formula)",
                exampleEn: grammar.exampleSentence,
                exampleVi: nil
            )
            count += 1
        }
        
        return count
    }
    
    private func extractSentences(from text: String) -> [String] {
        var sentences: [String] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let s = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty {
                sentences.append(s)
            }
            return true
        }
        return sentences.isEmpty ? [text] : sentences
    }
}
