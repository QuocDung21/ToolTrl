import SwiftUI
import WebKit

public struct QuickAIAssistantView: View {
    @ObservedObject var promptService = QuickPromptService.shared
    @ObservedObject var vocabService = VocabularyService.shared
    
    @State private var selectedProvider: AIProvider = .chatgpt
    @State private var webView: WKWebView?
    @State private var isLoading: Bool = false
    @State private var currentPrompt: String = ""
    @State private var injectedPrompt: String? = nil
    @State private var showPromptManager: Bool = false
    @State private var saveSuccessToast: String? = nil
    
    public let initialPrompt: String?
    public let targetWordId: UUID?
    public let targetWordTitle: String?
    public let onClose: () -> Void
    
    public init(
        initialPrompt: String? = nil,
        targetWordId: UUID? = nil,
        targetWordTitle: String? = nil,
        onClose: @escaping () -> Void
    ) {
        self.initialPrompt = initialPrompt
        self.targetWordId = targetWordId
        self.targetWordTitle = targetWordTitle
        self.onClose = onClose
        if let initial = initialPrompt, !initial.isEmpty {
            _currentPrompt = State(initialValue: initial)
            _injectedPrompt = State(initialValue: initial)
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Unified Single-Row Header Bar
            headerBar
            
            Divider()
                .opacity(0.18)
            
            // Target Word Banner (if specific word is being deeply analyzed)
            if let word = targetWordTitle {
                targetWordBanner(word: word)
                Divider().opacity(0.12)
            }
            
            // Dynamic Quick Prompt Suggestion Bar (if text is present and no target word)
            if !currentPrompt.isEmpty && targetWordTitle == nil {
                quickPromptBar
                Divider().opacity(0.12)
            }
            
            // Web View Container
            ZStack {
                AIWebView(
                    provider: selectedProvider,
                    pendingPrompt: injectedPrompt,
                    webView: $webView,
                    isLoading: $isLoading
                )
                
                if isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(0.85)
                            .padding(10)
                            .background(VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                        Spacer()
                    }
                    .padding(.top, 24)
                    .transition(.opacity)
                }
                
                // Toast notification
                if let toast = saveSuccessToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(toast)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow))
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
                        .padding(.bottom, 24)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 620)
        .background(
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
        )
        .ignoresSafeArea()
        .sheet(isPresented: $showPromptManager) {
            QuickPromptManagerSheet()
        }
    }
    
    // MARK: - Target Word Banner
    private func targetWordBanner(word: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: word.contains("📐") ? "function" : "book.closed")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.blue)
            
            Text("Đang phân tích cho: ")
                .font(.system(size: 11.5))
                .foregroundColor(.secondary) +
            Text("\"\(word)\"")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                saveAnalysisToTargetWord()
            }) {
                Label("Lưu vào sổ tay", systemImage: "square.and.arrow.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .help("Lưu kết quả phân tích cấu trúc của AI vào mục '\(word)' trong Sổ Tay")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.035))
    }
    
    // MARK: - Unified Single-Row Header Bar
    private var headerBar: some View {
        HStack(alignment: .center, spacing: 8) {
            // Traffic Light Clearance
            Spacer()
                .frame(width: 72)
            
            // Provider Segmented Tabs
            HStack(spacing: 4) {
                ForEach(AIProvider.allCases) { provider in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedProvider = provider
                        }
                    }) {
                        HStack(spacing: 5) {
                            Image(systemName: provider.icon)
                                .font(.system(size: 11))
                            Text(provider.rawValue)
                                .font(.system(size: 11.5, weight: selectedProvider == provider ? .bold : .medium))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .foregroundColor(selectedProvider == provider ? .white : .primary.opacity(0.85))
                        .background(
                            selectedProvider == provider ? Color.blue : Color.primary.opacity(0.06)
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // Right Action Buttons
            HStack(spacing: 6) {
                // Extract into Vocabulary Notebook Button
                if targetWordTitle != nil {
                    Button(action: {
                        saveAnalysisToTargetWord()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down.on.square")
                                .font(.system(size: 10.5))
                            Text("Lưu vào Chi Tiết")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Lưu câu trả lời của AI vào chi tiết từ trong Sổ Tay")
                } else {
                    Button(action: {
                        extractAndAnalyzeAIResponse()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down.on.square")
                                .font(.system(size: 10.5))
                            Text("Bóc tách vào Sổ Tay")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4.5)
                        .background(Color.green.opacity(0.12))
                        .foregroundColor(.green)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Dùng AI On-Device để tinh lọc câu trả lời của ChatGPT/Gemini thành từ vựng & ngữ pháp lưu vào Sổ Tay")
                }
                
                // Pin Window Button
                Button(action: {
                    QuickAIWindowController.shared.togglePin()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: QuickAIWindowController.shared.isPinned ? "pin.fill" : "pin")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(6)
                    .background(QuickAIWindowController.shared.isPinned ? Color.orange.opacity(0.18) : Color.primary.opacity(0.06))
                    .foregroundColor(QuickAIWindowController.shared.isPinned ? .orange : .secondary)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help(QuickAIWindowController.shared.isPinned ? "Đang ghim cửa sổ trên cùng (Bấm để bỏ ghim)" : "Ghim cửa sổ trên cùng để giữ phiên chat liên tục")
                
                Button(action: {
                    webView?.reload()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .padding(6)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Tải lại trang")
                
                Button(action: {
                    if let url = webView?.url ?? selectedProvider.baseURL as URL? {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Image(systemName: "safari")
                        .font(.system(size: 11, weight: .medium))
                        .padding(6)
                        .background(Color.primary.opacity(0.06))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Mở trong Safari")
            }
            .padding(.trailing, 14)
        }
        .frame(height: 48)
        .background(Color.primary.opacity(0.03))
    }
    
    // MARK: - Save Analysis Specifically to Target Word
    private func saveAnalysisToTargetWord() {
        guard let wv = webView else { return }
        
        let js = """
        (function() {
            let sel = window.getSelection().toString().trim();
            if (sel.length > 0) return sel;
            
            let gptMsgs = document.querySelectorAll('[data-message-author-role="assistant"]');
            if (gptMsgs.length > 0) {
                return gptMsgs[gptMsgs.length - 1].innerText.trim();
            }
            
            let geminiMsgs = document.querySelectorAll('.model-response-text, message-content, [data-test-id="model-response-text"]');
            if (geminiMsgs.length > 0) {
                return geminiMsgs[geminiMsgs.length - 1].innerText.trim();
            }
            
            let markdowns = document.querySelectorAll('.font-claude-message, .prose, .markdown');
            if (markdowns.length > 0) {
                return markdowns[markdowns.length - 1].innerText.trim();
            }
            
            return document.body.innerText.trim();
        })();
        """
        
        wv.evaluateJavaScript(js) { result, error in
            guard let text = (result as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
                return
            }
            
            if let wordId = targetWordId {
                vocabService.updateAIDetailedAnalysis(wordId: wordId, analysis: text)
            } else if let wordTitle = targetWordTitle {
                vocabService.updateAIDetailedAnalysis(wordTitle: wordTitle, analysis: text)
            }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                saveSuccessToast = "Đã lưu phân tích chi tiết vào Sổ Tay!"
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    saveSuccessToast = nil
                }
            }
        }
    }
    
    // MARK: - Extract and Analyze AI Response with Local AI (General Mode)
    private func extractAndAnalyzeAIResponse() {
        guard let wv = webView else {
            TextAnalysisWindowController.shared.showAnalysis(text: currentPrompt)
            return
        }
        
        let js = """
        (function() {
            let sel = window.getSelection().toString().trim();
            if (sel.length > 0) return sel;
            
            let gptMsgs = document.querySelectorAll('[data-message-author-role="assistant"]');
            if (gptMsgs.length > 0) {
                return gptMsgs[gptMsgs.length - 1].innerText.trim();
            }
            
            let geminiMsgs = document.querySelectorAll('.model-response-text, message-content, [data-test-id="model-response-text"]');
            if (geminiMsgs.length > 0) {
                return geminiMsgs[geminiMsgs.length - 1].innerText.trim();
            }
            
            let markdowns = document.querySelectorAll('.font-claude-message, .prose, .markdown');
            if (markdowns.length > 0) {
                return markdowns[markdowns.length - 1].innerText.trim();
            }
            
            return document.body.innerText.trim();
        })();
        """
        
        wv.evaluateJavaScript(js) { result, error in
            let extracted = (result as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let finalText = extracted.isEmpty ? currentPrompt : extracted
            TextAnalysisWindowController.shared.showAnalysis(text: finalText)
        }
    }
    
    // MARK: - Dynamic Quick Prompt Suggestions Bar
    private var quickPromptBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("Hỏi nhanh:")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 14)
                
                ForEach(promptService.activePrompts) { item in
                    let rendered = promptService.renderPrompt(for: item, text: currentPrompt)
                    promptChip(title: "\(item.icon) \(item.title)", prompt: rendered)
                }
                
                Button(action: {
                    showPromptManager = true
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 9.5))
                        Text("Tùy chỉnh mẫu...")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Color.primary.opacity(0.06))
                    .foregroundColor(.secondary)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Thêm, sửa, hoặc xóa các mẫu câu hỏi nhanh")
            }
            .padding(.vertical, 6)
            .padding(.trailing, 14)
        }
        .background(Color.primary.opacity(0.015))
    }
    
    private func promptChip(title: String, prompt: String) -> some View {
        Button(action: {
            injectedPrompt = prompt
        }) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05))
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}
