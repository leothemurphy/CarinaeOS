#!/bin/bash
# CarinaeOS - fontes TTF (o livro BLFS deixa a escolha ao utilizador: pagina
# "TTF and OTF fonts"). Instala a DejaVu com os comandos dessa pagina.
set -e
cd /sources/blfs && mkdir -p fontes && cd fontes
F=dejavu-fonts-ttf-2.37.tar.bz2
[ -s $F ] || wget -q https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/$F
echo "d0efec10b9f110a32e9b8f796e21782c  $F" | md5sum -c -
rm -rf dejavu-fonts-ttf-2.37 && tar -xf $F && cd dejavu-fonts-ttf-2.37
install -v -d -m755 /usr/share/fonts/dejavu &&
install -v -m644 ttf/*.ttf /usr/share/fonts/dejavu &&
fc-cache -v /usr/share/fonts/dejavu
