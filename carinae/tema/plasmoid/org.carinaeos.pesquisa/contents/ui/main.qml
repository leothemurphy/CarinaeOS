/*
    CarinaeOS — botão de pesquisa (lupa) na barra de cima.
    Abre a Pesquisa (carinaeos-comando), como o ícone de pesquisa do Windows.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: raiz
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: "Pesquisar"
    toolTipSubText: "Aplicativos, arquivos, ações e configurações (Ctrl+Espaço)"

    Layout.minimumWidth: Kirigami.Units.iconSizes.medium
    Layout.preferredWidth: Layout.minimumWidth
    Layout.fillHeight: true

    P5Support.DataSource {
        id: executar
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => disconnectSource(fonte)
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: Math.min(parent.height - 4, width)
        radius: height * 0.3
        color: Qt.rgba(1, 1, 1, rato.containsMouse ? 0.16 : 0)
        Behavior on color { ColorAnimation { duration: 120 } }
    }
    Kirigami.Icon {
        anchors.centerIn: parent
        source: "search"
        isMask: true
        color: "white"
        width: Math.round(Math.min(parent.width, parent.height) * 0.62)
        height: width
    }
    MouseArea {
        id: rato
        anchors.fill: parent
        hoverEnabled: true
        onClicked: executar.connectSource("carinaeos-comando")
    }
}
