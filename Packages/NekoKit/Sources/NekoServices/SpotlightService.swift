import Foundation
import CoreSpotlight

/// Service managing cleanup of NekoTrans data from macOS Spotlight.
/// Indexing has been removed per user requirement to eliminate unnecessary system indexing.
public final class SpotlightService: Sendable {
    public static let shared = SpotlightService()
    
    private let domainIdentifiers = [
        "com.quocdung.tooltrl.vocabulary",
        "com.nekotrans.mac.vocabulary"
    ]
    
    private init() {}
    
    /// Completely clear and purge any NekoTrans indexed items from macOS CoreSpotlight.
    public func clearAllIndex(completion: (@Sendable (Error?) -> Void)? = nil) {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: domainIdentifiers) { error in
            if let error = error {
                AppLog.spotlight.error("Clear-index failed: \(error.localizedDescription, privacy: .public)")
            } else {
                AppLog.spotlight.notice("Cleaned and purged all items from macOS Spotlight.")
            }
            completion?(error)
        }
    }
}
