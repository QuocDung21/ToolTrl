import SwiftUI

public struct FlashcardStudyView: View {
    let items: [SavedWordItem]
    @Binding var isPresented: Bool
    @ObservedObject var speechService = SpeechService.shared
    
    @State private var currentIndex: Int = 0
    @State private var isCardFlipped: Bool = false
    @State private var isCardHovered: Bool = false
    
    public init(items: [SavedWordItem], isPresented: Binding<Bool>) {
        self.items = items
        self._isPresented = isPresented
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Flashcard Header
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }) {
                    Label("Quay lại Sổ tay", systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                if !items.isEmpty {
                    Text("\(currentIndex + 1) / \(items.count)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)
                }
            }
            .padding(18)
            
            Spacer()
            
            // 3D Flip Card with Dynamic Hover Spring
            if !items.isEmpty && currentIndex < items.count {
                let currentItem = items[currentIndex]
                
                ZStack {
                    if isCardFlipped {
                        // Back of Card (Meaning / Formula)
                        cardBackView(item: currentItem)
                            .rotation3DEffect(.degrees(isCardFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0))
                    } else {
                        // Front of Card (Word / Context)
                        cardFrontView(item: currentItem)
                            .rotation3DEffect(.degrees(isCardFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    }
                }
                .scaleEffect(isCardHovered ? 1.025 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isCardHovered)
                .contentShape(Rectangle())
                .onHover { hovering in
                    isCardHovered = hovering
                }
                .onTapGesture {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                        isCardFlipped.toggle()
                    }
                }
            }
            
            Spacer()
            
            // Controls Bar
            HStack(spacing: 24) {
                Button(action: {
                    if currentIndex > 0 {
                        currentIndex -= 1
                        isCardFlipped = false
                    }
                }) {
                    Label("Trước", systemImage: "arrow.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .disabled(currentIndex == 0)
                
                let isSpeaking = speechService.isSpeaking && speechService.currentSpeakerID == "flashcard"
                Button(action: {
                    if currentIndex < items.count {
                        let item = items[currentIndex]
                        speechService.speak(text: item.cleanTitle, languageCode: "en-US", speakerID: "flashcard")
                    }
                }) {
                    HStack(spacing: 4) {
                        EqualizerWaveView(isActive: isSpeaking, barColor: .blue, height: 11)
                        if !isSpeaking {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(8)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Nghe phát âm")
                
                Button(action: {
                    if currentIndex < items.count - 1 {
                        currentIndex += 1
                        isCardFlipped = false
                    }
                }) {
                    HStack {
                        Text("Kế tiếp")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(currentIndex >= items.count - 1)
            }
            .padding(.bottom, 26)
        }
        .sensoryFeedback(.selection, trigger: isCardFlipped)
        .sensoryFeedback(.impact(weight: .light), trigger: currentIndex)
    }
    
    // MARK: - Front of Card
    private func cardFrontView(item: SavedWordItem) -> some View {
        VStack(spacing: 14) {
            HStack {
                Label(item.isGrammarFormula ? "CẤU TRÚC NGỮ PHÁP" : "TỪ VỰNG TIẾNG ANH", systemImage: item.isGrammarFormula ? "function" : "text.book.closed")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                }
            }
            
            Spacer()
            
            Text(item.cleanTitle)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            
            if let ph = item.phonetic, !ph.isEmpty, !item.isGrammarFormula {
                Text(ph)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundColor(.orange)
            }
            
            if let exEn = item.exampleEn, !exEn.isEmpty {
                Text("\"\(exEn)\"")
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(.secondary)
                    .italic()
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            Text("Chạm vào thẻ để lật xem nghĩa ➔")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(24)
        .frame(width: 480, height: 280)
        .background(cardBackground(isBack: false))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(isCardHovered ? 0.22 : 0.14), radius: isCardHovered ? 22 : 16, x: 0, y: isCardHovered ? 12 : 8)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(isCardHovered ? 0.18 : 0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Back of Card
    private func cardBackView(item: SavedWordItem) -> some View {
        VStack(spacing: 14) {
            HStack {
                Label(item.isGrammarFormula ? "CÔNG THỨC & CÁCH DÙNG" : "NGHĨA TIẾNG VIỆT", systemImage: item.isGrammarFormula ? "function" : "sparkles")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(item.isGrammarFormula ? .blue : .purple)
                
                Spacer()
                
                Text(item.aiThematicGenre.rawValue)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            if item.isGrammarFormula, let formula = item.phonetic {
                Text(formula)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
            }
            
            Text(item.translation)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .lineSpacing(3)
            
            Spacer()
            
            Text("Chạm để lật lại mặt trước")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(.secondary.opacity(0.8))
        }
        .padding(24)
        .frame(width: 480, height: 280)
        .background(cardBackground(isBack: true))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(isCardHovered ? 0.26 : 0.18), radius: isCardHovered ? 26 : 20, x: 0, y: isCardHovered ? 14 : 10)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(isCardHovered ? 0.35 : 0.2), lineWidth: 1.2)
        )
    }
    
    // MARK: - Modern macOS 15 MeshGradient / Dynamic Background
    @ViewBuilder
    private func cardBackground(isBack: Bool) -> some View {
        if #available(macOS 15.0, *) {
            if isBack {
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                        [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                    ],
                    colors: [
                        .blue.opacity(0.18), .purple.opacity(0.12), .indigo.opacity(0.18),
                        .cyan.opacity(0.10), .blue.opacity(0.08), .purple.opacity(0.12),
                        .indigo.opacity(0.18), .cyan.opacity(0.12), .blue.opacity(0.18)
                    ]
                )
                .background(VisualEffectBackground(material: .popover, blendingMode: .behindWindow))
            } else {
                MeshGradient(
                    width: 3, height: 3,
                    points: [
                        [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                        [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                        [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                    ],
                    colors: [
                        .cyan.opacity(0.08), .blue.opacity(0.06), .indigo.opacity(0.08),
                        .blue.opacity(0.05), Color.primary.opacity(0.02), .cyan.opacity(0.06),
                        .indigo.opacity(0.08), .blue.opacity(0.06), .cyan.opacity(0.08)
                    ]
                )
                .background(VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow))
            }
        } else {
            VisualEffectBackground(material: isBack ? .popover : .hudWindow, blendingMode: .behindWindow)
        }
    }
}
