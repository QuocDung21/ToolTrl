import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Service integrating NekoTrans Saved Vocabulary & Grammar directly into macOS Spotlight (Cmd + Space)
public final class SpotlightService: @unchecked Sendable {
    public static let shared = SpotlightService()
    
    private let index = CSSearchableIndex.default()
    /// Frozen on purpose: this identifier owns every item already indexed on a user's
    /// Mac. Renaming it orphans those entries in Spotlight until the legacy domain is
    /// explicitly deleted, so it is not part of the ToolTrL -> NekoTrans rename.
    private let domainIdentifier = "com.quocdung.tooltrl.vocabulary"
    
    private init() {}
    
    /// Index a single item into macOS Spotlight Search
    public func indexItem(_ item: SavedWordItem) {
        index.indexSearchableItems([searchableItem(for: item)]) { error in
            if let error = error {
                AppLog.spotlight.error("Indexing failed for [\(item.cleanTitle, privacy: .private)]: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    /// Batch index all items into macOS Spotlight
    public func indexAllItems(_ items: [SavedWordItem]) {
        guard !items.isEmpty else {
            clearAllIndex()
            return
        }
        
        index.indexSearchableItems(items.map(searchableItem(for:))) { error in
            if let error = error {
                AppLog.spotlight.error("Batch indexing failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    /// Single source of truth for how a notebook entry looks in Spotlight, so single and
    /// batch indexing can no longer drift apart (they previously used different keywords).
    func searchableItem(for item: SavedWordItem) -> CSSearchableItem {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
        attributeSet.title = item.cleanTitle
        attributeSet.displayName = item.cleanTitle
        
        var description = item.translation
        if let ph = item.phonetic, !ph.isEmpty {
            description += " • \(ph)"
        }
        if let ex = item.exampleEn, !ex.isEmpty {
            description += "\n\"\(ex)\""
        }
        
        attributeSet.contentDescription = description
        attributeSet.keywords = [
            item.cleanTitle,
            item.translation,
            item.aiThematicGenre.rawValue,
            item.aiPartOfSpeech.rawValue,
            item.isGrammarFormula ? "Ngữ pháp" : "Từ vựng",
            "NekoTrans"
        ]
        
        return CSSearchableItem(
            uniqueIdentifier: item.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )
    }
    
    /// Remove an item from macOS Spotlight
    public func removeItem(id: UUID) {
        index.deleteSearchableItems(withIdentifiers: [id.uuidString]) { error in
            if let error = error {
                AppLog.spotlight.error("Item deletion failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    /// Clear all NekoTrans indexed data from macOS Spotlight
    public func clearAllIndex() {
        index.deleteSearchableItems(withDomainIdentifiers: [domainIdentifier]) { error in
            if let error = error {
                AppLog.spotlight.error("Clear-index failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
