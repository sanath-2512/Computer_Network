#!/bin/bash
# Put this Mac back the way backup-settings.sh found it.
#   bash scripts/restore-settings.sh        end of a work session: original DNS + firewall back,
#                                           project servers stopped (project files kept for next time)
#   bash scripts/restore-settings.sh full   after the final evaluation: ALSO restores the original
#                                           dnsmasq config, removes our nginx site + certs, and
#                                           removes our CA from the System keychain
B="$HOME/cn-backup"
FW=/usr/libexec/ApplicationFirewall/socketfilterfw
if [ ! -f "$B/dns.txt" ]; then
  echo "No backup in $B. (backup-settings.sh was never run on this Mac.)"; exit 1
fi

echo "== 1. Original DNS servers"
if grep -qi "aren't any" "$B/dns.txt"; then
  sudo networksetup -setdnsservers Wi-Fi empty          # original = automatic (from the router)
else
  sudo networksetup -setdnsservers Wi-Fi $(cat "$B/dns.txt")
fi
networksetup -getdnsservers Wi-Fi
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder

echo "== 2. Stop project servers"
pkill -f "backend/backend.py" && echo "backend stopped"
if command -v brew >/dev/null 2>&1; then
  P=$(brew --prefix)
  [ -x "$P/bin/nginx" ] && sudo "$P/bin/nginx" -s stop 2>/dev/null && echo "nginx stopped"
  brew list dnsmasq >/dev/null 2>&1 && sudo brew services stop dnsmasq
fi

echo "== 3. Original firewall settings"
if [ -f "$B/firewall-added.txt" ]; then
  while read -r app; do [ -n "$app" ] && sudo "$FW" --remove "$app" >/dev/null && echo "removed exception: $app"; done < "$B/firewall-added.txt"
  rm -f "$B/firewall-added.txt"
fi
if grep -qiE "is on|enabled" "$B/firewall-stealth.txt"; then sudo "$FW" --setstealthmode on; else sudo "$FW" --setstealthmode off; fi
if grep -qiE "enabled|State = [12]" "$B/firewall-state.txt"; then sudo "$FW" --setglobalstate on; else sudo "$FW" --setglobalstate off; fi

if [ "$1" = "full" ]; then
  echo "== 4. Remove project configuration"
  if command -v brew >/dev/null 2>&1; then
    P=$(brew --prefix)
    if [ -f "$B/dnsmasq.conf.original" ]; then cp "$B/dnsmasq.conf.original" "$P/etc/dnsmasq.conf" && echo "original dnsmasq.conf restored"; fi
    rm -f "$P/etc/nginx/servers/edge.conf" && rm -rf "$P/etc/nginx/certs" && echo "nginx project site + certs removed"
  fi
  sudo security delete-certificate -c "team1 Local Root CA" /Library/Keychains/System.keychain 2>/dev/null \
    && echo "our CA removed from the System keychain"
fi
echo "Done."
