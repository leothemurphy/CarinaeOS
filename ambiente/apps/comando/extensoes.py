# CarinaeOS — Comando: extensões (como as do Ulauncher, mas nossas).
#
# Uma extensão é uma pasta com dois ficheiros:
#   extensao.json   {"nome": "Emojis", "descricao": "…", "icone": "face-smile",
#                    "palavras": ["emo"],      ← escreve-se "emo coração" (vazio = responde sempre)
#                    "comeca": ["~/", "/"]}    ← ou responde quando o texto começa assim (opcional)
#   extensao.py     def procurar(texto, ctx): devolve uma lista de resultados:
#                     {"titulo": "…", "sub": "…", "icone": "nome-do-icone ou /caminho.png",
#                      "acao": "copiar" | "abrir" | "correr" | "completar" | "terminal", "valor": "…"}
#                   "abrir" abre um endereço/arquivo; "correr" corre um comando; "completar" troca o
#                   texto da pesquisa (para navegar, ex.: pastas); "terminal" corre num terminal.
#                   ctx = {"casa": "/home/…", "idioma": "pt_BR", "palavra": a palavra usada ("g", "yt"…)}
#
# Pastas onde se procuram extensões (a do utilizador ganha se tiver o mesmo nome):
#   /usr/local/share/carinaeos/comando/extensoes/   (as que vêm com o CarinaeOS)
#   ~/.local/share/carinaeos/extensoes/              (as suas)
import importlib.util
import json
import os
import sys
import time
import traceback

AQUI = os.path.dirname(os.path.abspath(__file__))
HOME = os.path.expanduser('~')
PASTAS = [os.path.join(AQUI, 'extensoes'), os.path.join(HOME, '.local/share/carinaeos/extensoes')]
DESLIGADAS = os.path.join(HOME, '.config/carinaeos/extensoes-desligadas.json')


class Extensao:
    def __init__(self, pasta, info, modulo):
        self.pasta = pasta
        self.id = os.path.basename(pasta)
        self.nome = info.get('nome') or self.id
        self.descricao = info.get('descricao', '')
        self.icone = info.get('icone') or 'application-x-addon'
        if self.icone and '/' not in self.icone and os.path.exists(os.path.join(pasta, self.icone)):
            self.icone = os.path.join(pasta, self.icone)
        p = info.get('palavras', info.get('palavra', []))
        self.palavras = [p] if isinstance(p, str) else list(p or [])
        self.palavras = [x for x in self.palavras if x]
        self.comeca = list(info.get('comeca', []))
        self.sempre = bool(info.get('sempre', not self.palavras and not self.comeca))
        self.modulo = modulo
        self.lenta = 0.0          # se demorar muito sem palavra, deixa de ser chamada em cada tecla

    def responde(self, texto):
        """(texto para a extensão, com_palavra) ou None."""
        baixo = texto.lower()
        for p in self.palavras:
            if baixo.startswith(p.lower() + ' '):
                return texto[len(p):].strip(), True, p
            if baixo == p.lower():
                # só a palavra, sem espaço: mostra a dica, mas sem esconder os aplicativos ("senha" → Senhas)
                return '', False, p
        for c in self.comeca:
            if texto.startswith(c):
                return texto, True, ''
        if self.sempre and self.lenta < 0.25 and texto.strip():
            return texto, False, ''
        return None


def carregar():
    try:
        desligadas = set(json.load(open(DESLIGADAS, encoding='utf-8')))
    except (OSError, ValueError):
        desligadas = set()
    porId = {}
    for base in PASTAS:
        if not os.path.isdir(base):
            continue
        for nome in sorted(os.listdir(base)):
            pasta = os.path.join(base, nome)
            jf, pf = os.path.join(pasta, 'extensao.json'), os.path.join(pasta, 'extensao.py')
            if not (os.path.isfile(jf) and os.path.isfile(pf)):
                continue
            try:
                info = json.load(open(jf, encoding='utf-8'))
                spec = importlib.util.spec_from_file_location('carinae_ext_' + nome.replace('-', '_'), pf)
                mod = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(mod)
                porId[nome] = Extensao(pasta, info, mod)
            except Exception:
                print('comando: a extensão %s não carregou:' % nome, file=sys.stderr)
                traceback.print_exc()
    return [e for i, e in porId.items() if i not in desligadas]


def procurar(extensoes, texto, so_com_palavra=False):
    """Devolve (resultados, exclusivo): exclusivo = alguém respondeu à palavra (só esses contam)."""
    ctx = dict(casa=HOME, idioma=os.environ.get('LANG', 'pt_BR').split('.')[0])
    com_palavra, sem_palavra = [], []
    for e in extensoes:
        r = e.responde(texto)
        if r is None:
            continue
        sub_texto, palavra, qual = r
        if so_com_palavra and not palavra:
            continue
        t0 = time.time()
        try:
            itens = e.modulo.procurar(sub_texto, dict(ctx, palavra=qual)) or []
        except Exception as erro:
            itens = [dict(titulo='%s: erro' % e.nome, sub=str(erro), icone='dialog-error', acao='copiar', valor=str(erro))]
        dur = time.time() - t0
        if not palavra:
            e.lenta = max(e.lenta * 0.7, dur)
        for it in itens[:12]:
            it.setdefault('icone', e.icone)
            it['_ext'] = e.nome
        (com_palavra if palavra else sem_palavra).extend(itens[:12 if palavra else 4])
    if com_palavra:
        return com_palavra, True
    return sem_palavra, False


def ajuda(extensoes):
    """O que aparece ao escrever "?": cada extensão e como se usa."""
    r = []
    for e in extensoes:
        como = ', '.join(e.palavras + e.comeca) or 'responde sozinha'
        r.append(dict(titulo=e.nome, sub='%s  ·  %s' % (como, e.descricao), icone=e.icone,
                      acao='completar', valor=(e.palavras[0] + ' ') if e.palavras else (e.comeca[0] if e.comeca else '')))
    r.append(dict(titulo='Pasta das suas extensões', sub='~/.local/share/carinaeos/extensoes — veja o LEIA-ME', icone='folder',
                  acao='abrir', valor=PASTAS[1]))
    return r
