# CarinaeOS - Eta: voz (ouvir e falar), tudo no proprio computador.
#  - ouvir: grava o microfone com o pw-record (PipeWire), para sozinho quando a pessoa
#    se cala, e transcreve com o whisper.cpp (modelo "base", multilingue).
#  - falar: Piper (voz pt_BR "faber", natural) se estiver instalado; senao espeak-ng.
import array
import math
import os
import shutil
import subprocess
import tempfile
import time

DADOS = os.path.join(os.environ.get('XDG_DATA_HOME', os.path.expanduser('~/.local/share')), 'carinaeos', 'eta')
WHISPER = '/opt/carinaeos/whisper/whisper-cli'
MODELO_VOZ = os.path.join(DADOS, 'ouvido.bin')
URL_MODELO_VOZ = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin'
TAMANHO_MODELO_VOZ = 147951465
VOZ_PIPER = os.path.join(DADOS, 'voz-pt_BR.onnx')
URL_VOZ_PIPER = 'https://huggingface.co/rhasspy/piper-voices/resolve/main/pt/pt_BR/faber/medium/pt_BR-faber-medium.onnx'
TAMANHO_VOZ_PIPER = 63201294
URL_VOZ_PIPER_JSON = URL_VOZ_PIPER + '.json'


def pode_ouvir():
    return os.path.exists(WHISPER) and os.path.exists(MODELO_VOZ) and bool(shutil.which('pw-record'))


def _rms(dados):
    if len(dados) < 4:
        return 0.0
    a = array.array('h')
    a.frombytes(dados[:len(dados) - len(dados) % 2])
    if not a:
        return 0.0
    return math.sqrt(sum(x * x for x in a) / len(a))


class Gravador:
    """Grava ate a pessoa parar de falar. ouvir() bloqueia; parar() pode ser chamado de outra thread."""

    def __init__(self):
        self._proc = None
        self._parar = False
        self.nivel = 0.0          # 0..1, para a animacao da nuvem

    def parar(self):
        self._parar = True

    def ouvir(self, max_seg=15, silencio_fim=1.3, espera_inicio=7):
        """Devolve o caminho de um WAV com a fala, ou None (nada ouvido / cancelado)."""
        self._parar = False
        pasta = tempfile.mkdtemp(prefix='eta-voz-')
        wav = os.path.join(pasta, 'fala.wav')
        self._proc = subprocess.Popen(['pw-record', '--rate', '16000', '--channels', '1', '--format', 's16', wav],
                                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        inicio = time.time()
        lido = 44                  # cabecalho WAV
        ruido = []
        limiar = None
        falou = False
        ultimo_som = None
        try:
            while not self._parar:
                time.sleep(0.1)
                agora = time.time() - inicio
                try:
                    with open(wav, 'rb') as f:
                        f.seek(lido)
                        bloco = f.read()
                except OSError:
                    bloco = b''
                lido += len(bloco)
                r = _rms(bloco)
                self.nivel = min(1.0, r / 4000.0)
                if agora < 0.4:                       # mede o ruido de fundo
                    ruido.append(r)
                    continue
                if limiar is None:
                    base = sorted(ruido)[len(ruido) // 2] if ruido else 200
                    limiar = max(450.0, base * 2.8)
                if r > limiar:
                    falou = True
                    ultimo_som = agora
                if falou and ultimo_som is not None and agora - ultimo_som > silencio_fim:
                    break
                if not falou and agora > espera_inicio:
                    break
                if agora > max_seg:
                    break
        finally:
            self._proc.terminate()
            try:
                self._proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self._proc.kill()
            self.nivel = 0.0
        if self._parar or not falou:
            return None
        return wav


def transcrever(wav):
    """Texto falado (em portugues), ou '' se nao percebeu."""
    if not wav or not os.path.exists(wav):
        return ''
    threads = str(max(1, min(8, os.cpu_count() or 2)))
    try:
        r = subprocess.run([WHISPER, '-m', MODELO_VOZ, '-l', 'pt', '-t', threads, '-nt', '-np', '-f', wav],
                           capture_output=True, text=True, timeout=120)
        txt = ' '.join(l.strip() for l in r.stdout.splitlines() if l.strip())
    except Exception:
        txt = ''
    finally:
        shutil.rmtree(os.path.dirname(wav), ignore_errors=True)
    txt = txt.replace('[BLANK_AUDIO]', '').replace('(música)', '').strip(' .')
    return txt


class Falante:
    """Le textos em voz alta; parar() interrompe."""

    def __init__(self):
        self._proc = None

    @staticmethod
    def _limpo(texto):
        import re
        t = re.sub(r'[`*_#>|]', ' ', texto)
        t = re.sub(r'https?://\S+', 'o endereço', t)
        t = re.sub(r'[✦✓✕•]', '', t)
        return re.sub(r'\s+', ' ', t).strip()[:600]

    def falar(self, texto):
        self.parar()
        t = self._limpo(texto)
        if not t:
            return
        if os.path.exists(VOZ_PIPER) and os.path.exists(VOZ_PIPER + '.json') and shutil.which('piper') and shutil.which('pw-play'):
            cmd = 'piper -m %s --output-raw 2>/dev/null | pw-play --rate 22050 --channels 1 --format s16 -' % (
                subprocess.list2cmdline([VOZ_PIPER]))
            self._proc = subprocess.Popen(['bash', '-c', cmd], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                                          stderr=subprocess.DEVNULL, start_new_session=True)
            try:
                self._proc.stdin.write(t.encode())
                self._proc.stdin.close()
            except OSError:
                pass
        elif shutil.which('espeak-ng'):
            self._proc = subprocess.Popen(['espeak-ng', '-v', 'pt-br', '-s', '165', t],
                                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

    def parar(self):
        if self._proc and self._proc.poll() is None:
            try:
                os.killpg(self._proc.pid, 15)
            except OSError:
                pass
        self._proc = None
