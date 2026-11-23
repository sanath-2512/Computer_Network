# Computer Networks Course Project — Phase 2: Live 11-Step Demo Script & Viva Guide
**Team: Network Packers (Team 1)**  
- **Aryan Bhargava** (`2401010100`, Node 1 – Main Edge Nginx / Backends A & B / Backup DNS / PF Firewall)  
- **Krishna Pramod Dubale** (Node 2 – Primary DNS / Standby Edge Nginx / Verification Client)  
- **Sanath Waraikar** (Registered Team Member / Phase 1 Architecture & Edge/DNS)  
**Academic Term**: Fall 2026 | **Domain**: `team1.test` | **Deployment**: 2 Physical macOS Laptops on Private Physical LAN (`10.7.0.0/19`, en0)

---

## 1. Live 11-Step Demonstration Script (For Live Faculty Evaluation)

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

# STEP 9: Demonstrate Phase 2 DNS & Resilience Behavior (Extensions A, B, E)
# A) Extension A (DNS Failover): Stop Primary dnsmasq on Krishna -> Query automatically answered by Backup DNS (10.7.11.108):
#    From Krishna: dig @10.7.11.108 app.team1.test +short (Returns 10.7.11.108)
#    Inspect capture: evidence/phase2/dns-failover.pcapng (Shows port 53 query redirect)
# B) Extension B (TTL & Caching): Consecutive dig queries show 30s TTL countdown:
#    From Krishna: dig @10.7.9.214 app.team1.test (Observe TTL decrementing 30 -> 25 -> 0)
# C) Extension E (Standby Edge DNS Cutover):
#    From Krishna: bash ~/.cn-team1-phase2/scripts/set-primary-dns-migration.sh
#    From Aryan:   bash ~/.cn-team1-phase2/scripts/set-backup-dns-migration.sh
#    Verify:       curl -iv https://app.team1.test/api/status (Served by Standby Edge)
#    Restoration:  bash ~/.cn-team1-phase2/scripts/restore-primary-dns-records.sh
#                  bash ~/.cn-team1-phase2/scripts/restore-backup-dns-records.sh

# SEPARATE CHECK - Extension C: Kernel-Level Service Isolation (PF Firewall)
# From Krishna's Mac: nc -vz -w 2 10.7.11.108 3001 (TIMES OUT - Dropped at kernel driver)
# From Aryan's Mac:   curl -s http://127.0.0.1:3001/api/status (SUCCEEDS via loopback lo0)

# STEP 10: Faculty-Injected Fault Diagnosis
# Follow Layer Sequence: DNS (dig) -> TCP (nc/ping) -> TLS (openssl s_client) -> App (curl/logs)

# STEP 11: Individual Viva Questions (See Section 2 below)
```

---

## 2. Viva Defense Guide & Key Conceptual Questions

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
