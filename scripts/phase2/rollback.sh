#!/bin/bash
BASE="$HOME/.cn-team1-phase2"
echo "=== EMERGENCY ROLLBACK & CLEAN RESTORATION ==="

# 1. Detect Active Network Service Name dynamically
IFACE="en0"
SERVICE=$(networksetup -listnetworkserviceorder 2>/dev/null | grep -B 1 "Device: $IFACE" | head -n 1 | cut -d ')' -f 2 | sed 's/^[ ]*//')
if [ -z "$SERVICE" ]; then SERVICE="Wi-Fi"; fi
echo "Detected Network Service: $SERVICE on $IFACE"

echo "1. Stopping Main & Standby Nginx..."
"$BASE/scripts/stop-main-edge.sh" 2>/dev/null || true
if [ -f "$BASE/pids/nginx-standby.pid" ]; then
    sudo kill "$(cat "$BASE/pids/nginx-standby.pid")" 2>/dev/null || true
    rm -f "$BASE/pids/nginx-standby.pid"
fi

echo "2. Stopping Primary & Backup DNS..."
"$BASE/scripts/stop-backup-dns.sh" 2>/dev/null || true
"$BASE/scripts/stop-primary-dns.sh" 2>/dev/null || true

echo "3. Stopping Backends A and B..."
"$BASE/scripts/stop-backends.sh" 2>/dev/null || true

echo "4. Clearing PF firewall isolation anchor (com.apple/team1_isolation)..."
sudo pfctl -a com.apple/team1_isolation -F rules 2>/dev/null || true

# If PF was originally disabled, disable it
if [ -f "$BASE/rollback/original-pf-state.txt" ] && grep -qi "Status: Disabled" "$BASE/rollback/original-pf-state.txt"; then
    echo "Restoring original PF state: Disabling PF..."
    sudo pfctl -d 2>/dev/null || true
fi

echo "5. Restoring original DNS settings on $SERVICE..."
if [ -f "$BASE/rollback/original-dns.txt" ]; then
    ORIG_DNS=$(cat "$BASE/rollback/original-dns.txt")
    if echo "$ORIG_DNS" | grep -qi "There aren't any DNS Servers"; then
        sudo networksetup -setdnsservers "$SERVICE" empty
    else
        sudo networksetup -setdnsservers "$SERVICE" $ORIG_DNS
    fi
fi

echo "Rollback completed. Machine cleanly returned to baseline."
