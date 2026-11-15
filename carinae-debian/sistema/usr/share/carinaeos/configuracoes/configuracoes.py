#!/usr/bin/python3
# CarinaeOS - Configuracoes: as definicoes do computador num so sitio, ao estilo das
# Definicoes do Fedora: lista de seccoes a esquerda (com pesquisa), paginas simples a direita.
# O essencial faz-se aqui; "Mais opcoes" abre o modulo completo correspondente.
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import threading

sys.path.insert(0, '/usr/share/carinaeos/comum')
from base import correr, iniciar  # noqa: E402

from PySide6.QtCore import Property, QObject, Signal, Slot  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser('~')

# (id, nome, icone, modulo completo, palavras para a pesquisa)
SECCOES = [
    ('wifi', 'Wi-Fi', 'network-wireless', 'kcm_networkmanagement', 'internet rede sem fios'),
    ('rede', 'Rede', 'network-wired', 'kcm_networkmanagement', 'cabo ethernet vpn proxy'),
    ('bluetooth', 'Bluetooth', 'preferences-system-bluetooth', 'kcm_bluetooth', 'fones auscultadores rato'),
    ('ecras', 'Ecrãs', 'video-display', 'kcm_kscreen', 'monitor resolucao escala brilho luz noturna tela'),
    ('som', 'Som', 'audio-volume-high', 'kcm_pulseaudio', 'volume altifalantes microfone audio'),
    ('energia', 'Energia', 'battery-good', 'kcm_powerdevilprofilesconfig', 'bateria suspender desempenho poupanca'),
    ('aparencia', 'Aparência', 'preferences-desktop-theme', 'kcm_colors', 'tema claro escuro fundo papel de parede cores'),
    ('dock', 'Dock', 'preferences-desktop-icons', None, 'barra icones tamanho separador esconder posicao'),
    ('notificacoes', 'Notificações', 'preferences-desktop-notification', 'kcm_notifications', 'avisos nao incomodar'),
    ('pesquisa', 'Pesquisa', 'search', 'kcm_baloofile', 'indexacao arquivos procurar'),
    ('aplicativos', 'Aplicativos', 'preferences-desktop-default-applications', 'kcm_componentchooser', 'padrao navegador email abrir com'),
    ('privacidade', 'Privacidade e segurança', 'preferences-system-privacy', None, 'convidado bloqueio ecra senha'),
    ('partilha', 'Partilha', 'network-server', None, 'ssh acesso remoto pastas'),
    ('teclado', 'Teclado', 'preferences-desktop-keyboard', 'kcm_keyboard', 'atalhos idioma layout numlock'),
    ('rato', 'Rato e touchpad', 'input-mouse', 'kcm_mouse', 'touchpad cursor velocidade'),
    ('impressoras', 'Impressoras', 'printer', 'kcm_printer_manager', 'imprimir scanner'),
    ('contas', 'Contas online', 'preferences-online-accounts', 'kcm_kaccounts', 'google nextcloud calendario icloud outlook'),
    ('utilizadores', 'Utilizadores', 'system-users', 'kcm_users', 'conta senha foto'),
    ('regiao', 'Região e idioma', 'preferences-desktop-locale', 'kcm_regionandlang', 'lingua formato data moeda'),
    ('datahora', 'Data e hora', 'preferences-system-time', 'kcm_clock', 'relogio fuso horario'),
    ('acessibilidade', 'Acessibilidade', 'preferences-desktop-accessibility', 'kcm_access', 'lupa leitor contraste'),
    ('sistema', 'Sistema', 'carinaeos', None, 'sobre computador atualizacoes memoria processador nome'),
]


def cmd(args, timeout=8):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except Exception:
        return ''


def bg(args):
    try:
        subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except Exception:
        pass


def tamanho(n):
    for u in ('B', 'KB', 'MB', 'GB', 'TB'):
        if n < 1024 or u == 'TB':
            return ('%.0f %s' if u in ('B', 'KB', 'MB') else '%.1f %s') % (n, u)
        n /= 1024.0


SERVIDORES = os.path.join(HOME, '.config/carinaeos/servidores.json')


def servidores():
    try:
        with open(SERVIDORES) as f:
            return json.load(f)
    except (OSError, ValueError):
        return []


def normalizar_endereco(t):
    t = t.strip()
    if not t:
        return ''
    if re.match(r'^[a-z]+://', t):
        return t
    if t.startswith('\\\\'):                       # \\servidor\pasta (como no Windows)
        return 'smb://' + t.lstrip('\\').replace('\\', '/')
    return 'smb://' + t.lstrip('/')


def adicionar_local(url, nome):
    """Põe o endereço na barra lateral de "Meus documentos" (user-places.xbel)."""
    import xml.etree.ElementTree as ET
    f = os.path.join(HOME, '.local/share/user-places.xbel')
    try:
        arvore = ET.parse(f)
        raiz = arvore.getroot()
    except Exception:
        return
    for b in raiz.findall('bookmark'):
        if b.get('href') == url:
            return
    b = ET.SubElement(raiz, 'bookmark', href=url)
    ET.SubElement(b, 'title').text = nome
    info = ET.SubElement(b, 'info')
    md = ET.SubElement(info, 'metadata', owner='http://freedesktop.org')
    ic = ET.SubElement(md, '{http://www.freedesktop.org/standards/desktop-bookmarks}icon')
    ic.set('name', 'folder-remote')
    ET.register_namespace('bookmark', 'http://www.freedesktop.org/standards/desktop-bookmarks')
    arvore.write(f, encoding='utf-8', xml_declaration=True)


def partilhas():
    r = []
    out = cmd(['net', 'usershare', 'info'])
    atual = None
    for l in out.splitlines():
        m = re.match(r'^\[(.+)\]$', l.strip())
        if m:
            atual = dict(nome=m.group(1), caminho='', escrita=False)
            r.append(atual)
        elif atual and l.startswith('path='):
            atual['caminho'] = l[5:]
        elif atual and l.startswith('usershare_acl='):
            atual['escrita'] = ':F' in l
    return r


def sobre():
    info = {}
    try:
        with open('/etc/os-release') as f:
            os_rel = dict(l.strip().split('=', 1) for l in f if '=' in l)
        info['sistema'] = os_rel.get('PRETTY_NAME', 'CarinaeOS').strip('"')
    except OSError:
        info['sistema'] = 'CarinaeOS'
    info['nome'] = socket.gethostname()
    try:
        with open('/proc/cpuinfo') as f:
            m = re.search(r'model name\s*:\s*(.+)', f.read())
        info['processador'] = re.sub(r'\s+', ' ', m.group(1)) if m else '—'
    except OSError:
        info['processador'] = '—'
    info['nucleos'] = str(os.cpu_count() or 1)
    try:
        with open('/proc/meminfo') as f:
            kb = int(re.search(r'MemTotal:\s+(\d+)', f.read()).group(1))
        info['memoria'] = tamanho(kb * 1024)
    except Exception:
        info['memoria'] = '—'
    try:
        st = os.statvfs('/')
        info['disco'] = '%s (%s livres)' % (tamanho(st.f_blocks * st.f_frsize), tamanho(st.f_bavail * st.f_frsize))
    except OSError:
        info['disco'] = '—'
    gpu = cmd(['sh', '-c', "lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | cut -d: -f3"])
    info['grafica'] = gpu.strip() or '—'
    sessao = os.environ.get('XDG_SESSION_TYPE', '')
    info['janelas'] = 'Wayland' if sessao == 'wayland' else ('X11' if sessao == 'x11' else '—')
    info['nucleo'] = os.uname().release
    return info


class Config(QObject):
    mudou = Signal()
    _chegou = Signal(object, object)

    def __init__(self, inicio):
        super().__init__()
        self._inicio = inicio if any(s[0] == inicio for s in SECCOES) else 'wifi'
        self._redes = []
        self._msg = ''
        self._estado = {}
        self._chegou.connect(lambda f, r: f(r))

    seccoes = Property('QVariantList', lambda s: [dict(id=a, nome=b, icone=c, completo=bool(d), palavras=e)
                                                  for a, b, c, d, e in SECCOES], constant=True)
    inicio = Property(str, lambda s: s._inicio, constant=True)
    redes = Property('QVariantList', lambda s: s._redes, notify=mudou)
    mensagem = Property(str, lambda s: s._msg, notify=mudou)
    estado = Property('QVariantMap', lambda s: s._estado, notify=mudou)

    def _fundo(self, trabalho, depois):
        def t():
            try:
                r = trabalho()
            except Exception as e:
                r = e
            self._chegou.emit(depois, r)
        threading.Thread(target=t, daemon=True).start()

    def _aviso(self, msg):
        self._msg = msg
        self.mudou.emit()

    # ---- ler o estado de uma pagina ------------------------------------------------------------
    @Slot(str)
    def ler(self, pagina):
        def trabalho():
            e = {}
            if pagina in ('wifi', 'rede'):
                e['wifi'] = cmd(['nmcli', 'radio', 'wifi']) == 'enabled'
                linhas = cmd(['nmcli', '-t', '-f', 'IN-USE,SSID,SIGNAL,SECURITY', 'dev', 'wifi', 'list'], 15).splitlines()
                redes, vistos = [], set()
                for l in linhas:
                    p = re.split(r'(?<!\\):', l)
                    if len(p) < 4 or not p[1] or p[1] in vistos:
                        continue
                    vistos.add(p[1])
                    redes.append(dict(ssid=p[1].replace('\\:', ':'), ligada=p[0] == '*', sinal=int(p[2] or 0),
                                      segura=bool(p[3] and p[3] != '--')))
                e['redes'] = redes
                e['ligacoes'] = [dict(nome=x.split(':')[0], tipo=x.split(':')[1], disp=x.split(':')[2])
                                 for x in cmd(['nmcli', '-t', '-f', 'NAME,TYPE,DEVICE', 'con', 'show', '--active']).splitlines()
                                 if x.count(':') >= 2]
                e['ip'] = cmd(['hostname', '-I']).split()[:2]
                e['servidores'] = servidores()
            elif pagina == 'bluetooth':
                e['bluetooth'] = 'Powered: yes' in cmd(['bluetoothctl', 'show'])
                e['aparelhos'] = [l.split(' ', 2)[2] for l in cmd(['bluetoothctl', 'devices', 'Paired']).splitlines()
                                  if l.count(' ') >= 2]
            elif pagina == 'som':
                m = re.search(r'([\d.]+)', cmd(['wpctl', 'get-volume', '@DEFAULT_AUDIO_SINK@']))
                e['volume'] = min(1.0, float(m.group(1))) if m else 0.5
                m = re.search(r'([\d.]+)', cmd(['wpctl', 'get-volume', '@DEFAULT_AUDIO_SOURCE@']))
                e['microfone'] = min(1.0, float(m.group(1))) if m else 0.5
            elif pagina == 'ecras':
                if shutil.which('brightnessctl'):
                    a, mx = cmd(['brightnessctl', 'g']), cmd(['brightnessctl', 'm'])
                    e['brilho'] = int(a) / int(mx) if a.isdigit() and mx.isdigit() and int(mx) else -1
                else:
                    e['brilho'] = -1
                e['ecras'] = [l.strip() for l in cmd(['sh', '-c', "kscreen-doctor -o 2>/dev/null | sed 's/\\x1b\\[[0-9;]*m//g' | grep -E '^Output:'"]).splitlines()]
            elif pagina == 'energia':
                e['perfil'] = cmd(['powerprofilesctl', 'get']) or ''
                lista = cmd(['powerprofilesctl', 'list'])
                e['perfis'] = [p for p in ('performance', 'balanced', 'power-saver') if re.search(r'\b%s:' % p, lista)]
                m = re.search(r'performance:.*?Degraded:\s*yes\s*\((.*?)\)', lista, re.S)
                e['degradado'] = m.group(1) if m else ''
                bat = cmd(['sh', '-c', 'cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1'])
                e['bateria'] = int(bat) if bat.isdigit() else -1
            elif pagina == 'aparencia':
                e['claro'] = 'Light' in cmd(['kreadconfig6', '--group', 'General', '--key', 'ColorScheme'])
                fundos = []
                base = '/usr/share/wallpapers'
                for d in sorted(os.listdir(base)) if os.path.isdir(base) else []:
                    sc = os.path.join(base, d, 'contents/screenshot.jpg')
                    img = os.path.join(base, d, 'contents/images')
                    if os.path.exists(sc) and os.path.isdir(img):
                        fundos.append(dict(id=d, miniatura='file://' + sc, caminho=os.path.join(base, d)))
                fundos.sort(key=lambda x: (not x['id'].startswith('CarinaeOS-Nebulosa'), x['id'] != 'CarinaeOS', x['id']))
                e['fundos'] = fundos
            elif pagina == 'pesquisa':
                try:
                    with open(os.path.join(HOME, '.config/baloofilerc')) as f:
                        e['indexacao'] = 'Indexing-Enabled=false' not in f.read()
                except OSError:
                    e['indexacao'] = True
                e['indexados'] = cmd(['sh', '-c', "balooctl6 status 2>/dev/null | grep -iE 'total|arquivos|files' | head -2"])
            elif pagina == 'partilha':
                e['sambaInstalado'] = os.path.exists('/usr/sbin/smbd')
                e['samba'] = e['sambaInstalado'] and cmd(['systemctl', 'is-active', 'smbd']) == 'active'
                e['partilhas'] = partilhas() if e['sambaInstalado'] else []
                e['nomePc'] = socket.gethostname()
                e['ssh'] = -1 if not os.path.exists('/usr/sbin/sshd') else (1 if cmd(['systemctl', 'is-active', 'ssh']) == 'active' else 0)
                e['ip'] = cmd(['hostname', '-I']).split()[:2]
                e['usuario'] = os.environ.get('USER') or os.path.basename(HOME)
            elif pagina == 'dock':
                rc = os.path.join(HOME, '.config/plasma-org.kde.plasma.desktop-appletsrc')
                d = dict(iconSize=56, zoom=1.6, separatorWidth=1, separatorColor='#ffffff', posicao='bottom', esconder=False)
                try:
                    txt = open(rc, encoding='utf-8').read()
                    blocos = re.split(r'\n(?=\[)', txt)
                    cont = None
                    for i, b in enumerate(blocos):
                        if 'plugin=org.carinaeos.dock' in b:
                            m = re.match(r'\[Containments\]\[(\d+)\]\[Applets\]\[(\d+)\]', b)
                            if m:
                                cont, app = m.groups()
                    for b in blocos:
                        if cont and b.startswith('[Containments][%s][Applets][%s][Configuration][General]' % (cont, app)):
                            for l in b.splitlines()[1:]:
                                if '=' in l:
                                    k, v = l.split('=', 1)
                                    if k in ('iconSize', 'separatorWidth'):
                                        d[k] = int(v)
                                    elif k == 'zoom':
                                        d[k] = float(v)
                                    elif k == 'separatorColor':
                                        d[k] = v
                        if cont and b.startswith('[Containments][%s]\n' % cont):
                            m = re.search(r'^location=(\d+)', b, re.M)
                            if m:
                                d['posicao'] = {'3': 'top', '4': 'bottom', '5': 'left', '6': 'right'}.get(m.group(1), 'bottom')
                    pv = open(os.path.join(HOME, '.config/plasmashellrc'), encoding='utf-8').read()
                    m = re.search(r'\[PlasmaViews\]\[Panel %s\][^\[]*?panelVisibility=(\d)' % cont, pv)
                    d['esconder'] = bool(m and m.group(1) == '1')
                except Exception:
                    pass
                e.update(d)
            elif pagina == 'datahora':
                e['auto'] = 'NTP=yes' in cmd(['timedatectl', 'show', '-p', 'NTP'])
                e['fuso'] = cmd(['timedatectl', 'show', '-p', 'Timezone', '--value'])
                e['agora'] = cmd(['date', '+%A, %d de %B de %Y · %H:%M'])
            elif pagina == 'utilizadores':
                e['usuario'] = os.environ.get('USER') or os.path.basename(HOME)
                nome = cmd(['getent', 'passwd', e['usuario']]).split(':')
                e['nome'] = (nome[4].split(',')[0] if len(nome) > 4 else '') or e['usuario']
                foto = os.path.join(HOME, '.face.icon')
                e['foto'] = 'file://' + foto if os.path.exists(foto) else ''
            elif pagina == 'sistema':
                e.update(sobre())
            return e

        def depois(r):
            if isinstance(r, dict):
                self._estado = r
                self.mudou.emit()
        self._fundo(trabalho, depois)

    # ---- acoes ------------------------------------------------------------------------------------
    @Slot(str)
    def completo(self, ident):
        for s in SECCOES:
            if s[0] == ident and s[3]:
                bg(['kcmshell6', s[3]])

    @Slot(bool)
    def definirWifi(self, ligar):
        bg(['nmcli', 'radio', 'wifi', 'on' if ligar else 'off'])

    @Slot(str, str)
    def ligarWifi(self, ssid, senha):
        args = ['nmcli', 'dev', 'wifi', 'connect', ssid] + (['password', senha] if senha else [])
        self._aviso('A ligar a %s…' % ssid)

        def depois(r):
            ok = not isinstance(r, Exception) and r.returncode == 0
            self._aviso(('Ligado a %s ✓' % ssid) if ok else 'Não foi possível ligar: confirme a senha.')
            self.ler('wifi')
        self._fundo(lambda: subprocess.run(args, capture_output=True, text=True, timeout=60), depois)

    @Slot(bool)
    def definirBluetooth(self, ligar):
        bg(['bluetoothctl', 'power', 'on' if ligar else 'off'])

    @Slot(float)
    def definirVolume(self, v):
        bg(['wpctl', 'set-volume', '-l', '1.0', '@DEFAULT_AUDIO_SINK@', '%.2f' % v])

    @Slot(float)
    def definirMicrofone(self, v):
        bg(['wpctl', 'set-volume', '-l', '1.0', '@DEFAULT_AUDIO_SOURCE@', '%.2f' % v])

    @Slot(float)
    def definirBrilho(self, v):
        bg(['brightnessctl', '-q', 's', '%d%%' % max(1, round(v * 100))])

    @Slot(bool)
    def luzNoturna(self, ligar):
        bg(['kwriteconfig6', '--file', 'kwinrc', '--group', 'NightColor', '--key', 'Active', 'true' if ligar else 'false'])
        bg(['qdbus6', 'org.kde.KWin', '/KWin', 'reconfigure'])

    @Slot(str)
    def definirPerfil(self, p):
        nomes = {'performance': 'Desempenho', 'balanced': 'Equilibrado', 'power-saver': 'Poupança'}

        def depois(r):
            ok = not isinstance(r, Exception) and r.returncode == 0
            if ok:
                self._aviso('Modo %s ✓' % nomes.get(p, p))
            else:
                erro = '' if isinstance(r, Exception) else (r.stderr or '').strip()
                self._aviso('Este computador não tem o modo %s' % nomes.get(p, p) if 'not' in erro.lower() or 'available' in erro.lower()
                            else 'Não foi possível mudar o modo de energia')
            self.ler('energia')
        self._fundo(lambda: subprocess.run(['powerprofilesctl', 'set', p], capture_output=True, text=True, timeout=20), depois)

    @Slot(bool)
    def definirClaro(self, claro):
        bg(['plasma-apply-colorscheme', 'BreezeLight' if claro else 'CarinaeOS'])
        bg(['gsettings', 'set', 'org.gnome.desktop.interface', 'color-scheme', 'default' if claro else 'prefer-dark'])

    @Slot(str)
    def definirFundo(self, caminho):
        bg(['plasma-apply-wallpaperimage', caminho])
        self._aviso('Papel de parede aplicado ✓')

    @Slot(int)
    def definirAnimado(self, variante):
        js = ('var d = desktops(); for (var i = 0; i < d.length; i++) { d[i].wallpaperPlugin = "org.carinaeos.vivo"; '
              'd[i].currentConfigGroup = ["Wallpaper", "org.carinaeos.vivo", "General"]; d[i].writeConfig("Variante", %d); }'
              % (2 if variante == 2 else 1))
        bg(['qdbus6', 'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell.evaluateScript', js])
        self._aviso('Papel de parede animado aplicado ✓')

    @Slot(bool)
    def definirIndexacao(self, ligar):
        bg(['balooctl6', 'enable' if ligar else 'disable'])

    @Slot(bool)
    def definirSSH(self, ligar):
        self._aviso('A pedir autorização…')

        def depois(r):
            ok = not isinstance(r, Exception) and r.returncode == 0
            self._aviso(('Acesso remoto %s ✓' % ('ligado' if ligar else 'desligado')) if ok else 'Não foi alterado.')
            self.ler('partilha')
        self._fundo(lambda: subprocess.run(['pkexec', '/usr/lib/carinaeos/ssh', 'ligar' if ligar else 'desligar'],
                                           capture_output=True, timeout=600), depois)

    # ---- pastas partilhadas na rede (como "Outros locais" do Fedora) ----------------------------------
    @Slot(str)
    def ligarServidor(self, texto):
        url = normalizar_endereco(texto)
        if not url:
            return
        lista = [x for x in servidores() if x.get('url') != url]
        nome = re.sub(r'^[a-z]+://', '', url).rstrip('/')
        lista.insert(0, dict(url=url, nome=nome))
        os.makedirs(os.path.dirname(SERVIDORES), exist_ok=True)
        with open(SERVIDORES, 'w') as f:
            json.dump(lista[:12], f)
        adicionar_local(url, nome.split('/')[-1] or nome)
        bg(['dolphin', '--new-window', url])
        self._aviso('A ligar a %s… (se pedir, escreva o usuário e a senha do servidor)' % nome)
        self.ler('rede')

    @Slot(str)
    def esquecerServidor(self, url):
        lista = [x for x in servidores() if x.get('url') != url]
        with open(SERVIDORES, 'w') as f:
            json.dump(lista, f)
        self.ler('rede')

    escolherPastaPedida = Signal()

    @Slot(bool)
    def definirPartilha(self, ligar):
        self._aviso('A pedir autorização…')
        u = os.environ.get('USER') or os.path.basename(HOME)

        def depois(r):
            ok = not isinstance(r, Exception) and r.returncode == 0
            if ok and ligar:
                self._aviso('Partilha de pastas ligada ✓ Escolha a primeira pasta a partilhar.')
                self.escolherPastaPedida.emit()
            elif ok:
                self._aviso('Partilha de pastas desligada ✓')
            else:
                erro = '' if isinstance(r, Exception) else (r.stderr or b'').decode(errors='ignore').strip()
                self._aviso('Não foi possível: ' + (erro[-120:] or 'autorização recusada'))
            self.ler('partilha')
        self._fundo(lambda: subprocess.run(['pkexec', '/usr/lib/carinaeos/partilha', 'ligar' if ligar else 'desligar', u],
                                           capture_output=True, timeout=900), depois)

    @Slot()
    def ativarPartilha(self):
        self.definirPartilha(True)

    @Slot(str, bool)
    def partilharPasta(self, caminho, escrita):
        if caminho.startswith('file://'):
            from urllib.parse import unquote
            caminho = unquote(caminho[7:])
        nome = re.sub(r'[^A-Za-z0-9_-]', '_', os.path.basename(caminho.rstrip('/')) or 'pasta')[:40]
        acl = 'Everyone:F' if escrita else 'Everyone:R'
        r = subprocess.run(['net', 'usershare', 'add', nome, caminho, 'Partilhada pelo CarinaeOS', acl, 'guest_ok=y'],
                           capture_output=True, text=True)
        if r.returncode != 0:
            # ainda sem permissao na sessao atual (grupo novo): faz-se como administrador
            r = subprocess.run(['pkexec', '/usr/lib/carinaeos/partilha', 'pasta', nome, caminho, 'rw' if escrita else 'ro',
                                os.environ.get('USER') or ''], capture_output=True, text=True)
        if r.returncode == 0 and escrita:
            subprocess.run(['chmod', 'o+rwx', caminho])
        self._aviso(('“%s” está partilhada na rede ✓' % nome) if r.returncode == 0
                    else 'Não foi possível partilhar: ' + (r.stderr.strip() or r.stdout.strip())[:120])
        self.ler('partilha')

    @Slot(str)
    def deixarDePartilhar(self, nome):
        subprocess.run(['net', 'usershare', 'delete', nome], capture_output=True)
        self.ler('partilha')

    pastaEscolhida = Signal(str, bool)

    @Slot(bool)
    def escolherPastaPartilhar(self, escrita):
        def t():
            r = subprocess.run(['kdialog', '--title', 'Escolha a pasta a partilhar', '--getexistingdirectory', HOME],
                               capture_output=True, text=True)
            if r.returncode == 0 and r.stdout.strip():
                self._chegou.emit(lambda c: self.partilharPasta(c, escrita), r.stdout.strip())
        threading.Thread(target=t, daemon=True).start()

    # ---- Dock -----------------------------------------------------------------------------------------
    @Slot(str, 'QVariant')
    def definirDock(self, chave, valor):
        if chave == 'posicao':
            js = ('var p = panels(); for (var i = 0; i < p.length; i++) { var w = p[i].widgets(); '
                  'for (var j = 0; j < w.length; j++) if (w[j].type == "org.carinaeos.dock") p[i].location = "%s"; }' % valor)
        elif chave == 'esconder':
            js = ('var p = panels(); for (var i = 0; i < p.length; i++) { var w = p[i].widgets(); '
                  'for (var j = 0; j < w.length; j++) if (w[j].type == "org.carinaeos.dock") p[i].hiding = "%s"; }'
                  % ('autohide' if valor else 'none'))
        else:
            tipo = {'iconSize': int, 'zoom': float, 'separatorWidth': int, 'separatorColor': str}.get(chave, str)
            v = tipo(valor)
            js = ('var p = panels(); for (var i = 0; i < p.length; i++) { var w = p[i].widgets(); '
                  'for (var j = 0; j < w.length; j++) if (w[j].type == "org.carinaeos.dock") { '
                  'w[j].currentConfigGroup = ["General"]; w[j].writeConfig("%s", %s); } }' % (chave, json.dumps(v)))
        # depois: o painel-espaçador acompanha a Dock (altura do vidro, mesmo lado; sai se a Dock se esconder)
        try:
            js += '\n' + open('/usr/share/carinaeos/dock-espacador.js', encoding='utf-8').read()
        except OSError:
            pass
        bg(['qdbus6', 'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell.evaluateScript', js])
        if chave == 'esconder' and not valor:
            # voltar a "sempre visível" = modo 3 (as janelas passam por baixo; o espaçador reserva o vidro):
            # só se guarda com o Plasma parado, e o script de entrada trata disso
            bg(['sh', '-c', 'sleep 2; XDG_CURRENT_DESKTOP=KDE carinaeos-ambiente-inicio'])
        self._aviso('Dock atualizada ✓')

    @Slot(bool)
    def definirHoraAuto(self, ligar):
        bg(['timedatectl', 'set-ntp', 'true' if ligar else 'false'])

    @Slot(str)
    def abrir(self, comando):
        correr(['bash', '-lc', comando], espera=False)


if __name__ == '__main__':
    pag = sys.argv[1] if len(sys.argv) > 1 else ''
    sys.exit(iniciar('carinaeos-configuracoes', 'Configurações', 'preferences-system', os.path.join(AQUI, 'Main.qml'),
                     {'ajustes': Config(pag)}))
