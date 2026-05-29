"""Run this once after running setup.sh on the VPS to generate ca.mobileconfig.

Usage:
    scp root@YOUR_VPS:/root/.mitmproxy/mitmproxy-ca-cert.pem ./mitmproxy-ca-cert.pem
    python generate_mobileconfig.py

Output: ca.mobileconfig  -- copy to Xcode project as a resource
"""

import base64
import uuid
import sys
from pathlib import Path

CERT_PATH = Path("mitmproxy-ca-cert.pem")

if not CERT_PATH.exists():
    print("ERROR: mitmproxy-ca-cert.pem not found. Copy it from the VPS first.")
    sys.exit(1)

pem = CERT_PATH.read_text()
# Strip PEM headers and decode to DER base64 for the profile
cert_b64 = "".join(pem.splitlines()[1:-1])

payload_uuid = str(uuid.uuid4()).upper()
profile_uuid = str(uuid.uuid4()).upper()

profile = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadCertificateFileName</key>
            <string>ReelDetectorCA.cer</string>
            <key>PayloadContent</key>
            <data>{cert_b64}</data>
            <key>PayloadDescription</key>
            <string>Installs the ReelDetector certificate authority for AI Reel analysis</string>
            <key>PayloadDisplayName</key>
            <string>ReelDetector CA</string>
            <key>PayloadIdentifier</key>
            <string>com.yourname.reeldetector.ca.{payload_uuid}</string>
            <key>PayloadType</key>
            <string>com.apple.security.root</string>
            <key>PayloadUUID</key>
            <string>{payload_uuid}</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
        </dict>
    </array>
    <key>PayloadDescription</key>
    <string>ReelDetector certificate authority for private AI content analysis</string>
    <key>PayloadDisplayName</key>
    <string>ReelDetector</string>
    <key>PayloadIdentifier</key>
    <string>com.yourname.reeldetector.profile</string>
    <key>PayloadOrganization</key>
    <string>ReelDetector</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>{profile_uuid}</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>
"""

out = Path("ca.mobileconfig")
out.write_text(profile)
print(f"Written: {out}")
print("Copy ca.mobileconfig into your Xcode project under ReelDetector/Resources/")
