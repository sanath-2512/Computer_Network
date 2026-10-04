#!/bin/bash
# Load-balancing / failover test: N requests in a row (default 10).
# Prints the HTTP status line and which backend answered (X-Backend header).
#   bash scripts/lb-test.sh        -> 10 requests
#   bash scripts/lb-test.sh 6      -> 6 requests
source "$(dirname "$0")/common.sh"
N=${1:-10}
echo "== $N requests to $BASE/api/status"
for i in $(seq 1 "$N"); do
  OUT=$("${CURL[@]}" -D - -o /dev/null "$BASE/api/status" 2>&1)
  STATUS=$(echo "$OUT" | head -1 | tr -d '\r')
  BACKEND=$(echo "$OUT" | grep -i '^x-backend' | tr -d '\r')
  printf "request %2d:  %-22s %s\n" "$i" "${STATUS:-no response}" "${BACKEND:-(no X-Backend header)}"
done
