#!/bin/bash
# CN Project Phase 1 - full end-to-end check. Run on a CLIENT Mac (Krishna's or Sanath's).
# Every block prints evidence you can screenshot.
D="$(dirname "$0")"
source "$D/common.sh"

step() { echo; echo "=================== $1 ==================="; }

step "1. LAN: ping every laptop"
for ip in "$SANATH_IP" "$ARYAN_IP" "$KRISHNA_IP"; do
  printf "%-16s " "$ip"
  ping -c 2 "$ip" | grep "packets transmitted"
done

step "2. DNS: app + api names"
bash "$D/check-dns.sh"

step "3. HTTPS: TCP connect, TLS, certificate check, HTTP version"
"${CURL[@]}" -v -o /dev/null "$BASE/api/status" 2>&1 \
  | grep -Ei "Connected to|SSL connection|ALPN|subject:|issuer:|verify|^< HTTP|^< x-backend"
printf "api name too:    "; "${CURL[@]}" -D - -o /dev/null "$API_BASE/api/status" | head -1

step "4. Load balancing"
bash "$D/lb-test.sh" 6

step "5. HTTP/1.1 vs HTTP/2"
printf "forced HTTP/1.1: "; "${CURL[@]}" -D - -o /dev/null --http1.1 "$BASE/" | head -1
printf "offered HTTP/2:  "; "${CURL[@]}" -D - -o /dev/null --http2   "$BASE/" | head -1

step "6. Caching"
bash "$D/cache-test.sh"
