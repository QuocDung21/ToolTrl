import SwiftUI
import AppKit

public enum NotebookSidebarItem: Hashable, Identifiable {
    case vocabulary
    case grammar
    case favorites
    case mastered
    case all
    
    public var id: String {
        switch self {
        case .vocabulary: return "vocabulary"
        case .grammar: return "grammar"
        case .favorites: return "favorites"
        case .mastered: return "mastered"
        case .all: return "all"
        }
    }
    
    public var title: String {
        switch self {
        case .vocabulary: return "Từ vựng"
        case .grammar: return "Công thức ngữ pháp"
        case .favorites: return "Yêu thích"
        case .mastered: return "Đã thuộc"
        case .all: return "Tất cả ghi chú"
        }
    }
    
    public var icon: String {
        switch self {
        case .vocabulary: return "character.book.closed.fill"
        case .grammar: return "function"
        case .favorites: return "star.fill"
        case .mastered: return "checkmark.seal.fill"
        case .all: return "books.vertical.fill"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .vocabulary: return .orange
        case .grammar: return .blue
        case .favorites: return .yellow
        case .mastered: return .green
        case .all: return .purple
        }
    }
}

public enum NotebookSortOption: String, CaseIterable, Identifiable {
    case aiPriority = "🌟 Phân loại AI (Mức độ quan trọng)"
    case aiPartOfSpeech = "🏷️ Phân loại AI (Theo Từ Loại)"
    case newestFirst = "Mới lưu nhất"
    case oldestFirst = "Cũ nhất"
    case alphabeticalAZ = "Bảng chữ cái (A → Z)"
    case alphabeticalZA = "Bảng chữ cái (Z → A)"
    case favoritesFirst = "Yêu thích lên đầu"
    case learningFirst = "Chưa thuộc lên đầu"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .aiPriority: return "sparkles"
        case .aiPartOfSpeech: return "tag.fill"
        case .newestFirst: return "clock.arrow.circlepath"
        case .oldestFirst: return "clock"
        case .alphabeticalAZ: return "textformat.abc"
        case .alphabeticalZA: return "textformat.abc.dottedunderline"
        case .favoritesFirst: return "star.fill"
        case .learningFirst: return "circle.dashed"
        }
    }
}

public struct VocabularyNotebookView: View {
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var speechService = SpeechService.shared
    
    @State private var selectedSidebarItem: NotebookSidebarItem? = .vocabulary
    @State private var selectedItemID: UUID? = nil
    @State private var searchText: String = ""
    @State private var sortOption: NotebookSortOption = .aiPriority
    @State private var isFlashcardMode: Bool = false
    @State private var flashcardIndex: Int = 0
    @State private var isCardFlipped: Bool = false
    @State private var formulaCopied: Bool = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if isFlashcardMode {
                flashcardStudyView
            } else {
                nativeSplitLayout
            }
        }
        .frame(minWidth: 920, minHeight: 600)
    }
    
    // MARK: - Pure Native macOS 3-Pane Layout (Sidebar - List - Detail)
    private var nativeSplitLayout: some View {
        NavigationSplitView {
            sidebarView
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } content: {
            contentListView
                .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        } detail: {
            detailView
        }
        .navigationTitle(selectedSidebarItem?.title ?? "Sổ Tay")
        .searchable(text: $searchText, placement: .sidebar, prompt: "Tìm kiếm ghi chú...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Sorting & AI Grouping Menu
                Menu {
                    Section("PHÂN LOẠI & SẮP XẾP BẰNG AI") {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                sortOption = .aiPriority
                            }
                        }) {
                            if sortOption == .aiPriority {
                                Label("🌟 Phân loại AI (Mức độ quan trọng)", systemImage: "checkmark")
                            } else {
                                Label("🌟 Phân loại AI (Mức độ quan trọng)", systemImage: "sparkles")
                            }
                        }
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                sortOption = .aiPartOfSpeech
                            }
                        }) {
                            if sortOption == .aiPartOfSpeech {
                                Label("🏷️ Phân loại AI (Theo Từ Loại)", systemImage: "checkmark")
                            } else {
                                Label("🏷️ Phân loại AI (Theo Từ Loại)", systemImage: "tag.fill")
                            }
                        }
                    }
                    
                    Section("SẮP XẾP TIÊU CHUẨN") {
                        ForEach([
                            NotebookSortOption.newestFirst,
                            NotebookSortOption.oldestFirst,
                            NotebookSortOption.alphabeticalAZ,
                            NotebookSortOption.alphabeticalZA,
                            NotebookSortOption.favoritesFirst,
                            NotebookSortOption.learningFirst
                        ]) { opt in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    sortOption = opt
                                }
                            }) {
                                if sortOption == opt {
                                    Label(opt.rawValue, systemImage: "checkmark")
                                } else {
                                    Label(opt.rawValue, systemImage: opt.icon)
                                }
                            }
                        }
                    }
                } label: {
                    Label("Sắp xếp", systemImage: "arrow.up.arrow.down")
                }
                .help("Phân loại và sắp xếp ghi chú (\(sortOption.rawValue))")
                
                // AI Extraction Button
                Button(action: {
                    TextAnalysisWindowController.shared.showAnalysis()
                }) {
                    Label("AI Bóc Tách", systemImage: "brain.head.profile")
                }
                .help("AI tự động bóc tách từ vựng & ngữ pháp từ đoạn văn")
                
                // Flashcards Button
                Button(action: {
                    if !filteredItems.isEmpty {
                        flashcardIndex = 0
                        isCardFlipped = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isFlashcardMode = true
                        }
                    }
                }) {
                    Label("Flashcard", systemImage: "rectangle.portrait.on.rectangle.portrait.angled")
                }
                .disabled(filteredItems.isEmpty)
                .help("Ôn luyện thẻ ghi nhớ")
            }
        }
    }
    
    // MARK: - Native Sidebar
    private var sidebarView: some View {
        List(selection: $selectedSidebarItem) {
            Section("BỘ SƯU TẬP") {
                sidebarRow(item: .vocabulary, count: vocabCount)
                sidebarRow(item: .grammar, count: grammarCount)
                sidebarRow(item: .all, count: allCount)
            }
            
            Section("TRẠNG THÁI") {
                sidebarRow(item: .favorites, count: favCount)
                sidebarRow(item: .mastered, count: masteredCount)
            }
        }
        .listStyle(.sidebar)
    }
    
    private func sidebarRow(item: NotebookSidebarItem, count: Int) -> some View {
        NavigationLink(value: item) {
            HStack {
                Label {
                    Text(item.title)
                        .font(.system(size: 13))
                } icon: {
                    Image(systemName: item.icon)
                        .foregroundColor(item.accentColor)
                }
                
                Spacer()
                
                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Middle Content List (Supports AI Grouped Sections)
    private var contentListView: some View {
        Group {
            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: selectedSidebarItem?.icon ?? "books.vertical")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text(emptyListMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Spacer()
                }
            } else {
                List(selection: $selectedItemID) {
                    switch sortOption {
                    case .aiPriority:
                        // Group by AI Priority
                        ForEach(ItemAIPriority.allCases) { priority in
                            let group = filteredItems.filter { $0.aiPriority == priority }
                            if !group.isEmpty {
                                Section(header: Text("\(priority.rawValue) (\(group.count))")) {
                                    ForEach(group) { item in
                                        itemRowLink(item: item)
                                    }
                                }
                            }
                        }
                        
                    case .aiPartOfSpeech:
                        // Group by AI Part of Speech
                        ForEach(ItemAIPartOfSpeech.allCases) { pos in
                            let group = filteredItems.filter { $0.aiPartOfSpeech == pos }
                            if !group.isEmpty {
                                Section(header: Text("\(pos.rawValue) (\(group.count))")) {
                                    ForEach(group) { item in
                                        itemRowLink(item: item)
                                    }
                                }
                            }
                        }
                        
                    default:
                        // Standard Flat List
                        ForEach(filteredItems) { item in
                            itemRowLink(item: item)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .onAppear {
            if selectedItemID == nil, let first = filteredItems.first {
                selectedItemID = first.id
            }
        }
    }
    
    private func itemRowLink(item: SavedWordItem) -> some View {
        NavigationLink(value: item.id) {
            itemListRow(item: item)
        }
        .contextMenu {
            Button(action: {
                vocabService.toggleFavorite(id: item.id)
            }) {
                Label(item.isFavorite ? "Bỏ yêu thích" : "Yêu thích", systemImage: "star")
            }
            
            Button(action: {
                vocabService.toggleMastered(id: item.id)
            }) {
                Label(item.isMastered ? "Đánh dấu chưa thuộc" : "Đánh dấu đã thuộc", systemImage: "checkmark.circle")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                vocabService.removeWord(id: item.id)
                if selectedItemID == item.id {
                    selectedItemID = filteredItems.first?.id
                }
            }) {
                Label("Xóa", systemImage: "trash")
            }
        }
    }
    
    private func itemListRow(item: SavedWordItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if item.isGrammarFormula {
                    Text("📐")
                        .font(.system(size: 10))
                }
                
                Text(item.cleanTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.yellow)
                }
                
                if item.isMastered {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9.5))
                        .foregroundColor(.green)
                }
            }
            
            Text(item.isGrammarFormula ? (item.phonetic ?? item.translation) : item.translation)
                .font(.system(size: 11.5, design: item.isGrammarFormula ? .monospaced : .default))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Right Detail Document View
    private var detailView: some View {
        Group {
            if let id = selectedItemID,
               let item = vocabService.savedWords.first(where: { $0.id == id }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Area
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                if item.isGrammarFormula {
                                    Text("CÔNG THỨC NGỮ PHÁP")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                } else if let ph = item.phonetic, !ph.isEmpty {
                                    Text(ph)
                                        .font(.system(size: 14, weight: .medium, design: .serif))
                                        .foregroundColor(.orange)
                                }
                                
                                Text(item.cleanTitle)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            // Native Action Group
                            HStack(spacing: 8) {
                                if !item.isGrammarFormula {
                                    Button(action: {
                                        speechService.speak(text: item.word, languageCode: "en-US", speakerID: "detail_\(item.id.uuidString)")
                                    }) {
                                        Label("Phát âm", systemImage: (speechService.isSpeaking && speechService.currentSpeakerID == "detail_\(item.id.uuidString)") ? "speaker.wave.3.fill" : "speaker.wave.2")
                                    }
                                }
                                
                                Button(action: {
                                    vocabService.toggleFavorite(id: item.id)
                                }) {
                                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                                        .foregroundColor(item.isFavorite ? .yellow : .secondary)
                                }
                                .help(item.isFavorite ? "Bỏ yêu thích" : "Yêu thích")
                                
                                Button(action: {
                                    vocabService.toggleMastered(id: item.id)
                                }) {
                                    Image(systemName: item.isMastered ? "checkmark.seal.fill" : "checkmark.seal")
                                        .foregroundColor(item.isMastered ? .green : .secondary)
                                }
                                .help(item.isMastered ? "Đánh dấu chưa thuộc" : "Đánh dấu đã thuộc")
                                
                                Button(role: .destructive, action: {
                                    vocabService.removeWord(id: item.id)
                                    selectedItemID = filteredItems.first?.id
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.secondary)
                                }
                                .help("Xóa ghi chú này")
                            }
                        }
                        
                        Divider()
                        
                        // Formula Box (If Grammar)
                        if item.isGrammarFormula, let formula = item.phonetic, !formula.isEmpty {
                            GroupBox {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Label("Công thức", systemImage: "function")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.blue)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            let pb = NSPasteboard.general
                                            pb.clearContents()
                                            pb.setString(formula, forType: .string)
                                            withAnimation { formulaCopied = true }
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { formulaCopied = false }
                                        }) {
                                            Label(formulaCopied ? "Đã chép" : "Sao chép", systemImage: formulaCopied ? "checkmark" : "doc.on.doc")
                                                .font(.system(size: 10.5))
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    
                                    Text(formula)
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(.blue)
                                        .padding(.vertical, 2)
                                }
                                .padding(4)
                            }
                        }
                        
                        // Meaning & Explanation Box
                        GroupBox {
                            VStack(alignment: .leading, spacing: 6) {
                                Label(item.isGrammarFormula ? "Ý nghĩa & Cách dùng" : "Ý nghĩa tiếng Việt", systemImage: "text.alignleft")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                Text(item.translation)
                                    .font(.system(size: 14.5))
                                    .foregroundColor(.primary)
                                    .lineSpacing(3)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(4)
                        }
                        
                        // Example Sentence Box
                        if let exEn = item.exampleEn, !exEn.isEmpty {
                            GroupBox {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Label("Ví dụ trong đoạn văn", systemImage: "quote.opening")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.secondary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            speechService.speak(text: exEn, languageCode: "en-US", speakerID: "ex_\(item.id.uuidString)")
                                        }) {
                                            Image(systemName: "speaker.wave.2")
                                                .font(.system(size: 11))
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    
                                    Text("\"\(exEn)\"")
                                        .font(.system(size: 13.5, design: .serif))
                                        .foregroundColor(.primary)
                                        .italic()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(4)
                            }
                        }
                    }
                    .padding(24)
                }
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("Chọn một mục ở danh sách bên trái để xem chi tiết")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Flashcard Study Mode
    private var flashcardStudyView: some View {
        VStack(spacing: 0) {
            // Flashcard Header
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isFlashcardMode = false
                    }
                }) {
                    Label("Quay lại", systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                Text("\(flashcardIndex + 1) / \(filteredItems.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            
            Spacer()
            
            // 3D Flip Card
            if flashcardIndex < filteredItems.count {
                let currentItem = filteredItems[flashcardIndex]
                
                ZStack {
                    if isCardFlipped {
                        // Back of Card
                        GroupBox {
                            VStack(spacing: 12) {
                                Label(currentItem.isGrammarFormula ? "Công thức & Ý nghĩa" : "Ý nghĩa", systemImage: currentItem.isGrammarFormula ? "function" : "sparkles")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(currentItem.isGrammarFormula ? .blue : .orange)
                                
                                if currentItem.isGrammarFormula, let formula = currentItem.phonetic {
                                    Text(formula)
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                        .foregroundColor(.blue)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 12)
                                }
                                
                                Text(currentItem.translation)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                                
                                Text("Bấm để lật lại")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 440, height: 260)
                        }
                        .rotation3DEffect(.degrees(isCardFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                    } else {
                        // Front of Card
                        GroupBox {
                            VStack(spacing: 12) {
                                Label(currentItem.isGrammarFormula ? "Cấu trúc ngữ pháp" : "Từ vựng", systemImage: currentItem.isGrammarFormula ? "function" : "text.book.closed")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                Text(currentItem.cleanTitle)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                                
                                if let exEn = currentItem.exampleEn, !exEn.isEmpty {
                                    Text("\"\(exEn)\"")
                                        .font(.system(size: 12.5, design: .serif))
                                        .foregroundColor(.secondary)
                                        .italic()
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .padding(.horizontal, 16)
                                }
                                
                                Text("Bấm để xem đáp án")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .frame(width: 440, height: 260)
                        }
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
            
            // Controls
            HStack(spacing: 20) {
                Button(action: {
                    if flashcardIndex > 0 {
                        flashcardIndex -= 1
                        isCardFlipped = false
                    }
                }) {
                    Label("Trước", systemImage: "arrow.left")
                }
                .disabled(flashcardIndex == 0)
                
                Button(action: {
                    if flashcardIndex < filteredItems.count {
                        let item = filteredItems[flashcardIndex]
                        speechService.speak(text: item.cleanTitle, languageCode: "en-US", speakerID: "flashcard")
                    }
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 13))
                }
                
                Button(action: {
                    if flashcardIndex < filteredItems.count - 1 {
                        flashcardIndex += 1
                        isCardFlipped = false
                    }
                }) {
                    HStack {
                        Text("Kế tiếp")
                        Image(systemName: "arrow.right")
                    }
                }
                .disabled(flashcardIndex >= filteredItems.count - 1)
            }
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Helpers & Counts
    private var vocabCount: Int {
        vocabService.savedWords.filter { !$0.isGrammarFormula }.count
    }
    
    private var grammarCount: Int {
        vocabService.savedWords.filter { $0.isGrammarFormula }.count
    }
    
    private var favCount: Int {
        vocabService.savedWords.filter { $0.isFavorite }.count
    }
    
    private var masteredCount: Int {
        vocabService.savedWords.filter { $0.isMastered }.count
    }
    
    private var allCount: Int {
        vocabService.savedWords.count
    }
    
    private var filteredItems: [SavedWordItem] {
        var list = vocabService.savedWords
        
        switch selectedSidebarItem {
        case .vocabulary:
            list = list.filter { !$0.isGrammarFormula }
        case .grammar:
            list = list.filter { $0.isGrammarFormula }
        case .favorites:
            list = list.filter { $0.isFavorite }
        case .mastered:
            list = list.filter { $0.isMastered }
        case .all, .none:
            break
        }
        
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.word.lowercased().contains(q) ||
                $0.translation.lowercased().contains(q) ||
                ($0.phonetic?.lowercased().contains(q) ?? false)
            }
        }
        
        // Apply Sorting
        switch sortOption {
        case .aiPriority:
            // Grouping is handled in List Sections
            break
        case .aiPartOfSpeech:
            // Grouping is handled in List Sections
            break
        case .newestFirst:
            list.sort { $0.dateAdded > $1.dateAdded }
        case .oldestFirst:
            list.sort { $0.dateAdded < $1.dateAdded }
        case .alphabeticalAZ:
            list.sort { $0.cleanTitle.localizedCaseInsensitiveCompare($1.cleanTitle) == .orderedAscending }
        case .alphabeticalZA:
            list.sort { $0.cleanTitle.localizedCaseInsensitiveCompare($1.cleanTitle) == .orderedDescending }
        case .favoritesFirst:
            list.sort { ($0.isFavorite ? 0 : 1) < ($1.isFavorite ? 0 : 1) }
        case .learningFirst:
            list.sort { ($0.isMastered ? 1 : 0) < ($1.isMastered ? 1 : 0) }
        }
        
        return list
    }
    
    private var emptyListMessage: String {
        if !searchText.isEmpty { return "Không tìm thấy kết quả phù hợp" }
        switch selectedSidebarItem {
        case .vocabulary: return "Chưa có từ vựng nào được lưu"
        case .grammar: return "Chưa có công thức ngữ pháp nào được lưu"
        case .favorites: return "Chưa có mục nào được đánh dấu yêu thích"
        case .mastered: return "Chưa có mục nào được đánh dấu đã thuộc"
        case .all, .none: return "Sổ tay của bạn đang trống"
        }
    }
}
