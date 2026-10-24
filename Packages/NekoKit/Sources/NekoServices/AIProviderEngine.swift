import Foundation
import NekoCore
import Defaults

/// Standardized interface for AI Translation Engines
public protocol AIProviderEngine: Sendable {
    var provider: DirectAIProvider { get }
    
    func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain
    ) async throws -> String
    
    func streamTranslate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain,
        isCancelled: (@Sendable () -> Bool)?,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String
}

/// In-Process Metal LLM Engine powered by llama.cpp
public struct InProcessGGUFEngine: AIProviderEngine {
    public let provider: DirectAIProvider = .inProcessGGUF
    
    public init() {}
    
    public func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain
    ) async throws -> String {
        try await streamTranslate(
            text: text,
            from: sourceLang,
            to: targetLang,
            domain: domain,
            isCancelled: nil,
            onToken: { _ in }
        )
    }
    
    public func streamTranslate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain,
        isCancelled: (@Sendable () -> Bool)?,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        if !LocalGGUFService.shared.isLoaded {
            let path = Defaults[.customGGUFModelPath]
            guard !path.isEmpty && FileManager.default.fileExists(atPath: path) else {
                throw NSError(domain: "GGUF", code: 404, userInfo: [NSLocalizedDescriptionKey: "Chưa chọn file model GGUF nào hoặc file không tồn tại. Vui lòng vào Cài đặt để chọn file .gguf."])
            }
            try LocalGGUFService.shared.loadModel(at: path)
        }
        let sys = AIPromptBuilder.localGGUFSystemPrompt(sourceLang: sourceLang, targetLang: targetLang, domain: domain.rawValue)
        let userPrompt = AIPromptBuilder.localGGUFUserPrompt(text: text, targetLang: targetLang)
        let formattedPrompt = LocalGGUFService.shared.formatPrompt(system: sys, user: userPrompt)
        return try await LocalGGUFService.shared.streamInference(
            prompt: formattedPrompt,
            isCancelled: isCancelled,
            onToken: onToken
        )
    }
}

/// Factory / Registry for AIProviderEngine instances
public struct AIProviderEngineRegistry: Sendable {
    public static func engine(for provider: DirectAIProvider) -> any AIProviderEngine {
        switch provider {
        case .inProcessGGUF:
            return InProcessGGUFEngine()
        default:
            return DirectAIServiceAdapterEngine(provider: provider)
        }
    }
}

/// Fallback adapter engine wrapping DirectAIService for cloud providers
internal struct DirectAIServiceAdapterEngine: AIProviderEngine {
    public let provider: DirectAIProvider
    
    public func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain
    ) async throws -> String {
        let prompt = AIPromptBuilder.contextualTranslationPrompt(
            text: text,
            sourceLang: sourceLang,
            targetLang: targetLang,
            domain: domain.rawValue
        )
        return try await DirectAIService.shared.sendPromptToAI(prompt: prompt, provider: provider)
    }
    
    public func streamTranslate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        domain: TranslationDomain,
        isCancelled: (@Sendable () -> Bool)?,
        onToken: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        try await DirectAIService.shared.translateStreaming(
            text: text,
            from: sourceLang,
            to: targetLang,
            domain: domain,
            provider: provider,
            isCancelled: isCancelled,
            onToken: onToken
        )
    }
}
