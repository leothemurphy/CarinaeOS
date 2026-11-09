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
install -m644 $T/cores/CarinaeOS.colors       $U/color-schemes/
cp -a $T/sddm/carinaeos                       $U/sddm/themes/
cp -a $T/plymouth/carinaeos                   $U/plymouth/themes/
install -m644 arte/grub.png                   $U/carinaeos/grub.png
install -m644 arte/calamares-*.png            $I/etc/calamares/branding/carinaeos/

# Dock: lancadores das aplicacoes que existem nesta edicao
sed -i 's#<default>applications:org.kde.dolphin.desktop,.*</default>#<default>applications:org.kde.dolphin.desktop,applications:firefox-esr.desktop,applications:org.kde.konsole.desktop,applications:org.kde.gwenview.desktop,applications:org.kde.okular.desktop,applications:carinaeos-orbita.desktop,applications:carinaeos-supernova.desktop,applications:systemsettings.desktop</default>#' \
  $U/plasma/plasmoids/org.carinaeos.dock/contents/config/main.xml

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
