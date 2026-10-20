import Foundation

/// Persisted classification of a notebook entry. Drives the RULE 1 rendering split.
public enum VocabularyItemType: String, Codable, Sendable, CaseIterable {
    case vocabulary
    case grammar
}

public struct SavedWordItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var word: String
    public var phonetic: String?
    public var translation: String
    public var exampleEn: String?
    public var exampleVi: String?
    public let dateAdded: Date
    public var isFavorite: Bool
    public var isMastered: Bool
    public var aiDetailedAnalysis: String?
    /// Persisted entry type. `nil` only for rows saved before this field existed;
    /// `VocabularyService.loadWords()` backfills those exactly once.
    public var itemType: VocabularyItemType?

    public init(
        id: UUID = UUID(),
        word: String,
        phonetic: String?,
        translation: String,
        exampleEn: String? = nil,
        exampleVi: String? = nil,
        dateAdded: Date = Date(),
        isFavorite: Bool = false,
        isMastered: Bool = false,
        aiDetailedAnalysis: String? = nil,
        itemType: VocabularyItemType? = nil
    ) {
        self.id = id
        self.word = word
        self.phonetic = phonetic
        self.translation = translation
        self.exampleEn = exampleEn
        self.exampleVi = exampleVi
        self.dateAdded = dateAdded
        self.isFavorite = isFavorite
        self.isMastered = isMastered
        self.aiDetailedAnalysis = aiDetailedAnalysis
        self.itemType = itemType
    }

    public static func buildStructuredWordPrompt(for word: String) -> String {
        AIPromptBuilder.structuredWordPrompt(for: word)
    }

    public static func buildGrammarFormulaPrompt(for title: String, context: String? = nil) -> String {
        AIPromptBuilder.grammarFormulaPrompt(for: title, context: context)
    }

    public static func buildWordGrammarPatternsPrompt(for word: String, context: String? = nil) -> String {
        AIPromptBuilder.wordGrammarPatternsPrompt(for: word, context: context)
    }

    public static func buildStrictEnforcedGrammarPrompt(title: String, context: String? = nil, customNote: String? = nil) -> String {
        AIPromptBuilder.strictEnforcedGrammarPrompt(title: title, context: context, customNote: customNote)
    }

    /// Grammar-vs-vocabulary classification consumed by every rendering pipeline.
    ///
    /// Reads the **persisted** flag so re-classification can never flip an existing
    /// entry. Rows written before `itemType` existed fall back to the creation-time
    /// heuristic until `VocabularyService.loadWords()` backfills them.
    public var isGrammarFormula: Bool {
        let resolved = itemType ?? SavedWordItem.inferredItemType(
            word: word,
            phonetic: phonetic,
            translation: translation
        )
        return resolved == .grammar
    }

    /// Heuristic used **only** when an entry is first created (and to migrate legacy rows).
    /// Callers that know the intent must pass `itemType` explicitly instead.
    public static func inferredItemType(word: String, phonetic: String?, translation: String) -> VocabularyItemType {
        if word.contains("📐") { return .grammar }
        if let phonetic, phonetic.contains("+") { return .grammar }
        if translation.contains("Công thức:") { return .grammar }
        return .vocabulary
    }

    public var cleanTitle: String {
        word.replacingOccurrences(of: "📐", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var aiPriority: ItemAIPriority {
        WordClassifierService.shared.classifyPriority(for: self)
    }

    public var aiPartOfSpeech: ItemAIPartOfSpeech {
        WordClassifierService.shared.classifyPartOfSpeech(for: self)
    }

    public var aiThematicGenre: ItemThematicGenre {
        WordClassifierService.shared.classifyThematicGenre(for: self)
    }
}

public enum ItemThematicGenre: String, CaseIterable, Identifiable {
    case technology = "Công Nghệ & Lập Trình"
    case business = "Kinh Doanh & Công Sở"
    case academic = "Học Thuật & Nghiên Cứu"
    case dailyLife = "Đời Sống & Giao Tiếp"
    case grammar = "Cấu Trúc & Ngữ Pháp"
    case general = "Từ Vựng Tổng Hợp"

    public var id: String { rawValue }
}

public enum ItemAIPriority: String, CaseIterable, Identifiable {
    case core = "Từ Vựng Cốt Lõi"
    case phrases = "Cụm Từ & Thành Ngữ"
    case advanced = "Từ Vựng Nâng Cao"
    case grammar = "Công Thức Ngữ Pháp"

    public var id: String { rawValue }
}

public enum ItemAIPartOfSpeech: String, CaseIterable, Identifiable {
    case noun = "Danh Từ (Noun)"
    case verb = "Động Từ (Verb)"
    case adjective = "Tính Từ (Adjective)"
    case adverb = "Trạng Từ & Khác"
    case grammar = "Cấu Trúc Ngữ Pháp"

    public var id: String { rawValue }
}
