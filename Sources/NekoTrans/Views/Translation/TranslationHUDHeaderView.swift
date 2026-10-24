import SwiftUI
import KeyboardShortcuts
public struct TranslationHUDHeaderView: View {
    var viewModel: TranslationViewModel
    var iconService = AppIconService.shared
    var settings = AppSettings.shared
    @Binding var isPinned: Bool
    var onTogglePin: (() -> Void)?
    var onClose: () -> Void
    
    public init(
        viewModel: TranslationViewModel,
        isPinned: Binding<Bool>,
        onTogglePin: (() -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self._isPinned = isPinned
        self.onTogglePin = onTogglePin
        self.onClose = onClose
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            // Left: App Brand & History Back Button
            HStack(spacing: 5) {
                if viewModel.canGoBack {
                    Button(action: {
                        viewModel.goBack()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 9.5, weight: .bold))
                            Text("Lùi")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.accentSubtle)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Quay lại từ vừa tra (⌘[)")
                    .accessibilityLabel("Quay lại từ vừa tra")
                    .accessibilityHint("Nhấn để xem lại kết quả tra cứu trước đó (Phím tắt Command [)")
                    .accessibilityAddTraits(.isButton)
                } else {
                    HStack(spacing: 5) {
                        iconService.currentImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundColor(iconService.selectedType.accentColor)
                        
                        Text("NekoTrans")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    .allowsHitTesting(false)
                }
            }
            .fixedSize()
            
            // Unified Language & Engine Selector Pill
            Menu {
                Button(action: {
                    viewModel.swapLanguages()
                }) {
                    let src = viewModel.detectedLanguage.isEmpty ? "EN" : viewModel.detectedLanguage.uppercased()
                    let dst = viewModel.activeTargetLanguage.rawValue.uppercased()
                    Text("⇄  Đảo chiều ngôn ngữ (\(src) ⇄ \(dst))")
                }
                
                Divider()
                
                Section("Ngôn ngữ đích") {
                    ForEach(TargetLanguage.allCases) { lang in
                        let isSelected = (viewModel.activeTargetLanguage == lang)
                        Button(action: {
                            viewModel.targetLanguage = lang
                        }) {
                            if isSelected {
                                Text("✓  \(lang.flag)  \(lang.displayName)")
                            } else {
                                Text("      \(lang.flag)  \(lang.displayName)")
                            }
                        }
                    }
                }
                
                Divider()
                
                Section("Động cơ dịch") {
                    ForEach(TranslationEngine.allCases) { engine in
                        let isSelected = (viewModel.selectedEngine == engine)
                        Button(action: {
                            viewModel.selectedEngine = engine
                        }) {
                            if isSelected {
                                Text("✓  \(engine.emojiIcon)  \(engine.displayName)")
                            } else {
                                Text("      \(engine.emojiIcon)  \(engine.displayName)")
                            }
                        }
                    }
                }

                Divider()

                Section("Khi tra từ đơn") {
                    ForEach(WordLookupMode.allCases) { mode in
                        let isSelected = (settings.wordLookupMode == mode)
                        Button(action: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                settings.wordLookupMode = mode
                            }
                        }) {
                            if isSelected {
                                Text("✓  \(mode.emojiIcon)  \(mode.title)")
                            } else {
                                Text("      \(mode.emojiIcon)  \(mode.title)")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4.5) {
                    Text(viewModel.detectedLanguage.isEmpty ? "EN" : viewModel.detectedLanguage.uppercased())
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(AppColors.accent)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(AppColors.accent.opacity(0.12))
                        .cornerRadius(3.5)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text(viewModel.activeTargetLanguage.rawValue.uppercased())
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1.5)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(3.5)
                    
                    Circle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 3, height: 3)
                        .padding(.horizontal, 1)
                    
                    HStack(spacing: 3) {
                        Image(systemName: (viewModel.selectedEngine == .directAI && settings.aiProvider == .inProcessGGUF) ? "cpu.fill" : viewModel.selectedEngine.icon)
                            .font(.system(size: 8))
                        Group {
                            if viewModel.selectedEngine == .auto {
                                Text("Tự động")
                            } else if viewModel.selectedEngine == .directAI {
                                let p = settings.aiProvider
                                if p == .inProcessGGUF {
                                    let name = LocalGGUFService.friendlyModelName(from: LocalGGUFService.shared.loadedModelName ?? settings.customGGUFModelPath)
                                    Text(name.isEmpty ? "GGUF Metal" : name)
                                } else {
                                    let custom = settings.customAIModel
                                    let raw = custom.isEmpty ? p.defaultModel : custom
                                    let shortName = raw.contains("/") ? (raw.components(separatedBy: "/").last ?? raw) : raw
                                    Text(shortName)
                                }
                            } else {
                                Text(viewModel.selectedEngine.shortName)
                            }
                        }
                        .font(.system(size: 9.5, weight: .medium))
                        .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.85))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.primary.opacity(0.10), lineWidth: 0.8)
                )
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Chọn ngôn ngữ và động cơ dịch thuật")
            .accessibilityLabel("Tùy chọn ngôn ngữ và động cơ dịch thuật")
            .accessibilityHint("Nhấn để đảo chiều ngôn ngữ, đổi ngôn ngữ đích hoặc đổi động cơ dịch")
            
            Spacer(minLength: 8)
            
            // Right: Essential Controls + Advanced Features Menu
            HStack(spacing: 5) {
                // Quick Toggle: Dịch gọn vs Từ điển
                if viewModel.isWordLookup {
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                            settings.wordLookupMode = (settings.wordLookupMode == .dictionary) ? .quickTranslate : .dictionary
                        }
                    }) {
                        HStack(spacing: 3.5) {
                            Image(systemName: settings.wordLookupMode.icon)
                                .font(.system(size: 9.5, weight: .semibold))
                            if settings.wordLookupMode == .quickTranslate {
                                Text("Dịch gọn")
                                    .font(.system(size: 9.5, weight: .semibold))
                            } else {
                                Text("Từ điển")
                                    .font(.system(size: 9.5, weight: .semibold))
                            }
                        }
                        .padding(.horizontal, 6.5)
                        .frame(minHeight: 22)
                        .background(
                            settings.wordLookupMode == .quickTranslate
                                ? AppColors.accent.opacity(0.14)
                                : Color.blue.opacity(0.14)
                        )
                        .foregroundColor(
                            settings.wordLookupMode == .quickTranslate
                                ? AppColors.accent
                                : .blue
                        )
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help(settings.wordLookupMode == .quickTranslate ? "Đang bật chế độ Dịch nhanh gọn • Bấm để chuyển sang Từ điển chi tiết" : "Đang bật chế độ Từ điển • Bấm để chuyển sang Dịch nhanh gọn")
                    .accessibilityLabel(settings.wordLookupMode == .quickTranslate ? "Chuyển sang chế độ Từ điển chi tiết" : "Chuyển sang chế độ Dịch nhanh gọn")
                    .accessibilityHint("Nhấn để chuyển đổi giữa giao diện dịch gọn và từ điển đầy đủ")
                    .accessibilityAddTraits(.isButton)
                }

                // Pin / Auto-Translate Toggle
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isPinned.toggle()
                    }
                    onTogglePin?()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 10, weight: .medium))
                        if isPinned {
                            Text("Ghim")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                    }
                    .frame(minWidth: 22, minHeight: 22)
                    .padding(.horizontal, isPinned ? 6 : 0)
                    .background(isPinned ? Color.orange.opacity(0.18) : Color.primary.opacity(0.05))
                    .foregroundColor(isPinned ? .orange : .secondary)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Đang ghim • Tự động dịch khi bôi đen" : "Ghim cửa sổ trên cùng")
                .accessibilityLabel(isPinned ? "Bỏ ghim cửa sổ tra cứu" : "Ghim cửa sổ tra cứu trên cùng")
                .accessibilityHint("Khi ghim, cửa sổ luôn nổi trên cùng và tự động dịch văn bản được bôi đen")
                .accessibilityAddTraits(.isButton)
                
                // Advanced / Special Features Menu ("...")
                Menu {
                    if settings.showAIAssistantInMenu || settings.showAIVocabGrammarInMenu {
                        Section("Phân tích") {
                            if settings.showAIAssistantInMenu {
                                Button(action: {
                                    QuickAIWindowController.shared.showAI(prompt: viewModel.originalText)
                                }) {
                                    Label("Trợ lý AI (\(HotKeyManager.shared.aiDisplayString))", systemImage: "sparkles")
                                }
                            }
                            
                            if settings.showAIVocabGrammarInMenu {
                                Button(action: {
                                    TextAnalysisWindowController.shared.showAnalysis(text: viewModel.originalText)
                                }) {
                                    Label("Phân tích từ vựng & ngữ pháp", systemImage: "text.book.closed")
                                }
                            }
                        }
                    }
                    
                    if settings.showOCRInMenu {
                        Section("Chụp màn hình") {
                            Button(action: {
                                onClose()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    ScreenOCRService.shared.captureAndRecognize { text, snipRect in
                                        guard let recognized = text, !recognized.isEmpty else { return }
                                        AppDelegate.shared?.triggerTranslationWithText(recognized, nearRect: snipRect)
                                    }
                                }
                            }) {
                                Label("Chụp quét chữ (\(HotKeyManager.shared.ocrDisplayString))", systemImage: "camera.viewfinder")
                            }
                        }
                    }
                    
                    if settings.showDomainSelectorInMenu {
                        Menu {
                            ForEach(TranslationDomain.allCases) { domain in
                                Button(action: {
                                    settings.translationDomain = domain
                                    if !viewModel.originalText.isEmpty {
                                        viewModel.updateTranslation()
                                    }
                                }) {
                                    if settings.translationDomain == domain {
                                        Text("✓  \(domain.emojiIcon)  \(domain.rawValue)")
                                    } else {
                                        Text("      \(domain.emojiIcon)  \(domain.rawValue)")
                                    }
                                }
                            }
                        } label: {
                            Label("Ngữ cảnh: \(settings.translationDomain.rawValue)", systemImage: "text.book.closed")
                        }
                    }
                    
                    Section {
                        if settings.showNotebookInMenu {
                            Button(action: {
                                VocabularyWindowController.shared.showNotebook()
                            }) {
                                Label("Mở Sổ tay từ vựng (\(HotKeyManager.shared.notebookDisplayString))", systemImage: "book.closed.fill")
                            }
                        }
                        
                        Button(action: {
                            SettingsWindowController.shared.showSettings()
                        }) {
                            Label("Cài đặt... (⌘,)", systemImage: "gearshape")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(5)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Tính năng nâng cao (Bấm để mở)")
                .accessibilityLabel("Tính năng nâng cao và cài đặt")
                .accessibilityHint("Mở trợ lý AI, bóc tách ngữ pháp, quét OCR hoặc mở cài đặt ứng dụng")
                
                // Close Button
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Đóng (ESC)")
                .accessibilityLabel("Đóng cửa sổ tra cứu")
                .accessibilityHint("Nhấn để đóng cửa sổ tra cứu (Phím tắt Escape)")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(WindowDragArea())
        .help("Kéo để di chuyển khung popup")
    }
}

