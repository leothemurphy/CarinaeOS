#!/usr/bin/python3
# CarinaeOS - Central: todas as ferramentas do CarinaeOS num só lugar, e as páginas de
# Calendários (Google, iCloud, endereço iCal), Janelas em zonas, Drivers e hardware,
# Privacidade (sessão sem rastro, modo escuro forçado) e Área de transferência.
import json
import os
import re
import shutil
import subprocess
import sys
import threading

sys.path.insert(0, '/usr/share/carinaeos/comum')
from base import correr, iniciar  # noqa: E402

from PySide6.QtCore import Property, QObject, Signal, Slot  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser('~')
CFG = os.path.join(HOME, '.config')

FERRAMENTAS = [
    dict(id='eta', nome='Eta', desc='A assistente: pergunte ou peça qualquer coisa', icone='carinaeos-eta', cmd='carinaeos-eta'),
    dict(id='supernova', nome='Supernova', desc='Personalizar: Dock, janelas, efeitos, perfis', icone='carinaeos-supernova', cmd='carinaeos-supernova'),
    dict(id='orbita', nome='Órbita', desc='Loja de aplicativos', icone='carinaeos-orbita', cmd='carinaeos-orbita'),
    dict(id='ambientes', nome='Ambiente e estilo', desc='Mac, Windows 11, GNOME ou XFCE', icone='preferences-desktop-theme-global', cmd='carinaeos-ambientes'),
    dict(id='casa', nome='Casa', desc='Painéis do Home Assistant', icone='carinaeos-casa', cmd='carinaeos-casa'),
    dict(id='calendarios', nome='Calendários', desc='Google, iCloud e endereços iCal', icone='view-calendar', pagina='calendarios'),
    dict(id='janelas', nome='Janelas em zonas', desc='Encaixar janelas lado a lado e áreas de trabalho', icone='view-grid', pagina='janelas'),
    dict(id='cadeado', nome='Cadeado', desc='Pastas, arquivos e aplicativos com senha', icone='object-locked', pagina='cadeado'),
    dict(id='etiquetas', nome='Etiquetas', desc='Arquivos organizados por cores', icone='tag', cmd='xdg-open ' + os.path.join(HOME, 'Etiquetas')),
    dict(id='clipboard', nome='Histórico do Ctrl+C', desc='Tudo o que copiou (Meta+V)', icone='edit-paste', pagina='clipboard'),
    dict(id='drivers', nome='Drivers e hardware', desc='Placa de vídeo, Wi-Fi, impressoras, impressão digital', icone='preferences-devices-pci', pagina='drivers'),
    dict(id='privacidade', nome='Privacidade', desc='Sessão sem rastro e modo escuro em todo o lado', icone='preferences-system-privacy', pagina='privacidade'),
    dict(id='fundos', nome='Papéis de parede', desc='Fotos do céu em 8K e o Céu vivo', icone='preferences-desktop-wallpaper', cmd='carinaeos-ceu-vivo galeria'),
    dict(id='boasvindas', nome='Boas-vindas', desc='Tudo o que o CarinaeOS tem, num passeio', icone='carinaeos', cmd='carinaeos-boasvindas'),
    dict(id='sobre', nome='Sobre este computador', desc='Processador, memória, sistema', icone='carinaeos', cmd='kinfocenter'),
]


def qdbus(*args, timeout=20):
    exe = shutil.which('qdbus6') or shutil.which('qdbus') or 'qdbus6'
    r = subprocess.run([exe, *args], capture_output=True, text=True, timeout=timeout)
    if r.returncode != 0:
        raise RuntimeError((r.stderr or r.stdout).strip() or 'qdbus falhou')
    return r.stdout.strip()


# ---- calendarios (Akonadi, usado pelo Calendario/Merkuro e pelo relogio da barra) -------------------
def calendarios():
    try:
        ids = qdbus('org.freedesktop.Akonadi.Control', '/AgentManager',
                    'org.freedesktop.Akonadi.AgentManager.agentInstances').split()
    except Exception:
        return []
    res = []
    for i in ids:
        if not re.match(r'akonadi_(ical|google|davgroupware|icaldir)_resource', i):
            continue
        try:
            nome = qdbus('org.freedesktop.Akonadi.Control', '/AgentManager',
                         'org.freedesktop.Akonadi.AgentManager.agentInstanceName', i)
        except Exception:
            nome = i
        tipo = 'Google' if 'google' in i else 'CalDAV (iCloud, Nextcloud…)' if 'dav' in i else 'Endereço iCal'
        res.append(dict(id=i, nome=nome, tipo=tipo))
    return res


def criar_recurso(tipo):
    return qdbus('org.freedesktop.Akonadi.Control', '/AgentManager',
                 'org.freedesktop.Akonadi.AgentManager.createAgentInstance', tipo)


def adicionar_ical(url, nome):
    url = url.strip()
    if url.startswith('webcal://'):
        url = 'https://' + url[len('webcal://'):]
    if not re.match(r'^https?://', url):
        raise ValueError('O endereço tem de começar por https:// ou webcal://')
    ident = criar_recurso('akonadi_ical_resource')
    svc = 'org.freedesktop.Akonadi.Resource.' + ident
    for _ in range(20):
        try:
            qdbus(svc, '/Settings', 'org.kde.Akonadi.ICal.Settings.setPath', url)
            break
        except Exception:
            __import__('time').sleep(0.5)
    else:
        raise RuntimeError('o serviço de calendários não respondeu')
    qdbus(svc, '/Settings', 'org.kde.Akonadi.ICal.Settings.setReadOnly', 'true')
    qdbus(svc, '/Settings', 'org.kde.Akonadi.ICal.Settings.setMonitorFile', 'false')
    try:
        qdbus(svc, '/Settings', 'org.kde.Akonadi.ICal.Settings.setDisplayName', nome)
    except Exception:
        pass
    qdbus(svc, '/Settings', 'org.kde.Akonadi.ICal.Settings.save')
    qdbus('org.freedesktop.Akonadi.Control', '/AgentManager',
          'org.freedesktop.Akonadi.AgentManager.setAgentInstanceName', ident, nome)
    qdbus('org.freedesktop.Akonadi.Agent.' + ident, '/', 'org.freedesktop.Akonadi.Agent.Control.reconfigure')
    qdbus('org.freedesktop.Akonadi.Control', '/AgentManager',
          'org.freedesktop.Akonadi.AgentManager.agentInstanceSynchronize', ident)
    return ident


def configurar_conta(tipo):
    """Google ou CalDAV (iCloud): cria a conta e abre a janela de configuracao/autorizacao."""
    ident = criar_recurso(tipo)
    subprocess.Popen(['qdbus6', 'org.freedesktop.Akonadi.Agent.' + ident, '/',
                      'org.freedesktop.Akonadi.Agent.Control.configure', '0'],
                     start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return ident


def remover_calendario(ident):
    qdbus('org.freedesktop.Akonadi.Control', '/AgentManager',
          'org.freedesktop.Akonadi.AgentManager.removeAgentInstance', ident)


# ---- janelas em zonas (KWin) --------------------------------------------------------------------
ZONAS = {
    'duas': dict(nome='Duas colunas', tiles={'layoutDirection': 'horizontal', 'tiles': [{'width': 0.5}, {'width': 0.5}]}),
    'tres': dict(nome='Três colunas', tiles={'layoutDirection': 'horizontal', 'tiles': [{'width': 0.333}, {'width': 0.334}, {'width': 0.333}]}),
    'principal': dict(nome='Principal + duas', tiles={'layoutDirection': 'horizontal', 'tiles': [
        {'width': 0.6}, {'width': 0.4, 'layoutDirection': 'vertical', 'tiles': [{'height': 0.5}, {'height': 0.5}]}]}),
    'grade': dict(nome='Grade 2×2', tiles={'layoutDirection': 'horizontal', 'tiles': [
        {'width': 0.5, 'layoutDirection': 'vertical', 'tiles': [{'height': 0.5}, {'height': 0.5}]},
        {'width': 0.5, 'layoutDirection': 'vertical', 'tiles': [{'height': 0.5}, {'height': 0.5}]}]}),
    'larga': dict(nome='Ecrã largo (1/4 · 1/2 · 1/4)', tiles={'layoutDirection': 'horizontal', 'tiles': [{'width': 0.25}, {'width': 0.5}, {'width': 0.25}]}),
}


def aplicar_zonas(ident):
    z = ZONAS[ident]['tiles']
    kwinrc = os.path.join(CFG, 'kwinrc')
    try:
        txt = open(kwinrc, encoding='utf-8').read()
    except OSError:
        txt = ''
    grupos = re.findall(r'^\[Tiling\]\[([^\]]+)\]', txt, re.M)
    if not grupos:
        try:
            saida = subprocess.run(['kscreen-doctor', '-j'], capture_output=True, text=True, timeout=10).stdout
            grupos = [o.get('uuid') for o in json.loads(saida).get('outputs', []) if o.get('uuid')]
        except Exception:
            grupos = []
    for g in set(grupos):
        subprocess.run(['kwriteconfig6', '--file', 'kwinrc', '--group', 'Tiling', '--group', g,
                        '--key', 'tiles', json.dumps(z, separators=(',', ':'))])
    subprocess.run(['qdbus6', 'org.kde.KWin', '/KWin', 'reconfigure'], capture_output=True)
    return len(set(grupos))


def areas_de_trabalho(n):
    subprocess.run(['kwriteconfig6', '--file', 'kwinrc', '--group', 'Desktops', '--key', 'Number', str(n)])
    subprocess.run(['kwriteconfig6', '--file', 'kwinrc', '--group', 'Desktops', '--key', 'Rows', '1' if n <= 4 else '2'])
    subprocess.run(['qdbus6', 'org.kde.KWin', '/KWin', 'reconfigure'], capture_output=True)


# ---- drivers e hardware ------------------------------------------------------------------------
def instalado(pac):
    r = subprocess.run(['dpkg-query', '-W', '-f=${Status}', pac], capture_output=True, text=True)
    return 'install ok installed' in r.stdout


def hardware():
    lspci = subprocess.run(['lspci', '-nn'], capture_output=True, text=True).stdout
    lsusb = subprocess.run(['lsusb'], capture_output=True, text=True).stdout if shutil.which('lsusb') else ''
    itens = []

    def item(ident, nome, detalhe, pacotes, icone, nota=''):
        falta = [p for p in pacotes if not instalado(p)]
        itens.append(dict(id=ident, nome=nome, detalhe=detalhe, pacotes=pacotes, falta=falta, icone=icone, nota=nota))

    gpus = [l.split(': ', 1)[-1] for l in lspci.splitlines() if re.search(r'VGA|3D controller|Display controller', l)]
    for g in gpus:
        g_curto = re.sub(r'\s*\[[0-9a-f]{4}:[0-9a-f]{4}\].*', '', g)
        if re.search(r'NVIDIA', g, re.I):
            item('nvidia', 'Placa de vídeo NVIDIA', g_curto, ['nvidia-driver', 'firmware-misc-nonfree', 'nvidia-suspend-common'],
                 'nvidia', 'Driver oficial da NVIDIA (melhor desempenho em jogos e no Wayland). Reinicie depois de instalar.')
        elif re.search(r'AMD|ATI', g, re.I):
            item('amd', 'Placa de vídeo AMD', g_curto, ['firmware-amd-graphics', 'mesa-vulkan-drivers'], 'video-display')
        elif re.search(r'Intel', g, re.I):
            item('intel', 'Gráficos Intel', g_curto, ['intel-media-va-driver-non-free', 'mesa-vulkan-drivers'], 'video-display')
        else:
            item('video', 'Placa de vídeo', g_curto, [], 'video-display')
    if re.search(r'Network controller|Wireless', lspci) or re.search(r'Wireless|WLAN|802\.11', lsusb, re.I):
        item('wifi', 'Wi-Fi', 'Firmwares para Intel, Realtek, Atheros, Broadcom e MediaTek',
             ['firmware-iwlwifi', 'firmware-realtek', 'firmware-atheros', 'firmware-brcm80211', 'firmware-mediatek'], 'network-wireless')
    if re.search(r'Bluetooth', lsusb + lspci, re.I) or os.path.isdir('/sys/class/bluetooth'):
        item('bt', 'Bluetooth', 'Firmware e ferramentas', ['bluez', 'bluez-firmware'], 'preferences-system-bluetooth')
    item('impressoras', 'Impressoras e scanners', 'HP, Epson, Canon, Brother e as que funcionam sem driver (AirPrint)',
         ['cups', 'print-manager', 'printer-driver-all', 'hplip', 'sane-airscan', 'ipp-usb', 'skanlite'], 'printer')
    if re.search(r'fingerprint|Synaptics.*(FS|Prometheus)|Goodix|Elan.*Fingerprint|Validity', lsusb, re.I):
        item('digital', 'Leitor de impressão digital', 'Entrar e autorizar com o dedo', ['fprintd', 'libpam-fprintd'], 'fingerprint-gui',
             'Depois, registe o dedo em Configurações › Usuários.')
    if re.search(r'Logitech', lsusb, re.I):
        item('logitech', 'Rato/teclado Logitech', 'Botões, bateria e receptor Unifying/Bolt', ['solaar'], 'input-mouse')
    if re.search(r'Razer|SteelSeries|Roccat|Corsair|Glorious', lsusb, re.I):
        item('ratos', 'Rato de jogos', 'Botões, DPI e luzes (libratbag/Piper)', ['ratbagd', 'piper'], 'input-mouse')
    if re.search(r'Xbox|Sony.*(Controller|DualSense|DualShock)|8BitDo', lsusb, re.I):
        item('comandos', 'Comando de jogos', 'Xbox, PlayStation, 8BitDo', ['steam-devices'], 'input-gaming')
    return itens


# ---- privacidade: sessao sem rastro e modo escuro forcado -------------------------------------------
def convidado_ativo():
    try:
        with open('/etc/shadow') as f:
            pass
    except PermissionError:
        pass
    r = subprocess.run(['getent', 'passwd', 'convidado'], capture_output=True, text=True)
    if r.returncode != 0:
        return None
    return not os.path.exists('/etc/carinaeos/convidado-desligado')


ESCURO_CHROME = '--force-dark-mode\n--enable-features=WebContentsForceDark\n'
ESCURO_FF = ('user_pref("ui.systemUsesDarkTheme", 1);\n'
             'user_pref("layout.css.prefers-color-scheme.content-override", 0);\n'
             'user_pref("browser.theme.content-theme", 0);\nuser_pref("browser.theme.toolbar-theme", 0);\n')


def escuro_forcado():
    return os.path.exists(os.path.join(CFG, 'carinaeos', 'escuro-forcado'))


def definir_escuro(ligar):
    marca = os.path.join(CFG, 'carinaeos', 'escuro-forcado')
    os.makedirs(os.path.dirname(marca), exist_ok=True)
    flags = [os.path.join(CFG, n) for n in ('chromium-flags.conf', 'chrome-flags.conf', 'brave-flags.conf',
                                             'electron-flags.conf', 'code-flags.conf')]
    for f in flags:
        try:
            atual = open(f, encoding='utf-8').read()
        except OSError:
            atual = ''
        sem = '\n'.join(l for l in atual.splitlines() if l.strip() not in ('--force-dark-mode', '--enable-features=WebContentsForceDark'))
        novo = (sem.strip() + '\n' + ESCURO_CHROME) if ligar else (sem.strip() + '\n' if sem.strip() else '')
        if novo or os.path.exists(f):
            open(f, 'w', encoding='utf-8').write(novo.lstrip('\n'))
    # Firefox: em todos os perfis
    for base in (os.path.join(HOME, '.mozilla/firefox'), os.path.join(HOME, '.var/app/org.mozilla.firefox/.mozilla/firefox')):
        if not os.path.isdir(base):
            continue
        for p in os.listdir(base):
            d = os.path.join(base, p)
            if not os.path.exists(os.path.join(d, 'prefs.js')):
                continue
            uj = os.path.join(d, 'user.js')
            try:
                atual = open(uj, encoding='utf-8').read()
            except OSError:
                atual = ''
            linhas = [l for l in atual.splitlines() if l and l + '\n' not in ESCURO_FF]
            if ligar:
                linhas += ESCURO_FF.strip().splitlines()
            open(uj, 'w', encoding='utf-8').write('\n'.join(linhas) + ('\n' if linhas else ''))
    # GTK 3/4 e libadwaita
    subprocess.run(['gsettings', 'set', 'org.gnome.desktop.interface', 'color-scheme', 'prefer-dark' if ligar else 'default'],
                   capture_output=True)
    for v in ('gtk-3.0', 'gtk-4.0'):
        f = os.path.join(CFG, v, 'settings.ini')
        os.makedirs(os.path.dirname(f), exist_ok=True)
        try:
            txt = open(f, encoding='utf-8').read()
        except OSError:
            txt = '[Settings]\n'
        txt = re.sub(r'^gtk-application-prefer-dark-theme=.*\n?', '', txt, flags=re.M)
        if '[Settings]' not in txt:
            txt = '[Settings]\n' + txt
        txt = txt.replace('[Settings]\n', '[Settings]\ngtk-application-prefer-dark-theme=%s\n' % ('true' if ligar else 'false'), 1)
        open(f, 'w', encoding='utf-8').write(txt)
    # Flatpak: as apps tambem
    if shutil.which('flatpak'):
        subprocess.run(['flatpak', 'override', '--user', '--env=GTK_THEME=Adwaita:dark' if ligar else '--unset-env=GTK_THEME'],
                       capture_output=True)
    if ligar:
        open(marca, 'w').close()
    elif os.path.exists(marca):
        os.remove(marca)


class Central(QObject):
    mudou = Signal()
    _chegou = Signal(object, object)

    def __init__(self, pagina=''):
        super().__init__()
        self._pagina = pagina
        self._cals = []
        self._hw = []
        self._msg = ''
        self._ocupado = False
        self._chegou.connect(lambda f, r: f(r))

    ferramentas = Property('QVariantList', lambda s: FERRAMENTAS, constant=True)
    paginaInicial = Property(str, lambda s: s._pagina, constant=True)
    calendarios = Property('QVariantList', lambda s: s._cals, notify=mudou)
    hardware = Property('QVariantList', lambda s: s._hw, notify=mudou)
    mensagem = Property(str, lambda s: s._msg, notify=mudou)
    ocupado = Property(bool, lambda s: s._ocupado, notify=mudou)
    zonas = Property('QVariantList', lambda s: [dict(id=k, nome=v['nome'], tiles=json.dumps(v['tiles'])) for k, v in ZONAS.items()], constant=True)
    escuroForcado = Property(bool, lambda s: escuro_forcado(), notify=mudou)
    convidado = Property(int, lambda s: {None: -1, False: 0, True: 1}[convidado_ativo()], notify=mudou)
    plasma = Property(bool, lambda s: 'KDE' in os.environ.get('XDG_CURRENT_DESKTOP', 'KDE'), constant=True)

    def _fundo(self, trabalho, depois, aviso=''):
        self._ocupado = True
        self._msg = aviso
        self.mudou.emit()

        def t():
            try:
                r = trabalho()
            except Exception as e:
                r = e
            self._chegou.emit(depois, r)
        threading.Thread(target=t, daemon=True).start()

    def _fim(self, msg_ok):
        def f(r):
            self._ocupado = False
            self._msg = ('Não funcionou: %s' % r) if isinstance(r, Exception) else (msg_ok(r) if callable(msg_ok) else msg_ok)
            self.mudou.emit()
        return f

    @Slot(str)
    def abrir(self, cmd):
        correr(['bash', '-lc', cmd], espera=False)

    # calendarios
    @Slot()
    def lerCalendarios(self):
        def depois(r):
            self._ocupado = False
            self._msg = ''
            self._cals = r if isinstance(r, list) else []
            self.mudou.emit()
        self._fundo(calendarios, depois)

    @Slot(str, str)
    def adicionarIcal(self, url, nome):
        def depois(r):
            self._fim('Calendário “%s” adicionado ✓ Aparece no Calendário e no relógio da barra.' % (nome or 'novo'))(r)
            self.lerCalendarios()
        self._fundo(lambda: adicionar_ical(url, nome.strip() or 'Calendário'), depois, 'A adicionar o calendário…')

    @Slot(str)
    def conta(self, tipo):
        recurso = {'google': 'akonadi_google_resource', 'caldav': 'akonadi_davgroupware_resource'}[tipo]

        def depois(r):
            self._fim('Abri a janela da conta: siga os passos para entrar e autorizar.')(r)
            self.lerCalendarios()
        self._fundo(lambda: configurar_conta(recurso), depois, 'A preparar a conta…')

    @Slot(str)
    def removerCalendario(self, ident):
        self._fundo(lambda: remover_calendario(ident), lambda r: (self._fim('Calendário removido.')(r), self.lerCalendarios()))

    # janelas
    @Slot(str)
    def aplicarZonas(self, ident):
        self._fundo(lambda: aplicar_zonas(ident), self._fim(
            lambda n: 'Zonas “%s” prontas ✓ Arraste uma janela com Shift carregado para a encaixar numa zona.' % ZONAS[ident]['nome']))

    @Slot()
    def editarZonas(self):
        correr(['qdbus6', 'org.kde.kglobalaccel', '/component/kwin', 'org.kde.kglobalaccel.Component.invokeShortcut',
                'Edit Tiles'], espera=False)

    @Slot(int)
    def areas(self, n):
        self._fundo(lambda: areas_de_trabalho(n), self._fim('%d áreas de trabalho ✓ Ctrl+Meta+← → para mudar, Meta+W para ver todas.' % n))

    @Slot()
    def verAreas(self):
        correr(['qdbus6', 'org.kde.kglobalaccel', '/component/kwin', 'org.kde.kglobalaccel.Component.invokeShortcut',
                'Overview'], espera=False)

    # area de transferencia
    @Slot()
    def historico(self):
        correr(['qdbus6', 'org.kde.klipper', '/klipper', 'org.kde.klipper.klipper.showKlipperPopupMenu'], espera=False)

    # drivers
    @Slot()
    def lerHardware(self):
        def depois(r):
            self._ocupado = False
            self._msg = '' if isinstance(r, list) else 'Não consegui ver o hardware (%s).' % r
            self._hw = r if isinstance(r, list) else []
            self.mudou.emit()
        self._fundo(hardware, depois, 'A ver o que este computador tem…')

    @Slot(str)
    def instalarDriver(self, ident):
        it = next((h for h in self._hw if h['id'] == ident), None)
        if not it or not it['falta']:
            return
        pacs = ' '.join(it['falta'])
        cmd = ('pkexec bash -c "apt-get update -q; DEBIAN_FRONTEND=noninteractive apt-get install -y %s"' % pacs)

        def depois(r):
            self._fim(lambda _: '%s: instalado ✓%s' % (it['nome'], ' Reinicie o computador.' if ident == 'nvidia' else ''))(r)
            self.lerHardware()

        def trabalho():
            p = subprocess.run(['bash', '-c', cmd], capture_output=True, text=True)
            if p.returncode != 0:
                raise RuntimeError((p.stdout + p.stderr).strip().splitlines()[-1] if (p.stdout + p.stderr).strip() else 'cancelado')
        self._fundo(trabalho, depois, 'A instalar %s… (o sistema pede a sua senha)' % it['nome'])

    # privacidade
    @Slot(bool)
    def definirEscuro(self, ligar):
        self._fundo(lambda: definir_escuro(ligar), self._fim(
            'Modo escuro forçado %s ✓ Feche e abra os navegadores para ver.' % ('ligado' if ligar else 'desligado')))

    @Slot(bool)
    def definirConvidado(self, ligar):
        cmd = ['pkexec', '/usr/lib/carinaeos/convidado', 'ligar' if ligar else 'desligar']
        self._fundo(lambda: subprocess.run(cmd, check=True), self._fim(
            'Sessão sem rastro %s ✓' % ('disponível na tela de entrada' if ligar else 'desligada')))


if __name__ == '__main__':
    pag = sys.argv[1] if len(sys.argv) > 1 else ''
    sys.exit(iniciar('carinaeos-central', 'Central CarinaeOS', 'carinaeos', os.path.join(AQUI, 'Main.qml'),
                     {'central': Central(pag)}))
