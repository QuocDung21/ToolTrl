import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingPanel: FloatingPanel?
    private var viewModel: TranslationViewModel!
    private var menuBarController: MenuBarController?
    private var lastTriggerTime: Date = .distantPast
    
    public override init() {
        super.init()
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run as background agent without Dock icon
        NSApp.setActivationPolicy(.accessory)
        
        viewModel = TranslationViewModel()
        
        setupFloatingPanel()
        setupMenuBar()
        setupHotKey()
        
        // Prompt for Accessibility permission if not granted
        checkAccessibilityOnLaunch()
    }
    
    private func setupFloatingPanel() {
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 455, height: 345),
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
        panel.onOpenNotebookRequested = {
            VocabularyWindowController.shared.showNotebook()
        }
        panel.onOpenSettingsRequested = {
            SettingsWindowController.shared.showSettings()
        }
        
        let hudView = TranslationHUDView(viewModel: viewModel) { [weak panel] in
            panel?.hidePanel()
        }
        
        panel.contentView = NSHostingView(rootView: hudView)
        self.floatingPanel = panel
    }
    
    private func setupMenuBar() {
        menuBarController = MenuBarController(
            viewModel: viewModel,
            onTriggerTranslate: { [weak self] in
                self?.triggerTranslation()
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
            }
        )
    }
    
    public func triggerQuickAI() {
        Task { @MainActor in
            let text = await TextGrabber.shared.getSelectedText()
            QuickAIWindowController.shared.showAI(prompt: text)
        }
    }
    
    private func checkAccessibilityOnLaunch() {
        if !TextGrabber.isAccessibilityTrusted(prompt: true) {
            print("⚠️ Quyền Trợ năng (Accessibility) chưa được cấp. Đã gửi yêu cầu cấp quyền.")
        }
    }
    
    public func triggerTranslation() {
        let now = Date()
        // Debounce: Chống spam phím tắt dưới 250ms
        guard now.timeIntervalSince(lastTriggerTime) > 0.25 else { return }
        lastTriggerTime = now
        
        Task { @MainActor in
            let text = await TextGrabber.shared.getSelectedText()
            let isVisible = self.floatingPanel?.isVisible ?? false
            
            if let selectedText = text, !selectedText.isEmpty {
                // Nếu cửa sổ đang mở và người dùng bấm lại phím tắt trên đúng từ cũ -> Toggle đóng
                if isVisible && selectedText == self.viewModel.originalText {
                    self.floatingPanel?.hidePanel()
                    return
                }
                
                // Nếu chọn từ mới -> Cập nhật và hiển thị
                self.viewModel.processText(selectedText)
                self.floatingPanel?.showNearCursorOrCenter()
            } else {
                // Nếu không bôi đen từ nào:
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
    
    public func openQuickLookup() {
        let isVisible = self.floatingPanel?.isVisible ?? false
        if isVisible {
            self.floatingPanel?.hidePanel()
        } else {
            self.floatingPanel?.showNearCursorOrCenter()
        }
    }
    
    // MARK: - Handle Quit / Command + Q Confirmation
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let alert = NSAlert()
        alert.messageText = "Bạn có muốn tiếp tục chạy nền ToolTrL?"
        alert.informativeText = "ToolTrL là ứng dụng tiện ích. Ứng dụng sẽ tiếp tục chạy ẩn trên thanh Menu Bar để bạn có thể sử dụng phím tắt Option + D (⌥D) tra cứu nhanh bất kỳ lúc nào."
        alert.alertStyle = .informational
        
        // Button 1: Chạy nền (Ẩn vào Menu Bar) - Default
        alert.addButton(withTitle: "Chạy nền (Khuyên dùng)")
        // Button 2: Thoát hoàn toàn
        alert.addButton(withTitle: "Thoát hoàn toàn")
        
        let icon = AppLogo.nsImage
        alert.icon = icon
        
        NSApp.activate(ignoringOtherApps: true)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Chạy nền: Đóng popup nếu đang mở và hủy thao tác thoát
            self.floatingPanel?.hidePanel()
            return .terminateCancel
        } else {
            // Thoát hoàn toàn
            return .terminateNow
        }
    }
}
