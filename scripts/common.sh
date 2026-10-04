# Shared settings for the test scripts. configure.sh fills in the team number and IPs.
DOMAIN=app.team1.test
API_DOMAIN=api.team1.test
PORT=443                 # nginx listens on 443 (edge.conf). If you move it to 8443, change BOTH places.
SANATH_IP=10.7.7.6        # Mac 1: DNS + Backend B
ARYAN_IP=10.7.17.6         # Mac 2: nginx edge
KRISHNA_IP=10.7.9.214       # Mac 3: Backend A + test client

if [ "$PORT" = "443" ]; then
  BASE="https://$DOMAIN"; API_BASE="https://$API_DOMAIN"
else
  BASE="https://$DOMAIN:$PORT"; API_BASE="https://$API_DOMAIN:$PORT"
fi

# curl with a 5-second limit so nothing hangs.
# macOS curl sometimes ignores the Keychain. If it reports a certificate problem
# (exit code 60), we point it at our CA file instead. That is STILL full
# certificate validation - it is NOT -k / --insecure.
CURL=(curl -sS --max-time 5)
curl -sS --max-time 5 -o /dev/null "$BASE/api/status" 2>/dev/null
if [ $? -eq 60 ]; then
  for f in "$HOME/Downloads/ca.crt" "$HOME/cn-project/tls/ca.crt"; do
    if [ -f "$f" ]; then
      CURL+=(--cacert "$f")
      echo "(note: curl is using --cacert $f - still full certificate checking, not -k)"
      break
    fi
  done
fi

flush_dns() {
  if command -v dscacheutil >/dev/null 2>&1; then
    sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
  fi
}
