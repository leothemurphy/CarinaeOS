#!/bin/bash
# CarinaeOS - gera a ISO (Debian 13 + o ambiente do CarinaeOS: Gravidade, Aurora e os apps Carinae).
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
install -d $U/icons/hicolor/scalable/apps $U/wallpapers $U/sddm/themes $U/plymouth/themes $U/carinaeos
install -m644 $T/icones/*.svg $U/icons/hicolor/scalable/apps/
cp -a $T/wallpaper/CarinaeOS                  $U/wallpapers/
# o ambiente do CarinaeOS (código-fonte): é compilado dentro da imagem pelo hook 8000-ambiente
install -d $I/usr/src
rm -rf $I/usr/src/carinaeos-ambiente
cp -a ../ambiente $I/usr/src/carinaeos-ambiente
rm -rf $I/usr/src/carinaeos-ambiente/construcao
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

# manual do CarinaeOS (aplicativo Manual)
install -d $I/usr/share/doc/carinaeos/manual
install -m644 ../docs/manual/*.md $I/usr/share/doc/carinaeos/manual/
find $I/usr/share/carinaeos -name __pycache__ -prune -exec rm -rf {} +

# visual "Vidro" (Kvantum + Aurorae + icones WhiteSur, com as cores do CarinaeOS)
bash tema-vidro.sh "$PWD/$I" "$PWD/cache/vidro" || echo "AVISO: tema Vidro nao instalado"

# ArtCraft Launcher (instala e atualiza os aplicativos da Craft App Suite)
mkdir -p config/packages.chroot
rm -f config/packages.chroot/artcraft-launcher*
ACV=$(curl -sfL https://api.github.com/repos/storytold/craft-launcher/releases/latest | python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"].lstrip("v"))' 2>/dev/null || echo 0.9.0)
if [ ! -s cache/artcraft-launcher-$ACV.deb ]; then
  curl -sfL -o cache/artcraft-launcher-$ACV.deb \
    https://github.com/storytold/craft-launcher/releases/download/v$ACV/artcraft-launcher-$ACV-linux-x86_64.deb || rm -f cache/artcraft-launcher-$ACV.deb
fi
[ -s cache/artcraft-launcher-$ACV.deb ] && cp cache/artcraft-launcher-$ACV.deb config/packages.chroot/artcraft-launcher_${ACV}_amd64.deb || echo "AVISO: sem o ArtCraft Launcher"

# papéis de parede: os mesmos do sistema de referência (CarinaeOS-Ardosia, Areia, Aurora, ... em sistema/),
# e já não a coleção de fotos do fundos.py
cp -a $T/sddm/carinaeos                       $U/sddm/themes/
cp -a $T/plymouth/carinaeos                   $U/plymouth/themes/
# fundo do arranque: o ceu do papel de parede, escuro e desfocado (PNG pequeno para o initramfs)
python3 -c "
from PIL import Image, ImageFilter, ImageEnhance
im = Image.open('$U/wallpapers/CarinaeOS/contents/images/1920x1080.jpg').resize((960, 540), Image.LANCZOS)
im = ImageEnhance.Brightness(im.filter(ImageFilter.GaussianBlur(6))).enhance(0.55)
im.convert('P', palette=Image.ADAPTIVE, colors=200).save('$U/plymouth/themes/carinaeos/fundo.png', optimize=True)
" || cp $T/plymouth/carinaeos/barra-fundo.png $U/plymouth/themes/carinaeos/fundo.png
rm -rf $U/wallpapers/CarinaeOS          # só servia para o fundo acima; não está no sistema de referência
install -m644 arte/grub.png                   $U/carinaeos/grub.png
install -m644 arte/calamares-*.png arte/calamares-*.jpg $I/etc/calamares/branding/carinaeos/

# ---- Carinae 3D (Rust): compilado aqui e posto pronto em /usr/bin ----------------
C3D=$D/../carinae/apps/carinae-3d
if [ -f "$C3D/Cargo.toml" ]; then
    if ! command -v cargo >/dev/null; then
        curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
        . "$HOME/.cargo/env"
    fi
    (cd "$C3D" && cargo build --release --locked)
    install -Dm755 "$C3D/target/release/carinae-3d" $I/usr/bin/carinae-3d
    strip $I/usr/bin/carinae-3d || true
fi

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
