#!/usr/bin/python3
# CarinaeOS - Forçar o encerramento: a lista dos aplicativos abertos, para fechar à força o que
# travou (Ctrl+Shift+Esc, como no Windows; "Forçar encerramento" do macOS).
#   carinaeos-encerrar                      abre a janela
#   carinaeos-encerrar --pid N [--app ID]   encerra já esse aplicativo (usado pela Dock)
#
# Encerrar = pedir com SIGTERM ao processo e aos filhos; quem não sair em 3 s leva SIGKILL.
# Apps Flatpak anunciam o número de processo de dentro da caixa de areia: fecham-se com "flatpak kill".
# Se nada disso servir, corta-se a ligação da janela ao servidor gráfico (xkill).
import configparser
import glob
import json
import os
import re
import signal
import subprocess
import sys
import time

sys.path.insert(0, '/usr/share/carinaeos/comum')

AQUI = os.path.dirname(os.path.abspath(__file__))
EU = os.getuid()
IGNORAR = {'plasmashell', 'kwin_x11', 'kwin_wayland', 'xembedsniproxy', 'krunner', 'carinaeos-encerrar'}


def _cmd(args, timeout=5):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout
    except Exception:
        return ''


def _proc_uid(pid):
    try:
        return os.stat('/proc/%d' % pid).st_uid
    except OSError:
        return -1


def _comm(pid):
    try:
        with open('/proc/%d/comm' % pid) as f:
            return f.read().strip()
    except OSError:
        return ''


# ---- os aplicativos que estão abertos (janelas do X11) ---------------------------------------------
def _desktops():
    """{classe da janela (minúsculas): (nome, ícone, id do .desktop)} a partir dos atalhos instalados."""
    pastas = [os.path.expanduser('~/.local/share/applications'), '/usr/local/share/applications', '/usr/share/applications',
              os.path.expanduser('~/.local/share/flatpak/exports/share/applications'), '/var/lib/flatpak/exports/share/applications']
    m = {}
    for p in reversed(pastas):
        for f in glob.glob(os.path.join(p, '*.desktop')):
            cp = configparser.RawConfigParser(strict=False, interpolation=None)
            cp.optionxform = str
            try:
                cp.read(f, encoding='utf-8')
                d = cp['Desktop Entry']
            except Exception:
                continue
            ident = os.path.basename(f)[:-8]
            v = (d.get('Name', ident), d.get('Icon', ident), ident)
            m[ident.lower()] = v
            m.setdefault(ident.lower().rsplit('.', 1)[-1], v)      # org.kde.kcalc -> kcalc
            if d.get('StartupWMClass'):
                m[d['StartupWMClass'].lower()] = v
    return m


def _flatpaks():
    """{app id: pid real} das instâncias Flatpak que estão a correr."""
    r = {}
    for l in _cmd(['flatpak', 'ps', '--columns=application,pid']).splitlines():
        p = l.split()
        if len(p) >= 2 and p[1].isdigit():
            r.setdefault(p[0], int(p[1]))
    return r


def janelas():
    saida = _cmd(['xprop', '-root', '_NET_CLIENT_LIST'])
    ids = re.findall(r'0x[0-9a-f]+', saida)
    des = _desktops()
    fps = _flatpaks()
    apps = {}
    for w in ids:
        info = _cmd(['xprop', '-id', w, '_NET_WM_PID', 'WM_CLASS', '_NET_WM_NAME', '_NET_WM_WINDOW_TYPE', '_NET_WM_STATE'])
        if '_NET_WM_STATE_SKIP_TASKBAR' in info:
            continue
        tipo = re.search(r'_NET_WM_WINDOW_TYPE\(ATOM\) = (\S+)', info)
        if tipo and tipo.group(1).rstrip(',') not in ('_NET_WM_WINDOW_TYPE_NORMAL', '_NET_WM_WINDOW_TYPE_DIALOG'):
            continue
        pid = re.search(r'_NET_WM_PID\(CARDINAL\) = (\d+)', info)
        cls = re.search(r'WM_CLASS\(STRING\) = "([^"]*)", "([^"]*)"', info)
        tit = re.search(r'_NET_WM_NAME\(UTF8_STRING\) = "(.*)"', info)
        classe = (cls.group(2) if cls else '') or (cls.group(1) if cls else '')
        inst = cls.group(1) if cls else ''
        d = des.get(classe.lower()) or des.get(inst.lower())
        fp = next((a for a in fps if a.lower() in (classe.lower(), inst.lower(), (d[2] if d else '').lower())), '')
        pid = int(pid.group(1)) if pid else 0
        if fp:
            chave = 'flatpak:' + fp
        elif pid and _proc_uid(pid) == EU:
            chave = 'pid:%d' % pid
            if _comm(pid) in IGNORAR:
                continue
        else:
            chave = 'janela:' + classe
        a = apps.setdefault(chave, dict(chave=chave, nome=d[0] if d else (classe or (tit.group(1) if tit else '?')),
                                        icone=d[1] if d else (classe.lower() or 'application-x-executable'),
                                        app=d[2] if d else '', pid=pid, flatpak=fp, janelas=[], titulo=''))
        a['janelas'].append(w)
        if tit and not a['titulo']:
            a['titulo'] = tit.group(1)
    return sorted(apps.values(), key=lambda a: a['nome'].lower())


# ---- encerrar ----------------------------------------------------------------------------------------
def _filhos(pid):
    pais = {}
    for p in glob.glob('/proc/[0-9]*/stat'):
        try:
            with open(p) as f:
                s = f.read()
            q = int(p.split('/')[2])
            pais.setdefault(int(s.rsplit(')', 1)[1].split()[1]), []).append(q)
        except (OSError, ValueError, IndexError):
            pass
    todos, fila = [], [pid]
    while fila:
        x = fila.pop()
        todos.append(x)
        fila += pais.get(x, [])
    return todos


def _matar_arvore(pid):
    alvo = [p for p in _filhos(pid) if p > 1 and p != os.getpid() and _proc_uid(p) == EU and _comm(p) not in IGNORAR]
    if not alvo:
        return False
    for p in alvo:
        try:
            os.kill(p, signal.SIGTERM)
        except OSError:
            pass
    for _ in range(30):
        if not any(os.path.exists('/proc/%d' % p) for p in alvo):
            return True
        time.sleep(0.1)
    for p in alvo:
        try:
            os.kill(p, signal.SIGKILL)
        except OSError:
            pass
    return True


def encerrar(a):
    """a: um item de janelas() (ou o mínimo: pid / flatpak / janelas)."""
    if a.get('flatpak'):
        subprocess.run(['flatpak', 'kill', a['flatpak']], capture_output=True, timeout=20)
        return True
    if a.get('pid') and _proc_uid(a['pid']) == EU and _comm(a['pid']) not in IGNORAR:
        return _matar_arvore(a['pid'])
    for w in a.get('janelas', []):
        subprocess.run(['xkill', '-id', w], capture_output=True, timeout=5)
    return bool(a.get('janelas'))


def da_dock(pid, app):
    """A Dock passa o pid e o id do .desktop: procura o aplicativo certo na lista das janelas."""
    lista = janelas()
    app = (app or '').lower().replace('.desktop', '')
    a = next((x for x in lista if app and x['app'].lower() == app), None) or \
        next((x for x in lista if pid and x['pid'] == pid), None)
    if not a and pid and _proc_uid(pid) == EU:
        a = dict(nome=_comm(pid), pid=pid, janelas=[])
    if not a:
        return 1
    ok = encerrar(a)
    subprocess.run(['notify-send', '-a', 'CarinaeOS', '-i', 'process-stop',
                    ('%s foi encerrado' if ok else 'Não consegui encerrar %s') % a['nome']], capture_output=True)
    return 0 if ok else 1


if __name__ == '__main__':
    if '--pid' in sys.argv or '--app' in sys.argv:
        def arg(n):
            i = sys.argv.index(n) + 1 if n in sys.argv else 0
            return sys.argv[i] if 0 < i < len(sys.argv) and not sys.argv[i].startswith('--') else ''
        p = arg('--pid')
        sys.exit(da_dock(int(p) if p.isdigit() else 0, arg('--app')))
    if '--listar' in sys.argv:
        print(json.dumps(janelas(), ensure_ascii=False, indent=1))
        sys.exit(0)

    from base import iniciar
    from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot
    import threading

    class Encerrar(QObject):
        mudou = Signal()
        _chegou = Signal(object)

        def __init__(self):
            super().__init__()
            self._apps = []
            self._msg = ''
            self._chegou.connect(self._lista)
            self._t = QTimer(self)
            self._t.setInterval(3000)
            self._t.timeout.connect(self.atualizar)
            self._t.start()
            self.atualizar()

        apps = Property('QVariantList', lambda s: s._apps, notify=mudou)
        mensagem = Property(str, lambda s: s._msg, notify=mudou)

        def _lista(self, l):
            self._apps = l
            self.mudou.emit()

        @Slot()
        def atualizar(self):
            threading.Thread(target=lambda: self._chegou.emit(janelas()), daemon=True).start()

        @Slot(str)
        def encerrar(self, chave):
            a = next((x for x in self._apps if x['chave'] == chave), None)
            if not a:
                return
            self._msg = 'Encerrando %s…' % a['nome']
            self.mudou.emit()

            def t():
                ok = encerrar(a)
                self._msg = ('✓ %s foi encerrado.' if ok else 'Não consegui encerrar %s.') % a['nome']
                self._chegou.emit(janelas())
            threading.Thread(target=t, daemon=True).start()

    sys.exit(iniciar('carinaeos-encerrar', 'Forçar o encerramento', 'process-stop', os.path.join(AQUI, 'Main.qml'),
                     {'encerrar': Encerrar}))
