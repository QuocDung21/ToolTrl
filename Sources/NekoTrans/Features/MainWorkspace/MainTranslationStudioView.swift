import SwiftUI
import AppKit
#if canImport(Translation)
import Translation
#endif

public struct MainTranslationStudioView: View {
    @StateObject private var vm = TranslationViewModel()
    @ObservedObject var settings = AppSettings.shared
    @State private var inputDebounceTask: Task<Void, Never>? = nil
    @State private var showCopiedAlert: Bool = false
    @State private var showHistorySheet: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Pinned Sticky Language Bar & Engine Toolbar
            translationControlBar
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(VisualEffectBackground(material: .headerView, blendingMode: .behindWindow))
            
            Divider()
                .opacity(0.3)
            
            ScrollView {
                VStack(spacing: 18) {
                    // 2. The Unified Two-Pane Canvas
                    twoPaneCanvas
                        .frame(minHeight: 330)
                    
                    // 3. Smart Lexical & Dictionary Inspector (Automatically appears for words/phrases)
                    if let entry = vm.richEntry {
                        RichDictionaryCardView(entry: entry)
                    } else if let def = vm.definition, !def.isEmpty {
                        simpleDefinitionCard(def: def)
                    }
                }
                .padding(24)
            }
        }
        .background(VisualEffectBackground(material: .contentBackground, blendingMode: .behindWindow))
        .sheet(isPresented: $showHistorySheet) {
            TranslationHistorySheet(viewModel: vm)
        }
        #if canImport(Translation)
        .modifier(TranslationModifier(viewModel: vm))
        #endif
        .onAppear {
            if !vm.originalText.isEmpty {
                vm.updateTranslation()
            }
        }
    }
    
    // MARK: - 1. Language & Options Header Bar
    private var translationControlBar: some View {
        HStack(spacing: 12) {
            // Source Language Selector
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13))
                
                Text(vm.detectedLanguage.uppercased())
                    .font(.appCaptionBold.monospaced())
                
                Text("(Tự động nhận diện)")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
            )
            
            // Swap Languages Button
            Button(action: {
                if !vm.translatedText.isEmpty {
                    let prevTarget = vm.translatedText
                    vm.originalText = prevTarget
                    vm.processText(prevTarget)
                }
            }) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Đổi chiều dịch")
            
            // Target Language Picker
            Picker("", selection: $vm.targetLanguage) {
                ForEach(TargetLanguage.allCases) { lang in
                    Text(lang.displayName).tag(lang)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 155)
            
            Spacer()
            
            // Unified Translation Options Menu
            Menu {
                Section("ĐỘNG CƠ DỊCH") {
                    ForEach(TranslationEngine.allCases) { engine in
                        Button(action: { vm.selectedEngine = engine }) {
                            HStack {
                                Text(engine.rawValue)
                                if vm.selectedEngine == engine {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Section("VĂN PHONG DỊCH") {
                    ForEach(TranslationTone.allCases) { tone in
                        Button(action: { vm.translationTone = tone }) {
                            HStack {
                                Text(tone.rawValue)
                                if vm.translationTone == tone {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Section("CHUYÊN NGÀNH") {
                    ForEach(TranslationDomain.allCases) { domain in
                        Button(action: { settings.translationDomain = domain }) {
                            HStack {
                                Text(domain.rawValue)
                                if settings.translationDomain == domain {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                
                Section("CHẾ ĐỘ HIỂN THỊ") {
                    ForEach(TranslationDisplayMode.allCases) { mode in
                        Button(action: { settings.translationDisplayMode = mode }) {
                            HStack {
                                Text(mode.rawValue)
                                if settings.translationDisplayMode == mode {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.accentColor)
                    Text("\(vm.selectedEngine.rawValue) • \(vm.translationTone.rawValue)")
                        .font(.appCaptionMedium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .menuStyle(.borderedButton)
            
            // History Button
            Button(action: {
                showHistorySheet = true
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12))
                    Text("Lịch sử")
                        .font(.appCaptionMedium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .help("Xem lịch sử các bản dịch gần đây")
        }
    }
    
    // MARK: - 2. The Unified Two-Pane Canvas
    private var twoPaneCanvas: some View {
        HStack(spacing: 0) {
            // Left: Source Editor Pane
            VStack(alignment: .leading, spacing: 0) {
                // Source Header
                HStack {
                    Text("VĂN BẢN GỐC")
                        .font(.appCaptionBold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    let words = vm.originalText.split { $0.isWhitespace || $0.isNewline }.count
                    let chars = vm.originalText.count
                    Text("\(words) từ • \(chars) ký tự")
                        .font(.appCaption.monospaced())
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 8)
                
                // Text Input Area
                ZStack(alignment: .topLeading) {
                    TextEditor(text: Binding(
                        get: { vm.originalText },
                        set: { newText in
                            vm.originalText = newText
                            triggerDebouncedTranslation(newText)
                        }
                    ))
                    .font(.appHeadline)
                    .lineSpacing(5)
                    .padding(.horizontal, 14)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    
                    if vm.originalText.isEmpty {
                        Text("Nhập hoặc dán văn bản tiếng Anh cần dịch vào đây...")
                            .font(.appHeadline)
                            .foregroundColor(.secondary.opacity(0.55))
                            .padding(.horizontal, 18)
                            .padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                
                Divider()
                    .opacity(0.4)
                
                // Source Bottom Actions
                HStack(spacing: 12) {
                    Button(action: {
                        if let clip = NSPasteboard.general.string(forType: .string), !clip.isEmpty {
                            vm.originalText = clip
                            vm.processText(clip)
                        }
                    }) {
                        Label("Dán", systemImage: "doc.on.clipboard")
                            .font(.appCaption)
                    }
                    .buttonStyle(.borderless)
                    
                    Button(action: {
                        vm.speakOriginal()
                    }) {
                        Label("Nghe đọc", systemImage: "speaker.wave.2")
                            .font(.appCaption)
                    }
                    .buttonStyle(.borderless)
                    .disabled(vm.originalText.isEmpty)
                    
                    Spacer()
                    
                    if !vm.originalText.isEmpty {
                        Button(action: {
                            vm.originalText = ""
                            vm.translatedText = ""
                            vm.richEntry = nil
                            vm.definition = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Xóa văn bản")
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Vertical Hairline Divider
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.4))
                .frame(width: 1)
            
            // Right: Target Translation Result Pane
            VStack(alignment: .leading, spacing: 0) {
                // Target Header
                HStack {
                    Text("BẢN DỊCH (\(vm.targetLanguage.displayName.uppercased()))")
                        .font(.appCaptionBold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if vm.isLoading && !vm.isStreaming {
                        ProgressView()
                            .controlSize(.small)
                    } else if vm.isStreaming {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.6)
                            Text("AI Streaming")
                                .font(.appSubcaptionBold)
                                .foregroundColor(.purple)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Color.purple.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 8)
                
                // Translated Text Area
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if vm.translatedText.isEmpty {
                            Text(vm.isLoading ? "Đang xử lý bản dịch..." : "Bản dịch sẽ xuất hiện tại đây khi bạn nhập văn bản.")
                                .font(.appHeadline)
                                .foregroundColor(.secondary.opacity(0.55))
                                .italic()
                        } else {
                            Text(vm.translatedText)
                                .font(.appHeadline)
                                .lineSpacing(5.5)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                    .opacity(0.4)
                
                // Target Bottom Actions
                HStack(spacing: 12) {
                    Button(action: {
                        vm.copyTranslation()
                        showCopiedAlert = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopiedAlert = false
                        }
                    }) {
                        Label(showCopiedAlert ? "Đã sao chép!" : "Sao chép", systemImage: showCopiedAlert ? "checkmark" : "doc.on.doc")
                            .font(.appCaption)
                            .foregroundColor(showCopiedAlert ? .green : .primary)
                    }
                    .buttonStyle(.borderless)
                    .disabled(vm.translatedText.isEmpty)
                    
                    Button(action: {
                        vm.speakTranslated()
                    }) {
                        Label("Nghe phát âm", systemImage: "speaker.wave.2")
                            .font(.appCaption)
                    }
                    .buttonStyle(.borderless)
                    .disabled(vm.translatedText.isEmpty)
                    
                    Spacer()
                    
                    Button(action: {
                        vm.toggleBookmark()
                    }) {
                        Label(
                            vm.isBookmarked ? "Đã lưu Sổ tay" : "Lưu vào Sổ tay",
                            systemImage: vm.isBookmarked ? "bookmark.fill" : "bookmark"
                        )
                        .font(.appCaptionBold)
                        .foregroundColor(vm.isBookmarked ? .orange : .white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(vm.isBookmarked ? .orange : .accentColor)
                    .disabled(vm.originalText.isEmpty)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.primary.opacity(0.012))
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
    }
    
    private func simpleDefinitionCard(def: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Từ điển định nghĩa", systemImage: "book.closed")
                .font(.appHeadlineBold)
                .foregroundColor(.blue)
            
            Text(def)
                .font(.appBody)
                .lineSpacing(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }
    
    private func triggerDebouncedTranslation(_ text: String) {
        inputDebounceTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            vm.translatedText = ""
            vm.richEntry = nil
            vm.definition = nil
            return
        }
        
        inputDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                vm.processText(trimmed)
            }
        }
    }
}

// MARK: - Dedicated Rich Dictionary Subviews
private struct RichDictionaryCardView: View {
    let entry: RichWordEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerView
            Divider().opacity(0.3)
            meaningsList
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, y: 2)
    }
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "character.book.closed.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 18))
            
            Text(entry.word)
                .font(.appTitleMedium)
            
            if let phonetic = entry.phonetic, !phonetic.isEmpty {
                Text(phonetic)
                    .font(.appPhonetic)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(6)
            }
            
            if let usAudio = entry.usAudioURL {
                Button(action: {
                    AudioPlayerService.shared.playAudio(from: usAudio, fallbackText: entry.word, fallbackVoiceCode: "en-US")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("🇺🇸 US")
                    }
                    .font(.appCaptionBold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            if let ukAudio = entry.ukAudioURL {
                Button(action: {
                    AudioPlayerService.shared.playAudio(from: ukAudio, fallbackText: entry.word, fallbackVoiceCode: "en-GB")
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                        Text("🇬🇧 UK")
                    }
                    .font(.appCaptionBold)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            
            Spacer()
        }
    }
    
    private var meaningsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(entry.meanings) { meaning in
                MeaningGroupView(meaning: meaning)
            }
        }
    }
}

private struct MeaningGroupView: View {
    let meaning: MeaningGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(meaning.partOfSpeechDisplay)
                .font(.appSubcaptionBold)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(5)
            
            ForEach(meaning.definitions) { def in
                DefinitionRowView(def: def)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct DefinitionRowView: View {
    let def: DefinitionItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("• \(def.definitionEn)")
                .font(.appBody)
                .lineSpacing(2)
            
            if let defVi = def.definitionVi, !defVi.isEmpty {
                Text(defVi)
                    .font(.appBodyMedium)
                    .foregroundColor(.accentColor)
                    .padding(.leading, 12)
            }
            
            if let example = def.exampleEn, !example.isEmpty {
                Text("\"\(example)\"")
                    .font(.appExample)
                    .italic()
                    .foregroundColor(.secondary)
                    .padding(.leading, 12)
            }
        }
    }
}
