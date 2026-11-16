#!/bin/bash
# CarinaeOS - confere uma ISO gerada (ou uma pasta com o sistema já aberto) antes de a publicar:
# o que o CarinaeOS promete tem de estar lá. Sai com 1 se alguma coisa faltar (a CI para).
#   verificar-iso.sh CarinaeOS.iso     (precisa de sudo para montar)
#   verificar-iso.sh /caminho/da/raiz  (ex.: o chroot da construção)
set -u
ALVO=${1:?uso: verificar-iso.sh ISO|PASTA}
FALHAS=0
ok()    { printf '  \033[32m✓\033[0m %s\n' "$1"; }
falha() { printf '  \033[31m✗ %s\033[0m\n' "$1"; FALHAS=$((FALHAS + 1)); }
secao() { printf '\n%s\n' "$1"; }

# ---- abrir a ISO ----------------------------------------------------------------------------
if [ -d "$ALVO" ]; then
    R=$ALVO
else
    M=$(mktemp -d); R=$(mktemp -d)
    sudo mount -o loop,ro "$ALVO" "$M" || { echo "não consegui montar $ALVO"; exit 1; }
    SQ=$(find "$M" -name filesystem.squashfs | head -1)
    [ -n "$SQ" ] || { echo "a ISO não tem filesystem.squashfs"; sudo umount "$M"; exit 1; }
    sudo mount -t squashfs -o loop,ro "$SQ" "$R" || { echo "não consegui abrir o squashfs"; sudo umount "$M"; exit 1; }
    trap 'sudo umount "$R" "$M" 2>/dev/null; rmdir "$R" "$M" 2>/dev/null' EXIT
fi
echo "A conferir: $ALVO"

instalado() {   # pacote instalado no sistema da ISO
    awk -v p="$1" '$0=="Package: "p{a=1;next} a&&/^Status:/{print;exit} /^$/{a=0}' "$R/var/lib/dpkg/status" 2>/dev/null \
        | grep -q 'install ok installed'
}
existe()   { [ -e "$R$1" ] && ok "$2" || falha "$2 (falta $1)"; }
contem()   { grep -qE "$2" "$R$1" 2>/dev/null && ok "$3" || falha "$3 ($1 sem «$2»)"; }
pacote()   { instalado "$1" && ok "pacote $1" || falha "pacote $1 não está instalado"; }

# ---- memória: zram e a proteção do kernel contra travamentos ------------------------------------
secao "Memória"
pacote systemd-zram-generator
contem /etc/systemd/zram-generator.conf 'zram-size' 'zram configurado (metade da memória, zstd)'
contem /usr/lib/sysctl.d/60-carinaeos-memoria.conf 'vm\.swappiness *= *150' 'swappiness 150 (swap na memória)'
contem /usr/lib/tmpfiles.d/carinaeos-memoria.conf 'lru_gen/min_ttl_ms .* 1000' 'proteção contra travamentos (MGLRU 1000 ms)'
if ls "$R"/boot/config-* >/dev/null 2>&1; then
    grep -q '^CONFIG_LRU_GEN_ENABLED=y' "$R"/boot/config-* && ok 'kernel com o Multi-Gen LRU ligado' || falha 'kernel sem CONFIG_LRU_GEN_ENABLED'
    grep -qE '^CONFIG_ZRAM=(y|m)' "$R"/boot/config-* && ok 'kernel com zram' || falha 'kernel sem zram'
fi

# ---- disco mecânico (só liga em HD) ---------------------------------------------------------------
secao "Disco"
contem /usr/lib/udev/rules.d/60-carinaeos-disco.rules 'rotational.*=="1"' 'BFQ só nos discos mecânicos'
existe /usr/lib/modules-load.d/carinaeos-bfq.conf 'módulo BFQ carregado no arranque'

# ---- música: mpd sem io_uring e a ponte MPRIS ------------------------------------------------------
secao "Música"
pacote mpd
pacote mpdris2
contem /usr/lib/systemd/user/mpd.service.d/carinaeos-sem-io-uring.conf 'io_uring' 'mpd sem io_uring (sem pressão de disco falsa)'
contem /usr/lib/systemd/user/mpd.service.d/carinaeos-ponte-mpris.conf 'Wants=mpDris2' 'a ponte MPRIS arranca com o mpd'
contem /usr/lib/systemd/user/mpDris2.service.d/carinaeos.conf 'Restart=always' 'a ponte MPRIS volta sozinha'

# ---- atalhos ------------------------------------------------------------------------------------
secao "Atalhos"
contem /etc/xdg/kglobalshortcutsrc 'Ctrl\+Alt\+Del' 'Ctrl+Alt+Del → Forçar o encerramento'
contem /usr/share/kglobalaccel/carinaeos-encerrar.desktop 'X-KDE-Shortcuts=.*Ctrl\+Alt\+Del' 'atalho do Forçar o encerramento'
existe /usr/share/kglobalaccel/carinaeos-comando.desktop 'atalho do Comando (Ctrl+Espaço)'

# ---- ações de administrador (polkit): cada uma aponta para um programa que existe e é do root -------
secao "Administrador (polkit)"
for pol in "$R"/usr/share/polkit-1/actions/org.carinaeos.*.policy; do
    [ -e "$pol" ] || { falha 'nenhuma política do CarinaeOS'; break; }
    exe=$(grep -o 'exec.path">[^<]*' "$pol" | cut -d'>' -f2)
    nome=$(basename "$pol" .policy)
    if [ -z "$exe" ]; then ok "$nome"; continue; fi
    if [ -x "$R$exe" ] && [ "$(stat -c %u "$R$exe")" = 0 ] && [ "$(stat -c %a "$R$exe")" -le 755 ]; then
        ok "$nome → $exe"
    else
        falha "$nome → $exe não existe, não é do root ou tem permissões a mais"
    fi
done
contem /usr/lib/carinaeos/remover-pacote 'nvidia\.\*\|libnvidia\.\*\|firmware-\.\*' 'o desinstalador protege a NVIDIA e os firmwares'
contem /usr/lib/carinaeos/placa-video 'apt-mark manual' 'o driver NVIDIA fica fora do autoremove'

# ---- os comandos do CarinaeOS -----------------------------------------------------------------------
secao "Comandos"
n=0; ruins=""
for f in "$R"/usr/bin/carinaeos-* "$R"/usr/lib/carinaeos/*; do
    [ -f "$f" ] || continue
    n=$((n + 1))
    [ -x "$f" ] || ruins="$ruins $(basename "$f")"
done
[ -z "$ruins" ] && ok "$n comandos executáveis" || falha "sem permissão de execução:$ruins"
pyerro=""
for f in $(grep -rlE '^#!/usr/bin/(env )?python3' "$R"/usr/bin/carinaeos-* "$R"/usr/lib/carinaeos 2>/dev/null) \
         $(find "$R"/usr/share/carinaeos -name '*.py' 2>/dev/null); do
    python3 - "$f" <<'PY' 2>/dev/null || pyerro="$pyerro ${f#$R}"
import ast, sys
ast.parse(open(sys.argv[1], encoding='utf-8').read(), sys.argv[1])
PY
done
[ -z "$pyerro" ] && ok 'todo o Python do CarinaeOS compila' || falha "Python com erro de sintaxe:$pyerro"

# ---- o que saiu e o que nunca pode ir para a ISO -------------------------------------------------------
secao "Limpeza"
[ ! -e "$R/usr/bin/carinaeos-rotinas" ] && [ ! -d "$R/usr/share/carinaeos/rotinas" ] && ok 'as Rotinas saíram' || falha 'restos das Rotinas na ISO'
if grep -rqsE 'ptrace_scope *= *0' "$R"/etc/sysctl.d "$R"/usr/lib/sysctl.d "$R"/etc/sysctl.conf; then
    falha 'ptrace_scope = 0 na ISO (depurar processos de outros sem permissão)'
else
    ok 'ptrace_scope não é afrouxado'
fi
[ -z "$(ls -A "$R"/home 2>/dev/null)" ] && ok '/home vazio (sem dados de quem construiu)' || falha "/home não está vazio: $(ls "$R"/home)"

echo
if [ "$FALHAS" -eq 0 ]; then echo "ISO conferida: tudo no lugar."; exit 0; fi
echo "ISO com $FALHAS problema(s): não publicar."; exit 1
