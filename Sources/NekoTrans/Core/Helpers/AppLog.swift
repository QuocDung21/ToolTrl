import Foundation
import os

/// Central `os.Logger` instances for the app.
///
/// Replaces the previous `print()` calls, which were invisible in a release build
/// (stdout goes nowhere when an app is launched from Finder). Messages now land in
/// the unified logging system with a subsystem and category, so they can be read
/// with Console.app or:
///
///     log stream --predicate 'subsystem == "com.nekotrans.mac"' --level debug
///
/// Subsystem matches the shipping bundle identifier so every category groups under
/// one filter. User-supplied text (word titles, translated content) must stay
/// `.private`; only errors and identifiers should be marked `.public`.
public enum AppLog {
    private static let subsystem = "com.nekotrans.mac"

    /// App lifecycle, launch checks, window/status item wiring.
    public static let app = Logger(subsystem: subsystem, category: "app")
    /// Settings and preferences persistence.
    public static let settings = Logger(subsystem: subsystem, category: "settings")
    /// Vocabulary notebook storage, migration and Spotlight-indexed content.
    public static let vocabulary = Logger(subsystem: subsystem, category: "vocabulary")
    /// CoreSpotlight indexing.
    public static let spotlight = Logger(subsystem: subsystem, category: "spotlight")
    /// Translation history persistence.
    public static let history = Logger(subsystem: subsystem, category: "history")
    /// Dictionary API calls and lemmatization.
    public static let dictionary = Logger(subsystem: subsystem, category: "dictionary")
    /// Multi-engine translation.
    public static let translation = Logger(subsystem: subsystem, category: "translation")
    /// iPad Continuity / homework studio server.
    public static let continuity = Logger(subsystem: subsystem, category: "continuity")
    /// GitHub gist sync.
    public static let sync = Logger(subsystem: subsystem, category: "sync")
}
