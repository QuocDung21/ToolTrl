import SwiftUI

public enum AnalysisFilterTab: String, CaseIterable, Identifiable {
    case all = "Tất cả"
    case grammar = "Công thức ngữ pháp"
    case vocabulary = "Từ vựng trọng tâm"
    
    public var id: String { rawValue }
}

public struct SmartTextAnalysisSheet: View {
    @ObservedObject var analyzer = TextAnalysisService.shared
    @ObservedObject var speechService = SpeechService.shared
    
    @State private var inputText: String = ""
    @State private var analysisResult: TextAnalysisResult? = nil
    @State private var savedCountToast: Int? = nil
    @State private var selectedTab: AnalysisFilterTab = .all
    
    public let initialText: String
    public var onClose: (() -> Void)? = nil
    
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
        .frame(minWidth: 700, minHeight: 580)
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
            // Traffic Light Clearance (Exact alignment with macOS Traffic Lights 🔴 🟡 🟢)
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
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !inputText.isEmpty {
                    Text("\(inputText.split(separator: " ").count) từ")
                        .font(.system(size: 10.5))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            
            TextEditor(text: $inputText)
                .font(.system(size: 12))
                .padding(6)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(8)
                .frame(height: 65)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
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
            // Segmented Filter Bar
            HStack(spacing: 6) {
                ForEach(AnalysisFilterTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: selectedTab == tab ? .bold : .medium))
                            
                            // Badge Count
                            let count = badgeCount(for: tab, result: result)
                            Text("\(count)")
                                .font(.system(size: 9.5, weight: .bold))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(selectedTab == tab ? Color.white.opacity(0.25) : Color.primary.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4.5)
                        .foregroundColor(selectedTab == tab ? .white : .secondary)
                        .background(selectedTab == tab ? Color.purple : Color.primary.opacity(0.03))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.015))
            
            Divider().opacity(0.15)
            
            // Scrollable List
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if (selectedTab == .all || selectedTab == .grammar) && !result.grammars.isEmpty {
                        grammarSection(result)
                    }
                    
                    if (selectedTab == .all || selectedTab == .vocabulary) && !result.vocabularies.isEmpty {
                        vocabularySection(result)
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
                Text("Cấu Trúc & Công Thức Ngữ Pháp (\(result.grammars.count))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 8) {
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
                            HStack(alignment: .center) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(item.formula)
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2.5)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            
                            Text(item.meaningVi)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            if !item.exampleSentence.isEmpty {
                                HStack(alignment: .top, spacing: 4) {
                                    Text("Ví dụ trong đoạn:")
                                        .font(.system(size: 10, weight: .bold))
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
    }
    
    // MARK: - Vocabulary Section
    private func vocabularySection(_ result: TextAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "character.book.closed.fill")
                    .foregroundColor(.orange)
                Text("Từ Vựng Trọng Tâm & Collocations (\(result.vocabularies.count))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 8)], spacing: 8) {
                ForEach(result.vocabularies.indices, id: \.self) { idx in
                    let item = result.vocabularies[idx]
                    HStack(alignment: .top, spacing: 9) {
                        Button(action: {
                            analysisResult?.vocabularies[idx].isSelected.toggle()
                        }) {
                            Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 15))
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
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 5)
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
                    .padding(10)
                    .background(Color.primary.opacity(0.025))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(item.isSelected ? Color.orange.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 1)
                    )
                }
            }
        }
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
    
    private var welcomeHintSection: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Dán một đoạn văn tiếng Anh vào ô trên và bấm 'Phân Tích Ngay'")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyResultSection: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Không tìm thấy cấu trúc ngữ pháp đặc thù trong đoạn này.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Bottom Action Bar
    private func bottomActionBar(_ result: TextAnalysisResult) -> some View {
        let selectedVocabs = result.vocabularies.filter { $0.isSelected }.count
        let selectedGrammars = result.grammars.filter { $0.isSelected }.count
        let totalSelected = selectedVocabs + selectedGrammars
        
        return HStack {
            Text("Đã chọn \(selectedVocabs) từ vựng và \(selectedGrammars) công thức")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(.secondary)
            
            Spacer()
            
            if let saved = savedCountToast {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                    Text("Đã lưu \(saved) mục vào Sổ tay!")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.green)
                }
                .transition(.opacity)
            }
            
            Button(action: {
                let count = analyzer.saveSelectedToNotebook(result: result)
                withAnimation {
                    self.savedCountToast = count
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        self.savedCountToast = nil
                    }
                }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "tray.and.arrow.down.fill")
                    Text("Lưu (\(totalSelected)) vào Sổ tay từ vựng")
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(totalSelected > 0 ? Color.blue : Color.gray.opacity(0.5))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .disabled(totalSelected == 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
    }
}
