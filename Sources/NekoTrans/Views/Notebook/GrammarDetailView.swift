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
            // Header Action Bar
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "function")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.blue)
                    Text("CẤU TRÚC & QUY TẮC NGỮ PHÁP")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    QuickAIWindowController.shared.showAI(
                        prompt: AIPromptBuilder.grammarFormulaPrompt(for: item.cleanTitle, context: item.exampleEn),
                        targetWordId: item.id,
                        targetWordTitle: item.cleanTitle
                    )
                }) {
                    Label(parsed?.isEmpty == false ? "Làm mới phân tích" : "Phân tích cú pháp", systemImage: parsed?.isEmpty == false ? "arrow.triangle.2.circlepath" : "wand.and.stars")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderless)
            }
            .padding(.top, 2)
            
            if let p = parsed, !p.isEmpty {
                // 1. Công thức tổng quát (Formula Box)
                if let f = formula, !f.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("CÔNG THỨC TỔNG QUÁT", systemImage: "function")
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
                
                // 2. Cách dùng & Dấu hiệu nhận biết
                if !p.meanings.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("CÁCH DÙNG & DẤU HIỆU", systemImage: "text.book.closed")
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
                
                // 3. Ví dụ minh họa
                if !p.examples.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("VÍ DỤ MINH HỌA (3 THỂ)", systemImage: "quote.bubble")
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
                                                .foregroundColor(.secondary)
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
                
                // 4. Lỗi sai hay gặp & Lưu ý
                if !p.commonMistakes.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("LỖI SAI HAY GẶP & LƯU Ý", systemImage: "exclamationmark.triangle")
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
                
                // 5. Mẹo ghi nhớ
                if let mnemonic = p.mnemonic, !mnemonic.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("MẸO GHI NHỚ", systemImage: "lightbulb")
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
                // Fallback if no analysis yet but formula exists
                if let f = formula, !f.isEmpty {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Label("CÔNG THỨC TỔNG QUÁT", systemImage: "function")
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
                
                // Native macOS Clean Callout
                GroupBox {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Chưa có dữ liệu phân tích chi tiết")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                            Text("Nhấn phân tích để tạo công thức tổng quát, ví dụ và lưu ý sử dụng.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            QuickAIWindowController.shared.showAI(
                                prompt: AIPromptBuilder.grammarFormulaPrompt(for: item.cleanTitle, context: item.exampleEn),
                                targetWordId: item.id,
                                targetWordTitle: item.cleanTitle
                            )
                        }) {
                            Label("Phân tích", systemImage: "wand.and.stars")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                    .padding(4)
                }
            }
        }
    }
}
