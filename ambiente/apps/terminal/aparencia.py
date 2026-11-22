#!/usr/bin/env python3
# CarinaeOS — Terminal Carinae: aparência (tema de cores, fonte, tamanho, transparência, cursor)
# O Terminal Carinae (carinae-terminal) lê ~/.config/carinaeos/terminal.json e muda na hora quando se aplica.
#   carinae-terminal-aparencia            abre a janela
#   carinae-terminal-aparencia --aplicar  escreve o terminal.json (com as cores do tema) a partir do que está guardado
import json
import os
import re
import sys

CASA = os.path.expanduser('~')
DADOS = os.environ.get('XDG_DATA_HOME') or os.path.join(CASA, '.local/share')
CONF = os.environ.get('XDG_CONFIG_HOME') or os.path.join(CASA, '.config')
GUARDADO = os.path.join(CONF, 'carinaeos', 'terminal.json')
PERFIL = 'Terminal Carinae'

# fundo, texto, 8 cores normais, 8 cores fortes  (preto vermelho verde amarelo azul magenta ciano branco)
TEMAS = {
    'noite': {'nome': 'Noite', 'fundo': '#14111f', 'texto': '#e8e2f4', 'cursor': '#ffb46e',
              'cores': ['#2a2438', '#ff6f91', '#7ee0a6', '#ffb46e', '#7aa7ff', '#c792ea', '#5fd7d0', '#d8d0e8'],
              'fortes': ['#5a5270', '#ff8fab', '#a3f0c2', '#ffd09e', '#a3c2ff', '#ddb3f5', '#8fe8e2', '#ffffff']},
    'nebulosa': {'nome': 'Nebulosa', 'fundo': '#1a0f2e', 'texto': '#f0e6ff', 'cursor': '#ff6f91',
                 'cores': ['#2e1f4a', '#ff5c8a', '#9be7a0', '#ffd479', '#8ea8ff', '#e08aff', '#7ce8f0', '#e3d7f5'],
                 'fortes': ['#5e4a85', '#ff85a8', '#bdf2c0', '#ffe3a3', '#b3c4ff', '#ecb0ff', '#a8f2f7', '#ffffff']},
    'aurora': {'nome': 'Aurora', 'fundo': '#0b1a1f', 'texto': '#d9f7f2', 'cursor': '#5ef2b0',
               'cores': ['#173038', '#ff7a8a', '#5ef2b0', '#f2d06b', '#5fb4ff', '#c58cff', '#43e0e0', '#cde9e4'],
               'fortes': ['#3d5c66', '#ffa0ab', '#94f7cb', '#f7e09a', '#8fcbff', '#d9b3ff', '#7aeded', '#ffffff']},
    'orbita': {'nome': 'Órbita', 'fundo': '#0d1324', 'texto': '#dbe6ff', 'cursor': '#37d3c6',
               'cores': ['#1d2640', '#ff6b81', '#5ce0a0', '#ffc66d', '#4f8dff', '#7a5cff', '#37d3c6', '#c9d6f5'],
               'fortes': ['#46557a', '#ff94a5', '#8eedc0', '#ffd99e', '#82aeff', '#a28cff', '#72e3da', '#ffffff']},
    'supernova': {'nome': 'Supernova', 'fundo': '#1c1210', 'texto': '#ffe9d6', 'cursor': '#ffb347',
                  'cores': ['#33231f', '#ff5e5b', '#a6e07a', '#ffb347', '#7ab0ff', '#ff7fbf', '#5fd0c0', '#f2ddd0'],
                  'fortes': ['#6b5048', '#ff8a87', '#c4eda3', '#ffcd80', '#a6caff', '#ffa8d4', '#8ee0d4', '#ffffff']},
    'claro': {'nome': 'Claro', 'fundo': '#f8f6fb', 'texto': '#2a2438', 'cursor': '#d4572a',
              'cores': ['#2a2438', '#d1345b', '#1f9d63', '#b8730f', '#2f63d6', '#8a3fc7', '#13889a', '#d8d2e2'],
              'fortes': ['#6b6280', '#e85d7f', '#2fbf7c', '#d18f2b', '#5584e8', '#a865dd', '#26a5b8', '#ffffff']},
}
PADRAO = {'tema': 'noite', 'fonte': '', 'tamanho': 11, 'opacidade': 92, 'cursor': 'barra', 'margem': 12}
CURSORES = {'bloco': 0, 'barra': 1, 'sublinhado': 2}


def ler():
    c = dict(PADRAO)
    try:
        with open(GUARDADO, encoding='utf-8') as f:
            c.update({k: v for k, v in json.load(f).items() if k in PADRAO})
    except (OSError, ValueError):
        pass
    if c['tema'] not in TEMAS:
        c['tema'] = 'noite'
    return c


def fonte_padrao():
    for f in ('JetBrains Mono', 'Fira Code', 'Hack', 'Cascadia Code', 'Source Code Pro', 'DejaVu Sans Mono', 'Noto Sans Mono', 'Monospace'):
        if os.system('fc-list %s family 2>/dev/null | grep -q .' % repr(':family=' + f)) == 0:
            return f
    return 'Monospace'


def aplicar(c):
    c = dict(c)
    if not c['fonte']:
        c['fonte'] = fonte_padrao()
    t = TEMAS[c['tema']]
    # as cores já resolvidas, para o terminal não precisar de conhecer os temas
    c['paleta'] = dict(fundo=t['fundo'], texto=t['texto'], cursor=t['cursor'], cores=t['cores'], fortes=t['fortes'])
    os.makedirs(os.path.dirname(GUARDADO), exist_ok=True)
    tmp = GUARDADO + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(c, f, ensure_ascii=False, indent=1)
    os.replace(tmp, GUARDADO)
    # o atalho antigo (o Konsole com o nome "Terminal Carinae") deixa de ser preciso
    velho = os.path.join(DADOS, 'applications', 'org.kde.konsole.desktop')
    try:
        if 'Terminal Carinae' in open(velho, encoding='utf-8').read():
            os.remove(velho)
    except OSError:
        pass


def janela():
    sys.path.insert(0, os.environ.get('CARINAE_COMUM') or next((d for d in ('/usr/local/share/carinaeos/comum', '/usr/share/carinaeos/comum') if os.path.isdir(d)), '/usr/share/carinaeos/comum'))
    from base import iniciar
    from PySide6.QtCore import QObject, Property, Signal, Slot
    from PySide6.QtGui import QFontDatabase

    class Aparencia(QObject):
        mudou = Signal()

        def __init__(self):
            super().__init__()
            self._c = ler()
            if not self._c['fonte']:
                self._c['fonte'] = fonte_padrao()

        @Property('QVariantMap', notify=mudou)
        def config(self):
            return self._c

        @Property('QVariantList', constant=True)
        def temas(self):
            return [dict(TEMAS[k], id=k) for k in TEMAS]

        @Property('QStringList', constant=True)
        def fontes(self):
            return sorted({f for f in QFontDatabase.families()
                           if QFontDatabase.isFixedPitch(f) and not f.startswith('.')}, key=str.lower)

        @Slot(str, 'QVariant')
        def definir(self, chave, valor):
            if chave in PADRAO:
                self._c = dict(self._c, **{chave: valor})
                self.mudou.emit()

        @Slot()
        def aplicar(self):
            aplicar(self._c)

        @Slot()
        def cancelar(self):
            self._c = ler()
            if not self._c['fonte']:
                self._c['fonte'] = fonte_padrao()
            self.mudou.emit()

        @Slot()
        def abrirTerminal(self):
            os.system('carinae-terminal >/dev/null 2>&1 &')

    aqui = os.path.dirname(os.path.abspath(__file__))
    return iniciar('carinae-terminal-aparencia', 'Aparência do Carinae Terminal', 'carinaeos-terminal',
                   os.path.join(aqui, 'Main.qml'), {'aparencia': Aparencia})


if __name__ == '__main__':
    if '--aplicar' in sys.argv:
        aplicar(ler())
        sys.exit(0)
    sys.exit(janela())
