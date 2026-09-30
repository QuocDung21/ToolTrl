import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public var floatingPanel: FloatingPanel?
    private var viewModel: TranslationViewModel!
    private var menuBarController: MenuBarController?
    private var lastTriggerTime: Date = .distantPast
    

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Update dock icon to newest NekoTrans icon
        AppIconService.shared.updateDockIcon()

        // Setup standard macOS Application Menu (Quit, Close, Edit, Window)
        setupMainMenu()

        // Configure Dock vs Menu Bar activation policy
        if AppSettings.shared.showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }

        viewModel = TranslationViewModel()

        setupFloatingPanel()
        setupMenuBar()
        setupHotKey()

        // Setup background monitors conditionally according to feature flags
        updateBackgroundMonitors()

        NotificationCenter.default.addObserver(forName: .featureFlagsDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.updateBackgroundMonitors()
            }
        }

        // Prompt for Accessibility permission if not granted
        checkAccessibilityOnLaunch()

        // Show native main window on launch
        if AppSettings.shared.showMainWindowOnLaunch {
            MainWindowController.shared.showMainWindow()
        }
    }

    private var lastCopyTime: Date = .distantPast
    private var clipboardChangeCount: Int = NSPasteboard.general.changeCount
    private var clipboardTimer: Timer?

    private func updateBackgroundMonitors() {
        // 1. Double Cmd+C clipboard monitor
        if AppSettings.shared.isDoubleCmdCActive {
            if clipboardTimer == nil {
                setupClipboardMonitor()
            }
        } else {
            clipboardTimer?.invalidate()
            clipboardTimer = nil
        }

        // 2. Selection Bubble monitor
        if AppSettings.shared.isSelectionBubbleActive {
            SelectionBubbleController.shared.startMonitoring()
            SelectionBubbleController.shared.onBubbleClicked = { [weak self] text in
                self?.triggerTranslationWithText(text)
            }
        } else {
            SelectionBubbleController.shared.stopMonitoring()
        }
    }

    private func setupClipboardMonitor() {
        clipboardChangeCount = NSPasteboard.general.changeCount
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleClipboardTick()
            }
        }
    }

    private func handleClipboardTick() {
        guard AppSettings.shared.isDoubleCmdCActive else { return }
        guard !TextGrabber.isSimulatingCopy else {
            clipboardChangeCount = NSPasteboard.general.changeCount
            return
        }
        let currentCount = NSPasteboard.general.changeCount
        if currentCount != clipboardChangeCount {
            clipboardChangeCount = currentCount
            let now = Date()
            if now.timeIntervalSince(lastCopyTime) < 0.45 {
                // Double copy detected within 450ms!
                if let str = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    SelectionBubbleController.shared.hideBubble()
                    viewModel.processText(str)
                    floatingPanel?.showNearCursorOrCenter()
                }
            }
            lastCopyTime = now
        }
    }

    private func setupFloatingPanel() {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 515, height: 390),
            backing: .buffered,
            defer: false
        )

        panel.onCopyRequested = { [weak self] in
            self?.viewModel.copyTranslation()
        }
        panel.onSpeakRequested = { [weak self] in
            self?.viewModel.speakTranslated()
        }
        panel.onBookmarkRequested = { [weak self] in
            self?.viewModel.toggleBookmark()
        }
        panel.onBackRequested = { [weak self] in
            if self?.viewModel.canGoBack == true {
                self?.viewModel.goBack()
            }
        }
        panel.onOpenNotebookRequested = {
            VocabularyWindowController.shared.showNotebook()
        }
        panel.onOpenSettingsRequested = {
            SettingsWindowController.shared.showSettings()
        }
        panel.onSelectionTranslated = { [weak self] selectedText in
            guard let self = self else { return }
            if selectedText != self.viewModel.originalText {
                self.viewModel.processText(selectedText)
            }
        }

        let hudView = TranslationHUDView(
            viewModel: viewModel,
            onTogglePin: { [weak panel] in
                panel?.togglePin()
            },
            onClose: { [weak panel] in
                panel?.hidePanel()
            }
        )

        let hostingView = NSHostingView(rootView: hudView)
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 16
        hostingView.layer?.masksToBounds = true
        panel.contentView = hostingView
        self.floatingPanel = panel
    }

    private func setupMenuBar() {
        menuBarController = MenuBarController(
            viewModel: viewModel,
            onTriggerTranslate: { [weak self] in
                self?.triggerTranslation()
            },
            onTriggerOCR: { [weak self] in
                self?.triggerOCR()
            },
            onOpenSettings: { [weak self] in
                self?.openQuickLookup()
            }
        )
    }

    private func setupHotKey() {
        HotKeyManager.shared.registerHotKeys(
            onTranslate: { [weak self] in
                self?.triggerTranslation()
            },
            onAI: { [weak self] in
                self?.triggerQuickAI()
            },
            onNotebook: {
                VocabularyWindowController.shared.showNotebook()
            },
            onOCR: { [weak self] in
                self?.triggerOCR()
            }
        )
    }

    public func triggerOCR() {
        floatingPanel?.hidePanel()
        ScreenOCRService.shared.captureAndRecognize { [weak self] recognizedText in
            guard let text = recognizedText, !text.isEmpty else { return }
            self?.viewModel.processText(text)
            self?.floatingPanel?.showNearCursorOrCenter()
        }
    }

    public func triggerQuickAI() {
        Task { @MainActor in
            let text = await TextGrabber.shared.getSelectedText()
            QuickAIWindowController.shared.showAI(prompt: text)
        }
    }

    private func checkAccessibilityOnLaunch() {
        if !TextGrabber.isAccessibilityTrusted(prompt: true) {
            AppLog.app.notice("Quyền Trợ năng (Accessibility) chưa được cấp — đã gửi yêu cầu cấp quyền.")
        }
    }

    public func triggerTranslation() {
        let now = Date()
        // Debounce: Chống spam phím tắt dưới 250ms
        guard now.timeIntervalSince(lastTriggerTime) > 0.25 else { return }
        lastTriggerTime = now

        Task { @MainActor in
            SelectionBubbleController.shared.hideBubble()
            let text = await TextGrabber.shared.getSelectedText()
            let isVisible = self.floatingPanel?.isVisible ?? false

            if let selectedText = text, !selectedText.isEmpty {
                // Nếu cửa sổ đang mở và người dùng bấm lại phím tắt trên đúng từ cũ -> Toggle đóng
                if isVisible && selectedText == self.viewModel.originalText {
                    self.floatingPanel?.hidePanel()
                    return
                }

                self.viewModel.processText(selectedText)
                self.floatingPanel?.showNearCursorOrCenter()
            } else {
                if isVisible {
                    // Đang mở -> Toggle đóng
                    self.floatingPanel?.hidePanel()
                } else {
                    // Chưa mở -> Mở ô tìm kiếm thủ công
                    self.floatingPanel?.showNearCursorOrCenter()
                }
            }
        }
    }

    public func triggerTranslationWithText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        self.viewModel.processText(trimmed)
        self.floatingPanel?.showNearCursorOrCenter()
    }

    public func openQuickLookup() {
        let isVisible = self.floatingPanel?.isVisible ?? false
        if isVisible {
            self.floatingPanel?.hidePanel()
        } else {
            self.floatingPanel?.showNearCursorOrCenter()
        }
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainWindowController.shared.showMainWindow()
        return true
    }

    public func showMainWindow() {
        MainWindowController.shared.showMainWindow()
    }

    private var isTerminatingConfirmed = false

    // MARK: - Handle Quit / Command + Q Confirmation
    public func hideToBackground() {
        MainWindowController.shared.hideMainWindow()
        self.floatingPanel?.hidePanel()
        SelectionBubbleController.shared.hideBubble()
        FloatingHomeworkBubbleController.shared.hideBubble()
        QuickAIWindowController.shared.closeWindow()
        TextAnalysisWindowController.shared.closeWindow()
        ContinuityHomeworkWindowController.shared.closeWindow()
        VocabularyWindowController.shared.hideNotebook()
        SettingsWindowController.shared.hideSettings()

        for window in NSApp.windows {
            let className = NSStringFromClass(type(of: window))
            if className.contains("StatusBar") { continue }
            window.orderOut(nil)
        }

        NSApp.hide(nil)
        NSApp.deactivate()
    }

    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if isTerminatingConfirmed {
            return .terminateNow
        }

        // Kiểm tra nếu người dùng đã ghi nhớ lựa chọn trước đó
        switch AppSettings.shared.quitActionPreference {
        case .runInBackground:
            hideToBackground()
            return .terminateCancel
        case .terminateImmediately:
            isTerminatingConfirmed = true
            return .terminateNow
        case .askEveryTime:
            break
        }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Bạn muốn thoát NekoTrans?"
        alert.informativeText = "Ứng dụng có thể tiếp tục chạy ngầm trên thanh Menu để bạn dùng phím tắt dịch nhanh."
        alert.alertStyle = .informational

        // Checkbox ghi nhớ lựa chọn
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Ghi nhớ lựa chọn này"

        alert.addButton(withTitle: "Chạy dưới nền")
        alert.addButton(withTitle: "Thoát hoàn toàn")
        let cancelBtn = alert.addButton(withTitle: "Hủy")
        cancelBtn.keyEquivalent = "\u{1b}" // Esc

        let response = alert.runModal()
        let shouldRemember = alert.suppressionButton?.state == .on

        switch response {
        case .alertFirstButtonReturn:
            // Người dùng chọn chạy dưới nền
            if shouldRemember {
                AppSettings.shared.quitActionPreference = .runInBackground
            }
            hideToBackground()
            return .terminateCancel

        case .alertSecondButtonReturn:
            // Người dùng chọn thoát hoàn toàn
            if shouldRemember {
                AppSettings.shared.quitActionPreference = .terminateImmediately
            }
            isTerminatingConfirmed = true
            return .terminateNow

        default:
            // Người dùng bấm Hủy hoặc Esc -> Hủy thao tác tắt
            return .terminateCancel
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Nếu bấm nút đỏ tắt cửa sổ, app vẫn sẵn sàng chạy ngầm
    }

    // MARK: - Standard macOS System Main Menu (⌘Q, ⌘W, ⌘,, Cut, Copy, Paste)
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        // 1. App Menu (NekoTrans)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()

        appMenu.addItem(withTitle: "Giới thiệu NekoTrans", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(title: "Cài đặt...", action: #selector(handleOpenSettingsFromMenu), keyEquivalent: ",")
        prefsItem.target = self
        appMenu.addItem(prefsItem)

        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Ẩn NekoTrans", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")

        let hideOthersItem = NSMenuItem(title: "Ẩn các ứng dụng khác", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthersItem)

        appMenu.addItem(withTitle: "Hiện tất cả", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Thoát NekoTrans", action: #selector(handleQuitApp), keyEquivalent: "q")
        quitItem.target = self
        appMenu.addItem(quitItem)

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // 2. File Menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "Tệp")
        fileMenu.addItem(withTitle: "Đóng cửa sổ", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // 3. Edit Menu (Standard macOS Cut/Copy/Paste/Undo/Redo)
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Sửa")
        editMenu.addItem(withTitle: "Hoàn tác", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = NSMenuItem(title: "Làm lại", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cắt", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Sao chép", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Dán", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Chọn tất cả", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // 4. Window Menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Cửa sổ")
        windowMenu.addItem(withTitle: "Thu nhỏ", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Phóng to", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    @objc private func handleOpenSettingsFromMenu() {
        SettingsWindowController.shared.showSettings()
    }

    @objc private func handleQuitApp() {
        NSApp.terminate(nil)
    }
}
