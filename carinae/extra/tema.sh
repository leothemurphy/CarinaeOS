#!/bin/bash
# CarinaeOS - instala o visual do CarinaeOS no Plasma e torna-o o padrao do
# sistema (vale para todos os utilizadores novos):
#   barra em cima com a estrela, Dock em baixo com ampliacao, mesa com icones,
#   fundo de Eta Carinae, cores CarinaeOS, efeitos (lampada magica, janelas
#   gelatinosas, desfoque), botoes das janelas a esquerda e login com o fundo.
set -e
T=$(cd "$(dirname "$0")/../tema" && pwd)
P=/usr/share
E=$(dirname "$0")

# fonte da interface e ecra de arranque: se algum falhar, o resto do tema
# instala-se na mesma (e o aviso fica no registo)
bash $E/inter.sh    || echo "AVISO: a fonte Inter nao ficou instalada"
bash $E/plymouth.sh || echo "AVISO: o Plymouth nao ficou instalado"

install -vdm755 $P/icons/hicolor/scalable/apps
install -vm644 $T/icones/*.svg $P/icons/hicolor/scalable/apps/
gtk-update-icon-cache -qtf $P/icons/hicolor || true

for d in plasmoid/org.carinaeos.dock:plasma/plasmoids/org.carinaeos.dock \
         lookandfeel/org.carinaeos.desktop:plasma/look-and-feel/org.carinaeos.desktop \
         wallpaper/CarinaeOS:wallpapers/CarinaeOS; do
  rm -rf $P/${d#*:}; install -vdm755 $(dirname $P/${d#*:})
  cp -rv $T/${d%%:*} $P/${d#*:}
done
install -vDm644 $T/cores/CarinaeOS.colors $P/color-schemes/CarinaeOS.colors

# ---- padroes do sistema (/etc/xdg) --------------------------------------------
install -vdm755 /etc/xdg
cat > /etc/xdg/kdeglobals << "EOT"
[KDE]
LookAndFeelPackage=org.carinaeos.desktop
widgetStyle=Breeze

[General]
ColorScheme=CarinaeOS
AccentColor=255,180,110
font=Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
menuFont=Inter,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
toolBarFont=Inter,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1
smallestReadableFont=Inter,8,-1,5,400,0,0,0,0,0,0,0,0,0,0,1

[WM]
activeFont=Inter,10,-1,5,600,0,0,0,0,0,0,0,0,0,0,1

[Icons]
Theme=breeze-dark
EOT

cat > /etc/xdg/kwinrc << "EOT"
[org.kde.kdecoration2]
library=org.kde.breeze
theme=Breeze
ButtonsOnLeft=XIA
ButtonsOnRight=

[Plugins]
blurEnabled=true
contrastEnabled=true
magiclampEnabled=true
squashEnabled=false
wobblywindowsEnabled=true
scaleEnabled=true
translucencyEnabled=true
slideEnabled=true

[Effect-magiclamp]
AnimationDuration=320

[Effect-blur]
BlurStrength=10
NoiseStrength=3
EOT

cat > /etc/xdg/ksplashrc << "EOT"
[KSplash]
Engine=KSplashQML
Theme=org.carinaeos.desktop
EOT

cat > /etc/xdg/kscreenlockerrc << "EOT"
[Greeter][Wallpaper][org.kde.image][General]
Image=file:///usr/share/wallpapers/CarinaeOS/
EOT

cat > /etc/xdg/kcm-about-distrorc << "EOT"
[General]
LogoPath=/usr/share/icons/hicolor/scalable/apps/carinaeos.svg
Website=https://github.com/leothemurphy/atriumos
EOT

grep -q '^LOGO=' /etc/os-release || echo 'LOGO=carinaeos' >> /etc/os-release

# ---- ecra de login: tema proprio do CarinaeOS (estilo macOS) ------------------
rm -rf $P/sddm/themes/carinaeos
cp -rv $T/sddm/carinaeos $P/sddm/themes/carinaeos
install -vdm755 /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-carinaeos.conf << "EOT"
[Theme]
Current=carinaeos
CursorTheme=breeze_cursors
Font=Inter
EOT
# o /etc/sddm.conf (gerado na pagina do SDDM) tem precedencia: acertar la tambem
if [ -f /etc/sddm.conf ]; then
  sed -i -E '/^\[Theme\]/,/^\[/ s/^Current=.*/Current=carinaeos/' /etc/sddm.conf
  sed -i -E '/^\[Theme\]/,/^\[/ s/^CursorTheme=.*/CursorTheme=breeze_cursors/' /etc/sddm.conf
fi
# o SDDM so aparece depois de o ecra de arranque sair (passagem sem piscar)
install -vdm755 /etc/systemd/system/sddm.service.d
cat > /etc/systemd/system/sddm.service.d/plymouth.conf << "EOT"
[Unit]
After=plymouth-quit.service systemd-user-sessions.service
EOT

# ---- ecra de arranque (Plymouth) -----------------------------------------------
if [ -d $P/plymouth/themes ]; then
  rm -rf $P/plymouth/themes/carinaeos
  cp -rv $T/plymouth/carinaeos $P/plymouth/themes/carinaeos
  install -vdm755 /etc/plymouth
  cat > /etc/plymouth/plymouthd.conf << "EOT"
[Daemon]
Theme=carinaeos
ShowDelay=0
DeviceTimeout=8
EOT
fi
systemctl daemon-reload || true

# ---- menu de arranque (GRUB, configurado no cap. 10 do LFS) ---------------------
# Copia de seguranca, nome "CarinaeOS" na entrada e, se o GRUB tiver fonte para
# o modo grafico, o fundo com a estrela. Se o grub.cfg resultante nao passar no
# grub-script-check, volta-se a copia (o arranque nunca fica em risco).
G=/boot/grub/grub.cfg
if [ -f $G ] && ! grep -q 'carinaeos-grub.png' $G; then
  cp -v $G $G.antes-carinaeos
  install -vm644 $T/grub/carinaeos-grub.png /boot/grub/carinaeos-grub.png
  sed -i -E 's/^(menuentry +)"[^"]*"/\1"CarinaeOS"/' $G
  if ls /boot/grub/fonts/*.pf2 >/dev/null 2>&1; then
    F=$(ls /boot/grub/fonts/*.pf2 | head -1)
    sed -i "0,/^menuentry/s@^menuentry@insmod all_video\ninsmod gfxterm\ninsmod png\nloadfont ${F}\nset gfxmode=auto\nterminal_output gfxterm\nbackground_image -m stretch /boot/grub/carinaeos-grub.png\nset menu_color_normal=white/black\nset menu_color_highlight=black/light-gray\n\nmenuentry@" $G
  fi
  if [ -d $P/plymouth/themes/carinaeos ]; then
    sed -i -E '/^[[:space:]]*linux[[:space:]]/{/ splash/!s/$/ quiet splash loglevel=3 udev.log_level=3 vt.global_cursor_default=0/}' $G
  fi
  if command -v grub-script-check >/dev/null && ! grub-script-check $G; then
    echo "AVISO: grub.cfg invalido; a repor a copia"; cp -v $G.antes-carinaeos $G
  fi
fi
echo "== visual do CarinaeOS instalado"
