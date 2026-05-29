import ActivityKit
import Foundation

public struct ReelDetectionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public enum Status: String, Codable {
            case armed, analyzing, result, error
        }
        public var status: Status
        public var aiConfidence: Double
        public var isAI: Bool
        public var updatedAt: Date

        public init(
            status: Status = .armed,
            aiConfidence: Double = 0,
            isAI: Bool = false,
            updatedAt: Date = .now
        ) {
            self.status = status
            self.aiConfidence = aiConfidence
            self.isAI = isAI
            self.updatedAt = updatedAt
        }

        public var confidencePercent: Int { Int(aiConfidence * 100) }

        public var label: String {
            switch status {
            case .armed:    return "Ready"
            case .analyzing: return "Analyzing…"
            case .result:   return isAI ? "\(confidencePercent)% AI" : "\(100 - confidencePercent)% Real"
            case .error:    return "Error"
            }
        }
    }
}
