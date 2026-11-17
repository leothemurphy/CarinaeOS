/*
    CarinaeOS — Dock: o quadrado suave por trás de cada ícone, que acende ao passar o mouse
    (nos três modelos). No modelo "Só ícones" (sem fundo) o quadrado é de vidro escuro,
    para se ver também sobre papéis de parede claros.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick

Item {
    id: fundo
    required property var dock
    required property Item alvo          // o Item do ícone (x, y, width)
    property bool ativo: false           // o mouse está neste ícone
    property bool aberto: false          // a app tem janelas abertas
    readonly property bool semFundo: dock.e.fundo === "nenhum"

    visible: dock.e.item === "tile"
    z: -1
    width: dock.base * 1.12; height: width
    x: alvo.x + alvo.width / 2 - width / 2
    y: alvo.y + alvo.height / 2 - height / 2

    Rectangle {
        anchors.fill: parent
        radius: width * 0.24
        color: fundo.semFundo ? Qt.rgba(0.08, 0.08, 0.11, fundo.ativo ? 0.55 : 0)
                              : Qt.rgba(1, 1, 1, fundo.ativo ? 0.15 : fundo.aberto ? 0.05 : 0)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, fundo.ativo ? (fundo.semFundo ? 0.30 : 0.18) : 0)
    }
}
