#!/usr/bin/python3
# CarinaeOS - Musica: a porta de entrada do MPD (Music Player Daemon).
#   - prepara e liga o MPD do utilizador (~/.config/mpd/mpd.conf), sem terminal
#   - monta a biblioteca a partir das pastas que a pessoa escolher (Musicas, discos, pastas de rede)
#   - albuns com capa (da propria musica ou da internet: MusicBrainz / Cover Art Archive), artistas, musicas
#   - letras (da musica ou do LRCLIB, com as linhas sincronizadas a acompanhar)
#   - listas: cada lista do MPD aparece como "fonte" no Home Assistant (integracao Music Player Daemon)
#   - radios da internet (guardadas como listas)
import hashlib
import json
import os
import re
import socket
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request

sys.path.insert(0, '/usr/share/carinaeos/comum')
from base import iniciar  # noqa: E402

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot  # noqa: E402

try:
    from mpd import MPDClient, CommandError
except ImportError:  # pragma: no cover
    MPDClient = None
    CommandError = Exception

AQUI = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser('~')
CONF_DIR = os.path.join(HOME, '.config/mpd')
CONF = os.path.join(CONF_DIR, 'mpd.conf')
DADOS = os.path.join(HOME, '.local/share/carinaeos/musica')
BIBLIO = os.path.join(DADOS, 'biblioteca')          # pastas escolhidas, como ligacoes
PREFS = os.path.join(DADOS, 'preferencias.json')
CAPAS = os.path.join(HOME, '.cache/carinaeos/capas')
LETRAS = os.path.join(HOME, '.cache/carinaeos/letras')
UA = 'CarinaeOS-Musica/1.0 (https://github.com/leothemurphy/CarinaeOS)'
PORTA = 6600


def pasta_musica():
    try:
        r = subprocess.run(['xdg-user-dir', 'MUSIC'], capture_output=True, text=True, timeout=3).stdout.strip()
        if r and r != HOME:
            return r
    except Exception:
        pass
    return os.path.join(HOME, 'Músicas')


def ip_local():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('10.255.255.255', 1))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return '127.0.0.1'


def ler_prefs():
    try:
        with open(PREFS, encoding='utf-8') as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def gravar_prefs(p):
    os.makedirs(DADOS, exist_ok=True)
    with open(PREFS, 'w', encoding='utf-8') as f:
        json.dump(p, f, ensure_ascii=False, indent=1)


def escrever_conf(rede, senha):
    """mpd.conf do utilizador. 'rede' abre o MPD a outros computadores (Home Assistant)."""
    os.makedirs(CONF_DIR, exist_ok=True)
    os.makedirs(os.path.join(DADOS, 'listas'), exist_ok=True)
    os.makedirs(BIBLIO, exist_ok=True)
    linhas = [
        '# Criado pelo aplicativo Música do CarinaeOS (mude-o lá, não aqui)',
        'music_directory    "%s"' % BIBLIO,
        'playlist_directory "%s"' % os.path.join(DADOS, 'listas'),
        'db_file            "%s"' % os.path.join(DADOS, 'mpd.db'),
        'state_file         "%s"' % os.path.join(DADOS, 'estado'),
        'sticker_file       "%s"' % os.path.join(DADOS, 'stickers.sql'),
        'follow_outside_symlinks "yes"',
        'follow_inside_symlinks  "yes"',
        'auto_update        "yes"',
        'restore_paused     "yes"',
        'metadata_to_use    "artist,album,title,track,name,genre,date,albumartist,disc,composer"',
        'bind_to_address    "%s"' % ('0.0.0.0' if rede else '127.0.0.1'),
        'port               "%d"' % PORTA,
        'zeroconf_enabled   "yes"',
        'zeroconf_name      "Música de %s"' % socket.gethostname(),
    ]
    if rede and senha:
        linhas.append('password           "%s@read,add,control,admin"' % senha.replace('"', ''))
    linhas += [
        'audio_output {',
        '    type  "pipewire"',
        '    name  "Altifalantes deste computador"',
        '}',
        'audio_output {',
        '    type  "pulse"',
        '    name  "Altifalantes (compatibilidade)"',
        '    enabled "no"',
        '}',
        'audio_output {',
        '    type     "httpd"',
        '    name     "Transmissão na rede (http://%s:8000)"' % ip_local(),
        '    encoder  "lame"',
        '    port     "8000"',
        '    bitrate  "192"',
        '    format   "44100:16:2"',
        '    always_on "yes"',
        '    enabled  "%s"' % ('yes' if rede else 'no'),
        '}',
    ]
    with open(CONF, 'w', encoding='utf-8') as f:
        f.write('\n'.join(linhas) + '\n')


def chave_capa(artista, album):
    return hashlib.sha1(('%s\x00%s' % (artista or '', album or '')).lower().encode()).hexdigest()


def baixar(url, timeout=10):
    req = urllib.request.Request(url, headers={'User-Agent': UA, 'Accept': 'application/json'})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


class Musica(QObject):
    mudou = Signal()
    estadoMudou = Signal()
    filaMudou = Signal()
    bibliotecaMudou = Signal()
    letraMudou = Signal()
    capaPronta = Signal(str)
    _chegou = Signal(object, object)

    def __init__(self):
        super().__init__()
        self._lock = threading.Lock()
        self._cli = None
        self._ligado = False
        self._estado = {}
        self._atual = {}
        self._albuns = []
        self._artistas = []
        self._musicas = []
        self._listas = []
        self._fila = []
        self._letra = dict(texto='', linhas=[], fonte='')
        self._msg = ''
        self._prefs = ler_prefs()
        self._chegou.connect(lambda f, r: f(r))
        os.makedirs(CAPAS, exist_ok=True)
        os.makedirs(LETRAS, exist_ok=True)
        self._relogio = QTimer(self)
        self._relogio.setInterval(1000)
        self._relogio.timeout.connect(self._tique)
        self._relogio.start()
        self._ultimo_id = None
        self._ultima_versao = None
        self._a_ler = False
        self._preparar()

    # ---- MPD --------------------------------------------------------------------------------------
    def _bg(self, trabalho, depois=None):
        def t():
            try:
                r = trabalho()
            except Exception as e:
                r = e
            if depois:
                self._chegou.emit(depois, r)
        threading.Thread(target=t, daemon=True).start()

    def _mpd(self, *cmd, **kw):
        """Corre um comando no MPD (liga-se se for preciso)."""
        if MPDClient is None:
            raise RuntimeError('python3-mpd em falta')
        with self._lock:
            for tentativa in range(2):
                try:
                    if self._cli is None:
                        c = MPDClient()
                        c.timeout = 8
                        c.idletimeout = None
                        c.connect('127.0.0.1', PORTA)
                        senha = self._prefs.get('senha') if self._prefs.get('rede') else ''
                        if senha:
                            c.password(senha)
                        self._cli = c
                    return getattr(self._cli, cmd[0])(*cmd[1:], **kw)
                except (ConnectionError, OSError, BrokenPipeError) as e:
                    try:
                        if self._cli:
                            self._cli.disconnect()
                    except Exception:
                        pass
                    self._cli = None
                    if tentativa:
                        raise e

    def _preparar(self):
        """Primeira vez: mpd.conf, a pasta Músicas na biblioteca, e o MPD ligado com a sessão."""
        def trabalho():
            if not os.path.exists(CONF) or 'Criado pelo aplicativo Música' not in open(CONF, encoding='utf-8').read():
                if os.path.exists(CONF):
                    os.replace(CONF, CONF + '.antes-do-carinaeos')
                escrever_conf(self._prefs.get('rede', False), self._prefs.get('senha', ''))
            if not os.listdir(BIBLIO):
                m = pasta_musica()
                os.makedirs(m, exist_ok=True)
                try:
                    os.symlink(m, os.path.join(BIBLIO, os.path.basename(m) or 'Músicas'))
                except FileExistsError:
                    pass
            subprocess.run(['systemctl', '--user', 'enable', '--now', 'mpd.service'], capture_output=True, timeout=30)
            for _ in range(20):
                try:
                    self._mpd('ping')
                    return True
                except Exception:
                    time.sleep(0.5)
            # sem systemd de utilizador: arranca à mão
            subprocess.Popen(['mpd', CONF], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            for _ in range(20):
                try:
                    self._mpd('ping')
                    return True
                except Exception:
                    time.sleep(0.5)
            return False

        def depois(r):
            self._ligado = r is True
            self._msg = '' if self._ligado else 'Não foi possível ligar o servidor de música (MPD).'
            self.mudou.emit()
            if self._ligado:
                self.recarregar()
        self._bg(trabalho, depois)

    def _reiniciar_mpd(self):
        with self._lock:
            try:
                if self._cli:
                    self._cli.disconnect()
            except Exception:
                pass
            self._cli = None
        subprocess.run(['systemctl', '--user', 'restart', 'mpd.service'], capture_output=True, timeout=30)
        time.sleep(1.5)

    # ---- estado (a cada segundo) ---------------------------------------------------------------------
    def _tique(self):
        # um pedido de cada vez: num computador lento não se acumulam
        if not self._ligado or self._a_ler:
            return
        self._a_ler = True

        def trabalho():
            st = self._mpd('status')
            atual = self._mpd('currentsong') if st.get('songid') != self._ultimo_id else None
            st['_db'] = self._mpd('stats').get('db_update')
            return st, atual

        def depois(r):
            self._a_ler = False
            if isinstance(r, Exception):
                return
            st, atual = r
            mudou = st != self._estado
            if st.get('playlist') != self._estado.get('playlist'):
                self._ler_fila()
            self._estado = st
            if atual is not None:
                self._ultimo_id = st.get('songid')
                self._atual = atual
                self._letra = dict(texto='', linhas=[], fonte='')
                self.letraMudou.emit()
                if atual:
                    self._procurar_letra(atual)
                    self._capa_de(atual.get('albumartist') or atual.get('artist', ''), atual.get('album', ''), atual.get('file', ''))
            # a biblioteca mudou (pasta nova, músicas copiadas): volta a ler
            if st.get('_db') != self._ultima_versao:
                if self._ultima_versao is not None:
                    self.recarregar()
                self._ultima_versao = st.get('_db')
            if mudou or atual is not None:   # só redesenha quando alguma coisa mudou
                self.estadoMudou.emit()
        self._bg(trabalho, depois)

    # ---- biblioteca ----------------------------------------------------------------------------------
    @Slot()
    def recarregar(self):
        def trabalho():
            albuns = {}
            artistas = {}
            musicas = []
            for m in self._mpd('listallinfo'):
                if 'file' not in m:
                    continue
                art = m.get('albumartist') or m.get('artist') or 'Artista desconhecido'
                if isinstance(art, list):
                    art = art[0]
                alb = m.get('album') or 'Sem álbum'
                if isinstance(alb, list):
                    alb = alb[0]
                tit = m.get('title') or os.path.splitext(os.path.basename(m['file']))[0]
                if isinstance(tit, list):
                    tit = tit[0]
                dur = float(m.get('duration') or m.get('time') or 0)
                k = chave_capa(art, alb)
                a = albuns.setdefault(k, dict(chave=k, album=alb, artista=art, ano=str(m.get('date', ''))[:4],
                                              faixas=0, ficheiro=m['file'], capa=''))
                a['faixas'] += 1
                artistas[art] = artistas.get(art, 0) + 1
                musicas.append(dict(ficheiro=m['file'], titulo=tit, artista=art, album=alb, duracao=dur,
                                    faixa=str(m.get('track', '')).split('/')[0], chave=k))
            for a in albuns.values():
                c = os.path.join(CAPAS, a['chave'] + '.jpg')
                a['capa'] = 'file://' + c if os.path.exists(c) else ''
            lista_alb = sorted(albuns.values(), key=lambda a: (a['artista'].lower(), a['ano'], a['album'].lower()))
            lista_art = [dict(nome=n, musicas=q) for n, q in sorted(artistas.items(), key=lambda x: x[0].lower())]
            musicas.sort(key=lambda m: (m['artista'].lower(), m['album'].lower(), int(m['faixa']) if m['faixa'].isdigit() else 0))
            listas = [dict(nome=p['playlist']) for p in self._mpd('listplaylists')]
            return lista_alb, lista_art, musicas, sorted(listas, key=lambda x: x['nome'].lower())

        def depois(r):
            if isinstance(r, Exception):
                self._msg = 'Erro a ler a biblioteca: %s' % r
                self.mudou.emit()
                return
            self._albuns, self._artistas, self._musicas, self._listas = r
            self.bibliotecaMudou.emit()
            # capas em falta: da própria música (MPD) primeiro
            self._capas_em_falta()
        self._bg(trabalho, depois)

    def _capas_em_falta(self):
        falta = [a for a in self._albuns if not a['capa']]

        def trabalho():
            for a in falta:
                self._capa_de(a['artista'], a['album'], a['ficheiro'], so_local=not self._prefs.get('internet', True), sincrono=True)
            return True
        self._bg(trabalho)

    def _capa_de(self, artista, album, ficheiro, so_local=False, sincrono=False):
        k = chave_capa(artista, album)
        destino = os.path.join(CAPAS, k + '.jpg')
        if os.path.exists(destino):
            self._chegou.emit(self._capa_ok, (k, destino))
            return

        def trabalho():
            dados = b''
            # 1) a capa dentro da música ou cover.jpg na pasta (o MPD lê as duas)
            for cmd in ('readpicture', 'albumart'):
                try:
                    r = self._mpd(cmd, ficheiro)
                    if r and r.get('binary'):
                        dados = r['binary']
                        break
                except Exception:
                    continue
            # 2) a internet: MusicBrainz + Cover Art Archive
            if not dados and not so_local and album and album != 'Sem álbum':
                try:
                    q = 'release:"%s" AND artist:"%s"' % (album.replace('"', ''), artista.replace('"', ''))
                    j = json.loads(baixar('https://musicbrainz.org/ws/2/release/?fmt=json&limit=3&query=' + urllib.parse.quote(q)))
                    for rel in j.get('releases', []):
                        try:
                            dados = baixar('https://coverartarchive.org/release/%s/front-500' % rel['id'], 15)
                            if dados:
                                break
                        except Exception:
                            continue
                    time.sleep(1.1)   # regras do MusicBrainz: 1 pedido por segundo
                except Exception:
                    pass
            if dados:
                with open(destino, 'wb') as f:
                    f.write(dados)
                return (k, destino)
            return None

        if sincrono:
            r = trabalho()
            if r:
                self._chegou.emit(self._capa_ok, r)
        else:
            self._bg(trabalho, lambda r: r and not isinstance(r, Exception) and self._capa_ok(r))

    def _capa_ok(self, r):
        k, destino = r
        url = 'file://' + destino
        for a in self._albuns:
            if a['chave'] == k:
                a['capa'] = url
        self.capaPronta.emit(k)
        self.bibliotecaMudou.emit()
        self.estadoMudou.emit()

    # ---- letras -----------------------------------------------------------------------------------------
    def _procurar_letra(self, m):
        art = m.get('artist') or ''
        if isinstance(art, list):
            art = art[0]
        tit = m.get('title') or ''
        if isinstance(tit, list):
            tit = tit[0]
        alb = m.get('album') or ''
        if isinstance(alb, list):
            alb = alb[0]
        dur = int(float(m.get('duration') or m.get('time') or 0))
        ficheiro = m.get('file', '')
        cache = os.path.join(LETRAS, hashlib.sha1(('%s\x00%s' % (art, tit)).lower().encode()).hexdigest() + '.json')
        if not tit:
            return

        def trabalho():
            if os.path.exists(cache):
                with open(cache, encoding='utf-8') as f:
                    return json.load(f)
            # 1) letra guardada na própria música
            caminho = os.path.realpath(os.path.join(BIBLIO, ficheiro))
            try:
                import mutagen
                mf = mutagen.File(caminho)
                if mf is not None and mf.tags is not None:
                    for k in list(mf.tags.keys()):
                        if k.startswith('USLT') or k.lower() in ('lyrics', 'unsyncedlyrics', '©lyr'):
                            v = mf.tags[k]
                            texto = getattr(v, 'text', v)
                            if isinstance(texto, list):
                                texto = '\n'.join(map(str, texto))
                            if str(texto).strip():
                                return dict(texto=str(texto), sincronizada='', fonte='da própria música')
            except Exception:
                pass
            # 2) LRCLIB (gratuito, sem conta)
            if not self._prefs.get('internet', True):
                return None
            q = {'artist_name': art, 'track_name': tit}
            if alb:
                q['album_name'] = alb
            if dur:
                q['duration'] = str(dur)
            try:
                j = json.loads(baixar('https://lrclib.net/api/get?' + urllib.parse.urlencode(q)))
            except Exception:
                try:
                    lst = json.loads(baixar('https://lrclib.net/api/search?' + urllib.parse.urlencode(
                        {'track_name': tit, 'artist_name': art})))
                    j = lst[0] if lst else None
                except Exception:
                    j = None
            if not j:
                return None
            r = dict(texto=j.get('plainLyrics') or '', sincronizada=j.get('syncedLyrics') or '', fonte='LRCLIB')
            with open(cache, 'w', encoding='utf-8') as f:
                json.dump(r, f, ensure_ascii=False)
            return r

        def depois(r):
            if self._atual.get('file') != ficheiro:
                return
            if not r or isinstance(r, Exception):
                self._letra = dict(texto='', linhas=[], fonte='')
            else:
                linhas = []
                for l in (r.get('sincronizada') or '').splitlines():
                    mm = re.match(r'\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)', l)
                    if mm:
                        linhas.append(dict(t=int(mm.group(1)) * 60 + float(mm.group(2)), texto=mm.group(3)))
                self._letra = dict(texto=r.get('texto') or '\n'.join(x['texto'] for x in linhas), linhas=linhas,
                                   fonte=r.get('fonte', ''))
            self.letraMudou.emit()
        self._bg(trabalho, depois)

    # ---- fila -------------------------------------------------------------------------------------------
    def _ler_fila(self):
        def trabalho():
            r = []
            for m in self._mpd('playlistinfo'):
                tit = m.get('title') or m.get('name') or os.path.basename(m.get('file', ''))
                art = m.get('artist') or ''
                r.append(dict(id=m.get('id'), pos=int(m.get('pos', 0)), titulo=tit if isinstance(tit, str) else tit[0],
                              artista=art if isinstance(art, str) else art[0]))
            return r
        self._bg(trabalho, lambda r: (not isinstance(r, Exception)) and (setattr(self, '_fila', r), self.filaMudou.emit()))

    # ---- propriedades para o QML ----------------------------------------------------------------------
    ligado = Property(bool, lambda s: s._ligado, notify=mudou)
    mensagem = Property(str, lambda s: s._msg, notify=mudou)
    albuns = Property('QVariantList', lambda s: s._albuns, notify=bibliotecaMudou)
    artistas = Property('QVariantList', lambda s: s._artistas, notify=bibliotecaMudou)
    musicas = Property('QVariantList', lambda s: s._musicas, notify=bibliotecaMudou)
    listas = Property('QVariantList', lambda s: s._listas, notify=bibliotecaMudou)
    fila = Property('QVariantList', lambda s: s._fila, notify=filaMudou)
    letra = Property('QVariantMap', lambda s: s._letra, notify=letraMudou)

    @Property('QVariantMap', notify=estadoMudou)
    def tocando(self):
        st, m = self._estado, self._atual
        def um(v):
            return v[0] if isinstance(v, list) else (v or '')
        art = um(m.get('albumartist') or m.get('artist'))
        alb = um(m.get('album'))
        c = os.path.join(CAPAS, chave_capa(art, alb) + '.jpg')
        return dict(
            estado=st.get('state', 'stop'),
            titulo=um(m.get('title')) or um(m.get('name')) or os.path.basename(m.get('file', '')),
            artista=um(m.get('artist')), album=alb,
            capa='file://' + c if os.path.exists(c) else '',
            tempo=float(st.get('elapsed', 0) or 0), duracao=float(st.get('duration', 0) or 0),
            volume=int(st.get('volume', -1) or -1), aleatorio=st.get('random') == '1', repetir=st.get('repeat') == '1',
            atualizando='updating_db' in st, pos=int(st.get('song', -1) or -1))

    @Property('QVariantList', notify=mudou)
    def pastas(self):
        r = []
        for n in sorted(os.listdir(BIBLIO)) if os.path.isdir(BIBLIO) else []:
            p = os.path.join(BIBLIO, n)
            r.append(dict(nome=n, caminho=os.path.realpath(p)))
        return r

    @Property('QVariantMap', notify=mudou)
    def rede(self):
        return dict(ligada=bool(self._prefs.get('rede')), ip=ip_local(), porta=PORTA, temSenha=bool(self._prefs.get('senha')),
                    internet=self._prefs.get('internet', True), nome=socket.gethostname())

    # ---- comandos de reprodução -------------------------------------------------------------------------
    def _faz(self, *cmd, depois=None):
        self._bg(lambda: self._mpd(*cmd), lambda r: (self._tique(), depois and depois(r)))

    @Slot()
    def tocarPausar(self):
        if self._estado.get('state') == 'play':
            self._faz('pause', 1)
        elif self._estado.get('state') == 'pause':
            self._faz('pause', 0)
        else:
            self._faz('play')

    @Slot()
    def seguinte(self):
        self._faz('next')

    @Slot()
    def anterior(self):
        self._faz('previous')

    @Slot(float)
    def irPara(self, segundos):
        self._faz('seekcur', '%.1f' % segundos)

    @Slot(int)
    def definirVolume(self, v):
        self._faz('setvol', max(0, min(100, v)))

    @Slot()
    def alternarAleatorio(self):
        self._faz('random', 0 if self._estado.get('random') == '1' else 1)

    @Slot()
    def alternarRepetir(self):
        self._faz('repeat', 0 if self._estado.get('repeat') == '1' else 1)

    @Slot(int)
    def tocarNaFila(self, pos):
        self._faz('play', pos)

    def _substituir_e_tocar(self, ficheiros, inicio=0):
        def trabalho():
            self._mpd('clear')
            for f in ficheiros:
                self._mpd('add', f)
            self._mpd('play', inicio)
        self._bg(trabalho, lambda r: self._tique())

    @Slot(str)
    def tocarAlbum(self, chave):
        fs = [m['ficheiro'] for m in self._musicas if m['chave'] == chave]
        self._substituir_e_tocar(fs)

    @Slot(str)
    def tocarArtista(self, nome):
        self._substituir_e_tocar([m['ficheiro'] for m in self._musicas if m['artista'] == nome])

    @Slot(str, str)
    def tocarMusica(self, ficheiro, contexto):
        """Toca a música dentro do seu álbum (ou da lista de todas), como nos leitores habituais."""
        if contexto == 'album':
            k = next((m['chave'] for m in self._musicas if m['ficheiro'] == ficheiro), '')
            fs = [m['ficheiro'] for m in self._musicas if m['chave'] == k]
        else:
            fs = [m['ficheiro'] for m in self._musicas]
        self._substituir_e_tocar(fs, fs.index(ficheiro) if ficheiro in fs else 0)

    @Slot(str)
    def adicionarFila(self, ficheiro):
        self._faz('add', ficheiro)
        self._msg = 'Adicionada à fila ✓'
        self.mudou.emit()

    @Slot(str)
    def tocarLista(self, nome):
        def trabalho():
            self._mpd('clear')
            self._mpd('load', nome)
            self._mpd('play', 0)
        self._bg(trabalho, lambda r: self._tique())

    # ---- listas (as "fontes" do Home Assistant) -----------------------------------------------------------
    @Slot(str)
    def guardarFilaComo(self, nome):
        nome = nome.strip().replace('/', '-')
        if not nome:
            return

        def trabalho():
            try:
                self._mpd('rm', nome)
            except Exception:
                pass
            self._mpd('save', nome)
        self._bg(trabalho, lambda r: (self._aviso('Lista “%s” guardada ✓ — aparece como fonte no Home Assistant' % nome)
                                      if not isinstance(r, Exception) else self._aviso('Erro: %s' % r), self.recarregar()))

    @Slot(str, str)
    def adicionarALista(self, ficheiro, nome):
        self._bg(lambda: self._mpd('playlistadd', nome, ficheiro),
                 lambda r: self._aviso(('Adicionada a “%s” ✓' % nome) if not isinstance(r, Exception) else 'Erro: %s' % r))

    @Slot(str)
    def apagarLista(self, nome):
        self._bg(lambda: self._mpd('rm', nome), lambda r: self.recarregar())

    @Slot(str, str)
    def adicionarRadio(self, nome, url):
        """Uma rádio da internet guardada como lista (assim também aparece no Home Assistant)."""
        nome, url = nome.strip(), url.strip()
        if not url:
            return
        if not re.match(r'^[a-z]+://', url):
            url = 'http://' + url
        nome = nome or url.split('/')[2]

        def trabalho():
            try:
                self._mpd('rm', 'Rádio · ' + nome)
            except Exception:
                pass
            self._mpd('playlistadd', 'Rádio · ' + nome, url)
        self._bg(trabalho, lambda r: (self._aviso('Rádio adicionada ✓') if not isinstance(r, Exception)
                                      else self._aviso('Erro: %s' % r), self.recarregar()))

    # ---- biblioteca: pastas ----------------------------------------------------------------------------------
    @Slot()
    def escolherPasta(self):
        def trabalho():
            return subprocess.run(['kdialog', '--title', 'Escolha uma pasta com música', '--getexistingdirectory', HOME],
                                  capture_output=True, text=True)

        def depois(r):
            if isinstance(r, Exception) or r.returncode != 0 or not r.stdout.strip():
                return
            self.adicionarPasta(r.stdout.strip())
        self._bg(trabalho, depois)

    @Slot(str)
    def adicionarPasta(self, caminho):
        if caminho.startswith('file://'):
            caminho = urllib.parse.unquote(caminho[7:])
        if not os.path.isdir(caminho):
            self._aviso('Pasta não encontrada')
            return
        nome = os.path.basename(caminho.rstrip('/')) or 'Música'
        destino = os.path.join(BIBLIO, nome)
        i = 2
        while os.path.lexists(destino):
            if os.path.realpath(destino) == os.path.realpath(caminho):
                self._aviso('Essa pasta já está na biblioteca')
                return
            destino = os.path.join(BIBLIO, '%s (%d)' % (nome, i))
            i += 1
        os.symlink(caminho, destino)
        self.mudou.emit()
        self.atualizarBiblioteca()

    @Slot(str)
    def tirarPasta(self, nome):
        p = os.path.join(BIBLIO, nome)
        if os.path.islink(p):
            os.remove(p)          # só a ligação: a música fica onde estava
        self.mudou.emit()
        self.atualizarBiblioteca()

    @Slot()
    def atualizarBiblioteca(self):
        self._aviso('A ler as pastas de música…')

        def trabalho():
            self._mpd('rescan')
            for _ in range(600):
                time.sleep(1)
                if 'updating_db' not in self._mpd('status'):
                    break
        self._bg(trabalho, lambda r: (self._aviso('Biblioteca atualizada ✓'), self.recarregar()))

    @Slot()
    def procurarCapas(self):
        self._aviso('A procurar capas na internet…')
        self._bg(lambda: [self._capa_de(a['artista'], a['album'], a['ficheiro'], sincrono=True)
                          for a in list(self._albuns) if not a['capa']],
                 lambda r: self._aviso('Capas atualizadas ✓'))

    # ---- rede / Home Assistant -----------------------------------------------------------------------------
    @Slot(bool, str)
    def definirRede(self, ligar, senha):
        self._prefs['rede'] = ligar
        if senha is not None:
            self._prefs['senha'] = senha.strip()
        gravar_prefs(self._prefs)
        self._aviso('A aplicar…')

        def trabalho():
            escrever_conf(ligar, self._prefs.get('senha', ''))
            self._reiniciar_mpd()
            subprocess.run('command -v ufw >/dev/null && ufw status | grep -q active && ufw allow %d/tcp' % PORTA,
                           shell=True, capture_output=True)
            return True
        self._bg(trabalho, lambda r: (self._aviso('Pronto ✓' if r is True else 'Erro: %s' % r), self.mudou.emit()))

    @Slot(bool)
    def definirInternet(self, sim):
        self._prefs['internet'] = sim
        gravar_prefs(self._prefs)
        self.mudou.emit()

    def _aviso(self, t):
        self._msg = t
        self.mudou.emit()


if __name__ == '__main__':
    sys.exit(iniciar('carinaeos-musica', 'Música', 'carinaeos-musica', os.path.join(AQUI, 'Main.qml'),
                     {'musica': Musica()}))
