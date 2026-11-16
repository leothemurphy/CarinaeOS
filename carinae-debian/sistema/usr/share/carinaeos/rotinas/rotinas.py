#!/usr/bin/python3
# CarinaeOS - Rotinas: criar e editar as rotinas do Deck (vários passos num só toque).
#   carinaeos-rotinas                    abre o editor
#   carinaeos-rotinas --editar ID        abre já nessa rotina   (--nova: uma rotina nova)
#   carinaeos-rotinas --correr ID        corre a rotina (o Deck usa isto)
#   carinaeos-rotinas --gatilho minuto|entrar   as rotinas com hora (relógio) ou ao entrar na sessão
import json
import os
import subprocess
import sys
import threading

sys.path.insert(0, '/usr/share/carinaeos/comum')
import rotinas as R  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
DECK = os.path.expanduser('~/.config/carinaeos-deck.json')

if __name__ == '__main__' and len(sys.argv) > 2 and sys.argv[1] == '--correr':
    sys.exit(R.correr(sys.argv[2]))
if __name__ == '__main__' and len(sys.argv) > 2 and sys.argv[1] == '--gatilho':
    R.gatilho(sys.argv[2])
    sys.exit(0)

from base import iniciar  # noqa: E402
from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot  # noqa: E402


def ler_deck():
    try:
        with open(DECK, encoding='utf-8') as f:
            d = json.load(f)
            return d if isinstance(d, list) else None
    except (OSError, ValueError):
        return None


class Rotinas(QObject):
    mudou = Signal()
    _chegou = Signal(object, object)

    def __init__(self, inicio):
        super().__init__()
        self._lista = R.ler()
        self._inicio = inicio
        self._catalogo = []
        self._apps = []
        self._msg = ''
        self._chegou.connect(lambda f, r: f(r))
        self._fundo(lambda: json.loads(subprocess.run(['carinaeos-deck', 'catalogo'], capture_output=True, text=True,
                                                      timeout=40).stdout or '[]'), self._com_catalogo)
        self._fundo(R.aplicativos, self._com_apps)
        self._relogio = QTimer(self)          # o "Rodando…" de cada rotina
        self._relogio.setInterval(1500)
        self._relogio.timeout.connect(self.mudou.emit)
        self._relogio.start()

    def _fundo(self, trabalho, depois):
        def t():
            try:
                r = trabalho()
            except Exception as e:
                r = e
            self._chegou.emit(depois, r)
        threading.Thread(target=t, daemon=True).start()

    def _com_catalogo(self, r):
        if isinstance(r, list):
            self._catalogo = [g for g in r if g.get('grupo') != 'Rotinas']
            self.mudou.emit()

    def _com_apps(self, r):
        if isinstance(r, list):
            self._apps = [dict(app=a['app'], nome=a['nome'], icone=a['icone']) for a in r]
            self.mudou.emit()

    lista = Property('QVariantList', lambda s: [dict(r, quando=R.descrever_gatilho(r.get('gatilho')),
                                                     correndo=R.correndo(r['id']),
                                                     noDeck=any(t.get('id') == 'rot:' + r['id'] for t in (ler_deck() or [])))
                                                for r in s._lista], notify=mudou)
    catalogo = Property('QVariantList', lambda s: s._catalogo, notify=mudou)
    apps = Property('QVariantList', lambda s: s._apps, notify=mudou)
    inicio = Property(str, lambda s: s._inicio, constant=True)
    mensagem = Property(str, lambda s: s._msg, notify=mudou)

    def _aviso(self, t):
        self._msg = t
        self.mudou.emit()

    @Slot('QVariantMap', result=str)
    def descrever(self, p):
        return R.descrever(dict(p))

    @Slot(str, result=str)
    def salvar(self, texto):
        """Grava uma rotina (JSON); devolve o id (novo, se ainda não tinha)."""
        r = json.loads(texto)
        r['nome'] = (r.get('nome') or '').strip() or 'Rotina'
        if not r.get('id'):
            r['id'] = R.novo_id(r['nome'], self._lista)
        i = next((k for k, x in enumerate(self._lista) if x['id'] == r['id']), -1)
        if i >= 0:
            self._lista[i] = r
        else:
            self._lista.append(r)
        R.gravar(self._lista)
        # o nome e o ícone da tecla no Deck acompanham a rotina
        d = ler_deck()
        if d is not None and any(t.get('id') == 'rot:' + r['id'] for t in d):
            for t in d:
                if t.get('id') == 'rot:' + r['id']:
                    t['nome'], t['icone'] = r['nome'], r.get('icone') or 'media-playlist-play'
            self._gravar_deck(d)
        self._aviso('✓ %s salva.' % r['nome'])
        return r['id']

    @Slot(str)
    def apagar(self, ident):
        self._lista = [r for r in self._lista if r['id'] != ident]
        R.gravar(self._lista)
        d = ler_deck()
        if d is not None:
            self._gravar_deck([t for t in d if t.get('id') != 'rot:' + ident])
        self._aviso('Rotina apagada.')

    @Slot(str)
    def testar(self, ident):
        R.lancar(ident)
        self._aviso('Rodando…')

    @Slot(str)
    def porNoDeck(self, ident):
        r = next((x for x in self._lista if x['id'] == ident), None)
        if not r:
            return
        d = ler_deck()
        if d is None:       # ainda o Deck original: começa por ele
            d = [dict(id='rot:' + m['id'], nome=m['nome'], icone=m['icone']) for m in R.MODELOS]
        if not any(t.get('id') == 'rot:' + ident for t in d):
            d.append(dict(id='rot:' + ident, nome=r['nome'], icone=r.get('icone') or 'media-playlist-play'))
            self._gravar_deck(d)
        self._aviso('✓ %s está no Deck (Launchpad › Deck).' % r['nome'])

    def _gravar_deck(self, d):
        os.makedirs(os.path.dirname(DECK), exist_ok=True)
        with open(DECK + '.tmp', 'w', encoding='utf-8') as f:
            json.dump(d, f, ensure_ascii=False)
        os.replace(DECK + '.tmp', DECK)
        self.mudou.emit()


if __name__ == '__main__':
    ini = ''
    if len(sys.argv) > 2 and sys.argv[1] == '--editar':
        ini = sys.argv[2]
    elif len(sys.argv) > 1 and sys.argv[1] == '--nova':
        ini = '+nova'
    sys.exit(iniciar('carinaeos-rotinas', 'Rotinas', 'media-playlist-play', os.path.join(AQUI, 'Main.qml'),
                     {'rotinas': lambda: Rotinas(ini)}))
