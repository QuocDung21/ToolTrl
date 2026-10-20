import Foundation
import Combine
import Defaults

extension Notification.Name {
    public static let featureFlagsDidChange = Notification.Name("NekoTrans.featureFlagsDidChange")
}

public enum FeatureFlag: String, CaseIterable, Identifiable, Sendable {
    case selectionBubble = "selection_bubble"
    case doubleCmdCTrigger = "double_cmd_c_trigger"
    case localLLM = "local_llm"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .selectionBubble:
            return "Bong bóng nổi tra cứu nhanh (Selection Bubble)"
        case .doubleCmdCTrigger:
            return "Gõ Double ⌘C để dịch nhanh"
        case .localLLM:
            return "Mô hình AI cục bộ Offline (Ollama Local LLM)"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .selectionBubble:
            return "Hiển thị nút tròn nhỏ nổi ngay cạnh con trỏ chuột khi bôi đen chữ trên màn hình (theo dõi sự kiện chuột toàn cục)."
        case .doubleCmdCTrigger:
            return "Theo dõi clipboard hệ thống để tự động tra từ khi bạn nhấn ⌘C hai lần liên tiếp trong 450ms."
        case .localLLM:
            return "Kết nối với máy chủ Ollama trên máy của bạn (localhost:11434) để dịch thuật và phân tích không cần Internet."
        }
    }
    
    public var icon: String {
        switch self {
        case .selectionBubble: return "character.bubble.fill"
        case .doubleCmdCTrigger: return "command"
        case .localLLM: return "server.rack"
        }
    }
}

@MainActor
public final class FeatureFlagService: ObservableObject {
    public static let shared = FeatureFlagService()
    
    // MARK: - Master Toggles
    @Published public var isDeveloperModeUnlocked: Bool {
        didSet {
            Defaults[.devModeUnlocked] = isDeveloperModeUnlocked
            notifyChange()
        }
    }
    
    @Published public var isBetaLabsEnabled: Bool {
        didSet {
            Defaults[.betaLabsEnabled] = isBetaLabsEnabled
            notifyChange()
        }
    }
    
    // MARK: - Individual Feature Flags
    @Published public var selectionBubble: Bool {
        didSet {
            Defaults[.flagSelectionBubble] = selectionBubble
            notifyChange()
        }
    }
    
    @Published public var doubleCmdCTrigger: Bool {
        didSet {
            Defaults[.flagDoubleCmdCTrigger] = doubleCmdCTrigger
            notifyChange()
        }
    }
    
    @Published public var localLLM: Bool {
        didSet {
            Defaults[.flagLocalLLM] = localLLM
            notifyChange()
        }
    }
    
    private init() {
        self.isDeveloperModeUnlocked = true
        self.isBetaLabsEnabled = Defaults[.betaLabsEnabled]
        
        // Mặc định các tính năng beta
        self.selectionBubble = Defaults[.flagSelectionBubble]
        self.doubleCmdCTrigger = Defaults[.flagDoubleCmdCTrigger]
        self.localLLM = Defaults[.flagLocalLLM]
    }
    
    /// Kiểm tra tính năng có đang được kích hoạt hay không
    public func isFeatureEnabled(_ flag: FeatureFlag) -> Bool {
        #if PUBLIC_RELEASE_STRIPPED
        return false
        #else
        // Phải bật Master Switch "Neko Labs" VÀ cờ của tính năng cụ thể đó
        guard isBetaLabsEnabled else { return false }
        
        switch flag {
        case .selectionBubble:
            return selectionBubble
        case .doubleCmdCTrigger:
            return doubleCmdCTrigger
        case .localLLM:
            return localLLM
        }
        #endif
    }
    
    public func unlockDeveloperMode() {
        isDeveloperModeUnlocked = true
    }
    
    public func lockDeveloperMode() {
        isDeveloperModeUnlocked = false
        isBetaLabsEnabled = false
    }
    
    private func notifyChange() {
        NotificationCenter.default.post(name: .featureFlagsDidChange, object: self)
    }
}
