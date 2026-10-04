#!/bin/bash
# DNS check (Task B): both project names must resolve to Aryan's Mac via Sanath's DNS.
source "$(dirname "$0")/common.sh"
for name in "$DOMAIN" "$API_DOMAIN"; do
  echo "== dig $name"
  dig "$name" +time=3 +tries=1 +noall +answer +stats | grep -E "IN[[:space:]]+A|SERVER|timed out"
  echo
done
echo "Expected: both names -> $ARYAN_IP"
echo "          SERVER -> $SANATH_IP#53  (on Sanath's own Mac: 127.0.0.1#53)"
