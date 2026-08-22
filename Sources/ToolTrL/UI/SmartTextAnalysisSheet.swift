import SwiftUI

public enum AnalysisFilterTab: String, CaseIterable, Identifiable {
    case all = "Tất cả"
    case grammar = "Công thức ngữ pháp"
    case vocabulary = "Từ vựng"
    
    public var id: String { rawValue }
}

public enum VocabSortOption: String, CaseIterable, Identifiable {
    case smartAI = "🌟 Phân loại AI (Mức độ quan trọng)"
    case partOfSpeech = "🏷️ Theo Từ Loại (Noun, Verb, Adj...)"
    case appearance = "⏱️ Thứ tự xuất hiện trong bài"
    case alphabetical = "🔤 Bảng chữ cái (A → Z)"
    
    public var id: String { rawValue }
}

public struct SmartTextAnalysisSheet: View {
    @ObservedObject var analyzer = TextAnalysisService.shared
    @ObservedObject var speechService = SpeechService.shared
    
    @State private var inputText: String = ""
    @State private var analysisResult: TextAnalysisResult? = nil
    @State private var selectedTab: AnalysisFilterTab = .all
    @State private var sortOption: VocabSortOption = .smartAI
    @State private var savedCount: Int? = nil
    @State private var showSavedNotification: Bool = false
    
    private var initialText: String
    private var onClose: (() -> Void)?
    
    public init(initialText: String = "", onClose: (() -> Void)? = nil) {
        self.initialText = initialText
        self.onClose = onClose
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Unified Top Header with Traffic Lights clearance
            topHeaderBar
            
            Divider().opacity(0.2)
            
            // Main Content Area
            VStack(spacing: 0) {
                // Input Text Box
                inputSection
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                
                Divider().opacity(0.15)
                
                // Result Views
                if analyzer.isAnalyzing {
                    loadingSection
                } else if let result = analysisResult {
                    if result.vocabularies.isEmpty && result.grammars.isEmpty {
                        emptyResultSection
                    } else {
                        // Filter Tabs & Items
                        resultsContent(result)
                    }
                } else {
                    welcomeHintSection
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Bottom Action Bar
            if let result = analysisResult, (!result.vocabularies.isEmpty || !result.grammars.isEmpty) {
                Divider().opacity(0.2)
                bottomActionBar(result)
            }
        }
        .frame(minWidth: 720, minHeight: 600)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
        .ignoresSafeArea()
        .onAppear {
            if !initialText.isEmpty {
                self.inputText = initialText
                Task {
                    self.analysisResult = await analyzer.analyzeText(initialText)
                }
            }
        }
    }
    
    // MARK: - Top Header Bar
    private var topHeaderBar: some View {
        HStack(alignment: .center, spacing: 8) {
            // Traffic Light Clearance
            Spacer()
                .frame(width: 72)
            
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.purple)
                Text("AI Bóc Tách Ngữ Pháp & Từ Vựng")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            if let closeAction = onClose {
                Button(action: closeAction) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary.opacity(0.65))
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
                .help("Đóng")
            }
        }
        .frame(height: 48)
        .background(Color.primary.opacity(0.025))
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Nhập hoặc dán đoạn văn bản:")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !inputText.isEmpty {
                    Text("\(inputText.split(separator: " ").count) từ")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary.opacity(0.8))
                }
            }
            
            TextEditor(text: $inputText)
                .font(.system(size: 12.5))
                .frame(height: 72)
                .padding(6)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            
            HStack(spacing: 8) {
                Button(action: {
                    Task {
                        self.analysisResult = await analyzer.analyzeText(inputText)
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                        Text("Phân Tích Ngay (AI On-Device)")
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.4) : Color.purple)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Button(action: {
                    QuickAIWindowController.shared.showAI(
                        prompt: "Hãy phân tích chi tiết đoạn văn sau:\n1. Bóc tách toàn bộ từ vựng quan trọng (Từ, Loại từ, Nghĩa tiếng Việt, Phiên âm, Ví dụ).\n2. Liệt kê toàn bộ công thức và cấu trúc ngữ pháp có trong câu.\n\nĐoạn văn:\n\(inputText)"
                    )
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Hỏi sâu với ChatGPT / Gemini...")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
                
                if !inputText.isEmpty {
                    Button("Xóa văn bản") {
                        inputText = ""
                        analysisResult = nil
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Filter Tabs & Results Content
    private func resultsContent(_ result: TextAnalysisResult) -> some View {
        VStack(spacing: 0) {
            // Segmented Filter Bar + Sort Options
            HStack(spacing: 8) {
                // Category Filter Pills
                HStack(spacing: 4) {
                    ForEach(AnalysisFilterTab.allCases) { tab in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 4) {
                                Text(tab.rawValue)
                                    .font(.system(size: 11, weight: selectedTab == tab ? .bold : .medium))
                                
                                let count = badgeCount(for: tab, result: result)
                                Text("\(count)")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(selectedTab == tab ? Color.white.opacity(0.25) : Color.primary.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .foregroundColor(selectedTab == tab ? .white : .secondary)
                            .background(selectedTab == tab ? Color.purple : Color.primary.opacity(0.03))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                Spacer()
                
                // AI Sort / Grouping Menu
                if selectedTab != .grammar {
                    Menu {
                        ForEach(VocabSortOption.allCases) { opt in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    sortOption = opt
                                }
                            }) {
                                if sortOption == opt {
                                    Label(opt.rawValue, systemImage: "checkmark")
                                } else {
                                    Text(opt.rawValue)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 9.5))
                            Text(sortOption.rawValue)
                                .font(.system(size: 10.5, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(5)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.015))
            
            Divider().opacity(0.15)
            
            // Scrollable List
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if (selectedTab == .all || selectedTab == .grammar) && !result.grammars.isEmpty {
                        grammarSection(result)
                    }
                    
                    if (selectedTab == .all || selectedTab == .vocabulary) && !result.vocabularies.isEmpty {
                        sortedVocabularySection(result)
                    }
                }
                .padding(18)
            }
        }
    }
    
    private func badgeCount(for tab: AnalysisFilterTab, result: TextAnalysisResult) -> Int {
        switch tab {
        case .all: return result.grammars.count + result.vocabularies.count
        case .grammar: return result.grammars.count
        case .vocabulary: return result.vocabularies.count
        }
    }
    
    // MARK: - Grammar Section
    private func grammarSection(_ result: TextAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "function")
                    .foregroundColor(.blue)
                Text("Cấu Trúc Ngữ Pháp Nhận Diện Được (\(result.grammars.count))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
            }
                
                ForEach(result.grammars.indices, id: \.self) { idx in
                    let item = result.grammars[idx]
                    HStack(alignment: .top, spacing: 10) {
                        Button(action: {
                            analysisResult?.grammars[idx].isSelected.toggle()
                        }) {
                            Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 15))
                                .foregroundColor(item.isSelected ? .blue : .secondary.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(item.formula)
                                .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(4)
                            
                            Text(item.meaningVi)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            if !item.exampleSentence.isEmpty {
                                HStack(alignment: .top, spacing: 4) {
                                    Text("Ví dụ:")
                                        .font(.system(size: 10.5, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text("\"\(item.exampleSentence)\"")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.primary.opacity(0.85))
                                        .italic()
                                }
                                .padding(.top, 2)
                            }
                        }
                    }
                    .padding(11)
                    .background(Color.primary.opacity(0.025))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(item.isSelected ? Color.blue.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 1)
                    )
                }
            }
        }
    
    // MARK: - Sorted & Grouped Vocabulary Section
    private func sortedVocabularySection(_ result: TextAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            switch sortOption {
            case .smartAI:
                // Group by AI Importance
                ForEach(VocabImportance.allCases, id: \.self) { importance in
                    let items = result.vocabularies.filter { $0.importance == importance }
                    if !items.isEmpty {
                        vocabGroupBlock(
                            title: importance.displayName,
                            color: importance.badgeColor,
                            items: items
                        )
                    }
                }
                
            case .partOfSpeech:
                // Group by Part of Speech
                ForEach(POSCategory.allCases, id: \.self) { pos in
                    let items = result.vocabularies.filter { $0.posCategory == pos }
                    if !items.isEmpty {
                        vocabGroupBlock(
                            title: "\(pos.rawValue)s",
                            color: pos.color,
                            items: items
                        )
                    }
                }
                
            case .appearance:
                let sorted = result.vocabularies.sorted { $0.orderIndex < $1.orderIndex }
                vocabGroupBlock(
                    title: "⏱️ Thứ Tự Xuất Hiện Trong Bài",
                    color: .purple,
                    items: sorted
                )
                
            case .alphabetical:
                let sorted = result.vocabularies.sorted { $0.word.lowercased() < $1.word.lowercased() }
                vocabGroupBlock(
                    title: "🔤 Bảng Chữ Cái (A → Z)",
                    color: .orange,
                    items: sorted
                )
            }
        }
    }
    
    // MARK: - Reusable Vocabulary Group Block
    private func vocabGroupBlock(title: String, color: Color, items: [ExtractedVocabulary]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(color)
                
                Text("\(items.count)")
                    .font(.system(size: 9.5, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(color.opacity(0.12))
                    .foregroundColor(color)
                    .clipShape(Capsule())
                
                Spacer()
                
                // Select All / Deselect All for this group
                let allSelected = items.allSatisfy { $0.isSelected }
                Button(action: {
                    toggleSelectGroup(items: items, selectAll: !allSelected)
                }) {
                    Text(allSelected ? "Bỏ chọn nhóm" : "Chọn nhóm")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 310), spacing: 8)], spacing: 8) {
                ForEach(items) { item in
                    vocabCard(item: item)
                }
            }
        }
        .padding(10)
        .background(Color.primary.opacity(0.015))
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.primary.opacity(0.04), lineWidth: 0.8)
        )
    }
    
    private func toggleVocabSelection(id: UUID) {
        guard var res = analysisResult else { return }
        if let idx = res.vocabularies.firstIndex(where: { $0.id == id }) {
            res.vocabularies[idx].isSelected.toggle()
            self.analysisResult = res
        }
    }
    
    private func vocabCard(item: ExtractedVocabulary) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Button(action: {
                toggleVocabSelection(id: item.id)
            }) {
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(item.isSelected ? .orange : .secondary.opacity(0.35))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .center, spacing: 6) {
                    Text(item.word)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(item.partOfSpeech)
                        .font(.system(size: 9))
                        .foregroundColor(.orange)
                        .padding(.horizontal, 4.5)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(3)
                    
                    Spacer()
                    
                    Button(action: {
                        speechService.speak(text: item.word, languageCode: "en-US", speakerID: "vocab_\(item.id)")
                    }) {
                        Image(systemName: (speechService.isSpeaking && speechService.currentSpeakerID == "vocab_\(item.id)") ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .help("Nghe phát âm")
                }
                
                Text(item.vietnameseMeaning)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary.opacity(0.9))
                
                if !item.contextSentence.isEmpty {
                    Text("\"\(item.contextSentence)\"")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .italic()
                        .lineLimit(2)
                }
            }
        }
        .padding(9)
        .background(Color.primary.opacity(0.025))
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(item.isSelected ? Color.orange.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
    
    private func toggleSelectGroup(items: [ExtractedVocabulary], selectAll: Bool) {
        guard var currentResult = analysisResult else { return }
        let ids = Set(items.map { $0.id })
        for i in 0..<currentResult.vocabularies.count {
            if ids.contains(currentResult.vocabularies[i].id) {
                currentResult.vocabularies[i].isSelected = selectAll
            }
        }
        self.analysisResult = currentResult
    }
    
    // MARK: - Welcome & Empty States
    private var loadingSection: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .scaleEffect(0.9)
            Text("AI đang bóc tách cấu trúc ngữ pháp và từ vựng...")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyResultSection: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Không tìm thấy cấu trúc ngữ pháp hay từ vựng đặc thù trong đoạn văn này.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var welcomeHintSection: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wand.and.stars")
                .font(.system(size: 34))
                .foregroundColor(.purple.opacity(0.5))
            
            Text("Dán một đoạn văn tiếng Anh vào ô phía trên và bấm 'Phân Tích Ngay'\nAI sẽ tự động trích xuất toàn bộ công thức ngữ pháp và từ vựng trọng tâm cho bạn.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Bottom Action Bar
    private func bottomActionBar(_ result: TextAnalysisResult) -> some View {
        let selectedVocabCount = result.vocabularies.filter { $0.isSelected }.count
        let selectedGrammarCount = result.grammars.filter { $0.isSelected }.count
        let totalSelected = selectedVocabCount + selectedGrammarCount
        
        return HStack(spacing: 12) {
            HStack(spacing: 6) {
                Button("Chọn tất cả") {
                    toggleAllSelection(true)
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(.purple)
                
                Text("•")
                    .foregroundColor(.secondary.opacity(0.5))
                
                Button("Bỏ chọn hết") {
                    toggleAllSelection(false)
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if showSavedNotification, let count = savedCount {
                Text("✅ Đã lưu \(count) mục vào Sổ tay!")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
            
            Button(action: {
                let count = analyzer.saveSelectedToNotebook(result: result)
                self.savedCount = count
                withAnimation {
                    self.showSavedNotification = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        self.showSavedNotification = false
                    }
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "folder.badge.plus")
                    Text("Lưu vào Sổ Tay (\(totalSelected) mục)")
                }
                .font(.system(size: 11.5, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6.5)
                .background(totalSelected > 0 ? Color.orange : Color.gray.opacity(0.4))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(totalSelected == 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.02))
    }
    
    private func toggleAllSelection(_ selected: Bool) {
        guard var result = analysisResult else { return }
        for i in 0..<result.vocabularies.count {
            result.vocabularies[i].isSelected = selected
        }
        for i in 0..<result.grammars.count {
            result.grammars[i].isSelected = selected
        }
        self.analysisResult = result
    }
}
