# Session Handoff — AI Reel Detector

## 1. Goal

Build a passive iOS app that detects AI-generated Instagram Reels without the user ever leaving Instagram.

**Core flow:** iPhone watches a Reel → VPN tunnels traffic to a VPS → mitmproxy on the VPS intercepts the Instagram CDN video URL → Python server downloads the video, extracts 20 keyframes, classifies with Hive AI API → result pushed via APNs to the Dynamic Island on the iPhone.

**Current phase:** Phase 1 (local pipeline) is complete. Starting Phase 2 (VPS setup) on Oracle Cloud Free Tier.

---

## 2. Current State of the Code

### Project structure

```
C:\Users\leee1\ai-reel-detector\
├── server\
│   ├── main.py              — FastAPI server (POST /analyze, POST /register, GET /health)
│   ├── analyzer.py          — Core pipeline: download → ffmpeg keyframes → stub score
│   ├── apns_sender.py       — APNs HTTP/2 push for Live Activity updates
│   ├── mitmproxy_addon.py   — mitmproxy addon watching Instagram CDN domains
│   ├── config.py            — Settings loaded from .env (pydantic-settings)
│   ├── requirements.txt
│   ├── setup.sh             — Full VPS provisioning script (WireGuard, iptables, systemd)
│   ├── test_pipeline.py     — Accuracy test harness (fill TEST_SET, run, need >80%)
│   ├── .env / .env.example  — Environment variables
│   ├── cookies.txt          — Instagram session cookies (Netscape format, valid as of this session)
│   └── config\domains.json  — Instagram CDN domain list
└── ios\
    ├── ReelDetector\        — Main SwiftUI app (onboarding, VPN, history, settings)
    ├── PacketTunnel\        — NEPacketTunnelProvider (TLS tunnel to VPS, packet forwarding)
    └── ReelWidget\          — WidgetKit/ActivityKit Dynamic Island widget
```

### What is complete

- **Phase 1 DONE — local pipeline fully working**
- **Test 1 PASSED**: `GET /health` returns `{"status":"ok"}`
- **Test 2 PASSED**: `POST /analyze` with a real Instagram Reel URL returns `{"confidence": 0.xx, "is_ai": true/false, "frame_count": 20}`
- **ffmpeg** installed and working at:
  `C:\Users\leee1\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.1-full_build\bin\`
- **cookies.txt** is in `server\`, is valid Netscape format, has `sessionid` and `csrftoken` — yt-dlp authenticates successfully

### Key design decisions

- `_HIVE_ENABLED = False` in `analyzer.py` — `_classify_parallel` returns random scores (0.1–0.9) with a 0.5s fake delay. One-line flip to enable real Hive classification later.
- `workers=1` in `main.py` uvicorn config — Windows doesn't pipe worker subprocess output back to the terminal; `workers=2` silently swallowed all error tracebacks.
- `_COOKIES_PATH` in `analyzer.py` uses `Path(__file__).parent / "cookies.txt"` (absolute path) — prevents `cookiefile` breaking when server is started from a different working directory.

### Windows dev environment notes

- **PATH fix** — must run this in every new PowerShell panel before starting the server:
  ```powershell
  $env:Path += ";C:\Users\leee1\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.1-full_build\bin"
  ```
- **Server start**: `cd C:\Users\leee1\ai-reel-detector\server` then `python main.py`
- **Test request**: use `Invoke-RestMethod`, not `curl` (PowerShell's `curl` is an alias for `Invoke-WebRequest`)

---

## 3. Files Modified This Session

| File | Change |
|---|---|
| `server/analyzer.py` | `_COOKIES_PATH` constant added; `cookiefile` now uses absolute path via `Path(__file__).parent` |
| `server/main.py` | `workers=2` → `workers=1` to fix Windows subprocess output visibility |

No other files were modified.

---

## 4. Everything Tried That Failed

| What was tried | Error | Why it failed | Fix applied |
|---|---|---|---|
| `asyncio.create_subprocess_exec` for ffmpeg/ffprobe | `NotImplementedError` | Windows SelectorEventLoop doesn't support subprocess | Replaced with `asyncio.to_thread(subprocess.run)` |
| `curl -X POST` in PowerShell | `-X` parameter not found | PowerShell's `curl` is `Invoke-WebRequest`, not real curl | Use `Invoke-RestMethod` |
| `"cookiesfrombrowser": ("chrome",)` with Chrome closed | `Could not copy Chrome cookie database` | Chrome locks SQLite cookie DB even when closed | Switched to `cookies.txt` file |
| `"cookiesfrombrowser": ("chrome",)` with Chrome open | `Failed to decrypt with DPAPI` | Chrome 127+ uses App-Bound Encryption on Windows | Switched to `cookies.txt` file |
| `sample-videos.com` as test MP4 URL | `httpx.ConnectError` | Site unreliable | Abandoned — use Instagram URL directly |
| `workers=2` in uvicorn | `{"detail":"Analysis failed"}` with no traceback | Windows doesn't forward worker subprocess stderr to the terminal | Changed to `workers=1` |
| `"cookiefile": "cookies.txt"` (relative path) | Path not found when server started from wrong directory | Relative path depends on CWD at startup | Changed to `Path(__file__).parent / "cookies.txt"` |
| yt-dlp diagnostic without `print()` | No output printed | `extract_info()` returns a dict, doesn't print it | Not a real failure — confirmed cookies work |
| Hetzner CX21 as VPS | N/A — decided against | User prefers free option | Switched to Oracle Cloud Free Tier |
| Google Colab as VPS | N/A — rejected | No stable IP, sessions expire, no root access, can't run WireGuard | Not viable for this use case |

---

## 5. Next Steps (in order)

### Immediate — VPS setup on Oracle Cloud Free Tier

User is setting up Oracle Cloud. Once the VM is running:

**Instance config chosen:**
- Shape: `VM.Standard.A1.Flex` (ARM Ampere, Always Free)
- OCPUs: 2, Memory: 12 GB
- Image: Ubuntu 22.04
- Home region: closest to user

**Oracle firewall ports to open** (Security List Ingress Rules):
| Source CIDR | Protocol | Port | Purpose |
|---|---|---|---|
| `0.0.0.0/0` | UDP | `51820` | WireGuard |
| `0.0.0.0/0` | TCP | `8000` | FastAPI (testing) |

**Ubuntu firewall (run after SSH in):**
```bash
sudo iptables -I INPUT -p udp --dport 51820 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 8000 -j ACCEPT
```

**SSH into instance:**
```powershell
ssh -i "C:\path\to\your-key.key" ubuntu@YOUR_VPS_IP
# If permissions error on the key:
icacls "C:\path\to\your-key.key" /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

**After SSHing in:**
1. Upload `server/` to VPS:
   ```powershell
   scp -i "C:\path\to\your-key.key" -r C:\Users\leee1\ai-reel-detector\server ubuntu@YOUR_VPS_IP:/opt/reeldetector/
   ```
2. Fill in `/opt/reeldetector/server/.env` on VPS (copy from `.env.example`, fill APNs keys now, `HIVE_API_KEY` later)
3. Run provisioning:
   ```bash
   cd /opt/reeldetector/server
   bash setup.sh
   ```
   This installs: WireGuard, iptables rules, mitmproxy, Python deps, two systemd services (`reeldetector` + `mitmproxy`)
4. Generate WireGuard keypairs (one for server, one for iPhone):
   ```bash
   wg genkey | tee server_private.key | wg pubkey > server_public.key
   wg genkey | tee iphone_private.key | wg pubkey > iphone_public.key
   ```
5. Copy mitmproxy CA cert off the VPS:
   ```powershell
   scp -i "C:\path\to\your-key.key" ubuntu@YOUR_VPS_IP:/root/.mitmproxy/mitmproxy-ca-cert.pem C:\Users\leee1\ai-reel-detector\ios\ReelDetector\Resources\
   ```

### After VPS — iOS App (Phase 3–5, requires macOS)

**The iOS build requires macOS.** User has Windows 11 + iPhone 17.
**Plan:** Use MacInCloud (rent cloud Mac by the hour, ~$1–2/hr) for Xcode build sessions only.

**Do this now (any browser, no Mac needed):**
- Apply for NetworkExtension entitlement at apple developer portal — takes 1–3 days, start the clock early

**iOS steps (when Mac is available):**
1. Create Xcode project with 3 targets: main app (`ReelDetector`), `PacketTunnel`, `ReelWidget`
2. Add App Group capability: `group.com.yourname.reeldetector` to all targets
3. Replace `YOUR_VPS_IP` in `ios/ReelDetector/Resources/Info.plist`
4. Drop `ca.mobileconfig` into Xcode as a resource
5. Get APNs `.p8` key from Apple Developer Portal → upload to VPS → fill in `.env`
6. Build + install on iPhone → complete onboarding (VPN → cert → notifications)
7. Open Instagram, watch a Reel → confirm Dynamic Island cycles: armed → analyzing → result

### Last step — Real AI Detection (Phase 6)

1. Get Hive API key from thehive.ai
2. Add `HIVE_API_KEY=xxx` to VPS `.env`
3. Set `_HIVE_ENABLED = True` in `analyzer.py`
4. Run `test_pipeline.py` with 20 AI + 20 real reels — need >80% accuracy
5. Redeploy server (`sudo systemctl restart reeldetector`)
