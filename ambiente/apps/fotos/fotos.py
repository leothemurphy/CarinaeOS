#!/usr/bin/env python3
# CarinaeOS — Fotos: ver imagens (no jeito do Fotos do Windows 11).
#   carinaeos-fotos [IMAGEM|PASTA]
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.parse

AQUI = os.path.dirname(os.path.abspath(__file__))
for _p in ('/usr/local/share/carinaeos/comum', '/usr/share/carinaeos/comum', os.path.join(AQUI, '..', 'comum')):
    if os.path.isdir(_p):
        sys.path.insert(0, _p)
        break

from PySide6.QtCore import QFileSystemWatcher, QObject, Property, QTimer, QUrl, Signal, Slot  # noqa: E402
from PySide6.QtGui import QGuiApplication, QImage  # noqa: E402

HOME = os.path.expanduser('~')
EXTENSOES = {'.jpg', '.jpeg', '.jpe', '.jfif', '.png', '.gif', '.webp', '.bmp', '.svg', '.svgz', '.tif', '.tiff',
             '.ico', '.avif', '.heic', '.heif', '.jxl', '.tga', '.ppm', '.pgm', '.pbm', '.xpm', '.xbm'}


def chave_natural(n):
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r'(\d+)', n)]


def tamanho(n):
    for u in ('B', 'KB', 'MB', 'GB'):
        if n < 1024 or u == 'GB':
            return ('%d %s' if u == 'B' else '%.1f %s') % (n, u)
        n /= 1024.0


# ---- Lixeira (a mesma do sistema: ~/.local/share/Trash, com o .trashinfo para "Restaurar") ----------------
LIXO = os.path.join(HOME, '.local', 'share', 'Trash')


def para_lixeira(caminho):
    """Devolve o caminho dentro da Lixeira (para poder desfazer)."""
    os.makedirs(os.path.join(LIXO, 'files'), exist_ok=True)
    os.makedirs(os.path.join(LIXO, 'info'), exist_ok=True)
    base = os.path.basename(caminho)
    nome, ext = os.path.splitext(base)
    destino, i = base, 1
    while os.path.exists(os.path.join(LIXO, 'files', destino)) or os.path.exists(os.path.join(LIXO, 'info', destino + '.trashinfo')):
        i += 1
        destino = '%s.%d%s' % (nome, i, ext)
    with open(os.path.join(LIXO, 'info', destino + '.trashinfo'), 'w', encoding='utf-8') as f:
        f.write('[Trash Info]\nPath=%s\nDeletionDate=%s\n' % (urllib.parse.quote(os.path.abspath(caminho)),
                                                             time.strftime('%Y-%m-%dT%H:%M:%S')))
    final = os.path.join(LIXO, 'files', destino)
    shutil.move(caminho, final)
    return final


def tirar_da_lixeira(no_lixo, original):
    shutil.move(no_lixo, original)
    try:
        os.remove(os.path.join(LIXO, 'info', os.path.basename(no_lixo) + '.trashinfo'))
    except OSError:
        pass


def exif(caminho):
    """Os dados da câmara (se o Pillow estiver instalado)."""
    r = []
    try:
        from PIL import ExifTags, Image
    except ImportError:
        return r
    try:
        with Image.open(caminho) as im:
            e = im.getexif()
            if not e:
                return r
            todos = dict(e)
            try:
                todos.update(e.get_ifd(0x8769))      # o bloco "Exif" (exposição, ISO…)
            except Exception:
                pass
            nomes = {ExifTags.TAGS.get(k, k): v for k, v in todos.items()}
    except Exception:
        return r

    def frac(v):
        try:
            return float(v)
        except (TypeError, ValueError, ZeroDivisionError):
            return None
    marca = str(nomes.get('Make', '') or '').strip()
    modelo = str(nomes.get('Model', '') or '').strip()
    if modelo:
        r.append(['Câmara', modelo if marca.lower() in modelo.lower() else (marca + ' ' + modelo).strip()])
    if nomes.get('DateTimeOriginal'):
        d = str(nomes['DateTimeOriginal'])
        m = re.match(r'(\d{4}):(\d\d):(\d\d) (\d\d):(\d\d)', d)
        r.append(['Tirada em', '%s/%s/%s %s:%s' % (m.group(3), m.group(2), m.group(1), m.group(4), m.group(5)) if m else d])
    f = frac(nomes.get('FNumber'))
    if f:
        r.append(['Abertura', 'f/%.1f' % f])
    t = frac(nomes.get('ExposureTime'))
    if t:
        r.append(['Exposição', ('1/%d s' % round(1 / t)) if t < 1 else ('%.1f s' % t)])
    if nomes.get('ISOSpeedRatings'):
        r.append(['ISO', str(nomes['ISOSpeedRatings'])])
    fl = frac(nomes.get('FocalLength'))
    if fl:
        r.append(['Distância focal', '%d mm' % round(fl)])
    if nomes.get('LensModel'):
        r.append(['Objetiva', str(nomes['LensModel']).strip()])
    return r


class Fotos(QObject):
    mudou = Signal()
    infoMudou = Signal()
    aviso = Signal(str, bool)          # texto, pode desfazer
    gravada = Signal()

    def __init__(self):
        super().__init__()
        self._lista = []
        self._i = -1
        self._pasta = ''
        self._info = {}
        self._desfazer = None
        self._vigia = QFileSystemWatcher(self)
        self._vigia.directoryChanged.connect(lambda _: self._atraso.start())
        self._atraso = QTimer(self)
        self._atraso.setSingleShot(True)
        self._atraso.setInterval(300)
        self._atraso.timeout.connect(self._reler)
        alvo = next((a for a in sys.argv[1:] if not a.startswith('-')), '')
        if alvo.startswith('file://'):
            alvo = urllib.parse.unquote(urllib.parse.urlparse(alvo).path)
        if alvo:
            self.abrir(alvo)
        else:
            pasta = subprocess.run(['xdg-user-dir', 'PICTURES'], capture_output=True, text=True).stdout.strip() if shutil.which('xdg-user-dir') else ''
            self.abrir(pasta if pasta and os.path.isdir(pasta) else HOME)

    # ---- lista da pasta
    def _ler_pasta(self, pasta):
        try:
            nomes = os.listdir(pasta)
        except OSError:
            return []
        r = [os.path.join(pasta, n) for n in nomes if os.path.splitext(n)[1].lower() in EXTENSOES and not n.startswith('.')]
        return sorted(r, key=lambda c: chave_natural(os.path.basename(c)))

    def _reler(self):
        atual = self.atual
        self._lista = self._ler_pasta(self._pasta)
        if atual in self._lista:
            self._i = self._lista.index(atual)
        else:
            self._i = min(self._i, len(self._lista) - 1)
        self._atualizar_info()
        self.mudou.emit()

    @Slot(str)
    def abrir(self, caminho):
        caminho = os.path.abspath(os.path.expanduser(caminho))
        pasta = caminho if os.path.isdir(caminho) else os.path.dirname(caminho)
        if self._pasta and self._pasta in self._vigia.directories():
            self._vigia.removePath(self._pasta)
        self._pasta = pasta
        if os.path.isdir(pasta):
            self._vigia.addPath(pasta)
        self._lista = self._ler_pasta(pasta)
        if os.path.isfile(caminho) and caminho not in self._lista:
            self._lista.insert(0, caminho)       # uma extensão que não conhecemos: tenta mesmo assim
        self._i = self._lista.index(caminho) if caminho in self._lista else (0 if self._lista else -1)
        self._atualizar_info()
        self.mudou.emit()

    @Property('QVariantList', notify=mudou)
    def lista(self):
        return self._lista

    @Property(int, notify=mudou)
    def indice(self):
        return self._i

    @Property(str, notify=mudou)
    def atual(self):
        return self._lista[self._i] if 0 <= self._i < len(self._lista) else ''

    @Property(str, notify=mudou)
    def pasta(self):
        return self._pasta

    @Slot(int)
    def ir(self, i):
        if not self._lista:
            return
        self._i = i % len(self._lista)
        self._atualizar_info()
        self.mudou.emit()

    @Slot()
    def seguinte(self):
        self.ir(self._i + 1)

    @Slot()
    def anterior(self):
        self.ir(self._i - 1)

    # ---- informações
    def _atualizar_info(self):
        c = self.atual
        if not c:
            self._info = {}
            self.infoMudou.emit()
            return
        try:
            st = os.stat(c)
        except OSError:
            st = None
        larg = alt = 0
        from PySide6.QtGui import QImageReader
        leitor = QImageReader(c)
        tam = leitor.size()
        if tam.isValid():
            larg, alt = tam.width(), tam.height()
        self._info = dict(
            nome=os.path.basename(c),
            pasta=os.path.dirname(c).replace(HOME, '~', 1),
            tamanho=tamanho(st.st_size) if st else '',
            dimensoes=('%d × %d' % (larg, alt)) if larg else '',
            megapixeis=('%.1f MP' % (larg * alt / 1e6)) if larg * alt >= 1e6 else '',
            data=time.strftime('%d/%m/%Y %H:%M', time.localtime(st.st_mtime)) if st else '',
            tipo=os.path.splitext(c)[1][1:].upper(),
            camera=[],
            animada=os.path.splitext(c)[1].lower() in ('.gif',) or (os.path.splitext(c)[1].lower() == '.webp' and leitor.supportsAnimation()),
        )
        self.infoMudou.emit()
        # os dados da câmara podem demorar um pouco (ficheiros grandes): depois
        QTimer.singleShot(0, lambda c=c: self._exif(c))

    def _exif(self, c):
        if c != self.atual:
            return
        self._info = dict(self._info, camera=exif(c))
        self.infoMudou.emit()

    @Property('QVariantMap', notify=infoMudou)
    def info(self):
        return self._info

    # ---- ações
    @Slot(int)
    def girar(self, graus):
        """Gira e grava (o JPEG mantém os dados da câmara)."""
        c = self.atual
        if not c:
            return
        try:
            from PIL import Image, ImageOps
        except ImportError:
            self.aviso.emit('Para girar e gravar instale o python3-pil.', False)
            return
        try:
            with Image.open(c) as im:
                fmt = im.format
                ex = im.info.get('exif')
                icc = im.info.get('icc_profile')
                im = ImageOps.exif_transpose(im)       # endireita primeiro (a orientação guardada)
                novo = im.rotate(-graus, expand=True)
                opcoes = {}
                if ex and fmt in ('JPEG', 'WEBP', 'PNG'):
                    try:
                        e = Image.Exif()
                        e.load(ex)
                        e[0x0112] = 1                    # já está direita
                        opcoes['exif'] = e.tobytes()
                    except Exception:
                        pass
                if icc:
                    opcoes['icc_profile'] = icc
                if fmt == 'JPEG':
                    opcoes.update(quality=95, optimize=True)
                tmp = c + '.carinae-tmp'
                novo.save(tmp, format=fmt, **opcoes)
            os.replace(tmp, c)
            self.gravada.emit()
        except Exception as e:
            self.aviso.emit('Não foi possível girar: %s' % e, False)
            return
        self._atualizar_info()
        self.mudou.emit()

    @Slot()
    def apagar(self):
        c = self.atual
        if not c:
            return
        try:
            no_lixo = para_lixeira(c)
        except OSError as e:
            self.aviso.emit('Não foi possível apagar: %s' % e.strerror, False)
            return
        self._desfazer = (no_lixo, c)
        i = self._i
        self._lista.remove(c)
        self._i = min(i, len(self._lista) - 1)
        self._atualizar_info()
        self.mudou.emit()
        self.aviso.emit('"%s" foi para a Lixeira.' % os.path.basename(c), True)

    @Slot()
    def desfazer(self):
        if not self._desfazer:
            return
        no_lixo, original = self._desfazer
        self._desfazer = None
        try:
            tirar_da_lixeira(no_lixo, original)
        except OSError as e:
            self.aviso.emit('Não foi possível restaurar: %s' % e.strerror, False)
            return
        self._lista = self._ler_pasta(self._pasta)
        self._i = self._lista.index(original) if original in self._lista else 0
        self._atualizar_info()
        self.mudou.emit()

    @Slot(str, result=str)
    def renomear(self, novo):
        c = self.atual
        novo = novo.strip().replace('/', '-')
        if not c or not novo:
            return 'Escreva um nome.'
        if not os.path.splitext(novo)[1]:
            novo += os.path.splitext(c)[1]
        destino = os.path.join(os.path.dirname(c), novo)
        if os.path.exists(destino):
            return 'Já existe um arquivo com esse nome.'
        try:
            os.rename(c, destino)
        except OSError as e:
            return e.strerror
        self._lista[self._i] = destino
        self._lista.sort(key=lambda x: chave_natural(os.path.basename(x)))
        self._i = self._lista.index(destino)
        self._atualizar_info()
        self.mudou.emit()
        return ''

    @Slot()
    def copiarImagem(self):
        im = QImage(self.atual)
        if not im.isNull():
            QGuiApplication.clipboard().setImage(im)
            self.aviso.emit('Imagem copiada.', False)

    @Slot()
    def copiarCaminho(self):
        QGuiApplication.clipboard().setText(self.atual)
        self.aviso.emit('Caminho copiado.', False)

    @Slot()
    def definirPapel(self):
        c = self.atual
        f = os.path.join(HOME, '.config', 'carinaeos-shell.json')
        import json
        try:
            d = json.load(open(f, encoding='utf-8'))
        except (OSError, ValueError):
            d = {}
        d['papel'] = d['papel2'] = c
        with open(f + '.tmp', 'w', encoding='utf-8') as o:
            json.dump(d, o, ensure_ascii=False)
        os.replace(f + '.tmp', f)
        self.aviso.emit('Papel de parede trocado.', False)

    @Slot()
    def mostrarNaPasta(self):
        subprocess.Popen(['carinaeos-arquivos', os.path.dirname(self.atual) or HOME], start_new_session=True)

    @Slot()
    def imprimir(self):
        if not shutil.which('lp'):
            self.aviso.emit('Não há impressoras configuradas (instale o CUPS).', False)
            return
        r = subprocess.run(['lp', '-o', 'fit-to-page', self.atual], capture_output=True, text=True)
        self.aviso.emit('Enviada para a impressora.' if r.returncode == 0 else
                        'Não foi possível imprimir: ' + (r.stderr.strip() or 'sem impressora predefinida'), False)

    _escolhido = Signal(str)

    @Slot()
    def escolher(self):
        import threading
        if not getattr(self, '_ligado', False):
            self._escolhido.connect(lambda c: self.abrir(c) if c else None)
            self._ligado = True

        def correr():
            r = subprocess.run(['carinae-escolher', 'ficheiro', 'Abrir imagem', self._pasta or HOME, 'Imagens',
                                ' '.join('*' + e for e in sorted(EXTENSOES))], capture_output=True, text=True)
            self._escolhido.emit(r.stdout.strip())
        threading.Thread(target=correr, daemon=True).start()

    @Slot(str, result=str)
    def url(self, caminho):
        return QUrl.fromLocalFile(caminho).toString()


def main():
    from base import iniciar
    return iniciar('carinaeos-fotos', 'Carinae Fotos', 'carinaeos-fotos', os.path.join(AQUI, 'Main.qml'), {'fotos': Fotos})


if __name__ == '__main__':
    sys.exit(main())
