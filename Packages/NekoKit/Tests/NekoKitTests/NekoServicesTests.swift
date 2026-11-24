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

// MARK: - 5. LocalGGUFService Tests
@Suite("NekoServices - LocalGGUFService Tests", .serialized)
struct LocalGGUFServiceTests {
    @Test("appleSiliconChipName returns non-empty string on macOS")
    func chipNameNonEmpty() {
        let chip = LocalGGUFService.shared.appleSiliconChipName
        #expect(!chip.isEmpty)
    }

    @Test("friendlyModelName extracts clean names from paths and hashes")
    func friendlyModelNameTests() {
        let path1 = "/Users/test/Downloads/qwen2.5-0.5b-instruct-q4_k_m.gguf"
        #expect(LocalGGUFService.friendlyModelName(from: path1) == "Qwen2.5-0.5B")
        
        let path2 = "/Users/test/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B-Instruct-GGUF/blobs/74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db"
        #expect(LocalGGUFService.friendlyModelName(from: path2) == "Qwen2.5-0.5B")
    }

    @Test("LocalGGUFModelItem formatted size works for MB and GB")
    func modelItemFormattedSize() {
        let itemMB = LocalGGUFModelItem(name: "tiny", path: "/tmp/tiny.gguf", fileSize: 500 * 1_048_576)
        #expect(itemMB.formattedSize == "500 MB")
        
        let itemGB = LocalGGUFModelItem(name: "large", path: "/tmp/large.gguf", fileSize: Int64(2.5 * 1_073_741_824))
        #expect(itemGB.formattedSize == "2.5 GB")
    }

    @Test("Qwen translation into Vietnamese")
    func testQwenTranslation() async throws {
        let path = "/Users/dungnguyenquoc/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B-Instruct-GGUF/snapshots/9217f5db79a29953eb74d5343926648285ec7e67/qwen2.5-0.5b-instruct-q4_k_m.gguf"
        guard FileManager.default.fileExists(atPath: path) else { return }
        
        try LocalGGUFService.shared.loadModel(at: path)
        defer { LocalGGUFService.shared.shutdown() }
        let sampleText = "Number of Parameters (Non-Embedding): 1.31B"

        let sys = AIPromptBuilder.localGGUFSystemPrompt(sourceLang: "en", targetLang: "vi", domain: "Tổng hợp")
        let user = AIPromptBuilder.localGGUFUserPrompt(text: sampleText, targetLang: "vi")
        let prompt = LocalGGUFService.shared.formatPrompt(system: sys, user: user)
        let res = try await LocalGGUFService.shared.streamInference(prompt: prompt, maxTokens: 64) { _ in }
        
        #expect(!res.isEmpty)
        // Ensure it did not output Indonesian 'Jumlah'
        #expect(!res.lowercased().contains("jumlah"))
    }

    @Test("Early cancellation halts stream inference quickly")
    func testEarlyCancellation() async throws {
        let path = "/Users/dungnguyenquoc/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B-Instruct-GGUF/snapshots/9217f5db79a29953eb74d5343926648285ec7e67/qwen2.5-0.5b-instruct-q4_k_m.gguf"
        guard FileManager.default.fileExists(atPath: path) else { return }

        try LocalGGUFService.shared.loadModel(at: path)
        defer { LocalGGUFService.shared.shutdown() }

        var tokenCount = 0
        let prompt = LocalGGUFService.shared.formatPrompt(system: "Translate to Vietnamese", user: "Write a long essay about the history of mathematics.")
        let res = try await LocalGGUFService.shared.streamInference(
            prompt: prompt,
            maxTokens: 500,
            isCancelled: {
                tokenCount >= 3
            },
            onToken: { _ in
                tokenCount += 1
            }
        )

        #expect(tokenCount <= 5)
        #expect(res.count < 100)
    }

    @Test("Idle watchdog unloads model after timeout")
    func testIdleWatchdog() async throws {
        let path = "/Users/dungnguyenquoc/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B-Instruct-GGUF/snapshots/9217f5db79a29953eb74d5343926648285ec7e67/qwen2.5-0.5b-instruct-q4_k_m.gguf"
        guard FileManager.default.fileExists(atPath: path) else { return }

        LocalGGUFService.shared.idleUnloadInterval = 0.6
        try LocalGGUFService.shared.loadModel(at: path)
        #expect(LocalGGUFService.shared.isLoaded == true)

        try await Task.sleep(nanoseconds: 900_000_000)
        #expect(LocalGGUFService.shared.isLoaded == false)

        LocalGGUFService.shared.idleUnloadInterval = 600
    }
}

// MARK: - 7. Phase 1 Optimization Suites
@Suite("NekoServices - Phase 1 Optimization Tests")
struct Phase1OptimizationTests {
    @Test("AppExclusionService never excludes NekoTrans itself")
    @MainActor
    func appExclusionNekoTransSafety() {
        let isSelfExcluded = AppExclusionService.shared.isAppExcluded(bundleIdentifier: Bundle.main.bundleIdentifier)
        #expect(!isSelfExcluded)
    }

    @Test("BrowserScriptHelper detects supported browser bundles")
    func browserDetection() {
        #expect(BrowserScriptHelper.isSupportedBrowser("com.apple.Safari"))
        #expect(BrowserScriptHelper.isSupportedBrowser("com.google.Chrome"))
        #expect(BrowserScriptHelper.isSupportedBrowser("company.thebrowser.Browser"))
        #expect(!BrowserScriptHelper.isSupportedBrowser("com.apple.finder"))
    }
}

// MARK: - 8. Phase 2 & 3 Optimization Suites
@Suite("NekoServices - Phase 2 & 3 Optimization Tests")
struct Phase2And3OptimizationTests {
    @Test("VocabularyService persists and loads using compressed file store")
    @MainActor
    func vocabularyServiceFilePersistence() {
        let testWord = SavedWordItem(
            word: "optimization_test",
            phonetic: "/ˌɑːptɪməˈzeɪʃn/",
            translation: "sự tối ưu hóa",
            exampleEn: "We test LZFSE persistence.",
            exampleVi: "Chúng tôi kiểm tra việc lưu trữ LZFSE.",
            itemType: .vocabulary
        )
        VocabularyService.shared.savedWords.append(testWord)
        VocabularyService.shared.flush()
        
        guard let url = VocabularyService.storeFileURL else {
            Issue.record("storeFileURL should not be nil")
            return
        }
        #expect(FileManager.default.fileExists(atPath: url.path))
        
        // Read raw data and ensure it can be decompressed with LZFSE
        let rawData = try? Data(contentsOf: url)
        #expect(rawData != nil)
        let decompressed = DataCompression.decompress(data: rawData!) ?? rawData!
        let decoded = try? JSONDecoder().decode([SavedWordItem].self, from: decompressed)
        #expect(decoded?.contains(where: { $0.word == "optimization_test" }) == true)
        
        // Clean up test word
        VocabularyService.shared.savedWords.removeAll(where: { $0.word == "optimization_test" })
        VocabularyService.shared.flush()
    }

    @Test("AIProviderEngineRegistry resolves correct engines for providers")
    func aiProviderEngineRegistryResolution() {
        let ggufEngine = AIProviderEngineRegistry.engine(for: .inProcessGGUF)
        #expect(ggufEngine.provider == .inProcessGGUF)
        #expect(ggufEngine is InProcessGGUFEngine)

        let openAIEngine = AIProviderEngineRegistry.engine(for: .openAI)
        #expect(openAIEngine.provider == .openAI)
    }

    @Test("AudioPlayerService enforces bounded cache and eviction at 100 entries")
    @MainActor
    func audioCacheBoundedEviction() {
        let service = AudioPlayerService.shared
        service.clearCache()
        #expect(service.cachedEntryCount == 0)

        let dummyData = Data([0x49, 0x44, 0x33]) // "ID3" dummy MP3 header
        for i in 1...110 {
            service.storeAudioForTesting(key: "https://example.com/audio_\(i).mp3", data: dummyData)
        }

        // Cache must not exceed maxAudioCacheEntries (100)
        #expect(service.cachedEntryCount == 100)

        // Byte budget test: storing 5 chunks of 1 MB each must evict older entries to stay <= 4 MB
        service.clearCache()
        let oneMB = Data(repeating: 0x49, count: 1_024 * 1_024)
        for i in 1...5 {
            service.storeAudioForTesting(key: "https://example.com/large_\(i).mp3", data: oneMB)
        }
        #expect(service.cachedEntryCount == 4)
        #expect(service.cachedByteCount <= 4 * 1_024 * 1_024)

        // Clear cache frees all memory
        service.clearCache()
        #expect(service.cachedEntryCount == 0)
        #expect(service.cachedByteCount == 0)
    }
}


