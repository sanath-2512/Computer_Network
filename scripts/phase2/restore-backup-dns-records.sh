#!/bin/bash
set -e
BASE="$HOME/.cn-team1-phase2"
CONF="$BASE/config/dnsmasq-backup.conf"
PIDFILE="$BASE/pids/dnsmasq-backup.pid"
ARYAN_IP="10.7.11.108"
BREW_PREFIX="$(brew --prefix)"

echo "[DNS Restore] Restoring backup DNS records: app.team1.test & api.team1.test -> $ARYAN_IP (TTL 30)..."
sed -i '' -e "s/^host-record=app\.team1\.test,.*/host-record=app.team1.test,$ARYAN_IP,30/" "$CONF"
sed -i '' -e "s/^host-record=api\.team1\.test,.*/host-record=api.team1.test,$ARYAN_IP,30/" "$CONF"

echo "[DNS Restore] Validating dnsmasq configuration syntax..."
"$BREW_PREFIX/sbin/dnsmasq" --test -C "$CONF"

echo "[DNS Restore] Safely restarting backup dnsmasq process to apply restored records..."
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    sudo kill "$PID" 2>/dev/null || true
    for i in {1..5}; do
        if ! sudo kill -0 "$PID" 2>/dev/null; then break; fi
        sleep 0.5
    done
fi
sudo "$BREW_PREFIX/sbin/dnsmasq" -C "$CONF"
sleep 1

echo "[DNS Restore] Verifying backup DNS answer for app.team1.test:"
dig @10.7.11.108 app.team1.test +noall +answer
