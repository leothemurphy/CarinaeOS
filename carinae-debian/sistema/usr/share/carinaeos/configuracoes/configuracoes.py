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
    ('notificacoes', 'Notificações', 'preferences-desktop-notification', 'kcm_notifications', 'avisos nao incomodar'),
    ('pesquisa', 'Pesquisa', 'search', 'kcm_baloofile', 'indexacao arquivos procurar'),
    ('aplicativos', 'Aplicativos', 'preferences-desktop-default-applications', 'kcm_componentchooser', 'padrao navegador email abrir com'),
    ('privacidade', 'Privacidade e segurança', 'preferences-system-privacy', None, 'convidado bloqueio ecra senha'),
    ('partilha', 'Partilha', 'network-server', None, 'ssh acesso remoto pastas'),
    ('teclado', 'Teclado', 'preferences-desktop-keyboard', 'kcm_keyboard', 'atalhos idioma layout numlock'),
    ('rato', 'Rato e touchpad', 'input-mouse', 'kcm_mouse', 'touchpad cursor velocidade'),
    ('impressoras', 'Impressoras', 'printer', 'kcm_printer_manager', 'imprimir scanner'),
    ('contas', 'Contas online', 'preferences-online-accounts', 'kcm_kaccounts', 'google nextcloud calendario'),
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
                e['ssh'] = -1 if not os.path.exists('/usr/sbin/sshd') else (1 if cmd(['systemctl', 'is-active', 'ssh']) == 'active' else 0)
                e['ip'] = cmd(['hostname', '-I']).split()[:2]
                e['usuario'] = os.environ.get('USER') or os.path.basename(HOME)
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
        bg(['powerprofilesctl', 'set', p])

    @Slot(bool)
    def definirClaro(self, claro):
        bg(['plasma-apply-colorscheme', 'BreezeLight' if claro else 'CarinaeOS'])
        bg(['gsettings', 'set', 'org.gnome.desktop.interface', 'color-scheme', 'default' if claro else 'prefer-dark'])

    @Slot(str)
    def definirFundo(self, caminho):
        bg(['plasma-apply-wallpaperimage', caminho])
        self._aviso('Papel de parede aplicado ✓')

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
