#!/bin/bash
# Cria browser/branding/portico a partir da marca "unofficial" do Firefox,
# trocando nome, ícones e ajustes padrão pelos do Pórtico.
# Uso: marca.sh <pasta-do-código-fonte> <pasta-portico-do-repositório>
set -euo pipefail
SRC="$1"; P="$2"; A="$P/../assets"
B="$SRC/browser/branding/portico"
rm -rf "$B"; cp -r "$SRC/browser/branding/unofficial" "$B"

# --- nome ---
sed -i 's/MOZ_APP_DISPLAYNAME=.*/MOZ_APP_DISPLAYNAME=Portico/' "$B/configure.sh"
grep -q MOZ_MACBUNDLE_ID "$B/configure.sh" || echo 'MOZ_MACBUNDLE_ID=org.atriumos.portico' >> "$B/configure.sh"
find "$B/locales" -name 'brand.ftl' -exec sed -i -E \
  -e 's/^(-brand-shorter-name|-brand-short-name|-brand-shortcut-name|-brand-full-name|-brand-product-name) = .*/\1 = Pórtico/' \
  -e 's/^-vendor-short-name = .*/-vendor-short-name = AtriumOS/' \
  -e 's/^trademarkInfo = .*/trademarkInfo = Pórtico usa o motor Gecko, da Mozilla./' {} +
find "$B/locales" -name 'brand.properties' -exec sed -i -E \
  -e 's/^(brandShorterName|brandShortName|brandFullName|brandProductName)=.*/\1=Pórtico/' \
  -e 's/^vendorShortName=.*/vendorShortName=AtriumOS/' {} +

# --- ícones: cada PNG da marca vira o ícone do Pórtico no mesmo tamanho ---
ICON="$A/portico-1024.png"
while IFS= read -r -d '' png; do
  geo=$(identify -format '%wx%h' "$png" 2>/dev/null || echo "")
  [ -n "$geo" ] && convert "$ICON" -resize "$geo!" "$png"
done < <(find "$B" -name '*.png' -print0)
ICO_TMP=$(mktemp -d)
for s in 16 24 32 48 64 128 256; do convert "$ICON" -resize ${s}x${s} "$ICO_TMP/$s.png"; done
convert "$ICO_TMP"/{16,24,32,48,64,128,256}.png "$ICO_TMP/portico.ico"
while IFS= read -r -d '' ico; do cp "$ICO_TMP/portico.ico" "$ico"; done < <(find "$B" -name '*.ico' -print0)
if command -v png2icns >/dev/null 2>&1; then
  for s in 16 32 128 256 512; do convert "$ICON" -resize ${s}x${s} "$ICO_TMP/i$s.png"; done
  png2icns "$ICO_TMP/portico.icns" "$ICO_TMP"/i{16,32,128,256,512}.png >/dev/null
  while IFS= read -r -d '' icns; do cp "$ICO_TMP/portico.icns" "$icns"; done < <(find "$B" -name '*.icns' -print0)
fi
while IFS= read -r -d '' svg; do
  case "$(basename "$svg")" in
    *wordmark*) cat > "$svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="172" height="42" viewBox="0 0 172 42"><text x="0" y="33" font-family="Inter, system-ui, sans-serif" font-size="34" font-weight="700" fill="context-fill #0f172a">Pórtico</text></svg>
SVG
    ;;
    *) cp "$A/browser.svg" "$svg" ;;
  esac
done < <(find "$B" -name '*.svg' -print0)

# --- ajustes padrão do Pórtico (privacidade, sem telemetria, IA desligada) ---
{
  echo ""
  echo "// ---- Pórtico ----"
  grep '^user_pref' "$P/perfil/user.js" | grep -v 'browser.startup.page' | sed 's/^user_pref/pref/'
  echo 'pref("intl.locale.requested", "");'
  echo 'pref("browser.startup.homepage", "about:home");'
} >> "$B/pref/firefox-branding.js"
echo "Marca do Pórtico aplicada em $B"
