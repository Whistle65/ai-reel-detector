import Foundation
import NetworkExtension
import UIKit

@MainActor
final class VPNManager: ObservableObject {
    static let shared = VPNManager()

    @Published var status: NEVPNStatus = .disconnected

    private var observer: Any?

    func load() async {
        status = NEVPNManager.shared().connection.status
        observer = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: NEVPNManager.shared().connection,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.status = NEVPNManager.shared().connection.status
            }
        }
    }

    var isConnected: Bool { status == .connected }

    func openWireGuard() {
        // Deep-link into the WireGuard app; falls back to App Store if not installed
        let wireGuard = URL(string: "wireguard://")!
        let appStore = URL(string: "https://apps.apple.com/app/wireguard/id1441195209")!
        let target = UIApplication.shared.canOpenURL(wireGuard) ? wireGuard : appStore
        UIApplication.shared.open(target)
    }
}
