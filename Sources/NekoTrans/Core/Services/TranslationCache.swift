import Foundation

/// Swift 6 Actor-Isolated Multi-Tier Cache with Zero Race Conditions
public actor TranslationCache {
    public static let shared = TranslationCache()
    
    private var memoryTranslations: [String: String]
    private var memoryDictionaries: [String: RichWordEntry]
    
    private var diskTranslations: [String: String]
    private var diskDictionaries: [String: RichWordEntry]
    private var saveTask: Task<Void, Never>?
    
    private static var cacheFileURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = appSupport.appendingPathComponent("NekoTrans", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let newURL = folder.appendingPathComponent("translation_l2_cache.json")
        
        // Auto-migrate legacy cache from ToolTrL directory if it exists
        if !FileManager.default.fileExists(atPath: newURL.path) {
            let legacyURL = appSupport.appendingPathComponent("ToolTrL", isDirectory: true).appendingPathComponent("translation_l2_cache.json")
            if FileManager.default.fileExists(atPath: legacyURL.path) {
                try? FileManager.default.copyItem(at: legacyURL, to: newURL)
            }
        }
        
        return newURL
    }
    
    private init() {
        let loaded = Self.loadInitialData()
        self.diskTranslations = loaded.translations
        self.diskDictionaries = loaded.dictionaries
        
        var memTrans: [String: String] = [:]
        for (k, v) in loaded.translations.prefix(500) {
            memTrans[k] = v
        }
        self.memoryTranslations = memTrans
        
        var memDicts: [String: RichWordEntry] = [:]
        for (k, v) in loaded.dictionaries.prefix(200) where !v.meanings.isEmpty {
            memDicts[k] = v
        }
        self.memoryDictionaries = memDicts
    }
    
    // MARK: - Translation Cache (Async Actor-Isolated)
    public func getTranslation(key: String) -> String? {
        let normKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if let memoryVal = memoryTranslations[normKey] {
            return memoryVal
        }
        if let diskVal = diskTranslations[normKey] {
            memoryTranslations[normKey] = diskVal
            return diskVal
        }
        return nil
    }
    
    public func setTranslation(key: String, value: String) {
        let normKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normKey.isEmpty, !value.isEmpty else { return }
        memoryTranslations[normKey] = value
        diskTranslations[normKey] = value
        scheduleSaveToDisk()
    }
    
    // MARK: - Dictionary Cache
    public func getDictionaryEntry(key: String) -> RichWordEntry? {
        let normKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let entry = memoryDictionaries[normKey] {
            if !entry.meanings.isEmpty || !entry.mainTranslation.isEmpty {
                return entry
            }
        }
        if let diskEntry = diskDictionaries[normKey] {
            if !diskEntry.meanings.isEmpty || !diskEntry.mainTranslation.isEmpty {
                memoryDictionaries[normKey] = diskEntry
                return diskEntry
            }
        }
        return nil
    }
    
    public func setDictionaryEntry(key: String, entry: RichWordEntry) {
        let normKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normKey.isEmpty else { return }
        
        // Never overwrite a cached entry that has meanings with an entry that has no meanings
        if entry.meanings.isEmpty {
            if let existing = memoryDictionaries[normKey], !existing.meanings.isEmpty {
                return
            }
            if let existingDisk = diskDictionaries[normKey], !existingDisk.meanings.isEmpty {
                return
            }
        }
        
        memoryDictionaries[normKey] = entry
        diskDictionaries[normKey] = entry
        scheduleSaveToDisk()
    }
    
    public func clearAll() {
        memoryTranslations.removeAll()
        memoryDictionaries.removeAll()
        diskTranslations.removeAll()
        diskDictionaries.removeAll()
        if let url = Self.cacheFileURL {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    public func flushNow() {
        persistToDisk()
    }
    
    // MARK: - Structured Disk Persistence
    private struct PersistentCacheData: Codable {
        var translations: [String: String]
        var dictionaries: [String: RichWordEntry]
    }
    
    private static func loadInitialData() -> PersistentCacheData {
        guard let url = cacheFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(PersistentCacheData.self, from: data) else {
            return PersistentCacheData(translations: [:], dictionaries: [:])
        }
        let cleanDicts = decoded.dictionaries.filter { !$0.value.meanings.isEmpty }
        return PersistentCacheData(translations: decoded.translations, dictionaries: cleanDicts)
    }
    
    private func scheduleSaveToDisk() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s Debounce
            guard let self = self, !Task.isCancelled else { return }
            await self.persistToDisk()
        }
    }
    
    private func persistToDisk() {
        guard let url = Self.cacheFileURL else { return }
        
        if diskTranslations.count > 2500 {
            diskTranslations = Dictionary(uniqueKeysWithValues: Array(diskTranslations.suffix(2000)))
        }
        if diskDictionaries.count > 1000 {
            diskDictionaries = Dictionary(uniqueKeysWithValues: Array(diskDictionaries.suffix(800)))
        }
        
        let dataObj = PersistentCacheData(
            translations: diskTranslations,
            dictionaries: diskDictionaries
        )
        if let encoded = try? JSONEncoder().encode(dataObj) {
            try? encoded.write(to: url, options: .atomic)
        }
    }
}
