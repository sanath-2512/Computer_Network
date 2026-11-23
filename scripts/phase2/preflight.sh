#!/bin/bash
# ------------------------------------------------------------------
# CN Project Phase 2 - Node Preflight Environment & Health Check
# ------------------------------------------------------------------
set -e
BASE="${CN_BASE:-$HOME/.cn-team1-phase2}"
ARYAN_IP="10.7.11.108"
KRISHNA_IP="10.7.9.214"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo '/opt/homebrew')"

CURRENT_IP="$(ipconfig getifaddr en0 2>/dev/null || ifconfig en0 2>/dev/null | grep 'inet ' | awk '{print $2}')"

echo "=== PREFLIGHT ENVIRONMENT & CONFIGURATION CHECK ==="
echo "Node IP: $CURRENT_IP | Runtime Base: $BASE"

echo "1. Network Reachability:"
if [ "$CURRENT_IP" = "$ARYAN_IP" ]; then
    ping -c 2 -W 1000 "$KRISHNA_IP" >/dev/null 2>&1 && echo "   [PASS] Peer Krishna ($KRISHNA_IP) is reachable on LAN" || echo "   [WARN] Cannot ping Krishna ($KRISHNA_IP)"
elif [ "$CURRENT_IP" = "$KRISHNA_IP" ]; then
    ping -c 2 -W 1000 "$ARYAN_IP" >/dev/null 2>&1 && echo "   [PASS] Peer Aryan ($ARYAN_IP) is reachable on LAN" || echo "   [WARN] Cannot ping Aryan ($ARYAN_IP)"
else
    echo "   [INFO] Local IP $CURRENT_IP detected."
fi

echo "2. Tooling Check:"
for tool in python3 nginx dnsmasq openssl curl dig; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "   [PASS] $tool installed ($(command -v "$tool"))"
    else
        echo "   [FAIL] $tool is missing!"
    fi
done

echo "3. Port Occupancy Check:"
CHECK_PORTS=(53 80 443)
if [ "$CURRENT_IP" = "$ARYAN_IP" ]; then
    CHECK_PORTS+=(3001 3002)
fi

for port in "${CHECK_PORTS[@]}"; do
    if netstat -an -f inet -p tcp 2>/dev/null | grep -q -E "\.$port .*LISTEN" || \
       netstat -an -f inet -p udp 2>/dev/null | grep -q -E "\.$port " || \
       lsof -nP -iTCP:$port -sTCP:LISTEN >/dev/null 2>&1 || \
       lsof -nP -iUDP:$port >/dev/null 2>&1; then
        echo "   [ACTIVE] Port $port is listening"
    else
        echo "   [FREE]   Port $port is available"
    fi
done

echo "4. Configuration Syntax Checks:"
if [ -f "$BASE/config/dnsmasq-backup.conf" ]; then
    "$BREW_PREFIX/sbin/dnsmasq" --test -C "$BASE/config/dnsmasq-backup.conf" && echo "   [PASS] dnsmasq-backup.conf syntax ok"
fi
if [ -f "$BASE/config/dnsmasq-primary.conf" ]; then
    "$BREW_PREFIX/sbin/dnsmasq" --test -C "$BASE/config/dnsmasq-primary.conf" && echo "   [PASS] dnsmasq-primary.conf syntax ok"
fi
if [ -f "$BASE/nginx/main.conf" ]; then
    "$BREW_PREFIX/bin/nginx" -t -c "$BASE/nginx/main.conf" >/dev/null 2>&1 && echo "   [PASS] nginx main.conf syntax ok"
fi
if [ -f "$BASE/nginx/standby.conf" ]; then
    "$BREW_PREFIX/bin/nginx" -t -c "$BASE/nginx/standby.conf" >/dev/null 2>&1 && echo "   [PASS] nginx standby.conf syntax ok"
fi
if [ -f "$BASE/identity/ca.crt" ] && [ -f "$BASE/identity/server.crt" ]; then
    openssl verify -CAfile "$BASE/identity/ca.crt" "$BASE/identity/server.crt" >/dev/null 2>&1 && echo "   [PASS] TLS certificate chain valid"
fi

echo "=== PREFLIGHT COMPLETE ==="
