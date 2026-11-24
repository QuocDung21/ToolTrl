import Foundation

/// Persisted classification of a notebook entry. Drives the RULE 1 rendering split.
public enum VocabularyItemType: String, Codable, Sendable, CaseIterable {
    case vocabulary
    case grammar
}

/// Spaced Repetition review grade (SM-2 / Anki style)
public enum ReviewGrade: Int, Codable, Sendable, CaseIterable {
    case again = 0
    case hard  = 1
    case good  = 2
    case easy  = 3
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

    // Spaced Repetition (SM-2) optional metadata — nil for unreviewed / legacy cards
    public var reviewCount: Int?
    public var easeFactor: Double?
    public var intervalDays: Int?
    public var nextReviewDate: Date?
    public var lastReviewedDate: Date?

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
        itemType: VocabularyItemType? = nil,
        reviewCount: Int? = nil,
        easeFactor: Double? = nil,
        intervalDays: Int? = nil,
        nextReviewDate: Date? = nil,
        lastReviewedDate: Date? = nil
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
        self.reviewCount = reviewCount
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.nextReviewDate = nextReviewDate
        self.lastReviewedDate = lastReviewedDate
    }

    /// Whether this item is due for spaced repetition review at `referenceDate`.
    public func isDueForReview(at referenceDate: Date = Date()) -> Bool {
        if isMastered, let next = nextReviewDate {
            return next <= referenceDate
        }
        if isMastered {
            return false
        }
        guard let next = nextReviewDate else {
            return true
        }
        return next <= referenceDate
    }

    /// Applies an SM-2 spaced repetition review grade and updates scheduling metadata.
    public mutating func applyReview(grade: ReviewGrade, now: Date = Date()) {
        let currentReps = reviewCount ?? 0
        let currentEF = easeFactor ?? 2.5
        let currentInterval = intervalDays ?? 0

        let newReps: Int
        let newInterval: Int
        var newEF = currentEF

        switch grade {
        case .again:
            newReps = 0
            newInterval = 1
            newEF = max(1.3, currentEF - 0.2)
            isMastered = false
        case .hard:
            newReps = currentReps + 1
            newInterval = max(1, Int((Double(max(1, currentInterval)) * 1.2).rounded()))
            newEF = max(1.3, currentEF - 0.15)
        case .good:
            newReps = currentReps + 1
            if currentReps == 0 {
                newInterval = 1
            } else if currentReps == 1 {
                newInterval = 4
            } else {
                newInterval = max(1, Int((Double(currentInterval) * currentEF).rounded()))
            }
        case .easy:
            newReps = currentReps + 1
            if currentReps == 0 {
                newInterval = 4
            } else {
                newInterval = max(4, Int((Double(max(1, currentInterval)) * currentEF * 1.3).rounded()))
            }
            newEF = min(3.2, currentEF + 0.15)
        }

        if newInterval >= 21 {
            isMastered = true
        }

        reviewCount = newReps
        easeFactor = newEF
        intervalDays = newInterval
        lastReviewedDate = now
        nextReviewDate = Calendar.current.date(byAdding: .day, value: newInterval, to: now)
            ?? now.addingTimeInterval(Double(newInterval) * 86_400)
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
