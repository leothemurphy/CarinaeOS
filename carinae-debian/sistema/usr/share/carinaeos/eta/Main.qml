// CarinaeOS - Eta: conversa com a assistente do sistema (escrita, voz e arquivos)
import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Window

ApplicationWindow {
    id: janela
    width: 540
    height: 680
    minimumWidth: 420
    minimumHeight: 520
    visible: !arranqueSoNuvem
    title: "Eta"
    color: "#0d0a14"

    readonly property color ambar: "#ffb46e"
    readonly property color rosa: "#ff6f91"
    readonly property color texto: "#f4eee8"
    readonly property color textoSuave: "#b3a9c2"
    readonly property color bolhaEta: "#1c1729"
    readonly property color bolhaEu: "#3a2a52"
    readonly property color verde: "#8fe3a8"

    font.family: "Inter"
    font.pixelSize: 14

    // fechar a janela nao para o que esta a fazer: a nuvem continua a mostrar
    // fechar a janela fecha a Eta (e a IA sai da memoria), a nao ser que esteja a trabalhar
    // ou que o usuario tenha pedido para a manter em segundo plano
    onClosing: (fecho) => {
        if (eta.ocupada || eta.segundoPlano) { fecho.accepted = false; janela.visible = false }
        else Qt.quit()
    }

    // copiar texto para a area de transferencia
    TextEdit { id: copiador; visible: false }
    function copiar(t) { copiador.text = t; copiador.selectAll(); copiador.copy() }

    // menu do botão direito: copiar / colar / selecionar tudo
    Menu {
        id: menuTexto
        property var alvo: null
        property bool editavel: false
        function abrir(item) { alvo = item; editavel = !item.readOnly; popup() }
        MenuItem { text: "Cortar"; visible: menuTexto.editavel; height: visible ? implicitHeight : 0; onTriggered: menuTexto.alvo.cut() }
        MenuItem { text: "Copiar"; enabled: menuTexto.alvo && menuTexto.alvo.selectedText !== ""; onTriggered: menuTexto.alvo.copy() }
        MenuItem { text: "Copiar tudo"; onTriggered: janela.copiar(menuTexto.alvo.text) }
        MenuItem { text: "Colar"; visible: menuTexto.editavel; height: visible ? implicitHeight : 0; onTriggered: menuTexto.alvo.paste() }
        MenuItem { text: "Selecionar tudo"; onTriggered: menuTexto.alvo.selectAll() }
    }

    FileDialog {
        id: escolherArquivo
        title: "Enviar arquivos para a Eta"
        fileMode: FileDialog.OpenFiles
        onAccepted: eta.anexar(selectedFiles)
    }
    FolderDialog {
        id: escolherPasta
        property string arquivo: ""
        title: "Guardar em…"
        onAccepted: eta.guardarEm(arquivo, selectedFolder.toString())
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#17112a" }
            GradientStop { position: 1.0; color: "#0a0810" }
        }
    }

    // arrastar arquivos para a janela
    DropArea {
        id: soltar
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: (d) => { if (d.hasUrls) { eta.anexar(d.urls); d.accept() } }
        Rectangle {
            anchors.fill: parent; anchors.margins: 10; radius: 20; z: 50
            visible: soltar.containsDrag
            color: Qt.rgba(1, 0.7, 0.43, 0.12); border.color: janela.ambar; border.width: 2
            Text { anchors.centerIn: parent; text: "Solte aqui para a Eta ler"; color: janela.ambar; font.pixelSize: 18; font.weight: Font.DemiBold }
        }
    }

    // ---- topo ---------------------------------------------------------------------------
    Rectangle {
        id: topo
        width: parent.width; height: 74
        color: Qt.rgba(1, 1, 1, 0.03)
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }

        Orbe {
            id: avatar
            x: 16; anchors.verticalCenter: parent.verticalCenter
            width: 46; height: 46
            ativo: eta.ocupada
            nivel: eta.ouvindo ? eta.nivelVoz : 0
        }
        Column {
            anchors.left: avatar.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
            anchors.right: botoesTopo.left; anchors.rightMargin: 8
            Text { text: "Eta"; color: janela.texto; font.pixelSize: 19; font.weight: Font.Bold }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: eta.atividade !== "" ? eta.atividade :
                      eta.nuvemCfg.ligada || eta.estado === "pronta" ? "assistente do CarinaeOS · " + eta.nomeCerebro :
                          eta.estado === "desligada" ? "IA desligada · tarefas simples" :
                      eta.estado === "a-iniciar" ? "a acordar a IA…" :
                      eta.estado === "a-baixar" ? "a baixar…" : "assistente do CarinaeOS"
                color: eta.atividade !== "" ? janela.ambar : janela.textoSuave; font.pixelSize: 12
            }
        }
        Row {
            id: botoesTopo
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            BotaoRedondo {
                visible: eta.ocupada
                icone: "media-playback-stop"; dica: "Parar tudo"; destaque: true
                onClicado: eta.parar()
            }
            BotaoRedondo {
                icone: "configure"; dica: "Como a Eta trabalha"
                onClicado: menuModo.popup()
                Menu {
                    id: menuModo
                    MenuItem { enabled: false; text: "Quando eu pedir uma tarefa:" }
                    MenuItem { text: (eta.modo === "perguntar" ? "✓ " : "    ") + "Perguntar se faz ou se mostra os comandos"; onTriggered: eta.definirModo("perguntar") }
                    MenuItem { text: (eta.modo === "fazer" ? "✓ " : "    ") + "Fazer sempre por mim"; onTriggered: eta.definirModo("fazer") }
                    MenuItem { text: (eta.modo === "comandos" ? "✓ " : "    ") + "Só mostrar os comandos"; onTriggered: eta.definirModo("comandos") }
                    MenuSeparator {}
                    MenuItem { text: (eta.falar ? "✓ " : "    ") + "Responder em voz alta quando falo"; onTriggered: eta.definirFalar(!eta.falar) }
                    MenuSeparator {}
                    MenuItem { text: "Cérebro da Eta (leve, completo ou na nuvem)…"; onTriggered: dialogoCerebro.open() }
                    MenuItem { text: eta.iaLigada ? "Desligar a IA (liberta a memória)" : "Ligar a IA"; onTriggered: eta.definirIA(!eta.iaLigada) }
                    MenuItem { text: "Manter a Eta aberta em segundo plano"; checkable: true; checked: eta.segundoPlano; onTriggered: eta.definirSegundoPlano(checked) }
                    MenuSeparator {}
                    MenuItem { text: "O que a Eta aprendeu"; onTriggered: eta.enviar("o que você aprendeu?") }
                    MenuItem { text: "Esquecer as respostas guardadas"; onTriggered: eta.enviar("esquece as respostas") }
                    MenuItem { text: "Limpar a conversa"; onTriggered: eta.limpar() }
                }
            }
        }
    }

    // ---- aviso: ativar a IA / a voz ----------------------------------------------------------
    Rectangle {
        id: aviso
        readonly property bool mostrar: (eta.estado === "sem-modelo" && !eta.nuvemCfg.ligada) || eta.estado === "a-baixar" || eta.estado === "erro" || eta.faltaVoz || eta.cerebroAntigo
        visible: mostrar
        anchors.top: topo.bottom; anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 28; height: visible ? avisoCol.implicitHeight + 24 : 0
        radius: 16
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#3b2470" }
            GradientStop { position: 1; color: "#7a2f6b" }
        }
        Column {
            id: avisoCol
            x: 16; y: 12; width: parent.width - 32; spacing: 8
            Text {
                width: parent.width; wrapMode: Text.WordWrap; color: "white"; font.pixelSize: 13
                text: eta.estado === "a-baixar" ? "A baixar a IA e a voz da Eta… " + Math.round(eta.baixado * 100) + "% (pode continuar a usar o computador)"
                    : eta.estado === "erro" ? "A IA não conseguiu arrancar neste computador. Continuo a ajudar com arquivos, guias e tarefas."
                    : eta.cerebroAntigo ? "Há um cérebro novo para a Eta, muito mais inteligente (entende melhor o que pede). Baixa " + eta.tamanhoFalta + " uma vez."
                    : eta.estado === "sem-modelo" ? "Ative a IA completa e a voz: baixa " + eta.tamanhoFalta + " uma única vez e depois funciona sem internet, sem enviar nada para fora do computador. (Ou ligue um cérebro na nuvem em ⚙.)"
                    : "Ative a voz para falar comigo: baixa 150 MB uma única vez."
            }
            Rectangle {
                visible: eta.estado === "a-baixar"
                width: parent.width; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.2)
                Rectangle { width: parent.width * eta.baixado; height: parent.height; radius: 3; color: janela.ambar; Behavior on width { NumberAnimation { duration: 300 } } }
            }
            Rectangle {
                visible: eta.estado !== "a-baixar" && eta.estado !== "erro"
                width: ativarTxt.implicitWidth + 32; height: 32; radius: 16; color: "white"
                Text { id: ativarTxt; anchors.centerIn: parent; text: eta.cerebroAntigo ? "Atualizar o cérebro" : eta.estado === "sem-modelo" ? "Ativar a IA e a voz" : "Ativar a voz"; color: "#2a1640"; font.weight: Font.Bold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: eta.baixarCerebro() }
            }
        }
    }

    // ---- conversa -----------------------------------------------------------------------------
    ListView {
        id: lista
        anchors.top: aviso.visible ? aviso.bottom : topo.bottom
        anchors.topMargin: 10
        anchors.bottom: sugestoes.top
        anchors.left: parent.left; anchors.right: parent.right
        clip: true
        spacing: 12
        model: eta.mensagens
        onCountChanged: Qt.callLater(() => lista.positionViewAtEnd())
        onContentHeightChanged: if (atEnd || eta.ocupada) Qt.callLater(() => lista.positionViewAtEnd())
        readonly property bool atEnd: contentY + height >= contentHeight - 80
        header: Item { height: 6 }
        footer: Item {
            height: eta.pensando ? 46 : 10
            width: lista.width
            Row {
                visible: eta.pensando
                x: 18; y: 8; spacing: 6
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: 8; height: 8; radius: 4; color: janela.ambar
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite; running: eta.pensando
                            PauseAnimation { duration: index * 160 }
                            NumberAnimation { to: 0.2; duration: 380 }
                            NumberAnimation { to: 1; duration: 380 }
                        }
                    }
                }
            }
        }

        delegate: Item {
            id: linha
            required property var modelData
            readonly property var m: modelData
            readonly property bool meu: m.papel === "eu"
            readonly property bool simples: m.papel === "feito"
            width: lista.width
            height: bolha.height

            HoverHandler { id: sobreLinha }
            BotaoRedondo {
                z: 5
                visible: sobreLinha.hovered && (linha.m.texto || "") !== "" && !linha.m.escrevendo
                tamanho: 26; icone: "edit-copy"; dica: "Copiar a mensagem"
                anchors.top: bolha.top; anchors.topMargin: -6
                x: linha.meu ? bolha.x - width + 6 : bolha.x + bolha.width - width + 6
                color: Qt.rgba(0.2, 0.16, 0.28, 0.95)
                onClicado: janela.copiar(linha.m.texto + ((linha.m.codigo || "") !== "" ? "\n\n" + linha.m.codigo : ""))
            }
            Rectangle {
                id: bolha
                x: linha.meu ? lista.width - width - 14 : 14
                width: linha.meu ? Math.min(lista.width * 0.78, corpo.implicitWidth + 28)
                     : linha.simples ? Math.min(lista.width - 28, corpo.implicitWidth + 28) : lista.width - 28
                height: conteudo.implicitHeight + (linha.simples ? 16 : 24)
                radius: linha.simples ? 14 : 18
                color: linha.meu ? janela.bolhaEu : linha.simples ? Qt.rgba(0.56, 0.89, 0.66, 0.1) : janela.bolhaEta
                border.color: linha.m.papel === "pedido" && linha.m.estado === "pendente" ? Qt.rgba(1, 0.7, 0.43, 0.55)
                            : linha.simples ? Qt.rgba(0.56, 0.89, 0.66, 0.3) : Qt.rgba(1, 1, 1, 0.06)

                Column {
                    id: conteudo
                    x: 14; y: linha.simples ? 8 : 12; width: parent.width - 28; spacing: 10

                    // texto da mensagem: dá para selecionar com o rato e copiar (Ctrl+C ou botão direito)
                    TextEdit {
                        id: corpo
                        visible: text !== ""
                        readonly property real larguraNatural: medida.implicitWidth
                        width: linha.meu || linha.simples ? Math.min(larguraNatural + 2, lista.width * 0.78 - 28) : parent.width
                        text: (linha.m.voz ? "🎤 " : "") + linha.m.texto + (linha.m.escrevendo ? " ▍" : "")
                        color: linha.simples ? janela.verde : janela.texto
                        selectionColor: Qt.rgba(1, 0.7, 0.43, 0.45)
                        selectedTextColor: "white"
                        wrapMode: Text.WordWrap
                        textFormat: TextEdit.PlainText
                        readOnly: true
                        selectByMouse: true
                        font: janela.font
                        Text { id: medida; visible: false; text: corpo.text; font: corpo.font }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: menuTexto.abrir(corpo)
                        }
                    }

                    // botões por baixo da mensagem (ex.: "Abrir as configurações de tela")
                    Flow {
                        visible: linha.m.papel === "eta" && (linha.m.botoes || []).length > 0
                        width: parent.width; spacing: 6
                        Repeater {
                            model: linha.m.papel === "eta" ? (linha.m.botoes || []) : []
                            delegate: Pilula {
                                required property var modelData
                                texto: modelData.rotulo
                                onClicado: eta.escolher(linha.m.id, modelData.n)
                            }
                        }
                    }

                    // bloco de comandos (terminal)
                    Rectangle {
                        visible: (linha.m.codigo || "") !== ""
                        width: parent.width; height: visible ? codTxt.implicitHeight + 52 : 0
                        radius: 10; color: "#0b0910"; border.color: Qt.rgba(1, 1, 1, 0.08)
                        TextEdit {
                            id: codTxt
                            x: 12; y: 10; width: parent.width - 24
                            text: linha.m.codigo || ""
                            readOnly: true; selectByMouse: true
                            selectionColor: Qt.rgba(1, 0.7, 0.43, 0.45)
                            color: "#d9cfe6"; font.family: "monospace"; font.pixelSize: 12; wrapMode: Text.WrapAnywhere
                            MouseArea { anchors.fill: parent; acceptedButtons: Qt.RightButton; onClicked: menuTexto.abrir(codTxt) }
                        }
                        Row {
                            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
                            spacing: 6
                            Pilula { texto: "Copiar"; onClicado: { janela.copiar(linha.m.codigo); texto = "Copiado ✓" } }
                            Pilula { texto: "Abrir no terminal"; onClicado: eta.abrirNoTerminal(linha.m.codigo) }
                        }
                    }

                    // lista de arquivos encontrados
                    Column {
                        visible: linha.m.papel === "arquivos"
                        width: parent.width; spacing: 4
                        Repeater {
                            model: linha.m.papel === "arquivos" ? linha.m.arquivos : []
                            delegate: Rectangle {
                                id: arq
                                required property var modelData
                                width: parent.width; height: 48; radius: 10
                                color: arqRato.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.03)
                                MouseArea { id: arqRato; anchors.fill: parent; hoverEnabled: true; onDoubleClicked: eta.abrirArquivo(modelData.caminho) }
                                Image { id: ai; x: 8; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; source: "image://icone/" + modelData.icone; sourceSize: Qt.size(56, 56) }
                                Column {
                                    anchors.left: ai.right; anchors.leftMargin: 10; anchors.right: botoes.left; anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { width: parent.width; text: modelData.nome; color: janela.texto; elide: Text.ElideMiddle; font.pixelSize: 13 }
                                    Text { width: parent.width; text: modelData.pasta; color: janela.textoSuave; elide: Text.ElideMiddle; font.pixelSize: 11 }
                                }
                                Row {
                                    id: botoes
                                    anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2
                                    Repeater {
                                        model: [
                                            { ic: "document-open", dica: "Abrir", acao: 0 },
                                            { ic: "folder-open", dica: "Mostrar na pasta", acao: 1 },
                                            { ic: "view-list-text", dica: "Ler e resumir", acao: 3 },
                                            { ic: "object-locked", dica: "Trancar com senha", acao: 2 }
                                        ]
                                        delegate: BotaoRedondo {
                                            required property var modelData
                                            tamanho: 30; icone: modelData.ic; dica: modelData.dica
                                            onClicado: {
                                                const c = arq.modelData.caminho;
                                                if (modelData.acao === 0) eta.abrirArquivo(c);
                                                else if (modelData.acao === 1) eta.mostrarNaPasta(c);
                                                else if (modelData.acao === 3) eta.resumirArquivo(c);
                                                else eta.bloquearArquivo(c);
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // escolhas (discos, redes Wi-Fi, arquivo enviado…)
                    Column {
                        visible: linha.m.papel === "escolhas"
                        width: parent.width; spacing: 6
                        Repeater {
                            model: linha.m.papel === "escolhas" ? linha.m.opcoes : []
                            delegate: Rectangle {
                                id: op
                                required property var modelData
                                width: parent.width
                                height: opCol.implicitHeight + 20
                                radius: 12
                                color: Qt.rgba(1, 1, 1, 0.04)
                                Column {
                                    id: opCol
                                    x: 10; y: 10; width: parent.width - 20; spacing: 8
                                    Item {
                                        width: parent.width; height: 34
                                        Image { id: oi; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; source: "image://icone/" + op.modelData.icone; sourceSize: Qt.size(60, 60) }
                                        Column {
                                            anchors.left: oi.right; anchors.leftMargin: 10; anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            Text { width: parent.width; text: op.modelData.nome; color: janela.texto; elide: Text.ElideMiddle; font.pixelSize: 13; font.weight: Font.DemiBold }
                                            Text { width: parent.width; text: op.modelData.detalhe; color: janela.textoSuave; elide: Text.ElideRight; font.pixelSize: 11 }
                                        }
                                    }
                                    Repeater {
                                        model: op.modelData.resumo
                                        delegate: Text {
                                            required property string modelData
                                            width: opCol.width; leftPadding: 14
                                            text: "•  " + modelData
                                            color: janela.texto; wrapMode: Text.WordWrap; font.pixelSize: 13; lineHeight: 1.15
                                        }
                                    }
                                    Flow {
                                        width: parent.width; spacing: 6
                                        Repeater {
                                            model: op.modelData.botoes
                                            delegate: Pilula {
                                                required property var modelData
                                                texto: modelData.rotulo
                                                onClicado: {
                                                    if (modelData.especial.startsWith("pasta:")) {
                                                        escolherPasta.arquivo = modelData.especial.substring(6);
                                                        escolherPasta.open();
                                                    } else {
                                                        eta.escolher(linha.m.id, modelData.n);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // tarefa: pedido de permissão ou a decorrer (com andamento e Parar)
                    Column {
                        visible: linha.m.papel === "pedido"
                        width: parent.width; spacing: 10
                        Rectangle {
                            width: parent.width; height: cmd.implicitHeight + 16; radius: 10
                            color: "#0b0910"; border.color: Qt.rgba(1, 1, 1, 0.08)
                            Text {
                                id: cmd
                                x: 10; y: 8; width: parent.width - 20
                                text: "$ " + (linha.m.comando || "")
                                color: "#d9cfe6"; font.family: "monospace"; font.pixelSize: 12; wrapMode: Text.WrapAnywhere
                                maximumLineCount: 4; elide: Text.ElideRight
                            }
                        }
                        Flow {
                            visible: linha.m.estado === "pendente"
                            width: parent.width
                            spacing: 8
                            Rectangle {
                                width: 136; height: 34; radius: 17
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: janela.rosa }
                                    GradientStop { position: 1; color: janela.ambar }
                                }
                                Text { anchors.centerIn: parent; text: "Fazer por mim"; color: "#1a0f14"; font.weight: Font.Bold }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: eta.permitir(linha.m.id) }
                            }
                            Pilula { texto: "Quero os comandos"; altura: 34; onClicado: eta.comandos(linha.m.id) }
                            Rectangle {
                                width: 100; height: 34; radius: 17
                                color: recRato.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: Qt.rgba(1, 1, 1, 0.14)
                                Text { anchors.centerIn: parent; text: "Agora não"; color: janela.texto; font.weight: Font.DemiBold }
                                MouseArea { id: recRato; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: eta.recusar(linha.m.id) }
                            }
                        }
                        // a decorrer: barra (ou animação), etapa atual e Parar
                        Item {
                            visible: linha.m.estado === "a-executar"
                            width: parent.width; height: 34
                            Rectangle {
                                id: barra
                                anchors.left: parent.left; anchors.right: pararBt.left; anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.1); clip: true
                                Rectangle {
                                    visible: (linha.m.progresso || -1) >= 0
                                    height: parent.height; radius: 4
                                    width: parent.width * Math.max(0.02, linha.m.progresso || 0)
                                    gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: janela.rosa } GradientStop { position: 1; color: janela.ambar } }
                                    Behavior on width { NumberAnimation { duration: 250 } }
                                }
                                Rectangle {   // sem percentagem: uma luz a passar
                                    visible: (linha.m.progresso === undefined || linha.m.progresso < 0) && linha.m.estado === "a-executar"
                                    width: parent.width * 0.3; height: parent.height; radius: 4; color: janela.ambar; opacity: 0.8
                                    NumberAnimation on x { from: -barra.width * 0.3; to: barra.width; duration: 1300; loops: Animation.Infinite; running: linha.m.estado === "a-executar" }
                                }
                            }
                            Pilula { id: pararBt; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; texto: "Parar"; onClicado: eta.cancelar(linha.m.id) }
                        }
                        Text {
                            visible: linha.m.estado === "a-executar" && (linha.m.etapa || "") !== ""
                            width: parent.width; elide: Text.ElideRight
                            text: ((linha.m.progresso || -1) >= 0 ? Math.round(linha.m.progresso * 100) + "% · " : "") + (linha.m.etapa || "")
                            color: janela.ambar; font.pixelSize: 12
                        }
                        Text {
                            visible: linha.m.estado !== "pendente" && linha.m.estado !== "a-executar"
                            text: linha.m.estado === "feito" ? "✓ Feito" :
                                  linha.m.estado === "recusado" ? "Recusado — nada foi feito." :
                                  linha.m.estado === "comandos" ? "Mostrei os comandos para fazer você mesmo ↓" :
                                  linha.m.estado === "cancelado" ? "Parado." : "✕ Não funcionou"
                            color: linha.m.estado === "feito" ? janela.verde : linha.m.estado === "falhou" ? janela.rosa : linha.m.estado === "comandos" ? janela.ambar : janela.textoSuave
                            font.pixelSize: 13; font.weight: Font.DemiBold
                        }
                        Text {
                            id: saidaTxt
                            property bool aberta: linha.m.estado === "a-executar" || linha.m.estado === "falhou"
                            visible: (linha.m.saida || "") !== ""
                            width: parent.width
                            text: linha.m.saida || ""
                            color: janela.textoSuave; font.family: "monospace"; font.pixelSize: 11
                            wrapMode: Text.WrapAnywhere; maximumLineCount: aberta ? 8 : 3; elide: Text.ElideLeft
                            MouseArea { anchors.fill: parent; onClicked: saidaTxt.aberta = !saidaTxt.aberta }
                        }
                    }
                }
            }
        }
    }

    // ---- sugestões (só no início) --------------------------------------------------------------
    Flow {
        id: sugestoes
        anchors.bottom: entrada.top; anchors.bottomMargin: 10
        anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 14; anchors.rightMargin: 14
        spacing: 8
        visible: eta.mensagens.length <= 1
        height: visible ? implicitHeight : 0
        Repeater {
            model: ["Encontre o meu currículo", "Verificar atualizações", "Abrir o HD externo", "Como vejo o espaço livre pelo terminal?", "Ligar a luz noturna", "Instala o GIMP"]
            delegate: Pilula {
                required property string modelData
                texto: modelData; altura: 32
                onClicado: eta.enviar(modelData)
            }
        }
    }

    // ---- caixa de texto, 📎 e 🎤 ------------------------------------------------------------------
    Rectangle {
        id: entrada
        anchors.bottom: parent.bottom; anchors.bottomMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 28; height: 50; radius: 25
        color: Qt.rgba(1, 1, 1, campo.activeFocus ? 0.1 : 0.06)
        border.color: eta.ouvindo ? janela.rosa : campo.activeFocus ? Qt.rgba(1, 0.7, 0.43, 0.5) : Qt.rgba(1, 1, 1, 0.12)
        BotaoRedondo {
            id: clipe
            anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter
            tamanho: 34; icone: "mail-attachment"; dica: "Enviar um arquivo para a Eta ler e resumir"
            onClicado: escolherArquivo.open()
        }
        TextField {
            id: campo
            anchors.left: clipe.right; anchors.leftMargin: 4
            anchors.right: micro.left; anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            placeholderText: eta.ouvindo ? "A ouvir… fale agora" : eta.dicaEntrada
            echoMode: eta.pedeSenha ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            placeholderTextColor: eta.ouvindo ? janela.rosa : janela.textoSuave
            color: janela.texto
            background: Item {}
            focus: true
            selectByMouse: true
            onAccepted: { eta.enviar(text); text = "" }
            Component.onCompleted: forceActiveFocus()
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                cursorShape: Qt.IBeamCursor
                onClicked: menuTexto.abrir(campo)
            }
        }
        // microfone: carregue e fale; carregue outra vez para terminar
        Rectangle {
            id: micro
            anchors.right: enviar.left; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 18
            color: eta.ouvindo ? janela.rosa : microRato.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
            scale: eta.ouvindo ? 1 + eta.nivelVoz * 0.35 : 1
            Behavior on scale { NumberAnimation { duration: 90 } }
            Image { anchors.centerIn: parent; width: 18; height: 18; source: "image://icone/audio-input-microphone"; sourceSize: Qt.size(36, 36) }
            MouseArea { id: microRato; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: eta.ouvir() }
            ToolTip.visible: microRato.containsMouse; ToolTip.text: eta.ouvindo ? "Terminar de falar" : "Falar com a Eta (Meta+Shift+Espaço)"
        }
        Rectangle {
            id: enviar
            anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 18
            opacity: campo.text.length > 0 ? 1 : 0.4
            gradient: Gradient {
                GradientStop { position: 0; color: janela.rosa }
                GradientStop { position: 1; color: janela.ambar }
            }
            Text { anchors.centerIn: parent; text: "↑"; color: "#1a0f14"; font.pixelSize: 18; font.weight: Font.Bold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { eta.enviar(campo.text); campo.text = "" } }
        }
    }

    // ---- a nuvem: janela pequena, sempre por cima, que mostra o que a Eta está a fazer ----------------
    Nuvem {
        id: nuvem
        visible: eta.nuvem && !(janela.visible && janela.active)
        onAbrir: { janela.visible = true; janela.raise(); janela.requestActivate(); eta.fecharNuvem() }
    }

    // ---- cerebro: local ou nuvem ------------------------------------------------------------------
    Popup {
        id: dialogoCerebro
        modal: true; focus: true
        anchors.centerIn: parent
        width: Math.min(parent.width - 30, 440); padding: 20
        property int escolhido: 0
        onOpened: {
            usarNuvem.checked = !!eta.nuvemCfg.ligada
            var i = 0
            for (var k = 0; k < eta.provedores.length; k++) if (eta.provedores[k].id === eta.nuvemCfg.provedor) i = k
            provedor.currentIndex = i
            modeloCampo.text = eta.nuvemCfg.modelo || eta.provedores[i].modelo
            chaveCampo.text = ""
        }
        background: Rectangle { radius: 18; color: "#1d1530"; border.color: Qt.rgba(1, 1, 1, 0.12) }
        contentItem: Column {
            spacing: 12
            Text { text: "Cérebro da Eta"; color: janela.texto; font.pixelSize: 18; font.weight: Font.Bold }
            Text {
                width: parent.width; wrapMode: Text.WordWrap; color: janela.textoSuave; font.pixelSize: 12
                text: "Neste computador: privado e sem internet (" + (eta.estado === "pronta" ? "ligado" : "ainda não instalado") + "). " +
                      "Na nuvem: mais inteligente e rápido em computadores modestos, mas as conversas vão para o serviço escolhido, " +
                      "com a sua própria chave."
            }
            Text { text: "Neste computador"; color: janela.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
            Row {
                spacing: 8
                Repeater {
                    model: [{ id: "leve", t: "Leve · 1,1 GB", d: "≈1,5 GB de memória" }, { id: "completo", t: "Completo · 2,5 GB", d: "≈3 GB de memória, entende melhor" }]
                    delegate: Rectangle {
                        required property var modelData
                        width: 190; height: 54; radius: 12
                        color: eta.modeloEscolhido === modelData.id ? Qt.rgba(1, 0.7, 0.45, 0.25) : Qt.rgba(1, 1, 1, 0.06)
                        border.color: eta.modeloEscolhido === modelData.id ? "#ffb46e" : Qt.rgba(1, 1, 1, 0.1)
                        Column {
                            anchors.centerIn: parent
                            Text { text: modelData.t; color: janela.texto; font.pixelSize: 13; font.weight: Font.DemiBold; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: modelData.d; color: janela.textoSuave; font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: eta.definirModelo(modelData.id) }
                    }
                }
            }
            Text { width: parent.width; wrapMode: Text.WordWrap; color: janela.textoSuave; font.pixelSize: 11
                   text: "O modelo sai sozinho da memória ao fim de 5 minutos sem uso, e quando fecha a Eta." }
            Switch { id: usarNuvem; text: "Usar um cérebro na nuvem"; palette.windowText: janela.texto }
            Column {
                width: parent.width; spacing: 8; enabled: usarNuvem.checked; opacity: enabled ? 1 : 0.45
                ComboBox {
                    id: provedor; width: parent.width
                    model: eta.provedores; textRole: "nome"
                    onActivated: modeloCampo.text = eta.provedores[currentIndex].modelo
                }
                Text {
                    width: parent.width; wrapMode: Text.WordWrap; color: janela.textoSuave; font.pixelSize: 11
                    text: "Onde obter a chave: " + (eta.provedores.length ? eta.provedores[provedor.currentIndex].chaveEm : "")
                }
                TextField {
                    id: chaveCampo; width: parent.width; echoMode: TextInput.Password
                    placeholderText: eta.nuvemCfg.temChave && eta.provedores[provedor.currentIndex].id === eta.nuvemCfg.provedor
                                     ? "Chave guardada (escreva para trocar)" : "Cole aqui a sua chave da API"
                }
                TextField { id: modeloCampo; width: parent.width; placeholderText: "Modelo" }
            }
            Row {
                anchors.right: parent.right; spacing: 8
                Pilula { texto: "Cancelar"; onClicado: dialogoCerebro.close() }
                Pilula {
                    texto: "Guardar"
                    onClicado: {
                        eta.definirNuvem(eta.provedores[provedor.currentIndex].id, chaveCampo.text, modeloCampo.text, usarNuvem.checked)
                        dialogoCerebro.close()
                    }
                }
            }
        }
    }
}
