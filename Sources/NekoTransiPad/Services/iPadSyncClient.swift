import Foundation
#if canImport(UIKit)
import UIKit

public struct DiscoveredMacDevice: Identifiable, Equatable, Sendable {
    public var id: String { "\(host):\(port)" }
    public let name: String
    public let host: String
    public let port: Int
    
    public init(name: String, host: String, port: Int) {
        self.name = name
        self.host = host
        self.port = port
    }
}

@MainActor
public final class iPadSyncClient: ObservableObject {
    public static let shared = iPadSyncClient()
    
    @Published public var serverHost: String = ""
    @Published public var serverPort: Int = 8099
    @Published public var isConnected: Bool = false
    @Published public var currentTaskId: String = ""
    @Published public var currentTaskText: String = ""
    @Published public var currentTaskImage: UIImage? = nil
    @Published public var isSubmitting: Bool = false
    @Published public var statusMessage: String = "Sẵn sàng kết nối"
    
    @Published public var isSearchingBonjour: Bool = false
    @Published public var discoveredMacName: String = ""
    @Published public var discoveredDevices: [DiscoveredMacDevice] = []
    @Published public var autoConnectedViaBonjour: Bool = false
    
    public var onNewTaskReceived: (() -> Void)?
    
    private var bonjourDiscovery: BonjourMacDiscovery?
    private var syncTimer: Timer?
    private var lastLoadedImageBase64: String = ""
    
    // Shared optimized URLSession for persistent TCP keep-alive connection pooling
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 4.0
        config.timeoutIntervalForResource = 15.0
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpShouldSetCookies = false
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
    
    private init() {
        if let savedHost = UserDefaults.standard.string(forKey: "tooltrl_mac_host") {
            self.serverHost = savedHost
        }
        let savedPort = UserDefaults.standard.integer(forKey: "tooltrl_mac_port")
        if savedPort > 0 {
            self.serverPort = savedPort
        }
        
        setupLifecycleObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Smart Background / Foreground Lifecycle (Battery & CPU Saver)
    private func setupLifecycleObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopRealtimeSync()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, !self.serverHost.isEmpty else { return }
            self.startRealtimeSync()
            Task { @MainActor in
                await self.fetchTaskFromMac()
            }
        }
    }
    
    // MARK: - Continuous Real-Time Sync Loop
    public func startRealtimeSync() {
        stopRealtimeSync()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self, !self.serverHost.isEmpty, !self.isSubmitting else { return }
            Task { @MainActor in
                await self.pollTaskUpdate()
            }
        }
    }
    
    public func stopRealtimeSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }
    
    public func pollTaskUpdate() async {
        guard !serverHost.isEmpty, let url = URL(string: "\(apiBaseURL)/api/task") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else { return }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let taskId = (json["taskId"] as? String) ?? ""
                let text = (json["text"] as? String) ?? ""
                let imgB64 = (json["imageBase64"] as? String) ?? ""
                
                // If a NEW task is detected from Mac
                if !taskId.isEmpty && taskId != self.currentTaskId {
                    var img: UIImage? = nil
                    if !imgB64.isEmpty {
                        autoreleasepool {
                            let clean = imgB64
                                .replacingOccurrences(of: "data:image/png;base64,", with: "")
                                .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                            if let imgData = Data(base64Encoded: clean, options: .ignoreUnknownCharacters) {
                                img = UIImage(data: imgData)
                            }
                        }
                    }
                    
                    self.lastLoadedImageBase64 = imgB64
                    self.currentTaskId = taskId
                    self.currentTaskText = text
                    self.currentTaskImage = img
                    self.isConnected = true
                    self.statusMessage = "⚡️ Đã nhận đề bài mới từ Mac"
                    self.onNewTaskReceived?()
                }
            }
        } catch {
            // Ignore background heartbeat failure quietly
        }
    }
    
    // MARK: - Apple Ecosystem Zero-Config Bonjour Discovery
    public func startAutoDiscovery() {
        startRealtimeSync()
        isSearchingBonjour = true
        statusMessage = "Đang tự động quét tìm máy Mac trong mạng..."
        
        let discovery = BonjourMacDiscovery()
        discovery.onDeviceFound = { [weak self] name, ipOrHost, port in
            guard let self = self else { return }
            Task { @MainActor in
                let device = DiscoveredMacDevice(name: name, host: ipOrHost, port: port)
                if !self.discoveredDevices.contains(where: { $0.id == device.id }) {
                    self.discoveredDevices.append(device)
                }
                
                // If not connected yet or matching previous host, auto-connect
                if !self.isConnected || self.serverHost.isEmpty {
                    self.selectDevice(device)
                }
            }
        }
        self.bonjourDiscovery = discovery
        discovery.start()
    }
    
    public func selectDevice(_ device: DiscoveredMacDevice) {
        self.discoveredMacName = device.name
        self.serverPort = device.port
        self.setHost(device.host)
        self.autoConnectedViaBonjour = true
        self.isSearchingBonjour = false
        self.isConnected = true
        self.statusMessage = "⚡️ Đã kết nối với \(device.name)"
        self.startRealtimeSync()
        
        Task { @MainActor in
            await self.fetchTaskFromMac()
        }
    }
    
    public func stopAutoDiscovery() {
        bonjourDiscovery?.stop()
        bonjourDiscovery = nil
        isSearchingBonjour = false
    }
    
    public func setHost(_ rawInput: String) {
        var clean = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle tooltrl://connect?host=...&port=...
        if clean.hasPrefix("tooltrl://") {
            if let components = URLComponents(string: clean) {
                if let hostParam = components.queryItems?.first(where: { $0.name == "host" || $0.name == "ip" })?.value {
                    clean = hostParam
                }
                if let portParam = components.queryItems?.first(where: { $0.name == "port" })?.value, let portNum = Int(portParam) {
                    self.serverPort = portNum
                }
            }
        }
        
        // Strip http:// and https:// and paths
        clean = clean.replacingOccurrences(of: "http://", with: "")
                     .replacingOccurrences(of: "https://", with: "")
        
        if let slashIndex = clean.firstIndex(of: "/") {
            clean = String(clean[..<slashIndex])
        }
        
        // Extract host and port if host:port
        if clean.contains(":") {
            let parts = clean.components(separatedBy: ":")
            if parts.count >= 2, let portNum = Int(parts[1]) {
                self.serverPort = portNum
            }
            clean = parts[0]
        }
        
        self.serverHost = clean
        UserDefaults.standard.set(clean, forKey: "tooltrl_mac_host")
        UserDefaults.standard.set(self.serverPort, forKey: "tooltrl_mac_port")
    }
    
    public var apiBaseURL: String {
        "http://\(serverHost):\(serverPort)"
    }
    
    public func fetchTaskFromMac() async {
        guard !serverHost.isEmpty else {
            self.statusMessage = "Chưa nhập địa chỉ IP máy Mac"
            return
        }
        
        guard let url = URL(string: "\(apiBaseURL)/api/task") else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.0
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
                self.isConnected = false
                self.statusMessage = "Không kết nối được với Mac"
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let taskId = (json["taskId"] as? String) ?? ""
                let text = (json["text"] as? String) ?? ""
                let imgB64 = (json["imageBase64"] as? String) ?? ""
                var img: UIImage? = nil
                
                if !imgB64.isEmpty {
                    autoreleasepool {
                        let clean = imgB64
                            .replacingOccurrences(of: "data:image/png;base64,", with: "")
                            .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                        if let imgData = Data(base64Encoded: clean, options: .ignoreUnknownCharacters) {
                            img = UIImage(data: imgData)
                        }
                    }
                }
                
                let isNewTask = (!taskId.isEmpty && (taskId != self.currentTaskId || self.currentTaskText != text))
                self.lastLoadedImageBase64 = imgB64
                self.isConnected = true
                self.currentTaskId = taskId
                self.currentTaskText = text
                self.currentTaskImage = img
                self.statusMessage = "⚡️ Đã đồng bộ đề bài từ Mac"
                if isNewTask {
                    self.onNewTaskReceived?()
                }
            }
        } catch {
            self.isConnected = false
            self.statusMessage = "Lỗi kết nối: \(error.localizedDescription)"
        }
    }
    
    public func submitDrawingToMac(image: UIImage) async -> Bool {
        guard !serverHost.isEmpty, let url = URL(string: "\(apiBaseURL)/api/submit") else { return false }
        
        self.isSubmitting = true
        self.statusMessage = "Đang gửi bài sang Mac..."
        
        var imgData: Data? = nil
        autoreleasepool {
            // Highly optimized JPEG compression (0.82) for fast network transmission
            imgData = image.jpegData(compressionQuality: 0.82) ?? image.pngData()
        }
        
        guard let finalData = imgData else {
            self.isSubmitting = false
            return false
        }
        
        let base64 = "data:image/jpeg;base64,\(finalData.base64EncodedString())"
        let payload: [String: Any] = [
            "imageBase64": base64,
            "notes": currentTaskText
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 12.0
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        
        do {
            let (_, response) = try await urlSession.data(for: request)
            let success = (response as? HTTPURLResponse)?.statusCode == 200
            self.isSubmitting = false
            self.statusMessage = success ? "✅ Đã gửi sang Mac thành công!" : "Lỗi khi gửi bài"
            return success
        } catch {
            self.isSubmitting = false
            self.statusMessage = "Lỗi kết nối: \(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - Native Bonjour Browser (Apple Ecosystem Zero-Config)
final class BonjourMacDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate, @unchecked Sendable {
    private let browser = NetServiceBrowser()
    private var pendingServices: [NetService] = []
    
    var onDeviceFound: ((String, String, Int) -> Void)?
    
    func start() {
        browser.delegate = self
        pendingServices.removeAll()
        browser.searchForServices(ofType: "_tooltrl._tcp.", inDomain: "local.")
    }
    
    func stop() {
        browser.stop()
        pendingServices.forEach { $0.stop() }
        pendingServices.removeAll()
    }
    
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        pendingServices.append(service)
        service.delegate = self
        service.resolve(withTimeout: 5.0)
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        let cleanName = sender.name.replacingOccurrences(of: "ToolTrL-", with: "")
        let port = sender.port > 0 ? sender.port : 8099
        
        // Priority 1: Real IPv4 address from network interface (fastest, most reliable)
        if let ip = extractIPv4(from: sender) {
            onDeviceFound?(cleanName, ip, port)
            return
        }
        
        // Priority 2: Clean mDNS hostname without trailing dot
        if let host = sender.hostName?.trimmingCharacters(in: CharacterSet(charactersIn: ".")) {
            let fullHost = host.contains(".local") ? host : "\(host).local"
            onDeviceFound?(cleanName, fullHost, port)
            return
        }
    }
    
    private func extractIPv4(from service: NetService) -> String? {
        guard let addresses = service.addresses else { return nil }
        for data in addresses {
            var storage = sockaddr_storage()
            (data as NSData).getBytes(&storage, length: MemoryLayout<sockaddr_storage>.size)
            if storage.ss_family == sa_family_t(AF_INET) {
                var addr = sockaddr_in()
                (data as NSData).getBytes(&addr, length: MemoryLayout<sockaddr_in>.size)
                if let ip = inet_ntoa(addr.sin_addr) {
                    let strIP = String(cString: ip)
                    if strIP != "127.0.0.1" && !strIP.isEmpty {
                        return strIP
                    }
                }
            }
        }
        return nil
    }
}
#endif
