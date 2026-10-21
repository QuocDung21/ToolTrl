import Foundation
import SwiftUI
import NaturalLanguage
import Defaults
import Observation
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

@Observable
@MainActor
public final class TranslationViewModel {
    public var originalText: String = ""
    public var translatedText: String = ""
    public var detectedLanguage: String = "en"
    public var definition: String? = nil
    public var richEntry: RichWordEntry? = nil
    public var wordGlosses: [WordGloss] = []
    public var isLoading: Bool = false
    public var isDictionaryLoading: Bool = false
    public var isBookmarked: Bool = false
    public var targetLanguage: TargetLanguage {
        didSet {
            Defaults[.targetLanguage] = targetLanguage.rawValue
            AppSettings.shared.targetLanguage = targetLanguage.rawValue
            self.activeTargetLanguage = targetLanguage
            if !originalText.isEmpty {
                updateTranslation()
            }
        }
    }
    
    public var activeTargetLanguage: TargetLanguage
    
    public var selectedEngine: TranslationEngine {
        didSet {
            AppSettings.shared.translationEngine = selectedEngine
            if !originalText.isEmpty {
                updateTranslation()
            }
        }
    }
    
    public var grammarRewriteResult: GrammarRewriteResult? = nil
    public var isAnalyzingGrammar: Bool = false
    public var inspectedWordToken: (word: String, explanation: String)? = nil
    public var isInspectingWord: Bool = false
    public var isStreaming: Bool = false
    public var isHistoryPresented: Bool = false
    public var isComparisonMode: Bool = false
    public var comparisonResults: [TranslationProviderResult] = []
    public var isComparing: Bool = false
    public var activeEngineLabel: String = ""
    
    public private(set) var lookupHistory: [String] = []
    
    public var canGoBack: Bool {
        return !lookupHistory.isEmpty
    }
    
    public var isWordLookup: Bool {
        let trimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let type = InputTextNormalizer.classify(trimmed)
        return type == .word || type == .code
    }
    
    #if canImport(Translation)
    public var translationConfig: TranslationSession.Configuration?
    #endif
    
    @ObservationIgnored
    private var translationTaskID: UUID = UUID()
    
    public init() {
        let savedLang = Defaults[.targetLanguage]
        let initialTarget = TargetLanguage(rawValue: savedLang) ?? .vietnamese
        self.targetLanguage = initialTarget
        self.activeTargetLanguage = initialTarget
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
        
        // Normalize input using Easydict techniques: code split, strip comments, strip quotes
        let normalized = InputTextNormalizer.normalize(trimmed)
        let effectiveQuery = normalized.isEmpty ? trimmed : normalized
        
        self.originalText = effectiveQuery
        self.translatedText = ""
        self.definition = nil
        self.richEntry = nil
        self.wordGlosses = []
        self.grammarRewriteResult = nil
        self.inspectedWordToken = nil
        self.isLoading = true
        self.isBookmarked = VocabularyService.shared.isWordSaved(effectiveQuery)
        
        // 1. Detect source language
        let detected = TranslationService.shared.detectLanguage(for: effectiveQuery)
        self.detectedLanguage = detected
        
        // Resolve effective target language (Auto-flip: VI -> EN, EN -> VI/target)
        let effectiveTarget = InputTextNormalizer.resolveTargetLanguage(
            sourceLanguageCode: detected,
            configuredTarget: self.targetLanguage
        )
        self.activeTargetLanguage = effectiveTarget
        
        let queryType = InputTextNormalizer.classify(effectiveQuery)
        
        // 2. Word Mode vs Long Paragraph Mode
        if queryType == .word || queryType == .code {
            self.isDictionaryLoading = true
            Task {
                let rich = await SmartDictionaryService.shared.fetchRichEntry(
                    for: effectiveQuery,
                    targetLanguage: effectiveTarget.rawValue
                )
                
                await MainActor.run {
                    if let rich = rich {
                        self.richEntry = rich
                        if self.translatedText.isEmpty {
                            self.translatedText = rich.mainTranslation
                        }
                    }
                    
                    if self.definition == nil {
                        self.definition = DictionaryService.shared.lookup(term: effectiveQuery)
                    }
                    self.isDictionaryLoading = false
                }
                
                if AppSettings.shared.autoSpeakWord {
                    self.speakOriginal()
                }
            }
        } else {
            self.isDictionaryLoading = false
            // 3. Fast Batch Word-by-Word Glosses for any length (no word limit)
            fetchWordGlosses(for: effectiveQuery)
        }
        
        // 4. Trigger AI Translation
        updateTranslation(effectiveTarget: effectiveTarget)
        
        // 5. Multi-engine comparison if active
        if isComparisonMode || Defaults[.enableHUDMultiEngine] {
            performComparison()
        }
    }
    
    public func updateTranslation(effectiveTarget: TargetLanguage? = nil) {
        guard !originalText.isEmpty else { return }
        let target = effectiveTarget ?? self.activeTargetLanguage
        self.isLoading = true
        self.isStreaming = false
        let currentID = UUID()
        self.translationTaskID = currentID
        
        #if canImport(Translation)
        if #available(macOS 15.0, *) {
            if selectedEngine == .appleOffline {
                let source = Locale.Language(identifier: detectedLanguage)
                let targetLocale = Locale.Language(identifier: target.rawValue)
                self.translationConfig = TranslationSession.Configuration(source: source, target: targetLocale)
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
                    var accumulated = ""
                    var lastFlush = CACurrentMediaTime()

                    let fullText = try await DirectAIService.shared.translateStreaming(
                        text: self.originalText,
                        from: self.detectedLanguage,
                        to: target.rawValue,
                        domain: AppSettings.shared.translationDomain,
                        provider: AppSettings.shared.aiProvider
                    ) { [weak self] token in
                        accumulated += token
                        let now = CACurrentMediaTime()
                        // Throttle to ~32ms (30 FPS) to eliminate main thread flooding and UI stutter
                        if now - lastFlush >= 0.032 {
                            let textToDisplay = accumulated
                            lastFlush = now
                            Task { @MainActor [weak self] in
                                guard let self = self, self.translationTaskID == currentID else { return }
                                self.translatedText = textToDisplay
                                self.isLoading = false
                            }
                        }
                    }
                    guard self.translationTaskID == currentID else { return }
                    self.translatedText = fullText
                    self.isLoading = false
                    self.isStreaming = false
                    let p = AppSettings.shared.aiProvider
                    if p == .inProcessGGUF {
                        let name = LocalGGUFService.friendlyModelName(from: LocalGGUFService.shared.loadedModelName ?? AppSettings.shared.customGGUFModelPath)
                        self.activeEngineLabel = "\(name.isEmpty ? "GGUF Metal" : name) (In-Process)"
                    } else {
                        let custom = AppSettings.shared.customAIModel
                        let model = custom.isEmpty ? p.defaultModel : custom
                        let shortModel = model.contains("/") ? (model.components(separatedBy: "/").last ?? model) : model
                        self.activeEngineLabel = "\(shortModel) (\(p.rawValue))"
                    }
                    self.recordHistory(translated: fullText)
                } catch {
                    // Graceful fallback to regular translation if AI streaming fails
                    self.isStreaming = false
                    if let result = await TranslationService.shared.translate(
                        text: self.originalText,
                        from: self.detectedLanguage,
                        to: target.rawValue,
                        domain: AppSettings.shared.translationDomain,
                        engine: .auto
                    ) {
                        guard self.translationTaskID == currentID else { return }
                        self.translatedText = result
                        let p = AppSettings.shared.aiProvider
                        if p == .inProcessGGUF {
                            self.activeEngineLabel = "Google Translate (Tự động chuyển do chưa chọn/nạp file GGUF)"
                        } else {
                            self.activeEngineLabel = "Google Translate (Tự động chuyển do Local AI chưa chạy)"
                        }
                        self.recordHistory(translated: result)
                    }
                    self.isLoading = false
                }
            }
            return
        }
        
        // Immediate high-speed neural translation pipeline with Engine
        Task {
            if let result = await TranslationService.shared.translate(
                text: self.originalText,
                from: self.detectedLanguage,
                to: target.rawValue,
                domain: AppSettings.shared.translationDomain,
                engine: self.selectedEngine
            ) {
                guard self.translationTaskID == currentID else { return }
                if self.translatedText.isEmpty || self.isLoading {
                    self.translatedText = result
                    self.activeEngineLabel = self.selectedEngine == .auto ? "Tự động (Google / MyMemory)" : self.selectedEngine.rawValue
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
    
    // MARK: - Swap Translation Direction
    public func swapLanguages() {
        let currentSource = detectedLanguage
        let currentTarget = activeTargetLanguage.rawValue
        
        if let newTarget = TargetLanguage(rawValue: currentSource) {
            self.targetLanguage = newTarget
            self.activeTargetLanguage = newTarget
        } else {
            self.targetLanguage = .english
            self.activeTargetLanguage = .english
        }
        
        self.detectedLanguage = currentTarget
        
        if !translatedText.isEmpty {
            let previousTargetText = translatedText
            processText(previousTargetText)
        } else if !originalText.isEmpty {
            updateTranslation()
        }
    }
    
    // MARK: - Multi-Engine Comparison (Easydict Logic Inheritance)
    public func performComparison() {
        guard !originalText.isEmpty else { return }
        self.isComparing = true
        
        Task {
            let results = await TranslationService.shared.compareTranslations(
                text: self.originalText,
                from: self.detectedLanguage,
                to: self.activeTargetLanguage.rawValue,
                domain: AppSettings.shared.translationDomain
            )
            self.comparisonResults = results
            self.isComparing = false
        }
    }
    
    public func applyComparisonResult(_ result: TranslationProviderResult) {
        guard !result.isError, !result.text.isEmpty else { return }
        self.translatedText = result.text
        recordHistory(translated: result.text)
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
            let target = self.activeTargetLanguage.rawValue
            
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
        
        // Easydict Inheritance: Continuous Auto-Journaling (words.jsonl)
        ContinuousJournalService.shared.logEntry(
            word: trimmedOriginal,
            phonetic: richEntry?.phonetic,
            translation: trimmedTarget,
            sourceLang: detectedLanguage,
            targetLang: targetLanguage.rawValue,
            context: isWordLookup ? nil : trimmedOriginal
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
        
        // Easydict Inheritance: 1-Click AnkiConnect Auto-sync
        if self.isBookmarked && Defaults[.enableAnkiConnect] && Defaults[.ankiAutoSyncOnBookmark] {
            let wordToSync = originalText
            let phoneticToSync = richEntry?.phonetic
            let defsToSync = richEntry?.conciseParts.map { "\($0.part): \($0.meanings.joined(separator: ", "))" }.joined(separator: "\n")
            let exToSync = richEntry?.meanings.first?.definitions.first?.exampleEn
            
            Task {
                _ = try? await AnkiConnectService.shared.addWord(
                    word: wordToSync,
                    phonetic: phoneticToSync,
                    translation: meaning,
                    definitions: defsToSync,
                    example: exToSync
                )
            }
        }
    }
}
