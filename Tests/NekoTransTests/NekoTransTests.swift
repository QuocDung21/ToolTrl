import XCTest
@testable import NekoTransKit

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
            domain: "Công nghệ & IT",
            tone: "Học thuật & IELTS"
        )
        
        XCTAssertTrue(prompt.contains("The quick brown fox jumps over the lazy dog."))
        XCTAssertTrue(prompt.contains("Công nghệ & IT"))
        XCTAssertTrue(prompt.contains("Học thuật & IELTS"))
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
        XCTAssertEqual(TranslationTone.allCases.count, 5)
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
}
