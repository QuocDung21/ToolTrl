import SwiftUI
import WebKit

public struct QuickAIAssistantView: View {
    @ObservedObject var promptService = QuickPromptService.shared
    
    @State private var selectedProvider: AIProvider = .chatgpt
    @State private var webView: WKWebView?
    @State private var isLoading: Bool = false
    @State private var currentPrompt: String = ""
    @State private var injectedPrompt: String? = nil
    @State private var showPromptManager: Bool = false
    
    public let initialPrompt: String?
    public let onClose: () -> Void
    
    public init(initialPrompt: String? = nil, onClose: @escaping () -> Void) {
        self.initialPrompt = initialPrompt
        self.onClose = onClose
        if let initial = initialPrompt, !initial.isEmpty {
            _currentPrompt = State(initialValue: initial)
            _injectedPrompt = State(initialValue: "Hãy giải thích chi tiết, dịch và phân tích ngữ pháp đoạn sau:\n\n\(initial)")
        }
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Unified Single-Row Header Bar
            headerBar
            
            Divider()
                .opacity(0.18)
            
            // Dynamic Quick Prompt Suggestion Bar (if text is present)
            if !currentPrompt.isEmpty {
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 680, minHeight: 600)
        .background(
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
        )
        .ignoresSafeArea()
        .sheet(isPresented: $showPromptManager) {
            QuickPromptManagerSheet()
        }
    }
    
    // MARK: - Unified Single-Row Header Bar
    private var headerBar: some View {
        HStack(alignment: .center, spacing: 8) {
            // Traffic Light Clearance on the exact same row (68px)
            Spacer()
                .frame(width: 72)
            
            // Provider Segmented Tabs
            HStack(spacing: 3) {
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
                        .foregroundColor(selectedProvider == provider ? .white : .primary.opacity(0.7))
                        .background(
                            selectedProvider == provider ? Color.blue : Color.primary.opacity(0.04)
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // Right Action Buttons
            HStack(spacing: 5) {
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
    
    // MARK: - Dynamic Quick Prompt Suggestions Bar
    private var quickPromptBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("Hỏi nhanh:")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 14)
                
                ForEach(promptService.prompts) { item in
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
            if let wv = webView {
                let escaped = prompt
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "\"", with: "\\\"")
                    .replacingOccurrences(of: "\n", with: "\\n")
                    .replacingOccurrences(of: "\r", with: "")
                
                let js = """
                (function() {
                    let el = document.querySelector('#prompt-textarea') || document.querySelector('.ql-editor') || document.querySelector('div[contenteditable="true"]') || document.querySelector('textarea');
                    if (el) {
                        el.focus();
                        if (el.tagName === 'TEXTAREA') {
                            el.value = "\(escaped)";
                        } else {
                            el.innerText = "\(escaped)";
                        }
                        el.dispatchEvent(new Event('input', { bubbles: true }));
                    }
                })();
                """
                wv.evaluateJavaScript(js, completionHandler: nil)
            }
        }) {
            Text(title)
                .font(.system(size: 10.5, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(Color.blue.opacity(0.09))
                .foregroundColor(.blue)
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}
