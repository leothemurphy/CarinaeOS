# CarinaeOS - Eta: o que a Eta sabe fazer no sistema (discos, rede, atualizacoes).
# Funcoes so de leitura correm logo; tudo o que muda o sistema devolve um comando
# que a Eta mostra num cartao "Permitir / Recusar" antes de executar.
# Senhas nunca vao para a linha de comando nem para a IA: seguem pelo stdin.
import json
import os
import re
import shlex
import subprocess

AO_VIVO = 'boot=live' in open('/proc/cmdline').read() if os.path.exists('/proc/cmdline') else False


def _sh(args, timeout=60, entrada=None):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout, input=entrada)
        return r.returncode, r.stdout
    except Exception as e:
        return -1, str(e)


def _tamanho(b):
    try:
        b = int(b)
    except (TypeError, ValueError):
        return str(b or '')
    for u in ('B', 'KB', 'MB', 'GB', 'TB'):
        if b < 1000:
            return ('%.0f %s' if u in ('B', 'KB') else '%.1f %s') % (b, u)
        b /= 1000.0
    return '%.1f PB' % b


# ---- discos -------------------------------------------------------------------------
CIFRADOS = ('crypto_LUKS', 'BitLocker')


def discos_externos():
    """Particoes de discos externos (USB, cartoes, discos amoviveis)."""
    c, s = _sh(['lsblk', '-J', '-b', '-o',
                'NAME,PATH,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINT,RM,HOTPLUG,TRAN,MODEL,VENDOR'])
    if c != 0:
        return []
    try:
        arvore = json.loads(s).get('blockdevices', [])
    except Exception:
        return []
    res = []

    def visitar(n, disco, externo):
        filhos = n.get('children') or []
        tipo = n.get('type')
        if tipo in ('part', 'disk', 'crypt') and (n.get('fstype') or tipo == 'crypt'):
            if tipo == 'disk' and filhos:
                pass                                   # o disco tem particoes: mostrar as particoes
            elif n.get('fstype') not in ('swap', 'iso9660') and n.get('mountpoint') not in ('/', '/boot', '/boot/efi', '[SWAP]') \
                    and not (n.get('mountpoint') or '').startswith('/run/live'):
                if tipo != 'crypt':
                    aberto = next((f for f in filhos if f.get('type') == 'crypt'), None)
                    nome = n.get('label') or (disco.get('vendor') or '').strip() + ' ' + (disco.get('model') or '').strip()
                    nome = nome.strip() or 'Disco externo'
                    ponto = n.get('mountpoint') or ''
                    if aberto:
                        filho = (aberto.get('children') or [aberto])[0]
                        ponto = filho.get('mountpoint') or aberto.get('mountpoint') or ''
                    res.append(dict(dispositivo=n.get('path'), nome=nome, tamanho=_tamanho(n.get('size')),
                                    sistema=n.get('fstype') or '', cifrado=n.get('fstype') in CIFRADOS,
                                    desbloqueado=bool(aberto), aberto_dev=(aberto or {}).get('path', ''),
                                    montado=ponto, disco=disco.get('path')))
                    return
        for f in filhos:
            if f.get('type') != 'crypt':
                visitar(f, disco, externo)

    for d in arvore:
        externo = d.get('tran') in ('usb', 'mmc', 'ieee1394') or d.get('hotplug') or d.get('rm')
        if d.get('type') == 'disk' and externo:
            visitar(d, d, True)
    return res


def descrever_disco(d):
    estado = ('aberto em %s' % d['montado']) if d['montado'] else \
             ('protegido com senha' if d['cifrado'] and not d['desbloqueado'] else 'ligado, ainda não aberto')
    return '%s · %s · %s' % (d['tamanho'], d['sistema'] or '?', estado)


def cmd_montar(d):
    """Comando para abrir (montar) um disco nao cifrado e mostra-lo nos Arquivos."""
    dev = shlex.quote(d['aberto_dev'] or d['dispositivo'])
    return ('p=$(udisksctl mount -b %s --no-user-interaction 2>/dev/null | sed -n "s/.* at //p" | sed "s/\\.$//"); '
            '[ -z "$p" ] && p=$(lsblk -no MOUNTPOINT %s | head -n1); '
            '[ -n "$p" ] && { echo "Aberto em $p"; dolphin "$p" >/dev/null 2>&1 & }; [ -n "$p" ]' % (dev, dev))


def cmd_desbloquear(d):
    """Desbloqueia (LUKS/BitLocker) com a senha vinda do stdin e abre o disco."""
    dev = shlex.quote(d['dispositivo'])
    return ('set -o pipefail; c=$(udisksctl unlock -b %s --key-file /dev/stdin | sed -n "s/.* as \\(.*\\)\\./\\1/p") || exit 1; '
            'p=$(udisksctl mount -b "$c" | sed -n "s/.* at //p" | sed "s/\\.$//"); '
            'echo "Desbloqueado e aberto em $p"; dolphin "$p" >/dev/null 2>&1 &' % dev)


def cmd_ejetar(d):
    dev = shlex.quote(d['aberto_dev'] or d['dispositivo'])
    partes = []
    if d['montado']:
        partes.append('udisksctl unmount -b %s' % dev)
    if d['desbloqueado']:
        partes.append('udisksctl lock -b %s' % shlex.quote(d['dispositivo']))
    partes.append('udisksctl power-off -b %s' % shlex.quote(d['disco']))
    return ' && '.join(partes) + ' && echo "Já pode desligar o cabo com segurança."'


# ---- pastas de rede (NAS, outro computador) ------------------------------------------------
def endereco_rede(texto, frase=False):
    r"""Aceita \\servidor\pasta, smb://servidor/pasta, 192.168.1.20/pasta, nas.local/pasta ou 'servidor pasta'.
    frase=True: o endereco vem no meio de uma frase ("liga a pasta 192.168.1.20/fotos")."""
    t = texto.strip()
    padroes = [r'smb://([^\s/]+)/?(\S*)', r'\\\\([^\s\\]+)\\?(\S*)',
               r'\b((?:\d{1,3}\.){3}\d{1,3})(?:(?:[/\\]| +(?=[\w-]+$))(\S*))?',
               r'\b([A-Za-z0-9][\w-]*\.(?:local|lan|home))(?:(?:[/\\]| +(?=[\w-]+$))(\S*))?']
    for pd in padroes:
        m = re.search(pd, t, re.I)
        if m:
            pasta = (m.group(2) or '').replace('\\', '/').strip('/')
            return 'smb://%s/%s' % (m.group(1), pasta)
    if frase:
        return None
    t = re.sub(r'^(smb|cifs)://', '', t.replace('\\', '/'), flags=re.I).strip('/')
    m = re.match(r'^([A-Za-z0-9][\w.-]*)(?:[/ ]+(.+))?$', t)
    if not m:
        return None
    return 'smb://%s/%s' % (m.group(1), (m.group(2) or '').strip())


def cmd_rede(url, anonimo):
    u = shlex.quote(url)
    base = 'gio mount -a %s' % u if anonimo else 'gio mount %s' % u
    return ('%s 2>&1 | grep -v -i -E "^(user|domain|password|utilizador|dom.nio|senha)" ; '
            'gio info %s >/dev/null 2>&1 || exit 1; dolphin "/run/user/$(id -u)/gvfs" >/dev/null 2>&1 & echo "Pasta de rede ligada."'
            % (base, u))


def stdin_rede(usuario, senha):
    # o gio pergunta: utilizador, dominio, senha
    return '%s\nWORKGROUP\n%s\n' % (usuario, senha)


# ---- Wi-Fi ------------------------------------------------------------------------------------
def redes_wifi():
    _sh(['nmcli', 'device', 'wifi', 'rescan'], timeout=15)
    c, s = _sh(['nmcli', '-t', '-f', 'IN-USE,SSID,SIGNAL,SECURITY', 'device', 'wifi', 'list'], timeout=20)
    if c != 0:
        return []
    vistas, res = set(), []
    for l in s.splitlines():
        partes = re.split(r'(?<!\\):', l)
        if len(partes) < 4 or not partes[1] or partes[1] in vistas:
            continue
        vistas.add(partes[1])
        res.append(dict(ssid=partes[1].replace('\\:', ':'), sinal=int(partes[2] or 0),
                        segura=partes[3] not in ('', '--'), ligada=partes[0] == '*'))
    res.sort(key=lambda r: (-r['ligada'], -r['sinal']))
    return res[:10]


def cmd_wifi(ssid, com_senha):
    if com_senha:
        return 'nmcli --ask device wifi connect %s' % shlex.quote(ssid)
    return 'nmcli device wifi connect %s' % shlex.quote(ssid)


# ---- atualizacoes -----------------------------------------------------------------------------
def verificar_atualizacoes():
    """Atualiza a lista de pacotes (PackageKit, sem senha) e conta o que ha para atualizar."""
    c, s = _sh(['pkcon', 'refresh'], timeout=900)
    if c != 0:
        raise RuntimeError('o serviço de atualizações não respondeu')
    c, s = _sh(['apt', 'list', '--upgradable'], timeout=120)
    sistema = []
    for l in s.splitlines():
        m = re.match(r'^([^/\s]+)/\S+\s+(\S+)', l)
        if m:
            sistema.append(m.group(1))
    apps = []
    for onde in ('--user', '--system'):
        c, s = _sh(['flatpak', 'remote-ls', onde, '--updates', '--app', '--columns=name'], timeout=120)
        if c == 0:
            apps += [x.strip() for x in s.splitlines() if x.strip()]
    seguranca = 0
    c, s = _sh(['apt', 'list', '--upgradable'], timeout=60)
    seguranca = sum(1 for l in s.splitlines() if '-security' in l)
    return sistema, apps, seguranca


def cmd_atualizar(sistema, apps):
    partes = []
    if sistema:
        # pkcon devolve 5 quando nao ha nada a fazer
        partes.append('pkcon -y update; r=$?; [ $r -eq 0 ] || [ $r -eq 5 ] || exit $r')
    if apps:
        partes.append('flatpak update --user -y --noninteractive; flatpak update --system -y --noninteractive || true')
    partes.append('echo "Tudo atualizado."')
    return '; '.join(partes) if len(partes) > 1 else partes[0]


# ---- terminal ---------------------------------------------------------------------------------
def no_terminal(cmd, titulo='Eta'):
    """Corre o comando numa janela do Konsole, a vista do usuario (o sudo pede la a senha)."""
    script = '%s; r=$?; echo; if [ $r -eq 0 ]; then echo "✓ Concluído. Pode fechar esta janela."; ' \
             'else echo "✕ Terminou com erro ($r)."; fi' % cmd
    return 'konsole --hold -p tabtitle=%s -e bash -c %s' % (shlex.quote(titulo), shlex.quote(script))


SEGURO_NOME = re.compile(r'^[a-z0-9][a-z0-9.+-]{1,60}$')


def pacote_apt(nome):
    """Devolve o nome do pacote do Debian se existir (ex.: 'vlc', 'gimp')."""
    n = nome.lower().strip()
    if not SEGURO_NOME.match(n):
        return None
    c, s = _sh(['apt-cache', 'policy', n], timeout=30)
    if c == 0 and re.search(r'Candidat[eo]:\s*(?!\(none\)|\(nenhum\))\S', s):
        return n
    return None


def instalado_apt(nome):
    c, s = _sh(['dpkg-query', '-W', '-f=${Status}', nome], timeout=15)
    return c == 0 and 'install ok installed' in s


def app_flathub(nome):
    """Procura no Flathub: devolve (id, nome) do melhor resultado ou None."""
    c, s = _sh(['flatpak', 'search', '--columns=application,name', nome], timeout=60)
    if c != 0:
        return None
    for l in s.splitlines():
        partes = l.split('\t')
        if len(partes) >= 2 and '.' in partes[0]:
            return partes[0].strip(), partes[1].strip()
    return None


def cmd_instalar_apt(pacote):
    """Instala pelo apt com a senha do sistema (pkexec) e com o andamento legivel (Status-Fd)."""
    p = shlex.quote(pacote)
    interno = ('apt-get update -q -o APT::Status-Fd=1 && DEBIAN_FRONTEND=noninteractive '
               'apt-get install -y -o APT::Status-Fd=1 %s' % p)
    return 'pkexec bash -c %s && (kbuildsycoca6 >/dev/null 2>&1; true)' % shlex.quote(interno)


def cmd_instalar_flatpak(ident):
    """O flatpak so mostra a percentagem num terminal: o 'script' da-lhe um terminal falso."""
    return ("script -qfec %s /dev/null && (kbuildsycoca6 >/dev/null 2>&1; true)"
            % shlex.quote('flatpak install --user -y flathub %s' % shlex.quote(ident)))
