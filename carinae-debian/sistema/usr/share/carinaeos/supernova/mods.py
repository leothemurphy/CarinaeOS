# CarinaeOS - Supernova: mods com MODELOS, ao estilo do Windhawk.
# Cada mod tem varios modelos para escolher (ex.: 13 estilos de Dock inspirados nos
# temas do "Windows 11 Taskbar Styler"). Escolher um modelo aplica-o logo.
import json
import os
import subprocess

CFG = os.path.join(os.environ.get('XDG_CONFIG_HOME', os.path.expanduser('~/.config')), 'carinaeos', 'supernova.json')
DOCK_JSON = os.path.expanduser('~/.config/carinaeos-dock.json')


def ambiente():
    d = (os.environ.get('XDG_CURRENT_DESKTOP', '') + ':' + os.environ.get('DESKTOP_SESSION', '')).lower()
    if 'gnome' in d or 'ubuntu' in d:
        return 'gnome'
    if 'xfce' in d:
        return 'xfce'
    return 'plasma'


AMB = ambiente()
NOME_AMB = {'plasma': 'KDE Plasma', 'gnome': 'GNOME', 'xfce': 'XFCE'}


def gs(esquema, chave, valor):
    _c(['gsettings', 'set', esquema, chave, str(valor)])


def xf(canal, prop, tipo, valor):
    _c(['xfconf-query', '-c', canal, '-p', prop, '-n', '-t', tipo, '-s', str(valor)])


def _c(cmd):
    try:
        subprocess.run(cmd, capture_output=True, timeout=30)
    except Exception:
        pass


def kw(arq, grupo, chave, valor):
    grupos = []
    for g in grupo.split('/'):
        grupos += ['--group', g]
    _c(['kwriteconfig6', '--file', arq] + grupos + ['--key', chave, str(valor)])


def kwin():
    _c(['qdbus6', 'org.kde.KWin', '/KWin', 'reconfigure'])


def efeito(nome, sim):
    kw('kwinrc', 'Plugins', nome + 'Enabled', 'true' if sim else 'false')
    _c(['qdbus6', 'org.kde.KWin', '/Effects', 'org.kde.kwin.Effects.loadEffect' if sim else 'org.kde.kwin.Effects.unloadEffect', nome])


def dock(**valores):
    try:
        with open(DOCK_JSON, encoding='utf-8') as f:
            d = json.load(f)
    except (OSError, ValueError):
        d = {}
    d.update(valores)
    os.makedirs(os.path.dirname(DOCK_JSON), exist_ok=True)
    tmp = DOCK_JSON + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(d, f)
    os.replace(tmp, DOCK_JSON)


# ---- como aplicar cada modelo -----------------------------------------------------------------
DTD = 'org.gnome.shell.extensions.dash-to-dock'
DTD_ESTILOS = {   # cor de fundo, opacidade (0..1)
    'mac': ('#d9d4de', 0.30), 'escuro': ('#1d1a23', 0.65), 'transparente': ('#000000', 0.0),
    'bolhas': ('#cfe3ff', 0.40), 'squircle': ('#36363a', 0.85), 'rosepine': ('#191724', 0.90),
    'xp': ('#2f6fe6', 0.95), 'vista': ('#1b2633', 0.70), 'translucido': ('#ffffff', 0.08),
    'docklike': ('#232323', 0.72), 'matter': ('#2b2930', 1.0), 'lucent': ('#f2f2f2', 0.55), 'neon': ('#14091e', 0.80)}


def a_estilo_dock(m):
    if AMB == 'gnome':
        cor, op = DTD_ESTILOS.get(m, DTD_ESTILOS['mac'])
        gs(DTD, 'dock-position', 'BOTTOM')
        gs(DTD, 'extend-height', 'false')
        gs(DTD, 'custom-background-color', 'true')
        gs(DTD, 'background-color', cor)
        gs(DTD, 'transparency-mode', 'FIXED')
        gs(DTD, 'background-opacity', op)
        gs(DTD, 'custom-theme-shrink', 'true')
        gs(DTD, 'apply-custom-theme', 'false')
        return
    dock(estilo=m)


def a_visivel(m):
    """Dock sempre visivel (padrao), a sair do caminho das janelas, ou escondida."""
    if AMB == 'gnome':
        gs(DTD, 'dock-fixed', 'true' if m == 'sempre' else 'false')
        gs(DTD, 'intellihide', 'true' if m == 'janelas' else 'false')
        gs(DTD, 'autohide', 'true' if m != 'sempre' else 'false')
        return
    if AMB == 'xfce':
        _c(['dconf', 'write', '/net/launchpad/plank/docks/dock1/hide-mode', {'sempre': '0', 'janelas': '1', 'esconder': '2'}[m]])
        return
    modo = {'sempre': 'none', 'janelas': 'dodgewindows', 'esconder': 'autohide'}[m]
    js = ('panels().forEach(function(p){if(p.location=="bottom"){p.hiding="%s";}});' % modo)
    _c(['qdbus6', 'org.kde.plasmashell', '/PlasmaShell', 'org.kde.PlasmaShell.evaluateScript', js])


def a_troca(m):
    kw('kwinrc', 'TabBox', 'LayoutName', m)
    kwin()


def a_minimizar(m):
    if AMB != 'plasma':
        return
    efeito('magiclamp', m == 'lampada')
    efeito('squash', m == 'encolher')
    kwin()


def a_abrir(m):
    efeito('scale', m in ('zoom', 'supernova'))
    efeito('fade', m == 'desvanecer')
    efeito('glide', m == 'tresd')
    efeito('fallapart', m == 'supernova')
    kwin()


def a_mesa(m):
    kw('kwinrc', 'Script-carinaeos-mesa', 'mostrarMesaAoClicar', 'false' if m == 'nao' else 'true')
    efeito('windowaperture', m == 'afastar')
    efeito('slidingpopups', True)
    kw('kwinrc', 'Plugins', 'carinaeos-mesaEnabled', 'true')
    _c(['qdbus6', 'org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting.unloadScript', 'carinaeos-mesa'])
    _c(['qdbus6', 'org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting.start'])
    kwin()


def a_canto(m):
    if AMB == 'gnome':
        gs('org.gnome.desktop.interface', 'enable-hot-corners', 'true' if m == 'visao' else 'false')
        return
    # o canto superior esquerdo: Visao geral (7 = canto sup. esq.; 9 = nenhum)
    kw('kwinrc', 'Effect-overview', 'BorderActivate', '7' if m == 'visao' else '9')
    kw('kwinrc', 'ElectricBorders', 'TopLeft', {'mesa': 'ShowDesktop', 'bloquear': 'LockScreen'}.get(m, 'None'))
    kw('kwinrc', 'Effect-windowview', 'BorderActivateAll', '7' if m == 'janelas' else '9')
    kwin()


def a_botoes(m):
    if AMB == 'gnome':
        gs('org.gnome.desktop.wm.preferences', 'button-layout',
           {'mac': 'close,minimize,maximize:', 'windows': ':minimize,maximize,close', 'fechar': ':close'}[m])
        return
    if AMB == 'xfce':
        xf('xfwm4', '/general/button_layout', 'string', {'mac': 'CHM|', 'windows': 'O|HMC', 'fechar': 'O|C'}[m])
        return
    esq, dir_ = {'mac': ('XIA', ''), 'windows': ('M', 'IAX'), 'fechar': ('', 'X'), 'ubuntu': ('', 'IAX')}[m]
    kw('kwinrc', 'org.kde.kdecoration2', 'ButtonsOnLeft', esq)
    kw('kwinrc', 'org.kde.kdecoration2', 'ButtonsOnRight', dir_)
    kwin()


def a_sombra(m):
    kw('breezerc', 'Common', 'ShadowSize', m)
    kwin()


def a_transparencia(m):
    sim = m != '100'
    efeito('translucency', sim)
    kw('kwinrc', 'Effect-translucency', 'Inactive', m)
    kw('kwinrc', 'Effect-translucency', 'MoveResize', '80' if sim else '100')
    kwin()


def a_desfoque(m):
    efeito('blur', m != '0')
    if m != '0':
        kw('kwinrc', 'Effect-blur', 'BlurStrength', m)
    kwin()


def a_velocidade(m):
    if AMB == 'gnome':
        gs('org.gnome.desktop.interface', 'enable-animations', 'false' if m == '0' else 'true')
        return
    kw('kdeglobals', 'KDE', 'AnimationDurationFactor', m)
    kwin()


def a_roda(m):
    if m == 'nao':
        dock(rodaVolume=False)
    else:
        dock(rodaVolume=True, passoVolume=int(m))


def a_meio(m):
    dock(cliqueMeio=m)


def a_cursor(m):
    tema, tam = {'escuro': ('breeze_cursors', 24), 'claro': ('Breeze_Light', 24),
                 'escuro-grande': ('breeze_cursors', 36), 'claro-grande': ('Breeze_Light', 36),
                 'enorme': ('breeze_cursors', 48)}[m]
    if AMB == 'gnome':
        gs('org.gnome.desktop.interface', 'cursor-theme', tema)
        gs('org.gnome.desktop.interface', 'cursor-size', tam)
        return
    if AMB == 'xfce':
        xf('xsettings', '/Gtk/CursorThemeName', 'string', tema)
        xf('xsettings', '/Gtk/CursorThemeSize', 'int', tam)
        return
    kw('kcminputrc', 'Mouse', 'cursorTheme', tema)
    kw('kcminputrc', 'Mouse', 'cursorSize', tam)
    _c(['plasma-apply-cursortheme', tema, '--size', str(tam)])


def a_noite(m):
    if AMB == 'gnome':
        cor = 'org.gnome.settings-daemon.plugins.color'
        gs(cor, 'night-light-enabled', 'false' if m == 'nao' else 'true')
        if m != 'nao':
            gs(cor, 'night-light-schedule-automatic', 'false')
            gs(cor, 'night-light-schedule-from', '19.0')
            gs(cor, 'night-light-schedule-to', '7.0')
            gs(cor, 'night-light-temperature', 'uint32 %s' % m)
        return
    if m == 'nao':
        kw('kwinrc', 'NightColor', 'Active', 'false')
    else:
        kw('kwinrc', 'NightColor', 'Active', 'true')
        kw('kwinrc', 'NightColor', 'Mode', 'Times')
        kw('kwinrc', 'NightColor', 'EveningBeginFixed', '1900')
        kw('kwinrc', 'NightColor', 'MorningBeginFixed', '0700')
        kw('kwinrc', 'NightColor', 'NightTemperature', m)
    kwin()


MODO_FUNDO = os.path.join(os.path.dirname(CFG), 'fundo-modo')


def a_fundo(m):
    os.makedirs(os.path.dirname(MODO_FUNDO), exist_ok=True)
    with open(MODO_FUNDO, 'w') as f:
        f.write(m)
    if m in ('ceu', 'galeria'):
        _c(['systemctl', '--user', 'enable', '--now', 'carinaeos-ceu-vivo.timer'])
        _c(['/usr/bin/carinaeos-ceu-vivo', '--forcar'])
    else:
        _c(['systemctl', '--user', 'disable', '--now', 'carinaeos-ceu-vivo.timer'])


def a_achar(m):
    efeito('shakecursor', m == 'sim')


def a_deslizar(m):
    efeito('slide', m == 'sim')
    kwin()


def a_janela_foco(m):
    efeito('diminactive', m != 'nao')
    if m != 'nao':
        kw('kwinrc', 'Effect-diminactive', 'Strength', m)
    kwin()


def a_gelatina(m):
    efeito('wobblywindows', m != 'nao')
    if m != 'nao':
        kw('kwinrc', 'Effect-wobblywindows', 'WobblynessLevel', m)   # 0 (pouco) .. 4 (muito)
    kwin()


# ---- catalogo ---------------------------------------------------------------------------------
# "inspirado": o mod do Windhawk (Windows) em que o modelo se baseia
MODS = [
    dict(id='estilo_dock', cat='dock', nome='Estilo da Dock', icone='carinaeos-estrela', aplicar=a_estilo_dock, padrao='mac',
         inspirado='Windows 11 Taskbar Styler',
         desc='O vidro por trás dos ícones da Dock. Os modelos vêm dos temas mais usados do Windhawk.',
         modelos=[
             dict(id='mac', nome='Mac claro', desc='Vidro fosco claro, como no macOS.', cor='#d9d4de'),
             dict(id='escuro', nome='Mac escuro', desc='Vidro fumado, para fundos claros.', cor='#29252f'),
             dict(id='transparente', nome='SimplyTransparent', desc='Sem vidro: só os ícones a flutuar.', cor='#00000000'),
             dict(id='bolhas', nome='Bubbles', desc='Bolha redonda, brilhante e azulada.', cor='#cfe3ff'),
             dict(id='squircle', nome='Squircle', desc='Cantos “squircle”, cinzento sólido.', cor='#36363a'),
             dict(id='rosepine', nome='Rosé Pine', desc='Roxo profundo com borda rosa-pálido.', cor='#ebbcba'),
             dict(id='xp', nome='Windows XP', desc='O azul “Luna” do XP, com brilho no topo.', cor='#3a81f3'),
             dict(id='vista', nome='WinVista', desc='Vidro Aero escuro com reflexo.', cor='#3b4c5c'),
             dict(id='translucido', nome='TranslucentTaskbar', desc='Quase invisível, só um véu de vidro.', cor='#33ffffff'),
             dict(id='docklike', nome='DockLike', desc='Dock escura e discreta, cantos médios.', cor='#232323'),
             dict(id='matter', nome='Matter', desc='Material Design: sólido e muito arredondado.', cor='#2b2930'),
             dict(id='lucent', nome='Lucent', desc='Vidro branco leitoso, borda brilhante.', cor='#f2f2f2'),
             dict(id='neon', nome='Neon Eta', desc='Escuro com borda néon rosa e âmbar a pulsar.', cor='#ff6f91'),
         ]),
    dict(id='visivel', cat='dock', nome='Dock sempre à vista', icone='view-visible', aplicar=a_visivel, padrao='sempre',
         inspirado='Taskbar auto-hide',
         desc='A Dock (e a barra de cima) ficam sempre no ecrã, ou escondem-se.',
         modelos=[
             dict(id='sempre', nome='Sempre visível', desc='Como a barra de cima: nunca se esconde (padrão).'),
             dict(id='janelas', nome='Sai do caminho', desc='Esconde-se quando uma janela passa por cima.'),
             dict(id='esconder', nome='Esconder sempre', desc='Aparece ao levar o rato ao fundo do ecrã.'),
         ]),
    dict(id='troca', cat='janelas', nome='Alt+Tab', icone='preferences-system-windows-effect-flipswitch', aplicar=a_troca, padrao='flipswitch',
         inspirado='Alt+Tab Flip 3D / Better Alt+Tab',
         desc='Como as janelas aparecem quando segura Alt e carrega em Tab.',
         modelos=[
             dict(id='flipswitch', nome='Flip 3D', desc='Janelas em perspetiva, como no Windows Vista.'),
             dict(id='coverswitch', nome='Cover Flow', desc='Carrossel 3D, como os discos no iTunes.'),
             dict(id='thumbnail_grid', nome='Grade', desc='Miniaturas em grade, como no Mac.'),
             dict(id='big_icons', nome='Ícones grandes', desc='Só os ícones, grandes.'),
             dict(id='sidebar', nome='Lista lateral', desc='Lista de janelas encostada à esquerda.'),
             dict(id='compact', nome='Compacto', desc='Lista simples com os nomes.'),
         ]),
    dict(id='minimizar', cat='janelas', nome='Animação ao minimizar', icone='window-minimize', aplicar=a_minimizar, padrao='lampada',
         inspirado='Window animations',
         desc='O que acontece à janela quando a minimiza.',
         modelos=[
             dict(id='lampada', nome='Lâmpada mágica', desc='A janela escorre para a Dock, como no Mac.'),
             dict(id='encolher', nome='Encolher', desc='Encolhe direto para o ícone, como no Windows.'),
             dict(id='nada', nome='Nenhuma', desc='Desaparece logo (mais rápido).'),
         ]),
    dict(id='abrir', cat='janelas', nome='Abrir e fechar janelas', icone='window-new', aplicar=a_abrir, padrao='zoom',
         inspirado='Window open/close animations',
         desc='A animação quando uma janela abre ou fecha.',
         modelos=[
             dict(id='zoom', nome='Zoom suave', desc='Pequeno zoom, padrão do Mac.'),
             dict(id='desvanecer', nome='Desvanecer', desc='A janela aparece e desaparece suavemente.'),
             dict(id='tresd', nome='Entrada em 3D', desc='A janela inclina-se em 3D.'),
             dict(id='supernova', nome='Supernova', desc='Zoom ao abrir e explosão em pedaços ao fechar.'),
             dict(id='nada', nome='Nenhuma', desc='Sem animação.'),
         ]),
    dict(id='mesa', cat='mesa', nome='Clicar no papel de parede', icone='user-desktop', aplicar=a_mesa, padrao='afastar',
         inspirado='Click on empty taskbar space / Show desktop',
         desc='Clicar numa parte vazia do papel de parede mostra a área de trabalho.',
         modelos=[
             dict(id='afastar', nome='Afastar as janelas', desc='As janelas vão para os cantos, como no macOS Sonoma.'),
             dict(id='minimizar', nome='Esconder tudo', desc='Esconde as janelas de uma vez, como no Windows.'),
             dict(id='nao', nome='Não fazer nada', desc='Clicar no papel de parede não muda nada.'),
         ]),
    dict(id='canto', cat='mesa', nome='Canto superior esquerdo', icone='view-app-grid', aplicar=a_canto, padrao='nada',
         inspirado='Hot corners',
         desc='Leve o rato ao canto superior esquerdo do ecrã para…',
         modelos=[
             dict(id='nada', nome='Nada', desc='O canto não faz nada.'),
             dict(id='visao', nome='Visão geral', desc='Todas as janelas e áreas de trabalho (Mission Control).'),
             dict(id='janelas', nome='Todas as janelas', desc='Só as janelas, lado a lado (Exposé).'),
             dict(id='mesa', nome='Mostrar a mesa', desc='Afasta as janelas.'),
             dict(id='bloquear', nome='Bloquear o ecrã', desc='Bloqueia logo, para sair à pressa.'),
         ]),
    dict(id='botoes', cat='janelas', nome='Botões das janelas', icone='window-close', aplicar=a_botoes, padrao='mac',
         inspirado='Windows 11 Window Styler',
         desc='Onde ficam os botões fechar, minimizar e maximizar.',
         modelos=[
             dict(id='mac', nome='Esquerda (Mac)', desc='Fechar, minimizar e maximizar à esquerda.'),
             dict(id='windows', nome='Direita (Windows)', desc='Minimizar, maximizar e fechar à direita.'),
             dict(id='fechar', nome='Só fechar', desc='Só o botão de fechar, à direita.'),
         ]),
    dict(id='sombra', cat='janelas', nome='Sombra das janelas', icone='draw-rectangle', aplicar=a_sombra, padrao='ShadowLarge',
         inspirado='Windows 11 Window Styler',
         desc='O tamanho da sombra à volta das janelas.',
         modelos=[
             dict(id='ShadowNone', nome='Sem sombra', desc='Visual plano.'),
             dict(id='ShadowSmall', nome='Pequena', desc='Discreta.'),
             dict(id='ShadowMedium', nome='Média', desc='Equilibrada.'),
             dict(id='ShadowLarge', nome='Grande', desc='Como no Mac (padrão).'),
             dict(id='ShadowVeryLarge', nome='Enorme', desc='As janelas flutuam.'),
         ]),
    dict(id='transparencia', cat='janelas', nome='Janelas em segundo plano', icone='preferences-desktop-effects', aplicar=a_transparencia, padrao='100',
         inspirado='Translucent Windows',
         desc='Deixa as janelas que não está a usar um pouco transparentes.',
         modelos=[
             dict(id='100', nome='Opacas', desc='Sem transparência.'),
             dict(id='92', nome='Um véu', desc='Quase não se nota.'),
             dict(id='85', nome='Translúcidas', desc='Vê-se o que está por trás.'),
             dict(id='75', nome='Muito', desc='Bem transparentes.'),
         ]),
    dict(id='desfoque', cat='mesa', nome='Vidro fosco', icone='blurfx', aplicar=a_desfoque, padrao='10',
         inspirado='Acrylic / Mica effect',
         desc='A força do desfoque por trás de menus, painéis e da barra de cima.',
         modelos=[
             dict(id='0', nome='Desligado', desc='Sem desfoque (mais leve).'),
             dict(id='4', nome='Leve', desc='Um desfoque suave.'),
             dict(id='10', nome='Médio', desc='Como no Mac (padrão).'),
             dict(id='15', nome='Forte', desc='Vidro bem fosco.'),
         ]),
    dict(id='velocidade', cat='mesa', nome='Velocidade das animações', icone='speedometer', aplicar=a_velocidade, padrao='1',
         inspirado='Faster animations',
         desc='Deixe tudo mais rápido ou mais cinematográfico.',
         modelos=[
             dict(id='0', nome='Instantâneo', desc='Sem animações.'),
             dict(id='0.5', nome='Rápido', desc='Metade do tempo.'),
             dict(id='1', nome='Normal', desc='Padrão.'),
             dict(id='1.6', nome='Suave', desc='Mais lento e elegante.'),
             dict(id='2.5', nome='Cinema', desc='Tudo em câmara lenta.'),
         ]),
    dict(id='roda', cat='dock', nome='Roda do rato na Dock', icone='audio-volume-high', aplicar=a_roda, padrao='5',
         inspirado='Taskbar Volume Control',
         desc='Rodar a roda do rato por cima da Dock muda o volume.',
         modelos=[
             dict(id='2', nome='Passos finos', desc='2% de cada vez.'),
             dict(id='5', nome='Normal', desc='5% de cada vez.'),
             dict(id='10', nome='Rápido', desc='10% de cada vez.'),
             dict(id='nao', nome='Desligado', desc='A roda não faz nada na Dock.'),
         ]),
    dict(id='meio', cat='dock', nome='Clique do meio na Dock', icone='input-mouse', aplicar=a_meio, padrao='nova',
         inspirado='Middle click to close on the taskbar',
         desc='O que faz o clique com a roda do rato num ícone da Dock.',
         modelos=[
             dict(id='nova', nome='Nova janela', desc='Abre outra janela do aplicativo.'),
             dict(id='fechar', nome='Fechar', desc='Fecha o aplicativo, como no mod do Windhawk.'),
         ]),
    dict(id='cursor', cat='mesa', nome='Cursor do rato', icone='input-mouse', aplicar=a_cursor, padrao='escuro',
         inspirado='Cursor customization',
         desc='A cor e o tamanho do cursor.',
         modelos=[
             dict(id='escuro', nome='Escuro', desc='Padrão.'),
             dict(id='claro', nome='Claro', desc='Branco, como no Mac.'),
             dict(id='escuro-grande', nome='Escuro grande', desc='Mais fácil de ver.'),
             dict(id='claro-grande', nome='Claro grande', desc='Branco e maior.'),
             dict(id='enorme', nome='Enorme', desc='Para ecrãs grandes ou TV.'),
         ]),
    dict(id='noite', cat='mesa', nome='Luz noturna', icone='redshift-status-on', aplicar=a_noite, padrao='nao',
         inspirado='Night light',
         desc='Cores mais quentes entre as 19h e as 7h, para descansar os olhos.',
         modelos=[
             dict(id='nao', nome='Desligada', desc='Cores normais sempre.'),
             dict(id='4500', nome='Suave', desc='Um pouco mais quente.'),
             dict(id='3500', nome='Quente', desc='Recomendado.'),
             dict(id='2700', nome='Vela', desc='Muito quente, para ler à noite.'),
         ]),
    dict(id='foco', cat='janelas', nome='Foco estelar', icone='view-visible', aplicar=a_janela_foco, padrao='nao', novo=True,
         inspirado='Dim inactive windows',
         desc='Escurece as janelas que não está a usar, para se concentrar numa só.',
         modelos=[
             dict(id='nao', nome='Desligado', desc=''),
             dict(id='15', nome='Leve', desc=''),
             dict(id='30', nome='Médio', desc=''),
             dict(id='50', nome='Forte', desc=''),
         ]),
    dict(id='gelatina', cat='janelas', nome='Janelas de gelatina', icone='transform-move', aplicar=a_gelatina, padrao='1',
         inspirado='Wobbly windows',
         desc='As janelas ondulam enquanto as arrasta.',
         modelos=[
             dict(id='nao', nome='Desligado', desc=''),
             dict(id='0', nome='Firme', desc=''),
             dict(id='1', nome='Normal', desc=''),
             dict(id='3', nome='Mole', desc=''),
             dict(id='4', nome='Gelatina!', desc=''),
         ]),
    dict(id='achar', cat='mesa', nome='Agitar para achar o cursor', icone='input-mouse', aplicar=a_achar, padrao='sim',
         inspirado='Shake to find cursor', desc='Agite o rato e o cursor cresce para o encontrar.',
         modelos=[dict(id='sim', nome='Ligado', desc=''), dict(id='nao', nome='Desligado', desc='')]),
    dict(id='deslizar', cat='mesa', nome='Trocar de área de trabalho', icone='go-next', aplicar=a_deslizar, padrao='sim',
         inspirado='Virtual desktop animation', desc='Animação ao passar de uma área de trabalho para outra.',
         modelos=[dict(id='sim', nome='Deslizar', desc=''), dict(id='nao', nome='Sem animação', desc='')]),
    dict(id='fundo', cat='mesa', nome='Papel de parede vivo', icone='weather-clear-night', aplicar=a_fundo, padrao='fixo', novo=True,
         inspirado='Wallpaper slideshow',
         desc='O fundo pode mudar sozinho ao longo do dia.',
         modelos=[
             dict(id='fixo', nome='Fixo', desc='O que escolher fica sempre.'),
             dict(id='ceu', nome='Céu vivo', desc='A Eta Carinae muda de tom: madrugada, manhã, tarde e noite.'),
             dict(id='galeria', nome='Galeria CarinaeOS', desc='Um fundo diferente da coleção a cada hora.'),
         ]),
]


def ler_escolhas():
    try:
        with open(CFG, encoding='utf-8') as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def gravar_escolhas(d):
    os.makedirs(os.path.dirname(CFG), exist_ok=True)
    with open(CFG, 'w', encoding='utf-8') as f:
        json.dump(d, f)


ONDE = {   # mods que tambem funcionam fora do Plasma
    'gnome': {'visivel', 'estilo_dock', 'botoes', 'cursor', 'noite', 'velocidade', 'canto', 'fundo'},
    'xfce': {'visivel', 'botoes', 'cursor', 'fundo'},
}


def lista():
    esc = ler_escolhas()
    res = []
    for m in MODS:
        r = {k: v for k, v in m.items() if k != 'aplicar'}
        r['escolhido'] = esc.get(m['id'], m['padrao'])
        r['disponivel'] = AMB == 'plasma' or m['id'] in ONDE.get(AMB, set())
        if AMB == 'gnome' and m['id'] == 'canto':
            r['modelos'] = [x for x in m['modelos'] if x['id'] in ('nada', 'visao')]
        if AMB == 'gnome' and m['id'] == 'velocidade':
            r['modelos'] = [x for x in m['modelos'] if x['id'] in ('0', '1')]
        res.append(r)
    return res


def escolher(ident, modelo):
    m = next((x for x in MODS if x['id'] == ident), None)
    if not m or modelo not in [x['id'] for x in m['modelos']]:
        return False
    m['aplicar'](modelo)
    esc = ler_escolhas()
    esc[ident] = modelo
    gravar_escolhas(esc)
    return True


# perfis: um conjunto de modelos de uma vez
PERFIS = [
    dict(id='mac', nome='Mac clássico', icone='carinaeos-estrela',
         desc='Dock de vidro claro, lâmpada mágica, botões à esquerda e Alt+Tab em grade.',
         escolhas=dict(estilo_dock='mac', minimizar='lampada', abrir='zoom', botoes='mac', troca='thumbnail_grid',
                       sombra='ShadowLarge', desfoque='10', mesa='afastar', canto='visao', gelatina='nao', velocidade='1')),
    dict(id='vista', nome='Vista retrô', icone='preferences-desktop-effects',
         desc='Dock de vidro Aero, Flip 3D no Alt+Tab, janelas a entrar em 3D e botões à direita.',
         escolhas=dict(estilo_dock='vista', minimizar='encolher', abrir='tresd', botoes='windows', troca='flipswitch',
                       sombra='ShadowVeryLarge', desfoque='15', mesa='minimizar', canto='nada', gelatina='nao', velocidade='1')),
    dict(id='xp', nome='Nostalgia XP', icone='computer',
         desc='Dock azul “Luna”, botões à direita, Alt+Tab compacto e animações rápidas.',
         escolhas=dict(estilo_dock='xp', minimizar='encolher', abrir='desvanecer', botoes='windows', troca='compact',
                       sombra='ShadowMedium', desfoque='0', mesa='minimizar', canto='nada', gelatina='nao', velocidade='0.5')),
    dict(id='supernova', nome='Supernova total', icone='carinaeos-supernova',
         desc='Dock néon, gelatina, explosão ao fechar, Cover Flow, Foco estelar e Céu vivo.',
         escolhas=dict(estilo_dock='neon', minimizar='lampada', abrir='supernova', botoes='mac', troca='coverswitch',
                       sombra='ShadowLarge', desfoque='15', mesa='afastar', canto='visao', gelatina='3', foco='15',
                       fundo='ceu', velocidade='1.6')),
    dict(id='rosepine', nome='Rosé Pine', icone='color-management',
         desc='Tons de rosa e roxo, Dock Rosé Pine, janelas translúcidas e luz noturna suave.',
         escolhas=dict(estilo_dock='rosepine', minimizar='lampada', abrir='desvanecer', botoes='mac', troca='thumbnail_grid',
                       transparencia='92', noite='4500', gelatina='nao')),
    dict(id='leve', nome='Leve e rápido', icone='speedometer',
         desc='Quase sem efeitos: ideal para computadores mais fracos.',
         escolhas=dict(estilo_dock='escuro', minimizar='nada', abrir='nada', troca='compact', sombra='ShadowSmall',
                       desfoque='0', transparencia='100', gelatina='nao', foco='nao', velocidade='0.5', fundo='fixo')),
]


def aplicar_perfil(ident):
    p = next((x for x in PERFIS if x['id'] == ident), None)
    if not p:
        return False
    disp = {m['id']: m['disponivel'] for m in lista()}
    for k, v in p['escolhas'].items():
        if disp.get(k):
            escolher(k, v)
    return True


def restaurar():
    for m in MODS:
        if AMB == 'plasma' or m['id'] in ONDE.get(AMB, set()):
            escolher(m['id'], m['padrao'])
