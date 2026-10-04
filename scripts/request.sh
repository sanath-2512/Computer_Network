#!/bin/bash
# One verbose HTTPS request: shows TCP connect, TLS + certificate check, and HTTP headers.
#   bash scripts/request.sh              -> https://app.team1.test/api/status
#   bash scripts/request.sh /            -> the home page
source "$(dirname "$0")/common.sh"
"${CURL[@]}" -v "$BASE${1:-/api/status}"
echo
