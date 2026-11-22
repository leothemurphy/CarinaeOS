#!/usr/bin/python3
"""CarinaeOS - Pulsar Player: a música e os vídeos num só aplicativo.

  - Música: o mesmo motor do antigo app Música (musica.py), sem mudar nada — MPD sem terminal,
    biblioteca, álbuns com capa, letras sincronizadas, listas, rádios e Home Assistant.
  - Vídeo: Qt Multimedia (FFmpeg) — mp4, mkv, webm, avi, mov, wmv, flv, m4v, mpg, ts, 3gp, ogv...
    com miniaturas, legendas .srt (ao lado do vídeo) e embutidas, pistas de áudio e "continuar de onde parei".
  - Abre ficheiros de áudio e vídeo passados na linha de comando (duplo clique no Dolphin);
    se o Pulsar já estiver aberto, entrega-lhos e sai.

    carinaeos-pulsar [ficheiro ...]
"""
import hashlib
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import threading
import time
import urllib.parse

AQUI = os.path.dirname(os.path.abspath(__file__))
MOTOR_MUSICA = os.environ.get('CARINAE_MUSICA', '/usr/share/carinaeos/musica')
COMUM = os.environ.get('CARINAE_COMUM') or next((d for d in ('/usr/local/share/carinaeos/comum', '/usr/share/carinaeos/comum') if os.path.isdir(d)), '/usr/share/carinaeos/comum')
sys.path.insert(0, COMUM)
sys.path.insert(0, MOTOR_MUSICA)

HOME = os.path.expanduser('~')
DADOS = os.path.join(HOME, '.local/share/carinaeos/pulsar')
POSICOES = os.path.join(DADOS, 'posicoes.json')
MINIATURAS = os.path.join(HOME, '.cache/carinaeos/pulsar/miniaturas')
CANAL = os.path.join(os.environ.get('XDG_RUNTIME_DIR') or '/tmp', 'carinaeos-pulsar-%d.sock' % os.getuid())

VIDEO = {'mp4', 'm4v', 'mkv', 'webm', 'avi', 'mov', 'wmv', 'flv', 'mpg', 'mpeg', 'ts', 'm2ts', 'mts',
         '3gp', 'ogv', 'vob', 'divx', 'asf', 'rm', 'rmvb'}
AUDIO = {'mp3', 'flac', 'ogg', 'oga', 'opus', 'wav', 'm4a', 'aac', 'wma', 'aiff', 'aif', 'ape', 'mka', 'alac'}


def para_caminho(url):
    if url.startswith('file://'):
        return urllib.parse.unquote(urllib.parse.urlparse(url).path)
    return url


def para_url(caminho):
    if '://' in caminho:
        return caminho
    return 'file://' + urllib.parse.quote(os.path.abspath(caminho))


def extensao(c):
    return os.path.splitext(c)[1].lower().lstrip('.')


# --- já há um Pulsar aberto? entrega-lhe os ficheiros e sai --------------------------------------
def entregar_ao_aberto(urls):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(1.5)
        s.connect(CANAL)
        s.sendall(('\n'.join(urls or ['--mostrar']) + '\n').encode('utf-8'))
        s.close()
        return True
    except OSError:
        return False


from base import iniciar  # noqa: E402
from PySide6.QtCore import Property, QObject, Signal, Slot  # noqa: E402

try:
    import musica as motor          # o motor do app Música, tal e qual
    Musica = motor.Musica
except Exception as e:  # pragma: no cover
    print('Pulsar: não encontrei o motor de música (%s)' % e, file=sys.stderr)
    Musica = None


def ler_json(c, padrao):
    try:
        with open(c, encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return padrao


def gravar_json(c, v):
    os.makedirs(os.path.dirname(c), exist_ok=True)
    tmp = c + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(v, f, ensure_ascii=False)
    os.replace(tmp, c)


def pasta_xdg(nome, padrao):
    try:
        r = subprocess.run(['xdg-user-dir', nome], capture_output=True, text=True, timeout=3).stdout.strip()
        if r and r != HOME:
            return r
    except Exception:
        pass
    return os.path.join(HOME, padrao)


def tamanho_bonito(n):
    for u in ('B', 'KB', 'MB', 'GB'):
        if n < 1024 or u == 'GB':
            return ('%.0f %s' if u in ('B', 'KB') else '%.1f %s') % (n, u)
        n /= 1024.0


# --- legendas .srt ---------------------------------------------------------------------------------
_TEMPO = re.compile(r'(\d+):(\d+):(\d+)[,.](\d+)\s*-->\s*(\d+):(\d+):(\d+)[,.](\d+)')


def ler_srt(caminho):
    texto = None
    for cod in ('utf-8-sig', 'cp1252', 'latin-1'):
        try:
            with open(caminho, encoding=cod) as f:
                texto = f.read()
            break
        except Exception:
            continue
    if not texto:
        return []
    cues = []
    for bloco in re.split(r'\n\s*\n', texto.replace('\r', '')):
        linhas = [l for l in bloco.strip().split('\n') if l.strip()]
        for i, l in enumerate(linhas):
            m = _TEMPO.search(l)
            if m:
                g = [int(x) for x in m.groups()]
                ini = ((g[0] * 60 + g[1]) * 60 + g[2]) * 1000 + g[3]
                fim = ((g[4] * 60 + g[5]) * 60 + g[6]) * 1000 + g[7]
                t = '\n'.join(linhas[i + 1:])
                t = re.sub(r'</?[ibu]>|\{\\[^}]*\}|<font[^>]*>|</font>', '', t)
                if t:
                    cues.append({'ini': ini, 'fim': fim, 'texto': t})
                break
    cues.sort(key=lambda c: c['ini'])
    return cues


def legendas_ao_lado(video):
    base = os.path.splitext(video)[0]
    pasta = os.path.dirname(video)
    nome = os.path.basename(base).lower()
    candidatos = []
    try:
        for f in os.listdir(pasta):
            fl = f.lower()
            if fl.endswith('.srt') and fl.startswith(nome):
                resto = fl[len(nome):-4]          # '', '.pt', '.pt-br', '.por'...
                peso = 0 if resto in ('', '.pt', '.pt-br', '.pt_br', '.por', '.portuguese') else 1
                candidatos.append((peso, f))
    except OSError:
        pass
    candidatos.sort()
    return [os.path.join(pasta, f) for _, f in candidatos]


class Pulsar(QObject):
    videosMudou = Signal()
    pedidoAbrir = Signal(str)
    miniaturaPronta = Signal(str)
    avisoMudou = Signal()
    _chegou = Signal(object, object)

    def __init__(self, musica=None, iniciais=None):
        super().__init__()
        self._musica = musica
        # sem tema de ícones (fora do KDE/Carinae): o Breeze, como o resto do CarinaeOS
        from PySide6.QtGui import QIcon
        if not QIcon.themeName() or QIcon.themeName() == 'hicolor':
            QIcon.setThemeName('breeze-dark' if os.path.isdir('/usr/share/icons/breeze-dark') else 'breeze')
        QIcon.setFallbackThemeName('hicolor')
        self._videos = []
        self._aviso = ''
        self._posicoes = ler_json(POSICOES, {})
        self._iniciais = [para_url(c) for c in (iniciais or [])]
        self._a_ler = False
        self._chegou.connect(lambda f, r: f(r))
        os.makedirs(MINIATURAS, exist_ok=True)
        self.pastaVideos = pasta_xdg('VIDEOS', 'Vídeos')
        self._ouvir()
        self.recarregarVideos()

    # ---- canal: outro "carinaeos-pulsar ficheiro" entrega-nos o que quer abrir ----------------------
    def _ouvir(self):
        try:
            if os.path.exists(CANAL):
                os.unlink(CANAL)
            srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            srv.bind(CANAL)
            os.chmod(CANAL, 0o600)
            srv.listen(4)
        except OSError as e:
            print('Pulsar: sem canal (%s)' % e, file=sys.stderr)
            return

        def ciclo():
            while True:
                try:
                    c, _ = srv.accept()
                    dados = b''
                    while True:
                        b = c.recv(65536)
                        if not b:
                            break
                        dados += b
                    c.close()
                    for l in dados.decode('utf-8', 'replace').split('\n'):
                        l = l.strip()
                        if l:
                            self._chegou.emit(self.pedidoAbrir.emit, l)
                except OSError:
                    time.sleep(0.5)
        threading.Thread(target=ciclo, daemon=True).start()

    def _bg(self, trabalho, depois=None):
        def t():
            try:
                r = trabalho()
            except Exception as e:  # noqa: BLE001
                r = e
            if depois:
                self._chegou.emit(depois, r)
        threading.Thread(target=t, daemon=True).start()

    # ---- vídeos ---------------------------------------------------------------------------------------
    def _miniatura_de(self, caminho, mtime):
        h = hashlib.md5(('%s|%d' % (caminho, int(mtime))).encode('utf-8', 'replace')).hexdigest()
        return os.path.join(MINIATURAS, h + '.jpg')

    @Slot()
    def recarregarVideos(self):
        if self._a_ler:
            return
        self._a_ler = True
        pastas = [self.pastaVideos, pasta_xdg('DOWNLOAD', 'Downloads')]

        def trabalho():
            vistos, lista = set(), []
            for raiz in pastas:
                if not os.path.isdir(raiz):
                    continue
                base_n = raiz.rstrip('/').count('/')
                for d, subs, fs in os.walk(raiz, followlinks=True):
                    subs[:] = [s for s in subs if not s.startswith('.')]
                    if d.count('/') - base_n >= 4:
                        subs[:] = []
                    for f in fs:
                        if extensao(f) not in VIDEO or f.startswith('.'):
                            continue
                        c = os.path.join(d, f)
                        real = os.path.realpath(c)
                        if real in vistos:
                            continue
                        vistos.add(real)
                        try:
                            st = os.stat(c)
                        except OSError:
                            continue
                        lista.append({
                            'nome': os.path.splitext(f)[0],
                            'caminho': c,
                            'url': para_url(c),
                            'pasta': os.path.basename(d) if d != raiz else os.path.basename(raiz),
                            'tamanho': tamanho_bonito(st.st_size),
                            'data': st.st_mtime,
                            'miniatura': self._miniatura_de(c, st.st_mtime),
                            'legendas': bool(legendas_ao_lado(c)),
                        })
            lista.sort(key=lambda v: -v['data'])
            return lista

        def depois(r):
            self._a_ler = False
            if isinstance(r, list):
                for v in r:
                    p = self._posicoes.get(v['caminho'])
                    v['visto'] = (p['ms'] / p['dur']) if p and p.get('dur') else 0
                self._videos = r
                self.videosMudou.emit()
                self._fazer_miniaturas([v for v in r if not os.path.exists(v['miniatura'])])
        self._bg(trabalho, depois)

    def _fazer_miniaturas(self, faltam):
        if not faltam:
            return
        tem_ft = shutil.which('ffmpegthumbnailer')
        tem_ff = shutil.which('ffmpeg')
        if not (tem_ft or tem_ff):
            return

        def trabalho():
            for v in faltam:
                destino = v['miniatura']
                try:
                    if tem_ft:
                        subprocess.run(['ffmpegthumbnailer', '-i', v['caminho'], '-o', destino, '-s', '480', '-t', '12%', '-q', '8'],
                                       capture_output=True, timeout=40)
                    if not os.path.exists(destino) and tem_ff:
                        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-ss', '8', '-i', v['caminho'], '-frames:v', '1',
                                        '-vf', 'scale=480:-2', destino], capture_output=True, timeout=40)
                        if not os.path.exists(destino):
                            subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', v['caminho'], '-frames:v', '1',
                                            '-vf', 'scale=480:-2', destino], capture_output=True, timeout=40)
                except Exception:  # noqa: BLE001
                    pass
                if os.path.exists(destino):
                    self._chegou.emit(self.miniaturaPronta.emit, destino)
        self._bg(trabalho)

    videos = Property('QVariantList', lambda s: s._videos, notify=videosMudou)
    aviso = Property(str, lambda s: s._aviso, notify=avisoMudou)

    @Property(str, constant=True)
    def pasta(self):
        return self.pastaVideos

    # ---- ficheiros ------------------------------------------------------------------------------------
    @Slot(result='QVariantList')
    def ficheirosIniciais(self):
        r, self._iniciais = self._iniciais, []
        return r

    @Slot(str, result=str)
    def tipo(self, url):
        e = extensao(para_caminho(url))
        if e in VIDEO:
            return 'video'
        if e in AUDIO:
            return 'audio'
        if url.startswith(('http://', 'https://')):
            return 'video'
        return ''

    @Slot(str, result=str)
    def nomeDe(self, url):
        return os.path.splitext(os.path.basename(para_caminho(url)))[0]

    @Slot(str, result='QVariantList')
    def legendas(self, url):
        c = para_caminho(url)
        for s in legendas_ao_lado(c):
            cues = ler_srt(s)
            if cues:
                return cues
        return []

    @Slot(str, result=int)
    def posicao(self, url):
        p = self._posicoes.get(para_caminho(url))
        return int(p['ms']) if p else 0

    @Slot(str, int, int)
    def guardarPosicao(self, url, ms, dur):
        c = para_caminho(url)
        if not c or dur <= 0:
            return
        # perto do início ou do fim não vale a pena lembrar
        if ms < 15000 or ms > dur - 30000:
            self._posicoes.pop(c, None)
        else:
            self._posicoes[c] = {'ms': int(ms), 'dur': int(dur), 't': time.time()}
        if len(self._posicoes) > 500:
            for k, _ in sorted(self._posicoes.items(), key=lambda kv: kv[1].get('t', 0))[:100]:
                self._posicoes.pop(k, None)
        try:
            gravar_json(POSICOES, self._posicoes)
        except OSError:
            pass
        for v in self._videos:
            if v['caminho'] == c:
                v['visto'] = (ms / dur) if c in self._posicoes else 0

    @Slot()
    def escolherFicheiros(self):
        filtro = ' '.join('*.' + e for e in sorted(VIDEO | AUDIO))

        def trabalho():
            r = subprocess.run(['carinae-escolher', 'ficheiro', 'Abrir no Pulsar', self.pastaVideos,
                                'Vídeos e músicas', filtro], capture_output=True, text=True)
            return r.stdout.strip()

        def depois(r):
            if isinstance(r, str) and r:
                self.pedidoAbrir.emit(para_url(r))
        self._bg(trabalho, depois)

    @Slot(str)
    def mostrarNaPasta(self, url):
        subprocess.Popen(['xdg-open', os.path.dirname(para_caminho(url))], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    @Slot()
    def pausarMusica(self):
        """Ao começar um vídeo, a música do MPD fica em pausa (não tocam as duas ao mesmo tempo)."""
        m = self._musica
        try:
            if m is not None and (m.tocando or {}).get('estado') == 'play':
                m.tocarPausar()
        except Exception:  # noqa: BLE001
            pass


def principal():
    ficheiros = [a for a in sys.argv[1:] if not a.startswith('-')]
    urls = [para_url(a) for a in ficheiros]
    if entregar_ao_aberto(urls):
        return 0
    contexto = {}
    contexto['musica'] = Musica if Musica else QObject
    contexto['pulsar'] = lambda: Pulsar(contexto['musica'], ficheiros)
    return iniciar('carinaeos-pulsar', 'Carinae Pulsar', 'carinaeos-pulsar', os.path.join(AQUI, 'Main.qml'), contexto)


if __name__ == '__main__':
    sys.exit(principal())
