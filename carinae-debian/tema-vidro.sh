#!/bin/bash
# CarinaeOS - visual "Vidro": janelas translúcidas com desfoque (Kvantum), botões de janela
# redondos à esquerda (Aurorae) e ícones coloridos (WhiteSur), recoloridos com as cores do
# CarinaeOS (violeta-noite, âmbar e rosa da estrela).
# Base: WhiteSur-kde e WhiteSur-icon-theme de Vince Liuice (GPL-3.0), baixados na construção.
#   tema-vidro.sh <raiz do chroot (includes.chroot)> <cache>
set -e
R=$1; C=$2
U=$R/usr/share
mkdir -p "$C"
buscar() {   # buscar <repo> <pasta>
  if [ ! -d "$C/$2/.git" ]; then
    rm -rf "$C/$2"
    git clone -q --depth 1 "https://github.com/vinceliuice/$1" "$C/$2"
  fi
}
buscar WhiteSur-kde whitesur-kde
buscar WhiteSur-icon-theme whitesur-icones
K=$C/whitesur-kde

# cinzentos do WhiteSur -> violeta-noite do CarinaeOS
recolorir() {
  sed -i -E \
    -e 's/#242424/#1a1527/gI' -e 's/#2d2d2d/#241d35/gI' -e 's/#282828/#1f192e/gI' -e 's/#202020/#15111f/gI' \
    -e 's/#3c3c3c/#342a49/gI' -e 's/#333333/#2a2340/gI' -e 's/#2a2a2a/#211b31/gI' -e 's/#262626/#1d1829/gI' \
    -e 's/#1e1e1e/#16121f/gI' -e 's/#363636/#2d2542/gI' -e 's/#313131/#272038/gI' -e 's/#2c2c2c/#231c33/gI' \
    -e 's/#a0b4f8/#ffb46e/gI' -e 's/#3484e2/#ffb46e/gI' "$@"
}

# ---- Kvantum: estilo dos aplicativos ----------------------------------------------------
KV=$U/Kvantum/CarinaeOS
mkdir -p "$KV"
cp "$K/Kvantum/WhiteSur/WhiteSurDark.svg" "$KV/CarinaeOS.svg"
cp "$K/Kvantum/WhiteSur/WhiteSurDark.kvconfig" "$KV/CarinaeOS.kvconfig"
recolorir "$KV/CarinaeOS.svg" "$KV/CarinaeOS.kvconfig"
sed -i -E \
  -e 's/^comment=.*/comment=CarinaeOS Vidro: escuro, translúcido e com desfoque (baseado no WhiteSur de Vince Liuice)/' \
  -e 's/^highlight\.color=.*/highlight.color=#e0785f/' -e 's/^inactive\.highlight\.color=.*/inactive.highlight.color=#a8566b/' \
  -e 's/^link\.color=.*/link.color=#ffb46e/' -e 's/^link\.visited\.color=.*/link.visited.color=#ff8fb0/' \
  -e 's/^text\.color=.*/text.color=#f2ecfa/' -e 's/^window\.text\.color=.*/window.text.color=#f2ecfa/' \
  -e 's/^button\.text\.color=.*/button.text.color=#f2ecfa/' \
  -e 's/^reduce_window_opacity=.*/reduce_window_opacity=18/' -e 's/^reduce_menu_opacity=.*/reduce_menu_opacity=12/' \
  "$KV/CarinaeOS.kvconfig"
mkdir -p "$R/etc/xdg/Kvantum"
printf '[General]\ntheme=CarinaeOS\n' > "$R/etc/xdg/Kvantum/kvantum.kvconfig"

# ---- Aurorae: barra de título com os botões redondos à esquerda ---------------------------
AU=$U/aurorae/themes/CarinaeOS
mkdir -p "$AU"
cp -r "$K/aurorae/main/WhiteSur-dark/." "$AU/"
cp "$K/aurorae/common/assets-dark/"*.svg "$AU/"
cp "$K/aurorae/main/WhiteSur-darkrc" "$AU/CarinaeOSrc"
sed -e 's/^Name=.*/Name=CarinaeOS/' -e 's/^X-KDE-PluginInfo-Name=.*/X-KDE-PluginInfo-Name=CarinaeOS/' \
    "$K/aurorae/metadata.desktop" > "$AU/metadata.desktop"
python3 - "$K/aurorae/metadata.json" "$AU/metadata.json" <<'EOT'
import json, sys
d = json.load(open(sys.argv[1]))
k = d.setdefault('KPlugin', {})
k['Id'] = 'CarinaeOS'; k['Name'] = 'CarinaeOS'
k['Description'] = 'Barra de título do CarinaeOS (baseada no WhiteSur de Vince Liuice)'
json.dump(d, open(sys.argv[2], 'w'), indent=2, ensure_ascii=False)
EOT
recolorir "$AU/"*.svg
sed -i -E 's/^ActiveFocusedTabColor=.*/ActiveFocusedTabColor=52,42,73/; s/^ActiveTextColor=.*/ActiveTextColor=242,236,250/' "$AU/CarinaeOSrc"

# ---- GTK (GNOME, XFCE, Chrome, Firefox, apps GTK): o mesmo visual, botões do Mac à esquerda ----
buscar WhiteSur-gtk-theme whitesur-gtk
mkdir -p "$U/themes"
tar -xJf "$C/whitesur-gtk/release/WhiteSur-Dark.tar.xz" -C "$U/themes"
mkdir -p "$R/etc/gtk-3.0" "$R/etc/gtk-4.0"
for v in 3.0 4.0; do
  printf '[Settings]\ngtk-theme-name=WhiteSur-Dark\ngtk-icon-theme-name=CarinaeOS\ngtk-application-prefer-dark-theme=true\ngtk-decoration-layout=close,minimize,maximize:\ngtk-font-name=Inter 10\ngtk-cursor-theme-name=breeze_cursors\n' > "$R/etc/gtk-$v/settings.ini"
done

# ---- ícones WhiteSur (claro e escuro) ------------------------------------------------------
if [ ! -d "$U/icons/WhiteSur-dark" ]; then
  ( cd "$C/whitesur-icones" && ./install.sh -d "$U/icons" -n WhiteSur -t default >/dev/null )
fi
# nada de logotipos da Apple: o Finder e o "Sistema" do WhiteSur dão lugar aos do CarinaeOS
for d in "$U/icons/WhiteSur" "$U/icons/WhiteSur-dark" "$U/icons/WhiteSur-light"; do
  [ -d "$d" ] || continue
  find "$d" \( -iname '*apple*' -o -iname '*finder*' -o -iname '*macos*' -o -iname 'start-here*' -o -iname 'distributor-logo*' \) \
       -exec rm -f {} + 2>/dev/null || true
done
echo "tema Vidro: Kvantum, Aurorae e ícones prontos"
