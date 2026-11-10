#!/usr/bin/python3
# CarinaeOS - Manual: le o manual (/usr/share/doc/carinaeos/manual/*.md) com capitulos, pesquisa
# e um botao para perguntar a Eta.
import glob
import os
import re
import subprocess
import sys

sys.path.insert(0, '/usr/share/carinaeos/comum')
from base import iniciar  # noqa: E402

from PySide6.QtCore import Property, QObject, Signal, Slot  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
PASTA = os.environ.get('CARINAEOS_MANUAL', '/usr/share/doc/carinaeos/manual')


def simples(t):
    import unicodedata
    t = unicodedata.normalize('NFD', t.lower())
    return ''.join(c for c in t if unicodedata.category(c) != 'Mn')


ESTILO = '''<style>
h1 { font-size: 30px; color: #ffffff; margin-bottom: 14px; }
h2 { font-size: 22px; color: #ffcf9e; margin-top: 26px; margin-bottom: 8px; }
h3 { font-size: 17px; color: #f2ecfa; margin-top: 18px; margin-bottom: 6px; }
p, li { line-height: 145%; }
p { margin-top: 6px; margin-bottom: 8px; }
pre { background-color: #1d1730; color: #e9e2ff; font-family: monospace; font-size: 13px; padding: 10px; margin: 8px 0px; }
code { background-color: #251d3a; color: #ffd8b0; font-family: monospace; }
table { margin: 8px 0px; }
th { background-color: #2a2140; color: #ffffff; padding: 6px; }
td { padding: 6px; border-bottom: 1px solid #2c2440; }
blockquote { color: #ffcf9e; margin-left: 10px; }
a { color: #ffb46e; }
</style>'''


def para_html(md):
    try:
        import markdown
    except ImportError:
        return ''
    corpo = markdown.markdown(md, extensions=['tables', 'fenced_code', 'sane_lists'])
    corpo = corpo.replace('<table>', '<table width="100%" cellspacing="0">')
    return ESTILO + corpo


class Manual(QObject):
    mudou = Signal()

    def __init__(self, inicio=''):
        super().__init__()
        self._caps = []
        for f in sorted(glob.glob(os.path.join(PASTA, '*.md'))):
            texto = open(f, encoding='utf-8').read()
            m = re.search(r'^#\s+(.+)$', texto, re.M)
            self._caps.append(dict(arquivo=os.path.basename(f), titulo=m.group(1) if m else os.path.basename(f), texto=texto))
        self._atual = 0
        if inicio:
            for i, c in enumerate(self._caps):
                if inicio in c['arquivo']:
                    self._atual = i

    capitulos = Property('QVariantList', lambda s: [dict(titulo=c['titulo'], arquivo=c['arquivo']) for c in s._caps], constant=True)
    atual = Property(int, lambda s: s._atual, notify=mudou)
    texto = Property(str, lambda s: s._caps[s._atual]['texto'] if s._caps else 'O manual não foi encontrado.', notify=mudou)
    html = Property(str, lambda s: para_html(s._caps[s._atual]['texto']) if s._caps else '', notify=mudou)

    @Slot(int)
    def abrir(self, i):
        if 0 <= i < len(self._caps):
            self._atual = i
            self.mudou.emit()

    @Slot(str)
    def seguirLigacao(self, url):
        nome = url.split('/')[-1].split('#')[0]
        for i, c in enumerate(self._caps):
            if c['arquivo'] == nome:
                self.abrir(i)
                return
        if url.startswith('http'):
            subprocess.Popen(['xdg-open', url], start_new_session=True)

    @Slot(str, result='QVariantList')
    def procurar(self, termo):
        t = simples(termo.strip())
        if len(t) < 2:
            return []
        res = []
        for i, c in enumerate(self._caps):
            secao = c['titulo']
            for linha in c['texto'].split('\n'):
                if linha.startswith('#'):
                    secao = linha.lstrip('# ').strip()
                if t in simples(linha) and not linha.startswith('#'):
                    res.append(dict(cap=i, capitulo=c['titulo'], secao=secao, linha=linha.strip()[:140]))
                    if len(res) > 80:
                        return res
        return res

    @Slot(str)
    def perguntarEta(self, pergunta):
        subprocess.Popen(['carinaeos-eta', pergunta], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


if __name__ == '__main__':
    inicio = sys.argv[1] if len(sys.argv) > 1 else ''
    sys.exit(iniciar('carinaeos-manual', 'Manual do CarinaeOS', 'help-contents', os.path.join(AQUI, 'Main.qml'),
                     {'manual': Manual(inicio)}))
