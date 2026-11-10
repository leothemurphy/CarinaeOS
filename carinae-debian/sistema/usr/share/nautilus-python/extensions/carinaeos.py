# CarinaeOS - menus do botao direito no GNOME Arquivos (Nautilus): trancar com senha,
# etiquetas, perguntar a Eta e adicionar a Dock (os mesmos que no Dolphin do Plasma).
import subprocess
from urllib.parse import unquote, urlparse

from gi.repository import GObject, Nautilus

CORES = ['Vermelho', 'Laranja', 'Amarelo', 'Verde', 'Azul', 'Roxo', 'Cinzento']


def _caminhos(arquivos):
    res = []
    for f in arquivos:
        loc = f.get_location()
        p = loc.get_path() if loc else None
        res.append(p or f.get_uri())
    return res


def _correr(*args):
    subprocess.Popen(list(args), start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


class CarinaeOS(GObject.GObject, Nautilus.MenuProvider):
    def get_file_items(self, *args):
        arquivos = args[-1]
        if not arquivos:
            return []
        caminhos = _caminhos(arquivos)
        locais = [c for c in caminhos if c.startswith('/')]
        itens = []
        if locais:
            trancar = Nautilus.MenuItem(name='CarinaeOS::trancar', label='Trancar com senha', icon='object-locked')
            trancar.connect('activate', lambda *_: _correr('carinaeos-cadeado', 'trancar', *locais))
            itens.append(trancar)
        topo = Nautilus.MenuItem(name='CarinaeOS::etiquetas', label='Etiquetas', icon='tag')
        sub = Nautilus.Menu()
        topo.set_submenu(sub)
        for cor in CORES:
            m = Nautilus.MenuItem(name='CarinaeOS::et-' + cor, label=cor)
            m.connect('activate', lambda _m, c=cor: _correr('carinaeos-etiquetas', 'pôr', c, *caminhos))
            sub.append_item(m)
        outra = Nautilus.MenuItem(name='CarinaeOS::et-outra', label='Outra etiqueta…')
        outra.connect('activate', lambda *_: _correr('carinaeos-etiquetas', 'outra', *caminhos))
        sub.append_item(outra)
        tirar = Nautilus.MenuItem(name='CarinaeOS::et-tirar', label='Tirar as etiquetas')
        tirar.connect('activate', lambda *_: _correr('carinaeos-etiquetas', 'tirar', *caminhos))
        sub.append_item(tirar)
        itens.append(topo)
        if len(locais) == 1:
            eta = Nautilus.MenuItem(name='CarinaeOS::eta', label='Perguntar à Eta sobre isto', icon='carinaeos-eta')
            eta.connect('activate', lambda *_: _correr('carinaeos-eta', '--arquivo', locais[0]))
            itens.append(eta)
            dock = Nautilus.MenuItem(name='CarinaeOS::dock', label='Adicionar à Dock', icon='list-add')
            dock.connect('activate', lambda *_: _correr('carinaeos-dock-adicionar', locais[0]))
            itens.append(dock)
        return itens
