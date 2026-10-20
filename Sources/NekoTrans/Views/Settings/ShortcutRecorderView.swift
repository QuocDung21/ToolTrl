import SwiftUI
import KeyboardShortcuts

/// A native shortcut recorder row powered by `KeyboardShortcuts.Recorder`.
/// Replaces the old `ShortcutRecorderView` that used a custom NSEvent monitor.
public struct ShortcutRecorderView: View {
    let name: KeyboardShortcuts.Name

    public init(name: KeyboardShortcuts.Name) {
        self.name = name
    }

    public var body: some View {
        KeyboardShortcuts.Recorder(for: name)
    }
}
