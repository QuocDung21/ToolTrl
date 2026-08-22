import SwiftUI
import AppKit

// MARK: - Navigation Items for Main App Window
public enum MainSidebarItem: String, CaseIterable, Identifiable {
    case translator = "Tra từ & Dịch thuật"
    case notebook = "Sổ tay & Ngữ pháp"
    case textAnalysis = "Phân tích đoạn văn"
    case aiAssistant = "Trợ lý AI"
    case settings = "Cài đặt"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .translator: return "character.bubble"
        case .notebook: return "book.closed"
        case .textAnalysis: return "doc.text.magnifyingglass"
        case .aiAssistant: return "bubble.left.and.bubble.right"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Main Application Unified Workspace View
public struct MainDashboardView: View {
    @State private var selectedItem: MainSidebarItem? = .translator
    
    // Translator State
    @State private var inputText: String = ""
    @State private var translatedText: String = ""
    @State private var sourceLang: String = "auto"
    @State private var targetLang: TargetLanguage = .vietnamese
    @State private var isTranslating: Bool = false
    @State private var richEntry: RichWordEntry? = nil
    @State private var isSearchingDictionary: Bool = false
    
    @ObservedObject var vocabService = VocabularyService.shared
    @ObservedObject var speechService = SpeechService.shared
    @ObservedObject var appSettings = AppSettings.shared
    
    public init() {}
    
    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedItem) {
                Section("TÍNH NĂNG") {
                    ForEach(MainSidebarItem.allCases.prefix(4)) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.icon)
                                .font(.system(size: 13))
                        }
                    }
                }
                
                Section("HỆ THỐNG") {
                    NavigationLink(value: MainSidebarItem.settings) {
                        Label(MainSidebarItem.settings.rawValue, systemImage: MainSidebarItem.settings.icon)
                            .font(.system(size: 13))
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            Group {
                switch selectedItem {
                case .translator:
                    nativeTranslatorWorkspace
                case .notebook:
                    VocabularyNotebookView()
                case .textAnalysis:
                    SmartTextAnalysisSheet(initialText: inputText)
                case .aiAssistant:
                    QuickAIAssistantView(initialPrompt: inputText.isEmpty ? nil : inputText, onClose: {})
                case .settings:
                    SettingsView()
                case .none:
                    nativeTranslatorWorkspace
                }
            }
            .navigationTitle(selectedItem?.rawValue ?? "ToolTrL")
        }
        .frame(minWidth: 900, minHeight: 620)
    }
    
    // MARK: - Native Apple Translate Workspace
    private var nativeTranslatorWorkspace: some View {
        VStack(spacing: 0) {
            // Language Control Bar
            HStack {
                Text("Phát hiện tự động")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Picker("", selection: $targetLang) {
                    ForEach(TargetLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 180)
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
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.02))
            
            Divider().opacity(0.2)
            
            // Side-by-Side or Stacked Translation Area
            GeometryReader { geo in
                HStack(spacing: 0) {
                    // Left Input Box
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $inputText)
                            .font(.system(size: 14 + appSettings.appFontSize.scaleDelta))
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .onChange(of: inputText) { _, newValue in
                                debounceTranslation(text: newValue)
                            }
                        
                        HStack {
                            if !inputText.isEmpty {
                                Button(action: {
                                    speechService.speak(text: inputText, languageCode: "en-US", speakerID: "main_input")
                                }) {
                                    Image(systemName: "speaker.wave.2")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.borderless)
                                .help("Nghe phát âm")
                            }
                            
                            Spacer()
                            
                            Text("\(inputText.count) ký tự")
                                .font(.system(size: 10.5))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                    }
                    .frame(width: geo.size.width / 2)
                    
                    Divider().opacity(0.2)
                    
                    // Right Output Box
                    VStack(alignment: .leading, spacing: 8) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                if isTranslating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .padding(.top, 20)
                                } else if !translatedText.isEmpty {
                                    Text(translatedText)
                                        .font(.system(size: 14 + appSettings.appFontSize.scaleDelta, weight: .medium))
                                        .foregroundColor(.primary)
                                        .textSelection(.enabled)
                                        .lineSpacing(3)
                                        .padding(12)
                                    
                                    // Rich Dictionary Entry Details if looking up single word
                                    if let entry = richEntry, !entry.meanings.isEmpty {
                                        VStack(alignment: .leading, spacing: 10) {
                                            if let pho = entry.phonetic, !pho.isEmpty {
                                                Text(pho)
                                                    .font(.system(size: 12, design: .monospaced))
                                                    .foregroundColor(.blue)
                                                    .padding(.horizontal, 12)
                                            }
                                            
                                            ForEach(entry.meanings) { group in
                                                GroupBox {
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        Text(group.partOfSpeechDisplay)
                                                            .font(.system(size: 10.5, weight: .bold))
                                                            .foregroundColor(.secondary)
                                                        
                                                        ForEach(Array(group.definitions.enumerated()), id: \.offset) { _, def in
                                                            VStack(alignment: .leading, spacing: 2) {
                                                                Text("• \(def.definitionEn)")
                                                                    .font(.system(size: 12))
                                                                    .foregroundColor(.primary)
                                                                
                                                                if let defVi = def.definitionVi, !defVi.isEmpty {
                                                                    Text("  = \(defVi)")
                                                                        .font(.system(size: 11))
                                                                        .foregroundColor(.secondary)
                                                                }
                                                            }
                                                            .padding(.vertical, 1)
                                                        }
                                                    }
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .padding(6)
                                                }
                                                .padding(.horizontal, 12)
                                            }
                                        }
                                    }
                                } else {
                                    Text("Bản dịch sẽ hiển thị tại đây...")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary.opacity(0.6))
                                        .padding(12)
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
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.borderless)
                                .help("Sao chép bản dịch")
                                
                                Button(action: {
                                    vocabService.toggleSaveWord(
                                        word: inputText,
                                        phonetic: richEntry?.phonetic,
                                        translation: translatedText
                                    )
                                }) {
                                    Image(systemName: vocabService.isWordSaved(inputText) ? "bookmark.fill" : "bookmark")
                                        .font(.system(size: 12))
                                        .foregroundColor(vocabService.isWordSaved(inputText) ? .yellow : .secondary)
                                }
                                .buttonStyle(.borderless)
                                .help("Lưu vào sổ tay")
                                
                                Button(action: {
                                    speechService.speak(text: translatedText, languageCode: "vi-VN", speakerID: "main_output")
                                }) {
                                    Image(systemName: "speaker.wave.2")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(.borderless)
                                .help("Nghe bản dịch")
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                    }
                    .frame(width: geo.size.width / 2)
                    .background(Color.primary.opacity(0.015))
                }
            }
        }
    }
    
    // MARK: - Debounce & Translation Logic
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
            // 1. Translate sentence / word
            let translation = await TranslationService.shared.translate(
                text: trimmed,
                from: sourceLang,
                to: targetLang.rawValue
            )
            
            // 2. If single word, fetch rich dictionary in parallel
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
