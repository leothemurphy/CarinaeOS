// Portado do Plasma pelo portar-do-plasma.py (CarinaeOS). Original: /home/claude/orig/plasmoids/org.carinaeos.dock/contents/ui/Rotulo.qml
/*
    CarinaeOS — Dock: nome da app por cima do ícone (como no macOS)
    É uma janelinha à parte (não ocupa espaço na Dock): assim o painel só tem a altura
    dos ícones e a zona por cima deles deixa passar os cliques para as janelas.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import CarinaeOS.Compat as PlasmaCore

Item {
    id: rotulo
    required property Item alvo
    required property string texto
    required property bool mostrar
    required property var dock

    // atraso curto: não pisca ao passar o rato de um ícone para o outro
    property bool pronto: false
    Timer { id: espera; interval: 90; onTriggered: rotulo.pronto = rotulo.mostrar }
    onMostrarChanged: { if (mostrar) espera.restart(); else pronto = false }

    PlasmaCore.Dialog {
        id: janela
        visualParent: rotulo.alvo
        location: rotulo.dock.localizacao
        type: PlasmaCore.Dialog.Tooltip
        flags: Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: false
        outputOnly: true
        visible: rotulo.pronto && rotulo.texto.length > 0

        mainItem: Rectangle {
            width: nome.implicitWidth + rotulo.dock.base * 0.42
            height: nome.implicitHeight + rotulo.dock.base * 0.16
            radius: rotulo.dock.win ? 6 : height / 2
            color: rotulo.dock.win ? Qt.rgba(0.17, 0.17, 0.17, 0.96) : Qt.rgba(0.10, 0.09, 0.14, 0.92)
            border.color: Qt.rgba(1, 1, 1, 0.14)
            border.width: 1

            Text {
                id: nome
                anchors.centerIn: parent
                text: rotulo.texto
                color: "white"
                font.pixelSize: rotulo.dock.win ? 12 : Math.round(rotulo.dock.base * 0.27)
                font.weight: Font.Medium
            }
        }
    }
}
