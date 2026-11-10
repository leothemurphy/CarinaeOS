#!/bin/bash
# CarinaeOS - gera a ISO (Debian 13 + KDE Plasma + visual CarinaeOS).
# Correr como root num Debian 13 (ou num chroot/contentor Debian 13) com o
# pacote live-build instalado:   sudo ./construir.sh
# Resultado: carinaeos-amd64.hybrid.iso nesta pasta.
set -e
D=$(cd "$(dirname "$0")" && pwd)
T=$D/../carinae/tema
cd "$D"
command -v lb >/dev/null || { echo "falta o live-build (apt install live-build)"; exit 1; }

# ---- limpar construcoes anteriores (mantem a cache de pacotes) -----------------
lb clean noauto >/dev/null 2>&1 || true
rm -rf config/includes.chroot config/includes.binary config/bootloaders

# ---- ficheiros do sistema -------------------------------------------------------
I=config/includes.chroot
mkdir -p $I
cp -a sistema/. $I/
U=$I/usr/share
install -d $U/icons/hicolor/scalable/apps $U/plasma/plasmoids $U/plasma/look-and-feel \
           $U/wallpapers $U/color-schemes $U/sddm/themes $U/plymouth/themes $U/carinaeos
install -m644 $T/icones/*.svg $U/icons/hicolor/scalable/apps/
cp -a $T/plasmoid/org.carinaeos.dock         $U/plasma/plasmoids/
cp -a $T/plasmoid/org.carinaeos.menuestrela  $U/plasma/plasmoids/
install -d $U/plasma/desktoptheme
cp -a $T/plasmastyle/carinaeos               $U/plasma/desktoptheme/
cp -a $T/lookandfeel/org.carinaeos.desktop    $U/plasma/look-and-feel/
cp -a $T/wallpaper/CarinaeOS                  $U/wallpapers/
# marca CarinaeOS em PNG, para substituir os logotipos do Debian (desktop-base, emblemas)
M=$U/carinaeos/marca
install -d $M
cat > /tmp/carinaeos-logo-texto.svg <<EOT
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 512 160">
  <image href="file://$PWD/$T/icones/carinaeos.svg" x="0" y="0" width="160" height="160"/>
  <text x="176" y="104" font-family="Inter, DejaVu Sans, sans-serif" font-size="72" font-weight="700" fill="#f4eee8">CarinaeOS</text>
</svg>
EOT
cp $T/icones/carinaeos.svg $M/logo.svg
cp /tmp/carinaeos-logo-texto.svg $M/logo-text.svg
cp /tmp/carinaeos-logo-texto.svg $M/logo-text-version.svg
for n in 16 22 24 32 48 64 128 256 512; do
  rsvg-convert -w $n -h $n $T/icones/carinaeos.svg -o $M/logo-$n.png
done
for n in 64 128 256; do
  rsvg-convert -h $n /tmp/carinaeos-logo-texto.svg -o $M/logo-text-$n.png
  cp $M/logo-text-$n.png $M/logo-text-version-$n.png
done

# colecao de papeis de parede 8K (fotos do Webb/Hubble + desenhos do CarinaeOS) para Plasma, GNOME e XFCE
python3 fundos/fundos.py "$PWD/$I" "$PWD/cache/fundos"
install -m644 $T/cores/CarinaeOS.colors       $U/color-schemes/
cp -a $T/sddm/carinaeos                       $U/sddm/themes/
cp -a $T/plymouth/carinaeos                   $U/plymouth/themes/
install -m644 arte/grub.png                   $U/carinaeos/grub.png
install -m644 arte/calamares-*.png            $I/etc/calamares/branding/carinaeos/

# Dock: lancadores das aplicacoes que existem nesta edicao
sed -i 's#<default>applications:org.kde.dolphin.desktop,.*</default>#<default>applications:org.kde.dolphin.desktop,applications:firefox-esr.desktop,applications:org.kde.konsole.desktop,applications:org.kde.gwenview.desktop,applications:org.kde.okular.desktop,applications:carinaeos-orbita.desktop,applications:carinaeos-supernova.desktop,applications:carinaeos-eta.desktop,applications:org.kde.merkuro.calendar.desktop,applications:systemsettings.desktop</default>#' \
  $U/plasma/plasmoids/org.carinaeos.dock/contents/config/main.xml

# ---- Eta: motor de IA local (llama.cpp, so o servidor, para CPU) -----------------
# compilado aqui (Debian 13) uma vez e guardado em cache; o modelo e baixado pelo
# usuario na primeira vez que ativa a IA (1,1 GB)
LLAMA_VERSAO=b12233
LC=cache/llama-$LLAMA_VERSAO
if [ ! -x $LC/llama-server ]; then
  rm -rf cache/llama-src && mkdir -p cache
  git clone -q --depth 1 --branch $LLAMA_VERSAO https://github.com/ggml-org/llama.cpp cache/llama-src
  cmake -S cache/llama-src -B cache/llama-src/build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=OFF \
        -DLLAMA_CURL=OFF -DBUILD_SHARED_LIBS=OFF -DLLAMA_BUILD_TESTS=OFF -DLLAMA_BUILD_EXAMPLES=OFF \
        -DLLAMA_BUILD_SERVER=ON >/dev/null
  cmake --build cache/llama-src/build --target llama-server -j"$(nproc)"
  mkdir -p $LC && install -m755 cache/llama-src/build/bin/llama-server $LC/
  cp cache/llama-src/LICENSE $LC/LICENSE
  rm -rf cache/llama-src
fi
install -d $I/opt/carinaeos/llama
install -m755 $LC/llama-server $I/opt/carinaeos/llama/
install -m644 $LC/LICENSE $I/opt/carinaeos/llama/LICENSE

# ---- Eta: ouvido (whisper.cpp, reconhecimento de fala no proprio computador) --------
WHISPER_VERSAO=v1.9.5
WC=cache/whisper-$WHISPER_VERSAO
if [ ! -x $WC/whisper-cli ]; then
  rm -rf cache/whisper-src && mkdir -p cache
  git clone -q --depth 1 --branch $WHISPER_VERSAO https://github.com/ggml-org/whisper.cpp cache/whisper-src
  cmake -S cache/whisper-src -B cache/whisper-src/build -DCMAKE_BUILD_TYPE=Release -DGGML_NATIVE=OFF \
        -DBUILD_SHARED_LIBS=OFF -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=ON -DWHISPER_SDL2=OFF >/dev/null
  cmake --build cache/whisper-src/build --target whisper-cli -j"$(nproc)"
  mkdir -p $WC && install -m755 cache/whisper-src/build/bin/whisper-cli $WC/
  cp cache/whisper-src/LICENSE $WC/LICENSE
  rm -rf cache/whisper-src
fi
install -d $I/opt/carinaeos/whisper
install -m755 $WC/whisper-cli $I/opt/carinaeos/whisper/
install -m644 $WC/LICENSE $I/opt/carinaeos/whisper/LICENSE

# ---- menus de arranque da ISO (BIOS: syslinux; UEFI: GRUB) ----------------------
B=config/bootloaders
mkdir -p $B
cp -a /usr/share/live/build/bootloaders/isolinux /usr/share/live/build/bootloaders/syslinux_common \
      /usr/share/live/build/bootloaders/grub-pc $B/
# o live-build junta syslinux_common ao isolinux; a imagem de fundo vai para os dois
install -m644 arte/splash.png $B/isolinux/splash.png
install -m644 arte/splash.png $B/syslinux_common/splash.png
install -m644 arte/splash.png $B/grub-pc/splash.png
sed -i 's/^timeout .*/timeout 50/' $B/isolinux/isolinux.cfg
sed -i '/^menu title /d; s/^\tmenu label \^Utilities/\tmenu label ^Utilitarios/' $B/syslinux_common/menu.cfg
sed -i 's/#76a1d0ff/#c0ffb46e/g; s/^menu tabmsg .*/menu tabmsg ENTER para iniciar, TAB para editar/; s/^menu vshift .*/menu vshift 13/' $B/syslinux_common/stdmenu.cfg
sed -i 's/menu label \^Live system (@FLAVOUR@)/menu label ^Iniciar o CarinaeOS/; s/menu label Live system (@FLAVOUR@ fail-safe mode)/menu label CarinaeOS (modo de seguranca)/' $B/syslinux_common/live.cfg.in
sed -i 's/^title-text:.*/title-text: ""/; s/top = 52%/top = 45%/; s/item_color = "#a8a8a8"/item_color = "#d8d0c8"/' $B/grub-pc/live-theme/theme.txt
sed -i 's/set gfxmode=800x600/set gfxmode=800x600\nset timeout=5/' $B/grub-pc/config.cfg
grep -q 'set timeout=5' $B/grub-pc/config.cfg || echo 'set timeout=5' >> $B/grub-pc/config.cfg

# ---- instalador: o grub-pc (BIOS) entra a parte, porque nao pode ser instalado ao
# mesmo tempo que o grub-efi-amd64 na lista de pacotes da ISO --------------------
mkdir -p config/packages.binary
rm -f config/packages.binary/grub-pc_*.deb
(cd config/packages.binary && apt-get download grub-pc)

# ---- construir ------------------------------------------------------------------
lb config
lb build 2>&1 | tee construir.log
ls -lh *.iso
