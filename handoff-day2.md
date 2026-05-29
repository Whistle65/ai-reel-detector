# Session Handoff — Day 2

## 1. What Was Accomplished

**Phase 2 (VPS Setup) is complete.**

The server pipeline is now running in the cloud. The iPhone no longer needs the local Windows machine — analysis requests will go to the Hetzner VPS.

---

## 2. VPS Details

| Field | Value |
|---|---|
| Provider | Hetzner Cloud |
| Server name | ubuntu-4gb-nbg1-3 |
| Plan | CX23 (x86 AMD, 4 GB RAM) |
| Location | Nuremberg, Germany |
| IPv4 | 78.46.218.15 |
| OS | Ubuntu 22.04 |
| SSH key | `C:\Users\leee1\.ssh\id_ed25519` |

**SSH in:**
```powershell
ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@78.46.218.15
```

---

## 3. Services Running on VPS

All three services are active and enabled to auto-start on reboot:

| Service | Status | Purpose |
|---|---|---|
| `wg-quick@wg0` | enabled, running | WireGuard VPN on UDP 51820 |
| `reeldetector-api` | enabled, running | FastAPI server on TCP 8000 |
| `reeldetector-mitm` | enabled, running | mitmproxy transparent proxy |

**Check services:**
```bash
systemctl status wg-quick@wg0 reeldetector-api reeldetector-mitm
```

**Test health:**
```powershell
Invoke-RestMethod -Uri "http://78.46.218.15:8000/health"
```

**Test analyze (stub mode — returns random scores):**
```powershell
Invoke-RestMethod -Uri "http://78.46.218.15:8000/analyze" -Method POST -ContentType "application/json" -Body '{"video_url":"REEL_URL_HERE","device_id":"test"}'
```

---

## 4. File Locations on VPS

```
/opt/reeldetector/
└── server/
    ├── main.py
    ├── analyzer.py          — _HIVE_ENABLED = False (stub mode)
    ├── apns_sender.py
    ├── mitmproxy_addon.py
    ├── config.py
    ├── requirements.txt
    ├── setup.sh
    ├── .env                 — copied from .env.example, keys are placeholders
    └── config/domains.json

/etc/wireguard/
    ├── wg0.conf             — server private key filled in, no [Peer] yet
    ├── server_private.key
    ├── server_public.key
    ├── iphone_private.key   — for iOS WireGuard config
    └── iphone_public.key

/root/.mitmproxy/
    └── mitmproxy-ca-cert.pem  — already copied to local machine (see below)
```

**mitmproxy CA cert saved locally at:**
`C:\Users\leee1\ai-reel-detector\ios\ReelDetector\Resources\mitmproxy-ca-cert.pem`

---

## 5. WireGuard State

WireGuard is running but has **no iPhone peer yet** — the `[Peer]` block was removed from `wg0.conf` because the iOS public key doesn't exist until the app is built. The iPhone peer must be added back when the iOS app is ready.

Current `/etc/wireguard/wg0.conf`:
```ini
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = <filled in>

# [Peer] block goes here when iOS app is built:
# [Peer]
# PublicKey = <iphone_public.key>
# AllowedIPs = 10.0.0.2/32
```

When ready to add the iPhone peer:
```bash
cat /etc/wireguard/iphone_public.key   # copy this value
nano /etc/wireguard/wg0.conf           # add [Peer] block
wg-quick down wg0 && wg-quick up wg0
```

---

## 6. What Was Tried and Failed

| What | Error | Fix |
|---|---|---|
| Oracle Cloud Free Tier A1.Flex | "Out of capacity" on all 3 ADs | Switched to Hetzner |
| Oracle Cloud ARM CAX11 on Hetzner | "Limited availability" at all locations | Fell back to CX23 (x86 AMD) |
| `setup.sh` using `eth0` for NAT | Would have broken on non-Hetzner naming | Fixed to auto-detect interface with `ip route` |
| `setup.sh` EnvironmentFile path `/opt/reeldetector/.env` | Wrong path — .env is inside `server/` | Fixed to `/opt/reeldetector/server/.env` |
| `scp` upload before `/opt/reeldetector/` existed | "No such file" | Created dir first with `mkdir -p` |
| WireGuard start with placeholder `IOS_DEVICE_PUBLIC_KEY_HERE` | "Key is not correct length or format" | Removed `[Peer]` block entirely until iOS app exists |
| `POST /analyze` with `{"url": "..."}` | 422 validation error | Correct field names are `video_url` and `device_id` |

---

## 7. Changes to Local Files This Session

| File | Change |
|---|---|
| `server/setup.sh` | Rewrote for Oracle→Hetzner/generic: auto-detects network interface, replaces ufw with iptables INPUT rules, fixes .env path, removes wg PostUp/PostDown (uses persistent iptables instead), services no longer auto-start until .env is filled |

---

## 8. Next Steps (in order)

### Immediate — Apple Developer Account (no Mac needed, any browser)

1. Sign up at **developer.apple.com** → $99/year — required for NetworkExtension entitlement
2. After activation, request **NetworkExtension entitlement** (takes 1–3 days for Apple approval)
3. Create App ID `com.yourname.reeldetector` in Certificates, Identifiers & Profiles → enable Network Extensions capability

### When Entitlement Is Approved — iOS App (requires macOS)

Use **MacInCloud** (~$1–2/hr) for Xcode sessions only.

1. Create Xcode project with 3 targets: `ReelDetector` (main app), `PacketTunnel`, `ReelWidget`
2. Add App Group capability: `group.com.yourname.reeldetector` to all 3 targets
3. Add `mitmproxy-ca-cert.pem` to Xcode resources (already saved locally)
4. Fill in VPS IP (`78.46.218.15`) in app config
5. Get APNs `.p8` key from Apple Developer Portal → upload to VPS:
   ```bash
   scp -i ~/.ssh/id_ed25519 AuthKey_KEYID.p8 root@78.46.218.15:/opt/reeldetector/
   ```
6. Fill in APNS keys in `/opt/reeldetector/server/.env` on VPS
7. Add iPhone WireGuard public key to `/etc/wireguard/wg0.conf` on VPS
8. Build + install on iPhone → complete onboarding (VPN → cert trust → notifications)
9. Open Instagram, watch a Reel → confirm Dynamic Island cycles: armed → analyzing → result

### Last Step — Real AI Detection (Phase 6)

1. Get Hive API key from thehive.ai
2. Set `HIVE_API_KEY=xxx` in `/opt/reeldetector/server/.env` on VPS
3. Set `_HIVE_ENABLED = True` in `analyzer.py` → redeploy:
   ```bash
   # on VPS
   nano /opt/reeldetector/server/analyzer.py   # flip _HIVE_ENABLED = True
   systemctl restart reeldetector-api
   ```
4. Run `test_pipeline.py` with 20 AI + 20 real reels — need >80% accuracy
