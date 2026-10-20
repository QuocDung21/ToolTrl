import XCTest
import KeyboardShortcuts
import Defaults
@testable import NekoTrans

final class NekoTransTests: XCTestCase {
    
    // MARK: - 1. AIPromptBuilder Tests
    func testAIPromptBuilderGeneratesCorrectGrammarPrompt() {
        let title = "Hiện tại đơn"
        let context = "I study English every day."
        let prompt = AIPromptBuilder.strictEnforcedGrammarPrompt(title: title, context: context, customNote: "Chi tiết cho TOEIC")
        
        XCTAssertTrue(prompt.contains("CÔNG THỨC CHUẨN (FORMULA)"))
        XCTAssertTrue(prompt.contains("Ý NGHĨA & CÁCH DÙNG"))
        XCTAssertTrue(prompt.contains("CÁC CÂU VÍ DỤ MINH HỌA (EXAMPLES)"))
        XCTAssertTrue(prompt.contains("LỖI SAI HAY GẶP & BẪY ĐỀ THI"))
        XCTAssertTrue(prompt.contains("MẸO GHI NHỚ THẦN TỐC"))
        XCTAssertTrue(prompt.contains(title))
        XCTAssertTrue(prompt.contains(context))
        XCTAssertTrue(prompt.contains("Chi tiết cho TOEIC"))
    }
    
    func testAIPromptBuilderGeneratesStructuredWordPrompt() {
        let word = "Resilience"
        let prompt = AIPromptBuilder.structuredWordPrompt(for: word)
        
        XCTAssertTrue(prompt.contains(word))
        XCTAssertTrue(prompt.contains("TỪ LOẠI & TẦNG NGHĨA CHÍNH"))
        XCTAssertTrue(prompt.contains("HỌ TỪ (WORD FAMILY)"))
        XCTAssertTrue(prompt.contains("COLLOCATIONS & THÀNH NGỮ"))
        XCTAssertTrue(prompt.contains("SẮC THÁI & PHÂN BIỆT (NUANCES)"))
    }
    
    // MARK: - 2. AIAnalysisParser Multiline Tests
    func testAIAnalysisParserMultilineFormula() {
        let rawAI = """
        ### 1. 📐 CÔNG THỨC CHUẨN (FORMULA)
        - Thể khẳng định (+): S + V(s/es) + O
        - Thể phủ định (-): S + do/does not + V_inf + O
        - Thể nghi vấn (?): Do/Does + S + V_inf + O?
        - Với To Be: S + am/is/are + N/Adj

        ### 2. 💡 Ý NGHĨA & CÁCH DÙNG
        - Diễn tả chân lý, sự thật hiển nhiên.
        - Diễn tả thói quen lặp đi lặp lại.

        ### 3. 📖 CÁC CÂU VÍ DỤ MINH HỌA (EXAMPLES)
        - She plays piano very well. ➔ Cô ấy chơi piano rất giỏi.
        - They do not go out. ➔ Họ không ra ngoài.

        ### 4. ⚠️ LỖI SAI HAY GẶP & BẪY ĐỀ THI (COMMON MISTAKES)
        - Quên chia 's/es' với chủ ngữ ngôi thứ 3 số ít (He/She/It).

        ### 5. 🧠 MẸO GHI NHỚ THẦN TỐC
        - Nhìn thấy always, usually, often ➔ chia ngay Hiện tại đơn!
        """
        
        let parsed = AIAnalysisParser.parse(rawAI)
        
        XCTAssertFalse(parsed.isEmpty)
        XCTAssertNotNil(parsed.formula)
        XCTAssertTrue(parsed.formula!.contains("S + V(s/es) + O"))
        XCTAssertTrue(parsed.formula!.contains("S + do/does not + V_inf + O"))
        XCTAssertTrue(parsed.formula!.contains("S + am/is/are + N/Adj"))
        
        XCTAssertEqual(parsed.meanings.count, 2)
        XCTAssertEqual(parsed.examples.count, 2)
        XCTAssertEqual(parsed.commonMistakes.count, 1)
        XCTAssertNotNil(parsed.mnemonic)
        XCTAssertTrue(parsed.mnemonic!.contains("always"))
    }
    
    func testAIAnalysisParserVocabularyStructure() {
        let rawAI = """
        ### 1. 🏷️ TỪ LOẠI & TẦNG NGHĨA CHÍNH
        - Danh từ: Sự kiên cường, khả năng phục hồi.

        ### 2. 🌿 HỌ TỪ (WORD FAMILY)
        - Noun: Resilience
        - Adj: Resilient

        ### 3. 💡 COLLOCATIONS & THÀNH NGỮ
        - Show resilience: Thể hiện sự kiên cường.
        - Build resilience: Xây dựng sức bền.

        ### 4. ⚖️ SẮC THÁI & PHÂN BIỆT (NUANCES)
        - Khác với Endurance (sức chịu đựng về thể chất), Resilience nhấn mạnh khả năng bật dậy sau thất bại.
        """
        
        let parsed = AIAnalysisParser.parse(rawAI)
        
        XCTAssertEqual(parsed.meanings.count, 1)
        XCTAssertTrue(parsed.wordFamily.count >= 2)
        XCTAssertTrue(parsed.collocations.count >= 2)
        XCTAssertFalse(parsed.nuances.isEmpty)
        XCTAssertTrue(parsed.nuances.first?.contains("Endurance") == true)
    }
    
    // MARK: - 3. TranslationCache & 2-Tier Persistence Tests
    func testTranslationCacheSetAndGet() async {
        let cache = TranslationCache.shared
        let key = "test_word_\(UUID().uuidString)"
        let translation = "từ thử nghiệm"
        
        await cache.setTranslation(key: key, value: translation)
        let retrieved = await cache.getTranslation(key: key)
        
        XCTAssertEqual(retrieved, translation)
    }
    
    func testTranslationCacheDictionaryEntryPersistence() async {
        let cache = TranslationCache.shared
        let key = "resilience_vi"
        let entry = RichWordEntry(
            word: "Resilience",
            phonetic: "/rɪˈzɪl.jəns/",
            mainTranslation: "Sự kiên cường",
            meanings: [],
            allSynonyms: ["flexibility", "toughness"],
            allAntonyms: ["fragility"],
            baseLemma: nil
        )
        
        await cache.setDictionaryEntry(key: key, entry: entry)
        let retrieved = await cache.getDictionaryEntry(key: key)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.word, "Resilience")
        XCTAssertEqual(retrieved?.mainTranslation, "Sự kiên cường")
        XCTAssertEqual(retrieved?.allSynonyms.count, 2)
    }
    
    // MARK: - 4. SmartDictionary Lemmatization Tests
    @MainActor
    func testSmartDictionaryLemmatization() {
        let service = SmartDictionaryService.shared
        
        XCTAssertEqual(service.findLemma(for: "went"), "go")
        XCTAssertEqual(service.findLemma(for: "running"), "run")
        XCTAssertEqual(service.findLemma(for: "swimming"), "swim")
        XCTAssertEqual(service.findLemma(for: "boxes"), "box")
        XCTAssertEqual(service.findLemma(for: "taken"), "take")
        
        // Base words should return nil (no inflected reduction needed)
        XCTAssertNil(service.findLemma(for: "go"))
        XCTAssertNil(service.findLemma(for: "apple"))
        
        XCTAssertEqual(service.findLemma(for: "servers"), "server")
    }
    
    // MARK: - 5. TranslationViewModel Nested Navigation Tests
    @MainActor
    func testTranslationViewModelNestedLookupHistory() {
        let viewModel = TranslationViewModel()
        
        viewModel.processText("apple")
        XCTAssertFalse(viewModel.canGoBack)
        XCTAssertEqual(viewModel.originalText, "apple")
        
        viewModel.processNestedWord("fruit")
        XCTAssertTrue(viewModel.canGoBack)
        XCTAssertEqual(viewModel.originalText, "fruit")
        
        viewModel.processNestedWord("seed")
        XCTAssertTrue(viewModel.canGoBack)
        XCTAssertEqual(viewModel.originalText, "seed")
        
        viewModel.goBack()
        XCTAssertEqual(viewModel.originalText, "fruit")
        XCTAssertTrue(viewModel.canGoBack)
        
        viewModel.goBack()
        XCTAssertEqual(viewModel.originalText, "apple")
        XCTAssertFalse(viewModel.canGoBack)
    }
    
    // MARK: - 6. SavedWordItem Domain Logic Tests
    func testSavedWordItemGrammarIdentification() {
        let grammarWord = SavedWordItem(
            word: "📐 Quá khứ hoàn thành",
            phonetic: "S + had + V3/ed",
            translation: "Diễn tả hành động xảy ra trước một hành động khác",
            exampleEn: "He had left before I arrived."
        )
        
        XCTAssertTrue(grammarWord.isGrammarFormula)
        XCTAssertEqual(grammarWord.cleanTitle, "Quá khứ hoàn thành")
        
        let normalWord = SavedWordItem(
            word: "Serendipity",
            phonetic: "/ˌser.ənˈdɪp.ə.t̬i/",
            translation: "Sự may mắn tình cờ",
            exampleEn: "Finding this book was pure serendipity."
        )
        
        XCTAssertFalse(normalWord.isGrammarFormula)
        XCTAssertEqual(normalWord.cleanTitle, "Serendipity")
    }
    
    // MARK: - 6b. Persisted itemType (RULE 1) Tests
    func testPersistedItemTypeOverridesContentHeuristic() {
        // A vocabulary entry whose IPA happens to contain "+" must stay vocabulary.
        let word = SavedWordItem(
            word: "leadership",
            phonetic: "/ˈliː.də+ʃɪp/",
            translation: "khả năng lãnh đạo",
            itemType: .vocabulary
        )
        XCTAssertEqual(word.itemType, .vocabulary)
        XCTAssertFalse(word.isGrammarFormula, "Persisted type must win over the phonetic heuristic")
        
        // A grammar entry without the 📐 marker or a "+" formula must stay grammar.
        let grammar = SavedWordItem(
            word: "Câu điều kiện loại 1",
            phonetic: nil,
            translation: "Diễn tả khả năng có thể xảy ra ở hiện tại",
            itemType: .grammar
        )
        XCTAssertTrue(grammar.isGrammarFormula, "Persisted type must win over the content heuristic")
    }
    
    func testLegacyItemWithoutItemTypeFallsBackToHeuristic() {
        let legacy = SavedWordItem(
            word: "📐 Hiện tại đơn",
            phonetic: "S + V(s/es)",
            translation: "Thói quen lặp lại"
        )
        XCTAssertNil(legacy.itemType, "Rows created before the field existed start unmigrated")
        XCTAssertTrue(legacy.isGrammarFormula, "Unmigrated rows keep rendering correctly")
        
        let legacyWord = SavedWordItem(word: "Serendipity", phonetic: "/ˌser.ənˈdɪp.ə.t̬i/", translation: "Sự may mắn")
        XCTAssertNil(legacyWord.itemType)
        XCTAssertFalse(legacyWord.isGrammarFormula)
    }
    
    func testInferredItemTypeClassification() {
        XCTAssertEqual(
            SavedWordItem.inferredItemType(word: "📐 Quá khứ hoàn thành", phonetic: nil, translation: "x"),
            .grammar
        )
        XCTAssertEqual(
            SavedWordItem.inferredItemType(word: "wish", phonetic: "S + wish + S + V-past", translation: "ước"),
            .grammar
        )
        XCTAssertEqual(
            SavedWordItem.inferredItemType(word: "clause", phonetic: nil, translation: "Công thức: S + V"),
            .grammar
        )
        XCTAssertEqual(
            SavedWordItem.inferredItemType(word: "apple", phonetic: "/ˈæp.əl/", translation: "quả táo"),
            .vocabulary
        )
    }
    
    func testItemTypeSurvivesCodableRoundTrip() throws {
        let original = SavedWordItem(
            word: "📐 Câu bị động",
            phonetic: "S + be + V3/ed",
            translation: "Nhấn mạnh đối tượng chịu tác động",
            itemType: .grammar
        )
        
        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([SavedWordItem].self, from: data)
        
        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].itemType, .grammar)
        XCTAssertTrue(decoded[0].isGrammarFormula)
    }
    
    @MainActor
    func testLegacyItemsAreMigratedAndMigrationIsIdempotent() {
        let legacy = [
            SavedWordItem(word: "📐 Quá khứ hoàn thành", phonetic: "S + had + V3/ed", translation: "Diễn tả hành động trước đó"),
            SavedWordItem(word: "Leadership", phonetic: "/ˈliː.dəʃɪp/", translation: "khả năng lãnh đạo"),
            // Duplicate of the row above once the title is normalized.
            SavedWordItem(word: "leadership", phonetic: nil, translation: "bản trùng")
        ]
        
        let first = VocabularyService.migrateLegacyItems(legacy)
        
        XCTAssertTrue(first.didMigrate)
        XCTAssertEqual(first.items.count, 2, "Duplicate rows must be dropped")
        XCTAssertEqual(first.items[0].itemType, .grammar)
        XCTAssertEqual(first.items[1].itemType, .vocabulary)
        XCTAssertEqual(first.items[1].word, "leadership", "Titles are normalized while migrating")
        
        // Idempotence: re-running over the migrated output must be a no-op, otherwise
        // every launch would rewrite the notebook.
        let second = VocabularyService.migrateLegacyItems(first.items)
        XCTAssertFalse(second.didMigrate)
        XCTAssertEqual(second.items.count, 2)
        XCTAssertEqual(second.items.map(\.itemType), [.grammar, .vocabulary])
    }
    
    func testLegacyJSONWithoutItemTypeStillDecodes() throws {
        // Shape produced by builds that predate `itemType` (no key at all).
        let legacyJSON = """
        [{
            "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
            "word": "📐 Quá khứ hoàn thành",
            "phonetic": "S + had + V3/ed",
            "translation": "Diễn tả hành động xảy ra trước một hành động khác",
            "dateAdded": 0,
            "isFavorite": false,
            "isMastered": false
        }]
        """
        let data = legacyJSON.data(using: .utf8)!
        let decoded = try JSONDecoder().decode([SavedWordItem].self, from: data)
        
        XCTAssertEqual(decoded.count, 1)
        XCTAssertNil(decoded[0].itemType, "A missing key must decode as nil, not throw")
        XCTAssertTrue(decoded[0].isGrammarFormula)
    }
    
    // MARK: - 7. Apple LZFSE DataCompression Tests
    func testDataCompressionRoundtrip() {
        let sampleText = "NekoTrans AI Dictionary & Translator: " + String(repeating: "Quick brown fox jumps over the lazy dog. ", count: 50)
        let sampleData = sampleText.data(using: .utf8)!
        
        let compressed = DataCompression.compress(data: sampleData)
        XCTAssertNotNil(compressed)
        XCTAssertTrue(compressed!.count < sampleData.count)
        
        let decompressed = DataCompression.decompress(data: compressed!)
        XCTAssertNotNil(decompressed)
        XCTAssertEqual(String(data: decompressed!, encoding: .utf8), sampleText)
    }
    
    func testDataCompressionHandlesIncompressiblePayload() {
        // Regression: the old fixed `data.count + 1024` destination could not hold the
        // expansion of incompressible input, so `compress` returned nil and the cloud
        // backup failed silently for already-compressed or random data.
        var bytes = [UInt8](repeating: 0, count: 1_048_576)
        for index in bytes.indices {
            bytes[index] = UInt8.random(in: 0...255)
        }
        let payload = Data(bytes)
        
        guard let compressed = DataCompression.compress(data: payload) else {
            return XCTFail("Compressing incompressible data must not fail")
        }
        
        XCTAssertEqual(DataCompression.decompress(data: compressed), payload)
    }
    
    func testDataCompressionRejectsOversizedDecompression() {
        let payload = Data(repeating: 0x41, count: 512 * 1024)
        guard let compressed = DataCompression.compress(data: payload) else {
            return XCTFail("Compression failed")
        }
        
        // Must refuse rather than silently truncate to the cap.
        XCTAssertNil(DataCompression.decompress(data: compressed, maxExpectedSize: 1024))
        
        // A cap that fits must still round-trip.
        let exact = DataCompression.decompress(data: compressed, maxExpectedSize: payload.count)
        XCTAssertEqual(exact?.count, payload.count)
    }
    
    func testDataCompressionRejectsCorruptInput() {
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
        XCTAssertNil(DataCompression.decompress(data: garbage), "Corrupt payloads must fail, not crash or truncate")
    }
    
    func testDataCompressionEmptyInputPassesThrough() {
        XCTAssertEqual(DataCompression.compress(data: Data()), Data())
        XCTAssertEqual(DataCompression.decompress(data: Data()), Data())
    }
    
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
        let text = """
        It was the best of times, it was the worst of times, it was the age of wisdom, it was the age of foolishness, it was the epoch of belief, it was the epoch of incredulity, it was the season of Light, it was the season of Darkness, it was the spring of hope, it was the winter of despair, we had everything before us, we had nothing before us, we were all going direct to Heaven, we were all going direct the other way — in short, the period was so far like the present period, that some of its noisiest authorities insisted on its being received, for good or for evil, in the superlative degree of comparison only.
        """
        let result = await TranslationService.shared.translate(
            text: text,
            from: "en",
            to: "vi"
        )
        print("📥 KẾT QUẢ:", result ?? "nil")
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

    // MARK: - 15. Easydict-Inspired Logic Tests

    func testBrowserBundleIDDetection() {
        XCTAssertTrue(BrowserScriptHelper.isSupportedBrowser("com.apple.Safari"))
        XCTAssertTrue(BrowserScriptHelper.isSupportedBrowser("com.google.Chrome"))
        XCTAssertTrue(BrowserScriptHelper.isSupportedBrowser("company.thebrowser.Browser"))
        XCTAssertTrue(BrowserScriptHelper.isSupportedBrowser("com.microsoft.edgemac"))
        XCTAssertTrue(BrowserScriptHelper.isSupportedBrowser("com.brave.Browser"))
        XCTAssertFalse(BrowserScriptHelper.isSupportedBrowser("com.apple.dt.Xcode"))
        XCTAssertFalse(BrowserScriptHelper.isSupportedBrowser("com.tinyspeck.slackmacgap"))
    }

    func testOCRDashHandlingDehyphenation() {
        // Line-break hyphenation removal
        let lines1 = ["This is an impor-", "tant discovery."]
        let result1 = ScreenOCRService.assembleSmartText(from: lines1)
        XCTAssertEqual(result1, "This is an important discovery.")

        // Compound word preservation
        let lines2 = ["A state-of-", "the-art model."]
        let result2 = ScreenOCRService.assembleSmartText(from: lines2)
        XCTAssertEqual(result2, "A state-of-the-art model.")

        // Numbers/Date preservation
        let lines3 = ["During 1990-", "2020."]
        let result3 = ScreenOCRService.assembleSmartText(from: lines3)
        XCTAssertEqual(result3, "During 1990-2020.")
    }

    @MainActor
    func testVocabularyExportAnkiAndMarkdownAndJSONL() {
        let service = VocabularyService.shared
        let originalWords = service.savedWords

        service.clearAll()
        service.addWord(
            word: "Serendipity",
            phonetic: "/ˌser.ənˈdɪp.ə.t̬i/",
            translation: "Sự may mắn tình cờ",
            exampleEn: "Pure serendipity.",
            exampleVi: "Hoàn toàn là may mắn tình cờ."
        )
        service.addWord(
            word: "📐 Quá khứ hoàn thành",
            phonetic: "S + had + V3/ed",
            translation: "Diễn tả hành động xảy ra trước",
            exampleEn: "He had left."
        )

        // 1. Anki TSV
        let anki = service.exportToAnkiTSV()
        XCTAssertTrue(anki.contains("serendipity\tSự may mắn tình cờ\t/ˌser.ənˈdɪp.ə.t̬i/\tPure serendipity.\tHoàn toàn là may mắn tình cờ.\tNekoTrans::Vocabulary"))
        XCTAssertTrue(anki.contains("Quá khứ hoàn thành\tDiễn tả hành động xảy ra trước\tS + had + V3/ed\tHe had left.\t\tNekoTrans::Grammar"))

        // 2. Markdown
        let md = service.exportToMarkdown()
        XCTAssertTrue(md.contains("# 📖 Sổ tay từ vựng NekoTrans"))
        XCTAssertTrue(md.contains("**serendipity**"))
        XCTAssertTrue(md.contains("S + had + V3/ed"))

        // 3. JSONL
        let jsonl = service.exportToJSONL()
        let rows = jsonl.split(separator: "\n")
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(jsonl.contains("serendipity"))

        // Restore original words
        service.savedWords = originalWords
        service.saveWords()
    }

    // MARK: - InputTextNormalizer Tests (Easydict Logic Inheritance)
    func testSplitCodeIdentifiers() {
        XCTAssertEqual(InputTextNormalizer.splitCodeIdentifiers("getUserProfile"), "get User Profile")
        XCTAssertEqual(InputTextNormalizer.splitCodeIdentifiers("XMLHttpRequest"), "XML Http Request")
        XCTAssertEqual(InputTextNormalizer.splitCodeIdentifiers("is_authenticated_user"), "is authenticated user")
        XCTAssertEqual(InputTextNormalizer.splitCodeIdentifiers("API_KEY_SECRET"), "API KEY SECRET")
    }

    func testStripCommentSymbols() {
        let codeWithSlash = "// This is a single line comment"
        XCTAssertEqual(InputTextNormalizer.stripCommentSymbols(codeWithSlash), "This is a single line comment")

        let codeWithTripleSlash = "/// Documentation comment"
        XCTAssertEqual(InputTextNormalizer.stripCommentSymbols(codeWithTripleSlash), "Documentation comment")

        let codeWithHash = "# Python style comment"
        XCTAssertEqual(InputTextNormalizer.stripCommentSymbols(codeWithHash), "Python style comment")

        let blockComment = "/* Multi-line comment block */"
        XCTAssertEqual(InputTextNormalizer.stripCommentSymbols(blockComment), "Multi-line comment block")
    }

    func testStripSurroundingQuotes() {
        XCTAssertEqual(InputTextNormalizer.stripSurroundingQuotes("\"hello world\""), "hello world")
        XCTAssertEqual(InputTextNormalizer.stripSurroundingQuotes("'single quoted'"), "single quoted")
        XCTAssertEqual(InputTextNormalizer.stripSurroundingQuotes("`backtick code`"), "backtick code")
        XCTAssertEqual(InputTextNormalizer.stripSurroundingQuotes("“smart quotes”"), "smart quotes")
    }

    func testInputTextNormalizerNormalize() {
        let raw1 = "\"// getUserProfile\""
        XCTAssertEqual(InputTextNormalizer.normalize(raw1), "get User Profile")

        let raw2 = "  # is_admin_active  "
        XCTAssertEqual(InputTextNormalizer.normalize(raw2), "is admin active")
    }

    func testInputTextClassifier() {
        XCTAssertEqual(InputTextNormalizer.classify("getUserProfile"), .code)
        XCTAssertEqual(InputTextNormalizer.classify("is_authenticated"), .code)
        XCTAssertEqual(InputTextNormalizer.classify("apple"), .word)
        XCTAssertEqual(InputTextNormalizer.classify("big apple"), .word)
        XCTAssertEqual(InputTextNormalizer.classify("This is a complete sentence."), .sentence)
    }

    func testResolveTargetLanguageAutoFlip() {
        // Vietnamese detected -> should auto-flip to English
        let targetForVi = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "vi",
            configuredTarget: .vietnamese
        )
        XCTAssertEqual(targetForVi, .english)

        // English detected -> should translate to configured target (Vietnamese)
        let targetForEn = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "en",
            configuredTarget: .vietnamese
        )
        XCTAssertEqual(targetForEn, .vietnamese)

        // English detected when configured target was Japanese -> should keep Japanese
        let targetForEnToJa = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "en",
            configuredTarget: .japanese
        )
        XCTAssertEqual(targetForEnToJa, .japanese)
    }

    // MARK: - HTMLEntityDecoder Tests
    func testHTMLEntityDecoder() {
        let encoded = "&quot;Hello &amp; World&quot; &lt;tag&gt; &#39;test&#39; &#65;"
        let decoded = HTMLEntityDecoder.decode(encoded)
        XCTAssertEqual(decoded, "\"Hello & World\" <tag> 'test' A")

        let hexEncoded = "&#x41;&#x42;&#x43;"
        let hexDecoded = HTMLEntityDecoder.decode(hexEncoded)
        XCTAssertEqual(hexDecoded, "ABC")
    }

    // MARK: - TranslationProviderResult Tests
    func testTranslationProviderResultInit() {
        let result = TranslationProviderResult(
            engine: .googleWeb,
            providerName: "Google Translate",
            text: "Xin chào",
            latencyMs: 142
        )
        XCTAssertEqual(result.engine, .googleWeb)
        XCTAssertEqual(result.providerName, "Google Translate")
        XCTAssertEqual(result.text, "Xin chào")
        XCTAssertEqual(result.latencyMs, 142)
        XCTAssertFalse(result.isError)
        XCTAssertNil(result.errorMessage)
    }

    // MARK: - OfflineDictionaryParser Tests
    func testOfflineDictionaryParserVietnameseDCSOutput() {
        let raw = "1. context danh từ 1 (văn học) văn cảnh; ngữ cảnh ▸ Can you guess the meaning of this phrase from the context? Anh có đoán được nghĩa của cụm từ này qua ngữ cảnh hay không? ▸ Don't quote my words out of context Đừng tách trích dẫn những từ ngữ của tôi mà tách chúng ra khỏi ngữ cảnh 2 tình huống mà trong đó cái gì đang xảy ra hoặc phải được suy xét; bối cảnh ▸ In the context of the present economic crisis Trong bối cảnh khủng hoảng kinh tế hiện nay từ đồng nghĩa background, circumstances, environment, framework, milieu, perspective, setting, situation 3 Kỹ thuật văn cảnh 4 Tin học văn cảnh"
        
        let groups = OfflineDictionaryParser.parse(rawText: raw, term: "context")
        XCTAssertFalse(groups.isEmpty)
        guard let group = groups.first else { return }
        XCTAssertEqual(group.partOfSpeech, "noun")
        XCTAssertEqual(group.items.count, 4)
        
        // Item 1
        let item1 = group.items[0]
        XCTAssertTrue(item1.definition.contains("văn cảnh; ngữ cảnh"))
        XCTAssertNotNil(item1.example)
        XCTAssertTrue(item1.example?.contains("Can you guess the meaning") == true)
        XCTAssertEqual(item1.exampleTranslation, "Anh có đoán được nghĩa của cụm từ này qua ngữ cảnh hay không?")
        
        // Item 2
        let item2 = group.items[1]
        XCTAssertTrue(item2.definition.contains("tình huống"))
        XCTAssertTrue(item2.example?.contains("present economic crisis") == true)
        XCTAssertEqual(item2.exampleTranslation, "Trong bối cảnh khủng hoảng kinh tế hiện nay")
        XCTAssertTrue(item2.synonyms.contains("background"))
        XCTAssertTrue(item2.synonyms.contains("situation"))
        
        // Item 3 & 4
        XCTAssertEqual(group.items[2].definition, "Kỹ thuật văn cảnh")
        XCTAssertEqual(group.items[3].definition, "Tin học văn cảnh")
    }

    func testOfflineDictionaryParserEnglishOxfordOutput() {
        let raw = """
        context | ˈkɑntɛkst |
        noun
        1 the circumstances that form the setting for an event.
        2 the parts of something written or spoken: word processing is affected by the context.
        PHRASES
        in context / out of context
        """
        let groups = OfflineDictionaryParser.parse(rawText: raw, term: "context")
        XCTAssertFalse(groups.isEmpty)
        guard let group = groups.first else { return }
        XCTAssertEqual(group.partOfSpeech, "noun")
        XCTAssertEqual(group.items.count, 2)
        XCTAssertTrue(group.items[0].definition.contains("the circumstances that form"))
        XCTAssertEqual(group.items[1].definition, "the parts of something written or spoken")
        XCTAssertEqual(group.items[1].example, "word processing is affected by the context.")
    }

    func testResolveTargetLanguageAutoFlipIdentical() {
        // When source is English and configured target is English -> flip to Vietnamese
        let targetEnToEn = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "en",
            configuredTarget: .english
        )
        XCTAssertEqual(targetEnToEn, .vietnamese)

        // When source is Vietnamese and configured target is Vietnamese -> flip to English
        let targetViToVi = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "vi",
            configuredTarget: .vietnamese
        )
        XCTAssertEqual(targetViToVi, .english)

        // When source is undetermined "und" and target is English -> should flip to Vietnamese
        let targetUnd = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: "und",
            configuredTarget: .english
        )
        XCTAssertEqual(targetUnd, .vietnamese)
    }

    // MARK: - ActionManager & Polishing Tests
    func testQuickPolishingPromptGeneration() {
        let text = "He dont has any money and he go to school."
        let prompt = AIPromptBuilder.quickPolishingPrompt(text: text)
        XCTAssertTrue(prompt.contains(text))
        XCTAssertTrue(prompt.contains("Output ONLY the polished replacement text"))
        XCTAssertTrue(prompt.contains("writing assistant"))
    }

    @MainActor
    func testActionManagerDefaultsAndShortcuts() {
        XCTAssertNotNil(ActionManager.shared)
        XCTAssertFalse(ActionManager.shared.isProcessing)
        
        let replaceShortcut = KeyboardShortcuts.Name.translateAndReplace.shortcut
        XCTAssertNotNil(replaceShortcut)
        XCTAssertEqual(replaceShortcut?.modifiers, [.option, .shift])
        
        let polishShortcut = KeyboardShortcuts.Name.polishAndReplace.shortcut
        XCTAssertNotNil(polishShortcut)
        XCTAssertEqual(polishShortcut?.modifiers, [.option, .shift])
    }

    // MARK: - Concise Word Dictionary (Easydict Standard) Tests
    func testPartOfSpeechStandardizationAndAbbreviations() {
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("noun"), "n.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("Danh từ"), "n.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("verb"), "v.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("động từ"), "v.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("adjective"), "adj.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("tính từ"), "adj.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("adverb"), "adv.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("phó từ"), "adv.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("preposition"), "prep.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("conjunction"), "conj.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("pronoun"), "pron.")
        XCTAssertEqual(InputTextNormalizer.partAbbreviation("interjection"), "int.")

        XCTAssertEqual(InputTextNormalizer.partFullName("noun"), "Danh từ")
        XCTAssertEqual(InputTextNormalizer.partFullName("verb"), "Động từ")
        XCTAssertEqual(InputTextNormalizer.partFullName("adjective"), "Tính từ")
    }

    func testRichWordEntryConcisePartsExtraction() {
        let def1 = DefinitionItem(
            definitionEn: "A reference work with a list of words from one or more languages, explaining each word's meaning...",
            definitionVi: "Tài liệu tham khảo có danh sách các từ của một hoặc nhiều ngôn ngữ, giải thích nghĩa của từng từ...",
            exampleEn: "look up in dictionary",
            exampleVi: "tra từ điển"
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
        XCTAssertEqual(conciseParts.count, 2)
        
        let nounPart = conciseParts.first(where: { $0.part == "n." })
        XCTAssertNotNil(nounPart)
        XCTAssertEqual(nounPart?.partFullName, "Danh từ")
        XCTAssertTrue(nounPart?.meanings.contains("từ điển") == true)
        
        let verbPart = conciseParts.first(where: { $0.part == "v." })
        XCTAssertNotNil(verbPart)
        XCTAssertEqual(verbPart?.partFullName, "Động từ")
        XCTAssertTrue(verbPart?.meanings.contains("Tra trong từ điển.") == true)
        XCTAssertTrue(verbPart?.meanings.contains("Biên soạn từ điển.") == true)
    }

    func testIPANormalizerStandardization() {
        // 1. Raw Wiktionary phonetic with ASCII stress markers and turned-r
        let raw = "/'dɪkʃə,nɛɹi/"
        let normalized = IPANormalizer.normalize(raw)
        XCTAssertEqual(normalized, "/ˈdɪkʃəˌnɛri/")

        // 2. Square brackets stripping and character conversions
        let rawBrackets = "[ˈækʃən]"
        XCTAssertEqual(IPANormalizer.normalize(rawBrackets), "/ˈækʃən/")

        // 3. Apple DCS American Heritage legacy digraph conversion
        let dcsRaw = "| ˈdikSHəˌnerē |"
        let dcsNormalized = IPANormalizer.normalize(dcsRaw)
        XCTAssertEqual(dcsNormalized, "/ˈdikʃəˌneri/")

        // 4. Comparison check
        XCTAssertTrue(IPANormalizer.areIdentical("/ˈdɪkʃənri/", "ˈdɪkʃənri"))
        XCTAssertFalse(IPANormalizer.areIdentical("/ˈdɪkʃənri/", "/ˈdɪkʃəˌneri/"))

        // 5. Wiktionary narrow glottal stop and unreleased stop diacritics stripping (e.g. [ʔæʔp̚] -> /æp/)
        let narrowApp = "[ʔæʔp̚]"
        XCTAssertEqual(IPANormalizer.normalize(narrowApp), "/æp/")

        // 6. User-specified broad Oxford IPA notation /'sɜ:və[r]/
        let oxfordServer = "/'sɜ:və[r]/"
        XCTAssertEqual(IPANormalizer.normalize(oxfordServer), "/ˈsɜːvə(r)/")

        // 7. Oxford Dictionary of English notation with triangular colon /əː/ -> /ɜː/
        let odeServer = "ˈsəːvə"
        XCTAssertEqual(IPANormalizer.normalize(odeServer), "/ˈsɜːvə/")

        // 8. Agent noun typo correction for server / servers
        let typoDCS = "/sə:v/"
        XCTAssertEqual(IPANormalizer.normalize(typoDCS, forWord: "servers"), "/ˈsɜːvə(r)/")
        XCTAssertEqual(IPANormalizer.normalize(typoDCS, forWord: "server"), "/ˈsɜːvə(r)/")
        XCTAssertEqual(IPANormalizer.normalize("/sɜːv/", forWord: "serve"), "/sɜːv/", "Root verb serve must not be altered")
    }

    @MainActor
    func testServersPhoneticFromDictionaryService() {
        // DictionaryService must extract the corrected phonetic for "server" and "servers"
        let phoneticServer = DictionaryService.shared.extractPhonetic(for: "server")
        XCTAssertEqual(phoneticServer, "/ˈsɜːvə(r)/")

        let phoneticServers = DictionaryService.shared.extractPhonetic(for: "servers")
        XCTAssertEqual(phoneticServers, "/ˈsɜːvə(r)/")
    }

    func testCacheDecoderSanitizesContaminatedServersPhonetic() throws {
        let poisonedEntry = RichWordEntry(
            word: "servers",
            phonetic: "/sə:v/",
            ukPhonetic: "/sə:v/",
            usPhonetic: "/sə:v/",
            mainTranslation: "máy chủ",
            meanings: [],
            allSynonyms: [],
            allAntonyms: [],
            baseLemma: "server"
        )

        let data = try JSONEncoder().encode(
            TranslationCache.PersistentCacheData(
                version: TranslationCache.currentCacheVersion,
                translations: [:],
                dictionaries: ["servers_vi": poisonedEntry]
            )
        )

        let decoded = TranslationCache.decodeCache(data)
        let sanitized = decoded?.dictionaries["servers_vi"]
        XCTAssertNotNil(sanitized)
        XCTAssertEqual(sanitized?.phonetic, "/ˈsɜːvə(r)/")
        XCTAssertEqual(sanitized?.ukPhonetic, "/ˈsɜːvə(r)/")
    }

    func testCleanConciseMeaningChunkParenthesesBalancing() {
        let unbalanced = "Ứng dụng (sử dụng"
        XCTAssertEqual(SmartDictionaryService.cleanConciseMeaningChunk(unbalanced), "Ứng dụng")

        let balanced = "Một ứng dụng (chương trình)"
        XCTAssertEqual(SmartDictionaryService.cleanConciseMeaningChunk(balanced), "Một ứng dụng (chương trình)")
    }

    // MARK: - 16. Continuous Journal & App Exclusion Tests (Easydict Inheritance)
    @MainActor
    func testAppExclusionService() {
        let service = AppExclusionService.shared
        let testBundleID = "com.test.exclusionApp"

        service.addExcludedApp(bundleIdentifier: testBundleID)
        XCTAssertTrue(service.isAppExcluded(bundleIdentifier: testBundleID))
        XCTAssertTrue(service.isAppExcluded(bundleIdentifier: "COM.TEST.EXCLUSIONAPP"), "Must be case-insensitive")

        service.removeExcludedApp(bundleIdentifier: testBundleID)
        XCTAssertFalse(service.isAppExcluded(bundleIdentifier: testBundleID))
    }

    func testContinuousJournalEntryPersistence() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let journalFile = tempDir.appendingPathComponent("test_words.jsonl")

        Defaults[.journalDirectoryPath] = journalFile.path
        defer {
            Defaults[.journalDirectoryPath] = ""
            try? FileManager.default.removeItem(at: tempDir)
        }

        let journal = ContinuousJournalService.shared
        journal.logEntry(
            word: "epiphany",
            phonetic: "/ɪˈpɪfəni/",
            translation: "sự thấu hiểu đột ngột",
            sourceLang: "en",
            targetLang: "vi",
            context: "She had an epiphany while walking."
        )

        // Wait briefly for file queue write
        let expectation = XCTestExpectation(description: "Write journal")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) {
            let entries = journal.readRecentEntries(limit: 10)
            XCTAssertFalse(entries.isEmpty)
            if let first = entries.first {
                XCTAssertEqual(first.word, "epiphany")
                XCTAssertEqual(first.translation, "sự thấu hiểu đột ngột")
                XCTAssertEqual(first.phonetic, "/ɪˈpɪfəni/")
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    func testAnkiErrorDescriptions() {
        let err1 = AnkiError.emptyWord
        XCTAssertEqual(err1.errorDescription, "Từ vựng không được để trống")

        let err2 = AnkiError.ankiError("cannot create note")
        XCTAssertEqual(err2.errorDescription, "Lỗi Anki: cannot create note")
    }
}

