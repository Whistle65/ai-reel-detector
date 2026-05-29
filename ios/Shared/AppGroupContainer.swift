import Foundation

enum AppGroup {
    static let id = "group.com.yourname.reeldetector"
    static let container = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: id)!

    static var pendingURLFile: URL {
        container.appendingPathComponent("pending_url.txt")
    }

    static var deviceIDFile: URL {
        container.appendingPathComponent("device_id.txt")
    }

    static var deviceID: String {
        if let id = try? String(contentsOf: deviceIDFile, encoding: .utf8) {
            return id
        }
        let id = UUID().uuidString
        try? id.write(to: deviceIDFile, atomically: true, encoding: .utf8)
        return id
    }
}
