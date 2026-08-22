import SwiftUI
import AppKit

// MARK: - Main Application Dashboard / Hub View
public struct MainDashboardView: View {
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var iconService = AppIconService.shared
    @ObservedObject var speechService = SpeechService.shared
    @ObservedObject var hotKeyManager = HotKeyManager.shared
    @ObservedObject var settings = AppSettings.shared
    
    @State private var quickSearchText: String = ""
    @State private var quickTranslationResult: String? = nil
    @State private var isSearching: Bool = false
    @State private var selectedLanguage: TargetLanguage = .vietnamese
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Top Brand & Header Section
                headerSection
                
                // Quick Lookup & Translate Card
                quickTranslateCard
                
                // 4 Main Feature Action Cards
                featureGridSection
                
                // Spotlight / Daily Word Card
                spotlightCard
                
                // Recent Notebook Items
                recentItemsSection
                
                // Footer Status & Hotkey Shortcuts
                footerSection
            }
            .padding(24)
        }
        .frame(minWidth: 780, minHeight: 620)
        .background(
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
        )
    }
    
    // MARK: - 1. Top Header Section
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 14) {
            iconService.currentImage
                .resizable()
                .scaledToFit()
                .frame(width: 42, height: 42)
                .foregroundColor(iconService.selectedType.accentColor)
                .shadow(color: iconService.selectedType.accentColor.opacity(0.3), radius: 6, x: 0, y: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("ToolTrL")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("v1.0.0")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(4)
                }
                
                Text("Trợ lý tra từ, phân tích ngữ pháp và học tiếng Anh thông minh trên macOS")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: {
                SettingsWindowController.shared.showSettings()
            }) {
                Label("Cài đặt", systemImage: "gearshape")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .buttonStyle(.borderless)
        }
    }
    
    // MARK: - 2. Quick Translate Card
    private var quickTranslateCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("TRA CỨU & DỊCH NHANH", systemImage: "magnifyingglass")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Menu {
                        ForEach(TargetLanguage.allCases) { lang in
                            Button(action: {
                                selectedLanguage = lang
                                if !quickSearchText.isEmpty {
                                    performQuickTranslation()
                                }
                            }) {
                                if selectedLanguage == lang {
                                    Label(lang.displayName, systemImage: "checkmark")
                                } else {
                                    Text(lang.displayName)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("Dịch sang: \(selectedLanguage.displayName)")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
                
                HStack(spacing: 10) {
                    TextField("Nhập từ vựng, câu hoặc đoạn văn để tra cứu ngay...", text: $quickSearchText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                        .onSubmit {
                            performQuickTranslation()
                        }
                    
                    Button(action: {
                        performQuickTranslation()
                    }) {
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 50)
                        } else {
                            Text("Tra cứu")
                                .font(.system(size: 12, weight: .semibold))
                                .frame(width: 50)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(quickSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSearching)
                }
                
                if let result = quickTranslationResult, !result.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider().opacity(0.15)
                        
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Bản dịch:")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                Text(result)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Button(action: {
                                    speechService.speak(text: quickSearchText, languageCode: "en-US", speakerID: "main_hub_audio")
                                }) {
                                    Image(systemName: "speaker.wave.2")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.borderless)
                                .help("Phát âm")
                                
                                Button(action: {
                                    vocabService.toggleSaveWord(
                                        word: quickSearchText,
                                        phonetic: nil,
                                        translation: result
                                    )
                                }) {
                                    Image(systemName: vocabService.isWordSaved(quickSearchText) ? "bookmark.fill" : "bookmark")
                                        .font(.system(size: 11))
                                        .foregroundColor(vocabService.isWordSaved(quickSearchText) ? .yellow : .secondary)
                                }
                                .buttonStyle(.borderless)
                                .help("Lưu vào sổ tay")
                                
                                Button(action: {
                                    QuickAIWindowController.shared.showAI(
                                        prompt: AIPromptBuilder.structuredWordPrompt(for: quickSearchText)
                                    )
                                }) {
                                    Label("Phân tích AI", systemImage: "wand.and.stars")
                                        .font(.system(size: 10.5))
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(8)
        }
    }
    
    // MARK: - 3. Feature Grid Section
    private var featureGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            // Card 1: Sổ Tay Từ Vựng
            featureCard(
                icon: "books.vertical.fill",
                iconColor: .blue,
                title: "Sổ Tay & Cẩm Nang",
                subtitle: "\(vocabService.savedWords.count) từ và cấu trúc đã lưu (\(vocabService.savedWords.filter { $0.isMastered }.count) đã thuộc)",
                badge: hotKeyManager.notebookShortcut.displayString,
                actionTitle: "Mở Sổ Tay"
            ) {
                VocabularyWindowController.shared.showNotebook()
            }
            
            // Card 2: Trợ Lý AI
            featureCard(
                icon: "bubble.left.and.bubble.right.fill",
                iconColor: .purple,
                title: "Trợ Lý AI Đa Năng",
                subtitle: "ChatGPT, Gemini, Claude phân tích ngữ cảnh và giải đáp chi tiết",
                badge: hotKeyManager.aiShortcut.displayString,
                actionTitle: "Mở Trợ Lý AI"
            ) {
                QuickAIWindowController.shared.showAI()
            }
            
            // Card 3: Phân Tích Đoạn Văn
            featureCard(
                icon: "doc.text.magnifyingglass",
                iconColor: .teal,
                title: "Phân Tích Đoạn Văn",
                subtitle: "Trích xuất từ vựng, cụm collocations và công thức ngữ pháp tự động",
                badge: "Smart OCR",
                actionTitle: "Mở Trình Phân Tích"
            ) {
                TextAnalysisWindowController.shared.showAnalysis()
            }
            
            // Card 4: Chụp Quét Màn Hình
            featureCard(
                icon: "viewfinder",
                iconColor: .orange,
                title: "Chụp Quét Chữ (OCR)",
                subtitle: "Nhận diện chữ nhanh trên mọi vùng màn hình chỉ với một thao tác",
                badge: hotKeyManager.ocrShortcut.displayString,
                actionTitle: "Chụp Màn Hình"
            ) {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.triggerOCR()
                }
            }
        }
    }
    
    private func featureCard(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        badge: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                        .frame(width: 32, height: 32)
                        .background(iconColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    Spacer()
                    
                    Text(badge)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(4)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .frame(height: 32, alignment: .topLeading)
                }
                
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(6)
        }
    }
    
    // MARK: - 4. Spotlight Card
    private var spotlightCard: some View {
        let spotlightItem = vocabService.savedWords.first ?? SavedWordItem(
            word: "Serendipity",
            phonetic: "/ˌser.ənˈdɪp.ə.t̬i/",
            translation: "Sự tình cờ may mắn; duyên may tìm thấy điều tốt đẹp bất ngờ",
            exampleEn: "We found each other by pure serendipity."
        )
        
        return GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(spotlightItem.isGrammarFormula ? "CẤU TRÚC GỢI Ý HÔM NAY" : "TỪ VỰNG GỢI Ý HÔM NAY", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    Button(action: {
                        speechService.speak(text: spotlightItem.cleanTitle, languageCode: "en-US", speakerID: "spotlight_audio")
                    }) {
                        Image(systemName: "speaker.wave.2")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(spotlightItem.cleanTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let pho = spotlightItem.phonetic, !pho.isEmpty {
                        Text(pho)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(spotlightItem.translation)
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
                
                if let ex = spotlightItem.exampleEn, !ex.isEmpty {
                    Text("\"\(ex)\"")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundColor(.primary)
                }
            }
            .padding(8)
        }
    }
    
    // MARK: - 5. Recent Items Section
    private var recentItemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("TỪ VỰNG & CẤU TRÚC GẦN ĐÂY", systemImage: "clock")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: {
                    VocabularyWindowController.shared.showNotebook()
                }) {
                    Text("Xem tất cả (\(vocabService.savedWords.count))")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            
            if vocabService.savedWords.isEmpty {
                GroupBox {
                    HStack(spacing: 10) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        Text("Chưa có từ vựng nào được lưu. Hãy bôi đen chữ và bấm \(hotKeyManager.translateShortcut.displayString) để tra và lưu từ.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(vocabService.savedWords.prefix(5)) { item in
                        GroupBox {
                            HStack(spacing: 10) {
                                Image(systemName: item.isGrammarFormula ? "function" : "book.closed")
                                    .font(.system(size: 11))
                                    .foregroundColor(item.isGrammarFormula ? .blue : .secondary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.cleanTitle)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text(item.translation)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    speechService.speak(text: item.cleanTitle, languageCode: "en-US", speakerID: "recent_\(item.id.uuidString)")
                                }) {
                                    Image(systemName: "speaker.wave.2")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                                
                                Button(action: {
                                    vocabService.toggleMastered(id: item.id)
                                }) {
                                    Image(systemName: item.isMastered ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 12))
                                        .foregroundColor(item.isMastered ? .green : .secondary.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                                .help(item.isMastered ? "Đã thuộc" : "Đánh dấu đã thuộc")
                            }
                            .padding(4)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 6. Footer Section
    private var footerSection: some View {
        HStack {
            Text("Phím tắt hệ thống: \(hotKeyManager.translateShortcut.displayString) Dịch nhanh • \(hotKeyManager.aiShortcut.displayString) Trợ lý AI • \(hotKeyManager.ocrShortcut.displayString) Chụp OCR • \(hotKeyManager.notebookShortcut.displayString) Sổ tay")
                .font(.system(size: 10.5))
                .foregroundColor(.secondary.opacity(0.8))
            
            Spacer()
        }
        .padding(.top, 4)
    }
    
    private func performQuickTranslation() {
        let text = quickSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isSearching = true
        Task {
            let res = await TranslationService.shared.translate(
                text: text,
                from: "auto",
                to: selectedLanguage.rawValue
            )
            await MainActor.run {
                self.quickTranslationResult = res
                self.isSearching = false
            }
        }
    }
}
