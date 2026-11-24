import XCTest
import KeyboardShortcuts
import Defaults
@testable import NekoTrans

final class SystemIntegrationTests: XCTestCase {
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

    func testGGUFTranslationOutput() async throws {
        let path = "/Users/dungnguyenquoc/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B-Instruct-GGUF/snapshots/9217f5db79a29953eb74d5343926648285ec7e67/qwen2.5-0.5b-instruct-q4_k_m.gguf"
        guard FileManager.default.fileExists(atPath: path) else { return }
        defer { LocalGGUFService.shared.shutdown() }
        try LocalGGUFService.shared.loadModel(at: path)
        
        let text = "Whether to return page content in content. Defaults to false; when false, content is always an empty string."
        let sys = AIPromptBuilder.localGGUFSystemPrompt(sourceLang: "en", targetLang: "vi")
        let userPrompt = AIPromptBuilder.localGGUFUserPrompt(text: text, targetLang: "vi")
        let prompt = LocalGGUFService.shared.formatPrompt(system: sys, user: userPrompt)
        let out = try await LocalGGUFService.shared.streamInference(prompt: prompt) { _ in }
        
        XCTAssertFalse(out.isEmpty)
        XCTAssertNotEqual(out, text, "GGUF model must not echo the original English input")
    }

    // MARK: - 17. TextGrabber & Stale Word Prevention Tests
    @MainActor
    func testViewModelReset() {
        let vm = TranslationViewModel()
        vm.originalText = "serendipity"
        vm.translatedText = "sự tình cờ may mắn"
        vm.isStreaming = true
        
        vm.reset()
        
        XCTAssertEqual(vm.originalText, "")
        XCTAssertEqual(vm.translatedText, "")
        XCTAssertNil(vm.richEntry)
        XCTAssertNil(vm.definition)
        XCTAssertFalse(vm.isStreaming)
        XCTAssertFalse(vm.isLoading)
        XCTAssertTrue(vm.lookupHistory.isEmpty)
    }

    @MainActor
    func testTextGrabberTargetApplicationDoesNotReturnNekoTrans() {
        let grabber = TextGrabber.shared
        let target = grabber.getTargetApplication()
        if let bundleID = target?.bundleIdentifier {
            XCTAssertNotEqual(bundleID, Bundle.main.bundleIdentifier, "TextGrabber must never target NekoTrans itself")
        }
    }

    // MARK: - 18. QuitActionPreference & Clean Termination Tests
    func testQuitActionPreferenceDefaultAndCases() {
        // Defaults key default value must be terminateImmediately so quitting cleanly removes Dock and header
        XCTAssertEqual(Defaults.Keys.quitActionPreference.defaultValue, .terminateImmediately)
        
        XCTAssertEqual(QuitActionPreference.terminateImmediately.rawValue, "terminate")
        XCTAssertEqual(QuitActionPreference.runInBackground.rawValue, "background")
        XCTAssertEqual(QuitActionPreference.askEveryTime.rawValue, "ask")

        XCTAssertEqual(QuitActionPreference.terminateImmediately.title, "Thoát hoàn toàn")
        XCTAssertEqual(QuitActionPreference.runInBackground.title, "Chạy dưới nền")
        XCTAssertEqual(QuitActionPreference.askEveryTime.title, "Luôn hỏi")
    }

    // MARK: - 20. Clean Uninstallation Tests
    @MainActor
    func testAppUninstallerTargetScanning() {
        let uninstaller = AppUninstaller.shared
        uninstaller.scanTargets()
        
        let targetIds = uninstaller.targets.map { $0.id }
        XCTAssertTrue(targetIds.contains("app_bundle"), "Must contain application bundle")
        XCTAssertTrue(targetIds.contains("app_support_neko"), "Must scan Application Support NekoTrans directory")
        XCTAssertTrue(targetIds.contains("preferences"), "Must scan preferences plist")
        XCTAssertTrue(targetIds.contains("keychain"), "Must scan Keychain credentials")
        XCTAssertTrue(targetIds.contains("caches"), "Must scan caches")
        XCTAssertTrue(targetIds.contains("webkit"), "Must scan WebKit web storage")
        XCTAssertTrue(targetIds.contains("system_integration"), "Must scan system integration items")
        XCTAssertTrue(targetIds.contains("journal"), "Must scan continuous journal file")
    }

    func testKeychainStoreRemoveAll() {
        let testAccount = KeyStore.Secret.openAI
        KeychainStore.set("test-key-purge", for: testAccount)
        XCTAssertEqual(KeychainStore.string(for: testAccount), "test-key-purge")

        let removed = KeychainStore.removeAll()
        XCTAssertTrue(removed, "KeychainStore.removeAll() must succeed")
        XCTAssertNil(KeychainStore.string(for: testAccount), "Secret must be nil after removeAll()")
    }

    // MARK: - 21. Custom URL Scheme Tests
    func testURLSchemeParsing() {
        guard let url = URL(string: "nekotrans://translate?text=Hello%20world") else {
            XCTFail("Invalid URL")
            return
        }
        XCTAssertEqual(url.scheme, "nekotrans")
        XCTAssertEqual(url.host, "translate")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let text = components?.queryItems?.first(where: { $0.name == "text" })?.value
        XCTAssertEqual(text, "Hello world")
    }
}
