import Foundation

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
    
    // MARK: - 1. Translate via Configured AI Provider
    public func translate(
        text: String,
        from sourceLang: String = "auto",
        to targetLang: String = "vi",
        domain: TranslationDomain = .general,
        tone: TranslationTone = .standard,
        provider: DirectAIProvider = AppSettings.shared.aiProvider
    ) async throws -> String {
        let prompt = AIPromptBuilder.contextualTranslationPrompt(
            text: text,
            sourceLang: sourceLang,
            targetLang: targetLang,
            domain: domain.rawValue,
            tone: tone.rawValue
        )
        
        return try await sendPromptToAI(prompt: prompt, provider: provider)
    }
    
    // MARK: - 1b. Translate via Configured AI Provider with Real-Time Token Streaming
    public func translateStreaming(
        text: String,
        from sourceLang: String = "auto",
        to targetLang: String = "vi",
        domain: TranslationDomain = .general,
        tone: TranslationTone = .standard,
        provider: DirectAIProvider = AppSettings.shared.aiProvider,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let prompt = AIPromptBuilder.contextualTranslationPrompt(
            text: text,
            sourceLang: sourceLang,
            targetLang: targetLang,
            domain: domain.rawValue,
            tone: tone.rawValue
        )
        
        switch provider {
        case .openAI, .groq, .deepSeek:
            let (endpoint, apiKey, defaultModel) = getOpenAICompatibleConfig(for: provider)
            guard !apiKey.isEmpty else {
                throw NSError(domain: "AI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập API Key cho \(provider.rawValue) trong Cài đặt."])
            }
            let model = AppSettings.shared.customAIModel.isEmpty ? defaultModel : AppSettings.shared.customAIModel
            return try await streamOpenAICompatible(
                endpoint: endpoint,
                apiKey: apiKey,
                model: model,
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
        let apiKey = AppSettings.shared.deepLKey.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
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
        provider: DirectAIProvider = AppSettings.shared.aiProvider
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
        provider: DirectAIProvider = AppSettings.shared.aiProvider
    ) async throws -> String {
        let prompt = AIPromptBuilder.wordInContextPrompt(word: word, sentence: sentence, targetLang: targetLang)
        return try await sendPromptToAI(prompt: prompt, provider: provider)
    }
    
    // MARK: - 5. Unified Dispatcher to Selected AI Engine
    private func sendPromptToAI(prompt: String, provider: DirectAIProvider) async throws -> String {
        switch provider {
        case .openAI:
            let apiKey = AppSettings.shared.openAIKey.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !apiKey.isEmpty else {
                throw NSError(domain: "AI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập OpenAI API Key trong Cài đặt."])
            }
            let model = AppSettings.shared.customAIModel.isEmpty ? provider.defaultModel : AppSettings.shared.customAIModel
            return try await queryOpenAICompatible(
                endpoint: "https://api.openai.com/v1/chat/completions",
                apiKey: apiKey,
                model: model,
                prompt: prompt
            )
            
        case .groq:
            let apiKey = AppSettings.shared.groqKey.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !apiKey.isEmpty else {
                throw NSError(domain: "AI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập Groq API Key trong Cài đặt."])
            }
            let model = AppSettings.shared.customAIModel.isEmpty ? provider.defaultModel : AppSettings.shared.customAIModel
            return try await queryOpenAICompatible(
                endpoint: "https://api.groq.com/openai/v1/chat/completions",
                apiKey: apiKey,
                model: model,
                prompt: prompt
            )
            
        case .deepSeek:
            let apiKey = AppSettings.shared.deepSeekKey.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !apiKey.isEmpty else {
                throw NSError(domain: "AI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập DeepSeek API Key trong Cài đặt."])
            }
            let model = AppSettings.shared.customAIModel.isEmpty ? provider.defaultModel : AppSettings.shared.customAIModel
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
                AppSettings.shared.openAIKey.trimmingCharacters(in: .whitespacesAndNewlines),
                provider.defaultModel
            )
        case .groq:
            return (
                "https://api.groq.com/openai/v1/chat/completions",
                AppSettings.shared.groqKey.trimmingCharacters(in: .whitespacesAndNewlines),
                provider.defaultModel
            )
        case .deepSeek:
            return (
                "https://api.deepseek.com/v1/chat/completions",
                AppSettings.shared.deepSeekKey.trimmingCharacters(in: .whitespacesAndNewlines),
                provider.defaultModel
            )
        default:
            return ("", "", "")
        }
    }
    
    // Anthropic Claude Messages API
    private func queryAnthropic(prompt: String) async throws -> String {
        let apiKey = AppSettings.shared.anthropicKey.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw NSError(domain: "Anthropic", code: 401, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập Anthropic API Key trong Cài đặt."])
        }
        
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let model = AppSettings.shared.customAIModel.isEmpty ? DirectAIProvider.anthropic.defaultModel : AppSettings.shared.customAIModel
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
        let apiKey = AppSettings.shared.geminiKey.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw NSError(domain: "Gemini", code: 401, userInfo: [NSLocalizedDescriptionKey: "Vui lòng nhập Google Gemini API Key trong Cài đặt."])
        }
        
        let model = AppSettings.shared.customAIModel.isEmpty ? DirectAIProvider.googleGemini.defaultModel : AppSettings.shared.customAIModel
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }
        
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
    
    // Ollama Local LLM API
    private func queryOllama(prompt: String) async throws -> String {
        var base = AppSettings.shared.ollamaEndpoint.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if base.isEmpty { base = "http://localhost:11434" }
        if base.hasSuffix("/") { base = String(base.dropLast()) }
        
        guard let url = URL(string: "\(base)/api/generate") else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let model = AppSettings.shared.customAIModel.isEmpty ? DirectAIProvider.ollama.defaultModel : AppSettings.shared.customAIModel
        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) else {
            let err = String(data: data, encoding: String.Encoding.utf8) ?? "Ollama Connection Error"
            throw NSError(domain: "Ollama", code: (response as? HTTPURLResponse)?.statusCode ?? 500, userInfo: [NSLocalizedDescriptionKey: "Không thể kết nối tới Ollama tại \(base): \(err)"])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let responseText = json["response"] as? String {
            return responseText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        
        throw NSError(domain: "Ollama", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không phân tích được phản hồi từ Ollama."])
    }
}
