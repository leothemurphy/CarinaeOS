#!/usr/bin/env python3
# CarinaeOS — Carinae Emojis (como o painel Win+. do Windows 11): Super+. abre, escolhe-se e o emoji
# é escrito onde se estava a escrever. Nomes e palavras em português (dados: Emojibase, licença MIT).
import json
import os
import shutil
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
for _p in ('/usr/local/share/carinaeos/comum', '/usr/share/carinaeos/comum', os.path.join(AQUI, '..', 'comum')):
    if os.path.isdir(_p):
        sys.path.insert(0, _p)
        break

from PySide6.QtCore import QObject, Property, QTimer, Signal, Slot  # noqa: E402
from PySide6.QtGui import QCursor, QGuiApplication  # noqa: E402

ESTADO = os.path.expanduser('~/.local/share/carinaeos/emojis.json')
GRUPOS = [('recentes', '🕒', 'Usados recentemente'), (0, '😀', 'Sorrisos e emoções'), (1, '👋', 'Pessoas e corpo'),
          (3, '🐻', 'Animais e natureza'), (4, '🍔', 'Comida e bebida'), (5, '✈️', 'Viagens e lugares'),
          (6, '⚽', 'Atividades'), (7, '💡', 'Objetos'), (8, '🔣', 'Símbolos'), (9, '🏁', 'Bandeiras')]
TONS = ['', '🏻', '🏼', '🏽', '🏾', '🏿']


def sem_acentos(t):
    import unicodedata
    return ''.join(c for c in unicodedata.normalize('NFD', t.lower()) if unicodedata.category(c) != 'Mn')


class Emojis(QObject):
    mudou = Signal()

    def __init__(self):
        super().__init__()
        self._todos = json.load(open(os.path.join(AQUI, 'emojis.json'), encoding='utf-8'))
        self._busca = [sem_acentos(e[1] + ' ' + e[2]) for e in self._todos]
        self._por_char = {e[0]: e for e in self._todos}
        try:
            d = json.load(open(ESTADO, encoding='utf-8'))
        except (OSError, ValueError):
            d = {}
        self._recentes = d.get('recentes', [])[:40]
        self._tom = d.get('tom', 0)
        self._texto = ''
        self._grupo = 'recentes' if self._recentes else 0
        self._lista = self._calcular()

    def _gravar(self):
        try:
            os.makedirs(os.path.dirname(ESTADO), exist_ok=True)
            json.dump(dict(recentes=self._recentes, tom=self._tom), open(ESTADO, 'w', encoding='utf-8'), ensure_ascii=False)
        except OSError:
            pass

    def _com_tom(self, e):
        if self._tom and e[4]:
            return e[4][self._tom - 1] if self._tom - 1 < len(e[4]) else e[0]
        return e[0]

    @Property('QVariantList', notify=mudou)
    def lista(self):
        return self._lista

    def _refazer(self):
        self._lista = self._calcular()
        self.mudou.emit()

    def _calcular(self):
        if self._texto:
            q = sem_acentos(self._texto).split()
            r = [e for e, b in zip(self._todos, self._busca) if all(p in b for p in q)]
            # os que começam pela palavra procurada primeiro
            r.sort(key=lambda e: 0 if sem_acentos(e[1]).startswith(q[0]) else 1)
        elif self._grupo == 'recentes':
            r = [self._por_char.get(c) or [c, '', '', -1, []] for c in self._recentes]
        else:
            r = [e for e in self._todos if e[3] == self._grupo]
        return [dict(e=self._com_tom(e), nome=e[1], tons=bool(e[4])) for e in r]

    @Property('QVariantList', constant=True)
    def grupos(self):
        return [dict(id=str(g[0]), icone=g[1], nome=g[2]) for g in GRUPOS]

    @Property(str, notify=mudou)
    def grupo(self):
        return str(self._grupo)

    @Slot(str)
    def escolherGrupo(self, g):
        self._grupo = 'recentes' if g == 'recentes' else int(g)
        self._texto = ''
        self._refazer()

    @Slot(str)
    def procurar(self, t):
        self._texto = t.strip()
        self._refazer()

    @Property(int, notify=mudou)
    def tom(self):
        return self._tom

    @Property('QVariantList', constant=True)
    def tons(self):
        return ['✋' + t if t else '✋' for t in TONS]

    @Slot(int)
    def definirTom(self, t):
        self._tom = t
        self._gravar()
        self._refazer()

    @Slot(str, bool)
    def escolher(self, e, ficarAberto):
        base = e
        for t in TONS[1:]:
            base = base.replace(t, '')
        if base in self._recentes:
            self._recentes.remove(base)
        self._recentes.insert(0, base)
        del self._recentes[40:]
        self._gravar()
        QGuiApplication.clipboard().setText(e)
        if ficarAberto:
            # Shift+clique: escreve e fica aberto (para vários seguidos)
            self._escrever(e, 0)
            return
        for j in QGuiApplication.topLevelWindows():
            j.hide()
        self._escrever(e, 150, sair=True)

    def _escrever(self, e, atraso, sair=False):
        def fazer():
            if shutil.which('xdotool'):
                subprocess.run(['xdotool', 'type', '--clearmodifiers', '--delay', '8', '--', e])
            if sair:
                QTimer.singleShot(200, QGuiApplication.quit)
        QTimer.singleShot(atraso, fazer)

    @Slot(result='QVariantList')
    def posicao(self):
        """Ao pé do rato, sem sair do ecrã."""
        p = QCursor.pos()
        ecra = QGuiApplication.screenAt(p) or QGuiApplication.primaryScreen()
        g = ecra.availableGeometry()
        w, h = 380, 460
        x = min(max(g.x() + 8, p.x() - w // 2), g.x() + g.width() - w - 8)
        y = p.y() + 24 if p.y() + 24 + h < g.y() + g.height() else p.y() - h - 12
        return [x, max(g.y() + 8, y)]


def main():
    from base import iniciar
    return iniciar('carinaeos-emojis', 'Carinae Emojis', 'carinaeos-emojis', os.path.join(AQUI, 'Main.qml'), {'emojis': Emojis})


if __name__ == '__main__':
    sys.exit(main())
