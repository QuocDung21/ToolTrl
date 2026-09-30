import Foundation
import NaturalLanguage

public final class WordClassifierService: Sendable {
    public static let shared = WordClassifierService()
    
    private init() {}
    
    // MARK: - 1. Classify AI Priority
    public func classifyPriority(for item: SavedWordItem) -> ItemAIPriority {
        if item.isGrammarFormula { return .grammar }
        let clean = item.cleanTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.contains(" ") || clean.contains("-") {
            return .phrases
        }
        
        let academicSuffixes = [
            "tion", "sion", "ment", "able", "ible", "ology", "istic",
            "ize", "ify", "ance", "ence", "ous", "ive", "ity", "ical", "tude"
        ]
        let hasAcademicSuffix = academicSuffixes.contains { clean.hasSuffix($0) }
        
        if clean.count >= 7 || hasAcademicSuffix {
            return .advanced
        }
        return .core
    }
    
    // MARK: - 2. Classify Part of Speech using Apple NaturalLanguage
    public func classifyPartOfSpeech(for item: SavedWordItem) -> ItemAIPartOfSpeech {
        if item.isGrammarFormula { return .grammar }
        let clean = item.cleanTitle.lowercased()
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
            let lowerTrans = item.translation.lowercased()
            if lowerTrans.contains("noun") || lowerTrans.contains("danh từ") { return .noun }
            if lowerTrans.contains("verb") || lowerTrans.contains("động từ") { return .verb }
            if lowerTrans.contains("adj") || lowerTrans.contains("tính từ") { return .adjective }
            return .noun
        }
    }
    
    // MARK: - 3. Classify Thematic Genre
    public func classifyThematicGenre(for item: SavedWordItem) -> ItemThematicGenre {
        if item.isGrammarFormula { return .grammar }
        let clean = (item.cleanTitle + " " + item.translation + " " + (item.exampleEn ?? "")).lowercased()
        
        let techWords = [
            "code", "software", "hardware", "data", "server", "app", "api", "database",
            "computer", "network", "system", "algorithm", "function", "variable", "class",
            "deploy", "debug", "cache", "memory", "compile", "terminal", "runtime", "cloud",
            "interface", "framework", "programming", "developer", "git", "web", "browser",
            "ios", "macos", "linux", "ai", "model", "token", "prompt", "công nghệ", "phần mềm",
            "lập trình", "dữ liệu", "máy chủ", "thuật toán"
        ]
        if techWords.contains(where: { clean.contains($0) }) {
            return .technology
        }
        
        let businessWords = [
            "business", "company", "market", "finance", "revenue", "profit", "budget",
            "meeting", "client", "customer", "project", "deadline", "contract", "salary",
            "career", "manager", "management", "strategy", "investment", "stakeholder",
            "colleague", "negotiate", "sales", "report", "công ty", "kinh doanh", "thị trường",
            "tài chính", "dự án", "đối tác", "hợp đồng", "quản lý", "doanh thu", "lợi nhuận", "chiến lược"
        ]
        if businessWords.contains(where: { clean.contains($0) }) {
            return .business
        }
        
        let academicWords = [
            "theory", "hypothesis", "experiment", "evidence", "science", "scientific",
            "methodology", "conclusion", "principle", "significant", "perspective",
            "evaluation", "literature", "academic", "research", "investigate", "scholarly",
            "philosoph", "psycholog", "học thuật", "nghiên cứu", "lý thuyết", "giả thuyết",
            "thí nghiệm", "bằng chứng", "khoa học", "phương pháp"
        ]
        if academicWords.contains(where: { clean.contains($0) }) {
            return .academic
        }
        
        let dailyWords = [
            "travel", "food", "eat", "drink", "health", "family", "friend", "house",
            "home", "feeling", "happy", "sad", "love", "opinion", "hobby", "sport",
            "weather", "music", "movie", "shopping", "daily", "cuộc sống", "gia đình",
            "bạn bè", "ăn uống", "sức khỏe", "cảm xúc", "du lịch", "thời tiết", "sở thích"
        ]
        if dailyWords.contains(where: { clean.contains($0) }) {
            return .dailyLife
        }
        
        return .general
    }
}
