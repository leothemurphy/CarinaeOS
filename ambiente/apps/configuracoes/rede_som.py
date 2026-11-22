# CarinaeOS — Configurações: Wi-Fi, Rede e Som, feitos com as ferramentas do sistema (nmcli e pactl),
# sem os módulos do KDE (kcm_networkmanagement, kcm_pulseaudio).
import json
import os
import re
import subprocess


def _cmd(args, timeout=10):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return r.returncode, r.stdout.strip(), r.stderr.strip()
    except Exception as e:
        return 1, '', str(e)


def _campos(linha):
    """Divide uma linha "nmcli -t" (os ':' dentro dos valores vêm como '\\:')."""
    return [p.replace('\\:', ':') for p in re.split(r'(?<!\\):', linha)]


# =========================================================================================================
# Wi-Fi
# =========================================================================================================
def wifi_estado(procurar=False):
    _, radio, _ = _cmd(['nmcli', 'radio', 'wifi'])
    _, disp, _ = _cmd(['nmcli', '-t', '-f', 'DEVICE,TYPE,STATE', 'device'])
    tem_wifi = any(_campos(l)[1:2] == ['wifi'] for l in disp.splitlines())
    redes = []
    if radio == 'enabled' and tem_wifi:
        _, lista, _ = _cmd(['nmcli', '-t', '-f', 'IN-USE,SSID,SIGNAL,SECURITY,FREQ', 'dev', 'wifi', 'list',
                            '--rescan', 'yes' if procurar else 'auto'], 25)
        vistas = {}
        for l in lista.splitlines():
            p = _campos(l)
            if len(p) < 5 or not p[1]:
                continue
            r = dict(ssid=p[1], ligada=p[0] == '*', sinal=int(p[2] or 0), seguranca=p[3] if p[3] != '--' else '',
                     segura=bool(p[3] and p[3] != '--'), banda='5 GHz' if p[4].startswith('5') else '2,4 GHz')
            antiga = vistas.get(r['ssid'])
            if not antiga or r['ligada'] or (r['sinal'] > antiga['sinal'] and not antiga['ligada']):
                vistas[r['ssid']] = r
        conhecidas = set(c['nome'] for c in ligacoes_guardadas() if c['tipo'] == 'wifi')
        for r in vistas.values():
            r['conhecida'] = r['ssid'] in conhecidas
        redes = sorted(vistas.values(), key=lambda r: (not r['ligada'], not r['conhecida'], -r['sinal']))
    return dict(wifi=radio == 'enabled', temWifi=tem_wifi, redes=redes)


def ligacoes_guardadas():
    _, saida, _ = _cmd(['nmcli', '-t', '-f', 'NAME,UUID,TYPE,DEVICE,AUTOCONNECT', 'con', 'show'])
    tipos = {'802-11-wireless': 'wifi', '802-3-ethernet': 'cabo', 'vpn': 'vpn', 'wireguard': 'vpn',
             'bridge': 'ponte', 'loopback': 'local'}
    saida_l = []
    for l in saida.splitlines():
        p = _campos(l)
        if len(p) < 5 or p[2] == 'loopback':
            continue
        saida_l.append(dict(nome=p[0], uuid=p[1], tipo=tipos.get(p[2], p[2]), dispositivo=p[3],
                            ativa=bool(p[3]), automatica=p[4] == 'yes'))
    return saida_l


def ligar_wifi(ssid, senha, oculta=False):
    args = ['nmcli', 'dev', 'wifi', 'connect', ssid]
    if senha:
        args += ['password', senha]
    if oculta:
        args += ['hidden', 'yes']
    c, s, e = _cmd(args, 60)
    if c == 0:
        return ''
    if 'Secrets were required' in e or 'password' in e.lower() or '802-11-wireless-security' in e:
        return 'senha'
    return e.replace('Error: ', '') or 'não foi possível ligar'


def ligar_guardada(uuid):
    c, _, e = _cmd(['nmcli', 'con', 'up', 'uuid', uuid], 60)
    return '' if c == 0 else (e.replace('Error: ', '') or 'falhou')


def desligar_ligacao(uuid):
    c, _, e = _cmd(['nmcli', 'con', 'down', 'uuid', uuid], 30)
    return '' if c == 0 else e


def esquecer(uuid):
    c, _, e = _cmd(['nmcli', 'con', 'delete', 'uuid', uuid], 30)
    return '' if c == 0 else e


def senha_wifi(uuid):
    """A senha guardada de uma rede (para mostrar/partilhar). O NetworkManager pode pedir autorização."""
    c, s, _ = _cmd(['nmcli', '-s', '-g', '802-11-wireless-security.psk', 'con', 'show', 'uuid', uuid], 60)
    return s if c == 0 else ''


# =========================================================================================================
# Rede (cabo, IP, DNS, VPN)
# =========================================================================================================
def rede_estado():
    _, disp, _ = _cmd(['nmcli', '-t', '-f', 'DEVICE,TYPE,STATE,CONNECTION', 'device'])
    dispositivos = []
    for l in disp.splitlines():
        p = _campos(l)
        if len(p) < 4 or p[1] in ('loopback', 'bridge', 'tun', 'wifi-p2p') or p[0].startswith(('veth', 'docker', 'virbr')):
            continue
        d = dict(nome=p[0], tipo={'ethernet': 'cabo', 'wifi': 'wifi'}.get(p[1], p[1]), estado=p[2], ligacao=p[3],
                 ligado=p[2].startswith('connected') or p[2].startswith('ligado'))
        _, info, _ = _cmd(['nmcli', '-t', '-f', 'GENERAL.HWADDR,GENERAL.CON-PATH,CAPABILITIES.SPEED,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,IP6.ADDRESS',
                           'device', 'show', p[0]])
        ips4, dns, ips6 = [], [], []
        for li in info.splitlines():
            k, _, v = li.partition(':')
            if k == 'GENERAL.HWADDR':
                d['mac'] = v
            elif k == 'CAPABILITIES.SPEED':
                d['velocidade'] = v if v and v != 'unknown' else ''
            elif k.startswith('IP4.ADDRESS'):
                ips4.append(v)
            elif k == 'IP4.GATEWAY':
                d['gateway'] = v
            elif k.startswith('IP4.DNS'):
                dns.append(v)
            elif k.startswith('IP6.ADDRESS') and not v.startswith('fe80'):
                ips6.append(v)
        d.update(ipv4=ips4, dns=dns, ipv6=ips6)
        dispositivos.append(d)
    ligs = ligacoes_guardadas()
    for lg in ligs:
        if lg['tipo'] in ('cabo', 'wifi'):
            _, cfg, _ = _cmd(['nmcli', '-t', '-f', 'ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,ipv4.ignore-auto-dns',
                              'con', 'show', 'uuid', lg['uuid']])
            v = dict(li.split(':', 1) for li in cfg.splitlines() if ':' in li)
            lg['metodo'] = 'manual' if v.get('ipv4.method') == 'manual' else 'auto'
            lg['enderecos'] = v.get('ipv4.addresses', '')
            lg['gateway'] = v.get('ipv4.gateway', '')
            lg['dnsManual'] = v.get('ipv4.dns', '').replace(',', ' ')
            lg['soDnsManual'] = v.get('ipv4.ignore-auto-dns') == 'yes'
    return dict(dispositivos=dispositivos, ligacoes=ligs, vpns=[l for l in ligs if l['tipo'] == 'vpn'],
                nomePc=_cmd(['hostname'])[1])


def configurar_ip(uuid, metodo, endereco, gateway, dns):
    """Automático (DHCP) ou manual (IP fixo), e DNS escolhido à mão."""
    args = ['nmcli', 'con', 'mod', 'uuid', uuid]
    dns = ' '.join(dns.replace(',', ' ').split())
    if metodo == 'manual':
        if '/' not in endereco:
            endereco += '/24'
        args += ['ipv4.method', 'manual', 'ipv4.addresses', endereco, 'ipv4.gateway', gateway or '']
    else:
        args += ['ipv4.method', 'auto', 'ipv4.addresses', '', 'ipv4.gateway', '']
    args += ['ipv4.dns', dns, 'ipv4.ignore-auto-dns', 'yes' if dns else 'no']
    c, _, e = _cmd(args, 60)
    if c != 0:
        return e.replace('Error: ', '') or 'falhou'
    c, _, e = _cmd(['nmcli', 'con', 'up', 'uuid', uuid], 60)
    return '' if c == 0 else (e.replace('Error: ', '') or 'falhou ao religar')


def importar_vpn(ficheiro):
    tipo = 'wireguard' if ficheiro.endswith('.conf') else 'openvpn'
    c, _, e = _cmd(['nmcli', 'con', 'import', 'type', tipo, 'file', ficheiro], 60)
    if c != 0 and tipo == 'openvpn' and 'plugin' in e.lower():
        return 'falta o suporte a OpenVPN: sudo apt install network-manager-openvpn'
    return '' if c == 0 else (e.replace('Error: ', '') or 'falhou')


# =========================================================================================================
# Som (PipeWire, pelo pactl)
# =========================================================================================================
def _pactl_json(*args):
    c, s, _ = _cmd(['pactl', '-f', 'json'] + list(args), 8)
    if c != 0 or not s:
        return []
    try:
        return json.loads(s)
    except ValueError:
        return []


def _nulo(t):
    return not t or t == '(null)'


def _pactl_texto():
    """Os nomes (com acentos) tirados do "pactl list" em texto, que não tem o defeito do JSON.
    As etiquetas ficam em inglês (LC_MESSAGES=C); os nomes vêm do PipeWire já em português."""
    nos, perfis = {}, {}
    amb = dict(os.environ, LC_MESSAGES='C', LANGUAGE='C')
    for tipo in ('sinks', 'sources', 'cards'):
        try:
            r = subprocess.run(['pactl', 'list', tipo], capture_output=True, text=True, timeout=8, env=amb)
        except Exception:
            continue
        nome, em_perfis = '', False
        for linha in r.stdout.splitlines():
            t = linha.strip()
            if not linha.startswith('\t'):
                nome, em_perfis = '', False
                continue
            if linha.startswith('\tName: '):
                nome = t[6:]
                em_perfis = False
            elif linha.startswith('\tDescription: ') and nome:
                nos[nome] = t[13:]
            elif t.startswith('device.description = ') and nome and tipo == 'cards':
                nos.setdefault(nome, t.split('=', 1)[1].strip().strip('"'))
            elif linha.startswith('\tProfiles:'):
                em_perfis = True
            elif linha.startswith('\t') and not linha.startswith('\t\t'):
                em_perfis = False
            elif em_perfis and linha.startswith('\t\t') and ': ' in t:
                chave, resto = t.split(': ', 1)
                perfis[(nome, chave)] = re.sub(r'\s*\((sinks|outputs):.*\)\s*$', '', resto)
    return nos, perfis


def _pw_nomes():
    """Os nomes bonitos (e traduzidos) de cada aparelho e de cada modo, tirados do PipeWire (pw-dump).
    O "pactl -f json" escreve "(null)" quando o texto tem acentos, por isso não serve para isto."""
    c, s, _ = _cmd(['pw-dump'], 10)
    nos, perfis = {}, {}
    if c != 0 or not s:
        return nos, perfis
    try:
        objetos = json.loads(s)
    except ValueError:
        return nos, perfis
    for o in objetos:
        info = o.get('info') or {}
        pr = info.get('props') or {}
        if o.get('type') == 'PipeWire:Interface:Node' and pr.get('node.name'):
            nos[pr['node.name']] = pr.get('node.description') or pr.get('node.nick') or ''
        elif o.get('type') == 'PipeWire:Interface:Device' and pr.get('device.name'):
            nos[pr['device.name']] = pr.get('device.description') or pr.get('device.nick') or ''
            for pf in (info.get('params') or {}).get('EnumProfile') or []:
                if pf.get('name') and pf.get('description'):
                    perfis[(pr['device.name'], pf['name'])] = pf['description']
    return nos, perfis


def _volume(v):
    try:
        canais = list((v or {}).values())
        if not canais:
            return 0.0
        return sum(int(str(c.get('value_percent', '0')).rstrip('%')) for c in canais) / len(canais) / 100.0
    except Exception:
        return 0.0


def _icone_aparelho(p):
    nome = (p.get('name', '') + ' ' + p.get('description', '')).lower()
    if 'hdmi' in nome or 'displayport' in nome:
        return 'video-display'
    if 'bluez' in nome or 'bluetooth' in nome:
        return 'audio-headphones'
    if 'usb' in nome:
        return 'audio-headset'
    if 'mic' in nome or p.get('_entrada'):
        return 'audio-input-microphone'
    return 'audio-speakers'


def som_estado():
    nomes, nomes_perfis = _pactl_texto()
    if not nomes:
        nomes, nomes_perfis = _pw_nomes()

    def desc(o):
        d = o.get('description', '')
        if _nulo(d):
            d = nomes.get(o.get('name', ''), '') or o.get('name', '')
        return d

    _, saida_padrao, _ = _cmd(['pactl', 'get-default-sink'])
    _, entrada_padrao, _ = _cmd(['pactl', 'get-default-source'])
    saidas = []
    for s in _pactl_json('list', 'sinks'):
        saidas.append(dict(nome=s.get('name', ''), descricao=desc(s),
                           volume=_volume(s.get('volume')), mudo=bool(s.get('mute')),
                           padrao=s.get('name') == saida_padrao, icone=_icone_aparelho(s)))
    entradas = []
    for s in _pactl_json('list', 'sources'):
        if s.get('monitor_source') or '.monitor' in s.get('name', ''):
            continue                      # o "monitor" de uma saída não é um microfone
        s['_entrada'] = True
        entradas.append(dict(nome=s.get('name', ''), descricao=desc(s),
                             volume=_volume(s.get('volume')), mudo=bool(s.get('mute')),
                             padrao=s.get('name') == entrada_padrao, icone=_icone_aparelho(s)))
    apps = []
    for a in _pactl_json('list', 'sink-inputs'):
        pr = a.get('properties', {})
        nome = next((x for x in (pr.get('application.name'), pr.get('media.name')) if not _nulo(x)), 'Aplicação')
        if pr.get('media.role') == 'event' or nome in ('speech-dispatcher',):
            continue
        apps.append(dict(id=a.get('index'), nome=nome, media='' if _nulo(pr.get('media.name')) else pr.get('media.name', ''),
                         icone=pr.get('application.icon_name') or (pr.get('application.process.binary') or '').lower() or 'audio-x-generic',
                         volume=_volume(a.get('volume')), mudo=bool(a.get('mute'))))
    placas = []
    for c in _pactl_json('list', 'cards'):
        cn = c.get('name', '')
        perfis = []
        for k, v in (c.get('profiles') or {}).items():
            if k == 'off' or v.get('available') is False:
                continue
            d = v.get('description', '')
            if _nulo(d):
                d = nomes_perfis.get((cn, k), '') or k.replace('output:', 'Saída ').replace('input:', 'Entrada ').replace('+', ' + ')
            perfis.append(dict(nome=k, descricao=d))
        perfis.sort(key=lambda p: -((c.get('profiles') or {}).get(p['nome'], {}).get('priority', 0)))
        ativo = c.get('active_profile', '')
        if ativo and ativo != 'off' and not any(p['nome'] == ativo for p in perfis):
            perfis.insert(0, dict(nome=ativo, descricao=nomes_perfis.get((cn, ativo), ativo)))
        if ativo == 'off':
            perfis.insert(0, dict(nome='off', descricao='Desligada'))
        dd = (c.get('properties') or {}).get('device.description', '')
        if _nulo(dd):
            dd = nomes.get(cn, '') or cn
        placas.append(dict(nome=cn, descricao=dd, perfil=ativo, perfis=perfis))
    return dict(saidas=saidas, entradas=entradas, apps=apps, placas=placas,
                temPactl=bool(saidas or entradas or _cmd(['pactl', 'info'])[0] == 0))


def som_padrao(tipo, nome):
    _cmd(['pactl', 'set-default-sink' if tipo == 'saida' else 'set-default-source', nome])
    # o que já está a tocar passa também para o aparelho novo
    if tipo == 'saida':
        for a in _pactl_json('list', 'sink-inputs'):
            _cmd(['pactl', 'move-sink-input', str(a.get('index')), nome])


def som_volume(tipo, nome, v):
    cmd = {'saida': 'set-sink-volume', 'entrada': 'set-source-volume', 'app': 'set-sink-input-volume'}[tipo]
    _cmd(['pactl', cmd, str(nome), '%d%%' % round(max(0.0, min(1.5, v)) * 100)])


def som_mudo(tipo, nome):
    cmd = {'saida': 'set-sink-mute', 'entrada': 'set-source-mute', 'app': 'set-sink-input-mute'}[tipo]
    _cmd(['pactl', cmd, str(nome), 'toggle'])


def som_perfil(placa, perfil):
    c, _, e = _cmd(['pactl', 'set-card-profile', placa, perfil])
    return '' if c == 0 else e


def som_testar(nome):
    for f in ('/usr/share/sounds/freedesktop/stereo/audio-test-signal.oga',
              '/usr/share/sounds/freedesktop/stereo/complete.oga', '/usr/share/sounds/freedesktop/stereo/bell.oga'):
        if os.path.exists(f):
            subprocess.Popen(['paplay', '--device=' + nome, f], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return
