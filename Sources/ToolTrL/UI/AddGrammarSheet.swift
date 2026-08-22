import SwiftUI
import AppKit

public struct AddGrammarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vocabService = VocabularyService.shared
    
    @State private var grammarTitle: String = ""
    @State private var contextExample: String = ""
    @State private var userNotes: String = ""
    @State private var selectedProvider: AIProvider = .chatgpt
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "function")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.blue)
                    Text("Thêm Cấu Trúc Ngữ Pháp Mới")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.primary.opacity(0.03))
            
            Divider()
            
            // Form Body
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Tip banner
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14))
                            .foregroundColor(.purple)
                        
                        Text("Nhập tên cấu trúc hoặc ghi chú thô bạn muốn học. AI sẽ tự động ép câu lệnh theo đúng khuôn mẫu chuẩn (Công thức toán học, 3 thể ví dụ, bẫy thi TOEIC/IELTS, mẹo nhớ) và lưu vào Sổ Tay.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                    .padding(10)
                    .background(Color.purple.opacity(0.06))
                    .cornerRadius(8)
                    
                    // Field 1: Tên cấu trúc
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tên Cấu Trúc / Quy Tắc Ngữ Pháp:")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.primary)
                        
                        TextField("Ví dụ: Câu điều kiện loại 3, Wish quá khứ, No sooner... than, Had better...", text: $grammarTitle)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                    }
                    
                    // Field 2: Ví dụ ngữ cảnh (Tùy chọn)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Câu Ví Dụ Ngữ Cảnh (Tùy chọn):")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.primary)
                        
                        TextField("Ví dụ: If I had studied harder, I would have passed the exam.", text: $contextExample)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5))
                    }
                    
                    // Field 3: Ghi chú của bạn (Tùy chọn)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ghi Chú Hoặc Yêu Cầu Riêng (Tùy chọn):")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.primary)
                        
                        TextField("Ví dụ: Nhấn mạnh bẫy đảo ngữ trong đề thi TOEIC...", text: $userNotes)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12.5))
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer Buttons
            HStack {
                Button("Hủy") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(action: {
                    createGrammarAndOpenAI()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Ép AI Sinh Công Thức & Lưu")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(grammarTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 480, height: 420)
    }
    
    private func createGrammarAndOpenAI() {
        let cleanTitle = grammarTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        
        let formattedWord = cleanTitle.contains("📐") ? cleanTitle : "📐 \(cleanTitle)"
        let exEn = contextExample.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : contextExample.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Check if already exists, else create new item in VocabularyService
        let itemId: UUID
        if let existing = vocabService.savedWords.first(where: { $0.cleanTitle.lowercased() == cleanTitle.lowercased() }) {
            itemId = existing.id
        } else {
            let newItem = SavedWordItem(
                word: formattedWord,
                phonetic: nil,
                translation: note.isEmpty ? "Cấu trúc ngữ pháp: \(cleanTitle)" : note,
                exampleEn: exEn,
                exampleVi: nil
            )
            vocabService.savedWords.insert(newItem, at: 0)
            vocabService.saveWords()
            itemId = newItem.id
        }
        
        // 2. Build strict prompt for ChatGPT / Gemini
        let prompt = SavedWordItem.buildStrictEnforcedGrammarPrompt(
            title: cleanTitle,
            context: exEn,
            customNote: note.isEmpty ? nil : note
        )
        
        dismiss()
        
        // 3. Open Quick AI Assistant
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            QuickAIWindowController.shared.showAI(
                prompt: prompt,
                targetWordId: itemId,
                targetWordTitle: cleanTitle
            )
        }
    }
}
