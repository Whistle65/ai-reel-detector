import SwiftUI

struct ContentView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    @ObservedObject var vpn = VPNManager.shared

    var body: some View {
        if !onboardingComplete {
            OnboardingView {
                onboardingComplete = true
                if #available(iOS 16.2, *) {
                    Task { await LiveActivityManager.shared.startActivity() }
                }
            }
        } else {
            MainTabView()
                .task {
                    await vpn.load()
                    if #available(iOS 16.2, *) {
                        await LiveActivityManager.shared.startActivity()
                    }
                }
        }
    }
}

private struct MainTabView: View {
    @ObservedObject var vpn = VPNManager.shared

    var body: some View {
        TabView {
            StatusView()
                .tabItem { Label("Status", systemImage: "dot.radiowaves.left.and.right") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

private struct StatusView: View {
    @ObservedObject var vpn = VPNManager.shared

    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 24, height: 24)
                    Text(statusLabel)
                        .font(.headline)
                }

                VStack(spacing: 4) {
                    Image(systemName: "pill.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.primary)
                    Text("Dynamic Island Active")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Open Instagram and watch a Reel. Results appear automatically in the Dynamic Island.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("ReelDetector")
        }
    }

    private var statusColor: Color {
        switch vpn.status {
        case .connected: return .green
        case .connecting, .disconnecting: return .yellow
        default: return .red
        }
    }

    private var statusLabel: String {
        switch vpn.status {
        case .connected: return "VPN Connected"
        case .connecting: return "Connecting…"
        case .disconnecting: return "Disconnecting…"
        default: return "VPN Disconnected"
        }
    }
}

private struct SettingsView: View {
    @ObservedObject var vpn = VPNManager.shared
    @AppStorage("onboardingComplete") private var onboardingComplete = true

    var body: some View {
        NavigationView {
            Form {
                Section("VPN") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(vpn.isConnected ? "Connected" : "Disconnected")
                            .foregroundStyle(vpn.isConnected ? .green : .red)
                    }
                    Button("Open WireGuard") {
                        vpn.openWireGuard()
                    }
                }
                Section("Certificate") {
                    Button("Re-install Certificate") {
                        CertificateInstaller.serveMobileConfig()
                    }
                }
                Section("Account") {
                    Button("Reset Setup", role: .destructive) {
                        onboardingComplete = false
                    }
                }
                Section("Privacy") {
                    Text("No video content is retained on our servers. Each Reel is analyzed and immediately deleted.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
