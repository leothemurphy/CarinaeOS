#!/usr/bin/env python3
# CarinaeOS — Leitor de PDF (o motor PDF do Qt; sem o Okular)
#   carinaeos-pdf [ARQUIVO.pdf]
import os
import shutil
import subprocess
import sys
import threading
import urllib.parse

AQUI = os.path.dirname(os.path.abspath(__file__))
for _p in ('/usr/local/share/carinaeos/comum', '/usr/share/carinaeos/comum', os.path.join(AQUI, '..', 'comum')):
    if os.path.isdir(_p):
        sys.path.insert(0, _p)
        break

from PySide6.QtCore import QObject, Property, QUrl, Signal, Slot  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402

HOME = os.path.expanduser('~')


class Leitor(QObject):
    mudou = Signal()
    aviso = Signal(str)
    impressorasMudaram = Signal()
    _escolhido = Signal(str)

    def __init__(self):
        super().__init__()
        self._arquivo = ''
        self._impressoras = []
        self._padrao = ''
        self._escolhido.connect(lambda c: self.abrir(c) if c else None)
        alvo = next((a for a in sys.argv[1:] if not a.startswith('-')), '')
        if alvo.startswith('file://'):
            alvo = urllib.parse.unquote(urllib.parse.urlparse(alvo).path)
        if alvo:
            self.abrir(alvo)

    @Slot(str)
    def abrir(self, caminho):
        caminho = os.path.abspath(os.path.expanduser(caminho))
        if not os.path.isfile(caminho):
            self.aviso.emit('Arquivo não encontrado: %s' % caminho)
            return
        self._arquivo = caminho
        self.mudou.emit()

    @Property(str, notify=mudou)
    def arquivo(self):
        return self._arquivo

    @Property(str, notify=mudou)
    def url(self):
        return QUrl.fromLocalFile(self._arquivo).toString() if self._arquivo else ''

    @Property(str, notify=mudou)
    def nome(self):
        return os.path.basename(self._arquivo)

    @Slot()
    def escolher(self):
        pasta = os.path.dirname(self._arquivo) if self._arquivo else os.path.join(HOME, 'Documentos')
        if not os.path.isdir(pasta):
            pasta = HOME

        def correr():
            r = subprocess.run(['carinae-escolher', 'ficheiro', 'Abrir PDF', pasta, 'Documentos PDF', '*.pdf *.PDF'],
                               capture_output=True, text=True)
            self._escolhido.emit(r.stdout.strip())
        threading.Thread(target=correr, daemon=True).start()

    # ---- imprimir (CUPS) ------------------------------------------------------------------------
    @Slot()
    def lerImpressoras(self):
        def correr():
            lista, padrao = [], ''
            if shutil.which('lpstat'):
                r = subprocess.run(['lpstat', '-e'], capture_output=True, text=True, env=dict(os.environ, LC_ALL='C'))
                lista = [l.strip() for l in r.stdout.splitlines() if l.strip()]
                d = subprocess.run(['lpstat', '-d'], capture_output=True, text=True, env=dict(os.environ, LC_ALL='C')).stdout
                if ':' in d:
                    padrao = d.split(':', 1)[1].strip()
            self._impressoras, self._padrao = lista, padrao
            self.impressorasMudaram.emit()
        threading.Thread(target=correr, daemon=True).start()

    @Property('QVariantList', notify=impressorasMudaram)
    def impressoras(self):
        return self._impressoras

    @Property(str, notify=impressorasMudaram)
    def impressoraPadrao(self):
        return self._padrao

    @Slot(str, str, int, bool, bool)
    def imprimir(self, impressora, paginas, copias, frenteVerso, cores):
        if not self._arquivo:
            return
        cmd = ['lp', '-n', str(max(1, copias)), '-t', self.nome]
        if impressora:
            cmd += ['-d', impressora]
        if paginas.strip():
            cmd += ['-P', paginas.strip().replace(' ', '')]
        if frenteVerso:
            cmd += ['-o', 'sides=two-sided-long-edge']
        if not cores:
            cmd += ['-o', 'print-color-mode=monochrome']
        cmd.append(self._arquivo)
        r = subprocess.run(cmd, capture_output=True, text=True)
        self.aviso.emit('Enviado para %s.' % (impressora or 'a impressora') if r.returncode == 0
                        else 'Não foi possível imprimir: ' + (r.stderr.strip() or 'erro desconhecido'))

    # ---- outros ---------------------------------------------------------------------------------
    @Slot()
    def mostrarNaPasta(self):
        subprocess.Popen(['carinaeos-arquivos', os.path.dirname(self._arquivo) or HOME], start_new_session=True)

    @Slot()
    def copiarCaminho(self):
        QGuiApplication.clipboard().setText(self._arquivo)
        self.aviso.emit('Caminho copiado.')

    @Slot(str)
    def abrirLigacao(self, url):
        subprocess.Popen(['xdg-open', url], start_new_session=True)

    @Slot(str)
    def copiar(self, texto):
        QGuiApplication.clipboard().setText(texto)


def main():
    from base import iniciar
    return iniciar('carinaeos-pdf', 'Carinae PDF', 'carinaeos-pdf', os.path.join(AQUI, 'Main.qml'), {'leitor': Leitor})


if __name__ == '__main__':
    sys.exit(main())
