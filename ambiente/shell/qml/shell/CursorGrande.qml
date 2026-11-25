/*
    CarinaeOS — "agitar para achar o cursor": quando se agita o rato, aparece por instantes
    uma seta grande por cima do cursor (Supernova › Agitar para achar o cursor).
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Window
import CarinaeOS.Base

Window {
    id: grande
    width: 220; height: 220
    flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowTransparentForInput | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: "CarinaeOS Cursor"
    visible: false

    function mostrar(px, py) {
        mover(px, py);
        crescer.restart();
        visible = true;
        Sistema.seguirCursor(1400);
        fim.restart();
    }
    function mover(px, py) { x = px - 18; y = py - 14; }

    Connections {
        target: Sistema
        function onCursorAgitado(px, py) { grande.mostrar(px, py) }
        function onCursorMoveu(px, py) { if (grande.visible) grande.mover(px, py) }
    }
    Timer { id: fim; interval: 1400; onTriggered: grande.visible = false }

    // a seta do rato, desenhada (branca com contorno escuro), a crescer e a voltar ao tamanho normal
    Item {
        id: seta
        width: 64; height: 64
        x: 14; y: 10
        transformOrigin: Item.TopLeft
        Canvas {
            anchors.fill: parent
            onPaint: {
                const c = getContext("2d");
                c.reset();
                c.beginPath();
                c.moveTo(4, 2); c.lineTo(4, 50); c.lineTo(16, 39); c.lineTo(25, 58); c.lineTo(33, 54);
                c.lineTo(24, 36); c.lineTo(40, 36); c.closePath();
                c.lineJoin = "round";
                c.lineWidth = 3; c.strokeStyle = "#1b1622"; c.fillStyle = "#ffffff";
                c.fill(); c.stroke();
            }
        }
        SequentialAnimation {
            id: crescer
            NumberAnimation { target: seta; property: "scale"; from: 0.4; to: 2.6; duration: 260; easing.type: Easing.OutBack }
            PauseAnimation { duration: 700 }
            NumberAnimation { target: seta; property: "scale"; to: 0.4; duration: 300; easing.type: Easing.InCubic }
        }
    }
}
