import ActivityKit
import Combine
import Foundation
import UserNotifications

@MainActor
@available(iOS 16.2, *)
final class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    private var activity: Activity<ReelDetectionAttributes>?
    @Published var pushToken: String?

    func startActivity() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let initial = ReelDetectionAttributes.ContentState(status: .armed)
        let content = ActivityContent(state: initial, staleDate: nil)

        do {
            let a = try Activity.request(
                attributes: ReelDetectionAttributes(),
                content: content,
                pushType: .token
            )
            activity = a
            await observePushToken(a)
        } catch {
            print("LiveActivity start error: \(error)")
        }
    }

    func endActivity() async {
        await activity?.end(nil, dismissalPolicy: .immediate)
        activity = nil
        pushToken = nil
    }

    func setAnalyzing() async {
        let state = ReelDetectionAttributes.ContentState(status: .analyzing)
        await activity?.update(ActivityContent(state: state, staleDate: nil))
    }

    func setResult(confidence: Double, isAI: Bool) async {
        let state = ReelDetectionAttributes.ContentState(
            status: .result, aiConfidence: confidence, isAI: isAI, updatedAt: .now
        )
        await activity?.update(ActivityContent(state: state, staleDate: nil))
    }

    func setError() async {
        let state = ReelDetectionAttributes.ContentState(status: .error)
        await activity?.update(ActivityContent(state: state, staleDate: nil))
    }

    private func observePushToken(_ a: Activity<ReelDetectionAttributes>) async {
        for await tokenData in a.pushTokenUpdates {
            let token = tokenData.map { String(format: "%02x", $0) }.joined()
            pushToken = token
            try? await APIClient.shared.registerDevice(pushToken: token)
        }
    }
}
