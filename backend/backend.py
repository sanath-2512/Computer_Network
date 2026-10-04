#!/usr/bin/env python3
"""
CN Project - Phase 1 backend server (Python standard library only, nothing to install).

Run on Mac 3 (Krishna):  python3 backend.py --id A --port 3001
Run on Mac 1 (Sanath):   python3 backend.py --id B --port 3002

Endpoints
  GET /             small HTML page saying which backend answered
  GET /api/status   JSON: {"backend": "A", "status": "ok", ...}
  GET /api/cached   cacheable JSON (Cache-Control: max-age=60 + ETag, answers 304)
HEAD works on every endpoint too, so `curl -I` works.
Every response carries the header  X-Backend: A  (or B).
"""
import argparse
import hashlib
import json
import socket
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

parser = argparse.ArgumentParser(description="CN project backend")
parser.add_argument("--id", required=True, help="backend identifier, e.g. A or B")
parser.add_argument("--port", type=int, required=True, help="TCP port, e.g. 3001")
parser.add_argument("--team", default="team1", help="team label shown in responses")
args = parser.parse_args()

BACKEND_ID = args.id
HOSTNAME = socket.gethostname()

# The cacheable resource has identical bytes on BOTH backends, so its ETag is
# identical too. That way a conditional request (If-None-Match) gets a 304 no
# matter which backend the load balancer sends it to.
CACHED_BODY = json.dumps(
    {
        "resource": "team-info",
        "team": args.team,
        "version": 1,
        "note": "Cacheable for 60 seconds. Revalidate with If-None-Match.",
    },
    indent=2,
).encode() + b"\n"
CACHED_ETAG = '"' + hashlib.sha256(CACHED_BODY).hexdigest()[:16] + '"'


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "CNBackend/1.0"

    def do_GET(self):
        self.route(send_body=True)

    def do_HEAD(self):  # `curl -I` sends HEAD: same headers, no body
        self.route(send_body=False)

    def route(self, send_body):
        path = self.path.split("?", 1)[0]

        if path == "/":
            self.reply(200, self.home_page(), "text/html; charset=utf-8",
                       {"Cache-Control": "no-store"}, send_body)

        elif path == "/api/status":
            body = json.dumps({
                "backend": BACKEND_ID,
                "status": "ok",
                "host": HOSTNAME,
                "port": args.port,
                "time": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            }).encode() + b"\n"
            # no-store: never cache, so every request really reaches a backend
            self.reply(200, body, "application/json",
                       {"Cache-Control": "no-store"}, send_body)

        elif path == "/api/cached":
            cache_headers = {"Cache-Control": "public, max-age=60", "ETag": CACHED_ETAG}
            if self.etag_matches():
                # client's copy is still valid -> 304, headers only, no body
                self.reply(304, b"", None, cache_headers, send_body)
            else:
                self.reply(200, CACHED_BODY, "application/json", cache_headers, send_body)

        else:
            body = json.dumps({"error": "not found", "path": path,
                               "backend": BACKEND_ID}).encode() + b"\n"
            self.reply(404, body, "application/json", {}, send_body)

    def etag_matches(self):
        header = self.headers.get("If-None-Match")
        if not header:
            return False
        tags = []
        for tag in header.split(","):
            tag = tag.strip()
            if tag.startswith("W/"):
                tag = tag[2:]
            tags.append(tag)
        return "*" in tags or CACHED_ETAG in tags

    def reply(self, code, body, content_type, headers, send_body):
        self.send_response(code)
        self.send_header("X-Backend", BACKEND_ID)
        for name, value in headers.items():
            self.send_header(name, value)
        if code != 304:
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if send_body and code != 304:
            self.wfile.write(body)

    def home_page(self):
        colour = "#1d4ed8" if BACKEND_ID == "A" else "#047857"
        return f"""<!doctype html>
<html><head><meta charset="utf-8"><title>Backend {BACKEND_ID}</title></head>
<body style="font-family:-apple-system,Helvetica,sans-serif;margin:48px">
  <h1 style="color:{colour}">Served by Backend {BACKEND_ID}</h1>
  <p>Host: {HOSTNAME} &middot; port {args.port} &middot; team {args.team}</p>
  <p>Refresh the page: the load balancer alternates between Backend A and Backend B.</p>
  <ul>
    <li><a href="/api/status">/api/status</a> (JSON, never cached)</li>
    <li><a href="/api/cached">/api/cached</a> (JSON, Cache-Control max-age=60 + ETag)</li>
  </ul>
</body></html>
""".encode()


if __name__ == "__main__":
    # 0.0.0.0 = listen on every interface (Wi-Fi included), NOT only 127.0.0.1,
    # so the edge machine (Mac 2) can reach this backend over the LAN.
    server = ThreadingHTTPServer(("0.0.0.0", args.port), Handler)
    print(f"Backend {BACKEND_ID} listening on 0.0.0.0:{args.port} (host {HOSTNAME}). Ctrl+C to stop.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print(f"\nBackend {BACKEND_ID} stopped.")
