#!/bin/bash
# ------------------------------------------------------------------
# CN Project Phase 2 - Role-Aware Privileged Services Startup
# Usage: ./privileged-start.sh [aryan|krishna]
# ------------------------------------------------------------------
set -e

ROLE="$1"
BASE="${CN_BASE:-$HOME/.cn-team1-phase2}"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo '/opt/homebrew')"

# Auto-detect role if not explicitly passed
if [ -z "$ROLE" ]; then
    CURRENT_IP="$(ipconfig getifaddr en0 2>/dev/null || ifconfig en0 2>/dev/null | grep 'inet ' | awk '{print $2}')"
    if [ "$CURRENT_IP" = "10.7.11.108" ]; then
        ROLE="aryan"
    elif [ "$CURRENT_IP" = "10.7.9.214" ]; then
        ROLE="krishna"
    else
        echo "[-] Error: Could not auto-detect role from IP '$CURRENT_IP'." >&2
        echo "    Usage: $0 [aryan|krishna]" >&2
        exit 1
    fi
fi

# Detect Network Service Name
IFACE="en0"
SERVICE=$(networksetup -listnetworkserviceorder 2>/dev/null | grep -B 1 "Device: $IFACE" | head -n 1 | cut -d ')' -f 2 | sed 's/^[ ]*//')
if [ -z "$SERVICE" ]; then SERVICE="Wi-Fi"; fi

echo "=========================================================="
echo "   CN PHASE 2 PRIVILEGED SERVICES BOOTSTRAP ($ROLE)"
echo "=========================================================="
echo "Role:            $ROLE"
echo "Runtime Base:    $BASE"
echo "Homebrew Prefix: $BREW_PREFIX"
echo "Network Service: $SERVICE ($IFACE)"
echo "=========================================================="

# Pass variables into sudo session without hardcoded strings
sudo bash -s "$BASE" "$BREW_PREFIX" "$ROLE" "$SERVICE" << 'SUDO_EOF'
set -e
BASE="$1"
BREW_PREFIX="$2"
ROLE="$3"
SERVICE="$4"

if [ "$ROLE" = "aryan" ]; then
    echo "[1/4] Starting Backup dnsmasq on port 53 (10.7.11.108)..."
    CONF_DNS="$BASE/config/dnsmasq-backup.conf"
    PID_DNS="$BASE/pids/dnsmasq-backup.pid"
    if [ -f "$PID_DNS" ] && kill -0 "$(cat "$PID_DNS")" 2>/dev/null; then
        echo "      dnsmasq already running (PID $(cat "$PID_DNS"))"
    elif [ -f "$CONF_DNS" ]; then
        "$BREW_PREFIX/sbin/dnsmasq" -C "$CONF_DNS"
        sleep 1
        echo "      dnsmasq started (PID $(cat "$PID_DNS"))"
    else
        echo "[-] WARNING: $CONF_DNS not found. Run bootstrap-phase2.sh aryan first."
    fi

    echo "[2/4] Starting Main Nginx Edge on ports 80 & 443..."
    CONF_NGINX="$BASE/nginx/main.conf"
    PID_NGINX="$BASE/pids/nginx.pid"
    if [ -f "$PID_NGINX" ] && kill -0 "$(cat "$PID_NGINX")" 2>/dev/null; then
        echo "      Nginx already running (PID $(cat "$PID_NGINX"))"
    elif [ -f "$CONF_NGINX" ]; then
        "$BREW_PREFIX/bin/nginx" -c "$CONF_NGINX"
        sleep 1
        echo "      Nginx started (PID $(cat "$PID_NGINX"))"
    else
        echo "[-] WARNING: $CONF_NGINX not found. Run bootstrap-phase2.sh aryan first."
    fi

    echo "[3/4] Loading PF Firewall Service Isolation anchor (com.apple/team1_isolation)..."
    CONF_PF="$BASE/config/pf-isolation.conf"
    if [ -f "$CONF_PF" ]; then
        pfctl -a com.apple/team1_isolation -f "$CONF_PF"
        pfctl -e 2>/dev/null || true
        echo "      Active PF anchor rules:"
        pfctl -a com.apple/team1_isolation -sr
    fi

    echo "[4/4] Installing Root CA into macOS System Keychain..."
    CA_FILE="$BASE/identity/ca.crt"
    if [ -f "$CA_FILE" ]; then
        security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CA_FILE"
        echo "      Root CA added to System Keychain successfully."
    fi

elif [ "$ROLE" = "krishna" ]; then
    echo "[1/3] Starting Primary dnsmasq on port 53 (10.7.9.214)..."
    CONF_DNS="$BASE/config/dnsmasq-primary.conf"
    PID_DNS="$BASE/pids/dnsmasq.pid"
    if [ -f "$PID_DNS" ] && kill -0 "$(cat "$PID_DNS")" 2>/dev/null; then
        echo "      Primary dnsmasq already running (PID $(cat "$PID_DNS"))"
    elif [ -f "$CONF_DNS" ]; then
        "$BREW_PREFIX/sbin/dnsmasq" -C "$CONF_DNS"
        sleep 1
        echo "      Primary dnsmasq started (PID $(cat "$PID_DNS"))"
    else
        echo "[-] WARNING: $CONF_DNS not found. Run bootstrap-phase2.sh krishna first."
    fi

    echo "[2/3] Installing Root CA into macOS System Keychain..."
    CA_FILE="$BASE/identity/ca.crt"
    if [ -f "$CA_FILE" ]; then
        security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$CA_FILE"
        echo "      Root CA added to System Keychain successfully."
    fi

    echo "[3/3] Setting Client DNS resolver on $SERVICE..."
    networksetup -setdnsservers "$SERVICE" 10.7.9.214 10.7.11.108
    echo "      DNS nameservers configured: 10.7.9.214 (Primary), 10.7.11.108 (Backup)"
    dscacheutil -flushcache
    killall -HUP mDNSResponder
fi
SUDO_EOF

# Start unprivileged application backends on Aryan's Mac as standard user
if [ "$ROLE" = "aryan" ]; then
    echo
    echo "Starting unprivileged Backend services (A & B)..."
    SCRIPTS_DIR="$BASE/scripts"
    if [ -f "$SCRIPTS_DIR/start-backends.sh" ]; then
        bash "$SCRIPTS_DIR/start-backends.sh"
    elif [ -f "$(dirname "$0")/start-backends.sh" ]; then
        bash "$(dirname "$0")/start-backends.sh"
    fi
fi

echo
echo "Privileged bootstrap sequence completed for $ROLE."
