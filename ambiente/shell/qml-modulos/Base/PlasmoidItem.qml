// CarinaeOS — PlasmoidItem: o item de topo da Dock/barra (aqui é só um Item)
// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

Item {
    property var fullRepresentation: null
    property var compactRepresentation: null
    property var preferredRepresentation: null
    property string toolTipMainText
    property string toolTipSubText
    property bool expanded: false
    property bool hideOnWindowDeactivate: true
}
