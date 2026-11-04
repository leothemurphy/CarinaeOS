#!/bin/sh
# AtriumOS — prepara o Android na primeira vez (roda como root).
# Baixa o sistema Android (~900 MB) e a loja Aurora (do F-Droid).
set -e
mkdir -p /var/lib/atriumos
if [ ! -e /var/lib/waydroid/waydroid.cfg ]; then
  waydroid init
fi
if [ ! -f /var/lib/atriumos/aurora-store.apk ]; then
  V=$(curl -fsSL https://f-droid.org/api/v1/packages/com.aurora.store | python3 -c 'import json,sys;print(json.load(sys.stdin)["suggestedVersionCode"])')
  curl -fsSL -o /var/lib/atriumos/aurora-store.apk "https://f-droid.org/repo/com.aurora.store_${V}.apk"
fi
systemctl enable --now waydroid-container.service || true
