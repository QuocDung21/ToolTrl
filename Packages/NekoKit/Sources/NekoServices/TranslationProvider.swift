import Foundation

// MARK: - Translation Provider Protocol
public protocol TranslationProvider: Sendable {
    var id: String { get }
    var engine: TranslationEngine { get }
    var displayName: String { get }
    
    func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain
    ) async throws -> String
}

// MARK: - Translation Provider Result
public struct TranslationProviderResult: Sendable, Identifiable {
    public let id: UUID
    public let engine: TranslationEngine
    public let providerName: String
    public let text: String
    public let latencyMs: Int
    public let isError: Bool
    public let errorMessage: String?
    
    public init(
        id: UUID = UUID(),
        engine: TranslationEngine,
        providerName: String,
        text: String,
        latencyMs: Int,
        isError: Bool = false,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.engine = engine
        self.providerName = providerName
        self.text = text
        self.latencyMs = latencyMs
        self.isError = isError
        self.errorMessage = errorMessage
    }
}

// MARK: - Concrete Providers

public final class GoogleWebProvider: TranslationProvider {
    public let id: String = "google_web"
    public let engine: TranslationEngine = .googleWeb
    public let displayName: String = "Google Translate"
    
    private let urlSession: URLSession
    
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    public func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain = .general
    ) async throws -> String {
        let sl = (sourceLang == "en" || sourceLang == "vi" || sourceLang == "ja" || sourceLang == "zh" || sourceLang == "ko" || sourceLang == "fr" || sourceLang == "de" || sourceLang == "es") ? sourceLang : "auto"
        guard let url = SafeURL.make(
            host: "translate.google.com",
            path: "/m",
            queryItems: [
                URLQueryItem(name: "sl", value: sl),
                URLQueryItem(name: "tl", value: targetLang),
                URLQueryItem(name: "q", value: text)
            ]
        ) else {
            throw NSError(domain: "GoogleWebProvider", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.5
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GoogleWebProvider", code: 500, userInfo: [NSLocalizedDescriptionKey: "Non-HTTP response"])
        }
        
        if httpResponse.statusCode == 429 {
            throw NSError(domain: "GoogleWebProvider", code: 429, userInfo: [NSLocalizedDescriptionKey: "Rate limited by Google"])
        }
        
        guard httpResponse.statusCode == 200, let html = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "GoogleWebProvider", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
        }
        
        let pattern = #"class="result-container">([\s\S]*?)<\/div>"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
           let range = Range(match.range(at: 1), in: html) {
            let rawText = String(html[range])
            let decoded = HTMLEntityDecoder.decode(rawText).trimmingCharacters(in: .whitespacesAndNewlines)
            if !decoded.isEmpty {
                return decoded
            }
        }
        
        throw NSError(domain: "GoogleWebProvider", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not parse Google response"])
    }
}

public final class GoogleGTXProvider: TranslationProvider {
    public let id: String = "google_gtx"
    public let engine: TranslationEngine = .auto
    public let displayName: String = "Google GTX"
    
    private let urlSession: URLSession
    
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    public func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain = .general
    ) async throws -> String {
        let sl = sourceLang.isEmpty ? "auto" : sourceLang
        guard let url = SafeURL.make(
            host: "translate.googleapis.com",
            path: "/translate_a/single",
            queryItems: [
                URLQueryItem(name: "client", value: "gtx"),
                URLQueryItem(name: "sl", value: sl),
                URLQueryItem(name: "tl", value: targetLang),
                URLQueryItem(name: "dt", value: "t"),
                URLQueryItem(name: "q", value: text)
            ]
        ) else {
            throw NSError(domain: "GoogleGTXProvider", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "GoogleGTXProvider", code: 500, userInfo: [NSLocalizedDescriptionKey: "Google GTX failed"])
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [Any],
           let sentences = json.first as? [Any] {
            var full = ""
            for s in sentences {
                if let sArr = s as? [Any], let t = sArr.first as? String {
                    full += t
                }
            }
            let cleaned = HTMLEntityDecoder.decode(full).trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleaned.isEmpty {
                return cleaned
            }
        }
        
        throw NSError(domain: "GoogleGTXProvider", code: 404, userInfo: [NSLocalizedDescriptionKey: "No translation returned"])
    }
}

public final class DeepLProvider: TranslationProvider {
    public let id: String = "deepl"
    public let engine: TranslationEngine = .deepL
    public let displayName: String = "DeepL Translator"
    
    public init() {}
    
    public func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain = .general
    ) async throws -> String {
        return try await DirectAIService.shared.translateViaDeepL(
            text: text,
            from: sourceLang,
            to: targetLang
        )
    }
}

public final class DirectAIProviderWrapper: TranslationProvider {
    public let id: String = "direct_ai"
    public let engine: TranslationEngine = .directAI
    public let displayName: String = "Direct AI"
    
    public init() {}
    
    public func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain = .general
    ) async throws -> String {
        return try await DirectAIService.shared.translate(
            text: text,
            from: sourceLang,
            to: targetLang,
            domain: domain
        )
    }
}

public final class MyMemoryProvider: TranslationProvider {
    public let id: String = "mymemory"
    public let engine: TranslationEngine = .auto
    public let displayName: String = "MyMemory"
    
    private let urlSession: URLSession
    
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    public func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain = .general
    ) async throws -> String {
        let sl = sourceLang == "auto" ? "en" : sourceLang
        guard let url = SafeURL.make(
            host: "api.mymemory.translated.net",
            path: "/get",
            queryItems: [
                URLQueryItem(name: "q", value: text),
                URLQueryItem(name: "langpair", value: "\(sl)|\(targetLang)")
            ]
        ) else {
            throw NSError(domain: "MyMemoryProvider", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.5
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw NSError(domain: "MyMemoryProvider", code: 500, userInfo: [NSLocalizedDescriptionKey: "MyMemory failed"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "MyMemoryProvider", code: 422, userInfo: [NSLocalizedDescriptionKey: "Unparsable response"])
        }
        
        switch MyMemoryResponse.parse(json) {
        case .translation(let text):
            return text
        case .rejected(let reason):
            throw NSError(domain: "MyMemoryProvider", code: 403, userInfo: [NSLocalizedDescriptionKey: reason])
        case .unparsable:
            throw NSError(domain: "MyMemoryProvider", code: 422, userInfo: [NSLocalizedDescriptionKey: "Unparsable MyMemory JSON"])
        }
    }
}
