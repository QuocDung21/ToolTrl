import SwiftUI

public enum SettingsSidebarSection: String, CaseIterable, Identifiable {
    case general = "Chung"
    case shortcuts = "Phím tắt"
    case speech = "Giọng đọc"
    case appearance = "Giao diện & Icon"
    case prompts = "Mẫu câu hỏi"
    case about = "Giới thiệu"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "command"
        case .speech: return "speaker.wave.2"
        case .appearance: return "paintbrush"
        case .prompts: return "text.badge.plus"
        case .about: return "info.circle"
        }
    }
    
    public var iconColor: Color {
        switch self {
        case .general: return .gray
        case .shortcuts: return .orange
        case .speech: return .blue
        case .appearance: return .purple
        case .prompts: return .teal
        case .about: return .indigo
        }
    }
}

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var speechService = SpeechService.shared
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var iconService = AppIconService.shared
    @ObservedObject var promptService = QuickPromptService.shared
    @ObservedObject var hotKeyManager = HotKeyManager.shared
    
    @State private var selectedSection: SettingsSidebarSection? = .general
    @State private var showPromptManagerSheet: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            // Sidebar Navigation (Standard macOS System Settings)
            List(selection: $selectedSection) {
                ForEach(SettingsSidebarSection.allCases) { sec in
                    NavigationLink(value: sec) {
                        Label {
                            Text(sec.rawValue)
                                .font(.system(size: 13))
                        } icon: {
                            Image(systemName: sec.icon)
                                .foregroundColor(sec.iconColor)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 230)
        } detail: {
            // Detail Form (macOS Grouped Form Style)
            Group {
                switch selectedSection {
                case .general:
                    generalSettingsForm
                case .shortcuts:
                    shortcutsSettingsForm
                case .speech:
                    speechSettingsForm
                case .appearance:
                    appearanceSettingsForm
                case .prompts:
                    promptsSettingsForm
                case .about:
                    aboutSettingsForm
                case .none:
                    generalSettingsForm
                }
            }
            .navigationTitle(selectedSection?.rawValue ?? "Cài đặt")
        }
        .frame(minWidth: 680, minHeight: 480)
        .sheet(isPresented: $showPromptManagerSheet) {
            QuickPromptManagerSheet()
        }
    }
    
    // MARK: - 1. General Settings Form
    private var generalSettingsForm: some View {
        Form {
            Section(header: Text("KHỞI ĐỘNG & HỆ THỐNG")) {
                Toggle("Tự động khởi chạy cùng macOS khi đăng nhập", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                
                Toggle("Tự động ẩn cửa sổ dịch khi bấm chuột ra ngoài", isOn: $settings.clickOutsideDismiss)
            }
            
            Section(header: Text("DỊCH THUẬT & NGÔN NGỮ")) {
                Picker("Ngôn ngữ đích mặc định:", selection: $settings.targetLanguage) {
                    ForEach(TargetLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                
                Picker("Chế độ hiển thị bản dịch:", selection: $settings.translationDisplayMode) {
                    ForEach(TranslationDisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            }
            
            Section(header: Text("BỘ NHỚ TẠM (CACHE)")) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Xóa bộ nhớ đệm dịch thuật")
                            .font(.system(size: 13))
                        Text("Làm sạch các bản dịch đã lưu trong RAM để giải phóng dung lượng.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Xóa Cache") {
                        TranslationCache.shared.clearAll()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - 2. Shortcuts Settings Form
    private var shortcutsSettingsForm: some View {
        Form {
            Section {
                shortcutRow(
                    title: "Dịch văn bản bôi đen",
                    subtitle: "Mở popup dịch ngay tại vị trí con trỏ chuột.",
                    shortcut: $hotKeyManager.translateShortcut,
                    defaultShortcut: KeyShortcut.defaultTranslate
                )
                
                shortcutRow(
                    title: "Quét chữ trên màn hình (OCR)",
                    subtitle: "Khoanh vùng ảnh màn hình để bóc tách chữ & dịch tức thì.",
                    shortcut: $hotKeyManager.ocrShortcut,
                    defaultShortcut: KeyShortcut.defaultOCR
                )
                
                shortcutRow(
                    title: "Mở nhanh Trợ lý AI",
                    subtitle: "Mở cửa sổ trò chuyện với ChatGPT, Gemini, Claude.",
                    shortcut: $hotKeyManager.aiShortcut,
                    defaultShortcut: KeyShortcut.defaultAI
                )
                
                shortcutRow(
                    title: "Mở Sổ tay từ vựng & Flashcards",
                    subtitle: "Xem lại từ vựng đã lưu và ôn tập thẻ ghi nhớ.",
                    shortcut: $hotKeyManager.notebookShortcut,
                    defaultShortcut: KeyShortcut.defaultNotebook
                )
            } header: {
                Text("PHÍM TẮT TOÀN CẦU (GLOBAL SHORTCUTS)")
            } footer: {
                Text("Bấm vào ô phím tắt để ghi nhận tổ hợp phím mới trên bàn phím của bạn.")
            }
            
            Section {
                Button("Khôi phục toàn bộ phím tắt mặc định") {
                    hotKeyManager.resetDefaults()
                }
                .foregroundColor(.orange)
            }
        }
        .formStyle(.grouped)
    }
    
    private func shortcutRow(
        title: String,
        subtitle: String,
        shortcut: Binding<KeyShortcut>,
        defaultShortcut: KeyShortcut
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            ShortcutRecorderView(
                shortcut: shortcut,
                defaultShortcut: defaultShortcut
            )
        }
    }
    
    // MARK: - 3. Speech Settings Form
    private var speechSettingsForm: some View {
        Form {
            Section(header: Text("PHÁT ÂM TỰ NHIÊN (TEXT-TO-SPEECH)")) {
                Toggle("Tự động phát âm khi tra từ đơn", isOn: $settings.autoSpeakWord)
            }
            
            Section(header: Text("TÙY CHỈNH GIỌNG ĐỌC")) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Tốc độ đọc:")
                        Spacer()
                        Text(String(format: "%.2fx", settings.speechRate))
                            .foregroundColor(.secondary)
                            .font(.system(size: 11, design: .monospaced))
                    }
                    
                    Slider(value: $settings.speechRate, in: 0.2...0.8, step: 0.05)
                }
                .padding(.vertical, 2)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Cao độ giọng đọc:")
                        Spacer()
                        Text(String(format: "%.2fx", settings.speechPitch))
                            .foregroundColor(.secondary)
                            .font(.system(size: 11, design: .monospaced))
                    }
                    
                    Slider(value: $settings.speechPitch, in: 0.5...1.5, step: 0.05)
                }
                .padding(.vertical, 2)
            }
            
            Section {
                Button(action: {
                    speechService.speak(
                        text: "Hello! ToolTrL helps you learn English effortlessly.",
                        languageCode: "en-US",
                        speakerID: "settings_test"
                    )
                }) {
                    Label("Nghe thử giọng đọc mẫu", systemImage: "speaker.wave.2")
                }
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - 4. Appearance Settings Form
    private var appearanceSettingsForm: some View {
        Form {
            Section(header: Text("BIỂU TƯỢNG MENU BAR & ỨNG DỤNG")) {
                Picker("Bộ Icon:", selection: $iconService.selectedType) {
                    ForEach(AppIconType.allCases) { (type: AppIconType) in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                if iconService.selectedType == .custom {
                    HStack {
                        iconService.currentImage
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .cornerRadius(6)
                        
                        Button("Chọn ảnh từ máy...") {
                            iconService.importCustomImage()
                        }
                    }
                }
            }
            
            Section(header: Text("XEM TRƯỚC BIỂU TƯỢNG")) {
                HStack(spacing: 12) {
                    iconService.currentImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundColor(iconService.selectedType.accentColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ToolTrL Menu Bar Icon")
                            .font(.system(size: 13, weight: .bold))
                        Text(iconService.selectedType.rawValue)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - 5. Prompts Settings Form
    private var promptsSettingsForm: some View {
        Form {
            Section {
                ForEach(promptService.prompts) { prompt in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(prompt.icon)
                                Text(prompt.title)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Text(prompt.template)
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
            } header: {
                Text("QUẢN LÝ MẪU CÂU HỎI NHANH (PROMPTS)")
            } footer: {
                Text("Các mẫu câu hỏi sẽ hiển thị trong thanh menu Trợ lý AI khi bạn bôi đen văn bản.")
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - 6. About Form
    private var aboutSettingsForm: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    iconService.currentImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundColor(iconService.selectedType.accentColor)
                    
                    VStack(spacing: 4) {
                        Text("ToolTrL")
                            .font(.system(size: 20, weight: .bold))
                        Text("Phiên bản 1.0.0 (macOS Native)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Ứng dụng tra từ điển, dịch thuật AI đa tầng, bóc tách ngữ pháp và ôn tập thẻ ghi nhớ tối ưu cho hệ điều hành macOS.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            
            Section(header: Text("THÔNG TIN MÃ NGUỒN & TÁC GIẢ")) {
                LabeledContent("Tác giả", value: "Dũng Nguyễn Quốc (QuocDung21)")
                LabeledContent("Bản quyền", value: "Giấy phép mã nguồn mở MIT")
                
                Link(destination: URL(string: "https://github.com/QuocDung21/ToolTrl.git")!) {
                    HStack {
                        Text("Kho mã nguồn GitHub")
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
