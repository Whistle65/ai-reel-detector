#!/usr/bin/env bash
# VPS setup script for ReelDetector server (Ubuntu 22.04, Oracle Cloud Free Tier ARM)
set -euo pipefail

echo "=== ReelDetector VPS Setup ==="

# Detect the default outbound network interface (eth0 on some providers, enp0s3 or ens3 on Oracle)
DEFAULT_IFACE=$(ip route show default | awk '/default/ {print $5; exit}')
echo "Detected default interface: $DEFAULT_IFACE"

# System deps
apt-get update -q
apt-get install -y python3.11 python3.11-venv python3-pip ffmpeg curl wireguard iptables-persistent

# Python env
python3.11 -m venv /opt/reeldetector/venv
source /opt/reeldetector/venv/bin/activate
pip install -q --upgrade pip
pip install -q -r /opt/reeldetector/server/requirements.txt

# IP forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
sysctl -p

# Transparent proxy routing: redirect wg0 TCP 80/443 → mitmproxy on 8080
iptables -t nat -A PREROUTING -i wg0 -p tcp --dport 80  -j REDIRECT --to-port 8080
iptables -t nat -A PREROUTING -i wg0 -p tcp --dport 443 -j REDIRECT --to-port 8080
# Allow forwarding from WireGuard interface
iptables -A FORWARD -i wg0 -j ACCEPT
# NAT outbound traffic from WireGuard peers through the real interface
iptables -t nat -A POSTROUTING -o "$DEFAULT_IFACE" -j MASQUERADE
# Allow our own ports through Oracle's host firewall
iptables -I INPUT -p udp --dport 51820 -j ACCEPT
iptables -I INPUT -p tcp --dport 8000  -j ACCEPT

# Persist iptables rules
netfilter-persistent save

# WireGuard VPN server config (fill in keys after generating them)
cat > /etc/wireguard/wg0.conf << 'WGCONF'
[Interface]
Address = 10.0.0.1/24
ListenPort = 51820
PrivateKey = SERVER_PRIVATE_KEY_HERE

# iOS device peer (fill in after generating WireGuard keypairs)
[Peer]
PublicKey = IOS_DEVICE_PUBLIC_KEY_HERE
AllowedIPs = 10.0.0.2/32
WGCONF

systemctl enable wg-quick@wg0
# Don't start wg0 yet — keys are placeholder; user fills them in before starting

# Generate mitmproxy CA cert
mitmdump --no-web-open-browser &
MITM_PID=$!
sleep 5
kill $MITM_PID 2>/dev/null || true
echo "mitmproxy CA generated at: /root/.mitmproxy/mitmproxy-ca-cert.pem"

# Systemd unit for FastAPI server
cat > /etc/systemd/system/reeldetector-api.service << 'UNIT'
[Unit]
Description=ReelDetector FastAPI Server
After=network.target

[Service]
User=root
WorkingDirectory=/opt/reeldetector/server
EnvironmentFile=/opt/reeldetector/server/.env
ExecStart=/opt/reeldetector/venv/bin/python main.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

# Systemd unit for mitmproxy transparent proxy
cat > /etc/systemd/system/reeldetector-mitm.service << 'UNIT'
[Unit]
Description=ReelDetector mitmproxy (transparent)
After=network.target wg-quick@wg0.service

[Service]
User=root
WorkingDirectory=/opt/reeldetector/server
ExecStart=/opt/reeldetector/venv/bin/mitmdump \
    --mode transparent \
    --showhost \
    --ssl-insecure \
    --allow-hosts '.*cdninstagram\.com|.*fbcdn\.net|.*instagram\.com' \
    -s mitmproxy_addon.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
# Don't auto-start services yet — .env must be filled in first

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "1. Fill in /opt/reeldetector/server/.env (copy from .env.example)"
echo "2. Generate WireGuard keypairs:"
echo "   wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key"
echo "   wg genkey | tee /etc/wireguard/iphone_private.key | wg pubkey > /etc/wireguard/iphone_public.key"
echo "3. Fill in SERVER_PRIVATE_KEY_HERE in /etc/wireguard/wg0.conf with the server private key"
echo "4. Fill in IOS_DEVICE_PUBLIC_KEY_HERE in /etc/wireguard/wg0.conf with the iPhone public key"
echo "5. systemctl start wg-quick@wg0 reeldetector-api reeldetector-mitm"
echo "6. Copy mitmproxy CA cert:"
echo "   scp ubuntu@VPS_IP:/root/.mitmproxy/mitmproxy-ca-cert.pem <local path>"
echo ""
echo "=== To update the live mitmproxy service after code changes ==="
echo "   cd /opt/reeldetector && git pull"
echo "   systemctl daemon-reload"
echo "   systemctl restart reeldetector-mitm reeldetector-api"
