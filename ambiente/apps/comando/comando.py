#!/usr/bin/python3
# CarinaeOS - Comando (Ctrl+Espaco): uma barra para fazer tudo depressa, como o Raycast.
#   aplicativos, comandos do sistema, arquivos, historico da area de transferencia,
#   contas, sites e pesquisa na web, com o estado do computador (CPU, memoria, disco,
#   o que mais gasta) sempre a vista.
# Fica a correr depois de aberto pela primeira vez (abre na hora nas vezes seguintes);
# "carinaeos-comando" mostra a janela que ja existe.
import ast
import json
import operator
import os
import re
import shlex
import shutil
import subprocess
import sys
import threading
import time

for _p in ('/usr/local/share/carinaeos/comum', '/usr/share/carinaeos/comum'):
    if os.path.isdir(_p):
        sys.path.insert(0, _p)
        break
from base import Icones  # noqa: E402
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import acoes as AC  # noqa: E402
import extensoes as EXT  # noqa: E402
import rapido as RP  # noqa: E402

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot  # noqa: E402
from PySide6.QtGui import QGuiApplication, QIcon  # noqa: E402
from PySide6.QtNetwork import QLocalServer, QLocalSocket  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402
from PySide6.QtQuickControls2 import QQuickStyle  # noqa: E402

try:
    import psutil
except ImportError:  # pragma: no cover
    psutil = None

try:
    import gi
    gi.require_version('Gio', '2.0')
    from gi.repository import Gio
except Exception:  # pragma: no cover
    Gio = None

AQUI = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser('~')
NOME_SERVIDOR = 'carinaeos-comando-%d' % os.getuid()
USO = os.path.join(HOME, '.local/share/carinaeos/comando-uso.json')


def sem_acentos(t):
    import unicodedata
    return ''.join(c for c in unicodedata.normalize('NFD', (t or '').lower()) if unicodedata.category(c) != 'Mn')


def correr(cmd):
    try:
        if isinstance(cmd, str):
            cmd = ['sh', '-c', cmd]
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except Exception:
        pass



def kglobal(atalho):
    return {'Overview': 'aurora --enviar lancador', 'Show Desktop': 'aurora --enviar mesa'}.get(atalho, 'true')


def nome_tamanho(n):
    for u in ('B', 'KB', 'MB', 'GB', 'TB'):
        if n < 1024 or u == 'TB':
            return ('%.0f %s' if u in ('B', 'KB') else '%.1f %s') % (n, u)
        n /= 1024.0


MONITOR = 'carinaeos-monitor'


# ---- comandos do sistema --------------------------------------------------------------
# (titulo, subtitulo, icone, comando, palavras extra para a pesquisa)
COMANDOS = [
    ('Bloquear a tela', 'Sistema', 'system-lock-screen', 'carinae-sessao bloquear', 'trancar lock'),
    ('Suspender', 'Sistema', 'system-suspend', 'carinae-sessao suspender', 'dormir sleep'),
    ('Reiniciar…', 'Sistema', 'system-reboot', 'carinae-sessao reiniciar', 'restart reboot'),
    ('Desligar…', 'Sistema', 'system-shutdown', 'carinae-sessao desligar', 'shutdown apagar'),
    ('Encerrar sessão…', 'Sistema', 'system-log-out', 'carinae-sessao sair', 'logout sair'),
    ('Captura de tela', 'A tela inteira (Shift+Print)', 'applets-screenshooter', 'carinae-captura', 'screenshot print foto da tela tela'),
    ('Captura de uma região', 'Escolher com o mouse (Print)', 'applets-screenshooter', 'carinae-captura regiao', 'screenshot recorte area tela'),
    ('Captura da janela', 'A janela ativa (Alt+Print)', 'applets-screenshooter', 'carinae-captura janela', 'screenshot janela'),
    ('Histórico da área de transferência', 'Tudo o que copiou com Ctrl+C', 'edit-paste', '@clip', 'clipboard copiar colar ctrl c'),
    ('Monitor do sistema', 'CPU, memória, processos', 'utilities-system-monitor', MONITOR, 'gestor de tarefas task manager processos'),
    ('Velocidade da internet', 'Download, upload, ping e latência', 'network-wireless', 'carinaeos-monitor velocidade', 'speedtest teste velocidade internet ping latencia'),
    ('Aplicativos de inicialização', 'O que arranca com a sessão', 'system-run', 'carinaeos-monitor arranque', 'autostart arranque inicializacao'),
    ('Todas as janelas', 'Visão geral', 'view-grid', kglobal('Overview'), 'expose janelas mission control'),
    ('Mostrar a área de trabalho', 'Afasta todas as janelas', 'user-desktop', kglobal('Show Desktop'), 'desktop area de trabalho'),
    ('Papel de parede seguinte', 'Fundos do CarinaeOS', 'preferences-desktop-wallpaper', 'aurora --enviar papel-seguinte', 'wallpaper fundo'),
    ('Abrir a lixeira', 'Arquivos', 'user-trash', 'carinaeos-arquivos "$HOME/.local/share/Trash/files"', 'lixo reciclagem'),
    ('Downloads', 'Pasta', 'folder-download', 'carinaeos-arquivos "$(xdg-user-dir DOWNLOAD)"', 'downloads'),
    ('Wi-Fi e rede', 'Configurações', 'network-wireless', 'carinaeos-configuracoes wifi', 'internet rede wifi'),
    ('Bluetooth', 'Configurações', 'preferences-system-bluetooth', 'carinaeos-configuracoes bluetooth', 'fones'),
    ('Som', 'Configurações', 'audio-volume-high', 'carinaeos-configuracoes som', 'audio volume alto-falantes'),
    ('Telas e monitores', 'Configurações', 'video-display', 'carinae-telas', 'monitor resolucao tela'),
    ('Impressoras', 'Configurações', 'printer', 'carinaeos-configuracoes impressoras', 'imprimir'),
    ('Acesso remoto (SSH)', 'Central', 'network-server', 'carinaeos-central ssh', 'ssh remoto servidor'),
    ('Drivers e hardware', 'Central', 'preferences-system', 'carinaeos-central drivers', 'driver nvidia placa'),
    ('Central do CarinaeOS', 'Todas as ferramentas', 'carinaeos-central', 'carinaeos-central', 'ferramentas'),
    ('Supernova', 'Personalizar o visual', 'carinaeos-supernova', 'carinaeos-supernova', 'tema visual dock'),
    ('Órbita', 'Loja de aplicativos', 'carinaeos-orbita', 'carinaeos-orbita', 'loja instalar store'),
    ('Manual do CarinaeOS', 'Ajuda e comandos', 'help-contents', 'carinaeos-manual', 'ajuda help guia'),
    ('Configurações', 'Wi-Fi, som, telas, aparência…', 'preferences-system', 'carinaeos-configuracoes', 'definicoes settings'),
]

SUGESTOES_PADRAO = ['@clip', MONITOR, 'carinae-captura regiao', 'carinaeos-configuracoes']


# ---- contas: so numeros e operadores (sem eval) ----------------------------------------
_OPS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv,
        ast.Pow: operator.pow, ast.Mod: operator.mod, ast.FloorDiv: operator.floordiv,
        ast.USub: operator.neg, ast.UAdd: operator.pos}


def _avaliar(n):
    if isinstance(n, ast.Expression):
        return _avaliar(n.body)
    if isinstance(n, ast.Constant) and isinstance(n.value, (int, float)):
        return n.value
    if isinstance(n, ast.BinOp) and type(n.op) in _OPS:
        a, b = _avaliar(n.left), _avaliar(n.right)
        if isinstance(n.op, ast.Pow) and abs(b) > 100:
            raise ValueError
        return _OPS[type(n.op)](a, b)
    if isinstance(n, ast.UnaryOp) and type(n.op) in _OPS:
        return _OPS[type(n.op)](_avaliar(n.operand))
    raise ValueError


def _num_br(s):
    s = s.strip()
    if ',' in s:
        s = s.replace('.', '').replace(',', '.')
    return float(s)


def _formatar(v):
    if isinstance(v, float):
        if v != v or abs(v) == float('inf'):
            return None
        v = round(v, 10)
        if v == int(v) and abs(v) < 1e15:
            v = int(v)
    s = str(v)
    return s.replace('.', ',') if isinstance(v, float) else s


def conta(texto):
    # "15% de 230", "raiz de 16", "√16"
    b = texto.strip().lower()
    m = re.fullmatch(r'([\d.,]+)\s*%\s*(?:de|of)\s*([\d.,]+)', b)
    if m:
        try:
            return _formatar(_num_br(m.group(1)) * _num_br(m.group(2)) / 100)
        except ValueError:
            return None
    m = re.fullmatch(r'(?:raiz(?: quadrada)?(?: de)?|√|sqrt)\s*\(?\s*([\d.,]+)\s*\)?', b)
    if m:
        try:
            return _formatar(_num_br(m.group(1)) ** 0.5)
        except ValueError:
            return None
    t = texto.strip().replace('×', '*').replace('÷', '/').replace('^', '**').replace(' ', '')
    if not re.fullmatch(r'[0-9.,+\-*/%()]+', t) or not re.search(r'\d[+\-*/%(]|\)', t):
        return None
    # 1.234,5 -> 1234.5 ; 3,5 -> 3.5
    t = re.sub(r'(\d)\.(\d{3})(?!\d)', r'\1\2', t) if ',' in t else t
    t = t.replace(',', '.')
    try:
        v = _avaliar(ast.parse(t, mode='eval'))
    except Exception:
        return None
    return _formatar(v)


class Comando(QObject):
    resultadosMudaram = Signal()
    estadoMudou = Signal()
    mostrar = Signal()
    textoPedido = Signal(str)     # uma extensão pediu para trocar o texto da pesquisa

    def __init__(self):
        super().__init__()
        self._resultados = []
        self._estado = {}
        self._apps = []
        self._apps_tempo = 0
        self._consulta = ''
        self._arquivos = []
        self._gen = 0
        self._uso = self._ler_uso()
        self._modo = ''
        self._tempo = None
        self._rapido = None      # cartão vindo da internet: {q, cartao}
        self._ext = EXT.carregar()
        self._exclusivo = False
        self._ext_tempo = time.time()
        RP.preparar()
        if psutil:
            psutil.cpu_percent(None)
        self._relogio = QTimer(self)
        self._relogio.setInterval(1500)
        self._relogio.timeout.connect(self.atualizarEstado)
        self.arquivosProntos.connect(self._juntar_arquivos)

    # ---- uso (para as sugestoes) ------------------------------------------------------
    def _ler_uso(self):
        try:
            with open(USO, encoding='utf-8') as f:
                d = json.load(f)
                return d if isinstance(d, dict) else {}
        except (OSError, ValueError):
            return {}

    def _contar(self, chave):
        self._uso[chave] = self._uso.get(chave, 0) + 1
        try:
            os.makedirs(os.path.dirname(USO), exist_ok=True)
            with open(USO, 'w', encoding='utf-8') as f:
                json.dump(self._uso, f)
        except OSError:
            pass

    # ---- aplicativos ---------------------------------------------------------------------
    def _carregar_apps(self):
        if self._apps and time.time() - self._apps_tempo < 60:
            return self._apps
        r = []
        if Gio:
            for a in Gio.AppInfo.get_all():
                try:
                    if not a.should_show():
                        continue
                    ic = a.get_icon()
                    icone = ''
                    if ic is not None:
                        if hasattr(ic, 'get_names'):
                            icone = (ic.get_names() or [''])[0]
                        elif hasattr(ic, 'get_file') and ic.get_file():
                            icone = ic.get_file().get_path() or ''
                    r.append(dict(id=a.get_id() or '', nome=a.get_display_name() or a.get_name() or '',
                                  desc=a.get_description() or '', icone=icone or 'application-x-executable',
                                  chaves=sem_acentos(' '.join([a.get_display_name() or '', a.get_name() or '',
                                                               a.get_executable() or '',
                                                               a.get_generic_name() or ''
                                                               if hasattr(a, 'get_generic_name') else '',
                                                               ' '.join(a.get_keywords() or [])
                                                               if hasattr(a, 'get_keywords') else '']))))
                except Exception:
                    continue
        r.sort(key=lambda x: sem_acentos(x['nome']))
        self._apps, self._apps_tempo = r, time.time()
        return r

    @staticmethod
    def _pontuar(consulta, nome, chaves):
        n = sem_acentos(nome)
        if n == consulta:
            return 100
        if n.startswith(consulta):
            return 80
        if any(p.startswith(consulta) for p in n.split()):
            return 65
        if consulta in n:
            return 50
        if consulta in chaves:
            return 30
        # iniciais: "lo" -> "LibreOffice"; "gc" -> "Google Chrome"
        iniciais = ''.join(p[0] for p in re.split(r'[\s\-_]+', n) if p)
        if len(consulta) >= 2 and iniciais.startswith(consulta):
            return 40
        return 0

    # ---- resultados ----------------------------------------------------------------------
    def _item(self, grupo, tipo, titulo, sub, icone, alvo, extra=None):
        botao = {'conta': 'Copiar', 'clip': 'Copiar', 'cmd': 'Abrir', 'terminal': 'Executar'}.get(tipo, 'Abrir')
        d = dict(grupo=grupo, tipo=tipo, titulo=titulo, sub=sub, icone=icone, alvo=alvo, botao=botao,
                 controlo='', rotulo='', descricao='', valor=0.0, dados='')
        if extra:
            d.update(extra)
        return d

    def _de_ext(self, x, grupo=None):
        acao = x.get('acao', 'copiar')
        botao = {'copiar': 'Copiar', 'abrir': 'Abrir', 'correr': 'Executar', 'terminal': 'Executar',
                 'completar': 'Entrar'}.get(acao, 'Abrir')
        return self._item(grupo or x.get('_ext', 'Extensões'), 'ext', str(x.get('titulo', '')), str(x.get('sub', '')),
                          x.get('icone') or 'application-x-addon', str(x.get('valor', '')),
                          dict(botao=botao, controlo='', descricao=acao))

    def recarregarExtensoes(self):
        # ao aparecer: lê de novo as extensões se alguma pasta mudou (para quem está a escrever a sua)
        mud = max([os.path.getmtime(os.path.join(b, n)) for b in EXT.PASTAS if os.path.isdir(b)
                   for n in os.listdir(b) + ['.']] or [0])
        if mud > self._ext_tempo:
            self._ext = EXT.carregar()
            self._ext_tempo = time.time()

    def _terminal(self, cmd):
        correr(['x-terminal-emulator', '-e', 'sh', '-c', cmd + '; echo; printf "Enter fecha "; read _'])

    def _sugestoes(self):
        apps = {a['id']: a for a in self._carregar_apps()}
        cmds = {c[3]: c for c in COMANDOS}
        mais = sorted(self._uso.items(), key=lambda kv: -kv[1])
        r = []
        for chave, _ in mais:
            if chave.startswith('app:') and chave[4:] in apps:
                a = apps[chave[4:]]
                r.append(self._item('Sugestões', 'app', a['nome'], a['desc'] or 'Aplicativo', a['icone'], a['id']))
            elif chave.startswith('cmd:') and chave[4:] in cmds:
                c = cmds[chave[4:]]
                r.append(self._item('Sugestões', 'cmd', c[0], c[1], c[2], c[3]))
            if len(r) >= 5:
                break
        for c in SUGESTOES_PADRAO:
            if len(r) >= 5:
                break
            if c in cmds and not any(x['alvo'] == c for x in r):
                k = cmds[c]
                r.append(self._item('Sugestões', 'cmd', k[0], k[1], k[2], k[3]))
        outros = [self._item('Outros', 'cmd', 'Configurações', 'Wi-Fi, som, telas, aparência…', 'preferences-system', 'carinaeos-configuracoes'),
                  self._item('Outros', 'cmd', 'Manual do CarinaeOS', 'Ajuda e comandos', 'help-contents', 'carinaeos-manual')]
        return r + outros

    def _clip(self, filtro=''):
        r = []
        try:
            import dbus
            # o histórico é da Aurora (fala o mesmo D-Bus do Klipper, para os apps que já o conhecem)
            k = dbus.SessionBus().get_object('org.kde.klipper', '/klipper')
            hist = [str(x) for x in k.getClipboardHistoryMenu(dbus_interface='org.kde.klipper.klipper')]
        except Exception:
            hist = []
        f = sem_acentos(filtro)
        for i, t in enumerate(hist):
            if f and f not in sem_acentos(t):
                continue
            linha = ' '.join(t.split())
            r.append(self._item('Área de transferência', 'clip', linha[:120] or '(vazio)',
                                '%d caracteres · Enter copia' % len(t), 'edit-paste', t))
            if len(r) >= 40:
                break
        if not r:
            r.append(self._item('Área de transferência', 'nada', 'O histórico está vazio' if not f else 'Nada encontrado',
                                'Copie algo com Ctrl+C e volte aqui', 'edit-paste', ''))
        return r

    def _procurar(self, texto):
        t = texto.strip()
        if self._modo == 'clip':
            return self._clip(t)
        if not t:
            return self._sugestoes()
        self._exclusivo = True
        if t == '?':
            return [self._de_ext(x, 'Extensões') for x in EXT.ajuda(self._ext)]
        ext, exclusivo = EXT.procurar(self._ext, texto.lstrip())
        self._exclusivo = exclusivo
        if exclusivo:
            return [self._de_ext(x) for x in ext] or [self._item('Extensões', 'nada', 'Nada encontrado', t, 'edit-find', '')]
        c = sem_acentos(t)
        r = []

        v = conta(t)
        if v is not None:
            r.append(self._item('Calculadora', 'conta', v, '%s · Enter copia o resultado' % t, 'accessories-calculator', v))

        # respostas rápidas: hora e países (na hora); moedas, CEP, endereços e jogos (da internet)
        rapidos = RP.local(t)
        if self._rapido and self._rapido.get('q') == t:
            rapidos.append(self._rapido['cartao'])
        nomes = {'hora': ('Hora', 'preferences-system-time'), 'pais': ('País', 'applications-education-geography'),
                 'moeda': ('Conversão de moeda', 'accessories-calculator'), 'endereco': ('Endereço', 'mark-location'),
                 'jogos': ('Próximos jogos', 'applications-games')}
        for cr in rapidos:
            rot, ico = nomes.get(cr['modelo'], ('Resposta', 'help-about'))
            r.append(self._item('Respostas', 'rapido', rot, 'Enter abre' if cr['url'] else 'Enter copia', ico,
                                cr['url'] or cr['copiar'],
                                dict(dados=json.dumps(cr, ensure_ascii=False), botao='Abrir' if cr['url'] else 'Copiar')))

        if t.startswith('>'):
            cmd = t[1:].strip()
            if cmd:
                r.append(self._item('Terminal', 'terminal', cmd, 'Correr no terminal', 'utilities-terminal', cmd))
            return r

        if re.match(r'^(https?://\S+|www\.\S+|[\w-]+(\.[\w-]+)*\.(com|pt|br|org|net|io|dev|gov|edu|eu)(/\S*)?)$', t, re.I):
            url = t if re.match(r'^https?://', t, re.I) else 'https://' + t
            r.append(self._item('Web', 'url', 'Abrir %s' % t, 'No navegador', 'internet-web-browser', url))

        for a in AC.reconhecer(t):
            valor = 0.0
            if a['controlo'] and a.get('ler'):
                try:
                    valor = float(a['ler']())
                except Exception:
                    valor = 0.0
            r.append(self._item('Ações', 'acao', a['titulo'], 'Ação', a['icone'], a['id'],
                                dict(botao=a['botao'], controlo=a['controlo'] or '', rotulo=a.get('rotulo', ''),
                                     descricao=a['descricao'], valor=valor)))

        for x in ext:
            r.append(self._de_ext(x))

        if self._tempo and self._tempo.get('q') == t:
            r.append(self._item('Tempo', 'tempo', self._tempo['titulo'], 'Previsão do tempo', 'weather-few-clouds',
                                self._tempo['url'], dict(dados=json.dumps(self._tempo))))

        if re.search(r'\b(cpu|processador|memoria|ram|desempenho|disco|espaco livre|lento)\b', c):
            self.atualizarEstado()
            r.append(self._item('Sistema', 'estado', 'Uso do computador', 'CPU, memória e disco agora',
                                'utilities-system-monitor', MONITOR,
                                dict(dados=json.dumps(self._estado), botao='Monitor')))

        apps = []
        for a in self._carregar_apps():
            p = self._pontuar(c, a['nome'], a['chaves'])
            if p:
                p += min(15, self._uso.get('app:' + a['id'], 0))
                apps.append((p, a))
        apps.sort(key=lambda x: -x[0])
        for _, a in apps[:7]:
            r.append(self._item('Aplicativos', 'app', a['nome'], a['desc'] or 'Aplicativo', a['icone'], a['id']))

        cmds = []
        for cm in COMANDOS:
            p = self._pontuar(c, cm[0], sem_acentos(cm[1] + ' ' + cm[4]))
            if p:
                cmds.append((p + min(15, self._uso.get('cmd:' + cm[3], 0)), cm))
        cmds.sort(key=lambda x: -x[0])
        for _, cm in cmds[:5]:
            r.append(self._item('Comandos', 'cmd', cm[0], cm[1], cm[2], cm[3]))

        for a in self._arquivos:
            r.append(a)

        r.append(self._item('Web', 'web', t, 'Pesquisar com o DuckDuckGo • Navegador', 'search',
                            'https://duckduckgo.com/?q=' + __import__('urllib.parse').parse.quote(t)))
        return r

    # ---- arquivos (Baloo; se nao houver indice, procura na pasta pessoal) ----------------------
    arquivosProntos = Signal(int, list)

    def _buscar_arquivos(self, gen, texto):
        achados = []
        try:
            loc = shutil.which('plocate') or shutil.which('locate')
            if loc:
                # o índice do sistema (plocate): só o que está na pasta pessoal e não é escondido
                out = subprocess.run([loc, '-i', '-l', '400', texto], capture_output=True, text=True, timeout=3).stdout
                achados = [l for l in out.splitlines() if l.startswith(HOME + '/') and '/.' not in l[len(HOME):]][:8]
            elif shutil.which('baloosearch6'):
                out = subprocess.run(['baloosearch6', '-l', '8', texto], capture_output=True, text=True,
                                     timeout=3).stdout
                achados = [l.strip() for l in out.splitlines() if l.strip().startswith('/')]
        except Exception:
            achados = []
        if not achados:
            alvo = sem_acentos(texto)
            fim = time.time() + 0.6
            for raiz, pastas, nomes in os.walk(HOME):
                pastas[:] = [p for p in pastas if not p.startswith('.') and p not in ('node_modules', '__pycache__')]
                for n in pastas + nomes:
                    if alvo in sem_acentos(n):
                        achados.append(os.path.join(raiz, n))
                        if len(achados) >= 8:
                            break
                if len(achados) >= 8 or time.time() > fim:
                    break
        itens = []
        for p in achados[:8]:
            pasta = os.path.isdir(p)
            mostra = p.replace(HOME, '~', 1)
            itens.append(self._item('Arquivos', 'arquivo', os.path.basename(p) or p, os.path.dirname(mostra),
                                    'folder' if pasta else self._icone_arquivo(p), p))
        self.arquivosProntos.emit(gen, itens)

    @staticmethod
    def _icone_arquivo(p):
        ext = os.path.splitext(p)[1].lower()
        return {'.pdf': 'application-pdf', '.jpg': 'image-jpeg', '.jpeg': 'image-jpeg', '.png': 'image-png',
                '.mp3': 'audio-mpeg', '.mp4': 'video-mp4', '.doc': 'x-office-document', '.docx': 'x-office-document',
                '.odt': 'x-office-document', '.xls': 'x-office-spreadsheet', '.xlsx': 'x-office-spreadsheet',
                '.ods': 'x-office-spreadsheet', '.ppt': 'x-office-presentation', '.pptx': 'x-office-presentation',
                '.txt': 'text-plain', '.zip': 'application-zip', '.iso': 'application-x-cd-image'}.get(ext, 'text-x-generic')

    @Slot(int, list)
    def _juntar_arquivos(self, gen, itens):
        if gen != self._gen:
            return
        self._arquivos = itens
        self._resultados = self._procurar(self._consulta)
        self.resultadosMudaram.emit()

    # ---- API para o QML --------------------------------------------------------------------
    @Property('QVariantList', notify=resultadosMudaram)
    def resultados(self):
        return self._resultados

    @Property('QVariantMap', notify=estadoMudou)
    def estado(self):
        return self._estado

    @Property(str, notify=resultadosMudaram)
    def modo(self):
        return self._modo

    def _talvez_tempo(self, texto, gen):
        m = re.match(r'^\s*(?:tempo|clima|previs[aã]o(?: do tempo)?|weather)\s+(?:em|no|na|de|in|para)?\s*(.+?)\s*$',
                     texto, re.I)
        if not m:
            return
        cidade = m.group(1)

        def t():
            time.sleep(0.4)
            if gen != self._gen:
                return
            try:
                import urllib.parse
                import urllib.request
                url = 'https://wttr.in/%s?format=j1&lang=pt' % urllib.parse.quote(cidade)
                with urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'curl/8'}), timeout=6) as f:
                    j = json.load(f)
                atual = j['current_condition'][0]
                dia = j['weather'][0]
                desc = (atual.get('lang_pt') or atual.get('weatherDesc') or [{'value': ''}])[0]['value']
                local = j.get('nearest_area', [{}])[0].get('areaName', [{'value': cidade}])[0]['value']
                self._tempo = dict(q=texto.strip(), titulo='Tempo em ' + cidade.title(), cidade=local,
                                   hora=time.strftime('%H:%M'), temp=atual['temp_C'], max=dia['maxtempC'],
                                   min=dia['mintempC'], desc=desc, codigo=atual.get('weatherCode', ''),
                                   url='https://wttr.in/' + urllib.parse.quote(cidade))
                self.arquivosProntos.emit(gen, self._arquivos)
            except Exception:
                pass
        threading.Thread(target=t, daemon=True).start()

    def _talvez_rapido(self, texto, gen):
        busca = RP.rede(texto) if self._modo == '' else None
        if not busca:
            return

        def t():
            time.sleep(0.45)           # espera que acabe de escrever
            if gen != self._gen:
                return
            try:
                c = busca()
            except Exception:
                c = None
            if c and gen == self._gen:
                self._rapido = dict(q=texto, cartao=c)
                self.arquivosProntos.emit(gen, self._arquivos)
        threading.Thread(target=t, daemon=True).start()

    @Property('QVariantList', notify=resultadosMudaram)
    def correcoes(self):
        if self._modo or not self._consulta.strip():
            return []
        if self._exclusivo:
            return []
        return AC.correcoes(self._consulta, [a['nome'] for a in self._apps[:300]])

    @Slot(int, float)
    def definirValor(self, i, v):
        if not 0 <= i < len(self._resultados) or self._resultados[i]['tipo'] != 'acao':
            return
        for a in AC.A:
            if a['id'] == self._resultados[i]['alvo'] and a.get('definir'):
                a['definir'](v)
                self._resultados[i]['valor'] = v

    @Slot(str)
    def procurar(self, texto):
        self._consulta = texto
        self._gen += 1
        self._arquivos = []
        self._resultados = self._procurar(texto)
        self.resultadosMudaram.emit()
        t = texto.strip()
        self._talvez_tempo(t, self._gen)
        self._talvez_rapido(t, self._gen)
        if self._modo == '' and len(t) >= 3 and not t.startswith('>') and conta(t) is None and not self._exclusivo:
            g = self._gen

            def depois():
                time.sleep(0.25)       # espera que acabe de escrever
                if g == self._gen:
                    self._buscar_arquivos(g, t)
            threading.Thread(target=depois, daemon=True).start()

    @Slot(str)
    def definirModo(self, modo):
        self._modo = modo
        self.procurar('')

    @Slot(int, result=bool)
    def executar(self, i):
        """Devolve True se a janela deve fechar."""
        if not 0 <= i < len(self._resultados):
            return False
        it = self._resultados[i]
        tipo, alvo = it['tipo'], it['alvo']
        if tipo == 'acao':
            for a in AC.A:
                if a['id'] == alvo:
                    self._contar('acao:' + alvo)
                    a['fazer']()
        elif tipo in ('tempo',):
            correr(['xdg-open', alvo])
        elif tipo == 'rapido':
            if alvo.startswith('http'):
                correr(['xdg-open', alvo])
            else:
                self._copiar(alvo)
        elif tipo == 'estado':
            correr(MONITOR)
        elif tipo == 'app':
            self._contar('app:' + alvo)
            self._abrir_app(alvo)
        elif tipo == 'cmd':
            if alvo == '@clip':
                self._contar('cmd:@clip')
                self.definirModo('clip')
                return False
            self._contar('cmd:' + alvo)
            correr(alvo)
        elif tipo == 'arquivo':
            correr(['xdg-open', alvo])
        elif tipo in ('url', 'web'):
            correr(['xdg-open', alvo])
        elif tipo in ('conta', 'clip'):
            self._copiar(alvo)
        elif tipo == 'terminal':
            self._terminal(alvo)
        elif tipo == 'ext':
            acao = it['descricao']
            if acao == 'completar':
                # depois de o QML limpar a caixa (executar devolve False)
                QTimer.singleShot(0, lambda: self.textoPedido.emit(alvo))
                return False
            if acao == 'copiar':
                self._copiar(alvo)
            elif acao == 'abrir':
                correr(['xdg-open', os.path.expanduser(alvo)])
            elif acao == 'correr':
                correr(alvo)
            elif acao == 'terminal':
                self._terminal(alvo)
        else:
            return False
        return True

    @Slot(int, result='QVariantList')
    def acoes(self, i):
        if not 0 <= i < len(self._resultados):
            return []
        it = self._resultados[i]
        tipo = it['tipo']
        a = []
        if tipo == 'app':
            a.append(dict(id='abrir', nome='Abrir', icone='media-playback-start'))
            if Gio:
                try:
                    info = Gio.DesktopAppInfo.new(it['alvo'])
                    for ac in (info.list_actions() if info else []):
                        a.append(dict(id='acao:' + ac, nome=info.get_action_name(ac), icone='go-next'))
                except Exception:
                    pass
            a.append(dict(id='dock', nome='Adicionar à Dock', icone='window-pin'))
        elif tipo == 'arquivo':
            a += [dict(id='abrir', nome='Abrir', icone='document-open'),
                  dict(id='pasta', nome='Mostrar na pasta', icone='folder-open'),
                  dict(id='copiar', nome='Copiar o caminho', icone='edit-copy')]
        elif tipo in ('conta', 'clip'):
            a.append(dict(id='abrir', nome='Copiar', icone='edit-copy'))
        elif tipo == 'acao':
            a.append(dict(id='abrir', nome=it['botao'], icone=it['icone']))
            a.append(dict(id='definicoes', nome='Abrir as Configurações', icone='preferences-system'))
        elif tipo in ('tempo', 'estado'):
            a.append(dict(id='abrir', nome='Abrir', icone='go-next'))
        elif tipo == 'rapido':
            if it['alvo'].startswith('http'):
                a.append(dict(id='abrir', nome='Abrir', icone='go-next'))
            a.append(dict(id='copiar', nome='Copiar', icone='edit-copy'))
        elif tipo == 'ext':
            a.append(dict(id='abrir', nome=it['botao'], icone=it['icone']))
            a.append(dict(id='copiar', nome='Copiar', icone='edit-copy'))
        elif tipo in ('cmd', 'url', 'web', 'terminal'):
            a.append(dict(id='abrir', nome='Executar', icone='media-playback-start'))
            if tipo in ('url', 'web'):
                a.append(dict(id='copiar', nome='Copiar o endereço', icone='edit-copy'))
        return a

    @Slot(int, str, result=bool)
    def executarAcao(self, i, acao):
        if not 0 <= i < len(self._resultados):
            return False
        it = self._resultados[i]
        if acao == 'abrir':
            return self.executar(i)
        if acao == 'definicoes':
            correr('carinaeos-configuracoes')
        elif acao == 'pasta':
            correr(['carinaeos-arquivos', os.path.dirname(it['alvo']) or '/'])
        elif acao == 'copiar':
            if it['tipo'] == 'rapido':
                try:
                    self._copiar(json.loads(it['dados']).get('copiar') or it['titulo'])
                except ValueError:
                    self._copiar(it['titulo'])
            else:
                self._copiar(it['alvo'])
        elif acao == 'dock' and Gio:
            info = Gio.DesktopAppInfo.new(it['alvo'])
            if info and info.get_filename():
                correr(['carinaeos-dock-adicionar', info.get_filename()])
        elif acao.startswith('acao:') and Gio:
            info = Gio.DesktopAppInfo.new(it['alvo'])
            if info:
                try:
                    info.launch_action(acao[5:], None)
                except Exception:
                    pass
        return True

    def _abrir_app(self, ident):
        if Gio:
            try:
                info = Gio.DesktopAppInfo.new(ident)
                if info and info.launch([], None):
                    return
            except Exception:
                pass
        correr(['gtk-launch', ident])

    def _copiar(self, texto):
        QGuiApplication.clipboard().setText(texto)
        try:
            import dbus
            k = dbus.SessionBus().get_object('org.kde.klipper', '/klipper')
            k.setClipboardContents(texto, dbus_interface='org.kde.klipper.klipper')
        except Exception:
            pass

    # ---- estado do computador -------------------------------------------------------------
    @Slot(bool)
    def acompanhar(self, sim):
        if sim:
            self.atualizarEstado()
            self._relogio.start()
        else:
            self._relogio.stop()

    @Slot()
    def atualizarEstado(self):
        if not psutil:
            return
        try:
            m = psutil.virtual_memory()
            d = psutil.disk_usage(HOME)
            procs = []
            for p in psutil.process_iter(['name', 'cpu_percent', 'memory_info']):
                try:
                    procs.append((p.info['name'] or '?', p.info['cpu_percent'] or 0.0,
                                  p.info['memory_info'].rss if p.info['memory_info'] else 0))
                except Exception:
                    continue
            # o mesmo programa em varios processos (navegadores) conta uma vez so
            juntos = {}
            for n, cpu, rss in procs:
                j = juntos.setdefault(n, [0.0, 0])
                j[0] += cpu
                j[1] += rss
            ncpu = psutil.cpu_count() or 1
            top_cpu = sorted(juntos.items(), key=lambda kv: -kv[1][0])[:3]
            top_mem = sorted(juntos.items(), key=lambda kv: -kv[1][1])[:3]
            self._estado = dict(
                cpu='%d%%' % round(psutil.cpu_percent(None)),
                memoria=nome_tamanho(m.total - m.available), memoriaTotal='de ' + nome_tamanho(m.total),
                memoriaPct=(m.total - m.available) / m.total if m.total else 0,
                disco=nome_tamanho(d.free), discoTotal='livres de ' + nome_tamanho(d.total),
                discoPct=d.used / d.total if d.total else 0,
                topCpu=[dict(nome=self._nome_bonito(n), valor='%d%%' % round(v[0] / ncpu)) for n, v in top_cpu],
                topMem=[dict(nome=self._nome_bonito(n), valor=nome_tamanho(v[1])) for n, v in top_mem])
            self.estadoMudou.emit()
        except Exception:
            pass

    NOMES = {'plasmashell': 'Ambiente (Plasma)', 'kwin_wayland': 'Janelas (KWin)', 'kwin_x11': 'Janelas (KWin)',
             'firefox-esr': 'Firefox', 'firefox': 'Firefox', 'chrome': 'Google Chrome', 'Xorg': 'Tela (Xorg)',
             'dolphin': 'Arquivos', 'konsole': 'Terminal', 'python3': 'Python', 'baloo_file': 'Índice de arquivos',
             'systemd': 'Sistema', 'Isolated Web Co': 'Firefox (página)', 'Web Content': 'Firefox (página)'}

    def _nome_bonito(self, n):
        return self.NOMES.get(n, n)


def main():
    # ja esta aberto? pede-lhe para aparecer e sai
    s = QLocalSocket()
    s.connectToServer(NOME_SERVIDOR)
    if s.waitForConnected(300):
        if '--fundo' in sys.argv:
            return 0
        s.write(b'mostrar\n')
        s.flush()
        s.waitForBytesWritten(300)
        s.disconnectFromServer()
        return 0

    QQuickStyle.setStyle('Basic')
    app = QGuiApplication(sys.argv)
    app.setApplicationName('carinaeos-comando')
    app.setApplicationDisplayName('Comando')
    app.setDesktopFileName('carinaeos-comando')
    app.setWindowIcon(QIcon.fromTheme('carinaeos-estrela'))
    app.setQuitOnLastWindowClosed(False)

    comando = Comando()
    servidor = QLocalServer()
    QLocalServer.removeServer(NOME_SERVIDOR)
    servidor.listen(NOME_SERVIDOR)

    def ligacao():
        c = servidor.nextPendingConnection()
        if c:
            c.readyRead.connect(lambda: (c.readAll(), comando.recarregarExtensoes(), comando.mostrar.emit()))
            c.disconnected.connect(c.deleteLater)
    servidor.newConnection.connect(ligacao)

    motor = QQmlApplicationEngine()
    motor.addImageProvider('icone', Icones())
    motor.rootContext().setContextProperty('comando', comando)
    motor.load(os.path.join(AQUI, 'Main.qml'))
    if not motor.rootObjects():
        return 1
    if '--fundo' in sys.argv:
        # arranque com a sessao: fica pronta (lista de aplicativos ja carregada) sem aparecer
        QTimer.singleShot(1500, comando._carregar_apps)
    else:
        comando.mostrar.emit()
    return app.exec()


if __name__ == '__main__':
    sys.exit(main())
