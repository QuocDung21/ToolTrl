import Foundation
import AppKit
import WebKit
import ServiceManagement
import KeyboardShortcuts

public struct UninstallTarget: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let icon: String
    public let path: String?
    public let sizeBytes: Int64
    public let exists: Bool
    public let isRemovable: Bool

    public var formattedSize: String {
        if !exists { return "0 B" }
        if sizeBytes == 0 { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    public init(
        id: String,
        title: String,
        detail: String,
        icon: String,
        path: String? = nil,
        sizeBytes: Int64 = 0,
        exists: Bool = true,
        isRemovable: Bool = false
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.icon = icon
        self.path = path
        self.sizeBytes = sizeBytes
        self.exists = exists
        self.isRemovable = isRemovable
    }
}

@MainActor
public final class AppUninstaller: ObservableObject {
    public static let shared = AppUninstaller()

    @Published public private(set) var targets: [UninstallTarget] = []
    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var isUninstalling: Bool = false
    @Published public private(set) var currentOperation: String = ""
    @Published public var deleteJournal: Bool = true

    public var totalSizeBytes: Int64 {
        targets.filter { $0.exists }.reduce(0) { $0 + $1.sizeBytes }
    }

    public var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
    }

    private init() {}

    // MARK: - Scan Items
    public func scanTargets() {
        isScanning = true
        let isEn = Localization.shared.resolvedLanguage == .english
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        var items: [UninstallTarget] = []

        // 1. App Bundle
        var bundleURL = Bundle.main.bundleURL
        if !bundleURL.path.hasSuffix(".app") {
            bundleURL = URL(fileURLWithPath: "/Applications/NekoTrans.app")
        }
        let bundleSize = calculateSize(at: bundleURL)
        items.append(UninstallTarget(
            id: "app_bundle",
            title: isEn ? "Application Bundle" : "Gói Ứng dụng NekoTrans",
            detail: bundleURL.path,
            icon: "macwindow.on.rectangle",
            path: bundleURL.path,
            sizeBytes: bundleSize,
            exists: fileManager.fileExists(atPath: bundleURL.path)
        ))

        // Also check /Applications/NekoTrans.app if different
        let stdAppURL = URL(fileURLWithPath: "/Applications/NekoTrans.app")
        if stdAppURL.path != bundleURL.path && fileManager.fileExists(atPath: stdAppURL.path) {
            let stdSize = calculateSize(at: stdAppURL)
            items.append(UninstallTarget(
                id: "std_app_bundle",
                title: isEn ? "Applications Copy" : "Bản cài đặt trong /Applications",
                detail: stdAppURL.path,
                icon: "app.dashed",
                path: stdAppURL.path,
                sizeBytes: stdSize,
                exists: true
            ))
        }

        // 2. Application Support (NekoTrans)
        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let nekoDir = appSupport.appendingPathComponent("NekoTrans")
            let size = calculateSize(at: nekoDir)
            items.append(UninstallTarget(
                id: "app_support_neko",
                title: isEn ? "Vocabulary Store & Data" : "Kho từ vựng & Dữ liệu NekoTrans",
                detail: nekoDir.path,
                icon: "book.closed.fill",
                path: nekoDir.path,
                sizeBytes: size,
                exists: fileManager.fileExists(atPath: nekoDir.path)
            ))

            let legacyDir = appSupport.appendingPathComponent("ToolTrL")
            if fileManager.fileExists(atPath: legacyDir.path) {
                let legSize = calculateSize(at: legacyDir)
                items.append(UninstallTarget(
                    id: "app_support_tooltrl",
                    title: isEn ? "Legacy Learning Stats & Icons" : "Thống kê & Biểu tượng (ToolTrL cũ)",
                    detail: legacyDir.path,
                    icon: "chart.bar.fill",
                    path: legacyDir.path,
                    sizeBytes: legSize,
                    exists: true
                ))
            }
        }

        // 3. Preferences (UserDefaults plist)
        let prefPath = home.appendingPathComponent("Library/Preferences/com.nekotrans.mac.plist").path
        let prefSize = fileManager.fileExists(atPath: prefPath) ? calculateSize(at: URL(fileURLWithPath: prefPath)) : 0
        items.append(UninstallTarget(
            id: "preferences",
            title: isEn ? "App Preferences & Settings" : "Tùy chọn & Cấu hình ứng dụng",
            detail: prefPath,
            icon: "gearshape.fill",
            path: prefPath,
            sizeBytes: prefSize,
            exists: fileManager.fileExists(atPath: prefPath)
        ))

        // 4. Keychain Secrets
        items.append(UninstallTarget(
            id: "keychain",
            title: isEn ? "Keychain API Keys & Tokens" : "Mật mã & API Keys (macOS Keychain)",
            detail: isEn ? "OpenAI, Anthropic, Gemini, Groq, DeepSeek, DeepL, GitHub PAT" : "Toàn bộ API Key LLM và GitHub PAT lưu trong Keychain",
            icon: "key.fill",
            path: nil,
            sizeBytes: 0,
            exists: true
        ))

        // 5. Caches
        if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            let cacheDir = caches.appendingPathComponent("com.nekotrans.mac")
            let cacheSize = calculateSize(at: cacheDir)
            items.append(UninstallTarget(
                id: "caches",
                title: isEn ? "Caches & Updates" : "Bộ nhớ đệm & Tải về Sparkle",
                detail: cacheDir.path,
                icon: "clock.arrow.circlepath",
                path: cacheDir.path,
                sizeBytes: cacheSize,
                exists: fileManager.fileExists(atPath: cacheDir.path)
            ))
        }

        // 6. WebKit & HTTP Storage
        let webKitDir = home.appendingPathComponent("Library/WebKit/com.nekotrans.mac")
        let httpDir = home.appendingPathComponent("Library/HTTPStorages/com.nekotrans.mac")
        let webSize = calculateSize(at: webKitDir) + calculateSize(at: httpDir)
        let webExists = fileManager.fileExists(atPath: webKitDir.path) || fileManager.fileExists(atPath: httpDir.path)
        items.append(UninstallTarget(
            id: "webkit",
            title: isEn ? "AI Assistant Web Storage" : "Bộ nhớ Web Trợ lý AI (WebKit)",
            detail: webKitDir.path,
            icon: "globe",
            path: webKitDir.path,
            sizeBytes: webSize,
            exists: webExists
        ))

        // 7. Saved State
        let savedStateDir = home.appendingPathComponent("Library/Saved Application State/com.nekotrans.mac.savedState")
        if fileManager.fileExists(atPath: savedStateDir.path) {
            let stateSize = calculateSize(at: savedStateDir)
            items.append(UninstallTarget(
                id: "saved_state",
                title: isEn ? "Saved Window State" : "Trạng thái cửa sổ đã lưu",
                detail: savedStateDir.path,
                icon: "macwindow",
                path: savedStateDir.path,
                sizeBytes: stateSize,
                exists: true
            ))
        }

        // 8. Spotlight & Login Item
        items.append(UninstallTarget(
            id: "system_integration",
            title: isEn ? "System Integration" : "Tích hợp hệ thống (Spotlight & Khởi động)",
            detail: isEn ? "CoreSpotlight index, ServiceManagement login item, Global hotkeys" : "Chỉ mục Spotlight, Khởi động cùng macOS, Phím tắt toàn cục",
            icon: "sparkle.magnifyingglass",
            path: nil,
            sizeBytes: 0,
            exists: true
        ))

        // 9. Vocabulary Journal (words.jsonl)
        let journalURL = ContinuousJournalService.shared.journalFileURL
        let journalParent = journalURL.deletingLastPathComponent()
        let journalSize = fileManager.fileExists(atPath: journalURL.path) ? calculateSize(at: journalParent) : 0
        items.append(UninstallTarget(
            id: "journal",
            title: isEn ? "Continuous Journal (words.jsonl)" : "Nhật ký từ vựng (words.jsonl)",
            detail: journalURL.path,
            icon: "doc.plaintext.fill",
            path: journalURL.path,
            sizeBytes: journalSize,
            exists: fileManager.fileExists(atPath: journalURL.path),
            isRemovable: true
        ))

        self.targets = items
        self.isScanning = false
    }

    // MARK: - Size Calculation Helper
    private func calculateSize(at url: URL) -> Int64 {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return 0
        }
        if !isDirectory.boolValue {
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        }
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey]) {
                total += Int64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileSize ?? 0)
            }
        }
        return total
    }

    // MARK: - Clean Uninstall Execution
    public func performCleanUninstall(deleteJournal: Bool) async {
        isUninstalling = true
        let isEn = Localization.shared.resolvedLanguage == .english
        currentOperation = isEn ? "Unregistering system services..." : "Đang hủy đăng ký dịch vụ hệ thống..."
        AppLog.uninstall.notice("Beginning clean uninstallation...")

        // 1. ServiceManagement (Login Item)
        do {
            if SMAppService.mainApp.status == .enabled {
                try await SMAppService.mainApp.unregister()
                AppLog.uninstall.notice("Unregistered SMAppService.")
            }
        } catch {
            AppLog.uninstall.error("Failed to unregister SMAppService: \(error.localizedDescription, privacy: .public)")
        }

        // 2. Clear Spotlight Search Index
        currentOperation = isEn ? "Purging Spotlight search index..." : "Đang xóa sạch chỉ mục Spotlight..."
        await withCheckedContinuation { continuation in
            SpotlightService.shared.clearAllIndex { _ in
                continuation.resume()
            }
        }

        // 3. Clear Keychain Secrets
        currentOperation = isEn ? "Removing API keys from Keychain..." : "Đang xóa mật mã & khóa API trong Keychain..."
        KeychainStore.removeAll()
        AppLog.uninstall.notice("Purged all Keychain items.")

        // 4. Reset Keyboard Shortcuts
        currentOperation = isEn ? "Resetting global shortcuts..." : "Đang đặt lại phím tắt toàn cục..."
        KeyboardShortcuts.reset(
            .translate,
            .ai,
            .notebook,
            .ocr,
            .silentOCR,
            .translateAndReplace,
            .polishAndReplace
        )

        // 5. Clear WebKit Data Store
        currentOperation = isEn ? "Clearing WebKit & cookies..." : "Đang xóa bộ nhớ đệm WebKit & Cookies..."
        await withCheckedContinuation { continuation in
            let dataStore = WKWebsiteDataStore.default()
            dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), for: records) {
                    continuation.resume()
                }
            }
        }

        // 6. Delete Application Data & Caches on disk
        currentOperation = isEn ? "Removing application files & cache..." : "Đang xóa tệp tin ứng dụng & bộ nhớ đệm..."
        let fileManager = FileManager.default
        var pathsToDelete: [URL] = []

        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            pathsToDelete.append(appSupport.appendingPathComponent("NekoTrans"))
            pathsToDelete.append(appSupport.appendingPathComponent("ToolTrL"))
        }
        if let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            pathsToDelete.append(caches.appendingPathComponent("com.nekotrans.mac"))
            pathsToDelete.append(caches.appendingPathComponent("com.quocdung.tooltrl"))
        }

        let home = fileManager.homeDirectoryForCurrentUser
        pathsToDelete.append(home.appendingPathComponent("Library/WebKit/com.nekotrans.mac"))
        pathsToDelete.append(home.appendingPathComponent("Library/HTTPStorages/com.nekotrans.mac"))
        pathsToDelete.append(home.appendingPathComponent("Library/Saved Application State/com.nekotrans.mac.savedState"))
        pathsToDelete.append(home.appendingPathComponent("Library/Preferences/com.nekotrans.mac.plist"))
        pathsToDelete.append(home.appendingPathComponent("Library/Preferences/com.quocdung.tooltrl.plist"))

        if deleteJournal {
            let journalURL = ContinuousJournalService.shared.journalFileURL
            pathsToDelete.append(journalURL)
            let journalParent = journalURL.deletingLastPathComponent()
            if journalParent.lastPathComponent == "NekoTrans" {
                pathsToDelete.append(journalParent)
            }
            let defaultDocsNeko = home.appendingPathComponent("Documents/NekoTrans")
            pathsToDelete.append(defaultDocsNeko)
        }

        // Temporary directory files
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        if let tempContents = try? fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for url in tempContents {
                let name = url.lastPathComponent.lowercased()
                if name.contains("nekotrans") || name.contains("tooltrl") {
                    pathsToDelete.append(url)
                }
            }
        }

        for url in pathsToDelete {
            if fileManager.fileExists(atPath: url.path) {
                do {
                    try fileManager.removeItem(at: url)
                    AppLog.uninstall.notice("Removed: \(url.path, privacy: .public)")
                } catch {
                    AppLog.uninstall.error("Failed to remove \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        // 7. Reset UserDefaults Persistent Domains
        currentOperation = isEn ? "Resetting preferences..." : "Đang xóa thiết lập UserDefaults..."
        UserDefaults.standard.removePersistentDomain(forName: "com.nekotrans.mac")
        UserDefaults.standard.removePersistentDomain(forName: "com.quocdung.tooltrl")
        if let bid = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bid)
        }
        UserDefaults.standard.synchronize()

        // 8. Delete App Bundle via detached helper process and terminate
        currentOperation = isEn ? "Cleaning app bundle & quitting..." : "Đang dọn sạch gói ứng dụng và thoát..."
        let pid = ProcessInfo.processInfo.processIdentifier
        var appPaths = [Bundle.main.bundleURL.path]
        let standardAppPath = "/Applications/NekoTrans.app"
        if fileManager.fileExists(atPath: standardAppPath) && !appPaths.contains(standardAppPath) {
            appPaths.append(standardAppPath)
        }

        var deletionCommands = ""
        for path in appPaths {
            let escapedPath = path.replacingOccurrences(of: "\"", with: "\\\"")
            deletionCommands += """
            if [ -e "\(escapedPath)" ]; then
                osascript -e 'tell application "Finder" to delete POSIX file "\(escapedPath)"' 2>/dev/null || rm -rf "\(escapedPath)"
            fi
            
            """
        }

        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done;
        \(deletionCommands)
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        try? process.run()

        AppLog.uninstall.notice("Detached uninstallation process launched. Terminating application...")

        try? await Task.sleep(nanoseconds: 600_000_000)
        NSApp.terminate(nil)
        exit(0)
    }
}
