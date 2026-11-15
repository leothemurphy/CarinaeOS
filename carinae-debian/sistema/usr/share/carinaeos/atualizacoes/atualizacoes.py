#!/usr/bin/python3
# CarinaeOS - Atualizações: o que há para atualizar (sistema e Flatpak), atualizar com um ponto de
# restauro antes, e voltar atrás a um ponto de restauro (Timeshift). A parte de administrador é o
# /usr/lib/carinaeos/atualizar, corrido com pkexec (a senha fica válida uns minutos).
#   atualizacoes.py [verificar]   sem argumento abre a janela; "verificar" só avisa (temporizador)
import datetime
import json
import os
import subprocess
import sys

sys.path.insert(0, '/usr/share/carinaeos/comum')

AQUI = os.path.dirname(os.path.abspath(__file__))
AJUDANTE = '/usr/lib/carinaeos/atualizar'
PONTOS = '/timeshift/snapshots'
ESTADO = os.path.join(os.environ.get('XDG_CACHE_HOME', os.path.expanduser('~/.cache')), 'carinaeos', 'atualizacoes.json')


def cmd(args, timeout=60):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return r.stdout
    except Exception:
        return ''


def pendentes():
    """[{nome, versao, origem}] — sistema (apt) e Flatpak. Não precisa de administrador:
    a lista do apt é atualizada todos os dias pelo próprio Debian (apt-daily)."""
    r = []
    for l in cmd(['apt', 'list', '--upgradable'], 60).splitlines():
        if '/' in l and '[' in l:
            nome = l.split('/')[0]
            partes = l.split()
            r.append(dict(nome=nome, versao=partes[1] if len(partes) > 1 else '', origem='Sistema'))
    if os.path.exists('/usr/bin/flatpak'):
        for l in cmd(['flatpak', 'remote-ls', '--updates', '--columns=name,application,version'], 60).splitlines():
            p = l.split('\t')
            if p and p[0].strip():
                r.append(dict(nome=p[0].strip(), versao=(p[2].strip() if len(p) > 2 else ''), origem='Flatpak'))
    return r


def pontos():
    """Pontos de restauro (mais recentes primeiro), lidos dos info.json do Timeshift."""
    r = []
    try:
        nomes = sorted(os.listdir(PONTOS), reverse=True)
    except OSError:
        return r
    for n in nomes:
        try:
            with open(os.path.join(PONTOS, n, 'info.json')) as f:
                i = json.load(f)
        except (OSError, ValueError):
            continue
        try:
            quando = datetime.datetime.strptime(n[:19], '%Y-%m-%d_%H-%M-%S').strftime('%d/%m/%Y às %H:%M')
        except ValueError:
            quando = n
        r.append(dict(nome=n, quando=quando, comentario=(i.get('comments') or '').replace('CarinaeOS:', '').strip()
                      or 'Ponto de restauro', tamanho=i.get('snapshot-size', '')))
    return r


def verificar():
    """Aviso (uma vez por dia e só se houver novidades), com o botão para abrir o app."""
    p = pendentes()
    try:
        with open(ESTADO) as f:
            e = json.load(f)
    except (OSError, ValueError):
        e = {}
    hoje = datetime.date.today().isoformat()
    if not p or (e.get('dia') == hoje and e.get('n') == len(p)):
        return 0
    os.makedirs(os.path.dirname(ESTADO), exist_ok=True)
    with open(ESTADO, 'w') as f:
        json.dump({'dia': hoje, 'n': len(p)}, f)
    n = len(p)
    r = cmd(['notify-send', '-a', 'Atualizações', '-i', 'system-software-update', '--wait',
             '-A', 'abrir=Ver e atualizar', 'Há %d atualizaç%s' % (n, 'ão' if n == 1 else 'ões'),
             'Antes de atualizar, o CarinaeOS cria um ponto de restauro para poder voltar atrás.'], 3600)
    if r.strip() == 'abrir':
        subprocess.Popen(['carinaeos-atualizacoes'], start_new_session=True)
    return 0


def janela():
    from base import iniciar
    from PySide6.QtCore import Property, QObject, QProcess, Signal, Slot

    class Atualizacoes(QObject):
        mudou = Signal()

        def __init__(self):
            super().__init__()
            self._lista, self._pontos = [], pontos()
            self._lendo, self._ocupado = True, False
            self._passo, self._log, self._erro, self._feito, self._reiniciar = '', [], '', False, False
            self._p = None
            self.ler()

        lista = Property('QVariantList', lambda s: s._lista, notify=mudou)
        pontosRestauro = Property('QVariantList', lambda s: s._pontos, notify=mudou)
        lendo = Property(bool, lambda s: s._lendo, notify=mudou)
        ocupado = Property(bool, lambda s: s._ocupado, notify=mudou)
        passo = Property(str, lambda s: s._passo, notify=mudou)
        registo = Property(str, lambda s: '\n'.join(s._log[-200:]), notify=mudou)
        erro = Property(str, lambda s: s._erro, notify=mudou)
        feito = Property(bool, lambda s: s._feito, notify=mudou)
        reiniciar = Property(bool, lambda s: s._reiniciar, notify=mudou)
        temTimeshift = Property(bool, lambda s: os.path.exists('/usr/bin/timeshift'), constant=True)

        @Slot()
        def ler(self):
            self._lendo = True
            self.mudou.emit()
            p = QProcess(self)
            p.finished.connect(lambda *_: self._lido(p))
            p.start(sys.executable, [os.path.abspath(__file__), 'lista'])

        def _lido(self, p):
            try:
                self._lista = json.loads(bytes(p.readAllStandardOutput()).decode() or '[]')
            except ValueError:
                self._lista = []
            self._pontos = pontos()
            self._lendo = False
            self.mudou.emit()

        def _correr(self, args):
            if self._ocupado:
                return
            self._ocupado, self._erro, self._feito, self._log, self._passo = True, '', False, [], 'Pedindo autorização…'
            self.mudou.emit()
            p = QProcess(self)
            p.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
            p.readyReadStandardOutput.connect(lambda: self._linhas(p))
            p.finished.connect(lambda codigo, *_: self._fim(codigo))
            p.start('pkexec', [AJUDANTE] + args)
            self._p = p

        def _linhas(self, p):
            for l in bytes(p.readAllStandardOutput()).decode(errors='replace').splitlines():
                l = l.strip()
                if not l:
                    continue
                if l.startswith('@passo '):
                    self._passo = l[7:]
                elif l.startswith('@erro '):
                    self._erro = l[6:]
                elif l == '@feito':
                    self._feito = True
                elif l == '@reiniciar':
                    self._reiniciar = True
                else:
                    self._log.append(l)
            self.mudou.emit()

        def _fim(self, codigo):
            self._ocupado = False
            if codigo in (126, 127) and not self._erro:
                self._erro = 'Cancelado: é preciso a senha de administrador.'
            elif codigo != 0 and not self._erro:
                self._erro = 'Não funcionou (código %d). Veja os detalhes.' % codigo
            self._passo = ''
            self.mudou.emit()
            self.ler()

        @Slot()
        def atualizar(self):
            self._correr(['sistema'])

        @Slot()
        def criarPonto(self):
            self._correr(['ponto', 'Criado em ' + datetime.datetime.now().strftime('%d/%m/%Y %H:%M')])

        @Slot(str)
        def restaurar(self, nome):
            self._correr(['restaurar', nome])

        @Slot(str)
        def apagar(self, nome):
            self._correr(['apagar', nome])

        @Slot()
        def reiniciarAgora(self):
            subprocess.Popen(['qdbus6', 'org.kde.LogoutPrompt', '/LogoutPrompt', 'promptReboot'], start_new_session=True)

    return iniciar('carinaeos-atualizacoes', 'Atualizações', 'system-software-update',
                   os.path.join(AQUI, 'Main.qml'), {'atu': Atualizacoes})


if __name__ == '__main__':
    a = sys.argv[1:]
    if a and a[0] == 'verificar':
        sys.exit(verificar())
    if a and a[0] == 'lista':
        print(json.dumps(pendentes()))
        sys.exit(0)
    sys.exit(janela())
