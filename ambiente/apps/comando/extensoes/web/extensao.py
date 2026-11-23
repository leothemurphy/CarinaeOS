from urllib.parse import quote

SITES = {
    'g': ('Google', 'https://www.google.com/search?q=%s', 'internet-web-browser'),
    'yt': ('YouTube', 'https://www.youtube.com/results?search_query=%s', 'video-x-generic'),
    'wiki': ('Wikipédia', 'https://pt.wikipedia.org/w/index.php?search=%s', 'accessories-dictionary'),
    'mapa': ('Mapas', 'https://www.openstreetmap.org/search?query=%s', 'mark-location'),
    'trad': ('Tradutor', 'https://translate.google.com/?sl=auto&tl=pt&text=%s', 'preferences-desktop-locale'),
    'img': ('Imagens', 'https://www.google.com/search?tbm=isch&q=%s', 'image-x-generic'),
    'ddg': ('DuckDuckGo', 'https://duckduckgo.com/?q=%s', 'internet-web-browser'),
}


def procurar(texto, ctx):
    nome, url, icone = SITES.get(ctx.get('palavra', 'g'), SITES['g'])
    if not texto:
        return [dict(titulo='%s: escreva o que procura' % nome, sub=url.split('/')[2], icone=icone, acao='completar',
                     valor=ctx.get('palavra', 'g') + ' ')]
    return [dict(titulo='%s: %s' % (nome, texto), sub='Enter abre no navegador', icone=icone, acao='abrir', valor=url % quote(texto))]
