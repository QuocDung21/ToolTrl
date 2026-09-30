import Foundation
import NaturalLanguage

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
        aiDetailedAnalysis: String? = nil
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
    
    public var isGrammarFormula: Bool {
        return word.contains("📐") || (phonetic?.contains("+") == true) || translation.contains("Công thức:")
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
        var normalizedList: [SavedWordItem] = []
        var seenKeys: Set<String> = []
        
        for item in items {
            let normalizedWord = VocabularyService.normalizeWordTitle(item.word)
            let key = normalizedWord.replacingOccurrences(of: "📐", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !seenKeys.contains(key) {
                seenKeys.insert(key)
                if item.word != normalizedWord {
                    let updated = SavedWordItem(
                        id: item.id,
                        word: normalizedWord,
                        phonetic: item.phonetic,
                        translation: item.translation,
                        exampleEn: item.exampleEn,
                        exampleVi: item.exampleVi,
                        dateAdded: item.dateAdded,
                        isFavorite: item.isFavorite,
                        isMastered: item.isMastered,
                        aiDetailedAnalysis: item.aiDetailedAnalysis
                    )
                    normalizedList.append(updated)
                } else {
                    normalizedList.append(item)
                }
            }
        }
        
        self.savedWords = normalizedList
        if items.count != normalizedList.count {
            saveWords()
        }
    }
    
    private let saveQueue = DispatchQueue(label: "com.tooltrl.vocabulary.save", qos: .utility)
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
                exampleVi: exampleVi
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
        exampleVi: String? = nil
    ) -> UUID? {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let normalized = VocabularyService.normalizeWordTitle(clean)
        let lower = normalized.replacingOccurrences(of: "📐", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
            savedWords[idx] = existing
            itemId = existing.id
        } else {
            let newItem = SavedWordItem(
                word: normalized,
                phonetic: phonetic,
                translation: translation,
                exampleEn: exampleEn,
                exampleVi: exampleVi
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
            if let formula = parsed.formula, !formula.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
            if let formula = parsed.formula, !formula.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
