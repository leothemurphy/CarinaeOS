# CarinaeOS — Configurações › Aplicativos padrão: com que programa abrir cada coisa (navegador, e-mail, fotos,
# música, vídeo, PDF, texto, pastas, ficheiros compactados) — no lugar do kcm_componentchooser do KDE.
# Grava no ~/.config/mimeapps.list (a norma freedesktop, que todos os programas respeitam).
import os

CATEGORIAS = [
    ('navegador', 'Navegador', 'internet-web-browser',
     ['x-scheme-handler/http', 'x-scheme-handler/https', 'text/html', 'application/xhtml+xml']),
    ('email', 'E-mail', 'internet-mail', ['x-scheme-handler/mailto']),
    ('imagens', 'Fotos e imagens', 'image-x-generic',
     ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp', 'image/tiff', 'image/avif', 'image/heic']),
    ('musica', 'Música', 'audio-x-generic',
     ['audio/mpeg', 'audio/flac', 'audio/ogg', 'audio/x-vorbis+ogg', 'audio/x-wav', 'audio/mp4', 'audio/aac', 'audio/x-opus+ogg']),
    ('video', 'Vídeo', 'video-x-generic',
     ['video/mp4', 'video/x-matroska', 'video/webm', 'video/x-msvideo', 'video/quicktime', 'video/mpeg']),
    ('pdf', 'PDF', 'application-pdf', ['application/pdf']),
    ('texto', 'Texto', 'text-x-generic', ['text/plain', 'text/markdown', 'text/x-log']),
    ('pastas', 'Pastas (gestor de ficheiros)', 'system-file-manager', ['inode/directory']),
    ('compactados', 'Ficheiros compactados', 'package-x-generic',
     ['application/zip', 'application/x-7z-compressed', 'application/x-tar', 'application/gzip',
      'application/x-compressed-tar', 'application/x-xz', 'application/vnd.rar']),
]


def _gio():
    import gi
    gi.require_version('Gio', '2.0')
    from gi.repository import Gio
    return Gio


def _info(app):
    ic = app.get_icon()
    return dict(id=app.get_id() or '', nome=app.get_display_name() or app.get_name() or app.get_id(),
                icone=ic.to_string() if ic else 'application-x-executable')


def estado():
    Gio = _gio()
    saida = []
    for chave, nome, icone, mimes in CATEGORIAS:
        atual = Gio.AppInfo.get_default_for_type(mimes[0], False)
        opcoes, vistos = [], set()
        for m in mimes[:3]:
            for a in Gio.AppInfo.get_all_for_type(m):
                if a.get_id() and a.get_id() not in vistos and a.should_show():
                    vistos.add(a.get_id())
                    opcoes.append(_info(a))
        opcoes.sort(key=lambda o: o['nome'].lower())
        saida.append(dict(chave=chave, nome=nome, icone=icone, atual=_info(atual) if atual else None, opcoes=opcoes))
    return saida


def definir(chave, app_id):
    Gio = _gio()
    cat = next((c for c in CATEGORIAS if c[0] == chave), None)
    app = next((a for a in Gio.AppInfo.get_all() if a.get_id() == app_id), None)
    if not cat or not app:
        return 'programa não encontrado'
    erros = 0
    for m in cat[3]:
        try:
            app.set_as_default_for_type(m)
        except Exception:
            erros += 1
    if chave == 'navegador':
        os.system('xdg-settings set default-web-browser %s >/dev/null 2>&1' % app_id.replace("'", ''))
    return '' if erros < len(cat[3]) else 'não foi possível'


def por_extensao(ext):
    """"Escolher por tipo de ficheiro": o programa de agora e os que sabem abrir esse tipo."""
    Gio = _gio()
    ext = ext.strip().lstrip('*').lstrip('.')
    if not ext:
        return {}
    mime, _ = Gio.content_type_guess('x.' + ext, None)
    if not mime or mime == 'application/octet-stream':
        return dict(extensao=ext, mime='', descricao='Tipo desconhecido', atual=None, opcoes=[])
    atual = Gio.AppInfo.get_default_for_type(mime, False)
    opcoes = [_info(a) for a in Gio.AppInfo.get_all_for_type(mime) if a.should_show()]
    return dict(extensao=ext, mime=mime, descricao=Gio.content_type_get_description(mime),
                atual=_info(atual) if atual else None, opcoes=opcoes)


def definir_mime(mime, app_id):
    Gio = _gio()
    app = next((a for a in Gio.AppInfo.get_all() if a.get_id() == app_id), None)
    if not app:
        return 'programa não encontrado'
    try:
        app.set_as_default_for_type(mime)
        return ''
    except Exception as e:
        return str(e)
