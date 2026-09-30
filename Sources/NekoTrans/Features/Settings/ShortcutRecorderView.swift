import SwiftUI
import AppKit

public struct ShortcutRecorderView: View {
    @Binding var shortcut: KeyShortcut
    let defaultShortcut: KeyShortcut
    
    @State private var isRecording: Bool = false
    @State private var monitor: Any?
    
    public init(shortcut: Binding<KeyShortcut>, defaultShortcut: KeyShortcut) {
        self._shortcut = shortcut
        self.defaultShortcut = defaultShortcut
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Button(action: {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }) {
                HStack(spacing: 5) {
                    if isRecording {
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 11))
                        Text("Bấm tổ hợp phím mới...")
                            .font(.system(size: 11.5, weight: .bold))
                    } else {
                        Text(shortcut.displayString)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isRecording ? Color.blue.opacity(0.18) : Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.blue : Color.clear, lineWidth: 1.5)
                )
                .foregroundColor(isRecording ? .blue : .primary)
            }
            .buttonStyle(.plain)
            .help(isRecording ? "Bấm ESC để hủy ghi nhận" : "Bấm vào đây rồi gõ tổ hợp phím tắt mới bạn muốn đặt")
            
            if isRecording {
                Button(action: {
                    stopRecording()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Hủy")
            } else if shortcut != defaultShortcut {
                Button(action: {
                    shortcut = defaultShortcut
                }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .help("Khôi phục phím tắt mặc định (\(defaultShortcut.displayString))")
            }
        }
        .onDisappear {
            stopRecording()
        }
    }
    
    private func startRecording() {
        stopRecording()
        isRecording = true
        
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // ESC -> Cancel recording
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            
            // Try to extract shortcut
            if let newShortcut = KeyShortcut.from(event: event) {
                self.shortcut = newShortcut
                stopRecording()
                return nil
            }
            
            return nil
        }
    }
    
    private func stopRecording() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
        }
        isRecording = false
    }
}
