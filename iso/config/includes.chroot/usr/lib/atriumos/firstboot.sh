#!/bin/sh
# AtriumOS — ajustes do primeiro boot do sistema instalado
# Entrar direto na interface com o usuário criado na instalação
U="$(getent passwd 1000 | cut -d: -f1)"
OV=/etc/systemd/system/getty@tty1.service.d/autologin.conf
if [ -n "$U" ]; then
  sed -i "s/--autologin [^ ]*/--autologin $U/" "$OV"
  [ -f "/home/$U/.bash_profile" ] || { cp /etc/skel/.bash_profile "/home/$U/"; chown "$U:" "/home/$U/.bash_profile"; }
else
  rm -f "$OV"
fi
systemctl daemon-reload || true

# Pontos de restauração automáticos (Btrfs + Snapper)
if [ "$(findmnt -no FSTYPE /)" = "btrfs" ] && command -v snapper >/dev/null 2>&1; then
  if [ ! -f /etc/snapper/configs/root ]; then
    snapper --no-dbus -c root create-config / || true
    snapper --no-dbus -c root set-config NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5 TIMELINE_CREATE=no || true
    snapper --no-dbus -c root create -d "AtriumOS instalado" -c number || true
  fi
fi
# ponto de restauração obrigatório antes de cada atualização
if [ -f /etc/snapper/configs/root ] && [ ! -f /etc/apt/apt.conf.d/80snapper ]; then
  cat > /etc/apt/apt.conf.d/80atrium-restauracao <<'APT'
DPkg::Pre-Invoke { "if [ -f /etc/snapper/configs/root ]; then snapper --no-dbus -c root create -d 'Antes da atualização' -c number --userdata important=yes || true; fi"; };
APT
fi
systemctl disable atrium-firstboot.service >/dev/null 2>&1 || true
