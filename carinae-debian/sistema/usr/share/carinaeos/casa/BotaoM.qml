// CarinaeOS - Casa: botão quadrado arredondado dos cartões Mushroom
import QtQuick

Rectangle {
    id: bt
    property string icone: ""
    property string texto: ""
    property string tinta: ""            // "" = neutro
    property bool ativo: true
    signal clicado()
    readonly property color cor: tinta !== "" ? tinta : "#ffffff"

    implicitWidth: texto !== "" ? linha.implicitWidth + 28 : 42
    implicitHeight: 42; radius: 12
    opacity: ativo ? 1 : 0.45
    color: tinta !== "" ? Qt.rgba(cor.r, cor.g, cor.b, m.pressed ? 0.35 : 0.2)
                        : Qt.rgba(1, 1, 1, m.pressed ? 0.14 : m.containsMouse ? 0.09 : 0.05)
    Row {
        id: linha
        anchors.centerIn: parent; spacing: 6
        Text { visible: bt.icone !== ""; text: bt.icone; font.family: "Material Design Icons"; font.pixelSize: 20
               color: bt.tinta !== "" ? bt.tinta : "#e1e1e1"; anchors.verticalCenter: parent.verticalCenter }
        Text { visible: bt.texto !== ""; text: bt.texto; color: "#e1e1e1"; font.pixelSize: 13; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
    }
    MouseArea { id: m; anchors.fill: parent; enabled: bt.ativo; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bt.clicado() }
}
