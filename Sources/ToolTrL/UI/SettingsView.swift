import SwiftUI

public struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var testTextEn = "Hello! This is a speech rate test."
    @State private var testTextVi = "Xin chào! Đây là bài kiểm tra tốc độ đọc."
    
    public init() {}
    
    public var body: some View {
        TabView {
            speechTab
                .tabItem {
                    Label("Âm thanh", systemImage: "speaker.wave.3.fill")
                }
            
            translationTab
                .tabItem {
                    Label("Dịch thuật", systemImage: "character.book.closed.fill")
                }
            
            generalTab
                .tabItem {
                    Label("Chung", systemImage: "gearshape.fill")
                }
        }
        .frame(width: 460, height: 320)
        .padding(16)
    }
    
    // MARK: - Speech Tab
    private var speechTab: some View {
        Form {
            Section(header: Text("Tốc độ phát âm (Speech Rate)").font(.system(size: 12, weight: .bold))) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Rất chậm")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Slider(value: $settings.speechRate, in: 0.15...0.65, step: 0.02)
                        
                        Text("Nhanh")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        let desc: String = {
                            if settings.speechRate <= 0.25 { return "Rất chậm (0.5x)" }
                            if settings.speechRate <= 0.35 { return "Chậm (0.7x)" }
                            if settings.speechRate <= 0.45 { return "Vừa phải (1.0x - Chuẩn)" }
                            if settings.speechRate <= 0.55 { return "Hơi nhanh (1.2x)" }
                            return "Nhanh (1.5x)"
                        }()
                        Text("Tốc độ: \(String(format: "%.2f", settings.speechRate)) — \(desc)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        SpeechService.shared.speak(text: testTextEn, languageCode: "en-US", speakerID: "test_en")
                    }) {
                        Label("Nghe thử (English)", systemImage: "play.circle.fill")
                    }
                    
                    Button(action: {
                        SpeechService.shared.speak(text: testTextVi, languageCode: "vi-VN", speakerID: "test_vi")
                    }) {
                        Label("Nghe thử (Tiếng Việt)", systemImage: "play.circle.fill")
                    }
                }
                .padding(.top, 4)
            }
            
            Section(header: Text("Tùy chọn tự động").font(.system(size: 12, weight: .bold))) {
                Toggle("Tự động đọc từ khi mở cửa sổ tra cứu", isOn: $settings.autoSpeakWord)
                    .font(.system(size: 12))
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - Translation Tab
    private var translationTab: some View {
        Form {
            Section(header: Text("Ngôn ngữ đích mặc định").font(.system(size: 12, weight: .bold))) {
                Picker("Dịch sang:", selection: $settings.targetLanguage) {
                    ForEach(TargetLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 12))
            }
            
            Section(header: Text("Bộ máy dịch AI").font(.system(size: 12, weight: .bold))) {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 14))
                    Text("Apple Intelligence / macOS Neural Translation")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("Sẵn sàng")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.green)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - General Tab
    private var generalTab: some View {
        Form {
            Section(header: Text("Phím tắt toàn hệ thống").font(.system(size: 12, weight: .bold))) {
                HStack {
                    Text("Dịch nhanh văn bản bôi đen:")
                        .font(.system(size: 12))
                    Spacer()
                    Text("Option + D (⌥D)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(5)
                }
            }
            
            Section(header: Text("Hành vi ứng dụng").font(.system(size: 12, weight: .bold))) {
                Toggle("Khởi động cùng macOS", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { settings.setLaunchAtLogin($0) }
                ))
                .font(.system(size: 12))
                
                Toggle("Tự động đóng popup khi click ra ngoài", isOn: $settings.clickOutsideDismiss)
                    .font(.system(size: 12))
            }
        }
        .formStyle(.grouped)
    }
}
