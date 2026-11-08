#!/bin/bash
# CarinaeOS - instala o visual do CarinaeOS no Plasma e torna-o o padrao do
# sistema (vale para todos os utilizadores novos):
#   barra em cima com a estrela, Dock em baixo com ampliacao, mesa com icones,
#   fundo de Eta Carinae, cores CarinaeOS, efeitos (lampada magica, janelas
#   gelatinosas, desfoque), botoes das janelas a esquerda e login com o fundo.
set -e
T=$(cd "$(dirname "$0")/../tema" && pwd)
P=/usr/share

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

# ---- ecra de login (SDDM com o tema Breeze do Plasma) ---------------------------
install -vdm755 /etc/sddm.conf.d
cat > /etc/sddm.conf.d/10-carinaeos.conf << "EOT"
[Theme]
Current=breeze
CursorTheme=breeze_cursors
EOT
if [ -d /usr/share/sddm/themes/breeze ]; then
cat > /usr/share/sddm/themes/breeze/theme.conf.user << "EOT"
[General]
type=image
background=/usr/share/wallpapers/CarinaeOS/contents/images/3840x2160.jpg
EOT
fi
echo "== visual do CarinaeOS instalado"
