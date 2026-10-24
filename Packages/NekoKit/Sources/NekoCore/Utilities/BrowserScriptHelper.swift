import Foundation
import AppKit

/// Centralized AppleScript automation helper for macOS web browsers.
/// Inspired by Easydict's `AppleScriptTask+Browser`.
///
/// Enables non-invasive, zero-clipboard-pollution text extraction and insertion
/// across Safari, Chrome, Edge, Arc, Brave, and other Chromium-based browsers.
public enum BrowserScriptHelper {

    // MARK: - Supported Browser Bundle Identifiers

    public static let safariBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview"
    ]

    public static let chromiumBundleIDs: Set<String> = [
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "com.microsoft.edgemac",
        "com.microsoft.edgemac.Canary",
        "com.microsoft.edgemac.Dev",
        "company.thebrowser.Browser", // Arc
        "com.brave.Browser",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "app.zen-browser.zen"
    ]

    public static func isSupportedBrowser(_ bundleID: String) -> Bool {
        safariBundleIDs.contains(bundleID) || chromiumBundleIDs.contains(bundleID)
    }

    public static func isSafari(_ bundleID: String) -> Bool {
        safariBundleIDs.contains(bundleID)
    }

    public static func isChromium(_ bundleID: String) -> Bool {
        chromiumBundleIDs.contains(bundleID)
    }

    // MARK: - Actions

    /// Get selected text from the active browser tab via JavaScript
    public static func getSelectedText(bundleID: String, timeout: TimeInterval = 0.5) async -> String? {
        guard isSupportedBrowser(bundleID) else { return nil }

        let script: String
        if isSafari(bundleID) {
            script = """
            tell application id "\(bundleID)"
                if (count of windows) > 0 then
                    tell front window
                        set selection_text to do JavaScript "window.getSelection().toString();" in current tab
                        return selection_text
                    end tell
                end if
            end tell
            """
        } else {
            script = """
            tell application id "\(bundleID)"
                if (count of windows) > 0 then
                    tell active tab of front window
                        set selection_text to execute javascript "window.getSelection().toString();"
                        return selection_text
                    end tell
                end if
            end tell
            """
        }

        return await runAppleScript(script, timeout: timeout)
    }

    /// Get current active tab URL from the browser
    public static func getCurrentTabURL(bundleID: String, timeout: TimeInterval = 0.5) async -> String? {
        guard isSupportedBrowser(bundleID) else { return nil }

        let script: String
        if isSafari(bundleID) {
            script = """
            tell application id "\(bundleID)"
                if (count of windows) > 0 then
                    return URL of front document
                end if
            end tell
            """
        } else {
            script = """
            tell application id "\(bundleID)"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """
        }

        return await runAppleScript(script, timeout: timeout)
    }

    /// Insert text into the active element in the browser
    public static func insertText(_ text: String, bundleID: String, timeout: TimeInterval = 1.0) async -> Bool {
        guard isSupportedBrowser(bundleID) else { return false }
        let escaped = escapeForJavaScript(text)

        let script: String
        if isSafari(bundleID) {
            script = """
            tell application id "\(bundleID)"
                if (count of windows) > 0 then
                    do JavaScript "document.execCommand('insertText', false, '\(escaped)')" in current tab of front window
                    return "true"
                end if
            end tell
            """
        } else {
            script = """
            tell application id "\(bundleID)"
                if (count of windows) > 0 then
                    tell active tab of front window
                        execute javascript "document.execCommand('insertText', false, '\(escaped)')"
                        return "true"
                    end tell
                end if
            end tell
            """
        }

        let result = await runAppleScript(script, timeout: timeout)
        return result == "true"
    }

    // MARK: - AppleScript Execution & Compiled Cache

    private static let scriptQueue = DispatchQueue(label: "com.nekotrans.applescript.worker", qos: .userInitiated)
    private nonisolated(unsafe) static var compiledScriptCache: [String: NSAppleScript] = [:]

    /// Runs an AppleScript string with a timeout on a background queue using pre-compiled script cache
    public static func runAppleScript(_ source: String, timeout: TimeInterval = 1.0) async -> String? {
        await withCheckedContinuation { continuation in
            var hasResumed = false
            let lock = NSLock()

            let workItem = DispatchWorkItem {
                let appleScript: NSAppleScript?
                if let cached = compiledScriptCache[source] {
                    appleScript = cached
                } else if let newScript = NSAppleScript(source: source) {
                    var compileError: NSDictionary?
                    _ = newScript.compileAndReturnError(&compileError)
                    compiledScriptCache[source] = newScript
                    appleScript = newScript
                } else {
                    appleScript = nil
                }

                guard let script = appleScript else {
                    lock.lock()
                    if !hasResumed {
                        hasResumed = true
                        lock.unlock()
                        continuation.resume(returning: nil)
                    } else {
                        lock.unlock()
                    }
                    return
                }

                var errorInfo: NSDictionary?
                let output = script.executeAndReturnError(&errorInfo)
                let str = (errorInfo == nil) ? output.stringValue : nil

                lock.lock()
                if !hasResumed {
                    hasResumed = true
                    lock.unlock()
                    continuation.resume(returning: str)
                } else {
                    lock.unlock()
                }
            }

            scriptQueue.async(execute: workItem)

            // Timeout watchdog
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                lock.lock()
                if !hasResumed {
                    hasResumed = true
                    lock.unlock()
                    workItem.cancel()
                    continuation.resume(returning: nil)
                } else {
                    lock.unlock()
                }
            }
        }
    }

    private static func escapeForJavaScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
}
