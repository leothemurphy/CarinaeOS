#!/usr/bin/python3
# CarinaeOS - Configuracao inicial (como no Fedora): aparece no primeiro arranque depois de instalar:
# boas-vindas, Wi-Fi, privacidade, aparencia, contas online e "Comecar a usar o CarinaeOS".
import os
import sys

sys.path.insert(0, '/usr/share/carinaeos/comum')
from base import correr, iniciar  # noqa: E402

from PySide6.QtCore import Property, QObject, Slot  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
FEITO = os.path.join(os.environ.get('XDG_CONFIG_HOME', os.path.expanduser('~/.config')), 'carinaeos', 'boas-vindas-vista')
PREFS = os.path.join(os.path.dirname(FEITO), 'privacidade.json')
sys.path.insert(0, '/usr/share/carinaeos/configuracoes')
from configuracoes import Config  # noqa: E402


class BoasVindas(QObject):
    @Slot(str)
    def abrir(self, cmd):
        correr(['bash', '-lc', cmd], espera=False)

    @Slot()
    def concluir(self):
        os.makedirs(os.path.dirname(FEITO), exist_ok=True)
        open(FEITO, 'w').close()

    @Slot(bool, bool)
    def privacidade(self, localizacao, relatorios):
        import json
        os.makedirs(os.path.dirname(PREFS), exist_ok=True)
        with open(PREFS, 'w') as f:
            json.dump({'localizacao': localizacao, 'relatorios': relatorios}, f)
        # relatorios de falhas: sem a janela de envio quando desligado
        correr(['kwriteconfig6', '--file', 'drkonqirc', '--group', 'General', '--key', 'Unattended',
                'false' if relatorios else 'true'], espera=False)

    nome = Property(str, lambda s: os.environ.get('USER', ''), constant=True)


if __name__ == '__main__':
    if '--se-primeira-vez' in sys.argv:
        if os.path.exists(FEITO) or 'boot=live' in open('/proc/cmdline').read():
            sys.exit(0)
    sys.argv = [a for a in sys.argv if not a.startswith('--')]
    sys.exit(iniciar('carinaeos-boasvindas', 'Configuração inicial', 'carinaeos',
                     os.path.join(AQUI, 'Main.qml'), {'bv': BoasVindas(), 'ajustes': Config('wifi')}))
