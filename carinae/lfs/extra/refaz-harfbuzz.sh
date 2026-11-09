#!/bin/bash
# CarinaeOS - HarfBuzz e FreeType dependem um do outro (o livro: construir um,
# depois o outro e refazer o primeiro). A fila instala o HarfBuzz e depois o
# FreeType (ja com HarfBuzz); aqui refaz-se o HarfBuzz, agora com FreeType
# (o Pango precisa do hb-ft.h).
set -e
rm -f /root/blfs-logs/harfbuzz.ok
bash /root/carinae/blfs.sh general/harfbuzz sim
test -f /usr/include/harfbuzz/hb-ft.h
