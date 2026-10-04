#!/bin/bash
# ------------------------------------------------------------------
# Fill in your team number and the three laptop IPs in every file.
# All three people run the SAME line on their own copy of the bundle.
#
#   bash configure.sh <team-number> <MAC1_IP> <MAC2_IP> <MAC3_IP>
#   e.g. bash configure.sh 4 192.168.1.11 192.168.1.12 192.168.1.13
#
#   MAC1 = Sanath (DNS + Backend B)
#   MAC2 = Aryan  (edge: nginx)
#   MAC3 = Krishna (Backend A)
# ------------------------------------------------------------------
set -e
cd "$(dirname "$0")"

if [ $# -ne 4 ]; then
  echo "Usage: bash configure.sh <team-number> <MAC1_IP> <MAC2_IP> <MAC3_IP>"
  exit 1
fi
N="$1"; M1="$2"; M2="$3"; M3="$4"

for ip in "$M1" "$M2" "$M3"; do
  if ! echo "$ip" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    echo "Not an IPv4 address: $ip"; exit 1
  fi
done
if ! echo "$N" | grep -Eq '^[0-9]+$'; then
  echo "Team number must be a number, e.g. 4"; exit 1
fi
if ! grep -q MAC2_IP config/dnsmasq.conf; then
  echo "This copy is already configured. Unzip a fresh copy and run again."; exit 1
fi

FILES="config/dnsmasq.conf config/edge.conf tls/make-certs.sh scripts/common.sh scripts/restore-settings.sh backend/backend.py"
for f in $FILES; do
  sed -e "s/MAC1_IP/$M1/g" -e "s/MAC2_IP/$M2/g" -e "s/MAC3_IP/$M3/g" \
      -e "s/team1/team$N/g" "$f" > "$f.tmp"
  mv "$f.tmp" "$f"
done
chmod +x tls/make-certs.sh scripts/*.sh backend/backend.py

echo "Configured for team$N.test"
echo "  Mac 1 (Sanath, DNS + Backend B): $M1"
echo "  Mac 2 (Aryan, edge nginx):       $M2"
echo "  Mac 3 (Krishna, Backend A):      $M3"
echo
grep -n "host-record=app" config/dnsmasq.conf
grep -n "server .*:300" config/edge.conf
