#!/usr/bin/python3
# CarinaeOS - Casa: painéis do Home Assistant montados pelo usuário, com tipos de cartões
# (botão, luz, entidades, sensor, gráfico, clima, cenas, som/TV, câmara, estores, tempo,
# número, texto), e este computador no Home Assistant (MQTT).
#
# Para nunca travar: a rede corre sempre noutra thread; a lista de cartões só muda quando o
# usuário mexe no painel; os estados chegam num dicionário (os cartões só atualizam o texto).
import json
import os
import sys
import tempfile
import threading
import time

sys.path.insert(0, '/usr/share/carinaeos/comum')
from base import correr, iniciar  # noqa: E402
import casa_ha as HA  # noqa: E402

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
PAINEIS = os.path.join(os.path.dirname(HA.CFG), 'casa-paineis.json')
CAMERAS = os.path.join(tempfile.gettempdir(), 'carinaeos-casa-%d' % os.getuid())

TIPOS = [
    dict(id='botao', nome='Botão', desc='Um aparelho grande para ligar e desligar', dominios=['light', 'switch', 'fan', 'input_boolean', 'lock', 'cover', 'scene', 'script', 'button', 'input_button', 'automation'], max=1),
    dict(id='luz', nome='Luz', desc='Luz com brilho', dominios=['light'], max=1),
    dict(id='entidades', nome='Lista', desc='Vários aparelhos ou sensores numa lista', dominios=[], max=12),
    dict(id='sensor', nome='Sensor', desc='Um valor em grande (temperatura, consumo…)', dominios=['sensor', 'binary_sensor'], max=1),
    dict(id='grafico', nome='Gráfico', desc='Histórico das últimas 24 horas', dominios=['sensor'], max=1),
    dict(id='clima', nome='Clima', desc='Ar condicionado ou aquecimento', dominios=['climate', 'water_heater', 'humidifier'], max=1),
    dict(id='cenas', nome='Cenas', desc='Fila de botões para cenas e rotinas', dominios=['scene', 'script', 'button', 'input_button', 'automation'], max=8),
    dict(id='media', nome='Som e TV', desc='Música ou TV com controlos', dominios=['media_player'], max=1),
    dict(id='camera', nome='Câmara', desc='Imagem ao vivo (a cada 10 s)', dominios=['camera'], max=1),
    dict(id='estores', nome='Estores e portões', desc='Abrir, parar e fechar', dominios=['cover'], max=1),
    dict(id='tempo', nome='Tempo', desc='Previsão do tempo', dominios=['weather'], max=1),
    dict(id='numero', nome='Número', desc='Controlo deslizante ou escolha', dominios=['input_number', 'number', 'select', 'input_select'], max=1),
    dict(id='texto', nome='Texto', desc='Uma nota ou título', dominios=[], max=0),
]


def ler_paineis():
    try:
        with open(PAINEIS, encoding='utf-8') as f:
            d = json.load(f)
            if d.get('paineis'):
                return d
    except (OSError, ValueError):
        pass
    return {'paineis': [{'nome': 'Início', 'cartoes': []}]}


def sugerir(ents):
    """Um primeiro painel a partir do que existe na casa."""
    por = lambda *d: [e['id'] for e in ents if e['dominio'] in d]  # noqa: E731
    cart = []
    cenas = por('scene', 'script')[:6]
    if cenas:
        cart.append(dict(tipo='cenas', titulo='Cenas', ents=cenas, largura=2))
    for eid in por('light')[:4]:
        cart.append(dict(tipo='luz', titulo='', ents=[eid], largura=1))
    for eid in por('climate')[:2]:
        cart.append(dict(tipo='clima', titulo='', ents=[eid], largura=1))
    t = [e['id'] for e in ents if e['dominio'] == 'sensor' and e['classe'] in ('temperature', 'humidity')][:2]
    for eid in t:
        cart.append(dict(tipo='grafico', titulo='', ents=[eid], largura=1))
    w = por('weather')[:1]
    if w:
        cart.append(dict(tipo='tempo', titulo='', ents=w, largura=2))
    sw = por('switch', 'input_boolean', 'fan')[:6]
    if sw:
        cart.append(dict(tipo='entidades', titulo='Interruptores', ents=sw, largura=1))
    for eid in por('media_player')[:1]:
        cart.append(dict(tipo='media', titulo='', ents=[eid], largura=2))
    return cart


class Casa(QObject):
    mudou = Signal()
    mudouEstados = Signal()
    mudouPaineis = Signal()
    _chegou = Signal(object, object)

    def __init__(self):
        super().__init__()
        self._cfg = HA.ler()
        self._todas = []
        self._estados = {}
        self._hist = {}
        self._cams = {}
        self._erro = ''
        self._ocupado = False
        self._a_buscar = False
        self._p = ler_paineis()
        self._chegou.connect(lambda f, r: f(r))
        self._relogio = QTimer(self)
        self._relogio.setInterval(4000)
        self._relogio.timeout.connect(self.atualizar)
        self._lento = QTimer(self)
        self._lento.setInterval(10000)
        self._lento.timeout.connect(self._atualizar_extras)
        if HA.ligado(self._cfg):
            self._relogio.start()
            self._lento.start()
            QTimer.singleShot(0, self.atualizar)

    # ---- propriedades ----------------------------------------------------------------------------
    ligado = Property(bool, lambda s: HA.ligado(s._cfg), notify=mudou)
    nome = Property(str, lambda s: s._cfg.get('nome', 'Casa'), notify=mudou)
    url = Property(str, lambda s: s._cfg.get('url', ''), notify=mudou)
    erro = Property(str, lambda s: s._erro, notify=mudou)
    ocupado = Property(bool, lambda s: s._ocupado, notify=mudou)
    agente = Property(bool, lambda s: bool(s._cfg.get('agente')), notify=mudou)
    mqttHost = Property(str, lambda s: s._cfg.get('mqttHost', ''), notify=mudou)
    mqttUsuario = Property(str, lambda s: s._cfg.get('mqttUsuario', ''), notify=mudou)
    estados = Property('QVariantMap', lambda s: s._estados, notify=mudouEstados)
    historicos = Property('QVariantMap', lambda s: s._hist, notify=mudouEstados)
    cameras = Property('QVariantMap', lambda s: s._cams, notify=mudouEstados)
    todas = Property('QVariantList', lambda s: s._todas, notify=mudouEstados)
    paineis = Property('QVariantList', lambda s: s._p['paineis'], notify=mudouPaineis)
    tipos = Property('QVariantList', lambda s: TIPOS, constant=True)

    def _fundo(self, trabalho, depois):
        def t():
            try:
                r = trabalho()
            except Exception as e:
                r = e
            self._chegou.emit(depois, r)
        threading.Thread(target=t, daemon=True).start()

    # ---- ligar ---------------------------------------------------------------------------------
    @Slot(str, str)
    def conectar(self, url, token):
        self._ocupado = True
        self._erro = ''
        self.mudou.emit()

        def depois(r):
            self._ocupado = False
            ok, msg = r if not isinstance(r, Exception) else (False, str(r))
            self._cfg = HA.ler()
            self._erro = '' if ok else msg
            if ok:
                self._relogio.start()
                self._lento.start()
                self.atualizar()
            self.mudou.emit()
        self._fundo(lambda: HA.conectar(url, token), depois)

    @Slot()
    def desconectar(self):
        cfg = HA.ler()
        for k in ('url', 'token', 'nome', 'versao'):
            cfg.pop(k, None)
        HA.gravar(cfg)
        self._cfg = cfg
        self._todas, self._estados = [], {}
        self._relogio.stop()
        self._lento.stop()
        self.mudou.emit()
        self.mudouEstados.emit()

    # ---- estados -------------------------------------------------------------------------------
    @Slot()
    def atualizar(self):
        if not HA.ligado(self._cfg) or self._a_buscar:
            return
        self._a_buscar = True

        def depois(r):
            self._a_buscar = False
            if isinstance(r, Exception):
                novo = 'O Home Assistant não respondeu (%s).' % getattr(r, 'reason', r)
            else:
                novo = ''
                estados = {e['id']: e for e in r}
                if estados != self._estados:
                    primeira = not self._todas
                    self._todas, self._estados = r, estados
                    self.mudouEstados.emit()
                    if primeira:
                        self._atualizar_extras()
                        if not any(p['cartoes'] for p in self._p['paineis']):
                            self._p['paineis'][0]['cartoes'] = sugerir(r)
                            self._gravar()
            if novo != self._erro:
                self._erro = novo
                self.mudou.emit()
        self._fundo(lambda: HA.entidades(self._cfg), depois)

    def _ids_do_tipo(self, *tipos):
        return {eid for p in self._p['paineis'] for c in p['cartoes'] if c['tipo'] in tipos for eid in c['ents']}

    def _atualizar_extras(self):
        """Graficos (a cada 5 min) e camaras (a cada 10 s), so dos cartoes que existem."""
        graf = [e for e in self._ids_do_tipo('grafico') if time.time() - self._hist.get('_t_' + e, 0) > 300]
        cams = list(self._ids_do_tipo('camera'))
        if not graf and not cams:
            return

        def trabalho():
            h, c = {}, {}
            for eid in graf:
                try:
                    pts = HA.historico(eid, 24, self._cfg)
                    h[eid] = [dict(x=x, y=y) for x, y in pts[-400:]]
                except Exception:
                    pass
            os.makedirs(CAMERAS, mode=0o700, exist_ok=True)
            for eid in cams:
                try:
                    f = HA.imagem_camera(eid, os.path.join(CAMERAS, eid + '.jpg'), self._cfg)
                    c[eid] = 'file://%s?%d' % (f, int(time.time()))
                except Exception:
                    pass
            return h, c

        def depois(r):
            if isinstance(r, Exception):
                return
            h, c = r
            for k, v in h.items():
                self._hist[k] = v
                self._hist['_t_' + k] = time.time()
            self._cams.update(c)
            self.mudouEstados.emit()
        self._fundo(trabalho, depois)

    def _acao(self, f):
        def depois(r):
            QTimer.singleShot(400, self.atualizar)
        self._fundo(f, depois)

    @Slot(str)
    def alternar(self, eid):
        e = self._estados.get(eid)
        if e and e['dominio'] in ('light', 'switch', 'fan', 'input_boolean'):  # resposta imediata no ecra
            e = dict(e, estado='off' if e['estado'] == 'on' else 'on')
            self._estados = dict(self._estados, **{eid: e})
            self.mudouEstados.emit()
        self._acao(lambda: HA.alternar(eid, None, self._cfg))

    @Slot(str, int)
    def brilho(self, eid, pct):
        self._acao(lambda: HA.brilho(eid, pct, self._cfg))

    @Slot(str, float)
    def temperatura(self, eid, graus):
        self._acao(lambda: HA.temperatura(eid, graus, self._cfg))

    @Slot(str, str)
    def valor(self, eid, v):
        self._acao(lambda: HA.valor(eid, v, self._cfg))

    @Slot(str, str)
    def media(self, eid, acao):
        self._acao(lambda: HA.media(eid, acao, self._cfg))

    @Slot(str, bool)
    def estore(self, eid, abrir):
        self._acao(lambda: HA.alternar(eid, abrir, self._cfg))

    @Slot(str)
    def pararEstore(self, eid):
        self._acao(lambda: HA.parar_estore(eid, self._cfg))

    # ---- paineis e cartoes -------------------------------------------------------------------------
    def _gravar(self):
        os.makedirs(os.path.dirname(PAINEIS), exist_ok=True)
        with open(PAINEIS + '.tmp', 'w', encoding='utf-8') as f:
            json.dump(self._p, f, ensure_ascii=False, indent=1)
        os.replace(PAINEIS + '.tmp', PAINEIS)
        self.mudouPaineis.emit()
        self._atualizar_extras()

    @Slot(str)
    def novoPainel(self, nome):
        self._p['paineis'].append({'nome': nome.strip() or 'Painel', 'cartoes': []})
        self._gravar()

    @Slot(int, str)
    def renomearPainel(self, i, nome):
        if 0 <= i < len(self._p['paineis']) and nome.strip():
            self._p['paineis'][i]['nome'] = nome.strip()
            self._gravar()

    @Slot(int)
    def apagarPainel(self, i):
        if len(self._p['paineis']) > 1 and 0 <= i < len(self._p['paineis']):
            self._p['paineis'].pop(i)
            self._gravar()

    @Slot(int, str, str, 'QVariantList', int)
    def adicionarCartao(self, painel, tipo, titulo, ents, largura):
        self._p['paineis'][painel]['cartoes'].append(
            dict(tipo=tipo, titulo=titulo, ents=[str(e) for e in ents], largura=max(1, min(3, largura))))
        self._gravar()

    @Slot(int, int, str, str, 'QVariantList', int)
    def editarCartao(self, painel, i, tipo, titulo, ents, largura):
        c = self._p['paineis'][painel]['cartoes']
        if 0 <= i < len(c):
            c[i] = dict(tipo=tipo, titulo=titulo, ents=[str(e) for e in ents], largura=max(1, min(3, largura)))
            self._gravar()

    @Slot(int, int)
    def apagarCartao(self, painel, i):
        c = self._p['paineis'][painel]['cartoes']
        if 0 <= i < len(c):
            c.pop(i)
            self._gravar()

    @Slot(int, int, int)
    def moverCartao(self, painel, i, para):
        c = self._p['paineis'][painel]['cartoes']
        j = i + para
        if 0 <= i < len(c) and 0 <= j < len(c):
            c[i], c[j] = c[j], c[i]
            self._gravar()

    @Slot(int)
    def sugerirPainel(self, painel):
        self._p['paineis'][painel]['cartoes'] = sugerir(self._todas)
        self._gravar()

    # ---- este computador no Home Assistant (MQTT) ----------------------------------------------
    @Slot(bool, str, str, str)
    def definirAgente(self, ligar, host, usuario, senha):
        cfg = HA.ler()
        cfg['agente'] = bool(ligar)
        if ligar:
            cfg['mqttHost'] = host.strip() or cfg.get('mqttHost', '')
            cfg['mqttUsuario'] = usuario.strip()
            if senha:
                cfg['mqttSenha'] = senha
        HA.gravar(cfg)
        self._cfg = cfg
        acao = 'enable' if ligar else 'disable'
        self._fundo(lambda: (correr(['systemctl', '--user', acao, '--now', 'carinaeos-casa-agente.service']),
                             ligar and correr(['systemctl', '--user', 'restart', 'carinaeos-casa-agente.service'])),
                    lambda r: None)
        self.mudou.emit()

    @Slot()
    def abrirNoNavegador(self):
        correr(['xdg-open', self._cfg.get('url', 'http://homeassistant.local:8123')], espera=False)


if __name__ == '__main__':
    sys.exit(iniciar('carinaeos-casa', 'Casa', 'carinaeos-casa', os.path.join(AQUI, 'Main.qml'), {'casa': Casa()}))
