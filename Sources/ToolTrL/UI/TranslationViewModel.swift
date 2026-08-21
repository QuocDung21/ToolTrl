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
            // 3. Fetch Word-by-Word Glosses in Parallel
            fetchWordGlosses(for: trimmed)
        }
        
        // 4. Trigger Apple Neural AI Translation
        updateTranslation()
    }
    
    public func updateTranslation() {
        guard !originalText.isEmpty else { return }
        self.isLoading = true
        let currentID = UUID()
        self.translationTaskID = currentID
        
        #if canImport(Translation)
        if #available(macOS 15.0, *) {
            let source = Locale.Language(identifier: detectedLanguage)
            let target = Locale.Language(identifier: targetLanguage.rawValue)
            self.translationConfig = TranslationSession.Configuration(source: source, target: target)
        }
        #endif
        
        // Fallback watchdog
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard self.translationTaskID == currentID else { return }
            if self.translatedText.isEmpty && self.isLoading {
                await self.runFallbackTranslation()
            }
        }
    }
    
    // MARK: - Parallel Word-by-Word Gloss Fetcher
    private func fetchWordGlosses(for text: String) {
        let tokens = text.split(separator: " ").map { String($0) }
        guard tokens.count >= 2 && tokens.count <= 50 else { return }
        
        // Initial placeholder glosses
        self.wordGlosses = tokens.map { token in
            let clean = token.trimmingCharacters(in: .punctuationCharacters)
            return WordGloss(original: token, gloss: "...", cleanWord: clean)
        }
        
        Task {
            let target = self.targetLanguage.rawValue
            var results: [WordGloss] = []
            
            await withTaskGroup(of: (Int, String, String, String).self) { group in
                for (index, token) in tokens.enumerated() {
                    let clean = token.trimmingCharacters(in: .punctuationCharacters)
                    group.addTask {
                        guard !clean.isEmpty else {
                            return (index, token, "", clean)
                        }
                        
                        let cacheKey = "gloss_\(clean.lowercased())_\(target)"
                        if let cached = TranslationCache.shared.getTranslation(key: cacheKey) {
                            return (index, token, cached, clean)
                        }
                        
                        if let translated = await TranslationService.shared.translateFallback(text: clean, from: "auto", to: target) {
                            let cleanTrans = translated.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            TranslationCache.shared.setTranslation(key: cacheKey, value: cleanTrans)
                            return (index, token, cleanTrans, clean)
                        }
                        return (index, token, clean.lowercased(), clean)
                    }
                }
                
                var gathered: [(Int, String, String, String)] = []
                for await item in group {
                    gathered.append(item)
                }
                gathered.sort { $0.0 < $1.0 }
                results = gathered.map { WordGloss(original: $0.1, gloss: $0.2, cleanWord: $0.3) }
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
            if self.translatedText.isEmpty {
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
