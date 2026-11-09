// CarinaeOS - Orbita: loja de aplicativos
import QtQuick
import QtQuick.Controls
import QtQuick.Window

ApplicationWindow {
    id: janela
    width: 1180
    height: 780
    minimumWidth: 940
    minimumHeight: 620
    visible: true
    title: "Órbita"
    color: "#0c0a16"

    readonly property color ambar: "#ffb46e"
    readonly property color rosa: "#ff6f91"
    readonly property color azul: "#6f8cff"
    readonly property color texto: "#f4eee8"
    readonly property color textoSuave: "#aea6c4"
    readonly property color cartao: "#17142a"
    readonly property color cartaoHover: "#1f1b36"
    property string secao: "descobrir"
    property string busca: ""

    font.family: "Inter"
    font.pixelSize: 14

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#141233" }
            GradientStop { position: 1.0; color: "#090814" }
        }
    }
    Repeater {
        model: 50
        Rectangle {
            required property int index
            readonly property real r: ((index * 7919) % 97) / 97
            x: ((index * 104729) % 1000) / 1000 * janela.width
            y: ((index * 1299709) % 1000) / 1000 * janela.height
            width: r > 0.85 ? 2.5 : 1.5; height: width; radius: width / 2
            color: "white"; opacity: 0.12 + r * 0.3
        }
    }

    Connections {
        target: orbita
        function onAviso(msg) { aviso.text = msg; avisoCaixa.visible = true; avisoTempo.restart() }
    }

    // ---- componentes ---------------------------------------------------------
    component Botao: Rectangle {
        id: b
        property string rotulo
        property bool principal: true
        signal clicado()
        width: Math.max(96, t.implicitWidth + 32); height: 34; radius: 17
        color: principal ? "transparent" : (r.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
        border.color: principal ? "transparent" : Qt.rgba(1, 1, 1, 0.14)
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            visible: b.principal
            opacity: r.containsMouse ? 1 : 0.92
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: janela.rosa }
                GradientStop { position: 1; color: janela.ambar }
            }
        }
        Text { id: t; anchors.centerIn: parent; text: b.rotulo; color: b.principal ? "#1a0f14" : janela.texto; font.weight: Font.Bold; font.pixelSize: 13 }
        MouseArea { id: r; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicado() }
        scale: r.pressed ? 0.96 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
    }

    component Acao: Item {
        id: ac
        property var app
        width: 140; height: 34
        // a instalar / remover: barra de progresso
        Rectangle {
            visible: ac.app.fila !== ""
            anchors.fill: parent; radius: 17
            color: Qt.rgba(1, 1, 1, 0.08)
            Rectangle {
                height: parent.height; radius: 17
                width: Math.max(height, parent.width * (ac.app.progresso / 100))
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: janela.rosa }
                    GradientStop { position: 1; color: janela.ambar }
                }
                opacity: 0.85
                Behavior on width { NumberAnimation { duration: 300 } }
            }
            Text {
                anchors.centerIn: parent
                text: (ac.app.fila === "instalando" ? "A instalar " : "A remover ") + ac.app.progresso + "%"
                color: "white"; font.pixelSize: 12; font.weight: Font.DemiBold
            }
        }
        Row {
            visible: ac.app.fila === ""
            anchors.right: parent.right
            spacing: 8
            Botao {
                visible: ac.app.instalado
                rotulo: "Abrir"
                onClicado: orbita.abrir(ac.app.id)
            }
            Rectangle {
                visible: ac.app.instalado
                width: 34; height: 34; radius: 17
                color: lixoRato.containsMouse ? Qt.rgba(1, 0.4, 0.45, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                Image { anchors.centerIn: parent; width: 18; height: 18; source: "image://icone/edit-delete"; sourceSize: Qt.size(36, 36) }
                MouseArea { id: lixoRato; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: orbita.remover(ac.app.id) }
            }
            Botao {
                visible: !ac.app.instalado
                rotulo: "Instalar"
                onClicado: orbita.instalar(ac.app.id)
            }
        }
    }

    component CartaoApp: Rectangle {
        id: c
        property var app
        height: 104; radius: 18
        color: cr.containsMouse ? janela.cartaoHover : janela.cartao
        border.color: Qt.rgba(1, 1, 1, 0.07)
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea { id: cr; anchors.fill: parent; hoverEnabled: true }
        Image {
            id: ic
            x: 18; anchors.verticalCenter: parent.verticalCenter
            width: 64; height: 64
            source: "image://icone/" + (c.app.icone !== "" ? c.app.icone : "application-x-executable")
            sourceSize: Qt.size(128, 128)
            asynchronous: true
        }
        Column {
            anchors.left: ic.right; anchors.leftMargin: 16
            anchors.right: acao.left; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            Text { width: parent.width; text: c.app.nome; color: janela.texto; font.pixelSize: 16; font.weight: Font.DemiBold; elide: Text.ElideRight }
            Text { width: parent.width; text: c.app.desc; color: janela.textoSuave; font.pixelSize: 13; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
        }
        Acao { id: acao; app: c.app; anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter }
    }

    // ---- barra lateral -------------------------------------------------------
    Rectangle {
        id: lateral
        width: 240
        anchors.top: parent.top; anchors.bottom: parent.bottom
        color: Qt.rgba(1, 1, 1, 0.03)
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.06) }

        Column {
            anchors.fill: parent; anchors.margins: 22; spacing: 6
            Row {
                spacing: 12
                Image { source: "image://icone/carinaeos-orbita"; width: 44; height: 44; sourceSize: Qt.size(88, 88) }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Órbita"; font.pixelSize: 22; font.weight: Font.Bold; color: janela.texto }
                    Text { text: "loja de aplicativos"; font.pixelSize: 11; color: janela.textoSuave }
                }
            }
            Item { width: 1; height: 20 }
            Repeater {
                model: [{ id: "descobrir", nome: "Descobrir", icone: "starred-symbolic" }]
                    .concat(orbita.categorias.map(cat => ({ id: cat.id, nome: cat.nome, icone: cat.icone })))
                    .concat([{ id: "meus", nome: "Instalados", icone: "emblem-checked" }])
                delegate: Rectangle {
                    required property var modelData
                    width: lateral.width - 44; height: 38; radius: 10
                    color: janela.secao === modelData.id && janela.busca === "" ? Qt.rgba(1, 0.7, 0.43, 0.16) : (nr.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                    Row {
                        anchors.verticalCenter: parent.verticalCenter; x: 12; spacing: 12
                        Image { source: "image://icone/" + modelData.icone; width: 20; height: 20; sourceSize: Qt.size(40, 40); anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: modelData.nome; anchors.verticalCenter: parent.verticalCenter
                            color: janela.secao === modelData.id && janela.busca === "" ? janela.ambar : janela.texto
                            font.weight: janela.secao === modelData.id ? Font.DemiBold : Font.Normal
                        }
                    }
                    MouseArea { id: nr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { campo.text = ""; janela.secao = modelData.id; area.contentItem.contentY = 0 } }
                }
            }
        }
        Text {
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 22
            text: orbita.estado !== "" ? orbita.estado : "Aplicativos do Flathub, instalados só para si."
            color: janela.textoSuave; font.pixelSize: 11; wrapMode: Text.WordWrap
        }
    }

    // ---- topo: pesquisa --------------------------------------------------------
    Rectangle {
        id: caixaBusca
        anchors.top: parent.top; anchors.topMargin: 22
        anchors.right: parent.right; anchors.rightMargin: 36
        width: 340; height: 40; radius: 20
        color: Qt.rgba(1, 1, 1, campo.activeFocus ? 0.12 : 0.07)
        border.color: Qt.rgba(1, 1, 1, 0.14)
        Image { id: lupa; x: 14; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18; source: "image://icone/search"; sourceSize: Qt.size(36, 36); opacity: 0.8 }
        TextField {
            id: campo
            anchors.left: lupa.right; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            placeholderText: "Pesquisar aplicativos…"
            placeholderTextColor: janela.textoSuave
            color: janela.texto
            background: Item {}
            onTextChanged: atraso.restart()
            Timer { id: atraso; interval: 350; onTriggered: { janela.busca = campo.text.trim(); orbita.pesquisar(janela.busca) } }
        }
    }

    // ---- conteúdo ------------------------------------------------------------
    ScrollView {
        id: area
        anchors.left: lateral.right; anchors.right: parent.right
        anchors.top: caixaBusca.bottom; anchors.topMargin: 6; anchors.bottom: parent.bottom
        contentWidth: availableWidth
        clip: true

        Column {
            id: coluna
            width: area.availableWidth
            padding: 36; topPadding: 12
            spacing: 22
            readonly property real largura: width - 72
            readonly property int colunas: largura > 760 ? 2 : 1
            readonly property real larguraCartao: (largura - 16 * (colunas - 1)) / colunas

            // pesquisa
            Text { visible: janela.busca !== ""; text: "Resultados para “" + janela.busca + "”"; color: janela.texto; font.pixelSize: 26; font.weight: Font.Bold }
            Text { visible: janela.busca !== "" && orbita.resultados.length === 0; text: "Nada encontrado. Tente outro nome."; color: janela.textoSuave }
            Flow {
                visible: janela.busca !== ""
                width: coluna.largura; spacing: 16
                Repeater { model: janela.busca !== "" ? orbita.resultados : []; delegate: CartaoApp { required property var modelData; app: modelData; width: coluna.larguraCartao } }
            }

            // descobrir
            Rectangle {
                visible: janela.busca === "" && janela.secao === "descobrir"
                width: coluna.largura; height: 190; radius: 22
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#3b2470" }
                    GradientStop { position: 0.6; color: "#7a2f6b" }
                    GradientStop { position: 1.0; color: "#c25a4a" }
                }
                Image { anchors.right: parent.right; anchors.rightMargin: 30; anchors.verticalCenter: parent.verticalCenter; width: 150; height: 150; source: "image://icone/carinaeos-orbita"; sourceSize: Qt.size(300, 300); opacity: 0.9 }
                Column {
                    x: 34; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                    Text { text: "Bem-vindo à Órbita"; color: "white"; font.pixelSize: 30; font.weight: Font.Bold }
                    Text { text: "Navegadores, escritório, jogos e muito mais.\nUm clique para instalar, sem senha de administrador."; color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: 15; lineHeight: 1.2 }
                }
            }
            Text { visible: janela.busca === "" && janela.secao === "descobrir"; text: "Em destaque"; color: janela.texto; font.pixelSize: 22; font.weight: Font.Bold }
            Flow {
                visible: janela.busca === "" && janela.secao === "descobrir"
                width: coluna.largura; spacing: 16
                Repeater { model: orbita.destaques; delegate: CartaoApp { required property var modelData; app: modelData; width: coluna.larguraCartao } }
            }

            // uma categoria
            Repeater {
                model: orbita.categorias
                delegate: Column {
                    required property var modelData
                    visible: janela.busca === "" && (janela.secao === modelData.id || janela.secao === "descobrir")
                    spacing: 14
                    Text { text: modelData.nome; color: janela.texto; font.pixelSize: janela.secao === modelData.id ? 30 : 22; font.weight: Font.Bold }
                    Flow {
                        width: coluna.largura; spacing: 16
                        Repeater { model: modelData.apps; delegate: CartaoApp { required property var modelData; app: modelData; width: coluna.larguraCartao } }
                    }
                }
            }

            // instalados
            Text { visible: janela.busca === "" && janela.secao === "meus"; text: "Instalados"; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold }
            Text { visible: janela.busca === "" && janela.secao === "meus" && orbita.meus.length === 0; text: "Ainda não instalou nenhum aplicativo pela Órbita."; color: janela.textoSuave }
            Flow {
                visible: janela.busca === "" && janela.secao === "meus"
                width: coluna.largura; spacing: 16
                Repeater { model: janela.secao === "meus" ? orbita.meus : []; delegate: CartaoApp { required property var modelData; app: modelData; width: coluna.larguraCartao } }
            }
        }
    }

    // ---- aviso de erro -----------------------------------------------------------
    Rectangle {
        id: avisoCaixa
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 24
        width: Math.min(parent.width - 80, aviso.implicitWidth + 40); height: 44; radius: 22
        color: "#3a1724"; border.color: janela.rosa
        Text { id: aviso; anchors.centerIn: parent; color: janela.texto; width: parent.width - 30; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
        Timer { id: avisoTempo; interval: 6000; onTriggered: avisoCaixa.visible = false }
    }
}
