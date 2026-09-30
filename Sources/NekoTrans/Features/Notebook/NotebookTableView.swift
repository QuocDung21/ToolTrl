import SwiftUI

public struct NotebookTableView: View {
    let items: [SavedWordItem]
    @Binding var selectedItemID: UUID?
    @Binding var sortOption: NotebookSortOption
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var speechService = SpeechService.shared
    @State private var editingItem: SavedWordItem? = nil
    
    public init(
        items: [SavedWordItem],
        selectedItemID: Binding<UUID?>,
        sortOption: Binding<NotebookSortOption>
    ) {
        self.items = items
        self._selectedItemID = selectedItemID
        self._sortOption = sortOption
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Table Header Status Bar
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Image(systemName: "tablecells")
                        .foregroundColor(.blue)
                    Text("\(items.count) từ vựng / công thức")
                        .font(.system(size: 12, weight: .bold))
                }
                
                Text("• Bấm phím Space để xem từ điển chi tiết")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.8))
                
                Spacer()
                
                sortDropdownMenu
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.02))
            
            Divider()
            
            if items.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "books.vertical")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.3))
                    Text("Không có mục nào trong chế độ bảng")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                Table(items, selection: $selectedItemID) {
                    // 1. Star / Favorite Column
                    TableColumn("⭐") { item in
                        Button(action: {
                            vocabService.toggleFavorite(id: item.id)
                        }) {
                            Image(systemName: item.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 11))
                                .foregroundColor(item.isFavorite ? .yellow : .secondary.opacity(0.4))
                        }
                        .buttonStyle(.plain)
                        .help("Yêu thích")
                    }
                    .width(min: 28, ideal: 32, max: 36)
                    
                    // 2. Word / Title Column
                    TableColumn("Từ vựng / Cấu trúc") { item in
                        HStack(spacing: 6) {
                            if item.isGrammarFormula {
                                Text("📐")
                                    .font(.system(size: 9))
                            }
                            
                            Text(item.cleanTitle)
                                .font(.system(size: 12.5, weight: .bold, design: item.isGrammarFormula ? .monospaced : .default))
                                .foregroundColor(item.isGrammarFormula ? .blue : .primary)
                            
                            if let ph = item.phonetic, !ph.isEmpty, !item.isGrammarFormula {
                                Text(ph)
                                    .font(.system(size: 10.5, design: .serif))
                                    .foregroundColor(.orange)
                            }
                            
                            Button(action: {
                                speechService.speak(text: item.word, languageCode: "en-US", speakerID: "table_\(item.id.uuidString)")
                            }) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Phát âm")
                        }
                    }
                    .width(min: 160, ideal: 200, max: 280)
                    
                    // 3. Meaning / Translation Column
                    TableColumn("Nghĩa tiếng Việt") { item in
                        Text(item.translation)
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.9))
                            .lineLimit(1)
                    }
                    .width(min: 180, ideal: 240)
                    
                    // 4. Thematic Genre / Topic
                    TableColumn("Chủ đề (AI)") { item in
                        Text(item.aiThematicGenre.rawValue)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(4)
                    }
                    .width(min: 130, ideal: 150, max: 180)
                    
                    // 5. Part of Speech Column
                    TableColumn("Từ loại") { item in
                        Text(item.aiPartOfSpeech.rawValue)
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                    }
                    .width(min: 110, ideal: 130, max: 160)
                    
                    // 6. Example Sentence Column
                    TableColumn("Ví dụ") { item in
                        if let ex = item.exampleEn, !ex.isEmpty {
                            Text("\"\(ex)\"")
                                .font(.system(size: 11, design: .serif))
                                .foregroundColor(.secondary)
                                .italic()
                                .lineLimit(1)
                        } else {
                            Text("—")
                                .foregroundColor(.secondary.opacity(0.4))
                        }
                    }
                    .width(min: 180, ideal: 260)
                    
                    // 7. Status (Mastered) Column
                    TableColumn("Trạng thái") { item in
                        Button(action: {
                            vocabService.toggleMastered(id: item.id)
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: item.isMastered ? "checkmark.seal.fill" : "circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(item.isMastered ? .green : .secondary.opacity(0.4))
                                Text(item.isMastered ? "Đã thuộc" : "Đang học")
                                    .font(.system(size: 10.5, weight: item.isMastered ? .semibold : .regular))
                                    .foregroundColor(item.isMastered ? .green : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .width(min: 85, ideal: 95, max: 110)
                    
                    // 8. Action Columns (Edit & Delete)
                    TableColumn("Thao tác") { item in
                        HStack(spacing: 8) {
                            Button(action: {
                                editingItem = item
                            }) {
                                Image(systemName: "square.and.pencil")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                            .help("Chỉnh sửa từ vựng...")
                            
                            Button(role: .destructive, action: {
                                vocabService.removeWord(id: item.id)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Xóa khỏi sổ tay")
                        }
                    }
                    .width(min: 54, ideal: 62, max: 72)
                }
            }
        }
        .sheet(item: $editingItem) { item in
            AddWordSheet(editingItem: item)
        }
        .sensoryFeedback(.selection, trigger: selectedItemID)
        .sensoryFeedback(.impact(weight: .light), trigger: sortOption)
    }
    
    private var sortDropdownMenu: some View {
        Menu {
            Section("PHÂN LOẠI THEO AI") {
                Button(action: { withAnimation { sortOption = .aiPriority } }) {
                    if sortOption == .aiPriority {
                        Label("Mức độ quan trọng (AI)", systemImage: "checkmark")
                    } else {
                        Label("Mức độ quan trọng (AI)", systemImage: "list.bullet.indent")
                    }
                }
                
                Button(action: { withAnimation { sortOption = .thematicGenre } }) {
                    if sortOption == .thematicGenre {
                        Label("Theo thể loại / chủ đề (AI)", systemImage: "checkmark")
                    } else {
                        Label("Theo thể loại / chủ đề (AI)", systemImage: "folder.badge.gearshape")
                    }
                }
                
                Button(action: { withAnimation { sortOption = .aiPartOfSpeech } }) {
                    if sortOption == .aiPartOfSpeech {
                        Label("Theo từ loại (AI)", systemImage: "checkmark")
                    } else {
                        Label("Theo từ loại (AI)", systemImage: "tag")
                    }
                }
            }
            
            Section("SẮP XẾP TIÊU CHUẨN") {
                ForEach([
                    NotebookSortOption.newestFirst,
                    NotebookSortOption.oldestFirst,
                    NotebookSortOption.alphabeticalAZ,
                    NotebookSortOption.alphabeticalZA,
                    NotebookSortOption.favoritesFirst,
                    NotebookSortOption.learningFirst
                ]) { opt in
                    Button(action: { withAnimation { sortOption = opt } }) {
                        if sortOption == opt {
                            Label(opt.rawValue, systemImage: "checkmark")
                        } else {
                            Label(opt.rawValue, systemImage: opt.icon)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: sortOption.icon)
                    .font(.system(size: 10))
                Text(sortOption.rawValue)
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .background(Color.primary.opacity(0.04))
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}
