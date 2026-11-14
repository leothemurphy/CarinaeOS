// CarinaeOS - Comando (Ctrl+Espaco)
import QtQuick
import QtQuick.Controls
import QtQuick.Window

Window {
    id: janela
    title: "CarinaeOS — Comando"
    width: 840
    height: caixa.height
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool
    visible: false

    readonly property color texto: "#f4f1fa"
    readonly property color suave: "#9c96ab"
    readonly property color linha: Qt.rgba(1, 1, 1, 0.08)
    property int atual: 0
    property bool emAcoes: false
    property var listaAcoes: []
    property bool foiAtiva: false
    property int acaoAtual: 0

    function aparecer() {
        busca.text = "";
        comando.definirModo("");
        atual = 0;
        emAcoes = false;
        foiAtiva = false;
        visible = true;
        raise();
        requestActivate();
        busca.forceActiveFocus();
        comando.acompanhar(true);
        entrada.restart();
    }
    function esconder() {
        comando.acompanhar(false);
        visible = false;
    }
    function executar(i) {
        if (comando.executar(i)) esconder();
        else { busca.text = ""; atual = 0; busca.forceActiveFocus(); }
    }
    function mover(d) {
        const n = lista.count;
        if (n === 0) return;
        let i = atual;
        for (let k = 0; k < n; ++k) {
            i = Math.max(0, Math.min(n - 1, i + d));
            if (comando.resultados[i].tipo !== "nada") break;
        }
        atual = i;
        lista.positionViewAtIndex(atual, ListView.Contain);
    }
    function abrirAcoes() {
        listaAcoes = comando.acoes(atual);
        if (listaAcoes.length === 0) return;
        acaoAtual = 0;
        emAcoes = true;
    }

    Connections {
        target: comando
        function onMostrar() { janela.aparecer(); }
        function onResultadosMudaram() {
            modelo.clear();
            for (const r of comando.resultados) modelo.append(r);
            if (janela.atual >= lista.count) janela.atual = 0;
        }
    }
    // só fecha ao perder o foco depois de o ter tido (no Wayland a ativação pode chegar tarde)
    onActiveChanged: {
        if (active) foiAtiva = true;
        else if (visible && foiAtiva) esconder();
    }

    Rectangle {
        id: caixa
        width: parent.width
        height: col.height
        radius: 26
        color: Qt.rgba(0.07, 0.06, 0.1, 0.93)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.13)
        opacity: 0
        scale: 0.97
        ParallelAnimation {
            id: entrada
            NumberAnimation { target: caixa; property: "opacity"; from: 0; to: 1; duration: 140; easing.type: Easing.OutCubic }
            NumberAnimation { target: caixa; property: "scale"; from: 0.97; to: 1; duration: 180; easing.type: Easing.OutCubic }
        }
        // brilho suave por cima, como vidro
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.06) }
                GradientStop { position: 0.4; color: Qt.rgba(1, 1, 1, 0) }
            }
        }

        Column {
            id: col
            width: parent.width

            // ---- pesquisa --------------------------------------------------------------
            Item {
                width: parent.width
                height: 72
                Text {
                    id: seta
                    x: 26
                    anchors.verticalCenter: parent.verticalCenter
                    text: comando.modo === "clip" ? "⧉" : "❯"
                    color: comando.modo === "clip" ? "#8fb2ff" : janela.suave
                    font.pixelSize: 22
                }
                TextField {
                    id: busca
                    anchors.left: seta.right
                    anchors.leftMargin: 14
                    anchors.right: modoChip.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    background: Item {}
                    color: janela.texto
                    font.pixelSize: 24
                    placeholderText: comando.modo === "clip" ? "Procurar no que copiou…" : "Aplicativos, arquivos, comandos, contas…"
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.38)
                    selectByMouse: true
                    onTextChanged: { comando.procurar(text); janela.atual = 0; janela.emAcoes = false; }
                    Keys.onPressed: ev => {
                        const ctrl = ev.modifiers & Qt.ControlModifier;
                        if (janela.emAcoes) {
                            if (ev.key === Qt.Key_Down) { janela.acaoAtual = Math.min(janela.listaAcoes.length - 1, janela.acaoAtual + 1); ev.accepted = true; }
                            else if (ev.key === Qt.Key_Up) { janela.acaoAtual = Math.max(0, janela.acaoAtual - 1); ev.accepted = true; }
                            else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                                if (comando.executarAcao(janela.atual, janela.listaAcoes[janela.acaoAtual].id)) janela.esconder();
                                janela.emAcoes = false; ev.accepted = true;
                            } else if (ev.key === Qt.Key_Escape || (ctrl && ev.key === Qt.Key_K)) { janela.emAcoes = false; ev.accepted = true; }
                            return;
                        }
                        if (ev.key === Qt.Key_Down) { janela.mover(1); ev.accepted = true; }
                        else if (ev.key === Qt.Key_Up) { janela.mover(-1); ev.accepted = true; }
                        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { janela.executar(janela.atual); ev.accepted = true; }
                        else if (ctrl && ev.key === Qt.Key_K) { janela.abrirAcoes(); ev.accepted = true; }
                        else if (ctrl && ev.key >= Qt.Key_1 && ev.key <= Qt.Key_9) {
                            const i = ev.key - Qt.Key_1;
                            if (i < lista.count) janela.executar(i);
                            ev.accepted = true;
                        } else if (ev.key === Qt.Key_Escape) {
                            if (comando.modo !== "") { comando.definirModo(""); busca.text = ""; }
                            else if (text !== "") text = "";
                            else janela.esconder();
                            ev.accepted = true;
                        } else if (ev.key === Qt.Key_Backspace && text === "" && comando.modo !== "") {
                            comando.definirModo(""); ev.accepted = true;
                        }
                    }
                }
                Rectangle {
                    id: modoChip
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    height: 30
                    width: chipTexto.implicitWidth + 44
                    radius: 9
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.10)
                    Rectangle {
                        x: 6; anchors.verticalCenter: parent.verticalCenter
                        width: 26; height: 20; radius: 5
                        color: Qt.rgba(1, 1, 1, 0.10)
                        Text { anchors.centerIn: parent; text: comando.modo === "clip" ? "Esc" : ">"; color: janela.texto; font.pixelSize: 11 }
                    }
                    Text {
                        id: chipTexto
                        x: 38; anchors.verticalCenter: parent.verticalCenter
                        text: comando.modo === "clip" ? "Voltar" : "Terminal"
                        color: janela.texto
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (comando.modo !== "") comando.definirModo("");
                            else busca.text = "> ";
                            busca.forceActiveFocus();
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: janela.linha }

            // ---- estado do computador ----------------------------------------------------
            Row {
                id: cartoes
                visible: comando.modo === "" && busca.text === ""
                x: 18
                topPadding: 16
                bottomPadding: 6
                spacing: 10
                readonly property var e: comando.estado

                component Cartao: Rectangle {
                    id: ct
                    property string titulo: ""
                    property string icone: ""
                    default property alias dentro: corpo.data
                    height: 108
                    radius: 16
                    color: Qt.rgba(1, 1, 1, 0.045)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    Row {
                        x: 14; y: 12; spacing: 6
                        Image { source: "image://icone/" + ct.icone; width: 14; height: 14; sourceSize: Qt.size(28, 28); opacity: 0.8; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: ct.titulo; color: "#9c96ab"; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 0.8 }
                    }
                    Item { id: corpo; x: 14; y: 36; width: parent.width - 28; height: parent.height - 46 }
                }
                component Barra: Rectangle {
                    id: barra
                    property real valor: 0
                    width: parent.width; height: 4; radius: 2
                    color: Qt.rgba(1, 1, 1, 0.08)
                    Rectangle {
                        width: barra.width * Math.max(0, Math.min(1, barra.valor)); height: parent.height; radius: 2
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#5b7cff" }
                            GradientStop { position: 1; color: barra.valor > 0.85 ? "#ff6f6f" : "#a35bff" }
                        }
                    }
                }

                Cartao {
                    width: 118; titulo: "CPU"; icone: "cpu"
                    Text { y: 4; text: (cartoes.e.cpu || "—"); color: janela.texto; font.pixelSize: 34; font.weight: Font.DemiBold }
                }
                Cartao {
                    width: 132; titulo: "MEMÓRIA"; icone: "memory"
                    Column {
                        width: parent.width; spacing: 4
                        Text { text: cartoes.e.memoria || "—"; color: janela.texto; font.pixelSize: 24; font.weight: Font.DemiBold }
                        Text { text: cartoes.e.memoriaTotal || ""; color: janela.suave; font.pixelSize: 11 }
                        Barra { valor: cartoes.e.memoriaPct || 0 }
                    }
                }
                Cartao {
                    width: 132; titulo: "DISCO"; icone: "drive-harddisk"
                    Column {
                        width: parent.width; spacing: 4
                        Text { text: cartoes.e.disco || "—"; color: janela.texto; font.pixelSize: 24; font.weight: Font.DemiBold }
                        Text { text: cartoes.e.discoTotal || ""; color: janela.suave; font.pixelSize: 11 }
                        Barra { valor: cartoes.e.discoPct || 0 }
                    }
                }
                Cartao {
                    width: 196; titulo: "MAIS CPU"; icone: "utilities-system-monitor"
                    Column {
                        width: parent.width; spacing: 5
                        Repeater {
                            model: cartoes.e.topCpu || []
                            delegate: Item {
                                required property var modelData
                                width: parent.width; height: 16
                                Text { width: parent.width - 44; elide: Text.ElideRight; text: parent.modelData.nome; color: janela.texto; font.pixelSize: 12 }
                                Text { anchors.right: parent.right; text: parent.modelData.valor; color: janela.suave; font.pixelSize: 12 }
                            }
                        }
                    }
                }
                Cartao {
                    width: 196; titulo: "MAIS MEMÓRIA"; icone: "memory"
                    Column {
                        width: parent.width; spacing: 5
                        Repeater {
                            model: cartoes.e.topMem || []
                            delegate: Item {
                                required property var modelData
                                width: parent.width; height: 16
                                Text { width: parent.width - 66; elide: Text.ElideRight; text: parent.modelData.nome; color: janela.texto; font.pixelSize: 12 }
                                Text { anchors.right: parent.right; text: parent.modelData.valor; color: janela.suave; font.pixelSize: 12 }
                            }
                        }
                    }
                }
            }

            // ---- resultados ------------------------------------------------------------------
            ListView {
                id: lista
                x: 10
                width: parent.width - 20
                height: Math.min(contentHeight, 8 * 50 + 3 * 34)
                clip: true
                model: ListModel { id: modelo }
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: janela.atual
                topMargin: 8
                bottomMargin: 8
                ScrollBar.vertical: ScrollBar {}

                section.property: "grupo"
                section.delegate: Item {
                    required property string section
                    width: lista.width
                    height: 34
                    Text {
                        x: 14
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 7
                        text: parent.section
                        color: janela.suave
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                }

                delegate: Rectangle {
                    id: linhaRes
                    required property var model
                    required property int index
                    readonly property bool escolhido: index === janela.atual
                    width: lista.width
                    height: model.tipo === "nada" ? 64 : 50
                    radius: 12
                    color: escolhido && model.tipo !== "nada" ? Qt.rgba(1, 1, 1, 0.085) : (mr.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                    border.width: escolhido && model.tipo !== "nada" ? 1 : 0
                    border.color: Qt.rgba(1, 1, 1, 0.08)

                    Image {
                        id: ic
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 28; height: 28
                        sourceSize: Qt.size(56, 56)
                        source: "image://icone/" + linhaRes.model.icone
                        asynchronous: true
                    }
                    Column {
                        anchors.left: ic.right
                        anchors.leftMargin: 14
                        anchors.right: atalho.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: linhaRes.model.titulo
                            color: janela.texto
                            font.pixelSize: linhaRes.model.tipo === "conta" ? 20 : 15
                            font.weight: linhaRes.model.tipo === "conta" ? Font.DemiBold : Font.Normal
                            textFormat: Text.PlainText
                        }
                        Text {
                            width: parent.width
                            elide: Text.ElideMiddle
                            text: linhaRes.model.sub
                            visible: text !== ""
                            color: janela.suave
                            font.pixelSize: 12
                            textFormat: Text.PlainText
                        }
                    }
                    Row {
                        id: atalho
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        visible: linhaRes.index < 9 && linhaRes.model.tipo !== "nada" && (linhaRes.escolhido || mr.containsMouse || linhaRes.index < 5)
                        Repeater {
                            model: ["Ctrl", String(linhaRes.index + 1)]
                            delegate: Rectangle {
                                required property string modelData
                                width: Math.max(24, t.implicitWidth + 12); height: 24; radius: 6
                                color: Qt.rgba(1, 1, 1, 0.07)
                                Text { id: t; anchors.centerIn: parent; text: parent.modelData; color: janela.suave; font.pixelSize: 11 }
                            }
                        }
                    }
                    MouseArea {
                        id: mr
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: linhaRes.model.tipo === "nada" ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: ev => {
                            if (linhaRes.model.tipo === "nada") return;
                            janela.atual = linhaRes.index;
                            if (ev.button === Qt.RightButton) janela.abrirAcoes();
                            else janela.executar(linhaRes.index);
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: janela.linha }

            // ---- rodapé -----------------------------------------------------------------------
            Item {
                width: parent.width
                height: 54
                Row {
                    x: 20
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Image { source: "image://icone/carinaeos-estrela"; width: 22; height: 22; sourceSize: Qt.size(44, 44); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: comando.modo === "clip" ? "Área de transferência" : "Comando"; color: janela.suave; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    component Tecla: Rectangle {
                        property string t: ""
                        width: Math.max(26, tt.implicitWidth + 12); height: 24; radius: 6
                        color: Qt.rgba(1, 1, 1, 0.08)
                        Text { id: tt; anchors.centerIn: parent; text: parent.t; color: "#f4f1fa"; font.pixelSize: 12 }
                    }
                    Text {
                        text: {
                            const r = comando.resultados[janela.atual];
                            if (!r) return "Abrir";
                            return r.tipo === "conta" || r.tipo === "clip" ? "Copiar" : r.tipo === "cmd" || r.tipo === "terminal" ? "Executar" : "Abrir";
                        }
                        color: janela.texto; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter
                    }
                    Tecla { t: "↵"; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle { width: 1; height: 18; color: janela.linha; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Ações"; color: janela.texto; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    Tecla { t: "Ctrl"; anchors.verticalCenter: parent.verticalCenter }
                    Tecla { t: "K"; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        // ---- painel de ações (Ctrl+K) -------------------------------------------------------
        Rectangle {
            visible: janela.emAcoes
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 60
            width: 300
            height: colAcoes.height + 16
            radius: 14
            color: Qt.rgba(0.12, 0.11, 0.16, 0.98)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)
            Column {
                id: colAcoes
                x: 8; y: 8
                width: parent.width - 16
                Repeater {
                    model: janela.listaAcoes
                    delegate: Rectangle {
                        id: ac
                        required property var modelData
                        required property int index
                        width: colAcoes.width
                        height: 38
                        radius: 9
                        color: index === janela.acaoAtual ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
                        Image { id: aic; x: 10; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; sourceSize: Qt.size(36, 36); source: "image://icone/" + ac.modelData.icone }
                        Text { anchors.left: aic.right; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: ac.modelData.nome; color: janela.texto; font.pixelSize: 14 }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: janela.acaoAtual = ac.index
                            onClicked: {
                                if (comando.executarAcao(janela.atual, ac.modelData.id)) janela.esconder();
                                janela.emAcoes = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
