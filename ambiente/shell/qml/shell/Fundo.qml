/*
    CarinaeOS — papel de parede de um ecrã (janela do tipo "desktop", fica atrás de tudo).
    O papel vem de ~/.config/carinaeos-shell.json: "papel" no ecrã principal, "papel2" nos outros.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Window
import CarinaeOS.Base
import CarinaeOS.Compat as C

Window {
    id: fundo

    property var ecra
    readonly property bool principal: ecra && ecra.name === Sistema.nomePrincipal
    readonly property string papel: {
        const s = Sistema.shell || {};
        let p = principal ? (s.papel || "") : (s.papel2 || s.papel || "");
        if (p === "") {     // sem papel escolhido: o padrão do CarinaeOS, no tamanho mais próximo do ecrã
            const w = ecra ? ecra.width * (ecra.devicePixelRatio || 1) : 1920;
            const t = w > 5120 ? "7680x4320" : w > 3840 ? "5120x2880" : w > 2560 ? "3840x2160"
                    : w > 1920 ? "2560x1440" : w > 1366 ? "1920x1080" : "1366x768";
            p = "/usr/share/wallpapers/CarinaeOS-Fusao/contents/images/" + t + ".jpg";
        }
        return p.startsWith("/") ? "file://" + p : p;
    }

    screen: ecra
    x: ecra ? ecra.virtualX : 0
    y: ecra ? ecra.virtualY : 0
    width: ecra ? ecra.width : 800
    height: ecra ? ecra.height : 600
    flags: Qt.FramelessWindowHint
    color: "#0e0d12"
    title: "Área de trabalho"

    // sem papel: um degradê escuro com as cores do CarinaeOS
    Rectangle {
        anchors.fill: parent
        visible: imagem.status !== Image.Ready
        gradient: Gradient {
            GradientStop { position: 0; color: "#1b1433" }
            GradientStop { position: 0.6; color: "#120f1c" }
            GradientStop { position: 1; color: "#2a1520" }
        }
    }
    Image {
        id: imagem
        anchors.fill: parent
        source: fundo.papel
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(fundo.width, fundo.height)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (rato) => {
            if (rato.button === Qt.RightButton) menu.open(rato.x, rato.y)
            // Supernova › "Clicar no papel de parede": esconder (ou voltar a mostrar) as janelas
            else if ((Sistema.shell || {}).cliqueMesa === "esconder") Sistema.alternarMesa()
        }
    }
    C.Menu {
        id: menu
        visualParent: fundo.contentItem
        C.MenuItem { text: "Mudar o papel de parede…"; icon: "preferences-desktop-wallpaper"; onClicked: Sistema.executar("command -v carinaeos-supernova >/dev/null && exec carinaeos-supernova || exec carinaeos-configuracoes aparencia") }
        C.MenuItem { text: "Telas…"; icon: "preferences-desktop-display"; onClicked: Sistema.executar("carinae-telas") }
        C.MenuItem { text: "Abrir o terminal aqui"; icon: "utilities-terminal"; onClicked: Sistema.executar("cd \"$HOME/Área de trabalho\" 2>/dev/null; x-terminal-emulator") }
        C.MenuItem { text: "Configurações…"; icon: "preferences-system"; onClicked: Sistema.executar("carinaeos-configuracoes") }
        C.MenuItem { separator: true }
        C.MenuItem { text: "Recarregar o ambiente"; icon: "view-refresh"; onClicked: Sistema.executar("carinae-shell --enviar recarregar") }
    }

    Component.onCompleted: {
        Sistema.tornarFundo(fundo);
        visible = true;
    }
}
