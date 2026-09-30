import SwiftUI

public struct NotebookQuickLookModal: View {
    let item: SavedWordItem
    @Binding var isPresented: Bool
    
    public init(item: SavedWordItem, isPresented: Binding<Bool>) {
        self.item = item
        self._isPresented = isPresented
    }
    
    public var body: some View {
        ZStack {
            // Dimmed backdrop
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isPresented = false
                    }
                }
            
            VStack(alignment: .leading, spacing: 0) {
                // Quick Look Titlebar
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "book.pages")
                            .font(.system(size: 11))
                            .foregroundColor(.blue)
                        Text("Từ Điển Chi Tiết")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("Bấm Space hoặc Esc để đóng")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.03))
                
                Divider()
                
                // Quick Look Body
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        WordDetailDocumentView(item: item)
                    }
                    .padding(20)
                }
            }
            .frame(width: 580, height: 500)
            .background(
                ZStack {
                    VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 12)
                    Color(nsColor: .windowBackgroundColor).opacity(0.98)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.45), radius: 24, x: 0, y: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.18), lineWidth: 1)
            )
            .transition(.scale(scale: 0.95).combined(with: .opacity))
        }
    }
}
