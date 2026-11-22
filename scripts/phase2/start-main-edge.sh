#!/bin/bash
set -e
BASE="$HOME/.cn-team1-phase2"
BREW_PREFIX="$(brew --prefix)"
PIDFILE="$BASE/pids/nginx.pid"
CONF="$BASE/nginx/main.conf"

if [ -f "$PIDFILE" ] && sudo kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Main Nginx is already running (PID $(cat "$PIDFILE"))"
    exit 0
fi

echo "Validating nginx configuration..."
sudo "$BREW_PREFIX/bin/nginx" -t -c "$CONF"

echo "Starting Main Nginx edge..."
sudo "$BREW_PREFIX/bin/nginx" -c "$CONF"
sleep 1

if [ -f "$PIDFILE" ] && sudo kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    echo "Main Nginx edge started successfully (PID $(cat "$PIDFILE"))"
else
    echo "Main Nginx edge failed to start. Check $BASE/logs/nginx-error.log"
    exit 1
fi
