#!/usr/bin/python3
# CarinaeOS - Casa: controlar o Home Assistant (luzes, cenas, interruptores, clima, sensores)
# e pôr este computador no Home Assistant (sensores e botões, por MQTT).
import os
import sys
import threading

sys.path.insert(0, '/usr/share/carinaeos/comum')
from base import correr, iniciar  # noqa: E402
import casa_ha as HA  # noqa: E402

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))


class Casa(QObject):
    mudou = Signal()
    _chegou = Signal(object)

    def __init__(self):
        super().__init__()
        self._cfg = HA.ler()
        self._ents = []
        self._erro = ''
        self._ocupado = False
        self._chegou.connect(self._receber)
        self._relogio = QTimer(self)
        self._relogio.setInterval(5000)
        self._relogio.timeout.connect(self.atualizar)
        if HA.ligado(self._cfg):
            self._relogio.start()
            QTimer.singleShot(0, self.atualizar)

    # ---- propriedades --------------------------------------------------------------------------
    ligado = Property(bool, lambda s: HA.ligado(s._cfg), notify=mudou)
    nome = Property(str, lambda s: s._cfg.get('nome', 'Casa'), notify=mudou)
    url = Property(str, lambda s: s._cfg.get('url', ''), notify=mudou)
    erro = Property(str, lambda s: s._erro, notify=mudou)
    ocupado = Property(bool, lambda s: s._ocupado, notify=mudou)
    entidades = Property('QVariantList', lambda s: s._ents, notify=mudou)
    agente = Property(bool, lambda s: bool(s._cfg.get('agente')), notify=mudou)
    mqttHost = Property(str, lambda s: s._cfg.get('mqttHost', ''), notify=mudou)
    mqttUsuario = Property(str, lambda s: s._cfg.get('mqttUsuario', ''), notify=mudou)

    def _fundo(self, f):
        def t():
            try:
                r = f()
            except Exception as e:
                r = e
            self._chegou.emit(r)
        threading.Thread(target=t, daemon=True).start()

    def _receber(self, r):
        self._ocupado = False
        if isinstance(r, Exception):
            self._erro = 'O Home Assistant não respondeu (%s).' % getattr(r, 'reason', r)
        elif isinstance(r, list):
            self._ents = r
            self._erro = ''
        elif isinstance(r, tuple):            # resposta de conectar
            ok, msg = r
            self._cfg = HA.ler()
            self._erro = '' if ok else msg
            if ok:
                self._relogio.start()
                self.atualizar()
        self.mudou.emit()

    # ---- acoes -------------------------------------------------------------------------------
    @Slot(str, str)
    def conectar(self, url, token):
        self._ocupado = True
        self._erro = ''
        self.mudou.emit()
        self._fundo(lambda: HA.conectar(url, token))

    @Slot()
    def desconectar(self):
        cfg = HA.ler()
        for k in ('url', 'token', 'nome', 'versao'):
            cfg.pop(k, None)
        HA.gravar(cfg)
        self._cfg = cfg
        self._ents = []
        self._relogio.stop()
        self.mudou.emit()

    @Slot()
    def atualizar(self):
        if HA.ligado(self._cfg):
            self._fundo(lambda: HA.entidades(self._cfg))

    def _e_depois(self, f):
        def t():
            f()
            return HA.entidades(self._cfg)
        self._fundo(t)

    @Slot(str)
    def alternar(self, eid):
        self._e_depois(lambda: HA.alternar(eid, None, self._cfg))

    @Slot(str, bool)
    def definir(self, eid, ligar):
        self._e_depois(lambda: HA.alternar(eid, ligar, self._cfg))

    @Slot(str, int)
    def brilho(self, eid, pct):
        self._e_depois(lambda: HA.brilho(eid, pct, self._cfg))

    @Slot(str, float)
    def temperatura(self, eid, graus):
        self._e_depois(lambda: HA.temperatura(eid, graus, self._cfg))

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
        correr(['systemctl', '--user', 'enable' if ligar else 'disable', '--now', 'carinaeos-casa-agente.service'])
        if ligar:
            correr(['systemctl', '--user', 'restart', 'carinaeos-casa-agente.service'])
        self.mudou.emit()

    @Slot()
    def abrirNoNavegador(self):
        correr(['xdg-open', self._cfg.get('url', 'http://homeassistant.local:8123')], espera=False)


if __name__ == '__main__':
    sys.exit(iniciar('carinaeos-casa', 'Casa', 'carinaeos-casa', os.path.join(AQUI, 'Main.qml'), {'casa': Casa()}))
