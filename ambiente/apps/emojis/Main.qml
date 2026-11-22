// CarinaeOS — Carinae Emojis (o painel Win+. do Windows 11)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: janela
    width: 380; height: 460
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "Carinae Emojis"
    font.family: "Inter"; font.pixelSize: 13
    palette.window: "#2b2a32"; palette.windowText: "#f2f0f6"; palette.base: "#24232a"; palette.text: "#f2f0f6"
    palette.button: "#3a3942"; palette.buttonText: "#f2f0f6"; palette.highlight: "#7aa7ff"; palette.highlightedText: "#10131c"
    palette.toolTipBase: "#2f2e37"; palette.toolTipText: "#f2f0f6"; palette.placeholderText: "#8a8597"

    readonly property color texto: "#f2f0f6"
    readonly property color suave: "#a8a3b6"
    readonly property color realce: "#7aa7ff"
    readonly property string fonteEmoji: "Noto Color Emoji"
    property bool jaAtiva: false
    property string sobre: ""

    Component.onCompleted: {
        const p = emojis.posicao();
        x = p[0]; y = p[1];
        requestActivate();
        busca.forceActiveFocus();
    }
    // como o painel do Windows: fecha ao clicar fora
    onActiveChanged: { if (active) jaAtiva = true; else if (jaAtiva) Qt.quit(); }

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: "#24232b"
        border.color: Qt.rgba(1, 1, 1, 0.1)

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 10; spacing: 8

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                MouseArea { Layout.preferredWidth: 22; Layout.preferredHeight: 30; onPressed: janela.startSystemMove()
                            Text { anchors.centerIn: parent; text: "⋮⋮"; color: janela.suave; font.pixelSize: 11 } }
                Text { text: "Emojis"; color: janela.texto; font.weight: Font.DemiBold; font.pixelSize: 15; Layout.fillWidth: true }
                // tom de pele
                Rectangle {
                    Layout.preferredWidth: 34; Layout.preferredHeight: 30; radius: 6
                    color: mtom.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    Text { anchors.centerIn: parent; text: emojis.tons[emojis.tom]; font.family: janela.fonteEmoji; font.pixelSize: 18 }
                    MouseArea { id: mtom; anchors.fill: parent; hoverEnabled: true; onClicked: escolhaTom.visible = !escolhaTom.visible }
                    ToolTip.visible: mtom.containsMouse; ToolTip.text: "Tom de pele"; ToolTip.delay: 500
                }
                Rectangle {
                    Layout.preferredWidth: 30; Layout.preferredHeight: 30; radius: 6
                    color: mfe.containsMouse ? "#c42b1c" : "transparent"
                    Text { anchors.centerIn: parent; text: "✕"; color: janela.texto }
                    MouseArea { id: mfe; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() }
                }
            }
            Row {
                id: escolhaTom
                visible: false
                Layout.alignment: Qt.AlignRight
                spacing: 2
                Repeater {
                    model: emojis.tons
                    Rectangle {
                        width: 34; height: 32; radius: 6
                        color: index === emojis.tom ? Qt.rgba(0.48, 0.65, 1, 0.3) : (mt.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
                        Text { anchors.centerIn: parent; text: modelData; font.family: janela.fonteEmoji; font.pixelSize: 18 }
                        MouseArea { id: mt; anchors.fill: parent; hoverEnabled: true; onClicked: { emojis.definirTom(index); escolhaTom.visible = false; } }
                    }
                }
            }

            // pesquisa (escrever logo procura)
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 8
                color: Qt.rgba(1, 1, 1, 0.06); border.color: busca.activeFocus ? janela.realce : Qt.rgba(1, 1, 1, 0.08)
                Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: janela.suave; font.pixelSize: 16 }
                TextField {
                    id: busca
                    anchors.fill: parent; leftPadding: 30
                    placeholderText: "Procurar (ex.: coração, gato, festa)"
                    color: janela.texto; background: null
                    onTextChanged: { emojis.procurar(text); grade.currentIndex = 0; janela.sobre = ""; }
                    Keys.onPressed: (ev) => {
                        if (ev.key === Qt.Key_Escape) { Qt.quit(); ev.accepted = true; }
                        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { if (grade.count) janela.escolher(grade.currentIndex, ev.modifiers & Qt.ShiftModifier); ev.accepted = true; }
                        else if (ev.key === Qt.Key_Down) { grade.moveCurrentIndexDown(); ev.accepted = true; }
                        else if (ev.key === Qt.Key_Up) { grade.moveCurrentIndexUp(); ev.accepted = true; }
                        else if (ev.key === Qt.Key_Right && busca.cursorPosition === busca.length) { grade.moveCurrentIndexRight(); ev.accepted = true; }
                        else if (ev.key === Qt.Key_Left && busca.cursorPosition === 0) { grade.moveCurrentIndexLeft(); ev.accepted = true; }
                    }
                }
            }

            // categorias
            RowLayout {
                Layout.fillWidth: true; spacing: 0
                visible: busca.text === ""
                Repeater {
                    model: emojis.grupos
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 34; radius: 6
                        readonly property bool ativo: emojis.grupo === modelData.id
                        color: ativo ? Qt.rgba(1, 1, 1, 0.09) : (mg.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        Text { anchors.centerIn: parent; text: modelData.icone; font.family: janela.fonteEmoji; font.pixelSize: 17; opacity: parent.ativo ? 1 : 0.75 }
                        Rectangle { visible: parent.ativo; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: 14; height: 3; radius: 2; color: janela.realce }
                        MouseArea { id: mg; anchors.fill: parent; hoverEnabled: true; onClicked: { emojis.escolherGrupo(modelData.id); grade.positionViewAtBeginning(); } }
                        ToolTip.visible: mg.containsMouse; ToolTip.text: modelData.nome; ToolTip.delay: 400
                    }
                }
            }

            GridView {
                id: grade
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / 8); cellHeight: 42
                model: emojis.lista
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                highlight: Rectangle { radius: 8; color: Qt.rgba(0.48, 0.65, 1, 0.22) }
                highlightMoveDuration: 0
                keyNavigationEnabled: true
                delegate: Item {
                    width: grade.cellWidth; height: grade.cellHeight
                    Rectangle { anchors.fill: parent; anchors.margins: 2; radius: 8; color: me.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent" }
                    Text { anchors.centerIn: parent; text: modelData.e; font.family: janela.fonteEmoji; font.pixelSize: 24 }
                    MouseArea {
                        id: me; anchors.fill: parent; hoverEnabled: true
                        onEntered: janela.sobre = modelData.nome
                        onClicked: (ev) => janela.escolher(index, ev.modifiers & Qt.ShiftModifier)
                    }
                }
                Text {
                    anchors.centerIn: parent; visible: grade.count === 0; color: janela.suave; horizontalAlignment: Text.AlignHCenter
                    text: busca.text ? "Nenhum emoji com \"" + busca.text + "\"" : "Os emojis que usar aparecem aqui."
                }
            }
            Text {
                Layout.fillWidth: true; elide: Text.ElideRight; color: janela.suave; font.pixelSize: 12
                text: janela.sobre || (grade.currentItem && grade.count ? emojis.lista[grade.currentIndex].nome : "") || "Shift+clique escreve vários seguidos"
            }
        }
    }

    function escolher(i, ficar) {
        const l = emojis.lista;
        if (i < 0 || i >= l.length) return;
        emojis.escolher(l[i].e, !!ficar);
    }
}
