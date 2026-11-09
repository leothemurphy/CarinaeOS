// CarinaeOS - Supernova: personalizar o sistema com mods
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: janela
    width: 1120
    height: 740
    minimumWidth: 900
    minimumHeight: 600
    visible: true
    title: "Supernova"
    color: "#0d0a13"

    readonly property color ambar: "#ffb46e"
    readonly property color rosa: "#ff6f91"
    readonly property color texto: "#f4eee8"
    readonly property color textoSuave: "#b9aec4"
    readonly property color cartao: "#1a1524"
    readonly property color cartaoHover: "#221b2f"
    property string secao: "perfis"

    font.family: "Inter"
    font.pixelSize: 14

    // ---- fundo: brilho da nebulosa no canto ----------------------------------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#150f1f" }
            GradientStop { position: 1.0; color: "#0a0810" }
        }
    }
    Rectangle {
        width: 720; height: 720; radius: 360
        x: parent.width - 420; y: -380
        opacity: 0.18
        gradient: Gradient {
            GradientStop { position: 0.0; color: janela.ambar }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
    Repeater {     // estrelas
        model: 60
        Rectangle {
            required property int index
            readonly property real r: ((index * 7919) % 97) / 97
            x: ((index * 104729) % 1000) / 1000 * janela.width
            y: ((index * 1299709) % 1000) / 1000 * janela.height
            width: r > 0.85 ? 2.5 : 1.5; height: width; radius: width / 2
            color: "white"
            opacity: 0.15 + r * 0.35
        }
    }

    // ---- componentes ---------------------------------------------------------
    component Interruptor: Item {
        id: sw
        property bool ligado: false
        signal alternado(bool valor)
        width: 46; height: 26
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: sw.ligado ? janela.ambar : "#3a3246"
            Behavior on color { ColorAnimation { duration: 160 } }
        }
        Rectangle {
            width: 20; height: 20; radius: 10
            y: 3
            x: sw.ligado ? sw.width - width - 3 : 3
            color: "white"
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sw.alternado(!sw.ligado)
        }
    }

    component IconeRedondo: Rectangle {
        property string nome: ""
        property color tom: janela.ambar
        width: 46; height: 46; radius: 13
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(tom.r, tom.g, tom.b, 0.32) }
            GradientStop { position: 1.0; color: Qt.rgba(tom.r, tom.g, tom.b, 0.12) }
        }
        border.color: Qt.rgba(tom.r, tom.g, tom.b, 0.35)
        Image {
            anchors.centerIn: parent
            width: 26; height: 26
            source: parent.nome ? "image://icone/" + parent.nome : ""
            sourceSize: Qt.size(52, 52)
        }
    }

    component CartaoMod: Rectangle {
        id: c
        property var mod
        width: (grade.width - grade.columnSpacing * (grade.columns - 1)) / grade.columns
        height: Math.max(84, textos.implicitHeight + 36)
        radius: 16
        color: rato.containsMouse ? janela.cartaoHover : janela.cartao
        border.color: c.mod.ligado ? Qt.rgba(1, 0.7, 0.43, 0.45) : Qt.rgba(1, 1, 1, 0.07)
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea { id: rato; anchors.fill: parent; hoverEnabled: true }

        IconeRedondo {
            id: ic
            x: 18; y: 18
            nome: c.mod.icone
            tom: c.mod.novo ? janela.rosa : janela.ambar
        }
        Column {
            id: textos
            anchors.left: ic.right; anchors.leftMargin: 14
            anchors.right: chave.left; anchors.rightMargin: 12
            y: 18
            spacing: 6
            Row {
                spacing: 8
                Text { text: c.mod.nome; color: janela.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
                Rectangle {
                    visible: c.mod.novo === true
                    width: novoTxt.implicitWidth + 12; height: 18; radius: 9
                    anchors.verticalCenter: parent.verticalCenter
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: janela.rosa }
                        GradientStop { position: 1; color: janela.ambar }
                    }
                    Text { id: novoTxt; anchors.centerIn: parent; text: "SÓ NO CARINAEOS"; color: "#1a0f14"; font.pixelSize: 9; font.weight: Font.Bold }
                }
            }
            Text {
                width: parent.width
                text: c.mod.desc
                color: janela.textoSuave
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
                font.pixelSize: 13
                lineHeight: 1.15
            }
        }
        Interruptor {
            id: chave
            anchors.right: parent.right; anchors.rightMargin: 18
            y: 22
            ligado: c.mod.ligado
            onAlternado: valor => supernova.ligar(c.mod.id, valor)
        }
    }

    // ---- barra lateral -------------------------------------------------------
    Rectangle {
        id: lateral
        width: 248
        anchors.top: parent.top; anchors.bottom: parent.bottom
        color: Qt.rgba(1, 1, 1, 0.03)
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.06) }

        Column {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 6

            Row {
                spacing: 12
                Image { source: "image://icone/carinaeos-supernova"; width: 44; height: 44; sourceSize: Qt.size(88, 88) }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: "Supernova"
                        font.pixelSize: 22; font.weight: Font.Bold
                        color: janela.texto
                    }
                    Text { text: "personalize o seu CarinaeOS"; font.pixelSize: 11; color: janela.textoSuave }
                }
            }
            Item { width: 1; height: 22 }

            Repeater {
                model: [
                    { id: "perfis", nome: "Perfis", icone: "bookmarks" },
                    { id: "janelas", nome: "Janelas", icone: "window" },
                    { id: "troca", nome: "Alt+Tab", icone: "preferences-system-windows-effect-flipswitch" },
                    { id: "mesa", nome: "Área de trabalho", icone: "user-desktop" },
                    { id: "dock", nome: "Dock", icone: "carinaeos-estrela" },
                    { id: "ideias", nome: "Ideias Supernova", icone: "starred-symbolic" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    width: lateral.width - 44; height: 40; radius: 10
                    color: janela.secao === modelData.id ? Qt.rgba(1, 0.7, 0.43, 0.16) : (navRato.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12; spacing: 12
                        Image { source: "image://icone/" + modelData.icone; width: 20; height: 20; sourceSize: Qt.size(40, 40); anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: modelData.nome
                            color: janela.secao === modelData.id ? janela.ambar : janela.texto
                            font.pixelSize: 14; font.weight: janela.secao === modelData.id ? Font.DemiBold : Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea { id: navRato; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: janela.secao = modelData.id }
                }
            }
        }

        Column {
            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.margins: 22
            spacing: 10
            Text { text: supernova.ativos + " mods ativos"; color: janela.textoSuave; font.pixelSize: 12 }
            Rectangle {
                width: 150; height: 32; radius: 16
                color: resRato.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                Text { anchors.centerIn: parent; text: "Restaurar padrão"; color: janela.texto; font.pixelSize: 12 }
                MouseArea { id: resRato; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: supernova.restaurar() }
            }
        }
    }

    // ---- conteúdo ------------------------------------------------------------
    ScrollView {
        id: area
        anchors.left: lateral.right; anchors.right: parent.right
        anchors.top: parent.top; anchors.bottom: parent.bottom
        contentWidth: availableWidth
        clip: true

        Column {
            width: area.availableWidth
            padding: 36
            spacing: 22

            readonly property var titulos: ({
                perfis: ["Perfis", "Mude o visual inteiro com um clique."],
                janelas: ["Janelas", "Animações e efeitos das janelas."],
                troca: ["Alt+Tab", "Escolha como as janelas aparecem ao alternar entre elas."],
                mesa: ["Área de trabalho", "Cantos da tela e conforto visual."],
                dock: ["Dock", "Tamanho dos ícones e força da lupa."],
                ideias: ["Ideias Supernova", "Recursos que só existem no CarinaeOS."]
            })

            Column {
                spacing: 6
                Text { text: parent.parent.titulos[janela.secao][0]; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold }
                Text { text: parent.parent.titulos[janela.secao][1]; color: janela.textoSuave; font.pixelSize: 14 }
            }

            // perfis
            Grid {
                visible: janela.secao === "perfis"
                width: area.availableWidth - 72
                columns: 2; columnSpacing: 16; rowSpacing: 16
                Repeater {
                    model: supernova.perfis
                    delegate: Rectangle {
                        required property var modelData
                        width: (parent.width - 16) / 2; height: 150; radius: 18
                        color: pRato.containsMouse ? janela.cartaoHover : janela.cartao
                        border.color: Qt.rgba(1, 1, 1, 0.07)
                        Behavior on color { ColorAnimation { duration: 120 } }
                        IconeRedondo { id: pic; x: 20; y: 20; nome: modelData.icone; tom: modelData.id === "supernova" ? janela.rosa : janela.ambar }
                        Column {
                            anchors.left: pic.right; anchors.leftMargin: 14; anchors.right: parent.right; anchors.rightMargin: 20
                            y: 20; spacing: 6
                            Text { text: modelData.nome; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
                            Text { width: parent.width; text: modelData.desc; color: janela.textoSuave; wrapMode: Text.WordWrap; font.pixelSize: 13 }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 18
                            width: 96; height: 32; radius: 16
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: janela.rosa }
                                GradientStop { position: 1; color: janela.ambar }
                            }
                            Text { anchors.centerIn: parent; text: "Aplicar"; color: "#1a0f14"; font.weight: Font.Bold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: supernova.aplicarPerfil(modelData.id) }
                        }
                        MouseArea { id: pRato; anchors.fill: parent; hoverEnabled: true; z: -1 }
                    }
                }
            }

            // mods por categoria
            Grid {
                id: grade
                visible: ["janelas", "mesa", "ideias"].indexOf(janela.secao) !== -1
                width: area.availableWidth - 72
                columns: width > 700 ? 2 : 1
                columnSpacing: 16; rowSpacing: 16
                Repeater {
                    model: supernova.mods.filter(m => m.cat === janela.secao)
                    delegate: CartaoMod { required property var modelData; mod: modelData }
                }
            }

            // Alt+Tab
            Grid {
                visible: janela.secao === "troca"
                width: area.availableWidth - 72
                columns: 3; columnSpacing: 16; rowSpacing: 16
                Repeater {
                    model: supernova.trocas
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool escolhido: supernova.troca === modelData.id
                        width: (parent.width - 32) / 3; height: 120; radius: 16
                        color: tRato.containsMouse ? janela.cartaoHover : janela.cartao
                        border.color: escolhido ? janela.ambar : Qt.rgba(1, 1, 1, 0.07)
                        border.width: escolhido ? 2 : 1
                        Column {
                            anchors.fill: parent; anchors.margins: 18; spacing: 6
                            Text { text: modelData.nome; color: escolhido ? janela.ambar : janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
                            Text { width: parent.width; text: modelData.desc; color: janela.textoSuave; wrapMode: Text.WordWrap; font.pixelSize: 13 }
                        }
                        MouseArea { id: tRato; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: supernova.escolherTroca(modelData.id) }
                    }
                }
            }
            Text {
                visible: janela.secao === "troca"
                text: "Dica: segure Alt e carregue em Tab para experimentar."
                color: janela.textoSuave; font.pixelSize: 13
            }

            // Dock
            Column {
                visible: janela.secao === "dock"
                width: area.availableWidth - 72
                spacing: 16
                Repeater {
                    model: [
                        { nome: "Força da lupa", de: 1.0, ate: 2.6, passo: 0.05, valor: supernova.zoom, fmt: v => (v === 1 ? "desligada" : Math.round((v - 1) * 100) + "% maior"), acao: v => supernova.mudarZoom(v) },
                        { nome: "Tamanho dos ícones", de: 32, ate: 80, passo: 2, valor: supernova.tamanho, fmt: v => Math.round(v) + " px", acao: v => supernova.mudarTamanho(Math.round(v)) }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 96; radius: 16
                        color: janela.cartao; border.color: Qt.rgba(1, 1, 1, 0.07)
                        Text { x: 22; y: 18; text: modelData.nome; color: janela.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { anchors.right: parent.right; anchors.rightMargin: 22; y: 18; text: modelData.fmt(barra.value); color: janela.ambar; font.pixelSize: 14 }
                        Slider {
                            id: barra
                            x: 16; y: 50; width: parent.width - 32
                            from: modelData.de; to: modelData.ate; stepSize: modelData.passo
                            value: modelData.valor
                            onPressedChanged: if (!pressed) modelData.acao(value)
                            background: Rectangle {
                                x: barra.leftPadding; y: barra.topPadding + barra.availableHeight / 2 - 3
                                width: barra.availableWidth; height: 6; radius: 3; color: "#3a3246"
                                Rectangle { width: barra.visualPosition * parent.width; height: parent.height; radius: 3; color: janela.ambar }
                            }
                            handle: Rectangle {
                                x: barra.leftPadding + barra.visualPosition * (barra.availableWidth - width)
                                y: barra.topPadding + barra.availableHeight / 2 - height / 2
                                width: 22; height: 22; radius: 11; color: "white"
                            }
                        }
                    }
                }
            }
        }
    }
}
