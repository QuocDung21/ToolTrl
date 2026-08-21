import SwiftUI

public enum NotebookFilter: String, CaseIterable, Identifiable {
    case all = "Tất cả"
    case learning = "Đang học"
    case mastered = "Đã thuộc"
    case favorite = "Yêu thích"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .all: return "books.vertical.fill"
        case .learning: return "book.fill"
        case .mastered: return "checkmark.seal.fill"
        case .favorite: return "star.fill"
        }
    }
}

public struct VocabularyNotebookView: View {
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var speechService = SpeechService.shared
    
    @State private var selectedFilter: NotebookFilter = .all
    @State private var searchText: String = ""
    @State private var selectedWordID: UUID? = nil
    @State private var isFlashcardMode: Bool = false
    @State private var flashcardIndex: Int = 0
    @State private var isCardFlipped: Bool = false
    @State private var copied: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if isFlashcardMode {
                flashcardStudyView
            } else {
                mainNotebookView
            }
        }
        .frame(minWidth: 780, minHeight: 520)
        .background(
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
        )
        .onAppear {
            if selectedWordID == nil, let first = filteredWords.first {
                selectedWordID = first.id
            }
        }
    }
    
    // MARK: - Main 2-Column Notebook View
    private var mainNotebookView: some View {
        HStack(spacing: 0) {
            // LEFT COLUMN: Binder & Word List
            sidebarView
                .frame(width: 300)
            
            Divider()
                .opacity(0.3)
            
            // RIGHT COLUMN: Beautiful Journal Page
            detailPageView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Left Sidebar: Word List & Stats
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Header Notebook Title & Flashcard Button
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                    Text("Sổ Tay Từ Vựng")
                        .font(.system(size: 13.5, weight: .bold))
                }
                
                Spacer()
                
                // Flashcard Button
                Button(action: {
                    if !filteredWords.isEmpty {
                        flashcardIndex = 0
                        isCardFlipped = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isFlashcardMode = true
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled.fill")
                            .font(.system(size: 10))
                        Text("Flashcard")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Color.orange.opacity(0.18))
                    .foregroundColor(.orange)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(filteredWords.isEmpty)
                .help("Luyện tập ghi nhớ từ vựng với Flashcard")
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField("Tìm từ tiếng Anh hoặc nghĩa...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5.5)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(6)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
            
            // Filter Segmented Chips
            HStack(spacing: 4) {
                ForEach(NotebookFilter.allCases) { filter in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedFilter = filter
                            if let first = filteredWords.first {
                                selectedWordID = first.id
                            }
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 9))
                            Text(filter.rawValue)
                                .font(.system(size: 10.5, weight: selectedFilter == filter ? .bold : .medium))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .foregroundColor(selectedFilter == filter ? .white : .primary.opacity(0.7))
                        .background(
                            selectedFilter == filter ? Color.orange : Color.primary.opacity(0.04)
                        )
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            
            Divider()
                .opacity(0.2)
            
            // Words List
            let words = filteredWords
            if words.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "book.closed")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.35))
                    Text(vocabService.savedWords.isEmpty ? "Chưa có từ nào trong sổ." : "Không có từ phù hợp.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(words) { item in
                            wordRowItem(item: item, isSelected: selectedWordID == item.id)
                                .onTapGesture {
                                    selectedWordID = item.id
                                }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
            
            Divider()
                .opacity(0.2)
            
            // Bottom Stats Bar
            HStack {
                Text("Tổng cộng: **\(vocabService.savedWords.count)** từ")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: exportAllVocabulary) {
                    HStack(spacing: 3) {
                        Image(systemName: copied ? "checkmark" : "square.and.arrow.up")
                        Text(copied ? "Đã sao chép" : "Xuất từ")
                    }
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(Color.primary.opacity(0.015))
    }
    
    // MARK: - Word Row Item in Sidebar
    private func wordRowItem(item: SavedWordItem, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.word)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    if item.isMastered {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? .white.opacity(0.9) : .green)
                    }
                    
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundColor(isSelected ? .yellow : .orange)
                    }
                }
                
                Text(item.translation)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button(action: {
                SpeechService.shared.speak(text: item.word, languageCode: "en-US", speakerID: "row_\(item.id.uuidString)")
            }) {
                Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "row_\(item.id.uuidString)") ? "speaker.wave.3.fill" : "speaker.wave.2")
                    .font(.system(size: 10.5))
                    .foregroundColor(isSelected ? .white : .blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Color.orange : Color.clear)
        )
        .contentShape(Rectangle())
    }
    
    // MARK: - Right Detail: The Aesthetic Journal Page
    private var detailPageView: some View {
        Group {
            if let selectedID = selectedWordID,
               let word = vocabService.savedWords.first(where: { $0.id == selectedID }) {
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Top Word Bar & Navigation
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(word.word)
                                    .font(.system(size: 28, weight: .heavy, design: .serif))
                                    .foregroundColor(.primary)
                                
                                if let ph = word.phonetic, !ph.isEmpty {
                                    Text(ph)
                                        .font(.system(size: 14, weight: .medium, design: .serif))
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Spacer()
                            
                            // Audio Speaker Large Button
                            Button(action: {
                                SpeechService.shared.speak(text: word.word, languageCode: "en-US", speakerID: "detail_\(word.id.uuidString)")
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "detail_\(word.id.uuidString)") ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 13))
                                    Text("Phát âm")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.blue.opacity(0.12))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Divider()
                            .opacity(0.3)
                        
                        // Translation Meaning Card
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                    .foregroundColor(.orange)
                                Text("Ý NGHĨA TIẾNG VIỆT")
                                    .font(.system(size: 10.5, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(word.translation)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                                .lineSpacing(4)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.06))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.orange.opacity(0.18), lineWidth: 1)
                        )
                        
                        // Action Buttons Bar (Mastered, Favorite, Delete)
                        HStack(spacing: 12) {
                            Button(action: {
                                vocabService.toggleMastered(id: word.id)
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: word.isMastered ? "checkmark.seal.fill" : "circle")
                                        .foregroundColor(word.isMastered ? .green : .secondary)
                                    Text(word.isMastered ? "Đã thuộc từ này" : "Đánh dấu đã thuộc")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(word.isMastered ? Color.green.opacity(0.12) : Color.primary.opacity(0.04))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: {
                                vocabService.toggleFavorite(id: word.id)
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: word.isFavorite ? "star.fill" : "star")
                                        .foregroundColor(word.isFavorite ? .orange : .secondary)
                                    Text(word.isFavorite ? "Đã yêu thích" : "Yêu thích")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(word.isFavorite ? Color.orange.opacity(0.12) : Color.primary.opacity(0.04))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            Button(action: {
                                vocabService.removeWord(id: word.id)
                                if let next = filteredWords.first {
                                    selectedWordID = next.id
                                } else {
                                    selectedWordID = nil
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("Xóa")
                                }
                                .font(.system(size: 11.5))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Date Added Footer
                        HStack {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text("Ngày lưu: \(formattedDate(word.dateAdded))")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.top, 10)
                    }
                    .padding(24)
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "hand.tap")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Chọn một từ vựng bên trái để mở trang sổ chi tiết")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    // MARK: - Flashcard Study View
    private var flashcardStudyView: some View {
        let words = filteredWords
        guard !words.isEmpty, flashcardIndex < words.count else {
            return AnyView(
                VStack {
                    Text("Không có từ vựng nào để luyện tập.")
                    Button("Quay lại Sổ tay") { isFlashcardMode = false }
                }
            )
        }
        
        let currentWord = words[flashcardIndex]
        
        return AnyView(
            VStack(spacing: 20) {
                // Header
                HStack {
                    Button(action: {
                        withAnimation(.spring()) {
                            isFlashcardMode = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Quay lại Sổ tay")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Text("Thẻ \(flashcardIndex + 1) / \(words.count)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                // 3D Flip Card
                ZStack {
                    if !isCardFlipped {
                        // FRONT OF CARD: English Word + Pronounce
                        VStack(spacing: 12) {
                            Text("TIẾNG ANH")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                                .tracking(1.5)
                            
                            Text(currentWord.word)
                                .font(.system(size: 34, weight: .bold, design: .serif))
                                .foregroundColor(.primary)
                            
                            if let ph = currentWord.phonetic, !ph.isEmpty {
                                Text(ph)
                                    .font(.system(size: 16, design: .serif))
                                    .foregroundColor(.orange)
                            }
                            
                            Button(action: {
                                SpeechService.shared.speak(text: currentWord.word, languageCode: "en-US", speakerID: "fc_\(currentWord.id.uuidString)")
                            }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .padding(10)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            
                            Text("Chạm để lật xem nghĩa 👉")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.7))
                                .padding(.top, 10)
                        }
                    } else {
                        // BACK OF CARD: Vietnamese Meaning
                        VStack(spacing: 12) {
                            Text("Ý NGHĨA")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.orange)
                                .tracking(1.5)
                            
                            Text(currentWord.translation)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Text("Chạm để lật lại")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary.opacity(0.7))
                                .padding(.top, 10)
                        }
                    }
                }
                .frame(width: 440, height: 260)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isCardFlipped.toggle()
                    }
                }
                
                Spacer()
                
                // Bottom Review Controls (Remembered / Need Review)
                HStack(spacing: 20) {
                    Button(action: {
                        nextCard()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Chưa nhớ (Ôn lại)")
                        }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.orange)
                        .frame(width: 160, height: 38)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        vocabService.toggleMastered(id: currentWord.id)
                        nextCard()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("Đã nhớ 👍")
                        }
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 160, height: 38)
                        .background(Color.green)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 24)
            }
        )
    }
    
    private func nextCard() {
        isCardFlipped = false
        if flashcardIndex + 1 < filteredWords.count {
            withAnimation(.easeInOut(duration: 0.2)) {
                flashcardIndex += 1
            }
        } else {
            withAnimation(.spring()) {
                isFlashcardMode = false
            }
        }
    }
    
    private var filteredWords: [SavedWordItem] {
        var list = vocabService.savedWords
        
        switch selectedFilter {
        case .all:
            break
        case .learning:
            list = list.filter { !$0.isMastered }
        case .mastered:
            list = list.filter { $0.isMastered }
        case .favorite:
            list = list.filter { $0.isFavorite }
        }
        
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.word.lowercased().contains(q) || $0.translation.lowercased().contains(q)
            }
        }
        return list
    }
    
    private func exportAllVocabulary() {
        let lines = vocabService.savedWords.map { item in
            let ph = item.phonetic != nil ? " [\(item.phonetic!)]" : ""
            return "\(item.word)\(ph) - \(item.translation)"
        }
        let fullText = lines.joined(separator: "\n")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fullText, forType: .string)
        
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            copied = false
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - SwiftUI Preview
#Preview("Vocabulary Notebook") {
    VocabularyNotebookView()
}
