import SwiftUI

/// Thẻ hiển thị so sánh kết quả dịch song song giữa nhiều động cơ (Google Web, Google GTX, DeepL, Direct AI).
/// Kế thừa logic so sánh multi-service trực quan từ Easydict.
public struct MultiEngineComparisonView: View {
    @ObservedObject var viewModel: TranslationViewModel
    
    public init(viewModel: TranslationViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header bar
            HStack(spacing: 8) {
                Image(systemName: "square.split.3x1")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 14, weight: .semibold))
                
                Text("So sánh bản dịch đa động cơ (Multi-Engine)")
                    .font(.appHeadlineBold)
                
                if viewModel.isComparing {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.8)
                    Text("Đang chạy đồng thời...")
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.performComparison()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                        Text("Làm mới")
                            .font(.appCaptionMedium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isComparing)
            }
            
            if viewModel.comparisonResults.isEmpty && !viewModel.isComparing {
                Text("Chưa có kết quả so sánh. Nhập văn bản hoặc bấm 'Làm mới' để bắt đầu so sánh.")
                    .font(.appBody)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 450), spacing: 14)], spacing: 14) {
                    ForEach(viewModel.comparisonResults) { result in
                        comparisonResultCard(result)
                    }
                }
            }
        }
        .padding(16)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func comparisonResultCard(_ result: TranslationProviderResult) -> some View {
        let isSelected = viewModel.translatedText == result.text && !result.text.isEmpty
        
        NekoCard(
            cornerRadius: 10,
            padding: 12,
            backgroundColor: isSelected ? Color.accentColor.opacity(0.06) : Color(nsColor: .controlBackgroundColor).opacity(0.6),
            borderColor: isSelected ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.1),
            borderWidth: isSelected ? 1.5 : 0.8,
            hasHoverEffect: true
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // Provider Title & Latency badge
                HStack(spacing: 6) {
                    Image(systemName: result.engine.icon)
                        .foregroundColor(.accentColor)
                        .font(.system(size: 12))
                    
                    Text(result.providerName)
                        .font(.appBodyBold)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Latency Badge
                    latencyBadge(latencyMs: result.latencyMs, isError: result.isError)
                }
                
                Divider()
                    .opacity(0.3)
                
                // Result Content
                if result.isError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(result.errorMessage ?? "Lỗi không xác định")
                            .font(.appBody)
                            .foregroundColor(.secondary)
                    }
                    .frame(minHeight: 60, alignment: .topLeading)
                } else {
                    Text(result.text)
                        .font(.appBody)
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                }
                
                // Action Buttons Footer
                HStack(spacing: 8) {
                    if !result.isError && !result.text.isEmpty {
                        NekoCopyButton(textToCopy: result.text)
                        
                        Button(action: {
                            viewModel.applyComparisonResult(result)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "arrow.up.left.circle")
                                    .font(.system(size: 11))
                                Text(isSelected ? "Đang chọn" : "Dùng bản này")
                                    .font(.appCaptionMedium)
                            }
                            .foregroundColor(isSelected ? .accentColor : .primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    @ViewBuilder
    private func latencyBadge(latencyMs: Int, isError: Bool) -> some View {
        if isError {
            Text("Thất bại")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.12))
                .cornerRadius(4)
        } else {
            let color: Color = latencyMs < 350 ? .green : (latencyMs < 1000 ? .blue : .orange)
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8))
                Text("\(latencyMs)ms")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
            }
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(4)
        }
    }
}
