#!/bin/bash
# Caching test (Task F): a full request, then a conditional request that should get 304.
source "$(dirname "$0")/common.sh"
URL="$BASE/api/cached"

echo "== 1. Full request (no cached copy): GET $URL"
"${CURL[@]}" -D - -o /dev/null "$URL" | tr -d '\r' | grep -Ei '^HTTP|^cache-control|^etag|^content-length|^x-backend'
ETAG=$("${CURL[@]}" -D - -o /dev/null "$URL" | grep -i '^etag' | awk '{print $2}' | tr -d '\r')

echo
echo "== 2. Conditional request: same URL + header  If-None-Match: $ETAG"
"${CURL[@]}" -D - -o /dev/null -H "If-None-Match: $ETAG" "$URL" | tr -d '\r' | grep -Ei '^HTTP|^cache-control|^etag|^content-length|^x-backend'

echo
echo "Expected: 1 = 200 with Cache-Control: public, max-age=60 and an ETag (body sent)."
echo "          2 = 304 Not Modified, no body. HTTP/2 304 or HTTP/1.1 304 are both fine."
