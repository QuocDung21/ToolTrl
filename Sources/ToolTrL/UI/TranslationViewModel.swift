import Foundation
import SwiftUI
import NaturalLanguage
#if canImport(Translation)
import Translation
#endif

public struct WordGloss: Identifiable, Sendable, Hashable {
    public var id = UUID()
    public let original: String
    public var gloss: String
    public let cleanWord: String
    
    public init(id: UUID = UUID(), original: String, gloss: String, cleanWord: String) {
        self.id = id
        self.original = original
        self.gloss = gloss
        self.cleanWord = cleanWord
    }
}

@MainActor
public final class TranslationViewModel: ObservableObject {
    @Published public var originalText: String = ""
    @Published public var translatedText: String = ""
    @Published public var detectedLanguage: String = "en"
    @Published public var definition: String? = nil
    @Published public var richEntry: RichWordEntry? = nil
    @Published public var wordGlosses: [WordGloss] = []
    @Published public var isLoading: Bool = false
    @Published public var isBookmarked: Bool = false
    @Published public var activeEngineBadge: String = "⚡ Apple Neural AI"
    @Published public var targetLanguage: TargetLanguage {
        didSet {
            UserDefaults.standard.set(targetLanguage.rawValue, forKey: "target_language")
            if !originalText.isEmpty {
                updateTranslation()
            }
        }
    }
    
    public var isWordLookup: Bool {
        let trimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.split(separator: " ").count <= 3
    }
    
    #if canImport(Translation)
    @Published public var translationConfig: TranslationSession.Configuration?
    #endif
    
    private var translationTaskID: UUID = UUID()
    
    public init() {
        let savedLang = UserDefaults.standard.string(forKey: "target_language") ?? TargetLanguage.vietnamese.rawValue
        self.targetLanguage = TargetLanguage(rawValue: savedLang) ?? .vietnamese
    }
    
    public func processText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        SpeechService.shared.stop()
        
        self.originalText = trimmed
        self.translatedText = ""
        self.definition = nil
        self.richEntry = nil
        self.wordGlosses = []
        self.isLoading = true
        self.isBookmarked = VocabularyService.shared.isWordSaved(trimmed)
        
        // Update active engine badge
        updateEngineBadge()
        
        // 1. Detect source language
        let detected = TranslationService.shared.detectLanguage(for: trimmed)
        self.detectedLanguage = detected
        
        let wordCount = trimmed.split(separator: " ").count
        
        // 2. Word Mode vs Long Paragraph Mode
        if wordCount <= 3 {
            Task {
                let rich = await SmartDictionaryService.shared.fetchRichEntry(
                    for: trimmed,
                    targetLanguage: self.targetLanguage.rawValue
                )
                
                if let rich = rich {
                    self.richEntry = rich
                    if self.translatedText.isEmpty {
                        self.translatedText = rich.mainTranslation
                    }
                }
                
                if self.definition == nil {
                    self.definition = DictionaryService.shared.lookup(term: trimmed)
                }
                
                if AppSettings.shared.autoSpeakWord {
                    self.speakOriginal()
                }
            }
        } else {
            // 3. Fast Batch Word-by-Word Glosses for any length (no word limit)
            fetchWordGlosses(for: trimmed)
        }
        
        // 4. Trigger AI Translation
        updateTranslation()
    }
    
    public func updateEngineBadge() {
        switch AppSettings.shared.aiTranslationEngine {
        case .appleNeural:
            self.activeEngineBadge = "⚡ Apple Neural AI"
        case .huggingFaceLocal:
            let model = LocalModelService.shared.activeModelName
            self.activeEngineBadge = "🤗 \(model)"
        case .ollamaLocal:
            let model = LocalModelService.shared.ollamaModelName
            self.activeEngineBadge = "🦙 Ollama: \(model)"
        }
    }
    
    public func updateTranslation() {
        guard !originalText.isEmpty else { return }
        self.isLoading = true
        let currentID = UUID()
        self.translationTaskID = currentID
        
        updateEngineBadge()
        
        // If Apple Neural AI is chosen -> Use Apple Translation framework if available
        if AppSettings.shared.aiTranslationEngine == .appleNeural {
            #if canImport(Translation)
            if #available(macOS 15.0, *) {
                let source = Locale.Language(identifier: detectedLanguage)
                let target = Locale.Language(identifier: targetLanguage.rawValue)
                self.translationConfig = TranslationSession.Configuration(source: source, target: target)
            }
            #endif
            
            // Watchdog fallback
            Task {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                guard self.translationTaskID == currentID else { return }
                if self.translatedText.isEmpty && self.isLoading {
                    await self.runFallbackTranslation()
                }
            }
        } else {
            // If Local Model / Ollama is chosen -> Bypass Apple Translation and run local model directly
            #if canImport(Translation)
            self.translationConfig = nil
            #endif
            
            Task {
                await self.runFallbackTranslation()
            }
        }
    }
    
    // MARK: - Fast Batch Word-by-Word Gloss Fetcher
    private func fetchWordGlosses(for text: String) {
        let tokens = text.split(separator: " ").map { String($0) }
        guard tokens.count >= 2 else { return }
        
        // Initial placeholder glosses
        self.wordGlosses = tokens.map { token in
            let clean = token.trimmingCharacters(in: .punctuationCharacters)
            return WordGloss(original: token, gloss: "...", cleanWord: clean)
        }
        
        Task {
            let target = self.targetLanguage.rawValue
            
            // Extract unique clean words
            let cleanWords = tokens.map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            let uniqueWords = Array(Set(cleanWords)).filter { !$0.isEmpty }
            
            var wordDict: [String: String] = [:]
            var uncachedWords: [String] = []
            
            // Check cache first
            for w in uniqueWords {
                let cacheKey = "gloss_\(w)_\(target)"
                if let cached = TranslationCache.shared.getTranslation(key: cacheKey) {
                    wordDict[w] = cached
                } else {
                    uncachedWords.append(w)
                }
            }
            
            // Batch translate uncached words in a single request
            if !uncachedWords.isEmpty {
                let joined = uncachedWords.joined(separator: "\n")
                if let batchResult = await TranslationService.shared.translateFallback(text: joined, from: "auto", to: target) {
                    let lines = batchResult.components(separatedBy: "\n")
                    for (i, w) in uncachedWords.enumerated() {
                        if i < lines.count {
                            let trans = lines[i].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            wordDict[w] = trans
                            TranslationCache.shared.setTranslation(key: "gloss_\(w)_\(target)", value: trans)
                        }
                    }
                }
            }
            
            // Reconstruct glosses in exact original token order
            var results: [WordGloss] = []
            for token in tokens {
                let clean = token.trimmingCharacters(in: .punctuationCharacters).lowercased()
                let gloss = wordDict[clean] ?? ""
                results.append(WordGloss(original: token, gloss: gloss, cleanWord: clean))
            }
            
            self.wordGlosses = results
        }
    }
    
    public func setTranslatedText(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            self.translatedText = cleaned
        }
        self.isLoading = false
    }
    
    public func runFallbackTranslation() async {
        if let fallback = await TranslationService.shared.translate(
            text: self.originalText,
            from: self.detectedLanguage,
            to: self.targetLanguage.rawValue
        ) {
            if self.translatedText.isEmpty || AppSettings.shared.aiTranslationEngine != .appleNeural {
                self.translatedText = fallback
            }
        }
        self.isLoading = false
    }
    
    public func speakOriginal() {
        let voiceCode = detectedLanguage == "vi" ? "vi-VN" : (detectedLanguage == "ja" ? "ja-JP" : (detectedLanguage == "zh" ? "zh-CN" : "en-US"))
        SpeechService.shared.speak(text: originalText, languageCode: voiceCode, speakerID: "original")
    }
    
    public func speakTranslated() {
        let voiceCode = targetLanguage == .vietnamese ? "vi-VN" : (targetLanguage == .japanese ? "ja-JP" : (targetLanguage == .chinese ? "zh-CN" : "en-US"))
        SpeechService.shared.speak(text: translatedText, languageCode: voiceCode, speakerID: "translated")
    }
    
    public func speakCustom(text: String, languageCode: String? = nil, speakerID: String) {
        SpeechService.shared.speak(text: text, languageCode: languageCode, speakerID: speakerID)
    }
    
    public func copyTranslation() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(translatedText, forType: .string)
    }
    
    public func toggleBookmark() {
        guard !originalText.isEmpty else { return }
        let meaning = !translatedText.isEmpty ? translatedText : (richEntry?.mainTranslation ?? "")
        VocabularyService.shared.toggleSaveWord(
            word: originalText,
            phonetic: richEntry?.phonetic,
            translation: meaning
        )
        self.isBookmarked = VocabularyService.shared.isWordSaved(originalText)
    }
}
