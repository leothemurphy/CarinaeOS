# Navegar pelas pastas: "~/Doc" → ~/Documentos/ (Enter entra); arquivos abrem com o programa predefinido.
import os


def procurar(texto, ctx):
    casa = ctx['casa']
    real = os.path.expanduser(texto)
    pasta, parte = (real, '') if real.endswith('/') else os.path.split(real)
    if not os.path.isdir(pasta):
        return []
    try:
        nomes = sorted(os.listdir(pasta), key=lambda n: (not os.path.isdir(os.path.join(pasta, n)), n.lower()))
    except OSError:
        return []
    mostrar_ocultos = parte.startswith('.')
    r = []
    for n in nomes:
        if n.startswith('.') and not mostrar_ocultos:
            continue
        if parte and not n.lower().startswith(parte.lower()):
            continue
        cam = os.path.join(pasta, n)
        bonito = cam.replace(casa, '~', 1) if cam.startswith(casa) else cam
        if os.path.isdir(cam):
            r.append(dict(titulo=n + '/', sub=bonito + '  ·  Enter entra na pasta', icone='folder', acao='completar', valor=bonito + '/'))
        else:
            r.append(dict(titulo=n, sub=bonito, icone='text-x-generic', acao='abrir', valor=cam))
        if len(r) >= 12:
            break
    if not parte:
        bonito = pasta.replace(casa, '~', 1) if pasta.startswith(casa) else pasta
        r.append(dict(titulo="Abrir esta pasta nos Documentos", sub=bonito, icone='system-file-manager',
                         acao='correr', valor="carinaeos-arquivos '%s'" % pasta.replace("'", '')))
    return r
