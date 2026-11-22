// CarinaeOS — Documentos (Carinae Arquivos), ao estilo do Explorador de Ficheiros do Windows 11:
// separadores na barra de título, barra de endereço por partes, barra de comandos, painel de navegação
// (Início, Galeria, pastas afixadas, Este computador, Rede), vista de Detalhes/Ícones, painel de
// detalhes, menus de contexto e "Mapear unidade de rede" (SMB).
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: janela
    width: 1220; height: 780
    minimumWidth: 720; minimumHeight: 460
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: arquivos.titulo + " — Carinae Documentos"

    readonly property bool maximizada: visibility === Window.Maximized || visibility === Window.FullScreen

    // ---- cores (Windows 11, escuro e claro) -------------------------------------------------------
    QtObject {
        id: t
        readonly property bool e: arquivos.escuro
        readonly property color mica: e ? "#202020" : "#e8ecf2"
        readonly property color barra: e ? "#2b2b2b" : "#f9f9f9"
        readonly property color fundo: e ? "#191919" : "#ffffff"
        readonly property color painel: e ? "#1c1c1c" : "#f7f7f7"
        readonly property color linha: e ? "#383838" : "#e5e5e5"
        readonly property color texto: e ? "#ffffff" : "#1a1a1a"
        readonly property color texto2: e ? "#d0d0d0" : "#404040"
        readonly property color texto3: e ? "#9d9d9d" : "#6b6b6b"
        readonly property color hover: e ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(0, 0, 0, 0.04)
        readonly property color carregado: e ? Qt.rgba(1, 1, 1, 0.035) : Qt.rgba(0, 0, 0, 0.025)
        readonly property color selecao: e ? Qt.rgba(1, 1, 1, 0.085) : Qt.rgba(0, 0.37, 0.72, 0.10)
        readonly property color selecaoHover: e ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0.37, 0.72, 0.15)
        readonly property color acento: e ? "#60cdff" : "#005fb8"
        readonly property color acentoTexto: e ? "#000000" : "#ffffff"
        readonly property color campo: e ? "#1f1f1f" : "#ffffff"
        readonly property color campoBorda: e ? "#3a3a3a" : "#e0e0e0"
        readonly property color menu: e ? "#2c2c2c" : "#f9f9f9"
        readonly property color menuBorda: e ? "#454545" : "#dedede"
        readonly property color perigo: "#c42b1c"
        readonly property string letra: "Inter"
    }
    font.family: t.letra
    font.pixelSize: 13

    // ---- estado da interface --------------------------------------------------------------------
    property bool painelDetalhes: false
    property int renomearIndice: -1
    property int ancora: -1                       // para Shift+clique
    property var detalhe: ({})
    property var expandidos: ({ computador: true, rede: true })
    property int larguraNav: 232
    property var colunas: ({ nome: 360, data: 170, tipo: 170, tamanho: 110, local: 260 })
    readonly property string modo: arquivos.modo
    readonly property bool emPasta: arquivos.pagina === "" || arquivos.pagina === "pesquisa" || arquivos.pagina === "galeria"
    readonly property var selecionado: arquivos.selecao.length === 1 ? arquivos.itens[arquivos.selecao[0]] : null

    function selecionadoEm(i) { return arquivos.selecao.indexOf(i) !== -1 }
    function clicar(i, mods) {
        if (mods & Qt.ShiftModifier && ancora >= 0) arquivos.selecionarIntervalo(ancora, i);
        else if (mods & Qt.ControlModifier) { arquivos.selecionar(i, true); ancora = i; }
        else { arquivos.selecionar(i, false); ancora = i; }
        if (painelDetalhes) arquivos.detalhes(i);
    }
    function abrirItem(i) { renomearIndice = -1; arquivos.abrir(i) }
    function apagar(permanente) {
        if (!arquivos.selecao.length) return;
        if (permanente) confirmarApagar.open(); else arquivos.apagarSelecao(false);
    }
    function mostrarDetalhesPainel() {
        if (!painelDetalhes) return;
        arquivos.detalhes(arquivos.selecao.length === 1 ? arquivos.selecao[0] : -1);
    }
    function fmtCaminho(c) {
        return c.startsWith("carinae:") ? arquivos.titulo : c;
    }

    // ---- separadores ---------------------------------------------------------------------------------
    ListModel { id: separadores }
    property int sepAtual: 0
    Component.onCompleted: separadores.append({ caminho: arquivos.caminho, titulo: arquivos.titulo, icone: arquivos.iconeAtual })
    Connections {
        target: arquivos
        function onCaminhoMudou() {
            if (separadores.count) {
                separadores.setProperty(janela.sepAtual, "caminho", arquivos.caminho);
                separadores.setProperty(janela.sepAtual, "titulo", arquivos.titulo);
                separadores.setProperty(janela.sepAtual, "icone", arquivos.iconeAtual);
            }
            janela.renomearIndice = -1;
            janela.ancora = -1;
            campoPesquisa.text = "";
            endereco.editando = false;
            if (campoEndereco.activeFocus) vistaPasta.forceActiveFocus();
            janela.detalhe = {};
            if (janela.painelDetalhes) arquivos.detalhes(-1);
        }
        function onAviso(texto) { aviso.mostrar(texto) }
        function onPedeCredenciais(alvo, titulo, utilizador) { credenciais.abrir(alvo, titulo, utilizador) }
        function onPedeRenomear() { if (arquivos.selecao.length === 1) janela.renomearIndice = arquivos.selecao[0] }
        function onDetalhesProntos(d) {
            janela.detalhe = d;
            if (propriedades.visible && propriedades.caminho === d.caminho) propriedades.dados = d;
        }
    }
    function novoSeparador(caminho) {
        separadores.append({ caminho: caminho || "carinae:inicio", titulo: "", icone: "" });
        irParaSeparador(separadores.count - 1);
    }
    function irParaSeparador(i) {
        if (i < 0 || i >= separadores.count) return;
        sepAtual = i;
        arquivos.entrar(separadores.get(i).caminho);
    }
    function fecharSeparador(i) {
        if (separadores.count <= 1) { Qt.quit(); return; }
        separadores.remove(i);
        if (sepAtual >= separadores.count) sepAtual = separadores.count - 1;
        else if (i < sepAtual) sepAtual--;
        arquivos.entrar(separadores.get(sepAtual).caminho);
    }

    // ---- atalhos de teclado (como no Explorador) ----------------------------------------------------
    Shortcut { sequence: "Ctrl+T"; onActivated: janela.novoSeparador("") }
    Shortcut { sequence: "Ctrl+W"; onActivated: janela.fecharSeparador(janela.sepAtual) }
    Shortcut { sequence: "Ctrl+Tab"; onActivated: janela.irParaSeparador((janela.sepAtual + 1) % separadores.count) }
    Shortcut { sequence: "Ctrl+Shift+Tab"; onActivated: janela.irParaSeparador((janela.sepAtual - 1 + separadores.count) % separadores.count) }
    Shortcut { sequences: ["Alt+Left", "Backspace"]; enabled: !campoEndereco.activeFocus && !campoPesquisa.activeFocus && janela.renomearIndice < 0
               onActivated: arquivos.voltar() }
    Shortcut { sequence: "Alt+Right"; onActivated: arquivos.avancar() }
    Shortcut { sequence: "Alt+Up"; onActivated: arquivos.subir() }
    Shortcut { sequence: "F5"; onActivated: arquivos.recarregar() }
    Shortcut { sequences: ["Ctrl+L", "Alt+D", "F4"]; onActivated: endereco.editar() }
    Shortcut { sequences: ["Ctrl+F", "Ctrl+E", "F3"]; onActivated: { campoPesquisa.forceActiveFocus(); campoPesquisa.selectAll() } }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: arquivos.novaPastaRenomear() }
    Shortcut { sequence: "Ctrl+N"; onActivated: arquivos.abrirNovaJanela ? arquivos.abrirNovaJanela() : null }
    Shortcut { sequence: "Ctrl+H"; onActivated: arquivos.alternarOcultos() }
    Shortcut { sequence: "Ctrl+Shift+C"; onActivated: arquivos.copiarCaminho() }
    Shortcut { sequence: "Alt+Return"; onActivated: propriedades.abrirPara(arquivos.selecao.length === 1 ? arquivos.selecao[0] : -1) }
    Shortcut { sequence: "Ctrl+Shift+6"; onActivated: arquivos.definirModo("detalhes") }
    Shortcut { sequence: "Ctrl+Shift+2"; onActivated: arquivos.definirModo("icones") }
    Shortcut { sequence: "Ctrl+Shift+3"; onActivated: arquivos.definirModo("medios") }
    Shortcut { sequence: "Alt+P"; onActivated: { janela.painelDetalhes = !janela.painelDetalhes; janela.mostrarDetalhesPainel() } }

    // ======================================================================================================
    // a janela: cantos redondos e moldura fina (como no Windows 11)
    // ======================================================================================================
    Rectangle {
        id: moldura
        anchors.fill: parent
        radius: janela.maximizada ? 0 : 8
        color: t.mica
        border.width: janela.maximizada ? 0 : 1
        border.color: t.e ? "#3d3d3d" : "#c9c9c9"
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: moldura.border.width
            spacing: 0

            // ---- 1. barra de título com separadores ---------------------------------------------------
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 42

                // arrastar a janela pela barra / duplo clique maximiza
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onPressed: janela.startSystemMove()
                    onDoubleClicked: janela.maximizada ? janela.showNormal() : janela.showMaximized()
                }

                Row {
                    id: linhaSeparadores
                    x: 8; anchors.bottom: parent.bottom
                    spacing: 0
                    Repeater {
                        model: separadores
                        delegate: Item {
                            id: sep
                            required property int index
                            required property string titulo
                            required property string icone
                            readonly property bool atual: index === janela.sepAtual
                            width: Math.max(120, Math.min(240, (moldura.width - 260) / Math.max(1, separadores.count)))
                            height: 34
                            // o separador ativo "funde-se" com a barra de baixo, com cantos de cima redondos
                            Rectangle {
                                anchors.fill: parent
                                anchors.bottomMargin: sep.atual ? -6 : 3
                                radius: 7
                                color: sep.atual ? t.barra : (ratoSep.containsMouse ? t.hover : "transparent")
                            }
                            // as "orelhas" curvas junto à barra
                            Canvas {
                                visible: sep.atual
                                x: -8; y: parent.height - 8; width: 8; height: 8
                                property color c: t.barra
                                onPaint: { const g = getContext("2d"); g.reset(); g.fillStyle = c; g.beginPath(); g.moveTo(8, 0); g.lineTo(8, 8); g.lineTo(0, 8); g.arc(0, 0, 8, Math.PI / 2, 0, true); g.closePath(); g.fill(); }
                                onCChanged: requestPaint()
                            }
                            Canvas {
                                visible: sep.atual
                                x: parent.width; y: parent.height - 8; width: 8; height: 8
                                property color c: t.barra
                                onPaint: { const g = getContext("2d"); g.reset(); g.fillStyle = c; g.beginPath(); g.moveTo(0, 0); g.lineTo(0, 8); g.lineTo(8, 8); g.arc(8, 0, 8, Math.PI / 2, Math.PI, false); g.closePath(); g.fill(); }
                                onCChanged: requestPaint()
                            }
                            // separador vertical entre separadores não ativos
                            Rectangle {
                                visible: !sep.atual && sep.index !== janela.sepAtual - 1 && sep.index < separadores.count - 1
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                width: 1; height: 16; color: t.linha
                            }
                            MouseArea {
                                id: ratoSep
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onClicked: (r) => { if (r.button === Qt.MiddleButton) janela.fecharSeparador(sep.index); else janela.irParaSeparador(sep.index) }
                            }
                            Image {
                                id: icSep
                                x: 12; anchors.verticalCenter: parent.verticalCenter
                                width: 16; height: 16
                                sourceSize: Qt.size(32, 32)
                                source: sep.icone ? "image://icones/" + sep.icone : ""
                            }
                            Text {
                                anchors.left: icSep.right; anchors.leftMargin: 8
                                anchors.right: xSep.left; anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: sep.titulo
                                color: t.texto; font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                id: xSep
                                anchors.right: parent.right; anchors.rightMargin: 6
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24; height: 24; radius: 4
                                color: ratoX.containsMouse ? t.hover : "transparent"
                                Ico { anchors.centerIn: parent; nome: "fechar"; lado: 12; cor: t.texto2 }
                                MouseArea { id: ratoX; anchors.fill: parent; hoverEnabled: true; onClicked: janela.fecharSeparador(sep.index) }
                            }
                        }
                    }
                    // novo separador
                    Item {
                        width: 40; height: 34
                        Rectangle {
                            anchors.centerIn: parent
                            width: 30; height: 28; radius: 5
                            color: ratoMais.containsMouse ? t.hover : "transparent"
                            Ico { anchors.centerIn: parent; nome: "mais"; lado: 14; cor: t.texto }
                            MouseArea { id: ratoMais; anchors.fill: parent; hoverEnabled: true; onClicked: janela.novoSeparador("") }
                        }
                    }
                }

                // botões da janela
                Row {
                    anchors.right: parent.right; anchors.top: parent.top
                    BotaoJanela { nomeIco: "minimizar"; onClicado: janela.showMinimized() }
                    BotaoJanela { nomeIco: janela.maximizada ? "restaurar" : "maximizar"
                                  onClicado: janela.maximizada ? janela.showNormal() : janela.showMaximized() }
                    BotaoJanela { nomeIco: "fechar"; fecho: true; onClicado: janela.close() }
                }
            }

            // ---- 2. endereço e pesquisa ----------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                color: t.barra
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 12
                    spacing: 4
                    BotaoIco { nomeIco: "voltar"; ativo: arquivos.podeVoltar; dica: "Voltar (Alt+Seta para a esquerda)"; onClicado: arquivos.voltar() }
                    BotaoIco { nomeIco: "avancar"; ativo: arquivos.podeAvancar; dica: "Avançar (Alt+Seta para a direita)"; onClicado: arquivos.avancar() }
                    BotaoIco { nomeIco: "subir"; ativo: arquivos.caminho !== "carinae:inicio"; dica: "Subir (Alt+Seta para cima)"; onClicado: arquivos.subir() }
                    BotaoIco { nomeIco: "atualizar"; dica: "Atualizar (F5)"; onClicado: arquivos.recarregar() }
                    Item { width: 4 }

                    // barra de endereço por partes
                    Rectangle {
                        id: endereco
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 4
                        color: t.campo
                        border.width: 1
                        border.color: campoEndereco.activeFocus ? t.acento : (ratoEnd.containsMouse ? (t.e ? "#4a4a4a" : "#cfcfcf") : t.campoBorda)
                        property bool editando: false
                        function editar() {
                            editando = true;
                            campoEndereco.text = janela.fmtCaminho(arquivos.caminho);
                            campoEndereco.forceActiveFocus();
                            campoEndereco.selectAll();
                        }
                        // linha de acento em baixo quando se escreve (Windows 11)
                        Rectangle { visible: campoEndereco.activeFocus; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width - 2; height: 2; radius: 1; color: t.acento }
                        MouseArea { id: ratoEnd; anchors.fill: parent; hoverEnabled: true; onClicked: endereco.editar() }
                        Row {
                            id: migalhas
                            visible: !endereco.editando
                            x: 8; anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            clip: true
                            width: parent.width - 16
                            Image {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 16; height: 16; sourceSize: Qt.size(32, 32)
                                source: "image://icones/" + arquivos.iconeAtual
                            }
                            Item { width: 4; height: 1 }
                            Repeater {
                                model: arquivos.migalhas
                                delegate: Row {
                                    required property var modelData
                                    required property int index
                                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                                    Item {
                                        width: 18; height: 24
                                        Ico { anchors.centerIn: parent; nome: "seta"; lado: 12; cor: t.texto3 }
                                    }
                                    Rectangle {
                                        width: txtMig.implicitWidth + 12; height: 24; radius: 4
                                        color: ratoMig.containsMouse ? t.hover : "transparent"
                                        Text { id: txtMig; anchors.centerIn: parent; text: modelData.nome; color: t.texto; font.pixelSize: 13 }
                                        MouseArea { id: ratoMig; anchors.fill: parent; hoverEnabled: true; onClicked: arquivos.entrar(modelData.caminho) }
                                    }
                                }
                            }
                        }
                        TextInput {
                            id: campoEndereco
                            visible: endereco.editando
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: t.texto; selectionColor: t.acento; selectedTextColor: t.acentoTexto
                            font.pixelSize: 13; font.family: t.letra
                            clip: true
                            onAccepted: { endereco.editando = false; arquivos.entrar(text) }
                            onActiveFocusChanged: if (!activeFocus) endereco.editando = false
                            Keys.onEscapePressed: { endereco.editando = false; focus = false }
                        }
                    }

                    // pesquisa
                    Rectangle {
                        Layout.preferredWidth: Math.min(300, janela.width * 0.26)
                        Layout.preferredHeight: 32
                        radius: 4
                        color: t.campo
                        border.width: 1
                        border.color: campoPesquisa.activeFocus ? t.acento : t.campoBorda
                        Rectangle { visible: campoPesquisa.activeFocus; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width - 2; height: 2; radius: 1; color: t.acento }
                        TextInput {
                            id: campoPesquisa
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 34
                            verticalAlignment: TextInput.AlignVCenter
                            color: t.texto; selectionColor: t.acento; selectedTextColor: t.acentoTexto
                            font.pixelSize: 13; font.family: t.letra
                            clip: true
                            onTextEdited: if (arquivos.pagina === "") arquivos.filtrar(text)
                            onAccepted: arquivos.pesquisar(text)
                            Keys.onEscapePressed: { text = ""; arquivos.filtrar(""); focus = false }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !parent.text
                                text: "Pesquisar em " + arquivos.titulo
                                color: t.texto3; font.pixelSize: 13
                                elide: Text.ElideRight; width: parent.width
                            }
                        }
                        Ico { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                              nome: "pesquisa"; lado: 15; cor: t.texto2 }
                    }
                }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: t.linha }
            }

            // ---- 3. barra de comandos -----------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                color: t.barra
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    spacing: 2
                    BotaoTexto {
                        id: botaoNovo
                        nomeIco: "mais"; texto: "Novo"; seta: true; corIco: t.acento
                        ativo: janela.emPasta && arquivos.pagina === ""
                        onClicado: menuNovo.popup(botaoNovo, 0, botaoNovo.height + 2)
                    }
                    Divisor {}
                    BotaoIco { nomeIco: "cortar"; dica: "Cortar (Ctrl+X)"; ativo: arquivos.selecao.length > 0 && arquivos.pagina === ""; onClicado: arquivos.copiarSelecao(true) }
                    BotaoIco { nomeIco: "copiar"; dica: "Copiar (Ctrl+C)"; ativo: arquivos.selecao.length > 0; onClicado: arquivos.copiarSelecao(false) }
                    BotaoIco { nomeIco: "colar"; dica: "Colar (Ctrl+V)"; ativo: arquivos.podeColar && arquivos.pagina === ""; onClicado: arquivos.colar() }
                    BotaoIco { nomeIco: "renomear"; dica: "Mudar o nome (F2)"; ativo: arquivos.selecao.length === 1 && arquivos.pagina === ""
                               onClicado: janela.renomearIndice = arquivos.selecao[0] }
                    BotaoIco { nomeIco: "partilhar"; dica: "Abrir com…"; ativo: !!janela.selecionado && !janela.selecionado.pasta
                               onClicado: abrirCom.abrirPara(arquivos.selecao[0]) }
                    BotaoIco { nomeIco: "eliminar"; dica: "Eliminar (Delete)"; ativo: arquivos.selecao.length > 0 && arquivos.pagina !== "galeria" || (arquivos.selecao.length > 0)
                               onClicado: janela.apagar(false) }
                    Divisor {}
                    BotaoTexto { id: botaoOrdenar; nomeIco: "ordenar"; texto: "Ordenar"; seta: true; ativo: janela.emPasta
                                 onClicado: menuOrdenar.popup(botaoOrdenar, 0, botaoOrdenar.height + 2) }
                    BotaoTexto { id: botaoVer; nomeIco: "ver"; texto: "Ver"; seta: true
                                 onClicado: menuVer.popup(botaoVer, 0, botaoVer.height + 2) }
                    Divisor {}
                    BotaoIco { id: botaoPontos; nomeIco: "pontos"; dica: "Ver mais"; onClicado: menuMais.popup(botaoPontos, 0, botaoPontos.height + 2) }
                    Item { Layout.fillWidth: true }
                    BotaoTexto { nomeIco: "detalhes"; texto: "Detalhes"; marcado: janela.painelDetalhes
                                 onClicado: { janela.painelDetalhes = !janela.painelDetalhes; janela.mostrarDetalhesPainel() } }
                }
            }

            // ---- 4. corpo: navegação | conteúdo | detalhes ---------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: t.fundo
                Rectangle { width: parent.width; height: 1; color: t.linha }

                // painel de navegação
                Rectangle {
                    id: nav
                    y: 1
                    width: janela.larguraNav; height: parent.height - 1
                    color: t.painel
                    ListView {
                        id: listaNav
                        anchors.fill: parent
                        anchors.topMargin: 6; anchors.bottomMargin: 6
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        model: arquivos.navegacao
                        ScrollBar.vertical: BarraRolar {}
                        delegate: LinhaNav {}
                    }
                    // a pega para mudar a largura
                    MouseArea {
                        anchors.right: parent.right; width: 6; height: parent.height
                        cursorShape: Qt.SizeHorCursor
                        property real x0
                        onPressed: (r) => x0 = r.x
                        onPositionChanged: (r) => janela.larguraNav = Math.max(160, Math.min(420, janela.larguraNav + r.x - x0))
                    }
                    Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: t.linha }
                }

                // conteúdo
                Item {
                    id: conteudo
                    anchors.left: nav.right; anchors.right: painelDir.left
                    anchors.top: parent.top; anchors.topMargin: 1; anchors.bottom: parent.bottom
                    clip: true

                    // páginas especiais
                    Loader {
                        anchors.fill: parent
                        active: !janela.emPasta || arquivos.pagina === "galeria" && false
                        visible: active
                        sourceComponent: arquivos.pagina === "inicio" ? paginaInicio
                                       : arquivos.pagina === "computador" ? paginaComputador
                                       : arquivos.pagina === "rede" ? paginaRede
                                       : arquivos.pagina === "servidor" ? paginaServidor : null
                    }

                    // pasta: detalhes / ícones
                    Item {
                        id: vistaPasta
                        anchors.fill: parent
                        visible: janela.emPasta
                        focus: true

                        Keys.onPressed: (ev) => {
                            const n = arquivos.itens.length;
                            const atual = arquivos.selecao.length ? arquivos.selecao[arquivos.selecao.length - 1] : -1;
                            const colunasGrelha = grelha.visible ? Math.max(1, Math.floor(grelha.width / grelha.cellWidth)) : 1;
                            let novo = -1;
                            if (ev.key === Qt.Key_Down) novo = Math.min(n - 1, atual + colunasGrelha);
                            else if (ev.key === Qt.Key_Up) novo = Math.max(0, atual - colunasGrelha);
                            else if (ev.key === Qt.Key_Right && grelha.visible) novo = Math.min(n - 1, atual + 1);
                            else if (ev.key === Qt.Key_Left && grelha.visible) novo = Math.max(0, atual - 1);
                            else if (ev.key === Qt.Key_Home) novo = 0;
                            else if (ev.key === Qt.Key_End) novo = n - 1;
                            else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) { if (arquivos.selecao.length === 1) janela.abrirItem(atual); ev.accepted = true; return; }
                            else if (ev.key === Qt.Key_Delete) { janela.apagar(ev.modifiers & Qt.ShiftModifier); ev.accepted = true; return; }
                            else if (ev.key === Qt.Key_F2) { if (arquivos.selecao.length === 1) janela.renomearIndice = atual; ev.accepted = true; return; }
                            else if (ev.matches(StandardKey.Copy)) { arquivos.copiarSelecao(false); ev.accepted = true; return; }
                            else if (ev.matches(StandardKey.Cut)) { arquivos.copiarSelecao(true); ev.accepted = true; return; }
                            else if (ev.matches(StandardKey.Paste)) { arquivos.colar(); ev.accepted = true; return; }
                            else if (ev.matches(StandardKey.SelectAll)) { arquivos.selecionarTudo(); ev.accepted = true; return; }
                            else if (ev.text && ev.text.length === 1 && ev.text > " " && !(ev.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                                // escrever salta para o primeiro nome com essa letra
                                const l = ev.text.toLowerCase();
                                for (let k = 1; k <= n; k++) { const j = (atual + k) % n; if (arquivos.itens[j].nome.toLowerCase().startsWith(l)) { novo = j; break; } }
                            }
                            if (novo >= 0 && n) {
                                if (ev.modifiers & Qt.ShiftModifier && janela.ancora >= 0) arquivos.selecionarIntervalo(janela.ancora, novo);
                                else { arquivos.selecionar(novo, false); janela.ancora = novo; }
                                (grelha.visible ? grelha : lista).positionViewAtIndex(novo, ListView.Contain);
                                janela.mostrarDetalhesPainel();
                                ev.accepted = true;
                            }
                        }

                        // largar ficheiros vindos de fora (ou de outro separador)
                        DropArea {
                            anchors.fill: parent
                            keys: ["text/uri-list"]
                            onDropped: (d) => {
                                if (!d.hasUrls) return;
                                const mover = d.source !== null && !(d.drop ? false : false) && d.proposedAction === Qt.MoveAction;
                                arquivos.largarAqui(d.urls.map(u => u.toString()).join("\n"), d.source !== null && d.action === Qt.MoveAction);
                                d.acceptProposedAction();
                            }
                        }

                        // clique no vazio: tira a seleção; botão direito: menu do fundo
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onPressed: (r) => {
                                vistaPasta.forceActiveFocus();
                                janela.renomearIndice = -1;
                                if (!(r.modifiers & Qt.ControlModifier)) arquivos.limparSelecao();
                                if (r.button === Qt.RightButton) menuFundo.popup();
                                janela.mostrarDetalhesPainel();
                            }
                        }

                        // cabeçalho das colunas (Detalhes)
                        Rectangle {
                            id: cabecalho
                            visible: janela.modo === "detalhes" || janela.modo === "lista"
                            width: parent.width; height: visible ? 34 : 0
                            color: t.fundo
                            Row {
                                x: 14; height: parent.height
                                Coluna { chave: "nome"; texto: "Nome"; ordem: "nome" }
                                Coluna { visible: arquivos.pagina === "pesquisa"; chave: "local"; texto: "Local"; ordem: "" }
                                Coluna { chave: "data"; texto: "Data de modificação"; ordem: "data" }
                                Coluna { chave: "tipo"; texto: "Tipo"; ordem: "tipo" }
                                Coluna { chave: "tamanho"; texto: "Tamanho"; ordem: "tamanho"; direita: true }
                            }
                        }

                        ListView {
                            id: lista
                            visible: janela.modo === "detalhes" || janela.modo === "lista"
                            anchors.fill: parent; anchors.topMargin: cabecalho.height
                            anchors.leftMargin: 4; anchors.rightMargin: 4
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: visible ? arquivos.itens : []
                            ScrollBar.vertical: BarraRolar {}
                            ScrollBar.horizontal: BarraRolar {}
                            contentWidth: Math.max(width, 20 + janela.colunas.nome + janela.colunas.data + janela.colunas.tipo + janela.colunas.tamanho
                                                   + (arquivos.pagina === "pesquisa" ? janela.colunas.local : 0))
                            flickableDirection: Flickable.AutoFlickIfNeeded
                            delegate: LinhaDetalhes {}
                            footer: Item { height: 40 }
                        }

                        GridView {
                            id: grelha
                            visible: !lista.visible
                            anchors.fill: parent
                            anchors.margins: 8
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            model: visible ? arquivos.itens : []
                            readonly property int lado: arquivos.pagina === "galeria" ? 168 : janela.modo === "medios" ? 52 : 96
                            cellWidth: arquivos.pagina === "galeria" ? 184 : janela.modo === "medios" ? 96 : 132
                            cellHeight: arquivos.pagina === "galeria" ? 184 : janela.modo === "medios" ? 104 : 156
                            ScrollBar.vertical: BarraRolar {}
                            delegate: CelulaIcone {}
                            footer: Item { height: 40 }
                        }

                        // vazio / a procurar
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 80
                            visible: arquivos.itens.length === 0
                            text: arquivos.pagina === "pesquisa" ? (arquivos.dadosPagina.aProcurar ? "A procurar…" : "Nenhum item corresponde à sua pesquisa.")
                                : arquivos.pagina === "galeria" ? "A juntar as fotos e os vídeos…" : "Esta pasta está vazia."
                            color: t.texto3; font.pixelSize: 13
                        }
                    }
                }

                // painel de detalhes (à direita)
                Rectangle {
                    id: painelDir
                    anchors.right: parent.right; anchors.top: parent.top; anchors.topMargin: 1; anchors.bottom: parent.bottom
                    width: janela.painelDetalhes ? 300 : 0
                    visible: width > 0
                    color: t.painel
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Rectangle { width: 1; height: parent.height; color: t.linha }
                    PainelDetalhes { anchors.fill: parent; anchors.leftMargin: 1 }
                }
            }

            // ---- 5. barra de estado -----------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: t.fundo
                Text {
                    x: 14; anchors.verticalCenter: parent.verticalCenter
                    text: (janela.emPasta ? arquivos.resumo : "") + (arquivos.infoSelecao ? "    │    " + arquivos.infoSelecao : "")
                    color: t.texto2; font.pixelSize: 12
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    BotaoIco { lado: 24; ladoIco: 14; nomeIco: "linhas"; marcado: janela.modo === "detalhes"; dica: "Detalhes"; onClicado: arquivos.definirModo("detalhes") }
                    BotaoIco { lado: 24; ladoIco: 14; nomeIco: "grelha"; marcado: janela.modo === "icones" || janela.modo === "medios"; dica: "Ícones grandes"; onClicado: arquivos.definirModo("icones") }
                }
            }
        }

        // as bordas para redimensionar (a janela não tem moldura do sistema)
        Repeater {
            model: janela.maximizada ? [] : [
                { b: Qt.LeftEdge, x: 0, y: 8, w: 5, h: -16, c: Qt.SizeHorCursor },
                { b: Qt.RightEdge, x: -5, y: 8, w: 5, h: -16, c: Qt.SizeHorCursor },
                { b: Qt.TopEdge, x: 8, y: 0, w: -16, h: 4, c: Qt.SizeVerCursor },
                { b: Qt.BottomEdge, x: 8, y: -5, w: -16, h: 5, c: Qt.SizeVerCursor },
                { b: Qt.LeftEdge | Qt.TopEdge, x: 0, y: 0, w: 8, h: 8, c: Qt.SizeFDiagCursor },
                { b: Qt.RightEdge | Qt.BottomEdge, x: -8, y: -8, w: 8, h: 8, c: Qt.SizeFDiagCursor },
                { b: Qt.RightEdge | Qt.TopEdge, x: -8, y: 0, w: 8, h: 8, c: Qt.SizeBDiagCursor },
                { b: Qt.LeftEdge | Qt.BottomEdge, x: 0, y: -8, w: 8, h: 8, c: Qt.SizeBDiagCursor }
            ]
            delegate: MouseArea {
                required property var modelData
                x: modelData.x < 0 ? moldura.width + modelData.x : modelData.x
                y: modelData.y < 0 ? moldura.height + modelData.y : modelData.y
                width: modelData.w <= 0 ? moldura.width + modelData.w : modelData.w
                height: modelData.h <= 0 ? moldura.height + modelData.h : modelData.h
                cursorShape: modelData.c
                onPressed: janela.startSystemResize(modelData.b)
            }
        }
    }

    // ======================================================================================================
    // componentes
    // ======================================================================================================
    component BotaoJanela: Rectangle {
        id: bj
        property string nomeIco
        property bool fecho: false
        signal clicado()
        width: 46; height: 34
        color: rbj.containsMouse ? (fecho ? t.perigo : t.hover) : "transparent"
        topRightRadius: fecho && !janela.maximizada ? 7 : 0
        Ico { anchors.centerIn: parent; nome: bj.nomeIco; lado: 14; espessura: 1.2; cor: rbj.containsMouse && bj.fecho ? "#ffffff" : t.texto }
        MouseArea { id: rbj; anchors.fill: parent; hoverEnabled: true; onClicked: bj.clicado() }
    }

    component BotaoIco: Rectangle {
        id: bi
        property string nomeIco
        property bool ativo: true
        property bool marcado: false
        property string dica: ""
        property int lado: 34
        property int ladoIco: 16
        property color corIco: t.texto
        signal clicado()
        Layout.preferredWidth: lado; Layout.preferredHeight: lado
        width: lado; height: lado; radius: 4
        color: !ativo ? "transparent" : rbi.pressed ? t.carregado : (rbi.containsMouse || marcado) ? t.hover : "transparent"
        opacity: ativo ? 1 : 0.38
        Ico { anchors.centerIn: parent; nome: bi.nomeIco; lado: bi.ladoIco; cor: bi.corIco }
        MouseArea { id: rbi; anchors.fill: parent; hoverEnabled: true; enabled: bi.ativo; onClicked: bi.clicado() }
        DicaW { visible: rbi.containsMouse && bi.dica !== ""; text: bi.dica }
    }

    component BotaoTexto: Rectangle {
        id: bt
        property string nomeIco
        property string texto
        property bool seta: false
        property bool ativo: true
        property bool marcado: false
        property color corIco: t.texto
        signal clicado()
        Layout.preferredHeight: 34
        width: linhaBt.implicitWidth + 20; height: 34
        Layout.preferredWidth: width
        radius: 4
        color: !ativo ? "transparent" : rbt.pressed ? t.carregado : (rbt.containsMouse || marcado) ? t.hover : "transparent"
        opacity: ativo ? 1 : 0.38
        Row {
            id: linhaBt
            anchors.centerIn: parent
            spacing: 8
            Ico { anchors.verticalCenter: parent.verticalCenter; nome: bt.nomeIco; lado: 16; cor: bt.corIco }
            Text { anchors.verticalCenter: parent.verticalCenter; text: bt.texto; color: t.texto; font.pixelSize: 13 }
            Ico { visible: bt.seta; anchors.verticalCenter: parent.verticalCenter; nome: "setaBaixo"; lado: 11; cor: t.texto2 }
        }
        MouseArea { id: rbt; anchors.fill: parent; hoverEnabled: true; enabled: bt.ativo; onClicked: bt.clicado() }
    }

    component DicaW: ToolTip {
        id: dicaw
        delay: 700
        contentItem: Text { text: dicaw.text; color: t.texto; font.pixelSize: 12; font.family: t.letra }
        background: Rectangle { radius: 4; color: t.menu; border.width: 1; border.color: t.menuBorda }
    }

    component Divisor: Rectangle {
        Layout.preferredWidth: 1; Layout.preferredHeight: 22
        Layout.leftMargin: 6; Layout.rightMargin: 6
        color: t.linha
    }

    component BarraRolar: ScrollBar {
        id: br
        policy: ScrollBar.AsNeeded
        contentItem: Rectangle {
            implicitWidth: br.hovered || br.pressed ? 8 : 3
            implicitHeight: br.hovered || br.pressed ? 8 : 3
            radius: 4
            color: t.e ? Qt.rgba(1, 1, 1, br.pressed ? 0.6 : 0.42) : Qt.rgba(0, 0, 0, br.pressed ? 0.55 : 0.38)
            opacity: br.active ? 1 : 0.0
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
        background: Item {}
    }

    // uma coluna do cabeçalho (clique ordena; a borda direita muda a largura)
    component Coluna: Item {
        id: col
        property string chave
        property string texto
        property string ordem
        property bool direita: false
        width: visible ? janela.colunas[chave] : 0
        height: parent.height
        Rectangle { anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: 3; radius: 4
                    color: rcol.containsMouse && col.ordem ? t.hover : "transparent" }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            x: col.direita ? parent.width - width - 14 : 8
            text: col.texto; color: t.texto2; font.pixelSize: 12
        }
        Ico {
            visible: col.ordem !== "" && arquivos.ordem === col.ordem
            anchors.horizontalCenter: parent.horizontalCenter; y: 1
            nome: arquivos.crescente ? "setaCima" : "setaBaixo"; lado: 10; cor: t.texto3
        }
        MouseArea { id: rcol; anchors.fill: parent; hoverEnabled: true; enabled: col.ordem !== ""; onClicked: arquivos.ordenar(col.ordem) }
        Rectangle { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 16; color: t.linha }
        MouseArea {
            anchors.right: parent.right; anchors.rightMargin: -3; width: 7; height: parent.height
            cursorShape: Qt.SizeHorCursor
            property real x0
            onPressed: (r) => x0 = r.x
            onPositionChanged: (r) => {
                const c = Object.assign({}, janela.colunas);
                c[col.chave] = Math.max(60, c[col.chave] + r.x - x0);
                janela.colunas = c;
            }
        }
    }

    // uma linha do painel de navegação
    component LinhaNav: Item {
        id: ln
        required property var modelData
        required property int index
        readonly property bool escondida: modelData.nivel === 1 && !janela.expandidos[modelData.grupo]
        readonly property bool atual: !!modelData.caminho && modelData.caminho === arquivos.caminho
        width: ListView.view.width
        height: escondida ? 0 : modelData.separador ? 17 : 34
        visible: !escondida
        Rectangle {
            visible: !!ln.modelData.separador
            anchors.centerIn: parent; width: parent.width - 24; height: 1; color: t.linha
        }
        Rectangle {
            visible: !ln.modelData.separador
            anchors.fill: parent; anchors.leftMargin: 4; anchors.rightMargin: 4; anchors.topMargin: 1; anchors.bottomMargin: 1
            radius: 4
            color: ln.atual ? (rln.containsMouse ? t.selecaoHover : t.selecao) : rln.containsMouse ? t.hover : "transparent"
            // o traço de acento do item atual
            Rectangle { visible: ln.atual; x: 0; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 16; radius: 1.5; color: t.acento }
        }
        DropArea {
            anchors.fill: parent
            enabled: !!ln.modelData.caminho && !ln.modelData.caminho.startsWith("carinae:")
            keys: ["text/uri-list"]
            onDropped: (d) => { arquivos.largarPara(ln.modelData.caminho, d.urls.map(u => u.toString()).join("\n"), d.source !== null); d.acceptProposedAction() }
        }
        // seta de expandir (Este computador, Rede)
        Item {
            visible: !!ln.modelData.grupo && ln.modelData.nivel === 0
            x: 6; width: 20; height: parent.height
            Ico { anchors.centerIn: parent; nome: janela.expandidos[ln.modelData.grupo] ? "setaBaixo" : "seta"; lado: 11; cor: t.texto2 }
            MouseArea {
                anchors.fill: parent
                onClicked: { const e = Object.assign({}, janela.expandidos); e[ln.modelData.grupo] = !e[ln.modelData.grupo]; janela.expandidos = e }
            }
        }
        Image {
            id: icNav
            visible: !ln.modelData.separador
            x: 28 + (ln.modelData.nivel || 0) * 18; anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18; sourceSize: Qt.size(36, 36)
            source: ln.modelData.icone ? "image://icones/" + ln.modelData.icone : ""
            opacity: ln.modelData.rede && !ln.modelData.ligado ? 0.55 : 1
        }
        Text {
            visible: !ln.modelData.separador
            anchors.left: icNav.right; anchors.leftMargin: 10
            anchors.right: pino.left; anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: ln.modelData.nome || ""
            color: ln.modelData.rede && !ln.modelData.ligado ? t.texto3 : t.texto
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        Ico {
            id: pino
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
            visible: !!ln.modelData.fixado && rln.containsMouse
            nome: "fixar"; lado: 13; cor: t.texto3
        }
        MouseArea {
            id: rln
            anchors.fill: parent; anchors.leftMargin: ln.modelData.grupo && ln.modelData.nivel === 0 ? 26 : 0
            enabled: !ln.modelData.separador
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: (r) => {
                const m = ln.modelData;
                if (r.button === Qt.RightButton) { menuNav.alvo = m; menuNav.popup(); return; }
                if (r.button === Qt.MiddleButton && m.caminho) { janela.novoSeparador(m.caminho); return; }
                if (m.cofre) arquivos.abrirCofre();
                else if (m.rede && !m.ligado) arquivos.ligarRede(m.redeIndice);
                else if (m.caminho) arquivos.entrar(m.caminho);
            }
        }
    }

    // uma linha da vista Detalhes
    component LinhaDetalhes: Item {
        id: ld
        required property var modelData
        required property int index
        readonly property bool sel: janela.selecionadoEm(index)
        width: ListView.view.contentWidth
        height: 32
        Rectangle {
            anchors.fill: parent; anchors.topMargin: 1; anchors.bottomMargin: 1
            radius: 4
            color: ld.sel ? (rld.containsMouse ? t.selecaoHover : t.selecao) : (rld.containsMouse || largar.containsDrag) ? t.hover : "transparent"
            border.width: largar.containsDrag ? 1 : 0; border.color: t.acento
        }
        Row {
            x: 10; height: parent.height
            Item {
                width: janela.colunas.nome; height: parent.height
                Image {
                    id: icLd
                    x: 2; anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20; sourceSize: Qt.size(40, 40)
                    asynchronous: true
                    source: "image://icones/" + ld.modelData.icone
                    opacity: ld.modelData.nome.startsWith(".") ? 0.55 : 1
                }
                Image {
                    visible: ld.modelData.trancado
                    anchors.right: icLd.right; anchors.bottom: icLd.bottom; anchors.margins: -3
                    width: 11; height: 11; source: "image://icones/cadeado"
                }
                Text {
                    visible: janela.renomearIndice !== ld.index
                    anchors.left: icLd.right; anchors.leftMargin: 10; anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: ld.modelData.nome
                    color: t.texto; font.pixelSize: 13
                    elide: Text.ElideRight
                }
                CampoRenomear {
                    visible: janela.renomearIndice === ld.index
                    anchors.left: icLd.right; anchors.leftMargin: 6; anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    indice: ld.index; nomeOriginal: ld.modelData.nome
                }
            }
            CelulaTexto { visible: arquivos.pagina === "pesquisa"; largura: janela.colunas.local; texto: ld.modelData.local || "" }
            CelulaTexto { largura: janela.colunas.data; texto: ld.modelData.data }
            CelulaTexto { largura: janela.colunas.tipo; texto: ld.modelData.tipo }
            CelulaTexto { largura: janela.colunas.tamanho; texto: ld.modelData.tamanho; direita: true }
        }
        DropArea {
            id: largar
            anchors.fill: parent
            enabled: ld.modelData.pasta
            keys: ["text/uri-list"]
            onDropped: (d) => { arquivos.largarEm(ld.index, d.urls.map(u => u.toString()).join("\n"), d.source !== null); d.acceptProposedAction() }
        }
        MouseArea {
            id: rld
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property point inicio
            property bool arrastou: false
            onPressed: (r) => {
                vistaPasta.forceActiveFocus();
                inicio = Qt.point(r.x, r.y); arrastou = false;
                if (r.button === Qt.RightButton) {
                    if (!ld.sel) janela.clicar(ld.index, 0);
                    menuItem.indice = ld.index; menuItem.popup(); return;
                }
                if (!ld.sel || r.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) janela.clicar(ld.index, r.modifiers);
            }
            onReleased: (r) => { if (!arrastou && r.button === Qt.LeftButton && !(r.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) && arquivos.selecao.length > 1) janela.clicar(ld.index, 0) }
            onPositionChanged: (r) => {
                if (pressed && !arrastou && Math.abs(r.x - inicio.x) + Math.abs(r.y - inicio.y) > 12 && arquivos.pagina !== "carinae:x") {
                    arrastou = true;
                    arrasto.comecar(ld.modelData.icone);
                }
            }
            onDoubleClicked: (r) => { if (r.button === Qt.LeftButton) janela.abrirItem(ld.index) }
        }
    }

    component CelulaTexto: Item {
        property real largura
        property string texto
        property bool direita: false
        width: visible ? largura : 0; height: parent.height
        Text {
            anchors.left: parent.left; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: parent.direita ? Text.AlignRight : Text.AlignLeft
            text: parent.texto; color: t.texto3; font.pixelSize: 13
            elide: Text.ElideRight
        }
    }

    // célula da vista de ícones (e da Galeria)
    component CelulaIcone: Item {
        id: ci
        required property var modelData
        required property int index
        readonly property bool sel: janela.selecionadoEm(index)
        readonly property bool galeria: arquivos.pagina === "galeria"
        width: GridView.view.cellWidth; height: GridView.view.cellHeight
        Rectangle {
            anchors.fill: parent; anchors.margins: 3
            radius: 4
            color: ci.sel ? (rci.containsMouse ? t.selecaoHover : t.selecao) : (rci.containsMouse || largarC.containsDrag) ? t.hover : "transparent"
            border.width: largarC.containsDrag ? 1 : 0; border.color: t.acento
        }
        Item {
            id: caixa
            anchors.horizontalCenter: parent.horizontalCenter
            y: ci.galeria ? 8 : 10
            width: grelha.lado; height: grelha.lado
            Image {
                id: miniatura
                anchors.fill: parent
                visible: ci.modelData.miniatura && status === Image.Ready
                source: ci.modelData.miniatura ? "image://miniaturas/" + encodeURIComponent(ci.modelData.caminho) : ""
                sourceSize: Qt.size(220, 220)
                fillMode: ci.galeria ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                asynchronous: true
                cache: true
            }
            Rectangle {   // moldura fina das fotos (Windows 11)
                visible: miniatura.visible && !ci.galeria
                x: (parent.width - miniatura.paintedWidth) / 2 - 1; y: (parent.height - miniatura.paintedHeight) / 2 - 1
                width: miniatura.paintedWidth + 2; height: miniatura.paintedHeight + 2
                color: "transparent"; border.width: 1; border.color: t.e ? "#4a4a4a" : "#d0d0d0"
            }
            Image {
                anchors.fill: parent
                visible: !miniatura.visible
                sourceSize: Qt.size(192, 192)
                asynchronous: true
                source: "image://icones/" + ci.modelData.icone
                opacity: ci.modelData.nome.startsWith(".") ? 0.55 : 1
            }
            Rectangle {   // vídeo: o "play" por cima
                visible: ci.modelData.video && miniatura.visible
                anchors.centerIn: parent; width: 34; height: 34; radius: 17; color: Qt.rgba(0, 0, 0, 0.55)
                Ico { anchors.centerIn: parent; nome: "avancar"; lado: 16; cor: "#ffffff" }
            }
        }
        Text {
            visible: !ci.galeria && janela.renomearIndice !== ci.index
            anchors.top: caixa.bottom; anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 12
            horizontalAlignment: Text.AlignHCenter
            text: ci.modelData.nome
            color: t.texto; font.pixelSize: 12
            wrapMode: Text.WrapAnywhere; maximumLineCount: ci.sel ? 4 : 2; elide: Text.ElideRight
        }
        CampoRenomear {
            visible: janela.renomearIndice === ci.index
            anchors.top: caixa.bottom; anchors.topMargin: 4
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 8
            indice: ci.index; nomeOriginal: ci.modelData.nome
        }
        DropArea {
            id: largarC
            anchors.fill: parent
            enabled: ci.modelData.pasta
            keys: ["text/uri-list"]
            onDropped: (d) => { arquivos.largarEm(ci.index, d.urls.map(u => u.toString()).join("\n"), d.source !== null); d.acceptProposedAction() }
        }
        MouseArea {
            id: rci
            anchors.fill: parent; anchors.margins: 3
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property point inicio
            property bool arrastou: false
            onPressed: (r) => {
                vistaPasta.forceActiveFocus();
                inicio = Qt.point(r.x, r.y); arrastou = false;
                if (r.button === Qt.RightButton) {
                    if (!ci.sel) janela.clicar(ci.index, 0);
                    menuItem.indice = ci.index; menuItem.popup(); return;
                }
                if (!ci.sel || r.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) janela.clicar(ci.index, r.modifiers);
            }
            onReleased: (r) => { if (!arrastou && r.button === Qt.LeftButton && !(r.modifiers & (Qt.ControlModifier | Qt.ShiftModifier)) && arquivos.selecao.length > 1) janela.clicar(ci.index, 0) }
            onPositionChanged: (r) => {
                if (pressed && !arrastou && Math.abs(r.x - inicio.x) + Math.abs(r.y - inicio.y) > 12) {
                    arrastou = true;
                    arrasto.comecar(ci.modelData.icone);
                }
            }
            onDoubleClicked: (r) => { if (r.button === Qt.LeftButton) janela.abrirItem(ci.index) }
        }
    }

    // mudar o nome no sítio (F2): seleciona o nome sem a extensão, como no Windows
    component CampoRenomear: Rectangle {
        id: cr
        property int indice
        property string nomeOriginal
        height: 26; radius: 3
        color: t.campo
        border.width: 1; border.color: t.acento
        onVisibleChanged: if (visible) {
            entrada.text = nomeOriginal;
            entrada.forceActiveFocus();
            const p = nomeOriginal.lastIndexOf(".");
            entrada.select(0, p > 0 ? p : nomeOriginal.length);
        }
        TextInput {
            id: entrada
            anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6
            verticalAlignment: TextInput.AlignVCenter
            color: t.texto; selectionColor: t.acento; selectedTextColor: t.acentoTexto
            font.pixelSize: 13; font.family: t.letra
            clip: true
            onAccepted: {
                const i = cr.indice, novo = text, antigo = cr.nomeOriginal;
                janela.renomearIndice = -1;
                vistaPasta.forceActiveFocus();
                if (novo !== antigo && novo.trim()) arquivos.renomear(i, novo);
            }
            Keys.onEscapePressed: { janela.renomearIndice = -1; vistaPasta.forceActiveFocus() }
            onActiveFocusChanged: if (!activeFocus && typeof janela !== "undefined" && janela.renomearIndice === cr.indice) {
                const i = cr.indice, novo = text, antigo = cr.nomeOriginal;
                janela.renomearIndice = -1;
                if (novo !== antigo && novo.trim()) arquivos.renomear(i, novo);
            }
        }
    }

    // arrastar ficheiros (para outras pastas, outros separadores ou outros programas)
    Item {
        id: arrasto
        width: 48; height: 48
        visible: false
        property string icone: ""
        Image { anchors.fill: parent; source: arrasto.icone ? "image://icones/" + arrasto.icone : "" }
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.MoveAction
        Drag.hotSpot.x: 24; Drag.hotSpot.y: 24
        function comecar(ic) {
            icone = ic;
            const u = arquivos.urlsDaSelecao();
            if (!u) return;
            Drag.mimeData = { "text/uri-list": u.split("\n").join("\r\n") + "\r\n", "text/plain": u };
            Drag.active = true;
            Drag.active = false;
        }
    }

    // ---- páginas especiais ---------------------------------------------------------------------------
    Component {
        id: paginaInicio
        Flickable {
            contentHeight: colInicio.height + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: BarraRolar {}
            Column {
                id: colInicio
                x: 24; y: 16
                width: parent.width - 48
                spacing: 10
                TituloSecao { texto: "Acesso rápido" }
                Flow {
                    width: parent.width
                    spacing: 6
                    Repeater {
                        model: arquivos.dadosPagina.rapido || []
                        delegate: Mosaico { required property var modelData; dados: modelData; sub: "Armazenado localmente"; fixado: true }
                    }
                }
                Item { width: 1; height: 8 }
                TituloSecao { texto: "Recentes" }
                Rectangle {
                    width: parent.width; height: 32; color: "transparent"
                    Row {
                        x: 10; height: parent.height
                        Text { width: Math.max(220, colInicio.width * 0.42); anchors.verticalCenter: parent.verticalCenter; text: "Nome"; color: t.texto2; font.pixelSize: 12 }
                        Text { width: 170; anchors.verticalCenter: parent.verticalCenter; text: "Data de modificação"; color: t.texto2; font.pixelSize: 12 }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Localização do ficheiro"; color: t.texto2; font.pixelSize: 12 }
                    }
                }
                Repeater {
                    model: arquivos.dadosPagina.recentes || []
                    delegate: Rectangle {
                        required property var modelData
                        width: colInicio.width; height: 34; radius: 4
                        color: rRec.containsMouse ? t.hover : "transparent"
                        Row {
                            x: 10; height: parent.height
                            Item {
                                width: Math.max(220, colInicio.width * 0.42); height: parent.height
                                Image { id: icRec; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; sourceSize: Qt.size(40, 40)
                                        source: "image://icones/" + modelData.icone }
                                Text { anchors.left: icRec.right; anchors.leftMargin: 10; anchors.right: parent.right; anchors.rightMargin: 10
                                       anchors.verticalCenter: parent.verticalCenter; text: modelData.nome; color: t.texto; font.pixelSize: 13; elide: Text.ElideRight }
                            }
                            Text { width: 170; anchors.verticalCenter: parent.verticalCenter; text: modelData.data; color: t.texto3; font.pixelSize: 13 }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.caminho.substring(0, modelData.caminho.lastIndexOf("/")).replace(arquivos.casa, "~")
                                   color: t.texto3; font.pixelSize: 13; elide: Text.ElideMiddle; width: colInicio.width * 0.4 }
                        }
                        MouseArea { id: rRec; anchors.fill: parent; hoverEnabled: true
                                    onDoubleClicked: Qt.openUrlExternally("file://" + modelData.caminho) }
                    }
                }
                Text { visible: !(arquivos.dadosPagina.recentes || []).length; x: 10; text: "Os ficheiros que abrir aparecem aqui."; color: t.texto3; font.pixelSize: 13 }
            }
        }
    }

    Component {
        id: paginaComputador
        Flickable {
            contentHeight: colComp.height + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: BarraRolar {}
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.RightButton; onClicked: menuComputador.popup() }
            Column {
                id: colComp
                x: 24; y: 16
                width: parent.width - 48
                spacing: 10
                TituloSecao { texto: "Pastas" }
                Flow {
                    width: parent.width; spacing: 6
                    Repeater { model: arquivos.dadosPagina.pastas || []
                               delegate: Mosaico { required property var modelData; dados: modelData; sub: "" } }
                }
                Item { width: 1; height: 8 }
                TituloSecao { texto: "Dispositivos e unidades" }
                Flow {
                    width: parent.width; spacing: 8
                    Repeater { model: arquivos.dadosPagina.unidades || []; delegate: MosaicoUnidade {} }
                }
                Item { width: 1; height: 8 }
                TituloSecao { texto: "Localizações de rede" }
                Flow {
                    width: parent.width; spacing: 8
                    Repeater { model: arquivos.dadosPagina.redes || []; delegate: MosaicoRede {} }
                    BotaoAdicionarRede {}
                }
            }
        }
    }

    Component {
        id: paginaRede
        Flickable {
            contentHeight: colRede.height + 40
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: BarraRolar {}
            Column {
                id: colRede
                x: 24; y: 16
                width: parent.width - 48
                spacing: 10
                TituloSecao { texto: "Localizações de rede guardadas" }
                Flow {
                    width: parent.width; spacing: 8
                    Repeater { model: arquivos.dadosPagina.redes || []; delegate: MosaicoRede {} }
                    BotaoAdicionarRede {}
                }
                Item { width: 1; height: 8 }
                Row {
                    spacing: 12
                    TituloSecao { texto: "Computadores na rede" }
                    Text { anchors.verticalCenter: parent.verticalCenter; visible: !!arquivos.dadosPagina.aProcurar; text: "A procurar…"; color: t.texto3; font.pixelSize: 12 }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter; visible: !arquivos.dadosPagina.aProcurar
                        text: "Procurar outra vez"; color: t.acento; font.pixelSize: 12
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: arquivos.procurarRede() }
                    }
                }
                Flow {
                    width: parent.width; spacing: 8
                    Repeater {
                        model: arquivos.dadosPagina.servidores || []
                        delegate: MosaicoGrande {
                            required property var modelData
                            icone: "win:servidor"; titulo: modelData.nome; sub: modelData.ip || modelData.host
                            onAbrir: arquivos.explorarServidor(modelData.host, "", "", "")
                        }
                    }
                }
                Text {
                    visible: !arquivos.dadosPagina.aProcurar && !(arquivos.dadosPagina.servidores || []).length
                    width: parent.width; wrapMode: Text.Wrap
                    text: "Não encontrei computadores com pastas partilhadas. Se souber o nome ou o IP, escreva \\\\servidor na barra de endereço, ou use \"Mapear unidade de rede\"."
                    color: t.texto3; font.pixelSize: 13
                }
            }
        }
    }

    Component {
        id: paginaServidor
        Flickable {
            contentHeight: colServ.height + 40
            clip: true
            ScrollBar.vertical: BarraRolar {}
            Column {
                id: colServ
                x: 24; y: 16
                width: parent.width - 48
                spacing: 10
                TituloSecao { texto: "Pastas partilhadas em \\\\" + (arquivos.dadosPagina.host || "") }
                Flow {
                    width: parent.width; spacing: 8
                    Repeater {
                        model: arquivos.dadosPagina.partilhas || []
                        delegate: MosaicoGrande {
                            required property var modelData
                            icone: "win:pasta-rede"; titulo: modelData.nome; sub: modelData.comentario
                            onAbrir: arquivos.abrirPartilha(arquivos.dadosPagina.host, modelData.nome)
                            onMenu: { mapear.abrir("\\\\" + arquivos.dadosPagina.host + "\\" + modelData.nome) }
                        }
                    }
                }
            }
        }
    }

    component TituloSecao: Row {
        property string texto
        spacing: 6
        Ico { anchors.verticalCenter: parent.verticalCenter; nome: "setaBaixo"; lado: 12; cor: t.texto2 }
        Text { text: parent.texto; color: t.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
    }

    // mosaico de pasta (Acesso rápido / Pastas)
    component Mosaico: Rectangle {
        id: mo
        property var dados
        property string sub: ""
        property bool fixado: false
        width: 150; height: 132; radius: 6
        color: rmo.pressed ? t.carregado : rmo.containsMouse ? t.hover : "transparent"
        Image { anchors.horizontalCenter: parent.horizontalCenter; y: 12; width: 64; height: 64; sourceSize: Qt.size(128, 128)
                source: "image://icones/" + mo.dados.icone }
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 84; width: parent.width - 12; horizontalAlignment: Text.AlignHCenter
               text: mo.dados.nome; color: t.texto; font.pixelSize: 13; elide: Text.ElideRight }
        Row {
            visible: mo.sub !== ""
            anchors.horizontalCenter: parent.horizontalCenter; y: 104; spacing: 4
            Text { text: mo.sub; color: t.texto3; font.pixelSize: 11 }
            Ico { visible: mo.fixado; nome: "fixar"; lado: 11; cor: t.texto3; anchors.verticalCenter: parent.verticalCenter }
        }
        DropArea {
            anchors.fill: parent; keys: ["text/uri-list"]
            onDropped: (d) => { arquivos.largarPara(mo.dados.caminho, d.urls.map(u => u.toString()).join("\n"), d.source !== null); d.acceptProposedAction() }
        }
        MouseArea {
            id: rmo; anchors.fill: parent; hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: (r) => {
                if (r.button === Qt.RightButton) { menuNav.alvo = { caminho: mo.dados.caminho, nome: mo.dados.nome, fixado: mo.fixado, removivel: true }; menuNav.popup(); }
                else if (r.button === Qt.MiddleButton) janela.novoSeparador(mo.dados.caminho);
            }
            onDoubleClicked: arquivos.entrar(mo.dados.caminho)
        }
    }

    // mosaico de unidade com a barra do espaço usado (Este computador)
    component MosaicoUnidade: Rectangle {
        id: mu
        required property var modelData
        width: 300; height: 76; radius: 6
        color: rmu.pressed ? t.carregado : rmu.containsMouse ? t.hover : "transparent"
        Image { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 52; height: 52; sourceSize: Qt.size(104, 104)
                source: "image://icones/" + mu.modelData.icone; opacity: mu.modelData.montado ? 1 : 0.6 }
        Column {
            x: 72; anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 84
            spacing: 5
            Text { width: parent.width; elide: Text.ElideRight; color: t.texto; font.pixelSize: 13
                   text: mu.modelData.nome + (mu.modelData.ponto && mu.modelData.ponto !== "/" ? "" : "") + "  (" + (mu.modelData.ponto || mu.modelData.dispositivo) + ")" }
            Rectangle {
                visible: mu.modelData.montado
                width: parent.width; height: 12
                color: t.e ? "#3a3a3a" : "#e6e6e6"
                border.width: 1; border.color: t.e ? "#4a4a4a" : "#bcbcbc"
                Rectangle {
                    x: 1; y: 1; height: parent.height - 2
                    width: Math.max(0, (parent.width - 2) * mu.modelData.usado)
                    color: mu.modelData.usado > 0.9 ? "#da3b01" : (t.e ? "#26a0da" : "#26a0da")
                }
            }
            Text { color: t.texto3; font.pixelSize: 12; text: mu.modelData.texto }
        }
        MouseArea {
            id: rmu; anchors.fill: parent; hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (r) => { if (r.button === Qt.RightButton) { menuUnidade.alvo = mu.modelData; menuUnidade.popup() } }
            onDoubleClicked: arquivos.abrirUnidade(mu.modelData.dispositivo)
        }
    }

    component MosaicoRede: MosaicoGrande {
        id: mr
        required property var modelData
        required property int index
        icone: "win:disco-rede"
        titulo: modelData.nome
        sub: modelData.ligado ? "Ligada" : "Desligada — clique para ligar"
        esbatido: !modelData.ligado
        onAbrir: modelData.ligado ? arquivos.entrar(modelData.caminho) : arquivos.ligarRede(index)
        onMenu: { menuRede.indice = index; menuRede.dados = modelData; menuRede.popup() }
    }

    component MosaicoGrande: Rectangle {
        id: mg
        property string icone
        property string titulo
        property string sub
        property bool esbatido: false
        signal abrir()
        signal menu()
        width: 300; height: 64; radius: 6
        color: rmg.pressed ? t.carregado : rmg.containsMouse ? t.hover : "transparent"
        Image { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 44; height: 44; sourceSize: Qt.size(88, 88)
                source: "image://icones/" + mg.icone; opacity: mg.esbatido ? 0.55 : 1 }
        Column {
            x: 64; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 74; spacing: 3
            Text { width: parent.width; elide: Text.ElideRight; text: mg.titulo; color: t.texto; font.pixelSize: 13 }
            Text { width: parent.width; elide: Text.ElideRight; text: mg.sub; color: t.texto3; font.pixelSize: 12; visible: text !== "" }
        }
        MouseArea {
            id: rmg; anchors.fill: parent; hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: (r) => { if (r.button === Qt.RightButton) mg.menu() }
            onDoubleClicked: mg.abrir()
        }
    }

    component BotaoAdicionarRede: Rectangle {
        width: 300; height: 64; radius: 6
        color: rbar.containsMouse ? t.hover : "transparent"
        border.width: 1; border.color: t.linha
        Row {
            anchors.centerIn: parent; spacing: 10
            Ico { anchors.verticalCenter: parent.verticalCenter; nome: "mais"; lado: 16; cor: t.acento }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Mapear unidade de rede"; color: t.texto; font.pixelSize: 13 }
        }
        MouseArea { id: rbar; anchors.fill: parent; hoverEnabled: true; onClicked: mapear.abrir("") }
    }

    // ---- painel de detalhes -------------------------------------------------------------------------
    component PainelDetalhes: Item {
        clip: true
        readonly property var d: janela.detalhe || ({})
        Flickable {
            anchors.fill: parent
            contentHeight: colDet.height + 30
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: colDet
                x: 18; y: 18; width: parent.width - 36
                spacing: 14
                Item {
                    width: parent.width; height: 170
                    Image {
                        id: fotoDet
                        anchors.fill: parent
                        visible: status === Image.Ready && !!d.caminho && /\.(jpe?g|png|webp|gif|bmp|avif|svg|tiff?)$/i.test(d.caminho || "")
                        source: visible || (d.caminho && /\.(jpe?g|png|webp|gif|bmp|avif|svg|tiff?|mp4|mkv|webm|mov)$/i.test(d.caminho)) ? "image://miniaturas/" + encodeURIComponent(d.caminho) : ""
                        sourceSize: Qt.size(300, 300)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                    Image {
                        anchors.centerIn: parent; width: 112; height: 112; sourceSize: Qt.size(224, 224)
                        visible: !fotoDet.visible
                        source: d.icone ? "image://icones/" + d.icone : "image://icones/" + arquivos.iconeAtual
                    }
                }
                Text { width: parent.width; wrapMode: Text.WrapAnywhere; text: d.nome || arquivos.titulo; color: t.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
                Rectangle { width: parent.width; height: 1; color: t.linha }
                Text { text: "Detalhes"; color: t.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
                Repeater {
                    model: d.caminho ? [["Tipo", d.tipo], ["Tamanho", d.tamanho], ["Conteúdo", d.conteudo], ["Localização", d.local],
                                        ["Data de modificação", d.modificado], ["Data de criação", d.criado], ["Dono", d.dono]] : []
                    delegate: Column {
                        required property var modelData
                        visible: !!modelData[1]
                        width: colDet.width; spacing: 2
                        Text { text: modelData[0]; color: t.texto3; font.pixelSize: 12 }
                        Text { width: parent.width; wrapMode: Text.WrapAnywhere; text: modelData[1] || ""; color: t.texto; font.pixelSize: 13 }
                    }
                }
                Text { visible: !d.caminho; width: parent.width; wrapMode: Text.Wrap; text: "Selecione um ficheiro para ver os detalhes."; color: t.texto3; font.pixelSize: 13 }
            }
        }
    }

    // ======================================================================================================
    // menus (ao estilo do Windows 11: cantos redondos, ícones à esquerda, atalhos à direita)
    // ======================================================================================================
    component MenuW: Menu {
        id: mw
        topPadding: 4; bottomPadding: 4
        delegate: ItemMenuW {}
        background: Rectangle {
            implicitWidth: 290
            radius: 8
            color: t.menu
            border.width: 1; border.color: t.menuBorda
        }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 90 } }
    }
    component ItemMenuW: MenuItem {
        id: imw
        property string ico: ""
        property string atalho: ""
        implicitHeight: visible ? 32 : 0
        leftPadding: 40; rightPadding: 14
        contentItem: RowLayout {
            spacing: 8
            Text { Layout.fillWidth: true; text: imw.text; color: imw.enabled ? t.texto : t.texto3; font.pixelSize: 13; elide: Text.ElideRight }
            Text { text: imw.atalho; color: t.texto3; font.pixelSize: 12; visible: text !== "" }
        }
        indicator: Item {
            x: 12; y: (imw.height - 16) / 2; width: 16; height: 16
            Ico { anchors.fill: parent; visible: !imw.checkable; nome: imw.ico; lado: 16; cor: imw.enabled ? t.texto : t.texto3 }
            Ico { anchors.fill: parent; visible: imw.checkable && imw.checked; nome: imw.autoExclusive ? "ponto" : "visto"; lado: 16; cor: t.texto; espessura: 2 }
        }
        arrow: Ico { x: imw.width - 24; y: (imw.height - 12) / 2; visible: !!imw.subMenu; nome: "seta"; lado: 12; cor: t.texto2 }
        background: Rectangle {
            x: 4; width: imw.width - 8; height: imw.height; radius: 4
            color: imw.highlighted && imw.enabled ? t.hover : "transparent"
        }
    }
    component SepW: MenuSeparator {
        topPadding: 3; bottomPadding: 3
        contentItem: Rectangle { implicitHeight: 1; color: t.menuBorda }
    }

    MenuW {
        id: menuNovo
        ItemMenuW { text: "Pasta"; ico: "pasta"; atalho: "Ctrl+Shift+N"; onTriggered: arquivos.novaPastaRenomear() }
        SepW {}
        ItemMenuW { text: "Documento de texto"; ico: "ficheiro"; onTriggered: arquivos.novoFicheiro("texto") }
        ItemMenuW { text: "Documento Markdown"; ico: "ficheiro"; onTriggered: arquivos.novoFicheiro("markdown") }
        ItemMenuW { text: "Script de terminal"; ico: "terminal"; onTriggered: arquivos.novoFicheiro("script") }
    }

    MenuW {
        id: menuOrdenar
        ItemMenuW { text: "Nome"; checkable: true; autoExclusive: true; checked: arquivos.ordem === "nome"; onTriggered: if (arquivos.ordem !== "nome") arquivos.ordenar("nome") }
        ItemMenuW { text: "Data de modificação"; checkable: true; autoExclusive: true; checked: arquivos.ordem === "data"; onTriggered: if (arquivos.ordem !== "data") arquivos.ordenar("data") }
        ItemMenuW { text: "Tipo"; checkable: true; autoExclusive: true; checked: arquivos.ordem === "tipo"; onTriggered: if (arquivos.ordem !== "tipo") arquivos.ordenar("tipo") }
        ItemMenuW { text: "Tamanho"; checkable: true; autoExclusive: true; checked: arquivos.ordem === "tamanho"; onTriggered: if (arquivos.ordem !== "tamanho") arquivos.ordenar("tamanho") }
        SepW {}
        ItemMenuW { text: "Ascendente"; checkable: true; checked: arquivos.crescente; onTriggered: if (!arquivos.crescente) arquivos.ordenar(arquivos.ordem) }
        ItemMenuW { text: "Descendente"; checkable: true; checked: !arquivos.crescente; onTriggered: if (arquivos.crescente) arquivos.ordenar(arquivos.ordem) }
    }

    MenuW {
        id: menuVer
        ItemMenuW { text: "Ícones grandes"; ico: "grelha"; atalho: "Ctrl+Shift+2"; onTriggered: arquivos.definirModo("icones") }
        ItemMenuW { text: "Ícones médios"; ico: "grelha"; atalho: "Ctrl+Shift+3"; onTriggered: arquivos.definirModo("medios") }
        ItemMenuW { text: "Lista"; ico: "lista"; atalho: "Ctrl+Shift+5"; onTriggered: arquivos.definirModo("lista") }
        ItemMenuW { text: "Detalhes"; ico: "linhas"; atalho: "Ctrl+Shift+6"; onTriggered: arquivos.definirModo("detalhes") }
        SepW {}
        ItemMenuW { text: "Painel de detalhes"; checkable: true; checked: janela.painelDetalhes; atalho: "Alt+P"
                    onTriggered: { janela.painelDetalhes = !janela.painelDetalhes; janela.mostrarDetalhesPainel() } }
        ItemMenuW { text: "Itens ocultos"; checkable: true; checked: arquivos.ocultos; atalho: "Ctrl+H"; onTriggered: arquivos.alternarOcultos() }
        SepW {}
        ItemMenuW { text: arquivos.escuro ? "Modo claro" : "Modo escuro"; ico: arquivos.escuro ? "sol" : "lua"; onTriggered: arquivos.alternarTema() }
    }

    MenuW {
        id: menuMais
        ItemMenuW { text: "Mapear unidade de rede"; ico: "rede"; onTriggered: mapear.abrir("") }
        ItemMenuW { text: "Desligar unidade de rede"; ico: "desligar"; enabled: arquivos.redes.length > 0; onTriggered: arquivos.entrar("carinae:rede") }
        SepW {}
        ItemMenuW { text: "Selecionar tudo"; ico: "visto"; atalho: "Ctrl+A"; onTriggered: arquivos.selecionarTudo() }
        ItemMenuW { text: "Selecionar nenhum"; ico: "fechar"; onTriggered: arquivos.limparSelecao() }
        ItemMenuW { text: "Inverter seleção"; ico: "atualizar"; onTriggered: arquivos.inverterSelecao() }
        SepW {}
        ItemMenuW { text: "Copiar caminho"; ico: "copiar"; atalho: "Ctrl+Shift+C"; onTriggered: arquivos.copiarCaminho() }
        ItemMenuW { text: "Abrir no Terminal"; ico: "terminal"; onTriggered: arquivos.abrirTerminal("") }
        ItemMenuW { text: "Afixar no Acesso rápido"; ico: "fixar"; enabled: arquivos.pagina === ""; onTriggered: arquivos.fixar(arquivos.caminho) }
        SepW {}
        ItemMenuW { text: "Propriedades"; ico: "propriedades"; atalho: "Alt+Enter"; enabled: arquivos.pagina === ""; onTriggered: propriedades.abrirPara(-1) }
    }

    // menu de um item
    MenuW {
        id: menuItem
        property int indice: -1
        readonly property var it: indice >= 0 && indice < arquivos.itens.length ? arquivos.itens[indice] : null
        readonly property bool pasta: !!it && it.pasta
        readonly property bool arquivo: !!it && /\.(zip|tar|tgz|gz|xz|bz2|zst|7z|rar)$/i.test(it.nome)
        // a fila de ícones do Windows 11 (cortar, copiar, mudar o nome, eliminar)
        MenuItem {
            implicitHeight: 44
            enabled: false
            background: Item {}
            contentItem: Row {
                leftPadding: 6
                spacing: 4
                Repeater {
                    model: [["cortar", "Cortar", () => arquivos.copiarSelecao(true)], ["copiar", "Copiar", () => arquivos.copiarSelecao(false)],
                            ["renomear", "Mudar o nome", () => { janela.renomearIndice = menuItem.indice }], ["partilhar", "Abrir com", () => abrirCom.abrirPara(menuItem.indice)],
                            ["eliminar", "Eliminar", () => janela.apagar(false)]]
                    delegate: Rectangle {
                        required property var modelData
                        width: 40; height: 36; radius: 4
                        color: rq.containsMouse ? t.hover : "transparent"
                        Ico { anchors.centerIn: parent; nome: modelData[0]; lado: 17; cor: t.texto }
                        MouseArea { id: rq; anchors.fill: parent; hoverEnabled: true; onClicked: { menuItem.close(); modelData[2]() } }
                        DicaW { visible: rq.containsMouse; text: modelData[1] }
                    }
                }
            }
        }
        SepW {}
        ItemMenuW { text: "Abrir"; ico: "abrir"; atalho: "Enter"; onTriggered: janela.abrirItem(menuItem.indice) }
        ItemMenuW { text: "Abrir num novo separador"; ico: "mais"; visible: menuItem.pasta; onTriggered: janela.novoSeparador(menuItem.it.caminho) }
        ItemMenuW { text: "Abrir com…"; ico: "partilhar"; visible: !menuItem.pasta; onTriggered: abrirCom.abrirPara(menuItem.indice) }
        ItemMenuW { text: "Abrir a localização do ficheiro"; ico: "pasta"; visible: arquivos.pagina === "pesquisa" || arquivos.pagina === "galeria"
                    onTriggered: { const c = menuItem.it.caminho; arquivos.entrar(c.substring(0, c.lastIndexOf("/")) || "/"); arquivos.selecionarPorNome(c.substring(c.lastIndexOf("/") + 1)) } }
        SepW {}
        ItemMenuW { text: "Compactar para arquivo ZIP"; ico: "zip"; visible: arquivos.pagina === ""; onTriggered: arquivos.comprimir() }
        ItemMenuW { text: "Compactar para…  (7Z, TAR, com senha)"; ico: "zip"; visible: arquivos.pagina === ""; onTriggered: arquivos.compactarCom() }
        ItemMenuW { text: "Extrair tudo…"; ico: "zip"; visible: menuItem.arquivo; onTriggered: arquivos.extrair(menuItem.indice) }
        ItemMenuW { text: "Ver o conteúdo"; ico: "abrir"; visible: menuItem.arquivo; onTriggered: arquivos.verCompactado(menuItem.it.caminho) }
        ItemMenuW { text: "Copiar como caminho"; ico: "copiar"; atalho: "Ctrl+Shift+C"; onTriggered: arquivos.copiarCaminho() }
        ItemMenuW { text: "Afixar no Acesso rápido"; ico: "fixar"; visible: menuItem.pasta; onTriggered: arquivos.fixar(menuItem.it.caminho) }
        ItemMenuW { text: "Abrir no Terminal"; ico: "terminal"; visible: menuItem.pasta; onTriggered: arquivos.abrirTerminal(menuItem.it.caminho) }
        MenuW {
            title: "Etiquetar"
            enabled: arquivos.pagina === ""
            Repeater {
                model: arquivos.etiquetas
                delegate: ItemMenuW { required property var modelData; required property int index
                                      text: modelData.nome; ico: "etiqueta"; onTriggered: arquivos.etiquetar(menuItem.indice, index) }
            }
            SepW {}
            ItemMenuW { text: "Nova etiqueta…"; ico: "mais"; onTriggered: novaEtiqueta.open() }
            ItemMenuW { text: "Tirar as etiquetas"; ico: "fechar"; onTriggered: arquivos.removerEtiquetasDoItem(menuItem.indice) }
        }
        ItemMenuW { text: menuItem.it && menuItem.it.trancado ? "Desbloquear" : "Bloquear com senha"; ico: "cadeado"; visible: arquivos.pagina === ""
                    onTriggered: arquivos.bloquear(menuItem.indice, !(menuItem.it && menuItem.it.trancado)) }
        ItemMenuW { text: "Criar atalho"; ico: "ligar"; visible: arquivos.pagina === ""; onTriggered: arquivos.criarAtalho(menuItem.indice) }
        SepW {}
        ItemMenuW { text: "Eliminar permanentemente"; ico: "eliminar"; atalho: "Shift+Del"; onTriggered: janela.apagar(true) }
        ItemMenuW { text: "Propriedades"; ico: "propriedades"; atalho: "Alt+Enter"; onTriggered: propriedades.abrirPara(menuItem.indice) }
    }

    // menu do fundo da pasta
    MenuW {
        id: menuFundo
        MenuW {
            title: "Ver"
            ItemMenuW { text: "Ícones grandes"; checkable: true; autoExclusive: true; checked: janela.modo === "icones"; onTriggered: arquivos.definirModo("icones") }
            ItemMenuW { text: "Ícones médios"; checkable: true; autoExclusive: true; checked: janela.modo === "medios"; onTriggered: arquivos.definirModo("medios") }
            ItemMenuW { text: "Lista"; checkable: true; autoExclusive: true; checked: janela.modo === "lista"; onTriggered: arquivos.definirModo("lista") }
            ItemMenuW { text: "Detalhes"; checkable: true; autoExclusive: true; checked: janela.modo === "detalhes"; onTriggered: arquivos.definirModo("detalhes") }
        }
        MenuW {
            title: "Ordenar por"
            ItemMenuW { text: "Nome"; checkable: true; autoExclusive: true; checked: arquivos.ordem === "nome"; onTriggered: if (arquivos.ordem !== "nome") arquivos.ordenar("nome") }
            ItemMenuW { text: "Data de modificação"; checkable: true; autoExclusive: true; checked: arquivos.ordem === "data"; onTriggered: if (arquivos.ordem !== "data") arquivos.ordenar("data") }
            ItemMenuW { text: "Tipo"; checkable: true; autoExclusive: true; checked: arquivos.ordem === "tipo"; onTriggered: if (arquivos.ordem !== "tipo") arquivos.ordenar("tipo") }
            ItemMenuW { text: "Tamanho"; checkable: true; autoExclusive: true; checked: arquivos.ordem === "tamanho"; onTriggered: if (arquivos.ordem !== "tamanho") arquivos.ordenar("tamanho") }
        }
        ItemMenuW { text: "Atualizar"; ico: "atualizar"; atalho: "F5"; onTriggered: arquivos.recarregar() }
        SepW {}
        ItemMenuW { text: "Colar"; ico: "colar"; atalho: "Ctrl+V"; enabled: arquivos.podeColar && arquivos.pagina === ""; onTriggered: arquivos.colar() }
        MenuW {
            title: "Novo"
            enabled: arquivos.pagina === ""
            ItemMenuW { text: "Pasta"; ico: "pasta"; onTriggered: arquivos.novaPastaRenomear() }
            ItemMenuW { text: "Documento de texto"; ico: "ficheiro"; onTriggered: arquivos.novoFicheiro("texto") }
            ItemMenuW { text: "Script de terminal"; ico: "terminal"; onTriggered: arquivos.novoFicheiro("script") }
        }
        SepW {}
        ItemMenuW { text: "Abrir no Terminal"; ico: "terminal"; onTriggered: arquivos.abrirTerminal("") }
        ItemMenuW { text: "Afixar no Acesso rápido"; ico: "fixar"; enabled: arquivos.pagina === ""; onTriggered: arquivos.fixar(arquivos.caminho) }
        ItemMenuW { text: "Propriedades"; ico: "propriedades"; enabled: arquivos.pagina === ""; onTriggered: propriedades.abrirPara(-1) }
    }

    // menu do painel de navegação / dos mosaicos
    MenuW {
        id: menuNav
        property var alvo: ({})
        ItemMenuW { text: "Abrir"; ico: "abrir"; enabled: !!menuNav.alvo.caminho
                    onTriggered: menuNav.alvo.cofre ? arquivos.abrirCofre() : arquivos.entrar(menuNav.alvo.caminho) }
        ItemMenuW { text: "Abrir num novo separador"; ico: "mais"; enabled: !!menuNav.alvo.caminho; onTriggered: janela.novoSeparador(menuNav.alvo.caminho) }
        ItemMenuW { text: "Desafixar do Acesso rápido"; ico: "fixar"; visible: !!menuNav.alvo.removivel; onTriggered: arquivos.desafixar(menuNav.alvo.caminho) }
        ItemMenuW { text: "Desligar"; ico: "desligar"; visible: !!menuNav.alvo.rede && !!menuNav.alvo.ligado; onTriggered: arquivos.desligarRede(menuNav.alvo.redeIndice) }
        ItemMenuW { text: "Remover esta localização"; ico: "eliminar"; visible: !!menuNav.alvo.rede; onTriggered: arquivos.removerRede(menuNav.alvo.redeIndice) }
        ItemMenuW { text: "Mapear unidade de rede"; ico: "rede"; visible: menuNav.alvo.grupo === "rede" && menuNav.alvo.nivel === 0; onTriggered: mapear.abrir("") }
        ItemMenuW { text: "Remover etiqueta"; ico: "eliminar"; visible: !!menuNav.alvo.etiqueta; onTriggered: arquivos.removerEtiqueta(menuNav.alvo.etqIndice) }
        ItemMenuW { text: "Abrir no Terminal"; ico: "terminal"; enabled: !!menuNav.alvo.caminho && !menuNav.alvo.caminho.startsWith("carinae:")
                    onTriggered: arquivos.abrirTerminal(menuNav.alvo.caminho) }
    }

    MenuW {
        id: menuUnidade
        property var alvo: ({})
        ItemMenuW { text: "Abrir"; ico: "abrir"; onTriggered: arquivos.abrirUnidade(menuUnidade.alvo.dispositivo) }
        ItemMenuW { text: "Abrir num novo separador"; ico: "mais"; enabled: !!menuUnidade.alvo.montado; onTriggered: janela.novoSeparador(menuUnidade.alvo.ponto) }
        ItemMenuW { text: "Ejetar"; ico: "ejetar"; visible: !!menuUnidade.alvo.usb && !!menuUnidade.alvo.montado; onTriggered: arquivos.ejetarUnidade(menuUnidade.alvo.dispositivo) }
        ItemMenuW { text: "Abrir no Terminal"; ico: "terminal"; enabled: !!menuUnidade.alvo.montado; onTriggered: arquivos.abrirTerminal(menuUnidade.alvo.ponto) }
    }

    MenuW {
        id: menuComputador
        ItemMenuW { text: "Mapear unidade de rede"; ico: "rede"; onTriggered: mapear.abrir("") }
        ItemMenuW { text: "Atualizar"; ico: "atualizar"; onTriggered: arquivos.recarregar() }
    }

    MenuW {
        id: menuRede
        property int indice: -1
        property var dados: ({})
        ItemMenuW { text: menuRede.dados.ligado ? "Abrir" : "Ligar"; ico: "ligar"
                    onTriggered: menuRede.dados.ligado ? arquivos.entrar(menuRede.dados.caminho) : arquivos.ligarRede(menuRede.indice) }
        ItemMenuW { text: "Desligar"; ico: "desligar"; enabled: !!menuRede.dados.ligado; onTriggered: arquivos.desligarRede(menuRede.indice) }
        ItemMenuW { text: "Ligar com outras credenciais…"; ico: "cadeado"
                    onTriggered: credenciais.abrir("rede:" + menuRede.indice, "Ligar a " + menuRede.dados.nome, "") }
        SepW {}
        ItemMenuW { text: "Remover"; ico: "eliminar"; onTriggered: arquivos.removerRede(menuRede.indice) }
    }

    // ======================================================================================================
    // diálogos
    // ======================================================================================================
    component DialogoW: Popup {
        id: dw
        property string titulo
        anchors.centerIn: Overlay.overlay
        modal: true
        focus: true
        padding: 0
        width: 480
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
        background: Rectangle { radius: 8; color: t.e ? "#202020" : "#f3f3f3"; border.width: 1; border.color: t.menuBorda }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 }
                            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 160; easing.type: Easing.OutCubic } }
    }
    component BotaoW: Rectangle {
        id: bw
        property string texto
        property bool destaque: false
        property bool ativo: true
        signal clicado()
        implicitWidth: Math.max(110, tbw.implicitWidth + 30); implicitHeight: 32
        Layout.preferredWidth: implicitWidth; Layout.preferredHeight: 32
        radius: 4
        opacity: ativo ? 1 : 0.45
        color: destaque ? (rbw.pressed ? Qt.darker(t.acento, 1.15) : rbw.containsMouse ? Qt.lighter(t.acento, 1.08) : t.acento)
                        : (rbw.containsMouse ? (t.e ? "#3a3a3a" : "#f0f0f0") : (t.e ? "#2d2d2d" : "#fbfbfb"))
        border.width: destaque ? 0 : 1; border.color: t.e ? "#3f3f3f" : "#d6d6d6"
        Text { id: tbw; anchors.centerIn: parent; text: bw.texto; color: bw.destaque ? t.acentoTexto : t.texto; font.pixelSize: 13 }
        MouseArea { id: rbw; anchors.fill: parent; hoverEnabled: true; enabled: bw.ativo; onClicked: bw.clicado() }
    }
    component CampoW: Rectangle {
        id: cw
        property alias text: tiw.text
        property string dica: ""
        property bool senha: false
        signal aceite()
        implicitHeight: 32
        Layout.fillWidth: true; Layout.preferredHeight: 32
        radius: 4
        color: t.campo
        border.width: 1; border.color: tiw.activeFocus ? t.acento : t.campoBorda
        Rectangle { visible: tiw.activeFocus; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 2; height: 2; radius: 1; color: t.acento }
        function focar() { tiw.forceActiveFocus(); tiw.selectAll() }
        TextInput {
            id: tiw
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            echoMode: cw.senha ? TextInput.Password : TextInput.Normal
            color: t.texto; selectionColor: t.acento; selectedTextColor: t.acentoTexto
            font.pixelSize: 13; font.family: t.letra
            clip: true
            onAccepted: cw.aceite()
            Text { anchors.verticalCenter: parent.verticalCenter; visible: !parent.text; text: cw.dica; color: t.texto3; font.pixelSize: 13 }
        }
    }
    component CaixaW: Row {
        id: cxw
        property string texto
        property bool marcada: false
        spacing: 10
        Rectangle {
            width: 20; height: 20; radius: 4
            color: cxw.marcada ? t.acento : "transparent"
            border.width: cxw.marcada ? 0 : 1; border.color: t.texto3
            Ico { anchors.centerIn: parent; visible: cxw.marcada; nome: "visto"; lado: 14; cor: t.acentoTexto; espessura: 2 }
        }
        Text { anchors.verticalCenter: parent.verticalCenter; text: cxw.texto; color: t.texto; font.pixelSize: 13 }
        TapHandler { onTapped: cxw.marcada = !cxw.marcada }
    }

    // "Mapear unidade de rede" (SMB)
    DialogoW {
        id: mapear
        function abrir(pasta) {
            campoPastaRede.text = pasta || "";
            campoNomeRede.text = "";
            campoUtilizador.text = ""; campoSenha.text = ""; campoDominio.text = "";
            outrasCred.marcada = false;
            religar.marcada = true;
            open();
            campoPastaRede.focar();
        }
        function concluir() {
            if (!campoPastaRede.text.trim()) return;
            arquivos.mapearRede(campoPastaRede.text, outrasCred.marcada ? campoUtilizador.text : "", outrasCred.marcada ? campoSenha.text : "",
                                outrasCred.marcada ? campoDominio.text : "", campoNomeRede.text, religar.marcada);
            close();
        }
        contentItem: ColumnLayout {
            spacing: 12
            Item { Layout.preferredHeight: 6 }
            RowLayout {
                Layout.leftMargin: 24; Layout.rightMargin: 24
                spacing: 12
                Image { Layout.preferredWidth: 32; Layout.preferredHeight: 32; sourceSize: Qt.size(64, 64); source: "image://icones/win:disco-rede" }
                Text { Layout.fillWidth: true; text: "Mapear unidade de rede"; color: t.texto; font.pixelSize: 20; font.weight: Font.DemiBold }
            }
            Text { Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.fillWidth: true; wrapMode: Text.Wrap
                   text: "Que pasta de rede quer mapear? Indique o servidor e a pasta partilhada (SMB / Windows)."
                   color: t.texto2; font.pixelSize: 13 }
            GridLayout {
                Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.fillWidth: true
                columns: 2; columnSpacing: 12; rowSpacing: 8
                Text { text: "Pasta:"; color: t.texto; font.pixelSize: 13 }
                CampoW { id: campoPastaRede; dica: "\\\\servidor\\partilha"; onAceite: mapear.concluir() }
                Item { width: 1; height: 1 }
                Text { text: "Exemplo: \\\\servidor\\partilha  ou  smb://192.168.1.10/fotos"; color: t.texto3; font.pixelSize: 12 }
                Text { text: "Nome:"; color: t.texto; font.pixelSize: 13 }
                CampoW { id: campoNomeRede; dica: "(opcional) ex.: NAS de casa"; onAceite: mapear.concluir() }
            }
            Column {
                Layout.leftMargin: 24; Layout.rightMargin: 24
                spacing: 10
                CaixaW { id: religar; texto: "Voltar a ligar ao iniciar sessão"; marcada: true }
                CaixaW { id: outrasCred; texto: "Ligar usando credenciais diferentes" }
            }
            GridLayout {
                visible: outrasCred.marcada
                Layout.leftMargin: 54; Layout.rightMargin: 24; Layout.fillWidth: true
                columns: 2; columnSpacing: 12; rowSpacing: 8
                Text { text: "Utilizador:"; color: t.texto; font.pixelSize: 13 }
                CampoW { id: campoUtilizador; dica: "utilizador"; onAceite: mapear.concluir() }
                Text { text: "Senha:"; color: t.texto; font.pixelSize: 13 }
                CampoW { id: campoSenha; senha: true; dica: "senha"; onAceite: mapear.concluir() }
                Text { text: "Domínio:"; color: t.texto; font.pixelSize: 13 }
                CampoW { id: campoDominio; dica: "(opcional) ex.: WORKGROUP"; onAceite: mapear.concluir() }
            }
            Text { visible: outrasCred.marcada; Layout.leftMargin: 54; Layout.rightMargin: 24; Layout.fillWidth: true; wrapMode: Text.Wrap
                   text: "A senha fica guardada no chaveiro do sistema (não neste programa)."; color: t.texto3; font.pixelSize: 12 }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 72; Layout.topMargin: 8
                color: t.e ? "#1b1b1b" : "#ebebeb"
                bottomLeftRadius: 8; bottomRightRadius: 8
                RowLayout {
                    anchors.right: parent.right; anchors.rightMargin: 24; anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    BotaoW { texto: "Concluir"; destaque: true; ativo: campoPastaRede.text.trim() !== ""; onClicado: mapear.concluir() }
                    BotaoW { texto: "Cancelar"; onClicado: mapear.close() }
                }
            }
        }
    }

    // credenciais de rede (quando o servidor pede utilizador e senha)
    DialogoW {
        id: credenciais
        width: 420
        property string alvo
        function abrir(a, tit, utilizador) {
            alvo = a; titulo = tit;
            credUtil.text = utilizador || ""; credSenha.text = ""; credDom.text = "";
            open();
            if (utilizador) credSenha.focar(); else credUtil.focar();
        }
        function ok() { arquivos.responderCredenciais(alvo, credUtil.text, credSenha.text, credDom.text); close() }
        contentItem: ColumnLayout {
            spacing: 10
            Item { Layout.preferredHeight: 6 }
            Text { Layout.leftMargin: 24; text: "Segurança do Windows"; color: t.texto3; font.pixelSize: 12 }
            Text { Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.fillWidth: true; wrapMode: Text.Wrap
                   text: "Introduza as credenciais de rede"; color: t.texto; font.pixelSize: 20; font.weight: Font.DemiBold }
            Text { Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.fillWidth: true; wrapMode: Text.Wrap
                   text: credenciais.titulo; color: t.texto2; font.pixelSize: 13 }
            ColumnLayout {
                Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.fillWidth: true
                spacing: 8
                CampoW { id: credUtil; dica: "Nome de utilizador"; onAceite: credSenha.focar() }
                CampoW { id: credSenha; dica: "Palavra-passe"; senha: true; onAceite: credenciais.ok() }
                CampoW { id: credDom; dica: "Domínio (opcional)"; onAceite: credenciais.ok() }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 72; Layout.topMargin: 8
                color: t.e ? "#1b1b1b" : "#ebebeb"
                bottomLeftRadius: 8; bottomRightRadius: 8
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 24
                    spacing: 8
                    BotaoW { Layout.fillWidth: true; texto: "OK"; destaque: true; onClicado: credenciais.ok() }
                    BotaoW { Layout.fillWidth: true; texto: "Cancelar"; onClicado: credenciais.close() }
                }
            }
        }
    }

    // propriedades
    DialogoW {
        id: propriedades
        width: 440
        property string caminho
        property var dados: ({})
        function abrirPara(i) {
            dados = {};
            caminho = i >= 0 && i < arquivos.itens.length ? arquivos.itens[i].caminho : arquivos.caminho;
            arquivos.detalhes(i);
            dados = janela.detalhe && janela.detalhe.caminho === caminho ? janela.detalhe : {};
            open();
        }
        contentItem: ColumnLayout {
            spacing: 0
            RowLayout {
                Layout.margins: 20
                spacing: 14
                Image { Layout.preferredWidth: 48; Layout.preferredHeight: 48; sourceSize: Qt.size(96, 96)
                        source: propriedades.dados.icone ? "image://icones/" + propriedades.dados.icone : "" }
                Text { Layout.fillWidth: true; wrapMode: Text.WrapAnywhere; text: (propriedades.dados.nome || "") + "  —  Propriedades"
                       color: t.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: t.linha }
            Column {
                Layout.margins: 20; Layout.fillWidth: true
                spacing: 9
                Repeater {
                    model: [["Tipo:", propriedades.dados.tipo], ["Localização:", propriedades.dados.local], ["Tamanho:", propriedades.dados.tamanho],
                            ["Conteúdo:", propriedades.dados.conteudo], ["-", "x"], ["Criado:", propriedades.dados.criado],
                            ["Modificado:", propriedades.dados.modificado], ["Acedido:", propriedades.dados.acedido], ["-", "x"],
                            ["Dono:", propriedades.dados.dono], ["Permissões:", propriedades.dados.permissoes],
                            ["Atributos:", ((propriedades.dados.somenteLeitura ? "Só de leitura  " : "") + (propriedades.dados.oculto ? "Oculto" : "")) || "Normal"]]
                    delegate: Item {
                        required property var modelData
                        visible: !!modelData[1]
                        width: 400; height: modelData[0] === "-" ? 1 : valor.height
                        Rectangle { visible: modelData[0] === "-"; anchors.fill: parent; color: t.linha }
                        Text { visible: modelData[0] !== "-"; width: 110; text: modelData[0]; color: t.texto3; font.pixelSize: 13 }
                        Text { id: valor; visible: modelData[0] !== "-"; x: 116; width: parent.width - 116; wrapMode: Text.WrapAnywhere
                               text: modelData[0] !== "-" ? (modelData[1] || "") : ""; color: t.texto; font.pixelSize: 13 }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 64
                color: t.e ? "#1b1b1b" : "#ebebeb"
                bottomLeftRadius: 8; bottomRightRadius: 8
                BotaoW { anchors.right: parent.right; anchors.rightMargin: 20; anchors.verticalCenter: parent.verticalCenter
                         texto: "OK"; destaque: true; onClicado: propriedades.close() }
            }
        }
        Connections {
            target: arquivos
            function onDetalhesProntos(d) { if (d.caminho === propriedades.caminho) propriedades.dados = d }
        }
    }

    // abrir com…
    DialogoW {
        id: abrirCom
        width: 420
        property int indice: -1
        property var apps: []
        property int escolhida: 0
        function abrirPara(i) { indice = i; apps = arquivos.aplicacoesPara(i); escolhida = 0; sempre.marcada = false; open() }
        contentItem: ColumnLayout {
            spacing: 10
            Item { Layout.preferredHeight: 6 }
            Text { Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.fillWidth: true; wrapMode: Text.Wrap
                   text: "Como quer abrir este ficheiro?"; color: t.texto; font.pixelSize: 20; font.weight: Font.DemiBold }
            ListView {
                Layout.fillWidth: true; Layout.preferredHeight: Math.min(320, contentHeight); Layout.leftMargin: 16; Layout.rightMargin: 16
                clip: true
                model: abrirCom.apps
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width; height: 44; radius: 4
                    color: index === abrirCom.escolhida ? t.selecao : rApp.containsMouse ? t.hover : "transparent"
                    Rectangle { visible: index === abrirCom.escolhida; x: 0; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 18; radius: 1.5; color: t.acento }
                    Image { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; sourceSize: Qt.size(56, 56)
                            source: "image://icones/" + (modelData.icone || "application-x-executable") }
                    Text { x: 52; anchors.verticalCenter: parent.verticalCenter; text: modelData.nome + (modelData.predefinida ? "  (predefinida)" : "")
                           color: t.texto; font.pixelSize: 13 }
                    MouseArea { id: rApp; anchors.fill: parent; hoverEnabled: true; onClicked: abrirCom.escolhida = index
                                onDoubleClicked: { arquivos.abrirCom(abrirCom.indice, modelData.id, sempre.marcada); abrirCom.close() } }
                }
            }
            CaixaW { id: sempre; Layout.leftMargin: 24; texto: "Usar sempre esta aplicação para este tipo de ficheiro" }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 72; Layout.topMargin: 6
                color: t.e ? "#1b1b1b" : "#ebebeb"
                bottomLeftRadius: 8; bottomRightRadius: 8
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 24
                    spacing: 8
                    BotaoW { Layout.fillWidth: true; texto: "OK"; destaque: true; ativo: abrirCom.apps.length > 0
                             onClicado: { arquivos.abrirCom(abrirCom.indice, abrirCom.apps[abrirCom.escolhida].id, sempre.marcada); abrirCom.close() } }
                    BotaoW { Layout.fillWidth: true; texto: "Cancelar"; onClicado: abrirCom.close() }
                }
            }
        }
    }

    // eliminar permanentemente
    DialogoW {
        id: confirmarApagar
        width: 420
        contentItem: ColumnLayout {
            spacing: 12
            Item { Layout.preferredHeight: 6 }
            Text { Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.fillWidth: true; wrapMode: Text.Wrap
                   text: "Eliminar permanentemente"; color: t.texto; font.pixelSize: 20; font.weight: Font.DemiBold }
            Text { Layout.leftMargin: 24; Layout.rightMargin: 24; Layout.fillWidth: true; wrapMode: Text.Wrap
                   text: arquivos.selecao.length === 1 ? "Tem a certeza de que quer eliminar permanentemente este item? Não vai para a Reciclagem."
                                                        : "Tem a certeza de que quer eliminar permanentemente estes " + arquivos.selecao.length + " itens?"
                   color: t.texto2; font.pixelSize: 13 }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 72; Layout.topMargin: 8
                color: t.e ? "#1b1b1b" : "#ebebeb"
                bottomLeftRadius: 8; bottomRightRadius: 8
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 24
                    spacing: 8
                    BotaoW { Layout.fillWidth: true; texto: "Sim"; destaque: true; onClicado: { arquivos.apagarSelecao(true); confirmarApagar.close() } }
                    BotaoW { Layout.fillWidth: true; texto: "Não"; onClicado: confirmarApagar.close() }
                }
            }
        }
    }

    // nova etiqueta
    DialogoW {
        id: novaEtiqueta
        width: 380
        property string cor: "#3498db"
        onOpened: { campoEtq.text = ""; campoEtq.focar() }
        contentItem: ColumnLayout {
            spacing: 12
            Item { Layout.preferredHeight: 6 }
            Text { Layout.leftMargin: 24; text: "Nova etiqueta"; color: t.texto; font.pixelSize: 20; font.weight: Font.DemiBold }
            CampoW { id: campoEtq; Layout.leftMargin: 24; Layout.rightMargin: 24; dica: "Nome (ex.: Trabalho)"
                     onAceite: { arquivos.criarEtiqueta(text, novaEtiqueta.cor, "folder"); novaEtiqueta.close() } }
            Row {
                Layout.leftMargin: 24; spacing: 8
                Repeater {
                    model: ["#e74c3c", "#e67e22", "#f1c40f", "#2ecc71", "#3498db", "#9b59b6", "#95a5a6"]
                    delegate: Rectangle {
                        required property string modelData
                        width: 26; height: 26; radius: 13; color: modelData
                        border.width: novaEtiqueta.cor === modelData ? 3 : 0; border.color: t.texto
                        MouseArea { anchors.fill: parent; onClicked: novaEtiqueta.cor = modelData }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 72; Layout.topMargin: 8
                color: t.e ? "#1b1b1b" : "#ebebeb"
                bottomLeftRadius: 8; bottomRightRadius: 8
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 24; anchors.rightMargin: 24
                    spacing: 8
                    BotaoW { Layout.fillWidth: true; texto: "Criar"; destaque: true; ativo: campoEtq.text.trim() !== ""
                             onClicado: { arquivos.criarEtiqueta(campoEtq.text, novaEtiqueta.cor, "folder"); novaEtiqueta.close() } }
                    BotaoW { Layout.fillWidth: true; texto: "Cancelar"; onClicado: novaEtiqueta.close() }
                }
            }
        }
    }

    // ---- progresso das cópias (canto de baixo à direita) ----------------------------------------------
    Rectangle {
        id: cartaoOp
        readonly property var op: arquivos.operacao
        visible: !!op.titulo
        anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 40
        width: 360; height: 88; radius: 8
        color: t.menu; border.width: 1; border.color: t.menuBorda
        Column {
            x: 16; y: 14; width: parent.width - 32; spacing: 8
            Text { width: parent.width; elide: Text.ElideRight; text: cartaoOp.op.titulo || ""; color: t.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
            Rectangle {
                width: parent.width; height: 4; radius: 2; color: t.e ? "#3a3a3a" : "#e0e0e0"
                Rectangle { width: parent.width * (cartaoOp.op.fracao || 0); height: parent.height; radius: 2; color: t.acento
                            Behavior on width { NumberAnimation { duration: 120 } } }
            }
            Text { width: parent.width; elide: Text.ElideMiddle; text: Math.round((cartaoOp.op.fracao || 0) * 100) + "% concluído  ·  " + (cartaoOp.op.texto || "")
                   color: t.texto3; font.pixelSize: 12 }
        }
    }

    // ---- aviso rápido --------------------------------------------------------------------------------
    Rectangle {
        id: aviso
        property bool visivel: false
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - (visivel ? 76 : 0)
        width: Math.min(parent.width - 80, textoAviso.implicitWidth + 40); height: 40; radius: 8
        color: t.menu; border.width: 1; border.color: t.menuBorda
        opacity: visivel ? 1 : 0
        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Text { id: textoAviso; anchors.centerIn: parent; width: parent.width - 32; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
               color: t.texto; font.pixelSize: 13 }
        Timer { id: esconde; interval: 3500; onTriggered: aviso.visivel = false }
        function mostrar(txt) { textoAviso.text = txt; visivel = true; esconde.restart() }
    }
}
