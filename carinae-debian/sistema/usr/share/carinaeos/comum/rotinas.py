# CarinaeOS - Rotinas: um botão do Deck que faz várias coisas de seguida (abrir apps, Não incomodar,
# som, música, luzes e cenas do Home Assistant, sites…), ao tocar, a uma hora ou ao entrar.
# Guardadas em ~/.config/carinaeos/rotinas.json. Usado pelo app Rotinas e pelo carinaeos-deck.
import configparser
import ctypes
import datetime
import glob
import json
import os
import re
import subprocess
import sys
import time
import unicodedata

sys.path.insert(0, '/usr/share/carinaeos/comum')
HOME = os.path.expanduser('~')
ARQUIVO = os.path.join(os.environ.get('XDG_CONFIG_HOME', os.path.join(HOME, '.config')), 'carinaeos', 'rotinas.json')
CORRENDO = os.path.join(os.environ.get('XDG_RUNTIME_DIR', '/tmp'), 'carinaeos-rotinas')
DIAS = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom']

# os exemplos com que o Deck começa (só usam o que existe em qualquer computador)
MODELOS = [
    dict(id='modo-foco', nome='Modo foco', icone='view-focus', gatilho=dict(tipo='manual'), passos=[
        dict(tipo='acao', id='sis:dnd', modo='ligar', nome='Não incomodar'),
        dict(tipo='acao', id='mus:pausar', modo='tocar', nome='Pausar a música'),
        dict(tipo='aviso', texto='Modo foco: notificações em silêncio. Bom trabalho!')]),
    dict(id='modo-filme', nome='Modo filme', icone='video-television', gatilho=dict(tipo='manual'), passos=[
        dict(tipo='acao', id='sis:dnd', modo='ligar', nome='Não incomodar'),
        dict(tipo='acao', id='mus:pausar', modo='tocar', nome='Pausar a música'),
        dict(tipo='volume', valor=70),
        dict(tipo='aviso', texto='Bom filme! 🍿')]),
    dict(id='fim-do-dia', nome='Fim do dia', icone='weather-clear-night', gatilho=dict(tipo='manual'), passos=[
        dict(tipo='acao', id='mus:pausar', modo='tocar', nome='Pausar a música'),
        dict(tipo='acao', id='sis:dnd', modo='desligar', nome='Não incomodar'),
        dict(tipo='aviso', texto='Até amanhã! O computador vai suspender daqui a 10 segundos.'),
        dict(tipo='esperar', segundos=10),
        dict(tipo='acao', id='sis:suspender', modo='tocar', nome='Suspender')]),
]


def _sem(t):
    t = unicodedata.normalize('NFD', (t or '').lower())
    return ''.join(c for c in t if unicodedata.category(c) != 'Mn')


def ler():
    try:
        with open(ARQUIVO, encoding='utf-8') as f:
            d = json.load(f)
            if isinstance(d, list):
                return d
    except FileNotFoundError:
        gravar(MODELOS)              # primeira vez: os exemplos
        return json.loads(json.dumps(MODELOS))
    except (OSError, ValueError):
        pass
    return []


def gravar(lista):
    os.makedirs(os.path.dirname(ARQUIVO), exist_ok=True)
    with open(ARQUIVO + '.tmp', 'w', encoding='utf-8') as f:
        json.dump(lista, f, ensure_ascii=False, indent=1)
    os.replace(ARQUIVO + '.tmp', ARQUIVO)
    # o relógio das rotinas com hora só corre se houver alguma
    com_hora = any((r.get('gatilho') or {}).get('tipo') == 'hora' for r in lista)
    subprocess.run(['systemctl', '--user', 'enable' if com_hora else 'disable', '--now', 'carinaeos-rotinas.timer'],
                   capture_output=True, timeout=20)


def novo_id(nome, lista):
    base = re.sub(r'[^a-z0-9]+', '-', _sem(nome)).strip('-') or 'rotina'
    i, ident = 2, base
    while any(r['id'] == ident for r in lista):
        ident, i = '%s-%d' % (base, i), i + 1
    return ident


# ---- descrever um passo (o que aparece no editor) ---------------------------------------------
def descrever(p):
    t = p.get('tipo')
    if t == 'acao':
        n = p.get('nome') or p.get('id', '')
        return {'ligar': 'Ligar: %s', 'desligar': 'Desligar: %s'}.get(p.get('modo'), '%s') % n
    if t == 'ha':
        n = p.get('nome') or p.get('id', '')
        return {'ligar': 'Casa · ligar %s', 'desligar': 'Casa · desligar %s', 'ativar': 'Casa · ativar %s'}.get(p.get('modo'), 'Casa · alternar %s') % n
    if t == 'abrir':
        return 'Abrir %s' % (p.get('nome') or p.get('app', ''))
    if t == 'fechar':
        return 'Fechar %s' % (p.get('nome') or p.get('app', ''))
    if t == 'site':
        return 'Abrir o site %s' % re.sub(r'^https?://(www\.)?', '', p.get('url', '')).rstrip('/')
    if t == 'volume':
        return 'Volume em %d%%' % int(p.get('valor', 50))
    if t == 'esperar':
        return 'Esperar %d s' % int(p.get('segundos', 5))
    if t == 'aviso':
        return 'Aviso: “%s”' % p.get('texto', '')
    if t == 'comando':
        return 'Comando: %s' % p.get('cmd', '')
    return t or '?'


def descrever_gatilho(g):
    g = g or {}
    if g.get('tipo') == 'hora':
        dias = g.get('dias') or list(range(1, 8))
        quando = 'todos os dias' if len(dias) == 7 else 'dias úteis' if dias == [1, 2, 3, 4, 5] else ', '.join(DIAS[d - 1] for d in dias)
        return 'Às %s, %s' % (g.get('hora', '08:00'), quando)
    if g.get('tipo') == 'entrar':
        return 'Ao entrar na sessão'
    return 'Ao tocar no Deck'


# ---- os aplicativos que se podem abrir ---------------------------------------------------------
def aplicativos():
    pastas = ['/usr/share/applications', '/usr/local/share/applications', '/var/lib/flatpak/exports/share/applications',
              os.path.join(HOME, '.local/share/flatpak/exports/share/applications'), os.path.join(HOME, '.local/share/applications')]
    apps = {}
    for p in pastas:
        for f in glob.glob(os.path.join(p, '*.desktop')):
            cp = configparser.RawConfigParser(strict=False, interpolation=None)
            cp.optionxform = str
            try:
                cp.read(f, encoding='utf-8')
                d = cp['Desktop Entry']
            except Exception:
                continue
            ident = os.path.basename(f)
            if d.get('NoDisplay', 'false').lower() == 'true' or d.get('Hidden', 'false').lower() == 'true' or not d.get('Exec'):
                apps.pop(ident, None)
                continue
            apps[ident] = dict(app=ident, nome=d.get('Name', ident), icone=d.get('Icon', 'application-x-executable'), caminho=f)
    return sorted(apps.values(), key=lambda a: a['nome'].lower())


# ---- fechar as janelas de um app com delicadeza (como clicar no X: ele pode perguntar se salva) ------
def _fechar_janelas(ids):
    try:
        x = ctypes.cdll.LoadLibrary('libX11.so.6')
    except OSError:
        return False
    x.XOpenDisplay.restype = ctypes.c_void_p
    x.XOpenDisplay.argtypes = [ctypes.c_char_p]
    d = x.XOpenDisplay(None)
    if not d:
        return False
    x.XDefaultRootWindow.restype = ctypes.c_ulong
    x.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
    x.XInternAtom.restype = ctypes.c_ulong
    x.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]

    class Msg(ctypes.Structure):
        _fields_ = [('type', ctypes.c_int), ('serial', ctypes.c_ulong), ('send_event', ctypes.c_int),
                    ('display', ctypes.c_void_p), ('window', ctypes.c_ulong), ('message_type', ctypes.c_ulong),
                    ('format', ctypes.c_int), ('data', ctypes.c_long * 5)]

    class Ev(ctypes.Union):
        _fields_ = [('xclient', Msg), ('pad', ctypes.c_long * 24)]
    x.XSendEvent.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_long, ctypes.POINTER(Ev)]
    raiz = x.XDefaultRootWindow(d)
    fechar = x.XInternAtom(d, b'_NET_CLOSE_WINDOW', 0)
    for w in ids:
        e = Ev()
        e.xclient.type = 33                    # ClientMessage
        e.xclient.window = int(w, 16) if isinstance(w, str) else int(w)
        e.xclient.message_type = fechar
        e.xclient.format = 32
        e.xclient.data[0] = int(time.time()) & 0xffffffff
        e.xclient.data[1] = 2                  # pedido de um "pager" (como a barra de tarefas)
        x.XSendEvent(d, raiz, 0, (1 << 19) | (1 << 20), ctypes.byref(e))   # SubstructureRedirect|Notify
    x.XFlush.argtypes = [ctypes.c_void_p]
    x.XFlush(d)
    x.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x.XCloseDisplay(d)
    return True


def fechar_app(app, espera=5):
    """Fecha as janelas do app; se ainda não tiver janela (acabou de abrir), espera até `espera` s por ela."""
    sys.path.insert(0, '/usr/share/carinaeos/encerrar')
    alvo = (app or '').lower().replace('.desktop', '')
    for _ in range(espera + 1):
        try:
            import encerrar
            ids = [w for a in encerrar.janelas() if a['app'].lower() == alvo for w in a['janelas']]
        except Exception:
            ids = []
        if ids:
            return _fechar_janelas(ids)
        time.sleep(1)
    return False


# ---- correr --------------------------------------------------------------------------------------
def _sh(args, timeout=30):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=timeout).returncode == 0
    except Exception:
        return False


def _bg(args):
    try:
        subprocess.Popen(args, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def avisar(titulo, texto='', icone='carinaeos-estrela'):
    _sh(['notify-send', '-a', 'Rotinas', '-i', icone, titulo, texto], 5)


def passo(p):
    t = p.get('tipo')
    if t == 'acao':
        _sh(['carinaeos-deck', 'definir', p['id'], p.get('modo', 'tocar')], 30)
    elif t == 'ha':
        try:
            import casa_ha as HA
            modo = p.get('modo', 'tocar')
            HA.alternar(p['id'], True if modo in ('ligar', 'ativar') else False if modo == 'desligar' else None)
        except Exception:
            pass
    elif t == 'abrir':
        a = next((x for x in aplicativos() if x['app'] == p.get('app')), None)
        if a:
            _bg(['gio', 'launch', a['caminho']])
    elif t == 'fechar':
        fechar_app(p.get('app'))
    elif t == 'site':
        url = p.get('url', '')
        if url and not re.match(r'^[a-z]+://', url):
            url = 'https://' + url
        if re.match(r'^https?://', url):
            _bg(['xdg-open', url])
    elif t == 'volume':
        _sh(['pactl', 'set-sink-volume', '@DEFAULT_SINK@', '%d%%' % max(0, min(150, int(p.get('valor', 50))))])
    elif t == 'esperar':
        time.sleep(max(0, min(3600, int(p.get('segundos', 5)))))
    elif t == 'aviso':
        avisar(p.get('texto', ''))
    elif t == 'comando' and p.get('cmd'):
        _bg(['sh', '-c', p['cmd']])


def correndo(ident):
    try:
        with open(os.path.join(CORRENDO, ident)) as f:
            return os.path.exists('/proc/' + f.read().strip())
    except OSError:
        return False


def correr(ident):
    r = next((x for x in ler() if x['id'] == ident), None)
    if not r:
        return 1
    os.makedirs(CORRENDO, exist_ok=True)
    marca = os.path.join(CORRENDO, ident)
    with open(marca, 'w') as f:
        f.write(str(os.getpid()))
    try:
        for p in r.get('passos', []):
            try:
                passo(p)
            except Exception as e:
                avisar('%s: um passo falhou' % r['nome'], '%s (%s)' % (descrever(p), e))
            if p.get('tipo') == 'abrir':
                time.sleep(0.8)          # os apps abrem pela ordem pedida
    finally:
        try:
            os.remove(marca)
        except OSError:
            pass
    return 0


def lancar(ident):
    """Corre a rotina noutro processo (o Deck e o app não ficam à espera)."""
    _bg(['carinaeos-rotinas', '--correr', ident])


def gatilho(evento):
    """'minuto' (o relógio: as rotinas da hora certa) ou 'entrar' (início da sessão)."""
    agora = datetime.datetime.now()
    for r in ler():
        g = r.get('gatilho') or {}
        if evento == 'entrar' and g.get('tipo') == 'entrar':
            lancar(r['id'])
        elif evento == 'minuto' and g.get('tipo') == 'hora' and g.get('hora') == agora.strftime('%H:%M') \
                and agora.isoweekday() in (g.get('dias') or list(range(1, 8))):
            lancar(r['id'])
