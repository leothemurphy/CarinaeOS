# CarinaeOS — Configurações: Aparência, Notificações, Pesquisa, Região e idioma e Acessibilidade,
# sem o KDE (kcm_colors, kcm_notifications, Baloo, kcm_regionandlang, kcm_access).
import glob
import json
import os
import re
import subprocess
import time

HOME = os.path.expanduser('~')
CFG = os.path.join(HOME, '.config', 'carinaeos')
C = dict(os.environ, LC_ALL='C', LANG='C', LANGUAGE='C')


def _cmd(args, timeout=10, amb=None):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout, env=amb)
        return r.returncode, r.stdout.strip(), r.stderr.strip()
    except Exception as e:
        return 1, '', str(e)


def _ler(nome, padrao):
    try:
        return dict(padrao, **json.load(open(os.path.join(CFG, nome), encoding='utf-8')))
    except (OSError, ValueError):
        return dict(padrao)


def _gravar(nome, d):
    os.makedirs(CFG, exist_ok=True)
    f = os.path.join(CFG, nome)
    with open(f + '.tmp', 'w', encoding='utf-8') as o:
        json.dump(d, o, ensure_ascii=False, indent=1)
    os.replace(f + '.tmp', f)


def _texto(f, padrao=''):
    try:
        return open(f, encoding='utf-8').read().strip()
    except OSError:
        return padrao


# =========================================================================================================
# Aparência
# =========================================================================================================
def aparencia_estado():
    a = _ler('aparencia.json', dict(tema='escuro'))
    shell = {}
    try:
        shell = json.load(open(os.path.join(HOME, '.config', 'carinaeos-shell.json'), encoding='utf-8'))
    except (OSError, ValueError):
        pass
    papeis, vistos = [], set()
    candidatos = []
    for pasta in (os.path.join(HOME, '.local/share/carinaeos/papeis'), '/usr/local/share/carinaeos/papeis',
                  '/usr/share/backgrounds/carinaeos'):
        candidatos += sorted(glob.glob(os.path.join(pasta, '*.jpg')) + glob.glob(os.path.join(pasta, '*.png')))
    for d in sorted(glob.glob('/usr/share/wallpapers/*/contents/images')):
        imgs = sorted(glob.glob(os.path.join(d, '*.jpg')) + glob.glob(os.path.join(d, '*.png')))
        if imgs:
            candidatos.append(next((i for i in imgs if '1920x1080' in i), imgs[-1]))
    for c in candidatos:
        if c not in vistos:
            vistos.add(c)
            papeis.append(dict(caminho=c, nome=os.path.splitext(os.path.basename(c))[0]))
    return dict(tema=a['tema'], claro=a['tema'] == 'claro', papel=shell.get('papel', ''), papeis=papeis[:40],
                luzNoturna=_texto(os.path.join(CFG, 'luz-noturna')) == '1')


def definir_tema(tema):
    a = _ler('aparencia.json', dict(tema='escuro'))
    a['tema'] = tema
    _gravar('aparencia.json', a)
    # os programas GTK/Electron e os Qt passam ao tema escolhido (os que já estão abertos: ao reabrir)
    _cmd(['carinae-aparencia-gtk', '--forcar'], 30)
    _cmd(['carinae-aparencia-qt', '--forcar'], 30)


def definir_papel(caminho):
    f = os.path.join(HOME, '.config', 'carinaeos-shell.json')
    try:
        c = json.load(open(f, encoding='utf-8'))
    except (OSError, ValueError):
        c = {}
    c['papel'] = caminho
    c['papel2'] = caminho
    with open(f + '.tmp', 'w', encoding='utf-8') as o:
        json.dump(c, o, ensure_ascii=False)
    os.replace(f + '.tmp', f)


def luz_noturna(ligar):
    """Cores mais quentes (a mesma luz noturna da central de ajustes da barra)."""
    os.makedirs(CFG, exist_ok=True)
    with open(os.path.join(CFG, 'luz-noturna'), 'w') as o:
        o.write('1\n' if ligar else '0\n')
    brilho = _texto(os.path.join(CFG, 'brilho'), '1.0') or '1.0'
    gama = '1.0:0.84:0.66' if ligar else '1:1:1'
    _, q, _ = _cmd(['xrandr', '--query'])
    for linha in q.splitlines():
        if ' connected' in linha:
            _cmd(['xrandr', '--output', linha.split()[0], '--gamma', gama, '--brightness', brilho])


# =========================================================================================================
# Notificações
# =========================================================================================================
NI = os.path.join(CFG, 'nao-incomodar')
HISTORICO = os.path.join(HOME, '.local/share/carinaeos/notificacoes.json')


def notificacoes_estado():
    try:
        n = len(json.load(open(HISTORICO, encoding='utf-8')))
    except (OSError, ValueError):
        n = 0
    _, dono, _ = _cmd(['gdbus', 'call', '--session', '--dest', 'org.freedesktop.DBus', '--object-path', '/org/freedesktop/DBus',
                       '--method', 'org.freedesktop.DBus.GetNameOwner', 'org.freedesktop.Notifications'], 5)
    _, info, _ = _cmd(['gdbus', 'call', '--session', '--dest', 'org.freedesktop.Notifications', '--object-path',
                       '/org/freedesktop/Notifications', '--method', 'org.freedesktop.Notifications.GetServerInformation'], 5)
    return dict(naoIncomodar=os.path.exists(NI), historico=n, servidor=info.split("'")[1] if "'" in info else '')


def nao_incomodar(ligar):
    os.makedirs(CFG, exist_ok=True)
    if ligar:
        open(NI, 'w').close()
    elif os.path.exists(NI):
        os.remove(NI)


def aviso_teste():
    _cmd(['notify-send', '-a', 'CarinaeOS', '-i', 'preferences-desktop-notification', 'Assim são os avisos',
          'Aparecem no canto de cima à direita e ficam guardados na central de ajustes.'])


# =========================================================================================================
# Pesquisa (o índice de ficheiros do sistema: plocate, no lugar do Baloo do KDE)
# =========================================================================================================
def pesquisa_estado():
    db = next((f for f in ('/var/lib/plocate/plocate.db', '/var/lib/mlocate/mlocate.db') if os.path.exists(f)), '')
    _, ativo, _ = _cmd(['systemctl', 'is-enabled', 'plocate-updatedb.timer'])
    baloo = bool(glob.glob('/usr/bin/balooctl*'))
    baloo_ligado = baloo and 'Indexing-Enabled=false' not in _texto(os.path.join(HOME, '.config/baloofilerc'))
    return dict(temPlocate=bool(_cmd(['sh', '-c', 'command -v plocate || command -v locate'])[1]),
                atualizado=time.strftime('%d/%m/%Y às %H:%M', time.localtime(os.path.getmtime(db))) if db else '',
                automatico=ativo == 'enabled', baloo=baloo, balooLigado=baloo_ligado)


def pesquisa_atualizar():
    c, _, e = _cmd(['pkexec', 'updatedb'], 900)
    return '' if c == 0 else (e or 'falhou')


def baloo(ligar):
    for b in ('balooctl6', 'balooctl'):
        if _cmd(['sh', '-c', 'command -v ' + b])[0] == 0:
            _cmd([b, 'enable' if ligar else 'disable'], 30)
            if not ligar:
                _cmd([b, 'purge'], 60)       # apaga o índice antigo (às vezes são gigabytes)
            return ''
    return 'o Baloo não está instalado'


# =========================================================================================================
# Região e idioma
# =========================================================================================================
NOMES_LINGUA = {'pt_PT': 'Português (Portugal)', 'pt_BR': 'Português (Brasil)', 'en_US': 'English (US)',
                'en_GB': 'English (UK)', 'es_ES': 'Español (España)', 'fr_FR': 'Français', 'de_DE': 'Deutsch',
                'it_IT': 'Italiano', 'C': 'Sem idioma (C)'}


def _nome_locale(l):
    base = l.split('.')[0]
    return NOMES_LINGUA.get(base, base)


def regiao_estado():
    _, s, _ = _cmd(['localectl', 'status'], amb=C)
    atual = dict(re.findall(r'(LANG|LC_\w+)=(\S+)', s))
    _, lst, _ = _cmd(['localectl', 'list-locales'])
    disponiveis = [l for l in lst.splitlines() if l.endswith(('.UTF-8', '.utf8')) or l == 'C.UTF-8']
    suportados = []
    try:
        for linha in open('/usr/share/i18n/SUPPORTED', encoding='utf-8'):
            p = linha.split()
            if len(p) == 2 and p[1] == 'UTF-8':
                suportados.append(p[0])
    except OSError:
        pass
    lang = atual.get('LANG', 'C.UTF-8')
    return dict(idioma=lang, formatos=atual.get('LC_TIME', lang),
                disponiveis=[dict(codigo=l, nome='%s  —  %s' % (_nome_locale(l), l)) for l in disponiveis],
                porInstalar=[dict(codigo=l, nome='%s  —  %s' % (_nome_locale(l), l)) for l in suportados
                             if l not in disponiveis and l.replace('.UTF-8', '.utf8') not in disponiveis
                             and re.match(r'(pt|en|es|fr|de|it)_', l)][:40])


def regiao_definir(idioma, formatos):
    args = ['localectl', 'set-locale', 'LANG=' + idioma]
    if formatos and formatos != idioma:
        args += ['LC_TIME=' + formatos, 'LC_NUMERIC=' + formatos, 'LC_MONETARY=' + formatos,
                 'LC_PAPER=' + formatos, 'LC_MEASUREMENT=' + formatos]
    c, _, e = _cmd(args, 120)
    return '' if c == 0 else (e or 'falhou')


def regiao_instalar(locale):
    if not re.fullmatch(r'[a-z]{2,3}_[A-Z]{2}\.UTF-8', locale):
        return 'nome inválido'
    script = ("sed -i 's/^# *%s UTF-8/%s UTF-8/' /etc/locale.gen && grep -q '^%s UTF-8' /etc/locale.gen "
              "|| echo '%s UTF-8' >> /etc/locale.gen; locale-gen") % ((locale.replace('.', '\\.'),) + (locale,) * 3)
    c, _, e = _cmd(['pkexec', '/bin/sh', '-c', script], 600)
    return '' if c == 0 else (e or 'falhou')


# =========================================================================================================
# Acessibilidade (vale a partir do próximo início de sessão; o cursor também logo nos programas novos)
# =========================================================================================================
def acess_estado():
    return _ler('acessibilidade.json', dict(texto=100, cursor=24, animacoes=True))


def acess_mudar(chave, valor):
    a = acess_estado()
    a[chave] = valor
    _gravar('acessibilidade.json', a)
    # tamanho do texto e do cursor: pelos Xresources (que a sessão lê ao arrancar) e pelo GTK
    xr = os.path.join(HOME, '.Xresources')
    linhas = [l for l in _texto(xr).splitlines() if not l.startswith(('Xft.dpi:', 'Xcursor.size:'))]
    linhas += ['Xft.dpi: %d' % round(96 * int(a['texto']) / 100), 'Xcursor.size: %d' % int(a['cursor'])]
    with open(xr, 'w') as o:
        o.write('\n'.join(l for l in linhas if l.strip()) + '\n')
    _cmd(['xrdb', '-merge', xr])
    _cmd(['gsettings', 'set', 'org.gnome.desktop.interface', 'text-scaling-factor', '%.2f' % (int(a['texto']) / 100)])
    _cmd(['gsettings', 'set', 'org.gnome.desktop.interface', 'cursor-size', str(int(a['cursor']))])
    _cmd(['gsettings', 'set', 'org.gnome.desktop.interface', 'enable-animations', 'true' if a['animacoes'] else 'false'])
