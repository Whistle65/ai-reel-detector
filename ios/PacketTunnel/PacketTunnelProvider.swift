import NetworkExtension
import Foundation

final class PacketTunnelProvider: NEPacketTunnelProvider {

    private var serverConnection: NWTCPConnection?
    private var tunnelFileDescriptor: Int32 = -1
    private var readingPackets = false

    // VPS TLS endpoint
    private var serverHost: String { (protocolConfiguration as? NETunnelProviderProtocol)?
        .providerConfiguration?["server"] as? String ?? "78.46.218.15" }
    private let serverPort: Int = 8443

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        configureTunnelSettings { [weak self] error in
            guard error == nil else { completionHandler(error); return }
            self?.openServerConnection(completionHandler: completionHandler)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        readingPackets = false
        serverConnection?.cancel()
        serverConnection = nil
        completionHandler()
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(nil)
    }

    // MARK: - Tunnel Settings

    private func configureTunnelSettings(completion: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: serverHost)

        // Virtual interface address
        let ipv4 = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4

        // DNS via VPS
        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        settings.mtu = 1420

        setTunnelNetworkSettings(settings, completionHandler: completion)
    }

    // MARK: - TLS Connection to VPS

    private func openServerConnection(completionHandler: @escaping (Error?) -> Void) {
        let endpoint = NWHostEndpoint(hostname: serverHost, port: "\(serverPort)")
        let tlsParams = NWTLSParameters()
        // Trust the mitmproxy CA (system-trusted via installed profile)
        tlsParams.tlsSessionID = nil

        let conn = createTCPConnection(
            to: endpoint,
            enableTLS: true,
            tlsParameters: tlsParams,
            delegate: nil
        )
        serverConnection = conn

        conn.observe(\.state, options: [.new]) { [weak self] connection, _ in
            switch connection.state {
            case .connected:
                completionHandler(nil)
                self?.startForwarding(connection: connection)
            case .cancelled, .disconnected:
                self?.reconnect()
            default:
                break
            }
        }
    }

    // MARK: - Packet Forwarding

    private func startForwarding(connection: NWTCPConnection) {
        readingPackets = true
        readDevicePackets(connection: connection)
        readServerData(connection: connection)
    }

    private func readDevicePackets(connection: NWTCPConnection) {
        guard readingPackets else { return }
        packetFlow.readPackets { [weak self] packets, protocols in
            for packet in packets {
                var length = UInt32(packet.count).bigEndian
                var frame = Data(bytes: &length, count: 4)
                frame.append(packet)
                connection.write(frame) { _ in }
            }
            self?.readDevicePackets(connection: connection)
        }
    }

    private func readServerData(connection: NWTCPConnection) {
        guard readingPackets else { return }
        connection.readMinimumLength(4, maximumLength: 65536) { [weak self] data, error in
            guard let self, let data, error == nil else { return }

            // Parse length-prefixed frames from server
            var offset = 0
            while offset + 4 <= data.count {
                let length = data[offset..<offset+4].withUnsafeBytes {
                    UInt32(bigEndian: $0.load(as: UInt32.self))
                }
                let frameEnd = offset + 4 + Int(length)
                if frameEnd <= data.count {
                    let packet = data[(offset+4)..<frameEnd]
                    self.packetFlow.writePackets([packet], withProtocols: [NSNumber(value: AF_INET)])
                }
                offset = frameEnd
            }
            self.readServerData(connection: connection)
        }
    }

    private func reconnect() {
        guard readingPackets else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.openServerConnection { _ in }
        }
    }
}
