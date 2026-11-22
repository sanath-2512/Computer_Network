# Computer Networks Course Project — Private Network Service Platform
**A Two-Phase, Team-Based Local Networking Project on Physical macOS Laptops**

- **Team**: Aryan Bhargava (`2401010100`), Krishna Pramod Dubale, Sanath Waraikar
- **Domain**: `team1.test` | **Physical Network**: Wi-Fi LAN (`10.7.0.0/19`, en0) | **Gateway**: `10.7.0.1`
- **Core Principle**: *The application stays simple — the network is the project.*

---

## Architecture Overview (Phase 2 Topology)

The platform operates across two physical macOS machines with complete separation of concerns and high-availability failover:

```
                              =============================================
                              PHYSICAL WI-FI LAN (Subnet 10.7.0.0/19, en0)
                              =============================================
                                      |                             |
                                      |                             |
             +----------------------------------+         +----------------------------------+
             |       KRISHNA'S MACBOOK          |         |         ARYAN'S MACBOOK          |
             |          (10.7.9.214)            |         |          (10.7.11.108)           |
             +----------------------------------+         +----------------------------------+
             | 1. Primary DNS (port 53, UDP/TCP)|         | 1. Main Nginx Edge (80 -> 443)   |
             |    Authoritative, TTL 30s        |         |    TLS 1.2/1.3, HTTP/2 ALPN      |
             | 2. Client Test Runner (curl, dig)|         |    Passive Upstream Failover     |
             | 3. Packet Analyzer (Wireshark)   |         | 2. Backup DNS (port 53, UDP/TCP) |
             | 4. Standby Nginx Edge (Ext E)    |         | 3. Backend A (Python, port 3001) |
             |    Reverse proxies during cutover|         | 4. Backend B (Python, port 3002) |
             |                                  |         | 5. PF Firewall (Isolation on en0)|
             +----------------------------------+         +----------------------------------+
```

| Component | Machine | IP Address | Port | Protocol / Features |
| :--- | :--- | :--- | :--- | :--- |
| **Primary DNS** | Krishna | `10.7.9.214` | 53 UDP/TCP | Authoritative for `team1.test`, TTL 30 |
| **Backup DNS** | Aryan | `10.7.11.108` | 53 UDP/TCP | Authoritative backup, TTL 30 |
| **Main Edge Proxy** | Aryan | `10.7.11.108` | 80, 443 | HTTP 301 redirect -> HTTPS, TLS 1.3 / HTTP/2 |
| **Standby Edge Proxy** | Krishna | `10.7.9.214` | 443 | Disaster recovery standby edge (Ext E) |
| **Backend Service A** | Aryan | `127.0.0.1` | 3001 TCP | Python REST backend (`X-Backend: A`) |
| **Backend Service B** | Aryan | `127.0.0.1` | 3002 TCP | Python REST backend (`X-Backend: B`) |
| **Service Isolation** | Aryan | `10.7.11.108` | 3001, 3002 | macOS Packet Filter (PF) drops inbound LAN traffic |

---

## Deliverables & Documentation Index

- **Phase 2 Architecture Document**: [`docs/PHASE2_ARCHITECTURE.md`](docs/PHASE2_ARCHITECTURE.md) ([HTML View](docs/PHASE2_ARCHITECTURE.html))
- **Phase 2 Final Engineering Report**: [`docs/PHASE2_FINAL_REPORT.md`](docs/PHASE2_FINAL_REPORT.md) ([HTML View](docs/PHASE2_FINAL_REPORT.html))
- **Phase 1 Architecture**: [`docs/architecture.pdf`](docs/architecture.pdf)
- **Phase 1 Evidence**: [`evidence/INDEX.txt`](evidence/INDEX.txt) & [`evidence/phase1-flow.pcapng`](evidence/phase1-flow.pcapng)
- **Phase 2 Evidence**: [`evidence/phase2/INDEX.txt`](evidence/phase2/INDEX.txt)
- **Phase 2 Configuration Bundle**: [`config/phase2/`](config/phase2/)
- **Phase 2 Automation Scripts**: [`scripts/phase2/`](scripts/phase2/)

---

## Rapid Evaluation Quick Start (11-Step Sequence)

During evaluation, run the following commands sequentially:

```bash
# 1. Inspect Inventory & Network Interfaces
cat docs/PHASE2_ARCHITECTURE.md

# 2. Verify Same-LAN Connectivity
ping -c 2 10.7.9.214

# 3. Verify DNS Resolution (Primary & Backup)
dig @10.7.9.214 app.team1.test +short
dig @10.7.11.108 app.team1.test +short

# 4. HTTPS over Domain Name (TLS 1.3 / HTTP/2)
curl -v https://app.team1.test/api/status

# 5. Round-Robin Load Balancing
for i in {1..6}; do curl -s -i https://app.team1.test/api/status | grep "x-backend:"; done

# 6. Wireshark Evidence
# Open evidence/phase1-flow.pcapng or evidence/phase2/dns-failover.pcapng

# 7. HTTP Caching & 304 Revalidation
curl -s -i https://app.team1.test/api/cached | grep -E "(ETag|Cache-Control)"
# Conditional request with ETag:
curl -s -i -H 'If-None-Match: "22926ba9d1982e7c"' https://app.team1.test/api/cached | grep "HTTP/"

# 8. Backend Failure (Stop A -> 100% traffic to B)
scripts/phase2/stop-backend-A.sh
for i in {1..4}; do curl -s -i https://app.team1.test/api/status | grep "x-backend:"; done
scripts/phase2/start-backend-A.sh

# 9. Packet Filter Firewall Isolation
# From Krishna (LAN): nc -vz -w 2 10.7.11.108 3001 -> Operation timed out
# From Aryan (Local): curl http://127.0.0.1:3001/api/status -> HTTP 200

# 10. Fault Diagnosis (Layer Hierarchy)
# Check: DNS (dig) -> TCP (nc) -> TLS (openssl s_client) -> App (curl)

# 11. Rollback to Baseline (When Finished)
scripts/phase2/rollback.sh
```

---

## Security & Change Control Policy
Private keys (`*.key`), local session credentials, and process PID files are excluded via `.gitignore` and remain strictly on the host machines. Certificates are generated using a 2048-bit RSA Local Root CA with strict validation enabled across all clients.
