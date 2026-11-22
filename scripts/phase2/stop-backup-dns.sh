#!/bin/bash
BASE="$HOME/.cn-team1-phase2"
PIDFILE="$BASE/pids/dnsmasq-backup.pid"

if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if sudo kill -0 "$PID" 2>/dev/null; then
        sudo kill "$PID" 2>/dev/null || true
        for i in {1..5}; do
            if ! sudo kill -0 "$PID" 2>/dev/null; then break; fi
            sleep 0.5
        done
        if sudo kill -0 "$PID" 2>/dev/null; then
            sudo kill -9 "$PID" 2>/dev/null || true
        fi
        echo "Backup dnsmasq (PID $PID) stopped."
    else
        echo "Backup dnsmasq (PID $PID) was not running."
    fi
    sudo rm -f "$PIDFILE"
else
    echo "No PID file found for backup dnsmasq."
fi
