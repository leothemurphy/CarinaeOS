// CarinaeOS - Casa: o círculo colorido do ícone (como nos cartões Mushroom)
import QtQuick

Rectangle {
    id: f
    property string icone: ""          // o glifo da fonte Material Design Icons
    property string tinta: ""          // cor quando ativo; "" = desligado (cinzento)
    property int tamanho: 40
    property bool clicavel: false
    signal clicado()
    readonly property color cor: tinta !== "" ? tinta : "#6f6f6f"

    width: tamanho; height: tamanho; radius: tamanho / 2
    color: Qt.rgba(cor.r, cor.g, cor.b, tinta !== "" ? 0.2 : 0.18)
    Behavior on color { ColorAnimation { duration: 200 } }
    Text {
        anchors.centerIn: parent
        text: f.icone; font.family: "Material Design Icons"; font.pixelSize: Math.round(f.tamanho * 0.5)
        color: f.tinta !== "" ? f.tinta : "#9e9e9e"
        Behavior on color { ColorAnimation { duration: 200 } }
    }
    MouseArea { anchors.fill: parent; visible: f.clicavel; cursorShape: Qt.PointingHandCursor; onClicked: f.clicado() }
}
