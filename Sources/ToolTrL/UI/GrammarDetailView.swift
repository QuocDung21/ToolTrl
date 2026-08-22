import SwiftUI
import AppKit

// MARK: - Modular Dedicated Grammar Detail View
public struct GrammarDetailView: View {
    public let item: SavedWordItem
    @ObservedObject var speechService = SpeechService.shared
    @State private var formulaCopied: Bool = false
    
    public init(item: SavedWordItem) {
        self.item = item
    }
    
    public var body: some View {
        let parsed = item.aiDetailedAnalysis != nil ? AIAnalysisParser.parse(item.aiDetailedAnalysis!) : nil
        let formula = (parsed?.formula?.isEmpty == false ? parsed?.formula : nil) ?? (item.phonetic?.isEmpty == false ? item.phonetic : nil)
        
        VStack(alignment: .leading, spacing: 14) {
            // Action Bar for Grammar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "function")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                    Text("CÔNG THỨC & QUY TẮC NGỮ PHÁP CHUẨN")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(action: {
                    QuickAIWindowController.shared.showAI(
                        prompt: AIPromptBuilder.grammarFormulaPrompt(for: item.cleanTitle, context: item.exampleEn),
                        targetWordId: item.id,
                        targetWordTitle: item.cleanTitle
                    )
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text(parsed?.isEmpty == false ? "AI Phân tích lại" : "Dùng AI phân tích")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
            
            if let p = parsed, !p.isEmpty {
                // 1. Khung Công Thức Chuẩn (Formula Box)
                if let f = formula, !f.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("CÔNG THỨC CHUẨN (FORMULA)", systemImage: "function")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.blue)
                                Spacer()
                                Button(action: {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.setString(f, forType: .string)
                                    withAnimation { formulaCopied = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { formulaCopied = false }
                                }) {
                                    Label(formulaCopied ? "Đã chép" : "Sao chép", systemImage: formulaCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 10.5))
                                }
                                .buttonStyle(.borderless)
                            }
                            
                            Text(f)
                                .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)
                                .lineSpacing(3)
                                .textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }
                }
                
                // 2. Ý Nghĩa, Cách Dùng & Dấu Hiệu Nhận Biết
                if !p.meanings.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Ý NGHĨA, CÁCH DÙNG & DẤU HIỆU", systemImage: "text.book.closed")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            ForEach(p.meanings, id: \.self) { m in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Text(m)
                                        .font(.system(size: 12.5))
                                        .foregroundColor(.primary)
                                        .lineSpacing(2)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }
                }
                
                // 3. Ví Dụ Minh Họa 3 Thể (+, -, ?)
                if !p.examples.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("VÍ DỤ MINH HỌA (3 THỂ KHẲNG ĐỊNH / PHỦ ĐỊNH / NGHI VẤN)", systemImage: "quote.bubble")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            ForEach(Array(p.examples.enumerated()), id: \.offset) { _, ex in
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(alignment: .top) {
                                        Text("\"\(ex.en)\"")
                                            .font(.system(size: 13, design: .serif))
                                            .italic()
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            speechService.speak(text: ex.en, languageCode: "en-US", speakerID: "gr_ex_\(item.id.uuidString)")
                                        }) {
                                            Image(systemName: "speaker.wave.2")
                                                .font(.system(size: 10))
                                                .foregroundColor(.blue)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    if !ex.vi.isEmpty {
                                        Text("➔ \(ex.vi)")
                                            .font(.system(size: 11.5))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }
                }
                
                // 4. Lỗi Sai Thường Gặp & Bẫy Đề Thi
                if !p.commonMistakes.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("LỖI SAI HAY GẶP & BẪY ĐỀ THI (TOEIC/IELTS)", systemImage: "exclamationmark.triangle")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.orange)
                            
                            ForEach(p.commonMistakes, id: \.self) { mistake in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("•")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.orange)
                                    Text(mistake)
                                        .font(.system(size: 12.5))
                                        .foregroundColor(.primary)
                                        .lineSpacing(2)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }
                }
                
                // 5. Mẹo Ghi Nhớ Thần Tốc
                if let mnemonic = p.mnemonic, !mnemonic.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("MẸO GHI NHỚ THẦN TỐC", systemImage: "lightbulb")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            
                            Text(mnemonic)
                                .font(.system(size: 12.5))
                                .foregroundColor(.primary)
                                .lineSpacing(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }
                }
            } else {
                // Fallback if no AI analysis yet but formula exists
                if let f = formula, !f.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("CÔNG THỨC CHUẨN (FORMULA)", systemImage: "function")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.blue)
                                Spacer()
                                Button(action: {
                                    let pb = NSPasteboard.general
                                    pb.clearContents()
                                    pb.setString(f, forType: .string)
                                    withAnimation { formulaCopied = true }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { formulaCopied = false }
                                }) {
                                    Label(formulaCopied ? "Đã chép" : "Sao chép", systemImage: formulaCopied ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 10.5))
                                }
                                .buttonStyle(.borderless)
                            }
                            
                            Text(f)
                                .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                                .foregroundColor(.blue)
                                .lineSpacing(3)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }
                }
                
                // Callout to analyze with AI
                Button(action: {
                    QuickAIWindowController.shared.showAI(
                        prompt: AIPromptBuilder.grammarFormulaPrompt(for: item.cleanTitle, context: item.exampleEn),
                        targetWordId: item.id,
                        targetWordTitle: item.cleanTitle
                    )
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "function")
                            .font(.system(size: 22))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chưa có phân tích công thức & quy tắc ngữ pháp đầy đủ")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Bấm để AI tự động tạo công thức toán học, ví dụ 3 thể và bẫy đề thi")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Phân tích ngay")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4.5)
                        .background(Color.purple)
                        .cornerRadius(6)
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.18), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
