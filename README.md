# Computer Networks Course Project — Private Network Service Platform
**A Two-Phase, Team-Based Local Networking Project on Physical macOS Laptops**

- **Team**: **Network Packers (Team 1)**
  - **Aryan Bhargava** (`2401010100`): Node 1 Operator (Main Edge Proxy, Backend Cluster A/B, Backup DNS, PF Firewall)
  - **Krishna Pramod Dubale**: Node 2 Operator (Primary DNS Server, Standby Edge Proxy, Verification Client)
  - **Sanath Waraikar**: Registered Team Member (Phase 1 Baseline Edge/DNS Architect)
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

- **Automated Node Bootstrap**: [`bootstrap-phase2.sh`](bootstrap-phase2.sh) *(Configures any node to Phase 2 runtime)*
- **Phase 2 Architecture Document**: [`docs/PHASE2_ARCHITECTURE.md`](docs/PHASE2_ARCHITECTURE.md) ([HTML View](docs/PHASE2_ARCHITECTURE.html))
- **Phase 2 Final Engineering Report**: [`docs/PHASE2_FINAL_REPORT.md`](docs/PHASE2_FINAL_REPORT.md) ([HTML View](docs/PHASE2_FINAL_REPORT.html))
- **Phase 1 Architecture**: [`docs/architecture.pdf`](docs/architecture.pdf)
- **Phase 1 Evidence**: [`evidence/INDEX.txt`](evidence/INDEX.txt) & [`evidence/phase1-flow.pcapng`](evidence/phase1-flow.pcapng)
- **Phase 2 Evidence**: [`evidence/phase2/INDEX.txt`](evidence/phase2/INDEX.txt) & [`evidence/phase2/dns-failover.pcapng`](evidence/phase2/dns-failover.pcapng)
- **Phase 2 Configuration Bundle**: [`config/phase2/`](config/phase2/)
- **Phase 2 Automation Scripts**: [`scripts/phase2/`](scripts/phase2/)

---

## Official 11-Step Final Demonstration Sequence (Section 8 Course Rubric)

Every team prepares to show all 11 steps sequentially during the faculty evaluation:

| Step | Demonstration Item | What the Evaluator Expects to See | Execution Command |
| :---: | :--- | :--- | :--- |
| **1** | **Show topology and IP/service inventory** | Display network diagram, IP table, and service map. Roles must be clear. | `cat docs/PHASE2_ARCHITECTURE.md` |
| **2** | **Confirm all machines on private LAN** | Run ping between machines; show each IP address. | `ping -c 2 10.7.9.214` |
| **3** | **Resolve private domain from client** | Run `dig app.team1.test` showing resolution to Aryan's IP via team DNS. | `dig @10.7.9.214 app.team1.test +short`<br>`dig @10.7.11.108 app.team1.test +short` |
| **4** | **Open service over HTTPS using domain name** | Open `https://app.team1.test` via curl/browser. No certificate warnings, no IP in URL. | `curl -v https://app.team1.test/api/status` |
| **5** | **Show load balancing across both backends** | Repeated requests showing `X-Backend: A` and `X-Backend: B` alternating. | `for i in {1..6}; do curl -s -i https://app.team1.test/api/status \| grep "x-backend:"; done` |
| **6** | **Show Wireshark evidence of DNS, TCP, TLS** | Open capture. Point to DNS query/response, TCP 3-way handshake, TLS handshake. | Open `evidence/phase2/dns-failover.pcapng` and `evidence/phase1-flow.pcapng` in Wireshark |
| **7** | **Show HTTP headers and caching behavior** | `curl -I` showing Cache-Control. Demonstrate 304 Not Modified or cache hit. | `curl -s -i https://app.team1.test/api/cached`<br>`curl -s -i -H 'If-None-Match: "22926ba9d1982e7c"' https://app.team1.test/api/cached` |
| **8** | **Fail one backend & prove service continues**| Stop Backend A. Show requests still succeed through Backend B only. | `scripts/phase2/stop-backend-A.sh`<br>`for i in {1..4}; do curl -s -i https://app.team1.test/api/status \| grep "x-backend:"; done`<br>`scripts/phase2/start-backend-A.sh` |
| **9** | **Demonstrate Phase 2 DNS & resilience behavior**| Show backup DNS failover, TTL/caching, or DNS-based cutover (Ext A/B/E). | **Ext A (DNS Failover):** Stop Primary dnsmasq -> verify fallback to Backup (10.7.11.108); inspect `evidence/phase2/dns-failover.pcapng`.<br>**Ext B (TTL/Caching):** `dig @10.7.9.214 app.team1.test` shows 30s TTL countdown; flush cache via `dscacheutil`.<br>**Ext E (DNS Cutover):** Run `set-primary-dns-migration.sh` & `set-backup-dns-migration.sh` -> verify Standby Edge. |
| **—** | **Extension C: Service Isolation (Separate Check)** | Block raw LAN inbound TCP to ports 3001/3002 via kernel PF anchor while loopback reverse-proxying succeeds. | `nc -vz -w 2 10.7.11.108 3001` (times out from Krishna)<br>`curl -s http://127.0.0.1:3001/api/status` (succeeds locally on Aryan) |
| **10**| **Diagnose faculty-injected fault** | Team diagnoses and fixes fault layer by layer: DNS -> TCP -> TLS -> App. | Follow Section 3 runbook in [`docs/PHASE2_FINAL_REPORT.md`](docs/PHASE2_FINAL_REPORT.md) |
| **11**| **Individual viva questions** | Every team member answers individual conceptual questions. | Follow Section 6 viva guide in [`docs/PHASE2_FINAL_REPORT.md`](docs/PHASE2_FINAL_REPORT.md) |

*(To clean up and restore your machines to baseline after evaluation: run `scripts/phase2/rollback.sh`).*

---

## Security & Change Control Policy
Private keys (`*.key`), local session credentials, and process PID files are excluded via `.gitignore` and remain strictly on the host machines. Certificates are generated using a 2048-bit RSA Local Root CA with strict validation enabled across all clients.
