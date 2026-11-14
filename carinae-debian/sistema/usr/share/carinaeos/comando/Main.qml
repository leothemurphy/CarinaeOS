// CarinaeOS - Pesquisa (Ctrl+Espaco ou a lupa da barra de cima)
// Como a nova pesquisa do Windows: a caixa em baixo, os resultados por cima, acoes que se
// fazem ali mesmo (volume, brilho, tema, Wi-Fi, janelas…), correcoes de palavras e cartoes.
import QtQuick
import QtQuick.Controls
import QtQuick.Window

Window {
    id: janela
    title: "CarinaeOS — Comando"
    // tamanho fixo (o painel cresce por dentro, encostado em baixo)
    width: 660
    height: 620
    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    visible: false

    readonly property color texto: "#f3f1f7"
    readonly property color suave: "#a7a2b5"
    readonly property color realce: "#7aa7ff"
    readonly property color linha: Qt.rgba(1, 1, 1, 0.08)
    property int atual: 0
    property bool emAcoes: false
    property var listaAcoes: []
    property int acaoAtual: 0
    property bool foiAtiva: false
    readonly property var selecionado: atual < modelo.count ? modelo.get(atual) : null

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
        entrada.restart();
    }
    function escrever(t) { busca.text = t; }   // usado nos testes
    function esconder() {
        visible = false;
    }
    function executar(i) {
        if (i < 0 || i >= modelo.count) return;
        if (comando.executar(i)) esconder();
        else { busca.text = ""; atual = 0; busca.forceActiveFocus(); }
    }
    function mover(d) {
        const n = modelo.count;
        if (n === 0) return;
        let i = atual;
        for (let k = 0; k < n; ++k) {
            i = Math.max(0, Math.min(n - 1, i + d));
            if (modelo.get(i).tipo !== "nada") break;
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
    function usarCorrecao(p) {
        const t = busca.text.replace(/\s+$/, "");
        const i = t.lastIndexOf(" ");
        busca.text = (i === -1 ? "" : t.substring(0, i + 1)) + p + " ";
        busca.forceActiveFocus();
    }

    ListModel { id: modelo }
    Connections {
        target: comando
        function onMostrar() { janela.aparecer(); }
        function onResultadosMudaram() {
            modelo.clear();
            for (const r of comando.resultados) modelo.append(r);
            if (janela.atual >= modelo.count) janela.atual = 0;
        }
    }
    // só fecha ao perder o foco depois de o ter tido (no Wayland a ativação pode chegar tarde)
    onActiveChanged: {
        if (active) foiAtiva = true;
        else if (visible && foiAtiva) esconder();
    }

    // clique na parte vazia (transparente) da janela fecha
    MouseArea { anchors.fill: parent; onClicked: janela.esconder() }

    Rectangle {
        id: painel
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 20
        height: Math.min(parent.height - 10, col.height + 16)
        radius: 18
        color: Qt.rgba(0.11, 0.10, 0.15, 0.94)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        MouseArea { anchors.fill: parent }   // cliques no painel não fecham
        transform: Translate { id: subir; y: 0 }
        ParallelAnimation {
            id: entrada
            NumberAnimation { target: subir; property: "y"; from: 24; to: 0; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: painel; property: "opacity"; from: 0.4; to: 1; duration: 160 }
        }
        Rectangle {   // brilho de vidro por cima
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.05) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
            }
        }

        Column {
            id: col
            x: 8; y: 8
            width: parent.width - 16
            spacing: 6

            // ---- resultados --------------------------------------------------------------------
            ListView {
                id: lista
                width: parent.width
                height: Math.min(contentHeight, janela.height - 190)
                visible: modelo.count > 0
                clip: true
                model: modelo
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    id: item
                    required property int index
                    required property var model
                    readonly property bool escolhido: index === janela.atual && model.tipo !== "nada"
                    readonly property bool cartao: model.tipo === "tempo" || model.tipo === "estado"
                    width: lista.width
                    height: cabeca.height + (detalhe.visible ? detalhe.height + 10 : 0) + 8
                    radius: 10
                    color: escolhido ? Qt.rgba(1, 1, 1, 0.075) : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent")

                    // barra azul à esquerda do escolhido (como no Windows)
                    Rectangle {
                        visible: item.escolhido
                        x: 1; y: 18
                        width: 3; height: 18; radius: 1.5
                        color: janela.realce
                    }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: ev => {
                            if (item.model.tipo === "nada") return;
                            if (ev.button === Qt.RightButton) { janela.atual = item.index; janela.abrirAcoes(); }
                            else if (janela.atual === item.index || item.model.controlo === "") janela.executar(item.index);
                            else janela.atual = item.index;
                        }
                    }

                    Item {
                        id: cabeca
                        y: 4
                        width: parent.width
                        height: 46
                        Image {
                            id: ic
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            width: 22; height: 22
                            sourceSize: Qt.size(44, 44)
                            source: "image://icone/" + item.model.icone
                            asynchronous: true
                        }
                        Column {
                            anchors.left: ic.right
                            anchors.leftMargin: 14
                            anchors.right: botoes.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: item.model.titulo
                                color: janela.texto
                                font.pixelSize: item.model.tipo === "conta" ? 18 : 14
                                font.weight: item.model.tipo === "conta" ? Font.DemiBold : Font.Medium
                                textFormat: Text.PlainText
                            }
                            Row {
                                spacing: 5
                                visible: item.model.sub !== ""
                                Rectangle {   // selo "Ação"
                                    visible: item.model.tipo === "acao"
                                    width: 11; height: 11; radius: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: janela.realce
                                    Text { anchors.centerIn: parent; text: "✦"; color: "#0b1530"; font.pixelSize: 8 }
                                }
                                Text {
                                    width: Math.min(implicitWidth, cabeca.width - 140)
                                    elide: Text.ElideMiddle
                                    text: item.model.sub
                                    color: item.model.tipo === "acao" ? janela.realce : janela.suave
                                    font.pixelSize: 12
                                    textFormat: Text.PlainText
                                }
                            }
                        }
                        Row {
                            id: botoes
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            visible: item.escolhido || ma.containsMouse
                            Rectangle {
                                width: 30; height: 28; radius: 6
                                color: mais.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                Text { anchors.centerIn: parent; text: "···"; color: janela.texto; font.pixelSize: 15; font.weight: Font.Bold }
                                MouseArea { id: mais; anchors.fill: parent; hoverEnabled: true; onClicked: { janela.atual = item.index; janela.abrirAcoes(); } }
                            }
                            Rectangle {
                                width: 30; height: 28; radius: 6
                                color: entrar.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: item.model.tipo === "web" || item.model.tipo === "url" || item.model.tipo === "tempo" ? "↗" : "↵"
                                    color: janela.texto; font.pixelSize: 15
                                }
                                MouseArea { id: entrar; anchors.fill: parent; hoverEnabled: true; onClicked: janela.executar(item.index) }
                            }
                        }
                    }

                    // ---- o cartão por baixo do escolhido: controlo da ação, tempo, uso do PC ----------
                    Rectangle {
                        id: detalhe
                        visible: (item.escolhido && item.model.controlo !== "") || item.cartao
                        anchors.top: cabeca.bottom
                        anchors.topMargin: 2
                        x: 10
                        width: parent.width - 20
                        height: corpo.height + 28
                        radius: 10
                        color: Qt.rgba(1, 1, 1, 0.055)
                        readonly property var d: {
                            try { return item.model.dados ? JSON.parse(item.model.dados) : ({}); } catch (e) { return ({}); }
                        }
                        Column {
                            id: corpo
                            x: 16; y: 14
                            width: parent.width - 32
                            spacing: 6

                            // controlo deslizante (volume, brilho) ou interruptor (Wi-Fi, Bluetooth, mudo)
                            Text { visible: item.model.controlo !== ""; text: item.model.rotulo; color: janela.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
                            Text { visible: item.model.descricao !== "" && item.model.controlo !== ""; width: parent.width; wrapMode: Text.WordWrap; text: item.model.descricao; color: janela.suave; font.pixelSize: 12 }
                            Slider {
                                id: desl
                                visible: item.model.controlo === "deslizante"
                                width: parent.width
                                from: 0; to: 1
                                value: item.model.valor
                                onMoved: comando.definirValor(item.index, value)
                                background: Rectangle {
                                    x: desl.leftPadding
                                    y: desl.topPadding + desl.availableHeight / 2 - height / 2
                                    width: desl.availableWidth; height: 4; radius: 2
                                    color: Qt.rgba(1, 1, 1, 0.25)
                                    Rectangle { width: desl.visualPosition * parent.width; height: parent.height; radius: 2; color: janela.realce }
                                }
                                handle: Rectangle {
                                    x: desl.leftPadding + desl.visualPosition * (desl.availableWidth - width)
                                    y: desl.topPadding + desl.availableHeight / 2 - height / 2
                                    width: 18; height: 18; radius: 9
                                    color: "#2b2a35"
                                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.3)
                                    Rectangle { anchors.centerIn: parent; width: desl.pressed ? 12 : 9; height: width; radius: width / 2; color: janela.realce }
                                }
                            }
                            Switch {
                                visible: item.model.controlo === "interruptor"
                                checked: item.model.valor > 0.5
                                text: checked ? "Ligado" : "Desligado"
                                onToggled: comando.definirValor(item.index, checked ? 1 : 0)
                            }

                            // cartão do tempo
                            Item {
                                visible: item.model.tipo === "tempo"
                                width: parent.width; height: 120
                                Column {
                                    spacing: 2
                                    Text { text: (detalhe.d.cidade || "") + " · " + (detalhe.d.hora || ""); color: janela.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
                                    Text { text: "°C"; color: janela.suave; font.pixelSize: 12 }
                                    Row {
                                        spacing: 14
                                        Text { text: (detalhe.d.temp || "–") + "°"; color: janela.texto; font.pixelSize: 54; font.weight: Font.DemiBold }
                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text { text: "Máx. " + (detalhe.d.max || "–") + "°  ·  Mín. " + (detalhe.d.min || "–") + "°"; color: janela.texto; font.pixelSize: 13 }
                                            Text { text: detalhe.d.desc || ""; color: janela.suave; font.pixelSize: 13 }
                                        }
                                    }
                                }
                                Image {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 84; height: 84
                                    sourceSize: Qt.size(168, 168)
                                    source: "image://icone/" + (/^(113)$/.test(detalhe.d.codigo || "") ? "weather-clear"
                                        : /^(116|119)$/.test(detalhe.d.codigo || "") ? "weather-few-clouds"
                                        : /^(122|143|248|260)$/.test(detalhe.d.codigo || "") ? "weather-overcast"
                                        : /^(2|3)/.test(detalhe.d.codigo || "") ? "weather-showers" : "weather-few-clouds")
                                }
                            }

                            // cartão do uso do computador
                            Row {
                                visible: item.model.tipo === "estado"
                                spacing: 22
                                Repeater {
                                    model: [["CPU", detalhe.d.cpu || "—", ""],
                                            ["Memória", detalhe.d.memoria || "—", detalhe.d.memoriaTotal || ""],
                                            ["Disco livre", detalhe.d.disco || "—", detalhe.d.discoTotal || ""]]
                                    delegate: Column {
                                        required property var modelData
                                        Text { text: parent.modelData[0]; color: janela.suave; font.pixelSize: 12 }
                                        Text { text: parent.modelData[1]; color: janela.texto; font.pixelSize: 24; font.weight: Font.DemiBold }
                                        Text { text: parent.modelData[2]; color: janela.suave; font.pixelSize: 11 }
                                    }
                                }
                            }
                            Text {
                                visible: item.model.tipo === "estado" && (detalhe.d.topCpu || []).length > 0
                                text: "A gastar mais agora: " + (detalhe.d.topCpu || []).map(p => p.nome + " " + p.valor).join(" · ")
                                color: janela.suave; font.pixelSize: 12; width: parent.width; elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            // ---- correções (palavras parecidas com a última escrita) ------------------------------
            Item {
                width: parent.width
                height: chips.visible ? 34 : 0
                Rectangle {
                    id: chips
                    visible: comando.correcoes.length > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 32
                    width: linhaChips.width + 14
                    radius: 8
                    color: Qt.rgba(0.2, 0.19, 0.26, 0.98)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    Row {
                        id: linhaChips
                        anchors.centerIn: parent
                        spacing: 4
                        Repeater {
                            model: comando.correcoes
                            delegate: Rectangle {
                                required property string modelData
                                width: tc.implicitWidth + 20; height: 24; radius: 6
                                color: mc.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                Text { id: tc; anchors.centerIn: parent; text: parent.modelData; color: janela.texto; font.pixelSize: 13 }
                                MouseArea { id: mc; anchors.fill: parent; hoverEnabled: true; onClicked: janela.usarCorrecao(parent.modelData) }
                            }
                        }
                    }
                }
            }

            // ---- caixa de pesquisa, em baixo -----------------------------------------------------------
            Rectangle {
                width: parent.width
                height: 92
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: busca.activeFocus ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)

                TextField {
                    id: busca
                    x: 8; y: 6
                    width: parent.width - 16
                    background: Item {}
                    color: janela.texto
                    font.pixelSize: 15
                    placeholderText: comando.modo === "clip" ? "Procurar no que copiou…" : "Pesquise aplicativos, arquivos, configurações ou peça uma ação"
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.4)
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
                        else if (ev.key === Qt.Key_Tab && comando.correcoes.length > 0) { janela.usarCorrecao(comando.correcoes[0]); ev.accepted = true; }
                        else if (ctrl && ev.key >= Qt.Key_1 && ev.key <= Qt.Key_9) {
                            const i = ev.key - Qt.Key_1;
                            if (i < modelo.count) janela.executar(i);
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
                Text {
                    x: 16
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    text: comando.modo === "clip" ? "Área de transferência · Esc volta" : "Ctrl+K: mais opções · Tab: corrigir"
                    color: Qt.rgba(1, 1, 1, 0.32)
                    font.pixelSize: 11
                }
                // botão principal (Abrir, Diminuir, Aplicar…)
                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    visible: janela.selecionado !== null && janela.selecionado.tipo !== "nada"
                    width: rotuloBotao.implicitWidth + 30
                    height: 32
                    radius: 7
                    color: mb.pressed ? Qt.darker(janela.realce, 1.2) : (mb.containsMouse ? Qt.lighter(janela.realce, 1.08) : janela.realce)
                    Text { id: rotuloBotao; anchors.centerIn: parent; text: janela.selecionado ? janela.selecionado.botao : ""; color: "#081428"; font.pixelSize: 14; font.weight: Font.DemiBold }
                    MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: janela.executar(janela.atual) }
                }
            }
        }

        // ---- mais opções (··· ou Ctrl+K) ------------------------------------------------------------
        Rectangle {
            visible: janela.emAcoes
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 108
            width: 280
            height: colAcoes.height + 12
            radius: 10
            color: Qt.rgba(0.17, 0.16, 0.22, 0.99)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.14)
            Column {
                id: colAcoes
                x: 6; y: 6
                width: parent.width - 12
                Repeater {
                    model: janela.listaAcoes
                    delegate: Rectangle {
                        id: ac
                        required property var modelData
                        required property int index
                        width: colAcoes.width
                        height: 36
                        radius: 7
                        color: index === janela.acaoAtual ? Qt.rgba(1, 1, 1, 0.09) : "transparent"
                        Image { id: aic; x: 10; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; sourceSize: Qt.size(32, 32); source: "image://icone/" + ac.modelData.icone }
                        Text { anchors.left: aic.right; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: ac.modelData.nome; color: janela.texto; font.pixelSize: 13 }
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
