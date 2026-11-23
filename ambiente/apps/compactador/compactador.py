#!/usr/bin/env python3
# CarinaeOS — Carinae Compactador (no lugar do Ark): ver e extrair ZIP, RAR, 7Z, TAR… e criar ZIP/7Z/TAR.
#   carinaeos-compactador ARQUIVO.zip                  ver o que tem dentro
#   carinaeos-compactador --extrair-aqui ARQUIVO…      extrair ao lado (sem janela de escolha)
#   carinaeos-compactador --compactar CAMINHO…         criar um arquivo compactado com estes
import os
import shutil
import subprocess
import sys
import tempfile
import threading
import urllib.parse

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
for _p in ('/usr/local/share/carinaeos/comum', '/usr/share/carinaeos/comum', os.path.join(AQUI, '..', 'comum')):
    if os.path.isdir(_p):
        sys.path.insert(0, _p)
        break

import motor  # noqa: E402
from PySide6.QtCore import QObject, Property, Signal, Slot  # noqa: E402

HOME = os.path.expanduser('~')
ICONES = {'.pdf': 'application-pdf', '.txt': 'text-x-generic', '.md': 'text-x-generic', '.doc': 'x-office-document',
          '.docx': 'x-office-document', '.odt': 'x-office-document', '.xls': 'x-office-spreadsheet',
          '.xlsx': 'x-office-spreadsheet', '.ods': 'x-office-spreadsheet', '.ppt': 'x-office-presentation',
          '.pptx': 'x-office-presentation', '.html': 'text-html', '.py': 'text-x-script', '.sh': 'text-x-script',
          '.exe': 'application-x-executable', '.iso': 'application-x-cd-image'}


def caminhos(args):
    r = []
    for a in args:
        if a.startswith('file://'):
            a = urllib.parse.unquote(urllib.parse.urlparse(a).path)
        r.append(os.path.abspath(os.path.expanduser(a)))
    return r


def icone(nome, pasta):
    if pasta:
        return 'folder'
    e = os.path.splitext(nome)[1].lower()
    if e in ICONES:
        return ICONES[e]
    if e in ('.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg', '.bmp'):
        return 'image-x-generic'
    if e in ('.mp3', '.ogg', '.flac', '.wav', '.m4a'):
        return 'audio-x-generic'
    if e in ('.mp4', '.mkv', '.avi', '.webm', '.mov'):
        return 'video-x-generic'
    if any(nome.lower().endswith(x) for x in motor.EXTENSOES):
        return 'package-x-generic'
    return 'text-x-generic'


def tamanho(n):
    if not n:
        return ''
    for u in ('B', 'KB', 'MB', 'GB', 'TB'):
        if n < 1024 or u == 'TB':
            return ('%d %s' if u == 'B' else '%.1f %s') % (n, u)
        n /= 1024.0


def destino_livre(caminho):
    if not os.path.exists(caminho):
        return caminho
    base, ext = os.path.splitext(caminho)
    if base.endswith('.tar'):
        base, ext = base[:-4], '.tar' + ext
    i = 2
    while os.path.exists('%s (%d)%s' % (base, i, ext)):
        i += 1
    return '%s (%d)%s' % (base, i, ext)


class Compactador(QObject):
    mudou = Signal()
    progresso = Signal()
    pedeSenha = Signal()
    aviso = Signal(str)
    _fim = Signal(str, str)          # (erro, o que fazer depois)
    _listado = Signal('QVariant', str)
    _escolhido = Signal(str, str)

    def __init__(self):
        super().__init__()
        a = sys.argv[1:]
        self._modo = 'ver'
        self._arquivo = ''
        self._origens = []
        self._entradas = []
        self._pasta = ''          # a pasta de dentro do arquivo que se está a ver
        self._senha = ''
        self._erro = ''
        self._a_ler = False
        self._op = None           # dict(titulo, fracao) durante extrair/criar
        self._parar = None
        self._depois_senha = None
        self._fim.connect(self._acabou)
        self._listado.connect(self._chegou_lista)
        self._escolhido.connect(self._chegou_escolha)
        if '--compactar' in a:
            self._modo = 'criar'
            self._origens = caminhos(x for x in a if not x.startswith('--'))
        elif '--extrair-aqui' in a:
            self._modo = 'extrair-aqui'
            self._origens = caminhos(x for x in a if not x.startswith('--'))
        else:
            c = caminhos(x for x in a if not x.startswith('--'))
            if c:
                self.abrir(c[0])

    # ---- abrir e ver -------------------------------------------------------------------------
    @Slot(str)
    def abrir(self, caminho):
        self._arquivo = caminho
        self._modo = 'ver'
        self._pasta = ''
        self._entradas = []
        self._erro = ''
        self._a_ler = True
        self.mudou.emit()

        def correr():
            try:
                self._listado.emit(motor.listar(caminho, self._senha), '')
            except motor.PrecisaSenha:
                self._listado.emit(None, 'senha')
            except motor.Erro as e:
                self._listado.emit(None, str(e))
            except Exception as e:
                self._listado.emit(None, 'Não foi possível abrir: %s' % e)
        threading.Thread(target=correr, daemon=True).start()

    def _chegou_lista(self, lista, erro):
        self._a_ler = False
        if erro == 'senha':
            self._depois_senha = lambda: self.abrir(self._arquivo)
            self.pedeSenha.emit()
        elif erro:
            self._erro = erro
        else:
            self._entradas = lista
        self.mudou.emit()

    @Slot(str)
    def usarSenha(self, s):
        self._senha = s
        f, self._depois_senha = self._depois_senha, None
        if f:
            f()

    @Property(str, notify=mudou)
    def modo(self):
        return self._modo

    @Property(str, notify=mudou)
    def arquivo(self):
        return self._arquivo

    @Property(str, notify=mudou)
    def nome(self):
        return os.path.basename(self._arquivo) if self._arquivo else ''

    @Property(str, notify=mudou)
    def formato(self):
        return motor.nome_formato(self._arquivo) if self._arquivo else ''

    @Property(str, notify=mudou)
    def erro(self):
        return self._erro

    @Property(bool, notify=mudou)
    def aLer(self):
        return self._a_ler

    @Property(str, notify=mudou)
    def pasta(self):
        return self._pasta

    @Property('QVariantList', notify=mudou)
    def itens(self):
        pre = self._pasta + '/' if self._pasta else ''
        r = []
        for e in self._entradas:
            c = e['caminho']
            if not c.startswith(pre) or c == self._pasta:
                continue
            resto = c[len(pre):]
            if '/' in resto:
                continue
            r.append(dict(nome=resto, caminho=c, pasta=e['pasta'], icone=icone(resto, e['pasta']),
                          tamanho=tamanho(e['tamanho']) if not e['pasta'] else '',
                          comprimido=tamanho(e['comprimido']) if not e['pasta'] and e['comprimido'] else '',
                          data=e['data'], cifrado=e['cifrado']))
        r.sort(key=lambda x: (not x['pasta'], x['nome'].lower()))
        return r

    @Property(str, notify=mudou)
    def resumo(self):
        f = [e for e in self._entradas if not e['pasta']]
        total = sum(e['tamanho'] for e in f)
        try:
            no_disco = os.path.getsize(self._arquivo)
        except OSError:
            no_disco = 0
        taxa = (' · %d%% de compactação' % round(100 - 100 * no_disco / total)) if total and no_disco and no_disco < total else ''
        return '%d arquivos · %s%s' % (len(f), tamanho(total) or '0 B', taxa)

    @Slot(str)
    def entrar(self, p):
        self._pasta = p
        self.mudou.emit()

    @Slot()
    def subir(self):
        self._pasta = self._pasta.rsplit('/', 1)[0] if '/' in self._pasta else ''
        self.mudou.emit()

    # ---- extrair ------------------------------------------------------------------------------
    @Property('QVariantMap', notify=progresso)
    def operacao(self):
        return self._op or {}

    def _correr(self, titulo, trabalho, depois=''):
        self._op = dict(titulo=titulo, fracao=0.0)
        self._parar = threading.Event()
        self.progresso.emit()
        ultimo = [0.0]

        def marcar(feito, total):
            f = min(1.0, feito / total) if total else 0
            if f - ultimo[0] >= 0.01 or f >= 1:
                ultimo[0] = f
                self._op = dict(titulo=titulo, fracao=f)
                self.progresso.emit()

        def correr():
            try:
                trabalho(marcar, self._parar)
                self._fim.emit('', depois)
            except motor.PrecisaSenha:
                self._fim.emit('senha', depois)
            except motor.Erro as e:
                self._fim.emit(str(e), depois)
            except Exception as e:
                self._fim.emit(str(e) or e.__class__.__name__, depois)
        threading.Thread(target=correr, daemon=True).start()

    def _acabou(self, erro, depois):
        self._op = None
        self.progresso.emit()
        if erro == 'senha':
            self._depois_senha = self._repetir
            self.pedeSenha.emit()
            return
        if erro == 'cancelado':
            self.aviso.emit('Cancelado.')
        elif erro:
            self.aviso.emit('Não foi possível: %s' % erro)
        elif depois.startswith('mostrar:'):
            subprocess.Popen(['carinaeos-arquivos', depois[8:]], start_new_session=True)
            self.aviso.emit('Pronto.')
        elif depois.startswith('abrir:'):
            subprocess.Popen(['xdg-open', depois[6:]], start_new_session=True)
        elif depois == 'sair':
            from PySide6.QtGui import QGuiApplication
            QGuiApplication.quit()
        else:
            self.aviso.emit('Pronto.')
        if self._modo == 'extrair-aqui' and depois != 'sair':
            from PySide6.QtGui import QGuiApplication
            QGuiApplication.quit()

    @Slot()
    def cancelar(self):
        if self._parar:
            self._parar.set()

    @Property(str, notify=mudou)
    def destinoSugerido(self):
        if not self._arquivo:
            return ''
        return destino_livre(os.path.join(os.path.dirname(self._arquivo), motor.sem_extensao(os.path.basename(self._arquivo))))

    @Slot(str, 'QVariantList', bool)
    def extrair(self, destino, selecionados, mostrar):
        destino = os.path.expanduser(destino.strip()) or self.destinoSugerido
        sel = [str(s) for s in selecionados] or None
        arq, senha = self._arquivo, self._senha
        self._repetir = lambda: self.extrair(destino, selecionados, mostrar)
        self._correr('A extrair para %s' % os.path.basename(destino),
                     lambda marcar, parar: motor.extrair(arq, destino, sel, self._senha, marcar, parar),
                     'mostrar:' + destino if mostrar else '')
        del senha

    @Slot(str)
    def abrirItem(self, caminho):
        """Abre um arquivo de dentro (extrai para uma pasta temporária)."""
        tmp = tempfile.mkdtemp(prefix='carinae-compactador-')
        arq = self._arquivo
        self._repetir = lambda: self.abrirItem(caminho)
        self._correr('A abrir %s' % os.path.basename(caminho),
                     lambda marcar, parar: motor.extrair(arq, tmp, [caminho], self._senha, marcar, parar),
                     'abrir:' + os.path.join(tmp, caminho))

    @Slot(str)
    def escolherPasta(self, atual):
        def correr():
            r = subprocess.run(['carinae-escolher', 'pasta', 'Extrair para', os.path.dirname(atual) if atual else HOME],
                               capture_output=True, text=True)
            self._escolhido.emit('pasta', r.stdout.strip())
        threading.Thread(target=correr, daemon=True).start()

    @Slot()
    def escolherArquivo(self):
        def correr():
            r = subprocess.run(['carinae-escolher', 'ficheiro', 'Abrir arquivo compactado', os.path.join(HOME, 'Downloads'),
                                'Arquivos compactados', ' '.join('*' + e for e in motor.EXTENSOES)], capture_output=True, text=True)
            self._escolhido.emit('arquivo', r.stdout.strip())
        threading.Thread(target=correr, daemon=True).start()

    pastaEscolhida = Signal(str)

    def _chegou_escolha(self, tipo, valor):
        if not valor:
            return
        if tipo == 'arquivo':
            self.abrir(valor)
        else:
            self.pastaEscolhida.emit(valor)

    # ---- extrair aqui (menu dos Documentos) ------------------------------------------------------
    @Slot()
    def extrairAqui(self):
        origens = list(self._origens)

        def trabalho(marcar, parar):
            for i, o in enumerate(origens):
                destino = destino_livre(os.path.join(os.path.dirname(o), motor.sem_extensao(os.path.basename(o))))
                motor.extrair(o, destino, None, self._senha,
                              lambda f, t: marcar(i + (f / t if t else 0), len(origens)), parar)
        self._repetir = self.extrairAqui
        self._correr('A extrair %s' % ', '.join(os.path.basename(o) for o in origens), trabalho, 'sair')

    # ---- criar ------------------------------------------------------------------------------------
    @Property('QVariantList', notify=mudou)
    def origens(self):
        return [dict(nome=os.path.basename(o), icone=icone(o, os.path.isdir(o))) for o in self._origens]

    @Property(str, notify=mudou)
    def nomeSugerido(self):
        if not self._origens:
            return 'Arquivo'
        if len(self._origens) == 1:
            return os.path.splitext(os.path.basename(self._origens[0]))[0] if os.path.isfile(self._origens[0]) else os.path.basename(self._origens[0])
        return os.path.basename(os.path.dirname(self._origens[0])) or 'Arquivo'

    @Property('QVariantList', constant=True)
    def formatos(self):
        return [dict(id=f, nome=n, disponivel=(f != '7z' or bool(motor.sete()))) for f, n in motor.FORMATOS]

    @Property(bool, constant=True)
    def tem7z(self):
        return bool(motor.sete())

    @Slot(str, str, int, str, bool)
    def criar(self, nome, formato, nivel, senha, mostrar):
        nome = (nome.strip() or self.nomeSugerido).replace('/', '-')
        pasta = os.path.dirname(self._origens[0])
        destino = destino_livre(os.path.join(pasta, nome + '.' + formato))
        origens = list(self._origens)
        self._repetir = lambda: None
        self._correr('A compactar %s' % os.path.basename(destino),
                     lambda marcar, parar: motor.criar(destino, origens, formato, nivel, senha, marcar, parar),
                     'mostrar:' + pasta if mostrar else 'sair')


def main():
    from base import iniciar
    return iniciar('carinaeos-compactador', 'Carinae Compactador', 'carinaeos-compactador',
                   os.path.join(AQUI, 'Main.qml'), {'comp': Compactador})


if __name__ == '__main__':
    sys.exit(main())
