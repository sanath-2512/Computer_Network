# Computer Networks Course Project — Phase 2 Final Engineering Report
**Team: Network Packers (Team 1)**  
- **Aryan Bhargava** (`2401010100`, Node 1 – Main Edge Nginx / Backends A & B / Backup DNS / PF Firewall)  
- **Krishna Pramod Dubale** (Node 2 – Primary DNS / Standby Edge Nginx / Verification Client)  
- **Sanath Waraikar** (Registered Team Member / Phase 1 Architecture & Edge/DNS)  
**Academic Term**: Fall 2026 | **Domain**: `team1.test` | **Deployment**: 2 Physical macOS Laptops on Private Physical LAN (`10.7.0.0/19`, en0)

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
- **Objective**: Demonstrate application-layer resilience and zero-drop request retries when an upstream worker fails.
- **Physical Scope & HA Boundaries**: Both backends (A & B) are co-located on Aryan's physical Mac (`10.7.11.108`) bound to distinct loopback ports (`127.0.0.1:3001` and `3002`). This provides process-level redundancy and passive failover against application/worker crashes, but not physical hardware fault tolerance (which is addressed by Standby Edge DR in Extension E).
- **Execution**: Backend A (PID 16823) was stopped while Krishna executed 5 consecutive requests to `https://app.team1.test/api/status`.
- **Observed Behavior**:
  - Requests 1 through 5 returned `HTTP/2 200` with `X-Backend: B` (100% success rate, 0 dropped requests).
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
