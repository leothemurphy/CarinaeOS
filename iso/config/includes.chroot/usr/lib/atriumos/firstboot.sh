#!/bin/sh
# AtriumOS — ajustes do primeiro boot do sistema instalado
U="$(getent passwd 1000 | cut -d: -f1)"
[ -n "$U" ] && usermod -aG sambashare,lpadmin "$U" 2>/dev/null || true
rm -f /etc/sddm.conf.d/90-live.conf

# Pontos de restauração automáticos (Btrfs + Snapper)
if [ "$(findmnt -no FSTYPE /)" = "btrfs" ] && command -v snapper >/dev/null 2>&1; then
  if [ ! -f /etc/snapper/configs/root ]; then
    snapper --no-dbus -c root create-config / || true
    snapper --no-dbus -c root set-config NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5 TIMELINE_CREATE=no || true
    snapper --no-dbus -c root create -d "AtriumOS instalado" -c number || true
  fi
fi
# ponto de restauração obrigatório antes de cada atualização
if [ -f /etc/snapper/configs/root ] && [ ! -f /etc/apt/apt.conf.d/80atrium-restauracao ]; then
  cat > /etc/apt/apt.conf.d/80atrium-restauracao <<'APT'
DPkg::Pre-Invoke { "if [ -f /etc/snapper/configs/root ]; then snapper --no-dbus -c root create -d 'Antes da atualização' -c number --userdata important=yes || true; fi"; };
APT
fi
systemctl disable atrium-firstboot.service >/dev/null 2>&1 || true
