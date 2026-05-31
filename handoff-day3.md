# Session Handoff — Day 3

## 1. What Was Accomplished

- Created Xcode project on MacInCloud with 3 targets: `ReelDetector`, `PacketTunnel`, `ReelWidgetExtension`
- Added App Group `group.com.leee1.ReelDetector` to all 3 targets
- Pushed the full codebase to GitHub (github.com/Whistle65/ai-reel-detector, public)
- Cloned the repo on MacInCloud and added all Swift source files into the Xcode project
- Discovered that the free Personal Team cannot use the Network Extension (packet-tunnel-provider) entitlement
- **Decision: drop the custom PacketTunnel target — use the WireGuard app from the App Store instead**

---

## 2. Revised Architecture

The original plan used a custom `NEPacketTunnelProvider` to route traffic. This requires a paid Apple Developer account ($99/year). The new plan is simpler and works with a free account:

| Component | Old Plan | New Plan |
|---|---|---|
| VPN | Custom NEPacketTunnelProvider in the app | **WireGuard app** (free, App Store) |
| Traffic interception | Same | Same (mitmproxy on VPS) |
| AI analysis | Same | Same (FastAPI on VPS) |
| Dynamic Island | Custom Live Activity | Same — no change needed |
| App Store entitlements needed | NetworkExtension (restricted) | **None** |

**Flow remains identical:** iPhone → WireGuard VPN → VPS → mitmproxy intercepts Instagram CDN URL → FastAPI analyzes → APNs push → Dynamic Island shows result.

---

## 3. Current Xcode Project State

**Location on MacInCloud:** `~/Desktop/ReelDetector/`
**Repo on MacInCloud:** `~/ai-reel-detector/`

### Targets

| Target | Bundle ID | Status |
|---|---|---|
| ReelDetector | com.leee1.ReelDetector | Source files added, builds with signing warnings |
| PacketTunnel | com.leee1.ReelDetector.PacketTunnel | **To be deleted — replaced by WireGuard app** |
| ReelWidgetExtension | com.leee1.ReelDetector.ReelWidgetExtension | Source files added |

### Source files added to Xcode

```
ReelDetector/
├── App/ContentView.swift, ReelDetectorApp.swift
├── History/HistoryStore.swift, HistoryView.swift
├── LiveActivity/ReelDetectionAttributes.swift, LiveActivityManager.swift
├── Onboarding/OnboardingView.swift
├── VPN/VPNManager.swift, CertificateInstaller.swift   ← needs rewrite (see below)
├── Resources/Info.plist, ReelDetector.entitlements
├── APIClient.swift (Shared)
└── AppGroupContainer.swift (Shared)

ReelWidgetExtension/
├── ReelWidget.swift
└── ReelWidgetBundle.swift
```

---

## 4. What Needs to Change (New Architecture)

### A. Delete PacketTunnel target
In Xcode: click PacketTunnel target → minus button at bottom → Delete.

### B. Rewrite VPNManager.swift
The current `VPNManager.swift` uses `NEVPNManager` to manage the custom tunnel. With the WireGuard app handling VPN, this class should be simplified to just check if a VPN is active (using `NEVPNManager` in read-only mode) so the status dot in the UI still works.

New simplified behavior:
- `VPNManager.isConnected` → check `NEVPNManager.shared().connection.status == .connected`
- Remove all install/connect/disconnect logic (user controls VPN in WireGuard app)
- The Settings view "Connect/Disconnect" button should deep-link to the WireGuard app instead

### C. Rewrite OnboardingView.swift
Old onboarding: VPN setup → cert install → notification permission.
New onboarding:
1. **Step 1** — Install mitmproxy CA cert (still needed for TLS inspection)
2. **Step 2** — Open WireGuard app and import config (show QR code or share `.conf` file)
3. **Step 3** — Grant notification permission

### D. Generate WireGuard config for iPhone
On the VPS, generate a WireGuard config file for the iPhone peer and display it as a QR code:

```bash
# On VPS (SSH in first)
apt-get install -y qrencode

cat > /tmp/iphone.conf << EOF
[Interface]
PrivateKey = $(cat /etc/wireguard/iphone_private.key)
Address = 10.0.0.2/24
DNS = 8.8.8.8

[Peer]
PublicKey = $(cat /etc/wireguard/server_public.key)
Endpoint = 78.46.218.15:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

qrencode -t ansiutf8 < /tmp/iphone.conf
```

Then add the iPhone's public key to the VPS `wg0.conf`:
```bash
IPHONE_PUB=$(cat /etc/wireguard/iphone_public.key)
cat >> /etc/wireguard/wg0.conf << EOF

[Peer]
PublicKey = $IPHONE_PUB
AllowedIPs = 10.0.0.2/32
EOF

wg-quick down wg0 && wg-quick up wg0
```

### E. CertificateInstaller.swift
This serves the mitmproxy `.mobileconfig` via a local HTTP server so Safari can install it. The file `mitmproxy-ca-cert.pem` needs to be bundled into the app. It was already copied to:
`C:\Users\leee1\ai-reel-detector\ios\ReelDetector\Resources\mitmproxy-ca-cert.pem`
This file needs to be added to Xcode under Resources.

---

## 5. What Was Tried and Failed This Session

| What | Error | Fix/Decision |
|---|---|---|
| Oracle Cloud A1.Flex ARM | Out of capacity on all 3 ADs | Switched to Hetzner |
| Hetzner CAX11 ARM | Limited availability at all locations | Used CX23 x86 AMD instead |
| Custom NEPacketTunnelProvider | Free Personal Team doesn't support NetworkExtension entitlement | Switched to WireGuard app from App Store |
| `git clone` with GitHub password | Password auth no longer supported | Use Personal Access Token |
| Personal Access Token paste in terminal | 403 write access error | Made repo public instead |
| Duplicate template files in Xcode | Two ReelWidget.swift, two ReelWidgetBundle.swift | Deleted originals, renamed "2" versions |
| PacketTunnel.entitlements missing | File not in Xcode project directory | Copied from cloned repo with `cp` |

---

## 6. Next Steps (in order)

### On MacInCloud (current session or next)

1. **Delete PacketTunnel target** from Xcode project
2. **Read and rewrite VPNManager.swift** — remove NEVPNManager tunnel management, keep only status check
3. **Rewrite OnboardingView.swift** — new 3-step flow (cert → WireGuard QR → notifications)
4. **Add mitmproxy-ca-cert.pem** to Xcode resources (it's in the repo under `ios/ReelDetector/Resources/`)
5. **Try to build** — fix any remaining compile errors
6. **Connect iPhone to MacInCloud** via USB (MacInCloud supports USB passthrough via their client) to install the app

### On VPS (local PowerShell SSH)

7. **Generate WireGuard QR code** for iPhone (commands in Section 4D above)
8. **Add iPhone peer** to `wg0.conf` and restart WireGuard

### On iPhone

9. Install **WireGuard** from App Store
10. Scan QR code to import VPN config
11. Install mitmproxy CA cert via the app's onboarding
12. Enable WireGuard VPN
13. Open Instagram, watch a Reel → confirm Dynamic Island shows result

### Later — Real AI Detection

14. Get Hive API key from thehive.ai
15. Set `_HIVE_ENABLED = True` in VPS `analyzer.py`
16. Run accuracy test (need >80%)

---

## 7. Key Files Reference

| File | Location | Purpose |
|---|---|---|
| SSH key | `C:\Users\leee1\.ssh\id_ed25519` | SSH to VPS |
| VPS IP | `78.46.218.15` | Hetzner CX23 |
| GitHub repo | github.com/Whistle65/ai-reel-detector | Public, used to transfer code to MacInCloud |
| mitmproxy CA cert | `ios/ReelDetector/Resources/mitmproxy-ca-cert.pem` | Must be bundled in app for cert install flow |
| WireGuard iPhone private key | `/etc/wireguard/iphone_private.key` on VPS | Used to generate iPhone WireGuard config |
| WireGuard server public key | `/etc/wireguard/server_public.key` on VPS | Goes in iPhone WireGuard config |
