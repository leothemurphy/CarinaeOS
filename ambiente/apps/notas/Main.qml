// CarinaeOS — Carinae Notas (no jeito do Bloco de Notas do Windows 11)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: janela
    width: 960; height: 640
    minimumWidth: 480; minimumHeight: 300
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: (atual ? atual.titulo : "Sem título") + " — Carinae Notas"
    font.family: "Inter"; font.pixelSize: 13
    // as cores dos controlos padrão (menus, caixas, listas) no tema escuro do CarinaeOS
    palette.window: "#2b2a32"; palette.windowText: "#f2f0f6"; palette.base: "#24232a"; palette.alternateBase: "#2b2a32"
    palette.text: "#f2f0f6"; palette.button: "#3a3942"; palette.buttonText: "#f2f0f6"; palette.brightText: "#ffffff"
    palette.highlight: "#7aa7ff"; palette.highlightedText: "#10131c"; palette.light: "#4a4952"; palette.midlight: "#3f3e47"
    palette.mid: "#55535f"; palette.dark: "#1c1b21"; palette.shadow: "#000000"; palette.toolTipBase: "#2f2e37"; palette.toolTipText: "#f2f0f6"
    palette.placeholderText: "#8a8597"

    readonly property color fundo: "#1f1e25"
    readonly property color barra: "#2a2931"
    readonly property color texto: "#f2f0f6"
    readonly property color suave: "#a8a3b6"
    readonly property color realce: "#7aa7ff"
    readonly property bool maximizada: visibility === Window.Maximized || visibility === Window.FullScreen
    readonly property var cfg: notas.config
    readonly property int zoom: cfg.zoom || 100
    readonly property bool quebra: cfg.quebra !== false
    readonly property bool barraEstado: cfg.barraEstado !== false
    readonly property string fonte: cfg.fonte || "DejaVu Sans Mono"

    property var atual: null           // o painel da aba atual
    property int contador: 0
    property bool sessaoSuja: false

    ListModel { id: abas }

    // ---- abas ---------------------------------------------------------------------------------------
    function novaAba(dados) {
        contador++;
        const d = Object.assign({ ident: contador, caminho: "", textoInicial: "", codificacao: "UTF-8", fimLinha: "LF",
                                  modificadoInicial: false, cursor: 0, mtime: 0 }, dados || {});
        abas.append(d);
        lista.currentIndex = abas.count - 1;
        sessaoSuja = true;
        Qt.callLater(mudouAba);
    }
    function abrir(caminho) {
        if (!caminho) { janela.raise(); janela.requestActivate(); return; }
        for (let i = 0; i < abas.count; i++)
            if (abas.get(i).caminho === caminho) { lista.currentIndex = i; return; }
        const r = notas.ler(caminho);
        if (r.erro) { aviso(r.erro); return; }
        // uma aba vazia e sem nome é substituída (como no Windows)
        if (atual && !atual.caminho && !atual.modificado && atual.area.length === 0 && abas.count > 0) {
            const i = lista.currentIndex;
            abas.remove(i);
            contador++;
            abas.insert(i, { ident: contador, caminho: caminho, textoInicial: r.texto, codificacao: r.codificacao,
                             fimLinha: r.fimLinha, modificadoInicial: false, cursor: 0, mtime: r.mtime });
            lista.currentIndex = i;
            Qt.callLater(mudouAba);
        } else {
            novaAba({ caminho: caminho, textoInicial: r.texto, codificacao: r.codificacao, fimLinha: r.fimLinha, mtime: r.mtime });
        }
        sessaoSuja = true;
    }
    function fecharAba(i, forcar) {
        const p = paineis.itemAt(i);
        if (!p) return;
        if (p.modificado && !forcar) { lista.currentIndex = i; perguntaFechar.indice = i; perguntaFechar.open(); return; }
        abas.remove(i);
        if (abas.count === 0) novaAba();
        lista.currentIndex = Math.min(i, abas.count - 1);
        sessaoSuja = true;
        Qt.callLater(mudouAba);
    }
    function mudouAba() {
        atual = paineis.itemAt(lista.currentIndex);
        if (atual) atual.area.forceActiveFocus();
        sessaoSuja = true;
    }

    // ---- gravar -------------------------------------------------------------------------------------
    property var depoisDeGravar: ({})       // ident -> "fechar"
    function gravar(p, como) {
        if (!p) return;
        if (!p.caminho || como) {
            notas.escolherGravar(p.ident, p.caminho || (p.titulo.replace(/[\/\\:*?"<>|]/g, "-") + ".txt"));
            return;
        }
        const e = notas.gravar(p.caminho, p.area.text, p.codificacao, p.fimLinha);
        if (e) { aviso("Não foi possível salvar: " + e); return; }
        p.modificado = false;
        p.mtime = notas.mtime(p.caminho);
        sessaoSuja = true;
        if (depoisDeGravar[p.ident] === "fechar") { delete depoisDeGravar[p.ident]; fecharAba(p.index, true); }
    }
    Connections {
        target: notas
        function onGravarComoEscolhido(pedido, caminho) {
            if (!caminho) { delete janela.depoisDeGravar[pedido]; return; }
            for (let i = 0; i < abas.count; i++) {
                const p = paineis.itemAt(i);
                if (p && p.ident === pedido) {
                    p.caminho = caminho;
                    abas.setProperty(i, "caminho", caminho);
                    janela.gravar(p, false);
                    return;
                }
            }
        }
        function onAbrirPedido(c) { janela.abrir(c); }
        function onAviso(t) { janela.aviso(t); }
    }

    // ---- sessão -------------------------------------------------------------------------------------
    function gravarSessao() {
        const l = [];
        for (let i = 0; i < abas.count; i++) {
            const p = paineis.itemAt(i);
            if (!p) continue;
            const guardarTexto = p.modificado || !p.caminho;
            l.push({ caminho: p.caminho, texto: guardarTexto ? p.area.text : "", modificado: p.modificado,
                     codificacao: p.codificacao, fimLinha: p.fimLinha, cursor: p.area.cursorPosition, mtime: p.mtime });
        }
        notas.gravarSessao(JSON.stringify({ abas: l, atual: lista.currentIndex }));
        sessaoSuja = false;
    }
    Timer { interval: 3000; repeat: true; running: true; onTriggered: if (janela.sessaoSuja) janela.gravarSessao() }
    onClosing: gravarSessao()

    Component.onCompleted: {
        let s = null;
        try { s = JSON.parse(notas.lerSessao() || "null"); } catch (e) { s = null; }
        if (s && s.abas) {
            for (const a of s.abas) {
                if (a.caminho && !a.modificado) {
                    const r = notas.ler(a.caminho);
                    if (r.erro) continue;            // o arquivo já não existe: a aba não volta
                    novaAba({ caminho: a.caminho, textoInicial: r.texto, codificacao: r.codificacao, fimLinha: r.fimLinha, cursor: a.cursor || 0, mtime: r.mtime });
                } else if (a.texto || a.caminho) {
                    novaAba({ caminho: a.caminho || "", textoInicial: a.texto, codificacao: a.codificacao || "UTF-8",
                              fimLinha: a.fimLinha || "LF", modificadoInicial: !!a.modificado, cursor: a.cursor || 0, mtime: a.mtime || 0 });
                }
            }
            if (s.atual >= 0 && s.atual < abas.count) lista.currentIndex = s.atual;
        }
        for (const c of notas.iniciais) abrir(c);
        if (abas.count === 0) novaAba();
        Qt.callLater(mudouAba);
    }
    // ao voltar à janela: os arquivos que mudaram lá fora (e que não têm alterações aqui) recarregam
    onActiveChanged: {
        if (!active) { gravarSessao(); return; }
        for (let i = 0; i < abas.count; i++) {
            const p = paineis.itemAt(i);
            if (p && p.caminho && !p.modificado && p.mtime && notas.mtime(p.caminho) > p.mtime + 0.001) {
                const r = notas.ler(p.caminho);
                if (!r.erro) { const c = p.area.cursorPosition; p.carregar(r.texto); p.mtime = r.mtime; p.area.cursorPosition = Math.min(c, p.area.length); }
            }
        }
    }

    function aviso(t) { toast.texto = t; toast.opacity = 1; esconderToast.restart(); }

    // ---- atalhos ------------------------------------------------------------------------------------
    Shortcut { sequences: ["Ctrl+N", "Ctrl+T"]; onActivated: janela.novaAba() }
    Shortcut { sequence: "Ctrl+O"; onActivated: notas.escolherAbrir() }
    Shortcut { sequence: "Ctrl+S"; onActivated: janela.gravar(janela.atual, false) }
    Shortcut { sequence: "Ctrl+Shift+S"; onActivated: janela.gravar(janela.atual, true) }
    Shortcut { sequence: "Ctrl+Alt+S"; onActivated: janela.gravarTudo() }
    Shortcut { sequence: "Ctrl+W"; onActivated: janela.fecharAba(lista.currentIndex, false) }
    Shortcut { sequences: ["Ctrl+Tab", "Ctrl+PgDown"]; onActivated: { lista.currentIndex = (lista.currentIndex + 1) % abas.count; janela.mudouAba(); } }
    Shortcut { sequences: ["Ctrl+Shift+Tab", "Ctrl+PgUp"]; onActivated: { lista.currentIndex = (lista.currentIndex - 1 + abas.count) % abas.count; janela.mudouAba(); } }
    Shortcut { sequence: "Ctrl+F"; onActivated: busca.abrir(false) }
    Shortcut { sequence: "Ctrl+H"; onActivated: busca.abrir(true) }
    Shortcut { sequence: "F3"; onActivated: busca.procurar(true) }
    Shortcut { sequence: "Shift+F3"; onActivated: busca.procurar(false) }
    Shortcut { sequence: "Ctrl+G"; onActivated: irLinha.abrir() }
    Shortcut { sequence: "F5"; onActivated: if (janela.atual) janela.atual.area.insert(janela.atual.area.cursorPosition, notas.agora()) }
    Shortcut { sequences: ["Ctrl+=", "Ctrl++"]; onActivated: notas.definir("zoom", Math.min(500, janela.zoom + 10)) }
    Shortcut { sequence: "Ctrl+-"; onActivated: notas.definir("zoom", Math.max(30, janela.zoom - 10)) }
    Shortcut { sequence: "Ctrl+0"; onActivated: notas.definir("zoom", 100) }
    Shortcut { sequence: "Ctrl+P"; onActivated: if (janela.atual) notas.imprimir(janela.atual.area.text) }
    Shortcut { sequence: "Escape"; enabled: busca.visible; onActivated: busca.fechar() }
    Shortcut { sequence: "F11"; onActivated: janela.visibility = janela.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen }

    function gravarTudo() { for (let i = 0; i < abas.count; i++) { const p = paineis.itemAt(i); if (p && p.modificado) gravar(p, false); } }

    Rectangle {
        id: moldura
        anchors.fill: parent
        radius: janela.maximizada ? 0 : 10
        color: janela.fundo
        border.width: janela.maximizada ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.09)
        clip: true

        ColumnLayout {
            anchors.fill: parent; anchors.margins: moldura.border.width; spacing: 0

            // ---- abas no título -------------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 42
                color: Qt.darker(janela.fundo, 1.15)
                topLeftRadius: moldura.radius; topRightRadius: moldura.radius
                MouseArea {
                    anchors.fill: parent
                    onPressed: janela.startSystemMove()
                    onDoubleClicked: janela.visibility = janela.maximizada ? Window.Windowed : Window.Maximized
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 10; spacing: 2
                    Image { source: "image://icone/carinaeos-notas"; sourceSize: Qt.size(32, 32); Layout.preferredWidth: 18; Layout.preferredHeight: 18; Layout.rightMargin: 6 }
                    ListView {
                        id: lista
                        Layout.preferredWidth: Math.min(contentWidth, parent.width - 220)
                        Layout.fillHeight: true; Layout.topMargin: 6
                        orientation: ListView.Horizontal; interactive: false; spacing: 2; clip: true
                        model: abas
                        onCurrentIndexChanged: Qt.callLater(janela.mudouAba)
                        delegate: Rectangle {
                            id: aba
                            required property int index
                            readonly property var painel: (paineis.count, paineis.itemAt(index))
                            readonly property bool ativa: ListView.isCurrentItem
                            width: Math.max(120, Math.min(220, (janela.width - 260) / Math.max(1, abas.count)))
                            height: lista.height
                            topLeftRadius: 8; topRightRadius: 8
                            color: ativa ? janela.barra : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                            Text {
                                anchors.left: parent.left; anchors.leftMargin: 12; anchors.right: fx.left; anchors.rightMargin: 4
                                anchors.verticalCenter: parent.verticalCenter
                                text: aba.painel ? aba.painel.titulo : ""; elide: Text.ElideRight
                                color: aba.ativa ? janela.texto : janela.suave
                            }
                            MouseArea {
                                id: ma; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                onClicked: (ev) => { if (ev.button === Qt.MiddleButton) janela.fecharAba(aba.index, false); else { lista.currentIndex = aba.index; janela.mudouAba(); } }
                            }
                            ToolTip.visible: ma.containsMouse && aba.painel && !!aba.painel.caminho
                            ToolTip.text: aba.painel ? aba.painel.caminho : ""
                            ToolTip.delay: 700
                            // • quando há alterações; ✕ ao passar o rato
                            Rectangle {
                                id: fx
                                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                width: 22; height: 22; radius: 5
                                color: mfx.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: aba.painel && aba.painel.modificado && !(ma.containsMouse || mfx.containsMouse) ? "●" : "✕"
                                    visible: aba.ativa || ma.containsMouse || mfx.containsMouse || (aba.painel && aba.painel.modificado)
                                    color: janela.texto; font.pixelSize: text === "●" ? 9 : 11
                                }
                                MouseArea { id: mfx; anchors.fill: parent; hoverEnabled: true; onClicked: janela.fecharAba(aba.index, false) }
                            }
                        }
                    }
                    Pequeno { glifo: "+"; dica: "Nova aba (Ctrl+N)"; onClicado: janela.novaAba() }
                    Item { Layout.fillWidth: true }
                    BotaoJanela { texto: "—"; onClicado: janela.showMinimized() }
                    BotaoJanela { texto: janela.maximizada ? "❐" : "☐"; onClicado: janela.visibility = janela.maximizada ? Window.Windowed : Window.Maximized }
                    BotaoJanela { texto: "✕"; perigo: true; onClicado: janela.close() }
                }
            }

            // ---- menus --------------------------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 36
                color: janela.barra
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 6; spacing: 2
                    MenuTexto { texto: "Arquivo"; menu: menuArquivo }
                    MenuTexto { texto: "Editar"; menu: menuEditar }
                    MenuTexto { texto: "Exibir"; menu: menuExibir }
                    Item { Layout.fillWidth: true }
                }
            }

            // ---- o texto ------------------------------------------------------------------------------
            Item {
                Layout.fillWidth: true; Layout.fillHeight: true
                Repeater {
                    id: paineis
                    model: abas
                    delegate: Item {
                        id: painel
                        required property int index
                        required property var model
                        anchors.fill: parent
                        visible: index === lista.currentIndex
                        readonly property int ident: model.ident
                        property string caminho: model.caminho
                        property string codificacao: model.codificacao
                        property string fimLinha: model.fimLinha
                        property real mtime: model.mtime
                        property bool modificado: model.modificadoInicial
                        property bool aCarregar: false
                        readonly property alias area: area
                        readonly property string titulo: caminho ? notas.nomeDe(caminho) : (primeiraLinha || "Sem título")
                        readonly property string primeiraLinha: {
                            // as abas sem nome mostram o começo do texto (como no Windows 11)
                            const t = area.text.substring(0, 60).split("\n")[0].trim();
                            return t.length > 30 ? t.substring(0, 30) + "…" : t;
                        }
                        function carregar(t) { aCarregar = true; area.text = t; aCarregar = false; modificado = false; }
                        Component.onCompleted: {
                            aCarregar = true;
                            area.text = model.textoInicial;
                            area.cursorPosition = Math.min(model.cursor, area.length);
                            aCarregar = false;
                        }
                        ScrollView {
                            id: rolar
                            anchors.fill: parent
                            ScrollBar.horizontal.policy: janela.quebra ? ScrollBar.AlwaysOff : ScrollBar.AsNeeded
                            TextArea {
                                id: area
                                wrapMode: janela.quebra ? TextEdit.Wrap : TextEdit.NoWrap
                                font.family: janela.fonte
                                font.pixelSize: Math.round(15 * janela.zoom / 100)
                                color: janela.texto
                                selectionColor: Qt.rgba(0.48, 0.65, 1, 0.45)
                                selectedTextColor: janela.texto
                                selectByMouse: true; persistentSelection: true
                                leftPadding: 18; rightPadding: 18; topPadding: 12; bottomPadding: 12
                                tabStopDistance: 4 * fm.advanceWidth(" ")
                                FontMetrics { id: fm; font: area.font }
                                background: null
                                placeholderText: "Comece a escrever…"
                                placeholderTextColor: Qt.rgba(1, 1, 1, 0.25)
                                onTextChanged: if (!painel.aCarregar) { painel.modificado = true; janela.sessaoSuja = true; }
                                // Ctrl + roda: tamanho da letra
                                WheelHandler {
                                    acceptedModifiers: Qt.ControlModifier
                                    onWheel: (ev) => notas.definir("zoom", Math.max(30, Math.min(500, janela.zoom + (ev.angleDelta.y > 0 ? 10 : -10))))
                                }
                                TapHandler {
                                    acceptedButtons: Qt.RightButton
                                    onTapped: menuEditar.popup()
                                }
                            }
                        }
                    }
                }
                DropArea {
                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    onDropped: (ev) => { for (const u of ev.urls) janela.abrir(decodeURIComponent(String(u).replace("file://", ""))); }
                }

                // ---- procurar e substituir (por cima, à direita) -----------------------------------
                Rectangle {
                    id: busca
                    property bool substituir: false
                    property bool maiusculas: false
                    visible: false
                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 10
                    width: Math.min(440, parent.width - 20); height: col.implicitHeight + 16
                    radius: 8; color: "#2f2e37"; border.color: Qt.rgba(1, 1, 1, 0.1)
                    function abrir(subst) {
                        substituir = subst; visible = true;
                        if (janela.atual && janela.atual.area.selectedText && janela.atual.area.selectedText.indexOf("\n") < 0) campoBusca.text = janela.atual.area.selectedText;
                        campoBusca.forceActiveFocus(); campoBusca.selectAll();
                    }
                    function fechar() { visible = false; if (janela.atual) janela.atual.area.forceActiveFocus(); }
                    function procurar(frente) {
                        const a = janela.atual ? janela.atual.area : null;
                        const q = campoBusca.text;
                        if (!a || !q) return false;
                        const t = maiusculas ? a.text : a.text.toLowerCase();
                        const qq = maiusculas ? q : q.toLowerCase();
                        let i;
                        if (frente) {
                            i = t.indexOf(qq, a.selectionEnd);
                            if (i < 0) i = t.indexOf(qq, 0);
                        } else {
                            i = a.selectionStart > 0 ? t.lastIndexOf(qq, a.selectionStart - 1) : -1;
                            if (i < 0) i = t.lastIndexOf(qq);
                        }
                        if (i < 0) { semResultados.visible = true; return false; }
                        semResultados.visible = false;
                        a.select(i, i + q.length);
                        return true;
                    }
                    function trocar() {
                        const a = janela.atual ? janela.atual.area : null;
                        if (!a) return;
                        const igual = maiusculas ? a.selectedText === campoBusca.text : a.selectedText.toLowerCase() === campoBusca.text.toLowerCase();
                        if (a.selectedText && igual) {
                            const s = a.selectionStart;
                            a.remove(a.selectionStart, a.selectionEnd);
                            a.insert(s, campoTroca.text);
                            a.select(s + campoTroca.text.length, s + campoTroca.text.length);
                        }
                        procurar(true);
                    }
                    function trocarTudo() {
                        const a = janela.atual ? janela.atual.area : null;
                        if (!a || !campoBusca.text) return;
                        const esc = campoBusca.text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
                        const re = new RegExp(esc, maiusculas ? "g" : "gi");
                        const n = (a.text.match(re) || []).length;
                        if (!n) { semResultados.visible = true; return; }
                        const c = a.cursorPosition;
                        a.text = a.text.replace(re, () => campoTroca.text);
                        a.cursorPosition = Math.min(c, a.length);
                        janela.aviso(n === 1 ? "1 substituição." : n + " substituições.");
                    }
                    ColumnLayout {
                        id: col
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
                        spacing: 6
                        RowLayout {
                            spacing: 4
                            Pequeno { glifo: busca.substituir ? "⌄" : "›"; dica: "Substituir (Ctrl+H)"; onClicado: busca.substituir = !busca.substituir }
                            Campo { id: campoBusca; Layout.fillWidth: true; placeholderText: "Procurar"
                                    onAccepted: busca.procurar(true); onTextChanged: semResultados.visible = false }
                            Pequeno { glifo: "↑"; dica: "Anterior (Shift+F3)"; onClicado: busca.procurar(false) }
                            Pequeno { glifo: "↓"; dica: "Seguinte (F3)"; onClicado: busca.procurar(true) }
                            Pequeno { glifo: "Aa"; dica: "Diferenciar maiúsculas"; ativo: busca.maiusculas; onClicado: busca.maiusculas = !busca.maiusculas }
                            Pequeno { glifo: "✕"; dica: "Fechar (Esc)"; onClicado: busca.fechar() }
                        }
                        RowLayout {
                            visible: busca.substituir; spacing: 4
                            Item { Layout.preferredWidth: 36 }
                            Campo { id: campoTroca; Layout.fillWidth: true; placeholderText: "Substituir por"; onAccepted: busca.trocar() }
                            Botao { text: "Substituir"; onClicked: busca.trocar() }
                            Botao { text: "Tudo"; onClicked: busca.trocarTudo() }
                        }
                        Text { id: semResultados; visible: false; text: "Não encontrei \"" + campoBusca.text + "\""; color: "#ff9aa9"; font.pixelSize: 12; Layout.leftMargin: 40 }
                    }
                }
            }

            // ---- barra de estado -------------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: janela.barraEstado ? 30 : 0
                visible: janela.barraEstado
                color: janela.barra
                bottomLeftRadius: moldura.radius; bottomRightRadius: moldura.radius
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 0
                    readonly property var pos: {
                        const a = janela.atual ? janela.atual.area : null;
                        if (!a) return [1, 1];
                        const antes = a.text.substring(0, a.cursorPosition);
                        const ln = antes.split("\n").length;
                        return [ln, a.cursorPosition - antes.lastIndexOf("\n")];
                    }
                    Estado { texto: "Ln " + parent.pos[0] + ", Col " + parent.pos[1]; Layout.preferredWidth: 130 }
                    Estado {
                        Layout.preferredWidth: 170
                        texto: janela.atual ? (janela.atual.area.selectedText.length ? janela.atual.area.selectedText.length + " de " : "")
                                              + janela.atual.area.length.toLocaleString(Qt.locale("pt_BR"), "f", 0) + " caracteres" : ""
                    }
                    Item { Layout.fillWidth: true }
                    Estado { texto: janela.zoom + "%"; Layout.preferredWidth: 60 }
                    Estado {
                        Layout.preferredWidth: 130
                        texto: janela.atual ? ({ "CRLF": "Windows (CRLF)", "LF": "Unix (LF)", "CR": "Mac (CR)" })[janela.atual.fimLinha] : ""
                        clicavel: true; onClicado: menuFim.popup()
                    }
                    Estado { texto: janela.atual ? janela.atual.codificacao : ""; Layout.preferredWidth: 110; clicavel: true; onClicado: menuCod.popup() }
                }
            }
        }

        // ---- bordas ---------------------------------------------------------------------------------
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

        Rectangle {
            id: toast
            property string texto
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 50
            width: tt.implicitWidth + 32; height: 40; radius: 10
            color: "#34323d"; border.color: Qt.rgba(1, 1, 1, 0.1)
            opacity: 0; visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Timer { id: esconderToast; interval: 4000; onTriggered: toast.opacity = 0 }
            Text { id: tt; anchors.centerIn: parent; text: toast.texto; color: janela.texto }
        }
    }

    // ---- menus ----------------------------------------------------------------------------------------
    Menu {
        id: menuArquivo
        ItemMenu { text: "Nova aba"; atalho: "Ctrl+N"; onTriggered: janela.novaAba() }
        ItemMenu { text: "Abrir…"; atalho: "Ctrl+O"; onTriggered: notas.escolherAbrir() }
        ItemMenu { text: "Salvar"; atalho: "Ctrl+S"; onTriggered: janela.gravar(janela.atual, false) }
        ItemMenu { text: "Salvar como…"; atalho: "Ctrl+Shift+S"; onTriggered: janela.gravar(janela.atual, true) }
        ItemMenu { text: "Salvar tudo"; atalho: "Ctrl+Alt+S"; onTriggered: janela.gravarTudo() }
        MenuSeparator {}
        ItemMenu { text: "Imprimir"; atalho: "Ctrl+P"; onTriggered: if (janela.atual) notas.imprimir(janela.atual.area.text) }
        ItemMenu { text: "Mostrar na pasta"; enabled: janela.atual && !!janela.atual.caminho; onTriggered: notas.mostrarNaPasta(janela.atual.caminho) }
        MenuSeparator {}
        ItemMenu { text: "Fechar a aba"; atalho: "Ctrl+W"; onTriggered: janela.fecharAba(lista.currentIndex, false) }
        ItemMenu { text: "Sair"; onTriggered: janela.close() }
    }
    Menu {
        id: menuEditar
        ItemMenu { text: "Desfazer"; atalho: "Ctrl+Z"; enabled: janela.atual && janela.atual.area.canUndo; onTriggered: janela.atual.area.undo() }
        ItemMenu { text: "Refazer"; atalho: "Ctrl+Y"; enabled: janela.atual && janela.atual.area.canRedo; onTriggered: janela.atual.area.redo() }
        MenuSeparator {}
        ItemMenu { text: "Recortar"; atalho: "Ctrl+X"; onTriggered: janela.atual.area.cut() }
        ItemMenu { text: "Copiar"; atalho: "Ctrl+C"; onTriggered: janela.atual.area.copy() }
        ItemMenu { text: "Colar"; atalho: "Ctrl+V"; onTriggered: janela.atual.area.paste() }
        MenuSeparator {}
        ItemMenu { text: "Procurar"; atalho: "Ctrl+F"; onTriggered: busca.abrir(false) }
        ItemMenu { text: "Substituir"; atalho: "Ctrl+H"; onTriggered: busca.abrir(true) }
        ItemMenu { text: "Ir para a linha…"; atalho: "Ctrl+G"; onTriggered: irLinha.abrir() }
        MenuSeparator {}
        ItemMenu { text: "Selecionar tudo"; atalho: "Ctrl+A"; onTriggered: janela.atual.area.selectAll() }
        ItemMenu { text: "Data e hora"; atalho: "F5"; onTriggered: janela.atual.area.insert(janela.atual.area.cursorPosition, notas.agora()) }
    }
    Menu {
        id: menuExibir
        ItemMenu { text: "Aumentar a letra"; atalho: "Ctrl+="; onTriggered: notas.definir("zoom", Math.min(500, janela.zoom + 10)) }
        ItemMenu { text: "Diminuir a letra"; atalho: "Ctrl+−"; onTriggered: notas.definir("zoom", Math.max(30, janela.zoom - 10)) }
        ItemMenu { text: "Tamanho normal"; atalho: "Ctrl+0"; onTriggered: notas.definir("zoom", 100) }
        MenuSeparator {}
        ItemMenu { text: "Quebra automática de linha"; checkable: true; checked: janela.quebra; onTriggered: notas.definir("quebra", !janela.quebra) }
        ItemMenu { text: "Barra de estado"; checkable: true; checked: janela.barraEstado; onTriggered: notas.definir("barraEstado", !janela.barraEstado) }
        MenuSeparator {}
        ItemMenu { text: "Letra de máquina (monoespaçada)"; checkable: true; checked: janela.fonte !== "Inter"; onTriggered: notas.definir("fonte", "") }
        ItemMenu { text: "Letra normal"; checkable: true; checked: janela.fonte === "Inter"; onTriggered: notas.definir("fonte", "Inter") }
    }
    Menu {
        id: menuFim
        Repeater {
            model: [["CRLF", "Windows (CRLF)"], ["LF", "Unix (LF)"], ["CR", "Mac (CR)"]]
            ItemMenu { text: modelData[1]; checkable: true; checked: janela.atual && janela.atual.fimLinha === modelData[0]
                       onTriggered: { janela.atual.fimLinha = modelData[0]; janela.atual.modificado = true; } }
        }
    }
    Menu {
        id: menuCod
        Repeater {
            model: ["UTF-8", "UTF-8 com BOM", "UTF-16", "ANSI"]
            ItemMenu { text: modelData; checkable: true; checked: janela.atual && janela.atual.codificacao === modelData
                       onTriggered: { janela.atual.codificacao = modelData; janela.atual.modificado = true; } }
        }
    }

    // ---- diálogos -------------------------------------------------------------------------------------
    Popup {
        id: perguntaFechar
        property int indice: -1
        anchors.centerIn: parent; width: 420; modal: true; padding: 22
        background: Rectangle { radius: 10; color: "#2b2a32"; border.color: Qt.rgba(1, 1, 1, 0.1) }
        ColumnLayout {
            anchors.fill: parent; spacing: 16
            Text { text: "Carinae Notas"; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap; color: janela.texto
                text: { const p = paineis.itemAt(perguntaFechar.indice); return "Quer salvar as alterações em \"" + (p ? p.titulo : "") + "\"?"; }
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                Botao { text: "Salvar"; highlighted: true
                         onClicked: { const p = paineis.itemAt(perguntaFechar.indice); perguntaFechar.close(); if (p) { janela.depoisDeGravar[p.ident] = "fechar"; janela.gravar(p, false); } } }
                Botao { text: "Não salvar"; onClicked: { perguntaFechar.close(); janela.fecharAba(perguntaFechar.indice, true); } }
                Botao { text: "Cancelar"; onClicked: perguntaFechar.close() }
            }
        }
    }
    Popup {
        id: irLinha
        anchors.centerIn: parent; width: 320; modal: true; padding: 20
        function abrir() { campoLinha.text = ""; open(); campoLinha.forceActiveFocus(); }
        background: Rectangle { radius: 10; color: "#2b2a32"; border.color: Qt.rgba(1, 1, 1, 0.1) }
        ColumnLayout {
            anchors.fill: parent; spacing: 12
            Text { text: "Ir para a linha"; color: janela.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
            Campo { id: campoLinha; Layout.fillWidth: true; onAccepted: okLinha.clicked()
                    validator: IntValidator { bottom: 1 } }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                Botao { text: "Cancelar"; onClicked: irLinha.close() }
                Botao {
                    id: okLinha; text: "Ir"; highlighted: true
                    onClicked: {
                        const a = janela.atual.area, n = parseInt(campoLinha.text) || 1;
                        let pos = 0;
                        for (let i = 1; i < n; i++) { const k = a.text.indexOf("\n", pos); if (k < 0) break; pos = k + 1; }
                        irLinha.close(); a.cursorPosition = pos; a.forceActiveFocus();
                    }
                }
            }
        }
    }

    component MenuTexto: Rectangle {
        id: mt
        property string texto
        property var menu
        implicitWidth: tx.implicitWidth + 22; implicitHeight: 28; radius: 6
        color: mmt.containsMouse || (menu && menu.visible) ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        Text { id: tx; anchors.centerIn: parent; text: mt.texto; color: janela.texto }
        MouseArea { id: mmt; anchors.fill: parent; hoverEnabled: true; onClicked: mt.menu.popup(mt, 0, mt.height) }
    }
    component Estado: Item {
        id: es
        property string texto
        property bool clicavel
        signal clicado()
        Layout.fillHeight: true
        implicitWidth: te.implicitWidth
        Rectangle { anchors.fill: parent; anchors.topMargin: 3; anchors.bottomMargin: 3; radius: 4; color: es.clicavel && me.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent" }
        Text { id: te; anchors.verticalCenter: parent.verticalCenter; x: 6; text: es.texto; color: janela.suave; font.pixelSize: 12 }
        MouseArea { id: me; anchors.fill: parent; hoverEnabled: true; enabled: es.clicavel; onClicked: es.clicado() }
    }
    component Campo: TextField {
        color: janela.texto; placeholderTextColor: janela.suave
        background: Rectangle { radius: 6; color: Qt.rgba(1, 1, 1, 0.06); border.color: parent.activeFocus ? janela.realce : Qt.rgba(1, 1, 1, 0.1) }
    }
    component Pequeno: Rectangle {
        id: pq
        property string glifo
        property string dica
        property bool ativo
        signal clicado()
        Layout.preferredWidth: 32; Layout.preferredHeight: 30; implicitWidth: 32; implicitHeight: 30; radius: 6
        color: ativo ? Qt.rgba(0.48, 0.65, 1, 0.22) : (mp.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
        Text { anchors.centerIn: parent; text: pq.glifo; color: janela.texto; font.pixelSize: 15 }
        MouseArea { id: mp; anchors.fill: parent; hoverEnabled: true; onClicked: pq.clicado() }
        ToolTip.visible: mp.containsMouse && dica !== ""; ToolTip.text: dica; ToolTip.delay: 500
    }
    component BotaoJanela: Rectangle {
        id: bj
        property string texto
        property bool perigo
        signal clicado()
        Layout.preferredWidth: 46; Layout.fillHeight: true
        color: mbj.containsMouse ? (perigo ? "#c42b1c" : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
        Text { anchors.centerIn: parent; text: bj.texto; color: janela.texto }
        MouseArea { id: mbj; anchors.fill: parent; hoverEnabled: true; onClicked: bj.clicado() }
    }

    component Botao: Rectangle {
        id: bt
        property string text
        property bool highlighted: false
        property bool flat: false
        signal clicked()
        implicitWidth: Math.max(84, tb.implicitWidth + 28); implicitHeight: 32; radius: 6
        opacity: enabled ? 1 : 0.45
        color: highlighted ? (mb.pressed ? Qt.darker("#7aa7ff", 1.1) : mb.containsMouse ? Qt.lighter("#7aa7ff", 1.08) : "#7aa7ff")
                           : (mb.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, flat ? 0 : 0.08))
        border.color: highlighted ? "transparent" : Qt.rgba(1, 1, 1, 0.08)
        Text { id: tb; anchors.centerIn: parent; text: bt.text; color: bt.highlighted ? "#10131c" : "#f2f0f6"; font.weight: Font.DemiBold }
        MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bt.clicked() }
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
