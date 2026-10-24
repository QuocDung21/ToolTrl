import Foundation
import AppKit
import ApplicationServices
import Defaults

/// Central Action Manager for In-Place Text Processing (Translate & Replace, Polish & Replace)
/// Inherited and adapted from Easydict's `ActionManager.swift` and `SystemUtility+AX.swift`.
@MainActor
public final class ActionManager: ObservableObject {
    public static let shared = ActionManager()
    
    @Published public private(set) var isProcessing: Bool = false
    
    private init() {}
    
    // MARK: - 1. Translate & Replace
    
    /// Translates the selected text (or focused text field) in the active application and replaces it in-place.
    public func translateAndReplace(targetLanguage: TargetLanguage? = nil) async {
        guard !isProcessing else { return }
        guard Defaults[.enableInPlaceReplace] else { return }
        guard !AppExclusionService.shared.isCurrentAppExcluded() else {
            AppLog.translation.notice("Ứng dụng hiện tại đang nằm trong danh sách loại trừ (Silent Mode).")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // 1. Grab text from frontmost app (selection or focused element)
        var queryText = await TextGrabber.shared.getSelectedText()
        if queryText?.isEmpty ?? true {
            queryText = TextGrabber.shared.getFocusedElementFullText()
        }
        
        guard let raw = queryText, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            AppLog.translation.notice("Không tìm thấy văn bản được chọn để Dịch & Thay thế.")
            return
        }
        
        let cleaned = InputTextNormalizer.normalize(raw)
        let effectiveQuery = cleaned.isEmpty ? raw : cleaned
        
        // 2. Detect language and resolve target
        let detected = TranslationService.shared.detectLanguage(for: effectiveQuery)
        let target = targetLanguage ?? InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: detected,
            configuredTarget: TargetLanguage(rawValue: Defaults[.targetLanguage]) ?? .vietnamese
        )
        
        AppLog.translation.notice("Đang Dịch & Thay thế (\(detected) → \(target.rawValue)): \(effectiveQuery.prefix(30), privacy: .private)...")
        
        // 3. Perform translation
        guard let translated = await TranslationService.shared.translate(
            text: effectiveQuery,
            from: detected,
            to: target.rawValue,
            domain: AppSettings.shared.translationDomain,
            engine: AppSettings.shared.translationEngine
        ), !translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            AppLog.translation.error("Dịch thất bại, hủy thay thế văn bản.")
            return
        }
        
        // 4. Replace text in-place at cursor
        await replaceSelectedText(with: translated)
        
        if Defaults[.inPlaceReplaceSound] {
            SoundService.playPopSound()
        }
    }
    
    // MARK: - 2. Polish / Fix Grammar & Replace
    
    /// Polishes spelling, grammar, and fluency of selected text and replaces it in-place.
    public func polishAndReplace() async {
        guard !isProcessing else { return }
        guard Defaults[.enableInPlaceReplace] else { return }
        guard !AppExclusionService.shared.isCurrentAppExcluded() else {
            AppLog.translation.notice("Ứng dụng hiện tại đang nằm trong danh sách loại trừ (Silent Mode).")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        // 1. Grab text
        var queryText = await TextGrabber.shared.getSelectedText()
        if queryText?.isEmpty ?? true {
            queryText = TextGrabber.shared.getFocusedElementFullText()
        }
        
        guard let raw = queryText, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            AppLog.translation.notice("Không tìm thấy văn bản được chọn để Trau chuốt & Sửa lỗi.")
            return
        }
        
        let cleaned = InputTextNormalizer.normalize(raw)
        let effectiveQuery = cleaned.isEmpty ? raw : cleaned
        
        AppLog.translation.notice("Đang Trau chuốt & Sửa lỗi AI: \(effectiveQuery.prefix(30), privacy: .private)...")
        
        var polishedResult: String? = nil
        
        // 2. Try fast direct polishing prompt
        do {
            let prompt = AIPromptBuilder.quickPolishingPrompt(text: effectiveQuery)
            let result = try await DirectAIService.shared.sendPromptToAI(prompt: prompt)
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                polishedResult = trimmed
            }
        } catch {
            AppLog.translation.notice("Direct prompt thất bại (\(error.localizedDescription)), chuyển sang analyzeGrammarAndRephrase fallback.")
        }
        
        // 3. Fallback to grammar rewrite result if needed
        if polishedResult == nil {
            if let result = try? await DirectAIService.shared.analyzeGrammarAndRephrase(text: effectiveQuery) {
                let best = !result.businessVersion.isEmpty ? result.businessVersion : result.correction
                if !best.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    polishedResult = best
                }
            }
        }
        
        guard let finalPolished = polishedResult, !finalPolished.isEmpty else {
            AppLog.translation.error("Trau chuốt thất bại, hủy thay thế.")
            return
        }
        
        // 4. Replace text in-place at cursor
        await replaceSelectedText(with: finalPolished)
        
        if Defaults[.inPlaceReplaceSound] {
            SoundService.playPopSound()
        }
    }
    
    // MARK: - 3. In-Place Text Replacement Engine
    
    /// Replaces the currently focused / selected text using Accessibility API,
    /// falling back to non-destructive simulated Cmd+V with pasteboard backup & restore.
    public func replaceSelectedText(with text: String) async {
        // Method A: Accessibility API direct replacement (non-destructive, zero clipboard interference)
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
            var focusedRef: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
               let focused = focusedRef,
               CFGetTypeID(focused as CFTypeRef) == AXUIElementGetTypeID() {
                let ax = focused as! AXUIElement
                
                // Try setting kAXSelectedTextAttribute
                let errSelected = AXUIElementSetAttributeValue(ax, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
                if errSelected == .success {
                    AppLog.translation.debug("Thay thế thành công bằng Accessibility kAXSelectedTextAttribute.")
                    return
                }
                
                // If no selection was active, try setting kAXValueAttribute
                var valRef: AnyObject?
                if AXUIElementCopyAttributeValue(ax, kAXValueAttribute as CFString, &valRef) == .success,
                   valRef != nil {
                    let errValue = AXUIElementSetAttributeValue(ax, kAXValueAttribute as CFString, text as CFTypeRef)
                    if errValue == .success {
                        AppLog.translation.debug("Thay thế thành công bằng Accessibility kAXValueAttribute.")
                        return
                    }
                }
            }
        }
        
        // Method B: High-reliability simulated Cmd+V with pasteboard snapshot backup and restore
        AppLog.translation.debug("Thực hiện thay thế bằng mô phỏng Cmd+V an toàn.")
        let pasteboard = NSPasteboard.general
        
        // Backup existing pasteboard contents
        var backupItems: [(type: NSPasteboard.PasteboardType, data: Data)] = []
        if let items = pasteboard.pasteboardItems {
            for item in items {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        backupItems.append((type, data))
                    }
                }
            }
        }
        
        // Write replacement text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // 35ms pause to allow pasteboard synchronization across processes
        try? await Task.sleep(nanoseconds: 35_000_000)
        
        // Post Cmd+V
        postCleanPasteShortcut()
        
        // Restore user's previous clipboard after 350ms so clipboard is not polluted
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard !backupItems.isEmpty else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            let restoredItem = NSPasteboardItem()
            for (type, data) in backupItems {
                restoredItem.setData(data, forType: type)
            }
            pb.writeObjects([restoredItem])
        }
    }
    
    private func postCleanPasteShortcut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let vKeyCode: CGKeyCode = 9 // Virtual key 'V'
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }
        
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
