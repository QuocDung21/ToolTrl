import Foundation
import Synchronization
import NaturalLanguage

public final class WordClassifierService: Sendable {
    public static let shared = WordClassifierService()

    private struct CachedClassification {
        let priority: ItemAIPriority
        let partOfSpeech: ItemAIPartOfSpeech
        let genre: ItemThematicGenre
    }

    private struct ClassifierState: @unchecked Sendable {
        var cache: [String: CachedClassification] = [:]
        var order: [String] = []
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
    }

    private let state = Mutex(ClassifierState())
    private static let maxCacheEntries = 2000

    private static let academicSuffixes = [
        "tion", "sion", "ment", "able", "ible", "ology", "istic",
        "ize", "ify", "ance", "ence", "ous", "ive", "ity", "ical", "tude"
    ]

    private static let techWords = [
        "code", "software", "hardware", "data", "server", "app", "api", "database",
        "computer", "network", "system", "algorithm", "function", "variable", "class",
        "deploy", "debug", "cache", "memory", "compile", "terminal", "runtime", "cloud",
        "interface", "framework", "programming", "developer", "git", "web", "browser",
        "ios", "macos", "linux", "ai", "model", "token", "prompt", "công nghệ", "phần mềm",
        "lập trình", "dữ liệu", "máy chủ", "thuật toán"
    ]

    private static let businessWords = [
        "business", "company", "market", "finance", "revenue", "profit", "budget",
        "meeting", "client", "customer", "project", "deadline", "contract", "salary",
        "career", "manager", "management", "strategy", "investment", "stakeholder",
        "colleague", "negotiate", "sales", "report", "công ty", "kinh doanh", "thị trường",
        "tài chính", "dự án", "đối tác", "hợp đồng", "quản lý", "doanh thu", "lợi nhuận", "chiến lược"
    ]

    private static let academicWords = [
        "theory", "hypothesis", "experiment", "evidence", "science", "scientific",
        "methodology", "conclusion", "principle", "significant", "perspective",
        "evaluation", "literature", "academic", "research", "investigate", "scholarly",
        "philosoph", "psycholog", "học thuật", "nghiên cứu", "lý thuyết", "giả thuyết",
        "thí nghiệm", "bằng chứng", "khoa học", "phương pháp"
    ]

    private static let dailyWords = [
        "travel", "food", "eat", "drink", "health", "family", "friend", "house",
        "home", "feeling", "happy", "sad", "love", "opinion", "hobby", "sport",
        "weather", "music", "movie", "shopping", "daily", "cuộc sống", "gia đình",
        "bạn bè", "ăn uống", "sức khỏe", "cảm xúc", "du lịch", "thời tiết", "sở thích"
    ]
    
    private init() {}

    private func cachedOrCompute(for item: SavedWordItem) -> CachedClassification {
        if item.isGrammarFormula {
            return CachedClassification(priority: .grammar, partOfSpeech: .grammar, genre: .grammar)
        }
        let cacheKey = "\(item.cleanTitle)|\(item.translation)|\(item.exampleEn ?? "")"

        return state.withLock { s in
            if let hit = s.cache[cacheKey] {
                return hit
            }
            let priority = Self.computePriority(cleanTitle: item.cleanTitle)
            let pos = Self.computePartOfSpeech(cleanTitle: item.cleanTitle, translation: item.translation, tagger: s.tagger)
            let genre = Self.computeThematicGenre(cleanTitle: item.cleanTitle, translation: item.translation, exampleEn: item.exampleEn)

            let entry = CachedClassification(priority: priority, partOfSpeech: pos, genre: genre)
            if s.order.count >= Self.maxCacheEntries {
                let evicted = s.order.removeFirst()
                s.cache.removeValue(forKey: evicted)
            }
            s.order.append(cacheKey)
            s.cache[cacheKey] = entry
            return entry
        }
    }

    public func clearCache() {
        state.withLock { s in
            s.cache.removeAll()
            s.order.removeAll()
        }
    }
    
    // MARK: - 1. Classify AI Priority
    public func classifyPriority(for item: SavedWordItem) -> ItemAIPriority {
        cachedOrCompute(for: item).priority
    }

    private static func computePriority(cleanTitle: String) -> ItemAIPriority {
        let clean = cleanTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.contains(" ") || clean.contains("-") {
            return .phrases
        }
        let hasAcademicSuffix = academicSuffixes.contains { clean.hasSuffix($0) }
        if clean.count >= 7 || hasAcademicSuffix {
            return .advanced
        }
        return .core
    }
    
    // MARK: - 2. Classify Part of Speech using Apple NaturalLanguage
    public func classifyPartOfSpeech(for item: SavedWordItem) -> ItemAIPartOfSpeech {
        cachedOrCompute(for: item).partOfSpeech
    }

    private static func computePartOfSpeech(cleanTitle: String, translation: String, tagger: NLTagger) -> ItemAIPartOfSpeech {
        let clean = cleanTitle.lowercased()
        if clean.contains(" ") {
            return .adverb
        }
        
        tagger.string = clean
        defer { tagger.string = nil }
        let tag = tagger.tag(at: clean.startIndex, unit: .word, scheme: .lexicalClass).0
        
        switch tag {
        case .noun: return .noun
        case .verb: return .verb
        case .adjective: return .adjective
        case .adverb: return .adverb
        default:
            let lowerTrans = translation.lowercased()
            if lowerTrans.contains("noun") || lowerTrans.contains("danh từ") { return .noun }
            if lowerTrans.contains("verb") || lowerTrans.contains("động từ") { return .verb }
            if lowerTrans.contains("adj") || lowerTrans.contains("tính từ") { return .adjective }
            return .noun
        }
    }
    
    // MARK: - 3. Classify Thematic Genre
    public func classifyThematicGenre(for item: SavedWordItem) -> ItemThematicGenre {
        cachedOrCompute(for: item).genre
    }

    private static func computeThematicGenre(cleanTitle: String, translation: String, exampleEn: String?) -> ItemThematicGenre {
        let clean = (cleanTitle + " " + translation + " " + (exampleEn ?? "")).lowercased()
        if techWords.contains(where: { clean.contains($0) }) { return .technology }
        if businessWords.contains(where: { clean.contains($0) }) { return .business }
        if academicWords.contains(where: { clean.contains($0) }) { return .academic }
        if dailyWords.contains(where: { clean.contains($0) }) { return .dailyLife }
        return .general
    }
}
