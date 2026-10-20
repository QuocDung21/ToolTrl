import AppKit
import SwiftUI

@MainActor
public final class VocabularyWindowController {
    public static let shared = VocabularyWindowController()
    
    private var window: NSWindow?
    
    private init() {}
    
    public func showNotebook(initialTab: NotebookSidebarItem = .vocabulary) {
        MainWindowController.shared.showMainWindow(initialTab: .notebook)
    }
    
    public func hideNotebook() {
        MainWindowController.shared.hideMainWindow()
    }
}
