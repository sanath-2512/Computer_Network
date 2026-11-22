#!/bin/bash
PIDFILE="$HOME/.cn-team1-phase2/pids/dnsmasq.pid"
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    sudo kill "$PID" 2>/dev/null || true
    echo "Primary dnsmasq (PID $PID) stopped."
    sudo rm -f "$PIDFILE"
else
    echo "No PID file found for primary dnsmasq."
fi
