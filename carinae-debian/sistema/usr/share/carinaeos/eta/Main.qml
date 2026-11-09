// CarinaeOS - Eta: conversa com a assistente do sistema
import QtQuick
import QtQuick.Controls
import QtQuick.Window

ApplicationWindow {
    id: janela
    width: 520
    height: 760
    minimumWidth: 420
    minimumHeight: 520
    visible: true
    title: "Eta"
    color: "#0d0a14"

    readonly property color ambar: "#ffb46e"
    readonly property color rosa: "#ff6f91"
    readonly property color texto: "#f4eee8"
    readonly property color textoSuave: "#b3a9c2"
    readonly property color bolhaEta: "#1c1729"
    readonly property color bolhaEu: "#3a2a52"

    font.family: "Inter"
    font.pixelSize: 14

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#17112a" }
            GradientStop { position: 1.0; color: "#0a0810" }
        }
    }

    // ---- topo -------------------------------------------------------------------
    Rectangle {
        id: topo
        width: parent.width; height: 74
        color: Qt.rgba(1, 1, 1, 0.03)
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }

        Image {
            id: avatar
            x: 18; anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 44
            source: "image://icone/carinaeos-eta"; sourceSize: Qt.size(88, 88)
            SequentialAnimation on scale {
                running: eta.pensando
                loops: Animation.Infinite
                NumberAnimation { to: 1.12; duration: 520; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 520; easing.type: Easing.InOutSine }
            }
        }
        Column {
            anchors.left: avatar.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
            Text { text: "Eta"; color: janela.texto; font.pixelSize: 19; font.weight: Font.Bold }
            Text {
                text: eta.pensando ? "a pensar…" :
                      eta.estado === "pronta" ? "assistente do CarinaeOS · IA ligada" :
                      eta.estado === "a-iniciar" ? "a acordar a IA…" :
                      eta.estado === "a-baixar" ? "a baixar o cérebro…" : "assistente do CarinaeOS"
                color: eta.pensando ? janela.ambar : janela.textoSuave; font.pixelSize: 12
            }
        }
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 34; radius: 17
            color: limparRato.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            Image { anchors.centerIn: parent; width: 18; height: 18; source: "image://icone/edit-clear-history"; sourceSize: Qt.size(36, 36) }
            MouseArea { id: limparRato; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: eta.limpar() }
            ToolTip.visible: limparRato.containsMouse; ToolTip.text: "Limpar conversa"
        }
    }

    // ---- aviso: ativar a IA completa ----------------------------------------------------
    Rectangle {
        id: aviso
        visible: eta.estado === "sem-modelo" || eta.estado === "a-baixar" || eta.estado === "erro"
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
                text: eta.estado === "a-baixar" ? "A baixar o cérebro da Eta… " + Math.round(eta.baixado * 100) + "%"
                    : eta.estado === "erro" ? "A IA não conseguiu arrancar neste computador. Continuo a ajudar com arquivos e guias."
                    : "Ative a IA completa para conversar sobre qualquer assunto do sistema. Baixa 1,1 GB uma única vez e funciona sem internet depois."
            }
            Rectangle {
                visible: eta.estado === "a-baixar"
                width: parent.width; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.2)
                Rectangle { width: parent.width * eta.baixado; height: parent.height; radius: 3; color: janela.ambar; Behavior on width { NumberAnimation { duration: 300 } } }
            }
            Rectangle {
                visible: eta.estado === "sem-modelo"
                width: 150; height: 32; radius: 16; color: "white"
                Text { anchors.centerIn: parent; text: "Ativar a IA"; color: "#2a1640"; font.weight: Font.Bold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: eta.baixarCerebro() }
            }
        }
    }

    // ---- conversa ------------------------------------------------------------------------
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
            width: lista.width
            height: bolha.height

            Rectangle {
                id: bolha
                x: linha.meu ? lista.width - width - 14 : 14
                width: linha.meu ? Math.min(lista.width * 0.78, corpo.implicitWidth + 28)
                                 : lista.width - 28
                height: conteudo.implicitHeight + 24
                radius: 18
                color: linha.meu ? janela.bolhaEu : janela.bolhaEta
                border.color: linha.m.papel === "pedido" ? Qt.rgba(1, 0.7, 0.43, 0.45) : Qt.rgba(1, 1, 1, 0.06)

                Column {
                    id: conteudo
                    x: 14; y: 12; width: parent.width - 28; spacing: 10

                    Text {
                        id: corpo
                        width: linha.meu ? Math.min(implicitWidth, lista.width * 0.78 - 28) : parent.width
                        text: linha.m.texto
                        color: janela.texto
                        wrapMode: Text.WordWrap
                        textFormat: Text.PlainText
                        lineHeight: 1.18
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
                                            { ic: "object-locked", dica: "Bloquear com senha", acao: 2 }
                                        ]
                                        delegate: Rectangle {
                                            required property var modelData
                                            required property int index
                                            width: 30; height: 30; radius: 15
                                            color: br.containsMouse ? Qt.rgba(1, 0.7, 0.43, 0.25) : "transparent"
                                            Image { anchors.centerIn: parent; width: 16; height: 16; source: "image://icone/" + modelData.ic; sourceSize: Qt.size(32, 32) }
                                            MouseArea {
                                                id: br
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const c = arq.modelData.caminho;
                                                    if (modelData.acao === 0) eta.abrirArquivo(c);
                                                    else if (modelData.acao === 1) eta.mostrarNaPasta(c);
                                                    else eta.bloquearArquivo(c);
                                                }
                                            }
                                            ToolTip.visible: br.containsMouse; ToolTip.text: modelData.dica
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // escolhas (discos, redes Wi-Fi…) com botões
                    Column {
                        visible: linha.m.papel === "escolhas"
                        width: parent.width; spacing: 4
                        Repeater {
                            model: linha.m.papel === "escolhas" ? linha.m.opcoes : []
                            delegate: Rectangle {
                                id: op
                                required property var modelData
                                width: parent.width; height: 52; radius: 10
                                color: Qt.rgba(1, 1, 1, 0.04)
                                Image { id: oi; x: 10; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; source: "image://icone/" + op.modelData.icone; sourceSize: Qt.size(60, 60) }
                                Column {
                                    anchors.left: oi.right; anchors.leftMargin: 10; anchors.right: obotoes.left; anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { width: parent.width; text: op.modelData.nome; color: janela.texto; elide: Text.ElideRight; font.pixelSize: 13; font.weight: Font.DemiBold }
                                    Text { width: parent.width; text: op.modelData.detalhe; color: janela.textoSuave; elide: Text.ElideRight; font.pixelSize: 11 }
                                }
                                Row {
                                    id: obotoes
                                    anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                    spacing: 6
                                    Repeater {
                                        model: op.modelData.botoes
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: bt.implicitWidth + 24; height: 30; radius: 15
                                            color: btRato.containsMouse ? Qt.rgba(1, 0.7, 0.43, 0.3) : Qt.rgba(1, 1, 1, 0.08)
                                            border.color: Qt.rgba(1, 0.7, 0.43, 0.4)
                                            Text { id: bt; anchors.centerIn: parent; text: modelData.rotulo; color: janela.texto; font.pixelSize: 12; font.weight: Font.DemiBold }
                                            MouseArea { id: btRato; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: eta.escolher(linha.m.id, modelData.n) }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // pedido de permissão
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
                            }
                        }
                        Row {
                            visible: linha.m.estado === "pendente"
                            spacing: 10
                            Rectangle {
                                width: 110; height: 34; radius: 17
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: janela.rosa }
                                    GradientStop { position: 1; color: janela.ambar }
                                }
                                Text { anchors.centerIn: parent; text: "Permitir"; color: "#1a0f14"; font.weight: Font.Bold }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: eta.permitir(linha.m.id) }
                            }
                            Rectangle {
                                width: 110; height: 34; radius: 17
                                color: recRato.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: Qt.rgba(1, 1, 1, 0.14)
                                Text { anchors.centerIn: parent; text: "Recusar"; color: janela.texto; font.weight: Font.DemiBold }
                                MouseArea { id: recRato; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: eta.recusar(linha.m.id) }
                            }
                        }
                        Text {
                            visible: linha.m.estado !== "pendente" && linha.m.papel === "pedido"
                            text: linha.m.estado === "feito" ? "✓ Feito" :
                                  linha.m.estado === "a-executar" ? "A executar…" :
                                  linha.m.estado === "recusado" ? "Recusado — nada foi feito." : "✕ Não funcionou"
                            color: linha.m.estado === "feito" ? "#8fe3a8" : linha.m.estado === "falhou" ? janela.rosa : janela.textoSuave
                            font.pixelSize: 13; font.weight: Font.DemiBold
                        }
                        Text {
                            visible: (linha.m.saida || "") !== ""
                            width: parent.width
                            text: linha.m.saida || ""
                            color: janela.textoSuave; font.family: "monospace"; font.pixelSize: 11
                            wrapMode: Text.WrapAnywhere; maximumLineCount: 12; elide: Text.ElideRight
                        }
                    }
                }
            }
        }
    }

    // ---- sugestões (só no início) --------------------------------------------------------
    Flow {
        id: sugestoes
        anchors.bottom: entrada.top; anchors.bottomMargin: 10
        anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 14; anchors.rightMargin: 14
        spacing: 8
        visible: eta.mensagens.length <= 1
        height: visible ? implicitHeight : 0
        Repeater {
            model: ["Encontre o meu currículo", "Verificar atualizações", "Abrir o HD externo", "Como mudo o fundo de tela?", "Quanto espaço tenho livre?", "Ligar a luz noturna"]
            delegate: Rectangle {
                required property string modelData
                width: sugTxt.implicitWidth + 24; height: 32; radius: 16
                color: sugRato.containsMouse ? Qt.rgba(1, 0.7, 0.43, 0.2) : Qt.rgba(1, 1, 1, 0.06)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                Text { id: sugTxt; anchors.centerIn: parent; text: modelData; color: janela.texto; font.pixelSize: 12 }
                MouseArea { id: sugRato; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: eta.enviar(modelData) }
            }
        }
    }

    // ---- caixa de texto --------------------------------------------------------------------
    Rectangle {
        id: entrada
        anchors.bottom: parent.bottom; anchors.bottomMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - 28; height: 50; radius: 25
        color: Qt.rgba(1, 1, 1, campo.activeFocus ? 0.1 : 0.06)
        border.color: campo.activeFocus ? Qt.rgba(1, 0.7, 0.43, 0.5) : Qt.rgba(1, 1, 1, 0.12)
        TextField {
            id: campo
            anchors.left: parent.left; anchors.leftMargin: 18
            anchors.right: enviar.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            placeholderText: eta.dicaEntrada
            echoMode: eta.pedeSenha ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            placeholderTextColor: janela.textoSuave
            color: janela.texto
            background: Item {}
            focus: true
            onAccepted: { eta.enviar(text); text = "" }
            Component.onCompleted: forceActiveFocus()
        }
        Rectangle {
            id: enviar
            anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter
            width: 36; height: 36; radius: 18
            opacity: campo.text.length > 0 && !eta.pensando ? 1 : 0.4
            gradient: Gradient {
                GradientStop { position: 0; color: janela.rosa }
                GradientStop { position: 1; color: janela.ambar }
            }
            Text { anchors.centerIn: parent; text: "↑"; color: "#1a0f14"; font.pixelSize: 18; font.weight: Font.Bold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { eta.enviar(campo.text); campo.text = "" } }
        }
    }
}
