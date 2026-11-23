#!/bin/bash
# CarinaeOS — mede o arranque (BIOS → núcleo → serviços → login → sessão) e junta tudo num relatório.
# Só lê; não muda nada. Correr depois de reiniciar e entrar na sessão:
#   bash ~/Documentos/carinaeos-ambiente/ferramentas/medir-arranque.sh
SAIDA="$HOME/Documentos/carinaeos-ambiente/relatorio-arranque.txt"
PLOT="$HOME/Documentos/carinaeos-ambiente/relatorio-arranque.svg"
secao() { printf '\n========== %s ==========\n' "$*"; }

{
echo "Relatório de arranque — $(date '+%d/%m/%Y %H:%M:%S') — $(hostname)"
secao "Tempo total (firmware / carregador / núcleo / serviços)"
systemd-analyze 2>&1
secao "Ligado desde"
uptime -s; uptime
secao "Sessão: quando o login aconteceu (segundos depois de ligar)"
boot=$(date -d "$(uptime -s)" +%s)
for f in "$HOME/.cache/carinaeos/sessao.log"; do
    nasc=$(stat -c %W "$f" 2>/dev/null); [ "${nasc:-0}" -gt 0 ] 2>/dev/null || nasc=$(stat -c %Y "$f")
    echo "sessao.log criado $(( nasc - boot )) s depois de ligar"
done
secao "Sessão CarinaeOS (sessao.log)"
cat "$HOME/.cache/carinaeos/sessao.log" 2>&1 | head -150
secao "Serviços mais lentos (sistema)"
systemd-analyze blame 2>&1 | head -40
secao "Cadeia crítica (sistema)"
systemd-analyze critical-chain 2>&1 | head -40
secao "Serviços mais lentos (utilizador)"
systemd-analyze --user blame 2>&1 | head -25
secao "Cadeia crítica (utilizador)"
systemd-analyze --user critical-chain 2>&1 | head -30
secao "Disco (ROTA=1 é disco mecânico)"
lsblk -d -o NAME,ROTA,SIZE,MODEL 2>&1
findmnt -no SOURCE,FSTYPE,OPTIONS / 2>&1
secao "Linha do núcleo e GRUB"
cat /proc/cmdline
grep -E '^GRUB_(TIMEOUT|TIMEOUT_STYLE|CMDLINE_LINUX_DEFAULT|CMDLINE_LINUX)=' /etc/default/grub 2>&1
secao "Login (SDDM)"
cat /etc/sddm.conf 2>/dev/null; ls /etc/sddm.conf.d/ 2>/dev/null && cat /etc/sddm.conf.d/*.conf 2>/dev/null
secao "Núcleo: NVIDIA, firmware e esperas"
journalctl -b -k --no-pager 2>/dev/null | grep -iE 'nvidia|firmware|timed out|timeout|waiting' | head -40
secao "Erros deste arranque"
journalctl -b -p 3 --no-pager 2>&1 | tail -60
secao "Serviços ligados no arranque"
systemctl list-unit-files --type=service --state=enabled --no-pager 2>&1 | head -80
secao "Serviços do utilizador a correr"
systemctl --user list-units --type=service --state=running --no-pager 2>&1 | head -50
secao "Arranque automático (XDG)"
for d in /etc/xdg/autostart "$HOME/.config/autostart"; do
    echo "--- $d"
    for f in "$d"/*.desktop; do
        [ -f "$f" ] || continue
        printf '%s | %s | %s %s %s\n' "$(basename "$f")" "$(grep -m1 '^Exec=' "$f" | cut -c6-)" \
            "$(grep -m1 '^OnlyShowIn=' "$f")" "$(grep -m1 '^NotShowIn=' "$f")" "$(grep -m1 -E '^(Hidden|X-GNOME-Autostart-enabled)=' "$f")"
    done
done
secao "Programas que mais CPU gastaram desde o arranque"
ps -eo pid,etimes,time,rss,comm --sort=-time 2>/dev/null | head -30
secao "Memória"
free -h
} > "$SAIDA" 2>&1

systemd-analyze plot > "$PLOT" 2>/dev/null
echo "Relatório pronto: $SAIDA"
