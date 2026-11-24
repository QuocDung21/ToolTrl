import XCTest
import KeyboardShortcuts
import Defaults
@testable import NekoTrans

final class SecurityAndNetworkingTests: XCTestCase {
    // MARK: - 8. Advanced Direct AI & Contextual Translation Tests
    func testContextualTranslationPromptGeneration() {
        let prompt = AIPromptBuilder.contextualTranslationPrompt(
            text: "The quick brown fox jumps over the lazy dog.",
            sourceLang: "en",
            targetLang: "vi",
            domain: "Công nghệ & IT"
        )

        XCTAssertTrue(prompt.contains("The quick brown fox jumps over the lazy dog."))
        XCTAssertTrue(prompt.contains("Công nghệ & IT"))
        XCTAssertTrue(prompt.contains("Translate the following text from 'en' to 'vi'"))
    }

    func testGrammarAndPolishingPromptGeneration() {
        let prompt = AIPromptBuilder.grammarAndPolishingPrompt(text: "He go to school yesterday.", targetLang: "vi")
        XCTAssertTrue(prompt.contains("He go to school yesterday."))
        XCTAssertTrue(prompt.contains("academic_version"))
        XCTAssertTrue(prompt.contains("business_version"))
        XCTAssertTrue(prompt.contains("casual_version"))
    }

    func testWordInContextPromptGeneration() {
        let prompt = AIPromptBuilder.wordInContextPrompt(
            word: "bank",
            sentence: "He sat on the river bank watching the sunset.",
            targetLang: "vi"
        )
        XCTAssertTrue(prompt.contains("bank"))
        XCTAssertTrue(prompt.contains("He sat on the river bank watching the sunset."))
    }

    func testGrammarRewriteResultJSONDecoding() {
        let jsonString = """
        {
            "has_errors": true,
            "correction": "He went to school yesterday.",
            "explanation_vi": "Chia sai thì quá khứ của động từ 'go'.",
            "academic_version": "He attended school yesterday.",
            "business_version": "He was present at school yesterday.",
            "casual_version": "He went to school yesterday."
        }
        """

        let data = jsonString.data(using: .utf8)!
        let result = try? JSONDecoder().decode(GrammarRewriteResult.self, from: data)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.hasErrors)
        XCTAssertEqual(result!.correction, "He went to school yesterday.")
        XCTAssertEqual(result!.academicVersion, "He attended school yesterday.")
        XCTAssertEqual(result!.businessVersion, "He was present at school yesterday.")
    }

    func testTranslationEngineAndToneEnums() {
        XCTAssertEqual(TranslationEngine.allCases.count, 5)
        XCTAssertEqual(DirectAIProvider.allCases.count, 6)

        XCTAssertEqual(DirectAIProvider.openAI.defaultModel, "gpt-4o-mini")
        XCTAssertEqual(DirectAIProvider.googleGemini.defaultModel, "gemini-1.5-flash")
    }

    // MARK: - 8. TranslationHistoryService Tests
    @MainActor
    func testTranslationHistoryServiceRecordAndDeduplicate() {
        let history = TranslationHistoryService.shared
        history.clearAll()
        XCTAssertEqual(history.items.count, 0)

        history.record(
            originalText: "Hello world",
            translatedText: "Xin chào thế giới",
            sourceLang: "en",
            targetLang: "vi",
            engine: "Google Translate"
        )
        XCTAssertEqual(history.items.count, 1)
        XCTAssertEqual(history.items.first?.originalText, "Hello world")
        XCTAssertEqual(history.items.first?.translatedText, "Xin chào thế giới")

        // Record same word again: should update/move to top and not duplicate
        history.record(
            originalText: "hello world",
            translatedText: "Xin chào thế giới mới",
            sourceLang: "en",
            targetLang: "vi",
            engine: "Direct AI"
        )
        XCTAssertEqual(history.items.count, 1)
        XCTAssertEqual(history.items.first?.translatedText, "Xin chào thế giới mới")

        // Record another word
        history.record(
            originalText: "Apple",
            translatedText: "Quả táo",
            sourceLang: "en",
            targetLang: "vi",
            engine: "Google Translate"
        )
        XCTAssertEqual(history.items.count, 2)
        XCTAssertEqual(history.items.first?.originalText, "Apple")

        // Delete item
        if let firstId = history.items.first?.id {
            history.delete(id: firstId)
            XCTAssertEqual(history.items.count, 1)
            XCTAssertEqual(history.items.first?.originalText, "hello world")
        }

        // Clear all
        history.clearAll()
        XCTAssertEqual(history.items.count, 0)
    }

    // MARK: - 9. TranslationService Circuit Breaker Tests
    @MainActor
    func testTranslationServiceCircuitBreaker() {
        let service = TranslationService.shared
        service.resetCircuitBreaker()
        XCTAssertFalse(service.isCircuitOpen)

        // Trip circuit
        service.tripGoogleWebCircuit(duration: 60)
        XCTAssertTrue(service.isCircuitOpen)

        // Reset circuit
        service.resetCircuitBreaker()
        XCTAssertFalse(service.isCircuitOpen)
    }

    // MARK: - 10. Keychain Secret Storage Tests
    /// Unique probe account so tests never read or write a real user credential.
    private func makeProbeAccount() -> String {
        "nekotrans_tests_probe_\(UUID().uuidString)"
    }

    func testKeychainStoreRoundTrip() {
        let account = makeProbeAccount()
        defer { KeychainStore.remove(account: account) }

        XCTAssertNil(KeychainStore.string(for: account), "A fresh account must be empty")

        XCTAssertTrue(KeychainStore.set("sk-secret-value", for: account))
        XCTAssertEqual(KeychainStore.string(for: account), "sk-secret-value")

        // Overwriting an existing item must update in place, not duplicate or fail.
        XCTAssertTrue(KeychainStore.set("sk-rotated-value", for: account))
        XCTAssertEqual(KeychainStore.string(for: account), "sk-rotated-value")

        XCTAssertTrue(KeychainStore.remove(account: account))
        XCTAssertNil(KeychainStore.string(for: account))
    }

    func testKeychainSetEmptyStringRemovesItem() {
        let account = makeProbeAccount()
        defer { KeychainStore.remove(account: account) }

        KeychainStore.set("temporary", for: account)
        XCTAssertNotNil(KeychainStore.string(for: account))

        // Clearing the field in Settings must delete the secret, not store "".
        KeychainStore.set("", for: account)
        XCTAssertNil(KeychainStore.string(for: account))
    }

    func testKeychainMigrationMovesLegacyUserDefaultsValue() {
        let account = makeProbeAccount()
        let suiteName = "nekotrans_tests_suite_\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            KeychainStore.remove(account: account)
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("legacy-plaintext-token", forKey: account)

        KeychainStore.migrateFromUserDefaults(account: account, defaults: defaults)

        XCTAssertEqual(KeychainStore.string(for: account), "legacy-plaintext-token")
        XCTAssertNil(defaults.string(forKey: account), "Legacy UserDefaults copy must be dropped after a successful Keychain write")
    }

    func testSecretAccountsAreUniqueAndComplete() {
        let accounts = KeyStore.Secret.allAccounts
        XCTAssertEqual(accounts.count, Set(accounts).count, "Secret accounts must be unique")
        XCTAssertEqual(accounts.count, 7, "6 API keys + 1 GitHub PAT")
        XCTAssertTrue(accounts.contains(KeyStore.Secret.githubPAT))
        XCTAssertTrue(accounts.contains(KeyStore.Secret.openAI))
    }

    // MARK: - 11. SafeURL Encoding Tests
    func testSafeURLDoesNotDoubleEncodeMyMemoryURL() {
        // Regression: MyMemory's `langpair=en|vi` contains a raw "|", which made
        // URL(string:) re-encode the WHOLE string, turning "%20" into "%2520". The server
        // then received literal percent escapes and echoed them back as the translation:
        //   "In the past 12 months" -> "Trong%20the% 20past%2012%20tháng"
        guard let url = SafeURL.make(
            host: "api.mymemory.translated.net",
            path: "/get",
            queryItems: [
                URLQueryItem(name: "q", value: "In the past 12 months"),
                URLQueryItem(name: "langpair", value: "en|vi")
            ]
        ) else {
            return XCTFail("URL must build")
        }

        let absolute = url.absoluteString
        XCTAssertTrue(absolute.contains("q=In%20the%20past%2012%20months"), absolute)
        XCTAssertTrue(absolute.contains("langpair=en%7Cvi"), "The raw '|' must be escaped by us, not by Foundation: \(absolute)")
        XCTAssertFalse(absolute.contains("%2520"), "Query must be escaped exactly once: \(absolute)")
    }

    func testSafeURLRoundTripsReservedCharacters() {
        let samples = [
            "In the past 12 months",
            "100% sure",
            "C++ & \"quotes\" | pipe",
            "a=b&c|d#e?f",
            "résumé — dấu tiếng Việt"
        ]

        for sample in samples {
            guard let url = SafeURL.make(
                host: "example.com",
                path: "/get",
                queryItems: [URLQueryItem(name: "q", value: sample)]
            ) else {
                return XCTFail("Failed to build URL for \(sample)")
            }

            let decoded = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "q" })?.value
            XCTAssertEqual(decoded, sample, "Query value must survive the round trip: \(url.absoluteString)")
        }
    }

    func testSafeURLKeepsLiteralPlusOutOfFormDecoding() {
        // A bare "+" is decoded as a space by form-style query parsing, so "C++" would
        // reach the engines as "C  ".
        guard let url = SafeURL.make(
            host: "example.com",
            path: "/get",
            queryItems: [URLQueryItem(name: "q", value: "C++")]
        ) else {
            return XCTFail("URL must build")
        }

        XCTAssertTrue(url.absoluteString.contains("q=C%2B%2B"), url.absoluteString)
    }

    func testSafeURLEscapesPathSegment() {
        guard let url = SafeURL.make(
            host: "api.dictionaryapi.dev",
            pathPrefix: "/api/v2/entries/en/",
            segment: "100% résumé"
        ) else {
            return XCTFail("URL must build")
        }

        XCTAssertTrue(url.absoluteString.hasSuffix("/api/v2/entries/en/100%25%20r%C3%A9sum%C3%A9"), url.absoluteString)
    }

    // MARK: - 12. MyMemory Response Validation Tests
    func testMyMemoryParsesSuccessfulTranslation() {
        let outcome = MyMemoryResponse.parse([
            "responseStatus": 200,
            "responseData": ["translatedText": "Được các thương hiệu hàng đầu tin tưởng"]
        ])
        XCTAssertEqual(outcome, .translation("Được các thương hiệu hàng đầu tin tưởng"))
    }

    func testMyMemoryRejectsRefusalSentencesServedAsTranslations() {
        // MyMemory returns HTTP 200 with responseStatus 403 and the error sentence in
        // translatedText; the app used to display that sentence as the Vietnamese result.
        let sameLanguage = MyMemoryResponse.parse([
            "responseStatus": 403,
            "responseDetails": "PLEASE SELECT TWO DISTINCT LANGUAGES",
            "responseData": ["translatedText": "PLEASE SELECT TWO DISTINCT LANGUAGES"]
        ])
        XCTAssertEqual(sameLanguage, .rejected(reason: "status 403: PLEASE SELECT TWO DISTINCT LANGUAGES"))

        let tooLong = MyMemoryResponse.parse([
            "responseStatus": 403,
            "responseDetails": "QUERY LENGTH LIMIT EXCEEDED. MAX ALLOWED QUERY : 500 CHARS",
            "responseData": ["translatedText": "QUERY LENGTH LIMIT EXCEEDED. MAX ALLOWED QUERY : 500 CHARS"]
        ])
        guard case .rejected = tooLong else {
            return XCTFail("Expected a rejection, got \(tooLong)")
        }
    }

    func testMyMemoryRejectsExhaustedQuota() {
        let outcome = MyMemoryResponse.parse([
            "responseStatus": 200,
            "quotaFinished": true,
            "responseData": ["translatedText": "anything"]
        ])
        XCTAssertEqual(outcome, .rejected(reason: "daily quota exhausted"))
    }

    func testMyMemoryRejectsErrorSentenceEvenWithStatus200() {
        let outcome = MyMemoryResponse.parse([
            "responseStatus": 200,
            "responseData": ["translatedText": "MYMEMORY WARNING: YOU USED ALL AVAILABLE FREE TRANSLATIONS FOR TODAY"]
        ])
        guard case .rejected = outcome else {
            return XCTFail("Expected a rejection, got \(outcome)")
        }
    }

    func testMyMemoryRejectsMalformedPayloads() {
        XCTAssertEqual(MyMemoryResponse.parse([:]), .unparsable)
        XCTAssertEqual(MyMemoryResponse.parse(["responseStatus": 200]), .unparsable)
        XCTAssertEqual(
            MyMemoryResponse.parse(["responseStatus": 200, "responseData": ["translatedText": "   "]]),
            .unparsable
        )
    }

    // MARK: - 13. Translation Cache Version Tests
    func testCacheDecoderRejectsUntrustedPayloads() throws {
        // Version 2 exists because older files may hold percent-encoded junk that was
        // cached as a "translation" — replaying them would keep showing the garbage.
        let encoder = JSONEncoder()
        let entry = RichWordEntry(
            word: "resilience",
            phonetic: "/rɪˈzɪl.jəns/",
            mainTranslation: "Sự kiên cường",
            meanings: [],
            allSynonyms: [],
            allAntonyms: [],
            baseLemma: nil
        )

        // A file written before the version field existed (shipped builds omit nil optionals).
        let versionless = try encoder.encode(
            TranslationCache.PersistentCacheData(
                version: nil,
                translations: ["k": "MindMeister%20is%20great"],
                dictionaries: ["resilience": entry]
            )
        )

        guard let migrated = TranslationCache.decodeCache(versionless) else {
            return XCTFail("An unversioned file must still decode")
        }
        XCTAssertTrue(migrated.translations.isEmpty, "Poisoned translations must be dropped")
        XCTAssertEqual(migrated.dictionaries["resilience"]?.word, "resilience", "Dictionary entries are unaffected and worth keeping")
        XCTAssertEqual(migrated.version, TranslationCache.currentCacheVersion)

        let stale = try encoder.encode(
            TranslationCache.PersistentCacheData(version: 1, translations: ["k": "v"], dictionaries: [:])
        )
        XCTAssertEqual(TranslationCache.decodeCache(stale)?.translations.isEmpty, true)

        let current = try encoder.encode(
            TranslationCache.PersistentCacheData(
                version: TranslationCache.currentCacheVersion,
                translations: ["k": "v"],
                dictionaries: [:]
            )
        )
        XCTAssertEqual(TranslationCache.decodeCache(current)?.translations["k"], "v")
    }

    func testCacheDecoderRejectsGarbage() {
        XCTAssertNil(TranslationCache.decodeCache(Data("not json".utf8)))
        XCTAssertNil(TranslationCache.decodeCache(Data()))
    }

    // MARK: - 14. Percent-Encoded Junk Detection Tests
    func testEncodedJunkDetector() {
        // Verbatim values from the shipped cache and history.
        XCTAssertTrue(TranslationCache.looksLikeEncodedJunk("Trực tiếp%20Typing%20Playground"))
        XCTAssertTrue(TranslationCache.looksLikeEncodedJunk("MindMeister%20is%20great%20for%20creating"))
        XCTAssertTrue(TranslationCache.looksLikeEncodedJunk("Trong%20the% 20past%2012%20tháng"))
        XCTAssertTrue(TranslationCache.looksLikeEncodedJunk("Đáng tin cậy%20by%20industry-leading%20brands"))

        // Real prose must survive.
        XCTAssertFalse(TranslationCache.looksLikeEncodedJunk("Sự kiên cường"))
        XCTAssertFalse(TranslationCache.looksLikeEncodedJunk("Giảm 20% so với năm ngoái"))
        XCTAssertFalse(TranslationCache.looksLikeEncodedJunk("Được các thương hiệu hàng đầu tin tưởng"))
        XCTAssertFalse(TranslationCache.looksLikeEncodedJunk(""))
        XCTAssertFalse(TranslationCache.looksLikeEncodedJunk("50% và 30%"))
        // A single escape is not enough evidence — a technical translation may mention "%20".
        XCTAssertFalse(TranslationCache.looksLikeEncodedJunk("mã hóa %20 trong URL"))
    }

    func testCacheDecoderDropsPoisonedDictionaryEntries() throws {
        // This entry survived the version bump, so looking the phrase up again kept showing
        // "Trực tiếp%20Typing%20Playground".
        let poisoned = RichWordEntry(
            word: "live typing playground",
            phonetic: nil,
            mainTranslation: "Trực tiếp%20Typing%20Playground",
            meanings: [],
            allSynonyms: [],
            allAntonyms: [],
            baseLemma: nil
        )
        let clean = RichWordEntry(
            word: "resilience",
            phonetic: "/rɪˈzɪl.jəns/",
            mainTranslation: "Sự kiên cường",
            meanings: [],
            allSynonyms: [],
            allAntonyms: [],
            baseLemma: nil
        )

        let data = try JSONEncoder().encode(
            TranslationCache.PersistentCacheData(
                version: TranslationCache.currentCacheVersion,
                translations: [:],
                dictionaries: ["live typing playground_vi": poisoned, "resilience_vi": clean]
            )
        )

        let decoded = TranslationCache.decodeCache(data)
        XCTAssertNil(decoded?.dictionaries["live typing playground_vi"], "Poisoned entry must be dropped so it gets re-fetched")
        XCTAssertEqual(decoded?.dictionaries["resilience_vi"]?.mainTranslation, "Sự kiên cường")
    }

    func testCacheDecoderStripsJunkDefinitionsButKeepsEnglish() throws {
        let definition = DefinitionItem(
            definitionEn: "to make something known",
            definitionVi: "tiết lộ%20điều%20gì đó",
            exampleEn: "he revealed the truth",
            exampleVi: "anh ấy%20tiết lộ%20sự thật"
        )
        let entry = RichWordEntry(
            word: "reveal",
            phonetic: nil,
            mainTranslation: "tiết lộ",
            meanings: [
                MeaningGroup(partOfSpeech: "verb", definitions: [definition], synonyms: [], antonyms: [])
            ],
            allSynonyms: [],
            allAntonyms: [],
            baseLemma: nil
        )

        let data = try JSONEncoder().encode(
            TranslationCache.PersistentCacheData(
                version: TranslationCache.currentCacheVersion,
                translations: [:],
                dictionaries: ["reveal_vi": entry]
            )
        )

        let sanitized = TranslationCache.decodeCache(data)?.dictionaries["reveal_vi"]
        XCTAssertNotNil(sanitized, "The headline translation is clean, so the entry stays usable")
        XCTAssertNil(sanitized?.meanings.first?.definitions.first?.definitionVi, "Junk Vietnamese must be cleared")
        XCTAssertNil(sanitized?.meanings.first?.definitions.first?.exampleVi, "Junk example translation must be cleared")
        XCTAssertEqual(sanitized?.meanings.first?.definitions.first?.definitionEn, "to make something known", "English content is untouched")
        XCTAssertEqual(sanitized?.meanings.first?.definitions.first?.exampleEn, "he revealed the truth")
    }

    func testCacheDecoderFiltersJunkFromTranslationTier() throws {
        let data = try JSONEncoder().encode(
            TranslationCache.PersistentCacheData(
                version: TranslationCache.currentCacheVersion,
                translations: [
                    "good": "Sự kiên cường",
                    "bad": "MindMeister%20is%20great%20for%20creating"
                ],
                dictionaries: [:]
            )
        )

        let decoded = TranslationCache.decodeCache(data)
        XCTAssertEqual(decoded?.translations["good"], "Sự kiên cường")
        XCTAssertNil(decoded?.translations["bad"])
    }

    @MainActor
    func testRealTranslationResponse() async {
        let text = "Artificial intelligence is transforming language learning across the world."
        let result = await TranslationService.shared.translate(
            text: text,
            from: "en",
            to: "vi"
        )
        XCTAssertNotNil(result, "Phải dịch được")
    }


    func testPlayPopSoundEffectLive() {
        guard let sound = NSSound(named: NSSound.Name("Ping")) else {
            return XCTFail("Không nạp được âm thanh Pop")
        }

        sound.stop()
        let played = sound.play()
        XCTAssertTrue(played, "NSSound phát thất bại")

        // Tạm hoãn 0.8s để tiến trình Test không bị tắt trước khi loa phát xong tiếng "Pop"
        let expectation = expectation(description: "Chờ âm thanh Pop phát xong")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

}
