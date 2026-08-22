import SwiftUI
import WebKit
import AppKit

public enum AIProvider: String, CaseIterable, Identifiable {
    case chatgpt = "ChatGPT"
    case gemini = "Gemini"
    case claude = "Claude"
    case perplexity = "Perplexity"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .chatgpt: return "sparkle"
        case .gemini: return "sparkles"
        case .claude: return "brain.head.profile"
        case .perplexity: return "magnifyingglass.circle.fill"
        }
    }
    
    public var baseURL: URL {
        switch self {
        case .chatgpt:
            return URL(string: "https://chatgpt.com")!
        case .gemini:
            return URL(string: "https://gemini.google.com/app")!
        case .claude:
            return URL(string: "https://claude.ai")!
        case .perplexity:
            return URL(string: "https://www.perplexity.ai")!
        }
    }
    
    public func urlWithQuery(_ query: String) -> URL {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return baseURL }
        
        switch self {
        case .chatgpt:
            if let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                return URL(string: "https://chatgpt.com/?q=\(encoded)") ?? baseURL
            }
        case .perplexity:
            if let encoded = clean.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                return URL(string: "https://www.perplexity.ai/search?q=\(encoded)") ?? baseURL
            }
        case .gemini, .claude:
            return baseURL
        }
        return baseURL
    }
}

public struct AIWebView: NSViewRepresentable {
    public let provider: AIProvider
    public let pendingPrompt: String?
    @Binding public var webView: WKWebView?
    @Binding public var isLoading: Bool
    
    public init(
        provider: AIProvider,
        pendingPrompt: String? = nil,
        webView: Binding<WKWebView?>,
        isLoading: Binding<Bool>
    ) {
        self.provider = provider
        self.pendingPrompt = pendingPrompt
        self._webView = webView
        self._isLoading = isLoading
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // Persist user cookies and login sessions
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = context.coordinator
        wv.uiDelegate = context.coordinator
        
        // Safari macOS Desktop User-Agent (Fixes Google/OpenAI OAuth blocking)
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        
        let initialURL = provider.baseURL
        wv.load(URLRequest(url: initialURL))
        
        DispatchQueue.main.async {
            self.webView = wv
        }
        
        return wv
    }
    
    public func updateNSView(_ nsView: WKWebView, context: Context) {
        if context.coordinator.currentProvider != provider {
            context.coordinator.currentProvider = provider
            let targetURL = provider.baseURL
            nsView.load(URLRequest(url: targetURL))
        }
        
        if let prompt = pendingPrompt, !prompt.isEmpty, prompt != context.coordinator.lastInjectedPrompt {
            context.coordinator.lastInjectedPrompt = prompt
            context.coordinator.injectPrompt(prompt, into: nsView, provider: provider)
        }
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: AIWebView
        var currentProvider: AIProvider
        var lastInjectedPrompt: String? = nil
        
        init(_ parent: AIWebView) {
            self.parent = parent
            self.currentProvider = parent.provider
        }
        
        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }
        
        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                
                if let prompt = self.parent.pendingPrompt, !prompt.isEmpty {
                    self.injectPrompt(prompt, into: webView, provider: self.currentProvider)
                }
            }
        }
        
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        public func injectPrompt(_ prompt: String, into webView: WKWebView, provider: AIProvider) {
            let escapedPrompt = prompt
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")
            
            var jsCode = ""
            
            switch provider {
            case .chatgpt:
                jsCode = """
                (function() {
                    let el = document.querySelector('#prompt-textarea') || document.querySelector('div[contenteditable="true"]');
                    if (el) {
                        el.focus();
                        if (el.tagName === 'TEXTAREA') {
                            el.value = "\(escapedPrompt)";
                        } else {
                            el.innerText = "\(escapedPrompt)";
                        }
                        el.dispatchEvent(new Event('input', { bubbles: true }));
                    }
                })();
                """
            case .gemini:
                jsCode = """
                (function() {
                    let el = document.querySelector('.ql-editor') || document.querySelector('div[contenteditable="true"]') || document.querySelector('textarea');
                    if (el) {
                        el.focus();
                        if (el.tagName === 'TEXTAREA') {
                            el.value = "\(escapedPrompt)";
                        } else {
                            el.innerHTML = "<p>\(escapedPrompt)</p>";
                        }
                        el.dispatchEvent(new Event('input', { bubbles: true }));
                    }
                })();
                """
            case .claude:
                jsCode = """
                (function() {
                    let el = document.querySelector('div[contenteditable="true"]') || document.querySelector('fieldset textarea');
                    if (el) {
                        el.focus();
                        el.innerText = "\(escapedPrompt)";
                        el.dispatchEvent(new Event('input', { bubbles: true }));
                    }
                })();
                """
            case .perplexity:
                jsCode = """
                (function() {
                    let el = document.querySelector('textarea');
                    if (el) {
                        el.focus();
                        el.value = "\(escapedPrompt)";
                        el.dispatchEvent(new Event('input', { bubbles: true }));
                    }
                })();
                """
            }
            
            webView.evaluateJavaScript(jsCode, completionHandler: nil)
        }
    }
}
