# Computer Networks Course Project — Phase 2 Architecture Document
**Team Network Packers (Team 1) — Private Network Service Platform: Hardened 2-Node Topology**  
- **Aryan Bhargava** (`2401010100`, Node 1 – Main Edge Nginx / Backends A & B / Backup DNS / PF Firewall)  
- **Krishna Pramod Dubale** (Node 2 – Primary DNS / Standby Edge Nginx / Verification Client)  
- **Sanath Waraikar** (Registered Team Member / Phase 1 Architecture & Edge/DNS)  
**Date**: November 2026 | **Academic Term**: Fall 2026

---

## 1. Executive Summary & Topology Evolution

In Phase 1, our team deployed a 3-laptop architecture across three physical MacBooks (Mac 1: DNS & Backend B, Mac 2: Nginx Edge & TLS, Mac 3: Backend A & Client).

In **Phase 2 (Harden, Recover, and Troubleshoot)**, the network was redesigned and re-engineered for a robust **2-laptop deployment** operating exclusively between **Aryan's Mac** and **Krishna's Mac** over a unified physical Wi-Fi LAN (`10.7.0.0/19`). The platform enforces DNS redundancy, fast-converging TTL management, kernel-level packet filter (PF) service isolation, upstream passive high availability, and dynamic standby edge failover.

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
             |                                  |         |                                  |
             | 1. Primary DNS (dnsmasq, port 53)|         | 1. Main Nginx Edge (80 -> 443)   |
             |    Authoritative for team1.test  |         |    TLS 1.2/1.3, HTTP/2 ALPN      |
             |                                  |         |    Passive Upstream Health Check |
             | 2. Client Test Runner            |         |                                  |
             |    curl, dig, scutil, dscacheutil|         | 2. Backup DNS (dnsmasq, port 53) |
             |                                  |         |    Authoritative, TTL 30s        |
             | 3. Packet Analysis Engine        |         |                                  |
             |    Wireshark / tshark on en0     |         | 3. Backend A (Python, port 3001) |
             |                                  |         |    REST Service, X-Backend: A    |
             | 4. Standby Nginx Edge (Ext E)    |         |                                  |
             |    Dormant reverse proxy (443)   |         | 4. Backend B (Python, port 3002) |
             |    Reverse proxies to Aryan's    |         |    REST Service, X-Backend: B    |
             |    backends during migration     |         |                                  |
             |                                  |         | 5. PF Firewall (Packet Filter)   |
             |                                  |         |    Anchor com.apple/team1_is...  |
             |                                  |         |    Blocks direct LAN to 3001/3002|
             +----------------------------------+         +----------------------------------+
```

---

## 2. Machine Roles & IP / Service Table

| Machine | Person | Physical IPv4 | Network Services | Transport Port | Role / Cloud Equivalent |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Mac 1** | **Krishna** | `10.7.9.214` | Primary DNS (`dnsmasq`) | UDP / TCP 53 | Primary Managed Resolver (AWS Route 53 Primary) |
| | | | Test Client (`curl`, `dig`) | Ephemeral Ports | Client Device / Packet Analyzer |
| | | | Standby Nginx Edge (Ext E)| TCP 443 | Multi-Region Standby Edge / Warm Standby |
| **Mac 2** | **Aryan** | `10.7.11.108`| Main Edge Proxy (`nginx`) | TCP 80, TCP 443 | Cloud Application Load Balancer / CDN Edge |
| | | | Backup DNS (`dnsmasq`) | UDP / TCP 53 | Secondary DNS Resolver (Route 53 Secondary) |
| | | | Backend Service A | TCP 3001 | App Server Instance A (Availability Zone 1) |
| | | | Backend Service B | TCP 3002 | App Server Instance B (Availability Zone 2) |
| | | | Packet Filter (`pfctl`) | Kernel-level L3/L4 | Security Group / VPC Network ACL |

---

## 3. Detailed Request Flow by Protocol Layer

When Krishna requests `https://app.team1.test/api/status`, the request travels through seven distinct protocol stages:

```
[Krishna Client]
       │
       ▼ (Step 1: DNS Resolution)
Queries Primary DNS (10.7.9.214:53 UDP). If primary is down, system resolver queries Backup DNS (10.7.11.108:53).
Resolver responds with Authoritative A-Record: 10.7.11.108 (TTL = 30 seconds).
       │
       ▼ (Step 2: TCP 3-Way Handshake)
Client initiates TCP connection to Aryan's IP: 10.7.11.108 on destination port 443.
Packet sequence: SYN (Client -> Aryan) ──> SYN-ACK (Aryan -> Client) ──> ACK (Client -> Aryan).
       │
       ▼ (Step 3: TLS 1.3 Handshake & ALPN)
Client sends ClientHello with SNI (`app.team1.test`) and ALPN (`h2, http/1.1`).
Aryan's Nginx responds with ServerHello (TLS 1.3), Certificate, CertificateVerify, and Finished.
Client validates server certificate against trusted `team1 Local Root CA` in macOS System Keychain.
ALPN negotiates HTTP/2 (`h2`).
       │
       ▼ (Step 4: HTTP/2 Request & Reverse Proxy)
Client sends encrypted frame: `GET /api/status HTTP/2` over TLS stream.
Nginx terminates TLS, inspects URI and Host header, and applies upstream load balancing algorithm.
       │
       ▼ (Step 5: macOS Packet Filter Enforcement)
Nginx proxies request internally to `127.0.0.1:3001` or `127.0.0.1:3002` over loopback (`lo0`).
Physical Wi-Fi interface (`en0`) drops any incoming LAN packets to 3001/3002 via PF anchor rule:
`block drop in quick on en0 proto tcp from any to 10.7.11.108 port { 3001, 3002 }`.
       │
       ▼ (Step 6: Backend Execution)
Python REST backend receives HTTP/1.1 request, injects `X-Backend: A` (or `B`), `Cache-Control: no-store`,
and JSON payload: `{"backend": "A", "status": "ok", "port": 3001, ...}`.
       │
       ▼ (Step 7: HTTP/2 Response)
Nginx frames backend response into encrypted HTTP/2 data frames and returns them to Krishna.
```

---

## 4. Single Point of Failure (SPOF) Analysis & Architectural Trade-offs

| Component | Phase 1 Vulnerability | Phase 2 Mitigation | Remaining SPOF & Production Fix |
| :--- | :--- | :--- | :--- |
| **DNS Resolver** | Single `dnsmasq` on Mac 1; outage halted all lookups. | Added independent Backup DNS on Aryan's Mac (`10.7.11.108:53`) with identical records and TTL 30s. | Both resolvers share LAN broadcast domain. Production fix: Anycast BGP routing across distinct ASNs. |
| **Edge Proxy (Nginx)** | Single edge on Aryan's Mac; failure severed ingress. | Added dormant Standby Edge on Krishna's Mac (Extension E) with verified DNS cutover capability. | Manual DNS cutover takes ~30s. Production fix: BGP Anycast VIP with ECMP (Equal-Cost Multi-Path). |
| **Backend Hardware** | Run on separate laptops (Mac 1 and Mac 3). | Co-located on Aryan's machine; isolated by port, process memory, and PF firewall. | Aryan's physical hardware is a single failure domain. Production fix: Separate physical bare-metal hosts or AZs. |
| **Health Checking** | Passive retries via `proxy_next_upstream`. | Passive health check skips dead backend for 10s upon first failure; zero client error drops. | Requires at least 1 client request to discover a failed backend. Production fix: Active synthetic health probes (HTTP probe daemon). |
| **Backend Access Control** | Backends exposed on 0.0.0.0 across entire LAN. | Enforced kernel PF rule on `en0` dropping all inbound LAN TCP packets to 3001 & 3002. | Source-IP migration rule trusts Krishna's entire host. Production fix: Mutual TLS (mTLS) with client certificate verification. |
