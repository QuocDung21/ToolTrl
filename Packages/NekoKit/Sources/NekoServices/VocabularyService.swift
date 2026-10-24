import Foundation
import NaturalLanguage
import Defaults
import Observation
import NekoCore

@Observable
@MainActor
public final class VocabularyService {
    public static let shared = VocabularyService()
    
    public var savedWords: [SavedWordItem] = []
    
    public static var storeFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = appSupport.appendingPathComponent("NekoTrans", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("vocabulary_store.dat")
    }
    
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
        var loadedFromFile = false
        
        // 1. Try loading from compressed LZFSE file store
        if let url = Self.storeFileURL,
           FileManager.default.fileExists(atPath: url.path),
           let rawData = try? Data(contentsOf: url) {
            let payload = DataCompression.decompress(data: rawData) ?? rawData
            if let decoded = try? JSONDecoder().decode([SavedWordItem].self, from: payload) {
                items = decoded
                loadedFromFile = true
            }
        }
        
        // 2. Migration fallback: load from UserDefaults if file doesn't exist yet
        if !loadedFromFile {
            if let data = Defaults[.savedVocabularyItemsData],
               let decoded = try? JSONDecoder().decode([SavedWordItem].self, from: data) {
                items = decoded
            } else if let legacyData = Defaults[.legacySavedVocabularyItemsData],
                      let legacyItems = try? JSONDecoder().decode([SavedWordItem].self, from: legacyData) {
                items = legacyItems
            }
        }
        
        // Auto-Deduplicate & Normalize legacy items (e.g. "Leadership" -> "leadership")
        // and backfill `itemType` for rows saved before that field existed.
        let migrated = VocabularyService.migrateLegacyItems(items)
        self.savedWords = migrated.items
        
        // If loaded from UserDefaults or migrated, persist to file store and purge UserDefaults
        if !loadedFromFile || migrated.didMigrate {
            saveWords()
            if Defaults[.savedVocabularyItemsData] != nil || Defaults[.legacySavedVocabularyItemsData] != nil {
                Defaults[.savedVocabularyItemsData] = nil
                Defaults[.legacySavedVocabularyItemsData] = nil
                AppLog.vocabulary.info("Sổ từ vựng đã được di chuyển thành công từ UserDefaults sang file LZFSE độc lập.")
            }
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
        
        let workItem = DispatchWorkItem {
            guard let data = try? JSONEncoder().encode(snapshot) else { return }
            let compressed = DataCompression.compress(data: data) ?? data
            if let url = Self.storeFileURL {
                try? compressed.write(to: url, options: .atomic)
            }
            
            // Auto Sync to GitHub Cloud if enabled
            Task { @MainActor in
                if GitHubSyncService.shared.autoSyncEnabled && GitHubSyncService.shared.isConnected {
                    _ = await GitHubSyncService.shared.backupToGitHub()
                }
            }
        }
        
        saveWorkItem = workItem
        saveQueue.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
    
    /// Synchronous flush when needed
    public func flush() {
        saveWorkItem?.cancel()
        guard let data = try? JSONEncoder().encode(savedWords),
              let url = Self.storeFileURL else { return }
        let compressed = DataCompression.compress(data: data) ?? data
        try? compressed.write(to: url, options: .atomic)
    }
    
    /// Xóa toàn bộ dữ liệu từ vựng và ngữ pháp trên máy (dùng khi đăng xuất tài khoản)
    public func clearAllWords() {
        saveWorkItem?.cancel()
        self.savedWords = []
        if let url = Self.storeFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        Defaults[.savedVocabularyItemsData] = nil
        Defaults[.legacySavedVocabularyItemsData] = nil
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

    // MARK: - Export Logic (Inspired by Easydict VocabularyNotebook & AnkiConnect)

    /// Exports saved words into an Anki-compatible Tab-Separated Values (TSV) string.
    /// Columns: Word [Front] \t Translation [Back] \t Phonetic / Formula \t Example EN \t Example VI
    public func exportToAnkiTSV() -> String {
        var lines: [String] = []
        // Optional header comment for Anki
        lines.append("#separator:tab")
        lines.append("#html:true")
        lines.append("#tags column:6")

        for item in savedWords {
            let front = item.cleanTitle.replacingOccurrences(of: "\t", with: " ")
            let back = item.translation.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: "<br>")
            let phonetic = (item.phonetic ?? "").replacingOccurrences(of: "\t", with: " ")
            let exEn = (item.exampleEn ?? "").replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: "<br>")
            let exVi = (item.exampleVi ?? "").replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: "<br>")
            let tag = item.isGrammarFormula ? "NekoTrans::Grammar" : "NekoTrans::Vocabulary"

            let row = "\(front)\t\(back)\t\(phonetic)\t\(exEn)\t\(exVi)\t\(tag)"
            lines.append(row)
        }

        return lines.joined(separator: "\n")
    }

    /// Exports saved vocabulary and grammar formulas into a clean Markdown document.
    public func exportToMarkdown() -> String {
        var md: [String] = []
        md.append("# 📖 Sổ tay từ vựng NekoTrans")
        md.append("*Xuất ngày: \(Date().formatted(date: .abbreviated, time: .shortened))*")
        md.append("")

        let vocabItems = savedWords.filter { !$0.isGrammarFormula }
        let grammarItems = savedWords.filter { $0.isGrammarFormula }

        if !vocabItems.isEmpty {
            md.append("## 📚 Từ vựng (\(vocabItems.count))")
            md.append("")
            md.append("| Từ / Cụm từ | Phiên âm | Nghĩa | Ví dụ |")
            md.append("| :--- | :--- | :--- | :--- |")
            for item in vocabItems {
                let phonetic = item.phonetic ?? ""
                let example = [item.exampleEn, item.exampleVi].compactMap { $0 }.joined(separator: " - ")
                md.append("| **\(item.cleanTitle)** | `\(phonetic)` | \(item.translation) | *\(example)* |")
            }
            md.append("")
        }

        if !grammarItems.isEmpty {
            md.append("## 📐 Ngữ pháp & Cấu trúc (\(grammarItems.count))")
            md.append("")
            for item in grammarItems {
                md.append("### \(item.cleanTitle)")
                if let formula = item.phonetic, !formula.isEmpty {
                    md.append("```text\n\(formula)\n```")
                }
                md.append("- **Ý nghĩa**: \(item.translation)")
                if let exEn = item.exampleEn {
                    md.append("- **Ví dụ**: *\(exEn)*")
                    if let exVi = item.exampleVi {
                        md.append("  - *\(exVi)*")
                    }
                }
                md.append("")
            }
        }

        return md.joined(separator: "\n")
    }

    /// Exports vocabulary items as line-delimited JSON (JSONL), compatible with external tools and review programs.
    public func exportToJSONL() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var jsonLines: [String] = []

        for item in savedWords {
            if let data = try? encoder.encode(item), let jsonString = String(data: data, encoding: .utf8) {
                jsonLines.append(jsonString)
            }
        }

        return jsonLines.joined(separator: "\n")
    }
}
