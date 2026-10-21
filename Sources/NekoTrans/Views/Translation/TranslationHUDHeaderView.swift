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
                } else {
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
            }
            .fixedSize()
            
            // Unified Language & Engine Selector Pill
            ZStack {
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
                        Image(systemName: viewModel.selectedEngine.icon)
                            .font(.system(size: 8))
                        Group {
                            if viewModel.selectedEngine == .auto {
                                Text("Tự động")
                            } else if viewModel.selectedEngine == .directAI {
                                let custom = settings.customAIModel
                                let p = settings.aiProvider
                                let raw = custom.isEmpty ? (p == .ollama ? DirectAIProvider.ollama.defaultModel : p.defaultModel) : custom
                                let shortName = raw.contains("/") ? (raw.components(separatedBy: "/").last ?? raw) : raw
                                Text("⚡ \(shortName)")
                            } else {
                                Text(viewModel.selectedEngine.rawValue)
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

                Menu {
                    Section("Đổi chiều dịch") {
                        Button(action: {
                            viewModel.swapLanguages()
                        }) {
                            Label("Đảo chiều (\(viewModel.detectedLanguage.uppercased()) ⇄ \(viewModel.activeTargetLanguage.rawValue.uppercased()))", systemImage: "arrow.left.arrow.right")
                        }
                    }
                    
                    Section("Ngôn ngữ đích") {
                        ForEach(TargetLanguage.allCases) { lang in
                            Button(action: {
                                viewModel.targetLanguage = lang
                            }) {
                                if viewModel.activeTargetLanguage == lang {
                                    Label("\(lang.displayName) (Đang dịch)", systemImage: "checkmark")
                                } else {
                                    Text(lang.displayName)
                                }
                            }
                        }
                    }
                    
                    Section("Động cơ dịch") {
                        ForEach(TranslationEngine.allCases) { engine in
                            Button(action: {
                                viewModel.selectedEngine = engine
                            }) {
                                if viewModel.selectedEngine == engine {
                                    Label("\(engine.rawValue) (Đang chọn)", systemImage: "checkmark")
                                } else {
                                    Label(engine.rawValue, systemImage: engine.icon)
                                }
                            }
                        }
                    }

                    Section("Chế độ tra từ đơn") {
                        ForEach(WordLookupMode.allCases) { mode in
                            Button(action: {
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                                    settings.wordLookupMode = mode
                                }
                            }) {
                                if settings.wordLookupMode == mode {
                                    Label("\(mode.title) (Đang chọn)", systemImage: "checkmark")
                                } else {
                                    Label(mode.title, systemImage: mode.icon)
                                }
                            }
                        }
                    }
                } label: {
                    Color.white.opacity(0.0001)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }
            .fixedSize()
            .help("Chọn ngôn ngữ và động cơ dịch thuật")
            
            Spacer(minLength: 4)
            
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
                                : Color.primary.opacity(0.05)
                        )
                        .foregroundColor(
                            settings.wordLookupMode == .quickTranslate
                                ? AppColors.accent
                                : .secondary
                        )
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help(settings.wordLookupMode == .quickTranslate ? "Đang bật chế độ Dịch nhanh gọn • Bấm để chuyển sang Từ điển chi tiết" : "Đang bật chế độ Từ điển • Bấm để chuyển sang Dịch nhanh gọn")
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
                
                // Advanced / Special Features Menu ("...")
                Menu {
                    if settings.showAIAssistantInMenu || settings.showAIVocabGrammarInMenu {
                        Section("Công Cụ Phân Tích") {
                            if settings.showAIAssistantInMenu {
                                Button(action: {
                                    QuickAIWindowController.shared.showAI(prompt: viewModel.originalText)
                                }) {
                                    Label("Trợ lý phân tích sâu (\(HotKeyManager.shared.aiDisplayString))", systemImage: "text.magnifyingglass")
                                }
                            }
                            
                            if settings.showAIVocabGrammarInMenu {
                                Button(action: {
                                    TextAnalysisWindowController.shared.showAnalysis(text: viewModel.originalText)
                                }) {
                                    Label("Bóc tách từ vựng & ngữ pháp", systemImage: "list.bullet.rectangle.portrait")
                                }
                            }
                        }
                    }
                    
                    if settings.showOCRInMenu {
                        Section("📷 Công Cụ Màn Hình") {
                            Button(action: {
                                onClose()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    ScreenOCRService.shared.captureAndRecognize { text, snipRect in
                                        guard let recognized = text, !recognized.isEmpty else { return }
                                        AppDelegate.shared?.triggerTranslationWithText(recognized, nearRect: snipRect)
                                    }
                                }
                            }) {
                                Label("Chụp quét chữ màn hình (OCR) (\(HotKeyManager.shared.ocrDisplayString))", systemImage: "camera.viewfinder")
                            }
                        }
                    }
                    
                    if settings.showDomainSelectorInMenu {
                        Section("🌐 Ngữ Cảnh Chuyên Ngành: \(settings.translationDomain.rawValue)") {
                            ForEach(TranslationDomain.allCases) { domain in
                                Button(action: {
                                    settings.translationDomain = domain
                                    if !viewModel.originalText.isEmpty {
                                        viewModel.updateTranslation()
                                    }
                                }) {
                                    if settings.translationDomain == domain {
                                        Label("\(domain.rawValue) (Đang chọn)", systemImage: "checkmark")
                                    } else {
                                        Label(domain.rawValue, systemImage: domain.icon)
                                    }
                                }
                            }
                        }
                    }
                    
                    Section("📚 Sổ Tay & Cài Đặt") {
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
                            Label("Tùy chỉnh tính năng & Cài đặt (⌘,)", systemImage: "slider.horizontal.3")
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
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

