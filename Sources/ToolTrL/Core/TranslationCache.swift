import Foundation

public final class TranslationCache: @unchecked Sendable {
    public static let shared = TranslationCache()
    
    private let translationCache = NSCache<NSString, NSString>()
    private let dictionaryCache = NSCache<NSString, AnyObject>()
    
    private init() {
        translationCache.countLimit = 500
        dictionaryCache.countLimit = 200
    }
    
    // MARK: - Translation Cache
    public func getTranslation(key: String) -> String? {
        return translationCache.object(forKey: key as NSString) as String?
    }
    
    public func setTranslation(key: String, value: String) {
        translationCache.setObject(value as NSString, forKey: key as NSString)
    }
    
    // MARK: - Dictionary Cache
    public func getDictionaryEntry(key: String) -> RichWordEntry? {
        if let box = dictionaryCache.object(forKey: key.lowercased() as NSString) as? DictionaryCacheBox {
            return box.entry
        }
        return nil
    }
    
    public func setDictionaryEntry(key: String, entry: RichWordEntry) {
        dictionaryCache.setObject(DictionaryCacheBox(entry: entry), forKey: key.lowercased() as NSString)
    }
    
    public func clearAll() {
        translationCache.removeAllObjects()
        dictionaryCache.removeAllObjects()
    }
}

private final class DictionaryCacheBox: NSObject {
    let entry: RichWordEntry
    init(entry: RichWordEntry) {
        self.entry = entry
    }
}
