import Foundation
import NaturalLanguage

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
        return AIPromptBuilder.structuredWordPrompt(for: word)
    }
    
    public static func buildGrammarFormulaPrompt(for title: String, context: String? = nil) -> String {
        return AIPromptBuilder.grammarFormulaPrompt(for: title, context: context)
    }
    
    public static func buildWordGrammarPatternsPrompt(for word: String, context: String? = nil) -> String {
        return AIPromptBuilder.wordGrammarPatternsPrompt(for: word, context: context)
    }
    
    public static func buildStrictEnforcedGrammarPrompt(title: String, context: String? = nil, customNote: String? = nil) -> String {
        return AIPromptBuilder.strictEnforcedGrammarPrompt(title: title, context: context, customNote: customNote)
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
        return word.replacingOccurrences(of: "📐", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
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

@MainActor
public final class VocabularyService: ObservableObject {
    public static let shared = VocabularyService()
    
    private let storageKey = "saved_vocabulary_items_v2"
    
    @Published public var savedWords: [SavedWordItem] = []
    
    private init() {
        loadWords()
    }
    
    // MARK: - Smart Word Title Normalization
    /// Chuẩn hóa từ vựng: Tự động chuyển chữ cái đầu viết hoa về viết thường chuẩn từ điển ("Leadership" -> "leadership").
    /// Giữ nguyên chữ hoa đối với từ viết tắt toàn bộ ("AI", "API", "NASA", "TOEIC") hoặc danh từ riêng.
    public static func normalizeWordTitle(_ rawWord: String) -> String {
        let clean = rawWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return clean }
        
        // 1. Công thức ngữ pháp có icon -> Giữ nguyên
        if clean.contains("📐") { return clean }
        
        // 2. Viết tắt toàn bộ chữ hoa (All Caps) như AI, API, NASA, TOEIC -> Giữ nguyên
        let letters = clean.filter { $0.isLetter }
        if letters.count >= 2 && letters.allSatisfy({ $0.isUppercase }) {
            return clean
        }
        
        // 3. Nhận diện danh từ riêng (Proper Nouns: London, Vietnam, Google...) bằng Apple NaturalLanguage
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = clean
        let tag = tagger.tag(at: clean.startIndex, unit: .word, scheme: .nameType).0
        if tag == .personalName || tag == .placeName || tag == .organizationName {
            return clean
        }
        
        // 4. Nếu chữ cái đầu viết hoa nhưng phần còn lại là chữ thường (ví dụ "Leadership", "According")
        if let first = clean.first, first.isUppercase {
            let remainder = clean.dropFirst()
            if remainder.allSatisfy({ !$0.isUppercase }) {
                return clean.prefix(1).lowercased() + clean.dropFirst()
            }
        }
        
        return clean
    }
    
    public func loadWords() {
        var items: [SavedWordItem] = []
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([SavedWordItem].self, from: data) {
            items = decoded
        } else if let legacyData = UserDefaults.standard.data(forKey: "saved_vocabulary_items"),
                  let legacyItems = try? JSONDecoder().decode([SavedWordItem].self, from: legacyData) {
            items = legacyItems
        }
        
        // Auto-Deduplicate & Normalize legacy items (e.g. "Leadership" -> "leadership")
        // and backfill `itemType` for rows saved before that field existed.
        let migrated = VocabularyService.migrateLegacyItems(items)
        self.savedWords = migrated.items
        if migrated.didMigrate {
            saveWords()
        }
    }
    
    /// Normalizes titles, drops duplicates and backfills `itemType` on rows saved
    /// before that field existed.
    ///
    /// Pure and idempotent, so the migration can be unit tested without touching
    /// `UserDefaults`. A second pass over its own output reports `didMigrate == false`.
    public static func migrateLegacyItems(_ items: [SavedWordItem]) -> (items: [SavedWordItem], didMigrate: Bool) {
        var normalizedList: [SavedWordItem] = []
        var seenKeys: Set<String> = []
        var didMigrate = false
        
        for item in items {
            let normalizedWord = VocabularyService.normalizeWordTitle(item.word)
            let key = normalizedWord.replacingOccurrences(of: "📐", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !seenKeys.contains(key) else {
                didMigrate = true
                continue
            }
            seenKeys.insert(key)
            
            var resolvedItem = item
            if resolvedItem.itemType == nil {
                resolvedItem.itemType = SavedWordItem.inferredItemType(
                    word: normalizedWord,
                    phonetic: resolvedItem.phonetic,
                    translation: resolvedItem.translation
                )
                didMigrate = true
            }
            
            if resolvedItem.word != normalizedWord {
                resolvedItem.word = normalizedWord
                didMigrate = true
            }
            
            normalizedList.append(resolvedItem)
        }
        
        return (normalizedList, didMigrate)
    }
    
    private let saveQueue = DispatchQueue(label: "com.nekotrans.mac.vocabulary.save", qos: .utility)
    private var saveWorkItem: DispatchWorkItem?
    
    public func saveWords() {
        let snapshot = self.savedWords
        saveWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [storageKey] in
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            UserDefaults.standard.set(data, forKey: storageKey)
            
            // Auto Index to macOS CoreSpotlight (Cmd + Space Search)
            SpotlightService.shared.indexAllItems(snapshot)
            
            // Auto Sync to GitHub Cloud if enabled
            Task { @MainActor in
                if GitHubSyncService.shared.autoSyncEnabled && GitHubSyncService.shared.isConnected {
                    _ = await GitHubSyncService.shared.backupToGitHub()
                }
            }
        }
        
        saveWorkItem = workItem
        saveQueue.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }
    
    /// Synchronous flush when needed
    public func flush() {
        saveWorkItem?.cancel()
        if let data = try? JSONEncoder().encode(savedWords) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    /// Xóa toàn bộ dữ liệu từ vựng và ngữ pháp trên máy (dùng khi đăng xuất tài khoản)
    public func clearAllWords() {
        saveWorkItem?.cancel()
        self.savedWords = []
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: "saved_vocabulary_items")
        SpotlightService.shared.clearAllIndex()
    }
    
    public func isWordSaved(_ word: String) -> Bool {
        let clean = word.replacingOccurrences(of: "📐", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return savedWords.contains { $0.cleanTitle.lowercased() == clean || $0.word.lowercased() == clean }
    }
    
    public func toggleSaveWord(
        word: String,
        phonetic: String?,
        translation: String,
        exampleEn: String? = nil,
        exampleVi: String? = nil
    ) {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let normalized = VocabularyService.normalizeWordTitle(clean)
        let lower = normalized.replacingOccurrences(of: "📐", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        if let index = savedWords.firstIndex(where: { $0.cleanTitle.lowercased() == lower || $0.word.lowercased() == lower }) {
            savedWords.remove(at: index)
        } else {
            let newItem = SavedWordItem(
                word: normalized,
                phonetic: phonetic,
                translation: translation,
                exampleEn: exampleEn,
                exampleVi: exampleVi,
                itemType: SavedWordItem.inferredItemType(
                    word: normalized,
                    phonetic: phonetic,
                    translation: translation
                )
            )
            savedWords.insert(newItem, at: 0)
        }
        saveWords()
    }
    
    @discardableResult
    public func addWord(
        word: String,
        phonetic: String? = nil,
        translation: String,
        exampleEn: String? = nil,
        exampleVi: String? = nil,
        itemType: VocabularyItemType? = nil
    ) -> UUID? {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let normalized = VocabularyService.normalizeWordTitle(clean)
        let lower = normalized.replacingOccurrences(of: "📐", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Explicit caller intent wins; otherwise classify once, at creation time.
        let resolvedType = itemType ?? SavedWordItem.inferredItemType(
            word: normalized,
            phonetic: phonetic,
            translation: translation
        )
        let itemId: UUID
        if let idx = savedWords.firstIndex(where: { $0.cleanTitle.lowercased() == lower || $0.word.lowercased() == lower }) {
            var existing = savedWords[idx]
            if let ph = phonetic, !ph.isEmpty {
                existing.phonetic = ph
            }
            if !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                existing.translation = translation
            }
            if let exEn = exampleEn, !exEn.isEmpty {
                existing.exampleEn = exEn
            }
            if let exVi = exampleVi, !exVi.isEmpty {
                existing.exampleVi = exVi
            }
            // Promote to grammar when the caller re-adds the entry as a formula,
            // but never silently demote an existing grammar entry to vocabulary.
            if resolvedType == .grammar {
                existing.itemType = .grammar
            } else if existing.itemType == nil {
                existing.itemType = resolvedType
            }
            savedWords[idx] = existing
            itemId = existing.id
        } else {
            let newItem = SavedWordItem(
                word: normalized,
                phonetic: phonetic,
                translation: translation,
                exampleEn: exampleEn,
                exampleVi: exampleVi,
                itemType: resolvedType
            )
            savedWords.insert(newItem, at: 0)
            itemId = newItem.id
        }
        saveWords()
        return itemId
    }
    
    public func updateWord(
        id: UUID,
        word: String,
        phonetic: String? = nil,
        translation: String,
        exampleEn: String? = nil,
        exampleVi: String? = nil
    ) {
        guard savedWords.contains(where: { $0.id == id }) else { return }
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let normalized = VocabularyService.normalizeWordTitle(clean)
        let lower = normalized.replacingOccurrences(of: "📐", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // If another item has this exact normalized title, remove it to avoid duplicates
        if let duplicateIdx = savedWords.firstIndex(where: { $0.id != id && ($0.cleanTitle.lowercased() == lower || $0.word.lowercased() == lower) }) {
            savedWords.remove(at: duplicateIdx)
        }
        
        guard let currentIdx = savedWords.firstIndex(where: { $0.id == id }) else { return }
        savedWords[currentIdx].word = normalized
        savedWords[currentIdx].phonetic = phonetic?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? phonetic : nil
        savedWords[currentIdx].translation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        savedWords[currentIdx].exampleEn = exampleEn?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? exampleEn : nil
        savedWords[currentIdx].exampleVi = exampleVi?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? exampleVi : nil
        
        saveWords()
    }
    
    public func toggleFavorite(id: UUID) {
        if let index = savedWords.firstIndex(where: { $0.id == id }) {
            savedWords[index].isFavorite.toggle()
            saveWords()
        }
    }
    
    public func toggleMastered(id: UUID) {
        if let index = savedWords.firstIndex(where: { $0.id == id }) {
            savedWords[index].isMastered.toggle()
            saveWords()
        }
    }
    
    public func updateAIDetailedAnalysis(wordId: UUID, analysis: String) {
        if let index = savedWords.firstIndex(where: { $0.id == wordId }) {
            savedWords[index].aiDetailedAnalysis = analysis
            let parsed = AIAnalysisParser.parse(analysis)
            // RULE 1: only a grammar entry stores its formula in `phonetic`.
            // Overwriting a vocabulary entry's IPA with a formula would destroy it.
            if savedWords[index].isGrammarFormula,
               let formula = parsed.formula,
               !formula.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                savedWords[index].phonetic = formula
            }
            if let firstMeaning = parsed.meanings.first, !firstMeaning.isEmpty {
                if savedWords[index].translation.hasPrefix("Cấu trúc ngữ pháp:") || savedWords[index].translation.isEmpty {
                    savedWords[index].translation = firstMeaning
                }
            }
            saveWords()
        }
    }
    
    public func updateAIDetailedAnalysis(wordTitle: String, analysis: String) {
        let clean = wordTitle.replacingOccurrences(of: "📐", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let index = savedWords.firstIndex(where: { $0.cleanTitle.lowercased() == clean }) {
            savedWords[index].aiDetailedAnalysis = analysis
            let parsed = AIAnalysisParser.parse(analysis)
            // RULE 1: only a grammar entry stores its formula in `phonetic`.
            if savedWords[index].isGrammarFormula,
               let formula = parsed.formula,
               !formula.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                savedWords[index].phonetic = formula
            }
            if let firstMeaning = parsed.meanings.first, !firstMeaning.isEmpty {
                if savedWords[index].translation.hasPrefix("Cấu trúc ngữ pháp:") || savedWords[index].translation.isEmpty {
                    savedWords[index].translation = firstMeaning
                }
            }
            saveWords()
        }
    }
    
    public func removeWord(at offsets: IndexSet) {
        savedWords.remove(atOffsets: offsets)
        saveWords()
    }
    
    public func removeWord(id: UUID) {
        savedWords.removeAll { $0.id == id }
        saveWords()
    }
    
    public func clearAll() {
        savedWords.removeAll()
        saveWords()
    }
}
