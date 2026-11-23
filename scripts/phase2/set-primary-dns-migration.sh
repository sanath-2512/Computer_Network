#!/bin/bash
# ------------------------------------------------------------------
# CN Project Phase 2 - Extension E / B: Primary DNS Cutover (Krishna)
# Updates Primary dnsmasq records on Krishna's Mac to point to Standby Edge (10.7.9.214).
# ------------------------------------------------------------------
set -e

BASE="${CN_BASE:-$HOME/.cn-team1-phase2}"
CONF="$BASE/config/dnsmasq-primary.conf"
PIDFILE="$BASE/pids/dnsmasq.pid"
STANDBY_IP="${1:-10.7.9.214}"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo '/opt/homebrew')"

if [ ! -f "$CONF" ]; then
    echo "[-] Error: Primary DNS configuration not found at $CONF" >&2
    exit 1
fi

echo "[Primary DNS Cutover] Pointing app.team1.test & api.team1.test -> $STANDBY_IP (TTL 30)..."
sed -i '' -e "s/^host-record=app\.team1\.test,.*/host-record=app.team1.test,$STANDBY_IP,30/" "$CONF"
sed -i '' -e "s/^host-record=api\.team1\.test,.*/host-record=api.team1.test,$STANDBY_IP,30/" "$CONF"

echo "[Primary DNS Cutover] Validating dnsmasq configuration syntax..."
"$BREW_PREFIX/sbin/dnsmasq" --test -C "$CONF"

echo "[Primary DNS Cutover] Safely restarting dedicated primary dnsmasq process..."
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if sudo kill -0 "$PID" 2>/dev/null; then
        sudo kill "$PID" 2>/dev/null || true
        for i in {1..10}; do
            if ! sudo kill -0 "$PID" 2>/dev/null; then break; fi
            sleep 0.5
        done
    fi
fi
sudo "$BREW_PREFIX/sbin/dnsmasq" -C "$CONF"
sleep 1

echo "[Primary DNS Cutover] Flushing macOS resolver cache..."
sudo dscacheutil -flushcache 2>/dev/null || true
sudo killall -HUP mDNSResponder 2>/dev/null || true

echo "[Primary DNS Cutover] Verifying answer directly from Primary DNS resolver ($STANDBY_IP:53):"
dig @10.7.9.214 app.team1.test +noall +answer

echo "[Primary DNS Cutover] SUCCESS: Primary DNS now points to $STANDBY_IP"
