def procurar(texto, ctx):
    t = texto.strip()
    if len(t) < 3:
        return []
    return [dict(titulo='Abrir %s' % t, sub='Nos Documentos (pede a senha se o servidor precisar)', icone='folder-remote',
                 acao='correr', valor="carinaeos-arquivos '%s'" % t.replace("'", ''))]
