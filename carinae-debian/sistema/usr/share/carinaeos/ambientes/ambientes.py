#!/usr/bin/python3
# CarinaeOS - trocar de ambiente de trabalho: KDE Plasma, GNOME ou XFCE.
# Escolher um ambiente instala-o (com a senha do sistema e o andamento a vista) ja com o
# visual do CarinaeOS (Dock sempre visivel, tema escuro, papeis de parede), e depois
# basta terminar a sessao: a tela de entrada abre no ambiente escolhido.
import os
import re
import shlex
import subprocess
import sys
import threading

sys.path.insert(0, '/usr/share/carinaeos/comum')
from base import correr, iniciar  # noqa: E402

from PySide6.QtCore import Property, QObject, Signal, Slot  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
AO_VIVO = 'boot=live' in open('/proc/cmdline').read()

AMBIENTES = [
    dict(id='plasma', nome='CarinaeOS (estilo Mac)', icone='carinaeos-estrela', tamanho='já instalado',
         desc='O original: barra em cima, Dock com lupa em baixo, Launchpad na estrela, Flip 3D e Supernova completo.',
         sessoes=['/usr/share/wayland-sessions/plasma.desktop', '/usr/share/xsessions/plasmax11.desktop'],
         sessao='plasma.desktop', pacotes=[], visual='org.carinaeos.desktop'),
    dict(id='windows', nome='Estilo Windows 11', icone='start-here', tamanho='já instalado',
         desc='Barra de tarefas em baixo com os ícones ao centro e o menu Iniciar com a estrela do CarinaeOS, '
              'pesquisa e a mesma barra de cima do estilo Mac (menu estrela, menus do aplicativo, bandeja e relógio).',
         sessoes=['/usr/share/wayland-sessions/plasma.desktop', '/usr/share/xsessions/plasmax11.desktop'],
         sessao='plasma.desktop', pacotes=[], visual='org.carinaeos.windows'),
    dict(id='gnome', nome='GNOME', icone='view-app-grid', tamanho='cerca de 900 MB',
         desc='Simples e elegante, com a Dock do CarinaeOS sempre visível em baixo (Dash to Dock), '
              'tema escuro e os papéis de parede do CarinaeOS.',
         sessoes=['/usr/share/wayland-sessions/gnome.desktop', '/usr/share/xsessions/gnome.desktop'],
         sessao='gnome.desktop',
         pacotes=['gnome-core', 'gnome-shell-extension-dashtodock', 'gnome-shell-extension-appindicator',
                  'gnome-shell-extension-blur-my-shell', 'gnome-tweaks', 'python3-nautilus', 'zenity']),
    dict(id='xfce', nome='XFCE', icone='speedometer', tamanho='cerca de 350 MB',
         desc='Leve e rápido, ótimo para computadores mais antigos. Vem com uma Dock (Plank) e os papéis de parede do CarinaeOS.',
         sessoes=['/usr/share/xsessions/xfce.desktop'],
         sessao='xfce.desktop',
         pacotes=['task-xfce-desktop', 'plank', 'xfce4-whiskermenu-plugin', 'zenity', 'numlockx']),
]


PENDENTE = os.path.expanduser('~/.config/carinaeos/plasma-visual-pendente')


def atual():
    d = (os.environ.get('XDG_CURRENT_DESKTOP', '') + os.environ.get('DESKTOP_SESSION', '')).lower()
    if 'gnome' in d:
        return 'gnome'
    if 'xfce' in d:
        return 'xfce'
    _, v = correr(['kreadconfig6', '--group', 'KDE', '--key', 'LookAndFeelPackage'])
    return 'windows' if 'windows' in v else 'plasma'


def instalado(a):
    return any(os.path.exists(s) for s in a['sessoes'])


class Ambientes(QObject):
    mudou = Signal()
    _linha = Signal(str, float)
    _fim = Signal(str, bool, str)

    def __init__(self):
        super().__init__()
        self._a_instalar = ''
        self._progresso = -1.0
        self._etapa = ''
        self._mensagem = ''
        self._proc = None
        self._linha.connect(self._atualizar)
        self._fim.connect(self._terminou)

    def _lista(self):
        return [dict({k: v for k, v in a.items() if k != 'pacotes'}, instalado=instalado(a), atual=a['id'] == atual())
                for a in AMBIENTES]

    ambientes = Property('QVariantList', _lista, notify=mudou)
    aInstalar = Property(str, lambda s: s._a_instalar, notify=mudou)
    progresso = Property(float, lambda s: s._progresso, notify=mudou)
    etapa = Property(str, lambda s: s._etapa, notify=mudou)
    mensagem = Property(str, lambda s: s._mensagem, notify=mudou)
    aoVivo = Property(bool, lambda s: AO_VIVO, constant=True)

    @Slot(str)
    def instalar(self, ident):
        a = next((x for x in AMBIENTES if x['id'] == ident), None)
        if not a or self._a_instalar or not a['pacotes']:
            return
        pac = ' '.join(shlex.quote(p) for p in a['pacotes'])
        # manter o SDDM (a tela de entrada do CarinaeOS) mesmo que o GNOME traga o GDM
        interno = ('echo "shared/default-x-display-manager select sddm" | debconf-set-selections; '
                   'echo "gdm3 shared/default-x-display-manager select sddm" | debconf-set-selections; '
                   'dpkg --configure -a; DEBIAN_FRONTEND=noninteractive apt-get -f install -y; '
                   'apt-get update -q -o APT::Status-Fd=1 && '
                   'DEBIAN_FRONTEND=noninteractive apt-get install -y -o APT::Status-Fd=1 %s && '
                   'echo /usr/sbin/sddm > /etc/X11/default-display-manager && '
                   '(systemctl disable gdm3 2>/dev/null; systemctl enable sddm 2>/dev/null; %s'
                   'glib-compile-schemas /usr/share/glib-2.0/schemas; true)'
                   % (pac, '/usr/lib/carinaeos/gnome-extras; ' if ident == 'gnome' else ''))
        self._a_instalar = ident
        self._progresso = 0.0
        self._etapa = 'A pedir autorização…'
        self._mensagem = ''
        self.mudou.emit()

        def t():
            try:
                p = subprocess.Popen(['pkexec', 'bash', '-c', interno], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                     start_new_session=True, env=dict(os.environ, LC_ALL='C.UTF-8'))
                self._proc = p
                ultimas = []
                for linha in iter(p.stdout.readline, b''):
                    l = linha.decode('utf-8', 'ignore').strip()
                    m = re.match(r'^(pm|dl)status:[^:]*:([\d.]+):(.*)', l)
                    if m:
                        v = float(m.group(2)) / 100
                        self._linha.emit(('A baixar: ' if m.group(1) == 'dl' else 'A instalar: ') + m.group(3)[:80],
                                         v * 0.45 if m.group(1) == 'dl' else 0.45 + v * 0.55)
                    elif l:
                        ultimas = (ultimas + [l])[-6:]
                p.wait()
                self._fim.emit(ident, p.returncode == 0, '\n'.join(ultimas))
            except Exception as e:
                self._fim.emit(ident, False, str(e))
        threading.Thread(target=t, daemon=True).start()

    def _atualizar(self, etapa, prog):
        self._etapa = etapa
        self._progresso = prog
        self.mudou.emit()

    def _terminou(self, ident, ok, saida):
        nome = next(a['nome'] for a in AMBIENTES if a['id'] == ident)
        self._a_instalar = ''
        self._progresso = -1.0
        self._etapa = ''
        if ok:
            self._mensagem = ('Pronto! O %s está instalado. Carregue em “Usar este” e termine a sessão: '
                              'a tela de entrada abre no %s.' % (nome, nome))
        else:
            self._mensagem = 'A instalação não terminou. %s' % (saida.splitlines()[-1] if saida else 'Tente outra vez.')
        self.mudou.emit()

    @Slot()
    def cancelar(self):
        if self._proc and self._proc.poll() is None:
            try:
                os.killpg(self._proc.pid, 15)
            except OSError:
                pass

    @Slot(str)
    def usar(self, ident):
        """Escolhe o ambiente para a proxima entrada e termina a sessao."""
        a = next((x for x in AMBIENTES if x['id'] == ident), None)
        if not a or not instalado(a):
            return
        if a.get('visual'):
            if atual() in ('plasma', 'windows'):
                # ja estamos no Plasma: muda logo, sem terminar a sessao (em segundo plano: pode demorar)
                esq, dir_ = ('M', 'IAX') if ident == 'windows' else ('XIA', '')
                subprocess.Popen(['bash', '-c',
                                  'plasma-apply-lookandfeel -a %s --resetLayout; '
                                  'kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft "%s"; '
                                  'kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight "%s"; '
                                  'qdbus6 org.kde.KWin /KWin reconfigure' % (a['visual'], esq, dir_)],
                                 start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                self._mensagem = 'A mudar para o %s… (a barra muda em alguns segundos)' % a['nome']
                self.mudou.emit()
                return
            os.makedirs(os.path.dirname(PENDENTE), exist_ok=True)
            with open(PENDENTE, 'w') as f:
                f.write(a['visual'])
        sessao = next((s for s in a['sessoes'] if os.path.exists(s)), a['sessoes'][0])
        correr(['pkexec', 'bash', '-c',
                'mkdir -p /var/lib/sddm && f=/var/lib/sddm/state.conf; touch $f; '
                'grep -q "^\\[Last\\]" $f || printf "[Last]\\n" >> $f; '
                'sed -i "/^Session=/d" $f; sed -i "/^\\[Last\\]/a Session=%s" $f; chown sddm:sddm $f 2>/dev/null; true' % sessao])
        self._mensagem = 'A terminar a sessão para entrar no %s…' % a['nome']
        self.mudou.emit()
        d = atual()
        if d == 'gnome':
            correr(['gnome-session-quit', '--logout', '--no-prompt'], espera=False)
        elif d == 'xfce':
            correr(['xfce4-session-logout', '--logout', '--fast'], espera=False)
        else:
            correr(['qdbus6', 'org.kde.Shutdown', '/Shutdown', 'org.kde.Shutdown.logout'], espera=False)


if __name__ == '__main__':
    sys.exit(iniciar('carinaeos-ambientes', 'Ambiente de trabalho', 'preferences-desktop',
                     os.path.join(AQUI, 'Main.qml'), {'amb': Ambientes()}))
