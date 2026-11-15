#!/bin/bash
# CarinaeOS (ramo testes): aplica a passagem para português do Brasil neste computador.
# Guarda uma cópia de cada arquivo em /tmp/bom-ptbr antes de o trocar.
set -e
B=https://raw.githubusercontent.com/leothemurphy/CarinaeOS/e7c8fde9886d4c26417d036186619b6273759c0a
mkdir -p /tmp/bom-ptbr
p(){
    t=$(mktemp)
    if curl -fsSL -o "$t" "$B/$1" && [ -s "$t" ]; then
        [ -f "$2" ] && sudo cp -a --parents "$2" /tmp/bom-ptbr/
        sudo install -D -m "$3" "$t" "$2" && echo "ok  $2"
    else
        echo "FALHOU  $2 (ficou como estava)"
    fi
    rm -f "$t"
}
p 'carinae-debian/sistema/usr/bin/carinaeos-appimage' '/usr/bin/carinaeos-appimage' 755
p 'carinae-debian/sistema/usr/bin/carinaeos-cadeado' '/usr/bin/carinaeos-cadeado' 755
p 'carinae-debian/sistema/usr/bin/carinaeos-casa-agente' '/usr/bin/carinaeos-casa-agente' 755
p 'carinae-debian/sistema/usr/bin/carinaeos-contas' '/usr/bin/carinaeos-contas' 755
p 'carinae-debian/sistema/usr/bin/carinaeos-deck' '/usr/bin/carinaeos-deck' 755
p 'carinae-debian/sistema/usr/bin/carinaeos-etiquetas' '/usr/bin/carinaeos-etiquetas' 755
p 'carinae-debian/sistema/usr/lib/carinaeos/agente-senha' '/usr/lib/carinaeos/agente-senha' 755
p 'carinae-debian/sistema/usr/lib/carinaeos/musica-vigia' '/usr/lib/carinaeos/musica-vigia' 755
p 'carinae-debian/sistema/usr/lib/carinaeos/partilha' '/usr/lib/carinaeos/partilha' 755
p 'carinae-debian/sistema/usr/share/applications/carinaeos-appimage.desktop' '/usr/share/applications/carinaeos-appimage.desktop' 644
p 'carinae-debian/sistema/usr/share/applications/carinaeos-configuracoes.desktop' '/usr/share/applications/carinaeos-configuracoes.desktop' 644
p 'carinae-debian/sistema/usr/share/carinaeos/boasvindas/Main.qml' '/usr/share/carinaeos/boasvindas/Main.qml' 644
p 'carinae-debian/sistema/usr/share/carinaeos/casa/Cartao.qml' '/usr/share/carinaeos/casa/Cartao.qml' 644
p 'carinae-debian/sistema/usr/share/carinaeos/casa/Main.qml' '/usr/share/carinaeos/casa/Main.qml' 644
p 'carinae-debian/sistema/usr/share/carinaeos/casa/casa.py' '/usr/share/carinaeos/casa/casa.py' 644
p 'carinae-debian/sistema/usr/share/carinaeos/central/Main.qml' '/usr/share/carinaeos/central/Main.qml' 644
p 'carinae-debian/sistema/usr/share/carinaeos/central/central.py' '/usr/share/carinaeos/central/central.py' 644
p 'carinae-debian/sistema/usr/share/carinaeos/comando/acoes.py' '/usr/share/carinaeos/comando/acoes.py' 644
p 'carinae-debian/sistema/usr/share/carinaeos/comando/comando.py' '/usr/share/carinaeos/comando/comando.py' 644
p 'carinae-debian/sistema/usr/share/carinaeos/comum/base.py' '/usr/share/carinaeos/comum/base.py' 644
p 'carinae-debian/sistema/usr/share/carinaeos/comum/casa_ha.py' '/usr/share/carinaeos/comum/casa_ha.py' 644
p 'carinae-debian/sistema/usr/share/carinaeos/configuracoes/Main.qml' '/usr/share/carinaeos/configuracoes/Main.qml' 644
p 'carinae-debian/sistema/usr/share/carinaeos/configuracoes/configuracoes.py' '/usr/share/carinaeos/configuracoes/configuracoes.py' 644
p 'carinae-debian/sistema/usr/share/carinaeos/musica/Main.qml' '/usr/share/carinaeos/musica/Main.qml' 644
p 'carinae-debian/sistema/usr/share/carinaeos/musica/musica.py' '/usr/share/carinaeos/musica/musica.py' 644
p 'carinae-debian/sistema/usr/share/carinaeos/orbita/Main.qml' '/usr/share/carinaeos/orbita/Main.qml' 644
p 'carinae-debian/sistema/usr/share/carinaeos/orbita/orbita.py' '/usr/share/carinaeos/orbita/orbita.py' 644
p 'carinae-debian/sistema/usr/share/carinaeos/supernova/Main.qml' '/usr/share/carinaeos/supernova/Main.qml' 644
p 'carinae-debian/sistema/usr/share/carinaeos/supernova/mods.py' '/usr/share/carinaeos/supernova/mods.py' 644
p 'carinae-debian/sistema/usr/share/carinaeos/supernova/supernova.py' '/usr/share/carinaeos/supernova/supernova.py' 644
p 'carinae-debian/sistema/usr/share/kwin/scripts/carinaeos-mesa/metadata.json' '/usr/share/kwin/scripts/carinaeos-mesa/metadata.json' 644
p 'carinae/tema/lookandfeel/org.carinaeos.desktop/metadata.json' '/usr/share/plasma/look-and-feel/org.carinaeos.desktop/metadata.json' 644
p 'carinae/tema/plasmoid/org.carinaeos.agoratoca/contents/ui/main.qml' '/usr/share/plasma/plasmoids/org.carinaeos.agoratoca/contents/ui/main.qml' 644
p 'carinae/tema/plasmoid/org.carinaeos.agoratoca/metadata.json' '/usr/share/plasma/plasmoids/org.carinaeos.agoratoca/metadata.json' 644
p 'carinae/tema/plasmoid/org.carinaeos.dock/contents/ui/Lancador.qml' '/usr/share/plasma/plasmoids/org.carinaeos.dock/contents/ui/Lancador.qml' 644
p 'carinae/tema/plasmoid/org.carinaeos.dock/metadata.json' '/usr/share/plasma/plasmoids/org.carinaeos.dock/metadata.json' 644
p 'carinae/tema/plasmoid/org.carinaeos.menuestrela/contents/ui/main.qml' '/usr/share/plasma/plasmoids/org.carinaeos.menuestrela/contents/ui/main.qml' 644
p 'carinae/tema/plasmoid/org.carinaeos.nomeapp/contents/ui/main.qml' '/usr/share/plasma/plasmoids/org.carinaeos.nomeapp/contents/ui/main.qml' 644
p 'carinae/tema/sddm/carinaeos/metadata.desktop' '/usr/share/sddm/themes/carinaeos/metadata.desktop' 644
p 'docs/manual/00-indice.md' '/usr/share/doc/carinaeos/manual/00-indice.md' 644
p 'docs/manual/01-primeiros-passos.md' '/usr/share/doc/carinaeos/manual/01-primeiros-passos.md' 644
p 'docs/manual/02-area-de-trabalho.md' '/usr/share/doc/carinaeos/manual/02-area-de-trabalho.md' 644
p 'docs/manual/03-ferramentas.md' '/usr/share/doc/carinaeos/manual/03-ferramentas.md' 644
p 'docs/manual/04-arquivos-e-discos.md' '/usr/share/doc/carinaeos/manual/04-arquivos-e-discos.md' 644
p 'docs/manual/05-rede.md' '/usr/share/doc/carinaeos/manual/05-rede.md' 644
p 'docs/manual/06-programas.md' '/usr/share/doc/carinaeos/manual/06-programas.md' 644
p 'docs/manual/07-hardware.md' '/usr/share/doc/carinaeos/manual/07-hardware.md' 644
p 'docs/manual/08-debian.md' '/usr/share/doc/carinaeos/manual/08-debian.md' 644
p 'docs/manual/09-kernel.md' '/usr/share/doc/carinaeos/manual/09-kernel.md' 644
p 'docs/manual/10-terminal.md' '/usr/share/doc/carinaeos/manual/10-terminal.md' 644
p 'docs/manual/11-seguranca.md' '/usr/share/doc/carinaeos/manual/11-seguranca.md' 644
p 'docs/manual/12-problemas.md' '/usr/share/doc/carinaeos/manual/12-problemas.md' 644
kbuildsycoca6 >/dev/null 2>&1 || true
echo
echo "Pronto. Para ver tudo novo: kquitapp6 plasmashell; sleep 3; setsid plasmashell >/dev/null 2>&1 &"
echo "Para desfazer: sudo cp -a /tmp/bom-ptbr/. /"
