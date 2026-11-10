// CarinaeOS - Eta: a esfera que respira (a pensar) e pulsa com a voz (a ouvir)
import QtQuick

Item {
    id: orbe
    property bool ativo: false
    property real nivel: 0          // 0..1: volume do microfone
    property real fase: 0
    NumberAnimation on fase { from: 0; to: Math.PI * 2; duration: 2600; loops: Animation.Infinite; running: orbe.ativo }

    // aneis de luz
    Repeater {
        model: 3
        Rectangle {
            required property int index
            anchors.centerIn: parent
            width: orbe.width * (1 + (orbe.ativo ? 0.18 + 0.12 * Math.sin(orbe.fase + index * 2.1) + orbe.nivel * 0.5 : 0))
            height: width; radius: width / 2
            color: "transparent"
            border.width: 2
            border.color: index === 0 ? "#ff6f91" : index === 1 ? "#ffb46e" : "#b38cff"
            opacity: orbe.ativo ? 0.35 - index * 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
    }
    Rectangle {
        anchors.centerIn: parent
        width: orbe.width * (1 + orbe.nivel * 0.18); height: width; radius: width / 2
        gradient: Gradient {
            GradientStop { position: 0; color: "#ff8fa6" }
            GradientStop { position: 1; color: "#7a3ccf" }
        }
        Behavior on width { NumberAnimation { duration: 80 } }
        Image {
            anchors.centerIn: parent
            width: parent.width * 0.62; height: width
            source: "image://icone/carinaeos-estrela"; sourceSize: Qt.size(96, 96)
            rotation: orbe.ativo ? orbe.fase * 57.3 / 4 : 0
        }
    }
}
