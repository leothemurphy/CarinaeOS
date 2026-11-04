#!/bin/bash
# ============================================================
#  Pórtico 0.1 — instalador da prévia de teste (Linux)
#  Funciona com o Firefox normal, ESR, Flatpak ou Snap.
# ============================================================
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
echo ""
echo "  Pórtico 0.1 — instalando a prévia de teste"
echo ""
DEST="$HOME/.local/share/portico"
is_snap_wrapper(){ [ -f "$1" ] && grep -q "snap" "$1" 2>/dev/null; }
FF="$(command -v firefox 2>/dev/null || true)"
if [ -n "$FF" ] && ! is_snap_wrapper "$FF" && [ "$(readlink -f "$FF")" != "/usr/bin/snap" ]; then
  ENGINE="firefox"
elif command -v firefox-esr >/dev/null 2>&1; then
  ENGINE="firefox-esr"
elif command -v snap >/dev/null 2>&1 && snap list firefox >/dev/null 2>&1; then
  ENGINE="snap run firefox"; DEST="$HOME/snap/firefox/common/portico"
elif command -v flatpak >/dev/null 2>&1 && flatpak info org.mozilla.firefox >/dev/null 2>&1; then
  ENGINE="flatpak run org.mozilla.firefox"; DEST="$HOME/.var/app/org.mozilla.firefox/data/portico"
else
  echo "  O Pórtico usa o motor do Firefox. Instale o Firefox pela loja da sua distribuição e rode de novo."
  exit 1
fi
PROFILE="$DEST/Perfil"
mkdir -p "$PROFILE"
cp -R "$HERE/perfil/." "$PROFILE/"
rm -rf "$DEST/inicio"; cp -R "$HERE/inicio" "$DEST/inicio"
HOMEURL="file://$(printf '%s' "$DEST/inicio/inicio.html" | sed 's/ /%20/g')"
echo "user_pref(\"browser.startup.homepage\", \"$HOMEURL\");" >> "$PROFILE/user.js"

for s in 16 32 48 64 128 256 512; do
  mkdir -p "$HOME/.local/share/icons/hicolor/${s}x${s}/apps"
done
cp "$HERE/icones/portico.png" "$HOME/.local/share/icons/hicolor/512x512/apps/portico.png"
mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
cat > "$HOME/.local/bin/portico" <<EOS
#!/bin/bash
exec $ENGINE --profile "$PROFILE" --name portico --class portico "\$@"
EOS
chmod +x "$HOME/.local/bin/portico"
cat > "$HOME/.local/share/applications/portico.desktop" <<EOS
[Desktop Entry]
Type=Application
Name=Pórtico
GenericName=Navegador
Comment=Navegador do AtriumOS (prévia de teste)
Exec=$HOME/.local/bin/portico %u
Icon=portico
Terminal=false
StartupWMClass=portico
Categories=Network;WebBrowser;
MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;
Actions=privada;
[Desktop Action privada]
Name=Nova janela privada
Exec=$HOME/.local/bin/portico --private-window
EOS
command -v update-desktop-database >/dev/null && update-desktop-database "$HOME/.local/share/applications" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
cat > "$DEST/desinstalar.sh" <<EOS
#!/bin/bash
rm -rf "$DEST" "$HOME/.local/bin/portico" "$HOME/.local/share/applications/portico.desktop" "$HOME/.local/share/icons/hicolor/512x512/apps/portico.png"
echo "Pórtico removido."
EOS
chmod +x "$DEST/desinstalar.sh"
echo "  Pronto! Procure por Pórtico no menu de aplicativos."
echo "  Para remover: $DEST/desinstalar.sh"
nohup "$HOME/.local/bin/portico" >/dev/null 2>&1 &
