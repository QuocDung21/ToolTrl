import SwiftUI

public struct QuickPromptManagerSheet: View {
    @ObservedObject var promptService = QuickPromptService.shared
    @Environment(\.presentationMode) var presentationMode
    
    @State private var editingPrompt: QuickPromptItem? = nil
    @State private var isCreatingNew: Bool = false
    
    @State private var inputIcon: String = "💡"
    @State private var inputTitle: String = ""
    @State private var inputTemplate: String = ""
    @State private var inputIsEnabled: Bool = true
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .foregroundColor(.purple)
                    Text("Tùy Chỉnh & Sắp Xếp Mẫu Câu Hỏi Nhanh (AI Prompts)")
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
                // Left List with Sort & Visibility Toggles
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
                            inputIsEnabled = true
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
                            ForEach(Array(promptService.prompts.enumerated()), id: \.element.id) { index, item in
                                HStack(spacing: 6) {
                                    // 1. Visibility Toggle Button (Ẩn / Hiện)
                                    Button(action: {
                                        promptService.toggleEnabled(id: item.id)
                                    }) {
                                        Image(systemName: item.isEnabled ? "eye.fill" : "eye.slash")
                                            .font(.system(size: 11))
                                            .foregroundColor(item.isEnabled ? .blue : .secondary.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                    .help(item.isEnabled ? "Đang hiện trên thanh công cụ (Bấm để ẩn)" : "Đang ẩn (Bấm để hiện)")
                                    
                                    // 2. Select & Edit Area
                                    Button(action: {
                                        editingPrompt = item
                                        isCreatingNew = false
                                        inputIcon = item.icon
                                        inputTitle = item.title
                                        inputTemplate = item.template
                                        inputIsEnabled = item.isEnabled
                                    }) {
                                        HStack(spacing: 6) {
                                            Text(item.icon)
                                                .font(.system(size: 13))
                                            
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(item.title)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundColor(item.isEnabled ? .primary : .secondary)
                                                Text(item.template)
                                                    .font(.system(size: 9.5))
                                                    .foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            
                                            Spacer()
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // 3. Sort Up / Down Buttons
                                    HStack(spacing: 2) {
                                        Button(action: {
                                            promptService.moveUp(id: item.id)
                                        }) {
                                            Image(systemName: "chevron.up")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(index > 0 ? .secondary : .secondary.opacity(0.2))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(index == 0)
                                        .help("Di chuyển lên")
                                        
                                        Button(action: {
                                            promptService.moveDown(id: item.id)
                                        }) {
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(index < promptService.prompts.count - 1 ? .secondary : .secondary.opacity(0.2))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(index == promptService.prompts.count - 1)
                                        .help("Di chuyển xuống")
                                    }
                                    
                                    // 4. Delete Button
                                    if promptService.prompts.count > 1 {
                                        Button(action: {
                                            promptService.deletePrompt(id: item.id)
                                            if editingPrompt?.id == item.id {
                                                editingPrompt = nil
                                                isCreatingNew = false
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .font(.system(size: 10))
                                                .foregroundColor(.red.opacity(0.65))
                                        }
                                        .buttonStyle(.plain)
                                        .help("Xóa mẫu")
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    editingPrompt?.id == item.id ? Color.blue.opacity(0.12) : (item.isEnabled ? Color.primary.opacity(0.025) : Color.primary.opacity(0.01))
                                )
                                .cornerRadius(6)
                                .opacity(item.isEnabled ? 1.0 : 0.6)
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
                .frame(width: 290)
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
                                Text("Dùng {text} làm vị trí đoạn văn")
                                    .font(.system(size: 9.5))
                                    .foregroundColor(.blue)
                            }
                            
                            TextEditor(text: $inputTemplate)
                                .font(.system(size: 11.5))
                                .padding(4)
                                .background(Color.primary.opacity(0.04))
                                .cornerRadius(6)
                                .frame(height: 100)
                        }
                        
                        Toggle("Hiển thị mẫu này trên thanh câu hỏi nhanh", isOn: $inputIsEnabled)
                            .font(.system(size: 11))
                        
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                if !inputTitle.isEmpty {
                                    if isCreatingNew {
                                        promptService.addPrompt(icon: inputIcon, title: inputTitle, template: inputTemplate)
                                    } else if let cur = editingPrompt {
                                        promptService.updatePrompt(id: cur.id, icon: inputIcon, title: inputTitle, template: inputTemplate, isEnabled: inputIsEnabled)
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
                            Text("Chọn một mẫu bên trái để sửa, bấm 👁️ để ẩn/hiện, hoặc ⬆️⬇️ để đổi thứ tự")
                                .font(.system(size: 11.5))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 620, height: 380)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
    }
}
