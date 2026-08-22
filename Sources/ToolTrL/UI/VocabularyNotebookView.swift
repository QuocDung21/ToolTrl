import SwiftUI

public enum NotebookCategory: String, CaseIterable, Identifiable {
    case vocabulary = "Từ vựng"
    case grammar = "Công thức ngữ pháp"
    case all = "Tất cả"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .vocabulary: return "character.book.closed.fill"
        case .grammar: return "function"
        case .all: return "books.vertical.fill"
        }
    }
}

public enum NotebookFilter: String, CaseIterable, Identifiable {
    case all = "Tất cả"
    case learning = "Đang học"
    case mastered = "Đã thuộc"
    case favorite = "Yêu thích"
    
    public var id: String { rawValue }
}

public struct VocabularyNotebookView: View {
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var speechService = SpeechService.shared
    
    @State private var selectedCategory: NotebookCategory = .vocabulary
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
        .frame(minWidth: 860, minHeight: 560)
        .background(
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
        )
        .ignoresSafeArea()
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
                .frame(width: 330)
            
            Divider()
                .opacity(0.3)
            
            // RIGHT COLUMN: Journal Detail Page
            detailPageView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    // MARK: - Left Sidebar: Word List & Stats
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // 1. Top Window Clearance Bar (Leaves space for macOS Traffic Lights)
            HStack {
                Spacer()
                    .frame(width: 72)
                
                Spacer()
                
                // AI Analysis Button
                Button(action: {
                    TextAnalysisWindowController.shared.showAnalysis()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 10.5))
                        Text("AI Phân Tích")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.purple.opacity(0.25), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .help("Đưa vào một đoạn văn và để AI tự động trích xuất từ vựng & cấu trúc ngữ pháp")
                
                // Flashcard Quick Action Button
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
                            .font(.system(size: 10.5))
                        Text("Flashcard")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.16))
                    .foregroundColor(.orange)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.orange.opacity(0.25), lineWidth: 0.8)
                    )
                }
                .buttonStyle(.plain)
                .disabled(filteredWords.isEmpty)
                .help("Ôn luyện dạng thẻ Flashcard")
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 6)
            
            // 2. Main Category Tabs: [ Từ vựng ] | [ Công thức ngữ pháp ] | [ Tất cả ]
            HStack(spacing: 4) {
                ForEach(NotebookCategory.allCases) { cat in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            selectedCategory = cat
                            if let first = filteredWords.first {
                                selectedWordID = first.id
                            }
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: cat.icon)
                                .font(.system(size: 10))
                            Text(cat.rawValue)
                                .font(.system(size: 11, weight: selectedCategory == cat ? .bold : .medium))
                            
                            // Badge count
                            let count = categoryCount(cat)
                            Text("\(count)")
                                .font(.system(size: 9.5, weight: .bold))
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 1)
                                .background(selectedCategory == cat ? Color.white.opacity(0.25) : Color.primary.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .foregroundColor(selectedCategory == cat ? .white : .secondary)
                        .background(
                            selectedCategory == cat ? (cat == .grammar ? Color.blue : Color.orange) : Color.primary.opacity(0.04)
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            // 3. Search Bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                TextField(selectedCategory == .grammar ? "Tìm kiếm công thức, cấu trúc..." : "Tìm kiếm từ vựng, nghĩa...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(7)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            
            // 4. Status Filter Pills
            HStack(spacing: 4) {
                ForEach(NotebookFilter.allCases) { filter in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            selectedFilter = filter
                            if let first = filteredWords.first {
                                selectedWordID = first.id
                            }
                        }
                    }) {
                        Text(filter.rawValue)
                            .font(.system(size: 10, weight: selectedFilter == filter ? .bold : .medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .foregroundColor(selectedFilter == filter ? (selectedCategory == .grammar ? .blue : .orange) : .secondary)
                            .background(selectedFilter == filter ? (selectedCategory == .grammar ? Color.blue.opacity(0.12) : Color.orange.opacity(0.12)) : Color.clear)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            
            Divider()
                .opacity(0.2)
            
            // 5. Scrollable Word / Formula List
            if filteredWords.isEmpty {
                emptyListView
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredWords) { item in
                            wordRowItem(item: item, isSelected: item.id == selectedWordID)
                                .onTapGesture {
                                    selectedWordID = item.id
                                }
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private func categoryCount(_ cat: NotebookCategory) -> Int {
        switch cat {
        case .all: return vocabService.savedWords.count
        case .vocabulary: return vocabService.savedWords.filter { !$0.isGrammarFormula }.count
        case .grammar: return vocabService.savedWords.filter { $0.isGrammarFormula }.count
        }
    }
    
    // MARK: - Word / Formula Row Item in Sidebar
    private func wordRowItem(item: SavedWordItem, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2.5) {
                HStack(spacing: 5) {
                    if item.isGrammarFormula {
                        Text("📐")
                            .font(.system(size: 10.5))
                    }
                    
                    Text(item.cleanTitle)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                    
                    if item.isMastered {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(isSelected ? .white.opacity(0.9) : .green)
                    }
                    
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9.5))
                            .foregroundColor(isSelected ? .yellow : .orange)
                    }
                }
                
                if item.isGrammarFormula, let formula = item.phonetic, !formula.isEmpty {
                    Text(formula)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(isSelected ? .white.opacity(0.9) : .blue)
                        .lineLimit(1)
                } else {
                    Text(item.translation)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if !item.isGrammarFormula {
                Button(action: {
                    speechService.speak(text: item.word, languageCode: "en-US", speakerID: "row_\(item.id.uuidString)")
                }) {
                    Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "row_\(item.id.uuidString)") ? "speaker.wave.3.fill" : "speaker.wave.2")
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? .white : .blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? (item.isGrammarFormula ? Color.blue : Color.orange) : Color.clear)
        )
        .contentShape(Rectangle())
    }
    
    // MARK: - Right Detail: Aesthetic Journal Page
    private var detailPageView: some View {
        Group {
            if let selectedID = selectedWordID,
               let item = vocabService.savedWords.first(where: { $0.id == selectedID }) {
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if item.isGrammarFormula {
                            grammarDetailPage(item: item)
                        } else {
                            vocabularyDetailPage(item: item)
                        }
                    }
                    .padding(24)
                }
                
            } else {
                emptySelectionView
            }
        }
    }
    
    // MARK: - Detail Page: Grammar Formula
    private func grammarDetailPage(item: SavedWordItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Image(systemName: "function")
                            .foregroundColor(.blue)
                        Text("CÔNG THỨC NGỮ PHÁP TIẾNG ANH")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    
                    Text(item.cleanTitle)
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                actionButtons(item: item)
            }
            
            Divider().opacity(0.25)
            
            // Formula Code Box
            if let formula = item.phonetic, !formula.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "curlybraces")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue)
                        Text("CÔNG THỨC TỔNG QUÁT")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(formula, forType: .string)
                            withAnimation { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "Đã chép" : "Sao chép")
                            }
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(formula)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.blue)
                        .padding(.vertical, 4)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(9)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                )
            }
            
            // Meaning & Usage Card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                    Text("Ý NGHĨA & CÁCH DÙNG")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                Text(item.translation)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.primary)
                    .lineSpacing(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.025))
            .cornerRadius(9)
            
            // Example Sentence
            if let exEn = item.exampleEn, !exEn.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.blue)
                        Text("VÍ DỤ THỰC TẾ TRONG ĐOẠN VĂN")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            speechService.speak(text: exEn, languageCode: "en-US", speakerID: "ex_\(item.id.uuidString)")
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("\"\(exEn)\"")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundColor(.primary)
                        .italic()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.025))
                .cornerRadius(9)
            }
        }
    }
    
    // MARK: - Detail Page: Vocabulary Word
    private func vocabularyDetailPage(item: SavedWordItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.word)
                        .font(.system(size: 30, weight: .heavy, design: .serif))
                        .foregroundColor(.primary)
                    
                    if let ph = item.phonetic, !ph.isEmpty {
                        Text(ph)
                            .font(.system(size: 14.5, weight: .medium, design: .serif))
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                // Pronounce Button
                Button(action: {
                    speechService.speak(text: item.word, languageCode: "en-US", speakerID: "detail_\(item.id.uuidString)")
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "detail_\(item.id.uuidString)") ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                            .font(.system(size: 13))
                        Text("Phát âm")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            Divider().opacity(0.25)
            
            // Translation Meaning Card
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("Ý NGHĨA TIẾNG VIỆT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                Text(item.translation)
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
            
            // Example Sentences
            if let exEn = item.exampleEn, !exEn.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                        Text("CÂU VÍ DỤ NGỮ CẢNH")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            speechService.speak(text: exEn, languageCode: "en-US", speakerID: "ex_\(item.id.uuidString)")
                        }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text("\"\(exEn)\"")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundColor(.primary)
                        .italic()
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.025))
                .cornerRadius(10)
            }
            
            // Action Buttons Bar
            actionButtons(item: item)
        }
    }
    
    // MARK: - Action Buttons
    private func actionButtons(item: SavedWordItem) -> some View {
        HStack(spacing: 8) {
            Button(action: {
                vocabService.toggleMastered(id: item.id)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: item.isMastered ? "checkmark.seal.fill" : "circle")
                        .foregroundColor(item.isMastered ? .green : .secondary)
                    Text(item.isMastered ? "Đã thuộc" : "Đánh dấu đã thuộc")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5.5)
                .background(item.isMastered ? Color.green.opacity(0.12) : Color.primary.opacity(0.04))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                vocabService.toggleFavorite(id: item.id)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .foregroundColor(item.isFavorite ? .orange : .secondary)
                    Text(item.isFavorite ? "Đã thích" : "Yêu thích")
                        .font(.system(size: 11.5, weight: .medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5.5)
                .background(item.isFavorite ? Color.orange.opacity(0.12) : Color.primary.opacity(0.04))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                vocabService.removeWord(id: item.id)
                if let next = filteredWords.first {
                    selectedWordID = next.id
                } else {
                    selectedWordID = nil
                }
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(6)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Xóa mục này")
        }
    }
    
    // MARK: - Filtered Words List
    private var filteredWords: [SavedWordItem] {
        var list = vocabService.savedWords
        
        // 1. Category Filter
        switch selectedCategory {
        case .vocabulary:
            list = list.filter { !$0.isGrammarFormula }
        case .grammar:
            list = list.filter { $0.isGrammarFormula }
        case .all:
            break
        }
        
        // 2. Status Filter
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
        
        // 3. Search Query
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.word.lowercased().contains(q) ||
                $0.translation.lowercased().contains(q) ||
                ($0.phonetic?.lowercased().contains(q) ?? false)
            }
        }
        
        return list
    }
    
    // MARK: - Empty States
    private var emptyListView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: selectedCategory == .grammar ? "function" : "character.book.closed")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.35))
            
            Text(emptyMessage)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyMessage: String {
        if !searchText.isEmpty {
            return "Không tìm thấy kết quả khớp với '\(searchText)'."
        }
        switch selectedCategory {
        case .grammar:
            return "Chưa có công thức ngữ pháp nào được lưu.\nHãy dùng tính năng 'AI Phân Tích' để tự động bóc tách từ bài đọc!"
        case .vocabulary:
            return "Chưa có từ vựng nào trong danh sách."
        case .all:
            return "Sổ tay của bạn đang trống."
        }
    }
    
    private var emptySelectionView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.3))
            Text("Chọn một mục ở danh sách bên trái để xem chi tiết")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Flashcard Study View
    private var flashcardStudyView: some View {
        VStack(spacing: 0) {
            // Flashcard Top Navigation
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isFlashcardMode = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Quay lại Sổ tay")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("Thẻ \(flashcardIndex + 1) / \(filteredWords.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 12)
            
            Spacer()
            
            // 3D Flip Card
            if flashcardIndex < filteredWords.count {
                let currentItem = filteredWords[flashcardIndex]
                
                ZStack {
                    if isCardFlipped {
                        // BACK OF CARD (Meaning & Formula)
                        VStack(spacing: 14) {
                            Text(currentItem.isGrammarFormula ? "📐 CÔNG THỨC & Ý NGHĨA" : "✨ Ý NGHĨA")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(currentItem.isGrammarFormula ? .blue : .orange)
                            
                            if currentItem.isGrammarFormula, let formula = currentItem.phonetic {
                                Text(formula)
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.blue)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                            
                            Text(currentItem.translation)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Text("Bấm để lật lại mặt trước")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .frame(width: 440, height: 260)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(currentItem.isGrammarFormula ? Color.blue.opacity(0.25) : Color.orange.opacity(0.25), lineWidth: 1.5)
                        )
                        .rotation3DEffect(.degrees(isCardFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                    } else {
                        // FRONT OF CARD (Word / Structure Title)
                        VStack(spacing: 14) {
                            Text(currentItem.isGrammarFormula ? "📐 CẤU TRÚC NGỮ PHÁP" : "📚 TỪ VỰNG")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Text(currentItem.cleanTitle)
                                .font(.system(size: 26, weight: .heavy, design: currentItem.isGrammarFormula ? .default : .serif))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            if let exEn = currentItem.exampleEn, !exEn.isEmpty {
                                Text("\"\(exEn)\"")
                                    .font(.system(size: 12, design: .serif))
                                    .foregroundColor(.secondary)
                                    .italic()
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .padding(.horizontal, 24)
                            }
                            
                            Text("Bấm để xem đáp án / công thức")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary.opacity(0.6))
                        }
                        .frame(width: 440, height: 260)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1.5)
                        )
                        .rotation3DEffect(.degrees(isCardFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        isCardFlipped.toggle()
                    }
                }
            }
            
            Spacer()
            
            // Bottom Controls (Prev / Next / Speak)
            HStack(spacing: 20) {
                Button(action: {
                    if flashcardIndex > 0 {
                        flashcardIndex -= 1
                        isCardFlipped = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("Thẻ trước")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(flashcardIndex == 0)
                
                Button(action: {
                    if flashcardIndex < filteredWords.count {
                        let currentItem = filteredWords[flashcardIndex]
                        speechService.speak(text: currentItem.cleanTitle, languageCode: "en-US", speakerID: "flashcard")
                    }
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    if flashcardIndex < filteredWords.count - 1 {
                        flashcardIndex += 1
                        isCardFlipped = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Thẻ kế")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(flashcardIndex >= filteredWords.count - 1)
            }
            .padding(.bottom, 24)
        }
    }
}
