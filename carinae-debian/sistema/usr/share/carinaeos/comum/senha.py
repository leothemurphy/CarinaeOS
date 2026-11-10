# CarinaeOS - pedir uma senha com a janela da marca (usado pelo Cadeado e pelo agente de permissões).
import os

from PySide6.QtCore import Property, QObject, Signal, Slot

AQUI = os.path.dirname(os.path.abspath(__file__))
QML = os.path.join(AQUI, 'Senha.qml')


class Pedido(QObject):
    mudou = Signal()
    erroChanged = Signal()
    respondido = Signal(str)
    cancelado = Signal()

    def __init__(self, titulo, mensagem='', subtitulo='Segurança do sistema', detalhe='', rotulo='Senha',
                 botao='Continuar', nova=False):
        super().__init__()
        self._d = dict(titulo=titulo, mensagem=mensagem, subtitulo=subtitulo, detalhe=detalhe, rotulo=rotulo,
                       botao=botao, nova=nova)
        self._erro = ''

    titulo = Property(str, lambda s: s._d['titulo'], notify=mudou)
    mensagem = Property(str, lambda s: s._d['mensagem'], notify=mudou)
    subtitulo = Property(str, lambda s: s._d['subtitulo'], notify=mudou)
    detalhe = Property(str, lambda s: s._d['detalhe'], notify=mudou)
    rotulo = Property(str, lambda s: s._d['rotulo'], notify=mudou)
    botao = Property(str, lambda s: s._d['botao'], notify=mudou)
    nova = Property(bool, lambda s: s._d['nova'], notify=mudou)
    erro = Property(str, lambda s: s._erro, notify=erroChanged)

    def mostrar_erro(self, texto):
        self._erro = texto
        self.erroChanged.emit()

    @Slot(str)
    def responder(self, senha):
        self.respondido.emit(senha)

    @Slot()
    def cancelar(self):
        self.cancelado.emit()
