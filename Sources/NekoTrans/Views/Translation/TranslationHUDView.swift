import SwiftUI
import SettingsAccess
#if canImport(Translation)
import Translation
#endif

private struct HUDContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

private struct HUDTotalHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 {
            value = next
        }
    }
}

public struct TranslationHUDView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @ObservedObject var settings = AppSettings.shared
    var onClose: () -> Void
    var onTogglePin: (() -> Void)?
    var onHeightChanged: ((CGFloat) -> Void)?

    @State private var isPinned: Bool = false
    @State private var manualInput: String = ""
    @State private var measuredContentHeight: CGFloat = 80
    @State private var measuredTotalHeight: CGFloat = 160

    public init(
        viewModel: TranslationViewModel,
        onTogglePin: (() -> Void)? = nil,
        onHeightChanged: ((CGFloat) -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onTogglePin = onTogglePin
        self.onHeightChanged = onHeightChanged
        self.onClose = onClose
    }

    private var maxScrollHeight: CGFloat {
        if viewModel.originalText.isEmpty {
            return 75
        } else if viewModel.isWordLookup {
            return 320
        } else {
            return 360
        }
    }

    private var currentScrollHeight: CGFloat {
        let raw = measuredContentHeight > 0 ? measuredContentHeight : 80
        return min(raw, maxScrollHeight)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top App Bar
            TranslationHUDHeaderView(
                viewModel: viewModel,
                isPinned: $isPinned,
                onTogglePin: onTogglePin,
                onClose: onClose
            )

            Divider()
                .opacity(0.25)

            // Main Content Area
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.isWordLookup {
                        TranslationHUDDictionaryView(viewModel: viewModel)
                    } else if !viewModel.originalText.isEmpty {
                        TranslationHUDSentenceView(viewModel: viewModel)
                    } else {
                        emptyStateView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(key: HUDContentHeightKey.self, value: geo.size.height)
                    }
                )
                .animation(.easeInOut(duration: 0.18), value: viewModel.richEntry != nil)
            }
            .frame(height: currentScrollHeight)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: currentScrollHeight)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.originalText.isEmpty)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.isWordLookup)
            .onPreferenceChange(HUDContentHeightKey.self) { newHeight in
                guard newHeight > 0 else { return }
                if abs(measuredContentHeight - newHeight) > 1 {
                    measuredContentHeight = newHeight
                }
            }

            Divider()
                .opacity(0.2)

            // Bottom Quick Search Bar & Action Bar (Raycast Style)
            bottomInputBar
        }
        .frame(width: 515)
        .background(
            GeometryReader { totalGeo in
                Color.clear.preference(key: HUDTotalHeightKey.self, value: totalGeo.size.height)
            }
        )
        .onPreferenceChange(HUDTotalHeightKey.self) { exactTotalHeight in
            guard exactTotalHeight > 0 else { return }
            measuredTotalHeight = exactTotalHeight
            onHeightChanged?(exactTotalHeight)
        }
        .onChange(of: viewModel.originalText) { _, _ in
            if measuredTotalHeight > 0 {
                onHeightChanged?(measuredTotalHeight)
            }
        }
        .onChange(of: viewModel.isWordLookup) { _, _ in
            if measuredTotalHeight > 0 {
                onHeightChanged?(measuredTotalHeight)
            }
        }
        .onChange(of: settings.wordLookupMode) { _, _ in
            if measuredTotalHeight > 0 {
                onHeightChanged?(measuredTotalHeight)
            }
        }
        .background(
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 16)
                Color(nsColor: .windowBackgroundColor).opacity(0.68)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 0.8)
        )
        .openSettingsAccess()
        #if canImport(Translation)
        .modifier(TranslationModifier(viewModel: viewModel))
        #endif
    }

    // MARK: - Empty State (Sleek Raycast Banner)
    private var emptyStateView: some View {
        HStack(spacing: 12) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 20))
                .foregroundColor(AppColors.accent.opacity(0.85))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Bôi đen văn bản hoặc nhập từ để bắt đầu")
                    .font(.appBodyMedium)
                    .foregroundColor(.primary)
                Text("Dịch đa tầng AI • Phát âm IPA bản xứ • Bóc tách ngữ pháp")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom Input Bar & Action Hints
    private var bottomInputBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.accent.opacity(0.85))
                .font(.system(size: 12))

            TextField("Nhập từ, cụm từ hoặc câu cần tra cứu...", text: $manualInput)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .onSubmit {
                    let trimmed = manualInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        viewModel.processText(trimmed)
                        manualInput = ""
                    }
                }

            if !manualInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: {
                    let trimmed = manualInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        viewModel.processText(trimmed)
                        manualInput = ""
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(AppColors.accent)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 4)

            // Raycast-Style Shortcut Hints
            HStack(spacing: 5) {
                if !viewModel.translatedText.isEmpty {
                    Button(action: {
                        viewModel.copyTranslation()
                    }) {
                        HStack(spacing: 2.5) {
                            Text(verbatim: "⌘C")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            Text("Chép")
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Sao chép bản dịch (⌘C)")
                    
                    Button(action: {
                        viewModel.toggleBookmark()
                    }) {
                        HStack(spacing: 2.5) {
                            Text(verbatim: "⌘S")
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            Text(viewModel.isBookmarked ? "Đã lưu" : "Lưu")
                                .font(.system(size: 9.5, weight: .medium))
                        }
                        .foregroundColor(viewModel.isBookmarked ? .orange : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2.5)
                        .background(viewModel.isBookmarked ? Color.orange.opacity(0.16) : Color.primary.opacity(0.06))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Lưu vào Sổ tay từ vựng (⌘S / ⌘B)")
                }

                Text("ESC")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.65))
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 2.5)
                    .background(Color.primary.opacity(0.06))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8.5)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
    }
}

// MARK: - Translation ViewModifier for macOS 15+
#if canImport(Translation)
public struct TranslationModifier: ViewModifier {
    @ObservedObject public var viewModel: TranslationViewModel

    public init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
    }

    public func body(content: Content) -> some View {
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
                        AppLog.translation.error("Native Translation session failed, falling back: \(error.localizedDescription, privacy: .public)")
                        await viewModel.runFallbackTranslation()
                    }
                }
        } else {
            content
        }
    }
}
#endif

// MARK: - Previews

//#Preview("HUD — Trạng thái trống (Empty)") {
//    let vm = TranslationViewModel()
//    LocalizedRootView {
//        TranslationHUDView(
//            viewModel: vm,
//            onTogglePin: {},
//            onClose: {}
//        )
//        .padding(24)
//    }
//    .frame(width: 580)
//}
//
//#Preview("HUD — Tra từ điển (Word)") {
//    let vm = TranslationViewModel()
//    vm.originalText = "serendipity"
//    vm.translatedText = "sự tình cờ may mắn"
//    vm.detectedLanguage = "en"
//    vm.richEntry = RichWordEntry(
//        word: "serendipity",
//        phonetic: "/ˌser.ənˈdɪp.ə.ti/",
//        ukAudioURL: nil,
//        usAudioURL: nil,
//        mainTranslation: "sự tình cờ may mắn",
//        meanings: [
//            MeaningGroup(
//                partOfSpeech: "noun",
//                definitions: [
//                    DefinitionItem(
//                        definitionEn: "The occurrence and development of events by chance in a happy or beneficial way.",
//                        definitionVi: "Khả năng tình cờ tìm thấy những điều bất ngờ thú vị và may mắn.",
//                        exampleEn: "A fortunate stroke of serendipity brought them together.",
//                        exampleVi: "Một cơ duyên may mắn đầy bất ngờ đã đưa họ đến với nhau."
//                    )
//                ],
//                synonyms: ["chance", "happy accident", "fluke"],
//                antonyms: ["misfortune"]
//            )
//        ],
//        allSynonyms: ["chance", "happy accident", "fluke"],
//        allAntonyms: ["misfortune"],
//        semanticNeighbors: ["destiny", "coincidence", "fortune"]
//    )
//    return LocalizedRootView {
//        TranslationHUDView(
//            viewModel: vm,
//            onTogglePin: {},
//            onClose: {}
//        )
//        .padding(24)
//    }
//    .frame(width: 580)
//}
//
//#Preview("HUD — Dịch câu (Sentence)") {
//    let vm = TranslationViewModel()
//    vm.originalText = "SwiftUI makes building user interfaces across all Apple platforms faster and easier."
//    vm.translatedText = "SwiftUI giúp việc xây dựng giao diện người dùng trên tất cả các nền tảng Apple nhanh chóng và dễ dàng hơn."
//    vm.detectedLanguage = "en"
//    return LocalizedRootView {
//        TranslationHUDView(
//            viewModel: vm,
//            onTogglePin: {},
//            onClose: {}
//        )
//        .padding(24)
//    }
//    .frame(width: 580)
//}

#Preview("HUD — Dịch câu (Dark Mode)") {
    let vm = TranslationViewModel()
    vm.originalText = "SwiftUI makes building user interfaces across all Apple platforms faster and easier."
    vm.translatedText = "SwiftUI giúp việc xây dựng giao diện người dùng trên tất cả các nền tảng Apple nhanh chóng và dễ dàng hơn."
    vm.detectedLanguage = "en"
    return LocalizedRootView {
        TranslationHUDView(
            viewModel: vm,
            onTogglePin: {},
            onClose: {}
        )
        .padding(24)
    }
    .frame(width: 580)
}

