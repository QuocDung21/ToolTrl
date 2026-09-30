import SwiftUI
import AppKit

public struct MainWorkspaceView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var githubSync = GitHubSyncService.shared
    
    // Notebook local states
    @State private var selectedItemID: UUID? = nil
    @State private var searchText: String = ""
    @State private var sortOption: NotebookSortOption = .aiPriority
    @State private var layoutMode: NotebookLayoutMode = .split
    @State private var isQuickLookPresented: Bool = false
    @State private var showAddWordSheet: Bool = false
    @State private var showAddGrammarSheet: Bool = false
    @State private var editingItem: SavedWordItem? = nil
    @State private var keyMonitor: Any? = nil
    @State private var isFullScreen: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    public init() {}
    
    // MARK: - Computed Counts
    private var allCount: Int { vocabService.savedWords.count }
    private var vocabCount: Int { vocabService.savedWords.filter { !$0.isGrammarFormula }.count }
    private var grammarCount: Int { vocabService.savedWords.filter { $0.isGrammarFormula }.count }
    private var favCount: Int { vocabService.savedWords.filter { $0.isFavorite }.count }
    private var masteredCount: Int { vocabService.savedWords.filter { $0.isMastered }.count }
    
    // MARK: - Filtered Notebook Items
    private var filteredItems: [SavedWordItem] {
        var list: [SavedWordItem]
        switch settings.selectedSidebarItem {
        case .notebookVocab:
            list = vocabService.savedWords.filter { !$0.isGrammarFormula }
        case .notebookGrammar:
            list = vocabService.savedWords.filter { $0.isGrammarFormula }
        case .notebookFavorites:
            list = vocabService.savedWords.filter { $0.isFavorite }
        case .notebookMastered:
            list = vocabService.savedWords.filter { $0.isMastered }
        default:
            list = vocabService.savedWords
        }
        
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmed.isEmpty {
            list = list.filter {
                $0.word.lowercased().contains(trimmed) ||
                $0.translation.lowercased().contains(trimmed) ||
                ($0.phonetic?.lowercased().contains(trimmed) ?? false) ||
                ($0.exampleEn?.lowercased().contains(trimmed) ?? false)
            }
        }
        
        switch sortOption {
        case .aiPriority, .thematicGenre, .aiPartOfSpeech:
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
    
    private var selectedItem: SavedWordItem? {
        guard let id = selectedItemID else { return nil }
        return vocabService.savedWords.first(where: { $0.id == id })
    }
    
    // MARK: - Main Body
    public var body: some View {
        ZStack {
            mainSplitLayout
            
            // Spacebar Quick Look Modal
            if isQuickLookPresented, let item = selectedItem {
                NotebookQuickLookModal(item: item, isPresented: $isQuickLookPresented)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(100)
            }
        }
        .frame(minWidth: 1000, minHeight: 660)
        .background(VisualEffectBackground(material: .windowBackground, blendingMode: .behindWindow))
        .background(keyboardShortcutsHandler)
        .onAppear {
            setupSpacebarMonitor()
            if selectedItemID == nil, let first = filteredItems.first {
                selectedItemID = first.id
            }
            if let win = NSApp.keyWindow {
                isFullScreen = win.styleMask.contains(.fullScreen)
            }
        }
        .onDisappear {
            removeSpacebarMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isFullScreen = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                isFullScreen = false
            }
        }
        .sheet(isPresented: $showAddWordSheet) {
            AddWordSheet()
        }
        .sheet(isPresented: $showAddGrammarSheet) {
            AddGrammarSheet()
        }
        .sheet(item: $editingItem) { item in
            AddWordSheet(editingItem: item)
        }
    }
    
    // MARK: - Adaptive Split Layout
    @ViewBuilder
    private var mainSplitLayout: some View {
        if settings.selectedSidebarItem.isNotebookFolder {
            // 3-Column Mode for Notebook
            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebarView
                    .navigationSplitViewColumnWidth(min: 200, ideal: 225, max: 260)
            } content: {
                notebookListView
                    .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
            } detail: {
                notebookDetailPane
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            // 2-Column Mode for Translation, Flashcards, AI, Stats
            NavigationSplitView(columnVisibility: $columnVisibility) {
                sidebarView
                    .navigationSplitViewColumnWidth(min: 200, ideal: 225, max: 260)
            } detail: {
                singleStudioPane
            }
            .navigationSplitViewStyle(.balanced)
        }
    }
    
    // MARK: - 1. Unified Sidebar (Left Column)
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // App Branding Header (Unified with Traffic Lights)
            HStack(spacing: 8) {
                AppLogo.image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("NekoTrans")
                        .font(.system(size: 13, weight: .bold))
                    Text("AI Language Studio")
                        .font(.system(size: 9.5))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.leading, isFullScreen ? 16 : 76)
            .padding(.trailing, 12)
            .frame(height: 48)
            .animation(.easeInOut(duration: 0.2), value: isFullScreen)
            
            Divider()
                .opacity(0.3)
            
            // Sidebar Navigation Items
            List(selection: $settings.selectedSidebarItem) {
                Section("TRA CỨU & DỊCH THUẬT") {
                    sidebarRow(item: .translate, count: nil)
                }
                
                Section("SỔ TAY TỪ VỰNG & NGỮ PHÁP") {
                    sidebarRow(item: .notebookAll, count: allCount)
                    sidebarRow(item: .notebookVocab, count: vocabCount)
                    sidebarRow(item: .notebookGrammar, count: grammarCount)
                    sidebarRow(item: .notebookFavorites, count: favCount)
                    sidebarRow(item: .notebookMastered, count: masteredCount)
                }
                
                Section("HỌC TẬP & CÔNG CỤ") {
                    sidebarRow(item: .flashcards, count: nil)
                    sidebarRow(item: .deepAI, count: nil)
                    sidebarRow(item: .stats, count: nil)
                }
            }
            .listStyle(.sidebar)
            
            Divider()
                .opacity(0.3)
            
            // Sidebar Footer: Status & Settings
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                    Text("⌥D Sẵn sàng")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    SettingsWindowController.shared.showSettings()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cài đặt ứng dụng (⌘,)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
    
    private func sidebarRow(item: WorkspaceSidebarItem, count: Int?) -> some View {
        NavigationLink(value: item) {
            HStack {
                Label {
                    Text(item.title)
                        .font(.system(size: 12.5))
                } icon: {
                    Image(systemName: item.icon)
                        .font(.system(size: 12.5))
                        .foregroundColor(item == settings.selectedSidebarItem ? .accentColor : .secondary)
                }
                
                Spacer()
                
                if let count = count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - 2. Notebook List View (Middle Column)
    private var notebookListView: some View {
        VStack(spacing: 0) {
            // Search & Sort Bar
            VStack(spacing: 8) {
                // Search Input Field
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    
                    TextField("Tìm kiếm từ vựng, ngữ pháp...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                )
                
                // Secondary Bar: Count & Actions
                HStack {
                    Text("\(filteredItems.count) mục")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // Sort Menu
                    Menu {
                        ForEach([
                            NotebookSortOption.aiPriority,
                            NotebookSortOption.newestFirst,
                            NotebookSortOption.alphabeticalAZ,
                            NotebookSortOption.favoritesFirst,
                            NotebookSortOption.learningFirst
                        ]) { opt in
                            Button(action: { sortOption = opt }) {
                                HStack {
                                    Text(opt.rawValue)
                                    if sortOption == opt {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(sortOption.rawValue)
                                .font(.system(size: 11))
                                .lineLimit(1)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.secondary)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(maxWidth: 130)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            
            Divider().opacity(0.3)
            
            // Quick Add Action Bar
            if settings.selectedSidebarItem == .notebookGrammar {
                Button(action: { showAddGrammarSheet = true }) {
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
            } else if settings.selectedSidebarItem.isNotebookFolder {
                Button(action: { showAddWordSheet = true }) {
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
            
            // List of Items
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Không có mục nào")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if settings.selectedSidebarItem == .notebookGrammar {
                        Button(action: { showAddGrammarSheet = true }) {
                            Label("Thêm Cấu Trúc Ngữ Pháp", systemImage: "plus.circle.fill")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.purple)
                    } else if settings.selectedSidebarItem.isNotebookFolder {
                        Button(action: { showAddWordSheet = true }) {
                            Label("Thêm Từ Vựng Mới", systemImage: "plus.circle.fill")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredItems, selection: $selectedItemID) { item in
                    itemListRow(item: item)
                        .tag(item.id)
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
                                if selectedItemID == item.id {
                                    selectedItemID = filteredItems.first(where: { $0.id != item.id })?.id
                                }
                                vocabService.removeWord(id: item.id)
                            }) {
                                Label("Xóa khỏi sổ tay", systemImage: "trash")
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
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Layout Switcher (3 Cột vs Bảng)
                Picker("Chế độ xem", selection: $layoutMode) {
                    Label("3 Cột", systemImage: "rectangle.split.3x1").tag(NotebookLayoutMode.split)
                    Label("Bảng", systemImage: "tablecells").tag(NotebookLayoutMode.table)
                }
                .pickerStyle(.segmented)
                .help("Chuyển đổi giao diện: 3 Cột chi tiết hoặc Bảng dữ liệu rộng")
                
                // Add Menu (Vocabulary & Grammar)
                Menu {
                    Button(action: { showAddWordSheet = true }) {
                        Label("Thêm Từ Vựng Mới (⌘N)", systemImage: "book.closed")
                    }
                    Button(action: { showAddGrammarSheet = true }) {
                        Label("Thêm Cấu Trúc Ngữ Pháp (⇧⌘N)", systemImage: "function")
                    }
                } label: {
                    Label("Thêm", systemImage: "plus.circle.fill")
                }
                .help("Thêm từ vựng mới (⌘N) hoặc cấu trúc ngữ pháp (⇧⌘N)")
                
                // Cloud Sync Button
                Button(action: {
                    if githubSync.isConnected {
                        Task { _ = await githubSync.backupToGitHub() }
                    } else {
                        SettingsWindowController.shared.showSettings()
                    }
                }) {
                    if githubSync.isSyncing {
                        ProgressView().scaleEffect(0.6).frame(width: 16, height: 16)
                    } else {
                        Image(systemName: githubSync.isConnected ? "icloud.and.arrow.up" : "icloud.slash")
                            .foregroundColor(githubSync.isConnected ? .accentColor : .secondary)
                    }
                }
                .help(githubSync.isConnected ? "Đồng bộ đám mây GitHub" : "Chưa kết nối GitHub")
                
                // Quick Look Button
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
                .help("Xem nhanh chi tiết (Phím Space)")
            }
        }
    }
    
    private func itemListRow(item: SavedWordItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if item.isGrammarFormula {
                    Text("📐")
                        .font(.system(size: 10))
                }
                
                Text(item.cleanTitle)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9.5))
                        .foregroundColor(.yellow)
                }
                
                if item.isMastered {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.green)
                }
            }
            
            Text(item.isGrammarFormula ? (item.phonetic ?? item.translation) : item.translation)
                .font(.system(size: 11.5, design: item.isGrammarFormula ? .monospaced : .default))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }
    
    // MARK: - 3. Notebook Detail Pane
    @ViewBuilder
    private var notebookDetailPane: some View {
        if layoutMode == .table {
            NotebookTableView(
                items: filteredItems,
                selectedItemID: $selectedItemID,
                sortOption: $sortOption
            )
        } else {
            if let item = selectedItem {
                ScrollView {
                    WordDetailDocumentView(item: item)
                        .padding(22)
                }
                .background(VisualEffectBackground(material: .contentBackground, blendingMode: .behindWindow))
            } else {
                VStack(spacing: 12) {
                    AppLogo.image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .opacity(0.6)
                    Text("Chọn một mục từ danh sách để xem chi tiết")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VisualEffectBackground(material: .contentBackground, blendingMode: .behindWindow))
            }
        }
    }
    
    // MARK: - 4. Single Studio Pane (When Not in Notebook)
    @ViewBuilder
    private var singleStudioPane: some View {
        Group {
            switch settings.selectedSidebarItem {
            case .translate:
                MainTranslationStudioView()
            case .flashcards:
                MainFlashcardHubView()
            case .deepAI:
                MainDeepAIStudioView()
            case .stats:
                LearningStatsDashboardView()
            default:
                EmptyView()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Cloud Sync Button
                Button(action: {
                    if githubSync.isConnected {
                        Task { _ = await githubSync.backupToGitHub() }
                    } else {
                        SettingsWindowController.shared.showSettings()
                    }
                }) {
                    if githubSync.isSyncing {
                        ProgressView().scaleEffect(0.6).frame(width: 16, height: 16)
                    } else {
                        Image(systemName: githubSync.isConnected ? "icloud.and.arrow.up" : "icloud.slash")
                            .foregroundColor(githubSync.isConnected ? .accentColor : .secondary)
                    }
                }
                .help(githubSync.isConnected ? "Đồng bộ đám mây GitHub" : "Chưa kết nối GitHub")
                
                // Settings Button
                Button(action: {
                    SettingsWindowController.shared.showSettings()
                }) {
                    Image(systemName: "gearshape")
                }
                .help("Cài đặt ứng dụng (⌘,)")
            }
        }
    }
    
    // MARK: - Spacebar Keyboard Monitor
    private func setupSpacebarMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard settings.selectedSidebarItem.isNotebookFolder else { return event }
            if event.keyCode == 49 { // Spacebar
                if let responder = NSApp.keyWindow?.firstResponder,
                   responder is NSTextView || responder is NSTextField {
                    return event
                }
                if self.selectedItemID != nil {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        self.isQuickLookPresented.toggle()
                    }
                    return nil
                }
            } else if event.keyCode == 53 && self.isQuickLookPresented { // Esc
                withAnimation(.easeInOut(duration: 0.15)) {
                    self.isQuickLookPresented = false
                }
                return nil
            } else if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "n" {
                if let responder = NSApp.keyWindow?.firstResponder,
                   responder is NSTextView || responder is NSTextField {
                    return event
                }
                if event.modifierFlags.contains(.shift) {
                    self.showAddGrammarSheet = true
                } else {
                    self.showAddWordSheet = true
                }
                return nil
            } else if event.keyCode == 51 || event.keyCode == 117 { // Delete / Forward Delete
                if let responder = NSApp.keyWindow?.firstResponder,
                   responder is NSTextView || responder is NSTextField {
                    return event
                }
                if let id = self.selectedItemID {
                    self.selectedItemID = filteredItems.first(where: { $0.id != id })?.id
                    vocabService.removeWord(id: id)
                    return nil
                }
            }
            return event
        }
    }
    
    private func removeSpacebarMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    // MARK: - Keyboard Shortcuts Handler
    private var keyboardShortcutsHandler: some View {
        Group {
            Button("") { settings.selectedSidebarItem = .translate }
                .keyboardShortcut("1", modifiers: .command)
            Button("") { settings.selectedSidebarItem = .notebookAll }
                .keyboardShortcut("2", modifiers: .command)
            Button("") { settings.selectedSidebarItem = .flashcards }
                .keyboardShortcut("3", modifiers: .command)
            Button("") { settings.selectedSidebarItem = .deepAI }
                .keyboardShortcut("4", modifiers: .command)
            Button("") { settings.selectedSidebarItem = .stats }
                .keyboardShortcut("5", modifiers: .command)
            Button("") { showAddWordSheet = true }
                .keyboardShortcut("n", modifiers: .command)
            Button("") { showAddGrammarSheet = true }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}
