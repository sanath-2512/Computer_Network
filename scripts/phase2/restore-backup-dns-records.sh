#!/bin/bash
set -e
BASE="$HOME/.cn-team1-phase2"
CONF="$BASE/config/dnsmasq-backup.conf"
PIDFILE="$BASE/pids/dnsmasq-backup.pid"
ARYAN_IP="10.7.11.108"
BREW_PREFIX="$(brew --prefix)"

echo "Restoring backup DNS records: pointing app.team1.test & api.team1.test to ARYAN_IP ($ARYAN_IP)..."
sed -i '' -e "s/^host-record=app\.team1\.test,.*/host-record=app.team1.test,$ARYAN_IP,30/" "$CONF"
sed -i '' -e "s/^host-record=api\.team1\.test,.*/host-record=api.team1.test,$ARYAN_IP,30/" "$CONF"

echo "Validating dnsmasq configuration syntax..."
"$BREW_PREFIX/sbin/dnsmasq" --test -C "$CONF"

echo "Reloading backup dnsmasq process..."
if [ -f "$PIDFILE" ] && sudo kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    sudo kill -HUP "$(cat "$PIDFILE")" 2>/dev/null || sudo "$BASE/scripts/start-backup-dns.sh"
else
    sudo "$BASE/scripts/start-backup-dns.sh"
fi

echo "Verifying backup DNS response for app.team1.test:"
dig @10.7.11.108 app.team1.test +noall +answer
