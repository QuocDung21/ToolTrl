import SwiftUI
import AppKit
import Defaults

public struct AdvancedFeaturesSettingsSection: View {
    @ObservedObject var settings = AppSettings.shared
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
