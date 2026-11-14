/*
    CarinaeOS — Launchpad
    Ecrã inteiro em vidro fosco sobre o papel de parede:
      · à esquerda, as vistas (Início, Todos, Favoritos, Mais usados, Deck) e as categorias;
      · ao centro, a pesquisa e o conteúdo — cartões das categorias no Início, ícones nas outras;
      · à direita, o detalhe do aplicativo (descrição, Abrir, ações rápidas, Dock e Deck).
    O Deck é uma grelha de botões grandes para ações rápidas (como um Stream Deck),
    que cada um monta a seu gosto (~/.config/carinaeos-deck.json).
    Abre com a estrela da Dock ou com a tecla Meta; fecha com Esc ou com um clique fora.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.plasma5support as P5Support

Kicker.DashboardWindow {
    id: lp

    required property var dock

    backgroundColor: "transparent"
    keyEventProxy: busca

    // ---- cores ----------------------------------------------------------------
    readonly property color texto: "#f6f2ff"
    readonly property color suave: Qt.rgba(0.93, 0.9, 1, 0.62)
    readonly property color realce1: "#5b7cff"
    readonly property color realce2: "#a35bff"
    readonly property var paleta: [
        ["#8a4dff", "#d06bff"], ["#2d6bff", "#4fc3ff"], ["#0f9d8a", "#3ee0b0"], ["#ff7a3d", "#ffc04d"],
        ["#ff4f8b", "#ff9bb8"], ["#4b3bd6", "#8a6bff"], ["#2fae55", "#9be06a"], ["#e5484d", "#ff8a65"],
        ["#0891b2", "#67e8f9"], ["#b45309", "#fbbf24"]
    ]

    // ---- estado -----------------------------------------------------------------
    property var itens: []            // todos: [{ nome, icone, linha, id, chave, desc, acoes, cat }]
    property var categorias: []       // [{ nome, icone, apps: [item...], cor }]
    property var usados: []           // chaves dos mais usados
    property var deck: []             // [{ nome, icone, cmd } | { app: chave }]
    property string vista: "inicio"   // inicio | todos | favoritos | usados | deck | cat
    property int catAtual: -1
    property string filtro: ""
    property var selecionado: null
    property var acoesSel: []
    onSelecionadoChanged: acoesSel = []
    property int indice: 0

    function alfa(c: var, a: real): color {
        const k = Qt.darker(c, 1.0);
        return Qt.rgba(k.r, k.g, k.b, a);
    }
    function semAcentos(t: string): string {
        return (t || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    }
    // "applications:firefox-esr.desktop" / "file:///.../firefox-esr.desktop" -> "firefox-esr.desktop"
    function chave(id: string): string {
        if (!id) return "";
        let c = String(id);
        if (c.startsWith("applications:")) c = c.substring(13);
        const b = c.lastIndexOf("/");
        if (b !== -1) c = c.substring(b + 1);
        return c;
    }
    function idLancador(c: string): string {
        return c === "" ? "" : "applications:" + c;
    }
    function porChave(c: string): var {
        for (let i = 0; i < itens.length; ++i) {
            if (itens[i].chave === c) return itens[i];
        }
        return null;
    }
    function naDock(app: var): bool {
        if (!app || app.chave === "") return false;
        const l = lp.dock.modelo.launcherList;
        for (let i = 0; i < l.length; ++i) {
            if (chave(l[i]) === app.chave) return true;
        }
        return false;
    }
    function alternarDock(app: var): void {
        if (!app) return;
        const l = lp.dock.modelo.launcherList;
        for (let i = 0; i < l.length; ++i) {
            if (chave(l[i]) === app.chave) {
                lp.dock.modelo.requestRemoveLauncher(l[i]);
                lp.selecionadoChanged();
                return;
            }
        }
        lp.dock.modelo.requestAddLauncher(idLancador(app.chave));
        lp.selecionadoChanged();
    }

    // ---- a lista que se vê agora ----------------------------------------------
    readonly property var lista: {
        if (filtro !== "") {
            const f = semAcentos(filtro);
            const a = [], b = [];
            for (const x of itens) {
                const n = semAcentos(x.nome);
                if (n.startsWith(f)) a.push(x);
                else if (n.indexOf(f) !== -1 || semAcentos(x.desc).indexOf(f) !== -1) b.push(x);
            }
            return a.concat(b);
        }
        if (vista === "todos") return itens;
        if (vista === "cat") return (categorias[catAtual] || { apps: [] }).apps;
        if (vista === "favoritos") {
            const l = lp.dock.modelo.launcherList, r = [];
            for (let i = 0; i < l.length; ++i) {
                const x = porChave(chave(l[i]));
                if (x) r.push(x);
            }
            return r;
        }
        if (vista === "usados") {
            const r = [];
            for (const c of usados) {
                const x = porChave(c);
                if (x) r.push(x);
            }
            return r;
        }
        return [];
    }
    readonly property bool emGrelha: filtro !== "" || (vista !== "inicio" && vista !== "deck")
    readonly property string titulo: filtro !== "" ? "Resultados"
        : vista === "inicio" ? saudacao()
        : vista === "todos" ? "Todos os aplicativos"
        : vista === "favoritos" ? "Favoritos"
        : vista === "usados" ? "Mais usados"
        : vista === "deck" ? "Deck"
        : (categorias[catAtual] || { nome: "" }).nome
    readonly property string subtitulo: filtro !== "" ? contagem(lista.length)
        : vista === "inicio" ? "As suas categorias, de um relance"
        : vista === "favoritos" ? "Os aplicativos que estão na Dock"
        : vista === "deck" ? "Ações rápidas num toque · botão direito para tirar"
        : contagem(lista.length)

    function contagem(n: int): string {
        return n === 1 ? "1 aplicativo" : n + " aplicativos";
    }
    function saudacao(): string {
        const h = new Date().getHours();
        return h < 6 ? "Boa noite" : h < 13 ? "Bom dia" : h < 20 ? "Boa tarde" : "Boa noite";
    }
    function mudarVista(v: string, c: int): void {
        busca.text = "";
        vista = v;
        catAtual = c === undefined ? -1 : c;
        indice = 0;
        selecionado = lista.length > 0 ? lista[0] : null;
        if (grelha) grelha.positionViewAtBeginning();
    }
    onListaChanged: {
        if (emGrelha) {
            indice = 0;
            selecionado = lista.length > 0 ? lista[0] : null;
        }
    }
    function mover(d: int): void {
        if (!emGrelha || lista.length === 0) return;
        indice = Math.max(0, Math.min(lista.length - 1, indice + d));
        selecionado = lista[indice];
        grelha.positionViewAtIndex(indice, GridView.Contain);
    }

    // ---- abrir -----------------------------------------------------------------
    function abrir(app: var): void {
        if (!app) return;
        if (todosModelo) todosModelo.trigger(app.linha, "", null);
        lp.toggle();
    }
    function acao(app: var, a: var): void {
        if (!app || !todosModelo) return;
        todosModelo.trigger(app.linha, a.actionId, a.actionArgument);
        lp.toggle();
    }
    function correr(cmd: string): void {
        executar.connectSource(cmd);
    }
    readonly property P5Support.DataSource executar: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => disconnectSource(fonte)
    }

    onKeyEscapePressed: {
        if (busca.text !== "") busca.text = "";
        else if (formDeck.visible) formDeck.visible = false;
        else lp.toggle();
    }

    // ---- modelos do Plasma -----------------------------------------------------
    property var todosModelo: null
    readonly property Kicker.RootModel raiz: Kicker.RootModel {
        autoPopulate: false
        appletInterface: lp.dock
        flat: true
        sorted: true
        showSeparators: false
        showAllApps: true
        showAllAppsCategorized: false
        showTopLevelItems: false
        showRecentApps: false
        showRecentDocs: false
        onRefreshed: {
            lp.todosModelo = lp.raiz.modelForRow(0);
            recolha.model = lp.todosModelo;
            recolhaCat.model = lp.raiz;
        }
        Component.onCompleted: refresh()
    }
    // os mais usados (criado à parte: se a versão do Plasma não o tiver, o resto funciona)
    property var usadosModelo: null
    Component.onCompleted: {
        try {
            usadosModelo = Qt.createQmlObject(
                'import org.kde.plasma.private.kicker as K; K.RecentUsageModel { shownItems: K.RecentUsageModel.OnlyApps; ordering: 1 }', lp, "usados");
        } catch (e) {
            console.log("CarinaeOS Launchpad: sem RecentUsageModel", e);
        }
    }

    // ---- fundo: o papel de parede atual --------------------------------------------
    property string fundoAtual: ""
    readonly property P5Support.DataSource lerFundo: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            let f = (dados["stdout"] || "").trim();
            if (f === "") return;
            if (!f.startsWith("file:")) f = "file://" + f;
            lp.fundoAtual = f;
        }
    }

    // ---- Deck: ler e gravar ~/.config/carinaeos-deck.json -------------------------
    readonly property var deckPadrao: [
        { nome: "Captura de ecrã", icone: "spectacle", cmd: "spectacle" },
        { nome: "Terminal", icone: "utilities-terminal", cmd: "konsole" },
        { nome: "Transferências", icone: "folder-download", cmd: "sh -c 'xdg-open \"$(xdg-user-dir DOWNLOAD)\"'" },
        { nome: "Monitor do sistema", icone: "utilities-system-monitor", cmd: "plasma-systemmonitor" },
        { nome: "Todas as janelas", icone: "view-grid", cmd: "qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut Overview" },
        { nome: "Mostrar a mesa", icone: "user-desktop", cmd: "qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut 'Show Desktop'" },
        { nome: "Central", icone: "carinaeos-central", cmd: "carinaeos-central" },
        { nome: "Supernova", icone: "carinaeos-supernova", cmd: "carinaeos-supernova" },
        { nome: "Manual", icone: "help-contents", cmd: "carinaeos-manual" },
        { nome: "Configurações", icone: "preferences-system", cmd: "carinaeos-configuracoes" },
        { nome: "Bloquear", icone: "system-lock-screen", cmd: "loginctl lock-session" },
        { nome: "Suspender", icone: "system-suspend", cmd: "systemctl suspend" }
    ]
    readonly property P5Support.DataSource lerDeck: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            const t = (dados["stdout"] || "").trim();
            let d = null;
            try { d = JSON.parse(t); } catch (e) { d = null; }
            lp.deck = Array.isArray(d) ? d : lp.deckPadrao;
        }
    }
    function gravarDeck(): void {
        // JSON só com ASCII (os acentos vão como \uXXXX) para passar por base64 sem estragos
        const j = JSON.stringify(deck).replace(/[\u0080-￿]/g,
            c => "\\u" + ("0000" + c.charCodeAt(0).toString(16)).slice(-4));
        correr("sh -c 'mkdir -p \"$HOME/.config\" && echo " + Qt.btoa(j)
               + " | base64 -d > \"$HOME/.config/carinaeos-deck.json\"'");
    }
    function noDeck(app: var): bool {
        if (!app) return false;
        for (const t of deck) if (t.app === app.chave) return true;
        return false;
    }
    function adicionarAoDeck(app: var): void {
        if (!app || noDeck(app)) return;
        deck = deck.concat([{ app: app.chave }]);
        gravarDeck();
    }
    function tirarDoDeck(i: int): void {
        const d = deck.slice();
        d.splice(i, 1);
        deck = d;
        gravarDeck();
    }
    function tocarDeck(t: var): void {
        if (t.app) {
            abrir(porChave(t.app));
            return;
        }
        let c = t.cmd || "";
        if (/^(https?:\/\/|www\.)/.test(c)) {
            c = "xdg-open '" + (c.startsWith("www.") ? "https://" + c : c).replace(/'/g, "") + "'";
        }
        correr(c);
        lp.toggle();
    }

    onVisibleChanged: {
        if (visible) {
            lp.lerFundo.connectSource("f=$(grep -A4 '\\[Wallpaper\\]\\[org.kde.image\\]\\[General\\]' \"$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc\" | sed -n 's/^Image=//p' | head -1); "
                + "f=${f#file://}; if [ -d \"$f\" ]; then ls -S \"$f\"/contents/images/* 2>/dev/null | tail -1; else echo \"$f\"; fi #" + Date.now());
            lp.lerDeck.connectSource("cat \"$HOME/.config/carinaeos-deck.json\" 2>/dev/null #" + Date.now());
            busca.text = "";
            formDeck.visible = false;
            vista = "inicio";
            busca.forceActiveFocus();
            entrada.restart();
            juntarUsados.restart();
        } else {
            selecionado = null;
        }
    }

    mainItem: Item {
        id: palco
        anchors.fill: parent

        readonly property real u: Math.max(0.8, Math.min(1.35, height / 900))   // escala
        readonly property int m: Math.round(26 * u)
        readonly property int folga: Math.round(16 * u)
        readonly property bool comDetalhe: width >= 1180
        readonly property int larguraLado: Math.round(Math.max(220, Math.min(300, width * 0.17)))
        readonly property int larguraDetalhe: comDetalhe ? Math.round(Math.max(260, Math.min(350, width * 0.2))) : 0

        // ---- recolha dos dados dos modelos (invisível) ---------------------------
        Item {
            visible: false
            Repeater {
                id: recolha
                onCountChanged: juntar.restart()
                delegate: Item {
                    id: umApp
                    required property int index
                    required property var model
                    readonly property var dados: ({
                        nome: model.display || "", icone: model.decoration, linha: index,
                        chave: lp.chave(model.favoriteId || ""), desc: model.description || ""
                    })
                    // as ações rápidas só se leem para o aplicativo escolhido (ler as de todos de uma vez
                    // no arranque é pesado e pode derrubar o Plasma)
                    readonly property bool escolhido: lp.visible && lp.selecionado !== null && lp.selecionado.linha === index
                    onEscolhidoChanged: if (escolhido) lerAcoes.restart()
                    Timer {
                        id: lerAcoes
                        interval: 120
                        onTriggered: {
                            const l = umApp.model.hasActionList ? (umApp.model.actionList || []) : [];
                            lp.acoesSel = l.filter(a => a && a.actionId === "_kicker_jumpListAction");
                        }
                    }
                }
            }
            Repeater {
                id: recolhaCat
                onCountChanged: juntar.restart()
                delegate: Item {
                    id: cat
                    required property int index
                    required property var model
                    readonly property string nome: model.display || ""
                    readonly property var icone: model.decoration
                    property var chaves: []
                    Repeater {
                        id: apps
                        model: cat.index > 0 ? lp.raiz.modelForRow(cat.index) : null
                        onCountChanged: juntar.restart()
                        delegate: Item {
                            required property var model
                            readonly property string chave: lp.chave(model.favoriteId || "")
                        }
                    }
                    function recolher(): var {
                        const r = [];
                        for (let i = 0; i < apps.count; ++i) {
                            const it = apps.itemAt(i);
                            if (it && it.chave !== "") r.push(it.chave);
                        }
                        return r;
                    }
                }
            }
            Repeater {
                id: recolhaUsados
                model: lp.usadosModelo
                onCountChanged: juntarUsados.restart()
                delegate: Item {
                    required property var model
                    readonly property string chave: lp.chave(model.favoriteId || model.url || "")
                }
            }
            Timer {
                id: juntarUsados
                interval: 80
                onTriggered: {
                    const r = [];
                    for (let i = 0; i < recolhaUsados.count && r.length < 24; ++i) {
                        const it = recolhaUsados.itemAt(i);
                        if (it && it.chave.endsWith(".desktop")) r.push(it.chave);
                    }
                    lp.usados = r;
                }
            }
            Timer {
                id: juntar
                interval: 60
                onTriggered: {
                    const l = [], mapa = {};
                    for (let i = 0; i < recolha.count; ++i) {
                        const it = recolha.itemAt(i);
                        if (it && it.dados.nome) {
                            const d = Object.assign({ cat: "" }, it.dados);
                            l.push(d);
                            if (d.chave) mapa[d.chave] = d;
                        }
                    }
                    const cs = [];
                    for (let i = 1; i < recolhaCat.count; ++i) {
                        const c = recolhaCat.itemAt(i);
                        if (!c || c.nome === "") continue;
                        const apps = [];
                        for (const k of c.recolher()) {
                            const a = mapa[k];
                            if (a) {
                                apps.push(a);
                                if (a.cat === "") a.cat = c.nome;
                            }
                        }
                        if (apps.length > 0) {
                            cs.push({ nome: c.nome, icone: c.icone, apps: apps, cor: lp.paleta[cs.length % lp.paleta.length] });
                        }
                    }
                    lp.itens = l;
                    lp.categorias = cs;
                    if (!lp.selecionado && l.length > 0) lp.selecionado = l[0];
                }
            }
        }

        // ---- fundo -----------------------------------------------------------------
        Image {
            id: fundo
            anchors.fill: parent
            source: lp.fundoAtual !== "" ? lp.fundoAtual : "file:///usr/share/wallpapers/CarinaeOS/contents/images/1920x1080.jpg"
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 1920
            asynchronous: true
            visible: false
        }
        // muito desfocado: é o que se vê através do vidro dos painéis
        MultiEffect {
            id: fundoForte
            anchors.fill: parent
            source: fundo
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 1.0
            brightness: -0.08
            saturation: 0.25
        }
        // por cima, o papel de parede quase nítido (nota-se a paisagem entre os painéis)
        MultiEffect {
            anchors.fill: parent
            source: fundo
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 24
            blur: 0.5
            brightness: -0.16
            opacity: conteudo.opacity
        }
        Rectangle {   // véu escuro em baixo, para ler os nomes
            anchors.fill: parent
            opacity: conteudo.opacity
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0.04, 0.02, 0.1, 0.18) }
                GradientStop { position: 1; color: Qt.rgba(0.04, 0.02, 0.1, 0.42) }
            }
        }

        // clique fora dos painéis fecha
        MouseArea {
            anchors.fill: parent
            onClicked: lp.toggle()
        }

        // menu do botão direito de um aplicativo
        QQC2.Menu {
            id: menuApp
            property var app: null
            QQC2.MenuItem { text: "Abrir"; onTriggered: lp.abrir(menuApp.app) }
            QQC2.MenuItem {
                text: lp.naDock(menuApp.app) ? "Remover da Dock" : "Adicionar à Dock"
                enabled: menuApp.app !== null && menuApp.app.chave !== ""
                onTriggered: lp.alternarDock(menuApp.app)
            }
            QQC2.MenuItem {
                text: "Adicionar ao Deck"
                enabled: menuApp.app !== null && !lp.noDeck(menuApp.app)
                onTriggered: lp.adicionarAoDeck(menuApp.app)
            }
        }
        QQC2.Menu {
            id: menuDeck
            property int i: -1
            QQC2.MenuItem { text: "Tirar do Deck"; onTriggered: lp.tirarDoDeck(menuDeck.i) }
            QQC2.MenuItem { text: "Repor o Deck original"; onTriggered: { lp.deck = lp.deckPadrao; lp.gravarDeck(); } }
        }

        // ---- painel de vidro --------------------------------------------------------
        // tem de ser filho direto de "conteudo" (que cobre o ecrã todo, em 0,0)
        component Vidro: Item {
            id: v
            property real u: 1
            property Item fonte: null
            property real raio: 22 * v.u
            property real tinta: 0.40
            ShaderEffectSource {
                id: pedaco
                anchors.fill: parent
                sourceItem: v.fonte
                sourceRect: Qt.rect(v.x, v.y, v.width, v.height)
                visible: false
            }
            Rectangle {
                id: forma
                anchors.fill: parent
                radius: v.raio
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                anchors.fill: parent
                source: pedaco
                maskEnabled: true
                maskSource: forma
            }
            Rectangle {
                anchors.fill: parent
                radius: v.raio
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.10) }
                    GradientStop { position: 0.35; color: Qt.rgba(0.10, 0.08, 0.22, v.tinta) }
                    GradientStop { position: 1; color: Qt.rgba(0.06, 0.04, 0.16, v.tinta + 0.08) }
                }
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.16)
            }
            MouseArea { anchors.fill: parent }   // cliques no vidro não fecham
        }

        // item da barra lateral
        component ItemLado: Rectangle {
            id: il
            property real u: 1
            property string texto: ""
            property var icone: ""
            property string numero: ""
            property bool ativo: false
            signal escolhido()
            width: parent ? parent.width : 0
            height: Math.round(38 * il.u)
            radius: height * 0.32
            color: ativo ? "transparent" : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
            gradient: ativo ? grad : null
            Gradient {
                id: grad
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(0.36, 0.49, 1, 0.55) }
                GradientStop { position: 1; color: Qt.rgba(0.64, 0.36, 1, 0.40) }
            }
            border.width: ativo ? 1 : 0
            border.color: Qt.rgba(1, 1, 1, 0.22)
            Kirigami.Icon {
                id: ic
                source: il.icone
                width: Math.round(20 * il.u)
                height: width
                anchors.verticalCenter: parent.verticalCenter
                x: Math.round(12 * il.u)
            }
            Text {
                anchors.left: ic.right
                anchors.leftMargin: Math.round(10 * il.u)
                anchors.right: num.left
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: il.texto
                color: "#f6f2ff"
                elide: Text.ElideRight
                font.pixelSize: Math.round(14 * il.u)
                font.weight: il.ativo ? Font.DemiBold : Font.Normal
            }
            Text {
                id: num
                anchors.right: parent.right
                anchors.rightMargin: Math.round(12 * il.u)
                anchors.verticalCenter: parent.verticalCenter
                text: il.numero
                color: Qt.rgba(0.93, 0.9, 1, 0.62)
                font.pixelSize: Math.round(12 * il.u)
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: il.escolhido()
            }
        }

        // botão redondo pequeno (desligar, etc.)
        component BotaoRedondo: Rectangle {
            id: br
            property real u: 1
            property string icone: ""
            property string dica: ""
            signal carregado()
            width: Math.round(36 * br.u)
            height: width
            radius: width / 2
            color: mb.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.07)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.12)
            Kirigami.Icon { anchors.centerIn: parent; source: br.icone; width: parent.width * 0.5; height: width; color: "white"; isMask: true }
            MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: br.carregado() }
            QQC2.ToolTip.visible: mb.containsMouse && dica !== ""
            QQC2.ToolTip.text: dica
            QQC2.ToolTip.delay: 500
        }

        Item {
            id: conteudo
            anchors.fill: parent
            opacity: 0
            NumberAnimation { id: entrada; target: conteudo; property: "opacity"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }

            // ================= barra lateral =================================================
            Vidro {
                fonte: fundoForte
                u: palco.u
                id: lado
                x: palco.m
                y: palco.m
                width: palco.larguraLado
                height: palco.height - palco.m * 2
            }
            Item {
                anchors.fill: lado
                anchors.margins: Math.round(14 * palco.u)

                Row {
                    id: marca
                    spacing: Math.round(10 * palco.u)
                    x: Math.round(6 * palco.u)
                    y: Math.round(4 * palco.u)
                    Kirigami.Icon { source: "carinaeos-estrela"; width: Math.round(28 * palco.u); height: width }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "CarinaeOS"
                        color: lp.texto
                        font.pixelSize: Math.round(19 * palco.u)
                        font.weight: Font.DemiBold
                    }
                }

                Flickable {
                    anchors.top: marca.bottom
                    anchors.topMargin: Math.round(18 * palco.u)
                    anchors.bottom: energia.top
                    anchors.bottomMargin: Math.round(10 * palco.u)
                    width: parent.width
                    contentHeight: colLado.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: colLado
                        width: parent.width
                        spacing: Math.round(3 * palco.u)

                        ItemLado { u: palco.u; texto: "Início"; icone: "go-home"; ativo: lp.filtro === "" && lp.vista === "inicio"; onEscolhido: lp.mudarVista("inicio") }
                        ItemLado { u: palco.u; texto: "Todos os aplicativos"; icone: "view-app-grid"; numero: String(lp.itens.length); ativo: lp.filtro === "" && lp.vista === "todos"; onEscolhido: lp.mudarVista("todos") }
                        ItemLado { u: palco.u; texto: "Favoritos"; icone: "starred-symbolic"; numero: String(lp.dock.modelo.launcherList.length); ativo: lp.filtro === "" && lp.vista === "favoritos"; onEscolhido: lp.mudarVista("favoritos") }
                        ItemLado { u: palco.u; texto: "Mais usados"; icone: "office-chart-line"; visible: lp.usadosModelo !== null; ativo: lp.filtro === "" && lp.vista === "usados"; onEscolhido: lp.mudarVista("usados") }
                        ItemLado { u: palco.u; texto: "Deck"; icone: "view-grid-symbolic"; numero: String(lp.deck.length); ativo: lp.filtro === "" && lp.vista === "deck"; onEscolhido: lp.mudarVista("deck") }

                        Text {
                            text: "CATEGORIAS"
                            color: lp.suave
                            font.pixelSize: Math.round(11 * palco.u)
                            font.letterSpacing: 1.2
                            topPadding: Math.round(16 * palco.u)
                            bottomPadding: Math.round(6 * palco.u)
                            leftPadding: Math.round(12 * palco.u)
                        }
                        Repeater {
                            model: lp.categorias
                            delegate: ItemLado {
                                u: palco.u
                                required property var modelData
                                required property int index
                                texto: modelData.nome
                                icone: modelData.icone
                                numero: String(modelData.apps.length)
                                ativo: lp.filtro === "" && lp.vista === "cat" && lp.catAtual === index
                                onEscolhido: lp.mudarVista("cat", index)
                            }
                        }
                    }
                }

                Row {
                    id: energia
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(10 * palco.u)
                    BotaoRedondo { u: palco.u; icone: "system-lock-screen"; dica: "Bloquear"; onCarregado: { lp.correr("loginctl lock-session"); lp.toggle(); } }
                    BotaoRedondo { u: palco.u; icone: "system-suspend"; dica: "Suspender"; onCarregado: { lp.correr("systemctl suspend"); lp.toggle(); } }
                    BotaoRedondo { u: palco.u; icone: "system-reboot"; dica: "Reiniciar…"; onCarregado: { lp.correr("qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptReboot"); lp.toggle(); } }
                    BotaoRedondo { u: palco.u; icone: "system-shutdown"; dica: "Desligar…"; onCarregado: { lp.correr("qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptShutDown"); lp.toggle(); } }
                }
            }

            // ================= centro =========================================================
            Vidro {
                fonte: fundoForte
                u: palco.u
                id: centro
                x: lado.x + lado.width + palco.folga
                y: palco.m
                width: palco.width - x - palco.m - (palco.comDetalhe ? palco.larguraDetalhe + palco.folga : 0)
                height: palco.height - palco.m * 2
                tinta: 0.30
            }
            Item {
                id: dentro
                anchors.fill: centro
                anchors.margins: Math.round(22 * palco.u)

                // pesquisa
                Rectangle {
                    id: caixaBusca
                    width: parent.width
                    height: Math.round(48 * palco.u)
                    radius: height * 0.32
                    color: Qt.rgba(1, 1, 1, busca.activeFocus ? 0.13 : 0.09)
                    border.width: 1
                    border.color: busca.activeFocus ? Qt.rgba(0.5, 0.6, 1, 0.65) : Qt.rgba(1, 1, 1, 0.18)
                    Kirigami.Icon {
                        id: lupa
                        source: "search"
                        color: "white"
                        isMask: true
                        width: Math.round(20 * palco.u)
                        height: width
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.round(16 * palco.u)
                        opacity: 0.8
                    }
                    QQC2.TextField {
                        id: busca
                        anchors.left: lupa.right
                        anchors.leftMargin: Math.round(10 * palco.u)
                        anchors.right: dicaTecla.left
                        anchors.verticalCenter: parent.verticalCenter
                        placeholderText: "Pesquisar aplicativos…"
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.55)
                        color: "white"
                        font.pixelSize: Math.round(17 * palco.u)
                        background: Item {}
                        focus: true
                        onTextChanged: lp.filtro = text
                        onAccepted: {
                            if (lp.emGrelha && lp.selecionado) lp.abrir(lp.selecionado);
                            else if (lp.lista.length > 0) lp.abrir(lp.lista[0]);
                        }
                        Keys.onDownPressed: lp.mover(grelha.colunas)
                        Keys.onUpPressed: lp.mover(-grelha.colunas)
                        Keys.onRightPressed: event => { if (text === "" || cursorPosition === text.length) lp.mover(1); else event.accepted = false; }
                        Keys.onLeftPressed: event => { if (text === "") lp.mover(-1); else event.accepted = false; }
                    }
                    Text {
                        id: dicaTecla
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(16 * palco.u)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Ctrl+Espaço: Comando"
                        color: lp.suave
                        font.pixelSize: Math.round(12 * palco.u)
                        visible: centro.width > 700
                    }
                }

                // título da vista
                Column {
                    id: cabecalho
                    anchors.top: caixaBusca.bottom
                    anchors.topMargin: Math.round(20 * palco.u)
                    spacing: 2
                    Text {
                        text: lp.titulo
                        color: lp.texto
                        font.pixelSize: Math.round(28 * palco.u)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: lp.subtitulo
                        color: lp.suave
                        font.pixelSize: Math.round(13 * palco.u)
                    }
                }

                Item {
                    id: area
                    anchors.top: cabecalho.bottom
                    anchors.topMargin: Math.round(16 * palco.u)
                    anchors.bottom: parent.bottom
                    width: parent.width

                    // ---- grelha de ícones -----------------------------------------------
                    GridView {
                        id: grelha
                        anchors.fill: parent
                        visible: lp.emGrelha
                        clip: true
                        readonly property int colunas: Math.max(3, Math.floor(width / Math.round(150 * palco.u)))
                        cellWidth: Math.floor(width / colunas)
                        cellHeight: Math.round(138 * palco.u)
                        model: lp.emGrelha ? lp.lista : []
                        boundsBehavior: Flickable.StopAtBounds
                        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                        delegate: Item {
                            id: celula
                            required property var modelData
                            required property int index
                            width: grelha.cellWidth
                            height: grelha.cellHeight
                            readonly property bool escolhida: lp.selecionado === modelData

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: Math.round(5 * palco.u)
                                radius: Math.round(18 * palco.u)
                                color: celula.escolhida ? Qt.rgba(1, 1, 1, 0.13) : (rato.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent")
                                border.width: celula.escolhida ? 1 : 0
                                border.color: Qt.rgba(0.6, 0.65, 1, 0.5)
                            }
                            Kirigami.Icon {
                                id: icone
                                source: celula.modelData.icone
                                width: Math.round(72 * palco.u)
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: Math.round(16 * palco.u)
                                scale: rato.pressed ? 0.92 : (rato.containsMouse ? 1.07 : 1)
                                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            }
                            Text {
                                anchors.top: icone.bottom
                                anchors.topMargin: Math.round(8 * palco.u)
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - Math.round(14 * palco.u)
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: celula.modelData.nome
                                color: lp.texto
                                font.pixelSize: Math.round(13 * palco.u)
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.35)
                            }
                            Timer {
                                id: pairar
                                interval: 160
                                onTriggered: { lp.selecionado = celula.modelData; lp.indice = celula.index; }
                            }
                            MouseArea {
                                id: rato
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onContainsMouseChanged: if (containsMouse) pairar.restart(); else pairar.stop()
                                onClicked: ev => {
                                    if (ev.button === Qt.RightButton) {
                                        lp.selecionado = celula.modelData;
                                        menuApp.app = celula.modelData;
                                        menuApp.popup();
                                    } else {
                                        lp.abrir(celula.modelData);
                                    }
                                }
                                onPressAndHold: { menuApp.app = celula.modelData; menuApp.popup(); }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: grelha.count === 0
                            text: lp.filtro !== "" ? "Nenhum aplicativo encontrado"
                                : lp.vista === "usados" ? "Ainda não há aplicativos usados" : "Nada aqui ainda"
                            color: lp.suave
                            font.pixelSize: Math.round(16 * palco.u)
                        }
                    }

                    // ---- Início: recentes e cartões das categorias ----------------------
                    Flickable {
                        id: inicio
                        anchors.fill: parent
                        visible: !lp.emGrelha && lp.vista === "inicio"
                        clip: true
                        contentHeight: colInicio.height
                        boundsBehavior: Flickable.StopAtBounds
                        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}

                        Column {
                            id: colInicio
                            width: inicio.width
                            spacing: Math.round(18 * palco.u)

                            // usados recentemente
                            Row {
                                visible: lp.usados.length > 0
                                spacing: Math.round(8 * palco.u)
                                Repeater {
                                    model: {
                                        const r = [];
                                        for (const c of lp.usados) {
                                            const x = lp.porChave(c);
                                            if (x) r.push(x);
                                            if (r.length >= Math.floor(inicio.width / Math.round(96 * palco.u))) break;
                                        }
                                        return r;
                                    }
                                    delegate: Rectangle {
                                        id: rec
                                        required property var modelData
                                        width: Math.round(88 * palco.u)
                                        height: Math.round(92 * palco.u)
                                        radius: Math.round(16 * palco.u)
                                        color: mr.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05)
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.10)
                                        Kirigami.Icon {
                                            source: rec.modelData.icone
                                            width: Math.round(46 * palco.u); height: width
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: Math.round(12 * palco.u)
                                        }
                                        Text {
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: Math.round(9 * palco.u)
                                            width: parent.width - 10
                                            x: 5
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            text: rec.modelData.nome
                                            color: lp.texto
                                            font.pixelSize: Math.round(11 * palco.u)
                                        }
                                        MouseArea {
                                            id: mr
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onContainsMouseChanged: if (containsMouse) lp.selecionado = rec.modelData
                                            onClicked: lp.abrir(rec.modelData)
                                        }
                                    }
                                }
                            }

                            // cartões
                            Grid {
                                id: cartoes
                                width: parent.width
                                readonly property int colunas: width >= 900 * palco.u ? 3 : 2
                                columns: colunas
                                spacing: Math.round(14 * palco.u)
                                readonly property real lc: (width - spacing * (colunas - 1)) / colunas
                                Repeater {
                                    model: lp.categorias
                                    delegate: Item {
                                        id: cartao
                                        required property var modelData
                                        required property int index
                                        width: cartoes.lc
                                        height: Math.round(178 * palco.u)
                                        scale: mc.containsMouse ? 1.015 : 1
                                        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                                        Rectangle {
                                            id: corpo
                                            anchors.fill: parent
                                            radius: Math.round(22 * palco.u)
                                            clip: true
                                            gradient: Gradient {
                                                orientation: Gradient.Horizontal
                                                GradientStop { position: 0; color: lp.alfa(cartao.modelData.cor[0], 0.62) }
                                                GradientStop { position: 1; color: lp.alfa(cartao.modelData.cor[1], 0.30) }
                                            }
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, mc.containsMouse ? 0.38 : 0.20)
                                            // a "ilustração": o ícone da categoria grande e esbatido
                                            Kirigami.Icon {
                                                source: cartao.modelData.icone
                                                width: parent.height * 0.95
                                                height: width
                                                anchors.right: parent.right
                                                anchors.rightMargin: -parent.height * 0.12
                                                anchors.verticalCenter: parent.verticalCenter
                                                opacity: 0.16
                                            }
                                        }
                                        MouseArea {
                                            id: mc
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: lp.mudarVista("cat", cartao.index)
                                        }
                                        Rectangle {
                                            id: selo
                                            x: Math.round(16 * palco.u)
                                            y: Math.round(16 * palco.u)
                                            width: Math.round(44 * palco.u)
                                            height: width
                                            radius: width * 0.3
                                            gradient: Gradient {
                                                GradientStop { position: 0; color: cartao.modelData.cor[1] }
                                                GradientStop { position: 1; color: cartao.modelData.cor[0] }
                                            }
                                            Kirigami.Icon {
                                                anchors.centerIn: parent
                                                source: cartao.modelData.icone
                                                width: parent.width * 0.58
                                                height: width
                                                color: "white"
                                                isMask: true
                                            }
                                        }
                                        Column {
                                            anchors.left: selo.right
                                            anchors.leftMargin: Math.round(12 * palco.u)
                                            anchors.right: seta.left
                                            anchors.verticalCenter: selo.verticalCenter
                                            Text {
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: cartao.modelData.nome
                                                color: "white"
                                                font.pixelSize: Math.round(18 * palco.u)
                                                font.weight: Font.DemiBold
                                            }
                                            Text {
                                                width: parent.width
                                                elide: Text.ElideRight
                                                text: lp.lema(cartao.modelData.nome, cartao.modelData.apps.length)
                                                color: Qt.rgba(1, 1, 1, 0.75)
                                                font.pixelSize: Math.round(12 * palco.u)
                                            }
                                        }
                                        Rectangle {
                                            id: seta
                                            anchors.right: parent.right
                                            anchors.rightMargin: Math.round(14 * palco.u)
                                            anchors.verticalCenter: selo.verticalCenter
                                            width: Math.round(28 * palco.u)
                                            height: width
                                            radius: width / 2
                                            color: Qt.rgba(1, 1, 1, mc.containsMouse ? 0.28 : 0.14)
                                            Kirigami.Icon { anchors.centerIn: parent; source: "go-next"; width: parent.width * 0.55; height: width; color: "white"; isMask: true }
                                        }
                                        // até 4 aplicativos da categoria
                                        Row {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Math.round(14 * palco.u)
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: Math.round(12 * palco.u)
                                            spacing: Math.round(4 * palco.u)
                                            Repeater {
                                                model: cartao.modelData.apps.slice(0, Math.max(1, Math.min(4, Math.floor((cartao.width - 40) / Math.round(76 * palco.u)))))
                                                delegate: Item {
                                                    id: mini
                                                    required property var modelData
                                                    width: Math.round(72 * palco.u)
                                                    height: Math.round(78 * palco.u)
                                                    Rectangle {
                                                        anchors.fill: parent
                                                        radius: Math.round(14 * palco.u)
                                                        color: Qt.rgba(1, 1, 1, mm.containsMouse ? 0.20 : 0)
                                                    }
                                                    Kirigami.Icon {
                                                        source: mini.modelData.icone
                                                        width: Math.round(40 * palco.u)
                                                        height: width
                                                        anchors.horizontalCenter: parent.horizontalCenter
                                                        y: Math.round(8 * palco.u)
                                                    }
                                                    Text {
                                                        anchors.bottom: parent.bottom
                                                        anchors.bottomMargin: Math.round(6 * palco.u)
                                                        width: parent.width - 6
                                                        x: 3
                                                        horizontalAlignment: Text.AlignHCenter
                                                        elide: Text.ElideRight
                                                        text: mini.modelData.nome
                                                        color: "white"
                                                        font.pixelSize: Math.round(11 * palco.u)
                                                    }
                                                    MouseArea {
                                                        id: mm
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onContainsMouseChanged: if (containsMouse) lp.selecionado = mini.modelData
                                                        onClicked: lp.abrir(mini.modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ---- Deck -----------------------------------------------------------
                    GridView {
                        id: grelhaDeck
                        anchors.fill: parent
                        visible: !lp.emGrelha && lp.vista === "deck"
                        clip: true
                        readonly property int colunas: Math.max(3, Math.floor(width / Math.round(180 * palco.u)))
                        cellWidth: Math.floor(width / colunas)
                        cellHeight: Math.round(150 * palco.u)
                        model: lp.deck.length + 1
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Item {
                            id: tecla
                            required property int index
                            readonly property bool mais: index === lp.deck.length
                            readonly property var dado: mais ? null : lp.deck[index]
                            readonly property var app: dado && dado.app ? lp.porChave(dado.app) : null
                            readonly property var cor: lp.paleta[(index * 3) % lp.paleta.length]
                            width: grelhaDeck.cellWidth
                            height: grelhaDeck.cellHeight

                            Rectangle {
                                id: corpoTecla
                                anchors.fill: parent
                                anchors.margins: Math.round(8 * palco.u)
                                radius: Math.round(24 * palco.u)
                                scale: mt.pressed ? 0.94 : (mt.containsMouse ? 1.04 : 1)
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                gradient: Gradient {
                                    GradientStop { position: 0; color: tecla.mais ? Qt.rgba(1, 1, 1, 0.06) : lp.alfa(tecla.cor[1], 0.85) }
                                    GradientStop { position: 1; color: tecla.mais ? Qt.rgba(1, 1, 1, 0.03) : lp.alfa(tecla.cor[0], 0.85) }
                                }
                                border.width: 1
                                border.color: tecla.mais ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(1, 1, 1, 0.30)
                                // brilho de vidro na metade de cima
                                Rectangle {
                                    visible: !tecla.mais
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 1
                                    height: parent.height * 0.48
                                    radius: parent.radius
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.22) }
                                        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                                    }
                                }
                                Kirigami.Icon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: parent.height * 0.17
                                    width: Math.round(52 * palco.u)
                                    height: width
                                    source: tecla.mais ? "list-add" : (tecla.app ? tecla.app.icone : (tecla.dado ? tecla.dado.icone : ""))
                                    color: "white"
                                    isMask: tecla.mais
                                }
                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: parent.height * 0.13
                                    width: parent.width - 16
                                    x: 8
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: tecla.mais ? "Adicionar" : (tecla.app ? tecla.app.nome : (tecla.dado ? tecla.dado.nome : ""))
                                    color: "white"
                                    font.pixelSize: Math.round(14 * palco.u)
                                    font.weight: Font.DemiBold
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.25)
                                }
                            }
                            MouseArea {
                                id: mt
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: ev => {
                                    if (tecla.mais) {
                                        formDeck.abrir();
                                    } else if (ev.button === Qt.RightButton) {
                                        menuDeck.i = tecla.index;
                                        menuDeck.popup();
                                    } else {
                                        lp.tocarDeck(tecla.dado);
                                    }
                                }
                                onPressAndHold: if (!tecla.mais) { menuDeck.i = tecla.index; menuDeck.popup(); }
                            }
                        }
                    }

                    // formulário: novo botão do Deck
                    Rectangle {
                        id: formDeck
                        visible: false
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 40, Math.round(460 * palco.u))
                        height: colForm.height + Math.round(40 * palco.u)
                        radius: Math.round(22 * palco.u)
                        color: Qt.rgba(0.09, 0.07, 0.2, 0.96)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                        function abrir(): void {
                            nomeDeck.text = "";
                            cmdDeck.text = "";
                            visible = true;
                            nomeDeck.forceActiveFocus();
                        }
                        function guardar(): void {
                            if (cmdDeck.text.trim() === "") return;
                            const site = /^(https?:\/\/|www\.)/.test(cmdDeck.text.trim());
                            lp.deck = lp.deck.concat([{ nome: nomeDeck.text.trim() || cmdDeck.text.trim(),
                                                        icone: site ? "internet-web-browser" : "system-run",
                                                        cmd: cmdDeck.text.trim() }]);
                            lp.gravarDeck();
                            visible = false;
                            busca.forceActiveFocus();
                        }
                        MouseArea { anchors.fill: parent }
                        Column {
                            id: colForm
                            x: Math.round(20 * palco.u)
                            y: Math.round(20 * palco.u)
                            width: parent.width - Math.round(40 * palco.u)
                            spacing: Math.round(10 * palco.u)
                            Text { text: "Novo botão do Deck"; color: lp.texto; font.pixelSize: Math.round(18 * palco.u); font.weight: Font.DemiBold }
                            Text {
                                width: parent.width
                                wrapMode: Text.Wrap
                                text: "Um comando (ex.: <i>kcalc</i>) ou um site (ex.: <i>https://youtube.com</i>). Para pôr um aplicativo, use o botão direito sobre ele › Adicionar ao Deck."
                                color: lp.suave
                                font.pixelSize: Math.round(12 * palco.u)
                            }
                            QQC2.TextField { id: nomeDeck; width: parent.width; placeholderText: "Nome"; onAccepted: cmdDeck.forceActiveFocus() }
                            QQC2.TextField { id: cmdDeck; width: parent.width; placeholderText: "Comando ou endereço"; onAccepted: formDeck.guardar() }
                            Row {
                                spacing: 10
                                anchors.right: parent.right
                                QQC2.Button { text: "Cancelar"; onClicked: { formDeck.visible = false; busca.forceActiveFocus(); } }
                                QQC2.Button { text: "Adicionar"; highlighted: true; onClicked: formDeck.guardar() }
                            }
                        }
                    }
                }
            }

            // ================= detalhe =========================================================
            Vidro {
                fonte: fundoForte
                u: palco.u
                id: detalhe
                visible: palco.comDetalhe
                x: palco.width - palco.m - width
                y: palco.m
                width: palco.larguraDetalhe
                height: palco.height - palco.m * 2
            }
            Item {
                visible: palco.comDetalhe
                anchors.fill: detalhe
                anchors.margins: Math.round(22 * palco.u)
                readonly property var app: lp.selecionado

                Column {
                    id: colDet
                    width: parent.width
                    spacing: Math.round(10 * palco.u)
                    visible: parent.app !== null

                    Item {
                        width: parent.width
                        height: Math.round(150 * palco.u)
                        Kirigami.Icon {
                            id: iconeGrande
                            anchors.centerIn: parent
                            source: lp.selecionado ? lp.selecionado.icone : ""
                            width: Math.round(116 * palco.u)
                            height: width
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: iconeGrande
                            source: iconeGrande
                            shadowEnabled: true
                            shadowColor: Qt.rgba(0, 0, 0, 0.55)
                            shadowBlur: 0.8
                            shadowVerticalOffset: 6
                        }
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        text: lp.selecionado ? lp.selecionado.nome : ""
                        color: lp.texto
                        font.pixelSize: Math.round(22 * palco.u)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        text: lp.selecionado ? lp.selecionado.desc : ""
                        visible: text !== ""
                        color: lp.suave
                        font.pixelSize: Math.round(13 * palco.u)
                    }
                    Rectangle {   // categoria
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: lp.selecionado !== null && lp.selecionado.cat !== ""
                        width: chip.implicitWidth + Math.round(20 * palco.u)
                        height: Math.round(24 * palco.u)
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.10)
                        Text { id: chip; anchors.centerIn: parent; text: lp.selecionado ? lp.selecionado.cat : ""; color: lp.suave; font.pixelSize: Math.round(11 * palco.u) }
                    }
                    Item { width: 1; height: Math.round(4 * palco.u) }

                    // Abrir
                    Rectangle {
                        width: parent.width
                        height: Math.round(46 * palco.u)
                        radius: height * 0.3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: lp.realce1 }
                            GradientStop { position: 1; color: lp.realce2 }
                        }
                        opacity: ma2.pressed ? 0.8 : 1
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.25)
                        Row {
                            anchors.centerIn: parent
                            spacing: Math.round(8 * palco.u)
                            Kirigami.Icon { source: "media-playback-start"; width: Math.round(18 * palco.u); height: width; color: "white"; isMask: true; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Abrir"; color: "white"; font.pixelSize: Math.round(16 * palco.u); font.weight: Font.DemiBold }
                        }
                        MouseArea { id: ma2; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: lp.abrir(lp.selecionado) }
                    }

                    Text {
                        visible: lp.acoesSel.length > 0
                        text: "AÇÕES RÁPIDAS"
                        color: lp.suave
                        font.pixelSize: Math.round(11 * palco.u)
                        font.letterSpacing: 1.2
                        topPadding: Math.round(10 * palco.u)
                    }
                    Repeater {
                        model: lp.acoesSel.slice(0, 5)
                        delegate: ItemLado {
                            u: palco.u
                            required property var modelData
                            texto: modelData.text || ""
                            icone: modelData.icon || "media-playback-start"
                            onEscolhido: lp.acao(lp.selecionado, modelData)
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.10) }

                    ItemLado {

                        u: palco.u
                        texto: lp.naDock(lp.selecionado) ? "Remover da Dock" : "Fixar na Dock"
                        icone: lp.naDock(lp.selecionado) ? "window-unpin" : "window-pin"
                        onEscolhido: lp.alternarDock(lp.selecionado)
                    }
                    ItemLado {
                        u: palco.u
                        texto: lp.noDeck(lp.selecionado) ? "Já está no Deck" : "Adicionar ao Deck"
                        icone: "view-grid-symbolic"
                        opacity: lp.noDeck(lp.selecionado) ? 0.5 : 1
                        onEscolhido: lp.adicionarAoDeck(lp.selecionado)
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width
                    visible: lp.selecionado === null
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "Passe o rato por um aplicativo para ver os detalhes"
                    color: lp.suave
                    font.pixelSize: Math.round(13 * palco.u)
                }
            }
        }
    }

    // frase curta debaixo do nome de cada categoria
    function lema(nome: string, n: int): string {
        const c = semAcentos(nome);
        const t = c.indexOf("internet") !== -1 ? "Explore o mundo"
            : c.indexOf("graf") !== -1 ? "Crie, edite, inspire-se"
            : c.indexOf("multim") !== -1 ? "Música, vídeo e som"
            : c.indexOf("escrit") !== -1 ? "Documentos e produtividade"
            : c.indexOf("desenv") !== -1 || c.indexOf("program") !== -1 ? "Programar e construir"
            : c.indexOf("jogo") !== -1 ? "Jogue sem limites"
            : c.indexOf("sistema") !== -1 ? "Controle o seu sistema"
            : c.indexOf("utilit") !== -1 || c.indexOf("acess") !== -1 ? "Pequenas grandes ajudas"
            : c.indexOf("educ") !== -1 || c.indexOf("cienc") !== -1 ? "Aprender e descobrir"
            : c.indexOf("config") !== -1 || c.indexOf("defini") !== -1 ? "Ao seu gosto"
            : "";
        return t !== "" ? t + " · " + n : contagem(n);
    }
}
