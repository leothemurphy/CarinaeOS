import QtQuick

Rectangle {
    id: p
    property string texto: ""
    property int altura: 30
    signal clicado()
    width: t.implicitWidth + 24; height: altura; radius: altura / 2
    color: r.containsMouse ? Qt.rgba(1, 0.7, 0.43, 0.3) : Qt.rgba(1, 1, 1, 0.08)
    border.color: Qt.rgba(1, 0.7, 0.43, 0.4)
    Text { id: t; anchors.centerIn: parent; text: p.texto; color: "#f4eee8"; font.pixelSize: 12; font.weight: Font.DemiBold }
    MouseArea { id: r; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: p.clicado() }
}
