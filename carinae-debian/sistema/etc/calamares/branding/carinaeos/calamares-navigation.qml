/* CarinaeOS — botões do instalador, como no Fedora: Seguinte (azul), Voltar e Cancelar, à esquerda. */
import io.calamares.ui 1.0
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.3

Rectangle {
    id: barra
    color: "#1b1a22"
    height: 64

    Rectangle { width: parent.width; height: 1; color: "#2c2836" }

    component Botao: Rectangle {
        id: b
        property string texto: ""
        property int tipo: 0          // 0 principal (azul), 1 secundário (contorno), 2 ligação
        signal carregado()
        implicitWidth: rt.implicitWidth + 36
        implicitHeight: 36
        radius: 4
        opacity: enabled ? 1 : 0.45
        color: tipo === 0 ? (m.pressed ? "#004080" : (m.containsMouse ? "#004c99" : "#0066cc")) : "transparent"
        border.width: tipo === 1 ? 1 : 0
        border.color: m.containsMouse ? "#73bcf7" : "#0066cc"
        Text {
            id: rt
            anchors.centerIn: parent
            text: b.texto
            color: b.tipo === 0 ? "white" : "#73bcf7"
            font.pixelSize: 14
            font.underline: b.tipo === 2 && m.containsMouse
        }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: if (b.enabled) b.carregado() }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 12

        Botao {
            texto: ViewManager.nextLabel.replace("&", "")
            tipo: 0
            enabled: ViewManager.nextEnabled
            visible: ViewManager.backAndNextVisible
            onCarregado: ViewManager.next()
        }
        Botao {
            texto: ViewManager.backLabel.replace("&", "")
            tipo: 1
            enabled: ViewManager.backEnabled
            visible: ViewManager.backAndNextVisible
            onCarregado: ViewManager.back()
        }
        Item { Layout.fillWidth: true }
        Botao {
            texto: ViewManager.quitLabel.replace("&", "")
            tipo: 2
            enabled: ViewManager.quitEnabled
            visible: ViewManager.quitVisible
            onCarregado: ViewManager.quit()
        }
    }
}
