#!/bin/bash
# ------------------------------------------------------------------
# CN Project Phase 1 - create our own local CA + the server certificate
# Run ONCE on Mac 2 (Aryan):   bash make-certs.sh
#
# Output folder: ~/cn-project/tls
#   ca.key      CA private key       -> NEVER share, NEVER commit to GitHub
#   ca.crt      CA certificate       -> AirDrop to every client Mac and trust it
#   server.key  server private key   -> stays on Mac 2 (nginx)
#   server.crt  server certificate   -> nginx, signed by our CA,
#                                       valid for app.team1.test + api.team1.test
# ------------------------------------------------------------------
set -e
TEAM=team1
OUT="$HOME/cn-project/tls"
mkdir -p "$OUT"
cd "$OUT"

# 1. Config for the CA certificate (CA:TRUE = allowed to sign other certs)
cat > ca.cnf <<EOF
[ req ]
distinguished_name = dn
prompt             = no
x509_extensions    = v3_ca
[ dn ]
CN = ${TEAM} Local Root CA
O  = CN Project ${TEAM}
[ v3_ca ]
basicConstraints     = critical, CA:TRUE
keyUsage             = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
EOF

# 2. Config for the server certificate request
cat > server.cnf <<EOF
[ req ]
distinguished_name = dn
prompt             = no
[ dn ]
CN = app.${TEAM}.test
O  = CN Project ${TEAM}
EOF

# 3. Extensions for the server certificate. Browsers check subjectAltName (SAN),
#    not CN, and macOS requires extendedKeyUsage = serverAuth.
cat > server.ext <<EOF
basicConstraints       = CA:FALSE
keyUsage               = critical, digitalSignature, keyEncipherment
extendedKeyUsage       = serverAuth
subjectAltName         = DNS:app.${TEAM}.test, DNS:api.${TEAM}.test
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer
EOF

echo "== Creating CA key + self-signed CA certificate"
openssl genrsa -out ca.key 2048
openssl req -x509 -new -key ca.key -sha256 -days 365 -config ca.cnf -out ca.crt

echo "== Creating server key + certificate signing request"
openssl genrsa -out server.key 2048
openssl req -new -key server.key -config server.cnf -out server.csr

echo "== CA signs the server certificate (valid 365 days)"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 365 -sha256 -extfile server.ext -out server.crt

echo "== Checking the chain"
openssl verify -CAfile ca.crt server.crt
openssl x509 -in server.crt -noout -subject -issuer -dates
openssl x509 -in server.crt -noout -text | grep -A1 "Subject Alternative Name"

# 4. Copy the server cert + key where edge.conf expects them
if command -v brew >/dev/null 2>&1; then
  NGX="$(brew --prefix)/etc/nginx"
  mkdir -p "$NGX/certs"
  cp server.crt server.key "$NGX/certs/"
  chmod 600 "$NGX/certs/server.key"
  echo "== Copied server.crt + server.key to $NGX/certs/"
fi

echo
echo "Done. Next: AirDrop $OUT/ca.crt (ONLY ca.crt) to every client Mac and trust it:"
echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt"
