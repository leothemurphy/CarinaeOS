// CarinaeOS - Central: todas as ferramentas num só lugar
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: janela
    width: 1100; height: 740
    minimumWidth: 860; minimumHeight: 560
    visible: true
    title: "Central CarinaeOS"
    color: "#0c0a14"
    font.family: "Inter"; font.pixelSize: 14

    readonly property color ambar: "#ffb46e"
    readonly property color rosa: "#ff6f91"
    readonly property color texto: "#f6f2ff"
    readonly property color suave: "#b9b0cc"
    property string pagina: central.paginaInicial || "inicio"
    function carregar() {
        if (pagina === "calendarios") central.lerCalendarios()
        if (pagina === "drivers") central.lerHardware()
    }
    onPaginaChanged: carregar()
    Component.onCompleted: carregar()

    function abrirFerramenta(f) {
        if (f.pagina) janela.pagina = f.pagina
        else central.abrir(f.cmd)
    }

    Image { anchors.fill: parent; source: "file:///usr/share/backgrounds/carinaeos/eta-carinae.jpg"; fillMode: Image.PreserveAspectCrop; asynchronous: true }
    Rectangle { anchors.fill: parent; color: "#0c0a14"; opacity: 0.86 }

    // ---- barra lateral ------------------------------------------------------------------------------
    Rectangle {
        id: lado
        width: 250; height: parent.height
        color: Qt.rgba(1, 1, 1, 0.04)
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.07) }
        Column {
            x: 14; y: 20; width: parent.width - 28; spacing: 3
            Row {
                spacing: 12; leftPadding: 6; bottomPadding: 18
                Image { source: "image://icone/carinaeos"; width: 40; height: 40; sourceSize: Qt.size(80, 80) }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Central"; color: janela.texto; font.pixelSize: 19; font.weight: Font.Bold }
                    Text { text: "CarinaeOS"; color: janela.suave; font.pixelSize: 12 }
                }
            }
            Repeater {
                model: [{ id: "inicio", nome: "Todas as ferramentas", icone: "view-app-grid" }].concat(central.ferramentas.filter(f => f.pagina))
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool ativo: janela.pagina === (modelData.pagina || modelData.id)
                    width: parent.width; height: 38; radius: 10
                    color: ativo ? Qt.rgba(1, 0.62, 0.45, 0.24) : (lm.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                    Row {
                        x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        Image { source: "image://icone/" + modelData.icone; width: 20; height: 20; sourceSize: Qt.size(40, 40) }
                        Text { text: modelData.nome; color: janela.texto; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: lm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: janela.pagina = modelData.pagina || modelData.id }
                }
            }
        }
    }

    // ---- aviso -----------------------------------------------------------------------------------
    Rectangle {
        id: aviso
        visible: central.mensagem !== ""
        z: 5
        anchors.bottom: parent.bottom; anchors.bottomMargin: 18
        x: lado.width + (parent.width - lado.width - width) / 2
        width: Math.min(620, avisoTxt.implicitWidth + 60); height: 44; radius: 22
        color: "#2a2140"; border.color: Qt.rgba(1, 0.7, 0.45, 0.4)
        Row {
            anchors.centerIn: parent; spacing: 10
            BusyIndicator { running: central.ocupado; visible: central.ocupado; width: 22; height: 22 }
            Text { id: avisoTxt; text: central.mensagem; color: janela.texto; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter
                   width: Math.min(implicitWidth, 540); elide: Text.ElideRight }
        }
    }

    // ---- paginas ----------------------------------------------------------------------------------
    ScrollView {
        id: area
        x: lado.width; width: parent.width - lado.width; height: parent.height
        contentWidth: availableWidth; clip: true

        Column {
            id: conteudo
            width: area.availableWidth
            padding: 34; spacing: 18
            readonly property real largura: width - 68

            // ===== inicio =====
            Column {
                visible: janela.pagina === "inicio"
                width: conteudo.largura; spacing: 22
                Text { text: "Tudo o que o CarinaeOS tem"; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold }
                Flow {
                    width: parent.width; spacing: 14
                    Repeater {
                        model: central.ferramentas
                        delegate: Rectangle {
                            required property var modelData
                            width: Math.floor((conteudo.largura - 30) / 3); height: 104; radius: 20
                            color: fm.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
                            border.color: fm.containsMouse ? Qt.rgba(1, 0.72, 0.45, 0.5) : Qt.rgba(1, 1, 1, 0.08)
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Image { x: 18; anchors.verticalCenter: parent.verticalCenter; source: "image://icone/" + modelData.icone
                                    width: 52; height: 52; sourceSize: Qt.size(104, 104) }
                            Column {
                                x: 84; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 100; spacing: 3
                                Text { text: modelData.nome; color: janela.texto; font.pixelSize: 15; font.weight: Font.DemiBold; width: parent.width; elide: Text.ElideRight }
                                Text { text: modelData.desc; color: janela.suave; font.pixelSize: 12; width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                            }
                            MouseArea { id: fm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: janela.abrirFerramenta(modelData) }
                        }
                    }
                }
            }

            // ===== calendarios =====
            Column {
                visible: janela.pagina === "calendarios"
                width: conteudo.largura; spacing: 16
                Text { text: "Calendários"; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold }
                Text { width: parent.width; wrapMode: Text.WordWrap; color: janela.suave
                       text: "Os eventos aparecem no Calendário e ao clicar no relógio da barra de cima." }
                Row {
                    spacing: 14
                    Repeater {
                        model: [
                            { id: "google", t: "Conta Google", d: "Ler e criar eventos. Abre a página do Google para entrar e autorizar.", i: "google" },
                            { id: "caldav", t: "iCloud (Apple) e outros", d: "CalDAV: use o seu Apple ID e uma “senha específica de app” (appleid.apple.com › Segurança). Servidor: https://caldav.icloud.com", i: "preferences-web-browser-cookies" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: (conteudo.largura - 14) / 2; height: 150; radius: 20; color: Qt.rgba(1, 1, 1, 0.05); border.color: Qt.rgba(1, 1, 1, 0.08)
                            Column {
                                x: 18; y: 16; width: parent.width - 36; spacing: 6
                                Text { text: modelData.t; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
                                Text { text: modelData.d; color: janela.suave; font.pixelSize: 12; width: parent.width; wrapMode: Text.WordWrap }
                            }
                            Rectangle {
                                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 14
                                width: 110; height: 34; radius: 17; color: janela.ambar
                                Text { anchors.centerIn: parent; text: "Ligar"; color: "#1a0f14"; font.weight: Font.Bold }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: central.conta(modelData.id) }
                            }
                        }
                    }
                }
                Rectangle {
                    width: parent.width; height: icalCol.implicitHeight + 32; radius: 20; color: Qt.rgba(1, 1, 1, 0.05); border.color: Qt.rgba(1, 1, 1, 0.08)
                    Column {
                        id: icalCol
                        x: 18; y: 16; width: parent.width - 36; spacing: 10
                        Text { text: "Pelo endereço do calendário (Google, iCloud, Outlook, escola, feriados…)"; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
                        Text { width: parent.width; wrapMode: Text.WordWrap; color: janela.suave; font.pixelSize: 12
                               text: "Google Calendar: Definições › o seu calendário › “Endereço secreto em formato iCal”. iCloud: na app Calendário, partilhe o calendário como “Calendário público” e copie o link webcal://. Outlook: Definições › Calendários partilhados › Publicar › ICS." }
                        Row {
                            spacing: 10; width: parent.width
                            TextField { id: icalUrl; width: parent.width - icalNome.width - 140; placeholderText: "https://… ou webcal://…" }
                            TextField { id: icalNome; width: 200; placeholderText: "Nome (ex.: Trabalho)" }
                            Rectangle {
                                width: 110; height: 38; radius: 19; opacity: icalUrl.text !== "" ? 1 : 0.4
                                gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: janela.rosa } GradientStop { position: 1; color: janela.ambar } }
                                Text { anchors.centerIn: parent; text: "Adicionar"; color: "#1a0f14"; font.weight: Font.Bold }
                                MouseArea { anchors.fill: parent; enabled: icalUrl.text !== ""; cursorShape: Qt.PointingHandCursor
                                            onClicked: { central.adicionarIcal(icalUrl.text, icalNome.text); icalUrl.text = ""; icalNome.text = "" } }
                            }
                        }
                    }
                }
                Text { text: "Calendários ligados"; color: janela.suave; font.pixelSize: 12; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase; visible: central.calendarios.length > 0 }
                Repeater {
                    model: central.calendarios
                    delegate: Rectangle {
                        required property var modelData
                        width: conteudo.largura; height: 50; radius: 14; color: Qt.rgba(1, 1, 1, 0.04)
                        Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: "📅  " + modelData.nome + "   ·   " + modelData.tipo; color: janela.texto }
                        Text { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; text: "Remover"; color: janela.rosa
                               MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: central.removerCalendario(modelData.id) } }
                    }
                }
                Rectangle {
                    width: 200; height: 38; radius: 19; color: Qt.rgba(1, 1, 1, 0.08)
                    Text { anchors.centerIn: parent; text: "Abrir o Calendário"; color: janela.texto }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: central.abrir("merkuro-calendar") }
                }
            }

            // ===== janelas em zonas =====
            Column {
                visible: janela.pagina === "janelas"
                width: conteudo.largura; spacing: 16
                Text { text: "Janelas em zonas"; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold }
                Text { width: parent.width; wrapMode: Text.WordWrap; color: janela.suave
                       text: "Escolha um esquema. Depois, arraste uma janela com a tecla Shift carregada e solte-a numa zona: encaixa sozinha. Meta+← / → encostam a janela a meio ecrã; Meta+↑ maximiza (maximizar de verdade)." }
                Flow {
                    width: parent.width; spacing: 14
                    Repeater {
                        model: central.zonas
                        delegate: Rectangle {
                            required property var modelData
                            width: 200; height: 160; radius: 18; color: zm.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                            Item {
                                id: mini
                                x: 20; y: 18; width: 160; height: 96
                                function desenhar(t, x, y, w, h, lista) {
                                    if (!t.tiles) { lista.push({ x: x, y: y, w: w, h: h }); return }
                                    let pos = 0
                                    for (const s of t.tiles) {
                                        if (t.layoutDirection === "horizontal") { desenhar(s, x + pos * w, y, w * s.width, h, lista); pos += s.width }
                                        else { desenhar(s, x, y + pos * h, w, h * s.height, lista); pos += s.height }
                                    }
                                }
                                Repeater {
                                    model: { const l = []; mini.desenhar(JSON.parse(modelData.tiles), 0, 0, 160, 96, l); return l }
                                    delegate: Rectangle {
                                        required property var modelData
                                        x: modelData.x + 2; y: modelData.y + 2; width: modelData.w - 4; height: modelData.h - 4; radius: 6
                                        color: Qt.rgba(1, 0.7, 0.45, 0.25); border.color: Qt.rgba(1, 0.7, 0.45, 0.6)
                                    }
                                }
                            }
                            Text { x: 20; y: 126; text: modelData.nome; color: janela.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
                            MouseArea { id: zm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: central.aplicarZonas(modelData.id) }
                        }
                    }
                }
                Row {
                    spacing: 10
                    Rectangle { width: 230; height: 38; radius: 19; color: Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "Desenhar as minhas zonas (Meta+T)"; color: janela.texto }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: central.editarZonas() } }
                }
                Text { text: "Áreas de trabalho (como os Spaces do Mac)"; color: janela.texto; font.pixelSize: 18; font.weight: Font.DemiBold; topPadding: 12 }
                Text { width: parent.width; wrapMode: Text.WordWrap; color: janela.suave
                       text: "Ctrl+Meta+← / → muda de área; Meta+W mostra todas as janelas e áreas; arraste janelas entre áreas na vista geral." }
                Row {
                    spacing: 8
                    Repeater {
                        model: [1, 2, 3, 4, 6, 8]
                        delegate: Rectangle {
                            required property int modelData
                            width: 52; height: 38; radius: 19; color: Qt.rgba(1, 1, 1, 0.08)
                            Text { anchors.centerIn: parent; text: modelData; color: janela.texto }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: central.areas(modelData) }
                        }
                    }
                    Rectangle { width: 170; height: 38; radius: 19; color: Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "Ver todas (Meta+W)"; color: janela.texto }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: central.verAreas() } }
                }
            }

            // ===== cadeado =====
            Column {
                visible: janela.pagina === "cadeado"
                width: conteudo.largura; spacing: 16
                Text { text: "Cadeado"; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold }
                Repeater {
                    model: [
                        { t: "Pastas e arquivos", d: "Nos Arquivos, botão direito › “Trancar com senha”. A pasta fica no mesmo sítio, com um cadeado, e só abre com a senha (duplo clique). Por dentro fica cifrada (AES-256): sem a senha ninguém lê nada. Funciona também em pastas de rede.", b: "" },
                        { t: "Aplicativos", d: "Escolha aplicativos que pedem uma senha para abrir (por exemplo, o WhatsApp ou o navegador).", b: "carinaeos-cadeado aplicativos" },
                        { t: "Cofres", d: "Pastas cifradas que abre e fecha pelo ícone de cadeado na barra de cima (Plasma Vault).", b: "kcmshell6 kcm_plasmavault 2>/dev/null || plasma-vault" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        width: conteudo.largura; height: cdCol.implicitHeight + 32; radius: 20; color: Qt.rgba(1, 1, 1, 0.05); border.color: Qt.rgba(1, 1, 1, 0.08)
                        Column {
                            id: cdCol
                            x: 18; y: 16; width: parent.width - 180; spacing: 6
                            Text { text: modelData.t; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
                            Text { text: modelData.d; color: janela.suave; font.pixelSize: 13; width: parent.width; wrapMode: Text.WordWrap }
                        }
                        Rectangle {
                            visible: modelData.b !== ""
                            anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                            width: 130; height: 36; radius: 18; color: janela.ambar
                            Text { anchors.centerIn: parent; text: "Abrir"; color: "#1a0f14"; font.weight: Font.Bold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: central.abrir(modelData.b) }
                        }
                    }
                }
            }

            // ===== area de transferencia =====
            Column {
                visible: janela.pagina === "clipboard"
                width: conteudo.largura; spacing: 16
                Text { text: "Histórico do Ctrl+C"; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold }
                Text { width: parent.width; wrapMode: Text.WordWrap; color: janela.suave
                       text: "O CarinaeOS guarda o que copia (textos e imagens). Carregue em Meta+V em qualquer lado para ver a lista e escolher o que colar. Também está no ícone da prancheta na barra de cima, onde pode fixar itens ou limpar o histórico." }
                Rectangle {
                    width: 240; height: 40; radius: 20
                    gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: janela.rosa } GradientStop { position: 1; color: janela.ambar } }
                    Text { anchors.centerIn: parent; text: "Mostrar o histórico agora"; color: "#1a0f14"; font.weight: Font.Bold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: central.historico() }
                }
            }

            // ===== drivers =====
            Column {
                visible: janela.pagina === "drivers"
                width: conteudo.largura; spacing: 14
                Text { text: "Drivers e hardware"; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold }
                Text { width: parent.width; wrapMode: Text.WordWrap; color: janela.suave
                       text: "O que encontrei neste computador e o que falta para funcionar a 100%." }
                Repeater {
                    model: central.hardware
                    delegate: Rectangle {
                        required property var modelData
                        width: conteudo.largura; height: hwCol.implicitHeight + 30; radius: 18; color: Qt.rgba(1, 1, 1, 0.05); border.color: Qt.rgba(1, 1, 1, 0.08)
                        Image { x: 16; y: 16; source: "image://icone/" + modelData.icone; width: 40; height: 40; sourceSize: Qt.size(80, 80) }
                        Column {
                            id: hwCol
                            x: 72; y: 15; width: parent.width - 260; spacing: 4
                            Text { text: modelData.nome; color: janela.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Text { text: modelData.detalhe; color: janela.suave; font.pixelSize: 12; width: parent.width; wrapMode: Text.WordWrap }
                            Text { visible: modelData.nota !== ""; text: modelData.nota; color: janela.ambar; font.pixelSize: 12; width: parent.width; wrapMode: Text.WordWrap }
                        }
                        Rectangle {
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            width: 150; height: 36; radius: 18
                            color: modelData.falta.length ? janela.ambar : Qt.rgba(0.56, 0.89, 0.66, 0.15)
                            Text { anchors.centerIn: parent; text: modelData.falta.length ? "Instalar" : "✓ Pronto"; color: modelData.falta.length ? "#1a0f14" : "#8fe3a8"; font.weight: Font.Bold }
                            MouseArea { anchors.fill: parent; enabled: modelData.falta.length > 0 && !central.ocupado; cursorShape: Qt.PointingHandCursor
                                        onClicked: central.instalarDriver(modelData.id) }
                        }
                    }
                }
            }

            // ===== privacidade =====
            Column {
                visible: janela.pagina === "privacidade"
                width: conteudo.largura; spacing: 16
                Text { text: "Privacidade"; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold }
                Rectangle {
                    width: parent.width; height: pCol1.implicitHeight + 32; radius: 20; color: Qt.rgba(1, 1, 1, 0.05); border.color: Qt.rgba(1, 1, 1, 0.08)
                    Column {
                        id: pCol1
                        x: 18; y: 16; width: parent.width - 160; spacing: 6
                        Text { text: "Sessão sem rastro"; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
                        Text { width: parent.width; wrapMode: Text.WordWrap; color: janela.suave; font.pixelSize: 13
                               text: "Na tela de entrada aparece “Convidado (sem rastro)”, sem senha. Tudo o que se fizer nessa sessão (arquivos, histórico, senhas guardadas, downloads) vive só na memória e desaparece ao sair. Ideal para emprestar o computador ou para usar num sítio público." }
                    }
                    Switch {
                        anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                        enabled: central.convidado >= 0 && !central.ocupado
                        checked: central.convidado === 1
                        onToggled: central.definirConvidado(checked)
                    }
                }
                Rectangle {
                    width: parent.width; height: pCol2.implicitHeight + 32; radius: 20; color: Qt.rgba(1, 1, 1, 0.05); border.color: Qt.rgba(1, 1, 1, 0.08)
                    Column {
                        id: pCol2
                        x: 18; y: 16; width: parent.width - 160; spacing: 6
                        Text { text: "Modo escuro em todo o lado"; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
                        Text { width: parent.width; wrapMode: Text.WordWrap; color: janela.suave; font.pixelSize: 13
                               text: "Força o escuro nos aplicativos teimosos: Chrome, Chromium, Brave, Edge e apps Electron (também as páginas da internet), Firefox, aplicativos GTK/GNOME e Flatpak." }
                    }
                    Switch {
                        anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter
                        enabled: !central.ocupado
                        checked: central.escuroForcado
                        onToggled: central.definirEscuro(checked)
                    }
                }
            }
        }
    }
}
