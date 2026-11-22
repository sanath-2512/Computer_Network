#!/bin/bash
BASE="$HOME/.cn-team1-phase2"
BREW_PREFIX="$(brew --prefix)"
PIDFILE="$BASE/pids/nginx.pid"
CONF="$BASE/nginx/main.conf"

if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    echo "Stopping Main Nginx edge (PID $PID)..."
    sudo "$BREW_PREFIX/bin/nginx" -c "$CONF" -s stop 2>/dev/null || sudo kill -TERM "$PID" 2>/dev/null || true
    for i in {1..5}; do
        if ! sudo kill -0 "$PID" 2>/dev/null; then break; fi
        sleep 0.5
    done
    if sudo kill -0 "$PID" 2>/dev/null; then
        sudo kill -9 "$PID" 2>/dev/null || true
    fi
    sudo rm -f "$PIDFILE"
    echo "Main Nginx stopped."
else
    echo "No PID file found for Main Nginx."
fi
