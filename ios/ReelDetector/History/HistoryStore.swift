import Combine
import Foundation
import SwiftUI

struct HistoryEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let confidence: Double
    let isAI: Bool
    let thumbnailData: Data?

    init(confidence: Double, isAI: Bool, thumbnailData: Data? = nil) {
        self.id = UUID()
        self.date = .now
        self.confidence = confidence
        self.isAI = isAI
        self.thumbnailData = thumbnailData
    }

    var confidencePercent: Int { Int(confidence * 100) }

    var label: String {
        isAI ? "\(confidencePercent)% AI-generated" : "\(100 - confidencePercent)% Real"
    }

    var thumbnail: Image? {
        guard let d = thumbnailData, let ui = UIImage(data: d) else { return nil }
        return Image(uiImage: ui)
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var entries: [HistoryEntry] = []

    private let storeURL = AppGroup.container.appendingPathComponent("history.json")

    init() {
        load()
    }

    func append(_ entry: HistoryEntry) {
        entries.insert(entry, at: 0)
        if entries.count > 200 { entries = Array(entries.prefix(200)) }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) else { return }
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
