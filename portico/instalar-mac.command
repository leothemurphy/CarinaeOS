#!/bin/bash
# ============================================================
#  Pórtico 0.1 — instalador da prévia de teste (macOS 12+)
#  Cria o app "Pórtico" em ~/Aplicativos com um perfil separado.
# ============================================================
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
echo ""
echo "  Pórtico 0.1 — instalando a prévia de teste"
echo ""
ENGINE="/Applications/Firefox.app/Contents/MacOS/firefox"
[ -x "$ENGINE" ] || ENGINE="$HOME/Applications/Firefox.app/Contents/MacOS/firefox"
if [ ! -x "$ENGINE" ]; then
  if command -v brew >/dev/null 2>&1; then
    echo "  Instalando o motor (Firefox) com o Homebrew..."
    brew install --cask firefox || true
    ENGINE="/Applications/Firefox.app/Contents/MacOS/firefox"
  fi
fi
if [ ! -x "$ENGINE" ]; then
  echo "  O Pórtico usa o motor do Firefox. Instale em https://www.mozilla.org/firefox/ e rode de novo."
  open "https://www.mozilla.org/firefox/"
  exit 1
fi

DEST="$HOME/Library/Application Support/Portico"
PROFILE="$DEST/Perfil"
mkdir -p "$PROFILE"
cp -R "$HERE/perfil/." "$PROFILE/"
rm -rf "$DEST/inicio"; cp -R "$HERE/inicio" "$DEST/inicio"
HOMEURL="file://$(printf '%s' "$DEST/inicio/inicio.html" | sed 's/ /%20/g')"
echo "user_pref(\"browser.startup.homepage\", \"$HOMEURL\");" >> "$PROFILE/user.js"

APP="$HOME/Applications/Pórtico.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cat > "$APP/Contents/MacOS/portico" <<EOS
#!/bin/bash
exec "$ENGINE" -profile "$PROFILE" "\$@"
EOS
chmod +x "$APP/Contents/MacOS/portico"
cat > "$APP/Contents/Info.plist" <<EOS
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Pórtico</string>
  <key>CFBundleDisplayName</key><string>Pórtico</string>
  <key>CFBundleIdentifier</key><string>org.atriumos.portico.preview</string>
  <key>CFBundleVersion</key><string>0.1</string>
  <key>CFBundleShortVersionString</key><string>0.1</string>
  <key>CFBundleExecutable</key><string>portico</string>
  <key>CFBundleIconFile</key><string>portico</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>12.0</string>
</dict></plist>
EOS
iconutil -c icns "$HERE/icones/portico.iconset" -o "$APP/Contents/Resources/portico.icns" 2>/dev/null || cp "$HERE/icones/portico.png" "$APP/Contents/Resources/portico.png"
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true
cat > "$DEST/desinstalar.command" <<EOS
#!/bin/bash
rm -rf "$APP" "$DEST"
echo "Pórtico removido."
EOS
chmod +x "$DEST/desinstalar.command"

echo "  Pronto! O Pórtico está em ~/Aplicativos (procure por Pórtico no Spotlight)."
echo "  Para remover: $DEST/desinstalar.command"
open "$APP"
