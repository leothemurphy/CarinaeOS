#!/usr/bin/env python3
# CarinaeOS — Carinae Notas (no jeito do Bloco de Notas do Windows 11): abas, procurar e substituir,
# e nada se perde: ao fechar, as abas (mesmo as que não foram gravadas) voltam quando se abre de novo.
#   carinaeos-notas [ARQUIVO…]
import json
import os
import socket
import subprocess
import sys
import threading
import time
import urllib.parse

AQUI = os.path.dirname(os.path.abspath(__file__))
for _p in ('/usr/local/share/carinaeos/comum', '/usr/share/carinaeos/comum', os.path.join(AQUI, '..', 'comum')):
    if os.path.isdir(_p):
        sys.path.insert(0, _p)
        break

from PySide6.QtCore import QObject, Property, Signal, Slot  # noqa: E402
from PySide6.QtNetwork import QLocalServer, QLocalSocket  # noqa: E402

HOME = os.path.expanduser('~')
SESSAO = os.path.join(HOME, '.local', 'share', 'carinaeos', 'notas')
SOQUETE = 'carinaeos-notas-%d' % os.getuid()
LIMITE = 20 * 1024 * 1024


def argumentos():
    r = []
    for a in sys.argv[1:]:
        if a.startswith('-'):
            continue
        if a.startswith('file://'):
            a = urllib.parse.unquote(urllib.parse.urlparse(a).path)
        r.append(os.path.abspath(os.path.expanduser(a)))
    return r


class Notas(QObject):
    abrirPedido = Signal(str)                    # um arquivo para abrir numa aba nova
    gravarComoEscolhido = Signal(int, str)       # (pedido, caminho)
    aviso = Signal(str)
    configMudou = Signal()

    def __init__(self):
        super().__init__()
        os.makedirs(SESSAO, exist_ok=True)
        self._cfg = dict(quebra=True, zoom=100, fonte='', barraEstado=True)
        try:
            self._cfg.update(json.load(open(os.path.join(SESSAO, 'config.json'), encoding='utf-8')))
        except (OSError, ValueError):
            pass
        self._iniciais = argumentos()
        # uma só janela: se já houver uma, ela abre os arquivos e esta fecha
        self._servidor = QLocalServer(self)
        QLocalServer.removeServer(SOQUETE) if not self._ha_outra() else None
        self._servidor.listen(SOQUETE)
        self._servidor.newConnection.connect(self._ligacao)

    def _ha_outra(self):
        s = QLocalSocket()
        s.connectToServer(SOQUETE)
        if s.waitForConnected(200):
            s.write((json.dumps(self._iniciais) + '\n').encode())
            s.flush()
            s.waitForBytesWritten(300)
            s.disconnectFromServer()
            sys.exit(0)
        return False

    def _ligacao(self):
        c = self._servidor.nextPendingConnection()

        def ler():
            try:
                for a in json.loads(bytes(c.readAll()).decode() or '[]'):
                    self.abrirPedido.emit(a)
            except ValueError:
                pass
            self.abrirPedido.emit('')            # "mostra-te"
        c.readyRead.connect(ler)

    @Property('QVariantList', constant=True)
    def iniciais(self):
        return self._iniciais

    # ---- configuração
    @Property('QVariantMap', notify=configMudou)
    def config(self):
        return self._cfg

    @Slot(str, 'QVariant')
    def definir(self, k, v):
        self._cfg[k] = v
        try:
            json.dump(self._cfg, open(os.path.join(SESSAO, 'config.json'), 'w', encoding='utf-8'))
        except OSError:
            pass
        self.configMudou.emit()

    # ---- arquivos
    @Slot(str, result='QVariantMap')
    def ler(self, caminho):
        try:
            st = os.stat(caminho)
            if st.st_size > LIMITE:
                return dict(erro='O arquivo é grande demais para o Carinae Notas (%d MB).' % (st.st_size // 1048576))
            dados = open(caminho, 'rb').read()
        except OSError as e:
            return dict(erro=e.strerror or str(e))
        if b'\x00' in dados[:8192] and not dados.startswith((b'\xff\xfe', b'\xfe\xff')):
            return dict(erro='Este arquivo não parece ser texto.')
        cod = 'UTF-8'
        if dados.startswith(b'\xef\xbb\xbf'):
            texto, cod = dados[3:].decode('utf-8', 'replace'), 'UTF-8 com BOM'
        elif dados.startswith((b'\xff\xfe', b'\xfe\xff')):
            texto, cod = dados.decode('utf-16'), 'UTF-16'
        else:
            try:
                texto = dados.decode('utf-8')
            except UnicodeDecodeError:
                texto, cod = dados.decode('cp1252', 'replace'), 'ANSI'
        fim = 'CRLF' if '\r\n' in texto[:65536] else ('CR' if '\r' in texto[:65536] else 'LF')
        texto = texto.replace('\r\n', '\n').replace('\r', '\n')
        return dict(texto=texto, codificacao=cod, fimLinha=fim, erro='', mtime=st.st_mtime)

    @Slot(str, str, str, str, result=str)
    def gravar(self, caminho, texto, codificacao, fim):
        t = texto.replace('\n', {'CRLF': '\r\n', 'CR': '\r'}.get(fim, '\n'))
        try:
            if codificacao == 'UTF-16':
                dados = t.encode('utf-16')
            elif codificacao == 'ANSI':
                dados = t.encode('cp1252', 'replace')
            elif codificacao == 'UTF-8 com BOM':
                dados = b'\xef\xbb\xbf' + t.encode('utf-8')
            else:
                dados = t.encode('utf-8')
            tmp = caminho + '.carinae-tmp'
            with open(tmp, 'wb') as f:
                f.write(dados)
            try:
                os.chmod(tmp, os.stat(caminho).st_mode & 0o7777)
            except OSError:
                pass
            os.replace(tmp, caminho)
        except OSError as e:
            return e.strerror or str(e)
        return ''

    @Slot(str, result=float)
    def mtime(self, caminho):
        try:
            return os.stat(caminho).st_mtime
        except OSError:
            return 0.0

    @Slot()
    def escolherAbrir(self):
        def correr():
            r = subprocess.run(['carinae-escolher', 'ficheiro', 'Abrir', os.path.join(HOME, 'Documentos') if os.path.isdir(os.path.join(HOME, 'Documentos')) else HOME,
                                'Texto', '*.txt *.md *.log *.ini *.conf *.cfg *.json *.xml *.csv *.sh *.py *.desktop'],
                               capture_output=True, text=True)
            if r.stdout.strip():
                self.abrirPedido.emit(r.stdout.strip())
        threading.Thread(target=correr, daemon=True).start()

    @Slot(int, str)
    def escolherGravar(self, pedido, sugestao):
        if not os.path.isabs(sugestao):
            pasta = os.path.join(HOME, 'Documentos')
            sugestao = os.path.join(pasta if os.path.isdir(pasta) else HOME, sugestao)

        def correr():
            r = subprocess.run(['carinae-escolher', 'salvar', 'Salvar como', sugestao], capture_output=True, text=True)
            self.gravarComoEscolhido.emit(pedido, r.stdout.strip())
        threading.Thread(target=correr, daemon=True).start()

    @Slot(str, result=str)
    def nomeDe(self, caminho):
        return os.path.basename(caminho)

    @Slot(str, result=str)
    def pastaDe(self, caminho):
        return os.path.dirname(caminho).replace(HOME, '~', 1)

    @Slot(result=str)
    def agora(self):
        return time.strftime('%H:%M %d/%m/%Y')

    @Slot(str)
    def mostrarNaPasta(self, caminho):
        subprocess.Popen(['carinaeos-arquivos', os.path.dirname(caminho) or HOME], start_new_session=True)

    @Slot(str)
    def imprimir(self, texto):
        try:
            r = subprocess.run(['lp', '-t', 'Carinae Notas', '-'], input=texto, capture_output=True, text=True)
            self.aviso.emit('Enviado para a impressora.' if r.returncode == 0 else 'Não foi possível imprimir: ' + (r.stderr.strip() or '?'))
        except OSError:
            self.aviso.emit('Não há impressoras configuradas.')

    # ---- sessão (as abas voltam ao abrir) ---------------------------------------------------------
    @Slot(result=str)
    def lerSessao(self):
        try:
            return open(os.path.join(SESSAO, 'sessao.json'), encoding='utf-8').read()
        except OSError:
            return ''

    @Slot(str)
    def gravarSessao(self, js):
        tmp = os.path.join(SESSAO, 'sessao.json.tmp')
        try:
            with open(tmp, 'w', encoding='utf-8') as f:
                f.write(js)
            os.replace(tmp, os.path.join(SESSAO, 'sessao.json'))
        except OSError:
            pass


def main():
    from base import iniciar
    return iniciar('carinaeos-notas', 'Carinae Notas', 'carinaeos-notas', os.path.join(AQUI, 'Main.qml'), {'notas': Notas})


if __name__ == '__main__':
    sys.exit(main())
