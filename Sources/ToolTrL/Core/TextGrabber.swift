import Foundation
import AppKit
import ApplicationServices

@MainActor
public final class TextGrabber {
    public static let shared = TextGrabber()

    private init() {}

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

    /// Get the currently selected text across macOS
    public func getSelectedText() async -> String? {
        // Attempt 1: Accessibility API (Direct extraction without clipboard manipulation)
        if let axText = getSelectedTextViaAccessibility(), !axText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return axText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Attempt 2: High-reliability simulated Cmd+C with modifier release & clipboard verification
        if let clipText = await getSelectedTextViaSimulatedCopy(), !clipText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return clipText.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    // MARK: - Accessibility API Extraction
    private func getSelectedTextViaAccessibility() -> String? {
        // Method A: Check frontmost application
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

            var focusedElementRef: AnyObject?
            let focusedErr = AXUIElementCopyAttributeValue(appElement, kAXFocusedUIElementAttribute as CFString, &focusedElementRef)
            if focusedErr == .success, let focusedElement = focusedElementRef {
                if let text = extractText(from: focusedElement as! AXUIElement) {
                    return text
                }
            }

            var focusedWindowRef: AnyObject?
            let windowErr = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowRef)
            if windowErr == .success, let focusedWindow = focusedWindowRef {
                if let text = extractText(from: focusedWindow as! AXUIElement) {
                    return text
                }
            }
        }

        // Method B: System-wide focused element
        let systemWide = AXUIElementCreateSystemWide()
        var systemFocusedRef: AnyObject?
        let sysErr = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &systemFocusedRef)
        if sysErr == .success, let element = systemFocusedRef {
            if let text = extractText(from: element as! AXUIElement) {
                return text
            }
        }

        return nil
    }

    private func extractText(from element: AXUIElement) -> String? {
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
    private func getSelectedTextViaSimulatedCopy() async -> String? {
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount

        // Save previous clipboard contents
        let previousString = pasteboard.string(forType: .string)

        // Small delay to ensure physical hotkey modifiers (e.g. Option) are released
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Post Cmd+C
        postCleanCopyShortcut()

        // Poll for clipboard change (max 350ms)
        var didChange = false
        for _ in 0..<18 {
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
            if pasteboard.changeCount != initialChangeCount {
                didChange = true
                break
            }
        }

        guard didChange, let newCopiedText = pasteboard.string(forType: .string), !newCopiedText.isEmpty else {
            return nil
        }

        // Restore user's previous clipboard string
        if let oldText = previousString {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(oldText, forType: .string)
            }
        }

        return newCopiedText
    }

    private func postCleanCopyShortcut() {
        let source = CGEventSource(stateID: .hidSystemState)
        let cKeyCode: CGKeyCode = 8 // 'C'

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: cKeyCode, keyDown: false) else {
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
