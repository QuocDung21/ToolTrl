import SwiftUI
import WebKit

public struct QuickAIAssistantView: View {
    @State private var selectedProvider: AIProvider = .chatgpt
    @State private var webView: WKWebView?
    @State private var isLoading: Bool = false
    @State private var currentPrompt: String = ""
    @State private var injectedPrompt: String? = nil
    
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
            // Header Bar
            headerBar
            
            Divider().opacity(0.3)
            
            // Quick Prompt Suggestion Bar (if there is selected text)
            if !currentPrompt.isEmpty {
                quickPromptBar
                Divider().opacity(0.2)
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
                            .scaleEffect(0.8)
                            .padding(8)
                            .background(VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow))
                            .clipShape(Circle())
                            .shadow(radius: 4)
                        Spacer()
                    }
                    .padding(.top, 16)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 640, minHeight: 580)
        .background(
            VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow)
        )
    }
    
    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 8) {
            // Window Traffic Light Clearance
            Spacer().frame(width: 58)
            
            // Provider Tabs
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
                                .font(.system(size: 11.5, weight: selectedProvider == provider ? .semibold : .regular))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .foregroundColor(selectedProvider == provider ? .white : .primary.opacity(0.75))
                        .background(
                            selectedProvider == provider ? Color.blue : Color.primary.opacity(0.04)
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // Action Buttons (Reload, Safari)
            HStack(spacing: 6) {
                Button(action: {
                    webView?.reload()
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .padding(6)
                        .background(Color.primary.opacity(0.05))
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
                        .font(.system(size: 11))
                        .padding(6)
                        .background(Color.primary.opacity(0.05))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Mở trong Safari")
            }
            .padding(.trailing, 12)
        }
        .padding(.vertical, 10)
    }
    
    // MARK: - Quick Prompt Suggestions Bar
    private var quickPromptBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("Hỏi nhanh:")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.leading, 12)
                
                promptChip(title: "📖 Giải thích & Dịch", prompt: "Hãy giải thích chi tiết, dịch chuẩn xác và phân tích câu sau:\n\n\(currentPrompt)")
                promptChip(title: "✍️ Viết lại tự nhiên", prompt: "Hãy viết lại đoạn văn sau theo 3 phong cách (Tự nhiên, Trang trọng, Học thuật):\n\n\(currentPrompt)")
                promptChip(title: "🔍 Tìm lỗi ngữ pháp", prompt: "Hãy kiểm tra lỗi ngữ pháp, từ vựng và chỉ ra cách sửa cho đoạn sau:\n\n\(currentPrompt)")
                promptChip(title: "💻 Giải thích Code", prompt: "Hãy giải thích cách hoạt động của đoạn mã này, độ phức tạp và tối ưu:\n\n\(currentPrompt)")
            }
            .padding(.vertical, 6)
            .padding(.trailing, 12)
        }
        .background(Color.primary.opacity(0.02))
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
                .background(Color.blue.opacity(0.08))
                .foregroundColor(.blue)
                .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }
}
