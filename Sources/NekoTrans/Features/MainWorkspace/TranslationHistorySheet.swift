import SwiftUI
import AppKit

public struct TranslationHistorySheet: View {
    @ObservedObject var historyService = TranslationHistoryService.shared
    @ObservedObject var viewModel: TranslationViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchFilter: String = ""
    @State private var copiedItemId: UUID? = nil
    
    public init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
    }
    
    private var filteredItems: [TranslationHistoryItem] {
        let trimmed = searchFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return historyService.items }
        return historyService.items.filter {
            $0.originalText.lowercased().contains(trimmed) ||
            $0.translatedText.lowercased().contains(trimmed)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.accentColor)
                
                Text("Lịch sử dịch thuật")
                    .font(.system(size: 15, weight: .bold))
                
                Text("(\(historyService.items.count))")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !historyService.items.isEmpty {
                    Button(role: .destructive, action: {
                        historyService.clearAll()
                    }) {
                        Text("Xóa tất cả")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("Tìm kiếm trong lịch sử dịch...", text: $searchFilter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                if !searchFilter.isEmpty {
                    Button(action: { searchFilter = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            .cornerRadius(8)
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            
            Divider().opacity(0.3)
            
            // Items List
            if filteredItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(searchFilter.isEmpty ? "Chưa có lịch sử dịch thuật nào" : "Không tìm thấy kết quả phù hợp")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredItems) { item in
                            historyItemCard(item: item)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 580, height: 460)
        .background(VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow))
    }
    
    private func historyItemCard(item: TranslationHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.originalText)
                        .font(.system(size: 13.5, weight: .medium))
                        .lineLimit(2)
                    
                    Text(item.translatedText)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer(minLength: 8)
                
                // Copy & Delete Buttons
                HStack(spacing: 6) {
                    Button(action: {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(item.translatedText, forType: .string)
                        copiedItemId = item.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            if copiedItemId == item.id {
                                copiedItemId = nil
                            }
                        }
                    }) {
                        Image(systemName: copiedItemId == item.id ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11.5))
                            .foregroundColor(copiedItemId == item.id ? .green : .secondary)
                            .padding(5)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Sao chép bản dịch")
                    
                    Button(action: {
                        historyService.delete(id: item.id)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(5)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Xóa khỏi lịch sử")
                }
            }
            
            // Metadata Footer
            HStack(spacing: 8) {
                Text("\(item.sourceLang.uppercased()) → \(item.targetLang.uppercased())")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
                
                Text(item.engine)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formattedDate(item.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 0.8)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Load into view model and dismiss
            viewModel.processText(item.originalText)
            dismiss()
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
