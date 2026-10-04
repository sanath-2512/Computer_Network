#!/bin/bash
# The request to run WHILE Wireshark is capturing (Task G).
# 1. Flushes the DNS cache so a real DNS query goes on the wire.
# 2. Forces TLS 1.2 (min AND max), so the Certificate message is visible in Wireshark
#    (in TLS 1.3 it is encrypted), and HTTP/1.1 so the headers are simple.
source "$(dirname "$0")/common.sh"
flush_dns
"${CURL[@]}" -v --http1.1 --tlsv1.2 --tls-max 1.2 "$BASE/api/status"
echo
