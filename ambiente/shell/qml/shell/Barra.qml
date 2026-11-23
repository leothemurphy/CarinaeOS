/*
    CarinaeOS — a barra de cima: estrela (o menu estrela de sempre), o nome da app ativa e, à direita,
    a bandeja (apps em segundo plano), o Pulsar, o volume, a central de ajustes e o relógio (calendário).
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import CarinaeOS.Base
import CarinaeOS.Compat as C
import "../barra"

Window {
    id: barra

    readonly property var ecra: Qt.application.screens[Sistema.indicePrincipal]
    readonly property int altura: 30

    screen: ecra
    flags: Qt.FramelessWindowHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: "CarinaeOS Barra"
    x: ecra ? ecra.virtualX : 0
    y: ecra ? ecra.virtualY : 0
    width: ecra ? ecra.width : 800
    height: altura

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 12
        spacing: 12

        MenuEstrela {
            Layout.fillHeight: true
        }
        Text {
            text: Sistema.nomeAppAtiva !== "" ? Sistema.nomeAppAtiva : "CarinaeOS"
            color: "#f6f2ff"
            font.pixelSize: 13
            font.weight: Font.DemiBold
            Layout.maximumWidth: barra.width * 0.3
            elide: Text.ElideRight
        }
        Text {
            text: Sistema.tituloAtivo
            visible: text !== "" && text !== Sistema.nomeAppAtiva
            color: Qt.rgba(0.93, 0.9, 1, 0.55)
            font.pixelSize: 12
            elide: Text.ElideRight
            Layout.fillWidth: true
            Layout.maximumWidth: barra.width * 0.35
        }
        Item { Layout.fillWidth: true }

        IconesBandeja { Layout.fillHeight: true }
        Pulsar { Layout.fillHeight: true }
        Volume { Layout.fillHeight: true }
        Central { Layout.fillHeight: true }
        Relogio { Layout.fillHeight: true }
    }

    Timer { id: reservar; interval: 60; onTriggered: Sistema.reservar(barra, 1, barra.height) }
    onWidthChanged: reservar.restart()
    onXChanged: reservar.restart()

    Component.onCompleted: {
        Sistema.tornarPainel(barra, 1, altura);
        visible = true;
    }
}
