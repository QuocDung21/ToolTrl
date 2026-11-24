import Foundation
import Synchronization
import Defaults

/// Service for continuously journaling all lookups and translations to a local `words.jsonl` file.
/// Inherited from Easydict's persistent journal architecture for seamless Obsidian / Logseq integration.
public final class ContinuousJournalService: Sendable {
    public static let shared = ContinuousJournalService()

    private let fileQueue = DispatchQueue(label: "com.nekotrans.continuous-journal", qos: .utility)
    private let writeLock = Mutex(())

    public struct JournalEntry: Codable, Identifiable, Sendable {
        public let id: String
        public let timestamp: String
        public let word: String
        public let phonetic: String?
        public let translation: String
        public let sourceLang: String
        public let targetLang: String
        public let context: String?

        public init(
            id: String = UUID().uuidString,
            timestamp: String,
            word: String,
            phonetic: String? = nil,
            translation: String,
            sourceLang: String,
            targetLang: String,
            context: String? = nil
        ) {
            self.id = id
            self.timestamp = timestamp
            self.word = word
            self.phonetic = phonetic
            self.translation = translation
            self.sourceLang = sourceLang
            self.targetLang = targetLang
            self.context = context
        }
    }

    private init() {}

    /// Resolves the effective file URL for the journal.
    public var journalFileURL: URL {
        let customPath = Defaults[.journalDirectoryPath].trimmingCharacters(in: .whitespacesAndNewlines)
        if !customPath.isEmpty {
            let customURL = URL(fileURLWithPath: (customPath as NSString).expandingTildeInPath)
            if customURL.pathExtension.lowercased() == "jsonl" {
                return customURL
            }
            return customURL.appendingPathComponent("words.jsonl")
        }

        // Default: ~/Documents/NekoTrans/words.jsonl
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let nekoDir = docs.appendingPathComponent("NekoTrans", isDirectory: true)
        return nekoDir.appendingPathComponent("words.jsonl")
    }

    /// Logs an entry to the journal file asynchronously.
    public func logEntry(
        word: String,
        phonetic: String? = nil,
        translation: String,
        sourceLang: String,
        targetLang: String,
        context: String? = nil
    ) {
        guard Defaults[.enableContinuousJournal] else { return }

        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTranslation = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty, !trimmedTranslation.isEmpty else { return }

        let isoTimestamp = Date().ISO8601Format(.iso8601(includingFractionalSeconds: true))
        let entry = JournalEntry(
            timestamp: isoTimestamp,
            word: trimmedWord,
            phonetic: phonetic,
            translation: trimmedTranslation,
            sourceLang: sourceLang,
            targetLang: targetLang,
            context: context
        )

        fileQueue.async { [weak self] in
            guard let self = self else { return }
            self.writeLock.withLock { _ in
                self.writeEntry(entry)
            }
        }
    }

    private func writeEntry(_ entry: JournalEntry) {
        do {
            let fileURL = self.journalFileURL
            let parentDir = fileURL.deletingLastPathComponent()

            if !FileManager.default.fileExists(atPath: parentDir.path) {
                try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.withoutEscapingSlashes]
            let jsonData = try encoder.encode(entry)

            var lineData = jsonData
            lineData.append(contentsOf: [0x0A]) // \n newline

            if FileManager.default.fileExists(atPath: fileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                defer { try? fileHandle.close() }
                try fileHandle.seekToEnd()
                try fileHandle.write(contentsOf: lineData)
            } else {
                try lineData.write(to: fileURL, options: .atomic)
            }

            AppLog.app.debug("Journaled word '\(entry.word, privacy: .private)' to \(fileURL.lastPathComponent)")
        } catch {
            AppLog.app.error("Failed to write continuous journal entry: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Reads recent journal entries from the JSONL file.
    public func readRecentEntries(limit: Int = 100) -> [JournalEntry] {
        let fileURL = self.journalFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }

        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let decoder = JSONDecoder()

            var entries: [JournalEntry] = []
            for line in lines.reversed() { // newest first
                guard let data = line.data(using: .utf8) else { continue }
                if let entry = try? decoder.decode(JournalEntry.self, from: data) {
                    entries.append(entry)
                    if entries.count >= limit {
                        break
                    }
                }
            }
            return entries
        } catch {
            AppLog.app.error("Failed to read journal entries: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}
