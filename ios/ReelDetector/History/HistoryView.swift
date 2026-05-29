import SwiftUI

struct HistoryView: View {
    @ObservedObject var store = HistoryStore.shared

    var body: some View {
        NavigationView {
            Group {
                if store.entries.isEmpty {
                    ContentUnavailableView(
                        "No Reels analyzed yet",
                        systemImage: "film.stack",
                        description: Text("Watch Instagram Reels to see results here")
                    )
                } else {
                    List {
                        ForEach(store.entries) { entry in
                            HistoryRow(entry: entry)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !store.entries.isEmpty {
                    Button("Clear", role: .destructive) { store.clear() }
                }
            }
        }
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(entry.isAI ? Color.orange : Color.green)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.label)
                    .font(.subheadline.weight(.medium))
                Text(entry.date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(entry.confidencePercent)%")
                .font(.headline.monospacedDigit())
                .foregroundStyle(entry.isAI ? .orange : .green)
        }
        .padding(.vertical, 4)
    }
}
