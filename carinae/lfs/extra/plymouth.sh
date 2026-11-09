#!/bin/bash
# CarinaeOS - ecra de arranque grafico (Plymouth 26.134.222, freedesktop.org).
# O Plymouth nao esta no livro BLFS 13.1; constroi-se como os pacotes meson do
# livro. Todas as dependencias (libdrm, libpng, pango, cairo, freetype, libevdev,
# libxkbcommon, xkeyboard-config, systemd) ja estao instaladas pela fila.
# Sem initramfs (LFS), o plymouth-start.service arranca logo no sysinit.
set -e
cd /sources/blfs && mkdir -p plymouth && cd plymouth
V=26.134.222; F=plymouth-$V.tar.xz; M=4b3af5529def5e3b1c986cb321c82f22
[ -s $F ] && echo "$M  $F" | md5sum -c - >/dev/null 2>&1 || {
  rm -f $F; wget -q https://www.freedesktop.org/software/plymouth/releases/$F; }
echo "$M  $F" | md5sum -c -
rm -rf plymouth-$V && tar -xf $F && cd plymouth-$V
mkdir build && cd build
meson setup ..                       \
      --prefix=/usr                  \
      --sysconfdir=/etc              \
      --localstatedir=/var           \
      --buildtype=release            \
      -D gtk=disabled                \
      -D docs=false                  \
      -D tracing=false               \
      -D background-color=0x000000   \
      -D background-start-color-stop=0x000000 \
      -D background-end-color-stop=0x000000   \
      -D release-file=/etc/os-release
ninja
ninja install
cd /sources/blfs/plymouth && rm -rf plymouth-$V
