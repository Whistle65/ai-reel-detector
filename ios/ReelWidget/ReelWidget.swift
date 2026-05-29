import ActivityKit
import SwiftUI
import WidgetKit

struct ReelWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReelDetectionAttributes.self) { context in
            // Lock screen / notification banner
            LockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded view (long press)
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.label)
                            .font(.subheadline.weight(.semibold))
                    } icon: {
                        statusIcon(context.state)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.status == .result {
                        Text("\(context.state.confidencePercent)%")
                            .font(.title2.bold().monospacedDigit())
                            .foregroundStyle(context.state.isAI ? .orange : .green)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.status == .result {
                        ConfidenceBar(value: context.state.aiConfidence, isAI: context.state.isAI)
                            .padding(.horizontal)
                    }
                }
            } compactLeading: {
                statusIcon(context.state)
                    .foregroundStyle(compactColor(context.state))
            } compactTrailing: {
                if context.state.status == .result {
                    Text("\(context.state.confidencePercent)%")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(context.state.isAI ? .orange : .green)
                } else if context.state.status == .analyzing {
                    ProgressView().scaleEffect(0.7)
                }
            } minimal: {
                statusIcon(context.state)
                    .foregroundStyle(compactColor(context.state))
            }
            .widgetURL(URL(string: "reeldetector://result"))
            .keylineTint(compactColor(context.state))
        }
    }

    @ViewBuilder
    private func statusIcon(_ state: ReelDetectionAttributes.ContentState) -> some View {
        switch state.status {
        case .armed:
            Image(systemName: "eye.fill")
        case .analyzing:
            Image(systemName: "waveform")
        case .result:
            Image(systemName: state.isAI ? "cpu.fill" : "checkmark.seal.fill")
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    private func compactColor(_ state: ReelDetectionAttributes.ContentState) -> Color {
        switch state.status {
        case .armed:    return .white
        case .analyzing: return .blue
        case .result:   return state.isAI ? .orange : .green
        case .error:    return .red
        }
    }
}

private struct LockScreenView: View {
    let state: ReelDetectionAttributes.ContentState

    var body: some View {
        HStack {
            Image(systemName: "waveform.badge.magnifyingglass")
                .font(.title3)
            VStack(alignment: .leading) {
                Text("ReelDetector")
                    .font(.caption.weight(.semibold))
                Text(state.label)
                    .font(.subheadline)
            }
            Spacer()
            if state.status == .result {
                Text("\(state.confidencePercent)%")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(state.isAI ? .orange : .green)
            } else if state.status == .analyzing {
                ProgressView()
            }
        }
        .padding()
    }
}

private struct ConfidenceBar: View {
    let value: Double
    let isAI: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.3))
                Capsule()
                    .fill(isAI ? Color.orange : Color.green)
                    .frame(width: geo.size.width * value)
            }
        }
        .frame(height: 6)
    }
}
