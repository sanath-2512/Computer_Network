# Computer Networks Course Project — Phase 2 Final Engineering Report
**Team 1**: Aryan Bhargava (`2401010100`, Mac 2 – Edge/Backends/Backup DNS) & Krishna Pramod Dubale (Mac 1 – Primary DNS/Client/Standby Edge)  
**Academic Term**: Fall 2026 | **Domain**: `team1.test` | **Deployment**: 2 macOS Laptops on Private Physical LAN (`10.7.0.0/19`)

---

## 1. What Changed from Phase 1 to Phase 2

In Phase 1, the team established a baseline 3-laptop private service platform. While functional, it exhibited significant vulnerabilities: a single DNS server, exposed backend sockets on the LAN, static routing without health isolation, and no standby ingress.

For Phase 2, the system was hardened, recovered, and thoroughly tested across a 2-laptop topology:

1. **Topology Re-engineering (3 Macs -> 2 Macs)**:
   - Sanath's Mac was decommissioned from the active deployment.
   - All backend services (Backend A and Backend B) were co-located on Aryan's physical Mac, running as independent processes on ports 3001 and 3002.
   - Krishna assumed the Primary DNS resolver and client test role.
   - Aryan added a dedicated Backup DNS resolver on port 53.

2. **DNS Redundancy & TTL Reduction (Extensions A & B)**:
   - DNS TTL was lowered from 60s to 30s across all authoritative A-records to enable fast failover and cutover.
   - Dual-resolver redundancy was introduced: Primary on Krishna (`10.7.9.214:53`) and Backup on Aryan (`10.7.11.108:53`).

3. **Kernel-Level Service Isolation (Extension C)**:
   - In Phase 1, backends listened on `0.0.0.0` with no firewall, allowing any device on the Wi-Fi LAN to bypass the Nginx edge and access the backends directly.
   - In Phase 2, a macOS Packet Filter (PF) anchor (`com.apple/team1_isolation`) was applied to interface `en0`, dropping all inbound LAN TCP packets to ports 3001 and 3002 while allowing Nginx to proxy over loopback (`lo0`).

4. **Upstream Passive High Availability (Extension D)**:
   - Nginx upstream configuration was configured with `max_fails=1 fail_timeout=10s` and `proxy_next_upstream error timeout http_502 http_503`.
   - When a backend service fails, Nginx transparently re-routes the request to the healthy backend within 2 seconds without dropping client connections.

5. **Standby Edge Migration (Extension E)**:
   - Krishna's Mac was equipped with a dormant Standby Nginx edge.
   - A temporary PF firewall migration exception was engineered to permit Krishna's standby edge to access Aryan's backend ports 3001 and 3002 during failover, followed by clean restoration.

---

## 2. Resilience Tests and Live Verification Results

Every required extension was tested live over the physical LAN between Aryan and Krishna:

### Extension A: DNS Failover Demonstration
- **Objective**: Prove client name resolution survives a primary DNS server crash.
- **Execution**: Krishna stopped the primary `dnsmasq` resolver while running a promiscuous packet capture (`tshark -i en0 -w dns-failover.pcapng`).
- **Observed Behavior**:
  - `dig @10.7.11.108 app.team1.test +short` immediately returned `10.7.11.108` from Aryan's Backup DNS.
  - Client `curl https://app.team1.test/api/status` continued operating seamlessly without interruption.
- **Capture Evidence**: [`dns-failover.pcapng`](../evidence/phase2/dns-failover.pcapng) (1.6 MB) captures the automated client failover sequence to `10.7.11.108:53`.

### Extension B: DNS TTL & Controlled Record Change
- **Objective**: Demonstrate DNS caching behavior and rapid cutover under low TTL (30s).
- **Execution**: Both resolvers configured with `local-ttl=30`. A-record for `app.team1.test` changed to `10.7.9.214` and subsequently restored to `10.7.11.108`.
- **Observed Behavior**: Cached responses persisted until TTL elapsed. Flushing local DNS cache (`dscacheutil -flushcache`) triggered instantaneous re-query and record update.

### Extension C: Service Isolation via Packet Filter (PF)
- **Objective**: Prevent clients on the LAN from bypassing the edge and querying backend services directly.
- **Execution**: Injected PF anchor rule:
  ```pf
  block drop in quick on en0 proto tcp from any to 10.7.11.108 port { 3001, 3002 }
  ```
- **Observed Behavior**:
  - Krishna ran `nc -vz -G 2 10.7.11.108 3001` and `3002` -> `Operation timed out`.
  - Local Nginx proxying via `127.0.0.1:3001` and `3002` on `lo0` functioned without degradation.
  - Client access to `https://app.team1.test` (port 443) succeeded with HTTP 200.

### Extension D: High-Availability Upstream Failover
- **Objective**: Prove zero-downtime application resilience when an upstream backend fails.
- **Execution**: Backend A (PID 16823) was stopped while Krishna executed 5 consecutive requests to `https://app.team1.test/api/status`.
- **Observed Behavior**:
  - Requests 1 through 5 returned `HTTP/2 200 OK` with `X-Backend: B` (100% success rate, 0 dropped requests).
  - Nginx marked Backend A down for 10 seconds (`fail_timeout=10s`).
  - Backend A was restarted. After 11 seconds, repeated requests resumed round-robin alternation between A and B.

### Extension E: Controlled Standby Edge Migration
- **Objective**: Migrate ingress traffic to a standby reverse proxy without backend downtime.
- **Execution**:
  1. Aryan applied temporary PF exception: `pass in quick on en0 proto tcp from 10.7.9.214 to 10.7.11.108 port { 3001, 3002 }`.
  2. Krishna started Standby Nginx on port 443 with identical certificates and upstreams.
  3. DNS record updated to point `app.team1.test` -> `10.7.9.214`.
  4. Client request verified against `10.7.9.214:443`.
- **Observed Behavior**: Krishna's Standby Nginx successfully proxied requests across the LAN to Aryan's backends, returning `Server: nginx/1.31.9` and `X-Backend: A/B`.
- **Restoration**: Standby Nginx stopped, DNS records restored to `10.7.11.108`, and Aryan restored normal PF isolation.

---

## 3. Extension F: Troubleshooting Challenge Runbook

The project enforces a strict hierarchical troubleshooting methodology:
$$\text{Layer 7 (DNS)} \longrightarrow \text{Layer 4 (TCP)} \longrightarrow \text{Layer 5/6 (TLS)} \longrightarrow \text{Layer 7 (Application)}$$

| # | Injected Fault | Affected Layer | Diagnostic Command | Expected Symptom | Systematic Remediation |
|---|:---|:---|:---|:---|:---|
| **1** | Wrong DNS Server on Client | DNS (L7) | `dig @8.8.8.8 app.team1.test` | `status: NXDOMAIN` | Set Wi-Fi DNS to team primary (`10.7.9.214`) and backup (`10.7.11.108`). |
| **2** | Stale / Wrong A-Record | DNS (L7) | `dig app.team1.test +short` | Resolves to wrong IP | Correct `host-record` in `dnsmasq.conf` and reload resolver. |
| **3** | Primary DNS Resolver Down | DNS (L7) | `dig @10.7.9.214 app.team1.test` | Connection timed out | Fall back to Backup DNS (`10.7.11.108`) and restart primary dnsmasq. |
| **4** | Wrong Destination Port | TCP (L4) | `curl https://app.team1.test:8444/` | `Connection refused` | Identify active listener (`lsof -iTCP -sTCP:LISTEN`) and target port 443. |
| **5** | Main Edge Nginx Stopped | TCP (L4) | `nc -zv 10.7.11.108 443` | `Connection refused` | Start Nginx (`start-main-edge.sh`); inspect `nginx-error.log`. |
| **6** | Untrusted Root CA Certificate | TLS (L5/L6) | `curl https://app.team1.test/api/status` | `SSL certificate problem` | Install `ca.crt` into macOS System Keychain with `trustRoot` flag. |
| **7** | Hostname / SAN Mismatch | TLS (L5/L6) | `openssl s_client -connect 10.7.11.108:443` | Certificate name mismatch | Re-issue certificate with `subjectAltName = DNS:app.team1.test, DNS:api.team1.test`. |
| **8** | Single Backend Failure | App (L7) | `curl -s -i .../api/status \| grep X-Backend` | Traffic sticks to healthy backend | Check backend process (`ps aux \| grep backend.py`); restart failed backend. |
| **9** | Both Backends Stopped | App (L7) | `curl -i https://app.team1.test/api/status` | `HTTP/2 502 Bad Gateway` | Restart Backend A (`port 3001`) and Backend B (`port 3002`). |
| **10**| PF Blocking Upstream Loopback | Network (L3/L4)| `curl http://127.0.0.1:3001/api/status` | Connection dropped/refused | Ensure PF rule matches only physical interface (`on en0`) and never `lo0`. |

---

## 4. Learning Summary (One Detailed Paragraph per Extension)

- **Extension A (Backup DNS Resolver)**: Implementing an active backup DNS resolver demonstrated the practical separation between network routing and name resolution. We learned how stub resolvers prioritize multiple DNS nameservers and how low failover latency depends on fast negative caching and responsive secondary resolvers. This directly mirrored enterprise Route 53 multi-AZ resolver architectures.

- **Extension B (DNS TTL and Controlled Cutover)**: Working with a 30-second TTL provided hands-on understanding of the trade-off between resolver caching efficiency and operational agility. High TTLs reduce recursive query load but prolong propagation delay during outages; low TTLs allow rapid cutover during migrations at the cost of higher query frequency. We observed how operating system resolver caches (macOS `mDNSResponder`) enforce TTL expirations.

- **Extension C (Service Isolation via PF Firewall)**: Developing kernel-level packet filter rules deepened our understanding of transport-layer boundaries and defense-in-depth security. By restricting ports 3001 and 3002 on `en0`, we proved that edge proxies must serve as the sole entry point, preventing perimeter bypass. Structuring rules inside dedicated anchors (`com.apple/team1_isolation`) taught us safe change control without risking host stability.

- **Extension D (High-Availability Upstream Failover)**: Configuring passive health checks (`max_fails` and `fail_timeout`) along with `proxy_next_upstream` demonstrated layer 7 load-balancing resilience. We saw how reverse proxies mask infrastructure failures from clients, retrying failed requests idempotently on healthy backends. This highlighted the difference between passive client-driven detection and proactive synthetic health probing.

- **Extension E (Controlled Standby Edge Migration)**: Engineering a standby edge proxy on Krishna's Mac simulated a disaster recovery cutover. We learned how host-based firewall exceptions must be dynamically relaxed to permit inter-node reverse proxying during migration, and how DNS cutovers shift client ingress without taking downstream services offline.

- **Extension F (Fault Isolation and Layer-by-Layer Diagnosis)**: Simulating ten reproducible network failures solidified our understanding of the TCP/IP abstraction hierarchy. We developed disciplined diagnostic habits: verifying name resolution before blaming transport connectivity, inspecting TLS handshake alerts before investigating HTTP errors, and checking socket bindings before restarting services.

---

## 5. Live 11-Step Demonstration Script (For Review & Viva)

Follow this precise sequence during the viva examination:

```bash
# STEP 1: Topology & IP/Service Inventory
cat ~/.cn-team1-phase2/handoff-aryan.md

# STEP 2: LAN Reachability (Aryan <-> Krishna)
ping -c 2 10.7.9.214

# STEP 3: DNS Resolution (Primary & Backup)
dig @10.7.9.214 app.team1.test +short
dig @10.7.11.108 app.team1.test +short

# STEP 4: HTTPS over Domain Name (Strict TLS, HTTP/2, Keychain Trust)
curl -v https://app.team1.test/api/status

# STEP 5: Load Balancing Distribution (Round-Robin A/B)
for i in {1..6}; do curl -s -i https://app.team1.test/api/status | grep "x-backend:"; done

# STEP 6: Wireshark / Packet Capture Protocol Evidence
# Open dns-failover.pcapng and phase1-flow.pcapng in Wireshark

# STEP 7: HTTP Caching & Conditional 304 Not Modified
curl -s -i https://app.team1.test/api/cached | grep -E "(ETag|Cache-Control)"
# Conditional request with ETag:
curl -s -i -H 'If-None-Match: "22926ba9d1982e7c"' https://app.team1.test/api/cached | grep "HTTP/"

# STEP 8: Backend Failure (Stop A -> 100% traffic to B)
~/.cn-team1-phase2/scripts/stop-backend-A.sh
for i in {1..4}; do curl -s -i https://app.team1.test/api/status | grep "x-backend:"; done
~/.cn-team1-phase2/scripts/start-backend-A.sh

# STEP 9: Demonstrate Phase 2 Resilience (PF Firewall Isolation)
# From Krishna's Mac: nc -vz -w 2 10.7.11.108 3001 (TIMES OUT)
# From Aryan's Mac: curl http://127.0.0.1:3001/api/status (SUCCEEDS)

# STEP 10: Faculty-Injected Fault Diagnosis
# Follow Layer Sequence: DNS (dig) -> TCP (nc/ping) -> TLS (openssl s_client) -> App (curl/logs)

# STEP 11: Individual Viva Questions (See Section 6)
```

---

## 6. Viva Defense Guide & Key Conceptual Questions

### Questions for Aryan (Edge, TLS, Backends & Firewall)
1. **Why does Nginx listen on 0.0.0.0 for ports 80/443, but proxies to 127.0.0.1 for backends?**  
   *Answer*: Nginx must accept incoming connections from any client on the physical LAN interface (`en0`), so it binds to `0.0.0.0`. Backends, however, only serve internal traffic and are accessed locally over loopback (`lo0`).
2. **How does macOS PF distinguish between a request from Krishna and a request from Nginx?**  
   *Answer*: PF filters by interface. The rule `block drop in quick on en0` applies strictly to packets arriving over the physical Wi-Fi NIC. Nginx connects to backends via `127.0.0.1`, which traverses the loopback interface (`lo0`), bypassing `en0` rules.
3. **What is the difference between TLS 1.2 and TLS 1.3 handshakes?**  
   *Answer*: TLS 1.2 requires two round-trips (2-RTT) to negotiate cipher suites, exchange key parameters, and authenticate certificates. TLS 1.3 optimizes this to 1-RTT by combining key share generation with the ClientHello, and encrypts all certificate messages.
4. **Why is `ca.key` never copied to other machines?**  
   *Answer*: The Root CA private key possesses the cryptographic authority to sign certificates for any domain. Exposing `ca.key` compromises the entire PKI trust chain. Only the public certificate (`ca.crt`) is needed for trust verification.

### Questions for Krishna (DNS, Client Resolvers, Standby Edge & Captures)
1. **Why does DNS use UDP for queries instead of TCP? When does it switch to TCP?**  
   *Answer*: UDP avoids the connection overhead of a 3-way handshake, maximizing lookup speed. DNS switches to TCP (port 53) when responses exceed 512 bytes (or EDNS0 buffer limits), or for zone transfers (AXFR).
2. **What does TTL 30 represent, and what happens when an IP changes before TTL expires?**  
   *Answer*: TTL (Time to Live) specifies how many seconds recursive and stub resolvers may cache the record. If an IP changes, clients continue sending traffic to the old IP until the cached TTL counter reaches zero.
3. **How does Nginx passive health checking work compared to active health checking?**  
   *Answer*: Passive health checking detects failure upon handling real client traffic. If a connection fails or times out, Nginx retries the live request via `proxy_next_upstream` and marks the backend down for `fail_timeout`. Active health checking sends synthetic probe requests periodically regardless of client traffic.
