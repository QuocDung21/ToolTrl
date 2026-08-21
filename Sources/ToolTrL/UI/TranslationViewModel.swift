import Foundation
import SwiftUI
import NaturalLanguage
#if canImport(Translation)
import Translation
#endif

@MainActor
public final class TranslationViewModel: ObservableObject {
    @Published public var originalText: String = ""
    @Published public var translatedText: String = ""
    @Published public var detectedLanguage: String = "en"
    @Published public var definition: String? = nil
    @Published public var richEntry: RichWordEntry? = nil
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
        self.isLoading = true
        
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
        }
        
        // 3. Trigger Apple Neural AI Translation
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
}
