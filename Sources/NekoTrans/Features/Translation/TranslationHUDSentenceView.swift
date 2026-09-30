import SwiftUI
import NaturalLanguage

public struct TranslationHUDSentenceView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @ObservedObject var speechService = SpeechService.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var copied: Bool = false

    @State private var showGrammarPanel: Bool = false
    @State private var showTonePicker: Bool = false

    public init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mode Switcher & Tools Header
            HStack(spacing: 6) {
                // Display Mode Segmented Pills
                HStack(spacing: 2) {
                    ForEach(TranslationDisplayMode.allCases) { mode in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                settings.translationDisplayMode = mode
                            }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 8.5))
                                Text(mode.shortName)
                                    .font(settings.translationDisplayMode == mode ? .system(size: 10, weight: .bold) : .system(size: 10, weight: .medium))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .foregroundColor(settings.translationDisplayMode == mode ? .white : .secondary)
                            .background(
                                settings.translationDisplayMode == mode ? AppColors.accent : Color.primary.opacity(0.04)
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .fixedSize()
                    }
                }

                Spacer(minLength: 4)

                // AI Tone Switcher Menu
                Menu {
                    ForEach(TranslationTone.allCases) { tone in
                        Button(action: {
                            viewModel.translationTone = tone
                        }) {
                            if viewModel.translationTone == tone {
                                Label("\(tone.rawValue) (Đang chọn)", systemImage: "checkmark")
                            } else {
                                Label(tone.rawValue, systemImage: tone.icon)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: viewModel.translationTone.icon)
                            .font(.system(size: 8.5))
                        Text(viewModel.translationTone.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Thay đổi văn phong dịch thuật (Học thuật, Kinh tế, Thân mật, IT)")

                // Grammar & Polish Toggle Button
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showGrammarPanel.toggle()
                        if showGrammarPanel && viewModel.grammarRewriteResult == nil && !viewModel.isAnalyzingGrammar {
                            viewModel.analyzeSentenceGrammar()
                        }
                    }
                }) {
                    HStack(spacing: 3) {
                        if viewModel.isAnalyzingGrammar {
                            ProgressView()
                                .scaleEffect(0.4)
                                .frame(width: 8, height: 8)
                        } else {
                            Image(systemName: "pencil.line")
                                .font(.system(size: 8.5))
                        }
                        Text("Sửa & Viết lại")
                            .font(.system(size: 10, weight: .bold))
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(showGrammarPanel ? Color.orange.opacity(0.2) : Color.orange.opacity(0.08))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help("Kiểm tra ngữ pháp & gợi ý 3 cách diễn đạt chuẩn bản xứ")
            }
            .padding(.bottom, 2)

            // In-Context Word Inspection Card (When a word inside the sentence is clicked)
            if let inspected = viewModel.inspectedWordToken {
                inspectedWordCard(token: inspected)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // AI Grammar & Rephrasing Suggestions Card
            if showGrammarPanel {
                grammarAndPolishingCard
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Main Translation View Modes
            switch settings.translationDisplayMode {
            case .wordByWord:
                wordByWordView
            case .onlyTarget:
                onlyTargetView
            case .standard:
                standardView
            case .syntax:
                syntaxHighlightingView
            }
        }
    }

    // MARK: - In-Sentence Inspected Word Popover Card
    private func inspectedWordCard(token: (word: String, explanation: String)) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                    Text("NGỮ CẢNH TỪ: '\(token.word)'")
                        .font(.appSubcaptionBold)
                        .foregroundColor(AppColors.accent)
                }

                Spacer()

                Button(action: {
                    viewModel.speakCustom(text: token.word, speakerID: "word_\(token.word)")
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 9.5))
                        .foregroundColor(AppColors.accent)
                }
                .buttonStyle(.plain)
                .help("Nghe phát âm từ này")

                Button(action: {
                    VocabularyService.shared.toggleSaveWord(
                        word: token.word,
                        phonetic: DictionaryService.shared.extractPhonetic(for: token.word),
                        translation: token.explanation
                    )
                }) {
                    Image(systemName: VocabularyService.shared.isWordSaved(token.word) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 9.5))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help("Lưu từ vào Sổ tay")

                Button(action: {
                    withAnimation { viewModel.dismissInspectedWord() }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(token.explanation)
                .font(.appSubcaption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .padding(9)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - AI Grammar Checking & 3-Tone Polishing Card
    private var grammarAndPolishingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "text.badge.checkmark")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                    Text("KIỂM TRA NGỮ PHÁP & ĐỀ XUẤT VIẾT LẠI")
                        .font(.appSubcaptionBold)
                        .foregroundColor(.orange)
                }

                Spacer()

                Button(action: {
                    viewModel.analyzeSentenceGrammar()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Phân tích lại")

                Button(action: {
                    withAnimation { showGrammarPanel = false }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            if viewModel.isAnalyzingGrammar {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 12, height: 12)
                    Text("Đang phân tích ngữ pháp và cấu trúc câu...")
                        .font(.appSubcaption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } else if let result = viewModel.grammarRewriteResult {
                // 1. Error Status & Correction
                if result.hasErrors {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("⚠️ Phát hiện điểm cần sửa:")
                                .font(.appSubcaptionBold)
                                .foregroundColor(.red)
                            Spacer()
                            Button(action: {
                                viewModel.applyCorrection(result.correction)
                            }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 8.5))
                                    Text("Áp dụng sửa")
                                        .font(.appSubcaptionBold)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)
                        }

                        Text(result.correction)
                            .font(.appBodyBold)
                            .foregroundColor(.primary)

                        if !result.explanationVi.isEmpty {
                            Text("• \(result.explanationVi)")
                                .font(.appSubcaption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(Color.red.opacity(0.06))
                    .cornerRadius(6)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 11))
                        Text("Cấu trúc ngữ pháp chuẩn xác!")
                            .font(.appSubcaptionBold)
                            .foregroundColor(.green)
                    }
                }

                // 2. Three Stylistic Rephrasings
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gợi ý diễn đạt tự nhiên theo văn phong:")
                        .font(.appSubcaptionBold)
                        .foregroundColor(.secondary)

                    if !result.academicVersion.isEmpty {
                        rephraseOptionRow(
                            label: "Học thuật / IELTS",
                            text: result.academicVersion,
                            badgeColor: .blue
                        )
                    }
                    if !result.businessVersion.isEmpty {
                        rephraseOptionRow(
                            label: "Công việc / Formal",
                            text: result.businessVersion,
                            badgeColor: .purple
                        )
                    }
                    if !result.casualVersion.isEmpty {
                        rephraseOptionRow(
                            label: "Thân mật / Giao tiếp",
                            text: result.casualVersion,
                            badgeColor: .green
                        )
                    }
                }
            } else {
                Text("Bấm 'Sửa & Viết lại' để kiểm tra lỗi và nhận các phương án diễn đạt tự nhiên hơn.")
                    .font(.appSubcaption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.04))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private func rephraseOptionRow(label: String, text: String, badgeColor: Color) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(badgeColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(badgeColor.opacity(0.12))
                .cornerRadius(3)
                .frame(width: 95, alignment: .leading)

            Text(text)
                .font(.appSubcaption)
                .foregroundColor(.primary)
                .lineLimit(2)

            Spacer()

            NekoCopyButton(textToCopy: text, iconOnly: true)
        }
        .padding(.vertical, 1.5)
    }

    // MARK: - Mode 1: Dịch từng từ tương ứng
    private var wordByWordView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "character.bubble.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                    Text("DỊCH TỪNG TỪ TƯƠNG ỨNG")
                        .font(.appSubcaptionBold)
                        .foregroundColor(AppColors.accent)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 10, height: 10)
                }

                Spacer()

                Button(action: { viewModel.speakOriginal() }) {
                    HStack(spacing: 3) {
                        EqualizerWaveView(
                            isActive: speechService.isSpeaking && speechService.currentSpeakerID == "original",
                            barColor: .secondary,
                            height: 9
                        )
                        Text("Đọc TA")
                            .font(.appSubcaption)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(AppColors.tagBackground)
                    .foregroundColor(.secondary)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.speakTranslated() }) {
                    HStack(spacing: 3) {
                        EqualizerWaveView(
                            isActive: speechService.isSpeaking && speechService.currentSpeakerID == "translated",
                            barColor: AppColors.accent,
                            height: 9
                        )
                        Text("Đọc TV")
                            .font(.appSubcaption)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(AppColors.accentSubtle)
                    .foregroundColor(AppColors.accent)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Button(action: {
                    viewModel.copyTranslation()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                        Text(copied ? "Đã chép" : "Sao chép")
                            .font(.appSubcaption)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(AppColors.accentSubtle)
                    .foregroundColor(AppColors.accent)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            if !viewModel.wordGlosses.isEmpty {
                WrappingHStack(models: viewModel.wordGlosses) { item in
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            viewModel.inspectWordInSentence(word: item.cleanWord)
                        }
                    }) {
                        VStack(alignment: .center, spacing: 2) {
                            Text(item.original)
                                .font(.appBodyBold)
                                .foregroundColor(.primary)
                                .lineLimit(1)

                            Text(item.gloss.isEmpty ? " " : item.gloss)
                                .font(.appSubcaption)
                                .foregroundColor(AppColors.accent)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(AppColors.accent.opacity(0.06))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(AppColors.accent.opacity(0.15), lineWidth: 0.8)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Bấm để tra cứu chi tiết từ '\(item.cleanWord)'")
                }
            } else {
                LiveSpokenTextView(
                    text: viewModel.originalText,
                    speakerID: "original",
                    font: .appBody,
                    defaultColor: .primary,
                    lineSpacing: 3.5
                )
            }

            Divider().opacity(0.2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 9))
                        .foregroundColor(AppColors.accent)
                    Text("Bản dịch trọn vẹn:")
                        .font(.appSubcaptionBold)
                        .foregroundColor(.secondary)
                }

                if viewModel.translatedText.isEmpty && viewModel.isLoading {
                    Text("Đang dịch thuật...")
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    LiveSpokenTextView(
                        text: viewModel.translatedText.isEmpty ? "—" : viewModel.translatedText,
                        speakerID: "translated",
                        font: .appBodyMedium,
                        defaultColor: .primary,
                        lineSpacing: 3.5
                    )
                }
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(AppColors.accent.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Mode 2: Chỉ Tiếng Việt
    private var onlyTargetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                    Text("BẢN DỊCH TIẾNG VIỆT")
                        .font(.appSubcaptionBold)
                        .foregroundColor(AppColors.accent)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.55)
                        .frame(width: 10, height: 10)
                }

                Spacer()

                Button(action: { viewModel.speakTranslated() }) {
                    Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "translated") ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 10.5))
                        .foregroundColor(AppColors.accent)
                }
                .buttonStyle(.plain)
                .help("Nghe bản dịch")

                Button(action: {
                    viewModel.copyTranslation()
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                        Text(copied ? "Đã chép" : "Sao chép")
                            .font(.appSubcaption)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AppColors.accentSubtle)
                    .foregroundColor(AppColors.accent)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                if viewModel.translatedText.isEmpty && viewModel.isLoading {
                    Text("Đang dịch thuật...")
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.vertical, 4)
                } else {
                    LiveSpokenTextView(
                        text: viewModel.translatedText.isEmpty ? "—" : viewModel.translatedText,
                        speakerID: "translated",
                        font: .appHeadline,
                        defaultColor: .primary,
                        lineSpacing: 4.5
                    )
                }
            }
            .padding(12)
            .background(AppColors.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.accent.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Mode 3: Tiêu chuẩn (Dual-Card Layout)
    private var standardView: some View {
        VStack(alignment: .leading, spacing: 9) {
            // 1. Original Text Card (Source)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.secondary.opacity(0.6))
                            .frame(width: 5, height: 5)
                        Text("VĂN BẢN GỐC (\(viewModel.detectedLanguage.uppercased()))")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { viewModel.speakOriginal() }) {
                        Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "original") ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Nghe phát âm văn bản gốc")

                    NekoCopyButton(textToCopy: viewModel.originalText, iconOnly: true)
                }

                LiveSpokenTextView(
                    text: viewModel.originalText,
                    speakerID: "original",
                    font: .system(size: 12.5),
                    defaultColor: .primary.opacity(0.88),
                    lineSpacing: 3.5
                )
            }
            .padding(10)
            .background(Color.primary.opacity(0.025))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.8)
            )

            // 2. Translated Text Card (Target Result)
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 5, height: 5)
                        Text("BẢN DỊCH (\(viewModel.targetLanguage.displayName.uppercased()))")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(AppColors.accent)
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 10, height: 10)
                    }

                    Spacer()

                    Button(action: { viewModel.speakTranslated() }) {
                        Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "translated") ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Nghe bản dịch")

                    Button(action: { viewModel.toggleBookmark() }) {
                        Image(systemName: viewModel.isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .help(viewModel.isBookmarked ? "Bỏ lưu câu này" : "Lưu câu vào sổ từ vựng")
                }

                if viewModel.translatedText.isEmpty && viewModel.isLoading {
                    Text("Đang dịch thuật...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.vertical, 4)
                } else {
                    LiveSpokenTextView(
                        text: viewModel.translatedText.isEmpty ? "—" : viewModel.translatedText,
                        speakerID: "translated",
                        font: .system(size: 13.5, weight: .semibold),
                        defaultColor: .primary,
                        lineSpacing: 4
                    )
                }

                // Action Bar under translated text
                HStack {
                    Spacer()

                    NekoCopyButton(
                        textToCopy: viewModel.translatedText,
                        label: "Sao chép bản dịch",
                        copiedLabel: "Đã chép bản dịch",
                        font: .system(size: 10, weight: .medium),
                        cornerRadius: 5,
                        horizontalPadding: 8,
                        verticalPadding: 3.5
                    )
                }
                .padding(.top, 2)
            }
            .padding(11)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.accent.opacity(0.2), lineWidth: 0.9)
            )
        }
    }

    // MARK: - Mode 4: 🌈 Tô màu cú pháp ngữ pháp trực quan (Apple NLP Syntax Highlighting)
    private var syntaxHighlightingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Bar
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                    Text("PHÂN TÍCH CÚ PHÁP NGỮ PHÁP (APPLE NLP)")
                        .font(.appSubcaptionBold)
                        .foregroundColor(AppColors.accent)
                }

                Spacer()

                Button(action: { viewModel.speakOriginal() }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Syntax Colorized Words Flow
            let taggedTokens = analyzeSyntax(text: viewModel.originalText)
            WrappingHStack(models: taggedTokens) { item in
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        viewModel.inspectWordInSentence(word: item.word)
                    }
                }) {
                    VStack(alignment: .center, spacing: 2) {
                        Text(item.word)
                            .font(.appBodyBold)
                            .foregroundColor(item.color)
                        Text(item.tagLabel)
                            .font(.appSubcaptionBold)
                            .foregroundColor(item.color.opacity(0.85))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(item.color.opacity(0.08))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Bấm để xem giải thích từ '\(item.word)' trong ngữ cảnh")
            }

            // Legend Footer
            HStack(spacing: 8) {
                syntaxLegendItem(label: "Danh từ", color: AppColors.accent)
                syntaxLegendItem(label: "Động từ", color: AppColors.destructive)
                syntaxLegendItem(label: "Tính từ", color: AppColors.success)
                syntaxLegendItem(label: "Trạng từ", color: AppColors.warning)
                syntaxLegendItem(label: "Giới từ/Liên từ", color: .purple)
            }
            .padding(.top, 4)

            Divider().opacity(0.2)

            // Natural Translation at bottom
            VStack(alignment: .leading, spacing: 3) {
                Text("Bản dịch:")
                    .font(.appSubcaptionBold)
                    .foregroundColor(.secondary)
                LiveSpokenTextView(
                    text: viewModel.translatedText.isEmpty ? "—" : viewModel.translatedText,
                    speakerID: "translated",
                    font: .appBody,
                    defaultColor: .primary
                )
            }
        }
        .padding(12)
        .background(AppColors.cardBackground)
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.purple.opacity(0.18), lineWidth: 1)
        )
    }

    private func syntaxLegendItem(label: String, color: Color) -> some View {
        HStack(spacing: 2.5) {
            Circle()
                .fill(color)
                .frame(width: 5.5, height: 5.5)
            Text(label)
                .font(.appSubcaption)
                .foregroundColor(.secondary)
        }
    }

    private struct TaggedToken: Hashable, Identifiable {
        let id = UUID()
        let word: String
        let tagLabel: String
        let color: Color
    }

    private func analyzeSyntax(text: String) -> [TaggedToken] {
        var results: [TaggedToken] = []
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text

        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            let word = String(text[range])
            let (label, color) = mapNLTag(tag)
            results.append(TaggedToken(word: word, tagLabel: label, color: color))
            return true
        }

        if results.isEmpty {
            return text.split(separator: " ").map {
                TaggedToken(word: String($0), tagLabel: "WORD", color: .primary)
            }
        }
        return results
    }

    private func mapNLTag(_ tag: NLTag?) -> (String, Color) {
        guard let tag = tag else { return ("OTHER", .secondary) }
        switch tag {
        case .noun:
            return ("NOUN", AppColors.accent)
        case .verb:
            return ("VERB", AppColors.destructive)
        case .adjective:
            return ("ADJ", AppColors.success)
        case .adverb:
            return ("ADV", AppColors.warning)
        case .pronoun:
            return ("PRON", AppColors.accent)
        case .preposition:
            return ("PREP", .purple)
        case .conjunction:
            return ("CONJ", .purple)
        case .particle:
            return ("PART", .indigo)
        case .determiner:
            return ("DET", .teal)
        default:
            return (tag.rawValue.uppercased(), .secondary)
        }
    }
}
