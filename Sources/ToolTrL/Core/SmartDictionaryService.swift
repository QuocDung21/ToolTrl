import Foundation

public struct DefinitionItem: Identifiable, Sendable {
    public var id = UUID()
    public let definitionEn: String
    public var definitionVi: String?
    public let exampleEn: String?
    public var exampleVi: String?
}

public struct MeaningGroup: Identifiable, Sendable {
    public var id = UUID()
    public let partOfSpeech: String // e.g. "verb", "noun"
    public var partOfSpeechDisplay: String {
        switch partOfSpeech.lowercased() {
        case "verb": return "ĐỘNG TỪ (VERB)"
        case "noun": return "DANH TỪ (NOUN)"
        case "adjective": return "TÍNH TỪ (ADJECTIVE)"
        case "adverb": return "PHÓ TỪ (ADVERB)"
        case "pronoun": return "ĐẠI TỪ (PRONOUN)"
        case "preposition": return "GIỚI TỪ (PREPOSITION)"
        case "conjunction": return "LIÊN TỪ (CONJUNCTION)"
        case "interjection": return "THÁN TỪ (INTERJECTION)"
        default: return partOfSpeech.uppercased()
        }
    }
    public var definitions: [DefinitionItem]
    public var synonyms: [String]
    public var antonyms: [String]
}

public struct RichWordEntry: Sendable {
    public let word: String
    public let phonetic: String?
    public var mainTranslation: String
    public var meanings: [MeaningGroup]
    public var allSynonyms: [String]
    public var allAntonyms: [String]
}

// MARK: - Decodable Raw API Models
private struct RawDef: Codable {
    let definition: String
    let example: String?
    let synonyms: [String]?
    let antonyms: [String]?
}

private struct RawMeaning: Codable {
    let partOfSpeech: String
    let definitions: [RawDef]
    let synonyms: [String]?
    let antonyms: [String]?
}

private struct RawEntry: Codable {
    let word: String
    let phonetic: String?
    let meanings: [RawMeaning]
}

@MainActor
public final class SmartDictionaryService {
    public static let shared = SmartDictionaryService()
    
    private init() {}
    
    /// Fetch rich dictionary entry with bilingual explanations and examples
    public func fetchRichEntry(for rawWord: String, targetLanguage: String = "vi") async -> RichWordEntry? {
        let cleanWord = rawWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanWord.isEmpty else { return nil }
        
        let cacheKey = "\(cleanWord)_\(targetLanguage)"
        if let cached = TranslationCache.shared.getDictionaryEntry(key: cacheKey) {
            return cached
        }
        
        guard let encoded = cleanWord.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)") else {
            return nil
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 4.0
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                if let directTranslation = await TranslationService.shared.translate(text: rawWord, from: "auto", to: targetLanguage) {
                    let fallbackEntry = RichWordEntry(
                        word: rawWord.capitalized,
                        phonetic: nil,
                        mainTranslation: directTranslation,
                        meanings: [],
                        allSynonyms: [],
                        allAntonyms: []
                    )
                    TranslationCache.shared.setDictionaryEntry(key: cacheKey, entry: fallbackEntry)
                    return fallbackEntry
                }
                return nil
            }
            
            let rawEntries = try JSONDecoder().decode([RawEntry].self, from: data)
            guard let firstEntry = rawEntries.first else { return nil }
            
            // Gather groups
            var meaningGroups: [MeaningGroup] = []
            var allSyns: Set<String> = []
            var allAnts: Set<String> = []
            
            // Collect texts to batch-translate
            var textsToTranslate: [String] = []
            
            for rawMeaning in firstEntry.meanings {
                // Collect synonyms / antonyms
                if let syns = rawMeaning.synonyms {
                    for s in syns { allSyns.insert(s) }
                }
                if let ants = rawMeaning.antonyms {
                    for a in ants { allAnts.insert(a) }
                }
                
                var defItems: [DefinitionItem] = []
                // Take top 3 definitions per part of speech for a clean, concise UI
                let topDefs = rawMeaning.definitions.prefix(3)
                
                for d in topDefs {
                    textsToTranslate.append(d.definition)
                    if let ex = d.example {
                        textsToTranslate.append(ex)
                    }
                    if let sList = d.synonyms {
                        for s in sList { allSyns.insert(s) }
                    }
                    if let aList = d.antonyms {
                        for a in aList { allAnts.insert(a) }
                    }
                    
                    defItems.append(DefinitionItem(
                        definitionEn: d.definition,
                        definitionVi: nil,
                        exampleEn: d.example,
                        exampleVi: nil
                    ))
                }
                
                if !defItems.isEmpty {
                    meaningGroups.append(MeaningGroup(
                        partOfSpeech: rawMeaning.partOfSpeech,
                        definitions: defItems,
                        synonyms: rawMeaning.synonyms ?? [],
                        antonyms: rawMeaning.antonyms ?? []
                    ))
                }
            }
            
            // Translate the word itself
            let mainTranslation = await TranslationService.shared.translateFallback(
                text: cleanWord,
                from: "en",
                to: targetLanguage
            ) ?? cleanWord
            
            // Fast parallel translation of definitions and examples using structured TaskGroup
            await withTaskGroup(of: (groupIndex: Int, defIndex: Int, isExample: Bool, translated: String?).self) { group in
                for gIdx in 0..<meaningGroups.count {
                    for dIdx in 0..<meaningGroups[gIdx].definitions.count {
                        let defEn = meaningGroups[gIdx].definitions[dIdx].definitionEn
                        group.addTask {
                            let trans = await TranslationService.shared.translateFallback(
                                text: defEn,
                                from: "en",
                                to: targetLanguage
                            )
                            return (gIdx, dIdx, false, trans)
                        }
                        
                        if let exEn = meaningGroups[gIdx].definitions[dIdx].exampleEn {
                            group.addTask {
                                let trans = await TranslationService.shared.translateFallback(
                                    text: exEn,
                                    from: "en",
                                    to: targetLanguage
                                )
                                return (gIdx, dIdx, true, trans)
                            }
                        }
                    }
                }
                
                for await result in group {
                    if result.isExample {
                        meaningGroups[result.groupIndex].definitions[result.defIndex].exampleVi = result.translated
                    } else {
                        meaningGroups[result.groupIndex].definitions[result.defIndex].definitionVi = result.translated
                    }
                }
            }
            
            let richEntry = RichWordEntry(
                word: firstEntry.word.capitalized,
                phonetic: firstEntry.phonetic,
                mainTranslation: mainTranslation,
                meanings: meaningGroups,
                allSynonyms: Array(allSyns),
                allAntonyms: Array(allAnts)
            )
            TranslationCache.shared.setDictionaryEntry(key: cacheKey, entry: richEntry)
            return richEntry
        } catch {
            print("SmartDictionaryService error: \(error)")
            return nil
        }
    }
}
