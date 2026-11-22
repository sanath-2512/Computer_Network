#!/bin/bash
set -e
PROJECT_DIR="$HOME/cn-project"
BASE="$HOME/.cn-team1-phase2"
PIDFILE="$BASE/pids/backend-A.pid"
LOGFILE="$BASE/logs/backend-A.log"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Backend A is already running (PID $(cat "$PIDFILE"))"
    exit 0
fi

nohup python3 "$PROJECT_DIR/backend/backend.py" --id A --port 3001 --team team1 >> "$LOGFILE" 2>&1 &
echo $! > "$PIDFILE"
sleep 1
if kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Backend A started successfully (PID $(cat "$PIDFILE") on port 3001)"
else
    echo "Backend A failed to start. Check $LOGFILE"
    exit 1
fi
