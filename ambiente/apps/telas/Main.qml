// CarinaeOS — Telas
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: janela
    width: 940; height: 660
    minimumWidth: 760; minimumHeight: 560
    visible: true
    title: "Telas"
    color: "#0c0a14"
    font.family: "Inter"; font.pixelSize: 14

    readonly property color ambar: "#ffb46e"
    readonly property color rosa: "#ff6f91"
    readonly property color texto: "#f6f2ff"
    readonly property color suave: "#b9b0cc"
    readonly property color cartao: Qt.rgba(1, 1, 1, 0.05)
    readonly property var nomesRot: ({ normal: "Normal", left: "90° à esquerda", inverted: "180° (de cabeça para baixo)", right: "90° à direita" })

    // cópia editável das saídas
    property var saidas: []
    property int escolhida: 0
    property bool alterado: false
    function copiar() {
        saidas = JSON.parse(JSON.stringify(telas.saidas))
        alterado = false
        if (escolhida >= saidas.length) escolhida = 0
    }
    Component.onCompleted: copiar()
    Connections { target: telas; function onMudou() { janela.copiar() } }

    function mexer(i, f) {
        var c = JSON.parse(JSON.stringify(saidas)); f(c[i], c); saidas = c; alterado = true
    }
    function tam(s) {
        var p = s.modo.replace("i", "").split("x"), w = +p[0], h = +p[1]
        return (s.rotacao === "left" || s.rotacao === "right") ? [h, w] : [w, h]
    }
    function nomeDe(s) { return s.monitor ? s.monitor : s.nome }
    function modoDe(s, res) { for (var i = 0; i < s.modos.length; i++) if (s.modos[i].res === res) return s.modos[i]; return null }

    // encostar o monitor arrastado ao lado mais próximo de outro (sem sobrepor)
    function encaixar(i, x, y) {
        var a = saidas[i], ta = tam(a), melhor = null, dist = 1e12
        for (var j = 0; j < saidas.length; j++) {
            if (j === i || !saidas[j].ativo) continue
            var b = saidas[j], tb = tam(b)
            var cands = [
                [b.x + tb[0], y], [b.x - ta[0], y],          // à direita / à esquerda
                [x, b.y + tb[1]], [x, b.y - ta[1]] ]         // em baixo / em cima
            for (var k = 0; k < cands.length; k++) {
                var cx = cands[k][0], cy = cands[k][1]
                if (k < 2) {
                    cy = Math.max(b.y - ta[1] + 1, Math.min(b.y + tb[1] - 1, cy))
                    if (Math.abs(cy - b.y) < tb[1] * 0.08) cy = b.y                       // alinhar topos
                    else if (Math.abs(cy + ta[1] - b.y - tb[1]) < tb[1] * 0.08) cy = b.y + tb[1] - ta[1]
                } else {
                    cx = Math.max(b.x - ta[0] + 1, Math.min(b.x + tb[0] - 1, cx))
                    if (Math.abs(cx - b.x) < tb[0] * 0.08) cx = b.x
                    else if (Math.abs(cx + ta[0] - b.x - tb[0]) < tb[0] * 0.08) cx = b.x + tb[0] - ta[0]
                }
                if (sobrepoe(i, cx, cy, ta)) continue
                var d = (cx - x) * (cx - x) + (cy - y) * (cy - y)
                if (d < dist) { dist = d; melhor = [cx, cy] }
            }
        }
        if (!melhor) melhor = [x, y]
        mexer(i, function (s) { s.x = Math.round(melhor[0]); s.y = Math.round(melhor[1]) })
    }
    function sobrepoe(i, x, y, ta) {
        for (var j = 0; j < saidas.length; j++) {
            if (j === i || !saidas[j].ativo) continue
            var b = saidas[j], tb = tam(b)
            if (x < b.x + tb[0] && x + ta[0] > b.x && y < b.y + tb[1] && y + ta[1] > b.y) return true
        }
        return false
    }

    // --------------------------------------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            Image { source: "image://icone/preferences-desktop-display"; sourceSize: Qt.size(40, 40); Layout.preferredWidth: 40; Layout.preferredHeight: 40 }
            Column {
                Layout.fillWidth: true
                Text { text: "Telas"; color: janela.texto; font.pixelSize: 24; font.weight: Font.Bold }
                Text { text: "Arraste os monitores para os pôr na posição em que estão na mesa"; color: janela.suave; font.pixelSize: 13 }
            }
            Botao { texto: "Identificar"; onClicado: identificar.mostrar() }
        }

        // ---- o arranjo ------------------------------------------------------------------------
        Rectangle {
            id: palco
            Layout.fillWidth: true
            Layout.preferredHeight: 260
            radius: 16
            color: janela.cartao
            border.color: Qt.rgba(1, 1, 1, 0.08)

            // escala para caber tudo com folga
            readonly property var caixa: {
                var x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9
                for (var i = 0; i < janela.saidas.length; i++) {
                    var s = janela.saidas[i]; if (!s.ativo) continue
                    var t = janela.tam(s)
                    x0 = Math.min(x0, s.x); y0 = Math.min(y0, s.y); x1 = Math.max(x1, s.x + t[0]); y1 = Math.max(y1, s.y + t[1])
                }
                if (x0 > x1) return [0, 0, 1920, 1080]
                return [x0, y0, x1 - x0, y1 - y0]
            }
            readonly property real escala: Math.min((width - 80) / caixa[2], (height - 60) / caixa[3])
            readonly property real ox: (width - caixa[2] * escala) / 2 - caixa[0] * escala
            readonly property real oy: (height - caixa[3] * escala) / 2 - caixa[1] * escala

            Repeater {
                model: janela.saidas
                delegate: Rectangle {
                    id: mon
                    required property var modelData
                    required property int index
                    readonly property var t: janela.tam(modelData)
                    visible: modelData.ativo
                    x: arrasto.active ? x : palco.ox + modelData.x * palco.escala
                    y: arrasto.active ? y : palco.oy + modelData.y * palco.escala
                    width: t[0] * palco.escala - 4; height: t[1] * palco.escala - 4
                    radius: 10
                    color: janela.escolhida === index ? Qt.rgba(1, 0.7, 0.43, 0.22) : Qt.rgba(1, 1, 1, 0.08)
                    border.width: 2
                    border.color: janela.escolhida === index ? janela.ambar : Qt.rgba(1, 1, 1, 0.25)
                    z: arrasto.active ? 2 : 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 2
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: (mon.index + 1); color: janela.texto; font.pixelSize: Math.min(40, mon.height * 0.35); font.weight: Font.Bold }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: janela.nomeDe(mon.modelData); color: janela.texto; font.pixelSize: 13; elide: Text.ElideRight; width: Math.min(implicitWidth, mon.width - 12) }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: mon.modelData.modo; color: janela.suave; font.pixelSize: 12 }
                    }
                    Text {
                        visible: mon.modelData.principal
                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8
                        text: "★"; color: janela.ambar; font.pixelSize: 16
                    }
                    DragHandler {
                        id: arrasto
                        cursorShape: Qt.ClosedHandCursor
                        onActiveChanged: {
                            janela.escolhida = mon.index
                            if (!active) janela.encaixar(mon.index, (mon.x - palco.ox) / palco.escala, (mon.y - palco.oy) / palco.escala)
                        }
                    }
                    TapHandler { onTapped: janela.escolhida = mon.index }
                }
            }
            Text {
                visible: janela.saidas.length === 0
                anchors.centerIn: parent
                text: "Não encontrei monitores (o xrandr não respondeu)"
                color: janela.suave
            }
        }

        // ---- separadores dos monitores --------------------------------------------------------
        Row {
            spacing: 8
            Repeater {
                model: janela.saidas
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    height: 34; width: rotulo.implicitWidth + 28; radius: 17
                    color: janela.escolhida === index ? janela.ambar : janela.cartao
                    Text {
                        id: rotulo
                        anchors.centerIn: parent
                        text: (index + 1) + "  " + janela.nomeDe(modelData) + (modelData.monitor ? "  ·  " + modelData.nome : "")
                        color: janela.escolhida === index ? "#1b1030" : janela.texto
                        font.weight: janela.escolhida === index ? Font.DemiBold : Font.Normal
                    }
                    MouseArea { anchors.fill: parent; onClicked: janela.escolhida = index }
                }
            }
        }

        // ---- definições do monitor escolhido --------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: janela.cartao
            border.color: Qt.rgba(1, 1, 1, 0.08)
            visible: janela.saidas.length > 0
            readonly property var s: janela.saidas[janela.escolhida] || null

            GridLayout {
                id: grelha
                anchors.fill: parent
                anchors.margins: 20
                columns: 4
                columnSpacing: 18; rowSpacing: 14
                readonly property var s: parent.s

                Text { text: "Ligado"; color: janela.suave }
                Interruptor {
                    ligado: grelha.s ? grelha.s.ativo : false
                    onAlternado: (v) => janela.mexer(janela.escolhida, function (s, todas) {
                        if (!v && todas.filter(function (o) { return o.ativo }).length <= 1) return
                        s.ativo = v
                        if (v) {   // pôr à direita do resto
                            var dir = 0
                            for (var i = 0; i < todas.length; i++) if (todas[i] !== s && todas[i].ativo) dir = Math.max(dir, todas[i].x + janela.tam(todas[i])[0])
                            s.x = dir; s.y = 0
                        } else if (s.principal) {
                            s.principal = false
                            for (var j = 0; j < todas.length; j++) if (todas[j].ativo) { todas[j].principal = true; break }
                        }
                    })
                }
                Text { text: "Tela principal"; color: janela.suave }
                Interruptor {
                    ligado: grelha.s ? grelha.s.principal : false
                    enabled: grelha.s ? grelha.s.ativo : false
                    onAlternado: (v) => { if (v) janela.mexer(janela.escolhida, function (s, todas) { for (var i = 0; i < todas.length; i++) todas[i].principal = false; s.principal = true }) }
                }

                Text { text: "Resolução"; color: janela.suave }
                Escolha {
                    Layout.fillWidth: true
                    enabled: grelha.s ? grelha.s.ativo : false
                    model: grelha.s ? grelha.s.modos.map(function (m) {
                        return { valor: m.res, texto: m.res.replace("x", " × ").replace("i", " (entrelaçado)") + (m.res === grelha.s.preferido ? "   · recomendada" : "") } }) : []
                    valor: grelha.s ? grelha.s.modo : ""
                    onEscolhido: (v) => janela.mexer(janela.escolhida, function (s) {
                        s.modo = v
                        var m = janela.modoDe(s, v)
                        if (m && m.taxas.indexOf(s.taxa) < 0) s.taxa = m.taxas[0]
                    })
                }
                Text { text: "Frequência"; color: janela.suave }
                Escolha {
                    Layout.fillWidth: true
                    enabled: grelha.s ? grelha.s.ativo : false
                    model: {
                        var m = grelha.s ? janela.modoDe(grelha.s, grelha.s.modo) : null
                        return m ? m.taxas.map(function (t) { return { valor: t, texto: Math.round(+t * 100) / 100 + " Hz" } }) : []
                    }
                    valor: grelha.s ? grelha.s.taxa : ""
                    onEscolhido: (v) => janela.mexer(janela.escolhida, function (s) { s.taxa = v })
                }

                Text { text: "Rotação"; color: janela.suave }
                Escolha {
                    Layout.fillWidth: true
                    enabled: grelha.s ? grelha.s.ativo : false
                    model: ["normal", "left", "right", "inverted"].map(function (r) { return { valor: r, texto: janela.nomesRot[r] } })
                    valor: grelha.s ? grelha.s.rotacao : "normal"
                    onEscolhido: (v) => janela.mexer(janela.escolhida, function (s) { s.rotacao = v })
                }
                Text { text: "Tamanho"; color: janela.suave }
                Text {
                    color: janela.texto
                    text: {
                        if (!grelha.s || !grelha.s.mm[0]) return "—"
                        var pol = Math.sqrt(grelha.s.mm[0] * grelha.s.mm[0] + grelha.s.mm[1] * grelha.s.mm[1]) / 25.4
                        return Math.round(pol) + "\" (" + Math.round(grelha.s.mm[0] / 10) + " × " + Math.round(grelha.s.mm[1] / 10) + " cm)"
                    }
                }
                Item { Layout.columnSpan: 4; Layout.fillHeight: true }
            }
        }

        // ---- botões -------------------------------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Text { id: erro; color: janela.rosa; Layout.fillWidth: true; wrapMode: Text.Wrap }
            Botao { texto: "Repor"; enabled: janela.alterado; onClicado: { erro.text = ""; janela.copiar() } }
            Botao {
                texto: "Aplicar"; destaque: true; enabled: janela.alterado
                onClicado: {
                    erro.text = ""
                    var r = telas.aplicar(janela.saidas)
                    if (r) erro.text = r
                    else confirmar.abrir()
                }
            }
        }
    }

    // ---- confirmação (volta atrás sozinho se o ecrã ficar preto) ---------------------------------
    Rectangle {
        id: confirmar
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.6)
        visible: false
        property int resta: 15
        function abrir() { resta = 15; visible = true; contador.start() }
        MouseArea { anchors.fill: parent }
        Timer {
            id: contador; interval: 1000; repeat: true
            onTriggered: { confirmar.resta--; if (confirmar.resta <= 0) { stop(); confirmar.visible = false; telas.reverter() } }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 440; height: col.implicitHeight + 48; radius: 18
            color: "#1b1726"; border.color: Qt.rgba(1, 1, 1, 0.1)
            Column {
                id: col
                anchors.centerIn: parent
                width: parent.width - 48
                spacing: 14
                Text { text: "Manter esta configuração?"; color: janela.texto; font.pixelSize: 19; font.weight: Font.Bold }
                Text { width: parent.width; wrapMode: Text.Wrap; color: janela.suave
                       text: "Se não confirmar, volta à anterior em " + confirmar.resta + " s." }
                Row {
                    anchors.right: parent.right
                    spacing: 10
                    Botao { texto: "Voltar atrás"; onClicado: { contador.stop(); confirmar.visible = false; telas.reverter() } }
                    Botao { texto: "Manter"; destaque: true; onClicado: { contador.stop(); confirmar.visible = false; telas.manter() } }
                }
            }
        }
    }

    // ---- número grande em cada ecrã ---------------------------------------------------------------
    QtObject {
        id: identificar
        function mostrar() { rotulos.model = 0; rotulos.model = Qt.application.screens; adeus.restart() }
    }
    Timer { id: adeus; interval: 3000; onTriggered: rotulos.model = 0 }
    Instantiator {
        id: rotulos
        model: 0
        delegate: Window {
            required property var modelData
            readonly property int indice: { for (var i = 0; i < janela.saidas.length; i++) if (janela.saidas[i].nome === modelData.name) return i; return -1 }
            flags: Qt.ToolTip | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
            color: "transparent"
            x: modelData.virtualX + 40; y: modelData.virtualY + 40
            width: 190; height: 150
            visible: true
            Rectangle {
                anchors.fill: parent; radius: 22; color: "#e61b1726"; border.color: janela.ambar; border.width: 2
                Column {
                    anchors.centerIn: parent
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: indice >= 0 ? indice + 1 : "?"; color: janela.ambar; font.pixelSize: 72; font.weight: Font.Bold }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: indice >= 0 ? janela.nomeDe(janela.saidas[indice]) : modelData.name; color: janela.texto; font.pixelSize: 14 }
                }
            }
        }
    }

    // ---- peças pequenas -----------------------------------------------------------------------------
    component Botao: Rectangle {
        id: b
        property string texto
        property bool destaque: false
        signal clicado()
        implicitWidth: t.implicitWidth + 36; implicitHeight: 38; radius: 19
        opacity: enabled ? 1 : 0.4
        color: destaque ? (area.containsMouse ? "#ffc58c" : janela.ambar) : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
        Text { id: t; anchors.centerIn: parent; text: b.texto; color: b.destaque ? "#1b1030" : janela.texto; font.weight: Font.DemiBold }
        MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; onClicked: b.clicado() }
    }
    component Interruptor: Rectangle {
        id: i
        property bool ligado
        signal alternado(bool v)
        implicitWidth: 46; implicitHeight: 26; radius: 13
        opacity: enabled ? 1 : 0.4
        color: ligado ? janela.ambar : Qt.rgba(1, 1, 1, 0.15)
        Rectangle { width: 20; height: 20; radius: 10; y: 3; x: i.ligado ? 23 : 3; color: "white"; Behavior on x { NumberAnimation { duration: 120 } } }
        MouseArea { anchors.fill: parent; onClicked: i.alternado(!i.ligado) }
    }
    component Escolha: ComboBox {
        id: c
        property string valor
        signal escolhido(string v)
        textRole: "texto"; valueRole: "valor"
        implicitHeight: 38
        opacity: enabled ? 1 : 0.4
        currentIndex: { for (var k = 0; k < count; k++) if (model[k] && model[k].valor === valor) return k; return -1 }
        onActivated: (k) => c.escolhido(model[k].valor)
        background: Rectangle { radius: 10; color: Qt.rgba(1, 1, 1, c.hovered ? 0.12 : 0.07); border.color: c.activeFocus ? janela.ambar : Qt.rgba(1, 1, 1, 0.12) }
        contentItem: Text { leftPadding: 12; text: c.displayText; color: janela.texto; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
        indicator: Text { x: c.width - width - 12; anchors.verticalCenter: parent.verticalCenter; text: "▾"; color: janela.suave }
        delegate: ItemDelegate {
            required property var modelData
            required property int index
            width: c.width
            highlighted: c.highlightedIndex === index
            contentItem: Text { text: modelData.texto; color: modelData.valor === c.valor ? janela.ambar : janela.texto }
            background: Rectangle { color: parent.highlighted ? Qt.rgba(1, 1, 1, 0.1) : "transparent" }
        }
        popup.background: Rectangle { color: "#1b1726"; radius: 10; border.color: Qt.rgba(1, 1, 1, 0.12) }
    }
}
