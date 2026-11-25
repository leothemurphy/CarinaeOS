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
    if 'carinae' in d:
        return 'carinae'     # o ambiente próprio: Gravidade (janelas) + Aurora (Dock, barra) + picom
    if 'gnome' in d or 'ubuntu' in d:
        return 'gnome'
    if 'xfce' in d:
        return 'xfce'
    return 'plasma'


AMB = ambiente()
NOME_AMB = {'carinae': 'CarinaeOS (Gravidade)', 'plasma': 'KDE Plasma', 'gnome': 'GNOME', 'xfce': 'XFCE'}


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


# ---- CarinaeOS: Gravidade, Aurora e o compositor (picom) ----------------------------------------
PASTA = os.path.join(os.environ.get('XDG_CONFIG_HOME', os.path.expanduser('~/.config')), 'carinaeos')
SHELL_JSON = os.path.expanduser('~/.config/carinaeos-shell.json')
PICOM_USER = os.path.join(PASTA, 'picom.conf')


def gravidade(chave, valor):
    """Grava uma opção em ~/.config/carinaeos/gravidade.conf e pede à Gravidade para reler (kill -HUP)."""
    f = os.path.join(PASTA, 'gravidade.conf')
    linhas = []
    try:
        with open(f, encoding='utf-8') as x:
            linhas = [l for l in x.read().splitlines() if l.split('=')[0].strip() != chave]
    except OSError:
        linhas = ['# CarinaeOS — opções da Gravidade (escritas pela Supernova)']
    linhas.append('%s = %s' % (chave, valor))
    os.makedirs(PASTA, exist_ok=True)
    with open(f, 'w', encoding='utf-8') as x:
        x.write('\n'.join(linhas) + '\n')
    _c(['pkill', '-HUP', '-x', 'gravidade'])


def shell(**valores):
    try:
        with open(SHELL_JSON, encoding='utf-8') as f:
            d = json.load(f)
    except (OSError, ValueError):
        d = {}
    d.update(valores)
    tmp = SHELL_JSON + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(d, f)
    os.replace(tmp, SHELL_JSON)


SOMBRAS = {'ShadowNone': None, 'ShadowSmall': (10, 0.30), 'ShadowMedium': (18, 0.42),
           'ShadowLarge': (26, 0.50), 'ShadowVeryLarge': (38, 0.58)}
BLUR = {'4': 3, '10': 5, '15': 8}


def _picom_backend():
    """O backend do picom que está a correr (glx/xrender), ou None se não houver picom."""
    try:
        r = subprocess.run(['ps', '-C', 'picom', '-o', 'args='], capture_output=True, text=True, timeout=5)
    except Exception:
        return None
    for l in r.stdout.splitlines():
        p = l.split()
        if '--backend' in p and p.index('--backend') + 1 < len(p):
            return p[p.index('--backend') + 1]
        return 'glx'
    return None


def _anim(gatilhos, preset, dur, **extra):
    x = ''.join('%s = %s; ' % (k, ('"%s"' % v) if isinstance(v, str) else ('%.2f' % v)) for k, v in extra.items())
    return '{ triggers = [ %s ]; preset = "%s"; duration = %.3f; %s}' % (
        ', '.join('"%s"' % g for g in gatilhos), preset, dur, x)


def gerar_picom(esc, backend):
    """O picom.conf do utilizador (formato do picom 12, com "rules"), a partir das escolhas da Supernova."""
    vel = float(esc.get('velocidade', '1'))
    sombra = SOMBRAS.get(esc.get('sombra', 'ShadowMedium'), (18, 0.42))
    opac = int(esc.get('transparencia', '100')) / 100.0
    dim = 0.0 if esc.get('foco', 'nao') == 'nao' else int(esc['foco']) / 100.0
    blur = BLUR.get(esc.get('desfoque', '0')) if backend == 'glx' else None
    l = ['# CarinaeOS — compositor (picom 12). Gerado pela Supernova: mude as opções lá, não aqui.',
         'vsync = true;', 'use-damage = true;', 'unredir-if-possible = true;',
         'detect-client-opacity = true;', 'detect-transient = true;', 'corner-radius = 10;']
    if sombra:
        l += ['shadow = true;', 'shadow-radius = %d;' % sombra[0], 'shadow-opacity = %.2f;' % sombra[1],
              'shadow-offset-x = %d;' % -int(sombra[0] * 0.9), 'shadow-offset-y = %d;' % -int(sombra[0] * 0.65)]
    else:
        l.append('shadow = false;')
    if vel <= 0:
        l.append('fading = false;')
    else:
        passo = min(0.3, 0.07 / vel)
        l += ['fading = true;', 'fade-in-step = %.3f;' % passo, 'fade-out-step = %.3f;' % passo, 'fade-delta = 5;']
    if blur:
        l += ['blur-method = "dual_kawase";', 'blur-strength = %d;' % blur]
    # animações só nas janelas dos aplicativos (a Dock, a barra e os menus têm as suas)
    an = []
    if vel > 0:
        d = lambda t: t * vel  # noqa: E731
        abrir = esc.get('abrir', 'desvanecer')
        if abrir == 'zoom':
            an += [_anim(['open'], 'appear', d(.20), scale=0.85), _anim(['close'], 'disappear', d(.16), scale=0.85)]
        elif abrir == 'desvanecer':
            an += [_anim(['open'], 'appear', d(.18), scale=1.0), _anim(['close'], 'disappear', d(.15), scale=1.0)]
        elif abrir == 'tresd':
            an += [_anim(['open'], 'fly-in', d(.28), direction='up'), _anim(['close'], 'fly-out', d(.22), direction='down')]
        elif abrir == 'supernova':
            an += [_anim(['open'], 'appear', d(.30), scale=0.6), _anim(['close'], 'disappear', d(.28), scale=1.35)]
        mini = esc.get('minimizar', 'suave')
        if mini == 'lampada':
            an += [_anim(['hide'], 'fly-out', d(.30), direction='down'), _anim(['show'], 'appear', d(.22), scale=0.8)]
        elif mini == 'encolher':
            an += [_anim(['hide'], 'disappear', d(.22), scale=0.3), _anim(['show'], 'appear', d(.22), scale=0.3)]
        elif mini == 'suave':
            an += [_anim(['hide'], 'disappear', d(.15), scale=1.0), _anim(['show'], 'appear', d(.15), scale=1.0)]
        if esc.get('gelatina', 'nao') in GELATINA:
            an.append(_elastico(esc['gelatina'], vel))
    regras = []
    janelas = "(window_type = 'normal' || window_type = 'dialog') && class_g != 'carinae-shell'"
    if an:
        regras.append('{ match = "%s"; animations = ( %s ); }' % (janelas, ', '.join(an)))
    if opac < 1 or dim > 0:
        x = ('opacity = %.2f; ' % opac if opac < 1 else '') + ('dim = %.2f; ' % dim if dim > 0 else '')
        regras.append('{ match = "window_type = \'normal\' && class_g != \'carinae-shell\' && !focused && !group_focused"; %s}' % x)
    regras.append('{ match = "window_type = \'dock\' || window_type = \'desktop\' || class_g = \'carinae-shell\' || '
                  '_GTK_FRAME_EXTENTS@ || _NET_WM_STATE@[*] = \'_NET_WM_STATE_HIDDEN\'"; shadow = false; }')
    regras.append('{ match = "window_type = \'dock\' || window_type = \'desktop\' || window_type = \'menu\' || '
                  'window_type = \'popup_menu\' || window_type = \'dropdown_menu\' || window_type = \'tooltip\' || '
                  'class_g = \'carinae-shell\' || fullscreen"; corner-radius = 0; }')
    if blur:
        regras.append('{ match = "class_g = \'carinae-shell\' || window_type = \'menu\' || window_type = \'popup_menu\' || '
                      'window_type = \'dropdown_menu\'"; blur-background = true; }')
    l.append('rules = (\n    ' + ',\n    '.join(regras) + '\n);')
    return '\n'.join(l) + '\n'


def picom(mudanca):
    """Regenera o picom.conf com a escolha nova e reinicia o picom. Se o picom não arrancar
    com o ficheiro novo, volta ao anterior (o ambiente nunca fica sem compositor por causa disto)."""
    import time
    esc = ler_escolhas()
    esc.update(mudanca)
    backend = _picom_backend()
    texto = gerar_picom(esc, backend or 'glx')
    try:
        with open(PICOM_USER, encoding='utf-8') as f:
            antes = f.read()
    except OSError:
        antes = None
    os.makedirs(PASTA, exist_ok=True)
    with open(PICOM_USER, 'w', encoding='utf-8') as f:
        f.write(texto)
    if backend is None:          # sem compositor (modo leve): fica para a próxima sessão
        return True

    def arrancar():
        _c(['pkill', '-x', 'picom'])
        for _ in range(20):
            if subprocess.run(['pgrep', '-x', 'picom'], capture_output=True).returncode != 0:
                break
            time.sleep(0.1)
        log = open(os.path.expanduser('~/.cache/carinaeos/picom.log'), 'a')
        p = subprocess.Popen(['picom', '--config', PICOM_USER, '--backend', backend],
                             stdout=log, stderr=log, start_new_session=True)
        time.sleep(1.5)
        return p.poll() is None

    os.makedirs(os.path.expanduser('~/.cache/carinaeos'), exist_ok=True)
    if arrancar():
        return True
    if antes is None:
        os.remove(PICOM_USER)
    else:
        with open(PICOM_USER, 'w', encoding='utf-8') as f:
            f.write(antes)
    if not os.path.exists(PICOM_USER):
        for c in ('/usr/local/share/carinaeos/picom.conf', '/usr/share/carinaeos/picom.conf'):
            if os.path.exists(c):
                import shutil
                shutil.copy(c, PICOM_USER)
                break
    arrancar()
    return False


# Alt+Tab: os modelos da Supernova -> os painéis da Aurora (Alternar.qml)
ALTTAB_CARINAE = {'simples': 'simples', 'thumbnail_grid': 'grade', 'big_icons': 'icones', 'sidebar': 'lista',
                  'compact': 'compacto', 'coverswitch': 'coverflow', 'flipswitch': 'flip'}
# janelas de gelatina: quanto a janela "passa do sítio" e volta, e quanto tempo leva
GELATINA = {'0': (1.15, 0.25), '1': (1.45, 0.35), '3': (1.85, 0.45), '4': (2.3, 0.55)}


def _elastico(nivel, vel):
    y, dur = GELATINA[nivel]
    dur *= vel
    curva = 'cubic-bezier(0.3, %.2f, 0.5, 1)' % y
    def v(nome, ini, fim):
        return '%s = { curve = "%s"; duration = %.3f; start = "%s"; end = %s; }; ' % (nome, curva, dur, ini, fim)
    return ('{ triggers = [ "geometry" ]; ' + v('offset-x', 'window-x-before - window-x', 0)
            + v('offset-y', 'window-y-before - window-y', 0)
            + v('scale-x', 'window-width-before / window-width', 1) + v('scale-y', 'window-height-before / window-height', 1)
            + 'saved-image-blend = { duration = %.3f; start = 1; end = 0; }; ' % dur
            + 'shadow-offset-x = "offset-x"; shadow-offset-y = "offset-y"; shadow-scale-x = "scale-x"; shadow-scale-y = "scale-y"; }')


CURSORES = {'escuro': ('breeze_cursors', 24), 'claro': ('Breeze_Light', 24), 'escuro-grande': ('breeze_cursors', 36),
            'claro-grande': ('Breeze_Light', 36), 'enorme': ('breeze_cursors', 48)}


def cursor_existe(tema):
    return any(os.path.isdir(os.path.join(b, tema, 'cursors'))
               for b in ('/usr/share/icons', '/usr/local/share/icons', os.path.expanduser('~/.icons'),
                         os.path.expanduser('~/.local/share/icons')))


# ---- como aplicar cada modelo -----------------------------------------------------------------
DTD = 'org.gnome.shell.extensions.dash-to-dock'
DTD_ESTILOS = {   # cor de fundo, opacidade (0..1)
    'mac': ('#d9d4de', 0.30), 'escuro': ('#1d1a23', 0.65), 'transparente': ('#000000', 0.0),
    'bolhas': ('#cfe3ff', 0.40), 'squircle': ('#36363a', 0.85), 'rosepine': ('#191724', 0.90),
    'xp': ('#2f6fe6', 0.95), 'vista': ('#1b2633', 0.70), 'translucido': ('#ffffff', 0.08),
    'docklike': ('#232323', 0.72), 'matter': ('#2b2930', 1.0), 'lucent': ('#f2f2f2', 0.55), 'neon': ('#14091e', 0.80),
    'vidro': ('#cfd8ff', 0.20), 'fluent': ('#18181f', 0.85), 'minimalista': ('#000000', 0.0), 'colorida': ('#0e0f33', 0.88),
    'orbital': ('#000000', 0.0), 'hexagonal': ('#000000', 0.0), 'aereo': ('#9db4ff', 0.18), 'icones': ('#000000', 0.0), 'redondos': ('#000000', 0.0), 'simples': ('#18181f', 0.85)}


def a_estilo_dock(m):
    if AMB == 'carinae':
        dock(estilo=m, semEfeitos=(m == 'simples'))
        return
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
    if AMB == 'carinae':
        estilo = ALTTAB_CARINAE.get(m, 'simples')
        shell(altTab=estilo)
        gravidade('alttab', 'simples' if estilo == 'simples' else 'painel')
        return
    kw('kwinrc', 'TabBox', 'LayoutName', m)
    kwin()


def a_minimizar(m):
    if AMB == 'carinae':
        picom({'minimizar': m})
        return
    if AMB != 'plasma':
        return
    efeito('magiclamp', m == 'lampada')
    efeito('squash', m == 'encolher')
    kwin()


def a_abrir(m):
    if AMB == 'carinae':
        picom({'abrir': m})
        return
    efeito('scale', m in ('zoom', 'supernova'))
    efeito('fade', m == 'desvanecer')
    efeito('glide', m == 'tresd')
    efeito('fallapart', m == 'supernova')
    kwin()


def a_mesa(m):
    if AMB == 'carinae':
        shell(cliqueMesa='' if m == 'nao' else 'esconder')
        return
    kw('kwinrc', 'Script-carinaeos-mesa', 'mostrarMesaAoClicar', 'false' if m == 'nao' else 'true')
    efeito('windowaperture', m == 'afastar')
    efeito('slidingpopups', True)
    kw('kwinrc', 'Plugins', 'carinaeos-mesaEnabled', 'true')
    _c(['qdbus6', 'org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting.unloadScript', 'carinaeos-mesa'])
    _c(['qdbus6', 'org.kde.KWin', '/Scripting', 'org.kde.kwin.Scripting.start'])
    kwin()


def a_canto(m):
    if AMB == 'carinae':
        shell(canto=m)
        return
    if AMB == 'gnome':
        gs('org.gnome.desktop.interface', 'enable-hot-corners', 'true' if m == 'visao' else 'false')
        return
    # o canto superior esquerdo: Visao geral (7 = canto sup. esq.; 9 = nenhum)
    kw('kwinrc', 'Effect-overview', 'BorderActivate', '7' if m == 'visao' else '9')
    kw('kwinrc', 'ElectricBorders', 'TopLeft', {'mesa': 'ShowDesktop', 'bloquear': 'LockScreen'}.get(m, 'None'))
    kw('kwinrc', 'Effect-windowview', 'BorderActivateAll', '7' if m == 'janelas' else '9')
    kwin()


def a_botoes(m):
    if AMB == 'carinae':
        gravidade('botoes', m if m in ('mac', 'windows', 'fechar') else 'mac')
        return
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
    if AMB == 'carinae':
        picom({'sombra': m})
        return
    kw('breezerc', 'Common', 'ShadowSize', m)
    kwin()


def a_transparencia(m):
    if AMB == 'carinae':
        picom({'transparencia': m})
        return
    sim = m != '100'
    efeito('translucency', sim)
    kw('kwinrc', 'Effect-translucency', 'Inactive', m)
    kw('kwinrc', 'Effect-translucency', 'MoveResize', '80' if sim else '100')
    kwin()


def a_desfoque(m):
    if AMB == 'carinae':
        picom({'desfoque': m})
        return
    efeito('blur', m != '0')
    if m != '0':
        kw('kwinrc', 'Effect-blur', 'BlurStrength', m)
    kwin()


def a_velocidade(m):
    if AMB == 'carinae':
        picom({'velocidade': m})
        return
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
    if AMB == 'carinae':
        tema, tam = CURSORES[m]
        d = os.path.expanduser('~/.icons/default')
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, 'index.theme'), 'w') as f:
            f.write('[Icon Theme]\nName=Default\nInherits=%s\n' % tema)
        with open(os.path.expanduser('~/.Xresources.carinaeos-cursor'), 'w') as f:
            f.write('Xcursor.theme: %s\nXcursor.size: %d\n' % (tema, tam))
        _c(['xrdb', '-merge', os.path.expanduser('~/.Xresources.carinaeos-cursor')])
        for g in ('gtk-3.0', 'gtk-4.0'):
            ini = os.path.expanduser('~/.config/%s/settings.ini' % g)
            try:
                with open(ini, encoding='utf-8') as f:
                    linhas = [l for l in f.read().splitlines() if not l.startswith(('gtk-cursor-theme-name', 'gtk-cursor-theme-size'))]
            except OSError:
                linhas = ['[Settings]']
            linhas += ['gtk-cursor-theme-name=%s' % tema, 'gtk-cursor-theme-size=%d' % tam]
            os.makedirs(os.path.dirname(ini), exist_ok=True)
            with open(ini, 'w', encoding='utf-8') as f:
                f.write('\n'.join(linhas) + '\n')
        _c(['xsetroot', '-cursor_name', 'left_ptr'])
        return
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
    if AMB == 'carinae':
        # a mesma luz noturna da central da barra (gama do xrandr), com a força escolhida
        gama = {'nao': '1:1:1', '4500': '1.0:0.90:0.80', '3500': '1.0:0.84:0.66', '2700': '1.0:0.75:0.52'}[m]
        os.makedirs(PASTA, exist_ok=True)
        with open(os.path.join(PASTA, 'luz-noturna'), 'w') as f:
            f.write('0\n' if m == 'nao' else '1\n')
        try:
            brilho = open(os.path.join(PASTA, 'brilho')).read().strip() or '1.0'
        except OSError:
            brilho = '1.0'
        r = subprocess.run(['xrandr', '--query'], capture_output=True, text=True)
        for linha in r.stdout.splitlines():
            if ' connected' in linha:
                _c(['xrandr', '--output', linha.split()[0], '--gamma', gama, '--brightness', brilho])
        return
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


def a_achar(m):
    if AMB == 'carinae':
        shell(agitarCursor=(m == 'sim'))
        return
    efeito('shakecursor', m == 'sim')


def a_deslizar(m):
    efeito('slide', m == 'sim')
    kwin()


def a_janela_foco(m):
    if AMB == 'carinae':
        picom({'foco': m})
        return
    efeito('diminactive', m != 'nao')
    if m != 'nao':
        kw('kwinrc', 'Effect-diminactive', 'Strength', m)
    kwin()


def a_gelatina(m):
    if AMB == 'carinae':
        picom({'gelatina': m})
        return
    efeito('wobblywindows', m != 'nao')
    if m != 'nao':
        kw('kwinrc', 'Effect-wobblywindows', 'WobblynessLevel', m)   # 0 (pouco) .. 4 (muito)
    kwin()


# ---- catalogo ---------------------------------------------------------------------------------
# "inspirado": o mod do Windhawk (Windows) em que o modelo se baseia
MODS = [
    dict(id='estilo_dock', cat='dock', nome='Estilo da Dock', icone='carinaeos-estrela', aplicar=a_estilo_dock, padrao='fluent',
         inspirado='Windows 11 Taskbar Styler',
         desc='O fundo por trás dos ícones da Dock e se ela tem efeitos.',
         modelos=[
             dict(id='fluent', nome='Padrão', desc='Escura; o ícone cresce um pouco e salta ao abrir.', cor='#18181f'),
             dict(id='simples', nome='Sem efeitos', desc='Escura; o ícone só acende ao passar o mouse.', cor='#18181f'),
             dict(id='icones', nome='Só ícones', desc='Sem o fundo da Dock; o ícone acende ao passar o mouse.', cor='#00000000'),
         ]),
    dict(id='visivel', cat='dock', nome='Dock sempre à vista', icone='view-visible', aplicar=a_visivel, padrao='sempre',
         inspirado='Taskbar auto-hide',
         desc='A Dock (e a barra de cima) ficam sempre na tela, ou escondem-se.',
         modelos=[
             dict(id='sempre', nome='Sempre visível', desc='Como a barra de cima: nunca se esconde (padrão).'),
             dict(id='janelas', nome='Sai do caminho', desc='Esconde-se quando uma janela passa por cima.'),
             dict(id='esconder', nome='Esconder sempre', desc='Aparece ao levar o mouse ao fundo da tela.'),
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
             dict(id='suave', nome='Desvanecer', desc='A janela desaparece suavemente.'),
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
    dict(id='mesa', cat='mesa', nome='Clicar no papel de parede', icone='user-desktop', aplicar=a_mesa, padrao='nao',
         inspirado='Click on empty taskbar space / Show desktop',
         desc='Clicar numa parte vazia do papel de parede mostra a área de trabalho.',
         modelos=[
             dict(id='afastar', nome='Afastar as janelas', desc='As janelas vão para os cantos, como no macOS Sonoma.'),
             dict(id='minimizar', nome='Esconder tudo', desc='Esconde as janelas de uma vez, como no Windows.'),
             dict(id='nao', nome='Não fazer nada', desc='Clicar no papel de parede não muda nada.'),
         ]),
    dict(id='canto', cat='mesa', nome='Canto superior esquerdo', icone='view-app-grid', aplicar=a_canto, padrao='nada',
         inspirado='Hot corners',
         desc='Leve o mouse ao canto superior esquerdo da tela para…',
         modelos=[
             dict(id='nada', nome='Nada', desc='O canto não faz nada.'),
             dict(id='visao', nome='Visão geral', desc='Todas as janelas e áreas de trabalho (Mission Control).'),
             dict(id='janelas', nome='Todas as janelas', desc='Só as janelas, lado a lado (Exposé).'),
             dict(id='mesa', nome='Mostrar a área de trabalho', desc='Afasta as janelas.'),
             dict(id='bloquear', nome='Bloquear a tela', desc='Bloqueia logo, para sair às pressas.'),
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
         desc='Deixa as janelas que não está usando um pouco transparentes.',
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
             dict(id='2.5', nome='Cinema', desc='Tudo em câmera lenta.'),
         ]),
    dict(id='roda', cat='dock', nome='Roda do mouse na Dock', icone='audio-volume-high', aplicar=a_roda, padrao='5',
         inspirado='Taskbar Volume Control',
         desc='Rodar a roda do mouse por cima da Dock muda o volume.',
         modelos=[
             dict(id='2', nome='Passos finos', desc='2% de cada vez.'),
             dict(id='5', nome='Normal', desc='5% de cada vez.'),
             dict(id='10', nome='Rápido', desc='10% de cada vez.'),
             dict(id='nao', nome='Desligado', desc='A roda não faz nada na Dock.'),
         ]),
    dict(id='meio', cat='dock', nome='Clique do meio na Dock', icone='input-mouse', aplicar=a_meio, padrao='nova',
         inspirado='Middle click to close on the taskbar',
         desc='O que faz o clique com a roda do mouse num ícone da Dock.',
         modelos=[
             dict(id='nova', nome='Nova janela', desc='Abre outra janela do aplicativo.'),
             dict(id='fechar', nome='Fechar', desc='Fecha o aplicativo, como no mod do Windhawk.'),
         ]),
    dict(id='cursor', cat='mesa', nome='Cursor do mouse', icone='input-mouse', aplicar=a_cursor, padrao='escuro',
         inspirado='Cursor customization',
         desc='A cor e o tamanho do cursor.',
         modelos=[
             dict(id='escuro', nome='Escuro', desc='Padrão.'),
             dict(id='claro', nome='Claro', desc='Branco, como no Mac.'),
             dict(id='escuro-grande', nome='Escuro grande', desc='Mais fácil de ver.'),
             dict(id='claro-grande', nome='Claro grande', desc='Branco e maior.'),
             dict(id='enorme', nome='Enorme', desc='Para telas grandes ou TV.'),
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
         desc='Escurece as janelas que não está usando, para se concentrar numa só.',
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
         inspirado='Shake to find cursor', desc='Agite o mouse e o cursor cresce para o encontrar.',
         modelos=[dict(id='sim', nome='Ligado', desc=''), dict(id='nao', nome='Desligado', desc='')]),
    dict(id='deslizar', cat='mesa', nome='Trocar de área de trabalho', icone='go-next', aplicar=a_deslizar, padrao='sim',
         inspirado='Virtual desktop animation', desc='Animação ao passar de uma área de trabalho para outra.',
         modelos=[dict(id='sim', nome='Deslizar', desc=''), dict(id='nao', nome='Sem animação', desc='')]),
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
    'carinae': {'estilo_dock', 'roda', 'meio', 'minimizar', 'abrir', 'botoes', 'sombra', 'transparencia', 'desfoque',
                'velocidade', 'foco', 'mesa', 'cursor', 'noite', 'troca', 'canto', 'achar', 'gelatina'},
    'gnome': {'visivel', 'estilo_dock', 'botoes', 'cursor', 'noite', 'velocidade', 'canto'},
    'xfce': {'visivel', 'botoes', 'cursor'},
}


# no CarinaeOS, o padrão é o que a sessão já faz sem a Supernova
PADRAO_CARINAE = {'abrir': 'desvanecer', 'minimizar': 'suave', 'sombra': 'ShadowMedium', 'desfoque': '0',
                  'troca': 'simples', 'canto': 'nada', 'achar': 'nao', 'gelatina': 'nao'}
# o que cada modelo faz na Gravidade/picom, quando é diferente do Plasma
DESC_CARINAE = {('abrir', 'tresd'): ('Voar', 'A janela sobe ao abrir e desce ao fechar.'),
                ('abrir', 'supernova'): ('Supernova', 'Zoom ao abrir; ao fechar a janela expande-se e desvanece.'),
                ('minimizar', 'lampada'): ('Descer para a Dock', 'A janela desce para a Dock.'),
                ('mesa', 'minimizar'): ('Esconder tudo', 'Esconde as janelas; outro clique volta a mostrá-las.'),
                ('troca', 'flipswitch'): ('Flip 3D', 'As janelas em pilha, em perspetiva, como no Windows Vista.'),
                ('troca', 'coverswitch'): ('Cover Flow', 'Carrossel em 3D: a escolhida de frente, as outras de lado.'),
                ('canto', 'visao'): ('Visão geral', 'Todas as janelas lado a lado, para escolher uma.'),
                ('gelatina', '0'): ('Firme', 'Um pequeno balanço ao largar a janela.'),
                ('gelatina', '1'): ('Normal', 'A janela passa um pouco do sítio e volta.'),
                ('gelatina', '3'): ('Mole', 'Balança bem ao mover e ao mudar de tamanho.'),
                ('gelatina', '4'): ('Gelatina!', 'Muito elástica.')}


def padrao(m):
    return PADRAO_CARINAE.get(m['id'], m['padrao']) if AMB == 'carinae' else m['padrao']


def lista():
    esc = ler_escolhas()
    res = []
    for m in MODS:
        disponivel = AMB == 'plasma' or m['id'] in ONDE.get(AMB, set())
        if AMB == 'carinae' and not disponivel:
            continue        # no CarinaeOS só aparece o que funciona
        r = {k: v for k, v in m.items() if k != 'aplicar'}
        r['padrao'] = padrao(m)
        r['escolhido'] = esc.get(m['id'], r['padrao'])
        r['disponivel'] = disponivel
        if AMB == 'carinae':
            mods_ = []
            for x in m['modelos']:
                if m['id'] == 'mesa' and x['id'] == 'afastar':
                    continue
                if m['id'] == 'canto' and x['id'] == 'janelas':
                    continue
                if m['id'] == 'cursor' and not cursor_existe(CURSORES[x['id']][0]):
                    continue
                x = dict(x)
                if (m['id'], x['id']) in DESC_CARINAE:
                    x['nome'], x['desc'] = DESC_CARINAE[(m['id'], x['id'])]
                mods_.append(x)
            if m['id'] == 'troca':
                mods_.insert(0, dict(id='simples', nome='Só trocar', desc='Sem painel: a janela escolhida vem logo para a frente.'))
            r['modelos'] = mods_
            r['inspirado'] = m.get('inspirado', '')
        elif m['id'] == 'minimizar':
            r['modelos'] = [x for x in m['modelos'] if x['id'] != 'suave']
        if AMB == 'gnome' and m['id'] == 'canto':
            r['modelos'] = [x for x in m['modelos'] if x['id'] in ('nada', 'visao')]
        if AMB == 'gnome' and m['id'] == 'velocidade':
            r['modelos'] = [x for x in m['modelos'] if x['id'] in ('0', '1')]
        res.append(r)
    return res


def escolher(ident, modelo):
    m = next((x for x in MODS if x['id'] == ident), None)
    extra = ['simples'] if (AMB == 'carinae' and ident == 'troca') else []
    if not m or modelo not in [x['id'] for x in m['modelos']] + extra:
        return False
    m['aplicar'](modelo)
    esc = ler_escolhas()
    esc[ident] = modelo
    gravar_escolhas(esc)
    return True


# perfis: um conjunto de modelos de uma vez
PERFIS = [
    dict(id='mac', nome='Mac clássico', icone='carinaeos-estrela',
         desc='Lâmpada mágica, botões à esquerda e Alt+Tab em grade.',
         desc_carinae='Zoom ao abrir, janelas a descer para a Dock, botões à esquerda e sombra grande.',
         escolhas=dict(estilo_dock='fluent', minimizar='lampada', abrir='zoom', botoes='mac', troca='thumbnail_grid',
                       sombra='ShadowLarge', desfoque='10', mesa='afastar', canto='visao', gelatina='nao', velocidade='1')),
    dict(id='vista', nome='Vista retrô', icone='preferences-desktop-effects',
         desc='Flip 3D no Alt+Tab, janelas a entrar em 3D e botões à direita.',
         desc_carinae='Janelas a voar, botões à direita e sombra enorme.',
         escolhas=dict(estilo_dock='fluent', minimizar='encolher', abrir='tresd', botoes='windows', troca='flipswitch',
                       sombra='ShadowVeryLarge', desfoque='15', mesa='minimizar', canto='nada', gelatina='nao', velocidade='1')),
    dict(id='xp', nome='Nostalgia XP', icone='computer',
         desc='Botões à direita, Alt+Tab compacto e animações rápidas.',
         desc_carinae='Botões à direita, Dock sem efeitos e animações rápidas.',
         escolhas=dict(estilo_dock='simples', minimizar='encolher', abrir='desvanecer', botoes='windows', troca='compact',
                       sombra='ShadowMedium', desfoque='0', mesa='minimizar', canto='nada', gelatina='nao', velocidade='0.5')),
    dict(id='supernova', nome='Supernova total', icone='carinaeos-supernova',
         desc='Gelatina, explosão ao fechar, Cover Flow e Foco estelar.',
         desc_carinae='Explosão ao fechar, vidro fosco forte, Foco estelar e animações lentas.',
         escolhas=dict(estilo_dock='fluent', minimizar='lampada', abrir='supernova', botoes='mac', troca='coverswitch',
                       sombra='ShadowLarge', desfoque='15', mesa='afastar', canto='visao', gelatina='3', foco='15', velocidade='1.6')),
    dict(id='rosepine', nome='Rosé Pine', icone='color-management',
         desc='Tons de rosa e roxo, Dock só com ícones, janelas translúcidas e luz noturna suave.',
         escolhas=dict(estilo_dock='icones', minimizar='lampada', abrir='desvanecer', botoes='mac', troca='thumbnail_grid',
                       transparencia='92', noite='4500', gelatina='nao')),
    dict(id='leve', nome='Leve e rápido', icone='speedometer',
         desc='Quase sem efeitos: ideal para computadores mais fracos.',
         desc_carinae='Quase sem efeitos: ideal para computadores mais fracos.',
         escolhas=dict(estilo_dock='simples', minimizar='nada', abrir='nada', troca='compact', sombra='ShadowSmall',
                       desfoque='0', transparencia='100', gelatina='nao', foco='nao', velocidade='0.5')),
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
            escolher(m['id'], padrao(m))
