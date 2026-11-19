#!/usr/bin/env python3
"""Serves invented Docker data on a Colima profile socket, so screenshots never show real projects.

Usage:  scripts/demo-engine.py            # listens on ~/.colima/demo/docker.sock
        COLIMA_PROFILE=demo open -n "build/Colima Control Panel.app"

Only the endpoints the app reads are implemented. The socket and its folder are removed on exit.
"""
import hashlib, json, os, random, signal, socketserver, struct, sys, threading, time
from http.server import BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

PROFILE = "demo"
ROOT = os.path.expanduser(f"~/.colima/{PROFILE}")
SOCKET = f"{ROOT}/docker.sock"
CPUS, MEMORY = 4, 8 * 1024 ** 3
NOW = time.time()


def ident(name): return hashlib.sha256(name.encode()).hexdigest()


def compose(project, service, directory): return {
    "com.docker.compose.project": project, "com.docker.compose.service": service,
    "com.docker.compose.project.working_dir": directory, "com.docker.compose.version": "2.29.7"}


# name, image, project, service, state, uptime/exit seconds, health, [(host, container)], memory MB, cpu share, env, exit code
SPEC = [
    ("shop-web-1", "acme/shop-web:2.4", "shop", "web", "running", 7400, "healthy", [(8080, 80)], 182, 0.04, ["NGINX_PORT=80"], 0),
    ("shop-api-1", "acme/shop-api:2.4", "shop", "api", "running", 7400, "healthy", [(3000, 3000), (5005, 5005)], 421, 0.18, ["DATABASE_URL=postgres://shop:shop-demo@db:5432/shop", "REDIS_URL=redis://cache:6379", "LOG_LEVEL=info", "API_TOKEN=demo-token-123"], 0),
    ("shop-db-1", "postgres:16", "shop", "db", "running", 7500, "healthy", [(5432, 5432)], 312, 0.07, ["POSTGRES_USER=shop", "POSTGRES_PASSWORD=shop-demo", "POSTGRES_DB=shop"], 0),
    ("shop-cache-1", "redis:7", "shop", "cache", "running", 7500, None, [(6379, 6379)], 28, 0.01, [], 0),
    ("shop-worker-1", "acme/shop-worker:2.4", "shop", "worker", "running", 5100, "unhealthy", [], 151, 0.12, ["QUEUE=default", "CONCURRENCY=4"], 0),
    ("blog-app-1", "ghost:5", "blog", "app", "running", 20400, "healthy", [(2368, 2368)], 236, 0.03, ["url=http://localhost:2368"], 0),
    ("blog-db-1", "mysql:8", "blog", "db", "running", 20400, None, [(3306, 3306)], 388, 0.05, ["MYSQL_ROOT_PASSWORD=blog-demo"], 0),
    ("blog-backup-1", "acme/backup:1.1", "blog", "backup", "exited", 18000, None, [], 0, 0, [], 0),
    ("mailpit", "axllent/mailpit:latest", None, None, "running", 86400, None, [(8025, 8025), (1025, 1025)], 36, 0.01, [], 0),
    ("old-migration", "acme/shop-api:2.3", None, None, "exited", 259200, None, [], 0, 0, [], 1),
]
IMAGES = [("acme/shop-web:2.4", 142), ("acme/shop-api:2.4", 612), ("acme/shop-worker:2.4", 598), ("acme/shop-api:2.3", 604), ("acme/backup:1.1", 88),
          ("postgres:16", 432), ("redis:7", 117), ("ghost:5", 541), ("mysql:8", 586), ("axllent/mailpit:latest", 24), ("node:22-alpine", 160)]
VOLUMES = [("shop_db_data", "shop", 1.4, 1), ("shop_redis_data", "shop", 0.01, 1), ("blog_mysql_data", "blog", 0.9, 1), ("blog_ghost_content", "blog", 0.3, 1),
           ("pgdata_old", None, 2.1, 0), ("scratch_1", None, 0.05, 0), ("scratch_2", None, 0.02, 0)]
NETWORKS = [("bridge", "bridge", "172.17.0.0/16"), ("host", "host", None), ("none", "null", None), ("shop_default", "bridge", "172.20.0.0/16"), ("blog_default", "bridge", "172.21.0.0/16")]
LEVELS = ["INF"] * 7 + ["WRN", "INF", "DBG", "INF", "ERR"]
MESSAGES = ["HTTP GET /api/products responded 200 in 12.4 ms", "HTTP POST /api/cart responded 201 in 31.8 ms", "Cache miss for key catalog:featured",
            "Slow query detected: SELECT * FROM orders WHERE status = 'open'", "Connected to database shop", "Worker picked up job send_receipt",
            "HTTP GET /healthz responded 200 in 0.4 ms", "Retrying payment webhook, attempt 2", "Flushed 48 metrics", "Payment provider timed out after 5000 ms"]
DIRECTORY = {"shop": "/Users/demo/code/shop", "blog": "/Users/demo/code/blog"}
counters, lock = {}, threading.Lock()


def containers():
    rows = []
    for name, image, project, service, state, age, health, ports, mem, cpu, env, code in SPEC:
        labels = compose(project, service, DIRECTORY[project]) if project else {}
        if state == "running":
            status = f"Up {age // 3600} hours" + (f" ({health})" if health else "")
        else:
            status = f"Exited ({code}) {age // 3600} hours ago"
        rows.append({"Id": ident(name), "Names": ["/" + name], "Image": image, "ImageID": "sha256:" + ident(image), "State": state, "Status": status,
                     "Created": int(NOW - age - 60), "Labels": labels,
                     "Ports": [{"PublicPort": h, "PrivatePort": c, "Type": "tcp"} for h, c in ports],
                     "Mounts": [], "NetworkSettings": {"Networks": {(f"{project}_default" if project else "bridge"): {}}}})
    return rows


def spec_for(cid): return next((s for s in SPEC if ident(s[0]) == cid), None)


def inspect(cid):
    name, image, project, service, state, age, health, ports, mem, cpu, env, code = spec_for(cid)
    started = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(NOW - age)) + ".123456789Z"
    network = f"{project}_default" if project else "bridge"
    return {"Id": cid, "Created": time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(NOW - age - 60)) + ".000000000Z", "Path": "/entrypoint.sh", "Args": ["serve", "--port", "80"],
            "RestartCount": 3 if health == "unhealthy" else 0,
            "Config": {"Image": image, "Env": ["PATH=/usr/local/bin:/usr/bin:/bin"] + env, "Tty": False, "Labels": compose(project, service, DIRECTORY[project]) if project else {}},
            "State": {"StartedAt": started, "Health": {"Status": health} if health else None, "ExitCode": code, "OOMKilled": False},
            "HostConfig": {"RestartPolicy": {"Name": "unless-stopped" if state == "running" else "no"},
                           **({"Memory": 768 * 1024 ** 2, "NanoCpus": 1_500_000_000} if service == "api" else {})},
            "Mounts": [{"Type": "volume", "Name": f"{project}_{service}_data", "Destination": "/data", "RW": True}] if service in ("db", "cache") else [],
            "NetworkSettings": {"Ports": {f"{c}/tcp": [{"HostPort": str(h)}] for h, c in ports}, "Networks": {network: {"IPAddress": "172.20.0." + str(2 + [s[0] for s in SPEC].index(name))}}}}


def stats(cid):
    spec = spec_for(cid)
    now = time.time()
    with lock:
        state = counters.setdefault(cid, {"t": now, "usage": 5_000_000_000, "system": 400_000_000_000})
        previous = dict(state)
        elapsed = max(now - state["t"], 0.05)
        load = max(0.003, spec[9] * (1 + 0.4 * random.uniform(-1, 1)))
        state["usage"] += int(elapsed * load * 1e9)
        state["system"] += int(elapsed * CPUS * 1e9)
        state["t"] = now
        current = dict(state)
    memory = int(spec[8] * 1024 ** 2 * (1 + 0.02 * random.uniform(-1, 1)))
    cpu = lambda s: {"cpu_usage": {"total_usage": s["usage"]}, "system_cpu_usage": s["system"], "online_cpus": CPUS}
    return {"cpu_stats": cpu(current), "precpu_stats": cpu(previous), "memory_stats": {"usage": memory, "limit": MEMORY, "stats": {"inactive_file": 0}}}


def df():
    sizes = {name: size for name, size in IMAGES}
    used = {}
    for s in SPEC: used[s[1]] = used.get(s[1], 0) + 1
    return {"Images": [{"Id": "sha256:" + ident(n), "RepoTags": [n], "Size": s * 1024 ** 2, "Created": int(NOW - 86400 * (3 + i)), "Containers": used.get(n, 0)} for i, (n, s) in enumerate(IMAGES)],
            "Volumes": [{"Name": n, "Labels": {"com.docker.compose.project": p} if p else {}, "UsageData": {"Size": int(g * 1024 ** 3), "RefCount": r}} for n, p, g, r in VOLUMES],
            "BuildCache": [{"Size": 380 * 1024 ** 2, "InUse": False}] * 6 + [{"Size": 90 * 1024 ** 2, "InUse": True}],
            "Containers": [{"State": s[4], "SizeRw": 12 * 1024 ** 2} for s in SPEC]}


def log_bytes(cid, count, start):
    out = b""
    for i in range(count):
        ts = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(start + i * 3)) + f".{random.randint(0, 999999999):09d}Z"
        level = LEVELS[(i * 7) % len(LEVELS)]
        text = f"{ts} [{time.strftime('%H:%M:%S', time.gmtime(start + i * 3))} {level}] {MESSAGES[(i * 3) % len(MESSAGES)]}\n".encode()
        out += struct.pack(">BxxxI", 2 if level == "ERR" else 1, len(text)) + text
    return out


class Server(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def address_string(self): return "unix"
    def log_message(self, *args): pass

    def reply(self, body, status=200, kind="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(data)

    def stream(self, producer):
        self.send_response(200)
        self.send_header("Content-Type", "application/vnd.docker.raw-stream")
        self.send_header("Transfer-Encoding", "chunked")
        self.send_header("Connection", "close")
        self.end_headers()
        try:
            for chunk in producer():
                self.wfile.write(f"{len(chunk):x}\r\n".encode() + chunk + b"\r\n")
                self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        url = urlparse(self.path)
        path = url.path
        if path == "/_ping": return self.reply(b"OK", kind="text/plain")
        if path == "/info": return self.reply({"NCPU": CPUS, "MemTotal": MEMORY, "ServerVersion": "28.0.4", "Name": "colima-demo"})
        if path == "/containers/json": return self.reply(containers())
        if path == "/system/df": return self.reply(df())
        if path == "/networks":
            return self.reply([{"Id": ident(n), "Name": n, "Driver": d, "Scope": "local", "Internal": False, "IPAM": {"Config": [{"Subnet": s}] if s else []}} for n, d, s in NETWORKS])
        if path.startswith("/networks/"):
            n = next((x for x in NETWORKS if ident(x[0]) == path.split("/")[2] or x[0] == path.split("/")[2]), NETWORKS[0])
            return self.reply({"Id": ident(n[0]), "Name": n[0], "Driver": n[1], "Scope": "local", "Created": "2026-11-01T10:00:00.000000000Z", "Internal": False, "EnableIPv6": False,
                               "IPAM": {"Config": [{"Subnet": n[2], "Gateway": n[2].replace("0/16", "1")}] if n[2] else []}, "Containers": {}})
        if path.startswith("/volumes/"):
            return self.reply({"Name": path.split("/")[2], "Driver": "local", "Scope": "local", "Mountpoint": "/var/lib/docker/volumes/" + path.split("/")[2] + "/_data", "CreatedAt": "2026-11-02T09:00:00Z", "Labels": {}})
        if path.startswith("/images/") and path.endswith("/json"):
            return self.reply({"Id": path.split("/")[2], "RepoTags": [], "RepoDigests": [], "Created": "2026-11-05T12:00:00.000000000Z", "Size": 0, "Architecture": "arm64", "Os": "linux",
                               "Config": {"Entrypoint": ["/entrypoint.sh"], "Cmd": ["serve"], "Env": ["PATH=/usr/local/bin"], "ExposedPorts": {"80/tcp": {}}}})
        parts = path.strip("/").split("/")
        if len(parts) == 3 and parts[0] == "containers" and spec_for(parts[1]):
            cid, action = parts[1], parts[2]
            if action == "json": return self.reply(inspect(cid))
            if action == "stats": return self.reply(stats(cid))
            if action == "logs":
                follow = parse_qs(url.query).get("follow", ["0"])[0] == "1"
                def produce():
                    yield log_bytes(cid, 60, time.time() - 180)
                    while follow:
                        time.sleep(3)
                        yield log_bytes(cid, 1, time.time())
                return self.stream(produce)
        if path == "/events":
            def idle():
                while True:
                    time.sleep(20)
                    yield b"\n"
            return self.stream(idle)
        self.reply({"message": "not found"}, status=404)

    def do_POST(self): self.reply({"message": "the demo engine is read-only"}, status=403)
    do_DELETE = do_POST


def main():
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    os.makedirs(ROOT, exist_ok=True)
    if os.path.exists(SOCKET): os.remove(SOCKET)
    server = Server(SOCKET, Handler)
    print(f"demo engine on {SOCKET}", flush=True)
    try:
        server.serve_forever()
    except (KeyboardInterrupt, SystemExit):
        pass
    finally:
        server.server_close()
        try:
            os.remove(SOCKET)
            os.rmdir(ROOT)
        except OSError:
            pass


if __name__ == "__main__":
    main()
