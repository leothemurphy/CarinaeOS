#!/bin/sh
# AtriumOS — prepara o Android na primeira vez (roda como root).
# Baixa o Android (LineageOS do Waydroid, com Google Play Services via GAPPS),
# a tradução de apps ARM (libndk) e a loja Aurora (F-Droid).
set -e
mkdir -p /var/lib/atriumos
if [ ! -e /var/lib/waydroid/waydroid.cfg ]; then
  waydroid init -s GAPPS || waydroid init
fi
if [ ! -f /var/lib/atriumos/aurora-store.apk ]; then
  V=$(curl -fsSL https://f-droid.org/api/v1/packages/com.aurora.store | python3 -c 'import json,sys;print(json.load(sys.stdin)["suggestedVersionCode"])')
  curl -fsSL -o /var/lib/atriumos/aurora-store.apk "https://f-droid.org/repo/com.aurora.store_${V}.apk"
fi
# apps feitos só para celular (ARM) — TikTok, bancos etc. — precisam da tradução libndk
if [ ! -f /var/lib/atriumos/libndk-ok ]; then
  T=/var/lib/atriumos/waydroid_script
  rm -rf "$T"; mkdir -p "$T"
  if curl -fsSL https://codeload.github.com/casualsnek/waydroid_script/tar.gz/refs/heads/main | tar -xz -C "$T" --strip-components=1 \
     && python3 -m venv "$T/venv" && "$T/venv/bin/pip" install -q -r "$T/requirements.txt" \
     && "$T/venv/bin/python3" "$T/main.py" install libndk; then
    touch /var/lib/atriumos/libndk-ok
  else
    echo "AVISO: tradução ARM (libndk) não instalada"
  fi
fi
systemctl enable --now waydroid-container.service || true
touch /var/lib/atriumos/android-pronto
