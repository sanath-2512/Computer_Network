#!/bin/bash
set -e
BASE="$HOME/.cn-team1-phase2"
BREW_PREFIX="$(brew --prefix)"
PIDFILE="$BASE/pids/dnsmasq-backup.pid"
CONF="$BASE/config/dnsmasq-backup.conf"

if [ -f "$PIDFILE" ] && sudo kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Backup dnsmasq is already running (PID $(cat "$PIDFILE"))"
    exit 0
fi

echo "Starting dedicated backup dnsmasq on port 53 (bound to 10.7.11.108)..."
sudo "$BREW_PREFIX/sbin/dnsmasq" -C "$CONF"
sleep 1

if [ -f "$PIDFILE" ] && sudo kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Backup dnsmasq started successfully (PID $(cat "$PIDFILE"))"
else
    echo "Failed to start backup dnsmasq. Check $BASE/logs/dnsmasq-backup.log"
    exit 1
fi
