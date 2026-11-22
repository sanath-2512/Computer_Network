#!/bin/bash
BASE="$HOME/.cn-team1-phase2"
CA="$BASE/identity/ca.crt"
HOST="app.team1.test"
ARYAN_IP="10.7.11.108"
KRISHNA_IP="10.7.9.214"

echo "========================================================"
echo "   CN PHASE 2 AUTOMATED TEST SUITE - ARYAN'S MAC"
echo "========================================================"

echo -e "\n[TEST 1] Local Backends Check (3001 & 3002):"
RESP_A=$(curl -s -i http://127.0.0.1:3001/api/status)
RESP_B=$(curl -s -i http://127.0.0.1:3002/api/status)
if echo "$RESP_A" | grep -q "X-Backend: A" && echo "$RESP_B" | grep -q "X-Backend: B"; then
    echo "  -> PASS: Backend A and Backend B healthy with correct X-Backend headers."
else
    echo "  -> FAIL: Backend health check failed."
fi

echo -e "\n[TEST 2] Backup DNS Resolution (Port 53 @ $ARYAN_IP):"
DIG_APP=$(dig @$ARYAN_IP app.team1.test +noall +answer)
DIG_API=$(dig @$ARYAN_IP api.team1.test +noall +answer)
echo "  Query app.team1.test: $DIG_APP"
echo "  Query api.team1.test: $DIG_API"
if echo "$DIG_APP" | grep -q "$ARYAN_IP" && echo "$DIG_API" | grep -q "$ARYAN_IP"; then
    echo "  -> PASS: Backup DNS correctly resolving app and api to $ARYAN_IP (TTL 30)."
else
    echo "  -> FAIL/BLOCKED: Backup DNS not answering or wrong IP."
fi

echo -e "\n[TEST 3] HTTPS & TLS Validation (Port 443):"
HTTPS_CHECK=$(curl -s -D - --cacert "$CA" --resolve "$HOST:443:$ARYAN_IP" "https://$HOST/api/status")
if echo "$HTTPS_CHECK" | grep -q "200 OK"; then
    echo "  -> PASS: HTTPS connection succeeded with full TLS verification (200 OK)."
else
    echo "  -> FAIL/BLOCKED: HTTPS request failed."
fi

echo -e "\n[TEST 4] Round-Robin Load Balancing (10 Requests):"
"$BASE/scripts/test-load-balancing.sh" 10

echo -e "\n[TEST 5] HTTP Caching (200 OK -> ETag -> 304 Not Modified):"
"$BASE/scripts/test-cache.sh"

echo -e "\n[TEST 6] PF Firewall Service Isolation Verification:"
echo "  Checking anchor com.apple/team1_isolation rules:"
sudo pfctl -a com.apple/team1_isolation -sr 2>/dev/null || echo "  (PF requires sudo to inspect rules)"

echo "========================================================"
echo "   TEST SUITE EXECUTION COMPLETE"
echo "========================================================"
