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
        if not _local_permitido(c):
            return {"ok": False}
        return {"ok": True, "itens": listar(c)}
    res = {}
    for nome in PASTAS:
        c = pasta_real(nome)
        os.makedirs(c, exist_ok=True)
        res[nome] = {"caminho": c, "itens": listar(c)}
    return {"ok": True, "pastas": res}


APPS_REAIS = {
    "portico": ["atrium-navegador"],
    "loja": ["atrium-loja"],
    "writer": ["libreoffice", "--writer"],
    "calc": ["libreoffice", "--calc"],
    "impress": ["libreoffice", "--impress"],
    "draw": ["libreoffice", "--draw"],
    "terminal": ["foot"],
    "android": ["atrium-android"],
}


def abrir(d):
    app = str(d.get("app", ""))
    arq = str(d.get("arquivo", ""))
    if arq:
        if not _local_permitido(arq) or not os.path.exists(arq):
            return {"ok": False, "erro": "arquivo fora da sua pasta"}
        ext = arq.rsplit(".", 1)[-1].lower()
        if ext in ("exe", "msi"):
            return {"ok": run(["atrium-windows", arq])}
        if ext == "apk":
            return {"ok": run(["atrium-android", arq])}
        if ext in ("html", "htm", "pdf", "png", "jpg", "jpeg", "gif", "webp", "svg", "txt", "mp4", "webm", "mp3", "ogg"):
            return {"ok": run(["xdg-open", arq])}
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


# ---------- teclado e região ----------
import re
KB_OK = re.compile(r"^[a-z]{2,6}$")
VAR_OK = re.compile(r"^[a-z0-9_]{0,16}$")
CFG = os.path.join(HOME, ".config", "atriumos")


def _ler_teclado():
    l, v = "", ""
    for f in ("/etc/default/keyboard", os.path.join(CFG, "teclado")):
        try:
            for linha in open(f):
                k, _, val = linha.strip().partition("=")
                val = val.strip().strip('"')
                if k == "XKBLAYOUT":
                    l = val.split(",")[0]
                elif k == "XKBVARIANT":
                    v = val.split(",")[0]
        except OSError:
            pass
    return l, v


def teclado_estado(_):
    l, v = _ler_teclado()
    tz = ""
    try:
        tz = os.path.realpath("/etc/localtime").split("zoneinfo/", 1)[1]
    except (IndexError, OSError):
        pass
    return {"ok": True, "layout": l, "variante": v, "tz": tz}


def teclado(d):
    l, v = str(d.get("layout", "")), str(d.get("variante", ""))
    if not KB_OK.match(l) or not VAR_OK.match(v):
        return {"ok": False}
    if DRY:
        print("[teste] teclado", l, v, flush=True)
        return {"ok": True}
    os.makedirs(CFG, exist_ok=True)
    with open(os.path.join(CFG, "teclado"), "w") as f:
        f.write(f'XKBLAYOUT="{l}"\nXKBVARIANT="{v}"\n')
    env = os.path.join(HOME, ".config", "labwc", "environment")
    linhas = []
    try:
        linhas = [x for x in open(env).read().splitlines() if not x.startswith("XKB_DEFAULT_")]
    except OSError:
        pass
    linhas += [f"XKB_DEFAULT_LAYOUT={l}"] + ([f"XKB_DEFAULT_VARIANT={v}"] if v else [])
    os.makedirs(os.path.dirname(env), exist_ok=True)
    with open(env, "w") as f:
        f.write("\n".join(linhas) + "\n")
    sh(["labwc", "--reconfigure"])
    # também para o sistema (terminal de texto, instalador), quando houver permissão
    sh(["sudo", "-n", "/usr/lib/atriumos/teclado-sistema", l, v])
    return {"ok": True}


def regiao(d):
    tz = str(d.get("tz", ""))
    if not re.match(r"^[A-Za-z_]+(/[A-Za-z0-9_+\-]+){0,2}$", tz) or not os.path.exists("/usr/share/zoneinfo/" + tz):
        return {"ok": False}
    ok, _ = sh(["timedatectl", "set-timezone", tz])
    return {"ok": ok}


# ======================================================================
# Rede, compartilhamento, acesso remoto, Home Assistant e cópia de segurança
# ======================================================================
import shutil
import threading
import time
import urllib.request
import urllib.error

UID = os.getuid()
GVFS = f"/run/user/{UID}/gvfs"
MEDIA = f"/media/{os.environ.get('USER', '')}"
RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"


def _local_permitido(p):
    p = os.path.realpath(p)
    if dentro_de_casa(p):
        return True
    for base in (GVFS, MEDIA, "/media", "/run/media"):
        if base and (p == base or p.startswith(base.rstrip("/") + os.sep)):
            return True
    return False


# ---------- rede ----------
def rede_info(_):
    ok, out = sh(["ip", "-4", "-o", "addr", "show", "scope", "global"])
    ips = []
    for linha in out.splitlines():
        partes = linha.split()
        if len(partes) > 3 and not partes[1].startswith(("lxc", "waydroid", "docker", "virbr", "veth", "br-")):
            ips.append({"interface": partes[1], "ip": partes[3].split("/")[0]})
    _, rota = sh(["ip", "-4", "route", "show", "default"])
    gw = rota.split()[2] if rota.startswith("default via") else ""
    _, devs = sh(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"])
    conexoes = []
    for linha in devs.splitlines():
        p = nm_split(linha)
        if len(p) >= 4 and p[1] in ("ethernet", "wifi") and p[2].startswith("connected"):
            conexoes.append({"interface": p[0], "tipo": "cabo" if p[1] == "ethernet" else "wifi", "nome": p[3]})
    _, host = sh(["hostname"])
    _, mac = sh(["cat", f"/sys/class/net/{ips[0]['interface']}/address"]) if ips else (0, "")
    _, virt = sh(["systemd-detect-virt"])
    return {"ok": True, "ips": ips, "gateway": gw, "conexoes": conexoes, "host": host.strip(),
            "mac": mac.strip(), "virtual": virt.strip() if virt.strip() != "none" else ""}


def rede_descobrir(_):
    """Procura de verdade na rede local (mDNS/Bonjour): pastas SMB, SFTP, impressoras."""
    if not shutil.which("avahi-browse"):
        return {"ok": False, "erro": "sem avahi"}
    tipos = {"_smb._tcp": "smb", "_sftp-ssh._tcp": "sftp", "_ipp._tcp": "impressora",
             "_ipps._tcp": "impressora", "_webdavs._tcp": "davs", "_home-assistant._tcp": "ha",
             "_device-info._tcp": None}
    achados = {}
    meus = [i["ip"] for i in rede_info(None)["ips"]]
    for t, kind in tipos.items():
        if kind is None:
            continue
        _, out = sh(["avahi-browse", "-tprk", t], timeout=8)
        for linha in out.splitlines():
            if not linha.startswith("="):
                continue
            p = linha.split(";")
            if len(p) < 9 or p[2] != "IPv4" or p[7].startswith("127."):
                continue
            nome = p[3].replace("\\032", " ").replace("\\046", "&")
            chave = (p[7], kind)
            if chave in achados:
                continue
            achados[chave] = {"nome": nome, "host": p[6], "ip": p[7], "porta": p[8], "tipo": kind,
                              "local": p[7] in meus or p[6].split(".")[0] == os.uname().nodename}
    return {"ok": True, "dispositivos": [d for d in achados.values() if not d["local"]]}


def _pastas_smb(host, usuario="", senha=""):
    if not shutil.which("smbclient"):
        return False, []
    cmd = ["smbclient", "-g", "-L", host]
    cmd += ["-U", f"{usuario}%{senha}"] if usuario else ["-N"]
    ok, out = sh(cmd, timeout=15)
    pastas = [l.split("|")[1] for l in out.splitlines() if l.startswith("Disk|") and not l.split("|")[1].endswith("$")]
    return bool(pastas) or ok, pastas


def _info_local(url):
    _, out = sh(["gio", "info", url], timeout=15)
    for linha in out.splitlines():
        if linha.strip().startswith("local path:"):
            return linha.split(":", 1)[1].strip()
    return ""


def rede_conectar(d):
    """Conecta de verdade: smb://, sftp://, ftp://, davs://, nfs://"""
    url = str(d.get("url", "")).strip()
    usuario, senha, dominio = str(d.get("usuario", "")), str(d.get("senha", "")), str(d.get("dominio", "")) or "WORKGROUP"
    m = re.match(r"^(smb|sftp|ftp|davs?|nfs)://([^/\s]+)/?([^\s]*)$", url, re.I)
    if not m:
        return {"ok": False, "erro": "Endereço inválido. Exemplo: smb://192.168.1.20/Filmes"}
    proto, host, resto = m.group(1).lower(), m.group(2), m.group(3)
    if proto == "smb" and not resto:
        ok, pastas = _pastas_smb(host, usuario, senha)
        if not pastas:
            return {"ok": False, "precisaSenha": not usuario, "erro": "Não encontrei pastas compartilhadas nesse endereço (ou o usuário/senha não confere)."}
        return {"ok": True, "pastas": pastas}
    if DRY:
        return {"ok": True, "caminho": "/tmp"}
    if usuario or senha:
        entrada = f"{usuario}\n{dominio}\n{senha}\n" if proto == "smb" else f"{usuario}\n{senha}\n"
        args = ["gio", "mount", url]
    else:
        entrada = "\n\n\n"
        args = ["gio", "mount", "-a", url] if proto == "smb" else ["gio", "mount", url]
    try:
        r = subprocess.run(args, input=entrada, capture_output=True, text=True, timeout=40)
        saida = (r.stdout or "") + (r.stderr or "")
    except (OSError, subprocess.TimeoutExpired) as e:
        return {"ok": False, "erro": str(e)}
    caminho = _info_local(url)
    if not caminho or not os.path.isdir(caminho):
        precisa = "denied" in saida.lower() or "password" in saida.lower() or "senha" in saida.lower() or not usuario
        return {"ok": False, "precisaSenha": precisa, "erro": "Não foi possível conectar. " + (saida.strip().splitlines() or [""])[-1][:160]}
    return {"ok": True, "caminho": caminho, "itens": listar(caminho)}


def rede_desconectar(d):
    url = str(d.get("url", ""))
    ok, _ = sh(["gio", "mount", "-u", url])
    return {"ok": ok}


def rede_compartilhar(d):
    """Compartilha a pasta Público (só leitura) com Windows, Mac e Linux da rede."""
    ligar = bool(d.get("ligar"))
    pub = os.path.join(HOME, "Público")
    ok_x, out = sh(["xdg-user-dir", "PUBLICSHARE"])
    if ok_x and out.strip() and out.strip() != HOME:
        pub = out.strip()
    if not shutil.which("net"):
        return {"ok": False, "erro": "Compartilhamento não instalado"}
    if ligar:
        os.makedirs(pub, exist_ok=True)
        ok, out = sh(["net", "usershare", "add", "Publico", pub, "Pasta pública do AtriumOS", "Everyone:R", "guest_ok=y"])
    else:
        ok, out = sh(["net", "usershare", "delete", "Publico"])
    return {"ok": ok, "pasta": pub, "erro": out.strip()[-200:] if not ok else ""}


def rede_compartilhar_estado(_):
    ok, out = sh(["net", "usershare", "list"]) if shutil.which("net") else (False, "")
    return {"ok": True, "ligado": "Publico" in out.split(), "disponivel": bool(shutil.which("net"))}


# ---------- acesso remoto (VNC com wayvnc) ----------
REMOTO_CFG = os.path.join(CFG, "remoto.json")
WAYVNC_DIR = os.path.join(HOME, ".config", "wayvnc")
_vnc = {"proc": None}


def _remoto_ler():
    try:
        return json.load(open(REMOTO_CFG))
    except (OSError, ValueError):
        return {}


def _senha_nova():
    import secrets
    a = "abcdefghjkmnpqrstuvwxyz23456789"
    return "".join(secrets.choice(a) for _ in range(8))


def _vnc_rodando():
    p = _vnc["proc"]
    if p and p.poll() is None:
        return True
    ok, _ = sh(["pgrep", "-u", str(UID), "-x", "wayvnc"])
    return ok


def _vnc_iniciar(cfg):
    os.makedirs(WAYVNC_DIR, exist_ok=True)
    chave = os.path.join(WAYVNC_DIR, "rsa_key.pem")
    tls_k, tls_c = os.path.join(WAYVNC_DIR, "tls_key.pem"), os.path.join(WAYVNC_DIR, "tls_cert.pem")
    if not os.path.exists(chave):
        sh(["openssl", "genrsa", "-traditional", "-out", chave, "4096"], timeout=60)
    if not os.path.exists(tls_c):
        sh(["openssl", "req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:secp384r1", "-sha384",
            "-days", "3650", "-nodes", "-keyout", tls_k, "-out", tls_c, "-subj", "/CN=AtriumOS"], timeout=60)
    with open(os.path.join(WAYVNC_DIR, "config"), "w") as f:
        f.write(f"address=0.0.0.0\nport=5900\nenable_auth=true\nusername=atrium\npassword={cfg['senha']}\n"
                f"rsa_private_key_file={chave}\nprivate_key_file={tls_k}\ncertificate_file={tls_c}\n"
                "relax_encryption=true\n")
    os.chmod(os.path.join(WAYVNC_DIR, "config"), 0o600)
    sh(["pkill", "-u", str(UID), "-x", "wayvnc"])
    time.sleep(0.5)
    try:
        log = open(os.path.join(HOME, ".local", "state", "atriumos", "remoto.log"), "a")
    except OSError:
        log = subprocess.DEVNULL
    _vnc["proc"] = subprocess.Popen(["wayvnc", "-C", os.path.join(WAYVNC_DIR, "config")],
                                    stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True)
    time.sleep(1.5)
    return _vnc_rodando()


def remoto_estado(_):
    cfg = _remoto_ler()
    clientes = []
    if _vnc_rodando() and shutil.which("wayvncctl"):
        _, out = sh(["wayvncctl", "--json", "client-list"])
        try:
            for c in json.loads(out or "[]"):
                clientes.append({"id": c.get("id"), "endereco": c.get("address") or "", "usuario": c.get("username") or ""})
        except ValueError:
            pass
    return {"ok": True, "instalado": bool(shutil.which("wayvnc")), "ligado": _vnc_rodando(),
            "senha": cfg.get("senha", ""), "ips": [i["ip"] for i in rede_info(None)["ips"]], "porta": 5900,
            "clientes": clientes}


def remoto(d):
    cfg = _remoto_ler()
    if d.get("novaSenha") or not cfg.get("senha"):
        cfg["senha"] = _senha_nova()
    if "ligar" in d:
        cfg["ligado"] = bool(d["ligar"])
    os.makedirs(CFG, exist_ok=True)
    with open(REMOTO_CFG, "w") as f:
        json.dump(cfg, f)
    os.chmod(REMOTO_CFG, 0o600)
    if not shutil.which("wayvnc"):
        return {"ok": False, "erro": "wayvnc não instalado"}
    if cfg.get("ligado"):
        ok = _vnc_iniciar(cfg)
    else:
        sh(["pkill", "-u", str(UID), "-x", "wayvnc"])
        ok = True
    r = remoto_estado(None)
    r["ok"] = ok
    return r


def remoto_desconectar(d):
    ok, _ = sh(["wayvncctl", "client-disconnect", str(d.get("id", ""))])
    return {"ok": ok}


def remoto_autoiniciar():
    cfg = _remoto_ler()
    if cfg.get("ligado") and cfg.get("senha") and shutil.which("wayvnc") and os.environ.get("WAYLAND_DISPLAY"):
        threading.Thread(target=_vnc_iniciar, args=(cfg,), daemon=True).start()


# ---------- Home Assistant ----------
HA_CFG = os.path.join(CFG, "homeassistant.json")


def _ha_ler():
    try:
        return json.load(open(HA_CFG))
    except (OSError, ValueError):
        return {}


def _ha_gravar(cfg):
    os.makedirs(CFG, exist_ok=True)
    with open(HA_CFG, "w") as f:
        json.dump(cfg, f)
    os.chmod(HA_CFG, 0o600)


def _ha_pedido(cfg, caminho, dados=None, timeout=8):
    url = cfg["url"].rstrip("/") + caminho
    req = urllib.request.Request(url, data=json.dumps(dados).encode() if dados is not None else None,
                                 headers={"Authorization": "Bearer " + cfg["token"], "Content-Type": "application/json"},
                                 method="POST" if dados is not None else "GET")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read() or b"null")


def ha(d):
    acao = str(d.get("acao", "estado"))
    cfg = _ha_ler()
    if acao == "conectar":
        url = str(d.get("url", "")).strip().rstrip("/")
        if url and not re.match(r"^https?://", url):
            url = "http://" + url
        if re.match(r"^https?://[^/:]+$", url) and ":" not in url.split("//", 1)[1]:
            url += ":8123"
        cfg = {**cfg, "url": url, "token": str(d.get("token", "")).strip() or cfg.get("token", "")}
        try:
            info = _ha_pedido(cfg, "/api/config")
        except urllib.error.HTTPError as e:
            return {"ok": False, "erro": "Token recusado pelo Home Assistant (código %s). Crie um token de longa duração no seu perfil." % e.code if e.code == 401 else "O Home Assistant respondeu com erro %s." % e.code}
        except (urllib.error.URLError, OSError, ValueError) as e:
            return {"ok": False, "erro": "Não foi possível chegar a %s (%s)." % (url, getattr(e, "reason", e))}
        cfg["nome"] = info.get("location_name", "Home Assistant")
        cfg["versao"] = info.get("version", "")
        _ha_gravar(cfg)
        return {"ok": True, "conectado": True, "nome": cfg["nome"], "versao": cfg["versao"], "url": url}
    if acao == "desconectar":
        _ha_gravar({"atalhos": cfg.get("atalhos", [])})
        return {"ok": True, "conectado": False}
    if not cfg.get("url") or not cfg.get("token"):
        return {"ok": True, "conectado": False, "atalhos": cfg.get("atalhos", [])}
    if acao == "estado":
        try:
            estados = _ha_pedido(cfg, "/api/states")
        except (urllib.error.URLError, OSError, ValueError) as e:
            return {"ok": True, "conectado": False, "url": cfg["url"], "erro": "Sem resposta de %s (%s)." % (cfg["url"], getattr(e, "reason", e)), "atalhos": cfg.get("atalhos", [])}
        ent = []
        for s in estados:
            eid = s.get("entity_id", "")
            dom = eid.split(".")[0]
            if dom in ("scene", "script", "light", "switch", "automation", "input_boolean", "fan", "cover", "media_player"):
                ent.append({"id": eid, "n": s.get("attributes", {}).get("friendly_name") or eid, "estado": s.get("state"), "dominio": dom})
        ent.sort(key=lambda e: (e["dominio"], e["n"].lower()))
        return {"ok": True, "conectado": True, "url": cfg["url"], "nome": cfg.get("nome", ""), "versao": cfg.get("versao", ""),
                "entidades": ent, "atalhos": cfg.get("atalhos", [])}
    if acao == "executar":
        eid = str(d.get("entidade", ""))
        dom = eid.split(".")[0]
        servico = {"scene": "turn_on", "script": "turn_on", "automation": "trigger"}.get(dom, "toggle")
        if dom == "media_player":
            servico = "media_play_pause"
        try:
            _ha_pedido(cfg, f"/api/services/{dom}/{servico}", {"entity_id": eid})
            return {"ok": True}
        except (urllib.error.URLError, OSError, ValueError) as e:
            return {"ok": False, "erro": str(getattr(e, "reason", e))}
    if acao == "atalhos":
        atalhos = [a for a in d.get("atalhos", []) if isinstance(a, dict) and re.match(r"^[A-Za-z0-9\-]+$", str(a.get("tecla", ""))) and re.match(r"^[a-z_]+\.[a-z0-9_]+$", str(a.get("entidade", "")))]
        cfg["atalhos"] = atalhos
        _ha_gravar(cfg)
        _ha_atalhos_labwc(atalhos)
        return {"ok": True, "atalhos": atalhos}
    return {"ok": False}


def _ha_atalhos_labwc(atalhos):
    xml = "".join(f'<keybind key="{a["tecla"]}"><action name="Execute" command="atrium-ha {a["entidade"]}"/></keybind>' for a in atalhos)
    with open(os.path.join(CFG, "atalhos.xml"), "w") as f:
        f.write(xml)
    rc = os.path.join(HOME, ".config", "labwc", "rc.xml")
    try:
        txt = open(rc).read()
        txt = re.sub(r"<!--ATALHOS-->.*?<!--/ATALHOS-->", "<!--ATALHOS-->" + xml + "<!--/ATALHOS-->", txt, flags=re.S)
        open(rc, "w").write(txt)
        sh(["labwc", "--reconfigure"])
    except OSError:
        pass


# ---------- cópia de segurança (pen drive, HD externo ou pasta da rede) ----------
BK_ESTADO = {"rodando": False, "feito": 0, "total": 0, "arquivo": "", "erro": "", "fim": False}
BK_PASTAS = {"Documentos": "DOCUMENTS", "Imagens": "PICTURES", "Música": "MUSIC", "Vídeos": "VIDEOS", "Downloads": "DOWNLOAD", "Mesa": "DESKTOP"}


def _tam(p):
    ok, out = sh(["du", "-sb", p], timeout=120)
    try:
        return int(out.split()[0]) if ok else 0
    except (ValueError, IndexError):
        return 0


def backup_info(_):
    ok, out = sh(["lsblk", "-J", "-b", "-o", "NAME,PATH,SIZE,TYPE,TRAN,RM,HOTPLUG,MODEL,LABEL,MOUNTPOINT,FSTYPE,FSAVAIL"])
    destinos = []
    try:
        discos = json.loads(out)["blockdevices"]
    except (ValueError, KeyError):
        discos = []
    _, raiz = sh(["findmnt", "-n", "-o", "SOURCE", "/"])
    for disco in discos:
        externo = disco.get("rm") or disco.get("hotplug") or disco.get("tran") == "usb"
        if disco.get("type") != "disk" or not externo:
            continue
        for p in (disco.get("children") or [disco]):
            if not p.get("fstype") or p.get("fstype") in ("swap", "iso9660", "squashfs") or p.get("path") in raiz:
                continue
            destinos.append({"id": p["path"], "n": (p.get("label") or disco.get("model") or p["name"]).strip(),
                             "modelo": (disco.get("model") or "").strip(), "tamanho": int(p.get("size") or 0),
                             "livre": int(p["fsavail"]) if p.get("fsavail") else None, "montado": p.get("mountpoint") or "",
                             "fs": p.get("fstype"), "tipo": "usb"})
    if os.path.isdir(GVFS):
        for e in os.listdir(GVFS):
            destinos.append({"id": os.path.join(GVFS, e), "n": e.split("share=")[-1].split(",")[0] + " (rede)", "tipo": "rede", "montado": os.path.join(GVFS, e)})
    tamanhos = {}
    for nome, chave in BK_PASTAS.items():
        ok2, p = sh(["xdg-user-dir", chave])
        p = p.strip()
        if ok2 and p and p != HOME and os.path.isdir(p):
            tamanhos[nome] = _tam(p)
    tamanhos["Ajustes e apps"] = _tam(os.path.join(HOME, ".config")) + _tam(os.path.join(HOME, ".local", "share"))
    copias = []
    for dest in destinos:
        m = dest.get("montado")
        if m and os.path.isdir(os.path.join(m, "AtriumOS-Backups")):
            for f in sorted(os.listdir(os.path.join(m, "AtriumOS-Backups")), reverse=True):
                if f.endswith(".tar.zst"):
                    copias.append({"arquivo": os.path.join(m, "AtriumOS-Backups", f), "n": f, "destino": dest["n"]})
    return {"ok": True, "destinos": destinos, "tamanhos": tamanhos, "copias": copias, "estado": BK_ESTADO}


def _montar(dev):
    if dev.startswith("/dev/"):
        _, out = sh(["lsblk", "-n", "-o", "MOUNTPOINT", dev])
        if out.strip():
            return out.strip().splitlines()[0]
        ok, out = sh(["udisksctl", "mount", "--no-user-interaction", "-b", dev], timeout=30)
        m = re.search(r" at (.+?)\.?$", out.strip())
        return m.group(1) if ok and m else ""
    return dev if _local_permitido(dev) and os.path.isdir(dev) else ""


def _backup_rodar(destino, pastas, total):
    import datetime
    BK_ESTADO.update(rodando=True, feito=0, total=total, erro="", fim=False)
    try:
        pasta_dest = os.path.join(destino, "AtriumOS-Backups")
        os.makedirs(pasta_dest, exist_ok=True)
        nome = f"{os.uname().nodename}-{datetime.datetime.now():%Y-%m-%d-%H%M}.tar.zst"
        arq = os.path.join(pasta_dest, nome)
        BK_ESTADO["arquivo"] = arq
        apps = os.path.join(CFG, "apps-instalados.txt")
        _, sel = sh(["dpkg-query", "-W", "-f", "${Package}\n"])
        with open(apps, "w") as f:
            f.write(sel)
        rel = [os.path.relpath(p, HOME) for p in pastas] + [os.path.relpath(apps, HOME)]
        p = subprocess.Popen(["tar", "--zstd", "-cf", arq, "--exclude=.cache", "--exclude=*/Cache*", "-C", HOME] + rel,
                             stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        while p.poll() is None:
            try:
                BK_ESTADO["feito"] = os.path.getsize(arq)
            except OSError:
                pass
            time.sleep(1)
        err = p.stderr.read() if p.stderr else ""
        if p.returncode not in (0, 1):
            BK_ESTADO["erro"] = (err.strip().splitlines() or ["falhou"])[-1][:200]
        BK_ESTADO["feito"] = os.path.getsize(arq) if os.path.exists(arq) else 0
        sh(["sync"], timeout=300)
    except OSError as e:
        BK_ESTADO["erro"] = str(e)
    BK_ESTADO.update(rodando=False, fim=True)


def backup_iniciar(d):
    if BK_ESTADO["rodando"]:
        return {"ok": False, "erro": "Já há uma cópia em andamento."}
    destino = _montar(str(d.get("destino", "")))
    if not destino:
        return {"ok": False, "erro": "Não foi possível abrir o disco escolhido."}
    pastas = []
    for nome in d.get("pastas", []):
        if nome == "Ajustes e apps":
            pastas += [p for p in (os.path.join(HOME, ".config"), os.path.join(HOME, ".local", "share")) if os.path.isdir(p)]
        elif nome in BK_PASTAS:
            ok, p = sh(["xdg-user-dir", BK_PASTAS[nome]])
            if ok and p.strip() and p.strip() != HOME and os.path.isdir(p.strip()):
                pastas.append(p.strip())
    if not pastas:
        return {"ok": False, "erro": "Escolha pelo menos uma pasta."}
    threading.Thread(target=_backup_rodar, args=(destino, pastas, int(d.get("total", 0))), daemon=True).start()
    return {"ok": True, "destino": destino}


def backup_estado(_):
    return {"ok": True, **BK_ESTADO}


def backup_restaurar(d):
    arq = str(d.get("arquivo", ""))
    if not arq.endswith(".tar.zst") or not os.path.isfile(arq) or not _local_permitido(arq):
        return {"ok": False}
    ok, out = sh(["tar", "--zstd", "-xf", arq, "-C", HOME, "--keep-newer-files"], timeout=3600)
    return {"ok": ok, "erro": out.strip()[-200:] if not ok else ""}


def ejetar(d):
    dev = str(d.get("id", ""))
    if not dev.startswith("/dev/"):
        return {"ok": False}
    sh(["udisksctl", "unmount", "--no-user-interaction", "-b", dev])
    ok, _ = sh(["udisksctl", "power-off", "--no-user-interaction", "-b", re.sub(r"p?\d+$", "", dev)])
    return {"ok": True}


# ---------- Windows: acompanhar a primeira abertura ----------
def windows_estado(_):
    try:
        with open(os.path.join(RUNTIME, "atrium-windows")) as f:
            return {"ok": True, "estado": f.read().strip()}
    except OSError:
        return {"ok": True, "estado": ""}


# ---------- informações reais do computador (Sobre e Monitor) ----------
_cpu_ant = [0, 0]


def _cpu_uso():
    try:
        v = [int(x) for x in open("/proc/stat").readline().split()[1:]]
    except (OSError, ValueError):
        return 0
    ocioso, total = v[3] + v[4], sum(v)
    d_t, d_o = total - _cpu_ant[0], ocioso - _cpu_ant[1]
    _cpu_ant[:] = [total, ocioso]
    return round(100 * (1 - d_o / d_t), 1) if d_t > 0 else 0


def sistema(d):
    mem = {}
    for linha in open("/proc/meminfo"):
        k, v = linha.split(":")
        mem[k] = int(v.split()[0]) * 1024
    modelo = ""
    for linha in open("/proc/cpuinfo"):
        if linha.startswith("model name"):
            modelo = linha.split(":", 1)[1].strip()
            break
    st = os.statvfs(HOME)
    os_rel = {}
    try:
        for linha in open("/etc/os-release"):
            k, _, v = linha.strip().partition("=")
            os_rel[k] = v.strip('"')
    except OSError:
        pass
    _, kernel = sh(["uname", "-r"])
    _, virt = sh(["systemd-detect-virt"])
    _, gpu = sh(["sh", "-c", "lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | cut -d: -f3-"])
    bat = None
    for b in ("BAT0", "BAT1"):
        p = f"/sys/class/power_supply/{b}"
        if os.path.isdir(p):
            try:
                bat = {"nivel": int(open(p + "/capacity").read()), "estado": open(p + "/status").read().strip()}
            except (OSError, ValueError):
                pass
    r = {"ok": True, "host": os.uname().nodename, "cpu": modelo, "nucleos": os.cpu_count(),
         "memTotal": mem.get("MemTotal", 0), "memUsada": mem.get("MemTotal", 0) - mem.get("MemAvailable", 0),
         "discoTotal": st.f_blocks * st.f_frsize, "discoLivre": st.f_bavail * st.f_frsize,
         "sistema": os_rel.get("PRETTY_NAME", "AtriumOS"), "versao": os_rel.get("VERSION_ID", ""),
         "kernel": kernel.strip(), "virtual": virt.strip() if virt.strip() != "none" else "",
         "video": gpu.strip(), "bateria": bat, "live": LIVE, "cpuUso": _cpu_uso(),
         "carga": os.getloadavg()[0]}
    if d.get("processos"):
        _, out = sh(["ps", "-eo", "pid,pcpu,rss,comm", "--sort=-pcpu", "--no-headers"])
        procs = []
        for linha in out.splitlines()[:25]:
            p = linha.split(None, 3)
            if len(p) == 4:
                procs.append({"pid": int(p[0]), "cpu": float(p[1]), "mem": int(p[2]) * 1024, "n": p[3]})
        r["processos"] = procs
    return r


def encerrar_processo(d):
    pid = int(d.get("pid", 0))
    if pid <= 1:
        return {"ok": False}
    try:
        if os.stat(f"/proc/{pid}").st_uid != UID:
            return {"ok": False, "erro": "Processo do sistema"}
        os.kill(pid, 15)
        return {"ok": True}
    except OSError as e:
        return {"ok": False, "erro": str(e)}


# ---------- músicas do usuário (tocadas pela própria interface) ----------
import secrets as _secrets
MIDIA_TOKEN = _secrets.token_urlsafe(16)
MUSICA_EXT = ("mp3", "ogg", "oga", "opus", "flac", "wav", "m4a", "aac", "webm")


def musicas(_):
    ok, p = sh(["xdg-user-dir", "MUSIC"])
    base = p.strip() if ok and p.strip() and p.strip() != HOME else os.path.join(HOME, "Música")
    faixas = []
    for raiz, _dirs, arqs in os.walk(base):
        for a in sorted(arqs):
            if a.rsplit(".", 1)[-1].lower() in MUSICA_EXT:
                c = os.path.join(raiz, a)
                faixas.append({"n": a.rsplit(".", 1)[0], "pasta": os.path.relpath(raiz, base), "caminho": c})
        if len(faixas) > 3000:
            break
    return {"ok": True, "pasta": base, "faixas": faixas, "token": MIDIA_TOKEN}


# ---------- conta, idioma e senha (configuração inicial e tela de bloqueio) ----------
LOCALES = {"pt_BR", "pt_PT", "en_US", "es_ES", "fr_FR", "de_DE", "it_IT"}


def conta(d):
    nome, host, senha = str(d.get("nome", ""))[:60], str(d.get("host", ""))[:40], str(d.get("senha", ""))
    if "\n" in senha or len(senha) < 4:
        return {"ok": False, "erro": "A senha precisa ter pelo menos 4 caracteres."}
    if DRY:
        return {"ok": True}
    try:
        r = subprocess.run(["sudo", "-n", "/usr/lib/atriumos/ajustes-sistema", "conta", nome, host],
                           input=senha + "\n", capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as e:
        return {"ok": False, "erro": str(e)}
    if r.returncode == 3:
        return {"ok": True, "jaConfigurado": True}
    return {"ok": r.returncode == 0, "erro": (r.stderr or "").strip()[-200:]}


def idioma(d):
    loc = str(d.get("locale", ""))
    if loc not in LOCALES:
        return {"ok": False}
    os.makedirs(CFG, exist_ok=True)
    env = os.path.join(HOME, ".config", "labwc", "environment")
    try:
        linhas = [x for x in open(env).read().splitlines() if not x.startswith(("LANG=", "LANGUAGE="))]
    except OSError:
        linhas = []
    linhas += [f"LANG={loc}.UTF-8", f"LANGUAGE={loc}:{loc.split('_')[0]}"]
    os.makedirs(os.path.dirname(env), exist_ok=True)
    with open(env, "w") as f:
        f.write("\n".join(linhas) + "\n")
    with open(os.path.join(CFG, "idioma"), "w") as f:
        f.write(loc)
    os.environ["LANG"] = loc + ".UTF-8"
    os.environ["LANGUAGE"] = f"{loc}:{loc.split('_')[0]}"
    sh(["sudo", "-n", "/usr/lib/atriumos/ajustes-sistema", "idioma", loc])
    return {"ok": True}


def verificar_senha(d):
    senha = str(d.get("senha", ""))
    usuario = os.environ.get("USER") or ""
    if DRY:
        return {"ok": True, "certa": True}
    try:
        r = subprocess.run(["/usr/sbin/unix_chkpwd", usuario, "nonull"], input=(senha + "\0").encode(),
                           capture_output=True, timeout=10)
        return {"ok": True, "certa": r.returncode == 0}
    except (OSError, subprocess.TimeoutExpired):
        return {"ok": False, "certa": False}


def conta_info(_):
    import pwd
    p = pwd.getpwuid(UID)
    return {"ok": True, "usuario": p.pw_name, "nome": p.pw_gecos.split(",")[0], "host": os.uname().nodename,
            "configurada": os.path.exists("/var/lib/atriumos/conta-configurada"), "live": LIVE}


# ======================================================================
# Rodada 3: janelas reais, servidor de rede via pty, drivers, Pasta Segura, loja, Chrome
# ======================================================================
import pty
import select
import signal


# ---------- janelas abertas (para a Dock e para trazer de volta janelas minimizadas) ----------
def janelas(_):
    if not shutil.which("wlrctl"):
        return {"ok": False, "janelas": []}
    ok, out = sh(["wlrctl", "toplevel", "list"])
    lista = []
    for linha in out.splitlines():
        app, _, titulo = linha.partition(":")
        app, titulo = app.strip(), titulo.strip()
        if not app or app.startswith("chrome-127.0.0.1") or "127.0.0.1" in titulo:
            continue
        lista.append({"app": app, "titulo": titulo})
    return {"ok": ok, "janelas": lista}


def focar(d):
    app = str(d.get("app", ""))
    if not re.match(r"^[\w.\-]+$", app):
        return {"ok": False}
    ok, _ = sh(["wlrctl", "toplevel", "focus", f"app_id:{app}"])
    return {"ok": ok}


# ---------- montar pastas da rede respondendo às perguntas do gio num terminal virtual ----------
def _gio_mount(url, usuario, senha, dominio):
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp("gio", ["gio", "mount", url])
    saida, enviados, fim = "", set(), time.time() + 45
    try:
        while time.time() < fim:
            r, _, _ = select.select([fd], [], [], 0.5)
            if r:
                try:
                    pedaco = os.read(fd, 4096).decode(errors="replace")
                except OSError:
                    break
                if not pedaco:
                    break
                saida += pedaco
                ult = saida.lower().rstrip()[-80:]
                for chave, valor in (("user", usuario), ("usuário", usuario), ("utilizador", usuario),
                                     ("domain", dominio), ("domínio", dominio),
                                     ("password", senha), ("senha", senha), ("palavra-passe", senha)):
                    if ult.endswith(":") and chave in ult.split("\n")[-1] and (chave, len(saida)) not in enviados:
                        enviados.add((chave, len(saida)))
                        os.write(fd, (valor + "\n").encode())
                        break
                if "anonymous" in ult.split("\n")[-1] and not usuario:
                    os.write(fd, b"1\n")
            wpid, status = os.waitpid(pid, os.WNOHANG)
            if wpid:
                return os.WEXITSTATUS(status) == 0, saida
        os.kill(pid, signal.SIGKILL)
        os.waitpid(pid, 0)
        return False, saida + "\n(tempo esgotado)"
    finally:
        os.close(fd)


def rede_conectar(d):  # substitui a versão anterior
    url = str(d.get("url", "")).strip()
    usuario, senha = str(d.get("usuario", "")), str(d.get("senha", ""))
    dominio = str(d.get("dominio", "")) or "WORKGROUP"
    m = re.match(r"^(smb|sftp|ftp|davs?|nfs)://([^/\s]+)/?([^\s]*)$", url, re.I)
    if not m:
        return {"ok": False, "erro": "Endereço inválido. Exemplo: smb://192.168.1.20/Filmes"}
    proto, host, resto = m.group(1).lower(), m.group(2), m.group(3)
    hostname = host.split("@")[-1].split(":")[0]
    # o computador responde?
    porta = {"smb": 445, "sftp": 22, "ftp": 21, "dav": 80, "davs": 443, "nfs": 2049}[proto]
    if ":" in host.split("@")[-1]:
        try:
            porta = int(host.split(":")[-1])
        except ValueError:
            pass
    import socket
    try:
        socket.create_connection((hostname, porta), timeout=5).close()
    except OSError:
        return {"ok": False, "erro": f"O computador {hostname} não respondeu na porta {porta}. Confira o endereço e se ele está ligado na mesma rede."}
    if proto == "smb" and not resto:
        ok, pastas = _pastas_smb(hostname, usuario, senha)
        if not pastas:
            return {"ok": False, "precisaSenha": True, "erro": "Usuário ou senha não conferem (ou o servidor não tem pastas compartilhadas)." if usuario else "Este servidor pede usuário e senha."}
        return {"ok": True, "pastas": pastas}
    caminho = _info_local(url)
    if caminho and os.path.isdir(caminho):
        return {"ok": True, "caminho": caminho, "itens": listar(caminho)}
    ok, saida = _gio_mount(url, usuario, senha, dominio)
    caminho = _info_local(url)
    if not caminho or not os.path.isdir(caminho):
        baixo = saida.lower()
        precisa = any(x in baixo for x in ("denied", "password", "senha", "palavra-passe", "authentication", "logon"))
        ultima = [l for l in saida.strip().splitlines() if l.strip() and ":" not in l[-2:]][-1:] or [""]
        return {"ok": False, "precisaSenha": precisa,
                "erro": ("Usuário ou senha não conferem." if precisa and usuario else "Não foi possível conectar. " + ultima[0][:160])}
    return {"ok": True, "caminho": caminho, "itens": listar(caminho)}


# ---------- drivers ----------
DRV_ESTADO = os.path.join(RUNTIME, "atrium-drivers")


def drivers_listar(_):
    pacotes = {}
    if shutil.which("isenkram-lookup"):
        _, out = sh(["isenkram-lookup"], timeout=90)
        for p in out.split():
            pacotes[p] = "Recomendado para o hardware deste computador"
    if shutil.which("nvidia-detect"):
        _, out = sh(["nvidia-detect"], timeout=60)
        for p in re.findall(r"\b(nvidia-(?:tesla-)?(?:\d+-)?driver|nvidia-open-kernel-dkms|nvidia-kernel-dkms)\b", out):
            pacotes[p] = "Placa de vídeo NVIDIA: driver oficial"
    _, cpu = sh(["sh", "-c", "grep -m1 vendor_id /proc/cpuinfo"])
    if "GenuineIntel" in cpu:
        pacotes.setdefault("intel-microcode", "Correções de segurança do processador Intel")
    if "AuthenticAMD" in cpu:
        pacotes.setdefault("amd64-microcode", "Correções de segurança do processador AMD")
    _, vga = sh(["sh", "-c", "lspci -nn 2>/dev/null | grep -iE 'vga|3d|display|network|wireless|audio'"])
    itens = []
    for p, motivo in sorted(pacotes.items()):
        ok, st = sh(["dpkg-query", "-W", "-f", "${Status}", p])
        itens.append({"pacote": p, "motivo": motivo, "instalado": ok and "install ok installed" in st})
    try:
        estado = open(DRV_ESTADO).read().strip()
    except OSError:
        estado = ""
    return {"ok": True, "pacotes": itens, "hardware": [l.split(": ", 1)[-1] for l in vga.splitlines()][:12], "estado": estado}


def drivers_instalar(d):
    pacotes = [str(p) for p in d.get("pacotes", []) if re.match(r"^[a-z0-9][a-z0-9.+\-]+$", str(p))]
    if not pacotes:
        return {"ok": False}
    with open(DRV_ESTADO, "w") as f:
        f.write("instalando")

    def rodar():
        try:
            r = subprocess.run(["sudo", "-n", "/usr/lib/atriumos/ajustes-sistema", "drivers"] + pacotes,
                               capture_output=True, text=True, timeout=3600)
            res = "pronto" if r.returncode == 0 else "erro:" + ((r.stderr or r.stdout).strip().splitlines() or [""])[-1][:200]
        except (OSError, subprocess.TimeoutExpired) as e:
            res = "erro:" + str(e)
        with open(DRV_ESTADO, "w") as f:
            f.write(res)
    threading.Thread(target=rodar, daemon=True).start()
    return {"ok": True}


# ---------- Pasta Segura (criptografada de verdade com gocryptfs) ----------
COFRE_DADOS = os.path.join(HOME, ".local", "share", "atriumos", "pasta-segura")
COFRE = os.path.join(HOME, "Pasta Segura")


def _cofre_aberto():
    ok, out = sh(["findmnt", "-n", COFRE])
    return ok and bool(out.strip())


def cofre_estado(_):
    return {"ok": True, "disponivel": bool(shutil.which("gocryptfs")),
            "criado": os.path.exists(os.path.join(COFRE_DADOS, "gocryptfs.conf")),
            "aberto": _cofre_aberto(), "caminho": COFRE}


def _com_senha(cmd, senha):
    import tempfile
    fd, nome = tempfile.mkstemp(dir=RUNTIME)
    try:
        os.write(fd, senha.encode())
        os.close(fd)
        return sh(cmd + ["-passfile", nome], timeout=60)
    finally:
        os.unlink(nome)


def cofre(d):
    acao, senha = str(d.get("acao", "")), str(d.get("senha", ""))
    if acao == "criar":
        if len(senha) < 6:
            return {"ok": False, "erro": "A senha precisa ter pelo menos 6 caracteres."}
        os.makedirs(COFRE_DADOS, exist_ok=True)
        ok, out = _com_senha(["gocryptfs", "-init", "-q"], senha) if not os.listdir(COFRE_DADOS) else (False, "já existe")
        if not ok:
            return {"ok": False, "erro": out.strip()[-200:]}
        acao = "abrir"
    if acao == "abrir":
        if _cofre_aberto():
            return {"ok": True, "aberto": True}
        os.makedirs(COFRE, exist_ok=True)
        ok, out = _com_senha(["gocryptfs", "-q", COFRE_DADOS, COFRE], senha)
        if not ok:
            return {"ok": False, "erro": "Senha incorreta." if "password" in out.lower() or "senha" in out.lower() else out.strip()[-200:]}
        return {"ok": True, "aberto": True, "itens": listar(COFRE)}
    if acao == "trancar":
        ok, out = sh(["fusermount3", "-u", COFRE]) if shutil.which("fusermount3") else sh(["fusermount", "-u", COFRE])
        return {"ok": ok or not _cofre_aberto(), "erro": "Feche os arquivos abertos da Pasta Segura e tente de novo." if not ok else ""}
    if acao == "mover":
        orig = str(d.get("caminho", ""))
        if not _cofre_aberto():
            return {"ok": False, "erro": "Abra a Pasta Segura primeiro."}
        if not dentro_de_casa(orig) or not os.path.exists(orig) or os.path.realpath(orig).startswith(COFRE):
            return {"ok": False}
        destino = os.path.join(COFRE, os.path.basename(orig))
        if os.path.exists(destino):
            return {"ok": False, "erro": "Já existe um item com esse nome na Pasta Segura."}
        shutil.move(orig, destino)
        return {"ok": True}
    return {"ok": False}


# ---------- loja (Bazaar, apps do Flathub) e Google Chrome ----------
LOJA_ID = "io.github.kolunmi.Bazaar"


def loja_estado(_):
    ok, _ = sh(["flatpak", "info", LOJA_ID])
    try:
        est = open(os.path.join(RUNTIME, "atrium-loja")).read().strip()
    except OSError:
        est = ""
    return {"ok": True, "instalada": ok, "estado": est}


def chrome(d):
    if d.get("acao") == "estado":
        try:
            est = open(os.path.join(RUNTIME, "atrium-chrome")).read().strip()
        except OSError:
            est = ""
        return {"ok": True, "instalado": bool(shutil.which("google-chrome")), "estado": est}
    if shutil.which("google-chrome"):
        return {"ok": run(["google-chrome"])}
    with open(os.path.join(RUNTIME, "atrium-chrome"), "w") as f:
        f.write("instalando")

    def rodar():
        r = subprocess.run(["sudo", "-n", "/usr/lib/atriumos/ajustes-sistema", "chrome"], capture_output=True, text=True, timeout=1800)
        with open(os.path.join(RUNTIME, "atrium-chrome"), "w") as f:
            f.write("pronto" if r.returncode == 0 else "erro")
        if r.returncode == 0:
            run(["google-chrome"])
    threading.Thread(target=rodar, daemon=True).start()
    return {"ok": True, "instalando": True}


ACTIONS2 = {"wifi_listar": wifi_listar, "wifi_conectar": wifi_conectar, "wifi_ligar": wifi_ligar,
            "volume": volume, "arquivos": arquivos, "abrir": abrir, "android_estado": android_estado,
            "teclado": teclado, "teclado_estado": teclado_estado, "regiao": regiao,
            "rede_info": rede_info, "rede_descobrir": rede_descobrir, "rede_conectar": rede_conectar,
            "rede_desconectar": rede_desconectar, "rede_compartilhar": rede_compartilhar,
            "rede_compartilhar_estado": rede_compartilhar_estado, "remoto": remoto, "remoto_estado": remoto_estado,
            "remoto_desconectar": remoto_desconectar, "ha": ha, "backup_info": backup_info,
            "backup_iniciar": backup_iniciar, "backup_estado": backup_estado, "backup_restaurar": backup_restaurar,
            "ejetar": ejetar, "windows_estado": windows_estado,
            "sistema": sistema, "encerrar_processo": encerrar_processo, "musicas": musicas,
            "conta": conta, "idioma": idioma, "verificar_senha": verificar_senha, "conta_info": conta_info,
            "janelas": janelas, "focar": focar, "drivers_listar": drivers_listar, "drivers_instalar": drivers_instalar,
            "cofre_estado": cofre_estado, "cofre": cofre, "loja_estado": loja_estado, "chrome": chrome}


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

    def do_GET(self):
        # /midia?t=TOKEN&c=/caminho/musica.mp3 — só a interface conhece o token
        if self.path.startswith("/midia?"):
            from urllib.parse import parse_qs, urlsplit
            q = parse_qs(urlsplit(self.path).query)
            c = (q.get("c") or [""])[0]
            if (q.get("t") or [""])[0] != MIDIA_TOKEN or not _local_permitido(c) or not os.path.isfile(c) \
                    or c.rsplit(".", 1)[-1].lower() not in MUSICA_EXT:
                return self._json(403, {"ok": False})
            tam = os.path.getsize(c)
            ini, fim = 0, tam - 1
            rg = self.headers.get("Range", "")
            m = re.match(r"bytes=(\d*)-(\d*)", rg)
            if m:
                ini = int(m.group(1) or 0)
                fim = int(m.group(2)) if m.group(2) else tam - 1
            self.send_response(206 if m else 200)
            import mimetypes
            self.send_header("Content-Type", mimetypes.guess_type(c)[0] or "audio/mpeg")
            self.send_header("Accept-Ranges", "bytes")
            self.send_header("Content-Length", str(fim - ini + 1))
            if m:
                self.send_header("Content-Range", f"bytes {ini}-{fim}/{tam}")
            self.end_headers()
            try:
                with open(c, "rb") as f:
                    f.seek(ini)
                    resta = fim - ini + 1
                    while resta > 0:
                        bloco = f.read(min(65536, resta))
                        if not bloco:
                            break
                        self.wfile.write(bloco)
                        resta -= len(bloco)
            except (OSError, ConnectionError):
                pass
            return None
        return super().do_GET()

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
    remoto_autoiniciar()
    Server(("127.0.0.1", PORT), Handler).serve_forever()
