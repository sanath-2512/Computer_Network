#!/bin/bash
set -e
BASE="$HOME/.cn-team1-phase2"
BREW_PREFIX="$(brew --prefix)"

echo "=========================================================="
echo "   CN PHASE 2 PRIVILEGED SERVICES BOOTSTRAP (ARYAN)"
echo "=========================================================="
echo "This script will request sudo to execute:"
echo " 1. Start backup dnsmasq on 10.7.11.108:53"
echo " 2. Start Main Nginx Edge on ports 80 & 443"
echo " 3. Load PF isolation anchor com.apple/team1_isolation"
echo " 4. Install Root CA into System Keychain"
echo "=========================================================="
echo

sudo bash << 'SUDO_EOF'
BASE="/Users/aryan./.cn-team1-phase2"
BREW_PREFIX="/opt/homebrew"

echo "[1/4] Starting backup dnsmasq on port 53..."
if [ -f "$BASE/pids/dnsmasq-backup.pid" ] && kill -0 "$(cat "$BASE/pids/dnsmasq-backup.pid")" 2>/dev/null; then
    echo "      dnsmasq already running (PID $(cat "$BASE/pids/dnsmasq-backup.pid"))"
else
    "$BREW_PREFIX/sbin/dnsmasq" -C "$BASE/config/dnsmasq-backup.conf"
    sleep 1
    echo "      dnsmasq started (PID $(cat "$BASE/pids/dnsmasq-backup.pid"))"
fi

echo "[2/4] Starting Main Nginx Edge on ports 80 & 443..."
if [ -f "$BASE/pids/nginx.pid" ] && kill -0 "$(cat "$BASE/pids/nginx.pid")" 2>/dev/null; then
    echo "      Nginx already running (PID $(cat "$BASE/pids/nginx.pid"))"
else
    "$BREW_PREFIX/bin/nginx" -c "$BASE/nginx/main.conf"
    sleep 1
    echo "      Nginx started (PID $(cat "$BASE/pids/nginx.pid"))"
fi

echo "[3/4] Loading PF Firewall Service Isolation anchor..."
pfctl -a com.apple/team1_isolation -f "$BASE/config/pf-isolation.conf"
pfctl -e 2>/dev/null || true
echo "      Active PF anchor rules:"
pfctl -a com.apple/team1_isolation -sr

echo "[4/4] Installing Root CA into macOS System Keychain..."
security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$BASE/identity/ca.crt"
echo "      Root CA added to System Keychain successfully."

echo
echo "All privileged services started and verified."
SUDO_EOF
