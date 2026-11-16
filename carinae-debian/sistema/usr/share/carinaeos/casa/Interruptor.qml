// CarinaeOS - Casa: o interruptor do Home Assistant
import QtQuick

Item {
    id: s
    property bool ligado: false
    property bool ativo: true
    signal alternado()
    implicitWidth: 40; implicitHeight: 24
    opacity: ativo ? 1 : 0.5
    Rectangle {
        anchors.centerIn: parent; width: 34; height: 14; radius: 7
        color: s.ligado ? Qt.rgba(0.012, 0.663, 0.957, 0.5) : Qt.rgba(1, 1, 1, 0.3)
    }
    Rectangle {
        width: 20; height: 20; radius: 10; anchors.verticalCenter: parent.verticalCenter
        x: s.ligado ? parent.width - width : 0
        color: s.ligado ? "#03a9f4" : "#bdbdbd"
        Behavior on x { NumberAnimation { duration: 140 } }
    }
    MouseArea { anchors.fill: parent; anchors.margins: -6; enabled: s.ativo; cursorShape: Qt.PointingHandCursor; onClicked: s.alternado() }
}
