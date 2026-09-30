import SwiftUI

public enum NotebookSortOption: String, CaseIterable, Identifiable {
    case aiPriority = "Mức độ quan trọng (AI)"
    case thematicGenre = "Thể loại / Chủ đề (AI)"
    case aiPartOfSpeech = "Từ loại (AI)"
    case newestFirst = "Mới nhất trước"
    case oldestFirst = "Cũ nhất trước"
    case alphabeticalAZ = "A ➔ Z"
    case alphabeticalZA = "Z ➔ A"
    case favoritesFirst = "Yêu thích lên đầu"
    case learningFirst = "Đang học lên đầu"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .aiPriority: return "list.bullet.indent"
        case .thematicGenre: return "folder.badge.gearshape"
        case .aiPartOfSpeech: return "tag"
        case .newestFirst: return "arrow.down"
        case .oldestFirst: return "arrow.up"
        case .alphabeticalAZ, .alphabeticalZA: return "textformat.abc"
        case .favoritesFirst: return "star.fill"
        case .learningFirst: return "book"
        }
    }
}

public enum NotebookLayoutMode: String, CaseIterable, Identifiable {
    case split = "3 Cột"
    case table = "Bảng"
    
    public var id: String { rawValue }
}

public enum NotebookSidebarItem: String, CaseIterable, Identifiable {
    case stats = "Tiến Trình & Thống Kê"
    case vocabulary = "Từ Vựng Đã Lưu"
    case grammar = "Công Thức Ngữ Pháp"
    case all = "Tất Cả"
    case favorites = "Yêu Thích ⭐"
    case mastered = "Đã Thuộc ✅"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .stats: return "Thống Kê & Chuỗi"
        case .vocabulary: return "Từ Vựng"
        case .grammar: return "Cấu Trúc Ngữ Pháp"
        case .all: return "Tất Cả Ghi Chú"
        case .favorites: return "Mục Yêu Thích"
        case .mastered: return "Đã Thuộc"
        }
    }
    
    public var icon: String {
        switch self {
        case .stats: return "flame.fill"
        case .vocabulary: return "book.closed.fill"
        case .grammar: return "function"
        case .all: return "tray.full.fill"
        case .favorites: return "star.fill"
        case .mastered: return "checkmark.seal.fill"
        }
    }
    
    public var accentColor: Color {
        switch self {
        case .stats: return .orange
        case .vocabulary: return .blue
        case .grammar: return .purple
        case .all: return .gray
        case .favorites: return .yellow
        case .mastered: return .green
        }
    }
}

public enum WordDetailTab: String, CaseIterable, Identifiable {
    case original = "Từ điển & Ghi chú"
    case ai = "Phân tích AI"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .original: return "book.closed"
        case .ai: return "text.magnifyingglass"
        }
    }
}

public struct VocabularyNotebookView: View {
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var speechService = SpeechService.shared
    @ObservedObject var githubSync = GitHubSyncService.shared
    
    @State private var selectedSidebarItem: NotebookSidebarItem? = .vocabulary
    @State private var selectedItemID: UUID? = nil
    @State private var layoutMode: NotebookLayoutMode = .split
    @State private var searchText: String = ""
    @State private var sortOption: NotebookSortOption = .aiPriority
    @State private var isFlashcardMode: Bool = false
    @State private var isQuickLookPresented: Bool = false
    @State private var showAddWordSheet: Bool = false
    @State private var showAddGrammarSheet: Bool = false
    @State private var editingItem: SavedWordItem? = nil
    @State private var keyMonitor: Any? = nil
    
    public init() {}
    
    public var body: some View {
        ZStack {
            if isFlashcardMode {
                FlashcardStudyView(items: filteredItems, isPresented: $isFlashcardMode)
            } else {
                nativeRootLayout
            }
            
            // Quick Look Overlay on Spacebar Press
            if isQuickLookPresented, let id = selectedItemID, let item = vocabService.savedWords.first(where: { $0.id == id }) {
                NotebookQuickLookModal(item: item, isPresented: $isQuickLookPresented)
            }
        }
        .frame(minWidth: 700, minHeight: 460)
        .sheet(isPresented: $showAddWordSheet) {
            AddWordSheet()
        }
        .sheet(isPresented: $showAddGrammarSheet) {
            AddGrammarSheet()
        }
        .sheet(item: $editingItem) { item in
            AddWordSheet(editingItem: item)
        }
        .onAppear {
            setupKeyMonitor()
            if selectedItemID == nil, let first = filteredItems.first {
                selectedItemID = first.id
            }
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }
    
    // MARK: - Local Key Monitor for Spacebar & Esc (Quick Look)
    private func setupKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 49 { // Spacebar
                if let window = NSApp.keyWindow,
                   let firstResponder = window.firstResponder as? NSTextView,
                   firstResponder.isFieldEditor {
                    return event
                }
                if selectedItemID != nil && selectedSidebarItem != .stats {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isQuickLookPresented.toggle()
                    }
                    return nil
                }
            } else if event.keyCode == 53 { // Esc key
                if isQuickLookPresented {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isQuickLookPresented = false
                    }
                    return nil
                }
            } else if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "n" {
                if let window = NSApp.keyWindow,
                   let firstResponder = window.firstResponder as? NSTextView,
                   firstResponder.isFieldEditor {
                    return event
                }
                if event.modifierFlags.contains(.shift) {
                    showAddGrammarSheet = true
                } else {
                    showAddWordSheet = true
                }
                return nil
            } else if event.keyCode == 51 || event.keyCode == 117 { // Delete / Forward Delete
                if let window = NSApp.keyWindow,
                   let firstResponder = window.firstResponder as? NSTextView,
                   firstResponder.isFieldEditor {
                    return event
                }
                if let id = selectedItemID {
                    selectedItemID = filteredItems.first(where: { $0.id != id })?.id
                    vocabService.removeWord(id: id)
                    return nil
                }
            }
            return event
        }
    }
    
    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    // MARK: - Native Root Layout (Split vs Table)
    private var nativeRootLayout: some View {
        Group {
            if layoutMode == .split {
                NavigationSplitView {
                    sidebarView
                        .navigationSplitViewColumnWidth(min: 170, ideal: 195, max: 240)
                } content: {
                    contentListView
                        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
                } detail: {
                    detailView
                }
            } else {
                NavigationSplitView {
                    sidebarView
                        .navigationSplitViewColumnWidth(min: 170, ideal: 195, max: 240)
                } detail: {
                    NotebookTableView(
                        items: filteredItems,
                        selectedItemID: $selectedItemID,
                        sortOption: $sortOption
                    )
                }
            }
        }
        .navigationTitle("")
        .searchable(text: $searchText, placement: .sidebar, prompt: "Tìm kiếm ghi chú...")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if selectedSidebarItem != .stats {
                    // Layout Switcher (3-Pane vs Table)
                    Picker("Chế độ xem", selection: $layoutMode) {
                        Label("3 Cột", systemImage: "rectangle.split.3x1").tag(NotebookLayoutMode.split)
                        Label("Bảng", systemImage: "tablecells").tag(NotebookLayoutMode.table)
                    }
                    .pickerStyle(.segmented)
                    .help("Chuyển đổi giao diện: 3 Cột chi tiết hoặc Bảng dữ liệu rộng")
                    
                    // Sorting Menu
                    sortMenu
                    
                    // Add Menu (Vocabulary & Grammar)
                    Menu {
                        Button(action: {
                            showAddWordSheet = true
                        }) {
                            Label("Thêm Từ Vựng Mới (⌘N)", systemImage: "book.closed")
                        }
                        
                        Button(action: {
                            showAddGrammarSheet = true
                        }) {
                            Label("Thêm Cấu Trúc Ngữ Pháp (⇧⌘N)", systemImage: "function")
                        }
                    } label: {
                        Label("Thêm", systemImage: "plus.circle.fill")
                    }
                    .help("Thêm từ vựng mới (⌘N) hoặc cấu trúc ngữ pháp (⇧⌘N)")
                    
                    // Learning Stats Button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSidebarItem = .stats
                        }
                    }) {
                        Label("Thống kê", systemImage: "chart.bar.xaxis")
                    }
                    .help("Xem biểu đồ thống kê tra từ và chuỗi ngày học tập (Streak)")
                }
                
                // GitHub Cloud Sync Quick Button (Available globally)
                Button(action: {
                    if githubSync.isConnected {
                        Task {
                            _ = await githubSync.backupToGitHub()
                        }
                    } else {
                        SettingsWindowController.shared.showSettings()
                    }
                }) {
                    if githubSync.isSyncing {
                        ProgressView()
                            .scaleEffect(0.65)
                            .frame(width: 16, height: 16)
                    } else {
                        Label(
                            githubSync.isConnected ? "Đồng bộ GitHub" : "Chưa kết nối GitHub",
                            systemImage: githubSync.isConnected ? "icloud.and.arrow.up" : "icloud.slash"
                        )
                        .foregroundColor(githubSync.isConnected ? .accentColor : .secondary)
                    }
                }
                .help(githubSync.isConnected ? "Đồng bộ đám mây GitHub (Đã kết nối @\(githubSync.currentUser?.login ?? ""))" : "Chưa kết nối GitHub - Bấm để mở Cài đặt đồng bộ")
                
                if selectedSidebarItem != .stats {
                    // Quick Look Spacebar Button
                    Button(action: {
                        if selectedItemID != nil {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                isQuickLookPresented.toggle()
                            }
                        }
                    }) {
                        Label("Xem nhanh", systemImage: "eye")
                    }
                    .disabled(selectedItemID == nil)
                    .help("Xem nhanh chi tiết từ đang chọn (Nhấn phím Space)")
                    
                    // iPad Pencil Studio Button (Experimental)
                    if FeatureFlagService.shared.isFeatureEnabled(.continuityStudio) {
                        Button(action: {
                            if let id = selectedItemID, let item = vocabService.savedWords.first(where: { $0.id == id }) {
                                ContinuityHomeworkController.shared.showStudio(taskText: "\(item.cleanTitle): \(item.translation)\n\(item.exampleEn ?? "")")
                            } else {
                                ContinuityHomeworkController.shared.showStudio()
                            }
                        }) {
                            Label("iPad Pencil", systemImage: "ipad.and.arrow.forward")
                        }
                        .help("Bắn bài tập sang iPad để giải bằng Apple Pencil & AI Chấm Điểm")
                    }
                }
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
            
            Section("TRẠNG THÁI ÔN TẬP") {
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
    
    // MARK: - Middle Content List (For 3-Pane Split Mode)
    private var contentListView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("\(filteredItems.count) mục")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                sortDropdownCompact
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.015))
            
            Divider().opacity(0.15)
            
            if selectedSidebarItem == .grammar {
                Button(action: {
                    showAddGrammarSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11.5))
                            .foregroundColor(.purple)
                        Text("Thêm Cấu Trúc Ngữ Pháp Mới")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.purple)
                        Spacer()
                        Text("⇧⌘N")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.purple.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            } else if selectedSidebarItem == .vocabulary || selectedSidebarItem == .all {
                Button(action: {
                    showAddWordSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11.5))
                            .foregroundColor(.blue)
                        Text("Thêm Từ Vựng Mới")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.blue)
                        Spacer()
                        Text("⌘N")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.blue.opacity(0.06))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            
            if filteredItems.isEmpty {
                emptyStatePlaceholder
            } else {
                List(selection: $selectedItemID) {
                    renderGroupedListRows
                }
                .listStyle(.inset)
            }
        }
    }
    
    private var detailView: some View {
        Group {
            if let id = selectedItemID,
               let item = vocabService.savedWords.first(where: { $0.id == id }) {
                ScrollView {
                    WordDetailDocumentView(item: item)
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
    
    private func itemRowLink(item: SavedWordItem) -> some View {
        NavigationLink(value: item.id) {
            itemListRow(item: item)
        }
        .contextMenu {
            Button(action: { editingItem = item }) {
                Label("Chỉnh sửa...", systemImage: "square.and.pencil")
            }
            Divider()
            Button(action: { vocabService.toggleFavorite(id: item.id) }) {
                Label(item.isFavorite ? "Bỏ yêu thích" : "Yêu thích", systemImage: "star")
            }
            Button(action: { vocabService.toggleMastered(id: item.id) }) {
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
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                if selectedItemID == item.id {
                    selectedItemID = filteredItems.first(where: { $0.id != item.id })?.id
                }
                vocabService.removeWord(id: item.id)
            } label: {
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
    
    private var emptyStatePlaceholder: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: selectedSidebarItem?.icon ?? "books.vertical")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.3))
            Text(emptyListMessage)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            if selectedSidebarItem == .grammar {
                Button(action: { showAddGrammarSheet = true }) {
                    Label("Thêm Cấu Trúc Ngữ Pháp", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.purple)
            } else if selectedSidebarItem == .vocabulary || selectedSidebarItem == .all {
                Button(action: { showAddWordSheet = true }) {
                    Label("Thêm Từ Vựng Mới", systemImage: "plus.circle.fill")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .tint(.blue)
            }
            Spacer()
        }
    }
    
    private var sortMenu: some View {
        Menu {
            Section("PHÂN LOẠI THEO AI") {
                Button(action: { withAnimation { sortOption = .aiPriority } }) {
                    Label("Mức độ quan trọng (AI)", systemImage: sortOption == .aiPriority ? "checkmark" : "list.bullet.indent")
                }
                Button(action: { withAnimation { sortOption = .thematicGenre } }) {
                    Label("Theo thể loại / chủ đề (AI)", systemImage: sortOption == .thematicGenre ? "checkmark" : "folder.badge.gearshape")
                }
                Button(action: { withAnimation { sortOption = .aiPartOfSpeech } }) {
                    Label("Theo từ loại (AI)", systemImage: sortOption == .aiPartOfSpeech ? "checkmark" : "tag")
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
                    Button(action: { withAnimation { sortOption = opt } }) {
                        Label(opt.rawValue, systemImage: sortOption == opt ? "checkmark" : opt.icon)
                    }
                }
            }
        } label: {
            Label("Sắp xếp", systemImage: "arrow.up.arrow.down")
        }
    }
    
    private var sortDropdownCompact: some View {
        Menu {
            Section("PHÂN LOẠI THEO AI") {
                Button(action: { withAnimation { sortOption = .aiPriority } }) {
                    Label("Mức độ quan trọng (AI)", systemImage: sortOption == .aiPriority ? "checkmark" : "list.bullet.indent")
                }
                Button(action: { withAnimation { sortOption = .thematicGenre } }) {
                    Label("Theo thể loại / chủ đề (AI)", systemImage: sortOption == .thematicGenre ? "checkmark" : "folder.badge.gearshape")
                }
                Button(action: { withAnimation { sortOption = .aiPartOfSpeech } }) {
                    Label("Theo từ loại (AI)", systemImage: sortOption == .aiPartOfSpeech ? "checkmark" : "tag")
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
                    Button(action: { withAnimation { sortOption = opt } }) {
                        Label(opt.rawValue, systemImage: sortOption == opt ? "checkmark" : opt.icon)
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
    
    // MARK: - Helpers & Counts
    private var vocabCount: Int { vocabService.savedWords.filter { !$0.isGrammarFormula }.count }
    private var grammarCount: Int { vocabService.savedWords.filter { $0.isGrammarFormula }.count }
    private var favCount: Int { vocabService.savedWords.filter { $0.isFavorite }.count }
    private var masteredCount: Int { vocabService.savedWords.filter { $0.isMastered }.count }
    private var allCount: Int { vocabService.savedWords.count }
    
    private var filteredItems: [SavedWordItem] {
        var list = vocabService.savedWords
        switch selectedSidebarItem {
        case .stats: break
        case .vocabulary: list = list.filter { !$0.isGrammarFormula }
        case .grammar: list = list.filter { $0.isGrammarFormula }
        case .favorites: list = list.filter { $0.isFavorite }
        case .mastered: list = list.filter { $0.isMastered }
        case .all, .none: break
        }
        
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.word.lowercased().contains(q) ||
                $0.translation.lowercased().contains(q) ||
                ($0.phonetic?.lowercased().contains(q) ?? false)
            }
        }
        
        switch sortOption {
        case .aiPriority, .thematicGenre, .aiPartOfSpeech: break
        case .newestFirst: list.sort { $0.dateAdded > $1.dateAdded }
        case .oldestFirst: list.sort { $0.dateAdded < $1.dateAdded }
        case .alphabeticalAZ: list.sort { $0.cleanTitle.localizedCaseInsensitiveCompare($1.cleanTitle) == .orderedAscending }
        case .alphabeticalZA: list.sort { $0.cleanTitle.localizedCaseInsensitiveCompare($1.cleanTitle) == .orderedDescending }
        case .favoritesFirst: list.sort { ($0.isFavorite ? 0 : 1) < ($1.isFavorite ? 0 : 1) }
        case .learningFirst: list.sort { ($0.isMastered ? 1 : 0) < ($1.isMastered ? 1 : 0) }
        }
        
        return list
    }
    
    private var emptyListMessage: String {
        if !searchText.isEmpty { return "Không tìm thấy kết quả phù hợp" }
        switch selectedSidebarItem {
        case .stats: return "Bảng thống kê học tập"
        case .vocabulary: return "Chưa có từ vựng nào được lưu"
        case .grammar: return "Chưa có công thức ngữ pháp nào được lưu"
        case .favorites: return "Chưa có mục nào được đánh dấu yêu thích"
        case .mastered: return "Chưa có mục nào được đánh dấu đã thuộc"
        case .all, .none: return "Sổ tay của bạn đang trống"
        }
    }
}
