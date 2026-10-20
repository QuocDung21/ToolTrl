import Foundation
import AppKit
import KeyboardShortcuts

public extension Notification.Name {
    static let hotKeysDidChange = Notification.Name("NekoTransHotKeysDidChangeNotification")
}

// MARK: - Shortcut Name Declarations

public extension KeyboardShortcuts.Name {
    static let translate = Self(
        "nekotrans_translate",
        initial: .init(.d, modifiers: .option)
    )
    static let ai = Self(
        "nekotrans_ai",
        initial: .init(.a, modifiers: .option)
    )
    static let notebook = Self(
        "nekotrans_notebook",
        initial: .init(.v, modifiers: .option)
    )
    static let ocr = Self(
        "nekotrans_ocr",
        initial: .init(.s, modifiers: .option)
    )
    static let silentOCR = Self(
        "nekotrans_silent_ocr",
        initial: .init(.s, modifiers: [.option, .shift])
    )
    static let translateAndReplace = Self(
        "nekotrans_translate_and_replace",
        initial: .init(.t, modifiers: [.option, .shift])
    )
    static let polishAndReplace = Self(
        "nekotrans_polish_and_replace",
        initial: .init(.p, modifiers: [.option, .shift])
    )
}

// MARK: - HotKeyManager

/// Thin wrapper around `KeyboardShortcuts` that registers global
/// shortcuts and routes them to action callbacks set by `AppDelegate`.
@MainActor
public final class HotKeyManager: ObservableObject {
    public static let shared = HotKeyManager()

    // MARK: - Computed display strings (forwarded from KeyboardShortcuts)

    public var translateDisplayString: String {
        KeyboardShortcuts.Name.translate.shortcut?.description ?? "⌥D"
    }
    public var aiDisplayString: String {
        KeyboardShortcuts.Name.ai.shortcut?.description ?? "⌥A"
    }
    public var notebookDisplayString: String {
        KeyboardShortcuts.Name.notebook.shortcut?.description ?? "⌥V"
    }
    public var ocrDisplayString: String {
        KeyboardShortcuts.Name.ocr.shortcut?.description ?? "⌥S"
    }
    public var silentOCRDisplayString: String {
        KeyboardShortcuts.Name.silentOCR.shortcut?.description ?? "⌥⇧S"
    }
    public var translateAndReplaceDisplayString: String {
        KeyboardShortcuts.Name.translateAndReplace.shortcut?.description ?? "⌥⇧T"
    }
    public var polishAndReplaceDisplayString: String {
        KeyboardShortcuts.Name.polishAndReplace.shortcut?.description ?? "⌥⇧P"
    }

    // MARK: - Init

    private init() {}

    // MARK: - Registration

    /// Call once from `AppDelegate.applicationDidFinishLaunching` to wire up
    /// the action handlers.
    public func registerHotKeys(
        onTranslate: @escaping () -> Void,
        onAI: @escaping () -> Void,
        onNotebook: @escaping () -> Void,
        onOCR: @escaping () -> Void,
        onSilentOCR: (() -> Void)? = nil,
        onTranslateAndReplace: (() -> Void)? = nil,
        onPolishAndReplace: (() -> Void)? = nil
    ) {
        KeyboardShortcuts.onKeyDown(for: .translate) { onTranslate() }
        KeyboardShortcuts.onKeyDown(for: .ai)        { onAI() }
        KeyboardShortcuts.onKeyDown(for: .notebook)  { onNotebook() }
        KeyboardShortcuts.onKeyDown(for: .ocr)       { onOCR() }
        if let onSilentOCR {
            KeyboardShortcuts.onKeyDown(for: .silentOCR) { onSilentOCR() }
        }
        if let onTranslateAndReplace {
            KeyboardShortcuts.onKeyDown(for: .translateAndReplace) { onTranslateAndReplace() }
        }
        if let onPolishAndReplace {
            KeyboardShortcuts.onKeyDown(for: .polishAndReplace) { onPolishAndReplace() }
        }
    }

    // MARK: - Reset

    public func resetDefaults() {
        KeyboardShortcuts.reset(.translate, .ai, .notebook, .ocr, .silentOCR, .translateAndReplace, .polishAndReplace)
        NotificationCenter.default.post(name: .hotKeysDidChange, object: nil)
    }
}
