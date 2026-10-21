import Foundation
import Defaults
import NekoCore

/// Metadata for a locally installed AI model on Apple Silicon (Ollama, LM Studio, MLX, llama.cpp).
public struct LocalAIModelInfo: Identifiable, Hashable, Sendable, Codable {
    public let id: String
    public let name: String
    public let sizeInBytes: Int64?
    public let parameterSize: String?
    public let family: String?
    public let quantization: String?

    public init(
        id: String,
        name: String,
        sizeInBytes: Int64? = nil,
        parameterSize: String? = nil,
        family: String? = nil,
        quantization: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sizeInBytes = sizeInBytes
        self.parameterSize = parameterSize
        self.family = family
        self.quantization = quantization
    }

    /// Formatted display name showing model tag, parameter size and quantization.
    public var displayName: String {
        var details: [String] = []
        if let p = parameterSize, !p.isEmpty { details.append(p) }
        if let q = quantization, !q.isEmpty { details.append(q) }
        if let s = formattedSize, !s.isEmpty { details.append(s) }
        if details.isEmpty {
            return name
        }
        return "\(name) (\(details.joined(separator: " • ")))"
    }

    /// Human-readable file or memory size (e.g. "2.0 GB").
    public var formattedSize: String? {
        guard let size = sizeInBytes, size > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

/// The type of local LLM backend server running on macOS.
public enum LocalAIBackendType: String, CaseIterable, Identifiable, Sendable {
    case ollama = "Ollama"
    case lmStudio = "LM Studio"
    case mlxOrLocalAI = "MLX / llama.cpp / LocalAI"
    case custom = "Tùy chỉnh"

    public var id: String { rawValue }

    public var defaultEndpoint: String {
        switch self {
        case .ollama: return "http://localhost:11434"
        case .lmStudio: return "http://localhost:1234"
        case .mlxOrLocalAI: return "http://localhost:8080"
        case .custom: return "http://localhost:11434"
        }
    }

    public var shortDescription: String {
        switch self {
        case .ollama: return "Ollama Server (11434)"
        case .lmStudio: return "LM Studio OpenAI Server (1234)"
        case .mlxOrLocalAI: return "MLX / llama.cpp Server (8080)"
        case .custom: return "Endpoint Tùy chọn"
        }
    }
}

/// The live connection and discovery state of the local AI server.
public enum LocalAIServerState: Equatable, Sendable {
    case idle
    case checking
    case online(backend: LocalAIBackendType, models: [LocalAIModelInfo])
    case offline(reason: String)
}

/// Service dedicated to discovering, health-checking, and communicating with
/// local LLM backends running on macOS (Apple Silicon Neural Engine / Metal).
public final class LocalAIService: Sendable {
    public static let shared = LocalAIService()

    private let probeSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.5
        config.timeoutIntervalForResource = 3.5
        return URLSession(configuration: config)
    }()

    private let streamingSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        return URLSession(configuration: config)
    }()

    private init() {}

    /// Hardware brand string of the host machine (e.g. "Apple M1 Pro", "Apple M3 Max").
    public var appleSiliconChipName: String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        guard size > 0 else { return "Apple Silicon" }
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &machine, &size, nil, 0)
        let brand = String(cString: machine).trimmingCharacters(in: .whitespacesAndNewlines)
        return brand.isEmpty ? "Apple Silicon" : brand
    }

    /// Normalizes user-typed or default endpoint URL into a valid base URL without trailing slash.
    public func normalizeEndpoint(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { trimmed = "http://localhost:11434" }
        if !trimmed.hasPrefix("http://") && !trimmed.hasPrefix("https://") {
            trimmed = "http://" + trimmed
        }
        while trimmed.hasSuffix("/") {
            trimmed = String(trimmed.dropLast())
        }
        return trimmed
    }

    /// Scans the local user directory `~/.cache/huggingface/hub/` to discover already downloaded Hugging Face models.
    public func scanHuggingFaceLocalCache() -> [LocalAIModelInfo] {
        let fileManager = FileManager.default
        let homeURL = fileManager.homeDirectoryForCurrentUser
        let hfHubURL = homeURL.appendingPathComponent(".cache/huggingface/hub")

        guard let contents = try? fileManager.contentsOfDirectory(at: hfHubURL, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }

        var models: [LocalAIModelInfo] = []

        for url in contents where url.lastPathComponent.hasPrefix("models--") {
            let rawName = String(url.lastPathComponent.dropFirst("models--".count))
            let modelID = rawName.replacingOccurrences(of: "--", with: "/")

            let snapshotsURL = url.appendingPathComponent("snapshots")
            var totalSize: Int64?
            var archName: String?

            if let snapshots = try? fileManager.contentsOfDirectory(at: snapshotsURL, includingPropertiesForKeys: nil),
               let firstSnapshot = snapshots.first {
                let configURL = firstSnapshot.appendingPathComponent("config.json")
                if let configData = try? Data(contentsOf: configURL),
                   let json = try? JSONSerialization.jsonObject(with: configData) as? [String: Any] {
                    if let archs = json["architectures"] as? [String], let firstArch = archs.first {
                        archName = firstArch
                    }
                }

                if let enumerator = fileManager.enumerator(at: firstSnapshot, includingPropertiesForKeys: [.fileSizeKey]) {
                    var sizeSum: Int64 = 0
                    for case let fileURL as URL in enumerator {
                        if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                           let s = attrs[.size] as? Int64 {
                            sizeSum += s
                        }
                    }
                    if sizeSum > 0 { totalSize = sizeSum }
                }
            }

            models.append(LocalAIModelInfo(
                id: modelID,
                name: modelID,
                sizeInBytes: totalSize,
                parameterSize: archName,
                family: "Hugging Face Cache",
                quantization: "safetensors"
            ))
        }

        return models.sorted { ($0.sizeInBytes ?? 0) > ($1.sizeInBytes ?? 0) }
    }

    /// Checks the health of a local AI endpoint and discovers its available models.
    public func checkHealth(endpoint: String) async -> LocalAIServerState {
        let base = normalizeEndpoint(endpoint)
        AppLog.ai.debug("Probing local AI endpoint at \(base, privacy: .public)")

        do {
            let (backend, models) = try await fetchAvailableModels(endpoint: base)
            return .online(backend: backend, models: models)
        } catch {
            let reason = error.localizedDescription
            AppLog.ai.debug("Local AI probe failed for \(base, privacy: .public): \(reason, privacy: .public)")
            return .offline(reason: reason)
        }
    }

    /// Automatically scans standard Apple Silicon local LLM ports (11434, 1234, 8080)
    /// to detect any currently running local AI server.
    public func autoDetectLocalServer() async -> (endpoint: String, backend: LocalAIBackendType, models: [LocalAIModelInfo])? {
        let candidateEndpoints: [(String, LocalAIBackendType)] = [
            ("http://localhost:11434", .ollama),
            ("http://localhost:1234", .lmStudio),
            ("http://localhost:8080", .mlxOrLocalAI),
            ("http://127.0.0.1:11434", .ollama),
            ("http://127.0.0.1:1234", .lmStudio),
            ("http://127.0.0.1:8080", .mlxOrLocalAI)
        ]

        for (endpoint, candidateBackend) in candidateEndpoints {
            do {
                let (detectedBackend, models) = try await fetchAvailableModels(endpoint: endpoint)
                let backend = (detectedBackend == .custom) ? candidateBackend : detectedBackend
                AppLog.ai.info("Auto-detected local AI server at \(endpoint, privacy: .public) with \(models.count, privacy: .public) models")
                return (endpoint, backend, models)
            } catch {
                continue
            }
        }

        return nil
    }

    /// Queries the endpoint to detect whether it is Ollama (/api/tags) or OpenAI-compatible (/v1/models)
    /// and parses the available local models.
    public func fetchAvailableModels(endpoint: String) async throws -> (backend: LocalAIBackendType, models: [LocalAIModelInfo]) {
        let base = normalizeEndpoint(endpoint)

        // 1. Try Ollama Native API (/api/tags)
        if let ollamaResult = try? await fetchOllamaTags(base: base) {
            return (.ollama, ollamaResult)
        }

        // 2. Try OpenAI-compatible API (/v1/models) - used by LM Studio, MLX Local Server, LocalAI, and Ollama v1
        if let openAIResult = try? await fetchOpenAIModels(base: base) {
            let backend: LocalAIBackendType = base.contains(":1234") ? .lmStudio : (base.contains(":8080") ? .mlxOrLocalAI : .custom)
            return (backend, openAIResult)
        }

        throw NSError(
            domain: "LocalAI",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: "Không phát hiện máy chủ Local AI phản hồi tại \(base). Hãy đảm bảo Ollama, LM Studio hoặc MLX đã khởi chạy."]
        )
    }

    // MARK: - Private Fetch Helpers

    private func fetchOllamaTags(base: String) async throws -> [LocalAIModelInfo] {
        guard var components = URLComponents(string: base) else { throw URLError(.badURL) }
        components.path = (components.path.isEmpty ? "" : components.path) + "/api/tags"
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await probeSession.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            throw URLError(.cannotConnectToHost)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["models"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        var results: [LocalAIModelInfo] = []
        for item in modelsArray {
            guard let name = item["name"] as? String else { continue }
            let size = item["size"] as? Int64
            var paramSize: String?
            var family: String?
            var quant: String?

            if let details = item["details"] as? [String: Any] {
                paramSize = details["parameter_size"] as? String
                family = details["family"] as? String
                quant = details["quantization_level"] as? String
            }

            results.append(LocalAIModelInfo(
                id: name,
                name: name,
                sizeInBytes: size,
                parameterSize: paramSize,
                family: family,
                quantization: quant
            ))
        }

        return results
    }

    private func fetchOpenAIModels(base: String) async throws -> [LocalAIModelInfo] {
        guard var components = URLComponents(string: base) else { throw URLError(.badURL) }
        let currentPath = components.path
        if currentPath.hasSuffix("/v1") {
            components.path = currentPath + "/models"
        } else {
            components.path = currentPath + "/v1/models"
        }
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await probeSession.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            throw URLError(.cannotConnectToHost)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        var results: [LocalAIModelInfo] = []
        for item in dataArray {
            guard let id = item["id"] as? String else { continue }
            results.append(LocalAIModelInfo(
                id: id,
                name: id,
                sizeInBytes: nil,
                parameterSize: nil,
                family: nil,
                quantization: nil
            ))
        }

        return results
    }

    // MARK: - Streaming & Query Inference Execution

    /// Streams token-by-token generation from a local LLM server using SSE (OpenAI-compatible)
    /// or falling back to Ollama native ndjson format.
    public func streamLocalInference(
        endpoint: String,
        model: String,
        prompt: String,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let base = normalizeEndpoint(endpoint)

        // Try standard OpenAI-compatible SSE streaming first (/v1/chat/completions)
        do {
            return try await streamOpenAICompatibleChat(base: base, model: model, prompt: prompt, onToken: onToken)
        } catch {
            AppLog.ai.debug("SSE /v1/chat/completions failed, attempting Ollama /api/generate fallback: \(error.localizedDescription, privacy: .public)")
            return try await streamOllamaNativeGenerate(base: base, model: model, prompt: prompt, onToken: onToken)
        }
    }

    private func streamOpenAICompatibleChat(
        base: String,
        model: String,
        prompt: String,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        guard var components = URLComponents(string: base) else { throw URLError(.badURL) }
        let currentPath = components.path
        if currentPath.hasSuffix("/v1") {
            components.path = currentPath + "/chat/completions"
        } else {
            components.path = currentPath + "/v1/chat/completions"
        }
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer local", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3,
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await streamingSession.bytes(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "LocalAI", code: status, userInfo: [NSLocalizedDescriptionKey: "HTTP \(status) từ Local AI endpoint."])
        }

        var accumulated = ""
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data: ") else { continue }
            let payload = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            if payload == "[DONE]" { break }

            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let delta = first["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }

            accumulated += content
            onToken(content)
        }

        let cleaned = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? accumulated : cleaned
    }

    private func streamOllamaNativeGenerate(
        base: String,
        model: String,
        prompt: String,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        guard var components = URLComponents(string: base) else { throw URLError(.badURL) }
        components.path = components.path + "/api/generate"
        guard let url = components.url else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await streamingSession.bytes(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "Ollama", code: status, userInfo: [NSLocalizedDescriptionKey: "HTTP \(status) từ Ollama /api/generate."])
        }

        var accumulated = ""
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["response"] as? String else {
                continue
            }

            accumulated += token
            onToken(token)

            if let done = json["done"] as? Bool, done {
                break
            }
        }

        let cleaned = accumulated.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? accumulated : cleaned
    }
}
