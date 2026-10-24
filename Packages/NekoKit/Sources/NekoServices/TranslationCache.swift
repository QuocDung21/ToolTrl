import Foundation
import NekoCore

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
        for (k, v) in loaded.dictionaries.prefix(200) where v.hasValidDefinitions {
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
            if memoryTranslations.count > 600 {
                memoryTranslations = Dictionary(uniqueKeysWithValues: Array(memoryTranslations.suffix(400)))
            }
            return diskVal
        }
        return nil
    }
    
    public func setTranslation(key: String, value: String) {
        let normKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normKey.isEmpty, !value.isEmpty else { return }
        memoryTranslations[normKey] = value
        if memoryTranslations.count > 600 {
            memoryTranslations = Dictionary(uniqueKeysWithValues: Array(memoryTranslations.suffix(400)))
        }
        diskTranslations[normKey] = value
        scheduleSaveToDisk()
    }
    
    // MARK: - Dictionary Cache
    public func getDictionaryEntry(key: String) -> RichWordEntry? {
        let normKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let entry = memoryDictionaries[normKey] {
            if let sanitized = Self.sanitize(entry) {
                return sanitized
            } else {
                memoryDictionaries.removeValue(forKey: normKey)
                diskDictionaries.removeValue(forKey: normKey)
                scheduleSaveToDisk()
            }
        }
        if let diskEntry = diskDictionaries[normKey] {
            if let sanitized = Self.sanitize(diskEntry) {
                memoryDictionaries[normKey] = sanitized
                if memoryDictionaries.count > 250 {
                    memoryDictionaries = Dictionary(uniqueKeysWithValues: Array(memoryDictionaries.suffix(180)))
                }
                return sanitized
            } else {
                diskDictionaries.removeValue(forKey: normKey)
                scheduleSaveToDisk()
            }
        }
        return nil
    }
    
    public func setDictionaryEntry(key: String, entry: RichWordEntry) {
        let normKey = key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normKey.isEmpty else { return }
        guard let sanitized = Self.sanitize(entry) else { return }
        
        // Never overwrite a cached entry with fewer definitions if the existing one is valid
        if let existing = memoryDictionaries[normKey], existing.totalDefinitionsCount > sanitized.totalDefinitionsCount {
            return
        }
        
        memoryDictionaries[normKey] = sanitized
        if memoryDictionaries.count > 250 {
            memoryDictionaries = Dictionary(uniqueKeysWithValues: Array(memoryDictionaries.suffix(180)))
        }
        diskDictionaries[normKey] = sanitized
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
    public struct PersistentCacheData: Codable, Sendable {
        /// Cache schema/quality version. Files written before the percent-encoding fix
        /// have no version and may hold values that are not translations at all.
        public var version: Int? = nil
        public var translations: [String: String]
        public var dictionaries: [String: RichWordEntry]

        public init(
            version: Int? = nil,
            translations: [String: String],
            dictionaries: [String: RichWordEntry]
        ) {
            self.version = version
            self.translations = translations
            self.dictionaries = dictionaries
        }
    }
    
    /// Bumped whenever the *content* of the cache stops being trustworthy.
    ///
    /// Version 2 discards the **translation** tier written while MyMemory was handed
    /// double-encoded queries: it echoed the percent escapes back, and those strings were
    /// cached as translations — so re-looking-up the same text would keep replaying the
    /// garbage. The dictionary tier is cleaned per value by `looksLikeEncodedJunk` instead,
    /// because a version bump alone provably missed entries there.
    public static let currentCacheVersion = 2
    
    /// Decodes persisted cache data.
    ///
    /// When the version does not match, the **translations** are dropped: older files may
    /// hold values that are not translations at all (the percent-encoding bug cached the
    /// engine's echoed query).
    ///
    /// Independently of the version, both tiers are then passed through
    /// `looksLikeEncodedJunk`, because the dictionary tier is not safe either: entries whose
    /// headline translation came from the same broken pipeline survive a version bump (the
    /// user's cache held `live typing playground_vi` -> `Trực tiếp%20Typing%20Playground`).
    public static func decodeCache(_ data: Data) -> PersistentCacheData? {
        guard let decoded = try? JSONDecoder().decode(PersistentCacheData.self, from: data) else {
            return nil
        }

        let translations = decoded.version == currentCacheVersion ? decoded.translations : [:]

        return PersistentCacheData(
            version: currentCacheVersion,
            translations: translations.filter { !looksLikeEncodedJunk($0.value) },
            dictionaries: decoded.dictionaries.compactMapValues { sanitize($0) }
        )
    }

    /// True when a cached string looks like a percent-encoded request rather than a
    /// translation.
    ///
    /// A double-encoded query kept its spaces as `%20`, so the engines echoed strings such
    /// as `Trực tiếp%20Typing%20Playground`. Natural prose does not contain runs of percent
    /// escapes, so such a value is treated as corrupt: dropping it only costs one request
    /// and can never surface a wrong translation.
    public static func looksLikeEncodedJunk(_ text: String) -> Bool {
        guard text.contains("%") else { return false }

        let characters = Array(text.uppercased())
        var escapes = 0
        var spaceEscapes = 0
        var index = 0

        while index + 2 < characters.count {
            if characters[index] == "%", characters[index + 1].isHexDigit, characters[index + 2].isHexDigit {
                escapes += 1
                if characters[index + 1] == "2", characters[index + 2] == "0" {
                    spaceEscapes += 1
                }
                index += 3
                continue
            }
            index += 1
        }

        return escapes >= 2 && spaceEscapes >= 1
    }

    /// Drops percent-encoded junk from a cached entry.
    ///
    /// Returns `nil` when the headline translation is junk, so the entry is re-fetched.
    /// Vietnamese fields inside definitions are cleared individually, keeping the English
    /// half of the entry usable.
    private static func sanitize(_ entry: RichWordEntry) -> RichWordEntry? {
        guard !looksLikeEncodedJunk(entry.mainTranslation) else { return nil }

        // Filter meaning groups: strip junk translations and drop any group with 0 definitions
        let validMeanings = entry.meanings.compactMap { group -> MeaningGroup? in
            let validDefs = group.definitions.compactMap { definition -> DefinitionItem? in
                guard !definition.definitionEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
                var def = definition
                if let translation = def.definitionVi, looksLikeEncodedJunk(translation) {
                    def.definitionVi = nil
                }
                if let example = def.exampleVi, looksLikeEncodedJunk(example) {
                    def.exampleVi = nil
                }
                return def
            }
            guard !validDefs.isEmpty else { return nil }
            var g = group
            g.definitions = validDefs
            return g
        }

        var cleaned = entry
        cleaned.meanings = validMeanings

        // Sanitize and re-normalize phonetics to guarantee standard broad IPA and fix typos
        if let ph = cleaned.phonetic {
            cleaned.phonetic = IPANormalizer.normalize(ph, forWord: cleaned.word)
        }
        if let ukPh = cleaned.ukPhonetic {
            cleaned.ukPhonetic = IPANormalizer.normalize(ukPh, forWord: cleaned.word)
        }
        if let usPh = cleaned.usPhonetic {
            cleaned.usPhonetic = IPANormalizer.normalize(usPh, forWord: cleaned.word)
        }

        return cleaned
    }
    
    private static func loadInitialData() -> PersistentCacheData {
        let empty = PersistentCacheData(version: currentCacheVersion, translations: [:], dictionaries: [:])
        guard let url = cacheFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let rawData = try? Data(contentsOf: url) else {
            return empty
        }
        let data = DataCompression.decompress(data: rawData) ?? rawData
        guard let decoded = decodeCache(data) else {
            return empty
        }
        let cleanDicts = decoded.dictionaries.compactMapValues { Self.sanitize($0) }
        return PersistentCacheData(
            version: currentCacheVersion,
            translations: decoded.translations,
            dictionaries: cleanDicts
        )
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
            version: Self.currentCacheVersion,
            translations: diskTranslations,
            dictionaries: diskDictionaries
        )
        if let encoded = try? JSONEncoder().encode(dataObj) {
            let toWrite = DataCompression.compress(data: encoded) ?? encoded
            try? toWrite.write(to: url, options: .atomic)
        }
    }
}
