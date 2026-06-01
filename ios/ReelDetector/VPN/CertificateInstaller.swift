import Foundation
import UIKit

struct CertificateInstaller {
    static func serveMobileConfig() {
        guard let config = makeMobileConfig() else { return }

        // Request background execution so iOS doesn't suspend the socket server
        // when Safari opens and ReelDetector moves to the background.
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }

        guard MobileConfigServer.bindAndListen(data: config, onDone: {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }) else {
            UIApplication.shared.endBackgroundTask(bgTask)
            return
        }

        UIApplication.shared.open(URL(string: "http://127.0.0.1:8765/ca.mobileconfig")!)
    }

    private static func makeMobileConfig() -> Data? {
        guard let pemURL = Bundle.main.url(forResource: "mitmproxy-ca-cert", withExtension: "pem"),
              let pem = try? String(contentsOf: pemURL) else { return nil }

        let b64 = pem
            .components(separatedBy: .newlines)
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
            .joined()
        guard let der = Data(base64Encoded: b64) else { return nil }

        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>PayloadContent</key>
            <array>
                <dict>
                    <key>PayloadCertificateFileName</key>
                    <string>mitmproxy-ca-cert.pem</string>
                    <key>PayloadContent</key>
                    <data>\(der.base64EncodedString())</data>
                    <key>PayloadDescription</key>
                    <string>Adds the ReelDetector CA root certificate</string>
                    <key>PayloadDisplayName</key>
                    <string>ReelDetector CA</string>
                    <key>PayloadIdentifier</key>
                    <string>com.leee1.ReelDetector.ca</string>
                    <key>PayloadType</key>
                    <string>com.apple.security.root</string>
                    <key>PayloadUUID</key>
                    <string>\(UUID().uuidString)</string>
                    <key>PayloadVersion</key>
                    <integer>1</integer>
                </dict>
            </array>
            <key>PayloadDescription</key>
            <string>Allows ReelDetector to inspect HTTPS traffic for Reel detection</string>
            <key>PayloadDisplayName</key>
            <string>ReelDetector</string>
            <key>PayloadIdentifier</key>
            <string>com.leee1.ReelDetector</string>
            <key>PayloadRemovalDisallowed</key>
            <false/>
            <key>PayloadType</key>
            <string>Configuration</string>
            <key>PayloadUUID</key>
            <string>\(UUID().uuidString)</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
        </plist>
        """
        return xml.data(using: .utf8)
    }
}

enum MobileConfigServer {
    static func bindAndListen(data: Data, onDone: @escaping () -> Void) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }

        var reuse: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(8765).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else { close(sock); return false }
        listen(sock, 1)

        DispatchQueue.global(qos: .userInitiated).async {
            let client = accept(sock, nil, nil)
            if client >= 0 {
                let header = "HTTP/1.1 200 OK\r\nContent-Type: application/x-apple-aspen-config\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
                _ = header.withCString { send(client, $0, strlen($0), 0) }
                data.withUnsafeBytes { _ = send(client, $0.baseAddress!, data.count, 0) }
                close(client)
            }
            close(sock)
            onDone()
        }
        return true
    }
}
