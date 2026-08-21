import Foundation

public struct SavedWordItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public let word: String
    public let phonetic: String?
    public let translation: String
    public let exampleEn: String?
    public let exampleVi: String?
    public let dateAdded: Date
    public var isFavorite: Bool
    public var isMastered: Bool
    
    public init(
        id: UUID = UUID(),
        word: String,
        phonetic: String?,
        translation: String,
        exampleEn: String? = nil,
        exampleVi: String? = nil,
        dateAdded: Date = Date(),
        isFavorite: Bool = false,
        isMastered: Bool = false
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
    }
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
