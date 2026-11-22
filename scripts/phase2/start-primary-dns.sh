#!/bin/bash
set -e
BREW_PREFIX="$(brew --prefix)"
CONF="$HOME/.cn-team1-phase2/config/dnsmasq-primary.conf"
PIDFILE="$HOME/.cn-team1-phase2/pids/dnsmasq.pid"

if [ -f "$PIDFILE" ] && sudo kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Primary dnsmasq is already running (PID $(cat "$PIDFILE"))"
    exit 0
fi

sudo "$BREW_PREFIX/sbin/dnsmasq" -C "$CONF"
sleep 1
if [ -f "$PIDFILE" ] && sudo kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Primary dnsmasq started (PID $(cat "$PIDFILE"))"
else
    echo "Primary dnsmasq failed to start."
    exit 1
fi
