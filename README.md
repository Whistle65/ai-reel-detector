# AI Reel Detector

Passive iOS app that detects AI-generated Instagram Reels using a VPN tunnel + Dynamic Island.

## Architecture

```
iPhone (Instagram) → WireGuard VPN → VPS (mitmproxy) → Hive API → APNs → Dynamic Island
```

## Build Order

### Phase 1 — Detection Pipeline (test first)

```bash
cd server
pip install -r requirements.txt
cp .env.example .env   # fill in HIVE_API_KEY
# populate TEST_SET in test_pipeline.py with real reel URLs
python test_pipeline.py
```

### Phase 2 — VPS Setup

1. Rent Hetzner CX21 (or any Ubuntu 22.04 VPS)
2. Copy project to `/opt/reeldetector/`
3. Fill in `.env` on the VPS
4. `bash setup.sh`
5. The script prints the mitmproxy CA path — copy it to your Mac:
   ```bash
   scp root@YOUR_VPS:/root/.mitmproxy/mitmproxy-ca-cert.pem ./ios/ReelDetector/Resources/
   cd ios/ReelDetector/Resources
   python generate_mobileconfig.py
   ```
6. Copy `ca.mobileconfig` into your Xcode project as a resource

### Phase 3 — iOS App (requires Mac + Xcode 16+)

#### Xcode Project Setup

1. Create new project: **File → New → Project → App**
   - Bundle ID: `com.yourname.reeldetector`
   - Language: Swift, Interface: SwiftUI

2. Add two additional targets:
   - **Network Extension** → `PacketTunnel` (bundle: `com.yourname.reeldetector.tunnel`)
   - **Widget Extension** → `ReelWidget` (bundle: `com.yourname.reeldetector.widget`)

3. Add an **App Group** capability to all three targets: `group.com.yourname.reeldetector`

4. Copy source files into each target:
   | File | Target |
   |------|--------|
   | `ios/ReelDetector/**/*.swift` | Main app |
   | `ios/Shared/*.swift` | All 3 targets |
   | `ios/PacketTunnel/PacketTunnelProvider.swift` | PacketTunnel |
   | `ios/ReelWidget/*.swift` | ReelWidget |

5. Set entitlements (replace the Xcode-generated ones with the provided `.entitlements` files)

6. In `Info.plist`, replace `YOUR_VPS_IP` with your actual VPS IP

7. Apply for the `networkextension` entitlement at:
   https://developer.apple.com/contact/request/network-extension-packet-tunnel

#### APNs Setup

1. In Apple Developer Portal → Certificates → Keys → create a new APNs key
2. Download the `.p8` file
3. Upload to VPS: `scp AuthKey_KEYID.p8 root@YOUR_VPS:/opt/reeldetector/`
4. Update `.env` with the Team ID and Key ID

### Phase 4 — Dynamic Island

The `ReelWidget.swift` implements all Dynamic Island states automatically:
- **Compact**: eye icon (armed) → spinner (analyzing) → percentage (result)
- **Expanded**: confidence bar + percentage
- **Minimal**: colored dot

### Phase 5 — Test End to End

1. Install app on device
2. Complete onboarding (VPN + cert + notifications)
3. Open Instagram, watch a Reel
4. Dynamic Island updates within ~4.5 seconds

## Customization

| File | What to change |
|------|---------------|
| `server/config/domains.json` | CDN domains (no app release needed) |
| `server/.env` | API keys, frame count, size limit |
| `ios/.../Info.plist` | `SERVER_BASE_URL`, `SERVER_HOST` |
| All `com.yourname.reeldetector` | Replace with your actual bundle ID |

## Known Limitations

- **VPN conflict**: iOS allows only one VPN at a time. Users with Mullvad/ProtonVPN must disable theirs.
- **Low power mode**: iOS may suspend the VPN. The Dynamic Island shows a paused state.
- **Root cert**: ~7 taps in Settings. The animated onboarding walks through each step.
- **App Review**: Include justification: "VPN is used solely for private AI content analysis. No user data is retained."
