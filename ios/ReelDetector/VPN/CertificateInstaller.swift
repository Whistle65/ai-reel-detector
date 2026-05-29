import Foundation
import UIKit

struct CertificateInstaller {
    static func serveMobileConfig() {
        // The .mobileconfig is served locally via a mini HTTP server so Safari
        // can download and install it. iOS only installs profiles opened from Safari.
        let server = MobileConfigServer()
        server.start()

        guard let url = URL(string: "http://127.0.0.1:8765/ca.mobileconfig") else { return }
        UIApplication.shared.open(url)
    }
}

// Minimal HTTP server that serves the mobileconfig once, then stops.
final class MobileConfigServer {
    private var listener: CFSocket?

    func start() {
        // The mobileconfig XML is embedded in the app bundle.
        guard let profileURL = Bundle.main.url(forResource: "ca", withExtension: "mobileconfig"),
              let data = try? Data(contentsOf: profileURL) else { return }

        let server = socket(AF_INET, SOCK_STREAM, 0)
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(8765).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        var reuse = 1
        setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(server, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        listen(server, 1)

        DispatchQueue.global().async {
            let client = accept(server, nil, nil)
            if client >= 0 {
                let response = "HTTP/1.1 200 OK\r\nContent-Type: application/x-apple-aspen-config\r\nContent-Length: \(data.count)\r\nConnection: close\r\n\r\n"
                _ = response.withCString { send(client, $0, strlen($0), 0) }
                data.withUnsafeBytes { send(client, $0.baseAddress!, data.count, 0) }
                close(client)
            }
            close(server)
        }
    }
}
