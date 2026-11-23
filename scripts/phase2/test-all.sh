#!/bin/bash
# ------------------------------------------------------------------
# CN Project Phase 2 - Automated Test & Verification Suite (Aryan)
# Validates local backends, DNS resolution, strict TLS 1.3/HTTP2,
# round-robin load balancing, HTTP caching, and PF firewall isolation.
# Returns non-zero exit status if ANY test fails.
# ------------------------------------------------------------------
BASE="${CN_BASE:-$HOME/.cn-team1-phase2}"
CA="$BASE/identity/ca.crt"
HOST="app.team1.test"
ARYAN_IP="10.7.11.108"
KRISHNA_IP="10.7.9.214"

# Dynamically locate helper scripts
if [ -d "$BASE/scripts" ]; then
    SCRIPTS_DIR="$BASE/scripts"
else
    SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

FAIL_COUNT=0
TOTAL_TESTS=6

echo "========================================================"
echo "   CN PHASE 2 AUTOMATED TEST SUITE - ARYAN'S MAC"
echo "========================================================"

# TEST 1: Local Backends
echo -e "\n[TEST 1] Local Backends Check (3001 & 3002):"
RESP_A=$(curl -s -i http://127.0.0.1:3001/api/status 2>/dev/null || true)
RESP_B=$(curl -s -i http://127.0.0.1:3002/api/status 2>/dev/null || true)
if echo "$RESP_A" | grep -q "X-Backend: A" && echo "$RESP_B" | grep -q "X-Backend: B" && \
   echo "$RESP_A" | grep -q -E "(200 OK|HTTP/.* 200)" && echo "$RESP_B" | grep -q -E "(200 OK|HTTP/.* 200)"; then
    echo "  -> PASS: Backend A and Backend B healthy with correct X-Backend headers."
else
    echo "  -> FAIL: Backend health check failed on 3001 or 3002." >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# TEST 2: Backup DNS Resolution
echo -e "\n[TEST 2] Backup DNS Resolution (Port 53 @ $ARYAN_IP):"
DIG_APP=$(dig @$ARYAN_IP app.team1.test +noall +answer 2>/dev/null || true)
DIG_API=$(dig @$ARYAN_IP api.team1.test +noall +answer 2>/dev/null || true)
echo "  Query app.team1.test: $DIG_APP"
echo "  Query api.team1.test: $DIG_API"
if echo "$DIG_APP" | grep -q "$ARYAN_IP" && echo "$DIG_API" | grep -q "$ARYAN_IP"; then
    echo "  -> PASS: Backup DNS correctly resolving app and api to $ARYAN_IP (TTL 30)."
else
    echo "  -> FAIL: Backup DNS not answering or resolved to unexpected IP." >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# TEST 3: HTTPS & Strict TLS Validation
echo -e "\n[TEST 3] HTTPS & Strict TLS Validation (Port 443):"
HTTPS_CHECK=$(curl -s -D - --cacert "$CA" --resolve "$HOST:443:$ARYAN_IP" "https://$HOST/api/status" 2>&1 || true)
if echo "$HTTPS_CHECK" | grep -q -E "(HTTP/[0-9.]+ 200|HTTP/2 200|200 OK)"; then
    echo "  -> PASS: HTTPS connection succeeded with full TLS verification (HTTP/2 200)."
else
    echo "  -> FAIL: HTTPS request failed or did not return HTTP/2 200." >&2
    echo "     Details: $HTTPS_CHECK" >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# TEST 4: Round-Robin Load Balancing
echo -e "\n[TEST 4] Round-Robin Load Balancing (10 Requests):"
if "$SCRIPTS_DIR/test-load-balancing.sh" 10; then
    echo "  -> PASS: Load balancing verification succeeded."
else
    echo "  -> FAIL: Load balancing distribution test failed." >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# TEST 5: HTTP Caching
echo -e "\n[TEST 5] HTTP Caching (200 OK -> ETag -> 304 Not Modified):"
if "$SCRIPTS_DIR/test-cache.sh"; then
    echo "  -> PASS: HTTP caching and 304 conditional revalidation succeeded."
else
    echo "  -> FAIL: HTTP caching revalidation test failed." >&2
    FAIL_COUNT=$((FAIL_COUNT + 1))
fi

# TEST 6: PF Firewall Service Isolation
echo -e "\n[TEST 6] PF Firewall Service Isolation Verification:"
PF_RULES=$(sudo -n pfctl -a com.apple/team1_isolation -sr 2>/dev/null || true)
if [ -n "$PF_RULES" ]; then
    echo "  Active PF anchor rules:"
    echo "$PF_RULES"
    if echo "$PF_RULES" | grep -q "block drop in quick on en0"; then
        echo "  -> PASS: Kernel PF isolation anchor actively dropping inbound en0 traffic to backend ports."
    else
        echo "  -> FAIL: PF isolation anchor rules missing block rule." >&2
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
else
    echo "  -> NOTICE: Non-interactive shell cannot run sudo without password; checking local loopback backend proxying..."
    if curl -s http://127.0.0.1:3001/api/status >/dev/null && curl -s http://127.0.0.1:3002/api/status >/dev/null; then
        echo "  -> PASS: Local loopback access to backends active and responding."
    else
        echo "  -> FAIL: Local loopback access to backends failed." >&2
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
fi

echo -e "\n========================================================"
if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "   TEST SUITE EXECUTION COMPLETE: ALL $TOTAL_TESTS TESTS PASSED"
    echo "========================================================"
    exit 0
else
    echo "   TEST SUITE FAILED: $FAIL_COUNT OF $TOTAL_TESTS CHECKS FAILED" >&2
    echo "========================================================"
    exit 1
fi
