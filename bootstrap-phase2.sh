#!/bin/bash
# ------------------------------------------------------------------
# CN Project Phase 2 - Role-Aware Node Bootstrap & Environment Setup
# Usage: ./bootstrap-phase2.sh <aryan|krishna> [certs_dir]
# ------------------------------------------------------------------
set -e

ROLE="$1"
CERTS_SRC="$2"

if [ "$ROLE" != "aryan" ] && [ "$ROLE" != "krishna" ]; then
    echo "==================================================================" >&2
    echo "[-] Error: Invalid or missing role." >&2
    echo "Usage: $0 <aryan|krishna> [certs_source_dir]" >&2
    echo "" >&2
    echo "Roles:" >&2
    echo "  aryan   : Main Edge Nginx, Backends A/B, Backup DNS, PF Isolation" >&2
    echo "            Expected IP on en0: 10.7.11.108" >&2
    echo "  krishna : Primary DNS, Verification Client, Standby Edge Proxy" >&2
    echo "            Expected IP on en0: 10.7.9.214" >&2
    echo "" >&2
    echo "Optional certs_source_dir: Path to directory containing valid ca.crt," >&2
    echo "                           server.crt, and server.key." >&2
    echo "==================================================================" >&2
    exit 1
fi

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="$HOME/.cn-team1-phase2"
BREW_PREFIX="$(brew --prefix 2>/dev/null || echo '/opt/homebrew')"

echo "=== CN Project Phase 2 Bootstrap ==="
echo "Assigned Role: $ROLE"
echo "Node Hostname: $(hostname)"
echo "Current User:  $(whoami)"
echo "Home Dir:      $HOME"
echo "Brew Prefix:   $BREW_PREFIX"
echo "Target Dir:    $TARGET_DIR"

# 1. Detect Network Interface & Verify Role IP
IFACE="en0"
CURRENT_IP="$(ipconfig getifaddr "$IFACE" 2>/dev/null || ifconfig "$IFACE" 2>/dev/null | grep 'inet ' | awk '{print $2}')"
SERVICE=$(networksetup -listnetworkserviceorder 2>/dev/null | grep -B 1 "Device: $IFACE" | head -n 1 | cut -d ')' -f 2 | sed 's/^[ ]*//')
if [ -z "$SERVICE" ]; then SERVICE="Wi-Fi"; fi

echo "Interface:     $IFACE (IP: $CURRENT_IP)"
echo "Net Service:   $SERVICE"

if [ "$ROLE" = "aryan" ]; then
    EXPECTED_IP="10.7.11.108"
elif [ "$ROLE" = "krishna" ]; then
    EXPECTED_IP="10.7.9.214"
fi

if [ -z "$CURRENT_IP" ]; then
    echo "[-] Error: Could not determine IPv4 address on interface $IFACE." >&2
    exit 1
fi

if [ "$CURRENT_IP" != "$EXPECTED_IP" ]; then
    echo "[-] Error: Interface $IFACE IP ($CURRENT_IP) does not match expected IP ($EXPECTED_IP) for role '$ROLE'." >&2
    echo "    Please verify physical LAN connection or select the appropriate role." >&2
    exit 1
fi

echo "[+] IP verification passed for role '$ROLE' ($CURRENT_IP)."

# 2. Create Target Directory Structure
mkdir -p "$TARGET_DIR"/{config,logs,pids,rollback,evidence,identity,nginx,scripts}
chmod 700 "$TARGET_DIR"

if [ "$ROLE" = "aryan" ]; then
    mkdir -p "$TARGET_DIR/backend"
fi

# 3. Save Baseline Network State (if not already recorded)
if [ ! -f "$TARGET_DIR/rollback/original-dns.txt" ]; then
    networksetup -getdnsservers "$SERVICE" > "$TARGET_DIR/rollback/original-dns.txt" 2>&1 || true
    scutil --dns > "$TARGET_DIR/rollback/scutil-dns-original.txt" 2>&1 || true
    sudo -n pfctl -s info > "$TARGET_DIR/rollback/original-pf-state.txt" 2>&1 || true
    echo "[+] Baseline DNS and PF state saved in $TARGET_DIR/rollback/"
fi

# 4. Identity & Certificate Staging
echo "Staging identity and certificates for role '$ROLE'..."

# Discover certificate source directory
CERTS_FOUND=0
CANDIDATE_DIRS=()
if [ -n "$CERTS_SRC" ]; then
    CANDIDATE_DIRS+=("$CERTS_SRC")
fi
CANDIDATE_DIRS+=(
    "$TARGET_DIR/identity"
    "$HOME/.cn-team1-phase2/identity"
    "$REPO_DIR/identity"
    "$HOME/.cn-team1-phase2/identity/krishna-bundle"
)

SRC_DIR=""
for dir in "${CANDIDATE_DIRS[@]}"; do
    if [ -f "$dir/ca.crt" ] && [ -f "$dir/server.crt" ] && [ -f "$dir/server.key" ]; then
        SRC_DIR="$dir"
        CERTS_FOUND=1
        break
    fi
done

if [ "$CERTS_FOUND" -eq 1 ] && [ "$SRC_DIR" != "$TARGET_DIR/identity" ]; then
    echo "[+] Copying certificates from $SRC_DIR to $TARGET_DIR/identity/..."
    cp "$SRC_DIR/ca.crt" "$TARGET_DIR/identity/ca.crt"
    cp "$SRC_DIR/server.crt" "$TARGET_DIR/identity/server.crt"
    cp "$SRC_DIR/server.key" "$TARGET_DIR/identity/server.key"
    chmod 644 "$TARGET_DIR/identity/ca.crt" "$TARGET_DIR/identity/server.crt"
    chmod 600 "$TARGET_DIR/identity/server.key"
elif [ -f "$TARGET_DIR/identity/ca.crt" ] && [ -f "$TARGET_DIR/identity/server.crt" ] && [ -f "$TARGET_DIR/identity/server.key" ]; then
    echo "[+] Valid certificates already staged in $TARGET_DIR/identity/."
    chmod 644 "$TARGET_DIR/identity/ca.crt" "$TARGET_DIR/identity/server.crt"
    chmod 600 "$TARGET_DIR/identity/server.key"
else
    echo "[-] WARNING: Required certificates (ca.crt, server.crt, server.key) not found in candidate paths." >&2
    echo "    Please stage them into $TARGET_DIR/identity/ or provide [certs_source_dir]." >&2
fi

# Explicit PKI Security Guard: Ensure ca.key is NEVER copied or committed
if [ "$ROLE" = "krishna" ] && [ -f "$TARGET_DIR/identity/ca.key" ]; then
    echo "[!] Security notice: Removing ca.key from Krishna node (CA private key must remain exclusively on CA root host)."
    rm -f "$TARGET_DIR/identity/ca.key"
fi

# 5. Role-Specific Configuration & Script Staging
echo "Staging configurations and scripts for role '$ROLE'..."

if [ "$ROLE" = "aryan" ]; then
    # Main Nginx Edge (ports 80 & 443)
    sed -e "s|/Users/aryan\.|$HOME|g" \
        -e "s|/opt/homebrew|$BREW_PREFIX|g" \
        "$REPO_DIR/config/phase2/nginx-edge-main.conf" > "$TARGET_DIR/nginx/main.conf"

    # Backup dnsmasq on port 53 (10.7.11.108)
    sed -e "s|/Users/aryan\.|$HOME|g" \
        "$REPO_DIR/config/phase2/dnsmasq-backup.conf" > "$TARGET_DIR/config/dnsmasq-backup.conf"

    # PF isolation and migration configs
    cp "$REPO_DIR/config/phase2/pf-isolation.conf" "$TARGET_DIR/config/pf-isolation.conf"
    cp "$REPO_DIR/config/phase2/pf-migration.conf" "$TARGET_DIR/config/pf-migration.conf"

    # Stage backend Python service
    if [ -f "$REPO_DIR/backend/backend.py" ]; then
        cp "$REPO_DIR/backend/backend.py" "$TARGET_DIR/backend/backend.py"
        echo "[+] Staged backend service into $TARGET_DIR/backend/backend.py"
    fi

    # Stage Aryan's scripts
    ARYAN_SCRIPTS=(
        "preflight.sh"
        "privileged-start.sh"
        "rollback.sh"
        "set-isolation.sh"
        "restore-isolation.sh"
        "set-migration-allow.sh"
        "set-backup-dns-migration.sh"
        "restore-backup-dns-records.sh"
        "start-backend-A.sh"
        "start-backend-B.sh"
        "start-backends.sh"
        "stop-backend-A.sh"
        "stop-backend-B.sh"
        "stop-backends.sh"
        "start-backup-dns.sh"
        "stop-backup-dns.sh"
        "start-main-edge.sh"
        "stop-main-edge.sh"
        "test-all.sh"
        "test-backend-ha.sh"
        "test-backends.sh"
        "test-cache.sh"
        "test-https.sh"
        "test-load-balancing.sh"
    )
    for scr in "${ARYAN_SCRIPTS[@]}"; do
        if [ -f "$REPO_DIR/scripts/phase2/$scr" ]; then
            cp "$REPO_DIR/scripts/phase2/$scr" "$TARGET_DIR/scripts/$scr"
        fi
    done

elif [ "$ROLE" = "krishna" ]; then
    # Primary dnsmasq on port 53 (10.7.9.214)
    sed -e "s|/Users/krishna|$HOME|g" \
        "$REPO_DIR/config/phase2/dnsmasq-primary.conf" > "$TARGET_DIR/config/dnsmasq-primary.conf"

    # Standby Nginx Edge on port 443
    sed -e "s|/Users/krishna|$HOME|g" \
        -e "s|/opt/homebrew|$BREW_PREFIX|g" \
        "$REPO_DIR/config/phase2/nginx-edge-standby.conf" > "$TARGET_DIR/nginx/standby.conf"

    # Stage Krishna's scripts
    KRISHNA_SCRIPTS=(
        "preflight.sh"
        "privileged-start.sh"
        "rollback.sh"
        "start-primary-dns.sh"
        "stop-primary-dns.sh"
        "set-primary-dns-migration.sh"
        "restore-primary-dns-records.sh"
        "test-all.sh"
        "test-cache.sh"
        "test-https.sh"
        "test-load-balancing.sh"
    )
    for scr in "${KRISHNA_SCRIPTS[@]}"; do
        if [ -f "$REPO_DIR/scripts/phase2/$scr" ]; then
            cp "$REPO_DIR/scripts/phase2/$scr" "$TARGET_DIR/scripts/$scr"
        fi
    done
fi

chmod +x "$TARGET_DIR/scripts/"*.sh

echo "=================================================================="
echo "[+] Bootstrap completed successfully for role '$ROLE'."
echo "    Staged files are in: $TARGET_DIR"
echo "    To verify environment, run: $TARGET_DIR/scripts/preflight.sh"
echo "=================================================================="
