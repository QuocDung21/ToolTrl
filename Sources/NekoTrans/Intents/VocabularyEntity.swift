import AppIntents
import Foundation

/// App Intents projection of a saved notebook entry (`SavedWordItem`).
///
/// The `id` is the item's persisted `UUID`, minted once at creation and stored with the
/// record, so Shortcuts/Siri references stay valid across launches.
struct VocabularyEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Mục sổ tay"
    static let defaultQuery = VocabularyEntityQuery()

    let id: UUID

    @Property(title: "Từ / Cấu trúc")
    var word: String

    @Property(title: "Nghĩa")
    var translation: String

    @Property(title: "Phiên âm / Công thức")
    var phonetic: String?

    @Property(title: "Ngữ pháp")
    var isGrammar: Bool

    @Property(title: "Yêu thích")
    var isFavorite: Bool

    @Property(title: "Đã thuộc")
    var isMastered: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(word)",
            subtitle: "\(translation)",
            image: .init(systemName: isGrammar ? "function" : "character.book.closed")
        )
    }

    init(item: SavedWordItem) {
        self.id = item.id
        self.word = item.cleanTitle
        self.translation = item.translation
        self.phonetic = item.phonetic
        self.isGrammar = item.isGrammarFormula
        self.isFavorite = item.isFavorite
        self.isMastered = item.isMastered
    }
}

/// Resolves notebook entries for Shortcuts / Siri pickers.
///
/// - `entities(for:)` resolves persisted ids in one batch (no N+1).
/// - `suggestedEntities()` feeds the picker (the framework default would be empty).
/// - `entities(matching:)` performs free-text search; the framework does not filter for us.
struct VocabularyEntityQuery: EntityStringQuery {
    private static let suggestionLimit = 30

    func entities(for identifiers: [UUID]) async throws -> [VocabularyEntity] {
        let wanted = Set(identifiers)
        return await MainActor.run {
            VocabularyService.shared.savedWords
                .filter { wanted.contains($0.id) }
                .map(VocabularyEntity.init(item:))
        }
    }

    func entities(matching string: String) async throws -> [VocabularyEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return try await suggestedEntities() }
        return await MainActor.run {
            VocabularyService.shared.savedWords
                .filter {
                    $0.cleanTitle.localizedCaseInsensitiveContains(needle)
                        || $0.translation.localizedCaseInsensitiveContains(needle)
                }
                .prefix(Self.suggestionLimit)
                .map(VocabularyEntity.init(item:))
        }
    }

    func suggestedEntities() async throws -> [VocabularyEntity] {
        await MainActor.run {
            VocabularyService.shared.savedWords
                .prefix(Self.suggestionLimit)
                .map(VocabularyEntity.init(item:))
        }
    }
}
