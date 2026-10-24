import SwiftUI
import NaturalLanguage
import Defaults

public struct TranslationHUDSentenceView: View {
    var viewModel: TranslationViewModel
    @ObservedObject var speechService = SpeechService.shared
    var settings = AppSettings.shared
    @State private var copied: Bool = false

    @State private var showGrammarPanel: Bool = false
    @State private var showTonePicker: Bool = false

    public init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Mode Switcher & Tools Header
            HStack(spacing: 5) {
                modeSwitcherCapsule

                Spacer(minLength: 4)

                // Multi-Engine Comparison Button
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        viewModel.isComparisonMode.toggle()
                        if viewModel.isComparisonMode && viewModel.comparisonResults.isEmpty {
                            viewModel.performComparison()
                        }
                    }
                }) {
                    HStack(spacing: 2.5) {
                        Image(systemName: "square.split.2x1")
                            .font(.system(size: 8.5))
                        Text("So sánh")
                            .font(.system(size: 9.5, weight: (viewModel.isComparisonMode || Defaults[.enableHUDMultiEngine]) ? .bold : .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 3)
                    .background((viewModel.isComparisonMode || Defaults[.enableHUDMultiEngine]) ? Color.blue.opacity(0.2) : Color.blue.opacity(0.08))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help("So sánh song song kết quả từ Google Translate, DeepL và AI")
                .accessibilityLabel((viewModel.isComparisonMode || Defaults[.enableHUDMultiEngine]) ? "Tắt so sánh đa động cơ" : "So sánh kết quả đa động cơ")
                .accessibilityHint("Nhấn để so sánh song song bản dịch giữa Google Translate, DeepL và AI")
                .accessibilityAddTraits((viewModel.isComparisonMode || Defaults[.enableHUDMultiEngine]) ? [.isButton, .isSelected] : .isButton)

                // Grammar & Polish Toggle Button
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showGrammarPanel.toggle()
                        if showGrammarPanel && viewModel.grammarRewriteResult == nil && !viewModel.isAnalyzingGrammar {
                            viewModel.analyzeSentenceGrammar()
                        }
                    }
                }) {
                    HStack(spacing: 2.5) {
                        if viewModel.isAnalyzingGrammar {
                            ProgressView()
                                .scaleEffect(0.4)
                                .frame(width: 8, height: 8)
                        } else {
                            Image(systemName: "pencil.line")
                                .font(.system(size: 8.5))
                        }
                        Text("Viết lại")
                            .font(.system(size: 9.5, weight: .bold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 3)
                    .background(showGrammarPanel ? Color.orange.opacity(0.2) : Color.orange.opacity(0.08))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .fixedSize()
                .help("Kiểm tra ngữ pháp & gợi ý 3 cách diễn đạt chuẩn bản xứ")
                .accessibilityLabel(showGrammarPanel ? "Đóng bảng kiểm tra ngữ pháp và viết lại" : "Kiểm tra ngữ pháp và gợi ý viết lại")
                .accessibilityHint("Nhấn để AI phân tích cấu trúc ngữ pháp và gợi ý các cách diễn đạt tự nhiên hơn")
                .accessibilityAddTraits(showGrammarPanel ? [.isButton, .isSelected] : .isButton)
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
            case .standard:
                standardView
            case .onlyTarget:
                onlyTargetView
            }
        }
    }

    // MARK: - Mode Switcher Controls
    private var modeSwitcherCapsule: some View {
        HStack(spacing: 1.5) {
            ForEach(TranslationDisplayMode.allCases) { mode in
                modeButton(for: mode)
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.04))
        .clipShape(Capsule())
    }

    private func modeButton(for mode: TranslationDisplayMode) -> some View {
        let isSelected = settings.translationDisplayMode == mode
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                settings.translationDisplayMode = mode
            }
        }) {
            HStack(spacing: 2.5) {
                Image(systemName: mode.icon)
                    .font(.system(size: 8))
                Text(mode.shortName)
                    .font(.system(size: 9.5, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 5.5)
            .padding(.vertical, 3)
            .foregroundColor(isSelected ? .white : .secondary)
            .background(isSelected ? AppColors.accent : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help(mode.rawValue)
        .accessibilityLabel("Chế độ hiển thị: \(mode.shortName)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Nhấn để chuyển sang chế độ hiển thị \(mode.rawValue)")
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

    private var engineAttributionBadge: some View {
        HStack(spacing: 4) {
            if viewModel.isStreaming {
                Image(systemName: "cpu.fill")
                    .font(.system(size: 8))
                    .foregroundColor(AppColors.accent)
                Text("AI đang tạo câu trả lời...")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(AppColors.accent)
            } else {
                Image(systemName: viewModel.selectedEngine == .directAI ? "cpu.fill" : "globe")
                    .font(.system(size: 8))
                Text("Dịch bởi: \(viewModel.activeEngineLabel.isEmpty ? (viewModel.selectedEngine == .directAI ? "AI Engine" : viewModel.selectedEngine.rawValue) : viewModel.activeEngineLabel)")
                    .font(.system(size: 9.5, weight: .medium))
            }
            Spacer()
        }
        .foregroundColor(.secondary.opacity(0.8))
        .padding(.top, 2)
    }

    // MARK: - Mode 2: Chỉ Tiếng Việt
    private var onlyTargetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Source Text Preview Banner (Crucial for OCR Option+S to verify recognized text)
            if !viewModel.originalText.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.quote")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                        .padding(.top, 1)

                    Text(viewModel.originalText)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    Spacer(minLength: 4)

                    HStack(spacing: 5) {
                        Button(action: { viewModel.speakOriginal() }) {
                            Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "original") ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .font(.system(size: 9.5))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Nghe câu gốc")

                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(viewModel.originalText, forType: .string)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Sao chép câu gốc")
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.8)
                )
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.accent)
                    Text("BẢN DỊCH TIẾNG VIỆT")
                        .font(.appSubcaptionBold)
                        .foregroundColor(AppColors.accent)
                }
                .fixedSize()

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
                .fixedSize()
            }

            VStack(alignment: .leading, spacing: 6) {
                if viewModel.translatedText.isEmpty && (viewModel.isLoading || viewModel.isStreaming) {
                    TranslationShimmerPlaceholder(message: "Đang dịch thuật...")
                        .frame(minHeight: viewModel.originalText.count > 100 ? 55 : 24, alignment: .leading)
                } else {
                    LiveSpokenTextView(
                        text: viewModel.translatedText.isEmpty ? "—" : viewModel.translatedText,
                        speakerID: "translated",
                        isStreaming: viewModel.isStreaming,
                        font: .appHeadline,
                        defaultColor: .primary,
                        lineSpacing: 4.5
                    )
                }

                if !viewModel.translatedText.isEmpty || viewModel.isStreaming {
                    engineAttributionBadge
                }
            }
            .padding(12)
            .background(AppColors.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        viewModel.isStreaming ? AppColors.accent.opacity(0.3) : AppColors.accent.opacity(0.15),
                        lineWidth: viewModel.isStreaming ? 1.2 : 1
                    )
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

                if viewModel.translatedText.isEmpty && (viewModel.isLoading || viewModel.isStreaming) {
                    TranslationShimmerPlaceholder(message: "Đang dịch thuật...")
                        .frame(minHeight: viewModel.originalText.count > 100 ? 55 : 24, alignment: .leading)
                } else {
                    LiveSpokenTextView(
                        text: viewModel.translatedText.isEmpty ? "—" : viewModel.translatedText,
                        speakerID: "translated",
                        isStreaming: viewModel.isStreaming,
                        font: .system(size: 13.5, weight: .semibold),
                        defaultColor: .primary,
                        lineSpacing: 4
                    )
                }

                // Action Bar under translated text
                HStack {
                    engineAttributionBadge

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
                    .stroke(
                        viewModel.isStreaming ? AppColors.accent.opacity(0.3) : AppColors.accent.opacity(0.2),
                        lineWidth: viewModel.isStreaming ? 1.2 : 0.9
                    )
            )

            // 3. Multi-Engine Comparison Stack (Easydict Signature Feature)
            if viewModel.isComparisonMode || Defaults[.enableHUDMultiEngine] {
                multiEngineStackView
            }
        }
    }

    // MARK: - Multi-Engine Comparison Stack View
    private var multiEngineStackView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "square.split.2x1.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color.blue)
                    Text("SO SÁNH ĐA CÔNG CỤ (MULTI-ENGINE STACK)")
                        .font(.appSubcaptionBold)
                        .foregroundColor(.blue)
                }

                if viewModel.isComparing {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 10, height: 10)
                }

                Spacer()

                Button(action: {
                    viewModel.performComparison()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 8.5))
                        Text("Tải lại")
                            .font(.system(size: 9.5))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Tải lại kết quả so sánh")
                .accessibilityLabel("Tải lại kết quả so sánh các động cơ")
                .accessibilityAddTraits(.isButton)
            }

            if viewModel.comparisonResults.isEmpty && viewModel.isComparing {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.6).frame(width: 14, height: 14)
                    Text("Đang đối chiếu kết quả giữa Google, DeepL và AI...")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .italic()
                }
                .padding(.vertical, 6)
            } else {
                ForEach(viewModel.comparisonResults) { res in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .center) {
                            HStack(spacing: 5) {
                                Text(res.providerName)
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundColor(.primary.opacity(0.85))

                                Text("\(res.latencyMs)ms")
                                    .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(res.latencyMs < 300 ? Color.green.opacity(0.12) : Color.primary.opacity(0.06))
                                    .foregroundColor(res.latencyMs < 300 ? .green : .secondary)
                                    .cornerRadius(3)
                            }

                            Spacer()

                            if !res.isError && !res.text.isEmpty {
                                Button(action: {
                                    viewModel.speakCustom(text: res.text, speakerID: "comp_\(res.providerName)")
                                }) {
                                    Image(systemName: "speaker.wave.2")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Nghe phát âm bản dịch này")
                                .accessibilityLabel("Phát âm bản dịch của \(res.providerName)")
                                .accessibilityAddTraits([.isButton, .startsMediaSession])

                                NekoCopyButton(textToCopy: res.text, iconOnly: true)

                                Button(action: {
                                    viewModel.applyComparisonResult(res)
                                }) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 9))
                                        Text("Dùng")
                                            .font(.system(size: 9.5, weight: .medium))
                                    }
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.12))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                                .help("Chọn bản dịch này làm kết quả chính")
                                .accessibilityLabel("Sử dụng bản dịch từ \(res.providerName)")
                                .accessibilityHint("Nhấn để áp dụng bản dịch này vào kết quả hiển thị chính")
                                .accessibilityAddTraits(.isButton)
                            }
                        }

                        if res.isError {
                            Text(res.errorMessage ?? "Không thể kết nối đến dịch vụ")
                                .font(.system(size: 11))
                                .foregroundColor(.red.opacity(0.8))
                                .italic()
                        } else {
                            LiveSpokenTextView(
                                text: res.text,
                                speakerID: "comp_\(res.providerName)",
                                font: .system(size: 12),
                                defaultColor: .primary.opacity(0.9),
                                lineSpacing: 3
                            )
                        }
                    }
                    .padding(8)
                    .background(Color.primary.opacity(0.025))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.primary.opacity(0.07), lineWidth: 0.8)
                    )
                }
            }
        }
        .padding(10)
        .background(Color.blue.opacity(0.03))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.18), lineWidth: 0.8)
        )
    }
}
