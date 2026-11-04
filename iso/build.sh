#!/bin/bash
# ============================================================
#  Constrói a ISO do AtriumOS (rodar como root num Debian 13,
#  ou deixar o GitHub Actions rodar: .github/workflows/iso.yml)
#
#  ATRIUM_ANDROID=0  -> sem Apps Android (Waydroid)
#  ATRIUM_WINDOWS=0  -> sem Apps do Windows (Wine)
# ============================================================
set -euo pipefail
cd "$(dirname "$0")"
ISO="$(pwd)"
ROOT="$(cd .. && pwd)"
INC="$ISO/config/includes.chroot"
ANDROID="${ATRIUM_ANDROID:-1}"
WINDOWS="${ATRIUM_WINDOWS:-1}"

echo "==> AtriumOS 0.1 · Android=$ANDROID · Windows=$WINDOWS"

# 0) confere se todos os pacotes existem no Debian 13 (os que faltarem saem da lista, com aviso)
if command -v apt-cache >/dev/null 2>&1 && grep -q trixie /etc/os-release 2>/dev/null; then
  if [ -f /etc/apt/sources.list.d/debian.sources ]; then
    sed -i -E 's/^Components:.*/Components: main contrib non-free non-free-firmware/' /etc/apt/sources.list.d/debian.sources
  fi
  apt-get update -qq || true
  if apt-cache policy bash 2>/dev/null | grep -q 'Candidate: [0-9]'; then
    for list in config/package-lists/*.list.chroot; do
      while read -r pkg; do
        case "$pkg" in ''|'#'*) continue ;; esac
        if [ -z "$(apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/{print $2}' | grep -v '(none)')" ]; then
          echo "AVISO: o pacote '$pkg' não existe no Debian 13 e foi tirado de $(basename "$list")"
          sed -i "/^${pkg}\$/d" "$list"
        fi
      done < <(sed 's/#.*//' "$list" | tr -s ' \t' '\n')
    done
  else
    echo "AVISO: não deu para conferir os pacotes; seguindo com a lista completa"
  fi
fi

# 1) opções do build (lidas pelos hooks)
mkdir -p "$INC/etc"
printf 'ANDROID=%s\nWINDOWS=%s\n' "$ANDROID" "$WINDOWS" > "$INC/etc/atriumos-build.conf"
if [ "$WINDOWS" != "1" ]; then rm -f config/package-lists/windows.list.chroot; fi

# 2) Pórtico (perfil + página inicial)
mkdir -p "$INC/usr/share/portico"
rm -rf "$INC/usr/share/portico/perfil" "$INC/usr/share/portico/inicio"
cp -r "$ROOT/portico/perfil" "$ROOT/portico/inicio" "$INC/usr/share/portico/"

# 3) ícones
for s in 16 22 24 32 48 64 128 256 512; do
  d="$INC/usr/share/icons/hicolor/${s}x${s}/apps"; mkdir -p "$d"
  cp "$ROOT/assets/atriumos-$s.png" "$d/atriumos.png"
  cp "$ROOT/assets/portico-$s.png"  "$d/portico.png"
done
mkdir -p "$INC/usr/share/icons/hicolor/scalable/apps" "$INC/usr/share/pixmaps"
cp "$ROOT/assets/tile.svg"    "$INC/usr/share/icons/hicolor/scalable/apps/atriumos.svg"
cp "$ROOT/assets/browser.svg" "$INC/usr/share/icons/hicolor/scalable/apps/portico.svg"
cp "$ROOT/assets/atriumos-256.png" "$INC/usr/share/pixmaps/atriumos.png"

# 4) papéis de parede
declare -A WN=([portal]=Portal [brasa]=Brasa [ecos]=Ecos [mosaico]=Mosaico [manha]=Manhã [neon]=Néon [atrio]=Átrio)
for k in "${!WN[@]}"; do
  id="AtriumOS-$(tr '[:lower:]' '[:upper:]' <<< "${k:0:1}")${k:1}"
  d="$INC/usr/share/wallpapers/$id"; mkdir -p "$d/contents/images"
  cp "$ROOT/assets/wallpapers/$k.jpg" "$d/contents/images/3840x2160.jpg"
  cat > "$d/metadata.json" <<J
{"KPlugin":{"Id":"$id","Name":"${WN[$k]}","Authors":[{"Name":"AtriumOS"}],"License":"CC-BY-SA-4.0"}}
J
done

# 5) tela de boot (Plymouth) e instalador (Calamares)
mkdir -p "$INC/usr/share/plymouth/themes/atriumos" "$INC/etc/calamares/branding/atriumos"
cp branding/plymouth/* "$INC/usr/share/plymouth/themes/atriumos/"
cp branding/calamares/* "$INC/etc/calamares/branding/atriumos/"

# 6) configuração do live-build
lb clean --purge >/dev/null 2>&1 || true
lb config

# 7) menu de boot do pen drive com a marca AtriumOS
if [ -d /usr/share/live/build/bootloaders ]; then
  rm -rf config/bootloaders
  cp -r /usr/share/live/build/bootloaders config/bootloaders
  find config/bootloaders -type f \( -name '*.cfg' -o -name '*.in' \) -exec \
    sed -i -e 's/Debian GNU\/Linux/AtriumOS/g' -e 's/Live system/AtriumOS/g' -e 's/Debian Live/AtriumOS/g' {} +
  find config/bootloaders -name 'splash.svg' -exec cp branding/boot/splash.svg {} \;
  find config/bootloaders -name 'splash.png' -exec cp branding/boot/splash.png {} \;
fi

# 8) construir
lb build

ls -lh ./*.iso
