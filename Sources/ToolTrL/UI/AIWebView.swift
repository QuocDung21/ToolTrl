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
        
        // Ensure seamless dark background without white flash
        wv.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) {
            wv.underPageBackgroundColor = .clear
        }
        
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
                
                // Inject dark mode style if macOS is in dark mode
                let isDark = NSApp.effectiveAppearance.name == .darkAqua || NSApp.effectiveAppearance.name == .vibrantDark
                if isDark {
                    let darkModeScript = """
                    (function() {
                        document.documentElement.classList.add('dark');
                        document.documentElement.setAttribute('data-theme', 'dark');
                        document.documentElement.style.colorScheme = 'dark';
                    })();
                    """
                    webView.evaluateJavaScript(darkModeScript, completionHandler: nil)
                }
                
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
            // 1. Sync directly to Clipboard as instant guarantee
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(prompt, forType: .string)
            
            // 2. Escape text safely for JS injection
            let escapedPrompt = prompt
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "")
            
            // 3. Bulletproof injection with active polling retry loop for dynamic SPAs
            let jsCode = """
            (function() {
                const textToInsert = "\(escapedPrompt)";
                let attempts = 0;
                const maxAttempts = 35; // Try for up to 10.5 seconds (35 * 300ms)
                
                function tryInsert() {
                    attempts++;
                    
                    // Comprehensive multi-provider input selector list
                    let el = document.querySelector('#prompt-textarea')
                          || document.querySelector('div#prompt-textarea')
                          || document.querySelector('div[contenteditable="true"][role="textbox"]')
                          || document.querySelector('rich-textarea div[contenteditable="true"]')
                          || document.querySelector('rich-textarea div')
                          || document.querySelector('.ql-editor')
                          || document.querySelector('div[contenteditable="true"]')
                          || document.querySelector('fieldset textarea')
                          || document.querySelector('form textarea')
                          || document.querySelector('textarea[placeholder]')
                          || document.querySelector('textarea');
                          
                    if (el) {
                        el.focus();
                        
                        if (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT') {
                            el.value = textToInsert;
                            el.dispatchEvent(new Event('input', { bubbles: true }));
                            el.dispatchEvent(new Event('change', { bubbles: true }));
                        } else {
                            // Rich text contenteditable (ChatGPT, Gemini, Claude)
                            document.execCommand('selectAll', false, null);
                            let success = false;
                            try {
                                success = document.execCommand('insertText', false, textToInsert);
                            } catch (e) {
                                success = false;
                            }
                            
                            if (!success || !el.innerText || el.innerText.trim().length === 0) {
                                el.innerText = textToInsert;
                                el.innerHTML = '<p>' + textToInsert.split('\\n').join('<br>') + '</p>';
                            }
                            
                            try {
                                el.dispatchEvent(new InputEvent('input', { bubbles: true, inputType: 'insertText', data: textToInsert }));
                            } catch (e) {
                                el.dispatchEvent(new Event('input', { bubbles: true }));
                            }
                            el.dispatchEvent(new Event('change', { bubbles: true }));
                        }
                        
                        // Scroll into view
                        el.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        return true;
                    }
                    
                    if (attempts < maxAttempts) {
                        setTimeout(tryInsert, 300);
                    }
                    return false;
                }
                
                tryInsert();
            })();
            """
            
            webView.evaluateJavaScript(jsCode, completionHandler: nil)
        }
    }
}
