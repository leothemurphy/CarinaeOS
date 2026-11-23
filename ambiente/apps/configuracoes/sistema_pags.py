# CarinaeOS — Configurações: Bluetooth, Teclado, Rato e touchpad, Impressoras, Data e hora e Utilizadores,
# feitos com as ferramentas do sistema (bluetoothctl, setxkbmap, xinput, CUPS, timedatectl, AccountsService),
# sem os módulos do KDE. O que precisa de administrador passa pelo pkexec (a nossa janela "Autorizar").
import json
import os
import pwd
import re
import subprocess

HOME = os.path.expanduser('~')
CFG = os.path.join(HOME, '.config', 'carinaeos')


def _cmd(args, timeout=10, entrada=None, amb=None):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout, input=entrada, env=amb)
        return r.returncode, r.stdout.strip(), r.stderr.strip()
    except Exception as e:
        return 1, '', str(e)


def _ler_json(nome, padrao):
    try:
        return dict(padrao, **json.load(open(os.path.join(CFG, nome), encoding='utf-8')))
    except (OSError, ValueError):
        return dict(padrao)


def _gravar_json(nome, dados):
    os.makedirs(CFG, exist_ok=True)
    f = os.path.join(CFG, nome)
    with open(f + '.tmp', 'w', encoding='utf-8') as o:
        json.dump(dados, o, ensure_ascii=False, indent=1)
    os.replace(f + '.tmp', f)


def _root(script, entrada=None, timeout=300):
    """Corre um bocado de shell como administrador (uma só pergunta da senha)."""
    c, s, e = _cmd(['pkexec', '/bin/sh', '-c', script], timeout, entrada)
    if c in (126, 127) and not e:
        e = 'autorização recusada'
    return '' if c == 0 else (e.splitlines()[-1] if e else 'falhou')


def _q(t):
    return "'" + str(t).replace("'", "'\\''") + "'"


# =========================================================================================================
# Bluetooth
# =========================================================================================================
def bt_estado():
    c, show, _ = _cmd(['bluetoothctl', 'show'], 5)
    if c != 0 or 'Controller' not in show:
        return dict(temBt=False, bluetooth=False, aparelhos=[], novos=[])
    ligado = 'Powered: yes' in show
    aparelhos, novos = [], []
    if ligado:
        _, emparelhados, _ = _cmd(['bluetoothctl', 'devices', 'Paired'], 5)
        _, todos, _ = _cmd(['bluetoothctl', 'devices'], 5)
        pares = set()
        for linha in emparelhados.splitlines():
            m = re.match(r'Device (\S+) (.+)', linha)
            if not m:
                continue
            pares.add(m.group(1))
            _, info, _ = _cmd(['bluetoothctl', 'info', m.group(1)], 5)
            bat = re.search(r'Battery Percentage: \S+ \((\d+)\)', info)
            ic = re.search(r'Icon: (\S+)', info)
            aparelhos.append(dict(mac=m.group(1), nome=m.group(2), ligado='Connected: yes' in info,
                                  bateria=int(bat.group(1)) if bat else -1, icone=ic.group(1) if ic else 'bluetooth'))
        for linha in todos.splitlines():
            m = re.match(r'Device (\S+) (.+)', linha)
            if m and m.group(1) not in pares and not re.fullmatch(r'([0-9A-F]{2}-){5}[0-9A-F]{2}', m.group(2)):
                novos.append(dict(mac=m.group(1), nome=m.group(2)))
    return dict(temBt=True, bluetooth=ligado, aparelhos=aparelhos, novos=novos,
                visivel='Discoverable: yes' in show)


def bt_procurar():
    subprocess.Popen(['bluetoothctl', '--timeout', '20', 'scan', 'on'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def bt_emparelhar(mac):
    c, s, e = _cmd(['bluetoothctl', '--timeout', '30', 'pair', mac], 40)
    if c != 0 and 'AlreadyExists' not in s + e:
        return (s + e).strip().splitlines()[-1] if (s + e).strip() else 'não foi possível emparelhar'
    _cmd(['bluetoothctl', 'trust', mac], 10)
    c, s, e = _cmd(['bluetoothctl', '--timeout', '20', 'connect', mac], 30)
    return ''


def bt_acao(acao, mac):
    c, s, e = _cmd(['bluetoothctl', '--timeout', '20', acao, mac], 30)
    return '' if c == 0 else ((s + e).strip().splitlines()[-1] if (s + e).strip() else 'falhou')


# =========================================================================================================
# Teclado e rato (gravado em ~/.config/carinaeos e aplicado ao entrar na sessão: carinae-entrada --aplicar)
# =========================================================================================================
TECLADO_PADRAO = dict(disposicoes=['pt'], variantes=[''], trocar='grp:alt_shift_toggle', numlock=True,
                      atraso=600, ritmo=25, capsCtrl=False)
RATO_PADRAO = dict(velocidade=0.0, aceleracao=True, natural=False, canhoto=False,
                   tpVelocidade=0.0, tpNatural=True, tpTocar=True, tpDesligarAoEscrever=True)


def _traduzir_xkb(t):
    """Os nomes das disposições vêm em inglês; o xkeyboard-config tem a tradução (se o pacote estiver)."""
    import gettext
    try:
        return gettext.translation('xkeyboard-config', languages=[os.environ.get('LANG', 'pt_BR').split('.')[0], 'pt_BR', 'pt']).gettext(t)
    except OSError:
        return t


def _disposicoes_xkb():
    """As disposições de teclado que existem (com o nome legível), do ficheiro do XKB."""
    lista, variantes, secao = [], {}, ''
    try:
        for linha in open('/usr/share/X11/xkb/rules/evdev.lst', encoding='utf-8'):
            if linha.startswith('!'):
                secao = linha[1:].strip()
                continue
            linha = linha.strip()
            if not linha:
                continue
            if secao == 'layout':
                cod, _, nome = linha.partition(' ')
                lista.append(dict(codigo=cod, nome=_traduzir_xkb(nome.strip())))
            elif secao == 'variant':
                cod, _, resto = linha.partition(' ')
                base, _, nome = resto.strip().partition(': ')
                variantes.setdefault(base, []).append(dict(codigo=cod, nome=_traduzir_xkb(nome)))
    except OSError:
        pass
    return lista, variantes


def teclado_estado():
    t = _ler_json('teclado.json', TECLADO_PADRAO)
    if not os.path.exists(os.path.join(CFG, 'teclado.json')):
        # a primeira vez: o que está a ser usado agora
        _, q, _ = _cmd(['setxkbmap', '-query'])
        m = dict(re.findall(r'(\w+):\s+(\S+)', q))
        if m.get('layout'):
            t['disposicoes'] = m['layout'].split(',')
            t['variantes'] = (m.get('variant', '') + ',' * len(t['disposicoes'])).split(',')[:len(t['disposicoes'])]
    lista, variantes = _disposicoes_xkb()
    nomes = {d['codigo']: d['nome'] for d in lista}
    t['ativas'] = [dict(codigo=c, variante=(t['variantes'][i] if i < len(t['variantes']) else ''),
                        nome=nomes.get(c, c) + (' — ' + next((v['nome'] for v in variantes.get(c, [])
                                                              if v['codigo'] == t['variantes'][i]), t['variantes'][i])
                                                if i < len(t['variantes']) and t['variantes'][i] else ''))
                   for i, c in enumerate(t['disposicoes'])]
    t['todas'] = lista
    t['variantesDe'] = variantes
    return t


def teclado_mudar(chave, valor):
    t = _ler_json('teclado.json', TECLADO_PADRAO)
    t[chave] = valor
    _gravar_json('teclado.json', t)
    aplicar_teclado(t)


def teclado_disposicao(acao, codigo, variante=''):
    t = _ler_json('teclado.json', TECLADO_PADRAO)
    pares = list(zip(t['disposicoes'], (t['variantes'] + [''] * 9)[:len(t['disposicoes'])]))
    if acao == 'juntar' and (codigo, variante) not in pares:
        pares.append((codigo, variante))
    elif acao == 'tirar' and len(pares) > 1:
        pares = [p for p in pares if p[0] != codigo or p[1] != variante]
    elif acao == 'primeira':
        pares = [p for p in pares if p == (codigo, variante)] + [p for p in pares if p != (codigo, variante)]
    t['disposicoes'] = [p[0] for p in pares]
    t['variantes'] = [p[1] for p in pares]
    _gravar_json('teclado.json', t)
    aplicar_teclado(t)


def aplicar_teclado(t=None):
    t = t or _ler_json('teclado.json', TECLADO_PADRAO)
    opcoes = []
    if len(t['disposicoes']) > 1 and t.get('trocar'):
        opcoes.append(t['trocar'])
    if t.get('capsCtrl'):
        opcoes.append('ctrl:nocaps')
    args = ['setxkbmap', '-layout', ','.join(t['disposicoes']),
            '-variant', ','.join((t['variantes'] + [''] * 9)[:len(t['disposicoes'])]), '-option', '']
    for o in opcoes:
        args += ['-option', o]
    _cmd(args)
    _cmd(['xset', 'r', 'rate', str(int(t.get('atraso', 600))), str(int(t.get('ritmo', 25)))])
    if t.get('numlock') and _cmd(['sh', '-c', 'command -v numlockx'])[0] == 0:
        _cmd(['numlockx', 'on'])


def _ponteiros():
    """Os ratos e touchpads ligados (xinput), com as propriedades libinput que cada um tem."""
    _, lista, _ = _cmd(['xinput', 'list', '--name-only'])
    _, ids, _ = _cmd(['xinput', 'list', '--id-only'])
    saida = []
    for nome, ident in zip(lista.splitlines(), ids.splitlines()):
        if not ident.strip().isdigit() or 'XTEST' in nome or 'Virtual core' in nome:
            continue
        _, props, _ = _cmd(['xinput', 'list-props', ident.strip()])
        if 'libinput Accel Speed' not in props and 'libinput Tapping Enabled' not in props:
            continue
        touchpad = 'libinput Tapping Enabled' in props
        saida.append(dict(id=ident.strip(), nome=nome.strip(), touchpad=touchpad))
    return saida


def rato_estado():
    r = _ler_json('rato.json', RATO_PADRAO)
    r['aparelhos'] = _ponteiros()
    r['temTouchpad'] = any(a['touchpad'] for a in r['aparelhos'])
    return r


def rato_mudar(chave, valor):
    r = _ler_json('rato.json', RATO_PADRAO)
    r[chave] = valor
    _gravar_json('rato.json', r)
    aplicar_rato(r)


def aplicar_rato(r=None):
    r = r or _ler_json('rato.json', RATO_PADRAO)
    for a in _ponteiros():
        i = a['id']
        tp = a['touchpad']
        vel = r['tpVelocidade'] if tp else r['velocidade']
        _cmd(['xinput', 'set-prop', i, 'libinput Accel Speed', '%.2f' % max(-1.0, min(1.0, float(vel)))])
        _cmd(['xinput', 'set-prop', i, 'libinput Natural Scrolling Enabled', '1' if (r['tpNatural'] if tp else r['natural']) else '0'])
        _cmd(['xinput', 'set-prop', i, 'libinput Left Handed Enabled', '1' if r['canhoto'] else '0'])
        if not tp:
            # perfil: adaptativo (com aceleração) ou plano
            _cmd(['xinput', 'set-prop', i, 'libinput Accel Profile Enabled', '1, 0' if r['aceleracao'] else '0, 1'])
        else:
            _cmd(['xinput', 'set-prop', i, 'libinput Tapping Enabled', '1' if r['tpTocar'] else '0'])
            _cmd(['xinput', 'set-prop', i, 'libinput Disable While Typing Enabled', '1' if r['tpDesligarAoEscrever'] else '0'])


# =========================================================================================================
# Impressoras (CUPS)
# =========================================================================================================
C = dict(os.environ, LC_ALL='C', LANG='C', LANGUAGE='C')


def impressoras_estado():
    c, p, _ = _cmd(['lpstat', '-p'], 8, amb=C)
    _, d, _ = _cmd(['lpstat', '-d'], 8, amb=C)
    _, v, _ = _cmd(['lpstat', '-v'], 8, amb=C)
    _, o, _ = _cmd(['lpstat', '-o'], 8, amb=C)
    padrao = d.split(':', 1)[1].strip() if ':' in d else ''
    _, lpo, _ = _cmd(['lpoptions'], 5)          # a escolha do próprio utilizador pesa mais
    m = re.search(r'printer-uri-supported=\S+/printers/(\S+)', lpo)
    enderecos = dict(re.findall(r'device for (\S+): (\S+)', v))
    trabalhos = {}
    for linha in o.splitlines():
        nome = linha.split('-')[0] if '-' in linha else ''
        trabalhos[nome] = trabalhos.get(nome, 0) + 1
    lista = []
    for linha in p.splitlines():
        mm = re.match(r'\S+\s+(\S+)\s+(.*)', linha)
        if not mm or not linha.startswith('printer'):
            continue
        nome = mm.group(1)
        estado = mm.group(2).lower()
        lista.append(dict(nome=nome, padrao=nome == padrao, endereco=enderecos.get(nome, ''),
                          parada='disabled' in estado, trabalhos=trabalhos.get(nome, 0)))
    return dict(temCups=c == 0 or 'scheduler' not in p, impressoras=lista)


def impressoras_descobrir():
    """As impressoras que o CUPS vê na rede e por USB (que ainda não foram adicionadas)."""
    achadas = {}
    c, s, _ = _cmd(['lpinfo', '--include-schemes', 'dnssd,ipp,ipps,usb,socket', '-l', '-v'], 40, amb=C)
    uri = info = marca = ''
    for linha in s.splitlines() + ['Device:']:
        t = linha.strip()
        if t.startswith('Device:'):
            if uri and '://' in uri and uri.split(':')[0] in ('dnssd', 'ipp', 'ipps', 'usb', 'socket'):
                achadas[uri] = dict(uri=uri, nome=info or marca or uri)
            uri = t.split('uri =', 1)[1].strip() if 'uri =' in t else ''
            info = marca = ''
        elif t.startswith('info ='):
            info = t[6:].strip()
        elif t.startswith('make-and-model ='):
            marca = t[16:].strip()
    _, s, _ = _cmd(['driverless'], 30)
    for linha in s.splitlines():
        if '://' in linha and linha not in achadas:
            achadas[linha] = dict(uri=linha, nome=re.sub(r'%20', ' ', linha.split('://', 1)[1].split('.')[0].split('/')[0]))
    _, ja, _ = _cmd(['lpstat', '-v'], 8, amb=C)
    return [a for a in achadas.values() if a['uri'] not in ja and a['nome'] != 'unknown']


def impressora_juntar(uri, nome):
    nome = re.sub(r'[^A-Za-z0-9_-]+', '_', nome).strip('_')[:60] or 'Impressora'
    # sem controlador: IPP Everywhere / driverless (funciona com quase todas as impressoras de rede atuais)
    c, _, e = _cmd(['lpadmin', '-p', nome, '-E', '-v', uri, '-m', 'everywhere'], 120)
    if c != 0:
        e2 = _root('lpadmin -p %s -E -v %s -m everywhere' % (_q(nome), _q(uri)))
        if e2:
            return (e or e2) + ' — experimente pela página do CUPS (http://localhost:631)'
    return ''


def impressora_acao(acao, nome):
    if acao == 'padrao':
        c, _, e = _cmd(['lpoptions', '-d', nome])
        return '' if c == 0 else e
    if acao == 'teste':
        for f in ('/usr/share/cups/data/testprint', '/usr/share/cups/data/default-testpage.pdf'):
            if os.path.exists(f):
                c, _, e = _cmd(['lp', '-d', nome, '-t', 'Página de teste do CarinaeOS', f])
                return '' if c == 0 else e
        return 'não encontrei a página de teste do CUPS'
    if acao == 'cancelar':
        c, _, e = _cmd(['cancel', '-a', nome])
        return '' if c == 0 else e
    if acao == 'retomar':
        c, _, e = _cmd(['cupsenable', nome])
        if c != 0:
            return _root('cupsenable %s' % _q(nome))
        return ''
    if acao == 'remover':
        c, _, e = _cmd(['lpadmin', '-x', nome])
        return '' if c == 0 else _root('lpadmin -x %s' % _q(nome))
    return 'ação desconhecida'


# =========================================================================================================
# Data e hora
# =========================================================================================================
def datahora_estado():
    _, s, _ = _cmd(['timedatectl', 'show'], amb=C)
    v = dict(l.split('=', 1) for l in s.splitlines() if '=' in l)
    _, fusos, _ = _cmd(['timedatectl', 'list-timezones'])
    return dict(auto=v.get('NTP') == 'yes', sincronizado=v.get('NTPSynchronized') == 'yes',
                fuso=v.get('Timezone', ''), fusos=fusos.splitlines(),
                relogioLocal=v.get('LocalRTC') == 'yes')


def datahora_acao(acao, valor):
    if acao == 'auto':
        args = ['timedatectl', 'set-ntp', 'true' if valor else 'false']
    elif acao == 'fuso':
        args = ['timedatectl', 'set-timezone', valor]
    elif acao == 'hora':
        args = ['timedatectl', 'set-time', valor]
    elif acao == 'rtc':
        # o relógio do computador em hora local: o que o Windows espera (para os dois sistemas não se baralharem)
        args = ['timedatectl', 'set-local-rtc', '1' if valor else '0']
    else:
        return 'ação desconhecida'
    c, _, e = _cmd(args, 120)      # o timedatectl pede a autorização sozinho (polkit)
    return '' if c == 0 else (e or 'falhou')


# =========================================================================================================
# Utilizadores
# =========================================================================================================
def _admins():
    nomes = set()
    for g in ('sudo', 'wheel', 'admin'):
        try:
            import grp
            nomes.update(grp.getgrnam(g).gr_mem)
        except KeyError:
            pass
    return nomes


def _foto_de(u):
    for f in ('/var/lib/AccountsService/icons/' + u.pw_name, os.path.join(u.pw_dir, '.face.icon'), os.path.join(u.pw_dir, '.face')):
        if os.path.isfile(f) and os.access(f, os.R_OK):
            return 'file://' + f
    return ''


def utilizadores_estado():
    eu = pwd.getpwuid(os.getuid()).pw_name
    adm = _admins()
    contas = []
    for u in pwd.getpwall():
        if (1000 <= u.pw_uid < 60000 or u.pw_name == eu) and u.pw_shell not in ('/usr/sbin/nologin', '/bin/false'):
            contas.append(dict(utilizador=u.pw_name, nome=u.pw_gecos.split(',')[0] or u.pw_name, eu=u.pw_name == eu,
                               admin=u.pw_name in adm, foto=_foto_de(u), convidado=u.pw_name == 'convidado'))
    contas.sort(key=lambda c: (not c['eu'], c['convidado'], c['nome'].lower()))
    auto = ''
    for f in ('/etc/sddm.conf', ) + tuple(sorted(os.path.join('/etc/sddm.conf.d', x) for x in (os.listdir('/etc/sddm.conf.d') if os.path.isdir('/etc/sddm.conf.d') else []))):
        try:
            txt = open(f, encoding='utf-8').read()
            m = re.search(r'\[Autologin\][^\[]*?^User=(\S*)', txt, re.M | re.S)
            if m:
                auto = m.group(1)
        except OSError:
            pass
    return dict(contas=contas, euAdmin=eu in adm, entradaAuto=auto == eu, usuario=eu)


def _accounts(metodo, *args):
    """AccountsService (o mesmo que a tela de entrada usa): nome e foto da própria conta."""
    _, caminho, _ = _cmd(['gdbus', 'call', '--system', '--dest', 'org.freedesktop.Accounts', '--object-path',
                          '/org/freedesktop/Accounts', '--method', 'org.freedesktop.Accounts.FindUserById', str(os.getuid())])
    m = re.search(r"'(/org/freedesktop/Accounts/User\d+)'", caminho)
    if not m:
        return 'o AccountsService não respondeu'
    c, _, e = _cmd(['gdbus', 'call', '--system', '--dest', 'org.freedesktop.Accounts', '--object-path', m.group(1),
                    '--method', 'org.freedesktop.Accounts.User.' + metodo] + list(args), 120)
    return '' if c == 0 else e


def mudar_nome(nome):
    return _accounts('SetRealName', nome)


def mudar_foto(ficheiro):
    import shutil
    try:
        destino = os.path.join(HOME, '.face.icon')
        # a foto quadrada e pequena (512 px), como a tela de entrada gosta
        if _cmd(['sh', '-c', 'command -v convert'])[0] == 0:
            _cmd(['convert', ficheiro, '-auto-orient', '-resize', '512x512^', '-gravity', 'center', '-extent', '512x512', 'png:' + destino], 60)
        else:
            shutil.copyfile(ficheiro, destino)
        os.chmod(destino, 0o644)
    except Exception as e:
        return str(e)
    return _accounts('SetIconFile', destino)


def mudar_senha(utilizador, nova):
    if len(nova) < 4:
        return 'a senha precisa de ter pelo menos 4 caracteres'
    return _root('chpasswd', '%s:%s\n' % (utilizador, nova))


def nova_conta(utilizador, nome, senha, admin):
    if not re.fullmatch(r'[a-z_][a-z0-9_-]{0,30}', utilizador):
        return 'o nome de utilizador só pode ter letras minúsculas, números, - e _ (sem espaços nem acentos)'
    grupos = 'sudo,lpadmin,netdev,audio,video,plugdev,bluetooth' if admin else 'lpadmin,netdev,audio,video,plugdev,bluetooth'
    script = ('useradd -m -s /bin/bash -c %s %s && for g in %s; do getent group "$g" >/dev/null && usermod -aG "$g" %s; done; '
              'chpasswd') % (_q(nome), _q(utilizador), grupos.replace(',', ' '), _q(utilizador))
    return _root(script, '%s:%s\n' % (utilizador, senha))


def apagar_conta(utilizador, ficheiros):
    if utilizador == pwd.getpwuid(os.getuid()).pw_name:
        return 'não pode apagar a conta com que está a usar o computador'
    return _root('userdel %s %s' % ('-r' if ficheiros else '', _q(utilizador)))


def mudar_admin(utilizador, admin):
    if utilizador == pwd.getpwuid(os.getuid()).pw_name and not admin:
        return 'não pode tirar a si próprio de administrador (ficava sem ninguém para autorizar)'
    return _root(('usermod -aG sudo %s' if admin else 'gpasswd -d %s sudo') % _q(utilizador))


def entrada_automatica(ligar):
    eu = pwd.getpwuid(os.getuid()).pw_name
    f = '/etc/sddm.conf.d/20-carinaeos-entrada.conf'
    if ligar:
        txt = '[Autologin]\\nUser=%s\\nSession=carinae.desktop\\n' % eu
        return _root("mkdir -p /etc/sddm.conf.d && printf '%s' > %s" % (txt, f))
    return _root('rm -f %s' % f)
