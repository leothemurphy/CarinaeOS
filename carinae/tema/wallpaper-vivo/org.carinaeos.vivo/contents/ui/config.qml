import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

ColumnLayout {
    id: raiz
    property int cfg_Variante: 1
    spacing: 12
    QQC2.Label { text: "Escolha a cena (em movimento):" }
    RowLayout {
        spacing: 16
        Repeater {
            model: [1, 2]
            delegate: ColumnLayout {
                required property int modelData
                Rectangle {
                    implicitWidth: 220; implicitHeight: 124; radius: 8
                    color: "transparent"
                    border.width: raiz.cfg_Variante === parent.modelData ? 3 : 1
                    border.color: raiz.cfg_Variante === parent.modelData ? "#7aa7ff" : "#555"
                    Image {
                        anchors.fill: parent; anchors.margins: 3
                        source: "file:///usr/share/wallpapers/CarinaeOS-NebulosaSobreOLago" + (parent.parent.modelData === 1 ? "" : "2") + "/contents/screenshot.jpg"
                        fillMode: Image.PreserveAspectCrop
                    }
                    MouseArea { anchors.fill: parent; onClicked: raiz.cfg_Variante = parent.parent.modelData }
                }
                QQC2.Label { Layout.alignment: Qt.AlignHCenter; text: modelData === 1 ? "Nebulosa sobre o lago" : "Nebulosa sobre o lago II" }
            }
        }
    }
}
