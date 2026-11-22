#!/bin/bash
# CarinaeOS — deixa o arranque mais rápido (medido com o medir-arranque.sh). Mostra tudo o que faz,
# guarda o estado anterior e pode ser desfeito:
#   sudo bash ferramentas/otimizar-arranque.sh            aplicar
#   sudo bash ferramentas/otimizar-arranque.sh --desfazer voltar ao que estava
set -u
[ "$(id -u)" = 0 ] || { echo "Corre com sudo: sudo bash $0 $*"; exit 1; }
GUARDA=/var/lib/carinaeos/otimizar-arranque
mkdir -p "$GUARDA"
verde() { printf '\033[32m%s\033[0m\n' "$*"; }
azul() { printf '\n\033[1;34m%s\033[0m\n' "$*"; }

# serviços que este PC de mesa não usa (ficam desligados, mas instalados: dá para voltar a ligar)
SERVICOS=(
  "ModemManager.service|modems 3G/4G (o PC não tem)"
  "switcheroo-control.service|troca de placa gráfica de portáteis"
  "nvidia-persistenced.service|só serve para placas de servidor/cálculo"
  "e2scrub_reap.service|limpeza de verificações de disco antigas"
  "cups-browsed.service|procurar impressoras na rede sozinho (imprimir continua a funcionar)"
)

if [ "${1:-}" = "--desfazer" ]; then
    azul "A desfazer"
    if [ -f "$GUARDA/servicos-ligados" ]; then
        while read -r s; do systemctl enable "$s" 2>/dev/null && verde "  ligado de novo: $s"; done < "$GUARDA/servicos-ligados"
    fi
    if [ -f "$GUARDA/ssh-service" ]; then
        systemctl disable --now ssh.socket 2>/dev/null; systemctl enable ssh.service && verde "  SSH volta a arrancar com o sistema"
    fi
    if [ -f "$GUARDA/adiados" ]; then
        systemctl disable carinae-adiar.timer 2>/dev/null
        for s in $(cat "$GUARDA/adiados"); do systemctl enable "$s" 2>/dev/null && verde "  arranca de novo com o sistema: $s"; done
    fi
    [ -f "$GUARDA/grub" ] && cp "$GUARDA/grub" /etc/default/grub && update-grub && verde "  GRUB como estava"
    [ -f "$GUARDA/initramfs.conf" ] && cp "$GUARDA/initramfs.conf" /etc/initramfs-tools/initramfs.conf && update-initramfs -u && verde "  initramfs como estava"
    rm -rf "$GUARDA"
    echo "Feito. Reinicia para valer."
    exit 0
fi

azul "1. Serviços que não fazem falta neste PC"
: > "$GUARDA/servicos-ligados.novo"
for item in "${SERVICOS[@]}"; do
    s=${item%%|*}; porque=${item#*|}
    if systemctl is-enabled "$s" >/dev/null 2>&1; then
        systemctl disable "$s" >/dev/null 2>&1 && echo "$s" >> "$GUARDA/servicos-ligados.novo" && verde "  desligado: $s — $porque"
    fi
done
# o winbind só faz falta num domínio Windows (Active Directory); é ele que atrasa o SSH 3 s
if systemctl is-enabled winbind.service >/dev/null 2>&1; then
    if grep -qiE '^\s*security\s*=\s*(ads|domain)' /etc/samba/smb.conf 2>/dev/null; then
        echo "  (winbind fica: o Samba está num domínio Windows)"
    else
        systemctl disable winbind.service >/dev/null 2>&1 && echo winbind.service >> "$GUARDA/servicos-ligados.novo" \
            && verde "  desligado: winbind.service — só para domínios Windows (a partilha de pastas continua)"
    fi
fi
cat "$GUARDA/servicos-ligados.novo" >> "$GUARDA/servicos-ligados" 2>/dev/null; rm -f "$GUARDA/servicos-ligados.novo"

azul "2. SSH só quando alguém se liga (deixa de atrasar o arranque 5 s)"
if systemctl is-enabled ssh.service >/dev/null 2>&1 && systemctl cat ssh.socket >/dev/null 2>&1; then
    systemctl disable ssh.service >/dev/null 2>&1 && systemctl enable ssh.socket >/dev/null 2>&1 && touch "$GUARDA/ssh-service" \
        && verde "  o SSH continua disponível: arranca no momento em que alguém se liga"
else
    echo "  (nada a fazer)"
fi

azul "3. GRUB: sem esperar 2 s no menu (Esc ou Shift no arranque mostra o menu)"
if grep -q '^GRUB_TIMEOUT=0$' /etc/default/grub && grep -q '^GRUB_TIMEOUT_STYLE=hidden$' /etc/default/grub; then
    echo "  (já estava)"
else
    [ -f "$GUARDA/grub" ] || cp /etc/default/grub "$GUARDA/grub"
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
    if grep -q '^GRUB_TIMEOUT_STYLE=' /etc/default/grub; then sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
    else echo 'GRUB_TIMEOUT_STYLE=hidden' >> /etc/default/grub; fi
    update-grub >/dev/null 2>&1 && verde "  pronto"
fi

azul "4. initramfs mais pequeno (só os módulos deste PC) — o disco lê menos no arranque"
IC=/etc/initramfs-tools/initramfs.conf
if grep -q '^MODULES=dep' "$IC" && grep -q '^COMPRESS=zstd' "$IC"; then
    echo "  (já estava)"
else
    [ -f "$GUARDA/initramfs.conf" ] || cp "$IC" "$GUARDA/initramfs.conf"
    sed -i 's/^MODULES=.*/MODULES=dep/' "$IC"
    if grep -q '^COMPRESS=' "$IC"; then sed -i 's/^COMPRESS=.*/COMPRESS=zstd/' "$IC"; else echo 'COMPRESS=zstd' >> "$IC"; fi
    antes=$(du -h /boot/initrd.img-"$(uname -r)" 2>/dev/null | cut -f1)
    update-initramfs -u >/dev/null 2>&1 && verde "  initramfs: $antes -> $(du -h /boot/initrd.img-"$(uname -r)" | cut -f1)"
fi

azul "5. Partilha de pastas (Samba) arranca 100 s depois de ligar, sem atrasar o arranque"
ADIAR=""
for s in smbd.service nmbd.service wsdd2.service; do
    systemctl is-enabled "$s" >/dev/null 2>&1 && ADIAR="$ADIAR $s"
done
if [ -n "$ADIAR" ] && [ -f /usr/local/lib/systemd/system/carinae-adiar.timer ]; then
    mkdir -p /var/lib/carinaeos
    echo $ADIAR > /var/lib/carinaeos/adiar
    for s in $ADIAR; do systemctl disable "$s" >/dev/null 2>&1; done
    systemctl daemon-reload; systemctl enable carinae-adiar.timer >/dev/null 2>&1
    cp /var/lib/carinaeos/adiar "$GUARDA/adiados"
    verde "  adiados:$ADIAR (continuam a funcionar, só arrancam um pouco depois)"
else
    echo "  (nada a fazer)"
fi

azul "6. Pré-aquecer a sessão enquanto o login espera"
if [ -f /usr/local/lib/systemd/system/carinae-preaquecer.service ]; then
    systemctl daemon-reload; systemctl reenable carinae-preaquecer.service >/dev/null 2>&1 && verde "  ligado (começa logo no início do arranque)"
else
    echo "  (instala primeiro o ambiente: bash instalar.sh)"
fi

echo
echo "Feito. Reinicia e volta a medir:  bash ~/Documentos/carinaeos-ambiente/ferramentas/medir-arranque.sh"
echo "Para voltar atrás:  sudo bash $0 --desfazer"
