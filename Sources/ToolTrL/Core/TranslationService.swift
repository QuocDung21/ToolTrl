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
    
    /// Multi-tier high-speed translation engine
    public func translate(text: String, from sourceLang: String = "auto", to targetLang: String) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let cacheKey = "\(sourceLang)_\(targetLang)_\(trimmed)"
        if let cached = TranslationCache.shared.getTranslation(key: cacheKey) {
            return cached
        }
        
        var result: String? = nil
        
        // Tier 1: Google Web Engine (Fastest ~50ms, Never blocked)
        if let res = await translateViaGoogleWeb(text: trimmed, from: sourceLang, to: targetLang), !res.isEmpty {
            result = res
        }
        // Tier 2: MyMemory Translation API
        else if let res = await translateViaMyMemory(text: trimmed, from: sourceLang, to: targetLang), !res.isEmpty {
            result = res
        }
        // Tier 3: Google API GTX Fallback
        else if let res = await translateViaGoogleGTX(text: trimmed, from: sourceLang, to: targetLang), !res.isEmpty {
            result = res
        }
        
        if let finalResult = result {
            TranslationCache.shared.setTranslation(key: cacheKey, value: finalResult)
        }
        
        return result
    }
    
    // MARK: - Engine 1: Google Web Mobile Engine (High Speed, Ultra Reliable)
    private func translateViaGoogleWeb(text: String, from sourceLang: String, to targetLang: String) async -> String? {
        let sl = (sourceLang == "en" || sourceLang == "vi" || sourceLang == "ja" || sourceLang == "zh" || sourceLang == "ko" || sourceLang == "fr" || sourceLang == "de") ? sourceLang : "auto"
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.google.com/m?sl=\(sl)&tl=\(targetLang)&q=\(encoded)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            // Extract from <div class="result-container">...</div>
            let pattern = #"class="result-container">([^<]+)<"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count)),
               let range = Range(match.range(at: 1), in: html) {
                let rawText = String(html[range])
                let decoded = decodeHTMLEntities(rawText).trimmingCharacters(in: .whitespacesAndNewlines)
                return decoded.isEmpty ? nil : decoded
            }
        } catch {
            print("Google Web translation error: \(error)")
        }
        return nil
    }
    
    // MARK: - Engine 2: MyMemory Translation API
    private func translateViaMyMemory(text: String, from sourceLang: String, to targetLang: String) async -> String? {
        let sl = sourceLang == "auto" ? "en" : sourceLang
        let langpair = "\(sl)|\(targetLang)"
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encoded)&langpair=\(langpair)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resData = json["responseData"] as? [String: Any],
               let translated = resData["translatedText"] as? String {
                let cleaned = decodeHTMLEntities(translated).trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.isEmpty ? nil : cleaned
            }
        } catch {
            print("MyMemory translation error: \(error)")
        }
        return nil
    }
    
    // MARK: - Engine 3: Google GTX API
    private func translateViaGoogleGTX(text: String, from sourceLang: String, to targetLang: String) async -> String? {
        let sl = sourceLang == "en" ? "en" : (sourceLang == "vi" ? "vi" : "auto")
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=\(sl)&tl=\(targetLang)&dt=t&q=\(encoded)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        
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
            print("Google GTX error: \(error)")
        }
        return nil
    }
    
    public func translateFallback(text: String, from sourceLang: String = "auto", to targetLang: String = "vi") async -> String? {
        return await translate(text: text, from: sourceLang, to: targetLang)
    }
    
    // MARK: - HTML Entity Decoder Helper
    private func decodeHTMLEntities(_ string: String) -> String {
        return string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}
