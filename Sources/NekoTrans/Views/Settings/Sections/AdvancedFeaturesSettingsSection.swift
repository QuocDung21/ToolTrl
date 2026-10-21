import SwiftUI
import AppKit
import Defaults

public struct AdvancedFeaturesSettingsSection: View {
    @Bindable var settings = AppSettings.shared
    @ObservedObject var hotKeyManager = HotKeyManager.shared
    @ObservedObject var ankiService = AnkiConnectService.shared
    @ObservedObject var appExclusionService = AppExclusionService.shared

    @State private var showPromptSheet: Bool = false
    @State private var isExpandedAIConfig: Bool = false
    @State private var isTestingConnection: Bool = false
    @State private var testStatusMessage: String? = nil
    @State private var testSuccess: Bool = false

    @State private var isTestingAnki: Bool = false
    @State private var ankiStatusMessage: String? = nil
    @State private var ankiSuccess: Bool = false

    @State private var localServerState: LocalAIServerState = .idle
    @State private var discoveredModels: [LocalAIModelInfo] = []
    @State private var isScanningLocalAI: Bool = false
    @State private var selectedBackendType: LocalAIBackendType = .ollama
    @State private var customModelInputMode: Bool = false
    @State private var localHFModels: [LocalAIModelInfo] = []
    @State private var copiedCommandMessage: String? = nil
    
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
                        Text("Phân tích cấu trúc ngữ pháp, ngữ cảnh từ vựng chuyên sâu với ChatGPT/Gemini (\(hotKeyManager.aiDisplayString)).")
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
                Toggle(isOn: $settings.enableInPlaceReplace) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Dịch & Trau chuốt thay thế tại chỗ (In-Place Replace)", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .medium))
                        Text("Bôi đen chữ trong bất kỳ ứng dụng nào và nhấn \(hotKeyManager.translateAndReplaceDisplayString) để dịch đè, hoặc \(hotKeyManager.polishAndReplaceDisplayString) để sửa lỗi AI trực tiếp.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                if settings.enableInPlaceReplace {
                    Toggle(isOn: $settings.inPlaceReplaceSound) {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Âm thanh phản hồi", systemImage: "speaker.wave.2")
                                .font(.system(size: 13, weight: .medium))
                            Text("Phát âm thanh nhẹ khi hoàn tất thay thế văn bản.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("DỊCH & TRAU CHUỐT TẠI CHỖ (IN-PLACE REPLACEMENT)")
            } footer: {
                Text("Tính năng hoạt động trực tiếp qua macOS Accessibility API mà không can thiệp Clipboard của người dùng.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Section {
                Picker("Nhà cung cấp AI mặc định:", selection: $settings.aiProvider) {
                    ForEach(DirectAIProvider.allCases) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                
                DisclosureGroup(isExpanded: $isExpandedAIConfig) {
                    VStack(alignment: .leading, spacing: 10) {
                        if settings.aiProvider != .ollama {
                            TextField("Model AI tùy chỉnh (để trống để dùng mặc định):", text: $settings.customAIModel)
                                .textFieldStyle(.roundedBorder)
                        }
                        
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
                            VStack(alignment: .leading, spacing: 8) {
                                // 1. Apple Silicon Hardware Acceleration Badge
                                HStack(spacing: 6) {
                                    Image(systemName: "cpu.fill")
                                        .foregroundColor(.cyan)
                                    Text("Apple Silicon Metal & Neural Engine (\(LocalAIService.shared.appleSiliconChipName))")
                                        .font(.system(size: 11, weight: .semibold))
                                    Spacer()
                                    Text("100% Cục bộ • Miễn phí")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .padding(8)
                                .background(Color.cyan.opacity(0.08))
                                .cornerRadius(6)

                                // 2. Live Server Status Banner
                                HStack(spacing: 8) {
                                    if isScanningLocalAI {
                                        ProgressView().controlSize(.small)
                                        Text("Đang dò tìm máy chủ Local AI...")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    } else {
                                        switch localServerState {
                                        case .online(let backend, let models):
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("\(backend.rawValue) Online: Phát hiện \(models.count) mô hình")
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(.green)
                                        case .offline:
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                            Text("Chưa phát hiện máy chủ Local AI")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        case .idle, .checking:
                                            Image(systemName: "circle")
                                                .foregroundColor(.secondary)
                                            Text("Sẵn sàng kiểm tra")
                                                .font(.system(size: 11))
                                                .foregroundColor(.secondary)
                                        }
                                    }

                                    Spacer()

                                    Button(action: scanLocalAI) {
                                        Label("Dò tìm / Quét lại", systemImage: "arrow.clockwise")
                                            .font(.system(size: 11))
                                    }
                                    .buttonStyle(.borderless)
                                    .disabled(isScanningLocalAI)
                                }

                                // 3. Endpoint Presets
                                Picker("Máy chủ Local:", selection: $selectedBackendType) {
                                    ForEach(LocalAIBackendType.allCases) { b in
                                        Text(b.shortDescription).tag(b)
                                    }
                                }
                                .pickerStyle(.menu)
                                .onChange(of: selectedBackendType) { _, newBackend in
                                    if newBackend != .custom {
                                        settings.ollamaEndpoint = newBackend.defaultEndpoint
                                        scanLocalAI()
                                    }
                                }

                                if selectedBackendType == .custom {
                                    TextField("Endpoint tùy chỉnh:", text: $settings.ollamaEndpoint)
                                        .textFieldStyle(.roundedBorder)
                                }

                                // 4. Discovered Models Picker / Input
                                if !discoveredModels.isEmpty && !customModelInputMode {
                                    HStack {
                                        Picker("Mô hình AI trên máy:", selection: $settings.customAIModel) {
                                            Text("Mặc định (\(discoveredModels.first?.name ?? DirectAIProvider.ollama.defaultModel))").tag("")
                                            Divider()
                                            ForEach(discoveredModels) { m in
                                                Text(m.displayName).tag(m.name)
                                            }
                                        }
                                        .pickerStyle(.menu)

                                        Button(action: { customModelInputMode = true }) {
                                            Image(systemName: "pencil")
                                        }
                                        .buttonStyle(.borderless)
                                        .help("Tự gõ tên model khác")
                                    }
                                } else {
                                    HStack {
                                        TextField("Tên mô hình (vd: llama3.2, qwen2.5:7b, deepseek-r1):", text: $settings.customAIModel)
                                            .textFieldStyle(.roundedBorder)

                                        if !discoveredModels.isEmpty {
                                            Button("Chọn từ danh sách") {
                                                customModelInputMode = false
                                            }
                                            .font(.system(size: 11))
                                        }
                                    }

                                    Text("💡 Gợi ý: Khởi động Ollama hoặc chạy lệnh `ollama run llama3.2` trong Terminal.")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                }

                                // 5. Local Hugging Face Cache Models
                                if !localHFModels.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Label("Phát hiện \(localHFModels.count) mô hình Hugging Face trên máy:", systemImage: "shippingbox.fill")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundColor(.purple)
                                            Spacer()
                                        }

                                        ForEach(localHFModels) { hf in
                                            let isSelected = settings.customAIModel == hf.name
                                            HStack(spacing: 8) {
                                                Image(systemName: isSelected ? "checkmark.seal.fill" : "cube.transparent.fill")
                                                    .foregroundColor(isSelected ? .green : .purple)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    HStack(spacing: 4) {
                                                        Text(hf.name)
                                                            .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                                        if isSelected {
                                                            Text("ĐANG CHỌN")
                                                                .font(.system(size: 8.5, weight: .bold))
                                                                .padding(.horizontal, 4)
                                                                .padding(.vertical, 1)
                                                                .background(Color.green.opacity(0.18))
                                                                .foregroundColor(.green)
                                                                .cornerRadius(3)
                                                        }
                                                    }
                                                    HStack(spacing: 4) {
                                                        if let arch = hf.parameterSize {
                                                            Text(arch)
                                                                .font(.system(size: 9.5))
                                                                .foregroundColor(.secondary)
                                                        }
                                                        if let size = hf.formattedSize {
                                                            Text("• \(size)")
                                                                .font(.system(size: 9.5))
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                }

                                                Spacer()

                                                if isSelected {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 10, weight: .bold))
                                                        Text("Đã kích hoạt")
                                                            .font(.system(size: 10.5, weight: .semibold))
                                                    }
                                                    .foregroundColor(.green)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                } else {
                                                    Button("Sử dụng") {
                                                        settings.customAIModel = hf.name
                                                        selectedBackendType = .mlxOrLocalAI
                                                        settings.ollamaEndpoint = LocalAIBackendType.mlxOrLocalAI.defaultEndpoint
                                                    }
                                                    .buttonStyle(.bordered)
                                                    .controlSize(.small)
                                                }

                                                Button(action: {
                                                    let cmd = "python3 -m mlx_lm.server --model \(hf.name) --port 8080"
                                                    NSPasteboard.general.clearContents()
                                                    NSPasteboard.general.setString(cmd, forType: .string)
                                                    copiedCommandMessage = "Đã sao chép: \(cmd)"
                                                }) {
                                                    Image(systemName: "doc.on.doc")
                                                }
                                                .buttonStyle(.borderless)
                                                .help("Sao chép lệnh chạy MLX Server cho \(hf.name)")
                                            }
                                            .padding(6)
                                            .background(isSelected ? Color.green.opacity(0.08) : Color.purple.opacity(0.05))
                                            .cornerRadius(6)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(isSelected ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1)
                                            )
                                        }

                                        if let copiedMsg = copiedCommandMessage {
                                            Text(copiedMsg)
                                                .font(.system(size: 10.5))
                                                .foregroundColor(.green)
                                        }

                                        if case .offline = localServerState {
                                            HStack(alignment: .top, spacing: 6) {
                                                Image(systemName: "info.circle.fill")
                                                    .foregroundColor(.orange)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text("Máy chủ Local AI (\(selectedBackendType.rawValue)) hiện chưa được bật!")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundColor(.orange)
                                                    Text("Để dịch bằng mô hình Hugging Face này, hãy mở Terminal và dán lệnh khởi chạy (bấm icon 📋 bên phải mô hình). Khi máy chủ chưa bật, NekoTrans sẽ tạm chuyển sang dịch tự động để không ngắt quãng công việc.")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .padding(8)
                                            .background(Color.orange.opacity(0.08))
                                            .cornerRadius(6)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }
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
                        Text("Khoanh vùng màn hình để quét và nhận diện chữ bằng Apple Vision (\(hotKeyManager.ocrDisplayString)).")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("CÔNG CỤ MÀN HÌNH")
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
                        Text("Hiển thị lối tắt mở nhanh Sổ tay lưu trữ từ vựng (\(hotKeyManager.notebookDisplayString)).")
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

            // ── ANKICONNECT (1-CLICK DIRECT ANKI SYNC) ──
            Section {
                Toggle(isOn: Binding(
                    get: { Defaults[.enableAnkiConnect] },
                    set: { Defaults[.enableAnkiConnect] = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Đồng bộ Anki Desktop (AnkiConnect)", systemImage: "square.stack.3d.up.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Kết nối trực tiếp cổng AnkiConnect (8765) để tạo thẻ từ vựng vào Anki 1-click.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                if Defaults[.enableAnkiConnect] {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("Địa chỉ AnkiConnect:", text: Binding(
                                get: { Defaults[.ankiConnectEndpoint] },
                                set: { Defaults[.ankiConnectEndpoint] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)

                            Button(action: testAnkiConnection) {
                                HStack(spacing: 4) {
                                    if isTestingAnki {
                                        ProgressView().scaleEffect(0.5).frame(width: 10, height: 10)
                                    }
                                    Text("Kiểm tra")
                                }
                            }
                            .disabled(isTestingAnki)
                        }

                        if let msg = ankiStatusMessage {
                            Text(msg)
                                .font(.system(size: 11))
                                .foregroundColor(ankiSuccess ? .green : .red)
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Bộ thẻ (Deck):")
                                    .font(.system(size: 11, weight: .medium))
                                if ankiService.availableDecks.isEmpty {
                                    TextField("Tên Deck:", text: Binding(
                                        get: { Defaults[.ankiConnectDeck] },
                                        set: { Defaults[.ankiConnectDeck] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                } else {
                                    Picker("", selection: Binding(
                                        get: { Defaults[.ankiConnectDeck] },
                                        set: { Defaults[.ankiConnectDeck] = $0 }
                                    )) {
                                        ForEach(ankiService.availableDecks, id: \.self) { deck in
                                            Text(deck).tag(deck)
                                        }
                                    }
                                    .labelsHidden()
                                }
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Kiểu thẻ (Model):")
                                    .font(.system(size: 11, weight: .medium))
                                if ankiService.availableModels.isEmpty {
                                    TextField("Tên Model:", text: Binding(
                                        get: { Defaults[.ankiConnectModel] },
                                        set: { Defaults[.ankiConnectModel] = $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                } else {
                                    Picker("", selection: Binding(
                                        get: { Defaults[.ankiConnectModel] },
                                        set: { Defaults[.ankiConnectModel] = $0 }
                                    )) {
                                        ForEach(ankiService.availableModels, id: \.self) { model in
                                            Text(model).tag(model)
                                        }
                                    }
                                    .labelsHidden()
                                }
                            }
                        }

                        Toggle("Tự động đồng bộ sang Anki khi bấm Lưu từ (⌘S)", isOn: Binding(
                            get: { Defaults[.ankiAutoSyncOnBookmark] },
                            set: { Defaults[.ankiAutoSyncOnBookmark] = $0 }
                        ))
                        .font(.system(size: 12))
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("ANKI FLASHCARD (ANKICONNECT)")
            } footer: {
                Text("Yêu cầu ứng dụng Anki Desktop đang mở và đã cài đặt add-on AnkiConnect (Mã: 2055492159).")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            // ── CONTINUOUS AUTO-JOURNALING (words.jsonl) ──
            Section {
                Toggle(isOn: Binding(
                    get: { Defaults[.enableContinuousJournal] },
                    set: { Defaults[.enableContinuousJournal] = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Nhật ký tra cứu tự động (words.jsonl)", systemImage: "doc.text.below.ecg.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Tự động ghi lại mọi từ và câu đã dịch vào tệp JSON Lines để đồng bộ với Obsidian, Logseq hoặc AI data pipelines.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                if Defaults[.enableContinuousJournal] {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Đường dẫn tệp nhật ký:")
                                    .font(.system(size: 11, weight: .medium))
                                Text(ContinuousJournalService.shared.journalFileURL.path)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Button("Mở trong Finder") {
                                let url = ContinuousJournalService.shared.journalFileURL
                                let dir = url.deletingLastPathComponent()
                                if !FileManager.default.fileExists(atPath: dir.path) {
                                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                                }
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                            .font(.system(size: 11))

                            Button("Đổi thư mục...") {
                                chooseJournalDirectory()
                            }
                            .font(.system(size: 11))
                        }
                    }
                    .padding(.vertical, 3)
                }
            } header: {
                Text("NHẬT KÝ TRA CỨU TỰ ĐỘNG (OBSIDIAN / LOGSEQ INTEGRATION)")
            }

            // ── APP EXCLUSION & SILENT MODE ──
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tắt bong bóng dịch và phím tắt thay thế trong các ứng dụng này để tránh gián đoạn trải nghiệm (Figma, Photoshop, Terminal, Game):")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    ForEach(appExclusionService.excludedBundleIDs, id: \.self) { bundleID in
                        let appInfo = appExclusionService.resolveAppInfo(for: bundleID)
                        HStack(spacing: 8) {
                            if let icon = appInfo.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                            } else {
                                Image(systemName: "app.dashed")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(appInfo.name)
                                    .font(.system(size: 12, weight: .medium))
                                Text(bundleID)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: {
                                appExclusionService.removeExcludedApp(bundleIdentifier: bundleID)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help("Xóa ứng dụng khỏi danh sách loại trừ")
                        }
                        .padding(.vertical, 2)
                    }

                    // Add application dropdown
                    Menu {
                        let running = appExclusionService.getRunningApplications().filter { app in
                            !appExclusionService.isAppExcluded(bundleIdentifier: app.bundleIdentifier)
                        }
                        ForEach(running) { app in
                            Button(action: {
                                appExclusionService.addExcludedApp(bundleIdentifier: app.bundleIdentifier)
                            }) {
                                HStack {
                                    Text(app.name)
                                    Text("(\(app.bundleIdentifier))")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Thêm ứng dụng đang mở...")
                        }
                        .font(.system(size: 11.5))
                    }
                    .menuStyle(.borderlessButton)
                    .padding(.top, 4)
                }
            } header: {
                Text("ỨNG DỤNG LOẠI TRỪ & CHẾ ĐỘ IM LẶNG (APP EXCLUSION)")
            }

            // ── HUD MULTI-ENGINE STACK ──
            Section {
                Toggle(isOn: Binding(
                    get: { Defaults[.enableHUDMultiEngine] },
                    set: { Defaults[.enableHUDMultiEngine] = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Hiển thị so sánh đa công cụ trong HUD", systemImage: "square.split.2x1.fill")
                            .font(.system(size: 13, weight: .medium))
                        Text("Tự động hiển thị song song kết quả từ Google Translate, DeepL và AI cùng lúc trong cửa sổ HUD.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("HUD SO SÁNH ĐA CÔNG CỤ (MULTI-ENGINE STACK)")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            syncSelectedBackendType()
            if settings.aiProvider == .ollama {
                scanLocalAI()
            }
        }
        .onChange(of: settings.aiProvider) { _, newProvider in
            if newProvider == .ollama {
                scanLocalAI()
            }
        }
    }

    private func syncSelectedBackendType() {
        let ep = settings.ollamaEndpoint
        if ep.contains(":11434") {
            selectedBackendType = .ollama
        } else if ep.contains(":1234") {
            selectedBackendType = .lmStudio
        } else if ep.contains(":8080") {
            selectedBackendType = .mlxOrLocalAI
        } else {
            selectedBackendType = .custom
        }
    }

    private func scanLocalAI() {
        isScanningLocalAI = true
        self.localHFModels = LocalAIService.shared.scanHuggingFaceLocalCache()
        Task {
            let state = await LocalAIService.shared.checkHealth(endpoint: settings.ollamaEndpoint)
            await MainActor.run {
                self.localServerState = state
                if case .online(_, let models) = state {
                    self.discoveredModels = models
                    self.isScanningLocalAI = false
                    if self.settings.customAIModel.isEmpty, let first = models.first {
                        self.settings.customAIModel = first.name
                    }
                } else {
                    // Try auto-detecting on standard local AI ports (11434, 1234, 8080)
                    Task {
                        if let detected = await LocalAIService.shared.autoDetectLocalServer() {
                            await MainActor.run {
                                self.settings.ollamaEndpoint = detected.endpoint
                                self.selectedBackendType = detected.backend
                                self.discoveredModels = detected.models
                                self.localServerState = .online(backend: detected.backend, models: detected.models)
                                self.isScanningLocalAI = false
                                if self.settings.customAIModel.isEmpty, let first = detected.models.first {
                                    self.settings.customAIModel = first.name
                                }
                            }
                        } else {
                            await MainActor.run {
                                self.isScanningLocalAI = false
                            }
                        }
                    }
                }
            }
        }
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

    private func testAnkiConnection() {
        isTestingAnki = true
        ankiStatusMessage = nil

        Task {
            let res = await ankiService.checkConnection()
            await MainActor.run {
                isTestingAnki = false
                ankiSuccess = res.connected
                ankiStatusMessage = res.connected ? "✅ \(res.message)" : "❌ \(res.message)"
            }
        }
    }

    private func chooseJournalDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Chọn thư mục"
        panel.message = "Chọn thư mục lưu tệp nhật ký tra cứu words.jsonl"

        if panel.runModal() == .OK, let url = panel.url {
            Defaults[.journalDirectoryPath] = url.path
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
