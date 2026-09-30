import SwiftUI

public struct WordDetailDocumentView: View {
    public let item: SavedWordItem
    private let dictService = SmartDictionaryService.shared
    
    @State private var selectedDetailTab: WordDetailTab = .original
    @State private var richDictionaryEntry: RichWordEntry? = nil
    @State private var isLoadingDictionary: Bool = false
    
    public init(item: SavedWordItem) {
        self.item = item
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            WordDetailHeaderView(item: item, richDictionaryEntry: richDictionaryEntry)
            
            Divider()
                .opacity(0.4)
            
            if item.isGrammarFormula {
                GrammarDetailView(item: item)
            } else {
                segmentedDetailContentSection
            }
        }
        .onAppear {
            loadDictionaryIfNeeded()
        }
        .onChange(of: item.id) { _, _ in
            loadDictionaryIfNeeded()
        }
        .onChange(of: item.word) { _, _ in
            loadDictionaryIfNeeded()
        }
    }
    
    private func loadDictionaryIfNeeded() {
        guard !item.isGrammarFormula else { return }
        let clean = item.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        
        isLoadingDictionary = true
        richDictionaryEntry = nil
        Task {
            let entry = await dictService.fetchRichEntry(for: clean)
            await MainActor.run {
                self.richDictionaryEntry = entry
                self.isLoadingDictionary = false
            }
        }
    }
    
    // MARK: - Separated Content Sections (Original vs AI)
    @ViewBuilder
    private var segmentedDetailContentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Segmented Switcher
            HStack {
                Picker("", selection: $selectedDetailTab) {
                    Text("Từ điển & Ghi chú").tag(WordDetailTab.original)
                    Text("Phân tích chi tiết").tag(WordDetailTab.ai)
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                
                Spacer()
                
                if selectedDetailTab == .ai, let analysis = item.aiDetailedAnalysis, !analysis.isEmpty {
                    Button(action: {
                        QuickAIWindowController.shared.showAI(
                            prompt: SavedWordItem.buildStructuredWordPrompt(for: item.cleanTitle),
                            targetWordId: item.id,
                            targetWordTitle: item.cleanTitle
                        )
                    }) {
                        Label("Làm mới", systemImage: "arrow.triangle.2.circlepath")
                            .font(.appCaptionMedium)
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            if selectedDetailTab == .original {
                WordDetailDictionaryTabView(
                    item: item,
                    richDictionaryEntry: richDictionaryEntry,
                    isLoadingDictionary: isLoadingDictionary
                )
            } else {
                WordDetailAITabView(item: item)
            }
        }
    }
}
