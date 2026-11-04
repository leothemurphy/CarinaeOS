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


# ---------- funções reais do sistema ----------
HOME = os.path.expanduser("~")


def sh(cmd, timeout=20):
    """Executa um comando e devolve (ok, saída)."""
    if DRY:
        print("[teste] executaria:", " ".join(cmd), flush=True)
        return True, ""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode == 0, (r.stdout or "") + (r.stderr or "")
    except (OSError, subprocess.TimeoutExpired) as e:
        return False, str(e)


def nm_split(line):
    """Divide uma linha do nmcli -t (com \\: escapado)."""
    out, cur, esc = [], "", False
    for ch in line:
        if esc:
            cur += ch
            esc = False
        elif ch == "\\":
            esc = True
        elif ch == ":":
            out.append(cur)
            cur = ""
        else:
            cur += ch
    out.append(cur)
    return out


def wifi_listar(_):
    ok, radio = sh(["nmcli", "-t", "radio", "wifi"])
    ligado = "enabled" in radio
    redes = {}
    if ligado:
        ok, out = sh(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "auto"])
        for line in out.splitlines():
            p = nm_split(line)
            if len(p) < 4 or not p[1]:
                continue
            ssid = p[1]
            sinal = int(p[2] or 0)
            r = {"ssid": ssid, "sinal": sinal, "seg": p[3] not in ("", "--"), "ativa": p[0] == "*"}
            if ssid not in redes or redes[ssid]["sinal"] < sinal or r["ativa"]:
                redes[ssid] = r
    ok, dev = sh(["nmcli", "-t", "-f", "TYPE,STATE", "dev"])
    cabo = any(l.startswith("ethernet:connected") for l in dev.splitlines())
    lista = sorted(redes.values(), key=lambda r: (not r["ativa"], -r["sinal"]))
    return {"ok": True, "ligado": ligado, "redes": lista, "cabo": cabo, "temWifi": "wifi" in dev}


def wifi_conectar(d):
    ssid = str(d.get("ssid", ""))[:64]
    senha = str(d.get("senha", ""))[:128]
    if not ssid:
        return {"ok": False, "erro": "rede vazia"}
    cmd = ["nmcli", "dev", "wifi", "connect", ssid]
    if senha:
        cmd += ["password", senha]
    ok, out = sh(cmd, timeout=45)
    return {"ok": ok, "erro": "" if ok else out.strip().splitlines()[-1][:160] if out.strip() else "falhou"}


def wifi_ligar(d):
    ok, _ = sh(["nmcli", "radio", "wifi", "on" if d.get("ligar") else "off"])
    return {"ok": ok}


def volume(d):
    v = max(0.0, min(1.0, float(d.get("v", 0.5))))
    ok, _ = sh(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", f"{v:.2f}"])
    return {"ok": ok}


PASTAS = {"Mesa": "DESKTOP", "Documentos": "DOCUMENTS", "Downloads": "DOWNLOAD",
          "Imagens": "PICTURES", "Música": "MUSIC", "Vídeos": "VIDEOS"}
TIPOS = {"doc": "txt md odt docx doc rtf", "sheet": "csv ods xlsx xls", "pdf": "pdf",
         "img": "png jpg jpeg gif webp svg bmp heic", "audio": "mp3 ogg flac wav m4a opus",
         "video": "mp4 mkv webm mov avi", "zip": "zip rar 7z tar gz xz", "exe": "exe msi",
         "apk": "apk", "disk": "iso img dmg"}


def tipo(nome, pasta):
    if pasta:
        return "folder"
    ext = nome.rsplit(".", 1)[-1].lower() if "." in nome else ""
    for k, exts in TIPOS.items():
        if ext in exts.split():
            return k
    return "file"


def pasta_real(nome):
    ok, out = sh(["xdg-user-dir", PASTAS[nome]])
    p = out.strip() if ok and out.strip() else ""
    return p if p and p != HOME else os.path.join(HOME, nome)


def dentro_de_casa(p):
    p = os.path.realpath(p)
    return p == HOME or p.startswith(HOME + os.sep)


def listar(caminho):
    itens = []
    try:
        with os.scandir(caminho) as it:
            for e in it:
                if e.name.startswith("."):
                    continue
                pasta = e.is_dir(follow_symlinks=True)
                itens.append({"n": e.name, "k": tipo(e.name, pasta), "caminho": e.path})
    except OSError:
        pass
    itens.sort(key=lambda i: (i["k"] != "folder", i["n"].lower()))
    return itens


def arquivos(d):
    if d.get("caminho"):
        c = str(d["caminho"])
        if not dentro_de_casa(c):
            return {"ok": False}
        return {"ok": True, "itens": listar(c)}
    res = {}
    for nome in PASTAS:
        c = pasta_real(nome)
        os.makedirs(c, exist_ok=True)
        res[nome] = {"caminho": c, "itens": listar(c)}
    return {"ok": True, "pastas": res}


APPS_REAIS = {
    "portico": ["/opt/portico/portico"],
    "terminal": ["foot"],
    "android": ["atrium-android"],
}


def abrir(d):
    app = str(d.get("app", ""))
    arq = str(d.get("arquivo", ""))
    if arq:
        if not dentro_de_casa(arq) or not os.path.exists(arq):
            return {"ok": False, "erro": "arquivo fora da sua pasta"}
        ext = arq.rsplit(".", 1)[-1].lower()
        if ext in ("exe", "msi"):
            return {"ok": run(["atrium-windows", arq])}
        if ext == "apk":
            return {"ok": run(["atrium-android", arq])}
        if ext in ("html", "htm", "pdf", "png", "jpg", "jpeg", "gif", "webp", "svg", "txt", "mp4", "webm", "mp3", "ogg"):
            return {"ok": run(APPS_REAIS["portico"] + [arq])}
        return {"ok": run(["xdg-open", arq])}
    cmd = APPS_REAIS.get(app)
    if not cmd:
        return {"ok": False}
    extra = [str(d["url"])] if app == "portico" and str(d.get("url", "")).startswith(("http://", "https://")) else []
    return {"ok": run(cmd + extra)}


def android_estado(_):
    try:
        with open(os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "atrium-android")) as f:
            return {"ok": True, "estado": f.read().strip()}
    except OSError:
        return {"ok": True, "estado": ""}


ACTIONS2 = {"wifi_listar": wifi_listar, "wifi_conectar": wifi_conectar, "wifi_ligar": wifi_ligar,
            "volume": volume, "arquivos": arquivos, "abrir": abrir, "android_estado": android_estado}


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
            # avisa o atrium-sessao que a interface carregou
            try:
                d = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
                with open(os.path.join(d, "atrium-interface-ok"), "w") as f:
                    f.write("ok")
            except OSError:
                pass
            return self._json(200, {"ok": True, "live": LIVE})
        if cmd in ACTIONS2:
            try:
                n = int(self.headers.get("Content-Length") or 0)
                dados = json.loads(self.rfile.read(n) or b"{}") if n else {}
            except (ValueError, OSError):
                dados = {}
            try:
                return self._json(200, ACTIONS2[cmd](dados if isinstance(dados, dict) else {}))
            except Exception as e:  # noqa: BLE001
                return self._json(200, {"ok": False, "erro": str(e)[:200]})
        fn = ACTIONS.get(cmd)
        if not fn:
            return self._json(404, {"ok": False})
        return self._json(200, {"ok": bool(fn())})


class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    Server(("127.0.0.1", PORT), Handler).serve_forever()
