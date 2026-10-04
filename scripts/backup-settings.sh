#!/bin/bash
# Run ONCE on every Mac BEFORE changing anything.
# Saves the original DNS servers, firewall settings and any existing dnsmasq/nginx
# configs into ~/cn-backup, so restore-settings.sh can put everything back.
B="$HOME/cn-backup"
FW=/usr/libexec/ApplicationFirewall/socketfilterfw

if [ -f "$B/dns.txt" ]; then
  echo "A backup already exists in $B - not overwriting it (it holds your ORIGINAL settings)."
  exit 0
fi
mkdir -p "$B"

networksetup -getdnsservers Wi-Fi > "$B/dns.txt"
$FW --getglobalstate  > "$B/firewall-state.txt"
$FW --getstealthmode  > "$B/firewall-stealth.txt"

if command -v brew >/dev/null 2>&1; then
  P=$(brew --prefix)
  [ -f "$P/etc/dnsmasq.conf" ] && cp "$P/etc/dnsmasq.conf" "$B/dnsmasq.conf.original"
  [ -d "$P/etc/nginx" ] && cp -R "$P/etc/nginx" "$B/nginx.original"
fi

echo "Saved to $B:"
echo "  DNS servers: $(tr '\n' ' ' < "$B/dns.txt")"
echo "  Firewall:    $(cat "$B/firewall-state.txt")"
echo "  Stealth:     $(cat "$B/firewall-stealth.txt")"
ls "$B"
