import Foundation
import Combine

public struct TranslationHistoryItem: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let originalText: String
    public let translatedText: String
    public let sourceLang: String
    public let targetLang: String
    public let timestamp: Date
    public let engine: String
    
    public init(
        id: UUID = UUID(),
        originalText: String,
        translatedText: String,
        sourceLang: String,
        targetLang: String,
        timestamp: Date = Date(),
        engine: String
    ) {
        self.id = id
        self.originalText = originalText
        self.translatedText = translatedText
        self.sourceLang = sourceLang
        self.targetLang = targetLang
        self.timestamp = timestamp
        self.engine = engine
    }
}

@MainActor
public final class TranslationHistoryService: ObservableObject {
    public static let shared = TranslationHistoryService()
    
    @Published public private(set) var items: [TranslationHistoryItem] = []
    
    private let maxItemCount = 200
    private var saveDebounceTask: Task<Void, Never>?
    
    private static var storageURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = appSupport.appendingPathComponent("NekoTrans", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("translation_history.json")
    }
    
    private init() {
        loadHistory()
    }
    
    public func record(
        originalText: String,
        translatedText: String,
        sourceLang: String,
        targetLang: String,
        engine: String
    ) {
        let trimmedOriginal = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTranslation = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedOriginal.isEmpty, !trimmedTranslation.isEmpty else { return }
        
        // Remove existing identical item if already present recently to avoid duplicate flood
        items.removeAll {
            $0.originalText.caseInsensitiveCompare(trimmedOriginal) == .orderedSame &&
            $0.targetLang == targetLang
        }
        
        let newItem = TranslationHistoryItem(
            originalText: trimmedOriginal,
            translatedText: trimmedTranslation,
            sourceLang: sourceLang,
            targetLang: targetLang,
            timestamp: Date(),
            engine: engine
        )
        
        items.insert(newItem, at: 0)
        
        if items.count > maxItemCount {
            items = Array(items.prefix(maxItemCount))
        }
        
        scheduleSave()
    }
    
    public func delete(id: UUID) {
        items.removeAll { $0.id == id }
        scheduleSave()
    }
    
    public func clearAll() {
        items.removeAll()
        scheduleSave()
    }
    
    private func loadHistory() {
        guard let url = Self.storageURL, FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode([TranslationHistoryItem].self, from: data)
            self.items = decoded
        } catch {
            AppLog.history.error("Failed to load history: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func scheduleSave() {
        saveDebounceTask?.cancel()
        saveDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms debounce
            guard !Task.isCancelled else { return }
            self.persistToDisk()
        }
    }
    
    private func persistToDisk() {
        guard let url = Self.storageURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            let data = try encoder.encode(items)
            try data.write(to: url, options: [.atomic])
        } catch {
            AppLog.history.error("Failed to save history: \(error.localizedDescription, privacy: .public)")
        }
    }
}
