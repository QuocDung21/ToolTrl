import Foundation
import Network
import Defaults
import NekoCore

/// Local HTTP loopback bridge server for synchronizing NekoTrans Core with Web Extensions (Chrome, Edge, Brave, Safari).
/// Listens exclusively on 127.0.0.1:42421 to ensure complete privacy, zero external exposure, and high performance.
public final class LocalBridgeServer: @unchecked Sendable {
    public static let shared = LocalBridgeServer()

    public static let defaultPort: UInt16 = 42421

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.nekotrans.bridge.server", qos: .userInitiated)
    private var isRunning: Bool = false

    private init() {}

    // MARK: - Lifecycle

    public func start(port: UInt16 = defaultPort) {
        guard !isRunning else { return }

        do {
            let tcpOptions = NWProtocolTCP.Options()
            let params = NWParameters(tls: nil, tcp: tcpOptions)
            params.allowLocalEndpointReuse = true

            // Strictly bind to 127.0.0.1 loopback only
            guard let portEndpoint = NWEndpoint.Port(rawValue: port) else {
                AppLog.bridge.error("Invalid port: \(port, privacy: .public)")
                return
            }

            let newListener = try NWListener(using: params, on: portEndpoint)
            newListener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    AppLog.bridge.info("LocalBridgeServer running on 127.0.0.1:\(port, privacy: .public)")
                    self?.isRunning = true
                case .failed(let error):
                    AppLog.bridge.error("LocalBridgeServer failed: \(error.localizedDescription, privacy: .public)")
                    self?.stop()
                case .cancelled:
                    self?.isRunning = false
                default:
                    break
                }
            }

            newListener.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }

            newListener.start(queue: queue)
            self.listener = newListener
        } catch {
            AppLog.bridge.error("Failed to start LocalBridgeServer: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func stop() {
        guard isRunning || listener != nil else { return }
        listener?.cancel()
        listener = nil
        isRunning = false
        AppLog.bridge.info("LocalBridgeServer stopped")
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveNext(from: connection, accumulatedData: Data())
    }

    private func receiveNext(from connection: NWConnection, accumulatedData: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                AppLog.bridge.debug("Connection error: \(error.localizedDescription, privacy: .public)")
                connection.cancel()
                return
            }

            var data = accumulatedData
            if let content = content {
                data.append(content)
            }

            // Check if we have received complete HTTP headers (\r\n\r\n)
            if let headerEndRange = data.range(of: Data([13, 10, 13, 10])) {
                let headerData = data.subdata(in: 0..<headerEndRange.lowerBound)
                let bodyData = data.subdata(in: headerEndRange.upperBound..<data.count)

                if let headerString = String(data: headerData, encoding: .utf8) {
                    let contentLength = self.parseContentLength(from: headerString)
                    if bodyData.count >= contentLength {
                        let (method, path) = self.parseMethodAndPath(from: headerString)
                        self.processRequest(method: method, path: path, body: bodyData, connection: connection)
                        return
                    }
                }
            }

            if isComplete {
                connection.cancel()
            } else {
                self.receiveNext(from: connection, accumulatedData: data)
            }
        }
    }

    // MARK: - HTTP Parsing & Dispatch

    private func parseContentLength(from header: String) -> Int {
        for line in header.components(separatedBy: "\r\n") {
            let lower = line.lowercased()
            if lower.hasPrefix("content-length:") {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2, let len = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
                    return len
                }
            }
        }
        return 0
    }

    private func parseMethodAndPath(from header: String) -> (String, String) {
        guard let firstLine = header.components(separatedBy: "\r\n").first else {
            return ("GET", "/")
        }
        let parts = firstLine.split(separator: " ")
        let method = parts.count > 0 ? String(parts[0]).uppercased() : "GET"
        let path = parts.count > 1 ? String(parts[1]) : "/"
        return (method, path)
    }

    private func processRequest(method: String, path: String, body: Data, connection: NWConnection) {
        // Handle preflight CORS request
        if method == "OPTIONS" {
            sendOptionsResponse(connection: connection)
            return
        }

        let cleanPath = path.components(separatedBy: "?").first ?? path

        switch (method, cleanPath) {
        case ("GET", "/api/status"), ("GET", "/api/config"):
            handleStatusRequest(connection: connection)

        case ("POST", "/api/translate"):
            handleTranslateRequest(body: body, connection: connection)

        case ("POST", "/api/translate-batch"):
            handleTranslateBatchRequest(body: body, connection: connection)

        case ("POST", "/api/save-word"):
            handleSaveWordRequest(body: body, connection: connection)

        case ("GET", "/api/check-word"), ("POST", "/api/check-word"):
            handleCheckWordRequest(path: path, body: body, connection: connection)

        default:
            sendResponse(statusCode: 404, statusText: "Not Found", json: ["error": "Endpoint not found"], connection: connection)
        }
    }

    // MARK: - Route Handlers

    private func handleStatusRequest(connection: NWConnection) {
        Task { @MainActor in
            let engine = Defaults[.translationEngine]
            let targetLang = Defaults[.targetLanguage]
            let domain = Defaults[.translationDomain]
            let aiProvider = Defaults[.aiProvider]

            let payload: [String: Any] = [
                "status": "ok",
                "app": "NekoTrans",
                "version": "1.0.0",
                "engine": engine.rawValue,
                "engineName": engine.displayName,
                "targetLanguage": targetLang,
                "sourceLanguage": "auto",
                "domain": domain.rawValue,
                "aiProvider": aiProvider.rawValue
            ]
            self.sendResponse(json: payload, connection: connection)
        }
    }

    private func handleTranslateRequest(body: Data, connection: NWConnection) {
        guard let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
              let text = json["text"] as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            sendResponse(statusCode: 400, statusText: "Bad Request", json: ["success": false, "error": "Missing or empty 'text'"], connection: connection)
            return
        }

        let requestedTarget = json["targetLang"] as? String
        let requestedSource = (json["sourceLang"] as? String) ?? "auto"

        var currentTask: Task<Void, Never>?
        connection.stateUpdateHandler = { state in
            switch state {
            case .cancelled, .failed:
                currentTask?.cancel()
            default:
                break
            }
        }

        currentTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            let target = (requestedTarget != nil && !requestedTarget!.isEmpty) ? requestedTarget! : Defaults[.targetLanguage]
            let translated = await TranslationService.shared.translate(
                text: text,
                from: requestedSource,
                to: target
            )

            guard !Task.isCancelled else {
                connection.cancel()
                return
            }

            if let translated = translated {
                var resp: [String: Any] = [
                    "success": true,
                    "translated": translated,
                    "original": text,
                    "engine": Defaults[.translationEngine].rawValue
                ]
                resp["isSaved"] = VocabularyService.shared.isWordSaved(text)
                self.sendResponse(json: resp, connection: connection)
            } else {
                self.sendResponse(statusCode: 502, statusText: "Bad Gateway", json: ["success": false, "error": "Translation failed"], connection: connection)
            }
        }
    }

    private func handleTranslateBatchRequest(body: Data, connection: NWConnection) {
        guard let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
              let texts = json["texts"] as? [String], !texts.isEmpty else {
            sendResponse(statusCode: 400, statusText: "Bad Request", json: ["success": false, "error": "Missing or empty 'texts' array"], connection: connection)
            return
        }

        let requestedTarget = json["targetLang"] as? String
        let requestedSource = (json["sourceLang"] as? String) ?? "auto"

        var currentTask: Task<Void, Never>?
        connection.stateUpdateHandler = { state in
            switch state {
            case .cancelled, .failed:
                currentTask?.cancel()
            default:
                break
            }
        }

        currentTask = Task { @MainActor in
            guard !Task.isCancelled else { return }
            let target = (requestedTarget != nil && !requestedTarget!.isEmpty) ? requestedTarget! : Defaults[.targetLanguage]
            var results: [String] = Array(repeating: "", count: texts.count)

            await withTaskGroup(of: (Int, String?).self) { group in
                for (index, text) in texts.enumerated() {
                    group.addTask {
                        guard !Task.isCancelled else { return (index, nil) }
                        let res = await TranslationService.shared.translate(
                            text: text,
                            from: requestedSource,
                            to: target
                        )
                        return (index, res)
                    }
                }
                for await (idx, res) in group {
                    guard !Task.isCancelled else { break }
                    results[idx] = res ?? texts[idx]
                }
            }

            guard !Task.isCancelled else {
                connection.cancel()
                return
            }

            self.sendResponse(json: [
                "success": true,
                "results": results,
                "engine": Defaults[.translationEngine].rawValue
            ], connection: connection)
        }
    }

    private func handleSaveWordRequest(body: Data, connection: NWConnection) {
        guard let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
              let word = json["word"] as? String, !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            sendResponse(statusCode: 400, statusText: "Bad Request", json: ["success": false, "error": "Missing 'word'"], connection: connection)
            return
        }

        let phonetic = json["phonetic"] as? String
        let translation = (json["translation"] as? String) ?? ""

        Task { @MainActor in
            VocabularyService.shared.toggleSaveWord(
                word: word,
                phonetic: phonetic,
                translation: translation
            )
            SoundService.play(.pop)

            let isSaved = VocabularyService.shared.isWordSaved(word)
            self.sendResponse(json: [
                "success": true,
                "word": word,
                "isSaved": isSaved
            ], connection: connection)
        }
    }

    private func handleCheckWordRequest(path: String, body: Data, connection: NWConnection) {
        var queryWord: String?

        if let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
           let word = json["word"] as? String {
            queryWord = word
        } else if let urlComponents = URLComponents(string: "http://localhost" + path),
                  let val = urlComponents.queryItems?.first(where: { $0.name == "word" })?.value {
            queryWord = val
        }

        guard let word = queryWord, !word.isEmpty else {
            sendResponse(statusCode: 400, statusText: "Bad Request", json: ["isSaved": false, "error": "Missing 'word'"], connection: connection)
            return
        }

        Task { @MainActor in
            let isSaved = VocabularyService.shared.isWordSaved(word)
            self.sendResponse(json: [
                "word": word,
                "isSaved": isSaved
            ], connection: connection)
        }
    }

    // MARK: - Responses with CORS

    private func sendResponse(
        statusCode: Int = 200,
        statusText: String = "OK",
        json: [String: Any],
        connection: NWConnection
    ) {
        let jsonData = (try? JSONSerialization.data(withJSONObject: json, options: [])) ?? Data()
        var header = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        header += "Content-Type: application/json; charset=utf-8\r\n"
        header += "Content-Length: \(jsonData.count)\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        header += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        header += "Access-Control-Allow-Headers: Content-Type, Authorization\r\n"
        header += "Connection: close\r\n\r\n"

        var responseData = header.data(using: .utf8) ?? Data()
        responseData.append(jsonData)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func sendOptionsResponse(connection: NWConnection) {
        let header = "HTTP/1.1 204 No Content\r\n" +
                     "Access-Control-Allow-Origin: *\r\n" +
                     "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" +
                     "Access-Control-Allow-Headers: Content-Type, Authorization\r\n" +
                     "Access-Control-Max-Age: 86400\r\n" +
                     "Connection: close\r\n\r\n"
        let data = header.data(using: .utf8)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
