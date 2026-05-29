import Foundation

struct APIClient {
    static let shared = APIClient()

    private let serverBase: String = {
        guard let base = Bundle.main.object(forInfoDictionaryKey: "SERVER_BASE_URL") as? String else {
            fatalError("SERVER_BASE_URL must be set in Info.plist")
        }
        return base
    }()

    func registerDevice(pushToken: String) async throws {
        let body: [String: Any] = [
            "device_id": AppGroup.deviceID,
            "push_token": pushToken,
        ]
        try await post(path: "/register", body: body)
    }

    func analyze(videoURL: String) async throws -> AnalysisResult {
        let body: [String: Any] = [
            "video_url": videoURL,
            "device_id": AppGroup.deviceID,
        ]
        let data = try await post(path: "/analyze", body: body)
        return try JSONDecoder().decode(AnalysisResult.self, from: data)
    }

    @discardableResult
    private func post(path: String, body: [String: Any]) async throws -> Data {
        let url = URL(string: serverBase + path)!
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

struct AnalysisResult: Codable {
    let confidence: Double
    let isAI: Bool
    let frameCount: Int

    enum CodingKeys: String, CodingKey {
        case confidence, isAI = "is_ai", frameCount = "frame_count"
    }
}
