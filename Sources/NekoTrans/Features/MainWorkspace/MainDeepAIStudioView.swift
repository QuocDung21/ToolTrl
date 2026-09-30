import SwiftUI
import AppKit

public struct MainDeepAIStudioView: View {
    @ObservedObject var analysisService = TextAnalysisService.shared
    @State private var inputText: String = ""
    @State private var analysisResult: TextAnalysisResult? = nil
    @State private var grammars: [ExtractedGrammarFormula] = []
    @State private var vocabularies: [ExtractedVocabulary] = []
    @State private var savedCount: Int? = nil
    @State private var showSavedToast: Bool = false
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 1. Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 22))
                            .foregroundColor(.purple)
                        
                        Text("AI Phân Tích & Bóc Tách Văn Bản")
                            .font(.system(size: 22, weight: .bold))
                    }
                    
                    Text("Dán bài báo, đoạn văn hoặc tài liệu tiếng Anh để bóc tách cấu trúc ngữ pháp nâng cao và từ vựng cốt lõi vào Sổ tay.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // 2. Input Box
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("ĐOẠN VĂN CẦN PHÂN TÍCH")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        let words = inputText.split { $0.isWhitespace || $0.isNewline }.count
                        Text("\(words) từ")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $inputText)
                            .font(.system(size: 14.5))
                            .lineSpacing(5)
                            .frame(minHeight: 140)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
                        
                        if inputText.isEmpty {
                            Text("Dán đoạn văn tiếng Anh vào đây (Ví dụ: If I had known earlier, I would have taken into account his proposal...)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary.opacity(0.55))
                                .padding(16)
                                .allowsHitTesting(false)
                        }
                    }
                    
                    HStack {
                        Button(action: {
                            if let clip = NSPasteboard.general.string(forType: .string), !clip.isEmpty {
                                inputText = clip
                            }
                        }) {
                            Label("Dán từ Clipboard", systemImage: "doc.on.clipboard")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.borderless)
                        
                        if !inputText.isEmpty {
                            Button(action: {
                                inputText = ""
                                analysisResult = nil
                                grammars = []
                                vocabularies = []
                                savedCount = nil
                            }) {
                                Label("Xóa", systemImage: "trash")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            runAnalysis()
                        }) {
                            if analysisService.isAnalyzing {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Đang bóc tách...")
                            } else {
                                Label("Bắt đầu phân tích AI", systemImage: "sparkles")
                                    .font(.system(size: 12.5, weight: .semibold))
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || analysisService.isAnalyzing)
                    }
                }
                .padding(16)
                .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow, cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1)
                )
                
                // 3. Results Presentation
                if analysisResult != nil {
                    VStack(alignment: .leading, spacing: 18) {
                        // Action & Summary Bar
                        HStack {
                            Text("KẾT QUẢ BÓC TÁCH (\(grammars.count) Ngữ pháp • \(vocabularies.count) Từ vựng)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: {
                                saveSelectedItems()
                            }) {
                                Label("Lưu các mục đã chọn vào Sổ tay", systemImage: "square.and.arrow.down.fill")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                        }
                        
                        if showSavedToast, let count = savedCount {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Đã lưu thành công \(count) mục vào Sổ tay từ vựng!")
                                    .font(.system(size: 12.5, weight: .medium))
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(8)
                        }
                        
                        // Grammar Points
                        if !grammars.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Cấu trúc ngữ pháp nhận diện được", systemImage: "function")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.indigo)
                                
                                ForEach(grammars.indices, id: \.self) { idx in
                                    grammarRow(grammar: $grammars[idx])
                                }
                            }
                        }
                        
                        // Vocabularies
                        if !vocabularies.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Từ vựng trọng tâm", systemImage: "character.book.closed.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.blue)
                                
                                ForEach(vocabularies.indices, id: \.self) { idx in
                                    vocabRow(vocab: $vocabularies[idx])
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(VisualEffectBackground(material: .contentBackground, blendingMode: .behindWindow))
    }
    
    private func grammarRow(grammar: Binding<ExtractedGrammarFormula>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: grammar.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(grammar.wrappedValue.title)
                        .font(.system(size: 13.5, weight: .bold))
                    
                    Spacer()
                    
                    Text(grammar.wrappedValue.formula)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Text(grammar.wrappedValue.meaningVi)
                    .font(.system(size: 12.5))
                    .foregroundColor(.secondary)
                
                if !grammar.wrappedValue.exampleSentence.isEmpty {
                    Text("\"\(grammar.wrappedValue.exampleSentence)\"")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, y: 1)
    }
    
    private func vocabRow(vocab: Binding<ExtractedVocabulary>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: vocab.isSelected)
                .toggleStyle(.checkbox)
                .labelsHidden()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(vocab.wrappedValue.word)
                        .font(.system(size: 14, weight: .bold))
                    
                    if let phonetic = vocab.wrappedValue.phonetic, !phonetic.isEmpty {
                        Text(phonetic)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(vocab.wrappedValue.posCategory.rawValue)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(vocab.wrappedValue.posCategory.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(vocab.wrappedValue.posCategory.color.opacity(0.12))
                        .cornerRadius(4)
                    
                    Text(vocab.wrappedValue.importance.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(vocab.wrappedValue.importance.badgeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(vocab.wrappedValue.importance.badgeColor.opacity(0.12))
                        .cornerRadius(4)
                    
                    Spacer()
                }
                
                Text(vocab.wrappedValue.vietnameseMeaning)
                    .font(.system(size: 13))
                
                if !vocab.wrappedValue.contextSentence.isEmpty {
                    Text("\"\(vocab.wrappedValue.contextSentence)\"")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 4, y: 1)
    }
    
    private func runAnalysis() {
        Task {
            let res = await analysisService.analyzeText(inputText)
            await MainActor.run {
                self.analysisResult = res
                self.grammars = res.grammars
                self.vocabularies = res.vocabularies
                self.savedCount = nil
                self.showSavedToast = false
            }
        }
    }
    
    private func saveSelectedItems() {
        guard let original = analysisResult?.originalParagraph else { return }
        let currentResult = TextAnalysisResult(
            originalParagraph: original,
            vocabularies: vocabularies,
            grammars: grammars
        )
        let count = analysisService.saveSelectedToNotebook(result: currentResult)
        self.savedCount = count
        self.showSavedToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.showSavedToast = false
        }
    }
}
