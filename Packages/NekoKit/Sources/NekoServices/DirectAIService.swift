import Foundation
import Defaults

// MARK: - Models for AI Grammar & Polishing
public struct GrammarRewriteResult: Sendable, Codable {
    public let hasErrors: Bool
    public let correction: String
    public let explanationVi: String
    public let academicVersion: String
    public let businessVersion: String
    public let casualVersion: String
    
    public init(
        hasErrors: Bool = false,
        correction: String = "",
        explanationVi: String = "",
        academicVersion: String = "",
        businessVersion: String = "",
        casualVersion: String = ""
    ) {
        self.hasErrors = hasErrors
        self.correction = correction
        self.explanationVi = explanationVi
        self.academicVersion = academicVersion
        self.businessVersion = businessVersion
        self.casualVersion = casualVersion
    }
    
    enum CodingKeys: String, CodingKey {
        case hasErrors = "has_errors"
        case correction
        case explanationVi = "explanation_vi"
        case academicVersion = "academic_version"
        case businessVersion = "business_version"
        case casualVersion = "casual_version"
    }
}

public final class DirectAIService: Sendable {
    public static let shared = DirectAIService()
    
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 15.0
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    private static func secret(_ account: String) -> String {
        KeychainStore.string(for: account)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - 1. Translate via Configured AI Provider
    public func translate(
        text: String,
        from sourceLang: String = "auto",
        to targetLang: String = "vi",
        domain: TranslationDomain = .general,
        provider: DirectAIProvider = Defaults[.aiProvider]
    ) async throws -> String {
        let prompt = AIPromptBuilder.contextualTranslationPrompt(
            text: text,
            sourceLang: sourceLang,
            targetLang: targetLang,
            domain: domain.rawValue
        )
        
        return try await sendPromptToAI(prompt: prompt, provider: provider)
    }
    
    // MARK: - 1b. Translate via Configured AI Provider with Real-Time Token Streaming
    public func translateStreaming(
        text: String,
        from sourceLang: String = "auto",
        to targetLang: String = "vi",
        domain: TranslationDomain = .general,
        provider: DirectAIProvider = Defaults[.aiProvider],
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let prompt = AIPromptBuilder.contextualTranslationPrompt(
            text: text,
            sourceLang: sourceLang,
            targetLang: targetLang,
            domain: domain.rawValue
        )
        
        switch provider {
        case .openAI, .groq, .deepSeek:
            let (endpoint, apiKey, defaultModel) = getOpenAICompatibleConfig(for: provider)
            guard !apiKey.isEmpty else {
                throw NSError(domain: "AI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập API Key cho \(provider.rawValue) trong Cài đặt."])
            }
            let customModel = Defaults[.customAIModel]
            let model = customModel.isEmpty ? defaultModel : customModel
            return try await streamOpenAICompatible(
                endpoint: endpoint,
                apiKey: apiKey,
                model: model,
                prompt: prompt,
                onToken: onToken
            )
        case .ollama:
            let customModel = Defaults[.customAIModel]
            let model = customModel.isEmpty ? DirectAIProvider.ollama.defaultModel : customModel
            let endpoint = Defaults[.ollamaEndpoint]
            return try await LocalAIService.shared.streamLocalInference(
                endpoint: endpoint,
                model: model,
                prompt: prompt,
                onToken: onToken
            )
        case .inProcessGGUF:
            if !LocalGGUFService.shared.isLoaded {
                let path = Defaults[.customGGUFModelPath]
                guard !path.isEmpty && FileManager.default.fileExists(atPath: path) else {
                    throw NSError(domain: "GGUF", code: 404, userInfo: [NSLocalizedDescriptionKey: "Chưa chọn file model GGUF nào hoặc file không tồn tại. Vui lòng vào Cài đặt để chọn file .gguf."])
                }
                try LocalGGUFService.shared.loadModel(at: path)
            }
            return try await LocalGGUFService.shared.streamInference(
                prompt: prompt,
                onToken: onToken
            )
        default:
            // One-shot fallback for other providers
            let result = try await sendPromptToAI(prompt: prompt, provider: provider)
            onToken(result)
            return result
        }
    }
    
    // MARK: - 2. DeepL Translation
    public func translateViaDeepL(
        text: String,
        from sourceLang: String = "auto",
        to targetLang: String = "VI"
    ) async throws -> String {
        let apiKey = Self.secret(KeyStore.Secret.deepL)
        guard !apiKey.isEmpty else {
            throw NSError(domain: "DeepL", code: 401, userInfo: [NSLocalizedDescriptionKey: "Chưa cấu hình DeepL API Key trong Cài đặt."])
        }
        
        let endpoint = apiKey.hasSuffix(":fx")
            ? "https://api-free.deepl.com/v2/translate"
            : "https://api.deepl.com/v2/translate"
        
        guard let url = URL(string: endpoint) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var targetUpper = targetLang.uppercased()
        if targetUpper == "EN" { targetUpper = "EN-US" }
        
        var payload: [String: Any] = [
            "text": [text],
            "target_lang": targetUpper
        ]
        if sourceLang != "auto" && !sourceLang.isEmpty {
            payload["source_lang"] = sourceLang.uppercased()
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            let errorMsg = String(data: data, encoding: String.Encoding.utf8) ?? "HTTP Error"
            throw NSError(domain: "DeepL", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: errorMsg])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let translations = json["translations"] as? [[String: Any]],
           let first = translations.first,
           let translatedText = first["text"] as? String {
            return translatedText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        
        throw NSError(domain: "DeepL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không phân tích được phản hồi từ DeepL."])
    }
    
    // MARK: - 3. Grammar Checking & Polishing
    public func analyzeGrammarAndRephrase(
        text: String,
        targetLang: String = "vi",
        provider: DirectAIProvider = Defaults[.aiProvider]
    ) async throws -> GrammarRewriteResult {
        let prompt = AIPromptBuilder.grammarAndPolishingPrompt(text: text, targetLang: targetLang)
        let rawResponse = try await sendPromptToAI(prompt: prompt, provider: provider)
        
        // Clean markdown backticks if AI wrapped JSON
        var cleaned = rawResponse.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        }
        if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        guard let data = cleaned.data(using: String.Encoding.utf8) else {
            return GrammarRewriteResult(hasErrors: false, correction: text, explanationVi: "Không phân tích được phản hồi.", academicVersion: text, businessVersion: text, casualVersion: text)
        }
        
        do {
            let decoded = try JSONDecoder().decode(GrammarRewriteResult.self, from: data)
            return decoded
        } catch {
            return GrammarRewriteResult(hasErrors: false, correction: text, explanationVi: rawResponse, academicVersion: text, businessVersion: text, casualVersion: text)
        }
    }
    
    // MARK: - 4. Explain Word In Context
    public func explainWordInContext(
        word: String,
        sentence: String,
        targetLang: String = "vi",
        provider: DirectAIProvider = Defaults[.aiProvider]
    ) async throws -> String {
        let prompt = AIPromptBuilder.wordInContextPrompt(word: word, sentence: sentence, targetLang: targetLang)
        return try await sendPromptToAI(prompt: prompt, provider: provider)
    }
    
    // MARK: - 5. Unified Dispatcher to Selected AI Engine
    public func sendPromptToAI(prompt: String, provider: DirectAIProvider = Defaults[.aiProvider]) async throws -> String {
        let customModel = Defaults[.customAIModel]
        switch provider {
        case .openAI:
            let apiKey = Self.secret(KeyStore.Secret.openAI)
            guard !apiKey.isEmpty else {
                throw NSError(domain: "AI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập OpenAI API Key trong Cài đặt."])
            }
            let model = customModel.isEmpty ? provider.defaultModel : customModel
            return try await queryOpenAICompatible(
                endpoint: "https://api.openai.com/v1/chat/completions",
                apiKey: apiKey,
                model: model,
                prompt: prompt
            )
            
        case .groq:
            let apiKey = Self.secret(KeyStore.Secret.groq)
            guard !apiKey.isEmpty else {
                throw NSError(domain: "AI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập Groq API Key trong Cài đặt."])
            }
            let model = customModel.isEmpty ? provider.defaultModel : customModel
            return try await queryOpenAICompatible(
                endpoint: "https://api.groq.com/openai/v1/chat/completions",
                apiKey: apiKey,
                model: model,
                prompt: prompt
            )
            
        case .deepSeek:
            let apiKey = Self.secret(KeyStore.Secret.deepSeek)
            guard !apiKey.isEmpty else {
                throw NSError(domain: "AI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập DeepSeek API Key trong Cài đặt."])
            }
            let model = customModel.isEmpty ? provider.defaultModel : customModel
            return try await queryOpenAICompatible(
                endpoint: "https://api.deepseek.com/v1/chat/completions",
                apiKey: apiKey,
                model: model,
                prompt: prompt
            )
            
        case .anthropic:
            return try await queryAnthropic(prompt: prompt)
            
        case .googleGemini:
            return try await queryGemini(prompt: prompt)
            
        case .ollama:
            return try await queryOllama(prompt: prompt)
            
        case .inProcessGGUF:
            if !LocalGGUFService.shared.isLoaded {
                let path = Defaults[.customGGUFModelPath]
                guard !path.isEmpty && FileManager.default.fileExists(atPath: path) else {
                    throw NSError(domain: "GGUF", code: 404, userInfo: [NSLocalizedDescriptionKey: "Chưa chọn file model GGUF nào hoặc file không tồn tại. Vui lòng vào Cài đặt để chọn file .gguf."])
                }
                try LocalGGUFService.shared.loadModel(at: path)
            }
            return try await LocalGGUFService.shared.streamInference(prompt: prompt, onToken: { _ in })
        }
    }
    
    // MARK: - Provider API Implementations
    
    // OpenAI / Groq / DeepSeek Compatible
    private func queryOpenAICompatible(endpoint: String, apiKey: String, model: String, prompt: String) async throws -> String {
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            let err = String(data: data, encoding: String.Encoding.utf8) ?? "HTTP Error"
            throw NSError(domain: "AI", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: err])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let first = choices.first,
           let message = first["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        
        throw NSError(domain: "AI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không phân tích được phản hồi từ AI."])
    }
    
    // OpenAI-Compatible SSE Streaming Runner
    private func streamOpenAICompatible(
        endpoint: String,
        apiKey: String,
        model: String,
        prompt: String,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
        
        let (bytes, response) = try await urlSession.bytes(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw NSError(domain: "AI", code: status, userInfo: [NSLocalizedDescriptionKey: "Lỗi phản hồi HTTP \(status) từ AI provider."])
        }
        
        var accumulatedText = ""
        
        for try await line in bytes.lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.hasPrefix("data: ") else { continue }
            let payload = String(trimmedLine.dropFirst(6)).trimmingCharacters(in: .whitespacesAndNewlines)
            if payload == "[DONE]" { break }
            
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let delta = first["delta"] as? [String: Any],
                  let content = delta["content"] as? String else {
                continue
            }
            
            accumulatedText += content
            onToken(content)
        }
        
        let cleaned = accumulatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? accumulatedText : cleaned
    }
    
    private func getOpenAICompatibleConfig(for provider: DirectAIProvider) -> (endpoint: String, apiKey: String, defaultModel: String) {
        switch provider {
        case .openAI:
            return (
                "https://api.openai.com/v1/chat/completions",
                Self.secret(KeyStore.Secret.openAI),
                provider.defaultModel
            )
        case .groq:
            return (
                "https://api.groq.com/openai/v1/chat/completions",
                Self.secret(KeyStore.Secret.groq),
                provider.defaultModel
            )
        case .deepSeek:
            return (
                "https://api.deepseek.com/v1/chat/completions",
                Self.secret(KeyStore.Secret.deepSeek),
                provider.defaultModel
            )
        default:
            return ("", "", "")
        }
    }
    
    // Anthropic Claude Messages API
    private func queryAnthropic(prompt: String) async throws -> String {
        let apiKey = Self.secret(KeyStore.Secret.anthropic)
        guard !apiKey.isEmpty else {
            throw NSError(domain: "Anthropic", code: 401, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập Anthropic API Key trong Cài đặt."])
        }
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let customModel = Defaults[.customAIModel]
        let model = customModel.isEmpty ? DirectAIProvider.anthropic.defaultModel : customModel
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            let err = String(data: data, encoding: String.Encoding.utf8) ?? "Anthropic API Error"
            throw NSError(domain: "Anthropic", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: err])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let contentArr = json["content"] as? [[String: Any]],
           let first = contentArr.first,
           let text = first["text"] as? String {
            return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        
        throw NSError(domain: "Anthropic", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không nhận được phản hồi từ Claude."])
    }
    
    // Google Gemini API
    private func queryGemini(prompt: String) async throws -> String {
        let apiKey = Self.secret(KeyStore.Secret.gemini)
        guard !apiKey.isEmpty else {
            throw NSError(domain: "Gemini", code: 401, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập Google Gemini API Key trong Cài đặt."])
        }
        
        let customModel = Defaults[.customAIModel]
        let model = customModel.isEmpty ? DirectAIProvider.googleGemini.defaultModel : customModel
        guard let url = SafeURL.make(
            host: "generativelanguage.googleapis.com",
            path: "/v1beta/models/\(model):generateContent",
            queryItems: [URLQueryItem(name: "key", value: apiKey)]
        ) else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            let err = String(data: data, encoding: String.Encoding.utf8) ?? "Gemini API Error"
            throw NSError(domain: "Gemini", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: err])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let first = candidates.first,
           let content = first["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let firstPart = parts.first,
           let text = firstPart["text"] as? String {
            return text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        
        throw NSError(domain: "Gemini", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không nhận được phản hồi từ Gemini."])
    }
    
    // Ollama / Local AI API
    private func queryOllama(prompt: String) async throws -> String {
        let customModel = Defaults[.customAIModel]
        let model = customModel.isEmpty ? DirectAIProvider.ollama.defaultModel : customModel
        let endpoint = Defaults[.ollamaEndpoint]
        return try await LocalAIService.shared.streamLocalInference(
            endpoint: endpoint,
            model: model,
            prompt: prompt,
            onToken: { _ in }
        )
    }
}
