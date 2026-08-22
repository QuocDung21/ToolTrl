import Foundation
import SwiftUI

public struct QuickPromptItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID = UUID()
    public var icon: String
    public var title: String
    public var template: String
    public var isEnabled: Bool = true
    
    public init(id: UUID = UUID(), icon: String, title: String, template: String, isEnabled: Bool = true) {
        self.id = id
        self.icon = icon
        self.title = title
        self.template = template
        self.isEnabled = isEnabled
    }
}

@MainActor
public final class QuickPromptService: ObservableObject {
    public static let shared = QuickPromptService()
    
    @Published public var prompts: [QuickPromptItem] = []
    
    public var activePrompts: [QuickPromptItem] {
        prompts.filter { $0.isEnabled }
    }
    
    public static let defaultPrompts: [QuickPromptItem] = [
        QuickPromptItem(
            icon: "📖",
            title: "Giải thích & Dịch",
            template: "Hãy giải thích chi tiết, dịch chuẩn xác và phân tích ngữ pháp câu sau:\n\n{text}",
            isEnabled: true
        ),
        QuickPromptItem(
            icon: "✍️",
            title: "Viết lại tự nhiên",
            template: "Hãy viết lại đoạn văn sau theo 3 phong cách (Tự nhiên, Trang trọng, Học thuật):\n\n{text}",
            isEnabled: true
        ),
        QuickPromptItem(
            icon: "🔍",
            title: "Tìm lỗi ngữ pháp",
            template: "Hãy kiểm tra lỗi ngữ pháp, từ vựng và chỉ ra cách sửa cho đoạn sau:\n\n{text}",
            isEnabled: true
        ),
        QuickPromptItem(
            icon: "💻",
            title: "Giải thích Code",
            template: "Hãy giải thích cách hoạt động của đoạn mã này, độ phức tạp và tối ưu:\n\n{text}",
            isEnabled: true
        ),
        QuickPromptItem(
            icon: "📌",
            title: "Tóm tắt ý chính",
            template: "Hãy tóm tắt đoạn văn sau thành các gạch đầu dòng ngắn gọn và súc tích nhất:\n\n{text}",
            isEnabled: true
        ),
        QuickPromptItem(
            icon: "✉️",
            title: "Viết Email tiếng Anh",
            template: "Hãy chuyển đoạn ý tưởng sau thành một email tiếng Anh trang trọng, lịch sự và chuyên nghiệp:\n\n{text}",
            isEnabled: true
        )
    ]
    
    private init() {
        loadPrompts()
    }
    
    public func loadPrompts() {
        if let data = UserDefaults.standard.data(forKey: "custom_quick_prompts"),
           let decoded = try? JSONDecoder().decode([QuickPromptItem].self, from: data), !decoded.isEmpty {
            self.prompts = decoded
        } else {
            self.prompts = Self.defaultPrompts
            savePrompts()
        }
    }
    
    public func savePrompts() {
        if let encoded = try? JSONEncoder().encode(prompts) {
            UserDefaults.standard.set(encoded, forKey: "custom_quick_prompts")
        }
    }
    
    public func addPrompt(icon: String, title: String, template: String) {
        let new = QuickPromptItem(icon: icon.isEmpty ? "💡" : icon, title: title, template: template, isEnabled: true)
        prompts.append(new)
        savePrompts()
    }
    
    public func updatePrompt(id: UUID, icon: String, title: String, template: String, isEnabled: Bool = true) {
        if let index = prompts.firstIndex(where: { $0.id == id }) {
            prompts[index].icon = icon.isEmpty ? "💡" : icon
            prompts[index].title = title
            prompts[index].template = template
            prompts[index].isEnabled = isEnabled
            savePrompts()
        }
    }
    
    public func toggleEnabled(id: UUID) {
        if let index = prompts.firstIndex(where: { $0.id == id }) {
            prompts[index].isEnabled.toggle()
            savePrompts()
        }
    }
    
    public func moveUp(id: UUID) {
        guard let index = prompts.firstIndex(where: { $0.id == id }), index > 0 else { return }
        prompts.swapAt(index, index - 1)
        savePrompts()
    }
    
    public func moveDown(id: UUID) {
        guard let index = prompts.firstIndex(where: { $0.id == id }), index < prompts.count - 1 else { return }
        prompts.swapAt(index, index + 1)
        savePrompts()
    }
    
    public func deletePrompt(id: UUID) {
        prompts.removeAll(where: { $0.id == id })
        savePrompts()
    }
    
    public func resetDefaults() {
        self.prompts = Self.defaultPrompts
        savePrompts()
    }
    
    public func renderPrompt(for item: QuickPromptItem, text: String) -> String {
        if item.template.contains("{text}") {
            return item.template.replacingOccurrences(of: "{text}", with: text)
        } else {
            return "\(item.template)\n\n\(text)"
        }
    }
}
