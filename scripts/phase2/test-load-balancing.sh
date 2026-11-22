#!/bin/bash
set -e
BASE="$HOME/.cn-team1-phase2"
CA="$BASE/identity/ca.crt"
HOST="app.team1.test"
ARYAN_IP="10.7.11.108"
COUNT=${1:-10}

echo "=== LOAD BALANCING ROUND-ROBIN TEST ($COUNT requests) ==="
count_A=0
count_B=0

for i in $(seq 1 $COUNT); do
    RESP=$(curl -s -D - --cacert "$CA" --resolve "$HOST:443:$ARYAN_IP" "https://$HOST/api/status")
    BACKEND=$(echo "$RESP" | grep -i "^x-backend:" | tr -d '\r' | awk '{print $2}')
    STATUS=$(echo "$RESP" | grep -i "^http/" | head -n 1 | tr -d '\r')
    echo "Request $i: $STATUS | X-Backend: $BACKEND"
    if [ "$BACKEND" = "A" ]; then count_A=$((count_A + 1)); fi
    if [ "$BACKEND" = "B" ]; then count_B=$((count_B + 1)); fi
done

echo "----------------------------------------"
echo "Distribution: Backend A: $count_A | Backend B: $count_B"
if [ $count_A -gt 0 ] && [ $count_B -gt 0 ]; then
    echo "RESULT: PASS (Both backends actively receiving traffic)"
else
    echo "RESULT: FAIL (Traffic not distributed to both backends)"
fi
