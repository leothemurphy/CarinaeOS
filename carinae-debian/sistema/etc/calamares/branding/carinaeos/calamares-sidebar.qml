/* CarinaeOS — barra lateral do instalador, como o instalador do Fedora:
   cabeçalho com a estrela e a lista de passos numerados (feito ✓, atual em azul, por fazer em cinza). */
import io.calamares.ui 1.0
import io.calamares.core 1.0
import QtQuick 2.15
import QtQuick.Layouts 1.3

Rectangle {
    id: lado
    color: "#16141d"
    anchors.fill: parent

    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: "#2c2836" }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 4

        RowLayout {
            spacing: 10
            Layout.bottomMargin: 22
            Image {
                source: "file:/" + Branding.imagePath(Branding.ProductLogo)
                sourceSize.width: 34; sourceSize.height: 34
                Layout.preferredWidth: 34; Layout.preferredHeight: 34
            }
            Column {
                Text { text: Branding.string(Branding.ProductName); color: "#ffffff"; font.pixelSize: 16; font.weight: Font.DemiBold }
                Text { text: "Instalação"; color: "#a9a4b8"; font.pixelSize: 12 }
            }
        }

        Repeater {
            model: ViewManager
            delegate: Rectangle {
                Layout.fillWidth: true
                height: 40
                radius: 6
                readonly property bool atual: index === ViewManager.currentStepIndex
                readonly property bool feito: index < ViewManager.currentStepIndex
                color: atual ? "#24303f" : "transparent"
                Rectangle {   // barra azul do passo atual (como no PatternFly)
                    visible: parent.atual
                    width: 3; height: parent.height; radius: 1.5
                    color: "#73bcf7"
                }
                Rectangle {
                    id: bola
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 22; radius: 11
                    color: parent.atual ? "#0066cc" : (parent.feito ? "#3e8635" : "transparent")
                    border.width: parent.atual || parent.feito ? 0 : 1
                    border.color: "#6a6e73"
                    Text {
                        anchors.centerIn: parent
                        text: parent.parent.feito ? "✓" : String(index + 1)
                        color: parent.parent.atual || parent.parent.feito ? "white" : "#a9a4b8"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                    }
                }
                Text {
                    anchors.left: bola.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: display
                    color: parent.atual ? "#ffffff" : (parent.feito ? "#d2d2d2" : "#a9a4b8")
                    font.pixelSize: 14
                    font.weight: parent.atual ? Font.DemiBold : Font.Normal
                }
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "Precisa de ajuda? O Manual do CarinaeOS está na área de trabalho e no Launchpad."
            color: "#6f6a80"
            font.pixelSize: 11
        }
    }
}
