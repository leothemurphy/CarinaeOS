# CarinaeOS - os aplicativos instalados, de todas as origens, num só lugar (como o "Aplicativos
# instalados" do Windows): Flathub, Debian, AppImage, apps Electron e programas do Windows (Bottles).
# Usado pelas Configurações (página Aplicativos) e pelo comando carinaeos-desinstalar.
import configparser
import glob
import json
import os
import re
import shutil
import subprocess

HOME = os.path.expanduser('~')
APPS_USUARIO = os.path.join(HOME, '.local/share/applications')
PASTA_APPS = os.path.join(HOME, 'Aplicativos')
BOTTLES = 'com.usebottles.bottles'
# o que é o próprio sistema: nunca se oferece para remover
PROTEGIDOS = re.compile(r'^(carinaeos.*|plasma.*|kwin.*|sddm.*|systemsettings|dolphin|konsole|kio.*|kde.*|libkf.*|'
                        r'xdg-desktop-portal.*|flatpak|apt|dpkg|calamares.*|plymouth.*|network-manager.*|pipewire.*|'
                        r'wireplumber|polkit.*|systemd.*|udisks2|kscreen|powerdevil|bluedevil|breeze.*|'
                        r'khelpcenter|kinfocenter|kmenuedit|discover|plasma-discover.*)$')


def _cmd(args, timeout=20):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).stdout
    except Exception:
        return ''


def _desktop(caminho):
    cp = configparser.RawConfigParser(strict=False, interpolation=None)
    cp.optionxform = str
    try:
        cp.read(caminho, encoding='utf-8')
        return dict(cp['Desktop Entry'])
    except Exception:
        return {}


def _tam_pasta(p):
    total = 0
    for raiz, _, arqs in os.walk(p):
        for a in arqs:
            try:
                total += os.lstat(os.path.join(raiz, a)).st_size
            except OSError:
                pass
    return total


def _bytes(txt):
    """'1,2 GB' / '512.0 MB' (flatpak) -> bytes."""
    m = re.match(r'([\d.,]+)\s*([kKMGT]?)i?B', (txt or '').strip())
    if not m:
        return 0
    n = float(m.group(1).replace(',', '.'))
    return int(n * {'': 1, 'k': 1e3, 'K': 1e3, 'M': 1e6, 'G': 1e9, 'T': 1e12}[m.group(2)])


def _mtime(p):
    try:
        return int(os.stat(p).st_mtime)
    except OSError:
        return 0


def _visivel(d):
    return (d.get('Type', 'Application') == 'Application' and d.get('NoDisplay', 'false').lower() != 'true'
            and d.get('Hidden', 'false').lower() != 'true' and d.get('Name'))


def flatpak():
    res = []
    for linha in _cmd(['flatpak', 'list', '--app', '--columns=application,name,version,size,installation']).splitlines():
        p = linha.split('\t')
        if len(p) < 5:
            continue
        ident, nome, versao, tam, onde = p[:5]
        base = '/var/lib/flatpak' if onde == 'system' else os.path.join(HOME, '.local/share/flatpak')
        res.append(dict(id='flatpak:%s:%s' % (onde, ident), nome=nome or ident, icone=ident, origem='Flathub',
                        versao=versao, tamanho=_bytes(tam), data=_mtime(os.path.join(base, 'app', ident, 'current')),
                        removivel=True, detalhe=ident))
    return res


def _sobrepostos():
    """Os .desktop que o CarinaeOS reescreve (nomes em português, escondidos) em /usr/local."""
    d = {}
    for f in glob.glob('/usr/local/share/applications/*.desktop'):
        d[os.path.basename(f)] = _desktop(f)
    return d


def debian():
    sob = _sobrepostos()
    arquivos = {}
    for f in glob.glob('/usr/share/applications/*.desktop'):
        b = os.path.basename(f)
        d = sob.get(b) or _desktop(f)
        if _visivel(d) and not os.path.exists(os.path.join(APPS_USUARIO, b)):
            arquivos[f] = d
    if not arquivos:
        return []
    pacote = {}
    for linha in _cmd(['dpkg-query', '-S'] + list(arquivos), 30).splitlines():
        if ': ' in linha:
            pk, cam = linha.split(': ', 1)
            pacote[cam.strip()] = pk.split(':')[0].split(',')[0].strip()
    info = {}
    nomes = sorted(set(pacote.values()))
    for linha in _cmd(['dpkg-query', '-W', '-f=${Package}\t${Installed-Size}\t${Version}\n'] + nomes, 30).splitlines():
        p = linha.split('\t')
        if len(p) == 3:
            info[p[0]] = (int(p[1] or 0) * 1024, p[2])
    res, vistos = [], set()
    for f, d in arquivos.items():
        pk = pacote.get(f)
        if not pk or pk in vistos:
            continue
        vistos.add(pk)
        tam, ver = info.get(pk, (0, ''))
        res.append(dict(id='deb:%s' % pk, nome=d.get('Name'), icone=d.get('Icon', ''), origem='Debian', versao=ver,
                        tamanho=tam, data=_mtime('/var/lib/dpkg/info/%s.list' % pk) or _mtime('/var/lib/dpkg/info/%s:amd64.list' % pk),
                        removivel=not PROTEGIDOS.match(pk), detalhe=pk))
    return res


def locais():
    """AppImages, apps Electron e programas do Windows: os atalhos que o CarinaeOS criou em ~/.local."""
    res = []
    for f in glob.glob(os.path.join(APPS_USUARIO, '*.desktop')):
        b = os.path.basename(f)
        d = _desktop(f)
        if not d.get('Name'):
            continue
        if b.startswith('appimage-') or d.get('X-CarinaeOS-AppImage'):
            m = re.match(r'"([^"]+)"|(\S+)', d.get('Exec', ''))
            arq = (m.group(1) or m.group(2)) if m else ''
            res.append(dict(id='appimage:' + b, nome=d['Name'], icone=d.get('Icon', ''), origem='AppImage', versao='',
                            tamanho=os.path.getsize(arq) if os.path.isfile(arq) else 0, data=_mtime(arq or f),
                            removivel=True, detalhe=arq))
        elif b.startswith('carinaeos-electron-') or d.get('X-CarinaeOS-Electron'):
            pasta = d.get('X-CarinaeOS-Electron') or ''
            if not os.path.isdir(pasta):
                m = re.match(r'"([^"]+)"', d.get('Exec', ''))
                pasta = os.path.dirname(m.group(1)) if m else ''
            res.append(dict(id='electron:' + b, nome=d['Name'], icone=d.get('Icon', ''), origem='Aplicativo', versao='',
                            tamanho=_tam_pasta(pasta) if pasta.startswith(PASTA_APPS) else 0, data=_mtime(pasta or f),
                            removivel=True, detalhe=pasta))
        elif b.startswith('carinaeos-windows-'):
            m = re.search(r'-b "([^"]+)"', d.get('Exec', ''))
            res.append(dict(id='windows:' + b, nome=d['Name'], icone=d.get('Icon', ''), origem='Windows', versao='',
                            tamanho=0, data=_mtime(f), removivel=True, detalhe=m.group(1) if m else ''))
    return res


def listar():
    res = flatpak() + debian() + locais()
    res.sort(key=lambda a: a['nome'].lower())
    return res


# ---- desinstalar ---------------------------------------------------------------------------------------
def simular_debian(pacote):
    """O que o apt removeria junto: (peças do próprio app, outros pacotes que bloqueiam)."""
    if not re.fullmatch(r'[a-z0-9][a-z0-9+.-]*', pacote or ''):
        return None
    saida = _cmd(['apt-get', '-s', 'remove', pacote], 60)
    junto = [l.split()[1] for l in saida.splitlines() if l.startswith('Remv ') and l.split()[1] != pacote]
    proprios = [p for p in junto if p.startswith(pacote + '-')]       # traduções e complementos do app
    return proprios, [p for p in junto if p not in proprios]


def previa(ident):
    """Antes de confirmar: o que vai sair, e se dá para desinstalar."""
    app = next((a for a in listar() if a['id'] == ident), None)
    if not app:
        return dict(pode=False, mensagem='Este aplicativo já não está instalado.')
    if not app['removivel']:
        return dict(pode=False, mensagem='%s faz parte do CarinaeOS e não pode ser desinstalado.' % app['nome'])
    if ident.startswith('deb:'):
        r = simular_debian(app['detalhe'])
        if r is None:
            return dict(pode=False, mensagem='Nome de pacote inválido.')
        proprios, outros = r
        if outros:
            return dict(pode=False, mensagem='Não dá para desinstalar %s sozinho: outras partes do sistema dependem dele (%s).'
                        % (app['nome'], ', '.join(outros[:5]) + ('…' if len(outros) > 5 else '')))
        return dict(pode=True, mensagem='Também saem as peças do próprio aplicativo: %s.' % ', '.join(proprios) if proprios else '')
    if ident.startswith('windows:'):
        return dict(pode=True, mensagem='O atalho sai do Launchpad e abre-se o desinstalador do Wine para apagar os arquivos do programa.')
    if ident.startswith('flatpak:'):
        return dict(pode=True, mensagem='', dados=True)
    return dict(pode=True, mensagem='')


def _limpar_atalho(desktop, *extras):
    for p in (desktop,) + extras:
        try:
            if p and os.path.isfile(p):
                os.remove(p)
        except OSError:
            pass
    _cmd(['update-desktop-database', APPS_USUARIO])
    _cmd(['kbuildsycoca6'], 60)


def desinstalar(ident, apagar_dados=False):
    """Devolve (ok, mensagem). Só remove o que listar() encontrou (nada de caminhos de fora)."""
    app = next((a for a in listar() if a['id'] == ident), None)
    if not app or not app['removivel']:
        return False, 'Este aplicativo não pode ser desinstalado.'
    tipo = ident.split(':', 1)[0]
    if tipo == 'flatpak':
        _, onde, fid = ident.split(':', 2)
        args = ['flatpak', 'uninstall', '--' + onde, '-y', '--noninteractive'] + (['--delete-data'] if apagar_dados else []) + [fid]
        r = subprocess.run(args, capture_output=True, text=True, timeout=600)
        if r.returncode != 0:
            return False, ((r.stderr or r.stdout).strip().splitlines() or ['erro'])[-1]
        return True, '%s foi desinstalado.' % app['nome']
    if tipo == 'deb':
        pk = app['detalhe']
        p = previa(ident)
        if not p['pode']:
            return False, p['mensagem']
        r = subprocess.run(['pkexec', '/usr/lib/carinaeos/remover-pacote', pk], capture_output=True, text=True, timeout=600)
        if r.returncode != 0:
            return False, ((r.stderr or r.stdout).strip().splitlines() or ['cancelado'])[-1]
        return True, '%s foi desinstalado.' % app['nome']
    desktop = os.path.join(APPS_USUARIO, ident.split(':', 1)[1])
    d = _desktop(desktop)
    icone = d.get('Icon', '')
    icone = icone if icone.startswith(os.path.join(HOME, '.local/share/icons')) else ''
    if tipo == 'appimage':
        arq = app['detalhe']
        if arq.startswith(PASTA_APPS + os.sep) and os.path.isfile(arq):
            os.remove(arq)
        _limpar_atalho(desktop, icone)
        return True, '%s foi desinstalado.' % app['nome']
    if tipo == 'electron':
        pasta = app['detalhe']
        if pasta.startswith(PASTA_APPS + os.sep) and os.path.isdir(pasta):
            shutil.rmtree(pasta, ignore_errors=True)
        _limpar_atalho(desktop, icone)
        return True, '%s foi desinstalado.' % app['nome']
    if tipo == 'windows':
        # o desinstalador do próprio programa, dentro da garrafa (a janela "Adicionar/remover" do Wine)
        garrafa = app['detalhe']
        if garrafa:
            subprocess.Popen(['flatpak', 'run', '--command=bottles-cli', BOTTLES, 'run', '-b', garrafa, '-e',
                              'C:\\windows\\system32\\uninstaller.exe'], start_new_session=True,
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        _limpar_atalho(desktop, icone)
        return True, 'Atalho removido; escolha %s na janela do Wine para apagar os arquivos.' % app['nome']
    return False, 'Origem desconhecida.'


if __name__ == '__main__':
    print(json.dumps(listar(), ensure_ascii=False, indent=1))
