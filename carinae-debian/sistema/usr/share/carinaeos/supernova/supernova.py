#!/usr/bin/python3
# CarinaeOS - Supernova: personalizar o sistema com "mods", cada um com varios MODELOS
# (ao estilo do Windhawk), perfis prontos, a Dock e a troca de ambiente de trabalho.
# Funciona no Plasma (completo), no GNOME e no XFCE (o que existe em cada um).
import json
import os
import sys
import threading

sys.path.insert(0, '/usr/share/carinaeos/comum')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base import correr, iniciar  # noqa: E402
import mods as M  # noqa: E402

from PySide6.QtCore import Property, QObject, Signal, Slot  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
DOCK_JSON = os.path.expanduser('~/.config/carinaeos-dock.json')


def dock_ler(chave, padrao):
    try:
        with open(DOCK_JSON, encoding='utf-8') as f:
            return json.load(f).get(chave, padrao)
    except (OSError, ValueError):
        return padrao


class Supernova(QObject):
    mudou = Signal()
    _feito = Signal()

    def __init__(self):
        super().__init__()
        self._mods = M.lista()
        self._ocupado = ''
        self._feito.connect(self._recarregar)

    def _recarregar(self):
        self._mods = M.lista()
        self._ocupado = ''
        self.mudou.emit()

    def _em_fundo(self, rotulo, f):
        self._ocupado = rotulo
        self.mudou.emit()

        def t():
            try:
                f()
            finally:
                self._feito.emit()
        threading.Thread(target=t, daemon=True).start()

    mods = Property('QVariantList', lambda s: s._mods, notify=mudou)
    perfis = Property('QVariantList', lambda s: [{k: v for k, v in p.items() if k != 'escolhas'} for p in M.PERFIS], constant=True)
    ambiente = Property(str, lambda s: M.AMB, constant=True)
    nomeAmbiente = Property(str, lambda s: M.NOME_AMB[M.AMB], constant=True)
    ocupado = Property(str, lambda s: s._ocupado, notify=mudou)
    zoom = Property(float, lambda s: float(dock_ler('zoom', 1.9)), notify=mudou)
    tamanho = Property(int, lambda s: int(dock_ler('iconSize', 48)), notify=mudou)
    personalizados = Property(int, lambda s: sum(1 for m in s._mods if m['escolhido'] != m['padrao']), notify=mudou)

    @Slot(str, str)
    def escolher(self, ident, modelo):
        self._em_fundo('A aplicar…', lambda: M.escolher(ident, modelo))

    @Slot(str)
    def aplicarPerfil(self, ident):
        self._em_fundo('A aplicar o perfil…', lambda: M.aplicar_perfil(ident))

    @Slot()
    def restaurar(self):
        self._em_fundo('A restaurar…', M.restaurar)

    @Slot(float)
    def mudarZoom(self, z):
        M.dock(zoom=round(z, 2))
        self.mudou.emit()

    @Slot(int)
    def mudarTamanho(self, t):
        M.dock(iconSize=int(t))
        self.mudou.emit()

    @Slot()
    def experimentarTroca(self):
        correr(['qdbus6', 'org.kde.kglobalaccel', '/component/kwin',
                'org.kde.kglobalaccel.Component.invokeShortcut', 'Walk Through Windows'], espera=False)

    @Slot()
    def abrirAmbientes(self):
        correr(['carinaeos-ambientes'], espera=False)


if __name__ == '__main__':
    s = Supernova()
    sys.exit(iniciar('carinaeos-supernova', 'Supernova', 'carinaeos-supernova',
                     os.path.join(AQUI, 'Main.qml'), {'supernova': s}))
