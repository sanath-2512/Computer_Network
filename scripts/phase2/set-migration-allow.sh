#!/bin/bash
set -e
BASE="$HOME/.cn-team1-phase2"
CONF="$BASE/config/pf-migration.conf"

echo "Applying temporary PF migration exception: ALLOW Krishna (10.7.9.214) to 3001/3002, BLOCK others..."
sudo pfctl -a com.apple/team1_isolation -f "$CONF"

echo "Active rules in com.apple/team1_isolation anchor:"
sudo pfctl -a com.apple/team1_isolation -sr
