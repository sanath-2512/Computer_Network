#!/bin/bash
set -e
BASE="$HOME/.cn-team1-phase2"
CONF="$BASE/config/pf-isolation.conf"

echo "Applying PF service isolation on en0 (block inbound 3001, 3002 from LAN)..."
# Save PF enabled state
sudo pfctl -s info > "$BASE/rollback/pf-info-before-isolation.txt" 2>&1 || true

# Load anchor
sudo pfctl -a com.apple/team1_isolation -f "$CONF"
# Enable PF if not already active
sudo pfctl -e 2>/dev/null || true

echo "Active rules in com.apple/team1_isolation anchor:"
sudo pfctl -a com.apple/team1_isolation -sr
