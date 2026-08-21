import Foundation
import NaturalLanguage

public enum TargetLanguage: String, CaseIterable, Identifiable, Sendable {
    case vietnamese = "vi"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh-Hans"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .vietnamese: return "Tiếng Việt (vi)"
        case .english: return "English (en)"
        case .japanese: return "日本語 (ja)"
        case .korean: return "한국어 (ko)"
        case .chinese: return "中文 (zh)"
        case .french: return "Français (fr)"
        case .german: return "Deutsch (de)"
        case .spanish: return "Español (es)"
        }
    }
}

public struct TranslationResult: Sendable {
    public let originalText: String
    public let translatedText: String
    public let sourceLanguage: String
    public let targetLanguage: String
    public let definition: String?
}

@MainActor
public final class TranslationService {
    public static let shared = TranslationService()
    
    private init() {}
    
    /// Detect dominant language in text using NaturalLanguage framework
    public func detectLanguage(for text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "en" }
        
        let vietnameseChars = "àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđĐ"
        if trimmed.contains(where: { vietnameseChars.contains($0) }) {
            return "vi"
        }
        
        if trimmed.split(separator: " ").count <= 3 && trimmed.range(of: "^[a-zA-Z\\s\\-\\']+$", options: .regularExpression) != nil {
            return "en"
        }
        
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        if let dominant = recognizer.dominantLanguage?.rawValue {
            return dominant
        }
        return "en"
    }
    
    /// Neural Translation engine (Fallback if Apple Translation framework is unavailable)
    public func translate(text: String, from sourceLang: String = "auto", to targetLang: String) async -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let engineKey = AppSettings.shared.aiTranslationEngine.rawValue
        let modelKey = LocalModelService.shared.activeModelName
        let cacheKey = "\(engineKey)_\(modelKey)_\(sourceLang)_\(targetLang)_\(trimmed)"
        
        if let cached = TranslationCache.shared.getTranslation(key: cacheKey) {
            return cached
        }
        
        // 1. Hugging Face Local GGUF Model Execution
        if AppSettings.shared.aiTranslationEngine == .huggingFaceLocal {
            let filename = UserDefaults.standard.string(forKey: "selected_local_model_filename") ?? ""
            if !filename.isEmpty {
                if let ggufRes = await LocalInferenceEngine.shared.translateWithGGUF(text: trimmed, modelFilename: filename, targetLang: targetLang), !ggufRes.isEmpty {
                    TranslationCache.shared.setTranslation(key: cacheKey, value: ggufRes)
                    return ggufRes
                }
            }
        }
        
        // 2. Ollama Local Endpoint Execution
        if AppSettings.shared.aiTranslationEngine == .ollamaLocal {
            if let ollamaRes = await LocalModelService.shared.translateViaOllama(text: trimmed, to: targetLang), !ollamaRes.isEmpty {
                TranslationCache.shared.setTranslation(key: cacheKey, value: ollamaRes)
                return ollamaRes
            }
        }
        
        var result: String? = nil
        
        // 3. Neural POST Cloud Engine (Fallback)
        if let res = await translateViaNeuralPost(text: trimmed, from: sourceLang, to: targetLang), !res.isEmpty {
            result = res
        } else if let res = await translateViaSecondaryEngine(text: trimmed, from: sourceLang, to: targetLang), !res.isEmpty {
            result = res
        }
        
        if let finalResult = result {
            TranslationCache.shared.setTranslation(key: cacheKey, value: finalResult)
        }
        
        return result
    }
    
    // MARK: - Engine 1: Neural POST Engine
    private func translateViaNeuralPost(text: String, from sourceLang: String, to targetLang: String) async -> String? {
        guard let url = URL(string: "https://translate.googleapis.com/translate_a/single") else { return nil }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 8.0
        request.setValue("application/x-www-form-urlencoded;charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
        
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: sourceLang == "en" ? "en" : (sourceLang == "vi" ? "vi" : "auto")),
            URLQueryItem(name: "tl", value: targetLang),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return nil
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [Any],
               let sentences = json.first as? [Any] {
                var translatedFullText = ""
                for sentence in sentences {
                    if let sentenceArray = sentence as? [Any],
                       let translatedPart = sentenceArray.first as? String {
                        translatedFullText += translatedPart
                    }
                }
                let cleaned = translatedFullText.trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.isEmpty ? nil : cleaned
            }
        } catch {
            print("Neural POST translation error: \(error)")
        }
        return nil
    }
    
    // MARK: - Engine 2: Secondary Cloud Fallback
    private func translateViaSecondaryEngine(text: String, from sourceLang: String, to targetLang: String) async -> String? {
        let sl = sourceLang == "en" ? "en" : (sourceLang == "vi" ? "vi" : "auto")
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=\(sl)&tl=\(targetLang)&dt=t&q=\(encoded)") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
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
                let cleaned = full.trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.isEmpty ? nil : cleaned
            }
        } catch {
            print("Secondary translation error: \(error)")
        }
        return nil
    }
    
    // MARK: - Fast Word Gloss Fallback (Single line)
    public func translateFallback(text: String, from sourceLang: String = "auto", to targetLang: String = "vi") async -> String? {
        return await translate(text: text, from: sourceLang, to: targetLang)
    }
}
