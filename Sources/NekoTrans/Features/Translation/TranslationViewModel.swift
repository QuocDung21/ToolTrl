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
    
    @Published public var translationTone: TranslationTone {
        didSet {
            AppSettings.shared.translationTone = translationTone
            if !originalText.isEmpty {
                updateTranslation()
            }
        }
    }
    
    @Published public var selectedEngine: TranslationEngine {
        didSet {
            AppSettings.shared.translationEngine = selectedEngine
            if !originalText.isEmpty {
                updateTranslation()
            }
        }
    }
    
    @Published public var grammarRewriteResult: GrammarRewriteResult? = nil
    @Published public var isAnalyzingGrammar: Bool = false
    @Published public var inspectedWordToken: (word: String, explanation: String)? = nil
    @Published public var isInspectingWord: Bool = false
    @Published public var isStreaming: Bool = false
    @Published public var isHistoryPresented: Bool = false
    
    @Published public private(set) var lookupHistory: [String] = []
    
    public var canGoBack: Bool {
        return !lookupHistory.isEmpty
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
        self.translationTone = AppSettings.shared.translationTone
        self.selectedEngine = AppSettings.shared.translationEngine
    }
    
    public func goBack() {
        guard let previous = lookupHistory.popLast() else { return }
        internalProcessText(previous)
    }
    
    public func processNestedWord(_ word: String) {
        let clean = word.trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean.lowercased() != originalText.lowercased() else { return }
        if !originalText.isEmpty {
            lookupHistory.append(originalText)
        }
        internalProcessText(clean)
    }
    
    public func processText(_ text: String) {
        lookupHistory.removeAll()
        internalProcessText(text)
    }
    
    private func internalProcessText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        SpeechService.shared.stop()
        
        // Record lookup statistics for daily & monthly motivation tracking
        LookupStatsService.shared.recordLookup(term: trimmed)
        
        self.originalText = trimmed
        self.translatedText = ""
        self.definition = nil
        self.richEntry = nil
        self.wordGlosses = []
        self.grammarRewriteResult = nil
        self.inspectedWordToken = nil
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
            // 3. Fast Batch Word-by-Word Glosses for any length (no word limit)
            fetchWordGlosses(for: trimmed)
        }
        
        // 4. Trigger AI Translation
        updateTranslation()
    }
    
    public func updateTranslation() {
        guard !originalText.isEmpty else { return }
        self.isLoading = true
        self.isStreaming = false
        let currentID = UUID()
        self.translationTaskID = currentID
        
        #if canImport(Translation)
        if #available(macOS 15.0, *) {
            if selectedEngine == .appleOffline {
                let source = Locale.Language(identifier: detectedLanguage)
                let target = Locale.Language(identifier: targetLanguage.rawValue)
                self.translationConfig = TranslationSession.Configuration(source: source, target: target)
                // Stop here: TranslationSession in SwiftUI ViewModifier will handle on-device translation
                return
            } else {
                self.translationConfig = nil
            }
        }
        #endif
        
        // Direct AI Engine with Real-Time SSE Token Streaming
        if selectedEngine == .directAI {
            Task { [weak self] in
                guard let self = self else { return }
                self.isStreaming = true
                self.translatedText = ""
                do {
                    let fullText = try await DirectAIService.shared.translateStreaming(
                        text: self.originalText,
                        from: self.detectedLanguage,
                        to: self.targetLanguage.rawValue,
                        domain: AppSettings.shared.translationDomain,
                        tone: self.translationTone,
                        provider: AppSettings.shared.aiProvider
                    ) { [weak self] token in
                        Task { @MainActor [weak self] in
                            guard let self = self, self.translationTaskID == currentID else { return }
                            self.translatedText += token
                            self.isLoading = false
                        }
                    }
                    guard self.translationTaskID == currentID else { return }
                    self.translatedText = fullText
                    self.isLoading = false
                    self.isStreaming = false
                    self.recordHistory(translated: fullText)
                } catch {
                    // Graceful fallback to regular translation if AI streaming fails
                    self.isStreaming = false
                    if let result = await TranslationService.shared.translate(
                        text: self.originalText,
                        from: self.detectedLanguage,
                        to: self.targetLanguage.rawValue,
                        domain: AppSettings.shared.translationDomain,
                        tone: self.translationTone,
                        engine: .auto
                    ) {
                        guard self.translationTaskID == currentID else { return }
                        self.translatedText = result
                        self.recordHistory(translated: result)
                    }
                    self.isLoading = false
                }
            }
            return
        }
        
        // Immediate high-speed neural translation pipeline with Tone & Engine
        Task {
            if let result = await TranslationService.shared.translate(
                text: self.originalText,
                from: self.detectedLanguage,
                to: self.targetLanguage.rawValue,
                domain: AppSettings.shared.translationDomain,
                tone: self.translationTone,
                engine: self.selectedEngine
            ) {
                guard self.translationTaskID == currentID else { return }
                if self.translatedText.isEmpty || self.isLoading {
                    self.translatedText = result
                    self.isLoading = false
                    self.recordHistory(translated: result)
                }
            } else {
                guard self.translationTaskID == currentID else { return }
                self.isLoading = false
            }
        }
    }
    
    // MARK: - AI Grammar Checking & 3-Tone Polishing
    public func analyzeSentenceGrammar() {
        guard !originalText.isEmpty else { return }
        self.isAnalyzingGrammar = true
        
        Task {
            if let result = try? await DirectAIService.shared.analyzeGrammarAndRephrase(
                text: self.originalText,
                targetLang: self.targetLanguage.rawValue,
                provider: AppSettings.shared.aiProvider
            ) {
                self.grammarRewriteResult = result
            }
            self.isAnalyzingGrammar = false
        }
    }
    
    // MARK: - In-Sentence Interactive Word Token Inspection
    public func inspectWordInSentence(word: String) {
        let clean = word.trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        self.isInspectingWord = true
        
        Task {
            if let explanation = try? await DirectAIService.shared.explainWordInContext(
                word: clean,
                sentence: self.originalText,
                targetLang: self.targetLanguage.rawValue,
                provider: AppSettings.shared.aiProvider
            ) {
                self.inspectedWordToken = (word: clean, explanation: explanation)
            } else {
                // Fallback to quick dictionary definition
                let fallbackDef = DictionaryService.shared.lookup(term: clean) ?? "Đang tải giải thích từ..."
                self.inspectedWordToken = (word: clean, explanation: fallbackDef)
            }
            self.isInspectingWord = false
        }
    }
    
    public func dismissInspectedWord() {
        self.inspectedWordToken = nil
    }
    
    public func applyCorrection(_ text: String) {
        self.originalText = text
        updateTranslation()
    }
    
    // MARK: - Fast Batch Word-by-Word Gloss Fetcher
    private func fetchWordGlosses(for text: String) {
        let rawTokens = text.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        guard rawTokens.count >= 2 else { return }
        
        // Initial placeholder glosses
        self.wordGlosses = rawTokens.map { token in
            let clean = token.trimmingCharacters(in: .punctuationCharacters)
            return WordGloss(original: token, gloss: "...", cleanWord: clean)
        }
        
        Task {
            let target = self.targetLanguage.rawValue
            
            // Extract unique clean words
            let cleanWords = rawTokens.map { $0.trimmingCharacters(in: .punctuationCharacters).lowercased() }
            let uniqueWords = Array(Set(cleanWords)).filter { !$0.isEmpty }
            
            var wordDict: [String: String] = [:]
            var uncachedWords: [String] = []
            
            // Check cache first
            for w in uniqueWords {
                let cacheKey = "gloss_\(w)_\(target)"
                if let cached = await TranslationCache.shared.getTranslation(key: cacheKey) {
                    wordDict[w] = cached
                } else {
                    uncachedWords.append(w)
                }
            }
            
            // Batch translate uncached words with numbered index to prevent line drift
            if !uncachedWords.isEmpty {
                let numberedList = uncachedWords.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
                if let batchResult = await TranslationService.shared.translateFallback(text: numberedList, from: "auto", to: target) {
                    let lines = batchResult.components(separatedBy: "\n")
                    let linePattern = #"^(\d+)[\.\:\-\s]+(.*)$"#
                    let lineRegex = try? NSRegularExpression(pattern: linePattern)
                    var translatedIndices: [Int: String] = [:]
                    
                    for line in lines {
                        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedLine.isEmpty else { continue }
                        
                        if let regex = lineRegex,
                           let match = regex.firstMatch(in: trimmedLine, options: [], range: NSRange(location: 0, length: trimmedLine.utf16.count)),
                           let numRange = Range(match.range(at: 1), in: trimmedLine),
                           let textRange = Range(match.range(at: 2), in: trimmedLine),
                           let itemNum = Int(trimmedLine[numRange]) {
                            let itemText = String(trimmedLine[textRange]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                            translatedIndices[itemNum - 1] = itemText
                        }
                    }
                    
                    for (i, w) in uncachedWords.enumerated() {
                        let trans = translatedIndices[i] ?? (i < lines.count ? lines[i].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() : "")
                        if !trans.isEmpty {
                            wordDict[w] = trans
                            await TranslationCache.shared.setTranslation(key: "gloss_\(w)_\(target)", value: trans)
                        }
                    }
                }
            }
            
            // Reconstruct glosses in exact original token order
            var results: [WordGloss] = []
            for token in rawTokens {
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
            recordHistory(translated: cleaned)
        }
        self.isLoading = false
        self.isStreaming = false
    }
    
    public func runFallbackTranslation() async {
        if let fallback = await TranslationService.shared.translate(
            text: self.originalText,
            from: self.detectedLanguage,
            to: self.targetLanguage.rawValue
        ) {
            if self.translatedText.isEmpty {
                self.translatedText = fallback
                recordHistory(translated: fallback)
            }
        }
        self.isLoading = false
        self.isStreaming = false
    }
    
    public func recordHistory(translated: String) {
        let trimmedOriginal = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTarget = translated.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOriginal.isEmpty, !trimmedTarget.isEmpty else { return }
        
        TranslationHistoryService.shared.record(
            originalText: trimmedOriginal,
            translatedText: trimmedTarget,
            sourceLang: detectedLanguage,
            targetLang: targetLanguage.rawValue,
            engine: selectedEngine.rawValue
        )
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
