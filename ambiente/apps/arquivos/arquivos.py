#!/usr/bin/python3
# CarinaeOS - Carinae Arquivos ("Documentos"): o gestor de ficheiros do sistema.
#
# Visual do Explorador de Ficheiros do Windows 11 (separadores, barra de comandos,
# Início, Este computador com as unidades, Rede com partilhas SMB), mas feito em
# casa: cada pixel e cada comportamento são nossos. Não usa nada do KDE.
#
#   carinaeos-arquivos            abre em ~
#   carinaeos-arquivos /caminho   abre nessa pasta
#   carinaeos-arquivos --religar  liga as partilhas de rede marcadas "voltar a ligar" (ao entrar na sessão)
#
# Este ficheiro e o "motor": lista pastas, abre ficheiros, move para a lixeira,
# renomeia, cria pastas e copia/cola. O desenho esta no Main.qml ao lado.

import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
import urllib.parse



def correr(cmd, espera=True):
    """Corre um comando; devolve (código, saída). Nunca levanta exceção."""
    try:
        if not espera:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return 0, ''
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return r.returncode, r.stdout.strip()
    except Exception as e:
        return 1, str(e)


from PySide6.QtCore import (Property, Q_ARG, QMetaObject, QObject, QSize, Qt,  # noqa: E402
                            Signal, Slot)
from PySide6.QtCore import QMimeData, QPointF, QRectF, QUrl  # noqa: E402
from PySide6.QtGui import (QColor, QGuiApplication, QIcon, QImage, QImageReader,  # noqa: E402
                           QLinearGradient, QPainter, QPainterPath, QPen, QPixmap)
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402
from PySide6.QtQuick import QQuickImageProvider  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser('~')

IMAGENS = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.avif', '.svg', '.tif', '.tiff'}
VIDEOS = {'.mp4', '.mkv', '.webm', '.avi', '.mov', '.m4v', '.wmv', '.flv'}

# cores das etiquetas (as mesmas que o carinaeos-etiquetas usa)
CORES_ETQ = {'Vermelho': 'red', 'Laranja': 'orange', 'Amarelo': 'yellow',
             'Verde': 'green', 'Azul': 'blue', 'Roxo': 'violet', 'Cinzento': 'grey'}

ICONES_EXT = {
    '.pdf': 'application-pdf', '.txt': 'text-plain', '.md': 'text-x-markdown',
    '.jpg': 'image-jpeg', '.jpeg': 'image-jpeg', '.png': 'image-png',
    '.gif': 'image-gif', '.webp': 'image-webp', '.svg': 'image-svg+xml',
    '.mp3': 'audio-mpeg', '.flac': 'audio-x-flac', '.wav': 'audio-x-wav',
    '.mp4': 'video-mp4', '.mkv': 'video-x-matroska', '.webm': 'video-webm',
    '.zip': 'application-zip', '.rar': 'application-x-rar', '.7z': 'application-x-7z-compressed',
    '.deb': 'application-x-deb', '.iso': 'application-x-cd-image',
    '.doc': 'x-office-document', '.docx': 'x-office-document',
    '.odt': 'x-office-document', '.xls': 'x-office-spreadsheet',
    '.xlsx': 'x-office-spreadsheet', '.ods': 'x-office-spreadsheet',
    '.ppt': 'x-office-presentation', '.pptx': 'x-office-presentation',
    '.py': 'text-x-python', '.sh': 'text-x-shellscript',
    '.json': 'application-json', '.html': 'text-html', '.css': 'text-css',
}


def tamanho_legivel(n):
    """1234567 -> '1,2 MB' (como o Explorador)."""
    if n is None:
        return ""
    if n < 1024:
        return "%d B" % n
    for unidade in ('KB', 'MB', 'GB', 'TB'):
        n /= 1024.0
        if n < 1024 or unidade == 'TB':
            return ("%.0f %s" if n >= 100 else "%.1f %s") % (n, unidade)


def nome_tipo(caminho, pasta):
    if pasta:
        return "Pasta de ficheiros"
    ext = os.path.splitext(caminho)[1].lower()
    if not ext:
        return "Ficheiro"
    return "Ficheiro %s" % ext.lstrip('.').upper()


PASTAS_ESPECIAIS = {}     # caminho -> "win:pasta-xxx" (preenchido no arranque)


def icone_de(caminho, pasta):
    if pasta:
        return PASTAS_ESPECIAIS.get(caminho, 'win:pasta')
    return ICONES_EXT.get(os.path.splitext(caminho)[1].lower(), 'text-x-generic')


class Icones(QQuickImageProvider):
    """Serve os icones do tema para o QML (image://icones/folder).

    O tema da sessão é escuro (ícones brancos); nesta janela o fundo é branco, por
    isso um ícone claro é escurecido aqui — assim fica sempre visível, seja qual
    for o tema, sem mexer no tema do sistema.
    """
    # cor com que os ícones claros são pintados (muda com o modo claro/escuro)
    TINTA = '#3a3a3a'

    def __init__(self):
        super().__init__(QQuickImageProvider.Image)

    @staticmethod
    def _escuro_demais(img):
        """Verdadeiro se o ícone é claro e sem cor (ícone simbólico do tema escuro).

        Os ícones coloridos (pastas das etiquetas, o vermelho do .deb) nunca são
        tocados: só os que são claros e acinzentados é que desapareceriam no branco.
        """
        luz = sat = n = 0
        for y in range(0, img.height(), 3):
            for x in range(0, img.width(), 3):
                c = img.pixelColor(x, y)
                if c.alpha() < 40:
                    continue
                h, s, v, a = c.getHsvF()
                luz += 0.299 * c.red() + 0.587 * c.green() + 0.114 * c.blue()
                sat += 0 if h < 0 else s
                n += 1
        if not n:
            return False
        return (luz / n) > 200 and (sat / n) < 0.15

    @staticmethod
    def _cadeado(lado=24, cor='#c9a227'):
        """Cadeado desenhado aqui: os temas não têm um ícone de cadeado fiável."""
        img = QImage(lado, lado, QImage.Format_ARGB32)
        img.fill(Qt.transparent)
        p = QPainter(img)
        p.setRenderHint(QPainter.Antialiasing, True)
        c = QColor(cor)
        # corpo
        p.setPen(Qt.NoPen)
        p.setBrush(c)
        p.drawRoundedRect(QRectF(lado * 0.22, lado * 0.46, lado * 0.56, lado * 0.42),
                          lado * 0.08, lado * 0.08)
        # arco
        pena = QPen(c)
        pena.setWidthF(lado * 0.11)
        pena.setCapStyle(Qt.RoundCap)
        p.setPen(pena)
        p.setBrush(Qt.NoBrush)
        p.drawArc(QRectF(lado * 0.30, lado * 0.18, lado * 0.40, lado * 0.44), 0, 180 * 16)
        # buraco da fechadura
        p.setPen(Qt.NoPen)
        p.setBrush(QColor(0, 0, 0, 140))
        p.drawEllipse(QPointF(lado * 0.5, lado * 0.66), lado * 0.07, lado * 0.07)
        p.end()
        return img

    @staticmethod
    def _ponto(cor, lado=24):
        """Ponto colorido (para etiquetas sem ícone no tema)."""
        img = QImage(lado, lado, QImage.Format_ARGB32)
        img.fill(Qt.transparent)
        p = QPainter(img)
        p.setRenderHint(QPainter.Antialiasing, True)
        p.setPen(Qt.NoPen)
        p.setBrush(QColor(cor))
        p.drawEllipse(QRectF(lado * 0.18, lado * 0.18, lado * 0.64, lado * 0.64))
        p.end()
        return img

    @staticmethod
    def _tingir(img, cor):
        img = img.convertToFormat(QImage.Format_ARGB32)
        p = QPainter(img)
        p.setCompositionMode(QPainter.CompositionMode_SourceIn)
        p.fillRect(img.rect(), cor)
        p.end()
        return img

    @staticmethod
    def _icone_base(chave):
        """Resolve um nome para um QIcon: pastas no modelo do macOS (WhiteSur) primeiro."""
        if chave == 'folder' or chave.startswith('folder-'):
            for raiz in ('/usr/share/icons/WhiteSur/places/scalable',
                         '/usr/share/icons/WhiteSur/places/22'):
                for nome in (chave, 'folder'):
                    f = os.path.join(raiz, nome + '.svg')
                    if os.path.isfile(f):
                        ic = QIcon(f)
                        if not ic.isNull():
                            return ic
        ic = QIcon.fromTheme(chave)
        if ic.isNull():
            alternativas = ('folder',) if chave.startswith('folder') else ('text-x-generic',)
            for alternativa in alternativas:
                ic = QIcon.fromTheme(alternativa)
                if not ic.isNull():
                    break
        return ic


    # ---- ícones ao estilo do Windows 11 (desenhados aqui) ---------------------------------
    # win:pasta[-documentos|-imagens|-transferencias|-musica|-videos|-trabalho|-rede|-etiqueta]
    # win:disco, win:disco-sistema, win:disco-usb, win:computador, win:inicio, win:rede, win:servidor,
    # win:galeria, win:lixeira, win:cofre
    @staticmethod
    def _win(chave, lado):
        img = QImage(lado, lado, QImage.Format_ARGB32)
        img.fill(Qt.transparent)
        p = QPainter(img)
        p.setRenderHint(QPainter.Antialiasing, True)
        u = lado / 96.0
        nome = chave[4:]

        def r(x, y, w, h):
            return QRectF(x * u, y * u, w * u, h * u)

        def pasta(cor_tras='#E0A526', cor1='#FFD866', cor2='#F5B524'):
            # aba de trás
            caminho = QPainterPath()
            caminho.moveTo(8 * u, 22 * u)
            caminho.quadTo(8 * u, 16 * u, 14 * u, 16 * u)
            caminho.lineTo(36 * u, 16 * u)
            caminho.lineTo(44 * u, 24 * u)
            caminho.lineTo(82 * u, 24 * u)
            caminho.quadTo(88 * u, 24 * u, 88 * u, 30 * u)
            caminho.lineTo(88 * u, 74 * u)
            caminho.quadTo(88 * u, 80 * u, 82 * u, 80 * u)
            caminho.lineTo(14 * u, 80 * u)
            caminho.quadTo(8 * u, 80 * u, 8 * u, 74 * u)
            caminho.closeSubpath()
            p.setPen(Qt.NoPen)
            p.setBrush(QColor(cor_tras))
            p.drawPath(caminho)
            # frente
            g = QLinearGradient(0, 32 * u, 0, 82 * u)
            g.setColorAt(0, QColor(cor1))
            g.setColorAt(1, QColor(cor2))
            p.setBrush(g)
            p.drawRoundedRect(r(8, 33, 80, 49), 6 * u, 6 * u)
            # brilho no topo da frente
            p.setBrush(QColor(255, 255, 255, 70))
            p.drawRoundedRect(r(8, 33, 80, 3), 1.5 * u, 1.5 * u)

        def selo(cor):
            p.setPen(Qt.NoPen)
            p.setBrush(QColor(cor))
            p.drawRoundedRect(r(50, 50, 36, 36), 8 * u, 8 * u)
            pena = QPen(QColor('white'))
            pena.setWidthF(3.2 * u)
            pena.setCapStyle(Qt.RoundCap)
            pena.setJoinStyle(Qt.RoundJoin)
            p.setPen(pena)
            p.setBrush(Qt.NoBrush)
            return pena

        def unidade(cor_topo='#D9D9D9', cor_base='#9A9A9A', luz='#3BD16F', logo=False, usb=False):
            p.setPen(Qt.NoPen)
            g = QLinearGradient(0, 30 * u, 0, 72 * u)
            g.setColorAt(0, QColor(cor_topo))
            g.setColorAt(1, QColor(cor_base))
            p.setBrush(g)
            p.drawRoundedRect(r(8, 34, 80, 34), 7 * u, 7 * u)
            p.setBrush(QColor(0, 0, 0, 60))
            p.drawRoundedRect(r(8, 58, 80, 10), 4 * u, 4 * u)
            p.setBrush(QColor(luz))
            p.drawEllipse(r(74, 60, 6, 6))
            if logo:                    # a estrela do CarinaeOS no disco do sistema
                cx, cy, t = 26 * u, 46 * u, 8 * u
                est = QPainterPath()
                est.moveTo(cx, cy - t)
                est.quadTo(cx, cy, cx + t, cy)
                est.quadTo(cx, cy, cx, cy + t)
                est.quadTo(cx, cy, cx - t, cy)
                est.quadTo(cx, cy, cx, cy - t)
                p.setBrush(QColor('#7a5cff'))
                p.drawPath(est)
            if usb:
                p.setBrush(QColor('#6d6d6d'))
                p.drawRoundedRect(r(36, 22, 24, 14), 2 * u, 2 * u)

        if nome.startswith('pasta'):
            tipo = nome[6:]
            if tipo == 'rede':
                pasta('#3E7CC9', '#7DB7F5', '#4A90E2')
            else:
                pasta()
            if tipo == 'documentos':
                pena = selo('#2B7CD3')
                for y in (60, 67, 74):
                    p.drawLine(QPointF(58 * u, y * u), QPointF(78 * u, y * u))
            elif tipo == 'imagens':
                selo('#1F9BDE')
                p.setPen(Qt.NoPen)
                p.setBrush(QColor('white'))
                mont = QPainterPath()
                mont.moveTo(55 * u, 80 * u)
                mont.lineTo(65 * u, 64 * u)
                mont.lineTo(72 * u, 73 * u)
                mont.lineTo(75 * u, 69 * u)
                mont.lineTo(82 * u, 80 * u)
                mont.closeSubpath()
                p.drawPath(mont)
                p.drawEllipse(r(73, 56, 6, 6))
            elif tipo == 'transferencias':
                selo('#2DA44E')
                p.drawLine(QPointF(68 * u, 57 * u), QPointF(68 * u, 75 * u))
                p.drawLine(QPointF(61 * u, 68 * u), QPointF(68 * u, 75 * u))
                p.drawLine(QPointF(75 * u, 68 * u), QPointF(68 * u, 75 * u))
                p.drawLine(QPointF(59 * u, 80 * u), QPointF(77 * u, 80 * u))
            elif tipo == 'musica':
                selo('#E8590C')
                p.drawLine(QPointF(64 * u, 76 * u), QPointF(64 * u, 58 * u))
                p.drawLine(QPointF(64 * u, 58 * u), QPointF(76 * u, 56 * u))
                p.drawLine(QPointF(76 * u, 56 * u), QPointF(76 * u, 73 * u))
                p.setPen(Qt.NoPen)
                p.setBrush(QColor('white'))
                p.drawEllipse(r(57, 72, 8, 7))
                p.drawEllipse(r(69, 69, 8, 7))
            elif tipo == 'videos':
                selo('#8E44CF')
                p.setPen(Qt.NoPen)
                p.setBrush(QColor('white'))
                tri = QPainterPath()
                tri.moveTo(62 * u, 59 * u)
                tri.lineTo(78 * u, 68 * u)
                tri.lineTo(62 * u, 77 * u)
                tri.closeSubpath()
                p.drawPath(tri)
            elif tipo == 'trabalho':
                selo('#2B7CD3')
                p.drawRoundedRect(r(57, 58, 22, 15), 2 * u, 2 * u)
                p.drawLine(QPointF(63 * u, 79 * u), QPointF(73 * u, 79 * u))
        elif nome in ('disco', 'disco-sistema', 'disco-usb'):
            unidade(logo=(nome == 'disco-sistema'), usb=(nome == 'disco-usb'))
        elif nome == 'disco-rede':
            unidade(luz='#4A90E2')
            pena = QPen(QColor('#4A90E2'))
            pena.setWidthF(4 * u)
            p.setPen(pena)
            p.drawLine(QPointF(48 * u, 68 * u), QPointF(48 * u, 84 * u))
            p.drawLine(QPointF(30 * u, 84 * u), QPointF(66 * u, 84 * u))
        elif nome == 'computador':
            p.setPen(Qt.NoPen)
            p.setBrush(QColor('#4A4A4A'))
            p.drawRoundedRect(r(10, 16, 76, 52), 6 * u, 6 * u)
            g = QLinearGradient(0, 20 * u, 0, 64 * u)
            g.setColorAt(0, QColor('#5AB3FF'))
            g.setColorAt(1, QColor('#2563C9'))
            p.setBrush(g)
            p.drawRoundedRect(r(15, 21, 66, 42), 3 * u, 3 * u)
            p.setBrush(QColor('#8A8A8A'))
            p.drawRect(r(42, 68, 12, 10))
            p.drawRoundedRect(r(28, 78, 40, 5), 2 * u, 2 * u)
        elif nome == 'inicio':
            p.setPen(Qt.NoPen)
            p.setBrush(QColor('#4A90E2'))
            casa = QPainterPath()
            casa.moveTo(48 * u, 14 * u)
            casa.lineTo(86 * u, 46 * u)
            casa.lineTo(78 * u, 46 * u)
            casa.lineTo(78 * u, 82 * u)
            casa.lineTo(18 * u, 82 * u)
            casa.lineTo(18 * u, 46 * u)
            casa.lineTo(10 * u, 46 * u)
            casa.closeSubpath()
            p.drawPath(casa)
            p.setBrush(QColor('#FFD866'))
            p.drawRoundedRect(r(40, 56, 16, 26), 2 * u, 2 * u)
        elif nome in ('rede', 'servidor'):
            if nome == 'servidor':
                p.setPen(Qt.NoPen)
                for y in (16, 40, 64):
                    p.setBrush(QColor('#5F6B7A'))
                    p.drawRoundedRect(r(16, y, 64, 18), 4 * u, 4 * u)
                    p.setBrush(QColor('#3BD16F'))
                    p.drawEllipse(r(66, y + 6, 6, 6))
            else:
                pena = QPen(QColor('#4A90E2'))
                pena.setWidthF(5 * u)
                p.setPen(pena)
                p.setBrush(QColor(74, 144, 226, 50))
                p.drawEllipse(r(14, 14, 68, 68))
                p.setBrush(Qt.NoBrush)
                p.drawEllipse(r(32, 14, 32, 68))
                p.drawLine(QPointF(14 * u, 48 * u), QPointF(82 * u, 48 * u))
                p.drawLine(QPointF(20 * u, 31 * u), QPointF(76 * u, 31 * u))
                p.drawLine(QPointF(20 * u, 65 * u), QPointF(76 * u, 65 * u))
        elif nome == 'galeria':
            p.setPen(Qt.NoPen)
            p.setBrush(QColor('#1F9BDE'))
            p.drawRoundedRect(r(22, 14, 62, 50), 6 * u, 6 * u)
            p.setBrush(QColor('#7CC8F2'))
            p.drawRoundedRect(r(12, 30, 62, 50), 6 * u, 6 * u)
            p.setBrush(QColor('white'))
            mont = QPainterPath()
            mont.moveTo(18 * u, 74 * u)
            mont.lineTo(36 * u, 52 * u)
            mont.lineTo(48 * u, 64 * u)
            mont.lineTo(54 * u, 58 * u)
            mont.lineTo(68 * u, 74 * u)
            mont.closeSubpath()
            p.drawPath(mont)
        elif nome == 'lixeira':
            p.setPen(Qt.NoPen)
            p.setBrush(QColor('#9FB7CC'))
            p.drawRoundedRect(r(24, 26, 48, 58), 6 * u, 6 * u)
            p.setBrush(QColor('#7F97AC'))
            p.drawRoundedRect(r(18, 18, 60, 9), 3 * u, 3 * u)
            p.drawRoundedRect(r(40, 12, 16, 8), 2 * u, 2 * u)
        elif nome == 'ficheiro':
            pag = QPainterPath()
            pag.moveTo(22 * u, 10 * u)
            pag.lineTo(58 * u, 10 * u)
            pag.lineTo(76 * u, 28 * u)
            pag.lineTo(76 * u, 86 * u)
            pag.lineTo(22 * u, 86 * u)
            pag.closeSubpath()
            p.setPen(QPen(QColor('#9a9a9a'), 2 * u))
            p.setBrush(QColor('#fbfbfb'))
            p.drawPath(pag)
            dobra = QPainterPath()
            dobra.moveTo(58 * u, 10 * u)
            dobra.lineTo(58 * u, 28 * u)
            dobra.lineTo(76 * u, 28 * u)
            p.setBrush(QColor('#e3e3e3'))
            p.drawPath(dobra)
        elif nome == 'cofre':
            p.end()
            return Icones._cadeado(lado, '#E0A526')
        p.end()
        return img

    def requestImage(self, nome, tamanho, pedido):
        # desenhar grande e deixar o QML reduzir: nítido a 14 px e a 76 px
        lado = 96
        chave = nome.split('/')[0].split('?')[0]
        if chave.startswith('win:'):
            return self._win(chave, 192)

        # cadeado desenhado aqui (os temas não têm um fiável)
        if chave == 'cadeado':
            return self._cadeado(lado, '#c9a227')

        # etiqueta: "etq:COR:ICONE" -> ícone pintado com a cor da etiqueta
        if chave.startswith('etq:'):
            partes = chave.split(':')
            cor = '#' + (partes[1] if len(partes) > 1 else '888888')
            base = partes[2] if len(partes) > 2 and partes[2] else 'folder'
            ic = self._icone_base(base)
            if ic.isNull():
                return self._ponto(cor, lado)
            pix = ic.pixmap(QSize(lado, lado))
            if pix.isNull():
                return self._ponto(cor, lado)
            return self._tingir(pix.toImage().convertToFormat(QImage.Format_ARGB32), QColor(cor))

        ic = self._icone_base(chave)
        if ic.isNull():
            return self._win('win:ficheiro', 192)
        pix = ic.pixmap(QSize(lado, lado))
        img = pix.toImage()
        if img.isNull() or img.width() == 0:
            return QImage()
        mascara = img.convertToFormat(QImage.Format_ARGB32)
        if self._escuro_demais(mascara):
            img = self._tingir(mascara, QColor(self.TINTA))
        elif pedido.isValid() and (pedido.width() != img.width() or pedido.height() != img.height()):
            img = mascara.scaled(pedido, Qt.KeepAspectRatio, Qt.SmoothTransformation)
        else:
            img = mascara
        return img


CAB_PASTA = b'CARINAEOS-PASTA1'
CAB_ARQUI = b'CARINAEOS-ARQUI1'


class Miniaturas(QQuickImageProvider):
    """Miniaturas reais de fotos (e de vídeos, se houver ffmpegthumbnailer)."""
    LADO = 200

    def __init__(self):
        super().__init__(QQuickImageProvider.Image)
        base = os.environ.get('XDG_CACHE_HOME') or os.path.join(HOME, '.cache')
        self.dir = os.path.join(base, 'carinaeos/miniaturas')
        try:
            os.makedirs(self.dir, exist_ok=True)
        except OSError:
            self.dir = ''

    def _gerar(self, caminho):
        ext = os.path.splitext(caminho)[1].lower()
        if ext in IMAGENS:
            leitor = QImageReader(caminho)
            leitor.setAutoTransform(True)
            tam = leitor.size()
            if tam.isValid():
                leitor.setScaledSize(tam.scaled(QSize(self.LADO, self.LADO), Qt.KeepAspectRatio))
            return leitor.read()
        if ext in VIDEOS:
            return self._do_video(caminho)
        return QImage()

    def _do_video(self, caminho):
        if not shutil.which('ffmpegthumbnailer'):
            return QImage()
        destino = os.path.join(self.dir, 'v.tmp.png')
        try:
            subprocess.run(['ffmpegthumbnailer', '-i', caminho, '-s', str(self.LADO),
                            '-o', destino], capture_output=True, timeout=30)
            return QImage(destino)
        except Exception:
            return QImage()

    def requestImage(self, ident, tamanho, pedido):
        import hashlib
        import urllib.parse
        caminho = urllib.parse.unquote(ident)
        if not self.dir or not os.path.isfile(caminho):
            return QImage()
        try:
            st = os.stat(caminho)
        except OSError:
            return QImage()
        chave = hashlib.md5(('%s|%d|%d' % (caminho, st.st_mtime_ns, st.st_size)).encode()).hexdigest()
        cache = os.path.join(self.dir, chave + '.png')
        if not os.path.exists(cache):
            img = self._gerar(caminho)
            if img.isNull():
                return QImage()
            img.save(cache)
        return QImage(cache)


class Arquivos(QObject):
    mudou = Signal()
    caminhoMudou = Signal()
    aviso = Signal(str)
    temaMudou = Signal()
    pedeSenha = Signal(int, str)
    sistemaMudou = Signal()
    velocidadePronta = Signal(str)

    def __init__(self):
        super().__init__()
        self._caminho = HOME
        self._itens = []
        self._filtro = ""
        self._historico = []
        self._pos = -1
        self._etq = self._ler_etiquetas()
        self._locais, self._etiquetas, self._discos = self._ler_locais()
        self._cfg = os.path.join(HOME, '.config/carinaeos/arquivos.json')
        self._modo = 'detalhes'
        self._escuro, self._versao = self._ler_cfg()
        self._ordem = 'nome'
        self._crescente = True
        self._ocultos = False
        self._selecao = []
        self._redes = self._ler_redes()
        self._sistema = dict(volume=0.0, mudo=False, redeLigada=False, redeTexto='—',
                             redeTipo='ethernet', wifi=False, velocidade='')
        self._copiados = []
        self._recortados = False
        self._iniciar_win()
        self.entrar('carinae:inicio')

    # ---- aparência (claro/escuro) -------------------------------------------
    def _ler_cfg(self):
        try:
            with open(self._cfg, encoding='utf-8') as f:
                d = json.load(f)
            escuro = d.get('tema', 'escuro') != 'claro'
        except Exception:
            escuro = True
        Icones.TINTA = '#e8e8ea' if escuro else '#3a3a3a'
        try:
            with open(self._cfg, encoding='utf-8') as f:
                self._modo = json.load(f).get('modo', 'detalhes')
        except Exception:
            self._modo = 'detalhes'
        return escuro, (1 if escuro else 0)

    def _gravar_cfg(self):
        try:
            os.makedirs(os.path.dirname(self._cfg), exist_ok=True)
            with open(self._cfg, 'w', encoding='utf-8') as f:
                json.dump({'tema': 'escuro' if self._escuro else 'claro', 'modo': self._modo,
                           'painel': getattr(self, '_painel', False)}, f)
        except Exception:
            pass

    @Property(bool, notify=temaMudou)
    def escuro(self):
        return self._escuro

    @Property(int, notify=temaMudou)
    def versaoTema(self):
        return self._versao

    @Slot()
    def alternarTema(self):
        self._escuro = not self._escuro
        self._versao += 1
        Icones.TINTA = '#e8e8ea' if self._escuro else '#3a3a3a'
        self._gravar_cfg()
        self.temaMudou.emit()

    # ---- barra lateral -------------------------------------------------------
    def _ler_locais(self):
        pastas = [
            ('Início', HOME, 'user-home'),
            ('Documentos', os.path.join(HOME, 'Documentos'), 'folder-documents'),
            ('Downloads', os.path.join(HOME, 'Downloads'), 'folder-download'),
            ('Imagens', os.path.join(HOME, 'Imagens'), 'folder-pictures'),
            ('Música', os.path.join(HOME, 'Músicas'), 'folder-music'),
            ('Vídeos', os.path.join(HOME, 'Vídeos'), 'folder-videos'),
            ('Área de trabalho', os.path.join(HOME, 'Área de trabalho'), 'user-desktop'),
        ]
        locais = [dict(nome=n, caminho=c, icone=i) for n, c, i in pastas if os.path.isdir(c)]
        etiquetas = []
        tipos = {}
        try:
            with open('/proc/mounts', encoding='utf-8', errors='replace') as f:
                for linha in f:
                    campos = linha.split()
                    if len(campos) >= 3:
                        tipos[campos[1]] = campos[2]
        except OSError:
            pass
        discos = [dict(nome='Sistema de ficheiros', caminho='/', icone='drive-harddisk',
                       ligado=True, rede=False)]
        for raiz in ('/mnt', '/media'):
            if os.path.isdir(raiz):
                for n in sorted(os.listdir(raiz)):
                    p = os.path.join(raiz, n)
                    if os.path.isdir(p) and os.path.ismount(p):
                        fs = tipos.get(p, '')
                        remoto = fs in ('cifs', 'smb3', 'nfs', 'nfs4', 'fuse.sshfs')
                        discos.append(dict(nome=n, caminho=p,
                                           icone='network-server' if remoto else 'drive-harddisk',
                                           ligado=True, rede=remoto))
        return locais, etiquetas, discos

    # ---- propriedades --------------------------------------------------------
    @Property(str, notify=caminhoMudou)
    def caminho(self):
        return self._caminho

    @Property('QVariantList', notify=mudou)
    def itens(self):
        return self._itens

    @Property(str, constant=True)
    def casa(self):
        return HOME

    @Property('QVariantList', notify=mudou)
    def lateral(self):
        """Barra lateral inteira numa lista (títulos + itens), para rolar como um todo."""
        saida = [dict(titulo='Acesso rápido')]
        saida += [dict(nome=l['nome'], caminho=l['caminho'], icone=l['icone']) for l in self._locais]
        saida.append(dict(titulo='Cofre'))
        saida.append(dict(nome='Cofre', cofre=True, caminho='', icone='cadeado',
                          temCoisas=os.path.isdir(self.COFRE) and bool(os.listdir(self.COFRE))
                          if os.path.isdir(self.COFRE) else False))
        if self._etq:
            saida += [dict(titulo='Etiquetas')]
            for i, e in enumerate(self._etq):
                cor = (e.get('cor') or '#95a5a6').lstrip('#')
                saida.append(dict(nome=e['nome'], caminho=self._pasta_etq(e['nome']),
                                  icone='etq:%s:%s' % (cor, e.get('icone') or 'folder'),
                                  etiqueta=True, etqIndice=i))
        saida.append(dict(nome='Nova etiqueta…', acao='novaEtiqueta', icone='list-add'))
        saida += [dict(titulo='Rede')]
        if True:
            for i, r in enumerate(self._redes):
                ponto = self._ponto_gvfs(r.get('url', ''))
                ligado = bool(ponto) and os.path.isdir(ponto)
                saida.append(dict(nome=r.get('nome') or r['url'], rede=True, redeIndice=i,
                                  caminho=ponto if ligado else '',
                                  url=r.get('url', ''), ligado=ligado,
                                  icone='network-server' if ligado else 'folder-remote'))
        saida.append(dict(nome='Adicionar servidor…', acao='adicionarRede', icone='list-add'))
        saida += [dict(titulo='Este computador')]
        saida += [dict(nome=l['nome'], caminho=l['caminho'], icone=l['icone'],
                       ligado=l.get('ligado', False), rede=l.get('rede', False)) for l in self._discos]
        return saida

    @Property('QVariantList', constant=True)
    def locais(self):
        return self._locais

    @Property('QVariantList', constant=True)
    def etiquetas(self):
        return self._etiquetas

    @Property('QVariantList', constant=True)
    def discos(self):
        return self._discos

    @Property(bool, notify=mudou)
    def podeVoltar(self):
        return self._pos > 0

    @Property(bool, notify=mudou)
    def podeAvancar(self):
        return self._pos < len(self._historico) - 1

    @Property(str, notify=mudou)
    def resumo(self):
        n = len(self._itens)
        return "%d item" % n if n == 1 else "%d itens" % n

    # ---- navegação -----------------------------------------------------------
    @Slot(str)
    def entrar(self, caminho):
        caminho = (caminho or HOME).strip()
        if caminho.startswith('smb://') or caminho.startswith('\\\\'):
            url = self._para_smb(caminho)
            ponto = self._ponto_gvfs(url)
            if ponto and os.path.isdir(ponto):
                caminho = ponto
            else:
                partes = [x for x in url[6:].split('/') if x]
                if len(partes) == 1:
                    self.explorarServidor(partes[0], '', '', '')
                else:
                    self.mapearRede(url, '', '', '', '', False)
                return
        if caminho.startswith('carinae:'):
            if caminho not in self.PAGINAS:
                return
            self._caminho = caminho
            self._filtro = ''
            self._selecao = []
            if self._historico[self._pos:self._pos + 1] != [caminho]:
                self._historico = self._historico[:self._pos + 1] + [caminho]
                self._pos = len(self._historico) - 1
            self._listar()
            self.caminhoMudou.emit()
            return
        caminho = os.path.abspath(os.path.expanduser(caminho))
        if not os.path.isdir(caminho):
            self.aviso.emit("Não consigo abrir: %s" % caminho)
            return
        self._caminho = caminho
        self._filtro = ""
        self._selecao = []
        if self._historico[self._pos:self._pos + 1] != [caminho]:
            self._historico = self._historico[:self._pos + 1] + [caminho]
            self._pos = len(self._historico) - 1
        self._listar()
        self.caminhoMudou.emit()

    @Slot()
    def voltar(self):
        if self._pos > 0:
            self._pos -= 1
            self._caminho = self._historico[self._pos]
            self._listar()
            self.caminhoMudou.emit()

    @Slot()
    def avancar(self):
        if self._pos < len(self._historico) - 1:
            self._pos += 1
            self._caminho = self._historico[self._pos]
            self._listar()
            self.caminhoMudou.emit()

    @Slot()
    def subir(self):
        c = self._caminho
        if c.startswith('carinae:'):
            if c != 'carinae:inicio':
                self.entrar('carinae:inicio')
            return
        m = self.migalhas
        if len(m) >= 2:
            self.entrar(m[-2]['caminho'])
        elif c != '/':
            self.entrar(os.path.dirname(c.rstrip('/')) or '/')
        else:
            self.entrar('carinae:computador')

    @Slot()
    def recarregar(self):
        self._listar()

    @Slot(str)
    def filtrar(self, texto):
        self._filtro = (texto or '').strip().lower()
        self._listar()

    def _listar(self):
        if self._caminho.startswith('carinae:'):
            if self._caminho not in ('carinae:pesquisa', 'carinae:galeria', 'carinae:servidor'):
                self._itens = []
            self._carregar_pagina()
            self.mudou.emit()
            return
        # manter o Cofre em dia mesmo que o desbloqueio tenha sido feito noutro programa
        try:
            self._sincronizar_cofre()
        except Exception:
            pass
        itens = []
        try:
            nomes = sorted(os.listdir(self._caminho),
                           key=lambda n: (not os.path.isdir(os.path.join(self._caminho, n)), n.lower()))
        except PermissionError:
            self.aviso.emit("Sem permissão para ler esta pasta")
            nomes = []
        for nome in nomes:
            if nome.startswith('.') and not self._ocultos:
                continue          # ocultos: só com Ctrl+H
            if self._filtro and self._filtro not in nome.lower():
                continue
            p = os.path.join(self._caminho, nome)
            try:
                pasta = os.path.isdir(p)
                st = os.stat(p)
            except OSError:
                continue
            trancado = self._esta_trancado(p)
            if trancado and not pasta:
                try:
                    with open(p, 'rb') as f:
                        pasta = f.read(16).startswith(CAB_PASTA)
                except OSError:
                    pass
            itens.append(dict(
                nome=(nome[:-len('.trancado')] if trancado and nome.endswith('.trancado') else nome),
                caminho=p,
                pasta=pasta,
                icone=icone_de(p, pasta),
                tipo=nome_tipo(p, pasta),
                tamanho='' if pasta else tamanho_legivel(st.st_size),
                tamanhoNum=0 if pasta else st.st_size,
                data=time.strftime('%d/%m/%Y %H:%M', time.localtime(st.st_mtime)),
                dataNum=st.st_mtime,
                miniatura=(not pasta) and os.path.splitext(nome)[1].lower() in (IMAGENS | VIDEOS),
                video=os.path.splitext(nome)[1].lower() in VIDEOS,
                trancado=trancado,
                etiquetas=self._tags_do_item(p),
            ))
        if self._ordem == 'tamanho':
            itens.sort(key=lambda i: i['tamanhoNum'], reverse=not self._crescente)
        elif self._ordem == 'data':
            itens.sort(key=lambda i: i['dataNum'], reverse=not self._crescente)
        elif self._ordem == 'tipo':
            itens.sort(key=lambda i: (i['tipo'].lower(), i['nome'].lower()), reverse=not self._crescente)
        else:
            itens.sort(key=lambda i: (not i['pasta'], i['nome'].lower()), reverse=not self._crescente)
        self._itens = itens
        if self._selecao:
            self._selecao = [i for i in self._selecao if i < len(itens)]
        self.mudou.emit()

    # ---- etiquetas (nome, cor e ícone próprios) --------------------------------
    ETQ_CFG = os.path.join(HOME, '.config/carinaeos/arquivos-etiquetas.json')
    CORES_ETQ_PADRAO = [('Vermelho', '#e74c3c'), ('Laranja', '#e67e22'), ('Amarelo', '#f1c40f'),
                        ('Verde', '#2ecc71'), ('Azul', '#3498db'), ('Roxo', '#9b59b6'),
                        ('Cinzento', '#95a5a6')]

    def _ler_etiquetas(self):
        try:
            with open(self.ETQ_CFG, encoding='utf-8') as f:
                dados = json.load(f)
            if isinstance(dados, list):
                return [e for e in dados if isinstance(e, dict) and e.get('nome')]
        except Exception:
            pass
        # primeira vez: parte das pastas que já existem em ~/Etiquetas
        saida = []
        pasta = os.path.join(HOME, 'Etiquetas')
        cores = dict(self.CORES_ETQ_PADRAO)
        if os.path.isdir(pasta):
            for n in sorted(os.listdir(pasta)):
                if os.path.isdir(os.path.join(pasta, n)):
                    saida.append(dict(nome=n, cor=cores.get(n, '#95a5a6'), icone='folder'))
        return saida

    def _gravar_etiquetas(self):
        try:
            os.makedirs(os.path.dirname(self.ETQ_CFG), exist_ok=True)
            with open(self.ETQ_CFG, 'w', encoding='utf-8') as f:
                json.dump(self._etq, f, ensure_ascii=False, indent=1)
        except Exception:
            pass

    def _pasta_etq(self, nome):
        return os.path.join(HOME, 'Etiquetas', nome)

    @Property('QVariantList', notify=mudou)
    def etiquetas(self):
        return [dict(nome=e['nome'], cor=e.get('cor', '#95a5a6'), icone=e.get('icone', 'folder'),
                     caminho=self._pasta_etq(e['nome'])) for e in self._etq]

    @Slot(str, str, str)
    def criarEtiqueta(self, nome, cor, icone):
        nome = (nome or '').strip()
        if not nome:
            self.aviso.emit('A etiqueta precisa de um nome')
            return
        if any(e['nome'].lower() == nome.lower() for e in self._etq):
            self.aviso.emit('Já existe uma etiqueta com esse nome')
            return
        try:
            os.makedirs(self._pasta_etq(nome), exist_ok=True)
        except OSError:
            pass
        self._etq.append(dict(nome=nome, cor=cor or '#95a5a6', icone=icone or 'folder'))
        self._gravar_etiquetas()
        self.mudou.emit()
        self.aviso.emit('Etiqueta criada: %s' % nome)

    @Slot(int, str, str, str)
    def mudarEtiqueta(self, indice, nome, cor, icone):
        if not (0 <= indice < len(self._etq)):
            return
        antigo = self._etq[indice]['nome']
        novo = (nome or '').strip() or antigo
        if novo != antigo:
            if any(e['nome'].lower() == novo.lower() for e in self._etq):
                self.aviso.emit('Já existe uma etiqueta com esse nome')
                return
            try:
                origem, destino = self._pasta_etq(antigo), self._pasta_etq(novo)
                if os.path.isdir(origem):
                    os.rename(origem, destino)
            except OSError as e:
                self.aviso.emit('Não consegui renomear a pasta: %s' % e.strerror)
        self._etq[indice] = dict(nome=novo, cor=cor or self._etq[indice].get('cor', '#95a5a6'),
                                 icone=icone or self._etq[indice].get('icone', 'folder'))
        self._gravar_etiquetas()
        self.mudou.emit()
        self.aviso.emit('Etiqueta atualizada: %s' % novo)

    @Slot(int)
    def removerEtiqueta(self, indice):
        if not (0 <= indice < len(self._etq)):
            return
        nome = self._etq.pop(indice)['nome']
        self._gravar_etiquetas()
        self.mudou.emit()
        self.aviso.emit('Etiqueta removida da lista: %s (a pasta ficou)' % nome)

    # ---- etiquetar ficheiros e pastas -----------------------------------------
    def _link_etq(self, nome_etq, caminho):
        pasta = self._pasta_etq(nome_etq)
        try:
            os.makedirs(pasta, exist_ok=True)
            destino = os.path.join(pasta, os.path.basename(caminho))
            if not os.path.lexists(destino):
                os.symlink(caminho, destino)
        except OSError:
            pass

    @Slot(int, int)
    def etiquetar(self, indice, etqIndice):
        if not (0 <= indice < len(self._itens)) or not (0 <= etqIndice < len(self._etq)):
            return
        caminho = self._itens[indice]['caminho']
        nome = self._etq[etqIndice]['nome']
        try:
            atuais = os.getxattr(caminho, 'user.xdg.tags').decode().split(',')
            atuais = [a for a in atuais if a]
        except Exception:
            atuais = []
        if nome not in atuais:
            atuais.append(nome)
        try:
            os.setxattr(caminho, 'user.xdg.tags', ','.join(atuais).encode())
        except Exception:
            pass   # em NTFS/exFAT não há xattrs: a ligação na pasta da etiqueta resolve
        self._link_etq(nome, caminho)
        self.aviso.emit('Etiquetado: %s → %s' % (os.path.basename(caminho), nome))

    @Slot(int)
    def removerEtiquetasDoItem(self, indice):
        if not (0 <= indice < len(self._itens)):
            return
        caminho = self._itens[indice]['caminho']
        try:
            os.removexattr(caminho, 'user.xdg.tags')
        except Exception:
            pass
        for e in self._etq:
            lig = os.path.join(self._pasta_etq(e['nome']), os.path.basename(caminho))
            if os.path.islink(lig):
                try:
                    os.unlink(lig)
                except OSError:
                    pass
        self.aviso.emit('Etiquetas removidas de %s' % os.path.basename(caminho))

    # ---- Cofre: tudo o que está trancado, num só lugar ------------------------
    COFRE = os.path.join(os.environ.get('XDG_DATA_HOME', os.path.join(HOME, '.local/share')),
                         'carinaeos/cofre')
    COFRE_JSON = os.path.join(os.environ.get('XDG_DATA_HOME', os.path.join(HOME, '.local/share')),
                              'carinaeos/cofre.json')

    def _ler_cofre(self):
        try:
            with open(self.COFRE_JSON, encoding='utf-8') as f:
                d = json.load(f)
            return d if isinstance(d, dict) else {}
        except Exception:
            return {}

    def _gravar_cofre(self, d):
        try:
            os.makedirs(os.path.dirname(self.COFRE_JSON), exist_ok=True)
            with open(self.COFRE_JSON, 'w', encoding='utf-8') as f:
                json.dump(d, f, ensure_ascii=False, indent=1)
        except Exception:
            pass

    def _link_cofre(self, caminho):
        try:
            os.makedirs(self.COFRE, exist_ok=True)
            destino = os.path.join(self.COFRE, os.path.basename(caminho))
            if os.path.lexists(destino):
                return
            os.symlink(caminho, destino)
        except OSError:
            pass

    def _deslink_cofre(self, caminho):
        destino = os.path.join(self.COFRE, os.path.basename(caminho))
        try:
            if os.path.islink(destino):
                os.unlink(destino)
        except OSError:
            pass

    def _sincronizar_cofre(self):
        """O Cofre mostra exatamente o que está trancado agora."""
        d = self._ler_cofre()
        mudou = False
        for caminho in list(d.keys()):
            if not os.path.exists(caminho) or not self._esta_trancado(caminho):
                self._deslink_cofre(caminho)
                # ao destrancar, as etiquetas voltam ao original
                info = d.pop(caminho, {}) or {}
                alvo = caminho
                if os.path.exists(alvo) and info.get('tags'):
                    try:
                        os.setxattr(alvo, 'user.xdg.tags', ','.join(info['tags']).encode())
                    except Exception:
                        pass
                    for nome in info['tags']:
                        self._link_etq(nome, alvo)
                mudou = True
            else:
                self._link_cofre(caminho)
        if mudou:
            self._gravar_cofre(d)
        return d

    @Slot()
    def abrirCofre(self):
        """O Cofre é sempre fechado: pede a senha (fora da interface) antes de abrir."""
        import threading

        def pedir():
            try:
                r = subprocess.run(['carinaeos-cadeado', 'verificar', 'Cofre do CarinaeOS',
                                    'Esta pasta está protegida. Escreve a senha para entrar.'],
                                   capture_output=True, timeout=300)
                ok = r.returncode == 0
            except Exception:
                ok = False
            if ok:
                QMetaObject.invokeMethod(self, '_entrarNoCofre', Qt.QueuedConnection)
            else:
                QMetaObject.invokeMethod(self, '_cofreFechado', Qt.QueuedConnection)

        threading.Thread(target=pedir, daemon=True).start()

    @Slot()
    def _cofreFechado(self):
        self.aviso.emit('Cofre fechado')

    @Slot()
    def _entrarNoCofre(self):
        self._sincronizar_cofre()
        try:
            os.makedirs(self.COFRE, exist_ok=True)
        except OSError:
            pass
        self.entrar(self.COFRE)

    def _registar_no_cofre(self, caminho, trancar, tags=None):
        d = self._ler_cofre()
        if trancar:
            info = dict(tags=tags if tags is not None
                        else [e['nome'] for e in self._tags_do_item(caminho)])
            d[caminho] = info
            self._link_cofre(caminho)
            # as ligações nas pastas das etiquetas saem: o item passou a cofre
            for e in self._etq:
                lig = os.path.join(self._pasta_etq(e['nome']), os.path.basename(caminho))
                if os.path.islink(lig):
                    try:
                        os.unlink(lig)
                    except OSError:
                        pass
        else:
            d.pop(caminho, None)
            self._deslink_cofre(caminho)
        self._gravar_cofre(d)

    @Slot()
    def _recarregarSeguro(self):
        self._sincronizar_cofre()
        self._listar()

    @Slot(int)
    def tirarDoCofre(self, indice):
        """Tira um item do Cofre: atalho é apagado; pasta real é devolvida aos Documentos."""
        if not (0 <= indice < len(self._itens)):
            return
        origem = self._itens[indice]['caminho']
        if not os.path.abspath(origem).startswith(os.path.abspath(self.COFRE)):
            return
        nome = os.path.basename(origem.rstrip('/'))
        if os.path.islink(origem):
            try:
                os.unlink(origem)
            except OSError:
                pass
            self._gravar_cofre({k: v for k, v in self._ler_cofre().items()
                                if os.path.basename(k) != nome})
            self.aviso.emit('Atalho retirado do Cofre')
        else:
            destino_base = os.path.join(HOME, 'Documentos')
            try:
                os.makedirs(destino_base, exist_ok=True)
            except OSError:
                destino_base = HOME
            destino, n = os.path.join(destino_base, nome), 1
            while os.path.exists(destino):
                n += 1
                destino = os.path.join(destino_base, '%s (%d)' % (nome, n))
            try:
                shutil.move(origem, destino)
                self.aviso.emit('Retirado do Cofre para %s' % destino)
            except OSError as e:
                self.aviso.emit('Não consegui mover: %s' % e.strerror)
        self._listar()

    # ---- bloquear com senha (carinaeos-cadeado) --------------------------------
    @Slot(int, bool)
    def bloquear(self, indice, trancar):
        import threading
        if not (0 <= indice < len(self._itens)):
            return
        caminho = self._itens[indice]['caminho']
        # dentro do Cofre o item é um atalho: a operação tem de ir ao original
        if os.path.islink(caminho):
            real = os.path.realpath(caminho)
            if os.path.exists(real):
                caminho = real
        acao = 'trancar' if trancar else 'abrir'
        # as etiquetas têm de ser lidas ANTES de trancar (o contentor perde os atributos)
        etiquetas_antes = [e['nome'] for e in self._tags_do_item(caminho)] if trancar else []
        self.aviso.emit(('A trancar' if trancar else 'A abrir') + ': ' + os.path.basename(caminho))

        def trabalhar():
            try:
                subprocess.run(['carinaeos-cadeado', acao, caminho], timeout=600)
            except Exception:
                pass
            # registar no cofre (antes: guarda as etiquetas para as devolver)
            try:
                if trancar and os.path.exists(caminho):
                    self._registar_no_cofre(caminho, True, etiquetas_antes)
                elif not trancar:
                    self._registar_no_cofre(caminho, False)
            except Exception:
                pass
            QMetaObject.invokeMethod(self, '_recarregarSeguro', Qt.QueuedConnection)

        threading.Thread(target=trabalhar, daemon=True).start()

    @Slot(int, result=bool)
    def estaTrancado(self, indice):
        if not (0 <= indice < len(self._itens)):
            return False
        nome = self._itens[indice]['nome']
        return nome.endswith('.trancado') or os.path.isfile(os.path.join(self._caminho, '.' + nome + '.trancado'))

    # ---- rede (SMB) -----------------------------------------------------------
    CFG_REDES = os.path.join(HOME, '.config/carinaeos/arquivos-redes.json')

    def _ler_redes(self):
        try:
            with open(self.CFG_REDES, encoding='utf-8') as f:
                dados = json.load(f)
            return [r for r in dados if isinstance(r, dict) and r.get('url')]
        except Exception:
            return []

    def _gravar_redes(self):
        try:
            os.makedirs(os.path.dirname(self.CFG_REDES), exist_ok=True)
            with open(self.CFG_REDES, 'w', encoding='utf-8') as f:
                json.dump(self._redes, f, ensure_ascii=False, indent=1)
        except Exception:
            pass

    @staticmethod
    def _ponto_gvfs(url):
        """smb://user@host/share -> /run/user/1000/gvfs/smb-share:server=host,share=share"""
        try:
            sem_esquema = url.split('://', 1)[1]
            if '@' in sem_esquema:
                sem_esquema = sem_esquema.split('@', 1)[1]
            partes = [x for x in sem_esquema.split('/') if x]
            host = partes[0]
            share = partes[1] if len(partes) > 1 else ''
            base = os.path.join(os.environ.get('XDG_RUNTIME_DIR', '/run/user/1000'), 'gvfs')
            nome = 'smb-share:server=%s' % host
            if share:
                nome += ',share=%s' % share
            return os.path.join(base, nome)
        except Exception:
            return ''

    @Property('QVariantList', notify=mudou)
    def redes(self):
        saida = []
        for r in self._redes:
            ponto = self._ponto_gvfs(r.get('url', ''))
            saida.append(dict(nome=r.get('nome') or r.get('url'), url=r.get('url', ''),
                              ligado=bool(ponto) and os.path.isdir(ponto),
                              caminho=ponto if ponto and os.path.isdir(ponto) else ''))
        return saida

    @Slot(str, str)
    def adicionarRede(self, nome, url):
        url = (url or '').strip()
        if not url.startswith('smb://'):
            self.aviso.emit('O endereço deve começar por smb://')
            return
        if any(r.get('url') == url for r in self._redes):
            self.aviso.emit('Esse servidor já está na lista')
            return
        self._redes.append(dict(nome=(nome or '').strip() or url.split('/')[-1], url=url))
        self._gravar_redes()
        self.mudou.emit()
        self.aviso.emit('Servidor adicionado: %s' % url)
        self.ligarRede(len(self._redes) - 1)

    @Slot(int)
    def removerRede(self, indice):
        if 0 <= indice < len(self._redes):
            self._redes.pop(indice)
            self._gravar_redes()
            self.mudou.emit()

    @Slot(int)
    def ligarRede(self, indice):
        import threading
        if not (0 <= indice < len(self._redes)):
            return
        url = self._redes[indice]['url']
        ponto = self._ponto_gvfs(url)
        if ponto and os.path.isdir(ponto):
            self.entrar(ponto)
            return
        r = self._redes[indice]
        usuario = r.get('utilizador', '')
        if not usuario and '@' in url.split('://', 1)[1]:
            usuario = url.split('://', 1)[1].split('@', 1)[0]
        self._ligar(indice, usuario, '', r.get('dominio', ''))

    @staticmethod
    def _montar_gio(url, usuario='', senha='', dominio=''):
        """Monta a partilha com o Gio (que aceita credenciais), sem pedir a mais ninguém."""
        try:
            import gi
            gi.require_version('Gio', '2.0')
            from gi.repository import Gio, GLib
        except Exception as e:
            return False, 'Gio indisponível: %s' % e
        estado = {'ok': False, 'erro': ''}
        loop = GLib.MainLoop()
        op = Gio.MountOperation()
        if usuario:
            op.set_username(usuario)
        if dominio:
            op.set_domain(dominio)
        if senha:
            op.set_password(senha)
            op.set_password_save(Gio.PasswordSave.PERMANENTLY)
        tentativas = [0]

        def perguntar(operacao, mensagem, utilizador_padrao, dominio_padrao, bandeiras):
            tentativas[0] += 1
            # sem utilizador: tenta como convidado (anónimo); com credenciais: só uma vez (senão dava ciclo)
            if not usuario and (bandeiras & Gio.AskPasswordFlags.ANONYMOUS_SUPPORTED) and tentativas[0] == 1:
                operacao.set_anonymous(True)
                operacao.reply(Gio.MountOperationResult.HANDLED)
            elif usuario and tentativas[0] == 1:
                operacao.reply(Gio.MountOperationResult.HANDLED)
            else:
                operacao.reply(Gio.MountOperationResult.ABORTED)

        op.connect('ask-password', perguntar)

        def terminou(ficheiro, resultado):
            try:
                ficheiro.mount_enclosing_volume_finish(resultado)
                estado['ok'] = True
            except GLib.Error as e:
                # "já está montado" também é bom
                if e.matches(Gio.io_error_quark(), Gio.IOErrorEnum.ALREADY_MOUNTED):
                    estado['ok'] = True
                else:
                    estado['erro'] = e.message if tentativas[0] < 2 else 'password: ' + e.message
            loop.quit()

        Gio.File.new_for_uri(url).mount_enclosing_volume(Gio.MountMountFlags.NONE, op, None, terminou)
        GLib.timeout_add_seconds(90, lambda: (loop.quit(), False)[1])
        loop.run()
        return estado['ok'], estado['erro']

    @Slot(int, str)
    def ligarComSenha(self, indice, senha):
        import threading
        if not (0 <= indice < len(self._redes)):
            return
        url = self._redes[indice]['url']
        usuario = ''
        if '@' in url.split('://', 1)[1]:
            usuario = url.split('://', 1)[1].split('@', 1)[0]
        self.aviso.emit('A ligar…')

        def tentar():
            ok, erro = self._montar_gio(url, usuario, senha)
            QMetaObject.invokeMethod(self, '_fimLigarRede', Qt.QueuedConnection,
                                     Q_ARG(int, indice), Q_ARG(str, '' if ok else erro))

        threading.Thread(target=tentar, daemon=True).start()

    @Slot(int, str)
    def _fimLigarRede(self, indice, erro):
        if 0 <= indice < len(self._redes):
            ponto = self._ponto_gvfs(self._redes[indice]['url'])
            if ponto and os.path.isdir(ponto):
                self.entrar(ponto)
                self.mudou.emit()
                return
        baixo = (erro or '').lower()
        if any(t in baixo for t in ('password', 'senha', 'autentic', 'authentic', 'logon', 'credential',
                                    'permission denied', 'access denied', 'cancel', 'abort')):
            r = self._redes[indice]
            self.pedeCredenciais.emit('rede:%d' % indice, 'Ligar a %s' % (r.get('nome') or r['url']),
                                      r.get('utilizador', ''))
        else:
            self.aviso.emit('Não consegui ligar: %s' % (erro or 'senha ou servidor?'))
        self.mudou.emit()

    @Slot(int)
    def desligarRede(self, indice):
        if not (0 <= indice < len(self._redes)):
            return
        url = self._redes[indice]['url']
        try:
            subprocess.run(['gio', 'mount', '-u', url], capture_output=True, timeout=60)
        except Exception:
            pass
        if self._caminho.startswith('/run/user'):
            self.entrar(HOME)
        self.mudou.emit()

    # ---- selos dos itens (etiquetas e cadeado) --------------------------------
    @staticmethod
    def _esta_trancado(caminho):
        if caminho.endswith('.trancado'):
            return True
        try:
            with open(caminho, 'rb') as f:
                cab = f.read(16)
            return cab.startswith(CAB_PASTA) or cab.startswith(CAB_ARQUI)
        except OSError:
            return False

    def _tags_do_item(self, caminho):
        nomes = []
        try:
            bruto = os.getxattr(caminho, 'user.xdg.tags')
            nomes = [n for n in bruto.decode(errors='ignore').split(',') if n]
        except Exception:
            nomes = []
        if not nomes:
            # sem atributos (NTFS/exFAT): ver as ligações nas pastas das etiquetas
            base = os.path.basename(caminho)
            for e in self._etq:
                if os.path.lexists(os.path.join(self._pasta_etq(e['nome']), base)):
                    nomes.append(e['nome'])
        por_nome = {e['nome']: e for e in self._etq}
        saida = []
        for n in nomes:
            e = por_nome.get(n)
            if e:
                cor = (e.get('cor') or '#95a5a6').lstrip('#')
                saida.append(dict(nome=n, icone='etq:%s:%s' % (cor, e.get('icone') or 'folder')))
            else:
                saida.append(dict(nome=n, icone='tag'))
        return saida

    # ---- ordenação, ocultos, ocultos, seleção ---------------------------------
    @Property(str, notify=mudou)
    def modo(self):
        return self._modo

    @Slot(str)
    def definirModo(self, m):
        if m in ('detalhes', 'icones', 'medios', 'lista') and m != self._modo:
            self._modo = m
            self._gravar_cfg()
            self.mudou.emit()

    @Property(str, notify=mudou)
    def ordem(self):
        return self._ordem

    @Property(bool, notify=mudou)
    def crescente(self):
        return self._crescente

    @Property(bool, notify=mudou)
    def ocultos(self):
        return self._ocultos

    @Slot(str)
    def ordenar(self, campo):
        if campo == self._ordem:
            self._crescente = not self._crescente
        else:
            self._ordem, self._crescente = campo, True
        self._listar()

    @Slot()
    def alternarOcultos(self):
        self._ocultos = not self._ocultos
        self._listar()

    @Property('QVariantList', notify=mudou)
    def selecao(self):
        return self._selecao

    @Slot(int, bool)
    def selecionar(self, indice, alternar):
        """Clique simples (alternar=false) ou Ctrl+clique (alternar=true)."""
        if not (0 <= indice < len(self._itens)):
            return
        if alternar:
            if indice in self._selecao:
                self._selecao.remove(indice)
            else:
                self._selecao.append(indice)
        else:
            self._selecao = [indice]
        self.mudou.emit()

    @Slot(int, int)
    def selecionarIntervalo(self, de, ate):
        a, b = sorted((de, ate))
        self._selecao = list(range(max(0, a), min(len(self._itens), b + 1)))
        self.mudou.emit()

    @Slot(str)
    def selecionarPorNome(self, nome):
        for i, item in enumerate(self._itens):
            if item['nome'] == nome:
                self._selecao = [i]
                self.mudou.emit()
                return

    @Slot()
    def limparSelecao(self):
        self._selecao = []
        self.mudou.emit()

    # ---- bandeja: som, rede, wi-fi, velocidade e papéis de parede --------------
    def _cmd(self, args, timeout=4):
        try:
            r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
            return (r.stdout or '').strip()
        except Exception:
            return ''

    @Slot()
    def atualizarSistema(self):
        saida = self._cmd(['wpctl', 'get-volume', '@DEFAULT_AUDIO_SINK@'])
        vol, mudo = 0.0, False
        if saida:
            partes = saida.replace('[', '').replace(']', '').split()
            for i, x in enumerate(partes):
                if x.lower() == 'volume' and i + 1 < len(partes):
                    try:
                        vol = float(partes[i + 1])
                    except ValueError:
                        pass
            mudo = 'MUTED' in saida.upper()
        novo = dict(volume=round(vol, 2), mudo=mudo)
        if novo != self._sistema:
            self._sistema.update(novo)
            self.sistemaMudou.emit()
        # rede / wi-fi (nmcli é lento; só de vez em quando)
        import time
        agora = time.time()
        if agora - getattr(self, '_ultima_rede', 0) > 6:
            self._ultima_rede = agora
            estado = self._cmd(['nmcli', '-t', '-f', 'STATE', 'general'])
            disp = self._cmd(['nmcli', '-t', '-f', 'DEVICE,TYPE,STATE', 'device'])
            tipo = 'ethernet'
            ligado = 'connected' in estado
            if 'wifi' in disp:
                tipo = 'wifi'
            wifi = self._cmd(['nmcli', '-t', '-f', 'WIFI', 'radio'])
            novo = dict(redeLigada=ligado, redeTexto=('Ligada' if ligado else 'Desligada'),
                        redeTipo=tipo, wifi=wifi.strip().lower() == 'enabled')
            if novo != {k: self._sistema.get(k) for k in novo}:
                self._sistema.update(novo)
                self.sistemaMudou.emit()

    @Property('QVariantMap', notify=sistemaMudou)
    def sistema(self):
        return self._sistema

    @Slot(float)
    def definirVolume(self, v):
        self._cmd(['wpctl', 'set-volume', '@DEFAULT_AUDIO_SINK@', '%.2f' % max(0.0, min(1.0, v))])
        self.atualizarSistema()

    @Slot()
    def alternarMudo(self):
        self._cmd(['wpctl', 'set-mute', '@DEFAULT_AUDIO_SINK@', 'toggle'])
        self.atualizarSistema()

    @Slot()
    def alternarWifi(self):
        self._cmd(['nmcli', 'radio', 'wifi', 'on' if not self._sistema.get('wifi') else 'off'], timeout=10)
        self._ultima_rede = 0
        self.atualizarSistema()

    @Slot()
    def medirVelocidade(self):
        import threading

        def medir():
            try:
                r = subprocess.run(['curl', '-s', '-o', '/dev/null', '--max-time', '20',
                                    '-w', '%{speed_download}',
                                    'https://speed.cloudflare.com/__down?bytes=25000000'],
                                   capture_output=True, text=True, timeout=30)
                bps = float((r.stdout or '0').strip() or 0)
                mbps = bps * 8 / 1_000_000
                texto = ('%.1f Mbps' % mbps) if mbps > 0.1 else 'sem ligação'
            except Exception:
                texto = 'falhou'
            QMetaObject.invokeMethod(self, '_fimVelocidade', Qt.QueuedConnection, Q_ARG(str, texto))

        threading.Thread(target=medir, daemon=True).start()

    @Slot(str)
    def _fimVelocidade(self, texto):
        self._sistema['velocidade'] = texto
        self.sistemaMudou.emit()
        self.velocidadePronta.emit(texto)

    @Slot(result='QVariantList')
    def papeis(self):
        import glob
        saida = []
        for pasta in sorted(glob.glob('/usr/share/wallpapers/*/')):
            nome = os.path.basename(pasta.rstrip('/'))
            if nome.startswith('.'):
                continue
            imagem = ''
            for cand in ('contents/images/1920x1080.jpg', 'contents/images/3840x2160.jpg',
                         'contents/screenshot.png', 'contents/screenshot.jpg'):
                p = os.path.join(pasta, cand)
                if os.path.isfile(p):
                    imagem = p
                    break
            if imagem:
                saida.append(dict(nome=nome, imagem=imagem))
        return saida

    @Slot(str)
    def aplicarPapel(self, imagem):
        try:
            if os.environ.get('XDG_CURRENT_DESKTOP', '').startswith('CarinaeOS'):
                # a Aurora lê o papel de parede de ~/.config/carinaeos-shell.json (e vê a mudança na hora)
                cfg = os.path.join(HOME, '.config', 'carinaeos-shell.json')
                try:
                    j = json.load(open(cfg, encoding='utf-8'))
                except (OSError, ValueError):
                    j = {}
                j['papel'] = imagem
                with open(cfg + '.tmp', 'w', encoding='utf-8') as f:
                    json.dump(j, f, ensure_ascii=False, indent=1)
                os.replace(cfg + '.tmp', cfg)
            else:
                subprocess.Popen(['plasma-apply-wallpaperimage', imagem], start_new_session=True)
            self.aviso.emit('Papel de parede: %s' % os.path.basename(os.path.dirname(os.path.dirname(imagem))))
        except Exception as e:
            self.aviso.emit('Não consegui mudar o papel: %s' % e)

    # ---- abrir com… ------------------------------------------------------------
    def _mime_do_item(self, indice):
        try:
            import gi
            gi.require_version('Gio', '2.0')
            from gi.repository import Gio
            ct, _ = Gio.content_type_guess(self._itens[indice]['caminho'], None)
            return ct or 'application/octet-stream'
        except Exception:
            return 'application/octet-stream'

    @Slot(int, result='QVariantList')
    def aplicacoesPara(self, indice):
        if not (0 <= indice < len(self._itens)):
            return []
        try:
            import gi
            gi.require_version('Gio', '2.0')
            from gi.repository import Gio
        except Exception:
            return []
        mime = self._mime_do_item(indice)
        saida = []
        try:
            omissao = Gio.AppInfo.get_default_for_type(mime, False)
            if omissao is not None:
                saida.append(dict(id=omissao.get_id() or '', nome=omissao.get_display_name() or '',
                                  icone=omissao.get_icon().to_string() if omissao.get_icon() else '',
                                  predefinida=True))
            for a in Gio.AppInfo.get_all_for_type(mime):
                if omissao is not None and a.get_id() == omissao.get_id():
                    continue
                saida.append(dict(id=a.get_id() or '', nome=a.get_display_name() or '',
                                  icone=a.get_icon().to_string() if a.get_icon() else '',
                                  predefinida=False))
        except Exception as e:
            self.aviso.emit('Não consegui listar os programas: %s' % e)
        return saida

    @Slot(int, str, bool)
    def abrirCom(self, indice, app_id, usar_sempre):
        if not (0 <= indice < len(self._itens)):
            return
        caminho = self._itens[indice]['caminho']
        try:
            import gi
            gi.require_version('Gio', '2.0')
            from gi.repository import Gio
        except Exception:
            self.aviso.emit('Gio indisponível')
            return
        mime = self._mime_do_item(indice)
        alvo = None
        try:
            for a in Gio.AppInfo.get_all_for_type(mime):
                if (a.get_id() or '') == app_id:
                    alvo = a
                    break
        except Exception:
            alvo = None
        if alvo is None:
            self.aviso.emit('Programa não encontrado')
            return
        if usar_sempre:
            try:
                Gio.AppInfo.set_default_for_type(alvo, mime, False)
                self.aviso.emit('Predefinição para %s: %s' % (mime, alvo.get_display_name()))
            except Exception:
                pass
        try:
            alvo.launch([Gio.File.new_for_path(caminho)], None)
        except Exception as e:
            # alguns programas (Flatpak) precisam do gtk-launch
            try:
                subprocess.Popen(['gtk-launch', app_id, caminho], start_new_session=True)
            except Exception:
                self.aviso.emit('Não consegui abrir: %s' % e)

    @Slot(int)
    def propriedades(self, indice):
        if not (0 <= indice < len(self._itens)):
            return
        item = self._itens[indice]
        try:
            st = os.stat(item['caminho'])
            modo = oct(st.st_mode & 0o777)[2:]
            dono = '%d:%d' % (st.st_uid, st.st_gid)
            tam = tamanho_legivel(st.st_size)
            extra = '' if item['pasta'] else ' · %s bytes' % st.st_size
        except OSError:
            modo, dono, tam, extra = '?', '?', '?', ''
        self.aviso.emit('%s — %s%s · %s · %s' % (item['nome'], tam, extra, item['data'], 'permissões ' + modo))

    @Slot(bool)
    def apagarSelecao(self, permanente):
        alvos = [self._itens[i]['caminho'] for i in self._selecao if 0 <= i < len(self._itens)]
        for caminho in alvos:
            try:
                if permanente:
                    if os.path.isdir(caminho):
                        shutil.rmtree(caminho)
                    else:
                        os.remove(caminho)
                else:
                    subprocess.run(['gio', 'trash', caminho], check=True, timeout=30)
            except Exception as e:
                self.aviso.emit('Não consegui apagar %s: %s' % (os.path.basename(caminho),
                                                               getattr(e, 'strerror', e)))
        self._selecao = []
        self._listar()

    @Slot(bool)
    def copiarSelecao(self, cortar):
        self._copiados = [self._itens[i]['caminho'] for i in self._selecao if 0 <= i < len(self._itens)]
        self._recortados = cortar
        if self._copiados:
            self._por_na_area(self._copiados, cortar)
            self.mudou.emit()
            self.aviso.emit(('Recortado' if cortar else 'Copiado') + ': %d item(ns)' % len(self._copiados))

    @Slot()
    def propriedadesPasta(self):
        try:
            st = os.stat(self._caminho)
            total = 0
            for nome in os.listdir(self._caminho):
                try:
                    total += os.path.getsize(os.path.join(self._caminho, nome))
                except OSError:
                    pass
            self.aviso.emit('%s — %d item(ns) · %s' % (os.path.basename(self._caminho) or '/',
                                                      len(self._itens), tamanho_legivel(total)))
        except OSError:
            self.aviso.emit('Sem permissão')

    @Slot(int)
    def criarAtalho(self, indice):
        if not (0 <= indice < len(self._itens)):
            return
        item = self._itens[indice]
        base = os.path.splitext(item['nome'])
        nome = '%s - Atalho%s' % (base[0], base[1])
        destino = os.path.join(self._caminho, nome)
        n = 1
        while os.path.exists(destino):
            n += 1
            destino = os.path.join(self._caminho, '%s - Atalho (%d)%s' % (base[0], n, base[1]))
        try:
            os.symlink(item['caminho'], destino)
            self.aviso.emit('Atalho criado: %s' % nome)
        except OSError as e:
            self.aviso.emit('Não consegui criar o atalho: %s' % e.strerror)
        self._listar()

    @Slot(int, bool)
    def apagar(self, indice, permanente):
        if not (0 <= indice < len(self._itens)):
            return
        caminho = self._itens[indice]['caminho']
        try:
            if permanente:
                if os.path.isdir(caminho):
                    shutil.rmtree(caminho)
                else:
                    os.remove(caminho)
            else:
                subprocess.run(['gio', 'trash', caminho], check=True, timeout=30)
        except Exception as e:
            self.aviso.emit('Não consegui apagar: %s' % getattr(e, 'strerror', e))
        self._listar()

    # ---- ações ---------------------------------------------------------------
    @Slot(int)
    def abrir(self, indice):
        if not (0 <= indice < len(self._itens)):
            return
        item = self._itens[indice]
        if os.path.islink(item['caminho']):
            real = os.path.realpath(item['caminho'])
            if os.path.exists(real):
                item = dict(item, caminho=real)
        if item['trancado']:
            try:
                subprocess.Popen(['carinaeos-cadeado', 'abrir', item['caminho']], start_new_session=True)
                self.aviso.emit('A pedir a senha… (F5 para atualizar depois)')
            except Exception as e:
                self.aviso.emit('Não consegui chamar o cadeado: %s' % e)
            return
        if item['pasta']:
            self.entrar(item['caminho'])
        else:
            # abrir com o programa predefinido do sistema (xdg-open), sem bloquear
            correr(['xdg-open', item['caminho']], espera=False)

    @Slot(int)
    def lixeira(self, indice):
        if not (0 <= indice < len(self._itens)):
            return
        caminho = self._itens[indice]['caminho']
        try:
            subprocess.run(['gio', 'trash', caminho], check=True, timeout=30)
        except Exception:
            self.aviso.emit("Não consegui mover para a lixeira: %s" % os.path.basename(caminho))
        self._listar()

    @Slot(int, str)
    def renomear(self, indice, novo):
        if not (0 <= indice < len(self._itens)) or not novo.strip():
            return
        item = self._itens[indice]
        destino = os.path.join(self._caminho, novo.strip())
        if os.path.exists(destino):
            self.aviso.emit("Já existe um item com esse nome")
            return
        try:
            os.rename(item['caminho'], destino)
        except OSError as e:
            self.aviso.emit("Não consegui renomear: %s" % e.strerror)
        self._listar()

    @Slot()
    def novaPasta(self):
        base = os.path.join(self._caminho, 'Nova pasta')
        destino, n = base, 1
        while os.path.exists(destino):
            n += 1
            destino = '%s %d' % (base, n)
        try:
            os.mkdir(destino)
        except OSError as e:
            self.aviso.emit("Não consegui criar a pasta: %s" % e.strerror)
        self._listar()

    @Slot(int)
    def copiar(self, indice):
        if 0 <= indice < len(self._itens):
            self._copiados = [self._itens[indice]['caminho']]
            self._recortados = False
            self.aviso.emit("Copiado: %s" % self._itens[indice]['nome'])

    @Slot(int)
    def cortar(self, indice):
        if 0 <= indice < len(self._itens):
            self._copiados = [self._itens[indice]['caminho']]
            self._recortados = True
            self.aviso.emit("Recortado: %s" % self._itens[indice]['nome'])

    def _destino_livre(self, nome):
        """Como no Windows: se o nome já existe, cria 'nome - Cópia'."""
        destino = os.path.join(self._caminho, nome)
        if not os.path.exists(destino):
            return destino
        raiz, ext = os.path.splitext(nome)
        candidato = '%s - Cópia%s' % (raiz, ext)
        n = 1
        while os.path.exists(os.path.join(self._caminho, candidato)):
            n += 1
            candidato = '%s - Cópia (%d)%s' % (raiz, n, ext)
        return os.path.join(self._caminho, candidato)

    @Slot()
    def colar(self):
        if self._caminho.startswith('carinae:'):
            return
        origens, cortar = list(self._copiados), self._recortados
        if not origens:
            origens, cortar = self._ler_da_area()
        origens = [o for o in origens if o and os.path.exists(o)]
        if not origens:
            return
        self._copiados, self._recortados = [], False
        if cortar:
            QGuiApplication.clipboard().clear()
        self._colar_fundo(origens, cortar, self._caminho)

    def _colar_antigo(self):
        for origem in self._copiados:
            nome = os.path.basename(origem)
            destino = os.path.join(self._caminho, nome)
            if not self._recortados:
                destino = self._destino_livre(nome)
            try:
                if os.path.abspath(origem) == os.path.abspath(destino):
                    continue
                if os.path.isdir(origem):
                    shutil.copytree(origem, destino, dirs_exist_ok=False)
                else:
                    shutil.copy2(origem, destino)
                if self._recortados:
                    if os.path.isdir(origem):
                        shutil.rmtree(origem, ignore_errors=True)
                    else:
                        os.remove(origem)
            except FileExistsError:
                self.aviso.emit("Já existe: %s" % os.path.basename(origem))
            except OSError as e:
                self.aviso.emit("Falhou: %s" % e.strerror)
        self._copiados = []
        self._recortados = False
        self._listar()


    # =========================================================================================
    # Windows 11: páginas Início / Este computador / Rede / Pesquisa, unidades, partilhas SMB,
    # cópias em segundo plano, área de transferência partilhada com os outros programas
    # =========================================================================================
    PAGINAS = {'carinae:inicio': 'Início', 'carinae:computador': 'Este computador',
               'carinae:rede': 'Rede', 'carinae:pesquisa': 'Pesquisa', 'carinae:galeria': 'Galeria'}
    progresso = Signal()
    paginaMudou = Signal()
    pedeCredenciais = Signal(str, str, str)      # alvo (url ou host), título, utilizador sugerido
    detalhesProntos = Signal('QVariantMap')

    def _iniciar_win(self):
        self._pagina_dados = {}
        self._op = None              # operação a decorrer: {titulo, feito, total, texto}
        self._pesquisa = ''
        self._servidores = []        # descobertos na rede local
        self._a_procurar_rede = False

    # ---- pastas do utilizador (xdg-user-dirs) ---------------------------------------------------
    @staticmethod
    def pastas_utilizador():
        nomes = {'DESKTOP': 'Área de trabalho', 'DOWNLOAD': 'Transferências', 'DOCUMENTS': 'Documentos',
                 'PICTURES': 'Imagens', 'MUSIC': 'Música', 'VIDEOS': 'Vídeos'}
        icones = {'DESKTOP': 'win:pasta-trabalho', 'DOWNLOAD': 'win:pasta-transferencias',
                  'DOCUMENTS': 'win:pasta-documentos', 'PICTURES': 'win:pasta-imagens',
                  'MUSIC': 'win:pasta-musica', 'VIDEOS': 'win:pasta-videos'}
        caminhos = {}
        try:
            for linha in open(os.path.join(HOME, '.config/user-dirs.dirs'), encoding='utf-8'):
                m = re.match(r'XDG_(\w+)_DIR="(.*)"', linha.strip())
                if m and m.group(1) in nomes:
                    caminhos[m.group(1)] = m.group(2).replace('$HOME', HOME)
        except OSError:
            pass
        reserva = {'DESKTOP': ['Área de trabalho', 'Desktop'], 'DOWNLOAD': ['Transferências', 'Downloads'],
                   'DOCUMENTS': ['Documentos'], 'PICTURES': ['Imagens'], 'MUSIC': ['Música', 'Músicas'],
                   'VIDEOS': ['Vídeos']}
        saida = []
        for k in ('DESKTOP', 'DOWNLOAD', 'DOCUMENTS', 'PICTURES', 'MUSIC', 'VIDEOS'):
            c = caminhos.get(k)
            if not c or not os.path.isdir(c) or os.path.abspath(c) == HOME:
                c = next((os.path.join(HOME, n) for n in reserva[k] if os.path.isdir(os.path.join(HOME, n))), None)
            if c:
                saida.append(dict(nome=nomes[k] if os.path.basename(c) in reserva[k] else os.path.basename(c),
                                  caminho=c, icone=icones[k]))
        return saida

    # ---- a coluna da esquerda ----------------------------------------------------------------------
    @Property('QVariantList', notify=mudou)
    def navegacao(self):
        """Painel de navegação do Windows 11: Início, Galeria | fixadas | Este computador (unidades) | Rede."""
        nav = [dict(nome='Início', caminho='carinae:inicio', icone='win:inicio', nivel=0),
               dict(nome='Galeria', caminho='carinae:galeria', icone='win:galeria', nivel=0),
               dict(separador=True)]
        for f in self.pastas_utilizador():
            nav.append(dict(nome=f['nome'], caminho=f['caminho'], icone=f['icone'], nivel=0, fixado=True))
        for c in self._fixadas():
            if os.path.isdir(c):
                nav.append(dict(nome=os.path.basename(c) or c, caminho=c, icone=icone_de(c, True), nivel=0,
                                fixado=True, removivel=True))
        nav.append(dict(nome='Cofre', caminho='', cofre=True, icone='win:cofre', nivel=0))
        for i, e in enumerate(self._etq):
            cor = (e.get('cor') or '#95a5a6').lstrip('#')
            nav.append(dict(nome=e['nome'], caminho=self._pasta_etq(e['nome']),
                            icone='etq:%s:%s' % (cor, e.get('icone') or 'folder'), nivel=0,
                            etiqueta=True, etqIndice=i))
        nav.append(dict(separador=True))
        nav.append(dict(nome='Este computador', caminho='carinae:computador', icone='win:computador', nivel=0,
                        grupo='computador'))
        for d in self._unidades(rapido=True):
            if d['montado']:
                nav.append(dict(nome=d['nome'], caminho=d['ponto'], icone=d['icone'], nivel=1, grupo='computador'))
        nav.append(dict(nome='Rede', caminho='carinae:rede', icone='win:rede', nivel=0, grupo='rede'))
        for i, r in enumerate(self._redes):
            ponto = self._ponto_gvfs(r.get('url', ''))
            ligado = bool(ponto) and os.path.isdir(ponto)
            nav.append(dict(nome=r.get('nome') or r['url'], caminho=ponto if ligado else '', icone='win:disco-rede',
                            nivel=1, grupo='rede', rede=True, redeIndice=i, ligado=ligado))
        return nav

    FIXADAS = os.path.join(HOME, '.config/carinaeos/arquivos-fixadas.json')

    def _fixadas(self):
        try:
            return [c for c in json.load(open(self.FIXADAS, encoding='utf-8')) if isinstance(c, str)]
        except Exception:
            return []

    @Slot(str)
    def fixar(self, caminho):
        lista = self._fixadas()
        if caminho in lista or not os.path.isdir(caminho):
            return
        lista.append(caminho)
        os.makedirs(os.path.dirname(self.FIXADAS), exist_ok=True)
        json.dump(lista, open(self.FIXADAS, 'w', encoding='utf-8'), ensure_ascii=False)
        self.mudou.emit()
        self.aviso.emit('Afixado no Acesso rápido')

    @Slot(str)
    def desafixar(self, caminho):
        lista = [c for c in self._fixadas() if c != caminho]
        os.makedirs(os.path.dirname(self.FIXADAS), exist_ok=True)
        json.dump(lista, open(self.FIXADAS, 'w', encoding='utf-8'), ensure_ascii=False)
        self.mudou.emit()

    # ---- onde estamos ------------------------------------------------------------------------------
    @Property(str, notify=caminhoMudou)
    def pagina(self):
        return self._caminho[8:] if self._caminho.startswith('carinae:') else ''

    @Property('QVariantMap', notify=paginaMudou)
    def dadosPagina(self):
        return self._pagina_dados

    def _nome_unidade(self, ponto):
        for d in self._unidades(rapido=True):
            if d['montado'] and d['ponto'] == ponto:
                return d['nome'], d['icone']
        return None, None

    @Property('QVariantList', notify=caminhoMudou)
    def migalhas(self):
        """A barra de endereço por partes: [{nome, caminho, icone}]."""
        c = self._caminho
        if c.startswith('carinae:'):
            return [dict(nome=self.PAGINAS.get(c, c), caminho=c, icone=self._icone_pagina(c))]
        partes = []
        gvfs = os.path.join(os.environ.get('XDG_RUNTIME_DIR', '/run/user/%d' % os.getuid()), 'gvfs')
        if c == HOME or c.startswith(HOME + '/'):
            base, nome0, ic0 = HOME, os.path.basename(HOME), 'win:inicio'
            partes.append(dict(nome=nome0, caminho=HOME, icone=ic0))
        elif c.startswith(gvfs + '/'):
            seg = c[len(gvfs) + 1:].split('/')[0]
            m = dict(re.findall(r'(\w+)=([^,]+)', seg))
            base = os.path.join(gvfs, seg)
            partes.append(dict(nome='Rede', caminho='carinae:rede', icone='win:rede'))
            partes.append(dict(nome='%s (\\\\%s)' % (m.get('share', ''), m.get('server', '')), caminho=base,
                               icone='win:disco-rede'))
        else:
            # a unidade mais funda que contém o caminho
            base = '/'
            for d in self._unidades(rapido=True):
                if d['montado'] and (c == d['ponto'] or c.startswith(d['ponto'].rstrip('/') + '/')):
                    if len(d['ponto']) >= len(base):
                        base = d['ponto']
            partes.append(dict(nome='Este computador', caminho='carinae:computador', icone='win:computador'))
            n, ic = self._nome_unidade(base)
            partes.append(dict(nome=n or ('Sistema' if base == '/' else os.path.basename(base)), caminho=base,
                               icone=ic or 'win:disco'))
        resto = c[len(base):].strip('/')
        atual = base
        for seg in [x for x in resto.split('/') if x]:
            atual = os.path.join(atual, seg)
            partes.append(dict(nome=seg, caminho=atual, icone=''))
        return partes

    @staticmethod
    def _icone_pagina(c):
        return {'carinae:inicio': 'win:inicio', 'carinae:computador': 'win:computador', 'carinae:rede': 'win:rede',
                'carinae:galeria': 'win:galeria'}.get(c, 'system-search')

    @Property(str, notify=caminhoMudou)
    def titulo(self):
        c = self._caminho
        if c.startswith('carinae:'):
            return self.PAGINAS.get(c, c)
        m = self.migalhas
        return m[-1]['nome'] if m else (os.path.basename(c) or c)

    @Property(str, notify=caminhoMudou)
    def iconeAtual(self):
        c = self._caminho
        if c.startswith('carinae:'):
            return self._icone_pagina(c)
        m = self.migalhas
        if m and m[-1].get('icone'):
            return m[-1]['icone']
        return icone_de(c, True)

    # ---- as páginas especiais --------------------------------------------------------------------
    def _carregar_pagina(self):
        c = self._caminho
        if c == 'carinae:inicio':
            self._pagina_dados = dict(rapido=self.pastas_utilizador() + [
                dict(nome=os.path.basename(x), caminho=x, icone=icone_de(x, True)) for x in self._fixadas()
                if os.path.isdir(x)], recentes=self._recentes())
        elif c == 'carinae:computador':
            self._pagina_dados = dict(pastas=self.pastas_utilizador(), unidades=self._unidades(),
                                      redes=self.redes)
        elif c == 'carinae:rede':
            self._pagina_dados = dict(redes=self.redes, servidores=self._servidores, aProcurar=True)
            self._procurar_servidores()
        elif c == 'carinae:galeria':
            self._pagina_dados = dict()
            self._carregar_galeria()
            return
        elif c == 'carinae:pesquisa':
            return
        self.paginaMudou.emit()

    def _recentes(self, maximo=24):
        """Os ficheiros abertos há pouco (o mesmo registo que o GTK e o Qt usam)."""
        f = os.path.join(HOME, '.local/share/recently-used.xbel')
        saida, vistos = [], set()
        try:
            import xml.etree.ElementTree as ET
            raiz = ET.parse(f).getroot()
            marcas = []
            for b in raiz.findall('bookmark'):
                href = b.get('href', '')
                if not href.startswith('file://'):
                    continue
                marcas.append((b.get('visited') or b.get('modified') or '', urllib.parse.unquote(href[7:])))
            marcas.sort(reverse=True)
            for quando, cam in marcas:
                if cam in vistos or not os.path.exists(cam):
                    continue
                vistos.add(cam)
                saida.append(self._fazer_item(cam))
                if len(saida) >= maximo:
                    break
        except Exception:
            pass
        return saida

    def _carregar_galeria(self):
        """Todas as fotos e vídeos de Imagens e Vídeos (as mais novas primeiro), como a Galeria do Windows."""
        pastas = [f['caminho'] for f in self.pastas_utilizador() if f['icone'] in ('win:pasta-imagens', 'win:pasta-videos')]

        def trabalhar():
            achados = []
            for raiz in pastas:
                for d, subs, fichs in os.walk(raiz):
                    subs[:] = [x for x in subs if not x.startswith('.')]
                    for n in fichs:
                        if os.path.splitext(n)[1].lower() in (IMAGENS | VIDEOS):
                            cam = os.path.join(d, n)
                            try:
                                achados.append((os.stat(cam).st_mtime, cam))
                            except OSError:
                                pass
                    if len(achados) > 4000:
                        break
            achados.sort(reverse=True)
            self._galeria = [self._fazer_item(c) for _, c in achados[:1500]]
            QMetaObject.invokeMethod(self, '_fimGaleria', Qt.QueuedConnection)

        threading.Thread(target=trabalhar, daemon=True).start()

    @Slot()
    def _fimGaleria(self):
        if self._caminho == 'carinae:galeria':
            self._itens = getattr(self, '_galeria', [])
            self.mudou.emit()

    # ---- unidades (Este computador) --------------------------------------------------------------
    def _unidades(self, rapido=False):
        """Discos e pens: montados (com o espaço usado) e não montados (montam-se com um clique)."""
        if rapido and getattr(self, '_unid_cache', None) and time.time() - self._unid_t < 5:
            return self._unid_cache
        saida = []
        try:
            r = subprocess.run(['lsblk', '-J', '-b', '-o', 'NAME,PATH,LABEL,FSTYPE,SIZE,MOUNTPOINT,TYPE,RM,HOTPLUG,PARTTYPENAME,TRAN'],
                               capture_output=True, text=True, timeout=5)
            arvore = json.loads(r.stdout or '{}').get('blockdevices', [])
        except Exception:
            arvore = []
        uteis = ('ext4', 'ext3', 'ext2', 'btrfs', 'xfs', 'ntfs', 'ntfs3', 'vfat', 'exfat', 'f2fs', 'iso9660', 'udf', 'hfsplus')

        def percorrer(nos, pai_usb):
            for n in nos:
                usb = pai_usb or n.get('tran') == 'usb' or bool(n.get('rm')) or bool(n.get('hotplug'))
                filhos = n.get('children') or []
                if filhos:
                    percorrer(filhos, usb)
                    continue
                fs = n.get('fstype') or ''
                if fs not in uteis:
                    continue
                ponto = n.get('mountpoint') or ''
                tipo_part = (n.get('parttypename') or '').lower()
                tam = int(n.get('size') or 0)
                # fora: a partição EFI, a de arranque e as pequenas de sistema (recuperação, "reservado")
                if ponto in ('/boot/efi', '/boot', '/efi') or 'efi' in tipo_part or 'recovery' in tipo_part:
                    continue
                if 'reserved' in tipo_part or (tam and tam < 600 * 1024 * 1024 and not usb):
                    continue
                rotulo = n.get('label') or ''
                if ponto == '/':
                    nome, icone = 'Sistema CarinaeOS', 'win:disco-sistema'
                else:
                    nome = rotulo or ('Unidade USB' if usb else 'Disco local')
                    icone = 'win:disco-usb' if usb else 'win:disco'
                d = dict(nome=nome, dispositivo=n.get('path') or '', ponto=ponto, montado=bool(ponto), fs=fs,
                         icone=icone, usb=usb, total=tam, livre=0, usado=0.0,
                         texto=tamanho_legivel(tam))
                if ponto:
                    try:
                        st = os.statvfs(ponto)
                        total = st.f_blocks * st.f_frsize
                        livre = st.f_bavail * st.f_frsize
                        d.update(total=total, livre=livre, usado=(1 - livre / total) if total else 0,
                                 texto='%s livres de %s' % (tamanho_legivel(livre), tamanho_legivel(total)))
                    except OSError:
                        pass
                else:
                    d['texto'] = '%s · não montado' % tamanho_legivel(tam)
                saida.append(d)

        percorrer(arvore, False)
        saida.sort(key=lambda d: (d['ponto'] != '/', d['usb'], not d['montado'], d['nome'].lower()))
        self._unid_cache, self._unid_t = saida, time.time()
        return saida

    @Slot(str)
    def abrirUnidade(self, dispositivo):
        """Clique numa unidade: se não está montada, monta (o polkit pede a senha se for preciso)."""
        for d in self._unidades():
            if d['dispositivo'] != dispositivo:
                continue
            if d['montado']:
                self.entrar(d['ponto'])
                return
            self.aviso.emit('A abrir %s…' % d['nome'])

            def montar():
                r = subprocess.run(['udisksctl', 'mount', '-b', dispositivo, '--no-user-interaction'],
                                   capture_output=True, text=True, timeout=120)
                if r.returncode != 0 and 'NotAuthorized' in (r.stderr or ''):
                    r = subprocess.run(['udisksctl', 'mount', '-b', dispositivo], capture_output=True, text=True,
                                       timeout=300)
                m = re.search(r' at (.+?)\.?$', (r.stdout or '').strip())
                ponto = m.group(1) if m else ''
                QMetaObject.invokeMethod(self, '_fimMontar', Qt.QueuedConnection, Q_ARG(str, ponto),
                                         Q_ARG(str, (r.stderr or '').strip()))

            threading.Thread(target=montar, daemon=True).start()
            return

    @Slot(str, str)
    def _fimMontar(self, ponto, erro):
        self._unid_cache = None
        if ponto and os.path.isdir(ponto):
            self.entrar(ponto)
        else:
            self.aviso.emit('Não consegui abrir a unidade: %s' % (erro.split(':')[-1].strip() or 'erro'))
        self.mudou.emit()

    @Slot(str)
    def ejetarUnidade(self, dispositivo):
        def ejetar():
            r = subprocess.run(['udisksctl', 'unmount', '-b', dispositivo], capture_output=True, text=True, timeout=60)
            if r.returncode == 0:
                subprocess.run(['udisksctl', 'power-off', '-b', re.sub(r'p?\d+$', '', dispositivo)],
                               capture_output=True, timeout=30)
            QMetaObject.invokeMethod(self, '_fimEjetar', Qt.QueuedConnection,
                                     Q_ARG(str, '' if r.returncode == 0 else (r.stderr or 'ocupada').strip()))
        if self._caminho.startswith('/media') or self._caminho.startswith('/run/media'):
            self.entrar('carinae:computador')
        threading.Thread(target=ejetar, daemon=True).start()

    @Slot(str)
    def _fimEjetar(self, erro):
        self._unid_cache = None
        self.aviso.emit('Já pode retirar a unidade' if not erro else 'Não consegui ejetar: %s' % erro)
        self._listar()

    # ---- rede: descobrir computadores e as partilhas deles -----------------------------------------
    def _procurar_servidores(self):
        if self._a_procurar_rede:
            return
        self._a_procurar_rede = True

        def procurar():
            achados = {}
            if shutil.which('avahi-browse'):
                try:
                    r = subprocess.run(['avahi-browse', '-tpr', '_smb._tcp'], capture_output=True, text=True, timeout=8)
                    for linha in r.stdout.splitlines():
                        c = linha.split(';')
                        if c[0] == '=' and len(c) > 7 and c[2] == 'IPv4':
                            achados[c[3]] = dict(nome=c[3].replace('\\032', ' '), host=c[6].rstrip('.'), ip=c[7])
                except Exception:
                    pass
            try:
                r = subprocess.run(['gio', 'list', '-a', 'standard::display-name,standard::target-uri', 'network:///'],
                                   capture_output=True, text=True, timeout=8)
                for linha in r.stdout.splitlines():
                    m = re.search(r'standard::target-uri=smb://([^/\s]+)', linha)
                    nm = re.search(r'standard::display-name=(.+?)(\s+standard::|$)', linha)
                    if m:
                        host = m.group(1)
                        if not any(a['host'].split('.')[0].lower() == host.split('.')[0].lower() for a in achados.values()):
                            achados[host] = dict(nome=(nm.group(1) if nm else host), host=host, ip='')
            except Exception:
                pass
            lista = sorted(achados.values(), key=lambda a: a['nome'].lower())
            QMetaObject.invokeMethod(self, '_fimProcurar', Qt.QueuedConnection, Q_ARG(str, json.dumps(lista)))

        threading.Thread(target=procurar, daemon=True).start()

    @Slot(str)
    def _fimProcurar(self, dados):
        self._a_procurar_rede = False
        self._servidores = json.loads(dados)
        if self._caminho == 'carinae:rede':
            self._pagina_dados = dict(redes=self.redes, servidores=self._servidores, aProcurar=False)
            self.paginaMudou.emit()

    @Slot()
    def procurarRede(self):
        if self._caminho == 'carinae:rede':
            self._pagina_dados = dict(redes=self.redes, servidores=self._servidores, aProcurar=True)
            self.paginaMudou.emit()
        self._procurar_servidores()

    @Slot(str, str, str, str)
    def explorarServidor(self, host, utilizador, senha, dominio):
        """As pastas partilhadas de um computador (\\\\servidor)."""
        self.aviso.emit('A ver as pastas partilhadas de %s…' % host)

        def ver():
            cmd = ['smbclient', '-g', '-L', '//' + host]
            amb = dict(os.environ)
            if utilizador:
                cmd += ['-U', (dominio + '\\' if dominio else '') + utilizador]
                amb['PASSWD'] = senha
            else:
                cmd += ['-N']
            try:
                r = subprocess.run(cmd, capture_output=True, text=True, timeout=20, env=amb)
                saida = r.stdout + r.stderr
            except FileNotFoundError:
                saida = 'ERRO: falta o smbclient (sudo apt install smbclient)'
            except Exception as e:
                saida = 'ERRO: %s' % e
            partilhas = []
            for linha in saida.splitlines():
                c = linha.split('|')
                if len(c) >= 2 and c[0] == 'Disk' and not c[1].endswith('$'):
                    partilhas.append(dict(nome=c[1], comentario=c[2] if len(c) > 2 else ''))
            precisa = any(t in saida for t in ('NT_STATUS_ACCESS_DENIED', 'NT_STATUS_LOGON_FAILURE',
                                               'NT_STATUS_ACCOUNT_RESTRICTED'))
            QMetaObject.invokeMethod(self, '_fimExplorar', Qt.QueuedConnection, Q_ARG(str, host),
                                     Q_ARG(str, json.dumps(partilhas)), Q_ARG(bool, precisa and not partilhas),
                                     Q_ARG(str, '' if partilhas or precisa else saida.strip().splitlines()[-1:][0]
                                           if saida.strip() else 'sem resposta'), Q_ARG(str, utilizador))

        threading.Thread(target=ver, daemon=True).start()

    @Slot(str, str, bool, str, str)
    def _fimExplorar(self, host, partilhas, precisa, erro, utilizador):
        if precisa:
            self.pedeCredenciais.emit('host:' + host, 'Ligar a \\\\%s' % host, utilizador)
            return
        lista = json.loads(partilhas)
        if not lista:
            self.aviso.emit('Não vi pastas partilhadas em %s (%s)' % (host, erro))
            return
        self._caminho = 'carinae:servidor'
        self.PAGINAS['carinae:servidor'] = '\\\\' + host
        self._pagina_dados = dict(host=host, partilhas=lista, utilizador=utilizador)
        if self._historico[self._pos:self._pos + 1] != [self._caminho]:
            self._historico = self._historico[:self._pos + 1] + [self._caminho]
            self._pos = len(self._historico) - 1
        self._itens = []
        self.mudou.emit()
        self.caminhoMudou.emit()
        self.paginaMudou.emit()

    @Slot(str, str, str, str, str, bool)
    def mapearRede(self, pasta, utilizador, senha, dominio, nome, religar):
        """"Mapear unidade de rede": \\\\servidor\\partilha (ou smb://servidor/partilha)."""
        url = self._para_smb(pasta)
        if not url:
            self.aviso.emit('Escreva a pasta como \\\\servidor\\partilha')
            return
        existente = next((i for i, r in enumerate(self._redes) if r.get('url') == url), -1)
        reg = dict(nome=(nome or '').strip() or self._nome_partilha(url), url=url, religar=bool(religar),
                   utilizador=utilizador or '', dominio=dominio or '')
        if existente >= 0:
            self._redes[existente] = reg
            indice = existente
        else:
            self._redes.append(reg)
            indice = len(self._redes) - 1
        self._gravar_redes()
        self.mudou.emit()
        self._ligar(indice, utilizador, senha, dominio)

    @staticmethod
    def _para_smb(texto):
        t = (texto or '').strip()
        if t.startswith('\\\\') or t.startswith('//'):
            t = 'smb://' + t[2:].replace('\\', '/')
        if not t.startswith('smb://'):
            return ''
        resto = t[6:].strip('/')
        return 'smb://' + resto if resto else ''

    @staticmethod
    def _nome_partilha(url):
        partes = [x for x in url[6:].split('/') if x]
        host = partes[0].split('@')[-1] if partes else ''
        return '%s (\\\\%s)' % (partes[1], host) if len(partes) > 1 else '\\\\' + host

    def _ligar(self, indice, utilizador, senha, dominio):
        url = self._redes[indice]['url']
        self.aviso.emit('A ligar a %s…' % self._redes[indice].get('nome', url))

        def tentar():
            ok, erro = self._montar_gio(url, utilizador, senha, dominio)
            QMetaObject.invokeMethod(self, '_fimLigarRede', Qt.QueuedConnection,
                                     Q_ARG(int, indice), Q_ARG(str, '' if ok else erro))

        threading.Thread(target=tentar, daemon=True).start()

    @Slot(str, str, str, str)
    def responderCredenciais(self, alvo, utilizador, senha, dominio):
        if alvo.startswith('host:'):
            self.explorarServidor(alvo[5:], utilizador, senha, dominio)
        elif alvo.startswith('rede:'):
            i = int(alvo[5:])
            if 0 <= i < len(self._redes):
                self._redes[i]['utilizador'] = utilizador
                self._redes[i]['dominio'] = dominio
                self._gravar_redes()
                self._ligar(i, utilizador, senha, dominio)

    @Slot(str, str)
    def abrirPartilha(self, host, partilha):
        url = 'smb://%s/%s' % (host, partilha)
        ut = self._pagina_dados.get('utilizador', '') if isinstance(self._pagina_dados, dict) else ''
        ponto = self._ponto_gvfs(url)
        if ponto and os.path.isdir(ponto):
            self.entrar(ponto)
            return
        self.mapearRede(url, ut, '', '', '', False)

    # ---- pesquisa (Enter na caixa "Pesquisar") ---------------------------------------------------
    @Slot(str)
    def pesquisar(self, texto):
        texto = (texto or '').strip()
        if not texto:
            return
        raiz = self._caminho if not self._caminho.startswith('carinae:') else HOME
        if self._caminho == 'carinae:pesquisa':
            raiz = getattr(self, '_raiz_pesquisa', HOME)
        self._raiz_pesquisa = raiz
        self._pesquisa = texto
        self.PAGINAS['carinae:pesquisa'] = 'Resultados de "%s" em %s' % (texto, os.path.basename(raiz) or raiz)
        self._caminho = 'carinae:pesquisa'
        if self._historico[self._pos:self._pos + 1] != [self._caminho]:
            self._historico = self._historico[:self._pos + 1] + [self._caminho]
            self._pos = len(self._historico) - 1
        self._itens = []
        self._pagina_dados = dict(aProcurar=True, texto=texto)
        self.caminhoMudou.emit()
        self.paginaMudou.emit()
        self.mudou.emit()
        alvo = texto.lower()
        marca = object()
        self._marca_pesquisa = marca

        def procurar():
            achados = []
            for d, subs, fichs in os.walk(raiz):
                if self._marca_pesquisa is not marca:
                    return
                subs[:] = [x for x in subs if not x.startswith('.')]
                for n in subs + fichs:
                    if alvo in n.lower():
                        achados.append(os.path.join(d, n))
                if len(achados) >= 800:
                    break
            itens = [self._fazer_item(c, local=True) for c in achados]
            self._resultado_pesquisa = itens
            QMetaObject.invokeMethod(self, '_fimPesquisa', Qt.QueuedConnection)

        threading.Thread(target=procurar, daemon=True).start()

    @Slot()
    def _fimPesquisa(self):
        if self._caminho == 'carinae:pesquisa':
            self._itens = getattr(self, '_resultado_pesquisa', [])
            self._pagina_dados = dict(aProcurar=False, texto=self._pesquisa)
            self.paginaMudou.emit()
            self.mudou.emit()

    def _fazer_item(self, p, local=False):
        nome = os.path.basename(p)
        try:
            pasta = os.path.isdir(p)
            st = os.stat(p)
        except OSError:
            pasta, st = False, None
        ext = os.path.splitext(nome)[1].lower()
        return dict(nome=nome, caminho=p, pasta=pasta, icone=icone_de(p, pasta), tipo=nome_tipo(p, pasta),
                    tamanho='' if pasta or not st else tamanho_legivel(st.st_size),
                    tamanhoNum=0 if pasta or not st else st.st_size,
                    data=time.strftime('%d/%m/%Y %H:%M', time.localtime(st.st_mtime)) if st else '',
                    dataNum=st.st_mtime if st else 0,
                    miniatura=(not pasta) and ext in (IMAGENS | VIDEOS), video=ext in VIDEOS,
                    trancado=False, etiquetas=[], local=os.path.dirname(p) if local else '')

    # ---- seleção: o que aparece na barra de estado e no painel de detalhes -----------------------
    @Property(str, notify=mudou)
    def infoSelecao(self):
        sel = [self._itens[i] for i in self._selecao if 0 <= i < len(self._itens)]
        if not sel:
            return ''
        total = sum(i.get('tamanhoNum', 0) for i in sel)
        txt = '1 item selecionado' if len(sel) == 1 else '%d itens selecionados' % len(sel)
        if total and not any(i['pasta'] for i in sel):
            txt += '  ' + tamanho_legivel(total)
        return txt

    @Slot(int)
    def detalhes(self, indice):
        """Propriedades de um item (o tamanho das pastas é contado em segundo plano)."""
        if self._caminho.startswith('carinae:') and not (0 <= indice < len(self._itens)):
            return
        if 0 <= indice < len(self._itens):
            cam = self._itens[indice]['caminho']
        else:
            cam = self._caminho
        try:
            st = os.stat(cam)
        except OSError:
            return
        pasta = os.path.isdir(cam)
        import pwd
        try:
            dono = pwd.getpwuid(st.st_uid).pw_name
        except KeyError:
            dono = str(st.st_uid)
        d = dict(nome=os.path.basename(cam) or cam, caminho=cam, pasta=pasta, local=os.path.dirname(cam),
                 tipo=nome_tipo(cam, pasta), icone=icone_de(cam, pasta),
                 tamanho='a calcular…' if pasta else '%s (%s bytes)' % (tamanho_legivel(st.st_size), '{:,}'.format(st.st_size).replace(',', '.')),
                 conteudo='', criado=time.strftime('%d/%m/%Y, %H:%M', time.localtime(st.st_ctime)),
                 modificado=time.strftime('%d/%m/%Y, %H:%M', time.localtime(st.st_mtime)),
                 acedido=time.strftime('%d/%m/%Y, %H:%M', time.localtime(st.st_atime)),
                 permissoes=oct(st.st_mode & 0o777)[2:], dono=dono,
                 somenteLeitura=not os.access(cam, os.W_OK), oculto=os.path.basename(cam).startswith('.'))
        self.detalhesProntos.emit(d)
        if pasta:
            def contar():
                total = n_f = n_p = 0
                for dd, subs, fichs in os.walk(cam):
                    n_p += len(subs)
                    for f in fichs:
                        try:
                            total += os.lstat(os.path.join(dd, f)).st_size
                            n_f += 1
                        except OSError:
                            pass
                d2 = dict(d, tamanho='%s (%s bytes)' % (tamanho_legivel(total), '{:,}'.format(total).replace(',', '.')),
                          conteudo='%d ficheiros, %d pastas' % (n_f, n_p))
                QMetaObject.invokeMethod(self, '_fimDetalhes', Qt.QueuedConnection, Q_ARG(str, json.dumps(d2)))
            threading.Thread(target=contar, daemon=True).start()

    @Slot(str)
    def _fimDetalhes(self, dados):
        self.detalhesProntos.emit(json.loads(dados))

    # ---- novo / comprimir / extrair / caminho ------------------------------------------------------
    @Slot(str)
    def novoFicheiro(self, tipo):
        if self._caminho.startswith('carinae:'):
            return
        base, ext, conteudo = {'texto': ('Novo documento de texto', '.txt', b''),
                               'markdown': ('Novo documento', '.md', b''),
                               'script': ('Novo script', '.sh', b'#!/bin/sh\n')}.get(tipo, ('Novo ficheiro', '', b''))
        destino = os.path.join(self._caminho, base + ext)
        n = 1
        while os.path.exists(destino):
            n += 1
            destino = os.path.join(self._caminho, '%s (%d)%s' % (base, n, ext))
        try:
            with open(destino, 'wb') as f:
                f.write(conteudo)
            if tipo == 'script':
                os.chmod(destino, 0o755)
        except OSError as e:
            self.aviso.emit('Não consegui criar: %s' % e.strerror)
        self._listar()
        self.selecionarPorNome(os.path.basename(destino))
        self.pedeRenomear.emit()

    pedeRenomear = Signal()

    @Slot()
    def novaPastaRenomear(self):
        antes = set(i['nome'] for i in self._itens)
        self.novaPasta()
        for i, it in enumerate(self._itens):
            if it['nome'] not in antes:
                self._selecao = [i]
                self.mudou.emit()
                self.pedeRenomear.emit()
                return

    @Slot()
    def copiarCaminho(self):
        sel = [self._itens[i]['caminho'] for i in self._selecao if 0 <= i < len(self._itens)] or [self._caminho]
        QGuiApplication.clipboard().setText('\n'.join('"%s"' % c for c in sel))
        self.aviso.emit('Caminho copiado')

    @Slot()
    def comprimir(self):
        sel = [self._itens[i]['caminho'] for i in self._selecao if 0 <= i < len(self._itens)]
        if not sel or self._caminho.startswith('carinae:'):
            return
        nome = (os.path.splitext(os.path.basename(sel[0]))[0] if len(sel) == 1 else os.path.basename(self._caminho)) + '.zip'
        destino = self._destino_livre(nome)
        pasta_base = self._caminho

        def trabalhar():
            import zipfile
            ficheiros = []
            for s in sel:
                if os.path.isdir(s):
                    for d, _, fs in os.walk(s):
                        ficheiros += [os.path.join(d, f) for f in fs]
                else:
                    ficheiros.append(s)
            total = sum(os.path.getsize(f) for f in ficheiros if os.path.isfile(f)) or 1
            feito = 0
            try:
                with zipfile.ZipFile(destino, 'w', zipfile.ZIP_DEFLATED) as z:
                    for f in ficheiros:
                        z.write(f, os.path.relpath(f, pasta_base))
                        feito += os.path.getsize(f) if os.path.isfile(f) else 0
                        self._marcar_op('A comprimir', feito, total, os.path.basename(f))
                erro = ''
            except Exception as e:
                erro = str(e)
            QMetaObject.invokeMethod(self, '_fimOperacao', Qt.QueuedConnection, Q_ARG(str, erro))

        self._comecar_op('A comprimir para %s' % os.path.basename(destino))
        threading.Thread(target=trabalhar, daemon=True).start()

    @Slot()
    def compactarCom(self):
        sel = [self._itens[i]['caminho'] for i in self._selecao if 0 <= i < len(self._itens)]
        if sel:
            subprocess.Popen(['carinaeos-compactador', '--compactar'] + sel, start_new_session=True)

    @Slot(str)
    def verCompactado(self, caminho):
        subprocess.Popen(['carinaeos-compactador', caminho], start_new_session=True)

    @Slot(int)
    def extrair(self, indice):
        if not (0 <= indice < len(self._itens)):
            return
        orig = self._itens[indice]['caminho']
        base = os.path.basename(orig)
        for ext in ('.tar.gz', '.tar.xz', '.tar.bz2', '.tar.zst', '.tgz', '.zip', '.tar', '.7z', '.rar'):
            if base.lower().endswith(ext):
                base = base[:-len(ext)]
                break
        destino = self._destino_livre(base)

        def trabalhar():
            erro = ''
            try:
                if orig.lower().endswith(('.7z', '.rar')):
                    ferramenta = shutil.which('7z') or shutil.which('7zz') or shutil.which('unrar')
                    if not ferramenta:
                        raise RuntimeError('falta o 7-Zip (sudo apt install 7zip)')
                    os.makedirs(destino, exist_ok=True)
                    args = [ferramenta, 'x', '-o' + destino, orig] if '7z' in ferramenta else [ferramenta, 'x', orig, destino + '/']
                    r = subprocess.run(args, capture_output=True, text=True)
                    if r.returncode:
                        raise RuntimeError(r.stderr.strip() or 'falhou')
                else:
                    shutil.unpack_archive(orig, destino)
            except Exception as e:
                erro = str(e)
            QMetaObject.invokeMethod(self, '_fimOperacao', Qt.QueuedConnection, Q_ARG(str, erro))

        self._comecar_op('A extrair %s' % os.path.basename(orig))
        threading.Thread(target=trabalhar, daemon=True).start()

    # ---- operações em segundo plano (copiar, mover, comprimir) com progresso -----------------------
    @Property('QVariantMap', notify=progresso)
    def operacao(self):
        return self._op or {}

    def _comecar_op(self, titulo):
        self._op = dict(titulo=titulo, feito=0, total=1, texto='', fracao=0.0)
        self._op_t = 0
        self.progresso.emit()

    def _marcar_op(self, titulo, feito, total, texto):
        agora = time.time()
        if agora - getattr(self, '_op_t', 0) < 0.1:
            return
        self._op_t = agora
        self._op_pendente = dict(titulo=self._op['titulo'] if self._op else titulo, feito=feito, total=total,
                                 texto=texto, fracao=min(1.0, feito / total if total else 0))
        QMetaObject.invokeMethod(self, '_atualizarOp', Qt.QueuedConnection)

    @Slot()
    def _atualizarOp(self):
        if self._op is not None and getattr(self, '_op_pendente', None):
            self._op = self._op_pendente
            self.progresso.emit()

    @Slot(str)
    def _fimOperacao(self, erro):
        self._op = None
        self.progresso.emit()
        if erro:
            self.aviso.emit('Falhou: %s' % erro)
        self._listar()

    def _por_na_area(self, caminhos, cortar):
        """Copiar/cortar também para a área de transferência do sistema (os outros programas veem)."""
        try:
            m = QMimeData()
            m.setUrls([QUrl.fromLocalFile(c) for c in caminhos])
            gnome = ('cut' if cortar else 'copy') + '\n' + '\n'.join(QUrl.fromLocalFile(c).toString() for c in caminhos)
            m.setData('x-special/gnome-copied-files', gnome.encode())
            m.setText('\n'.join(caminhos))
            QGuiApplication.clipboard().setMimeData(m)
        except Exception:
            pass

    def _ler_da_area(self):
        try:
            m = QGuiApplication.clipboard().mimeData()
            if m is None:
                return [], False
            if m.hasFormat('x-special/gnome-copied-files'):
                linhas = bytes(m.data('x-special/gnome-copied-files')).decode(errors='ignore').splitlines()
                if linhas:
                    cortar = linhas[0].strip() == 'cut'
                    return [QUrl(x).toLocalFile() for x in linhas[1:] if x.startswith('file://')], cortar
            if m.hasUrls():
                return [u.toLocalFile() for u in m.urls() if u.isLocalFile()], False
        except Exception:
            pass
        return [], False

    @Property(bool, notify=mudou)
    def podeColar(self):
        return bool(self._copiados) or bool(self._ler_da_area()[0])

    def _colar_fundo(self, origens, cortar, pasta):
        """Copia/move em segundo plano, com progresso (a janela não fica parada)."""
        def destino_livre(nome):
            destino = os.path.join(pasta, nome)
            if not os.path.exists(destino):
                return destino
            raiz, ext = os.path.splitext(nome)
            n, cand = 1, '%s - Cópia%s' % (raiz, ext)
            while os.path.exists(os.path.join(pasta, cand)):
                n += 1
                cand = '%s - Cópia (%d)%s' % (raiz, n, ext)
            return os.path.join(pasta, cand)

        def tamanho(c):
            if os.path.isfile(c) or os.path.islink(c):
                return os.lstat(c).st_size
            t = 0
            for d, _, fs in os.walk(c):
                for f in fs:
                    try:
                        t += os.lstat(os.path.join(d, f)).st_size
                    except OSError:
                        pass
            return t

        def trabalhar():
            erro = ''
            try:
                total = sum(tamanho(o) for o in origens) or 1
                feito = [0]

                def copiar_ficheiro(o, d):
                    if os.path.islink(o):
                        os.symlink(os.readlink(o), d)
                        return
                    with open(o, 'rb') as fo, open(d, 'wb') as fd:
                        while True:
                            bloco = fo.read(4 * 1024 * 1024)
                            if not bloco:
                                break
                            fd.write(bloco)
                            feito[0] += len(bloco)
                            self._marcar_op('', feito[0], total, os.path.basename(o))
                    shutil.copystat(o, d)

                for o in origens:
                    nome = os.path.basename(o.rstrip('/'))
                    if os.path.abspath(os.path.dirname(o)) == os.path.abspath(pasta) and cortar:
                        continue
                    d = destino_livre(nome)
                    if os.path.isdir(o) and os.path.abspath(d).startswith(os.path.abspath(o) + '/'):
                        raise RuntimeError('não se pode copiar uma pasta para dentro dela própria')
                    if cortar:
                        try:
                            os.rename(o, d)             # mesmo disco: instantâneo
                            feito[0] += tamanho(d)
                            continue
                        except OSError:
                            pass
                    if os.path.isdir(o) and not os.path.islink(o):
                        shutil.copytree(o, d, symlinks=True, copy_function=lambda a, b: copiar_ficheiro(a, b))
                    else:
                        copiar_ficheiro(o, d)
                    if cortar:
                        if os.path.isdir(o) and not os.path.islink(o):
                            shutil.rmtree(o)
                        else:
                            os.remove(o)
            except Exception as e:
                erro = getattr(e, 'strerror', None) or str(e)
            QMetaObject.invokeMethod(self, '_fimOperacao', Qt.QueuedConnection, Q_ARG(str, erro))

        n = len(origens)
        self._comecar_op(('A mover' if cortar else 'A copiar') + (' %d itens' % n if n > 1 else ' ' + os.path.basename(origens[0])))
        threading.Thread(target=trabalhar, daemon=True).start()

    @Slot(str, bool)
    def largarAqui(self, urls, mover):
        """Arrastar ficheiros (de outra janela ou de outro programa) para esta pasta."""
        origens = [QUrl(u).toLocalFile() for u in urls.split('\n') if u.startswith('file://')]
        origens = [o for o in origens if o and os.path.exists(o)]
        if origens and not self._caminho.startswith('carinae:'):
            self._colar_fundo(origens, mover, self._caminho)

    @Slot(int, str, bool)
    def largarEm(self, indice, urls, mover):
        if not (0 <= indice < len(self._itens)) or not self._itens[indice]['pasta']:
            return
        origens = [QUrl(u).toLocalFile() for u in urls.split('\n') if u.startswith('file://')]
        origens = [o for o in origens if o and os.path.exists(o) and o != self._itens[indice]['caminho']]
        if origens:
            self._colar_fundo(origens, mover, self._itens[indice]['caminho'])

    @Slot(str, str, bool)
    def largarPara(self, pasta, urls, mover):
        """Largar ficheiros numa pasta do painel de navegação ou num mosaico."""
        if not pasta or pasta.startswith('carinae:') or not os.path.isdir(pasta):
            return
        origens = [QUrl(u).toLocalFile() for u in urls.split('\n') if u.startswith('file://')]
        origens = [o for o in origens if o and os.path.exists(o) and os.path.dirname(o.rstrip('/')) != pasta.rstrip('/')]
        if origens:
            self._colar_fundo(origens, mover, pasta)

    @Slot()
    def abrirNovaJanela(self):
        subprocess.Popen([sys.executable, os.path.abspath(__file__),
                          self._caminho if not self._caminho.startswith('carinae:') else HOME], start_new_session=True)

    @Slot(result=str)
    def urlsDaSelecao(self):
        return '\n'.join(QUrl.fromLocalFile(self._itens[i]['caminho']).toString()
                         for i in self._selecao if 0 <= i < len(self._itens))

    @Slot()
    def selecionarTudo(self):
        self._selecao = list(range(len(self._itens)))
        self.mudou.emit()

    @Slot()
    def inverterSelecao(self):
        self._selecao = [i for i in range(len(self._itens)) if i not in self._selecao]
        self.mudou.emit()

    @Slot(str)
    def abrirTerminal(self, caminho):
        pasta = caminho or (self._caminho if not self._caminho.startswith('carinae:') else HOME)
        for t in ('carinae-terminal', 'x-terminal-emulator', 'gnome-terminal', 'xterm'):
            if shutil.which(t):
                args = [t, '--workdir', pasta] if t == 'carinae-terminal' else [t]
                subprocess.Popen(args, cwd=pasta, start_new_session=True)
                return

    @Slot(result=str)
    def tema(self):
        return 'escuro' if self._escuro else 'claro'


def religar_partilhas():
    """Ao entrar na sessão: liga as partilhas marcadas "voltar a ligar" (as senhas estão no chaveiro)."""
    try:
        redes = json.load(open(Arquivos.CFG_REDES, encoding='utf-8'))
    except Exception:
        return 0
    for r in redes:
        if r.get('religar') and r.get('url'):
            ok, erro = Arquivos._montar_gio(r['url'], r.get('utilizador', ''), '', r.get('dominio', ''))
            print('%s: %s' % (r['url'], 'ligada' if ok else erro))
    return 0


def pasta_inicial(argumentos):
    """Interpreta o que o atalho/portal passa: caminho ou file:///...

    Devolve (pasta, ficheiro_a_selecionar) — ou (None, None) se não houver nada útil.
    """
    import urllib.parse
    for a in argumentos:
        if not a or a.startswith('-'):
            continue
        caminho = urllib.parse.unquote(a[7:]) if a.startswith('file://') else a
        caminho = os.path.expanduser(caminho)
        if os.path.isdir(caminho):
            return os.path.abspath(caminho), None
        # ficheiro (mesmo que ainda não exista): abre a pasta e tenta selecioná-lo
        pai = os.path.dirname(os.path.abspath(caminho))
        if pai and os.path.isdir(pai) and pai != os.path.abspath(caminho):
            return pai, os.path.basename(caminho)
    return None, None


def main():
    if '--religar' in sys.argv:
        return religar_partilhas()
    QGuiApplication.setHighDpiScaleFactorRoundingPolicy(Qt.HighDpiScaleFactorRoundingPolicy.PassThrough)
    app = QGuiApplication(sys.argv)
    app.setApplicationName('Carinae Arquivos')
    app.setApplicationDisplayName('Documentos')
    app.setDesktopFileName('carinaeos-arquivos')
    app.setWindowIcon(QIcon.fromTheme('system-file-manager'))

    # as pastas especiais (Documentos, Imagens…) têm o seu desenho
    for f in Arquivos.pastas_utilizador():
        PASTAS_ESPECIAIS[f['caminho']] = f['icone']

    arquivos = Arquivos()
    # ícones dos ficheiros: no tema escuro, o tema da sessão; no claro, a versão clara dele
    QIcon.setThemeSearchPaths(['/usr/share/icons', '/usr/local/share/icons'] + QIcon.themeSearchPaths())
    atual = QIcon.themeName()
    tentativas = []
    if not arquivos.escuro and atual and 'dark' in atual.lower():
        tentativas.append(re.sub(r'[-_]?dark', '', atual, flags=re.I))
    tentativas += [atual, 'WhiteSur-dark' if arquivos.escuro else 'WhiteSur', 'Papirus-Dark', 'Adwaita']
    for nome in tentativas:
        if not nome:
            continue
        QIcon.setThemeName(nome)
        if not QIcon.fromTheme('text-x-generic').isNull():
            break
    QIcon.setFallbackThemeName('hicolor')

    motor = QQmlApplicationEngine()
    motor.addImageProvider('icones', Icones())
    motor.addImageProvider('miniaturas', Miniaturas())
    motor.rootContext().setContextProperty('arquivos', arquivos)

    motor.load(os.path.join(AQUI, 'Main.qml'))
    if not motor.rootObjects():
        return 1

    # pasta nos argumentos (caminho, file:///..., smb://, \\\\servidor ou carinae:rede): abre lá
    especial = next((a for a in sys.argv[1:] if a.startswith(('carinae:', 'smb://', '\\\\'))), None)
    pasta, ficheiro = (None, None) if especial else pasta_inicial(sys.argv[1:])
    if especial:
        arquivos.entrar(especial)
    if pasta:
        arquivos.entrar(pasta)
        if ficheiro:
            arquivos.selecionarPorNome(ficheiro)

    return app.exec()


if __name__ == '__main__':
    sys.exit(main())
