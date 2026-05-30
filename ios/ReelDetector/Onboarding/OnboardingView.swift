import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @ObservedObject var vpn = VPNManager.shared
    @State private var step = 0
    @State private var notificationsGranted = false
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            TabView(selection: $step) {
                WelcomePage().tag(0)
                CertPage().tag(1)
                WireGuardPage(vpn: vpn).tag(2)
                NotificationsPage(granted: $notificationsGranted).tag(3)
                ReadyPage(onComplete: onComplete).tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            VStack {
                Spacer()
                if step < 4 {
                    Button(action: advance) {
                        Text(nextLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canAdvance ? Color.accentColor : Color.gray)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal)
                    }
                    .disabled(!canAdvance)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var nextLabel: String {
        switch step {
        case 0: return "Get Started"
        case 1: return "Install Certificate"
        case 2: return "Open WireGuard"
        case 3: return "Allow Notifications"
        default: return "Continue"
        }
    }

    private var canAdvance: Bool {
        step == 3 ? notificationsGranted : true
    }

    private func advance() {
        switch step {
        case 1:
            CertificateInstaller.serveMobileConfig()
            step = 2
        case 2:
            vpn.openWireGuard()
            step = 3
        case 3:
            requestNotifications()
        default:
            step += 1
        }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge]) { granted, _ in
            DispatchQueue.main.async {
                notificationsGranted = granted
                step = 4
            }
        }
    }
}

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "waveform.badge.magnifyingglass")
                .resizable().scaledToFit().frame(width: 80)
                .foregroundStyle(.tint)
            Text("ReelDetector")
                .font(.largeTitle.bold())
            Text("Automatically detects AI-generated Instagram Reels while you scroll. Results appear in the Dynamic Island — you never leave Instagram.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
        }
        .padding()
    }
}

private struct CertPage: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "lock.shield")
                .resizable().scaledToFit().frame(width: 70)
                .foregroundStyle(.tint)
            Text("Step 1: Trust Certificate").font(.title2.bold())
            Text("ReelDetector needs to inspect HTTPS traffic to detect Reels. This requires installing a trusted certificate.")
                .font(.body).multilineTextAlignment(.center)
                .foregroundStyle(.secondary).padding(.horizontal)
            VStack(alignment: .leading, spacing: 10) {
                ForEach([
                    "Tap below — Safari opens and downloads a profile",
                    "Go to Settings → General → VPN & Device Management",
                    "Install the ReelDetector profile",
                    "Go to Settings → General → About → Certificate Trust Settings",
                    "Enable full trust for the ReelDetector certificate",
                ], id: \.self) { instruction in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "chevron.right.circle.fill")
                            .foregroundStyle(.tint)
                        Text(instruction).font(.subheadline)
                    }
                }
            }
            .padding(.horizontal)
            Spacer()
        }
        .padding()
    }
}

private struct WireGuardPage: View {
    @ObservedObject var vpn: VPNManager
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "network.badge.shield.half.filled")
                .resizable().scaledToFit().frame(width: 70)
                .foregroundStyle(.tint)
            Text("Step 2: Set Up VPN").font(.title2.bold())
            Text("Traffic is routed through a private VPN so Reels can be analyzed. You'll use the free WireGuard app.")
                .font(.body).multilineTextAlignment(.center)
                .foregroundStyle(.secondary).padding(.horizontal)
            VStack(alignment: .leading, spacing: 10) {
                ForEach([
                    "Install WireGuard from the App Store if you haven't already",
                    "Tap below to open WireGuard",
                    "Tap + → Create from QR Code",
                    "Scan the QR code shown in your VPS terminal",
                    "Enable the tunnel in WireGuard",
                ], id: \.self) { instruction in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "chevron.right.circle.fill")
                            .foregroundStyle(.tint)
                        Text(instruction).font(.subheadline)
                    }
                }
            }
            .padding(.horizontal)
            if vpn.isConnected {
                Label("VPN Connected", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline.bold())
            }
            Spacer()
        }
        .padding()
    }
}

private struct NotificationsPage: View {
    @Binding var granted: Bool
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "bell.badge")
                .resizable().scaledToFit().frame(width: 70)
                .foregroundStyle(.tint)
            Text("Step 3: Notifications").font(.title2.bold())
            Text("Allow notifications so analysis results appear in the Dynamic Island even when the app is in the background.")
                .font(.body).multilineTextAlignment(.center)
                .foregroundStyle(.secondary).padding(.horizontal)
            Spacer()
        }
        .padding()
    }
}

private struct ReadyPage: View {
    var onComplete: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .resizable().scaledToFit().frame(width: 80)
                .foregroundStyle(.green)
            Text("All Set!").font(.largeTitle.bold())
            Text("Open Instagram and watch any Reel. Results will appear in the Dynamic Island at the top of your screen.")
                .font(.body).multilineTextAlignment(.center)
                .foregroundStyle(.secondary).padding(.horizontal)
            Button("Open Instagram") {
                onComplete()
                if let url = URL(string: "instagram://") {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding()
    }
}
