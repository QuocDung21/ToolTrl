import SwiftUI

public struct PromptsSettingsSection: View {
    @ObservedObject var promptService = QuickPromptService.shared
    @Binding var showPromptManagerSheet: Bool
    
    public init(showPromptManagerSheet: Binding<Bool>) {
        self._showPromptManagerSheet = showPromptManagerSheet
    }
    
    public var body: some View {
        Form {
            Section {
                ForEach(promptService.prompts.prefix(5)) { p in
                    HStack(spacing: 8) {
                        Image(systemName: p.icon)
                            .foregroundColor(AppColors.accent)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.title)
                                .font(.system(size: 13, weight: .medium))
                            Text(p.template)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
                
                Button(action: {
                    showPromptManagerSheet = true
                }) {
                    Label("Mở Trình Quản Lý Mẫu Câu Hỏi...", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
            } header: {
                Text("QUẢN LÝ MẪU CÂU HỎI NHANH (PROMPTS)")
            } footer: {
                Text("Các mẫu câu hỏi sẽ hiển thị trong thanh menu Trợ lý AI khi bạn bôi đen văn bản.")
            }
        }
        .formStyle(.grouped)
    }
}
