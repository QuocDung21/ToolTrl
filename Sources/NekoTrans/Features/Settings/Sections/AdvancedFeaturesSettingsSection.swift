import SwiftUI

public struct AdvancedFeaturesSettingsSection: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var hotKeyManager = HotKeyManager.shared
    @State private var showPromptSheet: Bool = false
    @State private var isExpandedAIConfig: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var testStatusMessage: String? = nil
    @State private var testSuccess: Bool = false
    
    private var hasCustomConfig: Bool {
        !settings.openAIKey.isEmpty ||
        !settings.anthropicKey.isEmpty ||
        !settings.geminiKey.isEmpty ||
        !settings.groqKey.isEmpty ||
        !settings.deepSeekKey.isEmpty ||
        !settings.deepLKey.isEmpty ||
        !settings.customAIModel.isEmpty
    }
    
    public init() {}
    
    public var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.showAIAssistantInMenu) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Trợ lý AI phân tích sâu", systemImage: "sparkles")
                            .font(.system(size: 13, weight: .medium))
                        Text("Phân tích cấu trúc ngữ pháp, ngữ cảnh từ vựng chuyên sâu với ChatGPT/Gemini (\(hotKeyManager.aiShortcut.displayString)).")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $settings.showAIVocabGrammarInMenu) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("AI Bóc tách từ vựng & Ngữ pháp", systemImage: "brain.head.profile")
                            .font(.system(size: 13, weight: .medium))
                        Text("Tự động trích xuất danh sách từ mới và công thức ngữ pháp từ đoạn văn vào Sổ tay.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("TRÍ TUỆ NHÂN TẠO (AI FEATURES)")
            }
            
            Section {
                Picker("Nhà cung cấp AI mặc định:", selection: $settings.aiProvider) {
                    ForEach(DirectAIProvider.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                
                DisclosureGroup(isExpanded: $isExpandedAIConfig) {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("Model AI tùy chỉnh (để trống để dùng mặc định):", text: $settings.customAIModel)
                            .textFieldStyle(.roundedBorder)
                        
                        switch settings.aiProvider {
                        case .openAI:
                            SecureField("OpenAI API Key (sk-...):", text: $settings.openAIKey)
                                .textFieldStyle(.roundedBorder)
                        case .anthropic:
                            SecureField("Anthropic Claude API Key (sk-ant-...):", text: $settings.anthropicKey)
                                .textFieldStyle(.roundedBorder)
                        case .googleGemini:
                            SecureField("Google Gemini API Key (AIza...):", text: $settings.geminiKey)
                                .textFieldStyle(.roundedBorder)
                        case .groq:
                            SecureField("Groq API Key (gsk_...):", text: $settings.groqKey)
                                .textFieldStyle(.roundedBorder)
                        case .deepSeek:
                            SecureField("DeepSeek API Key (sk-...):", text: $settings.deepSeekKey)
                                .textFieldStyle(.roundedBorder)
                        case .ollama:
                            TextField("Ollama Local Endpoint:", text: $settings.ollamaEndpoint)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        SecureField("DeepL API Key (Tùy chọn):", text: $settings.deepLKey)
                            .textFieldStyle(.roundedBorder)
                        
                        HStack(spacing: 8) {
                            Button(action: {
                                testAIConnection()
                            }) {
                                if isTestingConnection {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Đang kiểm tra kết nối...")
                                } else {
                                    Label("Xem trước / Thử kết nối AI", systemImage: "play.circle.fill")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isTestingConnection)
                            
                            if let msg = testStatusMessage {
                                Text(msg)
                                    .font(.system(size: 11))
                                    .foregroundColor(testSuccess ? .green : .red)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.top, 4)
                    }
                    .padding(.top, 4)
                } label: {
                    HStack {
                        Label("Cấu hình nâng cao (API Key & Model AI)", systemImage: "key.fill")
                            .font(.system(size: 13, weight: .medium))
                        
                        Spacer()
                        
                        if hasCustomConfig {
                            Text("Đã thiết lập")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12))
                                .cornerRadius(4)
                        }
                    }
                }
            } header: {
                Text("CẤU HÌNH AI DIRECT API & LOCAL LLM")
            } footer: {
                Text("API Key được lưu an toàn cục bộ trên máy. Bạn có thể sử dụng trực tiếp để dịch thuật thông minh, sửa lỗi câu và bóc tách từ vựng.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Section {
                Toggle(isOn: $settings.showOCRInMenu) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Chụp quét chữ màn hình (OCR)", systemImage: "camera.viewfinder")
                            .font(.system(size: 13, weight: .medium))
                        Text("Khoanh vùng màn hình để quét và nhận diện chữ bằng Apple Vision (\(hotKeyManager.ocrShortcut.displayString)).")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                if FeatureFlagService.shared.isFeatureEnabled(.continuityStudio) {
                    Toggle(isOn: $settings.showiPadContinuityInMenu) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Continuity Studio: Bắn bài sang iPad", systemImage: "ipad.and.arrow.forward")
                                .font(.system(size: 13, weight: .medium))
                            Text("Chuyển bài tập sang iPad để giải bằng Apple Pencil và tự động đồng bộ ngược về Mac.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("CÔNG CỤ MÀN HÌNH & LIÊN KẾT THIẾT BỊ")
            }
            
            Section {
                Toggle(isOn: $settings.showDomainSelectorInMenu) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Bộ chọn Ngữ cảnh chuyên ngành", systemImage: "globe")
                            .font(.system(size: 13, weight: .medium))
                        Text("Chuyển đổi linh hoạt ngữ cảnh dịch: Công nghệ IT, Kinh tế, Y khoa, Học thuật IELTS, Đời sống.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $settings.showNotebookInMenu) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Lối tắt Mở Sổ tay từ vựng", systemImage: "book.closed.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Hiển thị lối tắt mở nhanh Sổ tay lưu trữ từ vựng (\(hotKeyManager.notebookShortcut.displayString)).")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("NGỮ CẢNH & TIỆN ÍCH")
            }
            
            Section {
                Toggle(isOn: $settings.showSynonyms) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Từ đồng nghĩa, trái nghĩa & Liên quan NLP", systemImage: "sparkle.magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                        Text("Tải và gợi ý từ đồng nghĩa, từ trái nghĩa và vector liên quan từ Apple NaturalLanguage.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle(isOn: $settings.showOfflineDictionary) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Từ điển hệ thống macOS (Offline)", systemImage: "book.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Tự động tra cứu định nghĩa và phiên âm từ điển Apple Oxford gốc khi ngoại tuyến.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("TỪ ĐIỂN & TRA CỨU MỞ RỘNG")
            }
        }
        .formStyle(.grouped)
    }
    
    private func testAIConnection() {
        isTestingConnection = true
        testStatusMessage = nil
        
        Task {
            do {
                let sampleText = "Hello, NekoTrans!"
                let response = try await DirectAIService.shared.translate(
                    text: sampleText,
                    from: "en",
                    to: "vi",
                    provider: settings.aiProvider
                )
                await MainActor.run {
                    isTestingConnection = false
                    testSuccess = true
                    testStatusMessage = "✅ Thành công: \"\(response.trimmingCharacters(in: .whitespacesAndNewlines))\""
                }
            } catch {
                await MainActor.run {
                    isTestingConnection = false
                    testSuccess = false
                    testStatusMessage = "❌ Lỗi: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview("Tính Năng Nâng Cao (Light)") {
    AdvancedFeaturesSettingsSection()
        .frame(width: 580, height: 640)
}

#Preview("Tính Năng Nâng Cao (Dark)") {
    AdvancedFeaturesSettingsSection()
        .preferredColorScheme(.dark)
        .frame(width: 580, height: 640)
}
