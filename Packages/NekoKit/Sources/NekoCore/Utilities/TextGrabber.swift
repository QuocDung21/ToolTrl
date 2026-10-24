import Foundation
import AppKit
import ApplicationServices

@MainActor
public final class TextGrabber {
    public static let shared = TextGrabber()
    public static var isSimulatingCopy: Bool = false
    public private(set) var lastExternalApplication: NSRunningApplication?

    private init() {
        // Track the most recent external (non-NekoTrans) application that was active
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                MainActor.assumeIsolated {
                    self?.lastExternalApplication = app
                }
            }
        }

        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.lastExternalApplication = front
        }
    }

    /// Resolves the intended target application from which to extract text (never NekoTrans itself)
    public func getTargetApplication() -> NSRunningApplication? {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier,
           !front.isTerminated {
            return front
        }
        if let last = lastExternalApplication, !last.isTerminated {
            return last
        }
        return NSWorkspace.shared.runningApplications.first(where: {
            $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier && !$0.isTerminated
        })
    }

    /// Check if the application has accessibility permissions
    public static func isAccessibilityTrusted(prompt: Bool = false) -> Bool {
        if prompt {
            let promptKey = "AXTrustedCheckOptionPrompt" as CFString
            let options = [promptKey: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        } else {
            return AXIsProcessTrusted()
        }
    }

    /// Non-invasive text extraction without clipboard modification or simulated keystrokes.
    /// Safe for mouse-up selection bubbles and pinned auto-translate.
    public func getSelectedTextNonInvasive() async -> String? {
        let targetApp = getTargetApplication()
        let bundleID = targetApp?.bundleIdentifier ?? ""

        // Strategy 1: Browser JavaScript DOM selection
        if BrowserScriptHelper.isSupportedBrowser(bundleID) {
            if let browserText = await BrowserScriptHelper.getSelectedText(bundleID: bundleID),
               !browserText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return browserText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Strategy 2: Pure Accessibility API
        if let axText = getSelectedTextViaAccessibility(targetApp: targetApp),
           !axText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return axText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    /// Pure accessibility extraction without simulated keystrokes or clipboard modification
    public func getSelectedTextOnlyAccessibility() -> String? {
        if let axText = getSelectedTextViaAccessibility(targetApp: getTargetApplication()),
           !axText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return axText.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    /// Extracts the full text from the focused element (e.g. text field or text area) when no text is explicitly highlighted
    public func getFocusedElementFullText() -> String? {
        guard let targetApp = getTargetApplication() else { return nil }
        let appElement = AXUIElementCreateApplication(targetApp.processIdentifier)
        var focusedRef: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
           let focused = focusedRef,
           CFGetTypeID(focused as CFTypeRef) == AXUIElementGetTypeID() {
            let ax = focused as! AXUIElement
            var valRef: AnyObject?
            if AXUIElementCopyAttributeValue(ax, kAXValueAttribute as CFString, &valRef) == .success,
               let str = valRef as? String, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return str.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    /// Stores the last detected browser URL when text was grabbed from a web browser
    public private(set) var lastDetectedBrowserURL: String? = nil

    /// Get the currently selected text across macOS (browser DOM selection first, then AX, then clean Cmd+C fallback)
    public func getSelectedText() async -> String? {
        lastDetectedBrowserURL = nil
        let targetApp = getTargetApplication()
        let bundleID = targetApp?.bundleIdentifier ?? ""

        // Strategy 1: For web browsers, try JavaScript DOM selection FIRST!
        // In browsers, window.getSelection().toString() reflects the user's active drag selection,
        // avoiding stale AXUIElement focus (e.g. previously clicked input fields or search bars).
        if BrowserScriptHelper.isSupportedBrowser(bundleID) {
            if let browserText = await BrowserScriptHelper.getSelectedText(bundleID: bundleID),
               !browserText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lastDetectedBrowserURL = await BrowserScriptHelper.getCurrentTabURL(bundleID: bundleID)
                return browserText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Strategy 2: Accessibility API on target application (Direct extraction without clipboard manipulation)
        if let axText = getSelectedTextViaAccessibility(targetApp: targetApp),
           !axText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if BrowserScriptHelper.isSupportedBrowser(bundleID) {
                lastDetectedBrowserURL = await BrowserScriptHelper.getCurrentTabURL(bundleID: bundleID)
            }
            return axText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Strategy 3: High-reliability simulated Cmd+C with modifier key release
        if let clipText = await getSelectedTextViaSimulatedCopy(targetApp: targetApp),
           !clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if BrowserScriptHelper.isSupportedBrowser(bundleID) {
                lastDetectedBrowserURL = await BrowserScriptHelper.getCurrentTabURL(bundleID: bundleID)
            }
            return clipText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    // MARK: - Accessibility API Extraction
    private func getSelectedTextViaAccessibility(targetApp: NSRunningApplication?) -> String? {
        guard let app = targetApp, app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Method A: Check focused UI element in target app
        var focusedElementRef: AnyObject?
        let focusedErr = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef)
        if focusedErr == .success, let focusedElement = focusedElementRef, CFGetTypeID(focusedElement as CFTypeRef) == AXUIElementGetTypeID() {
            if let text = extractText(from: focusedElement as! AXUIElement, expectedPID: app.processIdentifier) {
                return text
            }
        }

        // Method B: Check focused window in target app
        var focusedWindowRef: AnyObject?
        let windowErr = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef)
        if windowErr == .success, let focusedWindow = focusedWindowRef, CFGetTypeID(focusedWindow as CFTypeRef) == AXUIElementGetTypeID() {
            if let text = extractText(from: focusedWindow as! AXUIElement, expectedPID: app.processIdentifier) {
                return text
            }
        }

        // Method C: System-wide focused element, strictly verified to belong to target app
        let systemWide = AXUIElementCreateSystemWide()
        var systemFocusedRef: AnyObject?
        let sysErr = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &systemFocusedRef)
        if sysErr == .success, let element = systemFocusedRef, CFGetTypeID(element as CFTypeRef) == AXUIElementGetTypeID() {
            if let text = extractText(from: element as! AXUIElement, expectedPID: app.processIdentifier) {
                return text
            }
        }

        return nil
    }

    private func extractText(from element: AXUIElement, expectedPID: pid_t? = nil) -> String? {
        var pid: pid_t = 0
        if AXUIElementGetPid(element, &pid) == .success {
            // Never extract from NekoTrans itself
            if pid == ProcessInfo.processInfo.processIdentifier {
                return nil
            }
            // If expectedPID was specified, verify it strictly matches
            if let expected = expectedPID, pid != expected {
                return nil
            }
        }

        var selectedTextRef: AnyObject?
        let textError = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedTextRef)
        if textError == .success, let selectedText = selectedTextRef as? String, !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return selectedText
        }

        // Try getting parameterized selected text range
        var selectedRangeRef: AnyObject?
        let rangeError = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &selectedRangeRef)
        if rangeError == .success, let rangeValue = selectedRangeRef {
            var stringRef: AnyObject?
            let stringError = AXUIElementCopyParameterizedAttributeValue(element, kAXStringForRangeParameterizedAttribute as CFString, rangeValue, &stringRef)
            if stringError == .success, let text = stringRef as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }

        return nil
    }

    // MARK: - Reliable Fallback Copy Simulation
    private func getSelectedTextViaSimulatedCopy(targetApp: NSRunningApplication?) async -> String? {
        guard let app = targetApp, app.bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }

        TextGrabber.isSimulatingCopy = true

        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount
        let previousString = pasteboard.string(forType: .string)

        // Wait up to 100ms for physical hotkey modifier keys (e.g. Option, Shift) to be released
        let deadline = Date().addingTimeInterval(0.10)
        while Date() < deadline {
            let flags = NSEvent.modifierFlags
            if !flags.contains(.option) && !flags.contains(.shift) && !flags.contains(.control) {
                break
            }
            try? await Task.sleep(nanoseconds: 15_000_000) // 15ms
        }

        // Post Clean Cmd+C without physical modifier bleed
        postCleanCopyShortcut()

        // Poll for clipboard change (max 360ms)
        var didChange = false
        for _ in 0..<18 {
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
            if pasteboard.changeCount != initialChangeCount {
                didChange = true
                break
            }
        }

        guard didChange, let newCopiedText = pasteboard.string(forType: .string), !newCopiedText.isEmpty else {
            TextGrabber.isSimulatingCopy = false
            return nil
        }

        // Restore user's previous clipboard string cleanly after short delay
        if let oldText = previousString, oldText != newCopiedText {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(oldText, forType: .string)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    TextGrabber.isSimulatingCopy = false
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                TextGrabber.isSimulatingCopy = false
            }
        }

        return newCopiedText
    }

    private func postCleanCopyShortcut() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        // Release any lingering physical modifier keys to prevent ⌥⌘C / ⇧⌘C collisions
        let modifierKeys: [CGKeyCode] = [58, 61, 56, 60, 59, 62] // Left/Right Option, Shift, Control
        for key in modifierKeys {
            if let modUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false) {
                modUp.flags = []
                modUp.post(tap: .cgSessionEventTap)
            }
        }

        let cKeyCode: CGKeyCode = 8 // 'C'
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
    }
}
