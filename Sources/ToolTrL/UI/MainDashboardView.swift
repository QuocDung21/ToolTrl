import SwiftUI
import AppKit

// MARK: - Main Application Navigation Modes
public enum MainAppTab: String, CaseIterable, Identifiable {
    case notebook = "Sổ tay & Ngữ pháp"
    case translator = "Dịch & Tra từ điển"
    case textAnalysis = "Phân tích đoạn văn"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .notebook: return "book.closed"
        case .translator: return "character.bubble"
        case .textAnalysis: return "doc.text.magnifyingglass"
        }
    }
}

// MARK: - Main Application Responsive Workspace
public struct MainDashboardView: View {
    @State private var selectedTab: MainAppTab = .notebook
    
    // Translator State
    @State private var inputText: String = ""
    @State private var translatedText: String = ""
    @State private var sourceLang: String = "auto"
    @State private var targetLang: TargetLanguage = .vietnamese
    @State private var isTranslating: Bool = false
    @State private var richEntry: RichWordEntry? = nil
    
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var speechService = SpeechService.shared
    @ObservedObject var appSettings = AppSettings.shared
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Unified Top macOS Toolbar Header
            topToolbarHeader
            
            Divider().opacity(0.18)
            
            // Dynamic Responsive Content Area (Zero Double-Nesting)
            Group {
                switch selectedTab {
                case .notebook:
                    VocabularyNotebookView()
                case .translator:
                    responsiveTranslatorWorkspace
                case .textAnalysis:
                    SmartTextAnalysisSheet(initialText: inputText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 780, minHeight: 520)
        .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow))
    }
    
    // MARK: - Top macOS Toolbar Header
    private var topToolbarHeader: some View {
        HStack(spacing: 12) {
            // Segmented Workspace Switcher
            Picker("", selection: $selectedTab) {
                ForEach(MainAppTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 440)
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: {
                    QuickAIWindowController.shared.showAI(prompt: inputText.isEmpty ? nil : inputText)
                }) {
                    Label("Trợ lý AI", systemImage: "bubble.left.and.bubble.right")
                        .font(.system(size: 11.5))
                }
                .buttonStyle(.borderless)
                
                Button(action: {
                    SettingsWindowController.shared.showSettings()
                }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Cài đặt")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.02))
    }
    
    // MARK: - Responsive Side-by-Side Translator Workspace
    private var responsiveTranslatorWorkspace: some View {
        VStack(spacing: 0) {
            // Language Selector Bar
            HStack {
                Text("Phát hiện tự động")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(5)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.6))
                
                Picker("", selection: $targetLang) {
                    ForEach(TargetLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 170)
                .onChange(of: targetLang) { _, _ in
                    performTranslation()
                }
                
                Spacer()
                
                if !inputText.isEmpty {
                    Button(action: {
                        inputText = ""
                        translatedText = ""
                        richEntry = nil
                    }) {
                        Label("Xóa", systemImage: "xmark.circle")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.015))
            
            Divider().opacity(0.15)
            
            // Flexible 50/50 Split View (No Hardcoded GeometryReader)
            HStack(spacing: 0) {
                // Left Panel: Source Text Editor
                VStack(alignment: .leading, spacing: 6) {
                    TextEditor(text: $inputText)
                        .font(.system(size: 13.5 + appSettings.appFontSize.scaleDelta))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .onChange(of: inputText) { _, newValue in
                            debounceTranslation(text: newValue)
                        }
                    
                    HStack {
                        if !inputText.isEmpty {
                            Button(action: {
                                speechService.speak(text: inputText, languageCode: "en-US", speakerID: "main_input")
                            }) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.system(size: 11.5))
                            }
                            .buttonStyle(.borderless)
                            .help("Nghe phát âm")
                        }
                        
                        Spacer()
                        
                        Text("\(inputText.count) ký tự")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider().opacity(0.2)
                
                // Right Panel: Result & Rich Dictionary Details
                VStack(alignment: .leading, spacing: 6) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if isTranslating {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.75)
                                    Text("Đang dịch...")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                            } else if !translatedText.isEmpty {
                                Text(translatedText)
                                    .font(.system(size: 13.5 + appSettings.appFontSize.scaleDelta, weight: .medium))
                                    .foregroundColor(.primary)
                                    .textSelection(.enabled)
                                    .lineSpacing(3)
                                    .padding(10)
                                
                                // Rich Dictionary Definitions
                                if let entry = richEntry, !entry.meanings.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        if let pho = entry.phonetic, !pho.isEmpty {
                                            Text(pho)
                                                .font(.system(size: 11.5, design: .monospaced))
                                                .foregroundColor(.blue)
                                                .padding(.horizontal, 10)
                                        }
                                        
                                        ForEach(entry.meanings) { group in
                                            GroupBox {
                                                VStack(alignment: .leading, spacing: 5) {
                                                    Text(group.partOfSpeechDisplay)
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(.secondary)
                                                    
                                                    ForEach(Array(group.definitions.enumerated()), id: \.offset) { _, def in
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text("• \(def.definitionEn)")
                                                                .font(.system(size: 11.5))
                                                                .foregroundColor(.primary)
                                                            
                                                            if let defVi = def.definitionVi, !defVi.isEmpty {
                                                                Text("  = \(defVi)")
                                                                    .font(.system(size: 10.5))
                                                                    .foregroundColor(.secondary)
                                                            }
                                                        }
                                                        .padding(.vertical, 1)
                                                    }
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(4)
                                            }
                                            .padding(.horizontal, 10)
                                        }
                                    }
                                }
                            } else {
                                Text("Bản dịch sẽ hiển thị tại đây...")
                                    .font(.system(size: 12.5))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(10)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    HStack {
                        if !translatedText.isEmpty {
                            Button(action: {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(translatedText, forType: .string)
                            }) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11.5))
                            }
                            .buttonStyle(.borderless)
                            .help("Sao chép")
                            
                            Button(action: {
                                vocabService.toggleSaveWord(
                                    word: inputText,
                                    phonetic: richEntry?.phonetic,
                                    translation: translatedText
                                )
                            }) {
                                Image(systemName: vocabService.isWordSaved(inputText) ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(vocabService.isWordSaved(inputText) ? .yellow : .secondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Lưu vào sổ tay")
                            
                            Button(action: {
                                speechService.speak(text: translatedText, languageCode: "vi-VN", speakerID: "main_output")
                            }) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.system(size: 11.5))
                            }
                            .buttonStyle(.borderless)
                            .help("Nghe bản dịch")
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.012))
            }
        }
    }
    
    // MARK: - Translation Logic
    @State private var searchTask: Task<Void, Never>? = nil
    
    private func debounceTranslation(text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            translatedText = ""
            richEntry = nil
            return
        }
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
            if !Task.isCancelled {
                await MainActor.run {
                    performTranslation()
                }
            }
        }
    }
    
    private func performTranslation() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isTranslating = true
        
        Task {
            let translation = await TranslationService.shared.translate(
                text: trimmed,
                from: sourceLang,
                to: targetLang.rawValue
            )
            
            let isSingleWord = !trimmed.contains(" ") && trimmed.count < 30
            var fetchedEntry: RichWordEntry? = nil
            if isSingleWord {
                fetchedEntry = await SmartDictionaryService.shared.fetchRichEntry(
                    for: trimmed,
                    targetLanguage: targetLang.rawValue
                )
            }
            
            await MainActor.run {
                self.translatedText = translation ?? ""
                self.richEntry = fetchedEntry
                self.isTranslating = false
            }
        }
    }
}
