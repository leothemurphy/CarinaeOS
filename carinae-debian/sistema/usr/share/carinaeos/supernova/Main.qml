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

    // um mod com os seus modelos (como no Windhawk: escolher um modelo aplica-o logo)
    component CartaoModelos: Rectangle {
        id: c
        property var mod
        readonly property var atual: c.mod.modelos.find(x => x.id === c.mod.escolhido) || c.mod.modelos[0]
        width: parent ? parent.width : 600
        height: col.implicitHeight + 40
        radius: 18
        color: rato.containsMouse ? janela.cartaoHover : janela.cartao
        border.color: c.mod.escolhido !== c.mod.padrao ? Qt.rgba(1, 0.7, 0.43, 0.45) : Qt.rgba(1, 1, 1, 0.07)
        opacity: c.mod.disponivel ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: 120 } }
        MouseArea { id: rato; anchors.fill: parent; hoverEnabled: true }

        IconeRedondo { id: ic; x: 20; y: 20; nome: c.mod.icone; tom: c.mod.novo ? janela.rosa : janela.ambar }
        Column {
            id: col
            anchors.left: ic.right; anchors.leftMargin: 16
            anchors.right: parent.right; anchors.rightMargin: 20
            y: 20
            spacing: 10
            Row {
                spacing: 8
                Text { text: c.mod.nome; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
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
                Rectangle {
                    visible: !c.mod.disponivel
                    width: indTxt.implicitWidth + 14; height: 20; radius: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.rgba(1, 1, 1, 0.1)
                    Text { id: indTxt; anchors.centerIn: parent; text: "só no KDE Plasma"; color: janela.textoSuave; font.pixelSize: 10; font.weight: Font.DemiBold }
                }
            }
            Text {
                width: parent.width
                text: c.mod.desc + (c.mod.inspirado ? "   ·   inspirado no mod “" + c.mod.inspirado + "” do Windhawk" : "")
                color: janela.textoSuave; wrapMode: Text.WordWrap; font.pixelSize: 13; lineHeight: 1.15
            }
            Flow {
                width: parent.width
                spacing: 8
                Repeater {
                    model: c.mod.modelos
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool escolhido: c.mod.escolhido === modelData.id
                        width: chipRow.implicitWidth + 26; height: 34; radius: 17
                        color: escolhido ? Qt.rgba(1, 0.7, 0.43, 0.22) : chipRato.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)
                        border.color: escolhido ? janela.ambar : Qt.rgba(1, 1, 1, 0.1)
                        border.width: escolhido ? 2 : 1
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 8
                            Rectangle {   // amostra de cor (estilos da Dock)
                                visible: (chip.modelData.cor || "") !== ""
                                width: 16; height: 16; radius: 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: chip.modelData.cor || "transparent"
                                border.color: Qt.rgba(1, 1, 1, 0.5)
                            }
                            Text {
                                text: chip.modelData.nome
                                color: chip.escolhido ? janela.ambar : janela.texto
                                font.pixelSize: 13; font.weight: chip.escolhido ? Font.DemiBold : Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea {
                            id: chipRato; anchors.fill: parent; hoverEnabled: true
                            enabled: c.mod.disponivel
                            cursorShape: Qt.PointingHandCursor
                            onClicked: supernova.escolher(c.mod.id, chip.modelData.id)
                        }
                        ToolTip.visible: chipRato.containsMouse && chip.modelData.desc !== ""
                        ToolTip.text: chip.modelData.desc
                        ToolTip.delay: 300
                    }
                }
            }
            Text {
                visible: c.atual && c.atual.desc !== ""
                width: parent.width
                text: "→ " + (c.atual ? c.atual.desc : "")
                color: janela.ambar; font.pixelSize: 12; wrapMode: Text.WordWrap
            }
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
                    { id: "dock", nome: "Dock", icone: "carinaeos-estrela" },
                    { id: "janelas", nome: "Janelas", icone: "window" },
                    { id: "mesa", nome: "Área de trabalho", icone: "user-desktop" },
                    { id: "ambiente", nome: "Ambiente de trabalho", icone: "preferences-desktop" }
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
            Text { text: supernova.ocupado !== "" ? supernova.ocupado : supernova.personalizados + " mods personalizados"; color: supernova.ocupado !== "" ? janela.ambar : janela.textoSuave; font.pixelSize: 12 }
            Text { text: "Ambiente: " + supernova.nomeAmbiente; color: janela.textoSuave; font.pixelSize: 12 }
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
                dock: ["Dock", "Estilo, tamanho, lupa e o que faz o rato na Dock."],
                janelas: ["Janelas", "Animações, Alt+Tab, botões, sombras e transparência."],
                mesa: ["Área de trabalho", "Papel de parede, cantos, cursor, luz noturna e velocidade."],
                ambiente: ["Ambiente de trabalho", "Use o CarinaeOS com KDE Plasma, GNOME ou XFCE."]
            })

            Column {
                spacing: 6
                Text { text: parent.parent.titulos[janela.secao][0]; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold }
                Text { text: parent.parent.titulos[janela.secao][1]; color: janela.textoSuave; font.pixelSize: 14 }
            }

            // aviso fora do Plasma
            Rectangle {
                visible: supernova.ambiente !== "plasma" && janela.secao !== "ambiente"
                width: area.availableWidth - 72; height: avisoTxt.implicitHeight + 28; radius: 14
                color: Qt.rgba(1, 0.7, 0.43, 0.12); border.color: Qt.rgba(1, 0.7, 0.43, 0.4)
                Text {
                    id: avisoTxt
                    x: 16; y: 14; width: parent.width - 32; wrapMode: Text.WordWrap
                    color: janela.texto; font.pixelSize: 13
                    text: "Está a usar o " + supernova.nomeAmbiente + ". As opções esbatidas só existem no KDE Plasma; as outras funcionam aqui."
                }
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

            // mods com modelos
            Column {
                visible: ["dock", "janelas", "mesa"].indexOf(janela.secao) !== -1
                width: area.availableWidth - 72
                spacing: 14
                Repeater {
                    model: supernova.mods.filter(m => m.cat === janela.secao)
                    delegate: CartaoModelos { required property var modelData; mod: modelData }
                }
            }

            // ambiente de trabalho
            Rectangle {
                visible: janela.secao === "ambiente"
                width: area.availableWidth - 72; height: 170; radius: 18
                color: janela.cartao; border.color: Qt.rgba(1, 1, 1, 0.07)
                Column {
                    x: 24; y: 22; width: parent.width - 48; spacing: 10
                    Text { text: "Neste momento: " + supernova.nomeAmbiente; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
                    Text {
                        width: parent.width; wrapMode: Text.WordWrap; color: janela.textoSuave; font.pixelSize: 13
                        text: "Pode instalar o GNOME ou o XFCE ao lado do Plasma e escolher qual usar na tela de entrada. Os seus arquivos, aplicativos e papéis de parede do CarinaeOS continuam lá."
                    }
                    Rectangle {
                        width: 220; height: 36; radius: 18
                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: janela.rosa } GradientStop { position: 1; color: janela.ambar } }
                        Text { anchors.centerIn: parent; text: "Trocar de ambiente…"; color: "#1a0f14"; font.weight: Font.Bold }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: supernova.abrirAmbientes() }
                    }
                }
            }

            // Dock: tamanho e lupa (só na Dock do Plasma)
            Column {
                visible: janela.secao === "dock" && supernova.ambiente === "plasma"
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
