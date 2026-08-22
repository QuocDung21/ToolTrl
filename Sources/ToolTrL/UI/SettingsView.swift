import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case vocabulary = "Sổ từ vựng"
    case display = "Hiển thị"
    case speech = "Âm thanh"
    case general = "Chung"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .vocabulary: return "character.book.closed.fill"
        case .display: return "text.viewfinder"
        case .speech: return "speaker.wave.3.fill"
        case .general: return "gearshape.fill"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var speechService = SpeechService.shared
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var iconService = AppIconService.shared
    @ObservedObject var promptService = QuickPromptService.shared
    
    @State private var selectedTab: SettingsTab = .display
    @State private var searchVocabText: String = ""
    @State private var copiedVocab: Bool = false
    @State private var showPromptManagerSheet: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Top Modern macOS Segmented Navigation Bar
            topNavigationBar
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)
            
            Divider()
                .opacity(0.3)
            
            // Tab Content Container
            ZStack {
                switch selectedTab {
                case .vocabulary:
                    vocabularyTab
                case .display:
                    displayTab
                case .speech:
                    speechTab
                case .general:
                    generalTab
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 560, height: 460)
        .background(
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
        )
        .sheet(isPresented: $showPromptManagerSheet) {
            QuickPromptManagerSheet()
        }
    }
    
    // MARK: - Top Segmented Navigation Bar
    private var topNavigationBar: some View {
        HStack(spacing: 6) {
            ForEach(SettingsTab.allCases) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                        Text(tab.rawValue)
                            .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundColor(selectedTab == tab ? .white : .primary.opacity(0.8))
                    .background(
                        selectedTab == tab ? Color.blue : Color.primary.opacity(0.04)
                    )
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }
    
    // MARK: - Tab 1: Sổ từ vựng
    private var vocabularyTab: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Button(action: {
                    VocabularyWindowController.shared.showNotebook()
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "book.pages.fill")
                        Text("Mở Sổ Tay Từ Vựng Chuyên Sâu (Cửa sổ lớn) ↗")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
            
            let filtered = filteredWords
            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "character.book.closed")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(vocabService.savedWords.isEmpty ? "Chưa có từ vựng nào được lưu." : "Không tìm thấy từ khớp.")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filtered) { item in
                            HStack(alignment: .center, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(item.word)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        if let ph = item.phonetic, !ph.isEmpty {
                                            Text(ph)
                                                .font(.system(size: 10.5, design: .serif))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Text(item.translation)
                                        .font(.system(size: 11.5))
                                        .foregroundColor(.blue)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    SpeechService.shared.speak(text: item.word, languageCode: "en-US", speakerID: "vocab_\(item.id.uuidString)")
                                }) {
                                    Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "vocab_\(item.id.uuidString)") ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: {
                                    vocabService.removeWord(id: item.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(6)
                        }
                    }
                }
            }
        }
    }
    
    private var filteredWords: [SavedWordItem] {
        let q = searchVocabText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return vocabService.savedWords }
        return vocabService.savedWords.filter {
            $0.word.lowercased().contains(q) || $0.translation.lowercased().contains(q)
        }
    }
    
    // MARK: - Tab 2: Hiển thị từ dịch
    private var displayTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                settingCard(title: "Ngôn ngữ đích mặc định", icon: "globe") {
                    Picker("Dịch tự động sang:", selection: $settings.targetLanguage) {
                        ForEach(TargetLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 12))
                }
                
                settingCard(title: "Chế độ hiển thị bản dịch đoạn văn", icon: "rectangle.stack.badge.plus") {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("", selection: $settings.translationDisplayMode) {
                            ForEach(TranslationDisplayMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)
                        .font(.system(size: 12))
                    }
                }
                
                settingCard(title: "Tùy chọn hiển thị chi tiết trong từ điển", icon: "slider.horizontal.3") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Hiển thị phiên âm quốc tế IPA (Phonetics)", isOn: $settings.showPhonetics)
                            .font(.system(size: 12))
                        
                        Toggle("Hiển thị câu ví dụ mẫu thực tế (Examples)", isOn: $settings.showExamples)
                            .font(.system(size: 12))
                        
                        Toggle("Hiển thị thẻ từ đồng nghĩa & trái nghĩa (Synonyms / Antonyms)", isOn: $settings.showSynonyms)
                            .font(.system(size: 12))
                        
                        Toggle("Hiển thị từ điển hệ thống macOS khi offline", isOn: $settings.showOfflineDictionary)
                            .font(.system(size: 12))
                    }
                }
                
                // Biểu Tượng Logo & Menu Bar (App Logo & Icons)
                settingCard(title: "Biểu Tượng Logo & Menu Bar", icon: "app.badge.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Chọn biểu tượng hiển thị trên Menu Bar và thanh công cụ ứng dụng:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                            ForEach(AppIconType.allCases) { iconType in
                                Button(action: {
                                    if iconType == .custom && iconService.customImageName == nil {
                                        iconService.importCustomImage()
                                    } else {
                                        iconService.selectIcon(iconType)
                                    }
                                }) {
                                    VStack(spacing: 5) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(iconService.selectedType == iconType ? iconType.accentColor.opacity(0.15) : Color.primary.opacity(0.04))
                                                .frame(width: 34, height: 34)
                                            
                                            if iconType == .defaultCat {
                                                AppLogo.image
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 22, height: 22)
                                            } else if iconType == .custom {
                                                if iconService.customImageName != nil {
                                                    iconService.currentImage
                                                        .resizable()
                                                        .scaledToFit()
                                                        .frame(width: 22, height: 22)
                                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                                } else {
                                                    Image(systemName: "plus.circle.fill")
                                                        .font(.system(size: 16))
                                                        .foregroundColor(.green)
                                                }
                                            } else if let sym = iconType.sfSymbol {
                                                Image(systemName: sym)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(iconType.accentColor)
                                            }
                                        }
                                        
                                        Text(iconType.rawValue)
                                            .font(.system(size: 10, weight: iconService.selectedType == iconType ? .bold : .regular))
                                            .foregroundColor(iconService.selectedType == iconType ? .primary : .secondary)
                                            .lineLimit(1)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(iconService.selectedType == iconType ? iconType.accentColor : Color.primary.opacity(0.08), lineWidth: iconService.selectedType == iconType ? 1.5 : 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                iconService.importCustomImage()
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "folder.badge.plus")
                                    Text(iconService.customImageName != nil ? "Đổi ảnh khác..." : "Tải ảnh từ máy (PNG/JPG)...")
                                }
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.primary.opacity(0.06))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            if iconService.selectedType != .defaultCat || iconService.customImageName != nil {
                                Button(action: {
                                    iconService.resetToDefault()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("Khôi phục mặc định")
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                
                // Mẫu Câu Hỏi Nhanh AI (Custom AI Prompts)
                settingCard(title: "Mẫu Câu Hỏi Nhanh Cho AI (Custom Prompts)", icon: "sparkles.rectangle.stack.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Tùy chỉnh các mẫu câu hỏi xuất hiện trên Trợ lý AI (Option + A):")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(promptService.activePrompts.count) / \(promptService.prompts.count) đang bật")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.purple.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        
                        VStack(spacing: 5) {
                            ForEach(promptService.prompts.prefix(4)) { item in
                                HStack(spacing: 6) {
                                    Image(systemName: item.isEnabled ? "eye.fill" : "eye.slash")
                                        .font(.system(size: 9.5))
                                        .foregroundColor(item.isEnabled ? .blue : .secondary.opacity(0.4))
                                    
                                    Text(item.icon)
                                        .font(.system(size: 12))
                                    Text(item.title)
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundColor(item.isEnabled ? .primary : .secondary)
                                    Text("• \(item.template)")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4.5)
                                .background(Color.primary.opacity(0.025))
                                .cornerRadius(5)
                                .opacity(item.isEnabled ? 1.0 : 0.6)
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                showPromptManagerSheet = true
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "slider.horizontal.3")
                                    Text("Quản lý, Sắp xếp & Thêm mẫu...")
                                }
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.purple.opacity(0.12))
                                .foregroundColor(.purple)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }
    
    // MARK: - Tab 3: Âm thanh
    private var speechTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                settingCard(title: "Tốc độ phát âm (Speech Rate)", icon: "speedometer") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Rất chậm")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2fx (Chuẩn tự nhiên)", settings.speechRate))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.blue)
                            Spacer()
                            Text("Nhanh")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $settings.speechRate, in: 0.15...0.65, step: 0.02)
                            .accentColor(.blue)
                        
                        HStack(spacing: 8) {
                            Button("Nghe thử TA") {
                                SpeechService.shared.speak(
                                    text: "Hello, this is a pronunciation test.",
                                    languageCode: "en-US",
                                    speakerID: "test_en"
                                )
                            }
                            .font(.system(size: 11))
                            
                            Button("Nghe thử TV") {
                                SpeechService.shared.speak(
                                    text: "Xin chào, đây là giọng đọc thử nghiệm tiếng Việt.",
                                    languageCode: "vi-VN",
                                    speakerID: "test_vi"
                                )
                            }
                            .font(.system(size: 11))
                        }
                        .padding(.top, 2)
                    }
                }
                
                settingCard(title: "Tùy chọn đọc tự động", icon: "speaker.wave.2") {
                    Toggle("Tự động phát âm khi tra từ đơn tiếng Anh", isOn: $settings.autoSpeakWord)
                        .font(.system(size: 12))
                }
            }
        }
    }
    
    // MARK: - Tab 4: Chung
    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                settingCard(title: "Phím tắt toàn hệ thống (Global Hotkey)", icon: "command") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Dịch nhanh từ / câu đã bôi đen")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Bôi đen văn bản bất kỳ rồi bấm phím tắt để mở cửa sổ dịch.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("⌥ + D")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(5)
                    }
                }
                
                settingCard(title: "Hành vi cửa sổ", icon: "macwindow") {
                    Toggle("Tự động ẩn cửa sổ dịch khi bấm ra ngoài", isOn: $settings.clickOutsideDismiss)
                        .font(.system(size: 12))
                }
                
                settingCard(title: "Khởi động", icon: "power") {
                    Toggle("Tự động khởi chạy cùng macOS khi đăng nhập", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    ))
                    .font(.system(size: 12))
                }
            }
        }
    }
    
    // MARK: - Custom Card Container
    private func settingCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.025))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - SwiftUI Preview
#Preview("Settings View") {
    SettingsView()
}
