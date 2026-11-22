#!/bin/bash
set -e
PROJECT_DIR="$HOME/cn-project"
BASE="$HOME/.cn-team1-phase2"
PIDFILE="$BASE/pids/backend-B.pid"
LOGFILE="$BASE/logs/backend-B.log"

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Backend B is already running (PID $(cat "$PIDFILE"))"
    exit 0
fi

nohup python3 "$PROJECT_DIR/backend/backend.py" --id B --port 3002 --team team1 >> "$LOGFILE" 2>&1 &
echo $! > "$PIDFILE"
sleep 1
if kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Backend B started successfully (PID $(cat "$PIDFILE") on port 3002)"
else
    echo "Backend B failed to start. Check $LOGFILE"
    exit 1
fi
