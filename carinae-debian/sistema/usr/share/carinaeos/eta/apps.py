# CarinaeOS - Eta: os aplicativos instalados (para "abre o LibreOffice", "abre o Chrome"...)
import glob
import os
import re
import unicodedata

PASTAS = ['/usr/share/applications', '/usr/local/share/applications',
          os.path.expanduser('~/.local/share/applications'),
          os.path.expanduser('~/.local/share/flatpak/exports/share/applications'),
          '/var/lib/flatpak/exports/share/applications']

# nomes escritos de varias formas -> uma so palavra
SINONIMOS = [(r'\blibre ?office\b', 'libreoffice'), (r'\bgoogle chrome\b', 'chrome'), (r'\b(vs ?code|visual studio code)\b', 'vscode'),
             (r'\bobs studio\b', 'obs'), (r'\bms ?teams\b|\bmicrosoft teams\b', 'teams'), (r'\bmicrosoft edge\b', 'edge'),
             (r'\bwhats ?app\b', 'whatsapp'), (r'\bfire ?fox\b', 'firefox'), (r'\bonly ?office\b', 'onlyoffice'),
             (r'\bgerenciador de arquivos\b|\bexplorador de arquivos\b', 'arquivos')]


def simples(t):
    t = unicodedata.normalize('NFD', (t or '').lower())
    return ''.join(c for c in t if unicodedata.category(c) != 'Mn')


def normalizar(s):
    for p, r in SINONIMOS:
        s = re.sub(p, r, s)
    return s


_cache = None


def instalados():
    """[(nome simples, nome, caminho .desktop)] dos aplicativos visiveis."""
    global _cache
    if _cache is not None:
        return _cache
    vistos, res = set(), []
    for pasta in PASTAS:
        for f in sorted(glob.glob(os.path.join(pasta, '*.desktop'))):
            base = os.path.basename(f)
            if base in vistos:
                continue
            nome, oculto, tipo = '', False, 'Application'
            try:
                with open(f, encoding='utf-8', errors='ignore') as fh:
                    secao = ''
                    for l in fh:
                        l = l.strip()
                        if l.startswith('['):
                            secao = l
                            continue
                        if secao != '[Desktop Entry]':
                            continue
                        if l.startswith('Name=') and not nome:
                            nome = l[5:]
                        elif l.startswith(('NoDisplay=true', 'Hidden=true')):
                            oculto = True
                        elif l.startswith('Type='):
                            tipo = l[5:]
            except OSError:
                continue
            vistos.add(base)
            if nome and not oculto and tipo == 'Application':
                chave = normalizar(simples(nome))
                res.append((chave, nome, f, normalizar(simples(base.replace('.desktop', '')))))
    _cache = res
    return res


def procurar(texto):
    """O aplicativo instalado mencionado no texto (nome mais comprido primeiro), ou None."""
    s = normalizar(simples(texto))
    melhor = None
    for chave, nome, caminho, ident in instalados():
        palavras = [w for w in re.findall(r'\w{3,}', chave) if w not in ('de', 'do', 'da')]
        if not palavras:
            continue
        if re.search(r'\b' + re.escape(chave) + r'\b', s) or (len(palavras) == 1 and re.search(r'\b' + re.escape(palavras[0]) + r'\b', s)) \
                or re.search(r'\b' + re.escape(ident.split('.')[-1]) + r'\b', s):
            if not melhor or len(chave) > len(melhor[0]):
                melhor = (chave, nome, caminho)
    return melhor


def comando_abrir(caminho):
    return 'gio launch %s' % caminho.replace(' ', '\\ ')
