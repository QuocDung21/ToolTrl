import SwiftUI
import AppKit

public struct AddWordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var speechService = SpeechService.shared
    
    public let editingItem: SavedWordItem?
    
    @State private var word: String = ""
    @State private var phonetic: String = ""
    @State private var translation: String = ""
    @State private var exampleEn: String = ""
    @State private var exampleVi: String = ""
    @State private var isLookingUp: Bool = false
    @State private var lookupError: String? = nil
    
    private let debounceDelay: TimeInterval = 0.6
    @State private var lookupTask: Task<Void, Never>? = nil
    
    public init(initialWord: String = "", editingItem: SavedWordItem? = nil) {
        self.editingItem = editingItem
        if let item = editingItem {
            _word = State(initialValue: item.word)
            _phonetic = State(initialValue: item.phonetic ?? "")
            _translation = State(initialValue: item.translation)
            _exampleEn = State(initialValue: item.exampleEn ?? "")
            _exampleVi = State(initialValue: item.exampleVi ?? "")
        } else {
            _word = State(initialValue: initialWord)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: editingItem != nil ? "square.and.pencil" : "book.closed.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(editingItem != nil ? .orange : .blue)
                    Text(editingItem != nil ? "Chỉnh Sửa Từ Vựng" : "Thêm Từ Vựng Mới")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.03))
            
            Divider()
            
            // MARK: - Form Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Information hint banner
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13))
                            .foregroundColor(editingItem != nil ? .orange : .blue)
                        
                        Text(editingItem != nil
                            ? "Chỉnh sửa từ vựng, phiên âm IPA, nghĩa hoặc câu ví dụ. Bạn cũng có thể bấm 'Tra tự động' để cập nhật nhanh từ điển."
                            : "Nhập từ vựng hoặc cụm từ tiếng Anh. Hệ thống có thể tự động tra cứu phiên âm IPA, dịch nghĩa và câu ví dụ minh họa."
                        )
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                    .padding(10)
                    .background((editingItem != nil ? Color.orange : Color.blue).opacity(0.06))
                    .cornerRadius(8)
                    
                    // Field 1: Word / Term
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Từ vựng / Cụm từ (Bắt buộc):")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if isLookingUp {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.55)
                                        .frame(width: 14, height: 14)
                                    Text("Đang tra cứu...")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                Button(action: {
                                    manualLookup()
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "sparkle.magnifyingglass")
                                        Text("Tra tự động")
                                    }
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .disabled(word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        
                        TextField("Ví dụ: resilient, state-of-the-art, catch on...", text: $word)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13, weight: .medium))
                            .onChange(of: word) { _, newValue in
                                scheduleAutoLookup(for: newValue)
                            }
                        
                        if let dup = existingDuplicateItem {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .foregroundColor(.orange)
                                Text("Từ '\(dup.cleanTitle)' đã có trong Sổ tay. Bấm lưu sẽ cập nhật nội dung mới.")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(5)
                        }
                    }
                    
                    // Field 2: Phonetic (IPA)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Phiên âm IPA (Tùy chọn):")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Button(action: {
                                    playPronunciation()
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: "speaker.wave.2.fill")
                                        Text("Nghe phát âm")
                                    }
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        TextField("Ví dụ: /rɪˈzɪl.jənt/", text: $phonetic)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5, design: .serif))
                    }
                    
                    // Field 3: Vietnamese Translation
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nghĩa tiếng Việt (Bắt buộc):")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.primary)
                        
                        TextField("Ví dụ: kiên cường, có khả năng phục hồi nhanh chóng", text: $translation)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5))
                    }
                    
                    // Field 4: Example Sentence (EN)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Câu ví dụ tiếng Anh (Tùy chọn):")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.primary)
                        
                        TextField("Ví dụ: The local economy proved to be remarkably resilient.", text: $exampleEn)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5))
                    }
                    
                    // Field 5: Example Translation (VI)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Dịch câu ví dụ (Tùy chọn):")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.primary)
                        
                        TextField("Ví dụ: Nền kinh tế địa phương tỏ ra có khả năng phục hồi đáng kể.", text: $exampleVi)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5))
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // MARK: - Footer Actions
            HStack(spacing: 12) {
                Button("Hủy") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                // Secondary: Save & Open AI Analysis
                Button(action: {
                    saveWord(openAI: true)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                        Text("Lưu & Phân tích AI")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .disabled(isSaveDisabled)
                .help("Lưu vào sổ tay và tự động mở Trợ lý AI để phân tích chuyên sâu")
                
                // Primary: Save to Notebook
                Button(action: {
                    saveWord(openAI: false)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: editingItem != nil ? "checkmark.circle.fill" : (existingDuplicateItem != nil ? "arrow.triangle.2.circlepath" : "plus.circle.fill"))
                        Text(editingItem != nil ? "Lưu thay đổi" : (existingDuplicateItem != nil ? "Cập nhật từ vựng" : "Lưu vào sổ tay"))
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(editingItem != nil ? .blue : (existingDuplicateItem != nil ? .orange : .blue))
                .disabled(isSaveDisabled)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 500, height: 490)
        .background(
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                Color(nsColor: .windowBackgroundColor).opacity(0.98)
            }
        )
        .onAppear {
            if editingItem == nil {
                let initial = word.trimmingCharacters(in: .whitespacesAndNewlines)
                if !initial.isEmpty && translation.isEmpty {
                    manualLookup()
                }
            }
        }
    }
    
    private var existingDuplicateItem: SavedWordItem? {
        let clean = word.replacingOccurrences(of: "📐", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }
        return vocabService.savedWords.first { item in
            if let edit = editingItem, item.id == edit.id {
                return false
            }
            return item.cleanTitle.lowercased() == clean || item.word.lowercased() == clean
        }
    }
    
    private var isSaveDisabled: Bool {
        word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Auto-Lookup Logic
    private func scheduleAutoLookup(for text: String) {
        lookupTask?.cancel()
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count >= 2 else { return }
        
        lookupTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(debounceDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await performLookup(for: clean)
        }
    }
    
    private func manualLookup() {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        lookupTask?.cancel()
        Task {
            await performLookup(for: clean)
        }
    }
    
    @MainActor
    private func performLookup(for term: String) async {
        isLookingUp = true
        defer { isLookingUp = false }
        
        // 1. Try Smart Dictionary for rich data (Phonetics, Meanings, Examples)
        let rich = await SmartDictionaryService.shared.fetchRichEntry(for: term, targetLanguage: "vi")
        
        if let rich = rich {
            if phonetic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let ph = rich.phonetic, !ph.isEmpty {
                self.phonetic = ph
            }
            
            if translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !rich.mainTranslation.isEmpty {
                self.translation = rich.mainTranslation
            }
            
            // Try extracting first good example
            if exampleEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                for group in rich.meanings {
                    if let def = group.definitions.first(where: { $0.exampleEn != nil && !$0.exampleEn!.isEmpty }) {
                        self.exampleEn = def.exampleEn ?? ""
                        if self.exampleVi.isEmpty, let exVi = def.exampleVi, !exVi.isEmpty {
                            self.exampleVi = exVi
                        }
                        break
                    }
                }
            }
        }
        
        // 2. If translation is still empty, translate directly
        if self.translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let directTrans = await TranslationService.shared.translate(text: term, from: "auto", to: "vi"),
               !directTrans.isEmpty && directTrans.lowercased() != term.lowercased() {
                self.translation = directTrans
            }
        }
        
        // 3. If example translation is still empty but exampleEn is present, translate example
        let cleanExEn = exampleEn.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanExEn.isEmpty && exampleVi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let exTrans = await TranslationService.shared.translate(text: cleanExEn, from: "auto", to: "vi"),
               !exTrans.isEmpty {
                self.exampleVi = exTrans
            }
        }
    }
    
    // MARK: - Pronunciation
    private func playPronunciation() {
        let clean = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        speechService.speak(text: clean, languageCode: "en-US", speakerID: "add_word_\(clean)")
    }
    
    // MARK: - Save Actions
    private func saveWord(openAI: Bool) {
        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTrans = translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanWord.isEmpty, !cleanTrans.isEmpty else { return }
        
        let ph = phonetic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : phonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        let exEn = exampleEn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : exampleEn.trimmingCharacters(in: .whitespacesAndNewlines)
        let exVi = exampleVi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : exampleVi.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let targetId: UUID
        if let editing = editingItem {
            vocabService.updateWord(
                id: editing.id,
                word: cleanWord,
                phonetic: ph,
                translation: cleanTrans,
                exampleEn: exEn,
                exampleVi: exVi
            )
            targetId = editing.id
        } else {
            guard let savedId = vocabService.addWord(
                word: cleanWord,
                phonetic: ph,
                translation: cleanTrans,
                exampleEn: exEn,
                exampleVi: exVi
            ) else { return }
            targetId = savedId
        }
        
        dismiss()
        
        if openAI {
            let prompt = AIPromptBuilder.structuredWordPrompt(for: cleanWord)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                QuickAIWindowController.shared.showAI(
                    prompt: prompt,
                    targetWordId: targetId,
                    targetWordTitle: cleanWord
                )
            }
        }
    }
}
