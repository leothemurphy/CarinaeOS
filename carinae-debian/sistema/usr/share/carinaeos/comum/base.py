# CarinaeOS - pecas comuns aos aplicativos Supernova e Orbita (PySide6 + QML)
import os
import shlex
import subprocess
import sys

from PySide6.QtCore import QObject, QProcess, QSize, Qt, Signal, Slot
from PySide6.QtGui import QGuiApplication, QIcon, QPixmap
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickImageProvider
from PySide6.QtQuickControls2 import QQuickStyle


class Icones(QQuickImageProvider):
    """image://icone/<nome> -> icone do tema (Breeze/CarinaeOS) ou ficheiro."""

    def __init__(self):
        super().__init__(QQuickImageProvider.ImageType.Pixmap)

    def requestPixmap(self, ident, size, pedido):
        lado = max(pedido.width(), pedido.height(), 64)
        if ident.startswith('/') and os.path.exists(ident):
            pm = QPixmap(ident)
            if not pm.isNull():
                return pm.scaled(lado, lado, Qt.AspectRatioMode.KeepAspectRatio,
                                 Qt.TransformationMode.SmoothTransformation)
        icone = QIcon.fromTheme(ident)
        if icone.isNull():
            icone = QIcon.fromTheme('application-x-executable')
        return icone.pixmap(QSize(lado, lado))


def correr(cmd, espera=True):
    """Corre um comando; devolve (codigo, saida). Nunca levanta excecao."""
    try:
        if isinstance(cmd, str):
            cmd = shlex.split(cmd)
        if not espera:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
            return 0, ''
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        return r.returncode, r.stdout.strip()
    except Exception as e:
        return 1, str(e)


def iniciar(nome_app, titulo, icone, qml, contexto):
    QQuickStyle.setStyle('Basic')
    app = QGuiApplication(sys.argv)
    app.setApplicationName(nome_app)
    app.setApplicationDisplayName(titulo)
    app.setDesktopFileName(nome_app)
    app.setWindowIcon(QIcon.fromTheme(icone))
    motor = QQmlApplicationEngine()
    motor.addImageProvider('icone', Icones())
    for k, v in contexto.items():
        motor.rootContext().setContextProperty(k, v)
    motor.load(qml)
    if not motor.rootObjects():
        sys.exit(1)
    return app.exec()
