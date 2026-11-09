#!/usr/bin/python3
# CarinaeOS - Orbita: loja de aplicativos (Flathub), instalacao num clique.
# Os aplicativos ficam na conta do utilizador (flatpak --user): nao e preciso
# senha de administrador e aparecem logo no Launchpad.
import os
import re
import shlex
import sys

sys.path.insert(0, '/usr/share/carinaeos/comum')
from base import correr, iniciar  # noqa: E402

from PySide6.QtCore import Property, QObject, QProcess, QTimer, Signal, Slot  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
FLATHUB = 'https://dl.flathub.org/repo/flathub.flatpakrepo'
ICONES = [os.path.expanduser('~/.local/share/flatpak/appstream/flathub/x86_64/active/icons/128x128'),
          '/var/lib/flatpak/appstream/flathub/x86_64/active/icons/128x128']

# ---- vitrine: os aplicativos que as pessoas mais procuram ------------------
C = [
    ('navegadores', 'Navegadores', 'internet-web-browser', [
        ('com.google.Chrome', 'Google Chrome', 'O navegador do Google, rápido e com sincronização.'),
        ('org.mozilla.firefox', 'Firefox', 'Navegador livre, focado em privacidade.'),
        ('com.brave.Browser', 'Brave', 'Navegador com bloqueio de anúncios integrado.'),
        ('com.microsoft.Edge', 'Microsoft Edge', 'O navegador da Microsoft.'),
        ('com.opera.Opera', 'Opera', 'Navegador com VPN e mensageiros na barra lateral.'),
        ('com.vivaldi.Vivaldi', 'Vivaldi', 'Navegador muito personalizável.'),
    ]),
    ('escritorio', 'Escritório', 'x-office-document', [
        ('org.libreoffice.LibreOffice', 'LibreOffice', 'Texto, planilhas e apresentações, compatível com Office.'),
        ('org.onlyoffice.desktopeditors', 'ONLYOFFICE', 'Editor de documentos com visual parecido com o Office.'),
        ('md.obsidian.Obsidian', 'Obsidian', 'Notas e conhecimento pessoal em Markdown.'),
        ('org.mozilla.Thunderbird', 'Thunderbird', 'E-mail, agenda e contatos.'),
        ('com.github.xournalpp.xournalpp', 'Xournal++', 'Anotar PDFs e escrever à mão.'),
    ]),
    ('comunicacao', 'Comunicação', 'internet-chat', [
        ('com.discordapp.Discord', 'Discord', 'Voz, vídeo e chat com amigos e comunidades.'),
        ('org.telegram.desktop', 'Telegram', 'Mensagens rápidas e seguras.'),
        ('io.github.mimbrero.WhatsAppDesktop', 'WhatsApp', 'WhatsApp no computador (cliente não oficial).'),
        ('org.signal.Signal', 'Signal', 'Mensagens privadas e criptografadas.'),
        ('us.zoom.Zoom', 'Zoom', 'Reuniões e videochamadas.'),
        ('com.slack.Slack', 'Slack', 'Comunicação para equipes.'),
    ]),
    ('midia', 'Música e vídeo', 'applications-multimedia', [
        ('com.spotify.Client', 'Spotify', 'Música e podcasts.'),
        ('org.videolan.VLC', 'VLC', 'Toca qualquer vídeo ou música.'),
        ('com.obsproject.Studio', 'OBS Studio', 'Gravar a tela e fazer transmissões ao vivo.'),
        ('org.kde.kdenlive', 'Kdenlive', 'Editor de vídeo completo.'),
        ('org.audacityteam.Audacity', 'Audacity', 'Gravar e editar áudio.'),
        ('com.stremio.Stremio', 'Stremio', 'Central de filmes e séries.'),
    ]),
    ('jogos', 'Jogos', 'applications-games', [
        ('com.valvesoftware.Steam', 'Steam', 'A maior loja de jogos para PC.'),
        ('com.heroicgameslauncher.hgl', 'Heroic', 'Jogos da Epic Games e GOG.'),
        ('net.lutris.Lutris', 'Lutris', 'Todos os seus jogos num só lugar.'),
        ('org.prismlauncher.PrismLauncher', 'Prism Launcher', 'Minecraft com mods, fácil.'),
        ('io.github.ryubing.Ryujinx', 'Ryujinx', 'Emulador de consoles.'),
    ]),
    ('criacao', 'Criação', 'applications-graphics', [
        ('org.gimp.GIMP', 'GIMP', 'Edição de imagens e fotos.'),
        ('org.kde.krita', 'Krita', 'Pintura digital profissional.'),
        ('org.inkscape.Inkscape', 'Inkscape', 'Desenho vetorial.'),
        ('org.blender.Blender', 'Blender', 'Modelagem e animação 3D.'),
        ('com.github.PintaProject.Pinta', 'Pinta', 'Desenho simples, como o Paint.'),
    ]),
    ('dev', 'Programação', 'applications-development', [
        ('com.visualstudio.code', 'Visual Studio Code', 'Editor de código da Microsoft.'),
        ('io.podman_desktop.PodmanDesktop', 'Podman Desktop', 'Contêineres de forma visual.'),
        ('com.jetbrains.PyCharm-Community', 'PyCharm', 'Programar em Python.'),
        ('io.dbeaver.DBeaverCommunity', 'DBeaver', 'Gerenciar bancos de dados.'),
    ]),
    ('utilitarios', 'Utilitários', 'applications-utilities', [
        ('com.anydesk.Anydesk', 'AnyDesk', 'Acesso remoto a outros computadores.'),
        ('com.rustdesk.RustDesk', 'RustDesk', 'Acesso remoto livre.'),
        ('org.qbittorrent.qBittorrent', 'qBittorrent', 'Downloads por torrent.'),
        ('com.github.tchx84.Flatseal', 'Flatseal', 'Permissões dos aplicativos.'),
        ('io.github.peazip.PeaZip', 'PeaZip', 'Compactar e extrair arquivos.'),
        ('com.bitwarden.desktop', 'Bitwarden', 'Gerenciador de senhas.'),
    ]),
]
DESTAQUES = ['com.google.Chrome', 'org.libreoffice.LibreOffice', 'com.spotify.Client',
             'com.discordapp.Discord', 'com.valvesoftware.Steam', 'com.visualstudio.code']


def icone_de(ident):
    for d in ICONES:
        f = os.path.join(d, ident + '.png')
        if os.path.exists(f):
            return f
    return ''


class Orbita(QObject):
    mudou = Signal()
    aviso = Signal(str)

    def __init__(self):
        super().__init__()
        self._instalados = set()
        self._fila = {}            # id -> 'instalando' | 'removendo'
        self._progresso = {}       # id -> 0..100
        self._detalhe = {}         # id -> texto curto (MB baixados, passo)
        self._rede0 = {}           # id -> bytes recebidos no inicio
        self._passo = {}           # id -> 'n/m'
        self._ao_vivo = 'boot=live' in open('/proc/cmdline').read()
        self._relogio = QTimer(self)
        self._relogio.setInterval(1000)
        self._relogio.timeout.connect(self._medir)
        self._pronto = False
        self._estado = 'A preparar a loja…'
        self._resultados = []
        self._proc = {}
        self._buscador = None
        QTimer.singleShot(0, self.preparar)

    # ---- preparar: Flathub + catalogo local -----------------------------------
    def preparar(self):
        p = QProcess(self)
        p.setProgram('sh')
        p.setArguments(['-c',
                        'flatpak remote-add --user --if-not-exists flathub %s && '
                        'flatpak update --user --appstream flathub' % FLATHUB])
        p.finished.connect(lambda *a: self._preparado(p))
        p.start()
        self.ler_instalados()

    def _preparado(self, p):
        self._pronto = True
        self._estado = '' if p.exitCode() == 0 else 'Sem ligação à internet: ligue-se para instalar aplicativos.'
        self.mudou.emit()

    def ler_instalados(self):
        c, s = correr(['flatpak', 'list', '--app', '--columns=application'])
        self._instalados = set(s.split()) if c == 0 else set()
        self.mudou.emit()

    # ---- dados para a interface ----------------------------------------------
    def _app(self, ident, nome, desc):
        return dict(id=ident, nome=nome, desc=desc, icone=icone_de(ident),
                    instalado=ident in self._instalados,
                    fila=self._fila.get(ident, ''), progresso=self._progresso.get(ident, 0),
                    detalhe=self._detalhe.get(ident, ''))

    def _categorias(self):
        return [dict(id=cid, nome=nome, icone=ic, apps=[self._app(*a) for a in apps]) for cid, nome, ic, apps in C]

    def _destaques(self):
        todos = {a[0]: a for _, _, _, apps in C for a in apps}
        return [self._app(*todos[i]) for i in DESTAQUES if i in todos]

    def _meus(self):
        conhecidos = {a[0]: a for _, _, _, apps in C for a in apps}
        r = []
        for i in sorted(self._instalados):
            a = conhecidos.get(i, (i, i.split('.')[-1], ''))
            r.append(self._app(*a))
        return r

    categorias = Property('QVariantList', _categorias, notify=mudou)
    destaques = Property('QVariantList', _destaques, notify=mudou)
    meus = Property('QVariantList', _meus, notify=mudou)
    resultados = Property('QVariantList', lambda s: [s._app(*a) for a in s._resultados], notify=mudou)
    estado = Property(str, lambda s: s._estado, notify=mudou)
    pronto = Property(bool, lambda s: s._pronto, notify=mudou)
    aoVivo = Property(bool, lambda s: s._ao_vivo, constant=True)

    # ---- acoes -----------------------------------------------------------------
    @staticmethod
    def _bytes_rede():
        # total recebido em todas as interfaces (menos lo): mostra quanto ja baixou
        total = 0
        try:
            for l in open('/proc/net/dev').readlines()[2:]:
                nome, dados = l.split(':', 1)
                if nome.strip() != 'lo':
                    total += int(dados.split()[0])
        except Exception:
            pass
        return total

    def _medir(self):
        if not self._fila:
            self._relogio.stop()
            return
        agora = self._bytes_rede()
        for ident, tipo in self._fila.items():
            if tipo != 'instalando':
                continue
            mb = max(0, agora - self._rede0.get(ident, agora)) / 1048576
            partes = []
            if self._passo.get(ident):
                partes.append('passo ' + self._passo[ident])
            partes.append(('%.0f MB' % mb) if mb < 1000 else ('%.2f GB' % (mb / 1024)))
            self._detalhe[ident] = ' · '.join(partes)
        self.mudou.emit()

    def _correr_flatpak(self, ident, args, tipo):
        self._fila[ident] = tipo
        self._progresso[ident] = 0
        self._detalhe[ident] = 'a preparar…'
        self._passo.pop(ident, None)
        self._rede0[ident] = self._bytes_rede()
        self.mudou.emit()
        p = QProcess(self)
        p.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        env = p.processEnvironment()
        if env.isEmpty():
            from PySide6.QtCore import QProcessEnvironment
            env = QProcessEnvironment.systemEnvironment()
        env.insert('COLUMNS', '200')
        env.insert('LC_ALL', 'C.UTF-8')       # mensagens previsiveis para ler o progresso
        p.setProcessEnvironment(env)
        p.readyReadStandardOutput.connect(lambda: self._ler_progresso(ident, p))
        p.finished.connect(lambda codigo, *a: self._terminou(ident, tipo, codigo, p))
        self._proc[ident] = p
        # o flatpak so mostra a percentagem quando acha que esta num terminal:
        # o "script" da-lhe um terminal falso, e lemos a saida dele.
        cmd = ' '.join(['flatpak'] + [shlex.quote(a) for a in args])
        p.start('script', ['-qfec', cmd, '/dev/null'])
        self._relogio.start()

    def _ler_progresso(self, ident, p):
        txt = bytes(p.readAllStandardOutput()).decode(errors='ignore')
        self._saida = getattr(self, '_saida', {})
        self._saida[ident] = (self._saida.get(ident, '') + txt)[-4000:]
        m = re.findall(r'(\d{1,3})%', txt)
        if m:
            self._progresso[ident] = min(100, int(m[-1]))
        n = re.findall(r'(?:Installing|Updating|Uninstalling|Instalando|A instalar)\s+(\d+)/(\d+)', txt)
        if n:
            self._passo[ident] = '%s/%s' % n[-1]
        if m or n:
            self.mudou.emit()

    def _terminou(self, ident, tipo, codigo, p):
        self._fila.pop(ident, None)
        self._proc.pop(ident, None)
        self._detalhe.pop(ident, None)
        if codigo != 0:
            bruto = getattr(self, '_saida', {}).get(ident, '') + bytes(p.readAll()).decode(errors='ignore')
            bruto = re.sub(r'\x1b\[[0-9;?]*[A-Za-z]', '', bruto).replace('\r', '\n')
            saida = [l.strip() for l in bruto.splitlines() if l.strip()]
            self.aviso.emit('Não foi possível %s. %s' % ('instalar' if tipo == 'instalando' else 'remover',
                                                          saida[-1] if saida else ''))
        self.ler_instalados()
        correr(['kbuildsycoca6'])           # o aplicativo aparece logo no Launchpad
        self.mudou.emit()

    @Slot(str)
    def instalar(self, ident):
        if ident in self._fila:
            return
        self._correr_flatpak(ident, ['install', '--user', '-y', '--noninteractive', 'flathub', ident], 'instalando')

    @Slot(str)
    def remover(self, ident):
        if ident in self._fila:
            return
        c, s = correr(['flatpak', 'list', '--user', '--app', '--columns=application'])
        onde = '--user' if ident in s.split() else '--system'
        self._correr_flatpak(ident, ['uninstall', onde, '-y', '--noninteractive', ident], 'removendo')

    @Slot(str)
    def abrir(self, ident):
        correr(['flatpak', 'run', ident], espera=False)

    @Slot(str)
    def pesquisar(self, texto):
        texto = texto.strip()
        if len(texto) < 2:
            self._resultados = []
            self.mudou.emit()
            return
        c, s = correr(['flatpak', 'search', '--columns=application,name,description', texto])
        r, vistos = [], set()
        if c == 0:
            for l in s.splitlines():
                partes = l.split('\t')
                if len(partes) >= 3 and partes[0] not in vistos and '.' in partes[0]:
                    vistos.add(partes[0])
                    r.append((partes[0], partes[1], partes[2]))
        self._resultados = r[:60]
        self.mudou.emit()


if __name__ == '__main__':
    o = Orbita()
    sys.exit(iniciar('carinaeos-orbita', 'Órbita', 'carinaeos-orbita',
                     os.path.join(AQUI, 'Main.qml'), {'orbita': o}))
