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

public enum NotebookLayoutMode: String, CaseIterable, Identifiable {
    case split = "3 Cột (Chi tiết)"
    case table = "Bảng dữ liệu"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .split: return "rectangle.split.3x1"
        case .table: return "tablecells"
        }
    }
}

public enum NotebookSortOption: String, CaseIterable, Identifiable {
    case aiPriority = "Mức độ quan trọng (AI)"
    case thematicGenre = "Theo thể loại / chủ đề (AI)"
    case aiPartOfSpeech = "Theo từ loại (AI)"
    case newestFirst = "Mới lưu nhất"
    case oldestFirst = "Cũ nhất"
    case alphabeticalAZ = "Bảng chữ cái (A → Z)"
    case alphabeticalZA = "Bảng chữ cái (Z → A)"
    case favoritesFirst = "Yêu thích lên đầu"
    case learningFirst = "Chưa thuộc lên đầu"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .aiPriority: return "list.bullet.indent"
        case .thematicGenre: return "folder.badge.gearshape"
        case .aiPartOfSpeech: return "tag"
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
    @State private var selectedTableItemIDs: Set<UUID> = []
    @State private var layoutMode: NotebookLayoutMode = .split
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
                nativeRootLayout
            }
        }
        .frame(minWidth: 960, minHeight: 620)
    }
    
    // MARK: - Native Root Layout (Split vs Table)
    private var nativeRootLayout: some View {
        Group {
            if layoutMode == .split {
                NavigationSplitView {
                    sidebarView
                        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
                } content: {
                    contentListView
                        .navigationSplitViewColumnWidth(min: 250, ideal: 290, max: 380)
                } detail: {
                    detailView
                }
            } else {
                NavigationSplitView {
                    sidebarView
                        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
                } detail: {
                    tableViewMode
                }
            }
        }
        .navigationTitle(selectedSidebarItem?.title ?? "Sổ Tay")
        .searchable(text: $searchText, placement: .sidebar, prompt: "Tìm kiếm ghi chú...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Layout Switcher (3-Pane vs Table)
                Picker("Chế độ xem", selection: $layoutMode) {
                    Label("3 Cột", systemImage: "rectangle.split.3x1").tag(NotebookLayoutMode.split)
                    Label("Bảng", systemImage: "tablecells").tag(NotebookLayoutMode.table)
                }
                .pickerStyle(.segmented)
                .help("Chuyển đổi giao diện: 3 Cột chi tiết hoặc Bảng dữ liệu rộng")
                
                // Sorting Menu
                Menu {
                    Section("PHÂN LOẠI THEO AI") {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                sortOption = .aiPriority
                            }
                        }) {
                            if sortOption == .aiPriority {
                                Label("Mức độ quan trọng (AI)", systemImage: "checkmark")
                            } else {
                                Label("Mức độ quan trọng (AI)", systemImage: "list.bullet.indent")
                            }
                        }
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                sortOption = .thematicGenre
                            }
                        }) {
                            if sortOption == .thematicGenre {
                                Label("Theo thể loại / chủ đề (AI)", systemImage: "checkmark")
                            } else {
                                Label("Theo thể loại / chủ đề (AI)", systemImage: "folder.badge.gearshape")
                            }
                        }
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                sortOption = .aiPartOfSpeech
                            }
                        }) {
                            if sortOption == .aiPartOfSpeech {
                                Label("Theo từ loại (AI)", systemImage: "checkmark")
                            } else {
                                Label("Theo từ loại (AI)", systemImage: "tag")
                            }
                        }
                    }
                    
                    Section("SẮP XẾP") {
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
                
                // Text Analysis Button
                Button(action: {
                    TextAnalysisWindowController.shared.showAnalysis()
                }) {
                    Label("Bóc Tách", systemImage: "doc.text.magnifyingglass")
                }
                .help("Bóc tách từ vựng & ngữ pháp từ đoạn văn")
                
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
    
    // MARK: - 1. Middle Content List (For 3-Pane Split Mode)
    private var contentListView: some View {
        VStack(spacing: 0) {
            // Quick Filter & Sort Header Bar
            HStack(spacing: 6) {
                Text("\(filteredItems.count) mục")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                sortDropdownMenu
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.015))
            
            Divider().opacity(0.15)
            
            // List View
            if filteredItems.isEmpty {
                emptyStatePlaceholder
            } else {
                List(selection: $selectedItemID) {
                    renderGroupedListRows
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
    
    // MARK: - 2. Full Table View Mode (Shows massive list of vocabulary at once)
    private var tableViewMode: some View {
        VStack(spacing: 0) {
            // Table Header Status Bar
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "tablecells")
                        .foregroundColor(.blue)
                    Text("\(filteredItems.count) từ vựng / công thức")
                        .font(.system(size: 12, weight: .bold))
                }
                
                Spacer()
                
                sortDropdownMenu
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))
            
            Divider()
            
            if filteredItems.isEmpty {
                emptyStatePlaceholder
            } else {
                Table(filteredItems, selection: $selectedItemID) {
                    // 1. Star / Favorite Column
                    TableColumn("⭐") { item in
                        Button(action: {
                            vocabService.toggleFavorite(id: item.id)
                        }) {
                            Image(systemName: item.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 11))
                                .foregroundColor(item.isFavorite ? .yellow : .secondary.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .help("Yêu thích")
                    }
                    .width(min: 28, ideal: 32, max: 36)
                    
                    // 2. Word / Title Column
                    TableColumn("Từ vựng / Cấu trúc") { item in
                        HStack(spacing: 6) {
                            if item.isGrammarFormula {
                                Text("📐")
                                    .font(.system(size: 9))
                            }
                            
                            Text(item.cleanTitle)
                                .font(.system(size: 12.5, weight: .bold, design: item.isGrammarFormula ? .monospaced : .default))
                                .foregroundColor(item.isGrammarFormula ? .blue : .primary)
                            
                            if let ph = item.phonetic, !ph.isEmpty, !item.isGrammarFormula {
                                Text(ph)
                                    .font(.system(size: 10.5, design: .serif))
                                    .foregroundColor(.orange)
                            }
                            
                            Button(action: {
                                speechService.speak(text: item.word, languageCode: "en-US", speakerID: "table_\(item.id.uuidString)")
                            }) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Phát âm")
                        }
                    }
                    .width(min: 160, ideal: 200, max: 280)
                    
                    // 3. Meaning / Translation Column
                    TableColumn("Nghĩa tiếng Việt") { item in
                        Text(item.translation)
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.9))
                            .lineLimit(1)
                    }
                    .width(min: 180, ideal: 240)
                    
                    // 4. Thematic Genre / Topic
                    TableColumn("Chủ đề (AI)") { item in
                        Text(item.aiThematicGenre.rawValue)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(4)
                    }
                    .width(min: 130, ideal: 150, max: 180)
                    
                    // 5. Part of Speech Column
                    TableColumn("Từ loại") { item in
                        Text(item.aiPartOfSpeech.rawValue)
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                    .width(min: 110, ideal: 130, max: 160)
                    
                    // 6. Example Sentence Column
                    TableColumn("Ví dụ") { item in
                        if let ex = item.exampleEn, !ex.isEmpty {
                            Text("\"\(ex)\"")
                                .font(.system(size: 11, design: .serif))
                                .foregroundColor(.secondary)
                                .italic()
                                .lineLimit(1)
                        } else {
                            Text("—")
                                .foregroundColor(.secondary.opacity(0.4))
                        }
                    }
                    .width(min: 180, ideal: 260)
                    
                    // 7. Status (Mastered) Column
                    TableColumn("Trạng thái") { item in
                        Button(action: {
                            vocabService.toggleMastered(id: item.id)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: item.isMastered ? "checkmark.seal.fill" : "circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(item.isMastered ? .green : .secondary.opacity(0.4))
                                Text(item.isMastered ? "Đã thuộc" : "Đang học")
                                    .font(.system(size: 10.5, weight: item.isMastered ? .semibold : .regular))
                                    .foregroundColor(item.isMastered ? .green : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .width(min: 85, ideal: 95, max: 110)
                    
                    // 8. Action Delete Column
                    TableColumn("Xóa") { item in
                        Button(role: .destructive, action: {
                            vocabService.removeWord(id: item.id)
                        }) {
                            Image(systemName: "trash")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .help("Xóa khỏi sổ tay")
                    }
                    .width(min: 36, ideal: 40, max: 46)
                }
            }
        }
    }
    
    // MARK: - Sort Dropdown Menu
    private var sortDropdownMenu: some View {
        Menu {
            Section("PHÂN LOẠI THEO AI") {
                Button(action: { withAnimation { sortOption = .aiPriority } }) {
                    if sortOption == .aiPriority {
                        Label("Mức độ quan trọng (AI)", systemImage: "checkmark")
                    } else {
                        Label("Mức độ quan trọng (AI)", systemImage: "list.bullet.indent")
                    }
                }
                
                Button(action: { withAnimation { sortOption = .thematicGenre } }) {
                    if sortOption == .thematicGenre {
                        Label("Theo thể loại / chủ đề (AI)", systemImage: "checkmark")
                    } else {
                        Label("Theo thể loại / chủ đề (AI)", systemImage: "folder.badge.gearshape")
                    }
                }
                
                Button(action: { withAnimation { sortOption = .aiPartOfSpeech } }) {
                    if sortOption == .aiPartOfSpeech {
                        Label("Theo từ loại (AI)", systemImage: "checkmark")
                    } else {
                        Label("Theo từ loại (AI)", systemImage: "tag")
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
                    Button(action: { withAnimation { sortOption = opt } }) {
                        if sortOption == opt {
                            Label(opt.rawValue, systemImage: "checkmark")
                        } else {
                            Label(opt.rawValue, systemImage: opt.icon)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: sortOption.icon)
                    .font(.system(size: 10))
                Text(sortOption.rawValue)
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Render Grouped Rows
    @ViewBuilder
    private var renderGroupedListRows: some View {
        switch sortOption {
        case .aiPriority:
            ForEach(ItemAIPriority.allCases) { priority in
                let group = filteredItems
                    .filter { $0.aiPriority == priority }
                    .sorted { $0.cleanTitle.localizedCaseInsensitiveCompare($1.cleanTitle) == .orderedAscending }
                if !group.isEmpty {
                    Section {
                        ForEach(group) { item in
                            itemRowLink(item: item)
                        }
                    } header: {
                        HStack {
                            Text(priority.rawValue.uppercased())
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(group.count)")
                                .font(.system(size: 9.5, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
        case .thematicGenre:
            ForEach(ItemThematicGenre.allCases) { genre in
                let group = filteredItems
                    .filter { $0.aiThematicGenre == genre }
                    .sorted { $0.cleanTitle.localizedCaseInsensitiveCompare($1.cleanTitle) == .orderedAscending }
                if !group.isEmpty {
                    Section {
                        ForEach(group) { item in
                            itemRowLink(item: item)
                        }
                    } header: {
                        HStack {
                            Text(genre.rawValue.uppercased())
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(group.count)")
                                .font(.system(size: 9.5, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
        case .aiPartOfSpeech:
            ForEach(ItemAIPartOfSpeech.allCases) { pos in
                let group = filteredItems
                    .filter { $0.aiPartOfSpeech == pos }
                    .sorted { $0.cleanTitle.localizedCaseInsensitiveCompare($1.cleanTitle) == .orderedAscending }
                if !group.isEmpty {
                    Section {
                        ForEach(group) { item in
                            itemRowLink(item: item)
                        }
                    } header: {
                        HStack {
                            Text(pos.rawValue.uppercased())
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(group.count)")
                                .font(.system(size: 9.5, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
        default:
            ForEach(filteredItems) { item in
                itemRowLink(item: item)
            }
        }
    }
    
    private var emptyStatePlaceholder: some View {
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
        case .aiPriority, .thematicGenre, .aiPartOfSpeech:
            // Section-based grouping handles sorting within sections
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
