import SwiftUI

public struct SmartTextAnalysisSheet: View {
    @ObservedObject var analyzer = TextAnalysisService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var inputText: String = ""
    @State private var analysisResult: TextAnalysisResult? = nil
    @State private var savedCountToast: Int? = nil
    
    public let initialText: String
    
    public init(initialText: String = "") {
        self.initialText = initialText
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            headerBar
            
            Divider().opacity(0.3)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Input Text Card
                    inputSection
                    
                    if analyzer.isAnalyzing {
                        loadingSection
                    } else if let result = analysisResult {
                        if result.vocabularies.isEmpty && result.grammars.isEmpty {
                            emptyResultSection
                        } else {
                            resultsSection(result)
                        }
                    }
                }
                .padding(16)
            }
            
            // Bottom Action Bar
            if let result = analysisResult, (!result.vocabularies.isEmpty || !result.grammars.isEmpty) {
                Divider().opacity(0.3)
                bottomActionBar(result)
            }
        }
        .frame(minWidth: 640, minHeight: 560)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
        .onAppear {
            if !initialText.isEmpty {
                self.inputText = initialText
                Task {
                    self.analysisResult = await analyzer.analyzeText(initialText)
                }
            }
        }
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.purple)
                Text("AI Phân Tích Đoạn Văn & Trích Xuất Ngữ Pháp / Từ Vựng")
                    .font(.system(size: 13, weight: .bold))
            }
            
            Spacer()
            
            Button("Đóng") {
                presentationMode.wrappedValue.dismiss()
            }
            .font(.system(size: 12, weight: .semibold))
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.primary.opacity(0.03))
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Đoạn văn bản cần phân tích:")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                if !inputText.isEmpty {
                    Button("Xóa") {
                        inputText = ""
                        analysisResult = nil
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }
            
            TextEditor(text: $inputText)
                .font(.system(size: 12))
                .padding(6)
                .background(Color.primary.opacity(0.035))
                .cornerRadius(8)
                .frame(height: 75)
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
                        Text("Phân tích ngay (AI On-Device)")
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray.opacity(0.5) : Color.purple)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Button(action: {
                    QuickAIWindowController.shared.showAI(
                        prompt: "Hãy phân tích chi tiết đoạn văn sau:\n1. Bóc tách toàn bộ từ vựng quan trọng (Từ, Loại từ, Nghĩa tiếng Việt, Phiên âm, Ví dụ).\n2. Liệt kê toàn bộ công thức và cấu trúc ngữ pháp có trong câu.\n\nĐoạn văn:\n\(inputText)"
                    )
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Phân tích sâu với ChatGPT / Gemini...")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
    
    // MARK: - Loading Skeleton
    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.9)
            Text("AI đang bóc tách cấu trúc ngữ pháp và từ vựng...")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }
    
    // MARK: - Empty Result
    private var emptyResultSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 26))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Không tìm thấy cấu trúc ngữ pháp hoặc từ vựng đặc thù trong đoạn này.")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
    
    // MARK: - Results Section
    private func resultsSection(_ result: TextAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 1. GRAMMAR STRUCTURES SECTION
            if !result.grammars.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "function")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.blue)
                        Text("Cấu Trúc & Công Thức Ngữ Pháp Phát Hiện Được (\(result.grammars.count))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    VStack(spacing: 8) {
                        ForEach(result.grammars.indices, id: \.self) { idx in
                            let grammar = result.grammars[idx]
                            HStack(alignment: .top, spacing: 10) {
                                Button(action: {
                                    analysisResult?.grammars[idx].isSelected.toggle()
                                }) {
                                    Image(systemName: grammar.isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(grammar.isSelected ? .blue : .secondary.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(grammar.title)
                                            .font(.system(size: 11.5, weight: .bold))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text(grammar.formula)
                                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    
                                    Text(grammar.meaningVi)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    
                                    HStack(alignment: .top, spacing: 4) {
                                        Text("Ví dụ:")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.secondary)
                                        Text("\"\(grammar.exampleSentence)\"")
                                            .font(.system(size: 10.5, weight: .medium))
                                            .foregroundColor(.primary.opacity(0.85))
                                            .italic()
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            .padding(10)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(grammar.isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            
            // 2. VOCABULARY SECTION
            if !result.vocabularies.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "character.book.closed.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                        Text("Từ Vựng Trọng Tâm & Ngữ Cảnh (\(result.vocabularies.count))")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 8)], spacing: 8) {
                        ForEach(result.vocabularies.indices, id: \.self) { idx in
                            let vocab = result.vocabularies[idx]
                            HStack(alignment: .top, spacing: 8) {
                                Button(action: {
                                    analysisResult?.vocabularies[idx].isSelected.toggle()
                                }) {
                                    Image(systemName: vocab.isSelected ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(vocab.isSelected ? .orange : .secondary.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                                .padding(.top, 2)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Text(vocab.word)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.primary)
                                        
                                        Text(vocab.partOfSpeech)
                                            .font(.system(size: 9.5))
                                            .foregroundColor(.orange)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.orange.opacity(0.1))
                                            .cornerRadius(3)
                                        
                                        Spacer()
                                    }
                                    
                                    Text(vocab.vietnameseMeaning)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.primary.opacity(0.9))
                                    
                                    Text("\"\(vocab.contextSentence)\"")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .italic()
                                        .lineLimit(2)
                                }
                            }
                            .padding(9)
                            .background(Color.primary.opacity(0.03))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(vocab.isSelected ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.primary.opacity(0.04))
    }
}
