import SwiftUI

public struct QuickPromptManagerSheet: View {
    @ObservedObject var promptService = QuickPromptService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var editingPrompt: QuickPromptItem? = nil
    @State private var isCreatingNew: Bool = false
    
    @State private var inputIcon: String = "💡"
    @State private var inputTitle: String = ""
    @State private var inputTemplate: String = ""
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .foregroundColor(.purple)
                    Text("Tùy Chỉnh Mẫu Câu Hỏi Nhanh (AI Prompts)")
                        .font(.system(size: 13, weight: .bold))
                }
                
                Spacer()
                
                Button("Xong") {
                    presentationMode.wrappedValue.dismiss()
                }
                .font(.system(size: 12, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.04))
            
            Divider().opacity(0.3)
            
            // Content
            HStack(spacing: 0) {
                // Left List
                VStack(spacing: 8) {
                    HStack {
                        Text("Danh sách mẫu (\(promptService.prompts.count))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            inputIcon = "💡"
                            inputTitle = ""
                            inputTemplate = "Hãy phân tích đoạn sau:\n\n{text}"
                            editingPrompt = nil
                            isCreatingNew = true
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "plus.circle.fill")
                                Text("Thêm mới")
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    
                    ScrollView {
                        LazyVStack(spacing: 5) {
                            ForEach(promptService.prompts) { item in
                                Button(action: {
                                    editingPrompt = item
                                    isCreatingNew = false
                                    inputIcon = item.icon
                                    inputTitle = item.title
                                    inputTemplate = item.template
                                }) {
                                    HStack(spacing: 8) {
                                        Text(item.icon)
                                            .font(.system(size: 14))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title)
                                                .font(.system(size: 11.5, weight: .semibold))
                                                .foregroundColor(.primary)
                                            Text(item.template)
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        
                                        Spacer()
                                        
                                        if promptService.prompts.count > 1 {
                                            Button(action: {
                                                promptService.deletePrompt(id: item.id)
                                                if editingPrompt?.id == item.id {
                                                    editingPrompt = nil
                                                    isCreatingNew = false
                                                }
                                            }) {
                                                Image(systemName: "trash")
                                                    .font(.system(size: 10.5))
                                                    .foregroundColor(.red.opacity(0.7))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        editingPrompt?.id == item.id ? Color.blue.opacity(0.12) : Color.primary.opacity(0.025)
                                    )
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                    
                    Divider().opacity(0.2)
                    
                    Button(action: {
                        promptService.resetDefaults()
                        editingPrompt = nil
                        isCreatingNew = false
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Khôi phục mặc định")
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
                .frame(width: 260)
                .background(Color.primary.opacity(0.015))
                
                Divider().opacity(0.3)
                
                // Right Edit / Create Form
                VStack(alignment: .leading, spacing: 12) {
                    if isCreatingNew || editingPrompt != nil {
                        Text(isCreatingNew ? "Thêm Mẫu Câu Hỏi Mới" : "Chỉnh Sửa Mẫu Câu Hỏi")
                            .font(.system(size: 12, weight: .bold))
                        
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Emoji Icon:")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                                TextField("Icon", text: $inputIcon)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 60)
                                    .font(.system(size: 13))
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tên hiển thị (Tiêu đề):")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                                TextField("Ví dụ: Tóm tắt 3 ý chính...", text: $inputTitle)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Nội dung Prompt gửi cho AI:")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Sử dụng {text} làm vị trí đoạn văn")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.blue)
                            }
                            
                            TextEditor(text: $inputTemplate)
                                .font(.system(size: 11.5))
                                .padding(4)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(6)
                                .frame(height: 110)
                        }
                        
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                if !inputTitle.isEmpty {
                                    if isCreatingNew {
                                        promptService.addPrompt(icon: inputIcon, title: inputTitle, template: inputTemplate)
                                    } else if let cur = editingPrompt {
                                        promptService.updatePrompt(id: cur.id, icon: inputIcon, title: inputTitle, template: inputTemplate)
                                    }
                                    isCreatingNew = false
                                    editingPrompt = nil
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark")
                                    Text("Lưu Mẫu")
                                }
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(inputTitle.isEmpty || inputTemplate.isEmpty)
                        }
                        
                        Spacer()
                    } else {
                        VStack(spacing: 8) {
                            Spacer()
                            Image(systemName: "hand.tap")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary.opacity(0.4))
                            Text("Chọn một mẫu bên trái để chỉnh sửa hoặc bấm 'Thêm mới'")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 580, height: 360)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
    }
}
