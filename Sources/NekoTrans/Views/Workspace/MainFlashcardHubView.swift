import SwiftUI

public struct MainFlashcardHubView: View {
    @ObservedObject var vocabService = VocabularyService.shared
    @State private var isStudying: Bool = false
    @State private var selectedDeckTitle: String = "Tất cả từ vựng"
    @State private var studyItems: [SavedWordItem] = []
    
    public init() {}
    
    private var allItems: [SavedWordItem] {
        vocabService.savedWords
    }
    
    private var needReviewItems: [SavedWordItem] {
        allItems.filter { !$0.isMastered }
    }
    
    private var favoriteItems: [SavedWordItem] {
        allItems.filter { $0.isFavorite }
    }
    
    private var grammarItems: [SavedWordItem] {
        allItems.filter { $0.isGrammarFormula }
    }
    
    public var body: some View {
        Group {
            if isStudying {
                FlashcardStudyView(items: studyItems, isPresented: $isStudying)
            } else {
                hubDashboardView
            }
        }
        .background(VisualEffectBackground(material: .contentBackground, blendingMode: .behindWindow))
    }
    
    private var hubDashboardView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // 1. Header Banner
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)
                        
                        Text("Trung Tâm Ôn Tập Flashcards")
                            .font(.system(size: 22, weight: .bold))
                    }
                    
                    Text("Luyện tập ghi nhớ từ vựng và công thức ngữ pháp bằng thuật toán lặp lại ngắt quãng (Spaced Repetition).")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                // 2. Metrics Bar
                HStack(spacing: 14) {
                    metricBadge(title: "Tổng số thẻ", value: "\(allItems.count)", icon: "square.stack.fill", color: .blue)
                    metricBadge(title: "Cần ôn tập", value: "\(needReviewItems.count)", icon: "clock.arrow.circlepath", color: .orange)
                    metricBadge(title: "Đã ghi nhớ", value: "\(allItems.filter(\.isMastered).count)", icon: "checkmark.seal.fill", color: .green)
                    metricBadge(title: "Yêu thích", value: "\(favoriteItems.count)", icon: "star.fill", color: .yellow)
                }
                
                Divider()
                
                // 3. Decks Grid
                Text("CHỌN BỘ THẺ ĐỂ BẮT ĐẦU ÔN TẬP")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                    deckCard(
                        title: "Tất cả từ vựng",
                        subtitle: "Bao gồm tất cả các từ và ngữ pháp đã lưu trong Sổ tay.",
                        icon: "books.vertical.fill",
                        color: .blue,
                        count: allItems.count,
                        items: allItems
                    )
                    
                    deckCard(
                        title: "Cần ôn tập ngay",
                        subtitle: "Các từ vựng đang học và chưa đạt trạng thái ghi nhớ hoàn toàn.",
                        icon: "flame.fill",
                        color: .orange,
                        count: needReviewItems.count,
                        items: needReviewItems
                    )
                    
                    deckCard(
                        title: "Mục Yêu Thích ⭐",
                        subtitle: "Danh sách những từ vựng quan trọng bạn đã đánh dấu sao.",
                        icon: "star.fill",
                        color: .yellow,
                        count: favoriteItems.count,
                        items: favoriteItems
                    )
                    
                    deckCard(
                        title: "Công Thức Ngữ Pháp 📐",
                        subtitle: "Ôn tập các mẫu câu và cấu trúc ngữ pháp quan trọng.",
                        icon: "function",
                        color: .indigo,
                        count: grammarItems.count,
                        items: grammarItems
                    )
                }
            }
            .padding(24)
        }
    }
    
    private func metricBadge(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.12))
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(title)
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
    }
    
    private func deckCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        count: Int,
        items: [SavedWordItem]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                
                Spacer()
                
                Text("\(count) thẻ")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(color.opacity(0.12))
                    .cornerRadius(6)
            }
            
            Text(subtitle)
                .font(.system(size: 12.5))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .frame(height: 34, alignment: .topLeading)
            
            HStack {
                Spacer()
                
                Button(action: {
                    studyItems = items.shuffled()
                    selectedDeckTitle = title
                    isStudying = true
                }) {
                    HStack(spacing: 6) {
                        Text("Bắt đầu học")
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(color)
                .disabled(count == 0)
            }
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
    }
}
