// CarinaeOS — Terminal Carinae: a janela (abas no topo, como o Terminal do Windows 11)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import CarinaeOS.Terminal

ApplicationWindow {
    id: janela
    width: 960; height: 600
    minimumWidth: 420; minimumHeight: 240
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: abaAtual && abaAtual.tituloAba ? abaAtual.tituloAba + " — Carinae Terminal" : "Carinae Terminal"
    font.family: "Inter"; font.pixelSize: 13

    // ---- aparência (de ~/.config/carinaeos/terminal.json) ------------------------------------------
    readonly property var cfg: configuracao.dados
    readonly property var paleta: cfg.paleta || ({})
    readonly property color corFundo: paleta.fundo || "#14111f"
    readonly property color corTexto: paleta.texto || "#e8e2f4"
    readonly property color corCursor: paleta.cursor || "#ffb46e"
    readonly property var cores16: (paleta.cores && paleta.fortes) ? paleta.cores.concat(paleta.fortes)
        : ["#2a2438", "#ff6f91", "#7ee0a6", "#ffb46e", "#7aa7ff", "#c792ea", "#5fd7d0", "#d8d0e8",
           "#5a5270", "#ff8fab", "#a3f0c2", "#ffd09e", "#a3c2ff", "#ddb3f5", "#8fe8e2", "#ffffff"]
    readonly property real opacidade: (cfg.opacidade !== undefined ? cfg.opacidade : 92) / 100
    readonly property string familia: cfg.fonte || "Monospace"
    property real zoom: 0
    readonly property real tamanho: (cfg.tamanho || 11) + zoom
    readonly property bool claro: (corFundo.r + corFundo.g + corFundo.b) / 3 > 0.6
    readonly property color corBarra: Qt.rgba(corFundo.r * 0.75, corFundo.g * 0.75, corFundo.b * 0.75 + 0.02, Math.min(1, opacidade + 0.04))
    readonly property color corAbaAtiva: Qt.rgba(corFundo.r, corFundo.g, corFundo.b, opacidade)
    readonly property bool maximizada: visibility === Window.Maximized || visibility === Window.FullScreen

    property var abaAtual: null
    property int contador: 0

    ListModel { id: abas }

    function novaAba(comando, pasta, manter, titulo) {
        contador++;
        abas.append({ ident: contador, comando: JSON.stringify(comando || []), pasta: pasta || (abaAtual ? abaAtual.pastaAtual : pastaInicial),
                      manter: !!manter, tituloFixo: titulo || "" });
        lista.currentIndex = abas.count - 1;
    }
    function fecharAba(i) {
        if (i < 0 || i >= abas.count) return;
        abas.remove(i);
        if (abas.count === 0) Qt.quit();
        else lista.currentIndex = Math.min(i, abas.count - 1);
    }
    Component.onCompleted: novaAba(comandoInicial, pastaInicial, manterInicial, tituloInicial)

    // ---- atalhos (os do Ctrl+Shift não chegam à shell, como nos outros terminais) -------------------
    Shortcut { sequence: "Ctrl+Shift+T"; onActivated: janela.novaAba() }
    Shortcut { sequence: "Ctrl+Shift+N"; onActivated: configuracao.novaJanela(janela.abaAtual ? janela.abaAtual.pastaAtual : pastaInicial) }
    Shortcut { sequence: "Ctrl+Shift+W"; onActivated: janela.fecharAba(lista.currentIndex) }
    Shortcut { sequence: "Ctrl+Shift+C"; onActivated: if (janela.abaAtual) janela.abaAtual.ecra.copiar() }
    Shortcut { sequence: "Ctrl+Shift+V"; onActivated: if (janela.abaAtual) janela.abaAtual.ecra.colar() }
    Shortcut { sequence: "Shift+Insert"; onActivated: if (janela.abaAtual) janela.abaAtual.ecra.colar() }
    Shortcut { sequence: "Ctrl+Shift+A"; onActivated: if (janela.abaAtual) janela.abaAtual.ecra.selecionarTudo() }
    Shortcut { sequence: "Ctrl+Shift+K"; onActivated: if (janela.abaAtual) janela.abaAtual.ecra.limparHistorico() }
    Shortcut { sequences: ["Ctrl+Tab", "Ctrl+PgDown"]; onActivated: lista.currentIndex = (lista.currentIndex + 1) % abas.count }
    Shortcut { sequences: ["Ctrl+Shift+Tab", "Ctrl+PgUp"]; onActivated: lista.currentIndex = (lista.currentIndex - 1 + abas.count) % abas.count }
    Shortcut { sequences: ["Ctrl+=", "Ctrl++", "Ctrl+Shift+="]; onActivated: janela.zoom = Math.min(24, janela.zoom + 1) }
    Shortcut { sequence: "Ctrl+-"; onActivated: janela.zoom = Math.max(-5, janela.zoom - 1) }
    Shortcut { sequence: "Ctrl+0"; onActivated: janela.zoom = 0 }
    Shortcut { sequence: "F11"; onActivated: janela.visibility = janela.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen }
    Repeater {
        model: 9
        Item { Shortcut { sequence: "Alt+" + (index + 1); onActivated: if (index < abas.count) lista.currentIndex = index } }
    }

    Rectangle {
        id: moldura
        anchors.fill: parent
        radius: janela.maximizada ? 0 : 10
        color: "transparent"
        clip: true
        border.width: janela.maximizada ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, janela.claro ? 0.25 : 0.09)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: moldura.border.width
            spacing: 0

            // ---- barra das abas (arrastar move a janela; duplo clique maximiza) -------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                color: janela.corBarra
                topLeftRadius: moldura.radius; topRightRadius: moldura.radius

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onPressed: (ev) => { if (ev.button === Qt.LeftButton) janela.startSystemMove(); }
                    onDoubleClicked: janela.visibility = janela.maximizada ? Window.Windowed : Window.Maximized
                    onClicked: (ev) => { if (ev.button === Qt.MiddleButton) janela.novaAba(); }
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    spacing: 2
                    ListView {
                        id: lista
                        Layout.preferredWidth: Math.min(contentWidth, parent.width - 160)
                        Layout.fillHeight: true
                        Layout.topMargin: 6
                        orientation: ListView.Horizontal
                        interactive: false
                        spacing: 2
                        model: abas
                        currentIndex: 0
                        clip: true
                        delegate: Rectangle {
                            id: aba
                            required property int index
                            required property var model
                            readonly property bool atual: ListView.isCurrentItem
                            readonly property string texto: model.tituloFixo || (painel ? painel.tituloAba : "Terminal")
                            width: Math.max(110, Math.min(220, (janela.width - 200) / Math.max(1, abas.count)))
                            height: lista.height
                            topLeftRadius: 8; topRightRadius: 8
                            color: atual ? janela.corAbaAtiva : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
                            // o painel de cada aba vive em "conteudo"; aqui só o apontador
                            property var painel: (conteudoRep.count, conteudoRep.itemAt(index))
                            Rectangle { visible: !aba.atual && aba.index < abas.count - 1 && !(lista.currentIndex === aba.index + 1)
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 16
                                        color: Qt.rgba(1, 1, 1, 0.12) }
                            Text {
                                id: simbolo
                                x: 12; anchors.verticalCenter: parent.verticalCenter
                                text: "❯"; color: aba.atual ? janela.corCursor : Qt.rgba(janela.corTexto.r, janela.corTexto.g, janela.corTexto.b, 0.6)
                                font.pixelSize: 12; font.bold: true
                            }
                            Text {
                                anchors.left: simbolo.right; anchors.leftMargin: 8
                                anchors.right: fechar.left; anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: aba.texto; elide: Text.ElideRight
                                color: Qt.rgba(janela.corTexto.r, janela.corTexto.g, janela.corTexto.b, aba.atual ? 1 : 0.65)
                            }
                            MouseArea {
                                id: ma
                                anchors.fill: parent; hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onClicked: (ev) => { if (ev.button === Qt.MiddleButton) janela.fecharAba(aba.index); else lista.currentIndex = aba.index; }
                            }
                            Rectangle {
                                id: fechar
                                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                width: 22; height: 22; radius: 5
                                visible: aba.atual || ma.containsMouse || mf.containsMouse
                                color: mf.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                Text { anchors.centerIn: parent; text: "✕"; font.pixelSize: 11; color: janela.corTexto }
                                MouseArea { id: mf; anchors.fill: parent; hoverEnabled: true; onClicked: janela.fecharAba(aba.index) }
                            }
                        }
                        onCurrentIndexChanged: Qt.callLater(janela.mudouAba)
                    }
                    BotaoBarra { texto: "+"; tamanhoLetra: 18; dica: "Nova aba (Ctrl+Shift+T)"; onClicado: janela.novaAba() }
                    BotaoBarra { texto: "⌄"; tamanhoLetra: 15; dica: "Mais"; onClicado: menuMais.popup() }
                    Item { Layout.fillWidth: true }
                    BotaoBarra { texto: "—"; largura: 46; dica: "Minimizar"; onClicado: janela.showMinimized() }
                    BotaoBarra { texto: janela.maximizada ? "❐" : "☐"; largura: 46; dica: janela.maximizada ? "Restaurar" : "Maximizar"
                                 onClicado: janela.visibility = janela.maximizada ? Window.Windowed : Window.Maximized }
                    BotaoBarra { texto: "✕"; largura: 46; perigo: true; dica: "Fechar"; onClicado: janela.close() }
                }
            }

            // ---- os terminais (um por aba; os escondidos continuam a correr) ------------------------------
            Item {
                id: conteudo
                Layout.fillWidth: true
                Layout.fillHeight: true
                Repeater {
                    id: conteudoRep
                    model: abas
                    delegate: Item {
                        id: painel
                        required property int index
                        required property var model
                        anchors.fill: parent
                        visible: index === lista.currentIndex
                        readonly property alias ecra: ecra
                        readonly property string pastaAtual: ecra.pasta || model.pasta
                        readonly property string tituloAba: {
                            // o título que a shell pede ("leo@pc: ~/Documentos"); sem ele, o programa e a pasta
                            if (ecra.titulo) return ecra.titulo;
                            const p = (ecra.pasta || "").replace(/^\/home\/[^/]+/, "~");
                            return ecra.programa && ecra.programa !== "bash" && ecra.programa !== "zsh" && ecra.programa !== "fish"
                                ? ecra.programa : (p || "Terminal");
                        }
                        Terminal {
                            id: ecra
                            anchors.fill: parent
                            comando: JSON.parse(painel.model.comando)
                            pastaInicial: painel.model.pasta
                            manter: painel.model.manter
                            familia: janela.familia
                            tamanho: janela.tamanho
                            cores: janela.cores16
                            fundo: janela.corFundo
                            texto: janela.corTexto
                            corCursor: janela.corCursor
                            formaCursor: janela.cfg.cursor || "barra"
                            opacidade: janela.opacidade
                            margem: janela.cfg.margem !== undefined ? janela.cfg.margem : 10
                            onTerminou: (codigo) => { if (!painel.model.manter) janela.fecharAba(painel.index); }
                            onMenuPedido: (x, y) => { menu.alvo = ecra; menu.popup(); }
                            onVisibleChanged: if (visible) focar()
                        }
                        // ao mudar o tamanho: "80×24" por um instante, como no Terminal do macOS
                        Rectangle {
                            id: tamanhoAviso
                            anchors.centerIn: parent
                            width: tt.implicitWidth + 24; height: 30; radius: 8
                            color: Qt.rgba(0, 0, 0, 0.6); opacity: 0
                            Text { id: tt; anchors.centerIn: parent; color: "white"; text: ecra.colunas + " × " + ecra.linhas }
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            Timer { id: esconderTam; interval: 700; onTriggered: tamanhoAviso.opacity = 0 }
                            Connections {
                                target: ecra
                                function onTamanhoGrelhaMudou() { if (painel.visible && janela.active) { tamanhoAviso.opacity = 1; esconderTam.restart(); } }
                            }
                        }
                    }
                }
            }
        }

        // ---- redimensionar pelas bordas (a janela não tem moldura do gestor) ----------------------------
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

    function mudouAba() {
        abaAtual = conteudoRep.itemAt(lista.currentIndex);
        if (abaAtual) abaAtual.ecra.focar();
    }
    onActiveChanged: if (active && abaAtual) abaAtual.ecra.focar()

    // ---- menus -------------------------------------------------------------------------------------
    Menu {
        id: menu
        property var alvo: null
        ItemMenu { text: "Copiar"; enabled: menu.alvo && menu.alvo.temSelecao; onTriggered: menu.alvo.copiar() }
        ItemMenu { text: "Colar"; onTriggered: menu.alvo.colar() }
        ItemMenu { text: "Selecionar tudo"; onTriggered: menu.alvo.selecionarTudo() }
        ItemMenu { text: "Limpar o histórico"; onTriggered: menu.alvo.limparHistorico() }
        MenuSeparator {}
        ItemMenu { text: "Nova aba"; onTriggered: janela.novaAba() }
        ItemMenu { text: "Abrir esta pasta nos Documentos"; onTriggered: configuracao.abrir("carinaeos-arquivos", [janela.abaAtual.pastaAtual]) }
        MenuSeparator {}
        ItemMenu { text: "Aparência do terminal…"; onTriggered: configuracao.abrir("carinae-terminal-aparencia", []) }
    }
    Menu {
        id: menuMais
        ItemMenu { text: "Nova aba"; atalho: "Ctrl+Shift+T"; onTriggered: janela.novaAba() }
        ItemMenu { text: "Nova janela"; atalho: "Ctrl+Shift+N"; onTriggered: configuracao.novaJanela(janela.abaAtual ? janela.abaAtual.pastaAtual : pastaInicial) }
        ItemMenu { text: "Nova aba como administrador"; onTriggered: janela.novaAba(["sudo", "-i"], "", false, "Administrador") }
        MenuSeparator {}
        ItemMenu { text: "Aumentar a letra"; atalho: "Ctrl+="; onTriggered: janela.zoom = Math.min(24, janela.zoom + 1) }
        ItemMenu { text: "Diminuir a letra"; atalho: "Ctrl+−"; onTriggered: janela.zoom = Math.max(-5, janela.zoom - 1) }
        ItemMenu { text: "Ecrã inteiro"; atalho: "F11"; onTriggered: janela.visibility = janela.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen }
        MenuSeparator {}
        ItemMenu { text: "Aparência do terminal…"; onTriggered: configuracao.abrir("carinae-terminal-aparencia", []) }
    }

    component BotaoBarra: Rectangle {
        id: bb
        property string texto
        property string dica
        property int largura: 34
        property int tamanhoLetra: 13
        property bool perigo: false
        signal clicado()
        Layout.preferredWidth: largura
        Layout.fillHeight: largura > 40
        Layout.preferredHeight: largura > 40 ? -1 : 30
        Layout.alignment: Qt.AlignVCenter
        radius: largura > 40 ? 0 : 6
        color: mb.containsMouse ? (perigo ? "#c42b1c" : Qt.rgba(1, 1, 1, 0.1)) : "transparent"
        Text { anchors.centerIn: parent; text: bb.texto; color: mb.containsMouse && bb.perigo ? "white" : janela.corTexto; font.pixelSize: bb.tamanhoLetra }
        MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; onClicked: bb.clicado() }
        ToolTip.visible: mb.containsMouse && dica !== ""
        ToolTip.text: dica
        ToolTip.delay: 600
    }

    component ItemMenu: MenuItem {
        id: im
        property string atalho
        implicitHeight: 32
        contentItem: RowLayout {
            spacing: 24
            Text { text: im.text; color: im.enabled ? "#f2f0f6" : "#77737f"; Layout.fillWidth: true; leftPadding: im.checkable ? 22 : 4 }
            Text { text: im.atalho; color: "#a8a3b6"; font.pixelSize: 12; visible: im.atalho !== ""; rightPadding: 4 }
        }
    }
}
