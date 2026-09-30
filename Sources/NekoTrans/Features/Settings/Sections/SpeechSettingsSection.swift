import SwiftUI

public struct SpeechSettingsSection: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var speechService = SpeechService.shared
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("PHÁT ÂM TỰ NHIÊN (TEXT-TO-SPEECH)")) {
                Toggle("Tự động phát âm khi tra từ đơn", isOn: $settings.autoSpeakWord)
            }
            
            Section(header: Text("TÙY CHỈNH GIỌNG ĐỌC")) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Âm lượng:")
                            .font(.system(size: 12.5))
                        Spacer()
                        Text("\(Int(round(settings.speechVolume * 100)))%")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11, design: .monospaced))
                    }
                    
                    Slider(value: $settings.speechVolume, in: 0.0...1.0, step: 0.05)
                }
                .padding(.vertical, 2)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Tốc độ đọc:")
                            .font(.system(size: 12.5))
                        Spacer()
                        Text(String(format: "%.2fx", settings.speechRate))
                            .foregroundColor(.secondary)
                            .font(.system(size: 11, design: .monospaced))
                    }
                    
                    Slider(value: $settings.speechRate, in: 0.2...0.8, step: 0.05)
                }
                .padding(.vertical, 2)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Cao độ giọng đọc:")
                            .font(.system(size: 12.5))
                        Spacer()
                        Text(String(format: "%.2fx", settings.speechPitch))
                            .foregroundColor(.secondary)
                            .font(.system(size: 11, design: .monospaced))
                    }
                    
                    Slider(value: $settings.speechPitch, in: 0.5...1.5, step: 0.05)
                }
                .padding(.vertical, 2)
            }
            
            Section {
                Button(action: {
                    speechService.speak(
                        text: "Hello! NekoTrans helps you learn English effortlessly.",
                        languageCode: "en-US",
                        speakerID: "settings_test"
                    )
                }) {
                    Label("Nghe thử giọng đọc mẫu", systemImage: "speaker.wave.2")
                }
                .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
    }
}
