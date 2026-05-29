import Foundation
import NetworkExtension
import Combine

@MainActor
final class VPNManager: ObservableObject {
    static let shared = VPNManager()

    @Published var status: NEVPNStatus = .disconnected
    @Published var error: String?

    private var manager: NETunnelProviderManager?
    private var observer: Any?

    func load() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            manager = managers.first ?? NETunnelProviderManager()
            status = manager?.connection.status ?? .disconnected
            startObserving()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func install() async {
        guard let mgr = manager else { return }
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.yourname.reeldetector.tunnel"
        proto.serverAddress = serverAddress()
        proto.providerConfiguration = [
            "server": serverAddress(),
            "port": 51820,
        ]

        mgr.protocolConfiguration = proto
        mgr.localizedDescription = "ReelDetector VPN"
        mgr.isEnabled = true

        do {
            try await mgr.saveToPreferences()
            try await mgr.loadFromPreferences()
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    func connect() {
        do {
            try manager?.connection.startVPNTunnel()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
    }

    var isConnected: Bool { status == .connected }
    var isInstalled: Bool { manager?.protocolConfiguration != nil }

    private func startObserving() {
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager?.connection,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.status = self?.manager?.connection.status ?? .disconnected
            }
        }
    }

    private func serverAddress() -> String {
        Bundle.main.object(forInfoDictionaryKey: "SERVER_HOST") as? String ?? "YOUR_VPS_IP"
    }
}
