import Testing
import Foundation
import Defaults
@testable import NekoCore
@testable import NekoServices

// MARK: - 1. TranslationCache Tests
@Suite("NekoServices - TranslationCache Tests")
struct TranslationCacheTests {
    @Test("TranslationCache stores and retrieves cached string translations")
    func cacheSetAndGet() async {
        let key = "test_key_\(UUID().uuidString)"
        let value = "Xin chào thế giới"

        await TranslationCache.shared.setTranslation(key: key, value: value)
        let retrieved = await TranslationCache.shared.getTranslation(key: key)

        #expect(retrieved == value)
    }

    @Test("TranslationCache stores and persists rich dictionary entries")
    func cacheDictionaryEntryPersistence() async {
        let word = "testword_\(UUID().uuidString)"
        let entry = RichWordEntry(
            word: word,
            phonetic: "/test/",
            ukAudioURL: nil,
            usAudioURL: nil,
            mainTranslation: "từ thử nghiệm",
            meanings: [
                MeaningGroup(partOfSpeech: "noun", definitions: [
                    DefinitionItem(definitionEn: "a test word")
                ])
            ],
            allSynonyms: ["trial"],
            allAntonyms: []
        )

        await TranslationCache.shared.setDictionaryEntry(key: word, entry: entry)
        let retrieved = await TranslationCache.shared.getDictionaryEntry(key: word)

        #expect(retrieved != nil)
        #expect(retrieved?.word == word)
        #expect(retrieved?.mainTranslation == "từ thử nghiệm")
        #expect(retrieved?.allSynonyms.contains("trial") == true)
    }
}

// MARK: - 2. SmartDictionaryService Tests
@Suite("NekoServices - SmartDictionaryService Tests")
struct SmartDictionaryServiceTests {
    @Test("Clean concise meaning chunk balances unclosed parentheses and trims punctuation")
    func cleanConciseMeaningChunk() {
        let chunkWithUnclosedParen = "sự việc (xảy ra bất ngờ"
        let cleaned = SmartDictionaryService.cleanConciseMeaningChunk(chunkWithUnclosedParen)
        #expect(cleaned == "sự việc")

        let chunkWithTrailingPeriod = "Tra trong từ điển."
        let cleanedPeriod = SmartDictionaryService.cleanConciseMeaningChunk(chunkWithTrailingPeriod)
        #expect(cleanedPeriod == "Tra trong từ điển")
    }

    @Test("SmartDictionaryService lemmatizes inflected English words")
    @MainActor
    func lemmatization() {
        let lemma1 = SmartDictionaryService.shared.findLemma(for: "went")
        #expect(lemma1 == "go")

        let lemma2 = SmartDictionaryService.shared.findLemma(for: "running")
        #expect(lemma2 == "run")

        let lemma3 = SmartDictionaryService.shared.findLemma(for: "boxes")
        #expect(lemma3 == "box")

        let lemma4 = SmartDictionaryService.shared.findLemma(for: "taken")
        #expect(lemma4 == "take")
    }

    @Test("RichWordEntry concise parts extraction groups meanings by part of speech")
    func richWordEntryConciseParts() {
        let def1 = DefinitionItem(
            definitionEn: "A book or electronic resource that lists the words of a language.",
            definitionVi: "Một cuốn sách hoặc tài liệu điện tử liệt kê các từ của một ngôn ngữ.",
            exampleEn: nil,
            exampleVi: nil
        )
        let def2 = DefinitionItem(
            definitionEn: "To look up in a dictionary.",
            definitionVi: "Tra trong từ điển.",
            exampleEn: nil,
            exampleVi: nil
        )
        let def3 = DefinitionItem(
            definitionEn: "To compile into a dictionary.",
            definitionVi: "Biên soạn từ điển.",
            exampleEn: nil,
            exampleVi: nil
        )

        let nounGroup = MeaningGroup(
            partOfSpeech: "noun",
            definitions: [def1],
            synonyms: ["wordbook"],
            antonyms: []
        )
        let verbGroup = MeaningGroup(
            partOfSpeech: "verb",
            definitions: [def2, def3],
            synonyms: [],
            antonyms: []
        )

        let entry = RichWordEntry(
            word: "Dictionary",
            phonetic: "/'dɪkʃə,nɛɹi/",
            mainTranslation: "từ điển",
            meanings: [nounGroup, verbGroup],
            allSynonyms: ["wordbook"],
            allAntonyms: []
        )

        let conciseParts = entry.conciseParts
        #expect(conciseParts.count == 2)

        let nounPart = conciseParts.first(where: { $0.part == "n." })
        #expect(nounPart != nil)
        #expect(nounPart?.partFullName == "Danh từ")
        #expect(nounPart?.meanings.contains("từ điển") == true)

        let verbPart = conciseParts.first(where: { $0.part == "v." })
        #expect(verbPart != nil)
        #expect(verbPart?.partFullName == "Động từ")
        #expect(verbPart?.meanings.contains("Tra trong từ điển") == true)
        #expect(verbPart?.meanings.contains("Biên soạn từ điển") == true)
    }
}

// MARK: - 3. MyMemory Response Validator Tests
@Suite("NekoServices - MyMemory Response Tests")
struct MyMemoryResponseTests {
    @Test("MyMemory parses successful HTTP 200 translation")
    func parsesSuccessfulTranslation() {
        let json: [String: Any] = [
            "responseStatus": 200,
            "responseData": [
                "translatedText": "Xin chào thế giới"
            ]
        ]
        let outcome = MyMemoryResponse.parse(json)
        if case .translation(let text) = outcome {
            #expect(text == "Xin chào thế giới")
        } else {
            Issue.record("Expected successful translation outcome")
        }
    }

    @Test("MyMemory rejects refusal sentences served as translated text")
    func rejectsRefusals() {
        let json: [String: Any] = [
            "responseStatus": 200,
            "responseData": [
                "translatedText": "PLEASE SELECT TWO DISTINCT LANGUAGES"
            ]
        ]
        let outcome = MyMemoryResponse.parse(json)
        if case .rejected = outcome {
            // Success
        } else {
            Issue.record("Expected refusal detection")
        }
    }

    @Test("MyMemory rejects exhausted quota (status 429)")
    func rejectsExhaustedQuota() {
        let json: [String: Any] = [
            "responseStatus": 429,
            "responseData": [
                "translatedText": "MYMEMORY WARNING: YOU USED ALL AVAILABLE FREE TRANSLATIONS TODAY"
            ]
        ]
        let outcome = MyMemoryResponse.parse(json)
        if case .rejected = outcome {
            // Success
        } else {
            Issue.record("Expected rejection for status 429")
        }
    }

    @Test("MyMemory rejects error sentence even when status is 200")
    func rejectsErrorSentenceStatus200() {
        let json: [String: Any] = [
            "responseStatus": 200,
            "responseData": [
                "translatedText": "QUERY LENGTH LIMIT EXCEEDED. MAX ALLOWED QUERY : 500 CHARS"
            ]
        ]
        let outcome = MyMemoryResponse.parse(json)
        if case .rejected(let reason) = outcome {
            #expect(reason.contains("QUERY LENGTH LIMIT EXCEEDED"))
        } else {
            Issue.record("Expected refusal for limit exceeded")
        }
    }
}

// MARK: - 4. Service Integrations Tests
@Suite("NekoServices - Service Integrations Tests")
struct ServiceIntegrationsTests {
    @Test("TranslationService circuit breaker trips and resets cleanly")
    @MainActor
    func circuitBreaker() {
        let service = TranslationService.shared
        service.tripGoogleWebCircuit(duration: 2)
        #expect(service.isCircuitOpen)

        service.resetCircuitBreaker()
        #expect(!service.isCircuitOpen)
    }

    @Test("AppExclusionService toggles and checks bundle exclusions")
    @MainActor
    func appExclusion() {
        let service = AppExclusionService.shared
        let testBundle = "com.test.exclusion.app"

        service.addExcludedApp(bundleIdentifier: testBundle)
        #expect(service.isAppExcluded(bundleIdentifier: testBundle))

        service.removeExcludedApp(bundleIdentifier: testBundle)
        #expect(!service.isAppExcluded(bundleIdentifier: testBundle))
    }

    @Test("ContinuousJournalService resolves journal file and decodes entries")
    func continuousJournal() {
        let service = ContinuousJournalService.shared
        #expect(service.journalFileURL.lastPathComponent == "words.jsonl")

        let entry = ContinuousJournalService.JournalEntry(
            timestamp: "2026-10-21T00:00:00Z",
            word: "ephemeral",
            phonetic: "/ɪˈfem.ər.əl/",
            translation: "phù du",
            sourceLang: "en",
            targetLang: "vi",
            context: "Life is ephemeral."
        )

        let encoder = JSONEncoder()
        let data = try? encoder.encode(entry)
        #expect(data != nil)

        if let data = data {
            let decoded = try? JSONDecoder().decode(ContinuousJournalService.JournalEntry.self, from: data)
            #expect(decoded?.word == "ephemeral")
            #expect(decoded?.translation == "phù du")
        }
    }

    @Test("AnkiError description formatting")
    func ankiErrorDescriptions() {
        let err1 = AnkiError.serverUnavailable
        #expect(err1.errorDescription?.isEmpty == false)

        let err2 = AnkiError.ankiError("Deck not found")
        #expect(err2.errorDescription?.contains("Deck not found") == true)
    }
}

// MARK: - 5. LocalAIService Tests
@Suite("NekoServices - LocalAIService Tests")
struct LocalAIServiceTests {
    @Test("normalizeEndpoint handles trailing slashes, whitespace, and missing scheme")
    func normalizeEndpoint() {
        let s = LocalAIService.shared

        #expect(s.normalizeEndpoint("http://localhost:11434/") == "http://localhost:11434")
        #expect(s.normalizeEndpoint("  http://localhost:11434///  ") == "http://localhost:11434")
        #expect(s.normalizeEndpoint("localhost:11434") == "http://localhost:11434")
        #expect(s.normalizeEndpoint("") == "http://localhost:11434")
        #expect(s.normalizeEndpoint("https://my-local-ai.lan:8080/") == "https://my-local-ai.lan:8080")
    }

    @Test("appleSiliconChipName returns non-empty string on macOS")
    func chipNameNonEmpty() {
        let chip = LocalAIService.shared.appleSiliconChipName
        #expect(!chip.isEmpty)
    }

    @Test("LocalAIModelInfo formatting handles parameter size, family, and byte count")
    func modelInfoFormatting() {
        let model = LocalAIModelInfo(
            id: "llama3.2:latest",
            name: "llama3.2:latest",
            sizeInBytes: 2019393189,
            parameterSize: "3.2B",
            family: "llama",
            quantization: "Q4_K_M"
        )

        #expect(model.id == "llama3.2:latest")
        #expect(model.parameterSize == "3.2B")
        #expect(model.quantization == "Q4_K_M")
        #expect(model.formattedSize != nil)
        #expect(model.displayName.contains("llama3.2:latest"))
        #expect(model.displayName.contains("3.2B"))
        #expect(model.displayName.contains("Q4_K_M"))
    }

    @Test("LocalAIBackendType default endpoints and descriptions")
    func backendTypeProperties() {
        #expect(LocalAIBackendType.ollama.defaultEndpoint == "http://localhost:11434")
        #expect(LocalAIBackendType.lmStudio.defaultEndpoint == "http://localhost:1234")
        #expect(LocalAIBackendType.mlxOrLocalAI.defaultEndpoint == "http://localhost:8080")
        #expect(LocalAIBackendType.allCases.count == 4)
    }
}

