#!/bin/bash
set -e
echo "=== DIRECT BACKEND INTEGRITY TEST ==="
echo "1. Testing Backend A (127.0.0.1:3001):"
curl -s -i http://127.0.0.1:3001/api/status | head -n 10

echo -e "\n2. Testing Backend B (127.0.0.1:3002):"
curl -s -i http://127.0.0.1:3002/api/status | head -n 10
