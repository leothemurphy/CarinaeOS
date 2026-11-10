// CarinaeOS - Manual do sistema
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: janela
    width: 1100; height: 760
    minimumWidth: 760; minimumHeight: 500
    visible: true
    title: "Manual do CarinaeOS"
    color: "#0f0c18"
    font.family: "Inter"; font.pixelSize: 14
    readonly property color texto: "#f2ecfa"
    readonly property color suave: "#b9b0cc"
    readonly property color ambar: "#ffb46e"
    property var achados: []

    Rectangle {
        id: lado
        width: 290; height: parent.height
        color: Qt.rgba(1, 1, 1, 0.04)
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.07) }
        Column {
            id: topo
            x: 14; y: 18; width: parent.width - 28; spacing: 12
            Row {
                spacing: 10; leftPadding: 4
                Image { source: "image://icone/carinaeos"; width: 36; height: 36; sourceSize: Qt.size(72, 72) }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Manual"; color: janela.texto; font.pixelSize: 18; font.weight: Font.Bold }
                    Text { text: "CarinaeOS"; color: janela.suave; font.pixelSize: 12 }
                }
            }
            TextField {
                id: procura
                width: parent.width; placeholderText: "Procurar no manual…"
                onTextChanged: janela.achados = text.length >= 2 ? manual.procurar(text) : []
            }
        }
        ListView {
            anchors.top: topo.bottom; anchors.topMargin: 12; anchors.bottom: perguntar.top; anchors.bottomMargin: 10
            x: 10; width: parent.width - 20; clip: true; spacing: 2
            model: procura.text.length >= 2 ? janela.achados : manual.capitulos
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool busca: procura.text.length >= 2
                width: ListView.view.width; radius: 8
                height: busca ? 54 : 36
                color: (!busca && manual.atual === index) ? Qt.rgba(1, 0.62, 0.45, 0.24) : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                Column {
                    x: 10; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 20
                    Text { width: parent.width; elide: Text.ElideRight; color: janela.texto; font.pixelSize: 13
                           text: busca ? modelData.secao : modelData.titulo }
                    Text { visible: busca; width: parent.width; elide: Text.ElideRight; color: janela.suave; font.pixelSize: 11
                           text: busca ? modelData.linha : "" }
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: manual.abrir(busca ? modelData.cap : index) }
            }
            ScrollBar.vertical: ScrollBar {}
        }
        Rectangle {
            id: perguntar
            anchors.bottom: parent.bottom; anchors.bottomMargin: 16; x: 14
            width: parent.width - 28; height: 40; radius: 20
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "#ff6f91" } GradientStop { position: 1; color: janela.ambar } }
            Text { anchors.centerIn: parent; text: "✦ Perguntar à Eta"; color: "#1a0f14"; font.weight: Font.Bold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: manual.perguntarEta(procura.text) }
        }
    }

    ScrollView {
        id: rolar
        x: lado.width; width: parent.width - lado.width; height: parent.height
        contentWidth: availableWidth; clip: true
        Connections { target: manual; function onMudou() { rolar.ScrollBar.vertical.position = 0 } }
        TextEdit {
            width: rolar.availableWidth
            leftPadding: 40; rightPadding: 40; topPadding: 30; bottomPadding: 40
            readOnly: true; selectByMouse: true; wrapMode: Text.Wrap
            textFormat: manual.html !== "" ? TextEdit.RichText : TextEdit.MarkdownText
            text: manual.html !== "" ? manual.html : manual.texto
            color: janela.texto; selectionColor: "#7a4f9c"
            font.pixelSize: 15
            onLinkActivated: (url) => manual.seguirLigacao(url)
            HoverHandler { cursorShape: parent.hoveredLink ? Qt.PointingHandCursor : Qt.IBeamCursor }
        }
    }
}
