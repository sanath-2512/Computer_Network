#!/bin/bash
# ------------------------------------------------------------------
# CN Project Phase 2 - Backup DNS Record Restoration (Aryan)
# Restores Backup dnsmasq records on Aryan's Mac to Main Edge (10.7.11.108).
# ------------------------------------------------------------------
set -e

BASE="${CN_BASE:-$HOME/.cn-team1-phase2}"
CONF="$BASE/config/dnsmasq-backup.conf"
PIDFILE="$BASE/pids/dnsmasq-backup.pid"
MAIN_IP="${1:-10.7.11.108}"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo '/opt/homebrew')"

if [ ! -f "$CONF" ]; then
    echo "[-] Error: Backup DNS configuration not found at $CONF" >&2
    exit 1
fi

echo "[Backup DNS Restore] Restoring app.team1.test & api.team1.test -> $MAIN_IP (TTL 30)..."
sed -i '' -e "s/^host-record=app\.team1\.test,.*/host-record=app.team1.test,$MAIN_IP,30/" "$CONF"
sed -i '' -e "s/^host-record=api\.team1\.test,.*/host-record=api.team1.test,$MAIN_IP,30/" "$CONF"

echo "[Backup DNS Restore] Validating dnsmasq configuration syntax..."
"$BREW_PREFIX/sbin/dnsmasq" --test -C "$CONF"

echo "[Backup DNS Restore] Safely restarting dedicated backup dnsmasq process..."
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

echo "[Backup DNS Restore] Flushing macOS resolver cache..."
sudo dscacheutil -flushcache 2>/dev/null || true
sudo killall -HUP mDNSResponder 2>/dev/null || true

echo "[Backup DNS Restore] Verifying answer directly from Backup DNS resolver (10.7.11.108:53):"
dig @10.7.11.108 app.team1.test +noall +answer

echo "[Backup DNS Restore] SUCCESS: Backup DNS restored to $MAIN_IP"
