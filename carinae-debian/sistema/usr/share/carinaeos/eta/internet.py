# CarinaeOS - Eta: pesquisar na internet quando nao sabe (DuckDuckGo, sem conta nem chave).
# Devolve os primeiros resultados e um trecho das paginas mais relevantes, com as fontes.
import html
import re
import urllib.parse
import urllib.request

AGENTE = 'Mozilla/5.0 (X11; Linux x86_64)'


def _baixar(url, limite=600000, tempo=8):
    r = urllib.request.Request(url, headers={'User-Agent': AGENTE, 'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.6'})
    with urllib.request.urlopen(r, timeout=tempo) as f:
        tipo = f.headers.get('Content-Type', '')
        if 'html' not in tipo and 'text' not in tipo:
            return ''
        return f.read(limite).decode(f.headers.get_content_charset() or 'utf-8', 'ignore')


def _texto(pagina):
    pagina = re.sub(r'(?is)<(script|style|nav|header|footer|aside|form|noscript|svg)[^>]*>.*?</\1>', ' ', pagina)
    pagina = re.sub(r'(?i)<(br|p|div|li|h[1-6]|tr|pre)[^>]*>', '\n', pagina)
    t = html.unescape(re.sub(r'<[^>]+>', ' ', pagina))
    t = re.sub(r'[ \t\r\f\v]+', ' ', t)
    return re.sub(r'\n\s*\n+', '\n', t).strip()


def _trecho(texto, consulta, tamanho=1400):
    """A parte da pagina com mais palavras da pesquisa."""
    palavras = [w for w in re.findall(r'\w{4,}', consulta.lower())]
    linhas = [l.strip() for l in texto.split('\n') if len(l.strip()) > 30]
    if not linhas:
        return ''
    melhor, pontos = 0, -1
    for i in range(len(linhas)):
        bloco = ' '.join(linhas[i:i + 8]).lower()
        p = sum(bloco.count(w) for w in palavras)
        if p > pontos:
            melhor, pontos = i, p
    out = ''
    for l in linhas[melhor:]:
        if len(out) + len(l) > tamanho:
            break
        out += l + '\n'
    return out.strip()


def _url(href):
    u = re.search(r'uddg=([^&]+)', href)
    return urllib.parse.unquote(u.group(1)) if u else html.unescape(href)


def _limpo(t):
    return html.unescape(re.sub(r'<[^>]+>', '', t or '')).strip()


def _ddg_html(consulta, n):
    pagina = _baixar('https://html.duckduckgo.com/html/?' + urllib.parse.urlencode({'q': consulta}))
    res = []
    for m in re.finditer(r'class="result__a" href="([^"]+)"[^>]*>(.*?)</a>(.*?)(?=class="result__a"|$)', pagina, re.S):
        href, titulo, resto = m.groups()
        snip = re.search(r'class="result__snippet"[^>]*>(.*?)</a>', resto, re.S)
        res.append(dict(titulo=_limpo(titulo), url=_url(href), resumo=_limpo(snip.group(1) if snip else '')))
    return res


def _ddg_lite(consulta, n):
    pagina = _baixar('https://lite.duckduckgo.com/lite/?' + urllib.parse.urlencode({'q': consulta}))
    res = []
    for m in re.finditer(r'href="([^"]+)" class=.result-link.>(.*?)</a>(.*?)(?=result-link|$)', pagina, re.S):
        href, titulo, resto = m.groups()
        snip = re.search(r"class='result-snippet'>(.*?)</td>", resto, re.S)
        res.append(dict(titulo=_limpo(titulo), url=_url(href), resumo=_limpo(snip.group(1) if snip else '')))
    return res


def _wikipedia(consulta, n):
    import json
    r = urllib.request.Request('https://pt.wikipedia.org/w/api.php?' + urllib.parse.urlencode(
        dict(action='query', list='search', srsearch=consulta, format='json', srlimit=n)),
        headers={'User-Agent': 'CarinaeOS-Eta/1.0 (https://github.com/leothemurphy/CarinaeOS)'})
    with urllib.request.urlopen(r, timeout=8) as f:
        d = json.load(f)
    return [dict(titulo=x['title'], url='https://pt.wikipedia.org/wiki/' + urllib.parse.quote(x['title'].replace(' ', '_')),
                 resumo=_limpo(x.get('snippet', ''))) for x in d.get('query', {}).get('search', [])]


def resultados(consulta, n=5):
    """DuckDuckGo (pagina normal e versao leve); se ambos falharem, a Wikipedia."""
    for motor in (_ddg_html, _ddg_lite, _wikipedia):
        try:
            res = [r for r in motor(consulta, n) if 'duckduckgo.com/y.js' not in r['url'] and r['url'].startswith('http')]
        except Exception:
            continue
        if res:
            return res[:n]
    return []


def pesquisar(consulta, paginas=2):
    """Texto para a IA: resultados numerados e trechos das primeiras paginas."""
    try:
        rs = resultados(consulta)
    except Exception as e:
        return 'A pesquisa falhou (%s). Talvez não haja internet.' % e
    if not rs:
        return 'A pesquisa não encontrou nada.'
    partes = ['Resultados da pesquisa por “%s” (cite as fontes pelo número e o endereço):' % consulta]
    for i, r in enumerate(rs, 1):
        partes.append('[%d] %s — %s\n%s' % (i, r['titulo'], r['url'], r['resumo']))
    lidas = 0
    for i, r in enumerate(rs, 1):
        if lidas >= paginas:
            break
        if re.search(r'youtube\.|facebook\.|instagram\.|tiktok\.|twitter\.|//x\.com|reddit\.com/media', r['url']):
            continue                                   # paginas so com JavaScript: fica o resumo
        try:
            t = _trecho(_texto(_baixar(r['url'])), consulta)
        except Exception:
            continue
        if t:
            partes.append('Trecho de [%d] %s:\n%s' % (i, r['url'], t))
            lidas += 1
    return '\n\n'.join(partes)


if __name__ == '__main__':
    import sys
    print(pesquisar(' '.join(sys.argv[1:]) or 'elegoo slicer linux'))
