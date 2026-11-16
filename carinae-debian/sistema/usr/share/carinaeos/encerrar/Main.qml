// CarinaeOS - Forçar o encerramento (Ctrl+Shift+Esc)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: janela
    width: 440; height: 520
    minimumWidth: 360; minimumHeight: 360
    visible: true
    title: "Forçar o encerramento"
    color: "#1e1d24"
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint      // fica por cima do aplicativo travado

    readonly property color texto: "#f2f0f6"
    readonly property color suave: "#a8a3b6"
    readonly property color perigo: "#ff6b81"
    property string escolhido: ""

    Shortcut { sequence: "Escape"; onActivated: Qt.quit() }
    Shortcut { sequences: ["Return", "Enter"]; onActivated: if (janela.escolhido !== "") encerrar.encerrar(janela.escolhido) }

    ColumnLayout {
        anchors.fill: parent; anchors.margins: 20; spacing: 12
        Text {
            Layout.fillWidth: true; wrapMode: Text.WordWrap; color: janela.suave; font.pixelSize: 13
            text: "Se um aplicativo não responder, escolha-o e force o encerramento. O que não estiver salvo nele será perdido."
        }
        Rectangle {
            Layout.fillWidth: true; Layout.fillHeight: true; radius: 12; color: "#2d2b35"; border.color: Qt.rgba(1, 1, 1, 0.07); clip: true
            ListView {
                id: lista
                anchors.fill: parent; anchors.margins: 6; spacing: 2
                model: encerrar.apps
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: janela.escolhido === modelData.chave
                    width: ListView.view.width; height: 48; radius: 8
                    color: sel ? Qt.rgba(1, 0.42, 0.5, 0.22) : ma.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    Image { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; sourceSize: Qt.size(56, 56)
                            source: "image://icone/" + (modelData.icone || "application-x-executable") }
                    Column {
                        x: 52; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 64
                        Text { width: parent.width; elide: Text.ElideRight; text: modelData.nome; color: janela.texto; font.pixelSize: 14 }
                        Text { width: parent.width; elide: Text.ElideRight; color: janela.suave; font.pixelSize: 11; visible: text !== ""
                               text: modelData.janelas.length > 1 ? modelData.janelas.length + " janelas" : (modelData.titulo !== modelData.nome ? modelData.titulo : "") }
                    }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: janela.escolhido = modelData.chave
                                onDoubleClicked: encerrar.encerrar(modelData.chave) }
                }
                Text { anchors.centerIn: parent; visible: lista.count === 0; text: "Nenhum aplicativo aberto"; color: janela.suave }
            }
        }
        Text { Layout.fillWidth: true; visible: encerrar.mensagem !== ""; text: encerrar.mensagem; color: janela.suave; font.pixelSize: 12; elide: Text.ElideRight }
        RowLayout {
            Layout.alignment: Qt.AlignRight; spacing: 8
            Rectangle {
                implicitWidth: t1.implicitWidth + 28; implicitHeight: 36; radius: 8; color: m1.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                Text { id: t1; anchors.centerIn: parent; text: "Fechar"; color: janela.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
                MouseArea { id: m1; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
            }
            Rectangle {
                readonly property bool pode: janela.escolhido !== "" && encerrar.apps.some(a => a.chave === janela.escolhido)
                implicitWidth: t2.implicitWidth + 28; implicitHeight: 36; radius: 8; opacity: pode ? 1 : 0.4
                color: m2.containsMouse && pode ? Qt.lighter(janela.perigo, 1.08) : janela.perigo
                Text { id: t2; anchors.centerIn: parent; text: "Forçar o encerramento"; color: "#2a0a12"; font.pixelSize: 13; font.weight: Font.DemiBold }
                MouseArea { id: m2; anchors.fill: parent; hoverEnabled: true; enabled: parent.pode; cursorShape: Qt.PointingHandCursor
                            onClicked: encerrar.encerrar(janela.escolhido) }
            }
        }
    }
}
