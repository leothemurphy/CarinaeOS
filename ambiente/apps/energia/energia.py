#!/usr/bin/env python3
# CarinaeOS — Energia: quando desligar o ecrã, bloquear, suspender e o que faz o botão de ligar.
# As escolhas ficam em ~/.config/carinaeos/energia.json; o carinae-energia (o serviço) aplica-as na hora.
import json
import os
import sys

CFG = os.path.join(os.path.expanduser('~'), '.config', 'carinaeos', 'energia.json')
PADRAO = dict(desligarEcra=10, bloquear=True, bloquearAoSuspender=True, suspender=0, botao='perguntar')


def main():
    sys.path.insert(0, os.environ.get('CARINAE_COMUM') or next(
        (d for d in ('/usr/local/share/carinaeos/comum', '/usr/share/carinaeos/comum') if os.path.isdir(d)),
        '/usr/share/carinaeos/comum'))
    from base import iniciar
    from PySide6.QtCore import QObject, Property, Signal, Slot

    class Energia(QObject):
        mudou = Signal()

        def __init__(self):
            super().__init__()
            try:
                self._v = dict(PADRAO, **json.load(open(CFG, encoding='utf-8')))
            except (OSError, ValueError):
                self._v = dict(PADRAO)

        @Property('QVariantMap', notify=mudou)
        def valores(self):
            return self._v

        @Slot(str, 'QVariant')
        def mudar(self, chave, valor):
            if chave in ('desligarEcra', 'suspender'):
                valor = int(valor)
            self._v[chave] = valor
            os.makedirs(os.path.dirname(CFG), exist_ok=True)
            with open(CFG + '.tmp', 'w', encoding='utf-8') as f:
                json.dump(self._v, f, indent=1)
            os.replace(CFG + '.tmp', CFG)
            self.mudou.emit()

    return iniciar('carinae-energia-ajustes', 'Carinae Energia', 'preferences-system-power',
                   os.path.join(os.path.dirname(os.path.abspath(__file__)), 'Main.qml'), {'energia': Energia})


if __name__ == '__main__':
    sys.exit(main())
