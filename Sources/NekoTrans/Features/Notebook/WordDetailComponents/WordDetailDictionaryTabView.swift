import SwiftUI

public struct WordDetailDictionaryTabView: View {
    public let item: SavedWordItem
    public let richDictionaryEntry: RichWordEntry?
    public let isLoadingDictionary: Bool
    @ObservedObject var speechService = SpeechService.shared
    
    public init(
        item: SavedWordItem,
        richDictionaryEntry: RichWordEntry?,
        isLoadingDictionary: Bool
    ) {
        self.item = item
        self.richDictionaryEntry = richDictionaryEntry
        self.isLoadingDictionary = isLoadingDictionary
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Saved Meaning Card
            cardBox {
                VStack(alignment: .leading, spacing: 6) {
                    Label(item.isGrammarFormula ? "Ý nghĩa & Cách dùng" : "Nghĩa tiếng Việt đã lưu", systemImage: "text.alignleft")
                        .font(.appSubcaptionBold)
                        .foregroundColor(.secondary)
                    
                    Text(item.translation)
                        .font(.appHeadlineBold)
                        .foregroundColor(.primary)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // 2. Saved Context Example
            if let exEn = item.exampleEn, !exEn.isEmpty {
                cardBox {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Ví dụ ngữ cảnh đã lưu", systemImage: "quote.opening")
                                .font(.appSubcaptionBold)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button(action: {
                                speechService.speak(text: exEn, languageCode: "en-US", speakerID: "ex_\(item.id.uuidString)")
                            }) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                        
                        Text("\"\(exEn)\"")
                            .font(.appExample)
                            .foregroundColor(.primary)
                            .italic()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            
            // 3. Offline Dictionary API Definitions
            if isLoadingDictionary {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Đang tải từ điển chi tiết...")
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if let entry = richDictionaryEntry, !entry.meanings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("TỪ ĐIỂN TỔNG HỢP THEO TỪ LOẠI", systemImage: "books.vertical.fill")
                            .font(.appCaptionBold)
                            .foregroundColor(AppColors.accent)
                        Spacer()
                    }
                    .padding(.top, 4)
                    
                    ForEach(entry.meanings) { group in
                        cardBox {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(group.partOfSpeechDisplay)
                                        .font(.appSubcaptionBold)
                                        .foregroundColor(AppColors.accent)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppColors.accentSubtle)
                                        .cornerRadius(4)
                                    Spacer()
                                }
                                
                                ForEach(Array(group.definitions.prefix(4))) { def in
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("• \(def.definitionEn)")
                                            .font(.appBody)
                                            .foregroundColor(.primary)
                                        
                                        if let ex = def.exampleEn, !ex.isEmpty {
                                            HStack(alignment: .top, spacing: 4) {
                                                Text("Ví dụ:")
                                                    .font(.appSubcaptionBold)
                                                    .foregroundColor(.secondary)
                                                Text("\"\(ex)\"")
                                                    .font(.appExample)
                                                    .foregroundColor(.secondary)
                                                    .italic()
                                                
                                                Button(action: {
                                                    speechService.speak(text: ex, languageCode: "en-US", speakerID: "def_\(def.id.uuidString)")
                                                }) {
                                                    Image(systemName: "speaker.wave.2")
                                                        .font(.system(size: 9))
                                                        .foregroundColor(AppColors.accent)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(.leading, 8)
                                        }
                                    }
                                    .padding(.vertical, 1.5)
                                }
                                
                                if !group.synonyms.isEmpty {
                                    HStack(alignment: .top, spacing: 4) {
                                        Text("Đồng nghĩa:")
                                            .font(.appSubcaptionBold)
                                            .foregroundColor(AppColors.success)
                                        Text(group.synonyms.prefix(5).joined(separator: ", "))
                                            .font(.appCaption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
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
