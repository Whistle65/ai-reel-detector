import SwiftUI
import NetworkExtension

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
                VPNPage(vpn: vpn).tag(1)
                CertPage().tag(2)
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
        case 1: return vpn.isInstalled ? "Continue" : "Install VPN"
        case 2: return "Install Certificate"
        case 3: return "Allow Notifications"
        default: return "Continue"
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 1: return true
        case 3: return notificationsGranted
        default: return true
        }
    }

    private func advance() {
        switch step {
        case 1:
            if !vpn.isInstalled {
                Task { await vpn.install(); vpn.connect() }
            }
            step = 2
        case 2:
            CertificateInstaller.serveMobileConfig()
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

private struct VPNPage: View {
    @ObservedObject var vpn: VPNManager
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "network.badge.shield.half.filled")
                .resizable().scaledToFit().frame(width: 70)
                .foregroundStyle(.tint)
            Text("Step 1: Allow VPN").font(.title2.bold())
            Text("A VPN is used to route your traffic through our private analysis server. Your video content is never stored.")
                .font(.body).multilineTextAlignment(.center)
                .foregroundStyle(.secondary).padding(.horizontal)
            if let err = vpn.error {
                Text(err).font(.caption).foregroundStyle(.red)
            }
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
            Text("Step 2: Trust Certificate").font(.title2.bold())
            VStack(alignment: .leading, spacing: 8) {
                ForEach([
                    "Safari will open and download a profile",
                    "Go to Settings → General",
                    "Tap VPN & Device Management",
                    "Install the ReelDetector profile",
                    "Go to Settings → General → About → Certificate Trust Settings",
                    "Enable full trust for the certificate",
                ], id: \.self) { step in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.tint)
                        Text(step).font(.subheadline)
                    }
                }
            }
            .padding(.horizontal)
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
            Text("Allow notifications so analysis results can appear in the Dynamic Island even when the app is in the background.")
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
