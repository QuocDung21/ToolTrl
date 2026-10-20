import Foundation
import NaturalLanguage

public struct DefinitionItem: Identifiable, Sendable, Codable {
    public var id = UUID()
    public let definitionEn: String
    public var definitionVi: String?
    public let exampleEn: String?
    public var exampleVi: String?

    public init(
        id: UUID = UUID(),
        definitionEn: String,
        definitionVi: String? = nil,
        exampleEn: String? = nil,
        exampleVi: String? = nil
    ) {
        self.id = id
        self.definitionEn = definitionEn
        self.definitionVi = definitionVi
        self.exampleEn = exampleEn
        self.exampleVi = exampleVi
    }
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
    
    public var partOfSpeechAbbr: String {
        InputTextNormalizer.partAbbreviation(partOfSpeech)
    }

    public init(
        id: UUID = UUID(),
        partOfSpeech: String,
        definitions: [DefinitionItem],
        synonyms: [String] = [],
        antonyms: [String] = []
    ) {
        self.id = id
        self.partOfSpeech = partOfSpeech
        self.definitions = definitions
        self.synonyms = synonyms
        self.antonyms = antonyms
    }
}

/// Concise part-of-speech grouped meaning item.
/// Directly inherited from Easydict's `EZTranslatePart` model.
public struct ConciseWordPart: Identifiable, Sendable, Codable, Equatable {
    public var id: String { part }
    public let part: String            // "n.", "v.", "adj."
    public let partFullName: String    // "Danh từ", "Động từ"
    public var meanings: [String]      // ["từ điển", "cuốn từ điển"]
    
    public var meaningsJoined: String {
        meanings
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: ".;:,- ")) }
            .filter { !$0.isEmpty }
            .joined(separator: "; ")
    }
    
    public init(part: String, partFullName: String, meanings: [String]) {
        self.part = part
        self.partFullName = partFullName
        self.meanings = meanings
    }
}

public struct RichWordEntry: Sendable, Codable {
    public let word: String
    public var phonetic: String?
    public var ukPhonetic: String?
    public var usPhonetic: String?
    public var ukAudioURL: String?
    public var usAudioURL: String?
    public var mainTranslation: String
    public var meanings: [MeaningGroup]
    public var allSynonyms: [String]
    public var allAntonyms: [String]
    public var semanticNeighbors: [String] // Apple NaturalLanguage NLEmbedding vector space neighbors
    public var baseLemma: String? // Base lemma if this is an inflected form (e.g. went -> go)
    public var bilingualParts: [ConciseWordPart]? = nil
    
    public init(
        word: String,
        phonetic: String?,
        ukPhonetic: String? = nil,
        usPhonetic: String? = nil,
        ukAudioURL: String? = nil,
        usAudioURL: String? = nil,
        mainTranslation: String,
        meanings: [MeaningGroup],
        allSynonyms: [String],
        allAntonyms: [String],
        semanticNeighbors: [String] = [],
        baseLemma: String? = nil,
        bilingualParts: [ConciseWordPart]? = nil
    ) {
        self.word = word
        self.phonetic = phonetic
        self.ukPhonetic = ukPhonetic
        self.usPhonetic = usPhonetic
        self.ukAudioURL = ukAudioURL
        self.usAudioURL = usAudioURL
        self.mainTranslation = mainTranslation
        self.meanings = meanings
        self.allSynonyms = allSynonyms
        self.allAntonyms = allAntonyms
        self.semanticNeighbors = semanticNeighbors
        self.baseLemma = baseLemma
        self.bilingualParts = bilingualParts
    }
    
    public var hasValidDefinitions: Bool {
        meanings.contains(where: { !$0.definitions.isEmpty }) || !(bilingualParts ?? []).isEmpty
    }
    
    public var totalDefinitionsCount: Int {
        meanings.reduce(0) { $0 + $1.definitions.count }
    }
    
    /// Concise part-of-speech breakdown inherited from Easydict (e.g. n. từ điển; v. tra từ điển)
    public var conciseParts: [ConciseWordPart] {
        if let bd = bilingualParts, !bd.isEmpty {
            return bd
        }
        var parts: [ConciseWordPart] = []
        for (index, group) in meanings.enumerated() {
            guard !group.definitions.isEmpty else { continue }
            let abbr = InputTextNormalizer.partAbbreviation(group.partOfSpeech)
            let fullName = InputTextNormalizer.partFullName(group.partOfSpeech)
            
            var means: [String] = []
            
            // 1. If primary group (index == 0) and mainTranslation is available, use mainTranslation
            if index == 0 && !mainTranslation.isEmpty {
                means.append(mainTranslation)
            }
            
            // 2. Add short definitions from this group
            for def in group.definitions {
                if let vi = def.definitionVi?.trimmingCharacters(in: .whitespacesAndNewlines), !vi.isEmpty {
                    var candidate = vi
                    if candidate.count > 45 {
                        let delimiters = CharacterSet(charactersIn: ",;:")
                        let chunks = candidate.components(separatedBy: delimiters)
                        if let firstChunk = chunks.first {
                            candidate = firstChunk
                        }
                    }

                    // Balance unclosed parentheses and clean trailing punctuation
                    candidate = SmartDictionaryService.cleanConciseMeaningChunk(candidate)

                    if candidate.count >= 2 && candidate.count <= 45 && !means.contains(where: { $0.caseInsensitiveCompare(candidate) == .orderedSame }) {
                        if !candidate.lowercased().hasPrefix("tài liệu") && !candidate.lowercased().hasPrefix("một cuốn") {
                            means.append(candidate)
                        }
                    }
                }
            }
            
            // 3. Fallback if means is empty
            if means.isEmpty {
                if !mainTranslation.isEmpty {
                    means.append(mainTranslation)
                } else if let firstDef = group.definitions.first {
                    let text = firstDef.definitionVi ?? firstDef.definitionEn
                    let short = String(text.prefix(35)).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !short.isEmpty {
                        means.append(short)
                    }
                }
            }
            
            let trimmedMeans = Array(means.prefix(3))
            if !trimmedMeans.isEmpty {
                if let existingIndex = parts.firstIndex(where: { $0.part == abbr }) {
                    for m in trimmedMeans {
                        if !parts[existingIndex].meanings.contains(where: { $0.caseInsensitiveCompare(m) == .orderedSame }) {
                            parts[existingIndex].meanings.append(m)
                        }
                    }
                } else {
                    parts.append(ConciseWordPart(part: abbr, partFullName: fullName, meanings: trimmedMeans))
                }
            }
        }
        
        if parts.isEmpty && !mainTranslation.isEmpty {
            parts.append(ConciseWordPart(part: "n.", partFullName: "Danh từ", meanings: [mainTranslation]))
        }
        
        return parts
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
    
    /// Balances parentheses and trims punctuation from extracted definition chunks
    nonisolated public static func cleanConciseMeaningChunk(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let openCount = text.filter { $0 == "(" }.count
        let closeCount = text.filter { $0 == ")" }.count
        if openCount > closeCount, let parenIdx = text.lastIndex(of: "(") {
            text = String(text[..<parenIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: ".;:,- "))
        return text
    }
    
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
        
        let detectedLemma = findLemma(for: cleanWord)
        let cacheKey = "\(cleanWord)_\(targetLanguage)_v2"
        if let cached = await TranslationCache.shared.getDictionaryEntry(key: cacheKey) {
            if cached.hasValidDefinitions {
                var validEntry = cached
                let targetWord = detectedLemma ?? cleanWord
                if let ph = validEntry.phonetic, let fixed = IPANormalizer.normalize(ph, forWord: targetWord), fixed != ph {
                    validEntry.phonetic = fixed
                    validEntry.ukPhonetic = IPANormalizer.normalize(validEntry.ukPhonetic, forWord: targetWord) ?? fixed
                    validEntry.usPhonetic = IPANormalizer.normalize(validEntry.usPhonetic, forWord: targetWord) ?? fixed
                    await TranslationCache.shared.setDictionaryEntry(key: cacheKey, entry: validEntry)
                }
                return validEntry
            }
        }
        
        let semanticWords = findSemanticNeighbors(for: cleanWord, maxCount: 8)
        
        // Attempt 1: Fetch direct word entry
        if let entry = await fetchEntryFromAPI(word: cleanWord, originalQuery: rawWord, targetLanguage: targetLanguage, semanticWords: semanticWords, baseLemma: nil) {
            if entry.hasValidDefinitions {
                await TranslationCache.shared.setDictionaryEntry(key: cacheKey, entry: entry)
                AudioPlayerService.shared.prefetchAudio(from: entry.ukAudioURL)
                AudioPlayerService.shared.prefetchAudio(from: entry.usAudioURL)
                return entry
            }
        }
        
        // Attempt 2: If direct word fails and a base lemma exists (e.g. went -> go, leaves -> leaf), fetch lemma entry
        if let lemma = detectedLemma,
           let entry = await fetchEntryFromAPI(word: lemma, originalQuery: rawWord, targetLanguage: targetLanguage, semanticWords: semanticWords, baseLemma: lemma) {
            if entry.hasValidDefinitions {
                await TranslationCache.shared.setDictionaryEntry(key: cacheKey, entry: entry)
                AudioPlayerService.shared.prefetchAudio(from: entry.ukAudioURL)
                AudioPlayerService.shared.prefetchAudio(from: entry.usAudioURL)
                return entry
            }
        }
        
        // Attempt 3: Fallback using macOS Dictionary & Apple NLP offline extraction
        let directTranslation = await TranslationService.shared.translate(text: rawWord, from: "auto", to: targetLanguage) ?? ""
        let offlinePhonetic = (detectedLemma != nil ? DictionaryService.shared.extractPhonetic(for: detectedLemma!) : nil) ?? DictionaryService.shared.extractPhonetic(for: rawWord)
        
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
        
        // Ensure offlineMeaningGroups only retains groups with at least one non-empty definition
        offlineMeaningGroups = offlineMeaningGroups.filter { !$0.definitions.isEmpty }
        
        if offlineMeaningGroups.isEmpty {
            let tagger = NLTagger(tagSchemes: [.lexicalClass])
            tagger.string = cleanWord
            let tag = tagger.tag(at: cleanWord.startIndex, unit: .word, scheme: .lexicalClass).0
            let commonPrepositions: Set<String> = [
                "in", "on", "at", "by", "for", "with", "about", "against", "between",
                "into", "through", "during", "before", "after", "above", "below",
                "to", "from", "up", "down", "off", "over", "under", "near"
            ]
            let posName: String = {
                switch tag {
                case .noun: return "noun"
                case .verb: return "verb"
                case .adjective: return "adjective"
                case .adverb: return "adverb"
                case .pronoun: return "pronoun"
                case .preposition: return commonPrepositions.contains(cleanWord) ? "preposition" : "noun"
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
        
        let targetWord = detectedLemma ?? cleanWord
        let normalizedOffline = IPANormalizer.normalize(offlinePhonetic, forWord: targetWord)
        let fallbackEntry = RichWordEntry(
            word: rawWord.capitalized,
            phonetic: normalizedOffline,
            ukPhonetic: normalizedOffline,
            usPhonetic: normalizedOffline,
            ukAudioURL: nil,
            usAudioURL: nil,
            mainTranslation: primaryTranslation,
            meanings: offlineMeaningGroups,
            allSynonyms: semanticWords,
            allAntonyms: [],
            semanticNeighbors: semanticWords,
            baseLemma: detectedLemma
        )
        
        if fallbackEntry.hasValidDefinitions {
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
            guard !og.items.isEmpty else { continue }
            var defItems: [DefinitionItem] = []
            var allSynonymsForGroup: [String] = []
            
            for (dIdx, item) in og.items.enumerated() {
                let isDefVi = OfflineDictionaryParser.containsVietnamese(item.definition)
                
                let defEn: String
                let defVi: String?
                
                if isDefVi {
                    // Definition is ALREADY in Vietnamese!
                    defEn = item.definition
                    defVi = nil
                } else {
                    defEn = item.definition
                    defVi = (gIdx == 0 && dIdx == 0 && !directTranslation.isEmpty) ? directTranslation : item.definitionTranslation
                    if defVi == nil {
                        itemsToTranslate.append((gIdx: gIdx, dIdx: dIdx, isEx: false, text: item.definition))
                    }
                }
                
                let exEn = item.example
                let exVi = item.exampleTranslation
                
                if let ex = exEn, exVi == nil, !ex.isEmpty {
                    if !OfflineDictionaryParser.containsVietnamese(ex) {
                        itemsToTranslate.append((gIdx: gIdx, dIdx: dIdx, isEx: true, text: ex))
                    }
                }
                
                defItems.append(DefinitionItem(
                    definitionEn: defEn,
                    definitionVi: defVi,
                    exampleEn: exEn,
                    exampleVi: exVi
                ))
                
                allSynonymsForGroup.append(contentsOf: item.synonyms)
            }
            
            if !defItems.isEmpty {
                meaningGroups.append(MeaningGroup(
                    partOfSpeech: og.partOfSpeech,
                    definitions: defItems,
                    synonyms: allSynonymsForGroup,
                    antonyms: []
                ))
            }
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
        guard let url = SafeURL.make(
            host: "api.dictionaryapi.dev",
            pathPrefix: "/api/v2/entries/en/",
            segment: word
        ) else {
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
            
            // Extract UK & US Audio URLs and Phonetics
            var ukAudio: String? = nil
            var usAudio: String? = nil
            var ukPhonetic: String? = nil
            var usPhonetic: String? = nil
            var generalPhonetic: String? = IPANormalizer.normalize(firstEntry.phonetic)
            
            if let phonetics = firstEntry.phonetics {
                for ph in phonetics {
                    let cleanText = IPANormalizer.normalize(ph.text)
                    
                    var audio: String? = nil
                    if let rawAudio = ph.audio?.trimmingCharacters(in: .whitespacesAndNewlines), !rawAudio.isEmpty {
                        if rawAudio.hasPrefix("//") { audio = "https:" + rawAudio }
                        else if rawAudio.hasPrefix("http://") { audio = "https://" + rawAudio.dropFirst(7) }
                        else if !rawAudio.hasPrefix("https://") { audio = "https://" + rawAudio }
                        else { audio = rawAudio }
                    }
                    
                    let audioLow = (audio ?? "").lowercased()
                    let isUK = audioLow.contains("-uk") || audioLow.contains("/uk/") || audioLow.hasSuffix("uk.mp3") || audioLow.contains("_gb_") || audioLow.contains("-gb.")
                    let isUS = audioLow.contains("-us") || audioLow.contains("/us/") || audioLow.hasSuffix("us.mp3") || audioLow.contains("_us_") || audioLow.contains("-us.")
                    
                    if isUK {
                        if ukAudio == nil && audio != nil { ukAudio = audio }
                        if ukPhonetic == nil && cleanText != nil { ukPhonetic = cleanText }
                    } else if isUS {
                        if usAudio == nil && audio != nil { usAudio = audio }
                        if usPhonetic == nil && cleanText != nil { usPhonetic = cleanText }
                    } else {
                        if usAudio == nil && audio != nil { usAudio = audio }
                        if generalPhonetic == nil && cleanText != nil { generalPhonetic = cleanText }
                    }
                }
                
                // Fallbacks if only one audio is available
                if ukAudio == nil && usAudio != nil { ukAudio = usAudio }
                if usAudio == nil && ukAudio != nil { usAudio = ukAudio }
            }
            
            let targetWord = baseLemma ?? word
            let offlinePhonetic = IPANormalizer.normalize(
                DictionaryService.shared.extractPhonetic(for: targetWord) ?? DictionaryService.shared.extractPhonetic(for: originalQuery),
                forWord: targetWord
            )
            let finalPhonetic = IPANormalizer.normalize(
                generalPhonetic ?? ukPhonetic ?? usPhonetic ?? offlinePhonetic,
                forWord: targetWord
            )
            
            if ukPhonetic == nil { ukPhonetic = finalPhonetic }
            if usPhonetic == nil { usPhonetic = finalPhonetic }
            let extractedPhonetic = finalPhonetic
            
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
            async let bdTask = fetchGoogleBilingualParts(
                word: targetWord,
                targetLanguage: targetLanguage
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
            
            let bdResult = await bdTask
            let mainTranslation = await mainTransTask ?? bdResult.mainTranslation ?? originalQuery
            
            let displayWord = baseLemma != nil ? originalQuery.capitalized : firstEntry.word.capitalized
            
            let richEntry = RichWordEntry(
                word: displayWord,
                phonetic: extractedPhonetic,
                ukPhonetic: ukPhonetic,
                usPhonetic: usPhonetic,
                ukAudioURL: ukAudio,
                usAudioURL: usAudio,
                mainTranslation: mainTranslation,
                meanings: meaningGroups,
                allSynonyms: Array(allSyns),
                allAntonyms: Array(allAnts),
                semanticNeighbors: semanticWords,
                baseLemma: baseLemma,
                bilingualParts: bdResult.parts.isEmpty ? nil : bdResult.parts
            )
            return richEntry
        } catch {
            AppLog.dictionary.error("Lookup failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Fetches concise bilingual dictionary parts (POS -> concise target meanings) via Google GTX `dt=bd`.
    private func fetchGoogleBilingualParts(
        word: String,
        targetLanguage: String
    ) async -> (mainTranslation: String?, parts: [ConciseWordPart]) {
        guard let url = SafeURL.make(
            host: "translate.googleapis.com",
            path: "/translate_a/single",
            queryItems: [
                URLQueryItem(name: "client", value: "gtx"),
                URLQueryItem(name: "sl", value: "en"),
                URLQueryItem(name: "tl", value: targetLanguage),
                URLQueryItem(name: "dt", value: "t"),
                URLQueryItem(name: "dt", value: "bd"),
                URLQueryItem(name: "q", value: word)
            ]
        ) else {
            return (nil, [])
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2.5
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let json = try JSONSerialization.jsonObject(with: data) as? [Any] else {
                return (nil, [])
            }

            var mainTrans: String? = nil
            if let sentences = json.first as? [Any] {
                var full = ""
                for s in sentences {
                    if let sArr = s as? [Any], let t = sArr.first as? String {
                        full += t
                    }
                }
                let cleaned = full.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    mainTrans = cleaned
                }
            }

            var parts: [ConciseWordPart] = []
            if json.count > 1, let bdArray = json[1] as? [Any] {
                for posItem in bdArray {
                    guard let posArr = posItem as? [Any],
                          posArr.count >= 2,
                          let posName = posArr[0] as? String else { continue }

                    let abbr = InputTextNormalizer.partAbbreviation(posName)
                    let fullName = InputTextNormalizer.partFullName(posName)

                    var groupedMeanings: [String] = []

                    // Prefer detailed entry groups at posArr[2] to group close synonyms per line (like Laban/Oxford)
                    if posArr.count > 2, let detailedEntries = posArr[2] as? [Any] {
                        for item in detailedEntries.prefix(3) {
                            if let entryArr = item as? [Any],
                               let viWord = entryArr.first as? String {
                                let cleanVi = SmartDictionaryService.cleanConciseMeaningChunk(viWord)
                                if !cleanVi.isEmpty && !groupedMeanings.contains(where: { $0.caseInsensitiveCompare(cleanVi) == .orderedSame }) {
                                    groupedMeanings.append(cleanVi)
                                }
                            }
                        }
                    }

                    if groupedMeanings.isEmpty, let terms = posArr[1] as? [String] {
                        for t in terms.prefix(3) {
                            let cleanVi = SmartDictionaryService.cleanConciseMeaningChunk(t)
                            if !cleanVi.isEmpty && !groupedMeanings.contains(where: { $0.caseInsensitiveCompare(cleanVi) == .orderedSame }) {
                                groupedMeanings.append(cleanVi)
                            }
                        }
                    }

                    if !groupedMeanings.isEmpty {
                        parts.append(ConciseWordPart(
                            part: abbr,
                            partFullName: fullName,
                            meanings: Array(groupedMeanings.prefix(3))
                        ))
                    }
                }
            }

            return (mainTrans, parts)
        } catch {
            return (nil, [])
        }
    }
}
