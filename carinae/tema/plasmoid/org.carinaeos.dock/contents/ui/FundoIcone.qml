/*
    CarinaeOS — Dock: o que fica por trás de cada ícone, conforme o estilo
      bolha    (Orbital)    — uma bolha de vidro redonda
      hex      (Hexagonal)  — um hexágono escuro com borda acesa
      tile     (Fluent)     — um quadrado suave que acende ao passar o rato
      circulo  (Colorida)   — um anel colorido no ícone debaixo do rato
    Desenha-se uma vez no tamanho do ícone ampliado e só muda de escala (leve).
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Shapes

Item {
    id: fundo
    required property var dock
    required property Item alvo          // o Item do ícone (x, y, width)
    property bool ativo: false           // o rato está neste ícone
    property bool aberto: false          // a app tem janelas abertas
    readonly property string tipo: dock.e.item || "nenhum"

    visible: tipo !== "nenhum"
    z: -1
    readonly property real lado: dock.base * (tipo === "bolha" ? 1.18 : tipo === "hex" ? 1.3 : 1.3)
    width: lado; height: lado
    x: alvo.x + alvo.width / 2 - width / 2
    y: alvo.y + alvo.height / 2 - height / 2
    scale: alvo.width / dock.base

    // ---- Orbital: bolha de vidro
    Rectangle {
        visible: fundo.tipo === "bolha"
        anchors.centerIn: parent
        width: parent.width; height: width; radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, fundo.ativo ? 0.34 : 0.24) }
            GradientStop { position: 0.55; color: Qt.rgba(0.75, 0.85, 1, 0.08) }
            GradientStop { position: 1.0; color: Qt.rgba(0.55, 0.75, 1, fundo.ativo ? 0.30 : 0.16) }
        }
        border.width: 1
        border.color: fundo.ativo ? Qt.rgba(1, 0.82, 0.55, 0.95) : Qt.rgba(1, 1, 1, 0.45)
        Rectangle {     // reflexo
            x: parent.width * 0.22; y: parent.height * 0.08
            width: parent.width * 0.42; height: parent.height * 0.2; radius: height / 2
            color: Qt.rgba(1, 1, 1, 0.28)
        }
    }

    // ---- Hexagonal
    Shape {
        visible: fundo.tipo === "hex"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: hp
            readonly property real w: fundo.width
            readonly property real h: fundo.height * 0.9
            readonly property real t: (fundo.height - h) / 2
            strokeWidth: 1.5
            strokeColor: fundo.ativo ? "#c9a6ff" : Qt.rgba(0.6, 0.45, 1, 0.55)
            fillGradient: LinearGradient {
                x1: 0; y1: 0; x2: 0; y2: fundo.height
                GradientStop { position: 0; color: Qt.rgba(0.13, 0.12, 0.20, 0.92) }
                GradientStop { position: 1; color: Qt.rgba(0.06, 0.05, 0.10, 0.92) }
            }
            startX: w * 0.25; startY: t
            PathLine { x: hp.w * 0.75; y: hp.t }
            PathLine { x: hp.w; y: hp.t + hp.h / 2 }
            PathLine { x: hp.w * 0.75; y: hp.t + hp.h }
            PathLine { x: hp.w * 0.25; y: hp.t + hp.h }
            PathLine { x: 0; y: hp.t + hp.h / 2 }
            PathLine { x: hp.w * 0.25; y: hp.t }
        }
    }

    // ---- Fluent: destaque suave
    Rectangle {
        visible: fundo.tipo === "tile"
        anchors.centerIn: parent
        width: parent.width * 0.96; height: width; radius: width * 0.24
        color: Qt.rgba(1, 1, 1, fundo.ativo ? 0.13 : fundo.aberto ? 0.05 : 0)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, fundo.ativo ? 0.16 : 0)
        Behavior on color { ColorAnimation { duration: 140 } }
    }

    // ---- Colorida: anel com as cores do CarinaeOS
    Rectangle {
        visible: fundo.tipo === "circulo"
        anchors.centerIn: parent
        width: parent.width * 0.98; height: width; radius: width / 2
        opacity: fundo.ativo ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        color: Qt.rgba(0.36, 0.30, 0.95, 0.22)
        border.width: 2
        border.color: "#a99bff"
        Rectangle {
            anchors.fill: parent; anchors.margins: -4; radius: width / 2
            color: "transparent"; border.width: 3; border.color: Qt.rgba(0.6, 0.5, 1, 0.25)
        }
    }
}
