import Foundation
import Network
import NetworkExtension
import UIKit
import Combine

@MainActor
final class VPNManager: ObservableObject {
    static let shared = VPNManager()

    @Published var isConnected = false

    private var monitor: NWPathMonitor?

    func load() async {
        let m = NWPathMonitor()
        monitor = m
        m.pathUpdateHandler = { [weak self] path in
            // WireGuard (and other VPN tunnels) create utun interfaces, which
            // NWPathMonitor reports as .other on iOS. Wi-Fi is .wifi, cellular is .cellular.
            let vpnActive = path.usesInterfaceType(.other) && path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isConnected = vpnActive
            }
        }
        m.start(queue: DispatchQueue.global(qos: .background))
    }

    // Computed to keep ContentView's switch statements working without changes
    var status: NEVPNStatus { isConnected ? .connected : .disconnected }

    func openWireGuard() {
        let wireGuard = URL(string: "wireguard://")!
        if UIApplication.shared.canOpenURL(wireGuard) {
            UIApplication.shared.open(wireGuard)
        } else {
            // itms-apps opens App Store app directly, avoiding browser redirect issues
            let appStore = URL(string: "itms-apps://itunes.apple.com/app/id1441195209")!
            UIApplication.shared.open(appStore)
        }
    }
}
