// CarinaeOS - Rotinas: vários passos num só toque do Deck
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: janela
    width: 1000; height: 680
    minimumWidth: 820; minimumHeight: 520
    visible: true
    title: "Rotinas"
    color: "#1e1d24"
    font.pixelSize: 14

    readonly property color lado: "#25232c"
    readonly property color cartao: "#2d2b35"
    readonly property color texto: "#f2f0f6"
    readonly property color suave: "#a8a3b6"
    readonly property color realce: "#ffb46e"
    readonly property color linha: Qt.rgba(1, 1, 1, 0.07)

    property var atual: null          // a rotina a ser editada (uma cópia)
    property bool sujo: false
    readonly property var icones: ["media-playlist-play", "chronometer", "video-television", "weather-clear-night", "weather-clear",
        "go-home", "applications-office", "applications-games", "audio-headphones", "folder-music", "applications-graphics",
        "printer", "lightbulb", "chronometer", "starred", "system-suspend", "internet-web-browser", "user-desktop"]

    function copia(o) { return JSON.parse(JSON.stringify(o)) }
    function escolher(r) { atual = copia(r); delete atual.quando; delete atual.correndo; delete atual.noDeck; sujo = false }
    function nova() { atual = { id: "", nome: "Nova rotina", icone: "media-playlist-play", gatilho: { tipo: "manual" }, passos: [] }; sujo = true; nomeR.forceActiveFocus(); nomeR.selectAll() }
    function mudar(f) { const a = copia(atual); f(a); atual = a; sujo = true }
    function salvar() { const id = rotinas.salvar(JSON.stringify(atual)); mudar(a => a.id = id); sujo = false; return id }
    function info(id) { return rotinas.lista.find(r => r.id === id) }
    function alternavel(id) {
        return /^sis:(dnd|luz|wifi|bt)$/.test(id)
            || /^ha:(light|switch|input_boolean|fan|cover|lock|media_player|climate|vacuum)\./.test(id)
    }
    function iconePasso(p) {
        return ({ abrir: "system-run", fechar: "window-close", site: "internet-web-browser", volume: "audio-volume-high",
                  esperar: "chronometer", aviso: "dialog-information", comando: "utilities-terminal", ha: "go-home" })[p.tipo]
               || (p.id && p.id.startsWith("ha:") ? "go-home" : p.id && p.id.startsWith("mus:") ? "folder-music" : "preferences-system")
    }

    Component.onCompleted: {
        if (rotinas.inicio === "+nova") nova()
        else {
            const r = rotinas.lista.find(x => x.id === rotinas.inicio) || rotinas.lista[0]
            if (r) escolher(r)
        }
    }

    // ---- a lista das rotinas -------------------------------------------------------------------------
    Rectangle {
        id: barra
        width: 280; height: parent.height; color: janela.lado
        Text { x: 20; y: 18; text: "Rotinas"; color: janela.texto; font.pixelSize: 20; font.weight: Font.DemiBold }
        Text { x: 20; y: 48; width: parent.width - 40; wrapMode: Text.WordWrap; color: janela.suave; font.pixelSize: 12
               text: "Um toque no Deck faz várias coisas de seguida." }
        ListView {
            id: listaR
            x: 10; y: 86; width: parent.width - 20; height: parent.height - y - 70; clip: true; spacing: 2
            model: rotinas.lista
            delegate: Rectangle {
                required property var modelData
                readonly property bool sel: janela.atual !== null && janela.atual.id === modelData.id
                width: ListView.view.width; height: 58; radius: 10
                color: sel ? Qt.rgba(1, 0.71, 0.43, 0.18) : mr.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                Image { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; sourceSize: Qt.size(56, 56)
                        source: "image://icone/" + (modelData.icone || "media-playlist-play") }
                Column {
                    x: 52; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 60
                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.nome; color: janela.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { width: parent.width; elide: Text.ElideRight; color: modelData.correndo ? janela.realce : janela.suave; font.pixelSize: 11
                           text: modelData.correndo ? "Rodando…" : modelData.passos.length + (modelData.passos.length === 1 ? " passo · " : " passos · ") + modelData.quando }
                }
                MouseArea { id: mr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: janela.escolher(modelData) }
            }
        }
        Botao { x: 16; anchors.bottom: parent.bottom; anchors.bottomMargin: 16; width: parent.width - 32; texto: "+  Nova rotina"; onCarregado: janela.nova() }
    }

    // ---- o editor --------------------------------------------------------------------------------------
    Item {
        x: barra.width; width: parent.width - barra.width; height: parent.height
        Text { anchors.centerIn: parent; visible: janela.atual === null; text: "Escolha uma rotina ou crie uma nova"; color: janela.suave }
        Flickable {
            id: rolar
            visible: janela.atual !== null
            anchors.fill: parent; anchors.bottomMargin: rodape.height
            contentHeight: col.height + 40; clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout {
                id: col
                x: 28; y: 24; width: Math.min(rolar.width - 56, 680); spacing: 14
                RowLayout {
                    spacing: 12; Layout.fillWidth: true
                    Rectangle {
                        width: 52; height: 52; radius: 14; color: mi.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                        Image { anchors.centerIn: parent; width: 32; height: 32; sourceSize: Qt.size(64, 64)
                                source: "image://icone/" + (janela.atual ? janela.atual.icone : "media-playlist-play") }
                        MouseArea { id: mi; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dlgIcone.open() }
                        ToolTip.visible: mi.containsMouse; ToolTip.text: "Mudar o ícone"
                    }
                    TextField {
                        id: nomeR
                        Layout.fillWidth: true; font.pixelSize: 20; color: janela.texto; placeholderText: "Nome da rotina"
                        text: janela.atual ? janela.atual.nome : ""
                        onTextEdited: janela.mudar(a => a.nome = text)
                        background: Rectangle { radius: 10; color: Qt.rgba(1, 1, 1, 0.05); border.color: nomeR.activeFocus ? janela.realce : janela.linha }
                    }
                }

                Text { text: "Passos"; color: janela.texto; font.pixelSize: 15; font.weight: Font.DemiBold; topPadding: 8 }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: passosCol.implicitHeight + 8; radius: 12; color: janela.cartao; border.color: janela.linha
                    Column {
                        id: passosCol
                        y: 4; width: parent.width
                        Text { visible: !janela.atual || janela.atual.passos.length === 0; width: parent.width; padding: 18; wrapMode: Text.WordWrap
                               text: "Ainda sem passos. Acrescente o que a rotina deve fazer, pela ordem."; color: janela.suave }
                        Repeater {
                            model: janela.atual ? janela.atual.passos : []
                            delegate: Item {
                                required property var modelData
                                required property int index
                                width: passosCol.width; height: 50
                                Rectangle { anchors.bottom: parent.bottom; x: 16; width: parent.width - 32; height: 1; color: janela.linha
                                            visible: index < janela.atual.passos.length - 1 }
                                Rectangle { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; radius: 12; color: Qt.rgba(1, 0.71, 0.43, 0.2)
                                            Text { anchors.centerIn: parent; text: index + 1; color: janela.realce; font.pixelSize: 12; font.weight: Font.Bold } }
                                Image { x: 48; anchors.verticalCenter: parent.verticalCenter; width: 22; height: 22; sourceSize: Qt.size(44, 44)
                                        source: "image://icone/" + (modelData.icone || janela.iconePasso(modelData)) }
                                Text { x: 80; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80 - acoesP.width - 20; elide: Text.ElideRight
                                       text: rotinas.descrever(modelData); color: janela.texto }
                                Row {
                                    id: acoesP
                                    anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                    Repeater {
                                        model: [["↑", -1], ["↓", 1], ["✕", 0]]
                                        delegate: Rectangle {
                                            required property var modelData
                                            readonly property bool pode: modelData[1] === 0 || (index + modelData[1] >= 0 && index + modelData[1] < janela.atual.passos.length)
                                            width: 30; height: 30; radius: 15; opacity: pode ? 1 : 0.25
                                            color: mp.containsMouse && pode ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                                            Text { anchors.centerIn: parent; text: modelData[0]; color: modelData[1] === 0 ? "#ff8a9e" : janela.suave; font.pixelSize: 15 }
                                            MouseArea {
                                                id: mp; anchors.fill: parent; hoverEnabled: true; enabled: parent.pode; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    const i = index, d = modelData[1]
                                                    janela.mudar(a => { if (d === 0) a.passos.splice(i, 1); else { const t = a.passos[i]; a.passos[i] = a.passos[i + d]; a.passos[i + d] = t } })
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                Botao { texto: "+  Adicionar passo"; onCarregado: dlgPasso.open() }

                Text { text: "Quando"; color: janela.texto; font.pixelSize: 15; font.weight: Font.DemiBold; topPadding: 8 }
                Flow {
                    Layout.fillWidth: true; spacing: 8
                    Repeater {
                        model: [["manual", "Ao tocar no Deck"], ["hora", "A uma hora"], ["entrar", "Ao entrar na sessão"]]
                        delegate: Pilula {
                            required property var modelData
                            texto: modelData[1]; sel: janela.atual && (janela.atual.gatilho || {}).tipo === modelData[0]
                            onCarregado: janela.mudar(a => { a.gatilho = Object.assign({ hora: "08:00", dias: [1, 2, 3, 4, 5] }, a.gatilho || {}); a.gatilho.tipo = modelData[0] })
                        }
                    }
                }
                RowLayout {
                    visible: janela.atual !== null && (janela.atual.gatilho || {}).tipo === "hora"
                    spacing: 8
                    TextField {
                        id: horaR
                        implicitWidth: 90; font.pixelSize: 16; color: janela.texto; horizontalAlignment: Text.AlignHCenter
                        inputMask: "99:99"; text: janela.atual && janela.atual.gatilho ? (janela.atual.gatilho.hora || "08:00") : "08:00"
                        onEditingFinished: {
                            const m = text.match(/^(\d\d):(\d\d)$/)
                            if (m && +m[1] < 24 && +m[2] < 60) janela.mudar(a => a.gatilho.hora = text)
                        }
                        background: Rectangle { radius: 10; color: Qt.rgba(1, 1, 1, 0.05); border.color: horaR.activeFocus ? janela.realce : janela.linha }
                    }
                    Repeater {
                        model: ["seg", "ter", "qua", "qui", "sex", "sáb", "dom"]
                        delegate: Pilula {
                            required property string modelData
                            required property int index
                            readonly property var dias: janela.atual && janela.atual.gatilho ? (janela.atual.gatilho.dias || []) : []
                            texto: modelData; sel: dias.indexOf(index + 1) !== -1; compacta: true
                            onCarregado: janela.mudar(a => {
                                const d = a.gatilho.dias || [], k = d.indexOf(index + 1)
                                if (k >= 0) { if (d.length > 1) d.splice(k, 1) } else d.push(index + 1)
                                a.gatilho.dias = d.sort()
                            })
                        }
                    }
                }
                Text {
                    visible: janela.atual !== null && (janela.atual.gatilho || {}).tipo === "entrar"
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; color: janela.suave; font.pixelSize: 12
                    text: "Corre sozinha sempre que entrar no CarinaeOS."
                }
            }
        }
        // ---- rodapé ----
        Rectangle {
            id: rodape
            visible: janela.atual !== null
            anchors.bottom: parent.bottom; width: parent.width; height: 68; color: janela.lado
            Text { x: 24; anchors.verticalCenter: parent.verticalCenter; width: parent.width - botoesR.width - 48; elide: Text.ElideRight
                   text: rotinas.mensagem; color: janela.suave; font.pixelSize: 12 }
            Row {
                id: botoesR
                anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                Botao {
                    visible: janela.atual !== null && janela.atual.id !== ""
                    texto: apagar.confirmar ? "Apagar mesmo?" : "Apagar"; perigo: true
                    id: apagar; property bool confirmar: false
                    onCarregado: { if (!confirmar) { confirmar = true; return } rotinas.apagar(janela.atual.id); confirmar = false; janela.atual = null
                                   if (rotinas.lista.length) janela.escolher(rotinas.lista[0]) }
                }
                Botao {
                    readonly property var i: janela.atual ? janela.info(janela.atual.id) : null
                    texto: i && i.noDeck ? "✓ No Deck" : "Pôr no Deck"
                    onCarregado: { const id = janela.sujo ? janela.salvar() : janela.atual.id; if (id) rotinas.porNoDeck(id) }
                }
                Botao {
                    texto: "▶  Testar"
                    onCarregado: { const id = janela.sujo ? janela.salvar() : janela.atual.id; if (id) rotinas.testar(id) }
                }
                Botao { texto: "Salvar"; principal: true; ativo: janela.sujo; onCarregado: janela.salvar() }
            }
        }
    }

    // ---- escolher o ícone -------------------------------------------------------------------------------
    Popup {
        id: dlgIcone
        anchors.centerIn: parent; modal: true; padding: 18
        background: Rectangle { radius: 16; color: janela.cartao; border.color: janela.linha }
        contentItem: Grid {
            columns: 6; spacing: 8
            Repeater {
                model: janela.icones
                delegate: Rectangle {
                    required property string modelData
                    width: 52; height: 52; radius: 12
                    color: janela.atual && janela.atual.icone === modelData ? Qt.rgba(1, 0.71, 0.43, 0.25) : mic.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Image { anchors.centerIn: parent; width: 32; height: 32; sourceSize: Qt.size(64, 64); source: "image://icone/" + modelData }
                    MouseArea { id: mic; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { janela.mudar(a => a.icone = modelData); dlgIcone.close() } }
                }
            }
        }
    }

    // ---- acrescentar um passo ---------------------------------------------------------------------------------
    Popup {
        id: dlgPasso
        objectName: "dlgPasso"
        property string aba: "apps"
        property string modoApp: "abrir"
        property string modoAcao: "ligar"
        property string procura: ""
        function juntar(p) { janela.mudar(a => a.passos.push(p)); close() }
        anchors.centerIn: parent; modal: true
        width: Math.min(janela.width - 60, 720); height: Math.min(janela.height - 60, 560); padding: 0
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }
        background: Rectangle { radius: 18; color: janela.cartao; border.color: janela.linha }
        onOpened: procura = ""
        contentItem: Item {
            Text { x: 22; y: 18; text: "Adicionar um passo"; color: janela.texto; font.pixelSize: 18; font.weight: Font.DemiBold }
            Row {
                x: 22; y: 54; spacing: 6
                Repeater {
                    model: [["apps", "Aplicativos"], ["sis", "Sistema e música"], ["casa", "Casa"], ["outros", "Outros"]]
                    delegate: Pilula { required property var modelData; texto: modelData[1]; sel: dlgPasso.aba === modelData[0]; onCarregado: dlgPasso.aba = modelData[0] }
                }
            }
            Item {
                x: 22; y: 100; width: parent.width - 44; height: parent.height - 100 - 18

                // aplicativos: abrir ou fechar
                ColumnLayout {
                    visible: dlgPasso.aba === "apps"; anchors.fill: parent; spacing: 8
                    RowLayout {
                        spacing: 6
                        Pilula { texto: "Abrir"; sel: dlgPasso.modoApp === "abrir"; onCarregado: dlgPasso.modoApp = "abrir" }
                        Pilula { texto: "Fechar (pergunta se quer salvar)"; sel: dlgPasso.modoApp === "fechar"; onCarregado: dlgPasso.modoApp = "fechar" }
                    }
                    Campo { Layout.fillWidth: true; placeholderText: "Procurar aplicativo"; onTextEdited: dlgPasso.procura = text.toLowerCase() }
                    ListView {
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 2
                        model: rotinas.apps.filter(a => dlgPasso.procura === "" || a.nome.toLowerCase().indexOf(dlgPasso.procura) !== -1)
                        ScrollBar.vertical: ScrollBar {}
                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width - 10; height: 42; radius: 8; color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                            Image { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; sourceSize: Qt.size(48, 48); source: "image://icone/" + modelData.icone }
                            Text { x: 46; anchors.verticalCenter: parent.verticalCenter; text: modelData.nome; color: janela.texto }
                            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: dlgPasso.juntar({ tipo: dlgPasso.modoApp, app: modelData.app, nome: modelData.nome, icone: modelData.icone }) }
                        }
                    }
                }

                // sistema, música e casa: as ações do Deck
                ColumnLayout {
                    visible: dlgPasso.aba === "sis" || dlgPasso.aba === "casa"; anchors.fill: parent; spacing: 8
                    RowLayout {
                        spacing: 6
                        Text { text: "Nos interruptores:"; color: janela.suave; font.pixelSize: 12 }
                        Repeater {
                            model: [["ligar", "Ligar"], ["desligar", "Desligar"], ["tocar", "Alternar"]]
                            delegate: Pilula { required property var modelData; texto: modelData[1]; compacta: true; sel: dlgPasso.modoAcao === modelData[0]; onCarregado: dlgPasso.modoAcao = modelData[0] }
                        }
                    }
                    Flickable {
                        Layout.fillWidth: true; Layout.fillHeight: true; clip: true; contentHeight: gruposCol.height
                        ScrollBar.vertical: ScrollBar {}
                        Column {
                            id: gruposCol
                            width: parent.width - 12; spacing: 12
                            Text { visible: rotinas.catalogo.length === 0; text: "Carregando…"; color: janela.suave }
                            Repeater {
                                model: rotinas.catalogo.filter(g => (dlgPasso.aba === "casa") === g.grupo.startsWith("Casa"))
                                delegate: Column {
                                    id: grp
                                    required property var modelData
                                    width: gruposCol.width; spacing: 6
                                    Text { text: grp.modelData.grupo; color: janela.texto; font.weight: Font.DemiBold }
                                    Text { visible: !!grp.modelData.aviso; width: parent.width; wrapMode: Text.WordWrap; text: grp.modelData.aviso || ""; color: janela.suave; font.pixelSize: 12 }
                                    Flow {
                                        width: parent.width; spacing: 6
                                        Repeater {
                                            model: grp.modelData.itens
                                            delegate: Pilula {
                                                required property var modelData
                                                texto: modelData.nome; icone: modelData.icone
                                                onCarregado: {
                                                    const alt = janela.alternavel(modelData.id)
                                                    dlgPasso.juntar({ tipo: "acao", id: modelData.id, modo: alt ? dlgPasso.modoAcao : "tocar", nome: modelData.nome, icone: modelData.icone })
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // outros: site, volume, esperar, aviso, comando
                Flickable {
                    visible: dlgPasso.aba === "outros"; anchors.fill: parent; clip: true; contentHeight: outrosCol.height
                    ColumnLayout {
                        id: outrosCol
                        width: parent.width - 12; spacing: 14
                        Text { text: "Abrir um site"; color: janela.texto; font.weight: Font.DemiBold }
                        RowLayout { Layout.fillWidth: true; spacing: 8
                            Campo { id: urlP; Layout.fillWidth: true; placeholderText: "ex.: youtube.com" }
                            Botao { texto: "Adicionar"; ativo: urlP.text.trim() !== ""; onCarregado: dlgPasso.juntar({ tipo: "site", url: urlP.text.trim() }) } }
                        Text { text: "Volume do som"; color: janela.texto; font.weight: Font.DemiBold }
                        RowLayout { Layout.fillWidth: true; spacing: 8
                            Slider { id: volP; Layout.fillWidth: true; from: 0; to: 100; stepSize: 5; value: 50 }
                            Text { text: Math.round(volP.value) + "%"; color: janela.texto; Layout.preferredWidth: 44 }
                            Botao { texto: "Adicionar"; onCarregado: dlgPasso.juntar({ tipo: "volume", valor: Math.round(volP.value) }) } }
                        Text { text: "Esperar"; color: janela.texto; font.weight: Font.DemiBold }
                        RowLayout { spacing: 8
                            property int seg: 5
                            id: espP
                            Botao { texto: "−"; onCarregado: espP.seg = Math.max(1, espP.seg - (espP.seg > 60 ? 30 : espP.seg > 10 ? 5 : 1)) }
                            Text { text: espP.seg >= 60 ? Math.floor(espP.seg / 60) + " min" + (espP.seg % 60 ? " " + espP.seg % 60 + " s" : "") : espP.seg + " s"
                                   color: janela.texto; font.pixelSize: 15; horizontalAlignment: Text.AlignHCenter; Layout.preferredWidth: 80 }
                            Botao { texto: "+"; onCarregado: espP.seg = Math.min(3600, espP.seg + (espP.seg >= 60 ? 30 : espP.seg >= 10 ? 5 : 1)) }
                            Botao { texto: "Adicionar"; onCarregado: dlgPasso.juntar({ tipo: "esperar", segundos: espP.seg }) } }
                        Text { text: "Mostrar um aviso"; color: janela.texto; font.weight: Font.DemiBold }
                        RowLayout { Layout.fillWidth: true; spacing: 8
                            Campo { id: avisoP; Layout.fillWidth: true; placeholderText: "ex.: Hora da pausa!" }
                            Botao { texto: "Adicionar"; ativo: avisoP.text.trim() !== ""; onCarregado: dlgPasso.juntar({ tipo: "aviso", texto: avisoP.text.trim() }) } }
                        Text { text: "Comando (avançado)"; color: janela.texto; font.weight: Font.DemiBold }
                        RowLayout { Layout.fillWidth: true; spacing: 8
                            Campo { id: cmdP; Layout.fillWidth: true; placeholderText: "um comando do terminal" }
                            Botao { texto: "Adicionar"; ativo: cmdP.text.trim() !== ""; onCarregado: dlgPasso.juntar({ tipo: "comando", cmd: cmdP.text.trim() }) } }
                    }
                }
            }
        }
    }

    // ---- peças ---------------------------------------------------------------------------------------------
    component Botao: Rectangle {
        id: bt
        property string texto: ""
        property bool principal: false
        property bool perigo: false
        property bool ativo: true
        signal carregado()
        implicitWidth: tb.implicitWidth + 28; implicitHeight: 36; radius: 8
        opacity: ativo ? 1 : 0.4
        color: principal ? (mb.containsMouse && ativo ? Qt.lighter(janela.realce, 1.08) : janela.realce)
             : perigo ? (mb.containsMouse ? Qt.rgba(1, 0.4, 0.5, 0.25) : Qt.rgba(1, 0.4, 0.5, 0.12))
             : (mb.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
        Text { id: tb; anchors.centerIn: parent; text: bt.texto; color: bt.principal ? "#2a1606" : bt.perigo ? "#ff9db0" : janela.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
        MouseArea { id: mb; anchors.fill: parent; enabled: bt.ativo; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bt.carregado() }
    }
    component Pilula: Rectangle {
        id: pl
        property string texto: ""
        property string icone: ""
        property bool sel: false
        property bool compacta: false
        signal carregado()
        implicitWidth: lin.implicitWidth + (compacta ? 20 : 26); implicitHeight: compacta ? 30 : 34; radius: implicitHeight / 2
        color: sel ? Qt.rgba(1, 0.71, 0.43, 0.22) : mpl.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
        border.width: 1; border.color: sel ? janela.realce : Qt.rgba(1, 1, 1, 0.1)
        Row {
            id: lin
            anchors.centerIn: parent; spacing: 6
            Image { visible: pl.icone !== ""; width: 18; height: 18; sourceSize: Qt.size(36, 36); source: pl.icone !== "" ? "image://icone/" + pl.icone : ""; anchors.verticalCenter: parent.verticalCenter }
            Text { text: pl.texto; color: pl.sel ? janela.realce : janela.texto; font.pixelSize: pl.compacta ? 12 : 13; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: mpl; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pl.carregado() }
    }
    component Campo: TextField {
        color: janela.texto; placeholderTextColor: janela.suave
        background: Rectangle { radius: 8; color: Qt.rgba(1, 1, 1, 0.05); border.color: parent.activeFocus ? janela.realce : janela.linha }
    }
}
