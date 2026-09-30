import SwiftUI

#if canImport(UIKit)
import UIKit

public struct RadarDeviceDiscoveryView: View {
    @ObservedObject var client = iPadSyncClient.shared
    public var onSelect: (DiscoveredMacDevice) -> Void
    
    @State private var radarRotation: Double = 0
    @State private var ripplePulse: Bool = false
    
    public init(onSelect: @escaping (DiscoveredMacDevice) -> Void) {
        self.onSelect = onSelect
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header Info
            VStack(spacing: 4) {
                Text("BẢN ĐỒ KẾT NỐI CONTINUITY")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .cornerRadius(8)
                
                Text(client.discoveredDevices.isEmpty ? "Đang quét tìm máy Mac xung quanh qua Bonjour..." : "Tìm thấy \(client.discoveredDevices.count) máy Mac. Chạm vào thiết bị để kết nối.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 10)
            
            // RADAR CIRCULAR MAP
            ZStack {
                // Background Concentric Rings
                ForEach([80, 160, 240, 320], id: \.self) { size in
                    Circle()
                        .stroke(Color.blue.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                        .frame(width: CGFloat(size), height: CGFloat(size))
                }
                
                // Pulsing Expanding Ripple Wave
                Circle()
                    .stroke(Color.blue.opacity(ripplePulse ? 0.0 : 0.35), lineWidth: 2)
                    .frame(width: 320, height: 320)
                    .scaleEffect(ripplePulse ? 1.15 : 0.85)
                
                // Continuous Sweeping Radar Beam
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(0.35),
                                Color.cyan.opacity(0.15),
                                Color.clear,
                                Color.clear
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: 320, height: 320)
                    .rotationEffect(.degrees(radarRotation))
                
                // CENTER NODE: This iPad
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 58, height: 58)
                            .shadow(color: Color.blue.opacity(0.4), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "ipad.and.pencil")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("iPad này")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                // SURROUNDING DISCOVERED MAC DEVICES IN ORBIT
                if !client.discoveredDevices.isEmpty {
                    let count = client.discoveredDevices.count
                    let radius: CGFloat = 125
                    
                    ForEach(Array(client.discoveredDevices.enumerated()), id: \.element.id) { index, device in
                        let angle = (2.0 * .pi / Double(max(1, count))) * Double(index) - (.pi / 2.0)
                        let xOffset = CGFloat(cos(angle)) * radius
                        let yOffset = CGFloat(sin(angle)) * radius
                        let isSelected = client.serverHost == device.host && client.serverPort == device.port
                        
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onSelect(device)
                        }) {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? Color.green : Color(uiColor: .systemBackground))
                                        .frame(width: 54, height: 54)
                                        .shadow(color: isSelected ? Color.green.opacity(0.4) : Color.black.opacity(0.15), radius: 8, x: 0, y: 3)
                                        .overlay(
                                            Circle()
                                                .stroke(isSelected ? Color.green : Color.blue, lineWidth: isSelected ? 2.5 : 1.5)
                                        )
                                    
                                    Image(systemName: isSelected ? "laptopcomputer.and.ipad" : "laptopcomputer")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundColor(isSelected ? .white : .blue)
                                }
                                
                                Text(device.name)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Text(isSelected ? "🟢 Đã nối" : "Chạm để nối")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(isSelected ? .green : .blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(isSelected ? Color.green.opacity(0.12) : Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                        .buttonStyle(.plain)
                        .offset(x: xOffset, y: yOffset)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .frame(height: 340)
            .onAppear {
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    radarRotation = 360
                }
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    ripplePulse = true
                }
            }
            .onDisappear {
                radarRotation = 0
                ripplePulse = false
            }
            
            // Bottom Discovered Devices List
            if !client.discoveredDevices.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DANH SÁCH THIẾT BỊ XUNG QUANH")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)
                    
                    VStack(spacing: 8) {
                        ForEach(client.discoveredDevices) { device in
                            let isSelected = client.serverHost == device.host && client.serverPort == device.port
                            
                            HStack(spacing: 12) {
                                Image(systemName: "laptopcomputer")
                                    .font(.system(size: 20))
                                    .foregroundColor(isSelected ? .green : .blue)
                                    .frame(width: 36, height: 36)
                                    .background(isSelected ? Color.green.opacity(0.12) : Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(device.name)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text("\(device.host):\(device.port)")
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if isSelected {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                        Text("Đang kết nối")
                                    }
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.green.opacity(0.12))
                                    .cornerRadius(8)
                                } else {
                                    Button("Kết Nối") {
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        onSelect(device)
                                    }
                                    .font(.system(size: 13, weight: .semibold))
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                                }
                            }
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            
            Spacer()
        }
    }
}

#if DEBUG
#Preview("Radar Device Discovery") {
    RadarDeviceDiscoveryView { _ in }
        .preferredColorScheme(.light)
}
#endif
#endif

