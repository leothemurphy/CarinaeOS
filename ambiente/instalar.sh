#!/bin/bash
# CarinaeOS — instala o ambiente próprio (carinae-wm + carinae-shell + sessão "CarinaeOS" no SDDM)
#
#   ./instalar.sh            compila, instala em /usr/local e porta a tua Dock atual do Plasma
#   ./instalar.sh --do-plasma   volta a copiar a Dock/Launchpad da versão Plasma (APAGA o que só existe aqui:
#                               os modelos Windows 11/Órbita/Vidro e as animações novas)
#
# O Plasma NÃO é tocado: continua a existir como sessão de reserva.
set -e
cd "$(dirname "$(readlink -f "$0")")"
PREFIXO=/usr/local
QML="$PREFIXO/share/carinaeos/shell"

azul() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }

portar() {
    azul "Portar a Dock, o Launchpad e o menu estrela que estão no Plasma"
    if [ -d /usr/share/plasma/plasmoids/org.carinaeos.dock ]; then
        sudo python3 ferramentas/portar-do-plasma.py /usr/share/plasma/plasmoids "$QML"
    else
        echo "(não encontrei /usr/share/plasma/plasmoids/org.carinaeos.dock — fica a versão que vem no projeto)"
    fi
}

if [ "$1" = "--do-plasma" ]; then
    portar
    carinae-shell --enviar recarregar 2>/dev/null && echo "carinae-shell recarregado." || true
    exit 0
fi

azul "1/4  Dependências"
PRECISOS="build-essential cmake pkg-config qt6-base-dev qt6-declarative-dev
  libxcb1-dev libxcb-randr0-dev libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-cursor-dev libxcb-composite0-dev libxcb-screensaver0-dev
  libcairo2-dev x11proto-dev libpam0g-dev libpolkit-agent-1-dev libpolkit-gobject-1-dev libvterm-dev
  qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-window
  qml6-module-qtquick-templates qml6-module-qtqml-models qml6-module-qtqml-workerscript qml6-module-qtcore
  qml6-module-qt-labs-folderlistmodel qml6-module-qtquick-effects"
UTEIS="xdotool maim xclip qml6-module-qtmultimedia libqt6multimedia6 ffmpeg ffmpegthumbnailer picom xss-lock i3lock x11-utils x11-xserver-utils playerctl imagemagick zenity python3-psutil python3-dbus iputils-ping qt6ct qt6-style-kvantum avahi-utils smbclient numlockx xinput cups-client plocate libnotify-bin qml6-module-qtquick-pdf qml6-module-qtquick-dialogs python3-pil qt6-image-formats-plugins 7zip libarchive-tools"
lista=""
for p in $PRECISOS $UTEIS; do
    if apt-cache show "$p" >/dev/null 2>&1; then lista="$lista $p"; else echo "  aviso: o pacote $p não existe neste Debian (sigo sem ele)"; fi
done
# espera (até 10 min) se outro programa estiver a instalar (ex.: as atualizações automáticas)
sudo apt-get -o DPkg::Lock::Timeout=600 install -y $lista

azul "2/4  Compilar"
cmake -S . -B construcao -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIXO" -Wno-dev
cmake --build construcao -j"$(nproc)"

azul "3/4  Instalar em $PREFIXO (e a sessão em /usr/share/xsessions)"
sudo cmake --install construcao
sudo gtk-update-icon-cache -q -f "$PREFIXO/share/icons/hicolor" 2>/dev/null || true

# a Dock, o Launchpad e o menu estrela agora vivem neste projeto (já não se copiam do Plasma)
# pré-aquecer a sessão no arranque (lê para a memória o que a sessão vai usar, enquanto o login espera)
sudo systemctl daemon-reload 2>/dev/null; sudo systemctl reenable carinae-preaquecer.service 2>/dev/null || true
# o terminal do sistema (Ctrl+Alt+T, Super+Enter, "abrir no terminal" dos apps) passa a ser o nosso
sudo update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$PREFIXO/bin/carinae-terminal" 60 >/dev/null 2>&1 || true
sudo update-alternatives --set x-terminal-emulator "$PREFIXO/bin/carinae-terminal" >/dev/null 2>&1 || true
# sessão sem rastro (convidado) na tela de entrada
sudo bash ferramentas/convidado.sh || true

azul "4/4  Configuração pessoal"
mkdir -p "$HOME/.config/carinaeos"
[ -f "$HOME/.config/carinaeos/atalhos.conf" ] || cp sessao/atalhos.conf "$HOME/.config/carinaeos/atalhos.conf"
# a tecla Print passa a usar a nossa captura (não o Spectacle do KDE)
sed -i 's/^Print = spectacle$/Print = carinae-captura regiao\nShift+Print = carinae-captura\nAlt+Print = carinae-captura janela/' "$HOME/.config/carinaeos/atalhos.conf"
# o botão de ligar passa pelo CarinaeOS (Energia)
grep -q '= carinaeos-emojis' "$HOME/.config/carinaeos/atalhos.conf" || printf '\n# o painel de emojis (como o Win+. do Windows)\nSuper+period = carinaeos-emojis\n' >> "$HOME/.config/carinaeos/atalhos.conf"
grep -q '^Calculator' "$HOME/.config/carinaeos/atalhos.conf" || printf '\n# a tecla da calculadora do teclado\nCalculator = carinaeos-calculadora\n' >> "$HOME/.config/carinaeos/atalhos.conf"
grep -q '^PowerOff' "$HOME/.config/carinaeos/atalhos.conf" || printf '\n# o botão de ligar do computador (o que faz escolhe-se em Energia)\nPowerOff = carinae-energia --botao\nSleep = carinae-sessao suspender\n' >> "$HOME/.config/carinaeos/atalhos.conf"
pkill -HUP -x gravidade 2>/dev/null || true
# aparência dos apps GTK/Electron e o portal GTK (abrir/salvar, tema escuro) no lugar do do KDE
carinae-aparencia-gtk || true
# aparência das apps Qt pelo qt6ct (em vez do tema do Plasma)
carinae-aparencia-qt || true
systemctl --user stop plasma-xdg-desktop-portal-kde.service xdg-desktop-portal.service xdg-desktop-portal-gtk.service 2>/dev/null || true
# o Pulsar substitui o Música: esconder o Música do lançador (o motor dele continua a ser usado)
mkdir -p "$HOME/.local/share/applications"
for f in /usr/share/applications/*.desktop /usr/local/share/applications/*.desktop; do
    [ -f "$f" ] || continue
    case "$(basename "$f")" in carinaeos-pulsar.desktop) continue ;; esac
    if grep -q '^Exec=.*carinaeos-musica' "$f"; then
        d="$HOME/.local/share/applications/$(basename "$f")"
        grep -v '^NoDisplay=' "$f" | sed '0,/^\[Desktop Entry\]/s//[Desktop Entry]\nNoDisplay=true/' > "$d"
        echo "  Música escondido do lançador ($(basename "$f"))"
    fi
done
# o atalho do gestor de ficheiros (que abre o Carinae Arquivos) chama-se "Documentos", não "Dolphin"
d="$HOME/.local/share/applications/org.kde.dolphin.desktop"
if [ -f "$d" ] && grep -q '^Exec=carinaeos-arquivos' "$d"; then
    sed -i 's/^Name=Dolphin$/Name=Documentos/; s/^GenericName=Gestor de ficheiros$/GenericName=Gerenciador de arquivos/; s/^Comment=Redirecionado para o Carinae Arquivos$/Comment=Os seus arquivos e pastas (Carinae Arquivos)/' "$d"
    echo "  atalho Documentos (Carinae Arquivos) pronto"
fi
# papéis de parede para a troca rápida (central de ajustes): os do Leo ficam guardados fora dos Downloads
mkdir -p "$HOME/.local/share/carinaeos/papeis"
[ -f "$HOME/Downloads/wallpapper/futuristic-half-robot-tiger.jpg" ] && cp -n "$HOME/Downloads/wallpapper/futuristic-half-robot-tiger.jpg" "$HOME/.local/share/carinaeos/papeis/tigre.jpg"
[ -f "$HOME/Downloads/wallpapper/3d-colorful-abstract-background-generative-ai.jpg" ] && cp -n "$HOME/Downloads/wallpapper/3d-colorful-abstract-background-generative-ai.jpg" "$HOME/.local/share/carinaeos/papeis/abstrato.jpg"
# Terminal Carinae (o nosso, sem o Konsole): as cores e a fonte guardadas passam para o terminal.json
carinae-terminal-aparencia --aplicar && echo "  Terminal Carinae pronto (cores e fonte: clique direito no ícone › Aparência do terminal…)"
sudo python3 ferramentas/ajustar-antigos.py || true
# todos os nossos apps com o nome "Carinae …" (também os que foram instalados antes, como a Calculadora)
sudo python3 ferramentas/nomes-carinae.py /usr/share/applications "$PREFIXO/share/applications" || true
python3 ferramentas/nomes-carinae.py "$HOME/.local/share/applications" || true
update-desktop-database -q "$HOME/.local/share/applications" 2>/dev/null || true
sudo update-desktop-database -q "$PREFIXO/share/applications" 2>/dev/null || true
# imagens abrem nas Fotos e PDFs no Leitor de PDF (no lugar do Gwenview e do Okular)
for m in image/jpeg image/png image/gif image/webp image/bmp image/svg+xml image/tiff image/avif image/heif image/x-icon; do
    xdg-mime default carinaeos-fotos.desktop "$m" 2>/dev/null || true
done
xdg-mime default carinaeos-pdf.desktop application/pdf 2>/dev/null || true
for m in application/zip application/vnd.rar application/x-rar application/x-7z-compressed application/x-tar application/x-compressed-tar application/x-xz-compressed-tar application/x-bzip-compressed-tar application/x-zstd-compressed-tar application/gzip; do
    xdg-mime default carinaeos-compactador.desktop "$m" 2>/dev/null || true
done
for m in text/plain text/markdown text/x-log text/csv application/json; do
    xdg-mime default carinaeos-notas.desktop "$m" 2>/dev/null || true
done
sudo gtk-update-icon-cache -q -f "$PREFIXO/share/icons/hicolor" 2>/dev/null || true
[ -f "$HOME/.config/carinaeos/sessao.conf" ] || cp sessao/sessao.conf.exemplo "$HOME/.config/carinaeos/sessao.conf"

# a Aurora que está a correr passa já para a versão nova (o resto arranca no próximo início de sessão)
if pgrep -u "$(id -u)" -x aurora >/dev/null; then
    aurora --enviar recarregar 2>/dev/null && echo "  Aurora recarregada (versão nova)"
    pkill -HUP -u "$(id -u)" -x gravidade 2>/dev/null && echo "  Atalhos da Gravidade relidos (Super+. emojis, tecla da calculadora)" || true
    # o Comando novo (com as extensões): fecha o antigo e deixa o novo pronto em segundo plano
    pkill -u "$(id -u)" -f 'carinaeos/comando/comando.py' 2>/dev/null; sleep 0.5
    setsid "$PREFIXO/bin/carinaeos-comando" --fundo >/dev/null 2>&1 < /dev/null &
    echo "  Comando recarregado (Ctrl+Espaço; digite ? para ver as extensões)"
    pgrep -u "$(id -u)" -x carinae-energia >/dev/null || { setsid carinae-energia >/dev/null 2>&1 < /dev/null & echo "  carinae-energia arrancado"; }
    echo "  Para a Gravidade e a janela de senha passarem à versão nova: saia e entre de novo na sessão."
fi

cat <<'FIM'

Pronto! Há duas maneiras de experimentar:

  1) Agora mesmo, sem sair do Plasma:     carinae-experimentar
     (para voltar ao Plasma:              carinae-voltar)

  2) A sessão inteira: termina a sessão e, no ecrã de entrada (SDDM), escolhe "CarinaeOS (Gravidade)".
     Quando estiveres contente, para entrar sempre no CarinaeOS:
         sudo sed -i 's/^Session=plasma$/Session=carinae/' /etc/sddm.conf

Registo da sessão:  ~/.cache/carinaeos/sessao.log
Atalhos:            ~/.config/carinaeos/atalhos.conf
Copiar outra vez a Dock do Plasma (apaga a nossa):  ./instalar.sh --do-plasma
FIM
