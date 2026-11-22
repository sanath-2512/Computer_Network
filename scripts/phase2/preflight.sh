#!/bin/bash
set -e
BASE="$HOME/.cn-team1-phase2"
ARYAN_IP="10.7.11.108"
KRISHNA_IP="10.7.9.214"
BREW_PREFIX="$(brew --prefix)"

echo "=== PREFLIGHT ENVIRONMENT & CONFIGURATION CHECK ==="
echo "1. Network Reachability:"
ping -c 2 -W 1000 "$KRISHNA_IP" >/dev/null && echo "   [PASS] Krishna ($KRISHNA_IP) is reachable on LAN" || echo "   [FAIL] Cannot ping Krishna ($KRISHNA_IP)"

echo "2. Tooling Check:"
for tool in python3 nginx dnsmasq openssl curl dig; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "   [PASS] $tool installed ($(command -v "$tool"))"
    else
        echo "   [FAIL] $tool is missing!"
    fi
done

echo "3. Port Occupancy Check (Clean baseline expected):"
for port in 53 80 443 3001 3002; do
    if lsof -nP -iTCP:$port -sTCP:LISTEN >/dev/null 2>&1 || lsof -nP -iUDP:$port >/dev/null 2>&1; then
        OCCUPIER=$(lsof -nP -iTCP:$port -sTCP:LISTEN 2>/dev/null || lsof -nP -iUDP:$port 2>/dev/null | tail -n +2)
        echo "   [OCCUPIED] Port $port is listening: $OCCUPIER"
    else
        echo "   [FREE] Port $port is available"
    fi
done

echo "4. Configuration Syntax Checks:"
"$BREW_PREFIX/sbin/dnsmasq" --test -C "$BASE/config/dnsmasq-backup.conf" && echo "   [PASS] dnsmasq-backup.conf syntax ok"
"$BREW_PREFIX/bin/nginx" -t -c "$BASE/nginx/main.conf" >/dev/null 2>&1 && echo "   [PASS] nginx main.conf syntax ok"
openssl verify -CAfile "$BASE/identity/ca.crt" "$BASE/identity/server.crt" >/dev/null 2>&1 && echo "   [PASS] TLS certificate chain valid"

echo "=== PREFLIGHT COMPLETE ==="
