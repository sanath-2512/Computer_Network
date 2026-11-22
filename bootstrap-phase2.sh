#!/bin/bash
# ------------------------------------------------------------------
# CN Project Phase 2 - Node Bootstrap & Environment Setup
# Automatically configures Aryan's Mac or Krishna's Mac from repository files.
# ------------------------------------------------------------------
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.cn-team1-phase2"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo '/opt/homebrew')"

echo "=== CN Project Phase 2 Bootstrap ==="
echo "Node Hostname: $(hostname)"
echo "User:          $(whoami)"
echo "Target Dir:    $TARGET_DIR"

# 1. Detect Active Network Interface & Service Name
IFACE="en0"
IP=$(ifconfig "$IFACE" 2>/dev/null | grep "inet " | awk '{print $2}')
SERVICE=$(networksetup -listnetworkserviceorder 2>/dev/null | grep -B 1 "Device: $IFACE" | head -n 1 | cut -d ')' -f 2 | sed 's/^[ ]*//')
if [ -z "$SERVICE" ]; then SERVICE="Wi-Fi"; fi

echo "Interface:     $IFACE (IP: $IP)"
echo "Net Service:   $SERVICE"

# 2. Create directory structure
mkdir -p "$TARGET_DIR"/{config,logs,pids,rollback,evidence,identity,nginx,scripts}
chmod 700 "$TARGET_DIR"

# 3. Save Baseline Network & Firewall State
if [ ! -f "$TARGET_DIR/rollback/original-dns.txt" ]; then
    networksetup -getdnsservers "$SERVICE" > "$TARGET_DIR/rollback/original-dns.txt" 2>&1 || true
    scutil --dns > "$TARGET_DIR/rollback/scutil-dns-original.txt" 2>&1 || true
    sudo -n pfctl -s info > "$TARGET_DIR/rollback/original-pf-state.txt" 2>&1 || echo "PF state requires sudo"
fi

# 4. Copy and template configurations
echo "Templating configurations for $HOME..."

# Aryan's Main Edge
sed -e "s|/Users/aryan\.|$HOME|g" \
    -e "s|/opt/homebrew|$BREW_PREFIX|g" \
    "$REPO_DIR/config/phase2/nginx-edge-main.conf" > "$TARGET_DIR/nginx/main.conf"

# Aryan's Backup DNS
sed -e "s|/Users/aryan\.|$HOME|g" \
    "$REPO_DIR/config/phase2/dnsmasq-backup.conf" > "$TARGET_DIR/config/dnsmasq-backup.conf"

# Krishna's Primary DNS
sed -e "s|/Users/krishna|$HOME|g" \
    "$REPO_DIR/config/phase2/dnsmasq-primary.conf" > "$TARGET_DIR/config/dnsmasq-primary.conf"

# Krishna's Standby Nginx
sed -e "s|/Users/krishna|$HOME|g" \
    -e "s|/opt/homebrew|$BREW_PREFIX|g" \
    "$REPO_DIR/config/phase2/nginx-edge-standby.conf" > "$TARGET_DIR/nginx/standby.conf"

# PF Isolation & Migration
cp "$REPO_DIR/config/phase2/pf-isolation.conf" "$TARGET_DIR/config/pf-isolation.conf"
cp "$REPO_DIR/config/phase2/pf-migration.conf" "$TARGET_DIR/config/pf-migration.conf"

# 5. Copy automation scripts
cp "$REPO_DIR/scripts/phase2/"*.sh "$TARGET_DIR/scripts/"
chmod +x "$TARGET_DIR/scripts/"*.sh

echo "Bootstrap completed successfully. Files staged in $TARGET_DIR."
