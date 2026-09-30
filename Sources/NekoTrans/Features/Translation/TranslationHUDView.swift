import SwiftUI
#if canImport(Translation)
import Translation
#endif

public struct TranslationHUDView: View {
    @ObservedObject var viewModel: TranslationViewModel
    var onClose: () -> Void
    var onTogglePin: (() -> Void)?

    @State private var isPinned: Bool = false
    @State private var manualInput: String = ""

    public init(viewModel: TranslationViewModel, onTogglePin: (() -> Void)? = nil, onClose: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onTogglePin = onTogglePin
        self.onClose = onClose
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
                        // DICTIONARY MODE (Word / Short Phrase)
                        TranslationHUDDictionaryView(viewModel: viewModel)
                    } else if !viewModel.originalText.isEmpty {
                        // SENTENCE / PARAGRAPH TRANSLATION MODE
                        TranslationHUDSentenceView(viewModel: viewModel)
                    } else {
                        // EMPTY STATE
                        emptyStateView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .animation(.easeInOut(duration: 0.18), value: viewModel.richEntry != nil)
            }
            .frame(maxHeight: viewModel.originalText.isEmpty ? 75 : (viewModel.isWordLookup ? 290 : 400))
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.originalText.isEmpty)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.isWordLookup)

            Divider()
                .opacity(0.2)

            // Bottom Quick Search Bar & Action Bar (Raycast Style)
            bottomInputBar
        }
        .frame(width: 515)
        .background(
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 16)
                Color(nsColor: .windowBackgroundColor).opacity(0.68)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.30), radius: 22, x: 0, y: 10)
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
                            Text("⌘C")
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
                            Text("⌘S")
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
