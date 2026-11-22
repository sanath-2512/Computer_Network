#!/bin/bash
set -e
BASE="$HOME/.cn-team1-phase2"
CA="$BASE/identity/ca.crt"
HOST="app.team1.test"
ARYAN_IP="10.7.11.108"

echo "=== HTTPS / TLS VALIDATION TEST ==="
echo "Requesting https://$HOST/api/status via --resolve to $ARYAN_IP:443..."
curl -v --cacert "$CA" --resolve "$HOST:443:$ARYAN_IP" "https://$HOST/api/status" 2>&1 | grep -E "(SSL certificate|Connected to|X-Backend|< HTTP|backend)"
