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
OK = '/root/blfs-logs'
os.makedirs(CACHE, exist_ok=True)

def pagina(p):
    f = os.path.join(CACHE, p.replace('/', '__') + '.html')
    if not os.path.exists(f):
        req = r.Request(B + p + '.html', headers={'User-Agent': 'Wget/1.25'})
        open(f, 'wb').write(r.urlopen(req, timeout=120).read())
    return open(f, encoding='utf-8').read()

def txt(x): return html.unescape(re.sub(r'<[^>]+>', '', x)).strip()

def titulo(p):
    m = re.search(r'<title>(.*?)</title>', pagina(p), re.S)
    return txt(m.group(1)) if m else p

def deps(p):
    s = pagina(p)
    i = s.find('Dependencies')
    if i < 0: return [], []
    s = s[i:]
    fim = re.search(r'<h[23][^>]*>\s*(Installation|Kernel Configuration|Downloading)', s)
    if fim: s = s[:fim.start()]
    req, rec = [], []
    for cl, corpo in re.findall(r'<p class="(required|recommended)">(.*?)</p>', s, re.S):
        for h in re.findall(r'href="\.\./([a-z0-9_-]+/[A-Za-z0-9._+-]+?)\.html(?:#[^"]*)?"', corpo):
            (req if cl == 'required' else rec).append(h)
    return req, rec

def instalado(p): return os.path.exists(os.path.join(OK, os.path.basename(p) + '.ok'))

if len(sys.argv) < 2:
    sys.exit(__doc__ or 'uso: plano.py procura <texto> | plano.py <pagina> ...')

if sys.argv[1] == 'procura':
    termo = ' '.join(sys.argv[2:]).lower()
    s = pagina('index')
    for h, t in re.findall(r'href="([a-z0-9_-]+/[A-Za-z0-9._+-]+)\.html"[^>]*>(.*?)</a>', s, re.S):
        if termo in txt(t).lower(): print(f'{h:40s} {txt(t)}')
    sys.exit()

ordem, visto, pilha, motivo = [], set(), [], {}
def visita(p, por):
    if p in visto or instalado(p): return
    if p in pilha:
        print(f'   (ciclo ignorado: {" -> ".join(pilha[pilha.index(p):] + [p])})'); return
    pilha.append(p)
    try:
        req, rec = deps(p)
    except Exception as e:
        print(f'   AVISO: nao consegui ler {p}: {e}'); req, rec = [], []
    for d in req + rec: visita(d, p)
    pilha.pop(); visto.add(p); ordem.append(p); motivo[p] = por

for alvo in sys.argv[1:]: visita(alvo, 'alvo')
with open('/root/blfs-fila.txt', 'w') as f:
    for p in ordem: f.write(p + '\n')
for n, p in enumerate(ordem, 1):
    print(f'{n:4d}  {p:40s} {titulo(p)[:45]:45s} <- {motivo[p]}')
print(f'== {len(ordem)} paginas na fila: /root/blfs-fila.txt')
