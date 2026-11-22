#!/bin/bash
# CarinaeOS — tirar o Plasma/KDE do sistema, com segurança.
#   bash ferramentas/limpar-kde.sh              só mostra o que sairia (não muda nada)
#   bash ferramentas/limpar-kde.sh --remover    remove (pergunta antes, guarda a lista para poder voltar atrás)
#   bash ferramentas/limpar-kde.sh --restaurar ARQUIVO   reinstala o que foi removido
set -u
cd "$(dirname "$0")/.."
azul() { printf '\n\033[1;34m%s\033[0m\n' "$*"; }
aviso() { printf '\033[1;33m%s\033[0m\n' "$*"; }
erro() { printf '\033[1;31m%s\033[0m\n' "$*"; }

# ---- verificar que tudo o que é preciso para entrar no CarinaeOS está lá ------------------------------
verificar() {
    local falta=0
    ok() { printf '  \033[1;32m✔\033[0m %s\n' "$1"; }
    mal() { printf '  \033[1;31m✘ %s\033[0m\n' "$1"; falta=1; }
    command -v sddm >/dev/null && ok "SDDM (tela de entrada)" || mal "falta o SDDM"
    systemctl is-enabled sddm >/dev/null 2>&1 && ok "SDDM arranca com o computador" || mal "o SDDM não está ativado"
    [ -f /usr/share/sddm/themes/carinaeos/Main.qml ] && ok "tema da tela de entrada (carinaeos)" || mal "falta o tema carinaeos do SDDM"
    for m in QtQuick QtQuick/Controls QtQuick/Effects QtQuick/Layouts; do
        ls -d /usr/lib/*/qt6/qml/$m >/dev/null 2>&1 && ok "módulo Qt $m" || mal "falta o módulo Qt $m"
    done
    command -v Xorg >/dev/null || [ -x /usr/lib/xorg/Xorg ] && ok "servidor gráfico (Xorg)" || mal "falta o Xorg"
    [ -f /usr/share/xsessions/carinae.desktop ] && ok "sessão CarinaeOS registada" || mal "falta /usr/share/xsessions/carinae.desktop"
    for b in startcarinae gravidade aurora carinae-senha carinae-energia carinaeos-arquivos carinae-terminal; do
        command -v "$b" >/dev/null && ok "$b" || mal "falta $b"
    done
    python3 -c 'import PySide6.QtQuick' 2>/dev/null && ok "PySide6 (os nossos apps)" || mal "o PySide6 não funciona"
    for l in $(ldd "$(command -v aurora)" 2>/dev/null | awk '/not found/{print $1}'); do mal "a Aurora não encontra $l"; done
    for l in $(ldd "$(command -v gravidade)" 2>/dev/null | awk '/not found/{print $1}'); do mal "a Gravidade não encontra $l"; done
    command -v nmcli >/dev/null && ok "rede (NetworkManager)" || mal "falta o NetworkManager"
    command -v wpctl >/dev/null && ok "som (PipeWire)" || mal "falta o PipeWire"
    return $falta
}

if [ "${1:-}" = "--verificar" ]; then
    azul "O que é preciso para entrar no CarinaeOS"
    verificar && echo "  Tudo certo." || erro "  Há problemas acima: não reinicie antes de os resolver."
    exit $?
fi

if [ "${1:-}" = "--restaurar" ]; then
    f=${2:-$(ls -t "$HOME"/.local/share/carinaeos/kde-removido-*.txt 2>/dev/null | head -1)}
    [ -f "$f" ] || { erro "Não encontrei a lista ($f)."; exit 1; }
    azul "A reinstalar $(wc -w < "$f") pacotes de $f"
    sudo apt-get install -y $(cat "$f")
    exit $?
fi

# ---- o que sai: os programas e o ambiente do KDE (as bibliotecas saem sozinhas depois, se ninguém as usar) ----
PADROES='^(plasma-.*|kde-plasma.*|task-kde.*|kde-standard|kde-baseapps|kwin.*|kscreen.*|powerdevil.*|kde-config-.*|kdeplasma.*|plasma|kactivitymanagerd|kglobalacceld|ksystemstats|kmenuedit|khotkeys|kinfocenter|khelpcenter|kfind|kwalletmanager|kwrited|ksshaskpass|kde-spectacle|spectacle|dolphin|konsole|okular|gwenview|kate|kwrite|ark|kcalc|systemsettings|drkonqi|konqueror|merkuro|marble|partitionmanager|milou|polkit-kde-agent-1|xdg-desktop-portal-kde|kde-cli-tools|kdialog|kio-extras|ffmpegthumbs|kdegraphics-thumbnailers|sweeper|kmousetool|kmag|kmouth|kontrast|bluedevil|print-manager|kde-inotify-survey|kgamma|kup-backup|kunifiedpush|kwayland-integration|layer-shell-qt|oxygen-sounds|ocean-sound-theme|discover|plasma-discover.*)$'

# o que fica (ainda não tem substituto nosso, ou é útil fora do KDE)
MANTER='^(skanlite|kdeconnect|kaccounts-integration|kaccounts-providers|sddm|breeze-cursor-theme|breeze-icon-theme|breeze-gtk-theme|kde-style-breeze|qt6-style-kvantum)$'

# o que NUNCA pode sair (se o apt quiser levar algum destes, paramos)
PROTEGER='^(sddm|xserver-xorg-core|xserver-xorg|network-manager|pipewire|pipewire-pulse|wireplumber|polkitd|udisks2|cups|bluez|dbus|systemd|sudo|firefox-esr|zenity|qt6ct|xdg-desktop-portal|xdg-desktop-portal-gtk|gnome-keyring|xdotool|picom|python3-pyside6.*|qml6-module-qtquick.*|libqt6core6.*|libqt6gui6.*|qt6-base-dev|python3|grub.*|linux-image.*|nvidia-driver|firmware-.*)$'
# e tudo o que o instalar.sh do CarinaeOS precisa
NOSSOS=$(sed -n '/^PRECISOS="/,/"$/p; /^UTEIS="/p' instalar.sh | sed 's/^[A-Z]*="//; s/"$//' | tr ' \n' '\n\n' | grep -v '^$' | sort -u)

azul "1/4  O que está instalado do KDE"
instalados=$(dpkg-query -W -f='${db:Status-Status} ${Package}\n' 2>/dev/null | awk '$1=="installed"{print $2}')
LISTA=$(echo "$instalados" | grep -E "$PADROES" | grep -vE "$MANTER" | sort -u)
if [ -z "$LISTA" ]; then
    echo "  Nada do Plasma/KDE para tirar. Já está limpo."
    exit 0
fi
echo "$LISTA" | column -c "$(tput cols 2>/dev/null || echo 100)"
echo "  ($(echo "$LISTA" | wc -l) pacotes; ficam: skanlite, kdeconnect, contas online, o SDDM e os cursores/ícones Breeze)"

azul "2/4  Simulação (o apt diz o que levaria junto — nada é mudado)"
# o que queremos manter não pode ir "por arrasto": descobrimos qual dos pacotes da lista o arrastaria
# (simula-se a remoção de cada um sozinho) e esse fica.
FICAM_POR=""
for volta in 1 2 3; do
    SIM=$(LC_ALL=C apt-get -s purge $LISTA 2>&1)
    if echo "$SIM" | grep -q '^E:'; then erro "$(echo "$SIM" | grep '^E:')"; exit 1; fi
    LEVA=$(echo "$SIM" | awk '/^Purg|^Remv/{print $2}' | sort -u)
    ARRASTO=$(echo "$LEVA" | grep -E "$MANTER" | grep -vxF -f <(echo "$LISTA"))
    [ -z "$ARRASTO" ] && break
    [ "$volta" = 1 ] && echo "  A ver o que o $(echo $ARRASTO | sed 's/ /, o /g') precisa (demora uns segundos)…"
    for x in $LISTA; do
        leva_x=$(LC_ALL=C apt-get -s purge "$x" 2>/dev/null | awk '/^Purg|^Remv/{print $2}')
        apanha=$(echo "$leva_x" | grep -xF -f <(echo "$ARRASTO") | head -1)
        if [ -n "$apanha" ]; then
            FICAM_POR="$FICAM_POR
$x  (o $apanha precisa)"
            LISTA=$(echo "$LISTA" | grep -vx "$x")
        fi
    done
done
if [ -n "$(echo "$FICAM_POR" | grep .)" ]; then
    echo "  Ficam também (são precisos para o KDE Connect ou as contas online):"
    echo "$FICAM_POR" | grep . | sort -u | sed 's/^/    /'
fi
EXTRA=$(comm -13 <(echo "$LISTA") <(echo "$LEVA"))
if [ -n "$EXTRA" ]; then
    echo "  Também sairiam (dependem dos de cima):"
    echo "$EXTRA" | sed 's/^/    /'
fi
PERIGO=$( { echo "$LEVA" | grep -E "$PROTEGER"; comm -12 <(echo "$LEVA") <(echo "$NOSSOS"); } | sort -u)
if [ -n "$PERIGO" ]; then
    erro "  PARO AQUI: a remoção levaria coisas de que o CarinaeOS precisa:"
    echo "$PERIGO" | sed 's/^/    /'
    echo "  Mande-me esta saída para eu ajustar a lista."
    exit 2
fi
tam=$(dpkg-query -W -f='${Installed-Size}\n' $LEVA 2>/dev/null | awk '{s+=$1} END{printf "%.0f", s/1024}')
echo "  Nada de essencial é tocado. Libertaria cerca de ${tam} MB (mais o que o autoremove limpar a seguir)."

azul "3/4  O que ainda usa o KDE neste momento"
for p in /proc/[0-9]*; do
    exe=$(readlink "$p/exe" 2>/dev/null) || continue
    pk=$(dpkg -S "$exe" 2>/dev/null | cut -d: -f1 | head -1)
    if [ -n "$pk" ] && echo "$LEVA" | grep -qx "$pk"; then
        echo "  $(basename "$exe") (pacote $pk) está a correr"
    fi
done | sort -u

if [ "${1:-}" != "--remover" ]; then
    azul "4/4  Nada foi mudado."
    echo "  Para remover de verdade:  bash ferramentas/limpar-kde.sh --remover"
    exit 0
fi

azul "4/4  Remover"
mkdir -p "$HOME/.local/share/carinaeos"
GUARDA="$HOME/.local/share/carinaeos/kde-removido-$(date +%Y%m%d-%H%M).txt"
echo "$LEVA" > "$GUARDA"
echo "  A lista do que sai ficou em: $GUARDA"
echo "  (para voltar atrás:  bash ferramentas/limpar-kde.sh --restaurar \"$GUARDA\")"
grep -q 'carinae' /etc/sddm.conf.d/*.conf 2>/dev/null || aviso "  Atenção: a sessão CarinaeOS não está definida como a predefinida no SDDM."
printf '\n  Escreva SIM para remover %s pacotes: ' "$(echo "$LEVA" | wc -l)"
read -r resposta
[ "$resposta" = "SIM" ] || { echo "  Cancelado. Nada foi mudado."; exit 0; }
sudo apt-get purge -y $LISTA || { erro "  O apt falhou; veja acima."; exit 1; }

echo
echo "  Bibliotecas do KDE que ficaram sem uso (simulação):"
AUTO=$(LC_ALL=C apt-get -s autoremove --purge 2>/dev/null | awk '/^Purg|^Remv/{print $2}')
if [ -n "$AUTO" ]; then
    PERIGO=$( { echo "$AUTO" | grep -E "$PROTEGER"; comm -12 <(echo "$AUTO" | sort -u) <(echo "$NOSSOS"); } | sort -u)
    if [ -n "$PERIGO" ]; then
        aviso "  O autoremove levaria coisas nossas; não o corro. Pacotes:"; echo "$PERIGO" | sed 's/^/    /'
    else
        echo "$AUTO" | column -c "$(tput cols 2>/dev/null || echo 100)"
        echo "$AUTO" >> "$GUARDA"
        printf '  Remover também estes %s? (SIM/não): ' "$(echo "$AUTO" | wc -l)"
        read -r r2
        [ "$r2" = "SIM" ] && sudo apt-get autoremove --purge -y
    fi
fi
# os nossos atalhos e as associações de ficheiros continuam certas; o menu é refeito
sudo update-desktop-database -q /usr/share/applications 2>/dev/null || true
azul "Verificação final"
if verificar; then
    azul "Pronto. Tudo o que é preciso para entrar está lá."
    echo "  Teste primeiro sem reiniciar: termine a sessão (estrela › Terminar sessão) e entre de novo."
    echo "  Se entrar bem, pode reiniciar à vontade."
else
    erro "Há problemas acima. NÃO reinicie: mande-me esta saída, ou volte atrás com:"
    echo "  bash ferramentas/limpar-kde.sh --restaurar \"$GUARDA\""
fi
