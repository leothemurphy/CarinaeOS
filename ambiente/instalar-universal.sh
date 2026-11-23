#!/bin/bash
# CarinaeOS — instala o ambiente Gravidade + Aurora noutra distribuição Linux
#
#   ./instalar-universal.sh              instala (pede a senha de administrador)
#   ./instalar-universal.sh --remover    desinstala o que foi instalado
#   ./instalar-universal.sh --so-dependencias | --so-compilar     (para testes)
#
# Funciona em Debian 13+, Ubuntu 25.04+, Fedora 41+, Arch/Manjaro/EndeavourOS e openSUSE Tumbleweed.
# Instala em /usr/local e acrescenta a sessão "CarinaeOS (Gravidade)" à tela de entrada.
# O ambiente que já tem (GNOME, KDE, XFCE…) não é tocado: continua lá para escolher no login.
set -e
cd "$(dirname "$(readlink -f "$0")")"
PREFIXO=/usr/local
CONSTRUCAO=construcao-universal
azul() { printf '\n\033[1;34m== %s\033[0m\n' "$*"; }
erro() { printf '\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }
SUDO=sudo; [ "$(id -u)" = 0 ] && SUDO=

if [ "$1" = "--remover" ]; then
    [ -f "$CONSTRUCAO/install_manifest.txt" ] || erro "Não encontrei $CONSTRUCAO/install_manifest.txt (instale primeiro com este script)."
    azul "Remover o CarinaeOS (Gravidade + Aurora)"
    xargs -d '\n' -a "$CONSTRUCAO/install_manifest.txt" $SUDO rm -f
    echo "Removido. As suas definições em ~/.config/carinaeos ficaram (apague à mão se quiser)."
    exit 0
fi

. /etc/os-release
FAMILIA=""
for i in $ID $ID_LIKE; do
    case "$i" in
        debian|ubuntu) FAMILIA=debian; break ;;
        fedora|rhel|centos) FAMILIA=fedora; break ;;
        arch|archlinux|manjaro|endeavouros) FAMILIA=arch; break ;;
        opensuse*|suse|sles) FAMILIA=suse; break ;;
    esac
done
[ -n "$FAMILIA" ] || erro "Ainda não sei instalar em \"$PRETTY_NAME\". Instale à mão os pacotes de LEIA-ME e corra: cmake -S . -B construcao && sudo cmake --install construcao"
echo "Sistema: $PRETTY_NAME  (família $FAMILIA)"

azul "1/3  Dependências"
case $FAMILIA in
debian)
    PACOTES="build-essential cmake pkg-config qt6-base-dev qt6-declarative-dev qt6-base-private-dev qt6-declarative-private-dev
      libxcb1-dev libxcb-randr0-dev libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-cursor-dev libxcb-composite0-dev
      libxcb-screensaver0-dev libcairo2-dev libpam0g-dev libpolkit-agent-1-dev libpolkit-gobject-1-dev libvterm-dev
      qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-window
      qml6-module-qtquick-templates qml6-module-qtqml-models qml6-module-qtqml-workerscript qml6-module-qtcore
      qml6-module-qt-labs-folderlistmodel qml6-module-qtquick-effects qml6-module-qtquick-dialogs qml6-module-qtquick-pdf
      qml6-module-qtmultimedia qt6-image-formats-plugins qt6-svg-plugins
      python3-pyside6.qtcore python3-pyside6.qtgui python3-pyside6.qtqml python3-pyside6.qtquick
      python3-pyside6.qtquickcontrols2 python3-pyside6.qtnetwork python3-gi python3-dbus python3-psutil python3-pil
      xorg picom xdotool maim xclip zenity x11-xserver-utils x11-utils playerctl libnotify-bin i3lock xss-lock
      network-manager pipewire-pulse wireplumber fonts-inter"
    $SUDO apt-get update -qq
    lista=""
    for p in $PACOTES; do
        if apt-cache show "$p" >/dev/null 2>&1; then lista="$lista $p"; else echo "  (não existe aqui: $p — sigo sem ele)"; fi
    done
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y --no-install-recommends $lista ;;
fedora)
    $SUDO dnf install -y --skip-unavailable gcc-c++ cmake pkgconf-pkg-config qt6-qtbase-devel qt6-qtbase-private-devel \
      qt6-qtdeclarative-devel libxcb-devel xcb-util-wm-devel xcb-util-keysyms-devel xcb-util-cursor-devel cairo-devel \
      pam-devel polkit-devel libvterm-devel qt6-qtdeclarative qt6-qtmultimedia qt6-qtsvg qt6-qtimageformats qt6-qtpdf \
      python3-pyside6 python3-gobject python3-dbus python3-psutil python3-pillow \
      xorg-x11-server-Xorg xinit picom xdotool maim xclip zenity xrandr xset xprop xdpyinfo playerctl libnotify \
      i3lock xss-lock NetworkManager rsms-inter-fonts ;;
arch)
    $SUDO pacman -Sy --needed --noconfirm base-devel cmake pkgconf qt6-base qt6-declarative qt6-multimedia qt6-svg \
      qt6-imageformats qt6-webengine libxcb xcb-util-wm xcb-util-keysyms xcb-util-cursor cairo pam polkit libvterm \
      pyside6 python-gobject python-dbus python-psutil python-pillow \
      xorg-server picom xdotool maim xclip zenity xorg-xrandr xorg-xset xorg-xprop xorg-xdpyinfo playerctl libnotify \
      i3lock xss-lock networkmanager inter-font ;;
suse)
    $SUDO zypper --non-interactive install --no-recommends gcc-c++ cmake pkgconf qt6-base-devel qt6-base-private-devel \
      qt6-declarative-devel qt6-declarative-private-devel libxcb-devel xcb-util-wm-devel xcb-util-keysyms-devel \
      xcb-util-cursor-devel cairo-devel pam-devel polkit-devel libvterm-devel \
      qt6-declarative-imports qt6-multimedia-imports qt6-svg qt6-imageformats qt6-pdf-imports \
      python3-pyside6 python3-gobject python3-dbus-python python3-psutil python3-Pillow \
      xorg-x11-server picom xdotool maim xclip zenity xrandr xset xprop xdpyinfo playerctl libnotify-tools \
      i3lock xss-lock NetworkManager inter-fonts ;;
esac
[ "$1" = "--so-dependencias" ] && exit 0

azul "2/3  Compilar a Gravidade e a Aurora"
cmake -S . -B "$CONSTRUCAO" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIXO" -Wno-dev >/dev/null
cmake --build "$CONSTRUCAO" -j"$(nproc)"
[ "$1" = "--so-compilar" ] && exit 0

azul "3/3  Instalar em $PREFIXO"
$SUDO cmake --install "$CONSTRUCAO" >/dev/null
$SUDO gtk-update-icon-cache -q -f "$PREFIXO/share/icons/hicolor" 2>/dev/null || true
$SUDO update-desktop-database -q "$PREFIXO/share/applications" 2>/dev/null || true
# o terminal do sistema passa a ser o Terminal Carinae (só onde há "alternatives")
command -v update-alternatives >/dev/null && \
    $SUDO update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator "$PREFIXO/bin/carinae-terminal" 40 >/dev/null 2>&1 || true
if [ -n "$SUDO" ]; then
    mkdir -p "$HOME/.config/carinaeos"
    [ -f "$HOME/.config/carinaeos/atalhos.conf" ] || cp sessao/atalhos.conf "$HOME/.config/carinaeos/atalhos.conf"
    [ -f "$HOME/.config/carinaeos/sessao.conf" ] || cp sessao/sessao.conf.exemplo "$HOME/.config/carinaeos/sessao.conf"
fi

echo
echo "✔ Pronto. Termine a sessão e, na tela de entrada, escolha \"CarinaeOS (Gravidade)\"."
echo "  (é uma sessão X11; no GDM a escolha está na roda dentada, no SDDM no canto de baixo)"
echo "  Para desinstalar:  ./instalar-universal.sh --remover"
