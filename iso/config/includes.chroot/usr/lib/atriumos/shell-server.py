#!/usr/bin/env python3
"""AtriumOS — serviço local da interface.

Serve a interface do AtriumOS (shell/index.html) em http://127.0.0.1:7777 e
recebe dela alguns pedidos do sistema: desligar, reiniciar, repouso e abrir o
instalador. Só aceita pedidos vindos da própria interface (mesma origem e
cabeçalho X-Atrium), para que sites abertos no navegador não consigam usá-lo.
"""
import http.server
import json
import os
import socketserver
import subprocess

ROOT = os.environ.get("ATRIUM_SHELL_DIR", "/usr/share/atriumos/shell")
PORT = 7777
ORIGIN = f"http://127.0.0.1:{PORT}"
LIVE = os.path.isdir("/run/live/medium") or os.environ.get("ATRIUM_LIVE") == "1"
DRY = os.environ.get("ATRIUM_DRY_RUN") == "1"   # para testes: não executa nada


def run(cmd):
    if DRY:
        print("[teste] executaria:", " ".join(cmd), flush=True)
        return True
    try:
        subprocess.Popen(cmd, stdin=subprocess.DEVNULL, start_new_session=True)
        return True
    except OSError:
        return False


ACTIONS = {
    "desligar": lambda: run(["systemctl", "poweroff"]),
    "reiniciar": lambda: run(["systemctl", "reboot"]),
    "repouso": lambda: run(["systemctl", "suspend"]),
    "instalar": lambda: LIVE and run(["sudo", "-E", "calamares"]),
}


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

    def log_message(self, *a):
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def _json(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(403)
        self.end_headers()

    def do_POST(self):
        if self.headers.get("X-Atrium") != "1" or self.headers.get("Origin") != ORIGIN:
            return self._json(403, {"ok": False})
        cmd = self.path.removeprefix("/api/")
        if cmd == "estado":
            return self._json(200, {"ok": True, "live": LIVE})
        fn = ACTIONS.get(cmd)
        if not fn:
            return self._json(404, {"ok": False})
        return self._json(200, {"ok": bool(fn())})


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    Server(("127.0.0.1", PORT), Handler).serve_forever()
