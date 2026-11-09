/*
    CarinaeOS — Dock: nome da app por cima do ícone (como no macOS)
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick

Rectangle {
    id: rotulo
    required property Item alvo
    required property string texto
    required property bool mostrar
    required property var dock

    parent: alvo.parent
    anchors.horizontalCenter: alvo.horizontalCenter
    y: alvo.y - height - dock.base * 0.18
    width: nome.implicitWidth + dock.base * 0.42
    height: nome.implicitHeight + dock.base * 0.16
    radius: height / 2
    color: Qt.rgba(0.10, 0.09, 0.14, 0.86)
    border.color: Qt.rgba(1, 1, 1, 0.14)
    border.width: 1
    opacity: mostrar && texto.length > 0 ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 120 } }
    z: 10

    Text {
        id: nome
        anchors.centerIn: parent
        text: rotulo.texto
        color: "white"
        font.pixelSize: Math.round(rotulo.dock.base * 0.27)
        font.weight: Font.Medium
    }
}
