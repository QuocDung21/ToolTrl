import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var speechService = SpeechService.shared
    
    @State private var searchVocabText: String = ""
    @State private var copiedVocab: Bool = false
    @State private var testTextEn = "Hello! This is a speech rate test."
    @State private var testTextVi = "Xin chào! Đây là bài kiểm tra tốc độ đọc."
    
    public init() {}
    
    public var body: some View {
        TabView {
            vocabularyTab
                .tabItem {
                    Label("Sổ từ vựng (\(vocabService.savedWords.count))", systemImage: "bookmark.fill")
                }
            
            displayTab
                .tabItem {
                    Label("Hiển thị từ dịch", systemImage: "character.book.closed.fill")
                }
            
            speechTab
                .tabItem {
                    Label("Âm thanh", systemImage: "speaker.wave.3.fill")
                }
            
            generalTab
                .tabItem {
                    Label("Chung", systemImage: "gearshape.fill")
                }
        }
        .frame(width: 520, height: 380)
        .padding(16)
    }
    
    // MARK: - Tab 1: Sổ từ vựng đã lưu (Saved Vocabulary)
    private var vocabularyTab: some View {
        VStack(spacing: 10) {
            // Header Search & Actions
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                    TextField("Tìm kiếm từ vựng đã lưu...", text: $searchVocabText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.04))
                .cornerRadius(6)
                
                // Export / Copy to Clipboard
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
                .help("Sao chép danh sách từ để học trên Anki / Flashcards")
                
                // Clear All Button
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
            
            Divider()
                .opacity(0.3)
            
            // List of Saved Words
            let filtered = filteredWords
            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(vocabService.savedWords.isEmpty ? "Chưa có từ vựng nào được lưu." : "Không tìm thấy từ phù hợp.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    if vocabService.savedWords.isEmpty {
                        Text("Bấm vào icon 🔖 bookmark trên popup tra từ để lưu từ mới vào sổ.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filtered) { item in
                            HStack(alignment: .center, spacing: 8) {
                                // Word & Phonetic
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(item.word)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        if let ph = item.phonetic, !ph.isEmpty {
                                            Text(ph)
                                                .font(.system(size: 11, design: .serif))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Text(item.translation)
                                        .font(.system(size: 11.5))
                                        .foregroundColor(.blue)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                                
                                // Pronounce Button
                                Button(action: {
                                    SpeechService.shared.speak(text: item.word, languageCode: "en-US", speakerID: "vocab_\(item.id.uuidString)")
                                }) {
                                    Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "vocab_\(item.id.uuidString)") ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .help("Nghe phát âm")
                                
                                // Delete Button
                                Button(action: {
                                    vocabService.removeWord(id: item.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .help("Xóa từ này")
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.primary.opacity(0.025))
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
    
    // MARK: - Tab 2: Tùy chọn Hiển thị từ dịch
    private var displayTab: some View {
        Form {
            Section(header: Text("Ngôn ngữ đích mặc định").font(.system(size: 12, weight: .bold))) {
                Picker("Dịch sang:", selection: $settings.targetLanguage) {
                    ForEach(TargetLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 12))
            }
            
            Section(header: Text("Chi tiết hiển thị trong từ điển").font(.system(size: 12, weight: .bold))) {
                Toggle("Hiển thị phiên âm quốc tế IPA (Phonetics)", isOn: $settings.showPhonetics)
                    .font(.system(size: 12))
                
                Toggle("Hiển thị câu ví dụ mẫu thực tế (Examples)", isOn: $settings.showExamples)
                    .font(.system(size: 12))
                
                Toggle("Hiển thị thẻ từ đồng nghĩa & trái nghĩa (Synonyms / Antonyms)", isOn: $settings.showSynonyms)
                    .font(.system(size: 12))
                
                Toggle("Hiển thị từ điển hệ thống macOS khi không có mạng", isOn: $settings.showOfflineDictionary)
                    .font(.system(size: 12))
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - Tab 3: Âm thanh (Speech Settings)
    private var speechTab: some View {
        Form {
            Section(header: Text("Tốc độ phát âm (Speech Rate)").font(.system(size: 12, weight: .bold))) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rất chậm")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Slider(value: $settings.speechRate, in: 0.15...0.65, step: 0.02)
                        
                        Text("Nhanh")
                            .font(.system(size: 11))
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
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        SpeechService.shared.speak(text: testTextEn, languageCode: "en-US", speakerID: "test_en")
                    }) {
                        Label("Nghe thử (English)", systemImage: "play.circle.fill")
                    }
                    
                    Button(action: {
                        SpeechService.shared.speak(text: testTextVi, languageCode: "vi-VN", speakerID: "test_vi")
                    }) {
                        Label("Nghe thử (Tiếng Việt)", systemImage: "play.circle.fill")
                    }
                }
                .padding(.top, 4)
            }
            
            Section(header: Text("Tùy chọn tự động").font(.system(size: 12, weight: .bold))) {
                Toggle("Tự động đọc từ khi mở cửa sổ tra cứu", isOn: $settings.autoSpeakWord)
                    .font(.system(size: 12))
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - Tab 4: Chung & Phím tắt
    private var generalTab: some View {
        Form {
            Section(header: Text("Phím tắt toàn hệ thống").font(.system(size: 12, weight: .bold))) {
                HStack {
                    Text("Dịch nhanh văn bản bôi đen:")
                        .font(.system(size: 12))
                    Spacer()
                    Text("Option + D (⌥D)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(5)
                }
            }
            
            Section(header: Text("Hành vi ứng dụng").font(.system(size: 12, weight: .bold))) {
                Toggle("Khởi động cùng macOS", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                .font(.system(size: 12))
                
                Toggle("Tự động đóng popup khi click ra ngoài", isOn: $settings.clickOutsideDismiss)
                    .font(.system(size: 12))
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - SwiftUI Preview
#Preview("Settings View") {
    SettingsView()
}
