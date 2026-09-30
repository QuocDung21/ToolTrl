import SwiftUI

public struct GitHubSyncSettingsSection: View {
    @ObservedObject var githubSync = GitHubSyncService.shared
    
    @State private var inputToken: String = ""
    @State private var showRestoreConfirmAlert: Bool = false
    @State private var showDisconnectAlert: Bool = false
    @State private var syncToastMessage: String? = nil
    @State private var detectedCLIAccount: GitHubSyncService.GitHubCLIAccount? = nil
    @State private var clipboardToken: String? = nil
    
    public init() {}
    
    public var body: some View {
        Form {
            if !githubSync.isConnected {
                connectSection
            } else {
                connectedAccountSection
                syncActionsSection
                
                if let msg = syncToastMessage {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppColors.success)
                            Text(msg)
                                .font(.appCaptionMedium)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            checkQuickConnectSources()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            checkQuickConnectSources()
        }
        .alert("Xác nhận khôi phục dữ liệu từ GitHub?", isPresented: $showRestoreConfirmAlert) {
            Button("Hủy", role: .cancel) {}
            Button("Gộp thêm vào máy (Khuyên dùng)") {
                Task {
                    let success = await githubSync.restoreFromGitHub(merge: true)
                    syncToastMessage = success ? "Khôi phục và gộp dữ liệu thành công!" : (githubSync.lastErrorMessage ?? "Lỗi khôi phục")
                }
            }
            Button("Ghi đè hoàn toàn", role: .destructive) {
                Task {
                    let success = await githubSync.restoreFromGitHub(merge: false)
                    syncToastMessage = success ? "Đã ghi đè toàn bộ dữ liệu từ GitHub!" : (githubSync.lastErrorMessage ?? "Lỗi khôi phục")
                }
            }
        } message: {
            Text("Bạn muốn gộp thêm từ vựng từ GitHub vào kho hiện tại hay ghi đè toàn bộ dữ liệu trên máy?")
        }
        .alert("Xác nhận đăng xuất tài khoản GitHub?", isPresented: $showDisconnectAlert) {
            Button("Hủy", role: .cancel) {}
            
            Button("Đăng xuất & Xóa dữ liệu trên máy", role: .destructive) {
                Task {
                    // Sao lưu bản mới nhất lên GitHub trước khi dọn dẹp máy
                    _ = await githubSync.backupToGitHub()
                    githubSync.disconnect(clearLocalData: true)
                    syncToastMessage = "Đã đăng xuất và làm sạch dữ liệu trên máy!"
                }
            }
            
            Button("Chỉ đăng xuất (Giữ lại từ vựng trên máy)") {
                githubSync.disconnect(clearLocalData: false)
                syncToastMessage = "Đã ngắt kết nối tài khoản GitHub!"
            }
        } message: {
            Text("Bạn có muốn xóa dữ liệu từ vựng và lịch sử học tập của tài khoản này khỏi máy không?\n\n• Đăng xuất & Xóa: Dọn sạch sổ tay trên máy. Dữ liệu trên GitHub Gist vẫn được bảo toàn để tải về khi đăng nhập lại.\n• Chỉ đăng xuất: Giữ nguyên toàn bộ từ vựng hiện có trên máy.")
        }
        .sensoryFeedback(.success, trigger: syncToastMessage)
        .sensoryFeedback(.impact(weight: .medium), trigger: githubSync.isConnected)
    }
    
    private func checkQuickConnectSources() {
        detectedCLIAccount = githubSync.detectGitHubCLI()
        
        if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           (clip.hasPrefix("ghp_") || clip.hasPrefix("gho_") || clip.hasPrefix("github_pat_")),
           clip.count >= 20 {
            clipboardToken = clip
        } else {
            clipboardToken = nil
        }
    }
    
    private var connectSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                // Header Intro
                HStack(spacing: 8) {
                    Image(systemName: "icloud.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.accent)
                    Text("Đồng bộ Sổ tay & Thống kê qua GitHub Secret Gist")
                        .font(.appHeadlineBold)
                }
                
                Text("Lưu trữ an toàn toàn bộ từ vựng, công thức ngữ pháp và lịch sử tra cứu của bạn lên kho lưu trữ riêng tư trên GitHub. Tự động đồng bộ hai chiều giữa các máy Mac.")
                    .font(.appCaption)
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                
                // 1. FASTEST METHOD: GitHub Web & CLI Login (No Token Needed)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.blue)
                        Text("Đăng nhập qua Web / GitHub CLI (Không cần tạo Token)")
                            .font(.system(size: 13, weight: .bold))
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(Color.green).frame(width: 6, height: 6)
                            Text("Khuyên Dùng")
                                .font(.system(size: 9.5, weight: .bold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    
                    if let cli = detectedCLIAccount {
                        Text("Phát hiện tài khoản **@\(cli.username)** đã xác thực trên máy. Bấm nút dưới để kết nối ngay tức thì mà không cần mở web hay sao chép token.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            Task {
                                let success = await githubSync.connectWithGitHubCLI()
                                if success {
                                    syncToastMessage = "Đã kết nối tài khoản GitHub @\(cli.username) thành công!"
                                }
                            }
                        }) {
                            HStack(spacing: 8) {
                                if githubSync.isSyncing {
                                    ProgressView().scaleEffect(0.7).frame(width: 16, height: 16)
                                    Text("Đang xác thực...")
                                } else {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 13))
                                    Text("Đăng nhập 1-chạm bằng tài khoản @\(cli.username)")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentColor)
                        .disabled(githubSync.isSyncing)
                        
                        HStack {
                            Button("Đăng nhập tài khoản khác trên Trình Duyệt Web...") {
                                githubSync.launchWebLoginInTerminal()
                            }
                            .buttonStyle(.link)
                            .font(.system(size: 11))
                            
                            Spacer()
                            
                            Button(action: {
                                checkQuickConnectSources()
                                if detectedCLIAccount != nil {
                                    Task { _ = await githubSync.connectWithGitHubCLI() }
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Làm mới")
                                }
                                .font(.system(size: 11))
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        Text("Đăng nhập an toàn qua trình duyệt Safari/Chrome với lệnh GitHub CLI chính thức (`gh auth login --web`). Trình duyệt sẽ mở để bạn bấm Authorize.")
                            .font(.system(size: 11.5))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 10) {
                            Button(action: {
                                githubSync.launchWebLoginInTerminal()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "safari")
                                        .font(.system(size: 12))
                                    Text("Mở Trình Duyệt để Đăng Nhập Web")
                                        .font(.system(size: 12, weight: .medium))
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button(action: {
                                checkQuickConnectSources()
                                if detectedCLIAccount != nil {
                                    Task { _ = await githubSync.connectWithGitHubCLI() }
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle")
                                    Text("Kiểm tra & Kết nối")
                                }
                                .font(.system(size: 12))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.06))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
                
                // 2. SMART CLIPBOARD BANNER: If token is detected in pasteboard
                if let clip = clipboardToken, !clip.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Phát hiện Token trong bộ nhớ tạm")
                                .font(.system(size: 11.5, weight: .semibold))
                            Text("\(clip.prefix(8))••••••••\(clip.suffix(4))")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Dán & Kết nối ngay") {
                            inputToken = clip
                            Task {
                                let success = await githubSync.verifyAndConnect(token: clip)
                                if success {
                                    syncToastMessage = "Kết nối GitHub thành công!"
                                    clipboardToken = nil
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(githubSync.isSyncing)
                    }
                    .padding(10)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 0.8)
                    )
                }
                
                Divider().padding(.vertical, 2)
                
                // 3. MANUAL / STANDARD TOKEN INPUT
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(detectedCLIAccount != nil ? "Hoặc nhập Token thủ công (PAT):" : "GitHub Personal Access Token (PAT):")
                            .font(.appBodyBold)
                        
                        Spacer()
                        
                        Link(destination: URL(string: "https://github.com/settings/tokens/new?scopes=gist&description=NekoTrans+Cloud+Backup")!) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.system(size: 10))
                                Text("Tạo token nhanh trên web (quyền Gist)")
                                    .font(.system(size: 11))
                            }
                        }
                    }
                    
                    HStack(spacing: 8) {
                        SecureField("ghp_xxxxxxxxxxxxxxxxxxxx hoặc gho_...", text: $inputToken)
                            .textFieldStyle(.roundedBorder)
                        
                        // Paste button
                        Button(action: {
                            if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                                inputToken = clip
                            }
                        }) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .help("Dán mã từ bộ nhớ tạm")
                        
                        Button(action: {
                            Task {
                                let success = await githubSync.verifyAndConnect(token: inputToken)
                                if success {
                                    inputToken = ""
                                    syncToastMessage = "Kết nối GitHub thành công!"
                                }
                            }
                        }) {
                            if githubSync.isSyncing {
                                ProgressView().scaleEffect(0.7)
                            } else {
                                Text("Kết nối")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppColors.accent)
                        .disabled(inputToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || githubSync.isSyncing)
                    }
                }
                
                if let error = githubSync.lastErrorMessage {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 11))
                        Text(error)
                            .font(.appCaption)
                    }
                    .foregroundColor(.red)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("KẾT NỐI TÀI KHOẢN GITHUB")
        } footer: {
            Text("Mẹo: NekoTrans tự động nhận diện tài khoản GitHub CLI trên máy và token bạn vừa sao chép từ trình duyệt để đăng nhập nhanh 1-chạm.")
                .font(.appCaption)
                .foregroundColor(.secondary)
        }
    }
    
    private var connectedAccountSection: some View {
        Section(header: Text("TÀI KHOẢN ĐÃ KẾT NỐI")) {
            HStack(spacing: 12) {
                if let avatarUrl = githubSync.currentUser?.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 42, height: 42)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .frame(width: 42, height: 42)
                        .foregroundColor(AppColors.accent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(githubSync.currentUser?.name ?? githubSync.currentUser?.login ?? "GitHub User")
                        .font(.appHeadlineBold)
                    Text("@\(githubSync.currentUser?.login ?? "")")
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Hủy kết nối", role: .destructive) {
                    showDisconnectAlert = true
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
            .padding(.vertical, 4)
            
            if let lastSync = githubSync.lastSyncDate {
                LabeledContent("Đồng bộ lần cuối:", value: lastSync.formatted(date: .abbreviated, time: .shortened))
            } else {
                LabeledContent("Đồng bộ lần cuối:", value: "Chưa đồng bộ")
            }
        }
    }
    
    private var syncActionsSection: some View {
        Section(header: Text("THAO TÁC ĐỒNG BỘ ĐÁM MÂY")) {
            Toggle("Tự động sao lưu lên GitHub khi thêm từ mới", isOn: $githubSync.autoSyncEnabled)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sao lưu lên GitHub (Push)")
                        .font(.appBodyBold)
                    Text("Đẩy toàn bộ Sổ tay từ vựng & Thống kê hiện tại lên kho lưu trữ riêng tư.")
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        let success = await githubSync.backupToGitHub()
                        syncToastMessage = success ? "Đã sao lưu lên GitHub thành công!" : (githubSync.lastErrorMessage ?? "Lỗi sao lưu")
                    }
                }) {
                    if githubSync.isSyncing {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Label("Sao lưu ngay", systemImage: "icloud.and.arrow.up")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(githubSync.isSyncing)
            }
            .padding(.vertical, 2)
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Khôi phục từ GitHub (Pull)")
                        .font(.appBodyBold)
                    Text("Tải dữ liệu từ GitHub về máy hiện tại (hỗ trợ gộp thêm hoặc ghi đè).")
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showRestoreConfirmAlert = true
                }) {
                    Label("Khôi phục", systemImage: "icloud.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled(githubSync.isSyncing)
            }
            .padding(.vertical, 2)
        }
    }
}
