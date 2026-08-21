import SwiftUI

public enum SettingsTab: String, CaseIterable, Identifiable {
    case vocabulary = "Sổ từ vựng"
    case display = "Hiển thị"
    case speech = "Âm thanh"
    case general = "Chung"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .vocabulary: return "bookmark.fill"
        case .display: return "character.book.closed.fill"
        case .speech: return "speaker.wave.3.fill"
        case .general: return "gearshape.fill"
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var speechService = SpeechService.shared
    
    @State private var selectedTab: SettingsTab = .vocabulary
    @State private var searchVocabText: String = ""
    @State private var copiedVocab: Bool = false
    @State private var testTextEn = "Hello! This is a speech rate test."
    @State private var testTextVi = "Xin chào! Đây là bài kiểm tra tốc độ đọc."
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Modern Top Segmented Tab Bar
            topTabBar
            
            Divider()
                .opacity(0.3)
            
            // Tab Content
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
        }
        .frame(width: 500, height: 420)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
    }
    
    // MARK: - Top Tab Bar
    private var topTabBar: some View {
        HStack(spacing: 6) {
            ForEach(SettingsTab.allCases) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 11))
                        
                        Text(tab.rawValue)
                            .font(.system(size: 11.5, weight: selectedTab == tab ? .semibold : .regular))
                        
                        if tab == .vocabulary && !vocabService.savedWords.isEmpty {
                            Text("\(vocabService.savedWords.count)")
                                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 1)
                                .background(selectedTab == tab ? Color.white.opacity(0.3) : Color.primary.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .foregroundColor(selectedTab == tab ? .white : .primary.opacity(0.8))
                    .background(
                        Group {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue)
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.clear)
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }
    
    // MARK: - Tab 1: Sổ từ vựng (Saved Vocabulary)
    private var vocabularyTab: some View {
        VStack(spacing: 10) {
            // Search & Actions Bar
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("Tìm từ đã lưu hoặc nghĩa tiếng Việt...", text: $searchVocabText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
                
                Button(action: {
                    exportVocabulary()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: copiedVocab ? "checkmark" : "square.and.arrow.up")
                            .font(.system(size: 10))
                        Text(copiedVocab ? "Đã sao chép" : "Xuất từ")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(vocabService.savedWords.isEmpty)
                .help("Sao chép danh sách từ để nhập vào Anki / Flashcards")
                
                if !vocabService.savedWords.isEmpty {
                    Button(action: {
                        vocabService.clearAll()
                    }) {
                        Text("Xóa hết")
                            .font(.system(size: 11))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            let filtered = filteredWords
            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text(vocabService.savedWords.isEmpty ? "Chưa có từ vựng nào trong sổ." : "Không tìm thấy từ khớp.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    if vocabService.savedWords.isEmpty {
                        Text("Bấm vào icon 🔖 bookmark trên popup tra từ để lưu từ mới.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
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
                                .help("Nghe phát âm")
                                
                                Button(action: {
                                    vocabService.removeWord(id: item.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .help("Xóa từ này")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.8)
                            )
                        }
                    }
                    .padding(.vertical, 2)
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
    
    private func exportVocabulary() {
        let lines = vocabService.savedWords.map { item in
            let ph = item.phonetic != nil ? " [\(item.phonetic!)]" : ""
            return "\(item.word)\(ph) - \(item.translation)"
        }
        let fullText = lines.joined(separator: "\n")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullText, forType: .string)
        
        copiedVocab = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copiedVocab = false
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
                            
                            Slider(value: $settings.speechRate, in: 0.15...0.65, step: 0.02)
                            
                            Text("Nhanh")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            let desc: String = {
                                if settings.speechRate <= 0.25 { return "Rất chậm (0.5x)" }
                                if settings.speechRate <= 0.35 { return "Chậm (0.7x)" }
                                if settings.speechRate <= 0.45 { return "Vừa phải (1.0x - Chuẩn)" }
                                if settings.speechRate <= 0.55 { return "Hơi nhanh (1.2x)" }
                                return "Nhanh (1.5x)"
                            }()
                            Text("Tốc độ: \(String(format: "%.2f", settings.speechRate)) — \(desc)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.blue)
                            
                            Spacer()
                        }
                        
                        Divider()
                            .opacity(0.2)
                            .padding(.vertical, 2)
                        
                        HStack(spacing: 10) {
                            Button(action: {
                                SpeechService.shared.speak(text: testTextEn, languageCode: "en-US", speakerID: "test_en")
                            }) {
                                Label("Nghe thử (English)", systemImage: "play.circle.fill")
                                    .font(.system(size: 11.5))
                            }
                            
                            Button(action: {
                                SpeechService.shared.speak(text: testTextVi, languageCode: "vi-VN", speakerID: "test_vi")
                            }) {
                                Label("Nghe thử (Tiếng Việt)", systemImage: "play.circle.fill")
                                    .font(.system(size: 11.5))
                            }
                        }
                    }
                }
                
                settingCard(title: "Tùy chọn tự động", icon: "waveform") {
                    Toggle("Tự động đọc từ khi mở cửa sổ tra cứu", isOn: $settings.autoSpeakWord)
                        .font(.system(size: 12))
                }
            }
        }
    }
    
    // MARK: - Tab 4: Chung & Phím tắt
    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                settingCard(title: "Phím tắt toàn hệ thống", icon: "keyboard") {
                    HStack {
                        Text("Dịch nhanh văn bản bôi đen:")
                            .font(.system(size: 12))
                        Spacer()
                        Text("Option + D (⌥D)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.08))
                            .cornerRadius(5)
                    }
                }
                
                settingCard(title: "Hành vi ứng dụng", icon: "macwindow") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Khởi động cùng macOS", isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { settings.setLaunchAtLogin($0) }
                        ))
                        .font(.system(size: 12))
                        
                        Toggle("Tự động đóng popup khi click ra ngoài", isOn: $settings.clickOutsideDismiss)
                            .font(.system(size: 12))
                    }
                }
            }
        }
    }
    
    // Helper Card Container
    private func settingCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11.5))
                    .foregroundColor(.blue)
                Text(title)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(.primary.opacity(0.85))
            }
            
            content()
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        }
    }
}

// MARK: - SwiftUI Preview
#Preview("Settings View") {
    SettingsView()
}
