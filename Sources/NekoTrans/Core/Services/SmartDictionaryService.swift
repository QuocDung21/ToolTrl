import Foundation
import NaturalLanguage

public struct DefinitionItem: Identifiable, Sendable, Codable {
    public var id = UUID()
    public let definitionEn: String
    public var definitionVi: String?
    public let exampleEn: String?
    public var exampleVi: String?
}

public struct MeaningGroup: Identifiable, Sendable, Codable {
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

public struct RichWordEntry: Sendable, Codable {
    public let word: String
    public let phonetic: String?
    public var ukAudioURL: String?
    public var usAudioURL: String?
    public var mainTranslation: String
    public var meanings: [MeaningGroup]
    public var allSynonyms: [String]
    public var allAntonyms: [String]
    public var semanticNeighbors: [String] // Apple NaturalLanguage NLEmbedding vector space neighbors
    public var baseLemma: String? // Base lemma if this is an inflected form (e.g. went -> go)
    
    public init(
        word: String,
        phonetic: String?,
        ukAudioURL: String? = nil,
        usAudioURL: String? = nil,
        mainTranslation: String,
        meanings: [MeaningGroup],
        allSynonyms: [String],
        allAntonyms: [String],
        semanticNeighbors: [String] = [],
        baseLemma: String? = nil
    ) {
        self.word = word
        self.phonetic = phonetic
        self.ukAudioURL = ukAudioURL
        self.usAudioURL = usAudioURL
        self.mainTranslation = mainTranslation
        self.meanings = meanings
        self.allSynonyms = allSynonyms
        self.allAntonyms = allAntonyms
        self.semanticNeighbors = semanticNeighbors
        self.baseLemma = baseLemma
    }
}

// MARK: - Decodable Raw API Models
private struct RawPhonetic: Codable {
    let text: String?
    let audio: String?
}

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
    let phonetics: [RawPhonetic]?
    let meanings: [RawMeaning]
}

@MainActor
public final class SmartDictionaryService {
    public static let shared = SmartDictionaryService()
    private let englishEmbedding = NLEmbedding.wordEmbedding(for: .english)
    
    private init() {}
    
    /// Finds semantically similar words offline using Apple Neural NLP Embedding (0ms latency, zero tokens)
    public func findSemanticNeighbors(for word: String, maxCount: Int = 8) -> [String] {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty, let embedding = englishEmbedding else { return [] }
        
        let neighbors = embedding.neighbors(for: clean, maximumCount: maxCount)
        return neighbors.map { $0.0 }
    }
    
    /// Finds the base dictionary lemma for inflected words using Apple NaturalLanguage (e.g. went -> go, happier -> happy)
    public func findLemma(for word: String) -> String? {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty, !clean.contains(" ") else { return nil }
        
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = clean
        let (tag, _) = tagger.tag(at: clean.startIndex, unit: .word, scheme: .lemma)
        if let lemma = tag?.rawValue, !lemma.isEmpty, lemma.lowercased() != clean {
            return lemma.lowercased()
        }
        return nil
    }
    
    /// Fetch rich dictionary entry with bilingual explanations, examples, human audio, Apple Neural Embeddings & Lemmatization
    public func fetchRichEntry(for rawWord: String, targetLanguage: String = "vi") async -> RichWordEntry? {
        let cleanWord = rawWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanWord.isEmpty else { return nil }
        
        let cacheKey = "\(cleanWord)_\(targetLanguage)"
        if let cached = await TranslationCache.shared.getDictionaryEntry(key: cacheKey) {
            return cached
        }
        
        let semanticWords = findSemanticNeighbors(for: cleanWord, maxCount: 8)
        let detectedLemma = findLemma(for: cleanWord)
        
        // Attempt 1: Fetch direct word entry
        if let entry = await fetchEntryFromAPI(word: cleanWord, originalQuery: rawWord, targetLanguage: targetLanguage, semanticWords: semanticWords, baseLemma: nil) {
            await TranslationCache.shared.setDictionaryEntry(key: cacheKey, entry: entry)
            AudioPlayerService.shared.prefetchAudio(from: entry.ukAudioURL)
            AudioPlayerService.shared.prefetchAudio(from: entry.usAudioURL)
            return entry
        }
        
        // Attempt 2: If direct word fails and a base lemma exists (e.g. went -> go, leaves -> leaf), fetch lemma entry
        if let lemma = detectedLemma,
           let entry = await fetchEntryFromAPI(word: lemma, originalQuery: rawWord, targetLanguage: targetLanguage, semanticWords: semanticWords, baseLemma: lemma) {
            await TranslationCache.shared.setDictionaryEntry(key: cacheKey, entry: entry)
            AudioPlayerService.shared.prefetchAudio(from: entry.ukAudioURL)
            AudioPlayerService.shared.prefetchAudio(from: entry.usAudioURL)
            return entry
        }
        
        // Attempt 3: Fallback using macOS Dictionary & Apple NLP offline extraction
        let directTranslation = await TranslationService.shared.translate(text: rawWord, from: "auto", to: targetLanguage) ?? ""
        let offlinePhonetic = DictionaryService.shared.extractPhonetic(for: rawWord) ?? (detectedLemma != nil ? DictionaryService.shared.extractPhonetic(for: detectedLemma!) : nil)
        
        var offlineMeaningGroups = await extractOfflineMeaningGroups(
            for: cleanWord,
            originalQuery: rawWord,
            targetLanguage: targetLanguage,
            directTranslation: directTranslation
        )
        
        if offlineMeaningGroups.isEmpty, let lemma = detectedLemma {
            offlineMeaningGroups = await extractOfflineMeaningGroups(
                for: lemma,
                originalQuery: rawWord,
                targetLanguage: targetLanguage,
                directTranslation: directTranslation
            )
        }
        
        if offlineMeaningGroups.isEmpty {
            let tagger = NLTagger(tagSchemes: [.lexicalClass])
            tagger.string = cleanWord
            let tag = tagger.tag(at: cleanWord.startIndex, unit: .word, scheme: .lexicalClass).0
            let posName: String = {
                switch tag {
                case .noun: return "noun"
                case .verb: return "verb"
                case .adjective: return "adjective"
                case .adverb: return "adverb"
                case .pronoun: return "pronoun"
                case .preposition: return "preposition"
                case .conjunction: return "conjunction"
                default: return "noun"
                }
            }()
            
            let defItem = DefinitionItem(
                definitionEn: cleanWord.capitalized,
                definitionVi: !directTranslation.isEmpty ? directTranslation : nil,
                exampleEn: nil,
                exampleVi: nil
            )
            offlineMeaningGroups.append(MeaningGroup(
                partOfSpeech: posName,
                definitions: [defItem],
                synonyms: semanticWords,
                antonyms: []
            ))
        }
        
        let primaryTranslation = !directTranslation.isEmpty ? directTranslation : (offlineMeaningGroups.first?.definitions.first?.definitionVi ?? cleanWord.capitalized)
        
        let fallbackEntry = RichWordEntry(
            word: rawWord.capitalized,
            phonetic: offlinePhonetic,
            ukAudioURL: nil,
            usAudioURL: nil,
            mainTranslation: primaryTranslation,
            meanings: offlineMeaningGroups,
            allSynonyms: semanticWords,
            allAntonyms: [],
            semanticNeighbors: semanticWords,
            baseLemma: detectedLemma
        )
        
        if !fallbackEntry.meanings.isEmpty {
            await TranslationCache.shared.setDictionaryEntry(key: cacheKey, entry: fallbackEntry)
        }
        return fallbackEntry
    }
    
    private func extractOfflineMeaningGroups(
        for word: String,
        originalQuery: String,
        targetLanguage: String,
        directTranslation: String
    ) async -> [MeaningGroup] {
        let offlineGroups = DictionaryService.shared.extractOfflineMeanings(for: word)
        guard !offlineGroups.isEmpty else { return [] }
        
        var meaningGroups: [MeaningGroup] = []
        var itemsToTranslate: [(gIdx: Int, dIdx: Int, isEx: Bool, text: String)] = []
        
        for (gIdx, og) in offlineGroups.enumerated() {
            var defItems: [DefinitionItem] = []
            for (dIdx, d) in og.definitions.enumerated() {
                defItems.append(DefinitionItem(
                    definitionEn: d.definitionEn,
                    definitionVi: (gIdx == 0 && dIdx == 0 && !directTranslation.isEmpty) ? directTranslation : nil,
                    exampleEn: d.exampleEn,
                    exampleVi: nil
                ))
                itemsToTranslate.append((gIdx: gIdx, dIdx: dIdx, isEx: false, text: d.definitionEn))
                if let ex = d.exampleEn, !ex.isEmpty {
                    itemsToTranslate.append((gIdx: gIdx, dIdx: dIdx, isEx: true, text: ex))
                }
            }
            meaningGroups.append(MeaningGroup(
                partOfSpeech: og.partOfSpeech,
                definitions: defItems,
                synonyms: [],
                antonyms: []
            ))
        }
        
        if !itemsToTranslate.isEmpty {
            let joinedText = itemsToTranslate.enumerated().map { "\($0.offset + 1). \($0.element.text)" }.joined(separator: "\n")
            if let batchTranslated = await TranslationService.shared.translateFallback(
                text: joinedText,
                from: "en",
                to: targetLanguage
            ) {
                let lines = batchTranslated.components(separatedBy: "\n")
                let linePattern = #"^(\d+)[\.\:\-\s]+(.*)$"#
                let lineRegex = try? NSRegularExpression(pattern: linePattern)
                var translatedMap: [Int: String] = [:]
                
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedLine.isEmpty else { continue }
                    if let regex = lineRegex,
                       let match = regex.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)),
                       let numRange = Range(match.range(at: 1), in: trimmedLine),
                       let textRange = Range(match.range(at: 2), in: trimmedLine),
                       let num = Int(trimmedLine[numRange]) {
                        translatedMap[num] = String(trimmedLine[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                
                for (idx, item) in itemsToTranslate.enumerated() {
                    if let trans = translatedMap[idx + 1], !trans.isEmpty {
                        if item.isEx {
                            meaningGroups[item.gIdx].definitions[item.dIdx].exampleVi = trans
                        } else {
                            meaningGroups[item.gIdx].definitions[item.dIdx].definitionVi = trans
                        }
                    }
                }
            }
        }
        
        return meaningGroups
    }
    
    private func fetchEntryFromAPI(
        word: String,
        originalQuery: String,
        targetLanguage: String,
        semanticWords: [String],
        baseLemma: String?
    ) async -> RichWordEntry? {
        guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/en/\(encoded)") else {
            return nil
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 3.5
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return nil
            }
            
            let rawEntries = try JSONDecoder().decode([RawEntry].self, from: data)
            guard let firstEntry = rawEntries.first else { return nil }
            
            // Extract Phonetic IPA String with multi-source fallback
            var extractedPhonetic: String? = firstEntry.phonetic
            if extractedPhonetic == nil || extractedPhonetic?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                if let phonetics = firstEntry.phonetics {
                    for ph in phonetics {
                        if let t = ph.text, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            extractedPhonetic = t.trimmingCharacters(in: .whitespacesAndNewlines)
                            break
                        }
                    }
                }
            }
            if extractedPhonetic == nil || extractedPhonetic?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                extractedPhonetic = DictionaryService.shared.extractPhonetic(for: originalQuery) ?? DictionaryService.shared.extractPhonetic(for: word)
            }
            
            // Extract UK & US Audio URLs
            var ukAudio: String? = nil
            var usAudio: String? = nil
            
            if let phonetics = firstEntry.phonetics {
                for ph in phonetics {
                    guard let rawAudio = ph.audio?.trimmingCharacters(in: .whitespacesAndNewlines), !rawAudio.isEmpty else { continue }
                    var audio = rawAudio
                    if audio.hasPrefix("//") {
                        audio = "https:" + audio
                    } else if audio.hasPrefix("http://") {
                        audio = "https://" + audio.dropFirst(7)
                    } else if !audio.hasPrefix("https://") {
                        audio = "https://" + audio
                    }
                    
                    let audioLow = audio.lowercased()
                    if audioLow.contains("-uk") || audioLow.contains("/uk/") || audioLow.hasSuffix("uk.mp3") || audioLow.contains("_gb_") || audioLow.contains("-gb.") {
                        if ukAudio == nil { ukAudio = audio }
                    } else if audioLow.contains("-us") || audioLow.contains("/us/") || audioLow.hasSuffix("us.mp3") || audioLow.contains("_us_") || audioLow.contains("-us.") {
                        if usAudio == nil { usAudio = audio }
                    } else {
                        if usAudio == nil { usAudio = audio }
                    }
                }
                // Fallback if only one audio is available
                if ukAudio == nil && usAudio != nil { ukAudio = usAudio }
                if usAudio == nil && ukAudio != nil { usAudio = ukAudio }
            }
            
            var meaningGroups: [MeaningGroup] = []
            var allSyns: Set<String> = []
            var allAnts: Set<String> = []
            
            var textsToTranslate: [String] = []
            
            for rawMeaning in firstEntry.meanings {
                if let syns = rawMeaning.synonyms {
                    for s in syns { allSyns.insert(s) }
                }
                if let ants = rawMeaning.antonyms {
                    for a in ants { allAnts.insert(a) }
                }
                
                var defItems: [DefinitionItem] = []
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
            
            async let mainTransTask = TranslationService.shared.translateFallback(
                text: originalQuery,
                from: "en",
                to: targetLanguage
            )
            
            struct ItemToTranslate {
                let gIdx: Int
                let dIdx: Int
                let isExample: Bool
                let text: String
            }
            
            var batchItems: [ItemToTranslate] = []
            for gIdx in 0..<meaningGroups.count {
                for dIdx in 0..<meaningGroups[gIdx].definitions.count {
                    let defEn = meaningGroups[gIdx].definitions[dIdx].definitionEn
                    batchItems.append(ItemToTranslate(gIdx: gIdx, dIdx: dIdx, isExample: false, text: defEn))
                    
                    if let exEn = meaningGroups[gIdx].definitions[dIdx].exampleEn, !exEn.isEmpty {
                        batchItems.append(ItemToTranslate(gIdx: gIdx, dIdx: dIdx, isExample: true, text: exEn))
                    }
                }
            }
            
            if !batchItems.isEmpty {
                let joinedText = batchItems.enumerated().map { "\($0.offset + 1). \($0.element.text)" }.joined(separator: "\n")
                if let batchTranslated = await TranslationService.shared.translateFallback(
                    text: joinedText,
                    from: "en",
                    to: targetLanguage
                ) {
                    let lines = batchTranslated.components(separatedBy: "\n")
                    var translatedMap: [Int: String] = [:]
                    
                    let linePattern = #"^(\d+)[\.\:\-\s]+(.*)$"#
                    let lineRegex = try? NSRegularExpression(pattern: linePattern)
                    
                    for line in lines {
                        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedLine.isEmpty else { continue }
                        
                        if let regex = lineRegex,
                           let match = regex.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)),
                           let numRange = Range(match.range(at: 1), in: trimmedLine),
                           let textRange = Range(match.range(at: 2), in: trimmedLine),
                           let itemNum = Int(trimmedLine[numRange]) {
                            let itemText = String(trimmedLine[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                            translatedMap[itemNum - 1] = itemText
                        }
                    }
                    
                    for (index, item) in batchItems.enumerated() {
                        let transText = translatedMap[index] ?? (index < lines.count ? lines[index].trimmingCharacters(in: .whitespacesAndNewlines) : nil)
                        if let transText = transText, !transText.isEmpty {
                            if item.isExample {
                                meaningGroups[item.gIdx].definitions[item.dIdx].exampleVi = transText
                            } else {
                                meaningGroups[item.gIdx].definitions[item.dIdx].definitionVi = transText
                            }
                        }
                    }
                }
            }
            
            let mainTranslation = await mainTransTask ?? originalQuery
            
            let displayWord = baseLemma != nil ? originalQuery.capitalized : firstEntry.word.capitalized
            
            let richEntry = RichWordEntry(
                word: displayWord,
                phonetic: extractedPhonetic,
                ukAudioURL: ukAudio,
                usAudioURL: usAudio,
                mainTranslation: mainTranslation,
                meanings: meaningGroups,
                allSynonyms: Array(allSyns),
                allAntonyms: Array(allAnts),
                semanticNeighbors: semanticWords,
                baseLemma: baseLemma
            )
            return richEntry
        } catch {
            AppLog.dictionary.error("Lookup failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
