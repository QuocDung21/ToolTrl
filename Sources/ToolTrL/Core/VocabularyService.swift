import Foundation

public struct SavedWordItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public let word: String
    public let phonetic: String?
    public let translation: String
    public let dateAdded: Date
    public var isFavorite: Bool
    
    public init(id: UUID = UUID(), word: String, phonetic: String?, translation: String, dateAdded: Date = Date(), isFavorite: Bool = true) {
        self.id = id
        self.word = word
        self.phonetic = phonetic
        self.translation = translation
        self.dateAdded = dateAdded
        self.isFavorite = isFavorite
    }
}

@MainActor
public final class VocabularyService: ObservableObject {
    public static let shared = VocabularyService()
    
    private let storageKey = "saved_vocabulary_items"
    
    @Published public var savedWords: [SavedWordItem] = []
    
    private init() {
        loadWords()
    }
    
    public func loadWords() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let items = try? JSONDecoder().decode([SavedWordItem].self, from: data) else {
            self.savedWords = []
            return
        }
        self.savedWords = items
    }
    
    private func saveWords() {
        if let data = try? JSONEncoder().encode(savedWords) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    public func isWordSaved(_ word: String) -> Bool {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return savedWords.contains { $0.word.lowercased() == clean }
    }
    
    public func toggleSaveWord(word: String, phonetic: String?, translation: String) {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        if let index = savedWords.firstIndex(where: { $0.word.lowercased() == clean.lowercased() }) {
            savedWords.remove(at: index)
        } else {
            let newItem = SavedWordItem(
                word: clean,
                phonetic: phonetic,
                translation: translation
            )
            savedWords.insert(newItem, at: 0)
        }
        saveWords()
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
