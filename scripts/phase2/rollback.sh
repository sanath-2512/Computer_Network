#!/bin/bash
BASE="$HOME/.cn-team1-phase2"
echo "=== EMERGENCY ROLLBACK ==="

echo "1. Stopping Nginx Edge..."
"$BASE/scripts/stop-main-edge.sh" 2>/dev/null || true

echo "2. Stopping Backup DNS..."
"$BASE/scripts/stop-backup-dns.sh" 2>/dev/null || true

echo "3. Stopping Backends A and B..."
"$BASE/scripts/stop-backends.sh" 2>/dev/null || true

echo "4. Clearing PF firewall isolation anchor..."
sudo pfctl -a com.apple/team1_isolation -F rules 2>/dev/null || true

echo "5. Restoring original DNS settings on Wi-Fi..."
if [ -f "$BASE/rollback/original-dns.txt" ]; then
    ORIG_DNS=$(cat "$BASE/rollback/original-dns.txt")
    if [ "$ORIG_DNS" = "There aren't any DNS Servers set on Wi-Fi." ]; then
        sudo networksetup -setdnsservers Wi-Fi empty
    else
        sudo networksetup -setdnsservers Wi-Fi $ORIG_DNS
    fi
fi

echo "Rollback completed. System restored to baseline."
