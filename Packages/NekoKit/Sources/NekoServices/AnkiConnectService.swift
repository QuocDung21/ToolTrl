import Foundation
import Defaults

/// Service for communicating with a local AnkiConnect server (usually http://127.0.0.1:8765)
/// Inherited from Easydict's `AnkiConnectClient` architecture.
@MainActor
public final class AnkiConnectService: ObservableObject {
    public static let shared = AnkiConnectService()

    @Published public var isConnected: Bool = false
    @Published public var isSyncing: Bool = false
    @Published public var lastSyncMessage: String = ""
    @Published public var availableDecks: [String] = []
    @Published public var availableModels: [String] = []

    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2.5
        config.timeoutIntervalForResource = 4.0
        return URLSession(configuration: config)
    }()

    private init() {}

    // MARK: - Generic AnkiConnect Request

    private func sendRequest<T>(
        action: String,
        params: [String: Any] = [:]
    ) async throws -> T {
        guard let url = URL(string: Defaults[.ankiConnectEndpoint]) else {
            throw AnkiError.invalidEndpoint
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "action": action,
            "version": 6,
            "params": params
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AnkiError.serverUnavailable
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AnkiError.invalidResponse
        }

        if let error = json["error"], !(error is NSNull) {
            throw AnkiError.ankiError("\(error)")
        }

        guard let result = json["result"] as? T else {
            throw AnkiError.invalidResponse
        }

        return result
    }

    // MARK: - Connection & Discovery

    /// Checks if Anki with AnkiConnect plugin is running locally
    @discardableResult
    public func checkConnection() async -> (connected: Bool, version: Int, message: String) {
        do {
            let version: Int = try await sendRequest(action: "version")
            self.isConnected = true
            self.lastSyncMessage = "Đã kết nối AnkiConnect v\(version)"
            
            // Pre-load decks & models
            _ = try? await fetchDecks()
            _ = try? await fetchModels()
            
            return (true, version, "Kết nối Anki thành công (v\(version))")
        } catch {
            self.isConnected = false
            self.lastSyncMessage = "Không kết nối được: Anki chưa mở hoặc chưa cài AnkiConnect"
            return (false, 0, "Không thể kết nối với Anki (hãy chắc chắn Anki Desktop đang mở và plugin AnkiConnect đã được cài đặt)")
        }
    }

    /// Fetches all deck names from Anki
    public func fetchDecks() async throws -> [String] {
        let decks: [String] = try await sendRequest(action: "deckNames")
        self.availableDecks = decks.sorted()
        return self.availableDecks
    }

    /// Fetches all model (note type) names from Anki
    public func fetchModels() async throws -> [String] {
        let models: [String] = try await sendRequest(action: "modelNames")
        self.availableModels = models.sorted()
        return self.availableModels
    }

    // MARK: - Card Creation

    /// Adds a vocabulary note directly to Anki Desktop without intermediate files
    @discardableResult
    public func addWord(
        word: String,
        phonetic: String? = nil,
        translation: String,
        definitions: String? = nil,
        example: String? = nil,
        deckName: String = Defaults[.ankiConnectDeck],
        modelName: String = Defaults[.ankiConnectModel],
        tags: [String] = ["NekoTrans"]
    ) async throws -> Int64 {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanWord.isEmpty else {
            throw AnkiError.emptyWord
        }

        self.isSyncing = true
        defer { self.isSyncing = false }

        // Build HTML formatted back text
        var backHTML = "<div><b>\(translation)</b></div>"
        if let ph = phonetic, !ph.isEmpty {
            backHTML += "<div style='color: #6366f1; font-size: 0.9em; margin-top: 3px;'>\(ph)</div>"
        }
        if let defs = definitions, !defs.isEmpty {
            backHTML += "<div style='margin-top: 6px; font-size: 0.88em; color: #555;'>\(defs.replacingOccurrences(of: "\n", with: "<br>"))</div>"
        }
        if let ex = example, !ex.isEmpty {
            backHTML += "<div style='margin-top: 6px; font-style: italic; font-size: 0.85em; color: #666;'>\(ex.replacingOccurrences(of: "\n", with: "<br>"))</div>"
        }

        // Standard Front/Back mapping for Basic note type, plus custom fields if available
        let fields: [String: String] = [
            "Front": cleanWord,
            "Back": backHTML,
            "Word": cleanWord,
            "Phonetic": phonetic ?? "",
            "Translation": translation,
            "Definition": definitions ?? "",
            "Example": example ?? ""
        ]

        let noteParams: [String: Any] = [
            "note": [
                "deckName": deckName.isEmpty ? "Default" : deckName,
                "modelName": modelName.isEmpty ? "Basic" : modelName,
                "fields": fields,
                "options": [
                    "allowDuplicate": false,
                    "duplicateScope": "deck"
                ],
                "tags": tags
            ]
        ]

        do {
            let noteID: Int64 = try await sendRequest(action: "addNote", params: noteParams)
            self.lastSyncMessage = "Đã lưu vào Anki [ID: \(noteID)]"
            AppLog.app.info("Successfully pushed word '\(cleanWord, privacy: .private)' to Anki with ID: \(noteID)")
            return noteID
        } catch {
            AppLog.app.error("Anki addNote failed: \(error.localizedDescription, privacy: .public)")
            self.lastSyncMessage = "Lỗi Anki: \(error.localizedDescription)"
            throw error
        }
    }
}

// MARK: - Anki Errors
public enum AnkiError: LocalizedError {
    case invalidEndpoint
    case serverUnavailable
    case invalidResponse
    case emptyWord
    case ankiError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Địa chỉ AnkiConnect không hợp lệ"
        case .serverUnavailable:
            return "Không thể kết nối đến AnkiConnect (hãy đảm bảo Anki đang mở)"
        case .invalidResponse:
            return "Dữ liệu trả về từ AnkiConnect không hợp lệ"
        case .emptyWord:
            return "Từ vựng không được để trống"
        case .ankiError(let msg):
            return "Lỗi Anki: \(msg)"
        }
    }
}
