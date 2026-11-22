/*
    CarinaeOS — a janela que segura a Dock (o mesmo Dock.qml que corria no Plasma),
    em baixo e ao centro do ecrã principal. Reserva a altura do vidro para as janelas não a taparem.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Window
import CarinaeOS.Base
import "../dock"

Window {
    id: janela

    readonly property var ecra: Qt.application.screens[Sistema.indicePrincipal]

    screen: ecra
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: "CarinaeOS Dock"
    // no modelo Windows 11 a barra ocupa a largura toda do ecrã
    width: dock.win && ecra ? ecra.width : Math.max(100, Math.ceil(dock.comprimento))
    height: Math.max(20, dock.alturaVidro)
    x: ecra ? ecra.virtualX + Math.round((ecra.width - width) / 2) : 0
    y: ecra ? ecra.virtualY + ecra.height - height : 0

    Dock {
        id: dock
        anchors.fill: parent
    }

    // Super+1..9 (vem do carinae-wm)
    Connections {
        target: Sistema
        function onAtivarTarefa(n) { dock.modelo.requestActivateByPosition(n); }
    }

    Timer { id: reservar; interval: 60; onTriggered: Sistema.reservar(janela, 2, janela.height) }
    onXChanged: reservar.restart()
    onYChanged: reservar.restart()
    onWidthChanged: reservar.restart()
    onHeightChanged: reservar.restart()

    Component.onCompleted: {
        Sistema.tornarPainel(janela, 2, height);
        visible = true;
    }
}
