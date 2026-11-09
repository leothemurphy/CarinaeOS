#!/bin/bash
# CarinaeOS - gdk-pixbuf e glycin sao circulares. O livro (pagina do
# gdk-pixbuf): construir o gdk-pixbuf sem glycin, depois o glycin com todas as
# dependencias recomendadas, e refazer o gdk-pixbuf. Este e o "refazer".
set -e
pkgconf glycin-2
rm -f /root/blfs-logs/gdk-pixbuf.ok
bash /root/carinae/blfs.sh x/gdk-pixbuf sim
