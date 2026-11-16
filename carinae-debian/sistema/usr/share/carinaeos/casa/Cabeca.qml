// CarinaeOS - Casa: ícone + nome + estado, a linha de cima dos cartões Mushroom
import QtQuick

Item {
    id: h
    property string icone: ""
    property string tinta: ""
    property string primario: ""
    property string secundario: ""
    property bool formaClicavel: false
    signal clicouForma()
    implicitHeight: 40

    Forma { id: fo; icone: h.icone; tinta: h.tinta; clicavel: h.formaClicavel; onClicado: h.clicouForma() }
    Column {
        x: 52; width: parent.width - 52; anchors.verticalCenter: fo.verticalCenter
        Text { width: parent.width; elide: Text.ElideRight; text: h.primario; color: "#e1e1e1"; font.pixelSize: 14; font.weight: Font.DemiBold }
        Text { width: parent.width; elide: Text.ElideRight; text: h.secundario; color: "#9b9b9b"; font.pixelSize: 12; visible: text !== "" }
    }
}
