#!/bin/bash
# ------------------------------------------------------------------
# CN Project Phase 2 - Extension E / B: Backup DNS Cutover (Aryan)
# Updates Backup dnsmasq records on Aryan's Mac to point to Standby Edge (10.7.9.214).
# ------------------------------------------------------------------
set -e

BASE="${CN_BASE:-$HOME/.cn-team1-phase2}"
CONF="$BASE/config/dnsmasq-backup.conf"
PIDFILE="$BASE/pids/dnsmasq-backup.pid"
STANDBY_IP="${1:-10.7.9.214}"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo '/opt/homebrew')"

if [ ! -f "$CONF" ]; then
    echo "[-] Error: Backup DNS configuration not found at $CONF" >&2
    exit 1
fi

echo "[Backup DNS Cutover] Pointing app.team1.test & api.team1.test -> $STANDBY_IP (TTL 30)..."
sed -i '' -e "s/^host-record=app\.team1\.test,.*/host-record=app.team1.test,$STANDBY_IP,30/" "$CONF"
sed -i '' -e "s/^host-record=api\.team1\.test,.*/host-record=api.team1.test,$STANDBY_IP,30/" "$CONF"

echo "[Backup DNS Cutover] Validating dnsmasq configuration syntax..."
"$BREW_PREFIX/sbin/dnsmasq" --test -C "$CONF"

echo "[Backup DNS Cutover] Safely restarting dedicated backup dnsmasq process..."
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

echo "[Backup DNS Cutover] Flushing macOS resolver cache..."
sudo dscacheutil -flushcache 2>/dev/null || true
sudo killall -HUP mDNSResponder 2>/dev/null || true

echo "[Backup DNS Cutover] Verifying answer directly from Backup DNS resolver (10.7.11.108:53):"
dig @10.7.11.108 app.team1.test +noall +answer

echo "[Backup DNS Cutover] SUCCESS: Backup DNS now points to $STANDBY_IP"
