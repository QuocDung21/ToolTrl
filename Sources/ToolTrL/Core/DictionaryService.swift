import Foundation
import CoreServices

@MainActor
public final class DictionaryService {
    public static let shared = DictionaryService()

    private init() {}

    /// Look up word definition in macOS built-in dictionaries
    public func lookup(term: String) -> String? {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let range = CFRangeMake(0, trimmed.utf16.count)
        guard let defRef = DCSCopyTextDefinition(nil, trimmed as CFString, range) else {
            return nil
        }

        let rawDef = defRef.takeRetainedValue() as String
        let cleaned = rawDef.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}
