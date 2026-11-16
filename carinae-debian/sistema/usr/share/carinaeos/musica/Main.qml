// CarinaeOS - Música: leitor e biblioteca, ligado ao MPD (e ao Home Assistant)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: janela
    // cabe no ecrã sem ficar por baixo da Dock
    width: 1180; height: 760
    minimumWidth: 860; minimumHeight: 540
    visible: true
    title: "Música"
    color: "#0c0a14"
    font.family: "Inter"; font.pixelSize: 14

    readonly property color ambar: "#ffb46e"
    readonly property color rosa: "#ff6f91"
    readonly property color texto: "#f6f2ff"
    readonly property color suave: "#b9b0cc"
    readonly property color cartao: Qt.rgba(1, 1, 1, 0.05)
    property string pagina: "albuns"
    property var albumAberto: null
    property string artistaAberto: ""
    property string filtro: ""
    readonly property var t: musica.tocando

    function hms(s) {
        s = Math.max(0, Math.floor(s || 0))
        var m = Math.floor(s / 60), r = s % 60
        return m + ":" + (r < 10 ? "0" : "") + r
    }
    function bate(m) {
        if (!janela.filtro) return true
        var f = janela.filtro.toLowerCase()
        return (m.titulo || m.album || m.nome || "").toLowerCase().indexOf(f) >= 0
            || (m.artista || "").toLowerCase().indexOf(f) >= 0
            || (m.album || "").toLowerCase().indexOf(f) >= 0
    }

    // fundo: a capa do que está a tocar, desfocada pela transparência
    Image {
        anchors.fill: parent; source: janela.t.capa || "file:///usr/share/backgrounds/carinaeos/eta-carinae.jpg"
        fillMode: Image.PreserveAspectCrop; asynchronous: true; opacity: 0.5
    }
    Rectangle { anchors.fill: parent; color: "#0c0a14"; opacity: 0.88 }

    // ---- menu de contexto partilhado (adicionar a lista) -------------------------------------------
    property string ficheiroMenu: ""
    Menu {
        id: menuMusica
        MenuItem { text: "Tocar a seguir à fila"; onTriggered: musica.adicionarFila(janela.ficheiroMenu) }
        Menu {
            id: subListas
            title: "Adicionar à lista"
            Instantiator {
                model: musica.listas
                delegate: MenuItem {
                    required property var modelData
                    text: modelData.nome
                    onTriggered: musica.adicionarALista(janela.ficheiroMenu, modelData.nome)
                }
                onObjectAdded: (i, o) => subListas.insertItem(i, o)
                onObjectRemoved: (i, o) => subListas.removeItem(o)
            }
            MenuSeparator { }
            MenuItem { text: "Nova lista…"; onTriggered: { novaLista.ficheiro = janela.ficheiroMenu; novaLista.open() } }
        }
    }

    Dialog {
        id: novaLista
        property string ficheiro: ""
        anchors.centerIn: parent; modal: true; width: 420
        title: ficheiro ? "Nova lista" : "Salvar a fila como lista"
        background: Rectangle { color: "#1b1726"; radius: 16; border.color: Qt.rgba(1, 1, 1, 0.1) }
        header: Text { text: novaLista.title; color: janela.texto; font.pixelSize: 18; font.weight: Font.Bold; padding: 20; bottomPadding: 6 }
        contentItem: Column {
            spacing: 10
            Text { width: 380; wrapMode: Text.Wrap; color: janela.suave; font.pixelSize: 13
                   text: "Cada lista aparece no Home Assistant como uma «fonte» do leitor de música." }
            Campo { id: nomeLista; width: 380; placeholderText: "Nome da lista (ex.: Sala · Jantar)" }
        }
        footer: Row {
            layoutDirection: Qt.RightToLeft; spacing: 10; padding: 16
            Botao { texto: "Salvar"; destaque: true
                onClicked: {
                    if (!nomeLista.text.trim()) return
                    if (novaLista.ficheiro) musica.adicionarALista(novaLista.ficheiro, nomeLista.text.trim())
                    else musica.guardarFilaComo(nomeLista.text.trim())
                    nomeLista.text = ""; novaLista.close()
                    musica.recarregar()
                } }
            Botao { texto: "Cancelar"; onClicked: novaLista.close() }
        }
    }

    Dialog {
        id: novaRadio
        anchors.centerIn: parent; modal: true; width: 460
        background: Rectangle { color: "#1b1726"; radius: 16; border.color: Qt.rgba(1, 1, 1, 0.1) }
        header: Text { text: "Adicionar rádio da internet"; color: janela.texto; font.pixelSize: 18; font.weight: Font.Bold; padding: 20; bottomPadding: 6 }
        contentItem: Column {
            spacing: 10
            Campo { id: nomeRadio; width: 420; placeholderText: "Nome (ex.: Antena 3)" }
            Campo { id: urlRadio; width: 420; placeholderText: "Endereço da transmissão (http://…)" }
        }
        footer: Row {
            layoutDirection: Qt.RightToLeft; spacing: 10; padding: 16
            Botao { texto: "Adicionar"; destaque: true
                onClicked: { musica.adicionarRadio(nomeRadio.text, urlRadio.text); nomeRadio.text = ""; urlRadio.text = ""; novaRadio.close() } }
            Botao { texto: "Cancelar"; onClicked: novaRadio.close() }
        }
    }

    // ---- escolher músicas para uma lista (nova ou existente) ----------------------------------
    Dialog {
        id: escolherMusicas
        property string modo: "nova"
        property string lista: ""
        property var escolhidas: []
        property string procura: ""
        function abrir(m, l) { modo = m; lista = l; escolhidas = []; procura = ""; nomeNova.text = ""; open() }
        function alternar(f) {
            const e = escolhidas.slice(); const i = e.indexOf(f)
            if (i === -1) e.push(f); else e.splice(i, 1)
            escolhidas = e
        }
        anchors.centerIn: parent; modal: true
        width: Math.min(janela.width - 80, 640); height: Math.min(janela.height - 60, 620)
        background: Rectangle { color: "#1b1726"; radius: 16; border.color: Qt.rgba(1, 1, 1, 0.1) }
        header: Text { text: escolherMusicas.modo === "nova" ? "Nova lista" : "Adicionar a «" + escolherMusicas.lista + "»"
                       color: janela.texto; font.pixelSize: 18; font.weight: Font.Bold; padding: 20; bottomPadding: 6; elide: Text.ElideRight }
        contentItem: ColumnLayout {
            spacing: 10
            Campo { id: nomeNova; visible: escolherMusicas.modo === "nova"; Layout.fillWidth: true; placeholderText: "Nome da lista (é o nome da fonte no Home Assistant)" }
            Campo { Layout.fillWidth: true; placeholderText: "Procurar música, artista ou álbum"; onTextChanged: escolherMusicas.procura = text.toLowerCase() }
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: escolherMusicas.escolhidas.length + " escolhidas"; color: janela.suave; font.pixelSize: 13 }
                Text { text: "Escolher todas as que aparecem"; color: janela.ambar; font.pixelSize: 13
                       MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                   onClicked: { const e = escolherMusicas.escolhidas.slice(); for (const m of listaEscolha.model) if (e.indexOf(m.ficheiro) === -1) e.push(m.ficheiro); escolherMusicas.escolhidas = e } } }
            }
            ListView {
                id: listaEscolha
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 2
                model: musica.musicas.filter(m => !escolherMusicas.procura
                    || (m.titulo + " " + m.artista + " " + m.album + " " + m.ficheiro).toLowerCase().indexOf(escolherMusicas.procura) >= 0)
                ScrollBar.vertical: ScrollBar { }
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool marcada: escolherMusicas.escolhidas.indexOf(modelData.ficheiro) !== -1
                    width: listaEscolha.width; height: 44; radius: 8
                    color: marcada ? Qt.rgba(1, 0.7, 0.43, 0.14) : (mesc.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                    MouseArea { id: mesc; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: escolherMusicas.alternar(modelData.ficheiro) }
                    Row {
                        x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                        Rectangle {
                            width: 20; height: 20; radius: 6; anchors.verticalCenter: parent.verticalCenter
                            color: parent.parent.marcada ? janela.ambar : "transparent"; border.color: parent.parent.marcada ? janela.ambar : janela.suave
                            Text { anchors.centerIn: parent; text: "✓"; visible: parent.parent.parent.marcada; color: "#1a1208"; font.pixelSize: 13; font.bold: true }
                        }
                        Column {
                            Text { text: modelData.titulo; color: janela.texto; font.pixelSize: 14; width: listaEscolha.width - 60; elide: Text.ElideRight }
                            Text { text: modelData.artista + " · " + modelData.album; color: janela.suave; font.pixelSize: 12; width: listaEscolha.width - 60; elide: Text.ElideRight }
                        }
                    }
                }
            }
        }
        footer: Row {
            layoutDirection: Qt.RightToLeft; spacing: 10; padding: 16
            Botao { texto: escolherMusicas.modo === "nova" ? "Criar lista" : "Adicionar"; destaque: true
                onClicked: {
                    if (escolherMusicas.modo === "nova") {
                        if (!nomeNova.text.trim()) { nomeNova.forceActiveFocus(); return }
                        musica.criarLista(nomeNova.text.trim(), escolherMusicas.escolhidas)
                    } else {
                        musica.adicionarVariasALista(escolherMusicas.lista, escolherMusicas.escolhidas)
                    }
                    escolherMusicas.close()
                } }
            Botao { texto: "Cancelar"; onClicked: escolherMusicas.close() }
        }
    }

    // ---- lista a partir de uma pasta ---------------------------------------------------------------
    Dialog {
        id: deUmaPasta
        anchors.centerIn: parent; modal: true
        width: Math.min(janela.width - 80, 560); height: Math.min(janela.height - 60, 560)
        background: Rectangle { color: "#1b1726"; radius: 16; border.color: Qt.rgba(1, 1, 1, 0.1) }
        header: Column {
            padding: 20; bottomPadding: 6; spacing: 4
            Text { text: "Lista a partir de uma pasta"; color: janela.texto; font.pixelSize: 18; font.weight: Font.Bold }
            Text { text: "A lista fica com o nome da pasta e todas as músicas dela."; color: janela.suave; font.pixelSize: 13 }
        }
        contentItem: ListView {
            id: listaPastas
            clip: true; spacing: 2
            model: musica.pastasMusica
            ScrollBar.vertical: ScrollBar { }
            delegate: Rectangle {
                required property var modelData
                width: listaPastas.width; height: 46; radius: 8
                color: mpas.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                MouseArea { id: mpas; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { musica.listaDaPasta(modelData.caminho); deUmaPasta.close() } }
                Row {
                    x: 10 + (modelData.caminho.split("/").length - 1) * 16; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                    Image { source: "image://icone/folder-music"; width: 22; height: 22; sourceSize: Qt.size(44, 44); anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        Text { text: modelData.nome; color: janela.texto; font.pixelSize: 14 }
                        Text { text: modelData.musicas + (modelData.musicas === 1 ? " música" : " músicas"); color: janela.suave; font.pixelSize: 12 }
                    }
                }
            }
        }
        footer: Row { layoutDirection: Qt.RightToLeft; padding: 16; Botao { texto: "Fechar"; onClicked: deUmaPasta.close() } }
    }

    Dialog {
        id: renomear
        property alias campo: campoNome
        anchors.centerIn: parent; modal: true; width: 420
        background: Rectangle { color: "#1b1726"; radius: 16; border.color: Qt.rgba(1, 1, 1, 0.1) }
        header: Text { text: "Mudar o nome da lista"; color: janela.texto; font.pixelSize: 18; font.weight: Font.Bold; padding: 20; bottomPadding: 6 }
        contentItem: Campo { id: campoNome; placeholderText: "Novo nome" }
        footer: Row {
            layoutDirection: Qt.RightToLeft; spacing: 10; padding: 16
            Botao { texto: "Salvar"; destaque: true; onClicked: { musica.renomearLista(musica.listaAberta.nome, campoNome.text); renomear.close() } }
            Botao { texto: "Cancelar"; onClicked: renomear.close() }
        }
    }

    Dialog {
        id: apagar
        property string nome: ""
        anchors.centerIn: parent; modal: true; width: 420
        background: Rectangle { color: "#1b1726"; radius: 16; border.color: Qt.rgba(1, 1, 1, 0.1) }
        header: Text { text: "Apagar a lista «" + apagar.nome + "»?"; color: janela.texto; font.pixelSize: 17; font.weight: Font.Bold; padding: 20; bottomPadding: 6; width: 400; elide: Text.ElideRight }
        contentItem: Text { text: "As músicas não são apagadas, só a lista (e a fonte no Home Assistant)."; color: janela.suave; wrapMode: Text.Wrap }
        footer: Row {
            layoutDirection: Qt.RightToLeft; spacing: 10; padding: 16
            Botao { texto: "Apagar"; destaque: true; onClicked: { musica.apagarLista(apagar.nome); apagar.close() } }
            Botao { texto: "Cancelar"; onClicked: apagar.close() }
        }
    }

    // ---- componentes ----------------------------------------------------------------------------------
    component Botao: Rectangle {
        id: b
        property string texto
        property string icone: ""
        property bool destaque: false
        signal clicked()
        implicitWidth: lin.implicitWidth + 28; implicitHeight: 36; radius: 18
        color: destaque ? (mb.containsMouse ? Qt.lighter(janela.ambar, 1.1) : janela.ambar)
                        : (mb.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
        Row {
            id: lin; anchors.centerIn: parent; spacing: 8
            Image { visible: b.icone !== ""; source: b.icone ? "image://icone/" + b.icone : ""; width: 16; height: 16; sourceSize: Qt.size(32, 32); anchors.verticalCenter: parent.verticalCenter }
            Text { text: b.texto; color: b.destaque ? "#1a1208" : janela.texto; font.pixelSize: 13; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicked() }
    }
    component Campo: TextField {
        color: janela.texto; placeholderTextColor: janela.suave; font.pixelSize: 14
        leftPadding: 14; implicitHeight: 40
        background: Rectangle { radius: 10; color: Qt.rgba(1, 1, 1, 0.06); border.color: parent.activeFocus ? janela.ambar : Qt.rgba(1, 1, 1, 0.1) }
    }
    component BotaoRedondo: Rectangle {
        id: br
        property string icone
        property bool ativo: false
        property int lado: 38
        signal clicked()
        width: lado; height: lado; radius: lado / 2
        color: mr.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
        Image { anchors.centerIn: parent; source: "image://icone/" + br.icone; width: br.lado * 0.5; height: width; sourceSize: Qt.size(64, 64); opacity: br.ativo || mr.containsMouse ? 1 : 0.75 }
        Rectangle { visible: br.ativo; width: 4; height: 4; radius: 2; color: janela.ambar; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 1 }
        MouseArea { id: mr; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: br.clicked() }
    }
    component Capa: Rectangle {
        property string fonte
        property string letra: "?"
        radius: 10; clip: true
        gradient: Gradient {
            GradientStop { position: 0; color: "#3b2a55" }
            GradientStop { position: 1; color: "#7a3550" }
        }
        Text { visible: !img.visible; anchors.centerIn: parent; text: parent.letra; color: Qt.rgba(1, 1, 1, 0.7); font.pixelSize: parent.width * 0.38; font.weight: Font.Bold }
        Image { id: img; anchors.fill: parent; source: parent.fonte; visible: parent.fonte !== "" && status === Image.Ready
                fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(400, 400) }
    }
    component LinhaMusica: Rectangle {
        id: lm
        required property var modelData
        required property int index
        property string contexto: "todas"
        property bool mostrarAlbum: true
        readonly property bool estaTocar: janela.t.titulo === modelData.titulo && janela.t.album === modelData.album
        width: ListView.view ? ListView.view.width : 600; height: 48; radius: 8
        color: estaTocar ? Qt.rgba(1, 0.7, 0.43, 0.14) : (ml.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 12
            Text { Layout.preferredWidth: 26; text: lm.estaTocar ? "♪" : (lm.modelData.faixa || lm.index + 1); color: lm.estaTocar ? janela.ambar : janela.suave; font.pixelSize: 13; horizontalAlignment: Text.AlignRight }
            Column {
                Layout.fillWidth: true
                Text { width: parent.width; text: lm.modelData.titulo; color: lm.estaTocar ? janela.ambar : janela.texto; elide: Text.ElideRight; font.pixelSize: 14 }
                Text { width: parent.width; text: lm.modelData.artista + (lm.mostrarAlbum ? " · " + lm.modelData.album : ""); color: janela.suave; elide: Text.ElideRight; font.pixelSize: 12 }
            }
            Text { text: janela.hms(lm.modelData.duracao); color: janela.suave; font.pixelSize: 12 }
            BotaoRedondo { icone: "overflow-menu"; lado: 32; onClicked: { janela.ficheiroMenu = lm.modelData.ficheiro; menuMusica.popup() } }
        }
        MouseArea {
            id: ml; anchors.fill: parent; anchors.rightMargin: 44; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
            onDoubleClicked: musica.tocarMusica(lm.modelData.ficheiro, lm.contexto)
            onClicked: (e) => { if (e.button === Qt.RightButton) { janela.ficheiroMenu = lm.modelData.ficheiro; menuMusica.popup() } }
        }
    }

    // ---- barra lateral ----------------------------------------------------------------------------------
    Rectangle {
        id: lado
        width: 232; anchors.top: parent.top; anchors.bottom: barra.top
        color: Qt.rgba(1, 1, 1, 0.035)
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.07) }
        Column {
            x: 14; y: 20; width: parent.width - 28; spacing: 3
            Row {
                spacing: 12; leftPadding: 6; bottomPadding: 16
                Image { source: "image://icone/carinaeos-musica"; width: 38; height: 38; sourceSize: Qt.size(76, 76) }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Música"; color: janela.texto; font.pixelSize: 19; font.weight: Font.Bold }
                    Text { text: musica.ligado ? "Servidor ligado" : "Ligando o servidor…"; color: musica.ligado ? "#7fd8a6" : janela.suave; font.pixelSize: 12 }
                }
            }
            Repeater {
                model: [
                    { id: "agora", nome: "Tocando", icone: "media-playback-start" },
                    { id: "albuns", nome: "Álbuns", icone: "media-optical-audio" },
                    { id: "artistas", nome: "Artistas", icone: "view-media-artist" },
                    { id: "musicas", nome: "Músicas", icone: "view-media-track" },
                    { id: "listas", nome: "Listas e rádios", icone: "view-media-playlist" },
                    { id: "fila", nome: "Fila", icone: "media-playlist-append" },
                    { id: "sep" },
                    { id: "biblioteca", nome: "Biblioteca", icone: "folder-music" },
                    { id: "casa", nome: "Home Assistant", icone: "go-home" }
                ]
                delegate: Item {
                    required property var modelData
                    width: parent.width; height: modelData.id === "sep" ? 18 : 38
                    Rectangle {
                        visible: modelData.id !== "sep"
                        readonly property bool ativo: janela.pagina === modelData.id
                        anchors.fill: parent; radius: 10
                        color: ativo ? Qt.rgba(1, 0.62, 0.45, 0.24) : (ms.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        Row {
                            x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                            Image { source: modelData.icone ? "image://icone/" + modelData.icone : ""; width: 18; height: 18; sourceSize: Qt.size(36, 36) }
                            Text { text: modelData.nome || ""; color: janela.texto; font.pixelSize: 14 }
                        }
                        MouseArea { id: ms; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { janela.pagina = modelData.id; janela.albumAberto = null; janela.artistaAberto = "" } }
                    }
                }
            }
        }
        Text {
            anchors.bottom: parent.bottom; anchors.margins: 16; x: 18; width: parent.width - 36
            text: musica.albuns.length + " álbuns · " + musica.musicas.length + " músicas"
            color: janela.suave; font.pixelSize: 12
        }
    }

    // ---- conteúdo ------------------------------------------------------------------------------------------
    Item {
        id: conteudo
        anchors { left: lado.right; right: parent.right; top: parent.top; bottom: barra.top }

        // cabeçalho com pesquisa
        RowLayout {
            id: cab
            visible: ["albuns", "artistas", "musicas"].indexOf(janela.pagina) >= 0
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
            height: visible ? 40 : 0
            Text {
                Layout.fillWidth: true
                text: janela.albumAberto ? "" : janela.artistaAberto ? janela.artistaAberto
                      : ({ albuns: "Álbuns", artistas: "Artistas", musicas: "Músicas" })[janela.pagina] || ""
                color: janela.texto; font.pixelSize: 26; font.weight: Font.Bold; elide: Text.ElideRight
            }
            Campo { Layout.preferredWidth: 280; placeholderText: "Procurar na biblioteca"; onTextChanged: janela.filtro = text }
        }

        // -- Álbuns (grelha) --
        GridView {
            id: grelha
            visible: janela.pagina === "albuns" && !janela.albumAberto || (janela.pagina === "artistas" && janela.artistaAberto && !janela.albumAberto)
            anchors { left: parent.left; right: parent.right; top: cab.bottom; bottom: parent.bottom; margins: 24; topMargin: 18 }
            clip: true
            readonly property int colunas: Math.max(2, Math.floor(width / 200))
            cellWidth: width / colunas; cellHeight: cellWidth + 52
            model: musica.albuns.filter(a => (!janela.artistaAberto || a.artista === janela.artistaAberto) && janela.bate(a))
            ScrollBar.vertical: ScrollBar { }
            delegate: Item {
                required property var modelData
                width: grelha.cellWidth; height: grelha.cellHeight
                Column {
                    anchors.fill: parent; anchors.margins: 8; spacing: 8
                    Capa {
                        width: parent.width; height: width; fonte: modelData.capa; letra: (modelData.album || "?")[0]
                        scale: ma.containsMouse ? 1.03 : 1
                        Behavior on scale { NumberAnimation { duration: 140 } }
                        Rectangle {
                            visible: ma.containsMouse; width: 44; height: 44; radius: 22; color: janela.ambar
                            anchors { right: parent.right; bottom: parent.bottom; margins: 10 }
                            Image { anchors.centerIn: parent; source: "image://icone/media-playback-start"; width: 20; height: 20; sourceSize: Qt.size(40, 40) }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: musica.tocarAlbum(modelData.chave) }
                        }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; z: -1; cursorShape: Qt.PointingHandCursor
                            onClicked: janela.albumAberto = modelData }
                    }
                    Text { width: parent.width; text: modelData.album; color: janela.texto; elide: Text.ElideRight; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { width: parent.width; text: modelData.artista + (modelData.ano ? " · " + modelData.ano : ""); color: janela.suave; elide: Text.ElideRight; font.pixelSize: 12 }
                }
            }
            Text {
                visible: grelha.count === 0; anchors.centerIn: parent; width: 420; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                color: janela.suave; font.pixelSize: 15
                text: musica.musicas.length ? "Nada encontrado." : "A biblioteca está vazia.\nPonha música na pasta Músicas ou junte outras pastas em «Biblioteca»."
            }
        }

        // -- Álbum aberto --
        Item {
            visible: janela.albumAberto !== null
            anchors { fill: parent; margins: 24 }
            BotaoRedondo { id: voltar; icone: "go-previous"; onClicked: janela.albumAberto = null }
            Row {
                id: topoAlbum
                anchors { left: parent.left; right: parent.right; top: voltar.bottom; topMargin: 8 }
                spacing: 24
                Capa { width: 200; height: 200; fonte: janela.albumAberto ? janela.albumAberto.capa : ""; letra: janela.albumAberto ? (janela.albumAberto.album || "?")[0] : "" }
                Column {
                    anchors.bottom: parent.bottom; spacing: 6; width: parent.width - 230
                    Text { text: "ÁLBUM"; color: janela.ambar; font.pixelSize: 11; font.letterSpacing: 2; font.weight: Font.Bold }
                    Text { width: parent.width; text: janela.albumAberto ? janela.albumAberto.album : ""; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                    Text { text: janela.albumAberto ? janela.albumAberto.artista + (janela.albumAberto.ano ? " · " + janela.albumAberto.ano : "") + " · " + janela.albumAberto.faixas + " músicas" : ""; color: janela.suave; font.pixelSize: 14 }
                    Item { width: 1; height: 8 }
                    Botao { texto: "Tocar"; icone: "media-playback-start"; destaque: true; onClicked: musica.tocarAlbum(janela.albumAberto.chave) }
                }
            }
            ListView {
                anchors { left: parent.left; right: parent.right; top: topoAlbum.bottom; bottom: parent.bottom; topMargin: 20 }
                clip: true; spacing: 2
                model: janela.albumAberto ? musica.musicas.filter(m => m.chave === janela.albumAberto.chave) : []
                ScrollBar.vertical: ScrollBar { }
                delegate: LinhaMusica { contexto: "album"; mostrarAlbum: false }
            }
        }

        // -- Artistas --
        ListView {
            id: listaArtistas
            visible: janela.pagina === "artistas" && !janela.artistaAberto
            anchors { left: parent.left; right: parent.right; top: cab.bottom; bottom: parent.bottom; margins: 24; topMargin: 18 }
            clip: true; spacing: 2
            model: musica.artistas.filter(a => !janela.filtro || a.nome.toLowerCase().indexOf(janela.filtro.toLowerCase()) >= 0)
            ScrollBar.vertical: ScrollBar { }
            delegate: Rectangle {
                required property var modelData
                width: listaArtistas.width; height: 60; radius: 10
                color: mart.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                Row {
                    x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 14
                    Rectangle {
                        width: 44; height: 44; radius: 22; color: Qt.rgba(1, 0.62, 0.45, 0.25)
                        Text { anchors.centerIn: parent; text: (modelData.nome || "?")[0]; color: janela.ambar; font.pixelSize: 18; font.weight: Font.Bold }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: modelData.nome; color: janela.texto; font.pixelSize: 15 }
                        Text { text: modelData.musicas + (modelData.musicas === 1 ? " música" : " músicas"); color: janela.suave; font.pixelSize: 12 }
                    }
                }
                BotaoRedondo { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                               icone: "media-playback-start"; onClicked: musica.tocarArtista(modelData.nome) }
                MouseArea { id: mart; anchors.fill: parent; anchors.rightMargin: 56; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: janela.artistaAberto = modelData.nome }
            }
        }

        // -- Músicas --
        ListView {
            id: listaMusicas
            visible: janela.pagina === "musicas"
            anchors { left: parent.left; right: parent.right; top: cab.bottom; bottom: parent.bottom; margins: 24; topMargin: 18 }
            clip: true; spacing: 2; reuseItems: true
            model: musica.musicas.filter(m => janela.bate(m))
            ScrollBar.vertical: ScrollBar { }
            delegate: LinhaMusica { contexto: "todas" }
        }

        // -- A tocar (capa grande + letra) --
        Item {
            visible: janela.pagina === "agora"
            anchors { fill: parent; margins: 32 }
            Column {
                id: colCapa
                width: Math.min(parent.width * 0.42, parent.height - 120)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 14
                Capa { width: parent.width; height: width; radius: 18; fonte: janela.t.capa; letra: (janela.t.album || janela.t.titulo || "♪")[0] }
                Text { width: parent.width; text: janela.t.titulo || "Nada a tocar"; color: janela.texto; font.pixelSize: 24; font.weight: Font.Bold; elide: Text.ElideRight }
                Text { width: parent.width; text: [janela.t.artista, janela.t.album].filter(x => x).join(" · "); color: janela.suave; font.pixelSize: 15; elide: Text.ElideRight }
            }
            Item {
                anchors { left: colCapa.right; leftMargin: 40; right: parent.right; top: parent.top; bottom: parent.bottom }
                Text { id: tituloLetra; text: "Letra"; color: janela.ambar; font.pixelSize: 12; font.letterSpacing: 2; font.weight: Font.Bold; font.capitalization: Font.AllUppercase }
                Text { anchors.right: parent.right; text: musica.letra.fonte ? "fonte: " + musica.letra.fonte : ""; color: janela.suave; font.pixelSize: 11 }
                // letra sincronizada: a linha atual em destaque
                ListView {
                    id: letraSinc
                    visible: musica.letra.linhas && musica.letra.linhas.length > 0
                    anchors { left: parent.left; right: parent.right; top: tituloLetra.bottom; bottom: parent.bottom; topMargin: 16 }
                    clip: true; spacing: 10
                    model: musica.letra.linhas || []
                    readonly property int atual: {
                        var ls = musica.letra.linhas || [], r = -1
                        for (var i = 0; i < ls.length; i++) if (ls[i].t <= janela.t.tempo + 0.3) r = i
                        return r
                    }
                    onAtualChanged: if (atual >= 0) positionViewAtIndex(atual, ListView.Center)
                    highlightMoveDuration: 400
                    delegate: Text {
                        required property var modelData
                        required property int index
                        width: letraSinc.width; wrapMode: Text.Wrap
                        text: modelData.texto || "♪"
                        color: index === letraSinc.atual ? janela.texto : Qt.rgba(1, 1, 1, index < letraSinc.atual ? 0.3 : 0.45)
                        font.pixelSize: index === letraSinc.atual ? 24 : 20; font.weight: Font.Bold
                        Behavior on font.pixelSize { NumberAnimation { duration: 200 } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: musica.irPara(modelData.t) }
                    }
                }
                ScrollView {
                    visible: !letraSinc.visible
                    anchors { left: parent.left; right: parent.right; top: tituloLetra.bottom; bottom: parent.bottom; topMargin: 16 }
                    clip: true
                    Text {
                        width: parent.parent.width - 20; wrapMode: Text.Wrap; lineHeight: 1.35
                        text: musica.letra.texto || (janela.t.titulo ? "Letra não encontrada para esta música." : "")
                        color: musica.letra.texto ? janela.texto : janela.suave
                        font.pixelSize: musica.letra.texto ? 18 : 14
                    }
                }
            }
        }

        // -- Fila --
        Item {
            visible: janela.pagina === "fila"
            anchors { fill: parent; margins: 24 }
            RowLayout {
                id: cabFila; width: parent.width
                Text { Layout.fillWidth: true; text: "Fila"; color: janela.texto; font.pixelSize: 26; font.weight: Font.Bold }
                Botao { texto: "Salvar como lista"; icone: "document-save"; onClicked: { novaLista.ficheiro = ""; novaLista.open() } }
            }
            ListView {
                anchors { left: parent.left; right: parent.right; top: cabFila.bottom; bottom: parent.bottom; topMargin: 16 }
                clip: true; spacing: 2
                model: musica.fila
                ScrollBar.vertical: ScrollBar { }
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool agora: modelData.pos === janela.t.pos
                    width: ListView.view.width; height: 46; radius: 8
                    color: agora ? Qt.rgba(1, 0.7, 0.43, 0.14) : (mf.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                    Row {
                        x: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 14
                        Text { width: 24; text: agora ? "♪" : modelData.pos + 1; color: agora ? janela.ambar : janela.suave; horizontalAlignment: Text.AlignRight; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            Text { text: modelData.titulo; color: agora ? janela.ambar : janela.texto; font.pixelSize: 14 }
                            Text { text: modelData.artista; color: janela.suave; font.pixelSize: 12 }
                        }
                    }
                    MouseArea { id: mf; anchors.fill: parent; hoverEnabled: true; onDoubleClicked: musica.tocarNaFila(modelData.pos) }
                }
                Text { visible: parent.count === 0; anchors.centerIn: parent; text: "A fila está vazia."; color: janela.suave }
            }
        }

        // -- Listas e rádios --
        Item {
            visible: janela.pagina === "listas" && !musica.listaAberta.nome
            anchors { fill: parent; margins: 24 }
            Column {
                id: cabListas; width: parent.width; spacing: 12
                Text { text: "Listas e rádios"; color: janela.texto; font.pixelSize: 26; font.weight: Font.Bold }
                Flow {
                    width: parent.width; spacing: 10
                    Botao { texto: "Nova lista"; icone: "list-add"; destaque: true; onClicked: escolherMusicas.abrir("nova", "") }
                    Botao { texto: "De uma pasta"; icone: "folder-music"; onClicked: deUmaPasta.open() }
                    Botao { texto: "Salvar a fila"; icone: "document-save"; onClicked: { novaLista.ficheiro = ""; novaLista.open() } }
                    Botao { texto: "Rádio"; icone: "radio"; onClicked: novaRadio.open() }
                }
            }
            Text {
                id: notaListas
                anchors.top: cabListas.bottom; anchors.topMargin: 8; width: parent.width; wrapMode: Text.Wrap
                color: janela.suave; font.pixelSize: 13
                text: "Cada lista é uma «fonte» no Home Assistant (leitor «Música de " + musica.rede.nome + "»). Crie uma lista escolhendo as músicas, a partir de uma pasta, da fila, ou com o botão ⋮ de qualquer música. Clique numa lista para a ver e mudar."
            }
            GridView {
                id: gListas
                anchors { left: parent.left; right: parent.right; top: notaListas.bottom; bottom: parent.bottom; topMargin: 18 }
                clip: true
                readonly property int colunas: Math.max(2, Math.floor(width / 260))
                cellWidth: width / colunas; cellHeight: 92
                model: musica.listas
                delegate: Item {
                    required property var modelData
                    width: gListas.cellWidth; height: gListas.cellHeight
                    Rectangle {
                        anchors.fill: parent; anchors.margins: 6; radius: 14
                        color: mlis.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : janela.cartao
                        border.color: Qt.rgba(1, 1, 1, 0.07)
                        MouseArea { id: mlis; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: musica.abrirLista(modelData.nome) }
                        Row {
                            x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                            Rectangle {
                                width: 48; height: 48; radius: 12
                                gradient: Gradient {
                                    GradientStop { position: 0; color: janela.rosa }
                                    GradientStop { position: 1; color: janela.ambar }
                                }
                                Image { anchors.centerIn: parent; width: 24; height: 24; sourceSize: Qt.size(48, 48)
                                        source: "image://icone/" + (modelData.nome.indexOf("Rádio") === 0 ? "radio" : "view-media-playlist") }
                            }
                            Text { anchors.verticalCenter: parent.verticalCenter; width: gListas.cellWidth - 170; text: modelData.nome; color: janela.texto; font.pixelSize: 15; elide: Text.ElideRight }
                        }
                        Row {
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            BotaoRedondo { icone: "media-playback-start"; onClicked: musica.tocarLista(modelData.nome) }
                            BotaoRedondo { icone: "edit-delete"; onClicked: { apagar.nome = modelData.nome; apagar.open() } }
                        }
                    }
                }
                Text { visible: gListas.count === 0; anchors.centerIn: parent; text: "Ainda não há listas. Clique em «Nova lista»."; color: janela.suave }
            }
        }

        // -- Uma lista aberta --
        Item {
            visible: janela.pagina === "listas" && !!musica.listaAberta.nome
            anchors { fill: parent; margins: 24 }
            Column {
                id: cabLista; width: parent.width; spacing: 12
                RowLayout {
                    width: parent.width; spacing: 10
                    BotaoRedondo { icone: "go-previous"; onClicked: musica.fecharLista() }
                    Column {
                        Layout.fillWidth: true
                        Text { text: "LISTA · FONTE NO HOME ASSISTANT"; color: janela.ambar; font.pixelSize: 11; font.letterSpacing: 2; font.weight: Font.Bold }
                        Text { width: parent.width; text: musica.listaAberta.nome || ""; color: janela.texto; font.pixelSize: 26; font.weight: Font.Bold; elide: Text.ElideRight }
                        Text { text: (musica.listaAberta.itens || []).length + " músicas"; color: janela.suave; font.pixelSize: 13 }
                    }
                }
                Flow {
                    width: parent.width; spacing: 10
                    Botao { texto: "Tocar"; icone: "media-playback-start"; destaque: true; onClicked: musica.tocarLista(musica.listaAberta.nome) }
                    Botao { texto: "Adicionar músicas"; icone: "list-add"; onClicked: escolherMusicas.abrir("adicionar", musica.listaAberta.nome) }
                    Botao { texto: "Mudar o nome"; icone: "edit-rename"; onClicked: { renomear.campo.text = musica.listaAberta.nome; renomear.open() } }
                    Botao { texto: "Apagar"; icone: "edit-delete"; onClicked: { apagar.nome = musica.listaAberta.nome; apagar.open() } }
                }
            }
            ListView {
                id: itensLista
                anchors { left: parent.left; right: parent.right; top: cabLista.bottom; bottom: parent.bottom; topMargin: 18 }
                clip: true; spacing: 2
                model: musica.listaAberta.itens || []
                ScrollBar.vertical: ScrollBar { }
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: itensLista.width; height: 48; radius: 8
                    color: mit.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    MouseArea { id: mit; anchors.fill: parent; hoverEnabled: true
                                onDoubleClicked: musica.tocarListaDesde(musica.listaAberta.nome, modelData.pos) }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 12
                        Text { Layout.preferredWidth: 26; text: index + 1; color: janela.suave; horizontalAlignment: Text.AlignRight }
                        Column {
                            Layout.fillWidth: true
                            Text { width: parent.width; text: modelData.titulo; color: janela.texto; font.pixelSize: 14; elide: Text.ElideRight }
                            Text { width: parent.width; text: modelData.artista; color: janela.suave; font.pixelSize: 12; elide: Text.ElideRight }
                        }
                        Text { text: modelData.duracao > 0 ? janela.hms(modelData.duracao) : ""; color: janela.suave; font.pixelSize: 12 }
                        BotaoRedondo { lado: 32; icone: "go-up"; visible: index > 0; onClicked: musica.moverNaLista(musica.listaAberta.nome, modelData.pos, modelData.pos - 1) }
                        BotaoRedondo { lado: 32; icone: "go-down"; visible: index < itensLista.count - 1; onClicked: musica.moverNaLista(musica.listaAberta.nome, modelData.pos, modelData.pos + 1) }
                        BotaoRedondo { lado: 32; icone: "list-remove"; onClicked: musica.tirarDaLista(musica.listaAberta.nome, modelData.pos) }
                    }
                }
                Text { visible: itensLista.count === 0; anchors.centerIn: parent; text: "A lista está vazia. Clique em «Adicionar músicas»."; color: janela.suave }
            }
        }

        // -- Biblioteca (pastas) --
        Flickable {
            visible: janela.pagina === "biblioteca"
            anchors { fill: parent; margins: 24 }
            contentHeight: colBib.height; clip: true
            Column {
                id: colBib; width: parent.width; spacing: 14
                Text { text: "Biblioteca"; color: janela.texto; font.pixelSize: 26; font.weight: Font.Bold }
                Text { width: parent.width; wrapMode: Text.Wrap; color: janela.suave; font.pixelSize: 13
                       text: "Escolha as pastas onde tem música: no computador, num disco externo ou numa pasta da rede (abra-a primeiro em Meus documentos › Rede). A música não é copiada nem mudada de lugar." }
                Repeater {
                    model: musica.pastas
                    delegate: Rectangle {
                        required property var modelData
                        width: colBib.width; height: 58; radius: 12; color: janela.cartao
                        Row {
                            x: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                            Image { source: "image://icone/folder-music"; width: 28; height: 28; sourceSize: Qt.size(56, 56); anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                Text { text: modelData.nome; color: janela.texto; font.pixelSize: 14 }
                                Text { text: modelData.caminho; color: janela.suave; font.pixelSize: 12 }
                            }
                        }
                        Botao { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                                texto: "Tirar da biblioteca"; onClicked: musica.tirarPasta(modelData.nome) }
                    }
                }
                Flow {
                    width: parent.width; spacing: 10
                    Botao { texto: "Juntar uma pasta…"; icone: "list-add"; destaque: true; onClicked: musica.escolherPasta() }
                    Botao { texto: "Atualizar a biblioteca"; icone: "view-refresh"; onClicked: musica.atualizarBiblioteca() }
                    Botao { texto: "Procurar capas em falta"; icone: "edit-find"; onClicked: musica.procurarCapas() }
                }
                Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }
                Text { text: "Capas e letras"; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
                Row {
                    spacing: 12
                    Switch { id: swNet; checked: musica.rede.internet; onToggled: musica.definirInternet(checked) }
                    Text { anchors.verticalCenter: parent.verticalCenter; width: colBib.width - 80; wrapMode: Text.Wrap; color: janela.suave; font.pixelSize: 13
                           text: "Usar a internet para o que faltar: capas no MusicBrainz / Cover Art Archive e letras no LRCLIB (gratuitos, sem conta). Primeiro usa-se sempre o que vem dentro da própria música e a imagem cover.jpg da pasta." }
                }
            }
        }

        // -- Home Assistant --
        Flickable {
            visible: janela.pagina === "casa"
            anchors { fill: parent; margins: 24 }
            contentHeight: colCasa.height; clip: true
            Column {
                id: colCasa; width: parent.width; spacing: 14
                Text { text: "Home Assistant"; color: janela.texto; font.pixelSize: 26; font.weight: Font.Bold }
                Text { width: parent.width; wrapMode: Text.Wrap; color: janela.suave; font.pixelSize: 13
                       text: "Este computador passa a ser um leitor de música que o Home Assistant (e qualquer programa MPD/mpc) controla. As suas listas aparecem lá como fontes." }
                Rectangle {
                    width: parent.width; height: 74; radius: 14; color: janela.cartao
                    Row {
                        x: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 14
                        Switch { id: swRede; checked: musica.rede.ligada; anchors.verticalCenter: parent.verticalCenter
                                 onToggled: musica.definirRede(checked, senhaMpd.text) }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "Deixar a rede de casa controlar a música"; color: janela.texto; font.pixelSize: 15 }
                            Text { text: musica.rede.ligada ? "Ligado — à espera do Home Assistant" : "Desligado — só este computador"; color: musica.rede.ligada ? "#7fd8a6" : janela.suave; font.pixelSize: 12 }
                        }
                    }
                }
                Row {
                    spacing: 10
                    Campo { id: senhaMpd; width: 300; echoMode: TextInput.Password; placeholderText: musica.rede.temSenha ? "Senha definida (escreva para mudar)" : "Senha opcional para o MPD" }
                    Botao { texto: "Aplicar"; anchors.verticalCenter: parent.verticalCenter; onClicked: { musica.definirRede(swRede.checked, senhaMpd.text); senhaMpd.text = "" } }
                }
                // atualização automática das fontes no Home Assistant
                Rectangle {
                    width: parent.width; height: colAuto.height + 32; radius: 14; color: janela.cartao
                    Column {
                        id: colAuto; x: 18; y: 16; width: parent.width - 36; spacing: 10
                        Text { text: "Fontes sempre atualizadas"; color: janela.texto; font.pixelSize: 15; font.weight: Font.Bold }
                        Text { width: parent.width; wrapMode: Text.Wrap; color: janela.suave; font.pixelSize: 13
                               text: "Com isto, uma lista, rádio ou música nova aparece logo nas fontes do Home Assistant (sem esperar 2 minutos), mesmo com este aplicativo fechado. As listas feitas «De uma pasta» acompanham a pasta sozinhas. O token cria-se no Home Assistant: o seu perfil › Segurança › Tokens de acesso de longa duração › Criar token." }
                        Campo { id: haUrl; width: parent.width; placeholderText: "Endereço do Home Assistant (ex.: http://homeassistant.local:8123)"; text: musica.rede.haUrl }
                        Campo { id: haToken; width: parent.width; echoMode: TextInput.Password
                                placeholderText: musica.rede.haToken ? "Token salvo (cole outro para mudar)" : "Token de acesso de longa duração" }
                        Botao { texto: "Salvar e testar"; destaque: true; onClicked: { musica.definirHomeAssistant(haUrl.text, haToken.text); haToken.text = "" } }
                    }
                }
                Rectangle {
                    width: parent.width; height: dadosHa.height + 32; radius: 14
                    color: Qt.rgba(1, 0.7, 0.43, 0.08); border.color: Qt.rgba(1, 0.7, 0.43, 0.3)
                    Column {
                        id: dadosHa; x: 18; y: 16; width: parent.width - 36; spacing: 8
                        Text { text: "No Home Assistant"; color: janela.ambar; font.pixelSize: 15; font.weight: Font.Bold }
                        Text { width: parent.width; wrapMode: Text.Wrap; color: janela.texto; font.pixelSize: 13; lineHeight: 1.3
                               text: "1. Configurações › Dispositivos e serviços › Adicionar integração › «Music Player Daemon (MPD)».\n2. Preencha:" }
                        Grid {
                            columns: 2; columnSpacing: 18; rowSpacing: 6; leftPadding: 14
                            Text { text: "Anfitrião"; color: janela.suave }
                            TextEdit { text: musica.rede.ip; readOnly: true; selectByMouse: true; color: janela.texto; font.family: "monospace"; font.pixelSize: 14 }
                            Text { text: "Porta"; color: janela.suave }
                            TextEdit { text: String(musica.rede.porta); readOnly: true; selectByMouse: true; color: janela.texto; font.family: "monospace"; font.pixelSize: 14 }
                            Text { text: "Senha"; color: janela.suave }
                            Text { text: musica.rede.temSenha ? "a que definiu acima" : "(deixe vazio)"; color: janela.texto }
                        }
                        Text { width: parent.width; wrapMode: Text.Wrap; color: janela.texto; font.pixelSize: 13; lineHeight: 1.3
                               text: "3. No cartão do leitor, «Fonte» mostra as listas e rádios deste aplicativo.\nO som também pode sair na rede, para outras colunas: http://" + musica.rede.ip + ":8000\nNo terminal:  mpc -h " + musica.rede.ip + " status" }
                    }
                }
            }
        }

        // aviso
        Rectangle {
            id: caixaAviso
            property bool mostrar: false
            visible: mostrar && aviso.text !== ""
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 14 }
            width: aviso.implicitWidth + 32; height: 36; radius: 18; color: "#2a2338"; border.color: Qt.rgba(1, 1, 1, 0.12)
            Text { id: aviso; anchors.centerIn: parent; text: musica.mensagem; color: janela.texto; font.pixelSize: 13 }
            Timer { id: tempoAviso; interval: 4000; onTriggered: caixaAviso.mostrar = false }
            Connections { target: musica; function onMudou() { if (musica.mensagem) { caixaAviso.mostrar = true; tempoAviso.restart() } } }
        }
    }

    // ---- barra do leitor ----------------------------------------------------------------------------
    Rectangle {
        id: barra
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 92
        color: Qt.rgba(0.07, 0.06, 0.1, 0.94)
        Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

        Row {
            x: 18; anchors.verticalCenter: parent.verticalCenter; spacing: 14
            width: parent.width * 0.3
            Capa { width: 60; height: 60; radius: 8; fonte: janela.t.capa; letra: (janela.t.album || "♪")[0]
                   MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: janela.pagina = "agora" } }
            Column {
                anchors.verticalCenter: parent.verticalCenter; width: parent.width - 80
                Text { width: parent.width; text: janela.t.titulo || "Nada a tocar"; color: janela.texto; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                Text { width: parent.width; text: janela.t.artista || ""; color: janela.suave; font.pixelSize: 12; elide: Text.ElideRight }
            }
        }

        Column {
            anchors.centerIn: parent; spacing: 4; width: parent.width * 0.38
            Row {
                anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
                BotaoRedondo { icone: "media-playlist-shuffle"; ativo: janela.t.aleatorio; onClicked: musica.alternarAleatorio() }
                BotaoRedondo { icone: "media-skip-backward"; onClicked: musica.anterior() }
                Rectangle {
                    width: 44; height: 44; radius: 22; color: mp.containsMouse ? Qt.lighter(janela.ambar, 1.1) : janela.ambar
                    Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: janela.t.estado === "play" ? 0 : 2
                           text: janela.t.estado === "play" ? "❚❚" : "▶"; color: "#1a1208"; font.pixelSize: janela.t.estado === "play" ? 15 : 18 }
                    MouseArea { id: mp; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: musica.tocarPausar() }
                }
                BotaoRedondo { icone: "media-skip-forward"; onClicked: musica.seguinte() }
                BotaoRedondo { icone: "media-playlist-repeat"; ativo: janela.t.repetir; onClicked: musica.alternarRepetir() }
            }
            RowLayout {
                width: parent.width; spacing: 10
                Text { text: janela.hms(janela.t.tempo); color: janela.suave; font.pixelSize: 11 }
                Slider {
                    id: progresso
                    Layout.fillWidth: true; from: 0; to: Math.max(1, janela.t.duracao)
                    Binding on value { when: !progresso.pressed; value: janela.t.tempo }
                    onMoved: musica.irPara(value)
                    background: Rectangle {
                        x: progresso.leftPadding; y: progresso.topPadding + progresso.availableHeight / 2 - 2
                        width: progresso.availableWidth; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.15)
                        Rectangle { width: progresso.visualPosition * parent.width; height: 4; radius: 2; color: janela.ambar }
                    }
                    handle: Rectangle { x: progresso.leftPadding + progresso.visualPosition * (progresso.availableWidth - 12); y: progresso.topPadding + progresso.availableHeight / 2 - 6
                                        width: 12; height: 12; radius: 6; color: "white"; visible: progresso.hovered || progresso.pressed }
                }
                Text { text: janela.hms(janela.t.duracao); color: janela.suave; font.pixelSize: 11 }
            }
        }

        RowLayout {
            anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
            spacing: 8
            BotaoRedondo { Layout.preferredWidth: 38; Layout.preferredHeight: 38; icone: "view-media-lyrics"; ativo: janela.pagina === "agora"; onClicked: janela.pagina = "agora" }
            BotaoRedondo { Layout.preferredWidth: 38; Layout.preferredHeight: 38; icone: "media-playlist-append"; ativo: janela.pagina === "fila"; onClicked: janela.pagina = "fila" }
            Image { Layout.preferredWidth: 18; Layout.preferredHeight: 18; Layout.leftMargin: 6; source: "image://icone/audio-volume-high"; sourceSize: Qt.size(36, 36) }
            Slider {
                id: vol
                Layout.preferredWidth: 120; Layout.preferredHeight: 24
                from: 0; to: 100; enabled: janela.t.volume >= 0
                onMoved: musica.definirVolume(Math.round(value))
                Binding on value { when: !vol.pressed; value: Math.max(0, janela.t.volume) }
                background: Rectangle {
                    x: vol.leftPadding; y: vol.topPadding + vol.availableHeight / 2 - 2
                    width: vol.availableWidth; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.15)
                    Rectangle { width: vol.visualPosition * parent.width; height: 4; radius: 2; color: janela.texto }
                }
                handle: Rectangle { x: vol.leftPadding + vol.visualPosition * (vol.availableWidth - 12); y: vol.topPadding + vol.availableHeight / 2 - 6; width: 12; height: 12; radius: 6; color: "white" }
            }
        }
    }
}
