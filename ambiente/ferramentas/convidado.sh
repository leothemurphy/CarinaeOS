#!/bin/bash
# CarinaeOS — prepara a sessão sem rastro (convidado) na tela de entrada.
# Verifica e corrige: a conta "convidado" (sem senha), a entrada sem senha e a pasta na memória (PAM do
# SDDM), e que o convidado entra na sessão CarinaeOS (não no Plasma). Pode correr-se várias vezes.
#   sudo bash ferramentas/convidado.sh            ligar / reparar
#   sudo bash ferramentas/convidado.sh --desligar tirar o convidado da tela de entrada
set -u
[ "$(id -u)" = 0 ] || { echo "Corra com sudo: sudo bash $0"; exit 1; }
verde() { printf '\033[32m✔\033[0m %s\n' "$*"; }
amarelo() { printf '\033[33m•\033[0m %s\n' "$*"; }

SCRIPT=/usr/lib/carinaeos/convidado
if [ ! -x "$SCRIPT" ]; then
    D=$(cd "$(dirname "$0")/.." && pwd)
    install -Dm755 "$D/sessao/carinae-convidado" "$SCRIPT"
    amarelo "script do convidado instalado em $SCRIPT"
fi

if [ "${1:-}" = "--desligar" ]; then
    "$SCRIPT" desligar
    verde "sessão sem rastro desligada (o convidado já não aparece na tela de entrada)"
    exit 0
fi

# 1. a conta
if getent passwd convidado >/dev/null; then verde "conta convidado existe ($(getent passwd convidado | cut -d: -f3,5))"
else amarelo "conta convidado não existia: a criar"; fi
"$SCRIPT" ligar
mkdir -p /etc/carinaeos && touch /etc/carinaeos/convidado-criado
verde "conta convidado ligada e sem senha"

# 2. PAM do SDDM: entra sem senha e a pasta pessoal vive na memória
P=/etc/pam.d/sddm
if [ -f "$P" ]; then
    if grep -q "pam_succeed_if.so user = convidado" "$P"; then verde "SDDM: entrada sem senha já configurada"
    else
        cp "$P" "$P.antes-convidado"
        sed -i '0,/^auth/s//auth    sufficient pam_succeed_if.so user = convidado quiet\nauth/' "$P"
        amarelo "SDDM: entrada sem senha configurada (cópia em $P.antes-convidado)"
    fi
    if grep -q "carinaeos/convidado pam" "$P"; then verde "SDDM: pasta na memória já configurada"
    else
        if grep -qE '^(session|@include common-session)' "$P"; then
            sed -i '0,/^\(session\|@include common-session\)/s//session optional pam_exec.so quiet \/usr\/lib\/carinaeos\/convidado pam\n&/' "$P"
        else
            printf 'session optional pam_exec.so quiet /usr/lib/carinaeos/convidado pam\n' >> "$P"
        fi
        amarelo "SDDM: pasta na memória configurada"
    fi
else
    amarelo "não encontrei $P (o SDDM está instalado?)"
fi

# 3. a sessão por omissão passa a ser a do CarinaeOS (o convidado não tem "última sessão" guardada)
C=/etc/sddm.conf.d/10-carinaeos.conf
mkdir -p /etc/sddm.conf.d
touch "$C"
for f in /etc/sddm.conf /etc/sddm.conf.d/*.conf; do
    [ -f "$f" ] && grep -q '^Session=plasma' "$f" || continue
    sed -i 's/^Session=plasma.*/Session=carinae.desktop/' "$f"
    amarelo "SDDM ($f): a sessão guardada era o Plasma, agora é o CarinaeOS"
done
python3 - "$C" <<'EOF'
import configparser, sys
f = sys.argv[1]
c = configparser.ConfigParser(strict=False, interpolation=None)
c.optionxform = str
c.read(f)
if not c.has_section('General'):
    c.add_section('General')
c.set('General', 'DefaultSession', 'carinae.desktop')
with open(f, 'w') as o:
    c.write(o, space_around_delimiters=False)
EOF
verde "SDDM: sessão por omissão = CarinaeOS"

# 4. a tela de entrada mostra o convidado? (UID entre o mínimo e o máximo do SDDM)
uid=$(id -u convidado)
min=$(grep -hs '^MinimumUid=' /etc/sddm.conf /etc/sddm.conf.d/*.conf /usr/lib/sddm/sddm.conf.d/*.conf | tail -1 | cut -d= -f2)
if [ -n "$min" ] && [ "$uid" -lt "$min" ]; then
    amarelo "o UID do convidado ($uid) é menor que o MinimumUid do SDDM ($min): não ia aparecer — a corrigir"
    python3 - "$C" "$uid" <<'EOF'
import configparser, sys
f, uid = sys.argv[1], sys.argv[2]
c = configparser.ConfigParser(strict=False, interpolation=None); c.optionxform = str; c.read(f)
if not c.has_section('Users'): c.add_section('Users')
c.set('Users', 'MinimumUid', uid)
with open(f, 'w') as o: c.write(o, space_around_delimiters=False)
EOF
fi
if grep -hs '^HideUsers=.*convidado' /etc/sddm.conf /etc/sddm.conf.d/*.conf >/dev/null; then
    sed -i 's/^\(HideUsers=.*\)convidado,\?/\1/' /etc/sddm.conf /etc/sddm.conf.d/*.conf 2>/dev/null
    amarelo "o convidado estava escondido na tela de entrada: já não está"
fi
verde "pronto: na próxima tela de entrada aparece \"Convidado (sem rastro)\", sem senha"
