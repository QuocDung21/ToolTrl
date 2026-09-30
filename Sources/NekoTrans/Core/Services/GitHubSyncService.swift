import Foundation
import SwiftUI
import Compression

public struct GitHubUser: Codable, Sendable {
    public let login: String
    public let name: String?
    public let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case login
        case name
        case avatarUrl = "avatar_url"
    }
}

public struct NekoTransBackupPayload: Codable, Sendable {
    public let appVersion: String
    public let timestamp: Date
    public let savedWords: [SavedWordItem]
    public let lookupRecords: [LookupRecord]
    public let dailyGoal: Int
    
    public init(
        appVersion: String = "1.0.0",
        timestamp: Date = Date(),
        savedWords: [SavedWordItem],
        lookupRecords: [LookupRecord],
        dailyGoal: Int
    ) {
        self.appVersion = appVersion
        self.timestamp = timestamp
        self.savedWords = savedWords
        self.lookupRecords = lookupRecords
        self.dailyGoal = dailyGoal
    }
}

@MainActor
public final class GitHubSyncService: ObservableObject {
    public static let shared = GitHubSyncService()
    
    /// Keychain account holding the GitHub PAT (raw value also the legacy UserDefaults key).
    private let tokenKey = KeyStore.Secret.githubPAT
    
    // Frozen on purpose: these keys hold the user's live gist id and connection state.
    // Renaming them without a migration would silently disconnect every existing user,
    // so the ToolTrL prefix stays part of the persisted contract.
    private let gistIdKey = "tooltrl_github_gist_id"
    private let lastSyncKey = "tooltrl_github_last_sync_date"
    private let autoSyncKey = "tooltrl_github_auto_sync_enabled"
    private let userKey = "tooltrl_github_user_cache"
    
    private let compressedBackupFileName = "nekotrans_backup.lzfse.b64"
    private let primaryBackupFileName = "nekotrans_backup_data.json"
    /// Name of the file inside the remote gist; kept so backups written by older
    /// builds are still found and restored.
    private let legacyBackupFileName = "tooltrl_backup_data.json"
    
    @Published public private(set) var token: String = ""
    @Published public private(set) var gistId: String = ""
    @Published public private(set) var lastSyncDate: Date? = nil
    @Published public private(set) var currentUser: GitHubUser? = nil
    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastErrorMessage: String? = nil
    
    @Published public var autoSyncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoSyncEnabled, forKey: autoSyncKey)
        }
    }
    
    public var isConnected: Bool {
        return !token.isEmpty && currentUser != nil
    }
    
    private init() {
        // The PAT lives in the Keychain; migrate a pre-Keychain value first.
        KeychainStore.migrateFromUserDefaults(account: tokenKey)
        self.token = KeychainStore.string(for: tokenKey) ?? ""
        self.gistId = UserDefaults.standard.string(forKey: gistIdKey) ?? ""
        
        if UserDefaults.standard.object(forKey: autoSyncKey) == nil {
            self.autoSyncEnabled = true
        } else {
            self.autoSyncEnabled = UserDefaults.standard.bool(forKey: autoSyncKey)
        }
        
        if let timestamp = UserDefaults.standard.object(forKey: lastSyncKey) as? Date {
            self.lastSyncDate = timestamp
        }
        
        if let userData = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(GitHubUser.self, from: userData) {
            self.currentUser = user
        }
        
        // If token exists but no user info, verify token
        if !token.isEmpty && currentUser == nil {
            Task {
                _ = await verifyToken(token)
            }
        }
    }
    
    // MARK: - Authentication & Token Verification
    public struct GitHubCLIAccount: Sendable, Equatable {
        public let username: String
        public let token: String
    }
    
    public func detectGitHubCLI() -> GitHubCLIAccount? {
        guard let ghPath = findGitHubCLIBinary() else { return nil }
        
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ghPath)
        p.arguments = ["auth", "token"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        
        do {
            try p.run()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !token.isEmpty else { return nil }
            
            // Query username via gh
            let userProcess = Process()
            userProcess.executableURL = URL(fileURLWithPath: ghPath)
            userProcess.arguments = ["api", "user", "--jq", ".login"]
            let userPipe = Pipe()
            userProcess.standardOutput = userPipe
            userProcess.standardError = Pipe()
            try? userProcess.run()
            userProcess.waitUntilExit()
            let userData = userPipe.fileHandleForReading.readDataToEndOfFile()
            let username = String(data: userData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            return GitHubCLIAccount(username: username.isEmpty ? "Tài khoản GitHub CLI" : username, token: token)
        } catch {
            return nil
        }
    }
    
    private func findGitHubCLIBinary() -> String? {
        let candidatePaths = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
            "/opt/local/bin/gh"
        ]
        for path in candidatePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }
    
    public func connectWithGitHubCLI() async -> Bool {
        guard let account = detectGitHubCLI() else {
            lastErrorMessage = "Không tìm thấy GitHub CLI hoặc chưa đăng nhập tài khoản."
            return false
        }
        return await verifyAndConnect(token: account.token)
    }

    public func launchWebLoginInTerminal() {
        let script = """
        tell application "Terminal"
            activate
            do script "gh auth login --web --scopes gist"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    public func verifyAndConnect(token inputToken: String) async -> Bool {
        let cleanToken = inputToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanToken.isEmpty else {
            lastErrorMessage = "Vui lòng nhập GitHub Personal Access Token."
            return false
        }
        
        isSyncing = true
        lastErrorMessage = nil
        
        let success = await verifyToken(cleanToken)
        isSyncing = false
        
        if success {
            self.token = cleanToken
            KeychainStore.set(cleanToken, for: tokenKey)
            if UserDefaults.standard.object(forKey: autoSyncKey) == nil {
                self.autoSyncEnabled = true
            }
            // Look for existing gist or create new
            await findOrCreateGist()
            
            // Smart Initial Sync:
            // Nếu dữ liệu trên máy đang trống nhưng trên GitHub đã có bản lưu -> Tự động kéo về máy!
            if !gistId.isEmpty && VocabularyService.shared.savedWords.isEmpty {
                _ = await restoreFromGitHub(merge: false)
            } else {
                // Nếu máy đã có từ vựng -> Sao lưu lên đám mây
                _ = await backupToGitHub()
            }
        }
        
        return success
    }
    
    private func verifyToken(_ tokenToTest: String) async -> Bool {
        guard let url = URL(string: "https://api.github.com/user") else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("token \(tokenToTest)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("NekoTrans-macOS", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                lastErrorMessage = "Mã GitHub Token không hợp lệ hoặc đã hết hạn."
                return false
            }
            
            let user = try JSONDecoder().decode(GitHubUser.self, from: data)
            self.currentUser = user
            if let encoded = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(encoded, forKey: userKey)
            }
            return true
        } catch {
            lastErrorMessage = "Không thể kết nối đến GitHub: \(error.localizedDescription)"
            return false
        }
    }
    
    public func disconnect(clearLocalData: Bool = false) {
        self.token = ""
        self.gistId = ""
        self.currentUser = nil
        self.lastSyncDate = nil
        self.lastErrorMessage = nil
        
        KeychainStore.remove(account: tokenKey)
        UserDefaults.standard.removeObject(forKey: gistIdKey)
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        
        if clearLocalData {
            VocabularyService.shared.clearAllWords()
            LookupStatsService.shared.clearAllRecords()
        }
    }
    
    // MARK: - Gist Discovery & Creation
    private func findOrCreateGist() async {
        guard !token.isEmpty else { return }
        
        // 1. If we already have a gistId, verify it exists
        if !gistId.isEmpty {
            if await checkGistExists(gistId: gistId) {
                return
            }
        }
        
        // 2. Search existing gists for backup data
        guard let url = URL(string: "https://api.github.com/gists?per_page=100") else { return }
        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("NekoTrans-macOS", forHTTPHeaderField: "User-Agent")
        
        if let (data, response) = try? await URLSession.shared.data(for: request),
           let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
           let gists = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for g in gists {
                if let files = g["files"] as? [String: Any],
                   (files[compressedBackupFileName] != nil || files[primaryBackupFileName] != nil || files[legacyBackupFileName] != nil),
                   let id = g["id"] as? String {
                    self.gistId = id
                    UserDefaults.standard.set(id, forKey: gistIdKey)
                    return
                }
            }
        }
    }
    
    private func checkGistExists(gistId: String) async -> Bool {
        guard let url = URL(string: "https://api.github.com/gists/\(gistId)") else { return false }
        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("NekoTrans-macOS", forHTTPHeaderField: "User-Agent")
        
        if let (_, response) = try? await URLSession.shared.data(for: request),
           let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            return true
        }
        return false
    }
    
    // MARK: - Backup (Push to GitHub Gist with Apple LZFSE Compression)
    public func backupToGitHub() async -> Bool {
        guard isConnected else {
            lastErrorMessage = "Chưa kết nối tài khoản GitHub."
            return false
        }
        
        isSyncing = true
        lastErrorMessage = nil
        
        let payload = NekoTransBackupPayload(
            savedWords: VocabularyService.shared.savedWords,
            lookupRecords: LookupStatsService.shared.records,
            dailyGoal: LookupStatsService.shared.dailyGoal
        )
        
        guard let payloadData = try? JSONEncoder().encode(payload) else {
            isSyncing = false
            lastErrorMessage = "Lỗi đóng gói dữ liệu sao lưu."
            return false
        }
        
        // 🗜️ Nén dữ liệu bằng thuật toán Apple LZFSE siêu nhanh & nhẹ (~85% reduction)
        let filesPayload: [String: [String: String]]
        if let compressedData = DataCompression.compress(data: payloadData, algorithm: COMPRESSION_LZFSE) {
            let b64 = compressedData.base64EncodedString()
            filesPayload = [
                compressedBackupFileName: ["content": b64]
            ]
        } else if let jsonString = String(data: payloadData, encoding: .utf8) {
            filesPayload = [
                primaryBackupFileName: ["content": jsonString]
            ]
        } else {
            isSyncing = false
            lastErrorMessage = "Lỗi nén dữ liệu."
            return false
        }
        
        var success = false
        if !gistId.isEmpty {
            success = await updateExistingGist(files: filesPayload)
        } else {
            success = await createNewSecretGist(files: filesPayload)
        }
        
        isSyncing = false
        if success {
            let now = Date()
            self.lastSyncDate = now
            UserDefaults.standard.set(now, forKey: lastSyncKey)
        }
        return success
    }
    
    private func createNewSecretGist(files: [String: [String: String]]) async -> Bool {
        guard let url = URL(string: "https://api.github.com/gists") else { return false }
        
        let body: [String: Any] = [
            "description": "NekoTrans Vocabulary Notebook & Analytics Backup (Apple LZFSE Compressed)",
            "public": false,
            "files": files
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("NekoTrans-macOS", forHTTPHeaderField: "User-Agent")
        request.httpBody = httpBody
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (http.statusCode == 200 || http.statusCode == 201),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let newGistId = json["id"] as? String else {
                lastErrorMessage = "Không thể tạo Gist trên GitHub."
                return false
            }
            
            self.gistId = newGistId
            UserDefaults.standard.set(newGistId, forKey: gistIdKey)
            return true
        } catch {
            lastErrorMessage = "Lỗi tải lên GitHub: \(error.localizedDescription)"
            return false
        }
    }
    
    private func updateExistingGist(files: [String: [String: String]]) async -> Bool {
        guard let url = URL(string: "https://api.github.com/gists/\(gistId)") else { return false }
        
        let body: [String: Any] = [
            "description": "NekoTrans Vocabulary Notebook & Analytics Backup (Apple LZFSE, \(Date().formatted()))",
            "files": files
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("NekoTrans-macOS", forHTTPHeaderField: "User-Agent")
        request.httpBody = httpBody
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                // If gist was deleted remotely, fallback to create
                return await createNewSecretGist(files: files)
            }
            return true
        } catch {
            lastErrorMessage = "Lỗi cập nhật Gist: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Restore (Pull from GitHub Gist with Automatic Decompression)
    public func restoreFromGitHub(merge: Bool = true) async -> Bool {
        guard isConnected else {
            lastErrorMessage = "Chưa kết nối tài khoản GitHub."
            return false
        }
        
        if gistId.isEmpty {
            await findOrCreateGist()
        }
        
        guard !gistId.isEmpty else {
            lastErrorMessage = "Không tìm thấy bản sao lưu nào trên GitHub của bạn."
            return false
        }
        
        isSyncing = true
        lastErrorMessage = nil
        
        guard let url = URL(string: "https://api.github.com/gists/\(gistId)") else {
            isSyncing = false
            return false
        }
        
        var request = URLRequest(url: url)
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("NekoTrans-macOS", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let files = json["files"] as? [String: Any] else {
                isSyncing = false
                lastErrorMessage = "Không tìm thấy nội dung file sao lưu hợp lệ trong Gist."
                return false
            }
            
            let rawData: Data
            
            // Case A: Bản sao lưu mới dạng nén Apple LZFSE Base64
            if let compressedFile = files[compressedBackupFileName] as? [String: Any],
               let b64Content = compressedFile["content"] as? String,
               let compressedBytes = Data(base64Encoded: b64Content),
               let decompressed = DataCompression.decompress(data: compressedBytes, algorithm: COMPRESSION_LZFSE) {
                rawData = decompressed
            }
            // Case B: Bản sao lưu cũ dạng JSON thuần (NekoTrans hoặc ToolTrL)
            else if let plainFile = (files[primaryBackupFileName] as? [String: Any]) ?? (files[legacyBackupFileName] as? [String: Any]),
                    let content = plainFile["content"] as? String,
                    let contentData = content.data(using: .utf8) {
                rawData = contentData
            } else {
                isSyncing = false
                lastErrorMessage = "Không thể giải nén hoặc đọc nội dung file sao lưu."
                return false
            }
            
            let payload = try JSONDecoder().decode(NekoTransBackupPayload.self, from: rawData)
            
            // Merge or Replace Vocabulary
            if merge {
                var currentWords = VocabularyService.shared.savedWords
                for remoteWord in payload.savedWords {
                    if !currentWords.contains(where: { $0.word.lowercased() == remoteWord.word.lowercased() }) {
                        currentWords.append(remoteWord)
                    }
                }
                VocabularyService.shared.savedWords = currentWords
                VocabularyService.shared.saveWords()
            } else {
                VocabularyService.shared.savedWords = payload.savedWords
                VocabularyService.shared.saveWords()
            }
            
            // Restore Daily Goal
            if payload.dailyGoal > 0 {
                LookupStatsService.shared.dailyGoal = payload.dailyGoal
            }
            
            let now = Date()
            self.lastSyncDate = now
            UserDefaults.standard.set(now, forKey: lastSyncKey)
            
            isSyncing = false
            return true
        } catch {
            isSyncing = false
            lastErrorMessage = "Lỗi khôi phục dữ liệu: \(error.localizedDescription)"
            return false
        }
    }
}
