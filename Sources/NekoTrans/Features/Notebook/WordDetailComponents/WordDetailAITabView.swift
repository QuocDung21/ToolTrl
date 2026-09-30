import SwiftUI

public struct WordDetailAITabView: View {
    public let item: SavedWordItem
    @State private var formulaCopied: Bool = false
    @ObservedObject var speechService = SpeechService.shared
    
    public init(item: SavedWordItem) {
        self.item = item
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let deepAnalysis = item.aiDetailedAnalysis, !deepAnalysis.isEmpty {
                let parsed = AIAnalysisParser.parse(deepAnalysis)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Card 0: Formula
                    if let formula = parsed.formula, !formula.isEmpty {
                        cardBox {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label("CÔNG THỨC TỔNG QUÁT", systemImage: "function")
                                        .font(.appSubcaptionBold)
                                        .foregroundColor(AppColors.grammar)
                                    Spacer()
                                    Button(action: {
                                        let pb = NSPasteboard.general
                                        pb.clearContents()
                                        pb.setString(formula, forType: .string)
                                        withAnimation { formulaCopied = true }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { formulaCopied = false }
                                    }) {
                                        Label(formulaCopied ? "Đã chép" : "Sao chép", systemImage: formulaCopied ? "checkmark" : "doc.on.doc")
                                            .font(.appCaption)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                
                                Text(formula)
                                    .font(.appFormula)
                                    .foregroundColor(AppColors.grammar)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Card 1: Meanings
                    if !parsed.meanings.isEmpty {
                        cardBox {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("ĐỊNH NGHĨA & TẦNG NGHĨA", systemImage: "text.book.closed")
                                    .font(.appSubcaptionBold)
                                    .foregroundColor(.secondary)
                                
                                ForEach(parsed.meanings, id: \.self) { m in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("•")
                                            .font(.appBodyBold)
                                            .foregroundColor(.secondary)
                                        Text(m)
                                            .font(.appBody)
                                            .foregroundColor(.primary)
                                            .lineSpacing(2)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Card 2: Word Family
                    if !parsed.wordFamily.isEmpty {
                        cardBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("HỌ TỪ (WORD FAMILY)", systemImage: "text.word.spacing")
                                    .font(.appSubcaptionBold)
                                    .foregroundColor(.secondary)
                                
                                ForEach(parsed.wordFamily) { wf in
                                    HStack(spacing: 8) {
                                        Text(wf.pos)
                                            .font(.appSubcaptionBold)
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(AppColors.tagBackground)
                                            .cornerRadius(4)
                                        
                                        Text(wf.words)
                                            .font(.appBodyBold)
                                            .foregroundColor(AppColors.accent)
                                        
                                        if !wf.meaning.isEmpty {
                                            Text("- \(wf.meaning)")
                                                .font(.appBody)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            speechService.speak(text: wf.words, languageCode: "en-US", speakerID: "wf_\(wf.id.uuidString)")
                                        }) {
                                            Image(systemName: "speaker.wave.2")
                                                .font(.system(size: 9))
                                                .foregroundColor(AppColors.accent)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Card 3: Collocations & Idioms
                    if !parsed.collocations.isEmpty {
                        cardBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("CỤM TỪ & THÀNH NGỮ HAY DÙNG (COLLOCATIONS)", systemImage: "link")
                                    .font(.appSubcaptionBold)
                                    .foregroundColor(.secondary)
                                
                                ForEach(parsed.collocations) { col in
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("• \(col.phrase)")
                                                .font(.appBodyBold)
                                                .foregroundColor(AppColors.accent)
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                speechService.speak(text: col.phrase, languageCode: "en-US", speakerID: "col_\(col.id.uuidString)")
                                            }) {
                                                Image(systemName: "speaker.wave.2")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(AppColors.accent)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        if !col.meaning.isEmpty {
                                            Text(col.meaning)
                                                .font(.appCaption)
                                                .foregroundColor(.secondary)
                                                .padding(.leading, 12)
                                        }
                                    }
                                    .padding(.vertical, 1.5)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Card 4: Nuances & Differences
                    if !parsed.nuances.isEmpty {
                        cardBox {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("SẮC THÁI NGHĨA & PHÂN BIỆT", systemImage: "arrow.left.and.right.circle")
                                    .font(.appSubcaptionBold)
                                    .foregroundColor(.secondary)
                                
                                ForEach(parsed.nuances, id: \.self) { n in
                                    Text(n)
                                        .font(.appBody)
                                        .foregroundColor(.primary)
                                        .lineSpacing(2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Card 5: Examples
                    if !parsed.examples.isEmpty {
                        cardBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("CÂU VÍ DỤ MINH HỌA", systemImage: "quote.bubble")
                                    .font(.appSubcaptionBold)
                                    .foregroundColor(.secondary)
                                
                                ForEach(parsed.examples, id: \.en) { ex in
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(alignment: .top) {
                                            Text("• \(ex.en)")
                                                .font(.appExample)
                                                .foregroundColor(.primary)
                                                .italic()
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                speechService.speak(text: ex.en, languageCode: "en-US", speakerID: "aiex_\(UUID().uuidString)")
                                            }) {
                                                Image(systemName: "speaker.wave.2")
                                                    .font(.system(size: 9))
                                                    .foregroundColor(AppColors.accent)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        
                                        if !ex.vi.isEmpty {
                                            Text(ex.vi)
                                                .font(.appCaption)
                                                .foregroundColor(.secondary)
                                                .padding(.leading, 12)
                                        }
                                    }
                                    .padding(.vertical, 1.5)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    
                    // Card 6: Memory Mnemonic
                    if let mn = parsed.mnemonic, !mn.isEmpty {
                        cardBox {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("MẸO GHI NHỚ THẦN TỐC", systemImage: "lightbulb.fill")
                                    .font(.appSubcaptionBold)
                                    .foregroundColor(AppColors.warning)
                                
                                Text(mn)
                                    .font(.appBody)
                                    .foregroundColor(.primary)
                                    .lineSpacing(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            } else {
                // Empty AI Callout
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 26))
                        .foregroundColor(AppColors.accent)
                    
                    Text("Chưa có bản phân tích AI cho từ này")
                        .font(.appHeadlineBold)
                    
                    Text("Bấm nút bên dưới để yêu cầu Trợ lý AI phân tích họ từ, thành ngữ, sắc thái ngữ nghĩa và câu ví dụ nâng cao.")
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Button(action: {
                        QuickAIWindowController.shared.showAI(
                            prompt: SavedWordItem.buildStructuredWordPrompt(for: item.cleanTitle),
                            targetWordId: item.id,
                            targetWordTitle: item.cleanTitle
                        )
                    }) {
                        Label("Yêu cầu AI phân tích ngay", systemImage: "brain.head.profile")
                            .font(.appBodyBold)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.accent)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(AppColors.cardBackground)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppColors.cardBorder, lineWidth: 0.8)
                )
            }
        }
    }
    
    private func cardBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(12)
            .background(AppColors.cardBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.cardBorder, lineWidth: 0.8)
            )
    }
}
