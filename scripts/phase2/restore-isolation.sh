#!/bin/bash
set -e
BASE="$HOME/.cn-team1-phase2"
CONF="$BASE/config/pf-isolation.conf"

echo "Restoring normal PF service isolation (blocking all LAN inbound to 3001/3002)..."
sudo pfctl -a com.apple/team1_isolation -f "$CONF"

echo "Active rules in com.apple/team1_isolation anchor:"
sudo pfctl -a com.apple/team1_isolation -sr
