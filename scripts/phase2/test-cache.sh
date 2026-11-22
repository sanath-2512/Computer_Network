#!/bin/bash
set -e
BASE="$HOME/.cn-team1-phase2"
CA="$BASE/identity/ca.crt"
HOST="app.team1.test"
ARYAN_IP="10.7.11.108"

echo "=== HTTP CACHING & 304 CONDITIONAL TEST (VIA NGINX) ==="
echo "1. Initial Request (Expecting 200 OK, ETag, Cache-Control):"
FIRST_RESP=$(curl -s -i --cacert "$CA" --resolve "$HOST:443:$ARYAN_IP" "https://$HOST/api/cached")
echo "$FIRST_RESP" | grep -E "(HTTP/|X-Backend|Cache-Control|ETag)"

ETAG=$(echo "$FIRST_RESP" | grep -i "^etag:" | tr -d '\r' | awk '{print $2}')
echo -e "\nCaptured ETag: $ETAG"

echo -e "\n2. Conditional Request with If-None-Match (Expecting 304 Not Modified):"
COND_RESP=$(curl -s -i --cacert "$CA" --resolve "$HOST:443:$ARYAN_IP" -H "If-None-Match: $ETAG" "https://$HOST/api/cached")
echo "$COND_RESP" | grep -E "(HTTP/|X-Backend|Cache-Control|ETag)"

if echo "$COND_RESP" | grep -q -E "(304 Not Modified|HTTP/.* 304)"; then
    echo -e "\nRESULT: PASS (304 Not Modified verified successfully)"
else
    echo -e "\nRESULT: FAIL (Expected 304 Not Modified)"
fi
