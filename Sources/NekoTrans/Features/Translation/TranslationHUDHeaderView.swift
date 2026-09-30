import SwiftUI

public struct TranslationHUDHeaderView: View {
    @ObservedObject var viewModel: TranslationViewModel
    @ObservedObject var iconService = AppIconService.shared
    @ObservedObject var settings = AppSettings.shared
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
            Menu {
                Section("Ngôn ngữ đích") {
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
            } label: {
                HStack(spacing: 5) {
                    Text(viewModel.detectedLanguage.uppercased())
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Color.blue.opacity(0.12))
                        .cornerRadius(3.5)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text(viewModel.targetLanguage.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Circle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 3, height: 3)
                        .padding(.horizontal, 1)
                    
                    HStack(spacing: 3) {
                        Image(systemName: viewModel.selectedEngine.icon)
                            .font(.system(size: 8))
                        Text(viewModel.selectedEngine == .auto ? "Tự động" : (viewModel.selectedEngine == .directAI ? "AI" : viewModel.selectedEngine.rawValue))
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
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Chọn ngôn ngữ và động cơ dịch thuật")
            
            Spacer(minLength: 4)
            
            // Right: Essential Controls + Advanced Features Menu
            HStack(spacing: 6) {
                // Pin / Auto-Translate Toggle
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        isPinned.toggle()
                    }
                    onTogglePin?()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 10))
                        if isPinned {
                            Text("Ghim")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                    }
                    .padding(.horizontal, isPinned ? 6.5 : 5)
                    .padding(.vertical, 3.5)
                    .background(isPinned ? Color.orange.opacity(0.18) : Color.primary.opacity(0.04))
                    .foregroundColor(isPinned ? .orange : .secondary.opacity(0.8))
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
                                    Label("Trợ lý phân tích sâu (\(HotKeyManager.shared.aiShortcut.displayString))", systemImage: "text.magnifyingglass")
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
                    
                    if settings.showOCRInMenu || settings.isContinuityStudioActive {
                        Section("📷 Công Cụ Màn Hình & Thiết Bị") {
                            if settings.showOCRInMenu {
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
                                    Label("Chụp quét chữ màn hình (OCR) (\(HotKeyManager.shared.ocrShortcut.displayString))", systemImage: "camera.viewfinder")
                                }
                            }
                            
                            if settings.isContinuityStudioActive {
                                Button(action: {
                                    ContinuityHomeworkController.shared.showStudio(taskText: viewModel.originalText)
                                }) {
                                    Label("Bắn bài tập sang iPad viết tay", systemImage: "ipad.and.arrow.forward")
                                }
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
                                Label("Mở Sổ tay từ vựng (\(HotKeyManager.shared.notebookShortcut.displayString))", systemImage: "book.closed.fill")
                            }
                        }
                        
                        Button(action: {
                            SettingsWindowController.shared.showSettings()
                        }) {
                            Label("Tùy chỉnh tính năng & Cài đặt (⌘,)", systemImage: "slider.horizontal.3")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(2)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Tính năng nâng cao (Bấm để mở)")
                
                // Close Button
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.65))
                }
                .buttonStyle(.plain)
                .help("Đóng (ESC)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
