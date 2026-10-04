# CN Project – Phase 1: Private Network Service Platform (Team 1)

A client resolves `app.team1.test` through our own DNS server, connects over HTTPS to an nginx edge that terminates TLS, and nginx load-balances each request round-robin across two Python REST backends. Everything runs locally on three MacBooks on one Wi-Fi LAN; no cloud.

## Team

| Name | Enrollment No. | Machine | Role |
|---|---|---|---|
| Sanath SURNAME | ENROLLMENT_NO | Mac 1 – 10.7.7.6 | Private DNS server (dnsmasq) + Backend B + test client |
| Aryan SURNAME | ENROLLMENT_NO | Mac 2 – 10.7.17.6 | Edge: nginx reverse proxy, load balancer, TLS termination |
| Krishna Pramod Dubale | ENROLLMENT_NO | Mac 3 – 10.7.9.214 | Backend A + test client + Wireshark |

Infrastructure type: **Type 2 – 3 Macs with combined roles** (Mac 1 does DNS and Backend B).

## Network

| Item | Value |
|---|---|
| Subnet | 10.7.0.0/19 (mask 255.255.224.0), gateway 10.7.0.1, interface en0 |
| Private domain | `team1.test` |
| DNS records | `app.team1.test` → 10.7.17.6, `api.team1.test` → 10.7.17.6 (TTL 60) |
| Request path | Client → DNS (UDP 53, Mac 1) → nginx (TCP 443, Mac 2) → Backend A (TCP 3001, Mac 3) or Backend B (TCP 3002, Mac 1) |

Full diagrams (topology, IP/service table, request flow by protocol layer): [`docs/architecture.pdf`](docs/architecture.pdf)

## Repository layout

| Path | What it is |
|---|---|
| `backend/backend.py` | REST backend (Python standard library only) |
| `config/dnsmasq.conf` | DNS server config (Mac 1) |
| `config/edge.conf` | nginx reverse proxy + load balancer + TLS config (Mac 2) |
| `tls/make-certs.sh` | Creates our local CA and the server certificate (private keys are never committed) |
| `scripts/` | Test scripts: `check-dns.sh`, `request.sh`, `lb-test.sh`, `cache-test.sh`, `tls12-request.sh`, `demo.sh`, plus `myinfo.sh`, `backup-settings.sh`, `restore-settings.sh`, `firewall-allow.sh` |
| `configure.sh` | Fills in team number + IPs (already run for our IPs) |
| `docs/architecture.pdf` | Architecture document |
| `evidence/` | Screenshots, `phase1-flow.pcapng` capture, `INDEX.txt` (what each file proves), `failure-tests.txt` |

## How to run the backends

Python 3, no packages needed. Keep each terminal open.

```bash
# Mac 3 (Krishna) – Backend A
python3 backend/backend.py --id A --port 3001

# Mac 1 (Sanath) – Backend B
python3 backend/backend.py --id B --port 3002
```

Endpoints (both backends listen on 0.0.0.0 so the edge can reach them):

| Endpoint | Response |
|---|---|
| `GET /` | HTML page "Served by Backend A/B" |
| `GET /api/status` | `{"backend": "A", "status": "ok", ...}`, `Cache-Control: no-store` |
| `GET /api/cached` | JSON with `Cache-Control: public, max-age=60` and `ETag`; answers `304 Not Modified` to `If-None-Match` |

Every response carries the header `X-Backend: A` or `X-Backend: B`.

## How to run the DNS server (Mac 1)

```bash
brew install dnsmasq
cp config/dnsmasq.conf "$(brew --prefix)/etc/dnsmasq.conf"
dnsmasq --test -C "$(brew --prefix)/etc/dnsmasq.conf"
sudo brew services start dnsmasq
dig @127.0.0.1 app.team1.test +short        # -> 10.7.17.6
```

Clients use it with `sudo networksetup -setdnsservers Wi-Fi 10.7.7.6` (Mac 1 itself uses `127.0.0.1`).

## How to run the edge (Mac 2)

```bash
brew install nginx
bash tls/make-certs.sh                       # local CA + server cert for app/api.team1.test
cp config/edge.conf "$(brew --prefix)/etc/nginx/servers/edge.conf"
sudo nginx -t && sudo nginx
```

- Listens on **443** (TLS 1.2/1.3, HTTP/2); port 80 redirects to HTTPS.
- Upstream (round-robin): `10.7.9.214:3001` (A), `10.7.7.6:3002` (B).
- Passive failover: `max_fails=1 fail_timeout=10s`, `proxy_next_upstream error timeout`, `proxy_connect_timeout 2s`.

## TLS certificate setup

- `tls/make-certs.sh` creates a 2048-bit RSA local root CA (`team1 Local Root CA`) and a server certificate signed by it: CN `app.team1.test`, SAN `app.team1.test` + `api.team1.test`, `extendedKeyUsage = serverAuth`, valid 365 days.
- Every client Mac trusts only the CA certificate:
  `sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ca.crt`
- No `-k` / `--insecure` is used anywhere.

## How to test (from a client Mac)

```bash
bash scripts/check-dns.sh      # app + api resolve to 10.7.17.6 via 10.7.7.6
bash scripts/request.sh        # HTTPS by name, "SSL certificate verify ok"
bash scripts/lb-test.sh 10     # X-Backend alternates A / B
bash scripts/cache-test.sh     # 200 + Cache-Control + ETag, then 304
bash scripts/demo.sh           # all checks, incl. HTTP/1.1 vs HTTP/2
```

## Failure demonstrations

All five required failures and their explanations are in [`evidence/failure-tests.txt`](evidence/failure-tests.txt): one backend down (B serves everything), both down (TLS works, nginx returns 502), wrong port (connection refused), wrong DNS server (NXDOMAIN but ping works), wrong DNS record (resolves to the wrong IP, connection fails).
