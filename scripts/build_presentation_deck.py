#!/usr/bin/env python3
"""
Build Phase 2 Final Presentation Slide Decks:
1. PowerPoint Presentation (.pptx) with embedded screenshots and 16:9 layout
2. Interactive & Printable HTML Presentation (.html) with side-by-side evidence
3. 16:9 Landscape PDF Export via headless Chrome (.pdf)

Team: Network Packers (Aryan Bhargava & Krishna Pramod Dubale)
Course: Computer Networks Project Phase 2 (Harden, Recover & Troubleshoot)
"""

import os
import sys
import subprocess
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.enum.shapes import MSO_SHAPE

REPO_ROOT = "/Users/aryan./cn-project"
DOCS_DIR = os.path.join(REPO_ROOT, "docs")
DESKTOP_DIR = "/Users/aryan./Desktop"
DOWNLOADS_DIR = "/Users/aryan./Downloads"
EVIDENCE_P2 = os.path.join(REPO_ROOT, "evidence", "phase2")
EVIDENCE_P1 = os.path.join(REPO_ROOT, "evidence")

PPTX_PATH = os.path.join(DOCS_DIR, "Phase2_Final_Presentation_Team1.pptx")
HTML_PATH = os.path.join(DOCS_DIR, "PHASE2_SLIDES.html")
PDF_PATH = os.path.join(DOCS_DIR, "Phase2_Final_Presentation_Team1.pdf")

# Color Palette (Dark High-Tech Slate Theme)
C_BG = RGBColor(11, 17, 32)          # #0B1120 (Deep Slate)
C_CARD = RGBColor(30, 41, 59)        # #1E293B (Card Slate)
C_BORDER = RGBColor(51, 65, 85)      # #334155 (Subtle Border)
C_PRIMARY = RGBColor(248, 250, 252)  # #F8FAFC (White/Slate-50)
C_MUTED = RGBColor(148, 163, 184)    # #94A3B8 (Slate-400)
C_CYAN = RGBColor(56, 189, 248)      # #38BDF8 (Cyan Accent)
C_GREEN = RGBColor(52, 211, 153)     # #34D399 (Emerald Green)
C_ROSE = RGBColor(244, 63, 94)       # #F43F5E (Rose Accent)
C_AMBER = RGBColor(251, 191, 36)     # #FBBF24 (Amber Accent)

FONT_HEAD = "Trebuchet MS"
FONT_BODY = "Calibri"

# Detailed Presentation Slide Definitions
SLIDES = [
    {
        "num": 1,
        "type": "title",
        "category": "FINAL DEFENSE & EVALUATION",
        "title": "Private Network Service Platform",
        "subtitle": "Phase 2: Harden, Recover & Troubleshoot — Dual-Node Production Network Architecture",
        "authors": [
            {"name": "Aryan Bhargava", "role": "Node 1: Edge Proxy, Upstreams (A & B), Backup DNS, PF Firewall", "ip": "10.7.11.108"},
            {"name": "Krishna Pramod Dubale", "role": "Node 2: Primary DNS Server, Standby Edge, Verification Client", "ip": "10.7.9.214"},
            {"name": "Sanath Waraikar", "role": "Registered Team Member / Phase 1 Architecture & Edge/DNS", "ip": "Phase 1 Host"}
        ],
        "motto": "Core Mandate: \"The application stays simple — the network is the project.\"",
        "meta": "Campus Wi-Fi Subnet: 10.7.0.0/19 | Domain: app.team1.test | Team: Network Packers | November 2026"
    },
    {
        "num": 2,
        "type": "split",
        "category": "ARCHITECTURAL EVOLUTION",
        "title": "Phase 1 Baseline vs Phase 2 Hardened Production",
        "subtitle": "Transitioning from a 3-Mac prototype to a resilient, hardened 2-Mac production topology",
        "bullets": [
            "<strong>Phase 1 (3 Macs):</strong> Single edge proxy (Sanath) and unencrypted backends directly reachable across campus LAN.",
            "<strong>Phase 2 Realignment:</strong> Consolidated 2-node architecture with hot-standby redundancy across DNS and Edge.",
            "<strong>Node 1 (Aryan - 10.7.11.108):</strong> Reverse Proxy (Nginx), Upstream Backends A (:3001) & B (:3002), Backup DNS (:53).",
            "<strong>Node 2 (Krishna - 10.7.9.214):</strong> Primary DNS (:53), Standby Edge (:443), macOS strict TLS test engine.",
            "<strong>Security Win:</strong> macOS PF kernel firewall eliminates raw backend LAN attack surface entirely."
        ],
        "image": os.path.join(EVIDENCE_P2, "01-phase2-lan-discovery-aryan.png"),
        "caption": "Live Verification: Subnet discovery, interface verification (en0), and peer reachability (~6.8ms RTT)."
    },
    {
        "num": 3,
        "type": "split",
        "category": "NETWORK INVENTORY",
        "title": "Physical LAN Topology & Port Matrix",
        "subtitle": "Complete service binding, transport layer mapping, and access policies",
        "bullets": [
            "<strong>Physical Subnet:</strong> 10.7.0.0/19 on interface en0 | Gateway: 10.7.0.1 | 0.0% packet loss.",
            "<strong>Port 53 UDP/TCP:</strong> dnsmasq Primary (Node 2) & Backup (Node 1) with 30s TTL.",
            "<strong>Port 80 TCP:</strong> Nginx HTTP redirect (301 Permanent Redirect to HTTPS).",
            "<strong>Port 443 TCP:</strong> Nginx Edge Proxy terminating TLS 1.3 & HTTP/2 with custom SAN cert.",
            "<strong>Ports 3001 & 3002 TCP:</strong> Python microservices bound to loopback (127.0.0.1) on Node 1.",
            "<strong>Standby Edge:</strong> Pre-configured dormant Nginx on Node 2 (:443) for disaster migration."
        ],
        "image": os.path.join(EVIDENCE_P1, "01-lan-aryan-network-info-and-ping.jpg"),
        "caption": "Physical Node 1 network interface binding (en0), IP assignment, and gateway reachability."
    },
    {
        "num": 4,
        "type": "flow",
        "category": "PROTOCOL JOURNEY",
        "title": "End-to-End Request Journey Across 7 Layers",
        "subtitle": "Tracing https://app.team1.test/api/status through the entire networking stack",
        "steps": [
            {"step": "1. DNS Resolution (L7/L4)", "desc": "Client queries Primary DNS 10.7.9.214:53 via UDP; receives 10.7.11.108 with 30-second TTL."},
            {"step": "2. TCP 3-Way Handshake (L4)", "desc": "Client initiates SYN to 10.7.11.108:443; receives SYN-ACK; completes handshake with ACK."},
            {"step": "3. TLS 1.3 Handshake (L4.5)", "desc": "ClientHello with ALPN 'h2' -> ServerHello, Certificate (SAN verified), Finished in 1-RTT."},
            {"step": "4. HTTP/2 Multiplexing (L7)", "desc": "Binary stream 1 sends GET /api/status over single persistent multiplexed TCP socket."},
            {"step": "5. Edge Upstream Routing", "desc": "Nginx applies round-robin; dispatches over loopback (lo0) to 127.0.0.1:3001 or 3002."},
            {"step": "6. Kernel PF Enforcement", "desc": "macOS Packet Filter passes lo0 traffic; drops any raw LAN packets destined for 3001/3002."},
            {"step": "7. Response & Caching", "desc": "Backend emits JSON + X-Backend: A/B; Nginx sets ETag; conditional request yields HTTP 304."}
        ]
    },
    {
        "num": 5,
        "type": "split",
        "category": "PKI & SECURITY",
        "title": "PKI Architecture & Strict TLS 1.3 Handshake",
        "subtitle": "Native macOS System Keychain trust without insecure bypass flags (-k)",
        "bullets": [
            "<strong>Custom Root CA:</strong> 'Team1 Root CA' generated with 4096-bit RSA private key and SHA-256.",
            "<strong>Server Certificate:</strong> 2048-bit RSA with Subject Alternative Names (SAN: app.team1.test, team1.test, 10.7.11.108, 10.7.9.214).",
            "<strong>System Keychain Integration:</strong> Installed via security add-trusted-cert into /Library/Keychains/System.keychain.",
            "<strong>Strict TLS Verification:</strong> curl validates natively: SSL certificate verify ok | TLSv1.3 / TLS_AES_256_GCM_SHA384.",
            "<strong>ALPN Negotiation:</strong> Automatically negotiates ALPN: h2 (HTTP/2 binary framing)."
        ],
        "image": os.path.join(EVIDENCE_P2, "02-phase2-strict-tls-status.png"),
        "caption": "Strict curl validation proving TLS 1.3 handshake, SAN verification, and HTTP/2 200 OK."
    },
    {
        "num": 6,
        "type": "split",
        "category": "REVERSE PROXY",
        "title": "Layer 7 Load Balancing & Header Routing",
        "subtitle": "Round-robin upstream distribution with backend identification headers",
        "bullets": [
            "<strong>Upstream Pool:</strong> Nginx balances traffic across 127.0.0.1:3001 (Backend A) and 127.0.0.1:3002 (Backend B).",
            "<strong>Backend Identification:</strong> Every response injects header X-Backend: A or X-Backend: B for complete transparency.",
            "<strong>Protocol Decoupling:</strong> Client communicates with Edge over TLS 1.3 / HTTP/2; Edge communicates with backends over HTTP/1.1.",
            "<strong>Verification:</strong> Consecutive curl requests demonstrate strict alternation: Request 1 -> B, Request 2 -> A, Request 3 -> B, Request 4 -> A."
        ],
        "image": os.path.join(EVIDENCE_P2, "03-phase2-load-balancing-roundrobin.png"),
        "caption": "Live curl loop showing requests alternating cleanly between Backend A and Backend B."
    },
    {
        "num": 7,
        "type": "split",
        "category": "HTTP CACHING",
        "title": "HTTP Caching Mechanics: ETag & 304 Not Modified",
        "subtitle": "RFC 9110 conditional validation saving wireless LAN bandwidth",
        "bullets": [
            "<strong>Initial Request (HTTP 200):</strong> Client requests static resource; Nginx computes ETag (e.g. \"674...-100\") and Cache-Control.",
            "<strong>Client Local Cache:</strong> Client stores representation and caches the ETag validator.",
            "<strong>Conditional Request (HTTP 304):</strong> Client sends If-None-Match with stored ETag.",
            "<strong>Zero-Body Response:</strong> Nginx confirms content has not changed; returns HTTP/2 304 Not Modified with Content-Length: 0.",
            "<strong>Bandwidth Conservation:</strong> Eliminates duplicate payload transfer over wireless LAN."
        ],
        "image": os.path.join(EVIDENCE_P2, "04-phase2-caching-200-then-304.png"),
        "caption": "Initial HTTP 200 response with ETag header followed by conditional HTTP 304 Not Modified response."
    },
    {
        "num": 8,
        "type": "split",
        "category": "EXTENSION A",
        "title": "Extension A: Redundant DNS Failover",
        "subtitle": "Automated resolver shift during primary DNS outage captured on packet level",
        "bullets": [
            "<strong>Dual DNS Config:</strong> macOS client configured with Primary (10.7.9.214) and Backup (10.7.11.108).",
            "<strong>Fault Injection:</strong> Primary dnsmasq process terminated on Node 2.",
            "<strong>Automated Failover:</strong> Client resolver detects socket timeout on Primary and routes queries to Backup (10.7.11.108).",
            "<strong>Zero Interruption:</strong> curl https://app.team1.test continues resolving and serving requests seamlessly.",
            "<strong>Packet Capture Proof:</strong> dns-failover.pcapng (1.6 MB) recorded via tshark captures the exact port 53 migration."
        ],
        "image": os.path.join(EVIDENCE_P2, "08-phase2-dns-failover-backup-resolver.png"),
        "caption": "Terminal verification: Primary DNS stopped, client resolver automatically falling back to Backup DNS."
    },
    {
        "num": 9,
        "type": "split",
        "category": "EXTENSION B",
        "title": "Extension B: Dynamic TTL & Controlled DNS Cutover",
        "subtitle": "Optimizing DNS cache expiration for rapid disaster recovery propagation",
        "bullets": [
            "<strong>The TTL Trade-off:</strong> High TTL (e.g. 24h) minimizes DNS query overhead but causes slow failovers; low TTL (5s) floods wireless LAN.",
            "<strong>Phase 2 Design Choice:</strong> 30-Second TTL provides sub-minute disaster cutover with minimal wireless overhead.",
            "<strong>TTL Countdown:</strong> Consecutive dig queries display TTL counting down: 30s -> 25s -> 12s -> 0s.",
            "<strong>Controlled Cutover:</strong> DNS record updated and client cache flushed via dscacheutil -flushcache && sudo killall -HUP mDNSResponder.",
            "<strong>Negative Caching:</strong> min-cache-ttl=0 configured to prevent persistent caching of transient lookup errors."
        ],
        "image": os.path.join(EVIDENCE_P2, "10-phase2-dns-cutover-and-restore.png"),
        "caption": "DNS cutover test: Verifying 30s TTL record update, cache eviction, and instant target restoration."
    },
    {
        "num": 10,
        "type": "split",
        "category": "EXTENSION C",
        "title": "Extension C: Kernel-Level Service Isolation (macOS PF)",
        "subtitle": "Enforcing zero-trust perimeter around backend services using macOS PF",
        "bullets": [
            "<strong>The Vulnerability:</strong> If raw backends listen on LAN interfaces, any unauthorized user can bypass Nginx security.",
            "<strong>Defense-in-Depth:</strong> Backends bound to 127.0.0.1 AND protected by macOS Packet Filter (pfctl) kernel anchor.",
            "<strong>PF Anchor Rules (com.apple/team1_isolation):</strong>",
            "  • block in quick on en0 proto tcp to any port {3001, 3002}",
            "  • pass in quick on lo0 proto tcp to any port {3001, 3002}",
            "  • pass in quick on en0 proto tcp to any port {80, 443}",
            "<strong>Empirical Proof:</strong> nc to 10.7.11.108:3001 times out (dropped by PF), while port 443 connects instantly."
        ],
        "image": os.path.join(EVIDENCE_P2, "05-phase2-pf-firewall-service-isolation.png"),
        "caption": "Firewall verification: nc probe to ports 3001/3002 times out while HTTPS port 443 succeeds."
    },
    {
        "num": 11,
        "type": "split",
        "category": "EXTENSION D",
        "title": "Extension D: Upstream HA & Passive Health Checks",
        "subtitle": "Transparent upstream failover and automatic recovery without dropping requests",
        "bullets": [
            "<strong>Nginx HA Config:</strong> server 127.0.0.1:3001 max_fails=2 fail_timeout=10s; proxy_next_upstream error timeout http_502;",
            "<strong>Physical Scope:</strong> Backends A & B are co-located on Node 1; provides process-level failover against worker crashes.",
            "<strong>Zero Dropped Requests:</strong> Backend A killed; 5 consecutive client requests served 100% by Backend B without drops.",
            "<strong>Automatic Recovery:</strong> Backend A restarted; after 10s cooldown, Nginx automatically restores round-robin balance (B -> A -> B -> A)."
        ],
        "image": os.path.join(EVIDENCE_P2, "06-phase2-backend-ha-failover-a-down.png"),
        "caption": "Backend failover proof: 5 consecutive curls successfully served by Backend B when Backend A is down."
    },
    {
        "num": 12,
        "type": "split",
        "category": "EXTENSION E",
        "title": "Extension E: Standby Edge Disaster Recovery",
        "subtitle": "Cross-node edge proxy cutover with dynamic firewall migration",
        "bullets": [
            "<strong>Disaster Scenario:</strong> Node 1 edge proxy crashes or suffers network partition.",
            "<strong>Standby Edge:</strong> Pre-configured dormant Nginx instance on Node 2 (10.7.9.214:443).",
            "<strong>Dynamic Firewall Migration Rule:</strong> Node 1 dynamically loads migration anchor com.apple/team1_migration:",
            "  • pass in quick on en0 proto tcp from 10.7.9.214 to any port {3001, 3002}",
            "<strong>Pinpointed Access:</strong> ONLY Node 2 can reach backends over LAN; all other network hosts remain blocked.",
            "<strong>DNS Cutover:</strong> Primary DNS record updated to 10.7.9.214; client requests served by Standby Edge."
        ],
        "image": os.path.join(EVIDENCE_P2, "09-phase2-standby-edge-migration.png"),
        "caption": "Edge migration verification: Standby Nginx on Node 2 proxying traffic to Node 1 backends."
    },
    {
        "num": 13,
        "type": "split",
        "category": "EXTENSION F",
        "title": "Extension F: Layer-by-Layer Troubleshooting Runbook",
        "subtitle": "60-second diagnostic runbook for faculty-injected network faults",
        "bullets": [
            "<strong>L1/L3 Connectivity:</strong> ping -c 2 <target_ip> (Tests ARP resolution, Wi-Fi link, IP routing).",
            "<strong>L7 DNS Resolution:</strong> dig @<dns_ip> app.team1.test +short (Tests port 53 listener & zone records).",
            "<strong>L4 Transport / Firewall:</strong> nc -zv -w 2 <target_ip> 443 (Distinguishes between port closed vs PF drop).",
            "<strong>L4.5 TLS Cryptography:</strong> openssl s_client -connect <target_ip>:443 (Tests cert validity & SAN match).",
            "<strong>L7 Application:</strong> curl -iv --http2 https://app.team1.test/api/status (Tests 200 OK & backend headers).",
            "<strong>Rapid Remediation:</strong> bash scripts/phase2/test-all.sh runs full 12-test suite in 15 seconds."
        ],
        "image": os.path.join(EVIDENCE_P1, "18-break4-wrong-dns-server.jpg"),
        "caption": "Fault isolation evidence: Diagnosing DNS failure mode and verifying negative query resolution."
    },
    {
        "num": 14,
        "type": "split",
        "category": "WIRESHARK ANALYSIS",
        "title": "Wireshark Packet Analysis & Protocol Evidence",
        "subtitle": "Deep-dive frame inspection across DNS, TCP 3-way handshake, TLS 1.3 & HTTP/2",
        "bullets": [
            "<strong>DNS Query/Response:</strong> UDP port 53 frame showing Standard query A app.team1.test, Answer with TTL: 30s.",
            "<strong>TCP 3-Way Handshake:</strong> SYN (seq=0) -> SYN-ACK (seq=0, ack=1) -> ACK (seq=1, ack=1) with MSS 1460.",
            "<strong>TLS 1.3 Handshake:</strong> Client Hello with ALPN h2, Server Hello with key share exchange (1-RTT).",
            "<strong>HTTP/2 Multiplexing:</strong> Binary HEADERS and DATA frames multiplexed over stream 1.",
            "<strong>Capture Artifacts in Repo:</strong> phase1-flow.pcapng (706 KB) + dns-failover.pcapng (1.6 MB continuous failover capture)."
        ],
        "image": os.path.join(EVIDENCE_P1, "10-wireshark-tcp-3way-handshake.jpg"),
        "caption": "Wireshark capture: Frame-by-frame analysis of the TCP 3-way handshake to port 443."
    },
    {
        "num": 15,
        "type": "cards",
        "category": "PRODUCTION HARDENING",
        "title": "Production Hardening & Architectural Trade-offs",
        "subtitle": "Critique of design decisions, scaling bottlenecks, and real-world datacenter practices",
        "cards": [
            {
                "title": "Health Checking Mechanisms",
                "accent": "cyan",
                "bullets": [
                    "Our Architecture: Nginx OSS passive health checks (max_fails=2, fail_timeout=10s).",
                    "Trade-off: Requires 1-2 failed client requests before an upstream is marked down.",
                    "Enterprise Production: Envoy / Nginx Plus active synthetic probes (health_check uri=/api/health).",
                    "Proactively removes failed servers before client requests ever experience latency."
                ]
            },
            {
                "title": "Edge Routing & Failover",
                "accent": "amber",
                "bullets": [
                    "Our Architecture: DNS-based failover with 30s TTL and dual resolver entries.",
                    "Trade-off: Dependent on client resolver implementation and OS cache flushing.",
                    "Enterprise Production: BGP Anycast routing where both nodes announce identical Virtual IP (VIP).",
                    "Sub-second failover at Layer 3/4 via ECMP router re-convergence with zero DNS delay."
                ]
            },
            {
                "title": "Zero-Trust Upstream Security",
                "accent": "green",
                "bullets": [
                    "Our Architecture: macOS PF firewall + loopback binding for upstream isolation.",
                    "Enterprise Production: Mutual TLS (mTLS) with client certificates between Edge and Backends.",
                    "Cryptographic identity guarantees only authenticated proxies can decrypt backend traffic.",
                    "Automated Certificate Lifecycle: ACME protocol / HashiCorp Vault automated rotation."
                ]
            }
        ]
    },
    {
        "num": 16,
        "type": "flow",
        "category": "LIVE DEMO PLAN",
        "title": "Official 11-Step Evaluation Live Demo Plan",
        "subtitle": "Step-by-step checklist matching Section 8 of the course rubric",
        "steps": [
            {"step": "Step 1: Network Topology", "desc": "Show Slide 3 and cat docs/PHASE2_ARCHITECTURE.md displaying IPs, ports, and interface mappings."},
            {"step": "Step 2: Private LAN Reachability", "desc": "Execute ping -c 2 10.7.11.108 from Krishna's Mac confirming 0.0% packet loss and low latency."},
            {"step": "Step 3: Private DNS Resolution", "desc": "Run dig @10.7.9.214 app.team1.test +short returning 10.7.11.108 with 30-second TTL."},
            {"step": "Step 4: Strict HTTPS Verification", "desc": "Run curl -iv --http2 https://app.team1.test/api/status without -k (Strict TLS 1.3 verification)."},
            {"step": "Step 5: Upstream Load Balancing", "desc": "Run 4 consecutive curl requests demonstrating alternating X-Backend: A and X-Backend: B headers."},
            {"step": "Step 6: Wireshark Packet Proof", "desc": "Show Wireshark frames for DNS query, TCP 3-way handshake, TLS 1.3 handshake, and HTTP/2 framing."},
            {"step": "Step 7: HTTP Caching Validation", "desc": "Execute test-cache.sh showing initial HTTP 200 with ETag followed by conditional HTTP 304 Not Modified."},
            {"step": "Step 8: Backend High Availability", "desc": "Stop Backend A; run 5 curls (100% served by B with 0 errors); restart A (rejoins round-robin)."},
            {"step": "Step 9: Redundant DNS Failover", "desc": "Stop Primary DNS; show client resolver fails over to Backup DNS 10.7.11.108 (dns-failover.pcapng)."},
            {"step": "Step 10: Faculty Fault Diagnosis", "desc": "Execute systematic 60-second diagnostic runbook: L1 -> L7 DNS -> L4 Port -> L4.5 TLS -> L7 HTTP."},
            {"step": "Step 11: Individual Viva Defense", "desc": "Defend design decisions, PF kernel isolation, TLS 1.3 1-RTT, and proxy_next_upstream mechanics."}
        ]
    },
    {
        "num": 17,
        "type": "cards",
        "category": "VIVA DEFENSE GUIDE",
        "title": "Viva Defense: High-Scoring Technical Model Answers",
        "subtitle": "Precision technical rationale for top examiner questions",
        "cards": [
            {
                "title": "Q1: Defense-in-Depth for Backends",
                "accent": "cyan",
                "bullets": [
                    "Q: Why bind backends to 127.0.0.1 AND use PF firewall?",
                    "A: Defense-in-depth principle. If a backend is accidentally bound to 0.0.0.0 or if an unauthorized process binds to a public port, the kernel PF packet filter guarantees incoming packets on en0 are silently dropped before reaching the application layer."
                ]
            },
            {
                "title": "Q2: macOS DNS Resolver Failover",
                "accent": "amber",
                "bullets": [
                    "Q: How does macOS resolver handle dual DNS entries?",
                    "A: mDNSResponder maintains affinity to the first nameserver (10.7.9.214). Upon query timeout, the resolver marks the primary as degraded, falls back to the secondary (10.7.11.108), and caches that failover state until the primary recovers."
                ]
            },
            {
                "title": "Q3: TLS 1.3 vs TLS 1.2 Handshake Latency",
                "accent": "green",
                "bullets": [
                    "Q: Why is TLS 1.3 faster than TLS 1.2 during connection setup?",
                    "A: TLS 1.2 requires 2 full round-trips (2-RTT) for negotiation and key exchange. TLS 1.3 completes in 1-RTT because the client speculatively sends its Diffie-Hellman key share inside the ClientHello message."
                ]
            }
        ]
    },
    {
        "num": 18,
        "type": "cards",
        "category": "DELIVERABLES & CONCLUSION",
        "title": "Submission Manifest & Team Sign-off",
        "subtitle": "Complete verification bundle, open-source repository, and live services status",
        "cards": [
            {
                "title": "Deliverables Manifest",
                "accent": "cyan",
                "bullets": [
                    "1. Architecture Doc: docs/PHASE2_ARCHITECTURE.md & .html",
                    "2. Final Report: docs/PHASE2_FINAL_REPORT.md & .html",
                    "3. Presentation Decks: Phase2_Final_Presentation_Team1.pptx & .pdf",
                    "4. Configuration Bundle: config/phase2/ (6 production configs)",
                    "5. Source & Scripts: scripts/phase2/ (20 automation scripts)"
                ]
            },
            {
                "title": "Evidence & GitHub Repository",
                "accent": "green",
                "bullets": [
                    "6. Evidence Folder: evidence/phase2/ (10 PNG screenshots, 1.6MB PCAP, raw logs)",
                    "7. Submission Archive: ~/Desktop/Phase2_Submission_Team1.zip (1.6 MB bundle)",
                    "8. GitHub Repository: https://github.com/sanath-2512/Computer_Network",
                    "Full commit history with reproducible verification logs."
                ]
            },
            {
                "title": "Live Status & Readiness",
                "accent": "amber",
                "bullets": [
                    "Aryan (10.7.11.108): Nginx (:443), Backends A & B (:3001/:3002), Backup DNS (:53) [ACTIVE]",
                    "Krishna (10.7.9.214): Primary DNS (:53), Standby Edge (:443), Test Client [ACTIVE]",
                    "All services running live on hardware, tested, verified, and ready for immediate demonstration.",
                    "Network Packers: Aryan Bhargava, Krishna Pramod Dubale, Sanath Waraikar."
                ]
            }
        ]
    }
]

def build_pptx():
    print("Building Widescreen PowerPoint Presentation (.pptx)...")
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6]

    for data in SLIDES:
        slide = prs.slides.add_slide(blank_layout)

        # 1. Dark Background
        bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), Inches(13.333), Inches(7.5))
        bg.fill.solid()
        bg.fill.fore_color.rgb = C_BG
        bg.line.color.rgb = C_BG

        # 2. Header
        top_bar = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.8), Inches(0.35), Inches(11.733), Inches(0.04))
        top_bar.fill.solid()
        top_bar.fill.fore_color.rgb = C_CYAN
        top_bar.line.fill.background()

        cat_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.42), Inches(11.0), Inches(0.3))
        tf_cat = cat_box.text_frame
        p_cat = tf_cat.paragraphs[0]
        p_cat.text = f"NETWORK PACKERS | {data['category']} | SLIDE {data['num']} OF {len(SLIDES)}"
        p_cat.font.name = FONT_HEAD
        p_cat.font.size = Pt(10)
        p_cat.font.bold = True
        p_cat.font.color.rgb = C_CYAN

        title_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.7), Inches(11.733), Inches(0.6))
        tf_title = title_box.text_frame
        p_title = tf_title.paragraphs[0]
        p_title.text = data["title"]
        p_title.font.name = FONT_HEAD
        p_title.font.size = Pt(22)
        p_title.font.bold = True
        p_title.font.color.rgb = C_PRIMARY

        sub_box = slide.shapes.add_textbox(Inches(0.8), Inches(1.25), Inches(11.733), Inches(0.4))
        tf_sub = sub_box.text_frame
        p_sub = tf_sub.paragraphs[0]
        p_sub.text = data["subtitle"]
        p_sub.font.name = FONT_BODY
        p_sub.font.size = Pt(12)
        p_sub.font.color.rgb = C_MUTED

        # 3. Slide Body Layouts
        stype = data.get("type")

        if stype == "title":
            # Title Hero Layout
            hero_box = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(1.9), Inches(11.733), Inches(4.7))
            hero_box.fill.solid()
            hero_box.fill.fore_color.rgb = C_CARD
            hero_box.line.color.rgb = C_BORDER
            hero_box.line.width = Pt(1.5)

            # Authors Cards
            num_authors = len(data["authors"])
            gap = Inches(0.25)
            total_w = Inches(11.1)
            card_w = (total_w - (num_authors - 1) * gap) / num_authors
            card_h = Inches(1.8)
            for idx, a in enumerate(data["authors"]):
                ax = Inches(1.1) + idx * (card_w + gap)
                ay = Inches(2.3)
                abox = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, ax, ay, card_w, card_h)
                abox.fill.solid()
                abox.fill.fore_color.rgb = RGBColor(20, 29, 47)
                abox.line.color.rgb = C_CYAN if idx == 0 else (C_AMBER if idx == 1 else C_GREEN)
                abox.line.width = Pt(1.5)

                atf = abox.text_frame
                atf.word_wrap = True
                p1 = atf.paragraphs[0]
                p1.text = f"{a['name']}"
                if a.get('ip'):
                    p1.text += f" ({a['ip']})"
                p1.font.name = FONT_HEAD
                p1.font.size = Pt(13)
                p1.font.bold = True
                p1.font.color.rgb = C_CYAN if idx == 0 else (C_AMBER if idx == 1 else C_GREEN)
                p1.space_after = Pt(4)

                p2 = atf.add_paragraph()
                p2.text = a["role"]
                p2.font.name = FONT_BODY
                p2.font.size = Pt(10)
                p2.font.color.rgb = C_PRIMARY

            # Motto Box
            mbox = slide.shapes.add_textbox(Inches(1.1), Inches(4.4), Inches(11.1), Inches(0.8))
            mtf = mbox.text_frame
            mtf.word_wrap = True
            mp = mtf.paragraphs[0]
            mp.text = data["motto"]
            mp.font.name = FONT_HEAD
            mp.font.size = Pt(16)
            mp.font.bold = True
            mp.font.color.rgb = C_GREEN
            mp.space_after = Pt(8)

            mp2 = mtf.add_paragraph()
            mp2.text = data["meta"]
            mp2.font.name = FONT_BODY
            mp2.font.size = Pt(12)
            mp2.font.color.rgb = C_MUTED

        elif stype == "split":
            # Left: Technical Content (width = 6.4 inches)
            left_rect = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(1.8), Inches(6.4), Inches(4.85))
            left_rect.fill.solid()
            left_rect.fill.fore_color.rgb = C_CARD
            left_rect.line.color.rgb = C_BORDER
            left_rect.line.width = Pt(1.5)

            ltf = left_rect.text_frame
            ltf.word_wrap = True
            for b_idx, b_text in enumerate(data["bullets"]):
                clean_text = b_text.replace("<strong>", "").replace("</strong>", "")
                p_b = ltf.paragraphs[0] if b_idx == 0 else ltf.add_paragraph()
                p_b.text = f"•  {clean_text}"
                p_b.font.name = FONT_BODY
                p_b.font.size = Pt(11)
                p_b.font.color.rgb = C_PRIMARY
                p_b.space_after = Pt(8)

            # Right: Image & Caption (width = 5.0 inches)
            img_path = data.get("image")
            if img_path and os.path.exists(img_path):
                try:
                    slide.shapes.add_picture(img_path, Inches(7.5), Inches(1.8), width=Inches(5.0))
                except Exception as e:
                    print(f"Warning: could not add picture {img_path}: {e}")

            cap_box = slide.shapes.add_textbox(Inches(7.5), Inches(5.6), Inches(5.0), Inches(1.0))
            ctf = cap_box.text_frame
            ctf.word_wrap = True
            cp = ctf.paragraphs[0]
            cp.text = data.get("caption", "Verification Evidence")
            cp.font.name = FONT_BODY
            cp.font.size = Pt(9.5)
            cp.font.color.rgb = C_MUTED

        elif stype == "flow":
            # Flow Layout
            flow_rect = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, Inches(0.8), Inches(1.8), Inches(11.733), Inches(4.85))
            flow_rect.fill.solid()
            flow_rect.fill.fore_color.rgb = C_CARD
            flow_rect.line.color.rgb = C_BORDER
            flow_rect.line.width = Pt(1.5)

            ftf = flow_rect.text_frame
            ftf.word_wrap = True
            steps = data.get("steps", [])
            for s_idx, st in enumerate(steps):
                p_s = ftf.paragraphs[0] if s_idx == 0 else ftf.add_paragraph()
                p_s.text = f"{st['step']}: {st['desc']}"
                p_s.font.name = FONT_BODY
                p_s.font.size = Pt(10)
                p_s.font.color.rgb = C_PRIMARY
                p_s.space_after = Pt(6)

        elif stype == "cards":
            # 3 Cards Layout
            cards = data.get("cards", [])
            card_w = Inches(3.72)
            card_h = Inches(4.85)
            gap = Inches(0.28)
            for i, card in enumerate(cards):
                cx = Inches(0.8 + i * (3.72 + 0.28))
                crect = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, cx, Inches(1.8), card_w, card_h)
                crect.fill.solid()
                crect.fill.fore_color.rgb = C_CARD
                crect.line.color.rgb = C_BORDER
                crect.line.width = Pt(1.5)

                ctf = crect.text_frame
                ctf.word_wrap = True
                p_head = ctf.paragraphs[0]
                p_head.text = card["title"]
                p_head.font.name = FONT_HEAD
                p_head.font.size = Pt(13)
                p_head.font.bold = True
                p_head.font.color.rgb = C_CYAN if card.get("accent") == "cyan" else (C_AMBER if card.get("accent") == "amber" else C_GREEN)
                p_head.space_after = Pt(8)

                for b_text in card["bullets"]:
                    p_b = ctf.add_paragraph()
                    p_b.text = f"•  {b_text}"
                    p_b.font.name = FONT_BODY
                    p_b.font.size = Pt(10)
                    p_b.font.color.rgb = C_PRIMARY
                    p_b.space_after = Pt(6)

        # 4. Slide Footer
        foot_box = slide.shapes.add_textbox(Inches(0.8), Inches(6.85), Inches(11.733), Inches(0.3))
        ftf = foot_box.text_frame
        p_ft = ftf.paragraphs[0]
        p_ft.text = f"Network Packers | Aryan Bhargava & Krishna Pramod Dubale | Slide {data['num']} of {len(SLIDES)}"
        p_ft.font.name = FONT_BODY
        p_ft.font.size = Pt(9)
        p_ft.font.color.rgb = C_MUTED

    prs.save(PPTX_PATH)
    print(f"PowerPoint created: {PPTX_PATH}")


def build_html():
    print("Building Interactive & Printable Widescreen HTML Presentation (.html)...")
    
    slides_html_parts = []
    
    for data in SLIDES:
        stype = data.get("type")
        body_html = ""
        
        if stype == "title":
            authors_html = ""
            for a in data["authors"]:
                authors_html += f"""
                <div class="author-card">
                    <div class="author-name">{a['name']} <span class="author-ip">({a['ip']})</span></div>
                    <div class="author-role">{a['role']}</div>
                </div>
                """
            body_html = f"""
            <div class="title-hero">
                <div class="authors-row">{authors_html}</div>
                <div class="motto-box">
                    <div class="motto-text">{data['motto']}</div>
                    <div class="motto-meta">{data['meta']}</div>
                </div>
            </div>
            """
            
        elif stype == "split":
            bullets_li = "".join([f"<li>{b}</li>" for b in data["bullets"]])
            img_tag = ""
            if data.get("image") and os.path.exists(data["image"]):
                img_tag = f"""
                <div class="img-wrapper">
                    <img src="{data['image']}" alt="Screenshot">
                    <div class="caption">{data.get('caption', '')}</div>
                </div>
                """
            body_html = f"""
            <div class="split-layout">
                <div class="split-left">
                    <ul class="bullet-list">{bullets_li}</ul>
                </div>
                <div class="split-right">
                    {img_tag}
                </div>
            </div>
            """
            
        elif stype == "flow":
            steps_html = ""
            for s in data["steps"]:
                steps_html += f"""
                <div class="flow-step">
                    <div class="step-num">{s['step']}</div>
                    <div class="step-desc">{s['desc']}</div>
                </div>
                """
            body_html = f"""
            <div class="flow-container">
                {steps_html}
            </div>
            """
            
        elif stype == "cards":
            cards_html = ""
            for c in data["cards"]:
                acc = c.get("accent", "cyan")
                c_li = "".join([f"<li>{b}</li>" for b in c["bullets"]])
                cards_html += f"""
                <div class="card card-{acc}">
                    <div class="card-bar"></div>
                    <div class="card-title">{c['title']}</div>
                    <ul class="card-bullets">{c_li}</ul>
                </div>
                """
            body_html = f"""
            <div class="cards-row">
                {cards_html}
            </div>
            """
            
        slides_html_parts.append(f"""
        <section class="slide" id="slide-{data['num']}">
            <div class="slide-header">
                <div class="badge-row">
                    <span class="badge">NETWORK PACKERS</span>
                    <span class="badge-cat">{data['category']}</span>
                    <span class="badge-num">SLIDE {data['num']} OF {len(SLIDES)}</span>
                </div>
                <h1 class="slide-title">{data['title']}</h1>
                <p class="slide-subtitle">{data['subtitle']}</p>
            </div>
            <div class="slide-body">
                {body_html}
            </div>
            <div class="slide-footer">
                <span>Network Packers &bull; Aryan Bhargava & Krishna Pramod Dubale</span>
                <span>Computer Networks Lab Final Review &bull; Slide {data['num']} / {len(SLIDES)}</span>
            </div>
        </section>
        """)

    all_slides = "\n".join(slides_html_parts)

    html_doc = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Network Packers - Private Network Service Platform (Phase 2)</title>
<style>
@page {{
    size: 1920px 1080px;
    margin: 0;
}}
* {{
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}}
body {{
    background: #0b1120;
    color: #f8fafc;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    margin: 0;
    padding: 0;
}}
.slide {{
    width: 1920px;
    height: 1080px;
    padding: 50px 70px 40px 70px;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    background: #0b1120;
    page-break-after: always;
    break-after: page;
    position: relative;
    overflow: hidden;
}}
.slide-header {{
    border-bottom: 2px solid #38bdf8;
    padding-bottom: 18px;
    flex-shrink: 0;
}}
.badge-row {{
    display: flex;
    gap: 12px;
    align-items: center;
    margin-bottom: 8px;
}}
.badge {{
    background: #38bdf8;
    color: #0b1120;
    font-size: 12px;
    font-weight: 800;
    padding: 3px 8px;
    border-radius: 4px;
    letter-spacing: 1px;
}}
.badge-cat {{
    color: #38bdf8;
    font-size: 14px;
    font-weight: 700;
    letter-spacing: 1.5px;
    text-transform: uppercase;
}}
.badge-num {{
    color: #64748b;
    font-size: 13px;
    font-weight: 600;
    margin-left: auto;
}}
.slide-title {{
    font-size: 38px;
    font-weight: 800;
    color: #ffffff;
    letter-spacing: -0.5px;
    line-height: 1.15;
}}
.slide-subtitle {{
    font-size: 18px;
    color: #94a3b8;
    margin-top: 6px;
}}
.slide-body {{
    flex-grow: 1;
    display: flex;
    flex-direction: column;
    justify-content: center;
    margin: 20px 0;
}}
/* Split Layout */
.split-layout {{
    display: flex;
    gap: 40px;
    align-items: center;
    width: 100%;
}}
.split-left {{
    flex: 1.25;
    background: #1e293b;
    border: 1px solid #334155;
    border-radius: 12px;
    padding: 28px 32px;
    box-shadow: 0 10px 25px rgba(0,0,0,0.4);
}}
.bullet-list {{
    list-style: square;
    padding-left: 20px;
    display: flex;
    flex-direction: column;
    gap: 16px;
}}
.bullet-list li {{
    font-size: 18px;
    line-height: 1.55;
    color: #cbd5e1;
}}
.bullet-list strong {{
    color: #38bdf8;
}}
.bullet-list code {{
    background: #0f172a;
    color: #34d399;
    padding: 2px 6px;
    border-radius: 4px;
    font-family: Consolas, monospace;
    font-size: 16px;
}}
.split-right {{
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
}}
.img-wrapper {{
    width: 100%;
    background: #1e293b;
    border: 1px solid #334155;
    border-radius: 12px;
    padding: 12px;
    box-shadow: 0 15px 30px rgba(0,0,0,0.5);
    display: flex;
    flex-direction: column;
    align-items: center;
}}
.img-wrapper img {{
    width: 100%;
    max-height: 520px;
    object-fit: contain;
    border-radius: 8px;
    border: 1px solid #475569;
}}
.caption {{
    font-size: 14px;
    color: #94a3b8;
    margin-top: 10px;
    text-align: center;
    font-family: Consolas, monospace;
}}
/* Title Hero Layout */
.title-hero {{
    display: flex;
    flex-direction: column;
    gap: 30px;
    width: 100%;
}}
.authors-row {{
    display: flex;
    gap: 30px;
    width: 100%;
}}
.author-card {{
    flex: 1;
    background: #1e293b;
    border: 2px solid #38bdf8;
    border-radius: 12px;
    padding: 25px 30px;
    box-shadow: 0 10px 25px rgba(0,0,0,0.4);
}}
.author-card:nth-child(2) {{
    border-color: #fbbf24;
}}
.author-card:nth-child(3) {{
    border-color: #34d399;
}}
.author-name {{
    font-size: 24px;
    font-weight: 800;
    color: #ffffff;
}}
.author-ip {{
    color: #38bdf8;
    font-size: 20px;
    font-family: Consolas, monospace;
}}
.author-card:nth-child(2) .author-ip {{
    color: #fbbf24;
}}
.author-card:nth-child(3) .author-ip {{
    color: #34d399;
}}
.author-role {{
    font-size: 16px;
    color: #cbd5e1;
    margin-top: 10px;
    line-height: 1.45;
}}
.motto-box {{
    background: #1e293b;
    border: 1px solid #334155;
    border-radius: 12px;
    padding: 25px 30px;
}}
.motto-text {{
    font-size: 22px;
    font-weight: 700;
    color: #34d399;
}}
.motto-meta {{
    font-size: 16px;
    color: #94a3b8;
    margin-top: 8px;
}}
/* Flow Layout */
.flow-container {{
    display: flex;
    flex-direction: column;
    gap: 12px;
    background: #1e293b;
    border: 1px solid #334155;
    border-radius: 12px;
    padding: 24px 30px;
}}
.flow-step {{
    display: flex;
    gap: 20px;
    align-items: baseline;
    border-bottom: 1px solid #334155;
    padding-bottom: 10px;
}}
.flow-step:last-child {{
    border-bottom: none;
    padding-bottom: 0;
}}
.step-num {{
    font-size: 17px;
    font-weight: 700;
    color: #38bdf8;
    min-width: 260px;
    font-family: Consolas, monospace;
}}
.step-desc {{
    font-size: 16px;
    color: #cbd5e1;
    line-height: 1.45;
}}
/* Cards Layout */
.cards-row {{
    display: flex;
    gap: 25px;
    width: 100%;
}}
.card {{
    flex: 1;
    background: #1e293b;
    border: 1px solid #334155;
    border-radius: 12px;
    padding: 25px;
    box-shadow: 0 10px 20px rgba(0,0,0,0.3);
    display: flex;
    flex-direction: column;
}}
.card-bar {{
    width: 40px;
    height: 4px;
    border-radius: 2px;
    margin-bottom: 15px;
}}
.card-cyan .card-bar {{ background: #38bdf8; }}
.card-cyan .card-title {{ color: #38bdf8; }}
.card-green .card-bar {{ background: #34d399; }}
.card-green .card-title {{ color: #34d399; }}
.card-amber .card-bar {{ background: #fbbf24; }}
.card-amber .card-title {{ color: #fbbf24; }}
.card-title {{
    font-size: 20px;
    font-weight: 700;
    margin-bottom: 15px;
}}
.card-bullets {{
    list-style: square;
    padding-left: 20px;
    display: flex;
    flex-direction: column;
    gap: 12px;
}}
.card-bullets li {{
    font-size: 15px;
    color: #cbd5e1;
    line-height: 1.45;
}}
/* Footer */
.slide-footer {{
    border-top: 1px solid #1e293b;
    padding-top: 14px;
    display: flex;
    justify-content: space-between;
    font-size: 14px;
    color: #64748b;
    flex-shrink: 0;
}}
</style>
</head>
<body>
{all_slides}
</body>
</html>
"""

    with open(HTML_PATH, "w", encoding="utf-8") as f:
        f.write(html_doc)
    print(f"HTML presentation created: {HTML_PATH}")


def export_pdf():
    print("Exporting 16:9 Landscape PDF via Chrome Headless...")
    chrome_bin = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    cmd = [
        chrome_bin,
        "--headless",
        "--disable-gpu",
        "--no-pdf-header-footer",
        f"--print-to-pdf={PDF_PATH}",
        HTML_PATH
    ]
    subprocess.run(cmd, check=True)
    print(f"PDF successfully exported to: {PDF_PATH}")


def sync_copies():
    print("Syncing copies to Desktop and Downloads...")
    for stem in ["Phase2_Final_Presentation_Team1", "Phase2_Final_Presentation_Network_Packers"]:
        subprocess.run(["cp", "-f", PPTX_PATH, os.path.join(DESKTOP_DIR, f"{stem}.pptx")], check=True)
        subprocess.run(["cp", "-f", PDF_PATH, os.path.join(DESKTOP_DIR, f"{stem}.pdf")], check=True)
        subprocess.run(["cp", "-f", PDF_PATH, os.path.join(DOWNLOADS_DIR, f"{stem}.pdf")], check=True)
        subprocess.run(["cp", "-f", PPTX_PATH, os.path.join(DOWNLOADS_DIR, f"{stem}.pptx")], check=True)
    print("All copies synced.")


if __name__ == "__main__":
    build_pptx()
    build_html()
    export_pdf()
    sync_copies()
    print("Presentation build process fully finished!")
