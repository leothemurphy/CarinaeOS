// CarinaeOS — Terminal Carinae: aparência
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: janela
    width: 1000; height: 640
    minimumWidth: 860; minimumHeight: 560
    visible: true
    title: "Aparência do Terminal"
    color: "#0c0a14"
    font.family: "Inter"; font.pixelSize: 14

    readonly property color ambar: "#ffb46e"
    readonly property color texto: "#f6f2ff"
    readonly property color suave: "#b9b0cc"
    readonly property color cartao: Qt.rgba(1, 1, 1, 0.05)
    readonly property var c: aparencia.config
    readonly property var tema: { for (var i = 0; i < aparencia.temas.length; i++) if (aparencia.temas[i].id === c.tema) return aparencia.temas[i]; return aparencia.temas[0] }
    property bool aplicado: false
    property bool editando: false       // as opções só aparecem depois de carregar em "Modificar"
    Connections { target: aparencia; function onMudou() { janela.aplicado = false } }

    function cor(i, forte) { return (forte ? tema.fortes : tema.cores)[i] }
    function span(t, cor, negrito) { return "<span style='color:" + cor + (negrito ? ";font-weight:bold" : "") + "'>" + t + "</span>" }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

        // ---- pré-visualização --------------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14
            RowLayout {
                Image { source: "image://icone/carinaeos-terminal"; sourceSize: Qt.size(44, 44); Layout.preferredWidth: 44; Layout.preferredHeight: 44 }
                Column {
                    Text { text: "Terminal Carinae"; color: janela.texto; font.pixelSize: 24; font.weight: Font.Bold }
                    Text { text: "Escolha as cores, a fonte e a transparência"; color: janela.suave; font.pixelSize: 13 }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                clip: true
                color: "#201a33"
                Image {
                    anchors.fill: parent
                    source: "file:///usr/share/backgrounds/carinaeos/eta-carinae.jpg"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
                Rectangle {      // a janela do terminal
                    anchors.fill: parent
                    anchors.margins: 26
                    radius: 10
                    color: Qt.rgba(0, 0, 0, 0)
                    border.color: Qt.rgba(1, 1, 1, 0.12)
                    clip: true
                    Rectangle {
                        anchors.fill: parent
                        radius: 10
                        color: janela.tema.fundo
                        opacity: janela.c.opacidade / 100
                    }
                    Rectangle {   // barra de título da Gravidade
                        id: titulo
                        width: parent.width; height: 32
                        color: Qt.rgba(0.08, 0.07, 0.12, 0.95)
                        radius: 10
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 10; color: parent.color }
                        Row {
                            x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 7
                            Rectangle { width: 12; height: 12; radius: 6; color: "#ff5f57" }
                            Rectangle { width: 12; height: 12; radius: 6; color: "#febc2e" }
                            Rectangle { width: 12; height: 12; radius: 6; color: "#28c840" }
                        }
                        Text { anchors.centerIn: parent; text: "leo : bash — Terminal Carinae"; color: janela.suave; font.pixelSize: 12 }
                    }
                    Column {
                    anchors.top: titulo.bottom
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.margins: janela.c.margem
                    Text {
                        id: amostra
                        textFormat: Text.RichText
                        wrapMode: Text.NoWrap
                        color: janela.tema.texto
                        font.family: janela.c.fonte
                        font.pixelSize: Math.round(janela.c.tamanho * 1.33)
                        lineHeight: 1.15
                        readonly property string pr: janela.span("leo@carinaeos", janela.cor(2, true), true) + ":" + janela.span("~", janela.cor(4, true), true) + "$ "
                        text: pr + "ls<br>"
                            + janela.span("Documentos", janela.cor(4, true), true) + "&nbsp;&nbsp;" + janela.span("Imagens", janela.cor(4, true), true) + "&nbsp;&nbsp;"
                            + "notas.txt&nbsp;&nbsp;" + janela.span("instalar.sh", janela.cor(2, true), true) + "&nbsp;&nbsp;" + janela.span("foto.png", janela.cor(5)) + "<br>"
                            + pr + "git status<br>"
                            + "No ramo " + janela.span("main", janela.cor(6)) + "<br>"
                            + "&nbsp;&nbsp;" + janela.span("modificado:&nbsp;&nbsp;&nbsp;README.md", janela.cor(1)) + "<br>"
                            + "&nbsp;&nbsp;" + janela.span("novo:&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;estrela.svg", janela.cor(2)) + "<br>"
                            + pr + "echo " + janela.span("\"olá, universo\"", janela.cor(3)) + "<br>"
                            + "olá, universo<br>"
                            + [0, 1, 2, 3, 4, 5, 6, 7].map(function (i) { return janela.span("██", janela.cor(i)) }).join("") + "<br>"
                            + [0, 1, 2, 3, 4, 5, 6, 7].map(function (i) { return janela.span("██", janela.cor(i, true)) }).join("")
                    }
                    Row {
                        Text {
                            textFormat: Text.RichText
                            color: janela.tema.texto
                            font: amostra.font
                            text: amostra.pr
                        }
                        Item {
                            width: amostra.font.pixelSize * 0.6
                            height: amostra.font.pixelSize * 1.2
                            Rectangle {      // o cursor, a piscar
                                anchors.bottom: parent.bottom
                                width: janela.c.cursor === "barra" ? 2 : parent.width
                                height: janela.c.cursor === "sublinhado" ? 3 : parent.height
                                color: janela.tema.cursor
                                SequentialAnimation on opacity { loops: Animation.Infinite; NumberAnimation { to: 0; duration: 520 } NumberAnimation { to: 1; duration: 520 } }
                            }
                        }
                    }
                    }
                }
            }
        }

        // ---- opções --------------------------------------------------------------------------------
        ColumnLayout {
        Layout.preferredWidth: janela.editando ? 360 : 260
        Behavior on Layout.preferredWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Layout.fillHeight: true
        spacing: 12
        // ---- resumo (fechado) ----
        ColumnLayout {
            visible: !janela.editando
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 14
            Item { Layout.preferredHeight: 60 }
            Text { text: "Aparência atual"; color: janela.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
            Repeater {
                model: [["Cores", janela.tema.nome], ["Fonte", janela.c.fonte + " · " + janela.c.tamanho + " pt"],
                        ["Transparência", (100 - janela.c.opacidade) + " %"],
                        ["Cursor", ({ barra: "Barra", bloco: "Bloco", sublinhado: "Sublinhado" })[janela.c.cursor] || ""]]
                delegate: Column {
                    required property var modelData
                    Text { text: modelData[0]; color: janela.suave; font.pixelSize: 12 }
                    Text { text: modelData[1]; color: janela.texto; font.pixelSize: 15 }
                }
            }
            Text {
                visible: janela.aplicado
                text: "Aplicado ✓  As janelas novas do terminal já abrem assim."
                color: janela.ambar; font.pixelSize: 12
                wrapMode: Text.Wrap; Layout.fillWidth: true
            }
            Item { Layout.fillHeight: true }
            Row {
                Layout.alignment: Qt.AlignRight
                spacing: 10
                Botao { texto: "Abrir terminal"; onClicado: aparencia.abrirTerminal() }
                Botao { texto: "Modificar"; destaque: true; onClicado: janela.editando = true }
            }
        }
        // ---- opções (aberto) ----
        Flickable {
            visible: janela.editando
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: opcoes.implicitHeight
            clip: true
            ColumnLayout {
                id: opcoes
                width: parent.width
                spacing: 18

                Text { text: "Cores"; color: janela.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
                GridLayout {
                    columns: 2; columnSpacing: 10; rowSpacing: 10
                    Layout.fillWidth: true
                    Repeater {
                        model: aparencia.temas
                        delegate: Rectangle {
                            id: cartaoTema
                            required property var modelData
                            readonly property bool escolhido: janela.c.tema === modelData.id
                            Layout.fillWidth: true
                            height: 62; radius: 12
                            color: modelData.fundo
                            border.width: escolhido ? 2 : 1
                            border.color: escolhido ? janela.ambar : Qt.rgba(1, 1, 1, 0.12)
                            Text { x: 12; y: 9; text: modelData.nome; color: modelData.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Row {
                                x: 12; y: 36; spacing: 4
                                Repeater {
                                    model: [1, 2, 3, 4, 5, 6]
                                    Rectangle { required property int modelData; width: 14; height: 14; radius: 7; color: cartaoTema.modelData.cores[modelData] }
                                }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: aparencia.definir("tema", cartaoTema.modelData.id) }
                        }
                    }
                }

                Text { text: "Fonte"; color: janela.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
                ComboBox {
                    id: fonte
                    Layout.fillWidth: true
                    implicitHeight: 38
                    model: aparencia.fontes
                    currentIndex: Math.max(0, aparencia.fontes.indexOf(janela.c.fonte))
                    onActivated: (i) => aparencia.definir("fonte", aparencia.fontes[i])
                    background: Rectangle { radius: 10; color: Qt.rgba(1, 1, 1, fonte.hovered ? 0.12 : 0.07); border.color: Qt.rgba(1, 1, 1, 0.12) }
                    contentItem: Text { leftPadding: 12; text: fonte.displayText; font.family: fonte.displayText; color: janela.texto; verticalAlignment: Text.AlignVCenter }
                    delegate: ItemDelegate {
                        required property string modelData
                        width: fonte.width
                        contentItem: Text { text: modelData; font.family: modelData; color: modelData === janela.c.fonte ? janela.ambar : janela.texto }
                        background: Rectangle { color: parent.highlighted ? Qt.rgba(1, 1, 1, 0.1) : "transparent" }
                    }
                    popup.background: Rectangle { color: "#1b1726"; radius: 10; border.color: Qt.rgba(1, 1, 1, 0.12) }
                }
                Deslizante { titulo: "Tamanho da letra"; valor: janela.c.tamanho; de: 8; ate: 22; unidade: " pt"; chave: "tamanho" }
                Deslizante { titulo: "Transparência do fundo"; valor: 100 - janela.c.opacidade; de: 0; ate: 50; unidade: " %"; chave: "opacidade"; inverter: true }
                Deslizante { titulo: "Margem à volta do texto"; valor: janela.c.margem; de: 0; ate: 30; unidade: " px"; chave: "margem" }

                Text { text: "Cursor"; color: janela.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
                Row {
                    spacing: 8
                    Repeater {
                        model: [["barra", "Barra  ▏"], ["bloco", "Bloco  █"], ["sublinhado", "Sublinhado  ▁"]]
                        delegate: Botao {
                            required property var modelData
                            texto: modelData[1]
                            destaque: janela.c.cursor === modelData[0]
                            onClicado: aparencia.definir("cursor", modelData[0])
                        }
                    }
                }

            }
        }
        Text {
            visible: janela.editando
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            color: janela.suave; font.pixelSize: 12
            text: "As mudanças valem para as janelas novas do terminal."
        }
        Row {
            visible: janela.editando
            Layout.alignment: Qt.AlignRight
            spacing: 10
            Botao { texto: "Cancelar"; onClicado: { aparencia.cancelar(); janela.editando = false } }
            Botao { texto: "Aplicar"; destaque: true; onClicado: { aparencia.aplicar(); janela.aplicado = true; janela.editando = false } }
        }
        }
    }

    component Deslizante: ColumnLayout {
        id: d
        property string titulo
        property real valor
        property real de
        property real ate
        property string unidade
        property string chave
        property bool inverter: false
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            Text { text: d.titulo; color: janela.texto; Layout.fillWidth: true }
            Text { text: Math.round(barra.value) + d.unidade; color: janela.suave }
        }
        Slider {
            id: barra
            Layout.fillWidth: true
            from: d.de; to: d.ate; stepSize: 1
            value: d.valor
            onMoved: aparencia.definir(d.chave, d.inverter ? 100 - Math.round(value) : Math.round(value))
            background: Rectangle {
                x: barra.leftPadding; y: barra.topPadding + barra.availableHeight / 2 - 2
                width: barra.availableWidth; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.15)
                Rectangle { width: barra.visualPosition * parent.width; height: 4; radius: 2; color: janela.ambar }
            }
            handle: Rectangle {
                x: barra.leftPadding + barra.visualPosition * (barra.availableWidth - width)
                y: barra.topPadding + barra.availableHeight / 2 - height / 2
                width: 18; height: 18; radius: 9; color: "white"
            }
        }
    }
    component Botao: Rectangle {
        id: b
        property string texto
        property bool destaque: false
        signal clicado()
        implicitWidth: t.implicitWidth + 32; implicitHeight: 38; radius: 19
        color: destaque ? (area.containsMouse ? "#ffc58c" : janela.ambar) : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
        Text { id: t; anchors.centerIn: parent; text: b.texto; color: b.destaque ? "#1b1030" : janela.texto; font.weight: Font.DemiBold }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicado() }
    }
}
