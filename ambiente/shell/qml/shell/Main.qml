/*
    CarinaeOS — o ambiente: um papel de parede por ecrã, a barra de cima e a Dock no ecrã principal.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Window
import QtQml.Models

QtObject {
    id: ambiente

    property var fundos: Instantiator {
        model: Qt.application.screens
        delegate: Fundo {
            required property var modelData
            ecra: modelData
        }
    }
    property var barra: Barra {}
    property var dock: JanelaDock {}
    property var avisos: Avisos {}
    property var desligar: Desligar {}
}
