import Foundation

enum AppGroup {
    static let id = "group.com.yourname.reeldetector"

    // Falls back to the app's own Documents folder if the App Group isn't
    // provisioned (e.g. free-account sideload without a proper entitlement).
    static let container: URL = {
        if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
            return url
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()

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
