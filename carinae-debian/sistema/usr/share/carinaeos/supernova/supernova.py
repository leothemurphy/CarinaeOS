#!/usr/bin/python3
# CarinaeOS - Supernova: personalizar o sistema com "mods" (efeitos, Alt+Tab,
# Dock, cantos da tela...) num clique, e perfis prontos.
import json
import os
import sys

sys.path.insert(0, '/usr/share/carinaeos/comum')
from base import correr, iniciar  # noqa: E402

from PySide6.QtCore import Property, QObject, Signal, Slot  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
CEU = os.path.expanduser('~/.config/systemd/user')

# ---- catalogo de mods ------------------------------------------------------
# tipo "efeito": efeito do KWin (liga/desliga logo, sem reiniciar)
# tipo "kwin":   chave do kwinrc; tipo "dock": configuracao da Dock
# tipo "ceu":    Ceu vivo (fundo muda com a hora do dia)
MODS = [
    # janelas
    dict(id='magiclamp', cat='janelas', nome='Lâmpada mágica', icone='window-minimize',
         desc='Ao minimizar, a janela escorre para a Dock como no Mac.', tipo='efeito', padrao=True),
    dict(id='wobblywindows', cat='janelas', nome='Janelas de gelatina', icone='transform-move',
         desc='As janelas ondulam enquanto você as arrasta.', tipo='efeito', padrao=True),
    dict(id='fallapart', cat='ideias', nome='Supernova ao fechar', icone='edit-bomb',
         desc='A janela explode em pedaços, como uma estrela, quando é fechada.', tipo='efeito', padrao=False, novo=True),
    dict(id='blur', cat='janelas', nome='Vidro fosco', icone='blurfx',
         desc='Desfoca o que está por trás de menus e painéis transparentes.', tipo='efeito', padrao=True),
    dict(id='glide', cat='janelas', nome='Entrada em 3D', icone='view-3D',
         desc='As janelas inclinam-se em 3D ao abrir e fechar.', tipo='efeito', padrao=False),
    dict(id='scale', cat='janelas', nome='Zoom suave', icone='zoom-in',
         desc='As janelas aparecem com um pequeno zoom (padrão do Mac).', tipo='efeito', padrao=True),
    dict(id='diminactive', cat='ideias', nome='Foco estelar', icone='view-visible',
         desc='Escurece as janelas que você não está usando, para se concentrar numa só.',
         tipo='efeito', padrao=False, novo=True),
    dict(id='shakecursor', cat='janelas', nome='Achar o cursor', icone='input-mouse',
         desc='Agite o mouse e o cursor cresce para você o encontrar.', tipo='efeito', padrao=True),
    dict(id='slide', cat='janelas', nome='Deslizar entre áreas', icone='go-next',
         desc='Animação ao trocar de área de trabalho.', tipo='efeito', padrao=True),
    # area de trabalho
    dict(id='canto', cat='mesa', nome='Canto mágico', icone='view-app-grid',
         desc='Leve o mouse ao canto superior esquerdo e veja todas as janelas (como o Mission Control).',
         tipo='kwin', grupo='Effect-overview', chave='BorderActivate', sim='7', nao='9', padrao=False),
    dict(id='noite', cat='mesa', nome='Luz noturna', icone='redshift-status-on',
         desc='Cores mais quentes à noite, para descansar os olhos.',
         tipo='kwin', grupo='NightColor', chave='Active', sim='true', nao='false', padrao=False),
    dict(id='ceu', cat='ideias', nome='Céu vivo', icone='weather-clear-night',
         desc='O fundo de Eta Carinae muda de tom ao longo do dia: madrugada, manhã, tarde e noite.',
         tipo='ceu', padrao=False, novo=True),
    dict(id='pulso', cat='ideias', nome='Pulso estelar', icone='media-playlist-repeat',
         desc='Os ícones da Dock saltam enquanto o aplicativo abre.', tipo='dock-bool',
         chave='bounce', padrao=True, novo=True),
]

TROCA = [  # Alt+Tab
    dict(id='flipswitch', nome='Flip 3D', desc='Janelas em perspetiva, como no Windows Vista.'),
    dict(id='coverswitch', nome='Cover Flow', desc='Janelas em carrossel 3D, como os discos no iTunes.'),
    dict(id='thumbnail_grid', nome='Grade', desc='Miniaturas de todas as janelas em grade.'),
    dict(id='big_icons', nome='Ícones grandes', desc='Só os ícones dos aplicativos, grandes.'),
    dict(id='sidebar', nome='Lista lateral', desc='Lista de janelas encostada à esquerda.'),
    dict(id='compact', nome='Compacto', desc='Lista simples com os nomes das janelas.'),
]

PERFIS = [
    dict(id='mac', nome='Mac clássico', icone='carinaeos-estrela',
         desc='Lâmpada mágica, zoom suave, vidro fosco e Alt+Tab em grade.',
         mods=['magiclamp', 'scale', 'blur', 'shakecursor', 'slide', 'pulso'], troca='thumbnail_grid'),
    dict(id='vista', nome='Vista retrô', icone='preferences-desktop-effects',
         desc='Flip 3D no Alt+Tab, vidro fosco e janelas a entrar em 3D.',
         mods=['blur', 'glide', 'scale', 'slide', 'pulso', 'magiclamp'], troca='flipswitch'),
    dict(id='supernova', nome='Supernova total', icone='carinaeos-supernova',
         desc='Tudo ligado: gelatina, explosão ao fechar, Cover Flow, Céu vivo e Foco estelar.',
         mods=[m['id'] for m in MODS if m['id'] not in ('glide',)], troca='coverswitch'),
    dict(id='leve', nome='Leve e rápido', icone='speedometer',
         desc='Quase sem efeitos: ideal para computadores mais fracos.',
         mods=['blur'], troca='compact'),
]


def kread(arq, grupo, chave, padrao=''):
    c, s = correr(['kreadconfig6', '--file', arq, '--group', grupo, '--key', chave, '--default', padrao])
    return s if c == 0 else padrao


def kwrite(arq, grupo, chave, valor):
    correr(['kwriteconfig6', '--file', arq, '--group', grupo, '--key', chave, str(valor)])


def kwin_recarregar():
    correr(['qdbus6', 'org.kde.KWin', '/KWin', 'reconfigure'])


def plasma_script(js):
    correr(['qdbus6', 'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell.evaluateScript', js])


def dock_ler(chave, padrao):
    # a Dock guarda a configuracao no ficheiro de applets do Plasma:
    # [Containments][N][Applets][M] plugin=org.carinaeos.dock
    # [Containments][N][Applets][M][Configuration][General] chave=valor
    f = os.path.expanduser('~/.config/plasma-org.kde.plasma.desktop-appletsrc')
    try:
        grupos, grupo = {}, None
        for l in open(f, encoding='utf-8'):
            l = l.strip()
            if l.startswith('['):
                grupo = l
                grupos.setdefault(grupo, {})
            elif '=' in l and grupo:
                k, v = l.split('=', 1)
                grupos[grupo][k] = v
        for g, kv in grupos.items():
            if kv.get('plugin') == 'org.carinaeos.dock':
                conf = grupos.get(g + '[Configuration][General]', {})
                return conf.get(chave, padrao)
    except Exception:
        pass
    return padrao


def dock_escrever(chave, valor):
    v = json.dumps(valor)
    plasma_script(
        'panels().forEach(function(p){p.widgets().forEach(function(w){'
        'if(w.type=="org.carinaeos.dock"){w.currentConfigGroup=["General"];'
        'w.writeConfig("%s",%s);w.reloadConfig();}});});' % (chave, v))


# ---- Ceu vivo: servico do systemd do utilizador ---------------------------------
def ceu_ativo():
    return os.path.exists(os.path.join(CEU, 'timers.target.wants', 'carinaeos-ceu-vivo.timer'))


def ceu_ligar(sim):
    if sim:
        correr(['systemctl', '--user', 'enable', '--now', 'carinaeos-ceu-vivo.timer'])
        correr(['/usr/bin/carinaeos-ceu-vivo', '--forcar'])
    else:
        correr(['systemctl', '--user', 'disable', '--now', 'carinaeos-ceu-vivo.timer'])
        correr(['plasma-apply-wallpaperimage', '/usr/share/wallpapers/CarinaeOS'])


class Supernova(QObject):
    mudou = Signal()

    def __init__(self):
        super().__init__()
        self._estado = {}
        self.ler()

    # ---- estado --------------------------------------------------------------
    def ler(self):
        e = {}
        for m in MODS:
            if m['tipo'] == 'efeito':
                e[m['id']] = kread('kwinrc', 'Plugins', m['id'] + 'Enabled', 'true' if m['padrao'] else 'false') == 'true'
            elif m['tipo'] == 'kwin':
                e[m['id']] = kread('kwinrc', m['grupo'], m['chave'], m['nao']) == m['sim']
            elif m['tipo'] == 'ceu':
                e[m['id']] = ceu_ativo()
            elif m['tipo'] == 'dock-bool':
                e[m['id']] = dock_ler(m['chave'], 'true' if m['padrao'] else 'false') == 'true'
        self._estado = e
        self._troca = kread('kwinrc', 'TabBox', 'LayoutName', 'flipswitch')
        try:
            self._zoom = float(dock_ler('zoom', '1.9'))
            self._tamanho = int(dock_ler('iconSize', '48'))
        except ValueError:
            self._zoom, self._tamanho = 1.9, 48
        self.mudou.emit()

    def _lista(self):
        return [dict(m, ligado=self._estado.get(m['id'], False)) for m in MODS]

    mods = Property('QVariantList', _lista, notify=mudou)
    trocas = Property('QVariantList', lambda s: TROCA, constant=True)
    perfis = Property('QVariantList', lambda s: PERFIS, constant=True)
    troca = Property(str, lambda s: s._troca, notify=mudou)
    zoom = Property(float, lambda s: s._zoom, notify=mudou)
    tamanho = Property(int, lambda s: s._tamanho, notify=mudou)
    ativos = Property(int, lambda s: sum(1 for v in s._estado.values() if v), notify=mudou)

    # ---- acoes -------------------------------------------------------------
    def _aplicar(self, m, sim, recarregar=True):
        if m['tipo'] == 'efeito':
            kwrite('kwinrc', 'Plugins', m['id'] + 'Enabled', 'true' if sim else 'false')
            correr(['qdbus6', 'org.kde.KWin', '/Effects',
                    'org.kde.kwin.Effects.loadEffect' if sim else 'org.kde.kwin.Effects.unloadEffect', m['id']])
        elif m['tipo'] == 'kwin':
            kwrite('kwinrc', m['grupo'], m['chave'], m['sim'] if sim else m['nao'])
            if recarregar:
                kwin_recarregar()
        elif m['tipo'] == 'ceu':
            ceu_ligar(sim)
        elif m['tipo'] == 'dock-bool':
            dock_escrever(m['chave'], bool(sim))
        self._estado[m['id']] = sim

    @Slot(str, bool)
    def ligar(self, ident, sim):
        for m in MODS:
            if m['id'] == ident:
                self._aplicar(m, sim)
        self.mudou.emit()

    @Slot(str)
    def escolherTroca(self, ident):
        kwrite('kwinrc', 'TabBox', 'LayoutName', ident)
        kwin_recarregar()
        self._troca = ident
        self.mudou.emit()

    @Slot(float)
    def mudarZoom(self, z):
        self._zoom = round(z, 2)
        dock_escrever('zoom', self._zoom)
        self.mudou.emit()

    @Slot(int)
    def mudarTamanho(self, t):
        self._tamanho = int(t)
        dock_escrever('iconSize', self._tamanho)
        self.mudou.emit()

    @Slot(str)
    def aplicarPerfil(self, ident):
        p = next((x for x in PERFIS if x['id'] == ident), None)
        if not p:
            return
        for m in MODS:
            self._aplicar(m, m['id'] in p['mods'], recarregar=False)
        kwrite('kwinrc', 'TabBox', 'LayoutName', p['troca'])
        self._troca = p['troca']
        kwin_recarregar()
        self.mudou.emit()

    @Slot()
    def restaurar(self):
        for m in MODS:
            self._aplicar(m, m['padrao'], recarregar=False)
        kwrite('kwinrc', 'TabBox', 'LayoutName', 'flipswitch')
        self._troca = 'flipswitch'
        kwin_recarregar()
        self.mudarZoom(1.9)
        self.mudarTamanho(48)
        self.mudou.emit()

    @Slot()
    def experimentarTroca(self):
        correr(['qdbus6', 'org.kde.kglobalaccel', '/component/kwin',
                'org.kde.kglobalaccel.Component.invokeShortcut', 'Walk Through Windows'], espera=False)


if __name__ == '__main__':
    s = Supernova()
    sys.exit(iniciar('carinaeos-supernova', 'Supernova', 'carinaeos-supernova',
                     os.path.join(AQUI, 'Main.qml'), {'supernova': s}))
