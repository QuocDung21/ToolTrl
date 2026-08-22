import Foundation
import NaturalLanguage

public struct SavedWordItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public let word: String
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
        return """
        Hãy phân tích từ vựng/cấu trúc '\(word)' thành một mục từ điển chuyên sâu theo đúng cấu trúc chuẩn sau để lưu vào Sổ Tay:

        ### 1. 🏷️ TỪ LOẠI & TẦNG NGHĨA CHÍNH
        - Liệt kê các nghĩa quan trọng nhất kèm giải thích tiếng Việt ngắn gọn.

        ### 2. 🌿 HỌ TỪ (WORD FAMILY)
        - Danh từ (Noun): ...
        - Động từ (Verb): ...
        - Tính từ (Adjective): ...
        - Trạng từ (Adverb): ...

        ### 3. 💡 COLLOCATIONS & THÀNH NGỮ
        - Liệt kê 3-4 cụm từ cố định hay đi kèm (Collocations) kèm ví dụ ngắn.

        ### 4. ⚖️ SẮC THÁI & PHÂN BIỆT (NUANCES)
        - Phân biệt với các từ dễ nhầm lẫn hoặc lưu ý quan trọng khi dùng.

        ### 5. 📖 VÍ DỤ MINH HỌA
        - 2 câu ví dụ tự nhiên (kèm dịch nghĩa).

        ### 6. 🧠 MẸO GHI NHỚ (MNEMONIC & ETYMOLOGY)
        - Gốc từ hoặc mẹo liên tưởng dễ nhớ.
        """
    }
    
    public static func buildGrammarFormulaPrompt(for title: String, context: String? = nil) -> String {
        let contextHint = (context != nil && !context!.isEmpty) ? "\n(Ngữ cảnh câu: \"\(context!)\")" : ""
        return """
        Hãy phân tích và thiết lập CÔNG THỨC & QUY TẮC NGỮ PHÁP cho cấu trúc '\(title)'\(contextHint) theo đúng khuôn mẫu chuẩn sau để lưu vào Sổ Tay:

        ### 1. 📐 CÔNG THỨC CHUẨN (FORMULA)
        [Ghi rõ công thức tổng quát dạng toán học, ví dụ: S + had + V3/ed + by the time + S + V2/ed, hoặc S + wish + (that) + S + V-past / would + V]

        ### 2. 💡 Ý NGHĨA & CÁCH DÙNG
        - Giải thích bản chất, hoàn cảnh sử dụng và các dấu hiệu nhận biết (Signal words / Trạng từ đi kèm).

        ### 3. 📖 CÁC CÂU VÍ DỤ MINH HỌA (EXAMPLES)
        - Thể khẳng định (+): ... ➔ Dịch nghĩa tiếng Việt
        - Thể phủ định (-): ... ➔ Dịch nghĩa tiếng Việt
        - Thể nghi vấn (?): ... ➔ Dịch nghĩa tiếng Việt

        ### 4. ⚠️ LỖI SAI HAY GẶP & BẪY ĐỀ THI (COMMON MISTAKES)
        - Điểm bẫy ngữ pháp thường xuất hiện trong đề thi TOEIC/IELTS hoặc giao tiếp.

        ### 5. 🧠 MẸO GHI NHỚ THẦN TỐC
        - Mẹo vần điệu hoặc quy tắc liên tưởng ngắn gọn giúp nhớ công thức vĩnh viễn.
        """
    }
    
    public static func buildWordGrammarPatternsPrompt(for word: String, context: String? = nil) -> String {
        let contextHint = (context != nil && !context!.isEmpty) ? "\n(Ví dụ ngữ cảnh: \"\(context!)\")" : ""
        return """
        Hãy phân tích và trích xuất các CẤU TRÚC & CÔNG THỨC NGỮ PHÁP quan trọng nhất đi với từ '\(word)'\(contextHint) theo đúng cấu trúc sau để lưu vào Sổ Tay:

        ### 1. 📐 CÔNG THỨC CHUẨN (FORMULA)
        [Liệt kê các cấu trúc ngữ pháp dạng công thức, ví dụ: S + \(word) + to V / V-ing / that + S + V / prep + O]

        ### 2. 💡 CÁCH DÙNG & GIỚI TỪ ĐI KÈM
        - Các giới từ cố định, cấu trúc đi kèm và ý nghĩa từng trường hợp.

        ### 3. 📖 CÁC CÂU VÍ DỤ MINH HỌA (EXAMPLES)
        - Câu ví dụ thực tế cho từng cấu trúc (kèm dịch nghĩa tiếng Việt).

        ### 4. ⚠️ LỖI SAI HAY GẶP & BẪY ĐỀ THI (COMMON MISTAKES)
        - Bẫy ngữ pháp thường gặp trong đề thi TOEIC/IELTS khi dùng từ này.

        ### 5. 🧠 MẸO GHI NHỚ
        - Mẹo ngắn gọn để nhớ nhanh các cấu trúc này.
        """
    }
    
    public static func buildStrictEnforcedGrammarPrompt(title: String, context: String? = nil, customNote: String? = nil) -> String {
        var extra = ""
        if let ctx = context, !ctx.isEmpty {
            extra += "\n- Câu ví dụ ngữ cảnh người dùng cung cấp: \"\(ctx)\""
        }
        if let note = customNote, !note.isEmpty {
            extra += "\n- Yêu cầu/ghi chú bổ sung: \(note)"
        }
        
        return """
        Hãy phân tích và thiết lập CÔNG THỨC & QUY TẮC NGỮ PHÁP cho cấu trúc '\(title)'\(extra) theo đúng 5 phần chuẩn sau để lưu trực tiếp vào Sổ Tay:

        ### 1. 📐 CÔNG THỨC CHUẨN (FORMULA)
        [Ghi công thức tổng quát dạng toán học, ví dụ: S + had + V3/ed + by the time + S + V2/ed, hoặc It + is + adj + that + S + (should) + V-inf]

        ### 2. 💡 Ý NGHĨA & CÁCH DÙNG
        - Giải thích bản chất, hoàn cảnh sử dụng và các trạng từ / từ nhận biết đi kèm.

        ### 3. 📖 CÁC CÂU VÍ DỤ MINH HỌA (EXAMPLES)
        - Thể khẳng định (+): ... ➔ Dịch nghĩa tiếng Việt
        - Thể phủ định (-): ... ➔ Dịch nghĩa tiếng Việt
        - Thể nghi vấn (?): ... ➔ Dịch nghĩa tiếng Việt

        ### 4. ⚠️ LỖI SAI HAY GẶP & BẪY ĐỀ THI (COMMON MISTAKES)
        - Bẫy ngữ pháp thường xuất hiện trong đề thi TOEIC/IELTS hoặc giao tiếp khi dùng cấu trúc này.

        ### 5. 🧠 MẸO GHI NHỚ THẦN TỐC
        - Mẹo ngắn gọn hoặc câu thần chú giúp thuộc công thức tức thì.
        """
    }
    
    public var isGrammarFormula: Bool {
        return word.contains("📐") || (phonetic?.contains("+") == true) || translation.contains("Công thức:")
    }
    
    public var cleanTitle: String {
        return word.replacingOccurrences(of: "📐", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    public var aiPriority: ItemAIPriority {
        if isGrammarFormula { return .grammar }
        let clean = cleanTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.contains(" ") || clean.contains("-") {
            return .phrases
        }
        
        let academicSuffixes = ["tion", "sion", "ment", "able", "ible", "ology", "istic", "ize", "ify", "ance", "ence", "ous", "ive", "ity", "ical", "tude"]
        let hasAcademicSuffix = academicSuffixes.contains { clean.hasSuffix($0) }
        
        if clean.count >= 7 || hasAcademicSuffix {
            return .advanced
        }
        return .core
    }
    
    public var aiPartOfSpeech: ItemAIPartOfSpeech {
        if isGrammarFormula { return .grammar }
        let clean = cleanTitle.lowercased()
        if clean.contains(" ") {
            return .adverb
        }
        
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = clean
        let tag = tagger.tag(at: clean.startIndex, unit: .word, scheme: .lexicalClass).0
        
        switch tag {
        case .noun: return .noun
        case .verb: return .verb
        case .adjective: return .adjective
        case .adverb: return .adverb
        default:
            if translation.lowercased().contains("noun") || translation.lowercased().contains("danh từ") { return .noun }
            if translation.lowercased().contains("verb") || translation.lowercased().contains("động từ") { return .verb }
            if translation.lowercased().contains("adj") || translation.lowercased().contains("tính từ") { return .adjective }
            return .noun
        }
    }
    
    public var aiThematicGenre: ItemThematicGenre {
        if isGrammarFormula { return .grammar }
        let clean = (cleanTitle + " " + translation + " " + (exampleEn ?? "")).lowercased()
        
        let techWords = ["code", "software", "hardware", "data", "server", "app", "api", "database", "computer", "network", "system", "algorithm", "function", "variable", "class", "deploy", "debug", "cache", "memory", "compile", "terminal", "runtime", "cloud", "interface", "framework", "programming", "developer", "git", "web", "browser", "ios", "macos", "linux", "ai", "model", "token", "prompt", "công nghệ", "phần mềm", "lập trình", "dữ liệu", "máy chủ", "thuật toán"]
        if techWords.contains(where: { clean.contains($0) }) {
            return .technology
        }
        
        let businessWords = ["business", "company", "market", "finance", "revenue", "profit", "budget", "meeting", "client", "customer", "project", "deadline", "contract", "salary", "career", "manager", "management", "strategy", "investment", "stakeholder", "colleague", "negotiate", "sales", "report", "công ty", "kinh doanh", "thị trường", "tài chính", "dự án", "đối tác", "hợp đồng", "quản lý", "doanh thu", "lợi nhuận", "chiến lược"]
        if businessWords.contains(where: { clean.contains($0) }) {
            return .business
        }
        
        let academicWords = ["theory", "hypothesis", "experiment", "evidence", "science", "scientific", "methodology", "conclusion", "principle", "significant", "perspective", "evaluation", "literature", "academic", "research", "investigate", "scholarly", "philosoph", "psycholog", "học thuật", "nghiên cứu", "lý thuyết", "giả thuyết", "thí nghiệm", "bằng chứng", "khoa học", "phương pháp"]
        if academicWords.contains(where: { clean.contains($0) }) {
            return .academic
        }
        
        let dailyWords = ["travel", "food", "eat", "drink", "health", "family", "friend", "house", "home", "feeling", "happy", "sad", "love", "opinion", "hobby", "sport", "weather", "music", "movie", "shopping", "daily", "cuộc sống", "gia đình", "bạn bè", "ăn uống", "sức khỏe", "cảm xúc", "du lịch", "thời tiết", "sở thích"]
        if dailyWords.contains(where: { clean.contains($0) }) {
            return .dailyLife
        }
        
        return .general
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
    
    public func loadWords() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([SavedWordItem].self, from: data) else {
            // Check legacy key
            if let legacyData = UserDefaults.standard.data(forKey: "saved_vocabulary_items"),
               let legacyItems = try? JSONDecoder().decode([SavedWordItem].self, from: legacyData) {
                self.savedWords = legacyItems
                saveWords()
                return
            }
            self.savedWords = []
            return
        }
        self.savedWords = items
    }
    
    public func saveWords() {
        if let data = try? JSONEncoder().encode(savedWords) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    public func isWordSaved(_ word: String) -> Bool {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return savedWords.contains { $0.word.lowercased() == clean }
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
        
        if let index = savedWords.firstIndex(where: { $0.word.lowercased() == clean.lowercased() }) {
            savedWords.remove(at: index)
        } else {
            let newItem = SavedWordItem(
                word: clean,
                phonetic: phonetic,
                translation: translation,
                exampleEn: exampleEn,
                exampleVi: exampleVi
            )
            savedWords.insert(newItem, at: 0)
        }
        saveWords()
    }
    
    public func addWord(
        word: String,
        phonetic: String? = nil,
        translation: String,
        exampleEn: String? = nil,
        exampleVi: String? = nil
    ) {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if let idx = savedWords.firstIndex(where: { $0.word.lowercased() == clean.lowercased() }) {
            savedWords[idx] = SavedWordItem(
                word: clean,
                phonetic: phonetic,
                translation: translation,
                exampleEn: exampleEn,
                exampleVi: exampleVi
            )
        } else {
            let newItem = SavedWordItem(
                word: clean,
                phonetic: phonetic,
                translation: translation,
                exampleEn: exampleEn,
                exampleVi: exampleVi
            )
            savedWords.insert(newItem, at: 0)
        }
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
