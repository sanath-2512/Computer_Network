#!/bin/bash
BASE="$HOME/.cn-team1-phase2"
PIDFILE="$BASE/pids/backend-B.pid"

if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID"
        for i in {1..5}; do
            if ! kill -0 "$PID" 2>/dev/null; then break; fi
            sleep 0.5
        done
        if kill -0 "$PID" 2>/dev/null; then
            kill -9 "$PID" 2>/dev/null || true
        fi
        echo "Backend B (PID $PID) stopped."
    else
        echo "Backend B (PID $PID) was not running."
    fi
    rm -f "$PIDFILE"
else
    echo "No PID file found for Backend B."
fi
