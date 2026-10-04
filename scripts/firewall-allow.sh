#!/bin/bash
# Keep the macOS firewall ON, but let the project services accept connections.
# Run it again after installing dnsmasq (Sanath) or nginx (Aryan).
FW=/usr/libexec/ApplicationFirewall/socketfilterfw
B="$HOME/cn-backup"; mkdir -p "$B"

realpath_of() { python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"; }

allow() {
  [ -e "$1" ] || return 0
  echo "== Allow incoming connections: $1"
  sudo "$FW" --add "$1" >/dev/null
  sudo "$FW" --unblockapp "$1"
  grep -qxF "$1" "$B/firewall-added.txt" 2>/dev/null || echo "$1" >> "$B/firewall-added.txt"
}

echo "== Stealth mode OFF (with it on, this Mac ignores ping)"
sudo "$FW" --setstealthmode off

# Python (runs the backends)
PYAPP=$(python3 -c 'import os,sys; print(os.path.join(sys.base_prefix, "Resources", "Python.app"))' 2>/dev/null)
allow "$PYAPP"

# dnsmasq (Sanath) and nginx (Aryan), if installed
if command -v brew >/dev/null 2>&1; then
  P=$(brew --prefix)
  [ -e "$P/sbin/dnsmasq" ] && allow "$(realpath_of "$P/sbin/dnsmasq")"
  [ -e "$P/bin/nginx" ]    && allow "$(realpath_of "$P/bin/nginx")"
fi

echo
"$FW" --getglobalstate
"$FW" --getstealthmode
echo "If macOS shows a popup asking to accept incoming connections, click Allow."
