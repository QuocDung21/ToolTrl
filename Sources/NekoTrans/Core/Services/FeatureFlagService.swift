import Foundation
import Combine

extension Notification.Name {
    public static let featureFlagsDidChange = Notification.Name("NekoTrans.featureFlagsDidChange")
}

public enum FeatureFlag: String, CaseIterable, Identifiable, Sendable {
    case continuityStudio = "continuity_studio"
    case selectionBubble = "selection_bubble"
    case doubleCmdCTrigger = "double_cmd_c_trigger"
    case localLLM = "local_llm"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .continuityStudio:
            return "Làm bài tập & Giải đề iPad (Continuity Homework Studio)"
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
        case .continuityStudio:
            return "Tính năng làm bài tập: Cho phép gửi đề sang iPad để giải bằng bút Apple Pencil, chấm điểm AI và theo dõi chỉ tiêu bài tập."
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
        case .continuityStudio: return "ipad.and.arrow.forward"
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
            UserDefaults.standard.set(isDeveloperModeUnlocked, forKey: "dev_mode_unlocked")
            notifyChange()
        }
    }
    
    @Published public var isBetaLabsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isBetaLabsEnabled, forKey: "beta_labs_enabled")
            notifyChange()
        }
    }
    
    // MARK: - Individual Feature Flags
    @Published public var continuityStudio: Bool {
        didSet {
            UserDefaults.standard.set(continuityStudio, forKey: "flag_continuity_studio")
            notifyChange()
        }
    }
    
    @Published public var selectionBubble: Bool {
        didSet {
            UserDefaults.standard.set(selectionBubble, forKey: "flag_selection_bubble")
            notifyChange()
        }
    }
    
    @Published public var doubleCmdCTrigger: Bool {
        didSet {
            UserDefaults.standard.set(doubleCmdCTrigger, forKey: "flag_double_cmd_c_trigger")
            notifyChange()
        }
    }
    
    @Published public var localLLM: Bool {
        didSet {
            UserDefaults.standard.set(localLLM, forKey: "flag_local_llm")
            notifyChange()
        }
    }
    
    private init() {
        #if DEBUG
        self.isDeveloperModeUnlocked = UserDefaults.standard.object(forKey: "dev_mode_unlocked") != nil
            ? UserDefaults.standard.bool(forKey: "dev_mode_unlocked")
            : true
        #else
        self.isDeveloperModeUnlocked = UserDefaults.standard.bool(forKey: "dev_mode_unlocked")
        #endif
        
        self.isBetaLabsEnabled = UserDefaults.standard.bool(forKey: "beta_labs_enabled")
        
        // Mặc định các tính năng beta đều TẮT cho người dùng bình thường
        self.continuityStudio = UserDefaults.standard.bool(forKey: "flag_continuity_studio")
        self.selectionBubble = UserDefaults.standard.bool(forKey: "flag_selection_bubble")
        self.doubleCmdCTrigger = UserDefaults.standard.bool(forKey: "flag_double_cmd_c_trigger")
        self.localLLM = UserDefaults.standard.bool(forKey: "flag_local_llm")
    }
    
    /// Kiểm tra tính năng có đang được kích hoạt hay không
    public func isFeatureEnabled(_ flag: FeatureFlag) -> Bool {
        #if PUBLIC_RELEASE_STRIPPED
        return false
        #else
        // Phải bật Master Switch "Neko Labs" VÀ cờ của tính năng cụ thể đó
        guard isBetaLabsEnabled else { return false }
        
        switch flag {
        case .continuityStudio:
            return continuityStudio
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
