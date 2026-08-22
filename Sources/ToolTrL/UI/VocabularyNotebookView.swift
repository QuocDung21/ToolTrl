import SwiftUI

public enum NotebookSection: String, CaseIterable, Identifiable {
    case vocabulary = "Từ vựng"
    case grammar = "Ngữ pháp"
    case favorites = "Yêu thích"
    case mastered = "Đã thuộc"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .vocabulary: return "text.book.closed.fill"
        case .grammar: return "function"
        case .favorites: return "star.fill"
        case .mastered: return "checkmark.seal.fill"
        }
    }
}

public struct VocabularyNotebookView: View {
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var speechService = SpeechService.shared
    
    @State private var selectedSection: NotebookSection = .vocabulary
    @State private var searchText: String = ""
    @State private var selectedItemID: UUID? = nil
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
                VStack(spacing: 0) {
                    // Unified Top Toolbar
                    topToolbar
                    
                    Divider().opacity(0.2)
                    
                    // Main 2-Pane Content
                    HStack(spacing: 0) {
                        // Left List Pane
                        itemListView
                            .frame(width: 300)
                        
                        Divider().opacity(0.2)
                        
                        // Right Detail Pane
                        detailPaneView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(minWidth: 880, minHeight: 580)
        .background(VisualEffectBackground(material: .underWindowBackground, blendingMode: .behindWindow))
        .ignoresSafeArea()
        .onAppear {
            if selectedItemID == nil, let first = filteredItems.first {
                selectedItemID = first.id
            }
        }
    }
    
    // MARK: - Top Window Toolbar
    private var topToolbar: some View {
        HStack(spacing: 12) {
            // Traffic Light Space
            Spacer()
                .frame(width: 70)
            
            // Section Switcher Segmented Control
            HStack(spacing: 2) {
                ForEach(NotebookSection.allCases) { sec in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSection = sec
                            if let first = filteredItems.first {
                                selectedItemID = first.id
                            }
                        }
                    }) {
                        HStack(spacing: 4.5) {
                            Image(systemName: sec.icon)
                                .font(.system(size: 10))
                            Text(sec.rawValue)
                                .font(.system(size: 11.5, weight: selectedSection == sec ? .semibold : .regular))
                            
                            let count = sectionCount(sec)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 4.5)
                                    .padding(.vertical, 1)
                                    .background(selectedSection == sec ? Color.primary.opacity(0.12) : Color.primary.opacity(0.06))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .foregroundColor(selectedSection == sec ? .primary : .secondary)
                        .background(
                            selectedSection == sec ? Color.primary.opacity(0.08) : Color.clear
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color.primary.opacity(0.035))
            .cornerRadius(8)
            
            Spacer()
            
            // Search Input
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                TextField("Tìm kiếm...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11.5))
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4.5)
            .frame(width: 180)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(6)
            
            // AI Analysis Button
            Button(action: {
                TextAnalysisWindowController.shared.showAnalysis()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 11))
                    Text("AI Bóc Tách")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.purple)
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Dán đoạn văn để AI tự bóc tách từ vựng & cấu trúc ngữ pháp")
            
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
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled.fill")
                        .font(.system(size: 10.5))
                    Text("Flashcard")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 9)
                .padding(.vertical, 4.5)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(filteredItems.isEmpty)
            .help("Ôn luyện từ vựng / công thức dạng thẻ lật")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
    }
    
    private func sectionCount(_ sec: NotebookSection) -> Int {
        switch sec {
        case .vocabulary: return vocabService.savedWords.filter { !$0.isGrammarFormula }.count
        case .grammar: return vocabService.savedWords.filter { $0.isGrammarFormula }.count
        case .favorites: return vocabService.savedWords.filter { $0.isFavorite }.count
        case .mastered: return vocabService.savedWords.filter { $0.isMastered }.count
        }
    }
    
    // MARK: - Left Items List
    private var itemListView: some View {
        Group {
            if filteredItems.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: selectedSection.icon)
                        .font(.system(size: 28))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text(emptyListMessage)
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredItems) { item in
                            itemRow(item: item, isSelected: item.id == selectedItemID)
                                .onTapGesture {
                                    selectedItemID = item.id
                                }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
    }
    
    private func itemRow(item: SavedWordItem, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    if item.isGrammarFormula {
                        Text("📐")
                            .font(.system(size: 9.5))
                    }
                    
                    Text(item.cleanTitle)
                        .font(.system(size: 12.5, weight: isSelected ? .bold : .semibold))
                        .foregroundColor(isSelected ? .white : .primary)
                        .lineLimit(1)
                    
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8.5))
                            .foregroundColor(isSelected ? .yellow : .orange)
                    }
                    
                    if item.isMastered {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundColor(isSelected ? .white.opacity(0.9) : .green)
                    }
                }
                
                Text(item.isGrammarFormula ? (item.phonetic ?? item.translation) : item.translation)
                    .font(.system(size: 11, design: item.isGrammarFormula ? .monospaced : .default))
                    .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6.5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }
    
    // MARK: - Right Detail Pane
    private var detailPaneView: some View {
        Group {
            if let id = selectedItemID,
               let item = vocabService.savedWords.first(where: { $0.id == id }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Header Bar: Title + Pronounce + Action Icons
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    if item.isGrammarFormula {
                                        Text("CÔNG THỨC NGỮ PHÁP")
                                            .font(.system(size: 9.5, weight: .bold))
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                    } else if let ph = item.phonetic, !ph.isEmpty {
                                        Text(ph)
                                            .font(.system(size: 12.5, weight: .medium, design: .serif))
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                Text(item.cleanTitle)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            // Pronounce Audio Button (for Vocabulary)
                            if !item.isGrammarFormula {
                                Button(action: {
                                    speechService.speak(text: item.word, languageCode: "en-US", speakerID: "detail_\(item.id.uuidString)")
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "detail_\(item.id.uuidString)") ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
                                            .font(.system(size: 11))
                                        Text("Phát âm")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.primary.opacity(0.05))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Favorite Button
                            Button(action: {
                                vocabService.toggleFavorite(id: item.id)
                            }) {
                                Image(systemName: item.isFavorite ? "star.fill" : "star")
                                    .font(.system(size: 12))
                                    .foregroundColor(item.isFavorite ? .orange : .secondary)
                                    .padding(6)
                                    .background(Color.primary.opacity(0.04))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help(item.isFavorite ? "Bỏ yêu thích" : "Đánh dấu yêu thích")
                            
                            // Mastered Button
                            Button(action: {
                                vocabService.toggleMastered(id: item.id)
                            }) {
                                Image(systemName: item.isMastered ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 12))
                                    .foregroundColor(item.isMastered ? .green : .secondary)
                                    .padding(6)
                                    .background(Color.primary.opacity(0.04))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help(item.isMastered ? "Bỏ đánh dấu đã thuộc" : "Đánh dấu đã thuộc")
                            
                            // Delete Button
                            Button(action: {
                                vocabService.removeWord(id: item.id)
                                if let next = filteredItems.first {
                                    selectedItemID = next.id
                                } else {
                                    selectedItemID = nil
                                }
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .padding(6)
                                    .background(Color.primary.opacity(0.04))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help("Xóa khỏi sổ tay")
                        }
                        
                        Divider().opacity(0.15)
                        
                        // Formula Box (If Grammar)
                        if item.isGrammarFormula, let formula = item.phonetic, !formula.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("CÔNG THỨC")
                                        .font(.system(size: 9.5, weight: .bold))
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        let pb = NSPasteboard.general
                                        pb.clearContents()
                                        pb.setString(formula, forType: .string)
                                        withAnimation { formulaCopied = true }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { formulaCopied = false }
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: formulaCopied ? "checkmark" : "doc.on.doc")
                                            Text(formulaCopied ? "Đã chép" : "Sao chép")
                                        }
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.blue)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Text(formula)
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(.blue)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.06))
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(Color.blue.opacity(0.15), lineWidth: 1)
                                    )
                            }
                        }
                        
                        // Meaning & Explanation Card
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.isGrammarFormula ? "Ý NGHĨA & CÁCH DÙNG" : "Ý NGHĨA TIẾNG VIỆT")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Text(item.translation)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                                .lineSpacing(3)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.025))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                        )
                        
                        // Example Sentence Card
                        if let exEn = item.exampleEn, !exEn.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("VÍ DỤ TRONG ĐOẠN VĂN")
                                        .font(.system(size: 9.5, weight: .bold))
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
                                    .font(.system(size: 13, design: .serif))
                                    .foregroundColor(.primary)
                                    .italic()
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.025))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                        }
                    }
                    .padding(20)
                }
            } else {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("Chọn một mục ở danh sách bên trái để xem chi tiết")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
    }
    
    // MARK: - Filter Items Logic
    private var filteredItems: [SavedWordItem] {
        var list = vocabService.savedWords
        
        switch selectedSection {
        case .vocabulary:
            list = list.filter { !$0.isGrammarFormula }
        case .grammar:
            list = list.filter { $0.isGrammarFormula }
        case .favorites:
            list = list.filter { $0.isFavorite }
        case .mastered:
            list = list.filter { $0.isMastered }
        }
        
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
    
    private var emptyListMessage: String {
        if !searchText.isEmpty { return "Không tìm thấy kết quả phù hợp" }
        switch selectedSection {
        case .vocabulary: return "Chưa có từ vựng nào được lưu"
        case .grammar: return "Chưa có công thức ngữ pháp nào được lưu"
        case .favorites: return "Chưa có mục nào được đánh dấu yêu thích"
        case .mastered: return "Chưa có mục nào được đánh dấu đã thuộc"
        }
    }
    
    // MARK: - Flashcard Study View
    private var flashcardStudyView: some View {
        VStack(spacing: 0) {
            // Flashcard Top Bar
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isFlashcardMode = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Quay lại")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("\(flashcardIndex + 1) / \(filteredItems.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Spacer()
            
            // 3D Flip Card
            if flashcardIndex < filteredItems.count {
                let currentItem = filteredItems[flashcardIndex]
                
                ZStack {
                    if isCardFlipped {
                        // BACK OF CARD
                        VStack(spacing: 12) {
                            Text(currentItem.isGrammarFormula ? "📐 CÔNG THỨC & Ý NGHĨA" : "Ý NGHĨA")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(currentItem.isGrammarFormula ? .blue : .orange)
                            
                            if currentItem.isGrammarFormula, let formula = currentItem.phonetic {
                                Text(formula)
                                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    .foregroundColor(.blue)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                            
                            Text(currentItem.translation)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            Text("Bấm để lật lại")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .frame(width: 420, height: 240)
                        .background(Color.primary.opacity(0.035))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .rotation3DEffect(.degrees(isCardFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                    } else {
                        // FRONT OF CARD
                        VStack(spacing: 12) {
                            Text(currentItem.isGrammarFormula ? "CẤU TRÚC NGỮ PHÁP" : "TỪ VỰNG")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Text(currentItem.cleanTitle)
                                .font(.system(size: 22, weight: .bold))
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
                                    .padding(.horizontal, 20)
                            }
                            
                            Text("Bấm để xem đáp án")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.5))
                        }
                        .frame(width: 420, height: 240)
                        .background(Color.primary.opacity(0.035))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
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
            
            // Bottom Controls
            HStack(spacing: 16) {
                Button(action: {
                    if flashcardIndex > 0 {
                        flashcardIndex -= 1
                        isCardFlipped = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("Trước")
                    }
                    .font(.system(size: 11.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(flashcardIndex == 0)
                
                Button(action: {
                    if flashcardIndex < filteredItems.count {
                        let item = filteredItems[flashcardIndex]
                        speechService.speak(text: item.cleanTitle, languageCode: "en-US", speakerID: "flashcard")
                    }
                }) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 13))
                        .padding(9)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    if flashcardIndex < filteredItems.count - 1 {
                        flashcardIndex += 1
                        isCardFlipped = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("Kế tiếp")
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 11.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(flashcardIndex >= filteredItems.count - 1)
            }
            .padding(.bottom, 24)
        }
    }
}
