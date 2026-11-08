#!/usr/bin/env python3
# CarinaeOS - monta a ordem de instalacao a partir das dependencias do livro BLFS.
# Le, em cada pagina, as dependencias "Required" e "Recommended" (como o livro
# recomenda) e devolve uma lista em que cada pacote vem depois das suas
# dependencias. Paginas ja instaladas (/root/blfs-logs/<pagina>.ok) ficam de fora.
#
#   python3 plano.py procura plasma        -> lista paginas cujo titulo contem "plasma"
#   python3 plano.py kde/plasma-all ...    -> grava a fila em /root/blfs-fila.txt
import os, re, sys, html, urllib.request as r

B = 'https://www.linuxfromscratch.org/blfs/view/13.1-systemd/'
CACHE = '/sources/blfs/paginas'
OK = os.environ.get('OKDIR', '/root/blfs-logs')
os.makedirs(CACHE, exist_ok=True) if not os.environ.get('LIVRO') else None

LOCAL = os.environ.get('LIVRO')
def pagina(p):
    if LOCAL: return normaliza(open(os.path.join(LOCAL, p + '.html'), encoding='utf-8').read())
    f = os.path.join(CACHE, p.replace('/', '__') + '.html')
    if not os.path.exists(f):
        req = r.Request(B + p + '.html', headers={'User-Agent': 'Wget/1.25'})
        open(f, 'wb').write(r.urlopen(req, timeout=120).read())
    return normaliza(open(f, encoding='utf-8').read())

def normaliza(s):
    # o HTML publicado passa pelo tidy, que quebra atributos em varias linhas
    # (ex.: class=\n"replaceable"); normalizamos antes de procurar
    s = re.sub(r'=\s+"', '="', s)
    s = re.sub(r'<(\w+)\s+', r'<\1 ', s)
    s = re.sub(r'(<h2 class="sect2">)\s+', r'\1', s)
    return s

def txt(x): return html.unescape(re.sub(r'<[^>]+>', '', x)).strip()

def titulo(p):
    if '#' in p:
        m = re.search(r'</a>(.*?)</h2>', trecho(p), re.S)
        return txt(m.group(1)) if m else p
    m = re.search(r'<title>(.*?)</title>', pagina(p), re.S)
    return txt(m.group(1)) if m else p

COLECOES = {'general/python-modules', 'general/python-dependencies',
            'general/perl-modules', 'general/perl-deps'}

def secoes(p):
    """divide a pagina nas secoes <h2 class="sect2"><a id=...> (pacotes dentro da pagina)"""
    s = pagina(p)
    marcas = [(m.start(), m.group(1)) for m in
              re.finditer(r'<h2 class="sect2"><a id="([^"]+)"', s)]
    return s, marcas

def trecho(p):
    """HTML do no: pagina inteira ou so a secao do #ancora"""
    pg, _, anc = p.partition('#')
    s, marcas = secoes(pg)
    if not anc: return s
    for i, (ini, a) in enumerate(marcas):
        if a == anc:
            fim = marcas[i + 1][0] if i + 1 < len(marcas) else len(s)
            return s[ini:fim]
    return s

def links_diretos(corpo):
    # so os itens da lista; links dentro de parenteses sao comentarios do livro
    # (ex.: "Graphite2 (necessario para TeX Live ou LibreOffice ...)")
    nivel, fora = 0, []
    for parte in re.split(r'(<a class="xref"[^>]*>.*?</a>)', corpo, flags=re.S):
        if parte.startswith('<a class="xref"'):
            if nivel == 0:
                m = re.search(r'href="([^"#]+)\.html(#[^"]*)?"', parte)
                if m: fora.append((m.group(1), m.group(2) or ''))
        else:
            t = re.sub(r'<[^>]+>', '', parte)
            nivel = max(0, nivel + t.count('(') - t.count(')'))
    return fora

def deps(p):
    pg = p.partition('#')[0]
    s = trecho(p)
    if pg in COLECOES and '#' not in p: s = s[:secoes(pg)[1][0][0]] if secoes(pg)[1] else s
    secao = pg.split('/')[0]
    req, rec = [], []
    for cl, corpo in re.findall(r'<p class="(required|recommended)">(.*?)</p>', s, re.S):
        for h, anc in links_diretos(corpo):
            h = h[3:] if h.startswith('../') else secao + '/' + h
            alvo = h + anc if (anc and h in COLECOES | {'x/x7driver', 'general/python-modules'}) else h
            if alvo != p and alvo != pg:
                (req if cl == 'required' else rec).append(alvo)
    return req, rec

# fora do plano (revisto): impressao (CUPS) fica para depois; portais de outros
# ambientes (o Plasma traz o xdg-desktop-portal-kde); paginas que sao so indice/lista
EXCLUIR = {'pst/cups': 'impressao fica para depois (recomendado do Qt6)',
           'x/xdg-desktop-portal-gtk': 'portal do GTK/GNOME; o Plasma usa o seu',
           'gnome/xdg-desktop-portal-gnome': 'portal do GNOME',
           'x/xdg-desktop-portal-wlr': 'portal do wlroots',
           'lxqt/xdg-desktop-portal-lxqt': 'portal do LXQt',
           'x/installing': 'pagina de indice, nao e pacote',
           'x/TTF-and-OTF-fonts': 'lista de fontes; o CarinaeOS instala as suas a parte'}

def instalado(p):
    if p in EXCLUIR: return True
    return os.path.exists(os.path.join(OK, os.path.basename(p).replace('#', '-') + '.ok'))

if len(sys.argv) < 2:
    sys.exit(__doc__ or 'uso: plano.py procura <texto> | plano.py <pagina> ...')

if sys.argv[1] == 'procura':
    termo = ' '.join(sys.argv[2:]).lower()
    s = pagina('index')
    for h, t in re.findall(r'href="([a-z0-9_-]+/[A-Za-z0-9._+-]+)\.html"[^>]*>(.*?)</a>', s, re.S):
        if termo in txt(t).lower(): print(f'{h:40s} {txt(t)}')
    sys.exit()

ordem, visto, pilha, motivo, CICLOS = [], set(), [], {}, []
pendentes = {}
_fecho = {}

def fecho_req(p):
    """tudo o que p exige (Required), direta ou indiretamente"""
    if p in _fecho: return _fecho[p]
    res, falta = set(), [p]
    while falta:
        x = falta.pop()
        try: r, _ = deps(x)
        except Exception: r = []
        for d in r:
            if d not in res and not instalado(d):
                res.add(d); falta.append(d)
    _fecho[p] = res
    return res

def visita(p, por):
    if p in visto or instalado(p): return
    if p in pilha:
        CICLOS.append(' -> '.join(pilha[pilha.index(p):] + [p])); return
    pilha.append(p)
    try:
        req, rec = deps(p)
    except Exception as e:
        print(f'   AVISO: nao consegui ler {p}: {e}'); req, rec = [], []
    for d in req: visita(d, p)
    for d in rec:
        # recomendado que EXIGE algo ainda por instalar nesta cadeia: vem depois
        bloq = [x for x in pilha if x in fecho_req(d)]
        if bloq and d not in visto:
            pendentes.setdefault(bloq[0], []).append((d, p))
        else:
            visita(d, p)
    pilha.pop(); visto.add(p); ordem.append(p); motivo[p] = por
    for d, quem in pendentes.pop(p, []):
        visita(d, quem + ' (depois)')

for alvo in sys.argv[1:]: visita(alvo, 'alvo')

# acerto final: cada pacote depois de tudo o que ele EXIGE (Required).
# Ciclos verdadeiros seguem a ordem que o livro manda (ex.: o Shadow e
# reinstalado depois do Linux-PAM).
ORDEM_DO_LIVRO = [('postlfs/linux-pam', 'postlfs/shadow'),   # Shadow refeito depois do PAM
                  ('kde/phonon', 'kde/phonon-backend-vlc')]   # o livro: backend instalado depois
for _ in range(len(ordem)):
    mudou = False
    for n in list(ordem):
        i = ordem.index(n)
        try: req, _r = deps(n)
        except Exception: req = []
        tardios = [d for d in req if d in ordem and ordem.index(d) > i
                   and (n not in fecho_req(d) or (d, n) in ORDEM_DO_LIVRO)]
        if tardios:
            ultimo = max(ordem.index(d) for d in tardios)
            ordem.remove(n); ordem.insert(ultimo, n); mudou = True
    if not mudou: break
with open(os.environ.get('FILA','/root/blfs-fila.txt'), 'w') as f:
    for p in ordem: f.write(p + '\n')
for n, p in enumerate(ordem, 1):
    print(f'{n:4d}  {p:40s} {titulo(p)[:45]:45s} <- {motivo[p]}')
print('\n'.join(CICLOS[:0]) if False else f'   ({len(CICLOS)} ciclos do livro ignorados)')
print(f'== {len(ordem)} paginas na fila: /root/blfs-fila.txt')
