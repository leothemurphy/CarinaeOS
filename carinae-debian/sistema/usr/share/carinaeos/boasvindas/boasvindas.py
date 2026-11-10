#!/usr/bin/python3
# CarinaeOS - Boas-vindas: aparece no primeiro arranque depois de instalar e mostra tudo o que o
# sistema tem, com um botão para experimentar cada coisa. Pode abrir-se de novo pelo Launchpad.
import os
import sys

sys.path.insert(0, '/usr/share/carinaeos/comum')
from base import correr, iniciar  # noqa: E402

from PySide6.QtCore import Property, QObject, Slot  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
FEITO = os.path.join(os.environ.get('XDG_CONFIG_HOME', os.path.expanduser('~/.config')), 'carinaeos', 'boas-vindas-vista')
AMB = 'gnome' if 'gnome' in os.environ.get('XDG_CURRENT_DESKTOP', '').lower() else \
      'xfce' if 'xfce' in os.environ.get('XDG_CURRENT_DESKTOP', '').lower() else 'plasma'


class BoasVindas(QObject):
    @Slot(str)
    def abrir(self, cmd):
        correr(['bash', '-lc', cmd], espera=False)

    @Slot()
    def concluir(self):
        os.makedirs(os.path.dirname(FEITO), exist_ok=True)
        open(FEITO, 'w').close()

    nome = Property(str, lambda s: os.environ.get('USER', ''), constant=True)
    ambiente = Property(str, lambda s: AMB, constant=True)


if __name__ == '__main__':
    if '--se-primeira-vez' in sys.argv:
        if os.path.exists(FEITO) or 'boot=live' in open('/proc/cmdline').read():
            sys.exit(0)
    sys.argv = [a for a in sys.argv if not a.startswith('--')]
    sys.exit(iniciar('carinaeos-boasvindas', 'Bem-vindo ao CarinaeOS', 'carinaeos',
                     os.path.join(AQUI, 'Main.qml'), {'bv': BoasVindas()}))
