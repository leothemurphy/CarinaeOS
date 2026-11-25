/*
    CarinaeOS — o ambiente: um papel de parede por ecrã, a barra de cima e a Dock no ecrã principal.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Window
import QtQml.Models
import CarinaeOS.Base

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
    property var alternar: Alternar {}
    property var cursorGrande: CursorGrande {}

    // o canto superior esquerdo (Supernova › Canto superior esquerdo)
    property var canto: Connections {
        target: Sistema
        function onCantoAtivado() {
            const a = (Sistema.shell || {}).canto || "";
            if (a === "visao" || a === "janelas") ambiente.alternar.abrirVisao();
            else if (a === "mesa") Sistema.alternarMesa();
            else if (a === "bloquear") Sistema.executar("carinae-sessao bloquear");
            else if (a === "lancador") Sistema.executar("aurora --enviar lancador");
        }
    }
}
