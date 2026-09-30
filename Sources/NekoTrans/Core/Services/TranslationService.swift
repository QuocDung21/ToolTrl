import Foundation
import NaturalLanguage

public enum TargetLanguage: String, CaseIterable, Identifiable, Sendable {
    case vietnamese = "vi"
    case english = "en"
    case japanese = "ja"
    case chinese = "zh"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .vietnamese: return "Tiếng Việt (vi)"
        case .english: return "Tiếng Anh (en)"
        case .japanese: return "Tiếng Nhật (ja)"
        case .chinese: return "Tiếng Trung (zh)"
        case .korean: return "Tiếng Hàn (ko)"
        case .french: return "Tiếng Pháp (fr)"
        case .german: return "Tiếng Đức (de)"
        case .spanish: return "Tiếng Tây Ban Nha (es)"
        }
    }
}

@MainActor
public final class TranslationService {
    public static let shared = TranslationService()
    
    private let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 8.0
        config.httpMaximumConnectionsPerHost = 10
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()
    
    private init() {}
    
    // MARK: - Circuit Breaker State for Google Web Scraping
    private var isGoogleWebTripped: Bool = false
    private var googleWebTripUntil: Date = .distantPast
    private var googleWebConsecutiveErrors: Int = 0
    
    public var isCircuitOpen: Bool {
        if isGoogleWebTripped {
            if Date() > googleWebTripUntil {
                isGoogleWebTripped = false
                googleWebConsecutiveErrors = 0
                return false
            }
            return true
        }
        return false
    }
    
    public func tripGoogleWebCircuit(duration: TimeInterval = 300) {
        isGoogleWebTripped = true
        googleWebTripUntil = Date().addingTimeInterval(duration)
    }
    
    public func resetCircuitBreaker() {
        isGoogleWebTripped = false
        googleWebTripUntil = .distantPast
        googleWebConsecutiveErrors = 0
    }
    
    private func recordGoogleWebSuccess() {
        googleWebConsecutiveErrors = 0
        isGoogleWebTripped = false
    }
    
    private func recordGoogleWebFailure() {
        googleWebConsecutiveErrors += 1
        if googleWebConsecutiveErrors >= 3 {
            tripGoogleWebCircuit(duration: 300)
        }
    }

    /// Detects language from text using Apple NaturalLanguage framework
    public func detectLanguage(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "en" }
        
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        
        if let dominant = recognizer.dominantLanguage?.rawValue {
            return dominant
        }
        return "en"
    }
    
    /// Multi-tier high-speed translation engine with Domain & Tone Context
    public func translate(
        text: String,
        from sourceLang: String = "auto",
        to targetLang: String,
        domain: TranslationDomain = AppSettings.shared.translationDomain,
        tone: TranslationTone = AppSettings.shared.translationTone,
        engine: TranslationEngine = AppSettings.shared.translationEngine
    ) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let cacheKey = "\(engine.rawValue)_\(tone.rawValue)_\(sourceLang)_\(targetLang)_\(domain.rawValue)_\(trimmed)"
        if let cached = await TranslationCache.shared.getTranslation(key: cacheKey) {
            return cached
        }
        
        // 1. Direct AI Engine Selected
        if engine == .directAI {
            if let aiResult = try? await DirectAIService.shared.translate(
                text: trimmed,
                from: sourceLang,
                to: targetLang,
                domain: domain,
                tone: tone
            ), !aiResult.isEmpty {
                await TranslationCache.shared.setTranslation(key: cacheKey, value: aiResult)
                return aiResult
            }
        }
        
        // 2. DeepL Engine Selected
        if engine == .deepL {
            if let deeplResult = try? await DirectAIService.shared.translateViaDeepL(
                text: trimmed,
                from: sourceLang,
                to: targetLang
            ), !deeplResult.isEmpty {
                await TranslationCache.shared.setTranslation(key: cacheKey, value: deeplResult)
                return deeplResult
            }
        }
        
        // 3. Google Web Explicit Engine Selected
        if engine == .googleWeb {
            if !isCircuitOpen, let webResult = await translateViaGoogleWeb(text: trimmed, from: sourceLang, to: targetLang), !webResult.isEmpty {
                await TranslationCache.shared.setTranslation(key: cacheKey, value: webResult)
                return webResult
            }
            // Fallback to GTX if Google Web fails
            if let gtxResult = await translateViaGoogleGTX(text: trimmed, from: sourceLang, to: targetLang), !gtxResult.isEmpty {
                await TranslationCache.shared.setTranslation(key: cacheKey, value: gtxResult)
                return gtxResult
            }
        }
        
        // 4. Apple Offline Engine Selected (Fallback path if not handled natively)
        if engine == .appleOffline {
            #if canImport(Translation)
            // If called here, Apple Translation session fallback or cache is used
            #endif
        }
        
        // 5. Multi-paragraph or long text (> 350 chars): Chunked concurrent translation
        if trimmed.count > 350 && (trimmed.contains("\n\n") || trimmed.contains("\n")) {
            if let chunkedResult = await translateLongTextInChunks(text: trimmed, from: sourceLang, to: targetLang, domain: domain, tone: tone) {
                await TranslationCache.shared.setTranslation(key: cacheKey, value: chunkedResult)
                return chunkedResult
            }
        }
        
        // 6. Speculative Fast-Racing Pipeline (Auto or Fallback)
        let result = await raceEngines(text: trimmed, from: sourceLang, to: targetLang, domain: domain, tone: tone)
        
        if let finalResult = result, !finalResult.isEmpty {
            await TranslationCache.shared.setTranslation(key: cacheKey, value: finalResult)
            return finalResult
        }
        
        return nil
    }
    
    // MARK: - Speculative Fast-Racing Engine Runner
    private func raceEngines(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain,
        tone: TranslationTone
    ) async -> String? {
        let skipGoogleWeb = isCircuitOpen
        
        return await withTaskGroup(of: String?.self) { group in
            if !skipGoogleWeb {
                // Primary Engine: Google Web Mobile
                group.addTask { [weak self] in
                    return await self?.translateViaGoogleWeb(text: text, from: sourceLang, to: targetLang)
                }
                
                // Fast JSON GTX Engine
                group.addTask { [weak self] in
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    guard !Task.isCancelled else { return nil }
                    return await self?.translateViaGoogleGTX(text: text, from: sourceLang, to: targetLang)
                }
                
                // Speculative Fallback: Launch MyMemory if primary engines do not return within 800ms
                group.addTask { [weak self] in
                    try? await Task.sleep(nanoseconds: 800_000_000) // 800ms
                    guard !Task.isCancelled else { return nil }
                    return await self?.translateViaMyMemory(text: text, from: sourceLang, to: targetLang)
                }
            } else {
                // Circuit is open: Immediately start Google GTX with 0ms latency
                group.addTask { [weak self] in
                    return await self?.translateViaGoogleGTX(text: text, from: sourceLang, to: targetLang)
                }
                
                // Backup MyMemory after 300ms
                group.addTask { [weak self] in
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                    guard !Task.isCancelled else { return nil }
                    return await self?.translateViaMyMemory(text: text, from: sourceLang, to: targetLang)
                }
            }
            
            // Return first successful non-empty result and cancel others
            for await res in group {
                if let r = res, !r.isEmpty {
                    group.cancelAll()
                    return r
                }
            }
            
            return nil
        }
    }
    
    // MARK: - Long Text Concurrent Chunking
    private func translateLongTextInChunks(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain,
        tone: TranslationTone
    ) async -> String? {
        let paragraphs = text.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard paragraphs.count > 1 else { return nil }
        
        var translatedParagraphs = Array(repeating: "", count: paragraphs.count)
        
        await withTaskGroup(of: (Int, String?).self) { group in
            for (index, para) in paragraphs.enumerated() {
                group.addTask { [weak self] in
                    let trans = await self?.raceEngines(text: para, from: sourceLang, to: targetLang, domain: domain, tone: tone)
                    return (index, trans)
                }
            }
            
            for await (index, trans) in group {
                if let t = trans {
                    translatedParagraphs[index] = t
                } else {
                    translatedParagraphs[index] = paragraphs[index]
                }
            }
        }
        
        let fullResult = translatedParagraphs.joined(separator: "\n\n")
        return fullResult.isEmpty ? nil : fullResult
    }
    
    // MARK: - Engine 1: Google Web Mobile Engine (High Speed, Ultra Reliable)
    private func translateViaGoogleWeb(text: String, from sourceLang: String, to targetLang: String) async -> String? {
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
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.5
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                recordGoogleWebFailure()
                return nil
            }
            if httpResponse.statusCode == 429 {
                // Rate limited by Google! Trip circuit immediately
                tripGoogleWebCircuit(duration: 300)
                return nil
            }
            guard httpResponse.statusCode == 200, let html = String(data: data, encoding: .utf8) else {
                recordGoogleWebFailure()
                return nil
            }
            
            // Extract from <div class="result-container">...</div> (supports multiline)
            let pattern = #"class="result-container">([\s\S]*?)<\/div>"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
               let range = Range(match.range(at: 1), in: html) {
                let rawText = String(html[range])
                let decoded = decodeHTMLEntities(rawText).trimmingCharacters(in: .whitespacesAndNewlines)
                if !decoded.isEmpty {
                    recordGoogleWebSuccess()
                    return decoded
                }
            }
            recordGoogleWebFailure()
        } catch {
            recordGoogleWebFailure()
        }
        return nil
    }
    
    // MARK: - Engine 2: Google GTX API (Fast JSON Translation)
    private func translateViaGoogleGTX(text: String, from sourceLang: String, to targetLang: String) async -> String? {
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
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.5
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [Any],
               let sentences = json.first as? [Any] {
                var full = ""
                for s in sentences {
                    if let sArr = s as? [Any], let t = sArr.first as? String {
                        full += t
                    }
                }
                let cleaned = decodeHTMLEntities(full).trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.isEmpty ? nil : cleaned
            }
        } catch {
            // Cancelled or error
        }
        return nil
    }
    
    // MARK: - Engine 3: MyMemory Translation API
    private func translateViaMyMemory(text: String, from sourceLang: String, to targetLang: String) async -> String? {
        let sl = sourceLang == "auto" ? "en" : sourceLang
        guard let url = SafeURL.make(
            host: "api.mymemory.translated.net",
            path: "/get",
            queryItems: [
                URLQueryItem(name: "q", value: text),
                URLQueryItem(name: "langpair", value: "\(sl)|\(targetLang)")
            ]
        ) else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                switch MyMemoryResponse.parse(json) {
                case .translation(let text):
                    return text
                case .rejected(let reason):
                    AppLog.translation.notice("MyMemory refused the request: \(reason, privacy: .public)")
                    return nil
                case .unparsable:
                    return nil
                }
            }
        } catch {
            // Error
        }
        return nil
    }
    
    public func translateFallback(text: String, from sourceLang: String = "auto", to targetLang: String = "vi") async -> String? {
        return await translate(text: text, from: sourceLang, to: targetLang)
    }
    
    // MARK: - Comprehensive HTML Entity Decoder Helper
    private func decodeHTMLEntities(_ string: String) -> String {
        var result = string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&rsquo;", with: "’")
            .replacingOccurrences(of: "&lsquo;", with: "‘")
            .replacingOccurrences(of: "&rdquo;", with: "”")
            .replacingOccurrences(of: "&ldquo;", with: "“")
            .replacingOccurrences(of: "&ndash;", with: "–")
            .replacingOccurrences(of: "&mdash;", with: "—")
            .replacingOccurrences(of: "&hellip;", with: "…")

        // Decode decimal entities &#123;
        if result.contains("&#") {
            let decimalPattern = #"&#([0-9]{1,6});"#
            if let regex = try? NSRegularExpression(pattern: decimalPattern) {
                let matches = regex.matches(in: result, range: NSRange(location: 0, length: result.utf16.count)).reversed()
                for match in matches {
                    if let codeRange = Range(match.range(at: 1), in: result),
                       let code = UInt32(result[codeRange]),
                       let scalar = UnicodeScalar(code) {
                        if let entityRange = Range(match.range, in: result) {
                            result.replaceSubrange(entityRange, with: String(Character(scalar)))
                        }
                    }
                }
            }

            // Decode hex entities &#x1F600;
            let hexPattern = #"&#[xX]([0-9a-fA-F]{1,6});"#
            if let regex = try? NSRegularExpression(pattern: hexPattern) {
                let matches = regex.matches(in: result, range: NSRange(location: 0, length: result.utf16.count)).reversed()
                for match in matches {
                    if let codeRange = Range(match.range(at: 1), in: result),
                       let code = UInt32(result[codeRange], radix: 16),
                       let scalar = UnicodeScalar(code) {
                        if let entityRange = Range(match.range, in: result) {
                            result.replaceSubrange(entityRange, with: String(Character(scalar)))
                        }
                    }
                }
            }
        }
        return result
    }
}

// MARK: - MyMemory Response Parsing

/// Parses a MyMemory `/get` payload.
///
/// MyMemory answers **HTTP 200 even when it refuses the request**: the real outcome lives
/// in `responseStatus`, and `translatedText` then carries the error sentence instead of a
/// translation. Those sentences were being displayed to users as if they were the
/// Vietnamese result (`PLEASE SELECT TWO DISTINCT LANGUAGES`, `QUERY LENGTH LIMIT
/// EXCEEDED...`), so the payload must be validated before it is trusted.
enum MyMemoryResponse {
    enum Outcome: Equatable {
        case translation(String)
        /// Refused: carries a loggable reason.
        case rejected(reason: String)
        /// Malformed or empty payload.
        case unparsable
    }

    static func parse(_ json: [String: Any]) -> Outcome {
        if let status = json["responseStatus"] as? Int, status != 200 {
            let detail = json["responseDetails"] as? String ?? "no details"
            return .rejected(reason: "status \(status): \(detail)")
        }

        if let quotaFinished = json["quotaFinished"] as? Bool, quotaFinished {
            return .rejected(reason: "daily quota exhausted")
        }

        guard let responseData = json["responseData"] as? [String: Any],
              let translated = responseData["translatedText"] as? String else {
            return .unparsable
        }

        let cleaned = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return .unparsable }

        // Defence in depth: some refusals still come back with status 200.
        if isErrorSentence(cleaned) {
            return .rejected(reason: cleaned)
        }

        return .translation(cleaned)
    }

    /// True for the human-readable refusal sentences MyMemory puts in `translatedText`.
    static func isErrorSentence(_ text: String) -> Bool {
        let upper = text.uppercased()
        return upper.hasPrefix("PLEASE SELECT TWO DISTINCT LANGUAGES")
            || upper.hasPrefix("QUERY LENGTH LIMIT EXCEEDED")
            || upper.hasPrefix("MYMEMORY WARNING")
            || upper.hasPrefix("INVALID EMAIL PROVIDED")
    }
}
