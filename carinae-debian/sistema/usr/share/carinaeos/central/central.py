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
    dict(id='supernova', nome='Supernova', desc='Personalizar: Dock, janelas, efeitos, perfis', icone='carinaeos-supernova', cmd='carinaeos-supernova'),
    dict(id='orbita', nome='Órbita', desc='Loja de aplicativos', icone='carinaeos-orbita', cmd='carinaeos-orbita'),
    dict(id='atualizacoes', nome='Atualizações', desc='Atualizar com ponto de restauro e voltar atrás', icone='system-software-update', cmd='carinaeos-atualizacoes'),
    dict(id='casa', nome='Carinae Casa', desc='Ligado ao Home Assistant', icone='carinaeos-casa', cmd='carinaeos-casa'),
    dict(id='windows', nome='Vindo do Windows', desc='Trazer os seus arquivos e achar os seus programas', icone='windows', pagina='windows'),
    dict(id='celular', nome='Celular', desc='KDE Connect: arquivos, encontrar o celular, texto copiado', icone='smartphone', pagina='celular'),
    dict(id='jogos', nome='Jogos', desc='Steam, Proton e desempenho, só se quiser', icone='applications-games', pagina='jogos'),
    dict(id='calendarios', nome='Calendários', desc='Google, iCloud e endereços iCal', icone='view-calendar', pagina='calendarios'),
    dict(id='janelas', nome='Janelas em zonas', desc='Encaixar janelas lado a lado e áreas de trabalho', icone='view-grid', pagina='janelas'),
    dict(id='cadeado', nome='Cadeado', desc='Pastas, arquivos e aplicativos com senha', icone='object-locked', pagina='cadeado'),
    dict(id='etiquetas', nome='Etiquetas', desc='Arquivos organizados por cores', icone='tag', cmd='xdg-open ' + os.path.join(HOME, 'Etiquetas')),
    dict(id='clipboard', nome='Histórico do Ctrl+C', desc='Tudo o que copiou (Meta+V)', icone='edit-paste', pagina='clipboard'),
    dict(id='drivers', nome='Drivers e hardware', desc='Placa de vídeo, Wi-Fi, impressoras, impressão digital', icone='preferences-devices-pci', pagina='drivers'),
    dict(id='entrada', nome='Tela de entrada', desc='A sua foto e a imagem de fundo do login', icone='preferences-desktop-user', pagina='entrada'),
    dict(id='firewall', nome='Firewall', desc='Ninguém da internet entra neste computador', icone='security-high', pagina='firewall'),
    dict(id='ssh', nome='Acesso remoto (SSH)', desc='Entrar neste computador a partir de outro', icone='network-server', pagina='ssh'),
    dict(id='privacidade', nome='Privacidade', desc='Sessão sem rastro e modo escuro em todo o lado', icone='preferences-system-privacy', pagina='privacidade'),
    dict(id='fundos', nome='Papéis de parede', desc='Dois claros e dois escuros', icone='preferences-desktop-wallpaper', cmd='carinaeos-configuracoes aparencia'),
    dict(id='boasvindas', nome='Boas-vindas', desc='Tudo o que o CarinaeOS tem, num passeio', icone='carinaeos', cmd='carinaeos-boasvindas'),
    dict(id='manual', nome='Manual do CarinaeOS', desc='Tudo: rede, discos, programas, música, terminal', icone='help-contents', cmd='carinaeos-manual'),
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


def lembretes_calendario():
    """Os lembretes do calendário (e o Akonadi por trás deles) só iniciam com a sessão depois de haver calendários."""
    subprocess.run(['kwriteconfig6', '--file', 'kalendaracrc', '--group', 'General', '--key', 'Autostart', 'true'], capture_output=True)
    if subprocess.run(['pgrep', '-x', 'kalendarac'], capture_output=True).returncode != 0:
        subprocess.Popen(['kalendarac'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def adicionar_ical(url, nome):
    """Baixa o calendario (carinaeos-calendarios) e liga o arquivo local ao Akonadi."""
    lembretes_calendario()
    r = subprocess.run(['carinaeos-calendarios', 'adicionar', url, nome], capture_output=True, text=True, timeout=90)
    if r.returncode != 0:
        raise RuntimeError((r.stderr.strip().splitlines() or ['não consegui baixar o calendário'])[-1].replace('ValueError: ', ''))
    arquivo, eventos = r.stdout.split()
    subprocess.run(['akonadictl', 'start'], capture_output=True, timeout=30)
    ident = None
    for _ in range(30):
        try:
            ident = criar_recurso('akonadi_ical_resource')
            break
        except Exception:
            __import__('time').sleep(1)
    if not ident:
        raise RuntimeError('o serviço de calendários (Akonadi) não arrancou')
    svc = 'org.freedesktop.Akonadi.Resource.' + ident
    for _ in range(30):
        try:
            qdbus(svc, '/Settings', 'org.kde.Akonadi.ICal.Settings.setPath', arquivo)
            break
        except Exception:
            __import__('time').sleep(0.5)
    else:
        raise RuntimeError('o serviço de calendários não respondeu')
    for metodo, valor in (('setReadOnly', 'true'), ('setMonitorFile', 'true'), ('setDisplayName', nome)):
        try:
            qdbus(svc, '/Settings', 'org.kde.Akonadi.ICal.Settings.' + metodo, valor)
        except Exception:
            pass
    qdbus(svc, '/Settings', 'org.kde.Akonadi.ICal.Settings.save')
    qdbus('org.freedesktop.Akonadi.Control', '/AgentManager',
          'org.freedesktop.Akonadi.AgentManager.setAgentInstanceName', ident, nome)
    try:
        qdbus('org.freedesktop.Akonadi.Agent.' + ident, '/', 'org.freedesktop.Akonadi.Agent.Control.reconfigure')
    except Exception:
        pass
    qdbus('org.freedesktop.Akonadi.Control', '/AgentManager',
          'org.freedesktop.Akonadi.AgentManager.agentInstanceSynchronize', ident)
    subprocess.run(['systemctl', '--user', 'enable', '--now', 'carinaeos-calendarios.timer'], capture_output=True)
    return int(eventos)


def configurar_conta(tipo):
    """Google ou CalDAV (iCloud): cria a conta e abre a janela de configuracao/autorizacao."""
    lembretes_calendario()
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
    'larga': dict(nome='Tela larga (1/4 · 1/2 · 1/4)', tiles={'layoutDirection': 'horizontal', 'tiles': [{'width': 0.25}, {'width': 0.5}, {'width': 0.25}]}),
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
def geracao_nvidia(nome):
    """'kepler' (GK…: precisa do 470), 'antiga' (Fermi e anteriores: sem controlador NVIDIA) ou 'atual'.
    O lspci mostra o nome do chip: "NVIDIA Corporation GK208B [GeForce GT 710]"."""
    m = re.search(r'\b(GK|GF|GT2|G8|G9|G7|G6|NV|MCP|GM|GP|GV|TU|GA|AD|GB|GH)\d', nome)
    if not m:
        return 'atual'
    p = m.group(1)
    if p == 'GK':
        return 'kepler'
    if p in ('GF', 'GT2', 'G8', 'G9', 'G7', 'G6', 'NV', 'MCP'):
        return 'antiga'
    return 'atual'


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
            ger = geracao_nvidia(g)
            if ger == 'kepler':
                # o Debian 13 já não traz controlador para a Kepler: o 470 vem do sid, com a sessão X11
                item('nvidia470', 'Placa de vídeo NVIDIA (Kepler)', g_curto, ['nvidia-tesla-470-driver'], 'nvidia',
                     'Controlador NVIDIA 470, o último que suporta esta placa. Só funciona na sessão X11 (fica escolhida '
                     'na tela de entrada). Reinicie depois de instalar.')
                itens[-1]['script'] = 'kepler'
            elif ger == 'antiga':
                item('nvidia-antiga', 'Placa de vídeo NVIDIA (antiga)', g_curto, [], 'nvidia',
                     'A NVIDIA já não tem controlador para esta placa. Fica com o controlador livre (nouveau), '
                     'que já vem com o sistema: dá para o dia a dia, mas não para jogos.')
            else:
                item('nvidia', 'Placa de vídeo NVIDIA', g_curto, ['nvidia-driver', 'firmware-misc-nonfree', 'nvidia-suspend-common'],
                     'nvidia', 'Controlador oficial da NVIDIA (GTX 750 em diante, RTX…): melhor desempenho em jogos e no Wayland. '
                     'Reinicie depois de instalar.' + (' Com gráficos Intel/AMD também (notebook), as janelas usam a placa '
                                                        'integrada e os jogos a NVIDIA.' if len(gpus) > 1 else ''))
                itens[-1]['script'] = 'atual'
        elif re.search(r'\bIntel\b', g, re.I):
            # (antes do AMD: "Intel CorporATIon" fazia-a passar por placa ATI)
            item('intel', 'Gráficos Intel', g_curto, ['intel-media-va-driver-non-free', 'mesa-vulkan-drivers'], 'video-display')
        elif re.search(r'\b(AMD|ATI)\b|Advanced Micro Devices|Radeon', g, re.I):
            item('amd', 'Placa de vídeo AMD', g_curto, ['firmware-amd-graphics', 'mesa-vulkan-drivers'], 'video-display')
        else:
            item('video', 'Placa de vídeo', g_curto, [], 'video-display')
    # Secure Boot: o controlador NVIDIA (DKMS) só carrega com a chave deste computador registada no firmware
    if (os.path.isdir('/sys/firmware/efi') and os.path.exists('/var/lib/dkms/mok.pub') and shutil.which('mokutil')
            and any(instalado(p) for p in ('nvidia-driver', 'nvidia-tesla-470-driver'))):
        t = subprocess.run(['mokutil', '--test-key', '/var/lib/dkms/mok.pub'], capture_output=True, text=True)
        estado = (t.stdout + t.stderr).lower()
        if 'already enrolled' not in estado:
            # o pedido (MokNew) só o administrador lê; basta ver se a variável existe
            import glob
            pendente = bool(glob.glob('/sys/firmware/efi/efivars/MokNew-*'))
            item('mok', 'Secure Boot: chave do controlador NVIDIA', 'Para a placa funcionar com o Secure Boot ligado',
                 ['chave'], 'security-high',
                 'Já pedida: reinicie e confirme na tela azul. Não sabe o código? Peça de novo.' if pendente else
                 'Registre a chave uma vez: na próxima reinicialização aparece uma tela azul onde escreve um código de 8 algarismos.')
            itens[-1]['script'] = 'mok'
            itens[-1]['falta'] = ['chave']
    if re.search(r'Network controller|Wireless', lspci) or re.search(r'Wireless|WLAN|802\.11', lsusb, re.I):
        item('wifi', 'Wi-Fi', 'Firmwares para Intel, Realtek, Atheros, Broadcom e MediaTek',
             ['firmware-iwlwifi', 'firmware-realtek', 'firmware-atheros', 'firmware-brcm80211', 'firmware-mediatek'], 'network-wireless')
    if re.search(r'Bluetooth', lsusb + lspci, re.I) or os.path.isdir('/sys/class/bluetooth'):
        item('bt', 'Bluetooth', 'Firmware e ferramentas', ['bluez', 'bluez-firmware'], 'preferences-system-bluetooth')
    item('impressoras', 'Impressoras e scanners', 'HP, Epson, Canon, Brother e as que funcionam sem driver (AirPrint)',
         ['cups', 'print-manager', 'printer-driver-all', 'hplip', 'sane-airscan', 'ipp-usb', 'skanlite'], 'printer')
    if re.search(r'fingerprint|Synaptics.*(FS|Prometheus)|Goodix|Elan.*Fingerprint|Validity', lsusb, re.I):
        item('digital', 'Leitor de impressão digital', 'Entrar e autorizar com o dedo', ['fprintd', 'libpam-fprintd'], 'fingerprint-gui',
             'Depois, registre o dedo em Configurações › Usuários.')
    if re.search(r'Logitech', lsusb, re.I):
        item('logitech', 'Mouse/teclado Logitech', 'Botões, bateria e receptor Unifying/Bolt', ['solaar'], 'input-mouse')
    if re.search(r'Razer|SteelSeries|Roccat|Corsair|Glorious', lsusb, re.I):
        item('ratos', 'Mouse de jogos', 'Botões, DPI e luzes (libratbag/Piper)', ['ratbagd', 'piper'], 'input-mouse')
    if re.search(r'Xbox|Sony.*(Controller|DualSense|DualShock)|8BitDo', lsusb, re.I):
        item('comandos', 'Controle de jogos', 'Xbox, PlayStation, 8BitDo', ['steam-devices'], 'input-gaming')
    return itens


# ---- jogos (nada vem instalado: só quem pedir) ---------------------------------------------------------
STEAM = 'com.valvesoftware.Steam'
EXTRAS_JOGOS = {'heroic': 'com.heroicgameslauncher.hgl', 'protonup': 'net.davidotek.pupgui2'}
SOBREPOR_STEAM = os.path.join(HOME, '.local/share/flatpak/overrides', STEAM)


def flatpaks():
    try:
        out = subprocess.run(['flatpak', 'list', '--columns=application,branch'], capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.SubprocessError):
        return set()
    r = set()
    for l in out.splitlines():
        a = l.split()
        if a:
            r.add(a[0])
            if len(a) > 1:
                r.add(a[0] + '//' + a[1])
    return r


def ambiente_steam():
    import configparser
    c = configparser.ConfigParser(interpolation=None)
    c.optionxform = str
    try:
        c.read(SOBREPOR_STEAM)
        return dict(c['Environment']) if c.has_section('Environment') else {}
    except (configparser.Error, OSError):
        return {}


def placa_kepler():
    try:
        out = subprocess.run(['lspci'], capture_output=True, text=True, timeout=10).stdout
    except (OSError, subprocess.SubprocessError):
        return False
    return any('NVIDIA' in l and geracao_nvidia(l) == 'kepler' for l in out.splitlines() if 'VGA' in l or '3D' in l)


def jogos_estado():
    f = flatpaks()
    amb = ambiente_steam()
    return dict(steam=STEAM in f, heroic=EXTRAS_JOGOS['heroic'] in f, protonup=EXTRAS_JOGOS['protonup'] in f,
                gamemode=os.path.exists('/usr/bin/gamemoded'),
                mangohudCamada=any(x.startswith('org.freedesktop.Platform.VulkanLayer.MangoHud') for x in f),
                mangohud=amb.get('MANGOHUD') == '1', desempenho='libgamemodeauto' in amb.get('LD_PRELOAD', ''),
                wined3d=amb.get('PROTON_USE_WINED3D') == '1', kepler=placa_kepler())


# ---- firewall (ufw) ------------------------------------------------------------------------------------
NOMES_FIREWALL = {'descoberta': 'Encontrar impressoras e computadores da rede', 'kdeconnect': 'KDE Connect (celular)',
                  'ssh': 'Acesso remoto (SSH)', 'partilha': 'Pastas compartilhadas', 'musica': 'Música para a rede (Home Assistant)'}


def firewall_estado():
    if not os.path.exists('/usr/sbin/ufw'):
        return -1
    try:
        for linha in open('/etc/ufw/ufw.conf'):
            if linha.strip().replace(' ', '').lower() == 'enabled=yes':
                return 1
    except OSError:
        pass
    return 0


def firewall_abertos():
    try:
        return [NOMES_FIREWALL.get(n, n) for n in open('/var/lib/carinaeos/firewall-abertos').read().split()]
    except OSError:
        return []


# ---- acesso remoto (SSH) ----------------------------------------------------------------------------
def ssh_estado():
    if not os.path.exists('/usr/sbin/sshd'):
        return -1
    r = subprocess.run(['systemctl', 'is-active', 'ssh'], capture_output=True, text=True)
    return 1 if r.stdout.strip() == 'active' else 0


def enderecos():
    try:
        r = subprocess.run(['hostname', '-I'], capture_output=True, text=True, timeout=5).stdout.split()
    except Exception:
        r = []
    return [ip for ip in r if ':' not in ip] or r[:2]


# ---- vindo do Windows ---------------------------------------------------------------------------------
# programa do Windows -> alternativa: (nome, descrição, flatpak ou '', .desktop do sistema que já a dá)
PROGRAMAS_WINDOWS = [
    ('Microsoft Office', 'OnlyOffice', 'Abre e grava .docx, .xlsx e .pptx com o mesmo visual', 'org.onlyoffice.desktopeditors', ''),
    ('Word, Excel (gratuito)', 'LibreOffice', 'Pacote de escritório completo', 'org.libreoffice.LibreOffice', 'libreoffice-startcenter.desktop'),
    ('Outlook', 'Thunderbird', 'E-mail, calendário e contatos', 'org.mozilla.Thunderbird', 'thunderbird.desktop'),
    ('Google Chrome', 'Google Chrome', 'O mesmo navegador, com a sua conta', 'com.google.Chrome', 'google-chrome.desktop'),
    ('Photoshop', 'GIMP', 'Editar fotos e imagens', 'org.gimp.GIMP', 'gimp.desktop'),
    ('Paint', 'KolourPaint', 'Desenho simples, como o Paint', 'org.kde.kolourpaint', 'org.kde.kolourpaint.desktop'),
    ('Illustrator', 'Inkscape', 'Desenho vetorial', 'org.inkscape.Inkscape', 'org.inkscape.Inkscape.desktop'),
    ('Premiere / CapCut', 'Kdenlive', 'Editar vídeos', 'org.kde.kdenlive', 'org.kde.kdenlive.desktop'),
    ('Lightroom', 'darktable', 'Revelar e organizar fotos', 'org.darktable.Darktable', 'org.darktable.darktable.desktop'),
    ('AutoCAD / SolidWorks', 'FreeCAD', 'Projeto mecânico 3D', 'org.freecad.FreeCAD', 'org.freecad.FreeCAD.desktop'),
    ('WhatsApp', 'ZapZap', 'O WhatsApp numa janela própria', 'com.rtosta.zapzap', ''),
    ('Spotify', 'Spotify', 'O mesmo Spotify', 'com.spotify.Client', ''),
    ('Discord', 'Discord', 'O mesmo Discord', 'com.discordapp.Discord', ''),
    ('Zoom', 'Zoom', 'O mesmo Zoom', 'us.zoom.Zoom', ''),
    ('OBS Studio', 'OBS Studio', 'Gravar a tela e transmitir', 'com.obsproject.Studio', ''),
    ('VS Code', 'Visual Studio Code', 'O mesmo editor de código', 'com.visualstudio.code', 'code.desktop'),
    ('Bloco de Notas, Notepad++', 'Kate', 'Já vem no CarinaeOS', '', 'org.kde.kate.desktop'),
    ('WinRAR, 7-Zip', 'Ark', 'Já vem no CarinaeOS: abre .zip, .rar, .7z', '', 'org.kde.ark.desktop'),
    ('Windows Media Player', 'VLC', 'Já vem no CarinaeOS: toca qualquer vídeo', '', 'vlc.desktop'),
    ('Explorador de Arquivos', 'Arquivos (Dolphin)', 'Já vem no CarinaeOS', '', 'org.kde.dolphin.desktop'),
    ('Programas .exe', 'Bottles', 'Dois cliques num .exe e o CarinaeOS oferece', 'com.usebottles.bottles', ''),
]
# pastas do Windows (C:\Users\nome\...) -> pastas do usuário aqui (xdg-user-dir)
PASTAS_WINDOWS = [('Desktop', 'DESKTOP', 'Área de Trabalho'), ('Documents', 'DOCUMENTS', 'Documentos'),
                  ('Pictures', 'PICTURES', 'Imagens'), ('Music', 'MUSIC', 'Músicas'), ('Videos', 'VIDEOS', 'Vídeos'),
                  ('Downloads', 'DOWNLOAD', 'Downloads')]


def programas_windows():
    f = flatpaks()
    r = []
    for win, alt, desc, fp, nativo in PROGRAMAS_WINDOWS:
        tem = (fp and fp in f) or (nativo and any(os.path.exists(os.path.join(p, nativo)) for p in
              ('/usr/share/applications', os.path.join(HOME, '.local/share/applications'))))
        r.append(dict(windows=win, nome=alt, desc=desc, flatpak=fp, instalado=bool(tem)))
    return r


def contas_windows():
    """Pastas de usuário do Windows em discos NTFS (o disco do Windows ou um disco externo).
    Monta só para leitura, com o udisks (pode pedir a senha num disco interno)."""
    try:
        j = json.loads(subprocess.run(['lsblk', '-J', '-o', 'PATH,FSTYPE,LABEL,SIZE,MOUNTPOINT'],
                                      capture_output=True, text=True, timeout=10).stdout)
    except (OSError, ValueError, subprocess.SubprocessError):
        return [], ''
    r, aviso = [], ''

    def todas(ds):
        for d in ds:
            yield d
            yield from todas(d.get('children') or [])
    for d in todas(j.get('blockdevices') or []):
        if (d.get('fstype') or '') not in ('ntfs', 'ntfs3', 'exfat', 'vfat'):
            continue
        mp = d.get('mountpoint')
        if not mp:
            p = subprocess.run(['udisksctl', 'mount', '-b', d['path'], '-o', 'ro', '--no-user-interaction'],
                               capture_output=True, text=True, timeout=30)
            if p.returncode != 0:
                p = subprocess.run(['udisksctl', 'mount', '-b', d['path'], '-o', 'ro'], capture_output=True, text=True, timeout=120)
            m = re.search(r' at (/\S+)', p.stdout)
            if not m:
                if 'hibernat' in (p.stderr or '').lower() or 'unclean' in (p.stderr or '').lower():
                    aviso = ('O disco do Windows está em hibernação (Início rápido). No Windows, desligue com Shift + Desligar, '
                             'ou desative o Início rápido, e volte aqui.')
                continue
            mp = m.group(1).rstrip('.')
        users = os.path.join(mp, 'Users')
        if not os.path.isdir(users):
            continue
        for u in sorted(os.listdir(users)):
            c = os.path.join(users, u)
            if u in ('Public', 'Default', 'Default User', 'All Users', 'defaultuser0') or not os.path.isdir(c) or os.path.islink(c):
                continue
            if not any(os.path.isdir(os.path.join(c, x[0])) for x in PASTAS_WINDOWS):
                continue
            r.append(dict(caminho=c, nome=u, disco=(d.get('label') or d['path']) + ' · ' + (d.get('size') or '')))
    return r, aviso


# ---- celular (KDE Connect) -------------------------------------------------------------------------------
KDC = 'org.kde.kdeconnect'


def _kdc_prop(caminho, interface, nome):
    try:
        r = subprocess.run(['qdbus6', KDC, caminho, 'org.freedesktop.DBus.Properties.Get', interface, nome],
                           capture_output=True, text=True, timeout=4)
        return r.stdout.strip() if r.returncode == 0 else ''
    except (OSError, subprocess.SubprocessError):
        return ''


def celulares():
    """Aparelhos do KDE Connect: nome, ligado (pareado e ao alcance), pareado, bateria, e se deixa ver os arquivos
    (o iPhone não deixa: a Apple não permite SFTP nem trabalho em segundo plano)."""
    def ids(*opc):
        try:
            r = subprocess.run(['kdeconnect-cli', '--id-name-only'] + list(opc), capture_output=True, text=True, timeout=8)
        except (OSError, subprocess.SubprocessError):
            return {}
        d = {}
        for l in r.stdout.splitlines():
            if ' ' in l.strip():
                i, n = l.strip().split(' ', 1)
                d[i] = n
        return d
    todos, ao_alcance = ids('-l'), ids('-a')
    r = []
    for i, nome in todos.items():
        caminho = '/modules/kdeconnect/devices/' + i
        pareado = i in ao_alcance or _kdc_prop(caminho, 'org.kde.kdeconnect.device', 'isPaired') == 'true' \
            or _kdc_prop(caminho, 'org.kde.kdeconnect.device', 'pairState') == '3'
        plugins = _kdc_prop(caminho, 'org.kde.kdeconnect.device', 'supportedPlugins')
        bat = _kdc_prop(caminho + '/battery', 'org.kde.kdeconnect.device.battery', 'charge') if i in ao_alcance else ''
        tipo = _kdc_prop(caminho, 'org.kde.kdeconnect.device', 'type')
        r.append(dict(id=i, nome=nome, ligado=i in ao_alcance, pareado=pareado,
                      bateria=int(bat) if bat.lstrip('-').isdigit() and int(bat) >= 0 else -1,
                      arquivos='kdeconnect_sftp' in plugins, tipo=tipo or 'smartphone'))
    r.sort(key=lambda x: (not x['ligado'], not x['pareado'], x['nome'].lower()))
    return r


def samba_ligado():
    try:
        return subprocess.run(['systemctl', 'is-active', 'smbd'], capture_output=True, text=True, timeout=5).stdout.strip() == 'active'
    except (OSError, subprocess.SubprocessError):
        return False


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
        self._jogos = {}
        self._celular = {}
        self._windows = {}
        self._passo.connect(self._mostrar_passo)

    ferramentas = Property('QVariantList', lambda s: FERRAMENTAS, constant=True)
    paginaInicial = Property(str, lambda s: s._pagina, constant=True)
    calendarios = Property('QVariantList', lambda s: s._cals, notify=mudou)
    hardware = Property('QVariantList', lambda s: s._hw, notify=mudou)
    mensagem = Property(str, lambda s: s._msg, notify=mudou)
    ocupado = Property(bool, lambda s: s._ocupado, notify=mudou)
    zonas = Property('QVariantList', lambda s: [dict(id=k, nome=v['nome'], tiles=json.dumps(v['tiles'])) for k, v in ZONAS.items()], constant=True)
    escuroForcado = Property(bool, lambda s: escuro_forcado(), notify=mudou)
    convidado = Property(int, lambda s: {None: -1, False: 0, True: 1}[convidado_ativo()], notify=mudou)
    jogos = Property('QVariantMap', lambda s: s._jogos, notify=mudou)
    celular = Property('QVariantMap', lambda s: s._celular, notify=mudou)
    windows = Property('QVariantMap', lambda s: s._windows, notify=mudou)
    firewall = Property(int, lambda s: firewall_estado(), notify=mudou)
    firewallAbertos = Property('QVariantList', lambda s: firewall_abertos(), notify=mudou)
    ssh = Property(int, lambda s: ssh_estado(), notify=mudou)
    sshEnderecos = Property('QVariantList', lambda s: enderecos(), notify=mudou)
    usuario = Property(str, lambda s: os.environ.get('USER') or os.path.basename(HOME), constant=True)
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
            self._fim(lambda n: 'Calendário “%s” adicionado ✓ %d eventos. Aparece no Calendário e no relógio da barra; atualiza a cada 30 min.' % (nome or 'novo', n))(r)
            self.lerCalendarios()
        self._fundo(lambda: adicionar_ical(url, nome.strip() or 'Calendário'), depois, 'Adicionando o calendário…')

    @Slot(str)
    def conta(self, tipo):
        recurso = {'google': 'akonadi_google_resource', 'caldav': 'akonadi_davgroupware_resource'}[tipo]

        def depois(r):
            self._fim('Abri a janela da conta: siga os passos para entrar e autorizar.')(r)
            self.lerCalendarios()
        self._fundo(lambda: configurar_conta(recurso), depois, 'Preparando a conta…')

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
        self._fundo(hardware, depois, 'Vendo o que este computador tem…')

    @Slot(str)
    def instalarDriver(self, ident):
        it = next((h for h in self._hw if h['id'] == ident), None)
        if not it or not it['falta']:
            return
        # cada ação com o seu próprio ajudante e mensagem (nunca um "bash como administrador" genérico)
        cmd = ['pkexec', '/usr/lib/carinaeos/instalar-pacotes'] + list(it['falta'])
        if it.get('script'):
            cmd = ['pkexec', '/usr/lib/carinaeos/placa-video', it['script']]

        def depois(r):
            self._fim(lambda _: '%s: instalado ✓%s' % (it['nome'], ' Reinicie o computador.' if ident.startswith('nvidia') else ''))(r)
            m = re.search(r'^MOK:(\d+)$', r, re.M) if isinstance(r, str) else None
            if m:       # Secure Boot: mostra o código para o ecrã azul do próximo arranque
                self._mok = m.group(1)
                self.mudou.emit()
            self.lerHardware()

        def trabalho():
            p = subprocess.run(cmd, capture_output=True, text=True)
            if p.returncode != 0:
                raise RuntimeError((p.stdout + p.stderr).strip().splitlines()[-1] if (p.stdout + p.stderr).strip() else 'cancelado')
            return p.stdout
        self._fundo(trabalho, depois, 'Instalando %s… (o sistema pede a sua senha)' % it['nome'])

    codigoMok = Property(str, lambda s: getattr(s, '_mok', ''), notify=mudou)

    @Slot()
    def esquecerMok(self):
        self._mok = ''
        self.mudou.emit()

    # tela de entrada
    fotoUsuario = Property(str, lambda s: s._foto(), notify=mudou)

    def _foto(self):
        for f in ('/var/lib/AccountsService/icons/' + os.environ.get('USER', ''), os.path.join(HOME, '.face.icon'),
                  os.path.join(HOME, '.face')):
            if os.path.exists(f) and os.access(f, os.R_OK):
                return 'file://' + f + '?%d' % int(os.path.getmtime(f))
        return ''

    @Slot(str)
    def escolherImagem(self, para):
        """Janela de escolha do proprio sistema (Meus documentos), em vez da do Qt."""
        titulo = 'Escolha a sua foto' if para == 'foto' else 'Escolha a imagem da tela de entrada'
        pasta = os.path.join(HOME, 'Imagens') if os.path.isdir(os.path.join(HOME, 'Imagens')) else HOME

        def trabalho():
            return subprocess.run(['carinae-escolher', 'ficheiro', titulo, pasta, 'Imagens',
                                   '*.jpg *.jpeg *.png *.webp *.bmp'], capture_output=True, text=True)

        def depois(r):
            self._ocupado = False
            self._msg = ''
            self.mudou.emit()
            if isinstance(r, Exception) or r.returncode != 0 or not r.stdout.strip():
                return
            url = 'file://' + r.stdout.strip()
            (self.definirFoto if para == 'foto' else self.definirFundoEntrada)(url)
        self._fundo(trabalho, depois)

    @Slot(str)
    def definirFoto(self, url):
        caminho = url.replace('file://', '')

        def trabalho():
            from PIL import Image
            im = Image.open(caminho).convert('RGB')
            lado = min(im.size)
            im = im.crop(((im.width - lado) // 2, (im.height - lado) // 2, (im.width + lado) // 2, (im.height + lado) // 2))
            im = im.resize((512, 512), Image.LANCZOS)
            face = os.path.join(HOME, '.face.icon')
            im.save(face, 'PNG')
            os.chmod(face, 0o644)
            try:
                os.remove(os.path.join(HOME, '.face'))
            except OSError:
                pass
            os.symlink(face, os.path.join(HOME, '.face'))
            r = subprocess.run(['busctl', 'call', 'org.freedesktop.Accounts', '/org/freedesktop/Accounts/User%d' % os.getuid(),
                                'org.freedesktop.Accounts.User', 'SetIconFile', 's', face], capture_output=True, text=True)
            if r.returncode != 0:
                raise RuntimeError(r.stderr.strip() or 'o serviço de contas recusou')
        self._fundo(trabalho, self._fim('Foto mudada ✓ Aparece na tela de entrada e no menu.'))

    @Slot(str)
    def definirFundoEntrada(self, url):
        caminho = url.replace('file://', '')
        self._fundo(lambda: subprocess.run(['pkexec', '/usr/lib/carinaeos/fundo-entrada', caminho], check=True),
                    self._fim('Fundo da tela de entrada mudado ✓ Vê-o na próxima vez que entrar.'), 'Salvando…')

    @Slot()
    def reporFundoEntrada(self):
        self._fundo(lambda: subprocess.run(['pkexec', '/usr/lib/carinaeos/fundo-entrada', '--repor'], check=True),
                    self._fim('A tela de entrada voltou ao fundo do CarinaeOS ✓'))

    # privacidade
    @Slot(bool)
    def definirEscuro(self, ligar):
        self._fundo(lambda: definir_escuro(ligar), self._fim(
            'Modo escuro forçado %s ✓ Feche e abra os navegadores para ver.' % ('ligado' if ligar else 'desligado')))

    @Slot(bool)
    def definirSSH(self, ligar):
        cmd = ['pkexec', '/usr/lib/carinaeos/ssh', 'ligar' if ligar else 'desligar']
        self._fundo(lambda: subprocess.run(cmd, check=True), self._fim(
            'Acesso remoto %s ✓' % ('ligado' if ligar else 'desligado')),
            'Instalando e ligando o servidor SSH…' if ligar and ssh_estado() < 0 else '')

    # jogos
    _passo = Signal(str)

    def _mostrar_passo(self, texto):
        self._msg = texto
        self.mudou.emit()

    @Slot()
    def lerJogos(self):
        def depois(r):
            self._ocupado = False
            self._jogos = r if isinstance(r, dict) else {}
            self.mudou.emit()
        self._fundo(jogos_estado, depois)

    @Slot(bool, bool)
    def prepararJogos(self, heroic, protonup):
        def trabalho():
            def corre(args, texto):
                self._passo.emit(texto)
                p = subprocess.run(args, capture_output=True, text=True)
                if p.returncode != 0:
                    raise RuntimeError((p.stderr or p.stdout).strip().splitlines()[-1:] or ['falhou'])
                return p.stdout
            # do sistema, só o pequeno: GameMode (desempenho) e as regras dos comandos (steam-devices)
            if not os.path.exists('/usr/bin/gamemoded') or not os.path.exists('/usr/lib/udev/rules.d/60-steam-input.rules'):
                corre(['pkexec', '/usr/lib/carinaeos/instalar-pacotes', 'gamemode', 'steam-devices'],
                      'Instalando o GameMode e o suporte a comandos (pede a senha)…')
            corre(['flatpak', 'remote-add', '--user', '--if-not-exists', 'flathub',
                   'https://dl.flathub.org/repo/flathub.flatpakrepo'], 'Ligando ao Flathub…')
            # o Steam vem isolado (Flatpak): não mexe nas bibliotecas do sistema e sai por inteiro ao remover
            corre(['flatpak', 'install', '--user', '-y', '--noninteractive', 'flathub', STEAM],
                  'Baixando o Steam (pode levar alguns minutos)…')
            rt = corre(['flatpak', 'info', '--show-runtime', STEAM], 'Preparando o MangoHud…').strip()
            ramo = rt.split('/')[-1] if rt else ''
            if ramo:
                corre(['flatpak', 'install', '--user', '-y', '--noninteractive', 'flathub',
                       'org.freedesktop.Platform.VulkanLayer.MangoHud//' + ramo], 'Instalando o MangoHud…')
            if heroic:
                corre(['flatpak', 'install', '--user', '-y', '--noninteractive', 'flathub', EXTRAS_JOGOS['heroic']],
                      'Baixando o Heroic (Epic e GOG)…')
            if protonup:
                corre(['flatpak', 'install', '--user', '-y', '--noninteractive', 'flathub', EXTRAS_JOGOS['protonup']],
                      'Baixando o ProtonUp-Qt…')
            if placa_kepler():
                # placa sem Vulkan 1.3: os jogos do Windows vão pelo WineD3D (OpenGL) em vez do DXVK
                subprocess.run(['flatpak', 'override', '--user', '--env=PROTON_USE_WINED3D=1', STEAM])
            return jogos_estado()

        def depois(r):
            self._ocupado = False
            if isinstance(r, Exception):
                self._msg = 'Não funcionou: %s' % r
            else:
                self._jogos = r
                self._msg = 'Pronto para jogar ✓ Abra o Steam e entre na sua conta.'
            self.mudou.emit()
        self._fundo(trabalho, depois, 'Começando…')

    @Slot(str, bool)
    def definirJogos(self, chave, ligar):
        var = {'mangohud': 'MANGOHUD=1', 'desempenho': 'LD_PRELOAD=libgamemodeauto.so.0',
               'wined3d': 'PROTON_USE_WINED3D=1'}.get(chave)
        if not var:
            return
        nome = var.split('=')[0]
        args = ['--env=' + var] if ligar else ['--unset-env=' + nome]
        subprocess.run(['flatpak', 'override', '--user'] + args + [STEAM], capture_output=True)
        self._jogos = jogos_estado()
        self.mudou.emit()

    @Slot()
    def removerJogos(self):
        def trabalho():
            f = flatpaks()
            apps = [a for a in [STEAM] + list(EXTRAS_JOGOS.values()) if a in f]
            if apps:
                subprocess.run(['flatpak', 'uninstall', '--user', '-y', '--noninteractive'] + apps, capture_output=True)
            subprocess.run(['flatpak', 'override', '--user', '--reset', STEAM], capture_output=True)
            subprocess.run(['flatpak', 'uninstall', '--user', '-y', '--noninteractive', '--unused'], capture_output=True)
            return jogos_estado()

        def depois(r):
            self._ocupado = False
            self._jogos = r if isinstance(r, dict) else self._jogos
            self._msg = 'Não funcionou: %s' % r if isinstance(r, Exception) else \
                'Steam e extras removidos ✓ Os jogos baixados ficam em ~/.var/app/com.valvesoftware.Steam (apague se quiser o espaço).'
            self.mudou.emit()
        self._fundo(trabalho, depois, 'Removendo…')

    @Slot(bool)
    def definirFirewall(self, ligar):
        cmd = ['pkexec', '/usr/lib/carinaeos/firewall', 'ligar' if ligar else 'desligar']
        self._fundo(lambda: subprocess.run(cmd, check=True, capture_output=True), self._fim(
            'Firewall %s ✓' % ('ligado' if ligar else 'desligado')))

    # vindo do Windows
    @Slot()
    def lerWindows(self):
        def depois(r):
            self._ocupado = False
            self._windows = dict(self._windows, programas=r if isinstance(r, list) else [])
            self.mudou.emit()
        self._fundo(programas_windows, depois)

    @Slot()
    def procurarWindows(self):
        def depois(r):
            self._ocupado = False
            contas, aviso = r if isinstance(r, tuple) else ([], '')
            self._windows = dict(self._windows, contas=contas, procurado=True)
            self._msg = aviso or ('' if contas else 'Não encontrei nenhum Windows nem disco com pastas do Windows. '
                                  'Ligue o disco externo onde fez a cópia e procure de novo.')
            self.mudou.emit()
        self._fundo(contas_windows, depois, 'Procurando o Windows nos discos…')

    @Slot(str)
    def trazerWindows(self, origem):
        if not os.path.isdir(origem) or '/Users/' not in origem:
            return

        def trabalho():
            feitas = []
            for win, xdg, nome in PASTAS_WINDOWS:
                o = os.path.join(origem, win)
                if not os.path.isdir(o):
                    continue
                dest = subprocess.run(['xdg-user-dir', xdg], capture_output=True, text=True).stdout.strip() or os.path.join(HOME, nome)
                os.makedirs(dest, exist_ok=True)
                self._passo.emit('Copiando %s… (os arquivos que já existem aqui ficam como estão)' % nome)
                # cópia sem apagar nem substituir nada; sem os atalhos e lixo do Windows
                subprocess.run(['rsync', '-rt', '--ignore-existing', '--no-perms', '--exclude=desktop.ini',
                                '--exclude=Thumbs.db', '--exclude=*.lnk', '--exclude=$RECYCLE.BIN',
                                '--exclude=My Music', '--exclude=My Pictures', '--exclude=My Videos',
                                o + '/', dest + '/'], capture_output=True)
                feitas.append(nome)
            return feitas

        def depois(r):
            self._ocupado = False
            self._msg = ('Não funcionou: %s' % r) if isinstance(r, Exception) else \
                ('Pronto ✓ Trouxe: %s. Nada foi apagado do Windows.' % ', '.join(r) if r else 'Não havia pastas para trazer.')
            self.mudou.emit()
        self._fundo(trabalho, depois, 'Começando a cópia…')

    @Slot(str)
    def instalarPrograma(self, fp):
        if not re.fullmatch(r'[A-Za-z0-9._-]+', fp):
            return

        def trabalho():
            self._passo.emit('Baixando… (pode levar alguns minutos)')
            subprocess.run(['flatpak', 'remote-add', '--user', '--if-not-exists', 'flathub',
                            'https://dl.flathub.org/repo/flathub.flatpakrepo'], capture_output=True)
            p = subprocess.run(['flatpak', 'install', '--user', '-y', '--noninteractive', 'flathub', fp],
                               capture_output=True, text=True)
            if p.returncode != 0:
                raise RuntimeError(((p.stderr or p.stdout).strip().splitlines() or ['sem internet?'])[-1])
            return programas_windows()

        def depois(r):
            self._ocupado = False
            if isinstance(r, Exception):
                self._msg = 'Não funcionou: %s' % r
            else:
                self._windows = dict(self._windows, programas=r)
                self._msg = 'Instalado ✓ Já aparece no Launchpad.'
            self.mudou.emit()
        self._fundo(trabalho, depois, 'Começando…')

    # celular (KDE Connect)
    @Slot()
    def lerCelular(self):
        def ler():
            ips = enderecos()
            return dict(aparelhos=celulares(), samba=samba_ligado(), ip=ips[0] if ips else '',
                        instalado=os.path.exists('/usr/bin/kdeconnect-cli'))

        def depois(r):
            self._ocupado = False
            self._celular = r if isinstance(r, dict) else {}
            self.mudou.emit()
        self._fundo(ler, depois)

    @Slot(str, str)
    def celularAcao(self, ident, acao):
        if not re.fullmatch(r'[A-Za-z0-9_{}-]+', ident):
            return
        nome = next((a['nome'] for a in self._celular.get('aparelhos', []) if a['id'] == ident), 'o celular')

        def trabalho():
            base = ['kdeconnect-cli', '-d', ident]
            if acao == 'tocar':
                subprocess.run(base + ['--ring'], check=True, capture_output=True, timeout=15)
                return 'O %s está tocando ✓' % nome
            if acao == 'texto':
                txt = subprocess.run(['qdbus6', 'org.kde.klipper', '/klipper', 'getClipboardContents'],
                                     capture_output=True, text=True, timeout=5).stdout.rstrip('\n')
                if not txt.strip():
                    return 'Não há texto copiado (copie algo com Ctrl+C e tente de novo).'
                subprocess.run(base + ['--share-text', txt], check=True, capture_output=True, timeout=15)
                return 'Texto enviado para o %s ✓' % nome
            if acao == 'arquivo':
                r = subprocess.run(['zenity', '--file-selection', '--multiple', '--separator=\n',
                                    '--title=Enviar para ' + nome, '--filename=' + HOME + '/'], capture_output=True, text=True)
                arqs = [a for a in r.stdout.splitlines() if a.strip()]
                if not arqs:
                    return ''
                for a in arqs:
                    subprocess.run(base + ['--share', a], check=True, capture_output=True, timeout=60)
                return '%d arquivo(s) enviados para o %s ✓' % (len(arqs), nome)
            if acao == 'ver':
                subprocess.Popen(['dolphin', '--new-window', 'kdeconnect://' + ident], start_new_session=True)
                return ''
            if acao == 'parear':
                subprocess.Popen(['kdeconnect-app'], start_new_session=True)
                return ''
            return ''

        def depois(r):
            self._ocupado = False
            self._msg = ('Não funcionou: o celular está com o KDE Connect aberto e na mesma rede?'
                         if isinstance(r, Exception) else r)
            self.mudou.emit()
        self._fundo(trabalho, depois)

    @Slot()
    def lerSSH(self):
        self.mudou.emit()

    @Slot(bool)
    def definirConvidado(self, ligar):
        cmd = ['pkexec', '/usr/lib/carinaeos/convidado', 'ligar' if ligar else 'desligar']
        self._fundo(lambda: subprocess.run(cmd, check=True), self._fim(
            'Sessão sem rastro %s ✓' % ('disponível na tela de entrada' if ligar else 'desligada')))


if __name__ == '__main__':
    pag = sys.argv[1] if len(sys.argv) > 1 else ''
    sys.exit(iniciar('carinaeos-central', 'Central CarinaeOS', 'carinaeos', os.path.join(AQUI, 'Main.qml'),
                     {'central': Central(pag)}))
