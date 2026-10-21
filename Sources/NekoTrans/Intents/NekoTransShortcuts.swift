import AppIntents

/// Zero-configuration App Shortcuts surfaced in Spotlight, Siri and the Shortcuts app.
///
/// Phrases are a published contract: once shipped, add new ones rather than renaming or
/// removing existing ones. Every phrase must contain `\(.applicationName)` or the system
/// index drops it. Apple caps an app at 10 App Shortcuts.
struct NekoTransShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateTextIntent(),
            phrases: [
                "Dịch với \(.applicationName)",
                "Translate with \(.applicationName)"
            ],
            shortTitle: "Dịch văn bản",
            systemImageName: "character.bubble"
        )
        AppShortcut(
            intent: SaveWordIntent(),
            phrases: [
                "Lưu từ vào \(.applicationName)",
                "Save a word to \(.applicationName)"
            ],
            shortTitle: "Lưu từ",
            systemImageName: "bookmark"
        )
        AppShortcut(
            intent: ReviewRandomWordIntent(),
            phrases: [
                "Ôn từ vựng với \(.applicationName)",
                "Review a word with \(.applicationName)"
            ],
            shortTitle: "Ôn từ ngẫu nhiên",
            systemImageName: "rectangle.on.rectangle.angled"
        )
        AppShortcut(
            intent: OpenNotebookIntent(),
            phrases: [
                "Mở sổ tay \(.applicationName)",
                "Open \(.applicationName) notebook"
            ],
            shortTitle: "Mở sổ tay",
            systemImageName: "books.vertical"
        )
        AppShortcut(
            intent: AskQuickAIIntent(),
            phrases: [
                "Hỏi AI với \(.applicationName)",
                "Ask AI with \(.applicationName)"
            ],
            shortTitle: "Hỏi AI",
            systemImageName: "sparkles"
        )
    }
}
