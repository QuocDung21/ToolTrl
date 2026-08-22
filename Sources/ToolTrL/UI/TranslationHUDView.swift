import SwiftUI
#if canImport(Translation)
import Translation
#endif

public struct TranslationHUDView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @ObservedObject var speechService = SpeechService.shared
    @ObservedObject var iconService = AppIconService.shared
    var onClose: () -> Void
    var onTogglePin: (() -> Void)?
    
    @State private var isPinned: Bool = false
    @State private var manualInput: String = ""
    @State private var copied: Bool = false
    @State private var showTextAnalysisSheet: Bool = false
    
    public init(viewModel: TranslationViewModel, onTogglePin: (() -> Void)? = nil, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onTogglePin = onTogglePin
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top App Bar
            topAppBar
            
            Divider()
                .opacity(0.25)
            
            // Main Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isWordLookup {
                        // DICTIONARY MODE (Word / Short Phrase)
                        if let rich = viewModel.richEntry {
                            richDictionaryView(entry: rich)
                        } else if viewModel.isLoading {
                            dictionaryLoadingSkeleton
                        } else {
                            dictionaryFallbackView
                        }
                    } else if !viewModel.originalText.isEmpty {
                        // SENTENCE / PARAGRAPH TRANSLATION MODE
                        sentenceTranslationView
                    } else {
                        // EMPTY STATE
                        emptyStateView
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .animation(.easeInOut(duration: 0.12), value: viewModel.richEntry != nil)
            }
            .frame(maxHeight: 340)
            
            Divider()
                .opacity(0.25)
            
            // Bottom Quick Search Bar
            bottomInputBar
        }
        .frame(width: 455)
        .background(
            VisualEffectBackground(material: .popover, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
        #if canImport(Translation)
        .modifier(TranslationModifier(viewModel: viewModel))
        #endif
    }
    
    // MARK: - Top App Bar
    private var topAppBar: some View {
        HStack(spacing: 8) {
            // App Branding
            HStack(spacing: 4.5) {
                iconService.currentImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundColor(iconService.selectedType.accentColor)
                
                Text("ToolTrL")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .fixedSize()
            
            // Unified Language Selector Pill (Clean, No Double Chevron)
            Menu {
                ForEach(TargetLanguage.allCases) { lang in
                    Button(action: {
                        viewModel.targetLanguage = lang
                    }) {
                        if viewModel.targetLanguage == lang {
                            Label(lang.displayName, systemImage: "checkmark")
                        } else {
                            Text(lang.displayName)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(viewModel.detectedLanguage.uppercased())
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(3)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text(viewModel.targetLanguage.displayName)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.primary.opacity(0.045))
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            
            Spacer(minLength: 4)
            
            // Right Action Buttons
            HStack(spacing: 5) {
                Button(action: {
                    QuickAIWindowController.shared.showAI(prompt: viewModel.originalText)
                }) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(.purple.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help("Mở Trợ lý AI (ChatGPT / Gemini) để phân tích sâu đoạn văn này (\(HotKeyManager.shared.aiShortcut.displayString))")
                
                Button(action: {
                    onClose()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        ScreenOCRService.shared.captureAndRecognize { text in
                            guard let recognized = text, !recognized.isEmpty else { return }
                            viewModel.processText(recognized)
                            if let appDelegate = NSApp.delegate as? AppDelegate {
                                appDelegate.floatingPanel?.showNearCursorOrCenter()
                            }
                        }
                    }
                }) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 11))
                        .foregroundColor(.blue.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help("Chụp & Quét chữ trên màn hình (OCR) (\(HotKeyManager.shared.ocrShortcut.displayString))")
                
                Button(action: {
                    isPinned.toggle()
                    onTogglePin?()
                }) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                        .foregroundColor(isPinned ? .orange : .secondary.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Đang ghim cửa sổ dịch trên cùng (Bấm để bỏ ghim)" : "Ghim cửa sổ trên cùng không tự tắt khi click ra ngoài")
                
                Button(action: {
                    VocabularyWindowController.shared.showNotebook()
                }) {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help("Mở Sổ tay từ vựng")
                
                Button(action: {
                    SettingsWindowController.shared.showSettings()
                }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.75))
                }
                .buttonStyle(.plain)
                .help("Cài đặt (Settings)")
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary.opacity(0.65))
                }
                .buttonStyle(.plain)
                .help("Đóng (ESC)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Rich Dictionary View
    private func richDictionaryView(entry: RichWordEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Word + Pronounce Button + Bookmark + Phonetic IPA
            HStack(alignment: .center, spacing: 8) {
                LiveSpokenTextView(
                    text: entry.word,
                    speakerID: "original",
                    font: .system(size: 17, weight: .bold),
                    defaultColor: .primary
                )
                
                // Pronounce Button with active wave animation
                Button(action: {
                    viewModel.speakOriginal()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "original") ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 9.5))
                        Text((speechService.isSpeaking && speechService.currentSpeakerID == "original") ? "Đang đọc" : "Phát âm")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background((speechService.isSpeaking && speechService.currentSpeakerID == "original") ? Color.blue.opacity(0.25) : Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                // Bookmark Icon
                Button(action: {
                    viewModel.toggleBookmark()
                }) {
                    Image(systemName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 12))
                        .foregroundColor(viewModel.isBookmarked ? .blue : .secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help(viewModel.isBookmarked ? "Bỏ lưu từ này" : "Lưu vào sổ từ vựng")
                
                // Phonetic Tag Box
                if AppSettings.shared.showPhonetics, let phonetic = entry.phonetic, !phonetic.isEmpty {
                    Text(phonetic)
                        .font(.system(size: 10.5, weight: .medium, design: .serif))
                        .foregroundColor(.primary.opacity(0.75))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)
                }
            }
            
            // Main Vietnamese Translation with speech highlight
            LiveSpokenTextView(
                text: entry.mainTranslation,
                speakerID: "translated",
                font: .system(size: 14.5, weight: .bold),
                defaultColor: .blue
            )
            
            // Meaning Groups
            ForEach(entry.meanings) { group in
                VStack(alignment: .leading, spacing: 6) {
                    // Part of Speech Badge + Count
                    HStack {
                        Text(group.partOfSpeechDisplay)
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .cornerRadius(3)
                        
                        Spacer()
                        
                        Text("\(group.definitions.count) định nghĩa")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                        .opacity(0.25)
                    
                    // Definitions List
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(group.definitions.enumerated()), id: \.offset) { index, item in
                            VStack(alignment: .leading, spacing: 2.5) {
                                // English Definition
                                HStack(alignment: .top, spacing: 3) {
                                    Text("\(index + 1).")
                                        .font(.system(size: 11.5, weight: .bold))
                                        .foregroundColor(.primary.opacity(0.88))
                                    
                                    LiveSpokenTextView(
                                        text: item.definitionEn,
                                        speakerID: "def_\(group.partOfSpeech)_\(index)",
                                        font: .system(size: 11.5, weight: .semibold),
                                        defaultColor: .primary.opacity(0.88)
                                    )
                                    
                                    Button(action: {
                                        viewModel.speakCustom(text: item.definitionEn, languageCode: "en-US", speakerID: "def_\(group.partOfSpeech)_\(index)")
                                    }) {
                                        Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "def_\(group.partOfSpeech)_\(index)") ? "speaker.wave.3.fill" : "speaker.wave.1")
                                            .font(.system(size: 9))
                                            .foregroundColor(.blue.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Vietnamese Translation
                                if let vi = item.definitionVi, !vi.isEmpty {
                                    HStack(alignment: .top, spacing: 3) {
                                        Text("👉")
                                            .font(.system(size: 10.5))
                                        LiveSpokenTextView(
                                            text: vi,
                                            speakerID: "def_vi_\(group.partOfSpeech)_\(index)",
                                            font: .system(size: 11, weight: .medium),
                                            defaultColor: .blue
                                        )
                                    }
                                }
                                
                                // Example in English & Vietnamese
                                if AppSettings.shared.showExamples {
                                    if let exEn = item.exampleEn, !exEn.isEmpty {
                                        HStack(alignment: .top, spacing: 4) {
                                            Text("\"")
                                                .font(.system(size: 10.5))
                                                .foregroundColor(.secondary)
                                            LiveSpokenTextView(
                                                text: exEn,
                                                speakerID: "ex_\(group.partOfSpeech)_\(index)",
                                                font: .system(size: 10.5, design: .serif),
                                                defaultColor: .secondary
                                            )
                                            Text("\"")
                                                .font(.system(size: 10.5))
                                                .foregroundColor(.secondary)
                                            
                                            Button(action: {
                                                viewModel.speakCustom(text: exEn, languageCode: "en-US", speakerID: "ex_\(group.partOfSpeech)_\(index)")
                                            }) {
                                                Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "ex_\(group.partOfSpeech)_\(index)") ? "speaker.wave.3.fill" : "speaker.wave.1")
                                                    .font(.system(size: 8.5))
                                                    .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .italic()
                                        .padding(.leading, 6)
                                    }
                                    
                                    if let exVi = item.exampleVi, !exVi.isEmpty {
                                        Text("= \(exVi)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary.opacity(0.8))
                                            .padding(.leading, 6)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Group Synonyms Tags
                    if AppSettings.shared.showSynonyms && !group.synonyms.isEmpty {
                        synonymTagSection(title: "Từ đồng nghĩa:", tags: group.synonyms)
                    }
                }
                .padding(8)
                .background(Color.primary.opacity(0.025))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
            }
            
            // All Synonyms Section
            if AppSettings.shared.showSynonyms && !entry.allSynonyms.isEmpty {
                synonymTagSection(title: "Từ đồng nghĩa (Synonyms):", tags: entry.allSynonyms)
            }
            
            // All Antonyms Section
            if AppSettings.shared.showSynonyms && !entry.allAntonyms.isEmpty {
                synonymTagSection(title: "Từ trái nghĩa (Antonyms):", tags: entry.allAntonyms)
            }
        }
    }
    
    // MARK: - Dictionary Loading Skeleton
    private var dictionaryLoadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(viewModel.originalText.capitalized)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
                
                Spacer()
            }
            
            Text(viewModel.translatedText.isEmpty ? "Đang phân tích từ điển..." : viewModel.translatedText)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(viewModel.translatedText.isEmpty ? .secondary : .blue)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.07))
                    .frame(width: 100, height: 16)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.05))
                    .frame(maxWidth: .infinity, maxHeight: 12)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.05))
                    .frame(width: 200, height: 12)
            }
            .padding(10)
            .background(Color.primary.opacity(0.025))
            .cornerRadius(6)
        }
    }
    
    // MARK: - Dictionary Fallback View
    private var dictionaryFallbackView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                LiveSpokenTextView(
                    text: viewModel.originalText.capitalized,
                    speakerID: "original",
                    font: .system(size: 16, weight: .bold),
                    defaultColor: .primary
                )
                
                Button(action: {
                    viewModel.speakOriginal()
                }) {
                    Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "original") ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            
            LiveSpokenTextView(
                text: viewModel.translatedText.isEmpty ? "—" : viewModel.translatedText,
                speakerID: "translated",
                font: .system(size: 14, weight: .bold),
                defaultColor: .blue
            )
            
            if let def = viewModel.definition, !def.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "book.fill")
                            .font(.system(size: 9.5))
                            .foregroundColor(.orange)
                        Text("TỪ ĐIỂN MACOS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.orange)
                    }
                    Text(def)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .padding(8)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(6)
            }
        }
    }
    
    // MARK: - Synonym / Antonym Tags Section
    private func synonymTagSection(title: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
            
            WrappingHStack(models: tags) { tag in
                Button(action: {
                    viewModel.processText(tag)
                }) {
                    Text(tag)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
    }
    
    // MARK: - Sentence & Long Paragraph Translation View
    private var sentenceTranslationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mode Switcher Header
            HStack {
                // Mode Selector Chips
                HStack(spacing: 4) {
                    ForEach(TranslationDisplayMode.allCases) { mode in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                AppSettings.shared.translationDisplayMode = mode
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 9))
                                Text(mode.shortName)
                                    .font(.system(size: 10, weight: AppSettings.shared.translationDisplayMode == mode ? .bold : .medium))
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .foregroundColor(AppSettings.shared.translationDisplayMode == mode ? .white : .secondary)
                            .background(
                                AppSettings.shared.translationDisplayMode == mode ? Color.blue : Color.primary.opacity(0.04)
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // AI Grammar & Vocab Extraction Button
                Button(action: {
                    TextAnalysisWindowController.shared.showAnalysis(text: viewModel.originalText)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 9))
                        Text("AI Bóc Tách")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("AI tự động bóc tách từ vựng trọng tâm và công thức ngữ pháp để lưu vào Sổ tay")
                
                Text("\(viewModel.originalText.split(separator: " ").count) từ")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(.bottom, 2)
            
            // Content based on selected mode
            switch AppSettings.shared.translationDisplayMode {
            case .wordByWord:
                wordByWordSentenceTranslationView
            case .onlyTarget:
                onlyTargetSentenceTranslationView
            case .standard:
                standardSentenceTranslationView
            }
        }
    }
    
    // MARK: - Mode 1: Dịch Từng Từ Tương Ứng (Tiếng Anh trên - Tiếng Việt nhỏ dưới từng từ - Gộp 1 khung duy nhất)
    private var wordByWordSentenceTranslationView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Bar
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "character.bubble.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text("DỊCH TỪNG TỪ TƯƠNG ỨNG")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 10, height: 10)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.speakOriginal()
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "original") ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 9))
                        Text("Đọc TA")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.primary.opacity(0.06))
                    .foregroundColor(.secondary)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Nghe phát âm tiếng Anh")
                
                Button(action: {
                    viewModel.speakTranslated()
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "translated") ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 9))
                        Text("Đọc TV")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    viewModel.copyTranslation()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        copied = false
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                        Text(copied ? "Đã chép" : "Sao chép")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            
            // 1. Continuous Interlinear Word Flow (English on top, Small Vietnamese directly below)
            if !viewModel.wordGlosses.isEmpty {
                WrappingHStack(models: viewModel.wordGlosses) { item in
                    Button(action: {
                        viewModel.speakCustom(text: item.cleanWord, languageCode: "en-US", speakerID: "wbw_\(item.id)")
                    }) {
                        VStack(alignment: .center, spacing: 2) {
                            // Chữ Tiếng Anh ở trên
                            Text(item.original)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            // Nghĩa Tiếng Việt nhỏ ngay dưới
                            Text(item.gloss.isEmpty ? " " : item.gloss)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(.blue)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Bấm để nghe đọc từ [\(item.cleanWord)]")
                }
            } else {
                LiveSpokenTextView(
                    text: viewModel.originalText,
                    speakerID: "original",
                    font: .system(size: 12),
                    defaultColor: .primary,
                    lineSpacing: 3.5
                )
            }
            
            Divider()
                .opacity(0.25)
            
            // 2. Full Natural Translation integrated into the bottom of the same card
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9))
                        .foregroundColor(.blue)
                    Text("Bản dịch trọn vẹn:")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                if viewModel.translatedText.isEmpty && viewModel.isLoading {
                    Text("Đang dịch thông minh bằng AI...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    LiveSpokenTextView(
                        text: viewModel.translatedText.isEmpty ? "—" : viewModel.translatedText,
                        speakerID: "translated",
                        font: .system(size: 12.5, weight: .regular),
                        defaultColor: .primary,
                        lineSpacing: 3.5
                    )
                }
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.06))
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        )
    }
    
    // MARK: - Mode 2: Chỉ hiển thị Tiếng Việt
    private var onlyTargetSentenceTranslationView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text("BẢN DỊCH TIẾNG VIỆT")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 10, height: 10)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.speakTranslated()
                }) {
                    Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "translated") ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 10.5))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Nghe bản dịch")
                
                Button(action: {
                    viewModel.copyTranslation()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        copied = false
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                        Text(copied ? "Đã chép" : "Sao chép")
                            .font(.system(size: 9.5, weight: .medium))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                if viewModel.translatedText.isEmpty && viewModel.isLoading {
                    Text("Đang dịch thông minh bằng AI...")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.vertical, 4)
                } else {
                    LiveSpokenTextView(
                        text: viewModel.translatedText.isEmpty ? "—" : viewModel.translatedText,
                        speakerID: "translated",
                        font: .system(size: 13.5, weight: .medium),
                        defaultColor: .primary,
                        lineSpacing: 4.5
                    )
                }
            }
            .padding(12)
            .background(Color.blue.opacity(0.07))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.18), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Mode 3: Tiêu chuẩn (2 Thẻ Gốc & Dịch)
    private var standardSentenceTranslationView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Original Text Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("VĂN BẢN GỐC")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.speakOriginal()
                    }) {
                        Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "original") ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 10.5))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Nghe phát âm")
                }
                
                LiveSpokenTextView(
                    text: viewModel.originalText,
                    speakerID: "original",
                    font: .system(size: 12),
                    defaultColor: .primary,
                    lineSpacing: 3.5
                )
            }
            .padding(10)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(8)
            
            // Translated Text Card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("BẢN DỊCH AI")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.blue)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.55)
                            .frame(width: 10, height: 10)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.speakTranslated()
                    }) {
                        Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "translated") ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 10.5))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Nghe bản dịch")
                    
                    Button(action: {
                        viewModel.copyTranslation()
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            copied = false
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 9))
                            Text(copied ? "Đã chép" : "Sao chép")
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                
                if viewModel.translatedText.isEmpty && viewModel.isLoading {
                    Text("Đang dịch thông minh bằng AI...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.vertical, 4)
                } else {
                    LiveSpokenTextView(
                        text: viewModel.translatedText.isEmpty ? "—" : viewModel.translatedText,
                        speakerID: "translated",
                        font: .system(size: 12.5, weight: .regular),
                        defaultColor: .primary,
                        lineSpacing: 4
                    )
                }
            }
            .padding(11)
            .background(Color.blue.opacity(0.07))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.18), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 6) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Chọn một từ hoặc nhập từ cần tra cứu")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 90)
    }
    
    // MARK: - Bottom Input Bar
    private var bottomInputBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 11))
            
            TextField("Nhập từ hoặc câu cần dịch...", text: $manualInput)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .onSubmit {
                    if !manualInput.isEmpty {
                        viewModel.processText(manualInput)
                        manualInput = ""
                    }
                }
            
            if !manualInput.isEmpty {
                Button(action: {
                    viewModel.processText(manualInput)
                    manualInput = ""
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            Text("ESC")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }
}

// MARK: - Live Spoken Text View with Real-time Word Highlight
struct LiveSpokenTextView: View {
    let text: String
    let speakerID: String
    @ObservedObject var speechService = SpeechService.shared
    var font: Font = .system(size: 12)
    var defaultColor: Color = .primary
    var lineSpacing: CGFloat = 3.5
    
    var body: some View {
        Text(attributedText)
            .font(font)
            .lineSpacing(lineSpacing)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .animation(.easeInOut(duration: 0.08), value: speechService.spokenRange)
    }
    
    private var attributedText: AttributedString {
        var attr = AttributedString(text)
        attr.foregroundColor = defaultColor
        
        if speechService.isSpeaking && speechService.currentSpeakerID == speakerID,
           let nsRange = speechService.spokenRange,
           let swiftRange = Range(nsRange, in: text) {
            
            if let lower = AttributedString.Index(swiftRange.lowerBound, within: attr),
               let upper = AttributedString.Index(swiftRange.upperBound, within: attr) {
                attr[lower..<upper].backgroundColor = Color.blue.opacity(0.3)
                attr[lower..<upper].foregroundColor = Color.blue
                attr[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
            }
        }
        return attr
    }
}

// MARK: - Wrapping HStack for Tags
struct WrappingHStack<Model: Hashable, V: View>: View {
    let models: [Model]
    let viewGenerator: (Model) -> V
    
    @State private var totalHeight: CGFloat = .zero
    
    var body: some View {
        VStack {
            GeometryReader { geometry in
                self.generateContent(in: geometry)
            }
        }
        .frame(height: totalHeight)
    }
    
    private func generateContent(in g: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return ZStack(alignment: .topLeading) {
            ForEach(self.models, id: \.self) { model in
                self.viewGenerator(model)
                    .padding([.horizontal, .vertical], 2)
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > g.size.width) {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if model == self.models.last! {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { _ in
                        let result = height
                        if model == self.models.last! {
                            height = 0
                        }
                        return result
                    })
            }
        }
        .background(viewHeightReader($totalHeight))
    }
    
    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        return GeometryReader { geometry -> Color in
            let rect = geometry.frame(in: .local)
            DispatchQueue.main.async {
                binding.wrappedValue = rect.size.height
            }
            return .clear
        }
    }
}

// MARK: - AppKit Visual Effect Background
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Translation ViewModifier for macOS 15+
#if canImport(Translation)
struct TranslationModifier: ViewModifier {
    @ObservedObject var viewModel: TranslationViewModel
    
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content
                .translationTask(viewModel.translationConfig) { session in
                    let text = viewModel.originalText
                    do {
                        let response = try await session.translate(text)
                        await MainActor.run {
                            viewModel.setTranslatedText(response.targetText)
                        }
                    } catch {
                        print("Native translation session error: \(error)")
                        await viewModel.runFallbackTranslation()
                    }
                }
        } else {
            content
        }
    }
}
#endif

// MARK: - SwiftUI Previews
#Preview("Word Lookup Mode") {
    let vm: TranslationViewModel = {
        let v = TranslationViewModel()
        v.originalText = "Serendipity"
        v.detectedLanguage = "en"
        v.translatedText = "Sự tình cờ may mắn"
        v.richEntry = RichWordEntry(
            word: "Serendipity",
            phonetic: "/ˌser.ənˈdɪp.ə.t̬i/",
            mainTranslation: "Sự tình cờ may mắn, khả năng tìm thấy những điều bất ngờ thú vị",
            meanings: [
                MeaningGroup(
                    partOfSpeech: "noun",
                    definitions: [
                        DefinitionItem(
                            definitionEn: "The occurrence and development of events by chance in a happy or beneficial way.",
                            definitionVi: "Sự xảy ra và phát triển của các sự việc một cách tình cờ theo chiều hướng may mắn hoặc có lợi.",
                            exampleEn: "A fortunate stroke of serendipity brought them together.",
                            exampleVi: "Một cơ duyên tình cờ may mắn đã đưa họ đến với nhau."
                        )
                    ],
                    synonyms: ["chance", "fluke", "fortune"],
                    antonyms: []
                )
            ],
            allSynonyms: ["chance", "coincidence", "fortune", "luck", "providence"],
            allAntonyms: ["misfortune", "bad luck"]
        )
        return v
    }()
    
    TranslationHUDView(viewModel: vm, onClose: {})
        .padding()
}

#Preview("Sentence Translation Mode") {
    let vm: TranslationViewModel = {
        let v = TranslationViewModel()
        v.originalText = "Artificial intelligence is transforming how people work and learn every day."
        v.detectedLanguage = "en"
        v.translatedText = "Trí tuệ nhân tạo đang thay đổi cách mọi người làm việc và học tập mỗi ngày."
        return v
    }()
    
    TranslationHUDView(viewModel: vm, onClose: {})
        .padding()
}

#Preview("Loading State") {
    let vm: TranslationViewModel = {
        let v = TranslationViewModel()
        v.originalText = "Innovation"
        v.isLoading = true
        return v
    }()
    
    TranslationHUDView(viewModel: vm, onClose: {})
        .padding()
        .background(.white)
}
