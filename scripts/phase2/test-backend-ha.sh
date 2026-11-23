#!/bin/bash
set -e
BASE="${CN_BASE:-$HOME/.cn-team1-phase2}"
CA="$BASE/identity/ca.crt"
HOST="app.team1.test"
ARYAN_IP="10.7.11.108"
EVID="$BASE/evidence/ha-test-$(date +%Y%m%d-%H%M%S).log"

# Locate scripts directory
if [ -d "$BASE/scripts" ]; then
    SCRIPTS_DIR="$BASE/scripts"
else
    SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
fi

echo "=== EXTENSION D: BACKEND HIGH AVAILABILITY DEMONSTRATION ===" | tee -a "$EVID"
date | tee -a "$EVID"

echo -e "\n[STEP 1] Baseline Verification: Both Backends Running" | tee -a "$EVID"
"$SCRIPTS_DIR/start-backends.sh" | tee -a "$EVID"
sleep 1
"$SCRIPTS_DIR/test-load-balancing.sh" 6 | tee -a "$EVID"

echo -e "\n[STEP 2] Simulating Failure: Stopping Backend A (Port 3001)" | tee -a "$EVID"
"$SCRIPTS_DIR/stop-backend-A.sh" | tee -a "$EVID"
sleep 1

echo -e "\n[STEP 3] Testing Edge Passive Failover (5 requests, expecting 100% Backend B)" | tee -a "$EVID"
b_count=0
for i in {1..5}; do
    RESP=$(curl -s -D - --cacert "$CA" --resolve "$HOST:443:$ARYAN_IP" "https://$HOST/api/status")
    BACKEND=$(echo "$RESP" | grep -i "^x-backend:" | tr -d '\r' | awk '{print $2}')
    STATUS=$(echo "$RESP" | grep -i "^http/" | head -n 1 | tr -d '\r')
    echo "  Failover Request $i: $STATUS | X-Backend: $BACKEND" | tee -a "$EVID"
    if [ "$BACKEND" = "B" ]; then b_count=$((b_count + 1)); fi
done

if [ "$b_count" -eq 5 ]; then
    echo "  -> PASS: 100% of requests routed to Backend B during Backend A outage." | tee -a "$EVID"
else
    echo "  -> FAIL: Request routing issue during Backend A outage." | tee -a "$EVID"
    "$SCRIPTS_DIR/start-backend-A.sh" >/dev/null 2>&1 || true
    exit 1
fi

echo -e "\n[STEP 4] Recovery: Restarting Backend A (Port 3001)" | tee -a "$EVID"
"$SCRIPTS_DIR/start-backend-A.sh" | tee -a "$EVID"

echo -e "\n[STEP 5] Waiting 11s for Nginx passive fail_timeout (10s) to expire..." | tee -a "$EVID"
sleep 11

echo -e "\n[STEP 6] Testing Edge Traffic Recovery (10 requests, expecting both A and B)" | tee -a "$EVID"
"$SCRIPTS_DIR/test-load-balancing.sh" 10 | tee -a "$EVID"

echo -e "\n=== BACKEND HA DEMONSTRATION COMPLETE ===" | tee -a "$EVID"
echo "Evidence saved in $EVID"
