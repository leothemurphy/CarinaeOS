#!/bin/bash
# CarinaeOS - aplicar num PC já instalado: os 4 papéis de parede novos (cor única com a marca afundada),
# sem papel de parede animado nem estrelas no arranque, a Dock com 3 modelos, janelas sem
# transparência e a cor do Launchpad à escolha.
# Uso (como o seu usuário, não como root):  bash aplicar-visual-simples.sh COMMIT
set -e
C="${1:?diga o commit}"
R="https://raw.githubusercontent.com/leothemurphy/CarinaeOS/$C"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

baixar() { curl -fsSL "$R/$1" -o "$T/x" && sudo install -Dm"${3:-644}" "$T/x" "$2"; }

echo "== Pacotes para gerar os papéis de parede"
sudo apt-get install -y python3-numpy python3-pil >/dev/null

echo "== Papéis de parede"
mkdir -p "$T/fundos"
curl -fsSL "$R/carinae-debian/fundos/fundos.py" -o "$T/fundos/fundos.py"
curl -fsSL "$R/carinae-debian/fundos/marca-mascara.png" -o "$T/fundos/marca-mascara.png"
sudo rm -rf /usr/share/wallpapers/CarinaeOS-* /usr/share/backgrounds/carinaeos
sudo python3 "$T/fundos/fundos.py" /
sudo install -m644 /usr/share/carinaeos/marca/grub.png /usr/share/carinaeos/grub.png

echo "== Sem papel de parede animado"
systemctl --user disable --now carinaeos-ceu-vivo.timer 2>/dev/null || true
sudo rm -rf /usr/share/plasma/wallpapers/org.carinaeos.vivo /usr/bin/carinaeos-ceu-vivo \
            /usr/lib/systemd/user/carinaeos-ceu-vivo.service /usr/lib/systemd/user/carinaeos-ceu-vivo.timer
rm -f "$HOME/.config/carinaeos/fundo-modo"

echo "== Restos das Rotinas (saíram no rc18)"
systemctl --user disable --now carinaeos-rotinas.timer 2>/dev/null || true
sudo rm -rf /usr/bin/carinaeos-rotinas /usr/share/carinaeos/rotinas /usr/share/carinaeos/comum/rotinas.py \
            /usr/share/applications/carinaeos-rotinas.desktop /etc/xdg/autostart/carinaeos-rotinas-entrar.desktop \
            /usr/lib/systemd/user/carinaeos-rotinas.service /usr/lib/systemd/user/carinaeos-rotinas.timer

echo "== Dock: 3 modelos"
D=carinae/tema/plasmoid/org.carinaeos.dock/contents/ui
for f in main.qml Tarefa.qml FundoIcone.qml Lancador.qml; do baixar "$D/$f" "/usr/share/plasma/plasmoids/org.carinaeos.dock/contents/ui/$f"; done
P=/usr/share/carinaeos/configuracoes/dock-estilos
sudo find "$P" -name '*.png' ! -name fluent.png ! -name icones.png -delete
baixar carinae-debian/sistema$P/simples.png "$P/simples.png"

echo "== Janelas de cor uniforme, sem transparência"
K=/usr/share/Kvantum/CarinaeOS/CarinaeOS.kvconfig
if [ -f "$K" ]; then
    sudo sed -i -E -e 's/^translucent_windows=.*/translucent_windows=false/' -e 's/^blurring=.*/blurring=false/' \
        -e 's/^popup_blurring=.*/popup_blurring=false/' -e 's/^blur_translucent=.*/blur_translucent=false/' \
        -e 's/^reduce_window_opacity=.*/reduce_window_opacity=0/' -e 's/^reduce_menu_opacity=.*/reduce_menu_opacity=0/' \
        -e 's/^comment=.*/comment=CarinaeOS: escuro, de cor uniforme e sem transparência (baseado no WhiteSur de Vince Liuice)/' "$K"
fi

echo "== Aplicativos (Configurações, Supernova, Central) e comandos"
S=carinae-debian/sistema
for f in usr/share/carinaeos/configuracoes/Main.qml usr/share/carinaeos/configuracoes/configuracoes.py \
         usr/share/carinaeos/supernova/mods.py usr/share/carinaeos/central/central.py; do
    baixar "$S/$f" "/$f"
done
for f in carinaeos-dock-estilo carinaeos-modo-leve carinaeos-fundo; do baixar "$S/usr/bin/$f" "/usr/bin/$f" 755; done
sudo find /usr/share/carinaeos -name __pycache__ -prune -exec rm -rf {} +

echo "== Arranque, entrada da sessão e GRUB"
L=carinae/tema/lookandfeel/org.carinaeos.desktop/contents
baixar "$L/splash/Splash.qml" /usr/share/plasma/look-and-feel/org.carinaeos.desktop/contents/splash/Splash.qml
baixar "$L/layouts/org.kde.plasma.desktop-layout.js" /usr/share/plasma/look-and-feel/org.carinaeos.desktop/contents/layouts/org.kde.plasma.desktop-layout.js
baixar carinae/tema/plymouth/carinaeos/carinaeos.script /usr/share/plymouth/themes/carinaeos/carinaeos.script
sudo rm -f /usr/share/plymouth/themes/carinaeos/brilho.png
# fundo da tela de entrada escolhido antes: volta ao padrão (o novo Ameixa)
sudo /usr/lib/carinaeos/fundo-entrada --repor 2>/dev/null || true
sudo update-grub 2>&1 | tail -1
echo "   (initramfs: demora um pouco)"
sudo update-initramfs -u 2>&1 | tail -1

echo "== A sua área de trabalho"
plasma-apply-wallpaperimage /usr/share/wallpapers/CarinaeOS >/dev/null 2>&1 || true
carinaeos-dock-estilo fluent >/dev/null
systemctl --user restart plasma-plasmashell
echo
echo "Pronto. Papel de parede: Ameixa. Dock: Padrão (com efeito)."
echo "Configurações › Dock tem os 3 modelos; Configurações › Aparência, os 4 papéis de parede."
echo "Launchpad: Editar › Cor do fundo (ou o botão de cores embaixo, à esquerda). Feche e abra os aplicativos para"
echo "verem as janelas sem transparência (ou saia e entre na sessão)."
