import QtQuick
import QtQuick.Controls

Rectangle {
    id: b
    property string icone: ""
    property string dica: ""
    property int tamanho: 34
    property bool destaque: false
    signal clicado()
    width: tamanho; height: tamanho; radius: tamanho / 2
    color: destaque ? (r.containsMouse ? "#ff8fa6" : "#ff6f91") : r.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
    Image { anchors.centerIn: parent; width: b.tamanho * 0.5; height: width; source: "image://icone/" + b.icone; sourceSize: Qt.size(48, 48) }
    MouseArea { id: r; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicado() }
    ToolTip.visible: r.containsMouse && b.dica !== ""; ToolTip.text: b.dica; ToolTip.delay: 400
}
