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
import QtCore

Kicker.DashboardWindow {
    id: lp

    required property var dock

    backgroundColor: "transparent"
    // o teclado vai para onde se está a escrever: o formulário aberto, ou a pesquisa
    keyEventProxy: formSenha.visible ? (confSenha.activeFocus ? confSenha : campoSenha)
        : formCartao.visible ? nomeCartao
        : formDeck.visible ? (cmdDeck.activeFocus ? cmdDeck : nomeDeck)
        : formSite.visible ? (urlSite.activeFocus ? urlSite : nomeSite)
        : busca

    // ---- cores ----------------------------------------------------------------
    readonly property color texto: "#f6f2ff"
    readonly property color suave: Qt.rgba(0.93, 0.9, 1, 0.62)
    readonly property color realce1: "#5b7cff"
    readonly property color realce2: "#a35bff"
    readonly property var paleta: [
        ["#8a4dff", "#d06bff"], ["#2d6bff", "#4fc3ff"], ["#0f9d8a", "#3ee0b0"], ["#ff7a3d", "#ffc04d"],
        ["#ff4f8b", "#ff9bb8"], ["#4b3bd6", "#8a6bff"], ["#2fae55", "#9be06a"], ["#e5484d", "#ff8a65"],
        ["#0891b2", "#67e8f9"], ["#b45309", "#fbbf24"],
        ["#1e293b", "#64748b"], ["#7c2d12", "#ea580c"], ["#be185d", "#f472b6"], ["#065f46", "#34d399"],
        ["#1e3a8a", "#60a5fa"], ["#581c87", "#c084fc"], ["#a16207", "#fde047"], ["#0f766e", "#5eead4"],
        ["#9f1239", "#fb7185"], ["#3f3f46", "#d4d4d8"], ["#4d7c0f", "#bef264"], ["#c2410c", "#fdba74"]
    ]

    // ---- estado -----------------------------------------------------------------
    property var itens: []            // todos: [{ nome, icone, linha, id, chave, desc, acoes, cat }]
    property var catSistema: []       // as categorias do sistema: [{ nome, icone, apps: [item...], cor }]
    // os cartões como a pessoa os organizou (~/.config/carinaeos-cartoes.json):
    //   novos: [{nome, icone, cor}]  colocar: {chave: cartão}  fixos: [cartão...] (em primeiro)
    //   nomes: {original: novo}  cores: {cartão: n}  ocultos: [cartão...]
    property var cartoesCfg: ({ novos: [], colocar: {}, fixos: [], nomes: {}, cores: {}, ocultos: [], ordem: [], imagens: {} })
    // [{ orig, nome, icone, apps, cor, propria, fixo }]
    readonly property var categorias: {
        const cfg = cartoesCfg, col = cfg.colocar || {}, nomes = cfg.nomes || {}, cores = cfg.cores || {};
        const ocultos = cfg.ocultos || [], fx = cfg.fixos || [];
        const lista = [], porOrig = {};
        const cor = (orig, padrao) => cores[orig] !== undefined ? paleta[cores[orig] % paleta.length] : padrao;
        const visto = {};      // cada aplicativo só num ambiente (o primeiro onde aparece, ou para onde foi movido)
        // o ambiente CarinaeOS: sempre lá, com tudo o que é do CarinaeOS (Central, Música, Órbita, Manual…)
        const doCarinae = itens.filter(a => /^carinaeos/i.test(a.chave || "") && !col[a.chave])
                               .sort((a, b) => a.nome.localeCompare(b.nome));
        for (const a of doCarinae) visto[a.chave] = true;
        for (const c of catSistema) {
            const apps = c.apps.filter(a => {
                if (col[a.chave] || visto[a.chave]) return false;
                visto[a.chave] = true;
                return true;
            });
            if (ocultos.indexOf(c.nome) !== -1) continue;
            const x = { orig: c.nome, nome: nomes[c.nome] || c.nome, icone: c.icone, cor: cor(c.nome, c.cor),
                        propria: false, apps: apps };
            lista.push(x);
            porOrig[x.orig] = x;
        }
        let k = 0;
        for (const n of (cfg.novos || [])) {
            if (porOrig[n.nome]) continue;
            const x = { orig: n.nome, nome: n.nome, icone: n.icone || "folder-favorites",
                        cor: cor(n.nome, paleta[(catSistema.length + k++) % paleta.length]), propria: true, apps: [] };
            lista.push(x);
            porOrig[x.orig] = x;
        }
        if (ocultos.indexOf("CarinaeOS") === -1) {
            let ca = porOrig["CarinaeOS"];
            if (!ca) {
                ca = { orig: "CarinaeOS", nome: nomes["CarinaeOS"] || "CarinaeOS", icone: "carinaeos-estrela",
                       cor: cor("CarinaeOS", ["#7b5cff", "#ff8a65"]), propria: false, carinae: true, apps: [] };
                lista.unshift(ca);
                porOrig["CarinaeOS"] = ca;
            }
            ca.carinae = true;
            ca.apps = ca.apps.concat(doCarinae.filter(a => ca.apps.indexOf(a) === -1));
        }
        for (const ch in col) {
            const c = porOrig[col[ch]], a = porChave(ch);
            if (c && a) c.apps.push(a);
        }
        const imagens = cfg.imagens || {};
        for (const c of lista) c.imagem = imagens[c.orig] || "";
        const r = lista.filter(c => c.propria || c.carinae || c.apps.length > 0);
        const ord = cfg.ordem || [];
        r.forEach((c, i) => { c.fixo = fx.indexOf(c.orig) !== -1; c.ordem = i; });
        r.sort((a, b) => {
            // 1.º os fixados em primeiro, 2.º a ordem arrastada no modo Editar, 3.º a ordem natural
            const ia = fx.indexOf(a.orig), ib = fx.indexOf(b.orig);
            if (ia !== -1 || ib !== -1) return (ia === -1 ? 1e6 : ia) - (ib === -1 ? 1e6 : ib);
            const oa = ord.indexOf(a.orig), ob = ord.indexOf(b.orig);
            if (oa !== -1 || ob !== -1) return (oa === -1 ? 1e6 + a.ordem : oa) - (ob === -1 ? 1e6 + b.ordem : ob);
            if (!!a.carinae !== !!b.carinae) return a.carinae ? -1 : 1;   // o CarinaeOS vem primeiro
            return a.ordem - b.ordem;
        });
        return r;
    }
    property var usados: []           // chaves dos mais usados
    property var novos: []            // chaves dos instalados nos ultimos 14 dias (mais recentes primeiro)
    property var deck: []             // [{ nome, icone, cmd } | { app: chave }]
    property string vista: "inicio"   // inicio | todos | favoritos | usados | deck | cat
    property int catAtual: -1
    property string filtro: ""
    property var selecionado: null
    property var acoesSel: []
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
                else if (n.indexOf(f) !== -1 || semAcentos(lp.descricaoDe(x)).indexOf(f) !== -1) b.push(x);
            }
            return a.concat(b);
        }
        if (vista === "todos") return itens;
        if (vista === "semamb") return semAmbiente;
        if (vista === "cat") return (categorias[catAtual] || { apps: [] }).apps;
        if (vista === "favoritos") {
            const l = lp.dock.modelo.launcherList, r = [];
            for (let i = 0; i < l.length; ++i) {
                const x = porChave(chave(l[i]));
                if (x) r.push(x);
            }
            return r;
        }
        if (vista === "novos") {
            const r = [];
            for (const c of novos) {
                const x = porChave(c);
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
    // os aplicativos que a pessoa ainda não pôs em nenhum ambiente (somem daqui ao serem movidos)
    readonly property var semAmbiente: {
        const col = cartoesCfg.colocar || {};
        return itens.filter(a => a.chave && !col[a.chave] && !/^carinaeos/i.test(a.chave)).sort((a, b) => a.nome.localeCompare(b.nome));
    }
    readonly property bool emGrelha: filtro !== "" || (vista !== "inicio" && vista !== "deck")
    readonly property string titulo: filtro !== "" ? "Resultados"
        : vista === "inicio" ? saudacao()
        : vista === "todos" ? "Todos os aplicativos"
        : vista === "favoritos" ? "Favoritos"
        : vista === "usados" ? "Mais usados"
        : vista === "novos" ? "Instalados recentemente"
        : vista === "deck" ? "Deck"
        : vista === "semamb" ? "Sem ambiente"
        : (categorias[catAtual] || { nome: "" }).nome
    readonly property string subtitulo: filtro !== "" ? contagem(lista.length)
        : vista === "inicio" ? (editando ? "Arraste os ambientes para os mudar de lugar · cor e imagem em cada um" : "Os seus ambientes, de um relance")
        : vista === "favoritos" ? "Os aplicativos que estão na Dock"
        : vista === "deck" ? "Seus sites e atalhos · botão direito para editar, ocultar ou tirar"
        : vista === "semamb" ? contagem(lista.length) + " por arrumar · botão direito › Mover para"
        : contagem(lista.length)

    function contagem(n: int): string {
        return n === 1 ? "1 aplicativo" : n + " aplicativos";
    }
    function saudacao(): string {
        const h = new Date().getHours();
        return h < 6 ? "Boa noite" : h < 13 ? "Bom dia" : h < 20 ? "Boa tarde" : "Boa noite";
    }
    function mudarVista(v: string, c: int): void {
        if (v === "cat" && c >= 0 && c < categorias.length) {
            const k = categorias[c];
            if (ambFechado(k.orig)) {
                abrirAmbienteTrancado(k);
                return;
            }
        }
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
        else if (formSite.visible) formSite.visible = false;
        else if (formAcoes.visible) formAcoes.visible = false;
        else if (formSenha.visible) formSenha.fechar();
        else if (formCartao.visible) formCartao.visible = false;
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
    }
    // a lista de aplicativos lê-se uns segundos depois de a sessão abrir (não atrasa a entrada);
    // se o Launchpad abrir antes disso, lê-se nesse momento
    readonly property Timer leituraInicial: Timer {
        interval: 20000
        running: true
        onTriggered: if (!lp.todosModelo) lp.raiz.refresh()
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

    // ---- cor do Launchpad: "" = vidro sobre o papel de parede; ou uma cor lisa, sem transparência
    // (guardada em ~/.config/carinaeos/launchpad.ini)
    readonly property var coresLp: [
        ["", "Vidro"], ["#3b1537", "Ameixa"], ["#24262c", "Grafite"], ["#121215", "Preto"],
        ["#172338", "Azul-noite"], ["#2a1f4d", "Violeta"], ["#15302a", "Verde-floresta"],
        ["#3a1420", "Vinho"], ["#2e221b", "Café"], ["#1d3440", "Petróleo"]
    ]
    readonly property Settings prefs: Settings {
        location: String(StandardPaths.writableLocation(StandardPaths.ConfigLocation)) + "/carinaeos/launchpad.ini"
        property string cor: ""
    }
    readonly property string corLp: prefs.cor

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
    // as teclas do Deck são ações (carinaeos-deck): { id, nome, icone }; continuam a valer
    // as antigas { nome, icone, cmd } (comando ou site) e { app } (de versões anteriores)
    // os atalhos com que o Deck começa (os sites vêm do navegador, na secção de cima)
    readonly property var deckPadrao: [
        { id: "sis:captura", nome: "Captura de tela", icone: "spectacle" },
        { id: "sis:janelas", nome: "Todas as janelas", icone: "view-grid" },
        { id: "sis:mesa", nome: "Mostrar a área de trabalho", icone: "user-desktop" },
        { id: "mus:tocar", nome: "Tocar / pausar", icone: "media-playback-start" }
    ]
    // os comandos do Deck antigo: um Deck só com estes é o de origem e passa ao novo
    readonly property var deckAntigo: ["spectacle", "konsole", "plasma-systemmonitor", "carinaeos-central", "carinaeos-supernova",
        "carinaeos-manual", "carinaeos-configuracoes", "loginctl lock-session", "systemctl suspend"]
    // ações que acontecem fora do Launchpad: ele fecha-se depois
    readonly property var deckFecha: ["sis:captura", "sis:janelas", "sis:mesa", "sis:bloquear", "sis:suspender"]
    // aplicativos instalados recentemente (Debian, Flathub, AppImage): pela data do lancador
    readonly property P5Support.DataSource lerNovos: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            const l = (dados["stdout"] || "").split("\n").map(x => x.trim()).filter(x => x.endsWith(".desktop"));
            const r = [];
            for (const c of l) if (r.indexOf(c) === -1) r.push(c);
            lp.novos = r;
        }
    }
    readonly property P5Support.DataSource lerDeck: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            const t = (dados["stdout"] || "").trim();
            let d = null;
            try { d = JSON.parse(t); } catch (e) { d = null; }
            if (Array.isArray(d) && d.length > 0 && d.every(t => t.cmd && (lp.deckAntigo.indexOf(t.cmd) !== -1 || /qdbus6|xdg-user-dir/.test(t.cmd))))
                d = null;       // ainda era o Deck de origem: passa às ações novas
            // nomes de versões antigas, ainda em português de Portugal
            const novosNomes = { "Captura de ecrã": "Captura de tela", "Transferências": "Downloads", "Mostrar a mesa": "Mostrar a área de trabalho",   // ptbr-ok (de pt-PT para pt-BR)
                                 "Ecrã": "Tela", "Definições": "Configurações" };   // ptbr-ok
            if (Array.isArray(d)) for (const t of d) if (novosNomes[t.nome]) t.nome = novosNomes[t.nome];
            if (Array.isArray(d)) d = d.filter(t => !String(t.id || "").startsWith("rot:"));   // as Rotinas saíram do CarinaeOS
            lp.deck = Array.isArray(d) ? d : lp.deckPadrao;
            lp.lerEstadosDeck();
        }
    }
    function gravarDeck(): void {
        // JSON só com ASCII (os acentos vão como \uXXXX) para passar por base64 sem estragos
        const j = JSON.stringify(deck).replace(/[\u0080-￿]/g,
            c => "\\u" + ("0000" + c.charCodeAt(0).toString(16)).slice(-4));
        correr("sh -c 'mkdir -p \"$HOME/.config\" && echo " + Qt.btoa(j)
               + " | base64 -d > \"$HOME/.config/carinaeos-deck.json\"'");
    }
    // ---- cartões: ler e gravar ~/.config/carinaeos-cartoes.json ----------------------
    // ---- recentes do aplicativo escolhido (carinaeos-recentes): documentos, sites, conversas ----
    property var recentes: []
    property var cacheRecentes: ({})
    property string chaveRecentes: ""
    onSelecionadoChanged: {
        acoesSel = [];
        const k = selecionado && selecionado.chave ? selecionado.chave : "";
        if (k === chaveRecentes) return;
        chaveRecentes = k;
        const c = cacheRecentes[k];
        recentes = c && Date.now() - c.quando < 60000 ? c.lista : [];
        if (k !== "" && !(c && Date.now() - c.quando < 60000)) pedirRecentes.restart();
    }
    readonly property Timer pedirRecentes: Timer {
        // só depois de o rato parar um pouco no aplicativo (passar por cima de vários não lê nada)
        interval: 250
        onTriggered: if (lp.chaveRecentes !== "" && /^[A-Za-z0-9._-]+$/.test(lp.chaveRecentes))
            lp.lerRecentes.connectSource("carinaeos-recentes '" + lp.chaveRecentes + "' #" + Date.now())
    }
    readonly property P5Support.DataSource lerRecentes: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            const m = fonte.match(/^carinaeos-recentes '([^']+)'/);
            if (!m) return;
            let l = [];
            try { l = JSON.parse((dados["stdout"] || "").trim()) || []; } catch (e) { l = []; }
            const c = Object.assign({}, lp.cacheRecentes);
            c[m[1]] = { quando: Date.now(), lista: l };
            lp.cacheRecentes = c;
            if (m[1] === lp.chaveRecentes) lp.recentes = l;
        }
    }
    function abrirRecente(app: var, item: var): void {
        if (!app || !app.chave || !item || !item.u) return;
        correr("carinaeos-recentes abrir '" + app.chave.replace(/'/g, "") + "' '" + String(item.u).replace(/'/g, "'\\''") + "'");
        lp.toggle();
    }

    // ---- descrições curtas em português de todos os aplicativos (carinaeos-descricoes) ------
    property var descricoes: ({})
    function descricaoDe(app: var): string {
        if (!app) return "";
        return (app.chave && descricoes[app.chave]) || descricoes["nome:" + (app.nome || "").toLowerCase()] || app.desc || "";
    }
    readonly property P5Support.DataSource lerDescricoes: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            try { lp.descricoes = JSON.parse((dados["stdout"] || "").trim()) || {}; } catch (e) {}
        }
    }
    readonly property P5Support.DataSource lerCartoes: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            let d = null;
            try { d = JSON.parse((dados["stdout"] || "").trim()); } catch (e) { d = null; }
            if (d && typeof d === "object") {
                lp.cartoesCfg = Object.assign({ novos: [], colocar: {}, fixos: [], nomes: {}, cores: {}, ocultos: [], ordem: [], imagens: {} }, d);
            }
        }
    }
    function gravarCartoes(): void {
        const j = JSON.stringify(cartoesCfg).replace(/[\u0080-\uffff]/g,
            c => "\\u" + ("0000" + c.charCodeAt(0).toString(16)).slice(-4));
        correr("sh -c 'mkdir -p \"$HOME/.config\" && echo " + Qt.btoa(j)
               + " | base64 -d > \"$HOME/.config/carinaeos-cartoes.json\"'");
    }
    function mudarCartoes(f: var): void {
        const c = JSON.parse(JSON.stringify(cartoesCfg));
        f(c);
        cartoesCfg = c;
        gravarCartoes();
    }
    // lista fixa dos ambientes para um menu (tirada ao abrir: mudar os ambientes com o menu aberto
    // recriava os itens debaixo do rato e prendia o Plasma)
    // o mesmo aplicativo pode chegar de listas diferentes (Favoritos, um cartão, a pesquisa) como objetos
    // diferentes: compara-se pela chave (o nome do .desktop), não pelo objeto
    function temApp(lista: var, app: var): bool {
        if (!app || !lista) return false;
        if (lista.indexOf(app) !== -1) return true;
        return !!app.chave && lista.some(a => a && a.chave === app.chave);
    }
    function ambientesPara(app: var): var {
        const atual = cartaoDe(app);
        return categorias.map(c => ({ orig: c.orig, nome: c.nome,
            marcado: app !== null && (atual === c.orig || (atual === "" && lp.temApp(c.apps, app))) }));
    }
    // o ambiente onde o aplicativo aparece agora (ou "" se não está em nenhum)
    function ambienteDe(app: var): string {
        if (!app) return "";
        for (const c of categorias) if (lp.temApp(c.apps, app)) return c.nome;
        return "";
    }
    function cartaoDe(app: var): string {
        return app && app.chave ? ((cartoesCfg.colocar || {})[app.chave] || "") : "";
    }
    function novoCartao(nome: string, app: var): void {
        nome = nome.trim();
        if (nome === "") return;
        mudarCartoes(c => {
            const existe = c.novos.some(n => n.nome === nome) || catSistema.some(x => x.nome === nome);
            if (!existe) c.novos.push({ nome: nome, icone: "folder-favorites" });
            const i = c.ocultos.indexOf(nome);
            if (i !== -1) c.ocultos.splice(i, 1);
            if (app && app.chave) c.colocar[app.chave] = nome;
        });
    }
    function colocarNoCartao(app: var, orig: string): void {
        if (!app || !app.chave) return;
        mudarCartoes(c => { c.colocar[app.chave] = orig; });
    }
    function tirarDoCartao(app: var): void {
        if (!app || !app.chave) return;
        mudarCartoes(c => { delete c.colocar[app.chave]; });
    }
    function alternarFixo(orig: string): void {
        mudarCartoes(c => {
            const i = c.fixos.indexOf(orig);
            if (i === -1) c.fixos.push(orig); else c.fixos.splice(i, 1);
        });
    }
    function renomearCartao(orig: string, nome: string, propria: bool): void {
        nome = nome.trim();
        if (nome === "" || nome === orig) return;
        mudarCartoes(c => {
            if (!propria) {
                c.nomes[orig] = nome;
                return;
            }
            // um cartão criado pela pessoa muda mesmo de nome (e leva os aplicativos, a cor e o lugar)
            for (const n of c.novos) if (n.nome === orig) n.nome = nome;
            for (const k in c.colocar) if (c.colocar[k] === orig) c.colocar[k] = nome;
            c.fixos = c.fixos.map(x => x === orig ? nome : x);
            if (c.cores[orig] !== undefined) { c.cores[nome] = c.cores[orig]; delete c.cores[orig]; }
        });
    }
    property bool editando: false
    function moverAmbiente(de: int, para: int): void {
        if (de === para || de < 0 || para < 0) return;
        const l = categorias.map(c => c.orig);
        const [x] = l.splice(de, 1);
        l.splice(para, 0, x);
        mudarCartoes(c => { c.ordem = l; c.fixos = []; });   // a ordem arrastada manda
    }
    property string imagemPara: ""
    readonly property P5Support.DataSource escolherImagem: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            const f = (dados["stdout"] || "").trim();
            const o = lp.imagemPara;
            if (f !== "" && o !== "") lp.mudarCartoes(c => { c.imagens[o] = "file://" + f; });
            reabrir.restart();      // deixa a gravação acabar antes de voltar a ler o ficheiro
        }
    }
    // quando uma janela (ficheiros, senha) tem de aparecer, o Launchpad fecha-se e volta depois a abrir aqui
    property bool voltarAEditar: false
    property string irPara: ""
    readonly property Timer reabrir: Timer {
        interval: 450
        onTriggered: { if (!lp.visible) lp.toggle(); else lp.aplicarVolta(); }
    }
    function aplicarVolta(): void {
        editando = voltarAEditar;
        voltarAEditar = false;
        if (irPara !== "") {
            const o = irPara;
            irPara = "";
            const i = categorias.findIndex(c => c.orig === o);
            if (i >= 0) mudarVista("cat", i);
        }
    }

    // ---- cadeado: aplicativos e ambientes trancados com senha (carinaeos-cadeado) ----
    property var cadeado: ({ apps: [], ambientes: [], senha: false })
    property var liberados: []        // ambientes trancados já abertos com a senha (até o Launchpad fechar)
    readonly property P5Support.DataSource lerCadeado: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            try {
                const c = JSON.parse((dados["stdout"] || "").trim());
                lp.cadeado = { apps: c.apps || [], ambientes: c.ambientes || [], senha: !!c.senha };
            } catch (e) {}
        }
    }
    function lerEstadoCadeado(): void {
        lerCadeado.connectSource("carinaeos-cadeado estado #" + Date.now());
    }
    function trancado(app: var): bool {
        return !!app && !!app.chave && cadeado.apps.indexOf(app.chave) !== -1;
    }
    function ambTrancado(orig: string): bool {
        return cadeado.ambientes.indexOf(orig) !== -1;
    }
    // trancado e ainda fechado agora (depois da senha, aparece normal)
    function ambFechado(orig: string): bool {
        return ambTrancado(orig) && liberados.indexOf(orig) === -1;
    }
    function aspas(t: string): string {
        return "'" + String(t).replace(/'/g, "'\\''") + "'";
    }
    // A senha é pedida aqui dentro do Launchpad (uma janela à parte ficava atrás dele). Para não ir na
    // linha de comandos (visível no "ps"), passa por um ficheiro em /run/user/<uid> (só do utilizador),
    // que o carinaeos-cadeado lê e apaga logo.
    readonly property string cofreCaminho: String(StandardPaths.writableLocation(StandardPaths.RuntimeLocation)).replace("file://", "")
                                           + "/carinaeos-cadeado-pedido.ini"
    readonly property Settings cofre: Settings { location: "file://" + lp.cofreCaminho }
    function hexUtf8(t: string): string {
        let h = "";
        const b = x => h += (x + 256).toString(16).slice(1);
        for (const ch of t) {
            const c = ch.codePointAt(0);
            if (c < 0x80) b(c);
            else if (c < 0x800) { b(0xc0 | c >> 6); b(0x80 | c & 63); }
            else if (c < 0x10000) { b(0xe0 | c >> 12); b(0x80 | c >> 6 & 63); b(0x80 | c & 63); }
            else { b(0xf0 | c >> 18); b(0x80 | c >> 12 & 63); b(0x80 | c >> 6 & 63); b(0x80 | c & 63); }
        }
        return h;
    }
    property var depoisCadeado: null
    property var falhaCadeado: null
    readonly property P5Support.DataSource acaoCadeado: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            const ok = dados["exit code"] === 0;
            const f = ok ? lp.depoisCadeado : lp.falhaCadeado;
            lp.depoisCadeado = null;
            lp.falhaCadeado = null;
            if (f) f();
            lp.lerEstadoCadeado();
        }
    }
    function cadeadoCmd(args: string, depois: var, falha: var): void {
        depoisCadeado = depois || null;
        falhaCadeado = falha || null;
        acaoCadeado.connectSource("carinaeos-cadeado " + args + " #" + Date.now());
    }
    // corre a ação com a senha escrita no formulário
    function comSenha(senha: string, acao: string, depois: var, falha: var): void {
        cofre.setValue("s", "n" + Date.now() + "x" + hexUtf8(senha));
        cofre.sync();
        cadeadoCmd("--senha-ficheiro " + aspas(cofreCaminho) + " " + acao, depois, falha);
    }
    function trancarOuCriarSenha(acao: string, oQue: string): void {
        if (cadeado.senha) cadeadoCmd(acao, null, null);
        else formSenha.abrir("Criar a senha do cadeado",
                             "É a senha que vai abrir " + oQue + " e tudo o que trancar a seguir.", true, acao, null);
    }
    function alternarTrancaApp(app: var): void {
        if (!app || !app.chave) return;
        if (trancado(app)) formSenha.abrir("Destrancar “" + app.nome + "”", "Digite a senha dos aplicativos.", false,
                                           "destrancar-app " + aspas(app.chave), null);
        else trancarOuCriarSenha("trancar-app " + aspas(app.chave), "«" + app.nome + "»");
    }
    function alternarTrancaAmbiente(c: var): void {
        if (!c) return;
        if (ambTrancado(c.orig)) formSenha.abrir("Destrancar o ambiente “" + c.nome + "”", "Digite a senha dos aplicativos.", false,
                                                 "destrancar-ambiente " + aspas(c.orig), null);
        else trancarOuCriarSenha("trancar-ambiente " + aspas(c.orig), "o ambiente «" + c.nome + "»");
    }
    function abrirAmbienteTrancado(c: var): void {
        const o = c.orig;
        formSenha.abrir("Abrir o ambiente “" + c.nome + "”", "Este ambiente está trancado. Digite a senha dos aplicativos.", false,
                        "verificar", () => {
                            lp.liberados = lp.liberados.concat([o]);
                            const i = lp.categorias.findIndex(k => k.orig === o);
                            if (i >= 0) lp.mudarVista("cat", i);
                        });
    }
    function pedirImagem(orig: string): void {
        imagemPara = orig;
        // a janela de ficheiros não fica por cima do Launchpad: fecha-se e volta a abrir no modo Editar
        voltarAEditar = true;
        if (visible) toggle();
        escolherImagem.connectSource("kdialog --title 'Imagem do ambiente' --getopenfilename \"$(xdg-user-dir PICTURES)\" "
            + "'image/png image/jpeg image/webp image/svg+xml' 2>/dev/null #" + Date.now());
    }
    function tirarImagem(orig: string): void {
        mudarCartoes(c => { delete c.imagens[orig]; });
    }
    function definirCor(orig: string, i: int): void {
        mudarCartoes(c => { c.cores[orig] = i; });
    }
    function abrirCores(orig: string, junto: var): void {
        tabelaCores.orig = orig;
        tabelaCores.parent = junto || palco;
        tabelaCores.open();
    }
    function mudarCor(orig: string): void {
        mudarCartoes(c => {
            const atual = c.cores[orig] !== undefined ? c.cores[orig] : Math.floor(Math.random() * paleta.length);
            c.cores[orig] = (atual + 1) % paleta.length;
        });
    }
    function esconderCartao(orig: string, propria: bool): void {
        mudarCartoes(c => {
            if (propria) {
                c.novos = c.novos.filter(n => n.nome !== orig);
                for (const k in c.colocar) if (c.colocar[k] === orig) delete c.colocar[k];
            } else if (c.ocultos.indexOf(orig) === -1) {
                c.ocultos.push(orig);
            }
            c.fixos = c.fixos.filter(x => x !== orig);
        });
        if (vista === "cat") mudarVista("inicio");
    }
    function noDeck(app: var): bool {
        if (!app) return false;
        for (const t of deck) if (t.app === app.chave) return true;
        return false;
    }
    function noDeckId(id: string): bool {
        return deck.some(t => t.id === id);
    }
    function adicionarAcao(a: var): void {
        if (noDeckId(a.id)) return;
        deck = deck.concat([{ id: a.id, nome: a.nome, icone: a.icone }]);
        gravarDeck();
        lerEstadosDeck();
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
    // ---- Deck › favoritos do navegador principal (carinaeos-favoritos) ----------------------
    property var favoritos: ({ navegador: "", itens: [] })
    property var favPilha: []             // as pastas abertas: [{ nome, itens }]
    readonly property var favAtuais: favPilha.length ? favPilha[favPilha.length - 1].itens : (favoritos.itens || [])
    readonly property P5Support.DataSource lerFavoritos: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            try { lp.favoritos = JSON.parse((dados["stdout"] || "").trim()); } catch (e) {}
        }
    }
    function atualizarFavoritos(): void { lerFavoritos.connectSource("carinaeos-favoritos #" + Date.now()); }
    // acrescentar / editar / tirar um site do Deck (os favoritos do navegador nunca mudam: só ficam ocultos)
    readonly property P5Support.DataSource mexerFavoritos: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => { disconnectSource(fonte); lp.atualizarFavoritos(); }
    }
    function sites(args: var): void {
        mexerFavoritos.connectSource("carinaeos-favoritos " + args.map(a => aspas(a)).join(" ") + " #" + Date.now());
    }
    function abrirFavorito(f: var): void {
        if (f.tipo === "pasta") { favPilha = favPilha.concat([f]); return; }
        correr("xdg-open " + aspas(f.url));
        lp.toggle();
    }
    onVistaChanged: if (vista === "deck") { favPilha = []; atualizarFavoritos(); }

    property var deckEstado: ({})
    readonly property P5Support.DataSource estadoDeck: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            try {
                const r = JSON.parse((dados["stdout"] || "").trim());
                lp.deckEstado = Object.assign({}, lp.deckEstado, r);
            } catch (e) {}
        }
    }
    function lerEstadosDeck(): void {
        const ids = deck.filter(t => t.id).map(t => aspas(t.id));
        if (ids.length > 0) estadoDeck.connectSource("carinaeos-deck estado " + ids.join(" ") + " #" + Date.now());
    }
    readonly property Timer relogioDeck: Timer {
        interval: 3000
        repeat: true
        running: lp.visible && lp.vista === "deck" && lp.filtro === ""
        onTriggered: lp.lerEstadosDeck()
    }
    readonly property P5Support.DataSource acaoDeck: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            const m = fonte.match(/^carinaeos-deck tocar '(.*)' #/);
            try {
                const r = JSON.parse((dados["stdout"] || "").trim());
                if (m) {
                    const e = Object.assign({}, lp.deckEstado);
                    e[m[1].replace(/'\\''/g, "'")] = r;
                    lp.deckEstado = e;
                }
            } catch (e) {}
        }
    }
    function tocarDeck(t: var): void {
        if (t.id) {
            // mostra já o estado contrário (a resposta confirma), e não fecha o Launchpad nos interruptores
            const e = deckEstado[t.id];
            if (e && e.ligado !== null && e.ligado !== undefined) {
                const n = Object.assign({}, deckEstado);
                n[t.id] = { ligado: !e.ligado, texto: "…" };
                deckEstado = n;
            }
            acaoDeck.connectSource("carinaeos-deck tocar " + aspas(t.id) + " #" + Date.now());
            if (deckFecha.indexOf(t.id) !== -1) lp.toggle();
            return;
        }
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
        if (!visible) liberados = [];
        if (visible) {
            lp.lerFundo.connectSource("f=$(grep -A4 '\\[Wallpaper\\]\\[org.kde.image\\]\\[General\\]' \"$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc\" | sed -n 's/^Image=//p' | head -1); "
                + "f=${f#file://}; if [ -d \"$f\" ]; then ls -S \"$f\"/contents/images/* 2>/dev/null | tail -1; else echo \"$f\"; fi #" + Date.now());
            lp.lerDeck.connectSource("cat \"$HOME/.config/carinaeos-deck.json\" 2>/dev/null #" + Date.now());
            lp.lerCartoes.connectSource("cat \"$HOME/.config/carinaeos-cartoes.json\" 2>/dev/null #" + Date.now());
            lp.lerDescricoes.connectSource("carinaeos-descricoes #" + Date.now());
            formCartao.visible = false;
            formSenha.visible = false;
            busca.text = "";
            formDeck.visible = false;
            formAcoes.visible = false;
            lp.editando = false;
            lp.lerEstadoCadeado();
            vista = "inicio";
            Qt.callLater(lp.aplicarVolta);
            busca.forceActiveFocus();
            entrada.restart();
            juntarUsados.restart();
            // apanha os aplicativos acabados de instalar (o menu do Plasma nem sempre se atualiza sozinho)
            Qt.callLater(() => lp.raiz.refresh());
            lp.lerNovos.connectSource("find /usr/share/applications /usr/local/share/applications \"$HOME/.local/share/applications\" "
                + "/var/lib/flatpak/exports/share/applications \"$HOME/.local/share/flatpak/exports/share/applications\" "
                + "-name '*.desktop' -mtime -30 -newer /usr/lib/carinaeos/.base -printf '%T@ %f\\n' 2>/dev/null | sort -rn | cut -d' ' -f2 | head -24 #" + Date.now());
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
                    lp.catSistema = cs;
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
            visible: lp.corLp === ""
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
            visible: lp.corLp === ""
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
            visible: lp.corLp === ""
            opacity: conteudo.opacity
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(0.04, 0.02, 0.1, 0.18) }
                GradientStop { position: 1; color: Qt.rgba(0.04, 0.02, 0.1, 0.42) }
            }
        }

        // cor lisa escolhida: a tela toda dessa cor, sem transparência
        Rectangle {
            anchors.fill: parent
            visible: lp.corLp !== ""
            color: lp.corLp !== "" ? lp.corLp : "black"
            opacity: conteudo.opacity
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
            property var amb: []
            onAboutToShow: amb = lp.ambientesPara(app)
            QQC2.MenuItem { text: "Abrir"; onTriggered: lp.abrir(menuApp.app) }
            QQC2.MenuItem {
                text: lp.naDock(menuApp.app) ? "Remover da Dock" : "Adicionar à Dock"
                enabled: menuApp.app !== null && menuApp.app.chave !== ""
                onTriggered: lp.alternarDock(menuApp.app)
            }
            QQC2.MenuItem {
                text: lp.trancado(menuApp.app) ? "Destrancar" : "Trancar com senha"
                icon.name: lp.trancado(menuApp.app) ? "object-unlocked" : "object-locked"
                enabled: menuApp.app !== null && menuApp.app.chave !== ""
                onTriggered: { const a = menuApp.app; Qt.callLater(() => lp.alternarTrancaApp(a)); }
            }
            QQC2.MenuSeparator {}
            QQC2.Menu {
                id: subCartoes
                title: "Mover para"
                enabled: menuApp.app !== null && menuApp.app.chave !== ""
                Instantiator {
                    model: menuApp.amb
                    delegate: QQC2.MenuItem {
                        required property var modelData
                        text: modelData.nome
                        checkable: true
                        checked: modelData.marcado
                        onTriggered: { const a = menuApp.app, o = modelData.orig; Qt.callLater(() => lp.colocarNoCartao(a, o)); }
                    }
                    onObjectAdded: (i, o) => subCartoes.insertItem(i, o)
                    onObjectRemoved: (i, o) => subCartoes.removeItem(o)
                }
                QQC2.MenuSeparator {}
                QQC2.MenuItem { text: "Novo ambiente…"; onTriggered: formCartao.abrir("novo", "", false, menuApp.app) }
            }
            QQC2.MenuItem {
                visible: lp.cartaoDe(menuApp.app) !== ""
                height: visible ? implicitHeight : 0
                text: "Voltar à categoria original"
                onTriggered: { const a = menuApp.app; Qt.callLater(() => lp.tirarDoCartao(a)); }
            }
            QQC2.MenuSeparator {}
            QQC2.MenuItem {      // como no Windows: abre Configurações › Aplicativos já com este app
                text: "Desinstalar…"
                icon.name: "edit-delete"
                enabled: menuApp.app !== null
                onTriggered: { const a = menuApp.app; lp.correr("carinaeos-configuracoes aplicativos " + lp.aspas(a.nome)); lp.toggle(); }
            }
        }
        // "Mover para ›" no painel do detalhe
        QQC2.Menu {
            id: menuMover
            property var app: null
            property var amb: []
            onAboutToShow: amb = lp.ambientesPara(app)
            Instantiator {
                model: menuMover.amb
                delegate: QQC2.MenuItem {
                    required property var modelData
                    text: modelData.nome
                    checkable: true
                    checked: modelData.marcado
                    onTriggered: { const a = menuMover.app, o = modelData.orig; Qt.callLater(() => lp.colocarNoCartao(a, o)); }
                }
                onObjectAdded: (i, o) => menuMover.insertItem(i, o)
                onObjectRemoved: (i, o) => menuMover.removeItem(o)
            }
            QQC2.MenuSeparator {}
            QQC2.MenuItem { text: "Novo ambiente…"; onTriggered: formCartao.abrir("novo", "", false, menuMover.app) }
            QQC2.MenuItem {
                visible: lp.cartaoDe(menuMover.app) !== ""
                height: visible ? implicitHeight : 0
                text: "Voltar à categoria original"
                onTriggered: { const a = menuMover.app; Qt.callLater(() => lp.tirarDoCartao(a)); }
            }
        }
        // tabela de cores de um ambiente
        QQC2.Popup {
            id: tabelaCores
            property string orig: ""
            readonly property int atual: {
                const c = lp.cartoesCfg.cores || {};
                return c[orig] !== undefined ? c[orig] % lp.paleta.length : -1;
            }
            x: !parent ? 0 : parent === palco ? (palco.width - width) / 2 : Math.min(0, parent.width - width)
            y: !parent ? 0 : parent === palco ? (palco.height - height) / 2 : parent.height + Math.round(8 * palco.u)
            modal: false
            margins: Math.round(12 * palco.u)
            padding: Math.round(14 * palco.u)
            onClosed: parent = palco
            background: Rectangle {
                radius: Math.round(18 * palco.u)
                color: Qt.rgba(0.08, 0.08, 0.12, 0.96)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.18)
            }
            contentItem: Column {
                spacing: Math.round(10 * palco.u)
                Text { text: "Cor do ambiente"; color: "white"; font.pixelSize: Math.round(14 * palco.u); font.weight: Font.DemiBold }
                Grid {
                    columns: 6
                    spacing: Math.round(8 * palco.u)
                    Repeater {
                        model: lp.paleta.length
                        delegate: Rectangle {
                            id: amostra
                            required property int index
                            width: Math.round(38 * palco.u)
                            height: width
                            radius: width / 2
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: lp.paleta[amostra.index][0] }
                                GradientStop { position: 1; color: lp.paleta[amostra.index][1] }
                            }
                            border.width: tabelaCores.atual === index ? 3 : (mAm.containsMouse ? 2 : 0)
                            border.color: "white"
                            scale: mAm.containsMouse ? 1.1 : 1
                            Kirigami.Icon { visible: tabelaCores.atual === amostra.index; anchors.centerIn: parent; source: "checkmark"; width: parent.width * 0.5; height: width; color: "white"; isMask: true }
                            MouseArea {
                                id: mAm
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: { const o = tabelaCores.orig, i = amostra.index; tabelaCores.close(); Qt.callLater(() => lp.definirCor(o, i)); }
                            }
                        }
                    }
                }
            }
        }
        // menu do botão direito de um cartão
        QQC2.Menu {
            id: menuCartao
            property var c: null
            QQC2.MenuItem {
                text: menuCartao.c && menuCartao.c.fixo ? "Tirar dos primeiros" : "Colocar em primeiro"
                onTriggered: lp.alternarFixo(menuCartao.c.orig)
            }
            QQC2.MenuItem { text: "Mudar o nome…"; onTriggered: formCartao.abrir("nome", menuCartao.c.orig, menuCartao.c.propria, null) }
            QQC2.MenuItem {
                text: menuCartao.c && lp.ambTrancado(menuCartao.c.orig) ? "Destrancar este ambiente" : "Trancar com senha"
                icon.name: menuCartao.c && lp.ambTrancado(menuCartao.c.orig) ? "object-unlocked" : "object-locked"
                onTriggered: { const c = menuCartao.c; Qt.callLater(() => lp.alternarTrancaAmbiente(c)); }
            }
            QQC2.MenuItem { text: "Mudar a cor…"; onTriggered: { const o = menuCartao.c.orig; Qt.callLater(() => lp.abrirCores(o, null)); } }
            QQC2.MenuSeparator {}
            QQC2.MenuItem { text: "Novo ambiente…"; onTriggered: formCartao.abrir("novo", "", false, null) }
            QQC2.MenuItem {
                text: menuCartao.c && menuCartao.c.propria ? "Apagar este ambiente" : "Esconder este ambiente"
                onTriggered: lp.esconderCartao(menuCartao.c.orig, menuCartao.c.propria)
            }
            QQC2.MenuItem {
                visible: (lp.cartoesCfg.ocultos || []).length > 0
                height: visible ? implicitHeight : 0
                text: "Mostrar os ambientes escondidos"
                onTriggered: lp.mudarCartoes(c => { c.ocultos = []; })
            }
        }
        QQC2.Menu {
            id: menuFav
            property var f: null
            readonly property bool site: f !== null && f.tipo === "site"
            QQC2.MenuItem { visible: menuFav.site; height: visible ? implicitHeight : 0; text: "Abrir"; icon.name: "internet-web-browser"
                            onTriggered: lp.abrirFavorito(menuFav.f) }
            QQC2.MenuItem { visible: menuFav.site; height: visible ? implicitHeight : 0; text: "Editar…"; icon.name: "document-edit"
                            onTriggered: formSite.abrir(menuFav.f) }
            QQC2.MenuItem { visible: menuFav.site && !menuFav.f.meu; height: visible ? implicitHeight : 0; text: "Manter no Deck"; icon.name: "window-pin"
                            onTriggered: lp.sites(["adicionar", menuFav.f.nome, menuFav.f.url]) }
            QQC2.MenuItem { visible: menuFav.site; height: visible ? implicitHeight : 0
                            text: menuFav.f && menuFav.f.meu ? "Tirar do Deck" : "Ocultar do Deck"; icon.name: "list-remove"
                            onTriggered: lp.sites(["remover", menuFav.f.url]) }
            QQC2.MenuSeparator {}
            QQC2.MenuItem { text: "Adicionar site…"; icon.name: "list-add"; onTriggered: formSite.abrir(null) }
            QQC2.MenuItem { visible: (lp.favoritos.ocultos || 0) > 0; height: visible ? implicitHeight : 0
                            text: "Mostrar os ocultos (" + (lp.favoritos.ocultos || 0) + ")"; icon.name: "view-visible"
                            onTriggered: lp.sites(["mostrar-todos"]) }
        }
        QQC2.Menu {
            id: menuDeck
            property int i: -1
            QQC2.MenuItem { text: "Tirar do Deck"; onTriggered: lp.tirarDoDeck(menuDeck.i) }
            QQC2.MenuItem {
                readonly property var app: menuDeck.i >= 0 && lp.deck[menuDeck.i] && lp.deck[menuDeck.i].app ? lp.porChave(lp.deck[menuDeck.i].app) : null
                visible: app !== null
                height: visible ? implicitHeight : 0
                text: lp.trancado(app) ? "Destrancar" : "Trancar com senha"
                icon.name: lp.trancado(app) ? "object-unlocked" : "object-locked"
                onTriggered: { const a = app; Qt.callLater(() => lp.alternarTrancaApp(a)); }
            }
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
            property string cor: ""          // cor lisa (sem vidro)
            Rectangle {
                visible: v.cor !== ""
                anchors.fill: parent
                radius: v.raio
                color: v.cor !== "" ? Qt.lighter(v.cor, 1.35) : "transparent"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.10)
            }
            ShaderEffectSource {
                id: pedaco
                visible: false
                enabled: v.cor === ""
                anchors.fill: parent
                sourceItem: v.cor === "" ? v.fonte : null
                sourceRect: Qt.rect(v.x, v.y, v.width, v.height)
            }
            Rectangle {
                id: forma
                anchors.fill: parent
                radius: v.raio
                visible: false
                layer.enabled: true
            }
            MultiEffect {
                visible: v.cor === ""
                anchors.fill: parent
                source: pedaco
                maskEnabled: true
                maskSource: forma
            }
            Rectangle {
                visible: v.cor === ""
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
                cor: lp.corLp
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
                        ItemLado { u: palco.u; texto: "Recém-instalados"; icone: "document-new"; numero: String(lp.lista && lp.novos ? lp.novos.filter(c => lp.porChave(c) !== null).length : 0); visible: lp.novos.length > 0; ativo: lp.filtro === "" && lp.vista === "novos"; onEscolhido: lp.mudarVista("novos") }
                        ItemLado { u: palco.u; texto: "Mais usados"; icone: "office-chart-line"; visible: lp.usadosModelo !== null; ativo: lp.filtro === "" && lp.vista === "usados"; onEscolhido: lp.mudarVista("usados") }
                        ItemLado { u: palco.u; texto: "Deck"; icone: "view-grid-symbolic"; numero: String(lp.deck.length); ativo: lp.filtro === "" && lp.vista === "deck"; onEscolhido: lp.mudarVista("deck") }

                        Text {
                            text: "AMBIENTES"
                            color: lp.suave
                            font.pixelSize: Math.round(11 * palco.u)
                            font.letterSpacing: 1.2
                            topPadding: Math.round(16 * palco.u)
                            bottomPadding: Math.round(6 * palco.u)
                            leftPadding: Math.round(12 * palco.u)
                        }
                        ItemLado {
                            u: palco.u
                            texto: "Sem ambiente"
                            icone: "folder-open"
                            numero: String(lp.semAmbiente.length)
                            visible: lp.semAmbiente.length > 0
                            ativo: lp.filtro === "" && lp.vista === "semamb"
                            onEscolhido: lp.mudarVista("semamb")
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
                        ItemLado {
                            u: palco.u
                            texto: "Novo ambiente…"
                            icone: "list-add"
                            onEscolhido: formCartao.abrir("novo", "", false, null)
                        }
                    }
                }

                Row {
                    id: energia
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(10 * palco.u)
                    BotaoRedondo { id: btCor; u: palco.u; icone: "color-management"; dica: "Cor do Launchpad"; onCarregado: escolhaCor.open() }
                    BotaoRedondo { u: palco.u; icone: "system-lock-screen"; dica: "Bloquear"; onCarregado: { lp.correr("loginctl lock-session"); lp.toggle(); } }
                    BotaoRedondo { u: palco.u; icone: "system-suspend"; dica: "Suspender"; onCarregado: { lp.correr("systemctl suspend"); lp.toggle(); } }
                    BotaoRedondo { u: palco.u; icone: "system-reboot"; dica: "Reiniciar…"; onCarregado: { lp.correr("qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptReboot"); lp.toggle(); } }
                    BotaoRedondo { u: palco.u; icone: "system-shutdown"; dica: "Desligar…"; onCarregado: { lp.correr("qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptShutDown"); lp.toggle(); } }
                }
            }

            // escolha da cor do Launchpad
            QQC2.Popup {
                id: escolhaCor
                parent: btCor
                y: -height - Math.round(10 * palco.u)
                x: -Math.round(12 * palco.u)
                padding: Math.round(14 * palco.u)
                background: Rectangle {
                    radius: Math.round(16 * palco.u)
                    color: "#1b1922"
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                }
                contentItem: Column {
                    spacing: Math.round(10 * palco.u)
                    Text { text: "Cor do Launchpad"; color: lp.texto; font.pixelSize: Math.round(14 * palco.u); font.weight: Font.DemiBold }
                    Grid {
                        columns: 5
                        spacing: Math.round(10 * palco.u)
                        Repeater {
                            model: lp.coresLp
                            delegate: Column {
                                id: amostra
                                required property var modelData
                                readonly property bool escolhida: lp.corLp === modelData[0]
                                spacing: Math.round(4 * palco.u)
                                width: Math.round(64 * palco.u)
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.round(38 * palco.u); height: width; radius: width / 2
                                    color: amostra.modelData[0] !== "" ? amostra.modelData[0] : Qt.rgba(1, 1, 1, 0.12)
                                    border.width: amostra.escolhida ? 3 : 1
                                    border.color: amostra.escolhida ? "#ffb46e" : Qt.rgba(1, 1, 1, maCor.containsMouse ? 0.6 : 0.2)
                                    Kirigami.Icon {
                                        visible: amostra.modelData[0] === ""
                                        anchors.centerIn: parent
                                        source: "blurfx"
                                        width: parent.width * 0.5; height: width
                                    }
                                    MouseArea {
                                        id: maCor
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: lp.prefs.cor = amostra.modelData[0]
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: amostra.modelData[1]
                                    color: lp.suave
                                    font.pixelSize: Math.round(11 * palco.u)
                                }
                            }
                        }
                    }
                }
            }

            // ================= centro =========================================================
            Vidro {
                fonte: fundoForte
                cor: lp.corLp
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
                        // com um formulário aberto, a pesquisa não aceita letras (desligá-la de todo faz o
                        // Plasma tentar dar-lhe o teclado sem fim e fechar-se: nunca usar "enabled" aqui)
                        readOnly: formSenha.visible || formCartao.visible || formDeck.visible || formAcoes.visible || formSite.visible
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
                        text: "Ctrl+Espaço: Pesquisa"
                        color: lp.suave
                        font.pixelSize: Math.round(12 * palco.u)
                        visible: centro.width > 700
                    }
                }

                // título da vista
                Rectangle {     // Editar os ambientes (arrastar, cor, imagem)
                    visible: lp.vista === "inicio" && lp.filtro === ""
                    anchors.right: parent.right
                    anchors.verticalCenter: cabecalho.verticalCenter
                    width: rotEditar.implicitWidth + Math.round(34 * palco.u)
                    height: Math.round(34 * palco.u)
                    radius: height / 2
                    color: lp.editando ? "#ffb46e" : (mEd.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.09))
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.2)
                    Row {
                        anchors.centerIn: parent
                        spacing: Math.round(6 * palco.u)
                        Kirigami.Icon { source: lp.editando ? "dialog-ok-apply" : "document-edit"; width: Math.round(16 * palco.u); height: width
                                        isMask: true; color: lp.editando ? "#1a1208" : "white"; anchors.verticalCenter: parent.verticalCenter }
                        Text { id: rotEditar; text: lp.editando ? "Concluído" : "Editar"; color: lp.editando ? "#1a1208" : "white"
                               font.pixelSize: Math.round(13 * palco.u); font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: mEd; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lp.editando = !lp.editando }
                }
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

                            // instalados recentemente (ou, se não houver, os usados recentemente)
                            Text {
                                visible: lp.novos.length > 0 || lp.usados.length > 0
                                text: lp.novos.length > 0 ? "Instalados recentemente" : "Usados recentemente"
                                color: lp.suave
                                font.pixelSize: Math.round(13 * palco.u)
                            }
                            Row {
                                visible: lp.novos.length > 0 || lp.usados.length > 0
                                spacing: Math.round(8 * palco.u)
                                Repeater {
                                    model: {
                                        const r = [];
                                        for (const c of (lp.novos.length > 0 ? lp.novos : lp.usados)) {
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
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onContainsMouseChanged: if (containsMouse) lp.selecionado = rec.modelData
                                            onClicked: (m) => {
                                                if (m.button === Qt.RightButton) {
                                                    menuApp.app = rec.modelData;
                                                    menuApp.popup();
                                                } else {
                                                    lp.abrir(rec.modelData);
                                                }
                                            }
                                            onPressAndHold: { menuApp.app = rec.modelData; menuApp.popup(); }
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
                                        // arrastar no modo Editar
                                        property real dx: 0
                                        property real dy: 0
                                        property point inicio
                                        readonly property bool aArrastar: arrasto.pressed && (Math.abs(dx) + Math.abs(dy)) > 4
                                        transform: Translate { x: cartao.dx; y: cartao.dy }
                                        z: aArrastar ? 10 : 0
                                        opacity: aArrastar ? 0.92 : 1
                                        scale: aArrastar ? 1.04 : (mc.containsMouse && !lp.editando ? 1.015 : 1)
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
                                            border.width: lp.editando ? 2 : 1
                                            border.color: lp.editando ? Qt.rgba(1, 0.75, 0.45, 0.85) : Qt.rgba(1, 1, 1, mc.containsMouse ? 0.38 : 0.20)
                                            // a imagem do ambiente, como marca de água
                                            Image {
                                                visible: cartao.modelData.imagem !== ""
                                                anchors.fill: parent
                                                source: cartao.modelData.imagem
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                sourceSize.width: Math.round(cartao.width)
                                                opacity: 0.24
                                            }
                                            // a "ilustração": o ícone da categoria grande e esbatido
                                            Kirigami.Icon {
                                                visible: cartao.modelData.imagem === ""
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
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            onClicked: (m) => {
                                                if (m.button === Qt.RightButton) {
                                                    menuCartao.c = cartao.modelData;
                                                    menuCartao.popup();
                                                } else {
                                                    lp.mudarVista("cat", cartao.index);
                                                }
                                            }
                                            onPressAndHold: { menuCartao.c = cartao.modelData; menuCartao.popup(); }
                                        }
                                        // modo Editar: o cartão inteiro arrasta-se; os botões ficam por cima
                                        MouseArea {
                                            id: arrasto
                                            z: 5
                                            anchors.fill: parent
                                            enabled: lp.editando
                                            visible: lp.editando
                                            preventStealing: true
                                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                            onPressed: (m) => { cartao.inicio = mapToItem(cartoes, m.x, m.y); }
                                            onPositionChanged: (m) => {
                                                const p = mapToItem(cartoes, m.x, m.y);
                                                cartao.dx += p.x - cartao.inicio.x;
                                                cartao.dy += p.y - cartao.inicio.y;
                                                cartao.inicio = p;
                                            }
                                            onReleased: {
                                                const cx = cartao.x + cartao.dx + cartao.width / 2;
                                                const cy = cartao.y + cartao.dy + cartao.height / 2;
                                                const col = Math.max(0, Math.min(cartoes.colunas - 1, Math.floor(cx / (cartoes.lc + cartoes.spacing))));
                                                const lin = Math.max(0, Math.floor(cy / (cartao.height + cartoes.spacing)));
                                                const alvo = Math.min(lp.categorias.length - 1, lin * cartoes.colunas + col);
                                                const de = cartao.index;
                                                cartao.dx = 0;
                                                cartao.dy = 0;
                                                Qt.callLater(() => lp.moverAmbiente(de, alvo));
                                            }
                                            onCanceled: { cartao.dx = 0; cartao.dy = 0; }
                                        }
                                        Row {
                                            z: 6
                                            visible: lp.editando && !cartao.aArrastar
                                            anchors.right: parent.right
                                            anchors.rightMargin: Math.round(12 * palco.u)
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: Math.round(12 * palco.u)
                                            spacing: Math.round(6 * palco.u)
                                            Repeater {
                                                model: [
                                                    { ic: "color-management", dica: "Mudar a cor", f: "cor" },
                                                    { ic: "insert-image", dica: "Colocar uma imagem (marca de água)", f: "img" },
                                                    { ic: "edit-clear", dica: "Tirar a imagem", f: "semimg" }
                                                ].filter(b => b.f !== "semimg" || cartao.modelData.imagem !== "")
                                                delegate: Rectangle {
                                                    id: bEd
                                                    required property var modelData
                                                    width: Math.round(34 * palco.u)
                                                    height: width
                                                    radius: width / 2
                                                    color: mB.containsMouse ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.35)
                                                    border.width: 1
                                                    border.color: Qt.rgba(1, 1, 1, 0.3)
                                                    Kirigami.Icon { anchors.centerIn: parent; source: bEd.modelData.ic; width: parent.width * 0.55; height: width; color: "white"; isMask: true }
                                                    QQC2.ToolTip.visible: mB.containsMouse
                                                    QQC2.ToolTip.text: bEd.modelData.dica
                                                    MouseArea {
                                                        id: mB
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            const o = cartao.modelData.orig, f = bEd.modelData.f;
                                                            Qt.callLater(() => {
                                                                if (f === "cor") lp.abrirCores(o, bEd);
                                                                else if (f === "img") lp.pedirImagem(o);
                                                                else lp.tirarImagem(o);
                                                            });
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        Kirigami.Icon {     // pega para arrastar
                                            z: 6
                                            visible: lp.editando
                                            source: "transform-move"
                                            color: "white"
                                            isMask: true
                                            opacity: 0.8
                                            width: Math.round(18 * palco.u); height: width
                                            anchors.right: parent.right
                                            anchors.rightMargin: Math.round(18 * palco.u)
                                            y: Math.round(10 * palco.u)
                                        }
                                        Rectangle {     // ambiente trancado
                                            visible: lp.ambFechado(cartao.modelData.orig) && !cartao.aArrastar
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: Math.round(28 * palco.u)
                                            width: Math.round(52 * palco.u); height: width; radius: width / 2
                                            color: Qt.rgba(0, 0, 0, 0.30)
                                            border.width: 1
                                            border.color: Qt.rgba(1, 1, 1, 0.25)
                                            Kirigami.Icon { anchors.centerIn: parent; source: "object-locked"; width: parent.width * 0.5; height: width; color: "white"; isMask: true }
                                        }
                                        Kirigami.Icon {     // fixado em primeiro
                                            visible: cartao.modelData.fixo === true
                                            source: "starred-symbolic"
                                            color: "#ffd479"
                                            isMask: true
                                            width: Math.round(16 * palco.u); height: width
                                            x: Math.round(48 * palco.u); y: Math.round(10 * palco.u)
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
                                                text: lp.ambFechado(cartao.modelData.orig) ? "Trancado com senha" : lp.lema(cartao.modelData.nome, cartao.modelData.apps.length)
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
                                            visible: !lp.editando
                                            color: Qt.rgba(1, 1, 1, mc.containsMouse ? 0.28 : 0.14)
                                            Kirigami.Icon { anchors.centerIn: parent; source: "go-next"; width: parent.width * 0.55; height: width; color: "white"; isMask: true }
                                        }
                                        // até 4 aplicativos da categoria
                                        Row {
                                            visible: !lp.ambFechado(cartao.modelData.orig)
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

                    // ---- Deck: secções (favoritos do navegador, atalhos) ---------------------
                    Flickable {
                        id: rolarDeck
                        anchors.fill: parent
                        visible: !lp.emGrelha && lp.vista === "deck"
                        clip: true
                        contentHeight: colDeck.height + Math.round(20 * palco.u)
                        boundsBehavior: Flickable.StopAtBounds
                        QQC2.ScrollBar.vertical: QQC2.ScrollBar {}
                    Column {
                        id: colDeck
                        width: rolarDeck.width
                        spacing: Math.round(6 * palco.u)

                        // ---- Favoritos do navegador ----
                        Item {
                            width: parent.width; height: Math.round(40 * palco.u)
                            Row {
                                x: Math.round(8 * palco.u); anchors.verticalCenter: parent.verticalCenter
                                spacing: Math.round(8 * palco.u)
                                Text {
                                    visible: lp.favPilha.length > 0
                                    text: "‹"; color: lp.texto; font.pixelSize: Math.round(22 * palco.u)
                                    anchors.verticalCenter: parent.verticalCenter
                                    MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
                                                onClicked: lp.favPilha = lp.favPilha.slice(0, -1) }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (lp.favoritos.titulo || (lp.favoritos.navegador ? "Favoritos do " + lp.favoritos.navegador : "Favoritos"))
                                          + lp.favPilha.map(p => "  ›  " + p.nome).join("")
                                    color: lp.texto; font.pixelSize: Math.round(15 * palco.u); font.weight: Font.DemiBold
                                }
                            }
                        }
                        Text {
                            visible: lp.favoritos.navegador !== "" && lp.favAtuais.length === 0 && lp.favPilha.length > 0
                            x: Math.round(8 * palco.u); width: parent.width - x * 2; wrapMode: Text.Wrap
                            text: "Ainda sem favoritos nem histórico. No navegador, clique na estrela ☆ da barra de endereço e escolha a pasta “Barra de favoritos”: eles aparecem aqui."
                            color: lp.suave; font.pixelSize: Math.round(12 * palco.u)
                        }
                        Flow {
                            id: fluxoFav
                            width: parent.width
                            spacing: 0
                            readonly property int colunas: Math.max(4, Math.floor(width / Math.round(132 * palco.u)))
                            readonly property real lado: Math.floor(width / colunas)
                            Repeater {
                                model: lp.favAtuais
                                delegate: Item {
                                    id: fav
                                    required property var modelData
                                    required property int index
                                    readonly property bool pasta: modelData.tipo === "pasta"
                                    readonly property var cor: lp.paleta[(index * 5 + 2) % lp.paleta.length]
                                    width: fluxoFav.lado; height: Math.round(104 * palco.u)
                                    Rectangle {
                                        anchors.fill: parent; anchors.margins: Math.round(6 * palco.u)
                                        radius: Math.round(18 * palco.u)
                                        scale: mf.pressed ? 0.95 : (mf.containsMouse ? 1.04 : 1)
                                        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }
                                        color: mf.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                                        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.14)
                                        // o ícone do site (do cache do navegador), uma pasta, ou a inicial numa bolinha
                                        Item {
                                            id: icFav
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: Math.round(14 * palco.u)
                                            width: Math.round(38 * palco.u); height: width
                                            Kirigami.Icon { anchors.fill: parent; visible: fav.pasta; source: "folder-favorites" }
                                            Image {
                                                id: imgFav
                                                anchors.centerIn: parent
                                                width: Math.round(30 * palco.u); height: width
                                                visible: !fav.pasta && status === Image.Ready
                                                source: !fav.pasta && fav.modelData.icone ? "file://" + fav.modelData.icone : ""
                                                sourceSize: Qt.size(64, 64); smooth: true; asynchronous: true
                                            }
                                            Rectangle {
                                                anchors.fill: parent; radius: width / 2
                                                visible: !fav.pasta && imgFav.status !== Image.Ready
                                                gradient: Gradient {
                                                    GradientStop { position: 0; color: fav.cor[1] }
                                                    GradientStop { position: 1; color: fav.cor[0] }
                                                }
                                                Text { anchors.centerIn: parent; color: "white"; font.pixelSize: Math.round(18 * palco.u); font.weight: Font.Bold
                                                       text: (fav.modelData.nome || "?").replace(/^[^A-Za-z0-9À-ÿ]+/, "").charAt(0).toUpperCase() }
                                            }
                                        }
                                        Text {
                                            anchors.top: icFav.bottom; anchors.topMargin: Math.round(8 * palco.u)
                                            x: 6; width: parent.width - 12
                                            horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                                            text: fav.modelData.nome; color: lp.texto
                                            font.pixelSize: Math.round(12 * palco.u)
                                        }
                                    }
                                    MouseArea {
                                        id: mf
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        onClicked: ev => {
                                            if (ev.button === Qt.RightButton) { menuFav.f = fav.modelData; menuFav.popup(); }
                                            else lp.abrirFavorito(fav.modelData);
                                        }
                                        onPressAndHold: { menuFav.f = fav.modelData; menuFav.popup(); }
                                    }
                                    QQC2.ToolTip.visible: mf.containsMouse && !fav.pasta
                                    QQC2.ToolTip.text: fav.pasta ? "" : fav.modelData.url
                                    QQC2.ToolTip.delay: 600
                                }
                            }
                            Item {      // + Adicionar site
                                visible: lp.favPilha.length === 0
                                width: fluxoFav.lado; height: Math.round(104 * palco.u)
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: Math.round(6 * palco.u)
                                    radius: Math.round(18 * palco.u)
                                    color: mAd.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.25)
                                    Kirigami.Icon { anchors.horizontalCenter: parent.horizontalCenter; y: Math.round(18 * palco.u)
                                                    width: Math.round(30 * palco.u); height: width; source: "list-add"; isMask: true; color: lp.texto }
                                    Text { anchors.bottom: parent.bottom; anchors.bottomMargin: Math.round(16 * palco.u); width: parent.width
                                           horizontalAlignment: Text.AlignHCenter; text: "Adicionar site"; color: lp.texto; font.pixelSize: Math.round(12 * palco.u) }
                                }
                                MouseArea { id: mAd; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: formSite.abrir(null) }
                            }
                        }

                        // ---- Atalhos (as teclas de sempre) ----
                        Text {
                            x: Math.round(8 * palco.u); topPadding: Math.round(14 * palco.u)
                            text: "Atalhos"; color: lp.texto; font.pixelSize: Math.round(15 * palco.u); font.weight: Font.DemiBold
                        }
                    GridView {
                        id: grelhaDeck
                        width: parent.width
                        height: Math.ceil(count / colunas) * cellHeight
                        interactive: false
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
                            readonly property var est: dado && dado.id ? lp.deckEstado[dado.id] : undefined
                            readonly property bool apagada: est !== undefined && est.ligado === false
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
                                    GradientStop { position: 0; color: tecla.mais ? Qt.rgba(1, 1, 1, 0.06) : lp.alfa(tecla.cor[1], tecla.apagada ? 0.22 : 0.85) }
                                    GradientStop { position: 1; color: tecla.mais ? Qt.rgba(1, 1, 1, 0.03) : lp.alfa(tecla.cor[0], tecla.apagada ? 0.18 : 0.85) }
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
                                    opacity: tecla.apagada ? 0.55 : 1
                                }
                                Rectangle {     // luz de "ligado"
                                    visible: tecla.est !== undefined && tecla.est.ligado === true
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: Math.round(14 * palco.u)
                                    width: Math.round(10 * palco.u); height: width; radius: width / 2
                                    color: "#7dffb0"
                                    border.width: 2
                                    border.color: Qt.rgba(1, 1, 1, 0.6)
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
                                    opacity: tecla.apagada ? 0.75 : 1
                                    font.pixelSize: Math.round(14 * palco.u)
                                    font.weight: Font.DemiBold
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.25)
                                }
                                Text {      // estado (Ligada · 80%, A tocar, …)
                                    visible: text !== ""
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: Math.round(5 * palco.u)
                                    width: parent.width - 16
                                    x: 8
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: tecla.est && tecla.est.texto ? tecla.est.texto : ""
                                    color: Qt.rgba(1, 1, 1, 0.7)
                                    font.pixelSize: Math.round(11 * palco.u)
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
                                        formAcoes.abrir();
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
                    }
                    }

                    // escolher uma ação para o Deck (catálogo do carinaeos-deck)
                    Rectangle {
                        id: formAcoes
                        visible: false
                        z: 55
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 40, Math.round(760 * palco.u))
                        height: Math.min(parent.height - 40, Math.round(640 * palco.u))
                        radius: Math.round(24 * palco.u)
                        color: Qt.rgba(0.09, 0.07, 0.2, 0.97)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                        property var grupos: []
                        property bool aCarregar: false
                        function abrir(): void {
                            aCarregar = true;
                            visible = true;
                            lerCatalogo.connectSource("carinaeos-deck catalogo #" + Date.now());
                        }
                        P5Support.DataSource {
                            id: lerCatalogo
                            engine: "executable"
                            connectedSources: []
                            onNewData: (fonte, dados) => {
                                disconnectSource(fonte);
                                try { formAcoes.grupos = JSON.parse((dados["stdout"] || "").trim()); } catch (e) { formAcoes.grupos = []; }
                                formAcoes.aCarregar = false;
                            }
                        }
                        MouseArea { anchors.fill: parent }
                        Column {
                            id: cabAcoes
                            x: Math.round(24 * palco.u); y: Math.round(20 * palco.u)
                            width: parent.width - Math.round(48 * palco.u)
                            spacing: 4
                            Text { text: "Adicionar ao Deck"; color: lp.texto; font.pixelSize: Math.round(20 * palco.u); font.weight: Font.DemiBold }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap
                                text: formAcoes.aCarregar ? "Procurando o que se pode colocar no Deck…" : "Toque numa ação para a colocar no Deck. As que mostram o estado acendem quando estão ligadas."
                                color: lp.suave; font.pixelSize: Math.round(12 * palco.u)
                            }
                        }
                        Flickable {
                            id: rolarAcoes
                            anchors.top: cabAcoes.bottom; anchors.topMargin: Math.round(14 * palco.u)
                            anchors.bottom: rodapeAcoes.top; anchors.bottomMargin: Math.round(10 * palco.u)
                            x: cabAcoes.x; width: cabAcoes.width
                            clip: true
                            contentHeight: colAcoes.height
                            boundsBehavior: Flickable.StopAtBounds
                            Column {
                                id: colAcoes
                                width: parent.width
                                spacing: Math.round(14 * palco.u)
                                Repeater {
                                    model: formAcoes.grupos
                                    delegate: Column {
                                        id: grupoA
                                        required property var modelData
                                        width: colAcoes.width
                                        spacing: Math.round(8 * palco.u)
                                        Text { text: grupoA.modelData.grupo; color: lp.texto; font.pixelSize: Math.round(14 * palco.u); font.weight: Font.DemiBold }
                                        Text {
                                            visible: !!grupoA.modelData.aviso
                                            width: parent.width; wrapMode: Text.Wrap
                                            text: grupoA.modelData.aviso || ""
                                            color: lp.suave; font.pixelSize: Math.round(12 * palco.u)
                                        }
                                        Flow {
                                            width: parent.width
                                            spacing: Math.round(8 * palco.u)
                                            Repeater {
                                                model: grupoA.modelData.itens
                                                delegate: Rectangle {
                                                    id: chipA
                                                    required property var modelData
                                                    readonly property bool ja: lp.noDeckId(modelData.id)
                                                    width: linhaA.implicitWidth + Math.round(26 * palco.u)
                                                    height: Math.round(38 * palco.u)
                                                    radius: height / 2
                                                    color: ja ? Qt.rgba(1, 0.71, 0.43, 0.25) : (mA.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                                                    border.width: 1
                                                    border.color: ja ? "#ffb46e" : Qt.rgba(1, 1, 1, 0.16)
                                                    Row {
                                                        id: linhaA
                                                        anchors.centerIn: parent
                                                        spacing: Math.round(8 * palco.u)
                                                        Kirigami.Icon { source: chipA.ja ? "checkmark" : chipA.modelData.icone; width: Math.round(18 * palco.u); height: width; anchors.verticalCenter: parent.verticalCenter }
                                                        Text { text: chipA.modelData.nome; color: lp.texto; font.pixelSize: Math.round(13 * palco.u); anchors.verticalCenter: parent.verticalCenter }
                                                    }
                                                    MouseArea {
                                                        id: mA
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: if (!chipA.ja) lp.adicionarAcao(chipA.modelData)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        Row {
                            id: rodapeAcoes
                            anchors.right: parent.right; anchors.rightMargin: Math.round(20 * palco.u)
                            anchors.bottom: parent.bottom; anchors.bottomMargin: Math.round(18 * palco.u)
                            spacing: 10
                            QQC2.Button { text: "Comando ou site…"; onClicked: { formAcoes.visible = false; formDeck.abrir(); } }
                            QQC2.Button { text: "Pronto"; highlighted: true; onClicked: { formAcoes.visible = false; busca.forceActiveFocus(); } }
                        }
                    }

                    // formulário: novo botão do Deck
                    Rectangle {
                        id: formSenha
                        visible: false
                        z: 60
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 40, Math.round(440 * palco.u))
                        height: colSenha.height + Math.round(44 * palco.u)
                        radius: Math.round(24 * palco.u)
                        color: Qt.rgba(0.09, 0.07, 0.2, 0.97)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                        property string titulo: ""
                        property string mensagem: ""
                        property bool nova: false
                        property string acao: ""
                        property var depois: null
                        property string erro: ""
                        property bool aVerificar: false
                        function abrir(t: string, m: string, n: bool, a: string, d: var): void {
                            titulo = t; mensagem = m; nova = n; acao = a; depois = d;
                            erro = ""; aVerificar = false;
                            campoSenha.text = ""; confSenha.text = "";
                            visible = true;
                            focoSenha.restart();
                        }
                        function fechar(): void {
                            visible = false;
                            campoSenha.text = ""; confSenha.text = "";
                            busca.forceActiveFocus();
                        }
                        Timer { id: focoSenha; interval: 80; onTriggered: campoSenha.forceActiveFocus() }
                        function enviar(): void {
                            if (aVerificar) return;
                            if (campoSenha.text === "") { erro = "Digite a senha."; return; }
                            if (nova && campoSenha.text.length < 4) { erro = "Use pelo menos 4 caracteres."; return; }
                            if (nova && campoSenha.text !== confSenha.text) { erro = "As duas senhas não são iguais."; confSenha.text = ""; confSenha.forceActiveFocus(); return; }
                            aVerificar = true;
                            erro = "";
                            const d = depois;
                            lp.comSenha(campoSenha.text, acao,
                                        () => { formSenha.fechar(); if (d) d(); },
                                        () => { formSenha.aVerificar = false; formSenha.erro = "Senha incorreta.";
                                                campoSenha.text = ""; campoSenha.forceActiveFocus(); });
                        }
                        MouseArea { anchors.fill: parent }
                        Column {
                            id: colSenha
                            x: Math.round(22 * palco.u)
                            y: Math.round(22 * palco.u)
                            width: parent.width - Math.round(44 * palco.u)
                            spacing: Math.round(10 * palco.u)
                            Row {
                                spacing: Math.round(12 * palco.u)
                                Rectangle {
                                    width: Math.round(42 * palco.u); height: width; radius: width * 0.3
                                    gradient: Gradient {
                                        GradientStop { position: 0; color: "#ff8a65" }
                                        GradientStop { position: 1; color: "#7b5cff" }
                                    }
                                    Kirigami.Icon { anchors.centerIn: parent; source: "object-locked"; width: parent.width * 0.55; height: width; color: "white"; isMask: true }
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: colSenha.width - Math.round(54 * palco.u)
                                    Text { width: parent.width; wrapMode: Text.Wrap; text: formSenha.titulo; color: lp.texto; font.pixelSize: Math.round(18 * palco.u); font.weight: Font.DemiBold }
                                    Text { text: "Cadeado do CarinaeOS"; color: lp.suave; font.pixelSize: Math.round(11 * palco.u) }
                                }
                            }
                            Text { width: parent.width; wrapMode: Text.Wrap; text: formSenha.mensagem; color: lp.suave; font.pixelSize: Math.round(13 * palco.u) }
                            QQC2.TextField {
                                id: campoSenha
                                width: parent.width
                                echoMode: TextInput.Password
                                placeholderText: formSenha.nova ? "Nova senha" : "Senha"
                                enabled: !formSenha.aVerificar
                                onAccepted: formSenha.nova && confSenha.text === "" ? confSenha.forceActiveFocus() : formSenha.enviar()
                            }
                            QQC2.TextField {
                                id: confSenha
                                visible: formSenha.nova
                                width: parent.width
                                echoMode: TextInput.Password
                                placeholderText: "Repita a senha"
                                enabled: !formSenha.aVerificar
                                onAccepted: formSenha.enviar()
                            }
                            Text {
                                visible: formSenha.erro !== "" || formSenha.aVerificar
                                text: formSenha.aVerificar ? "Verificando…" : formSenha.erro
                                color: formSenha.aVerificar ? lp.suave : "#ff8a8a"
                                font.pixelSize: Math.round(12 * palco.u)
                            }
                            Row {
                                spacing: 10
                                anchors.right: parent.right
                                QQC2.Button { text: "Cancelar"; onClicked: formSenha.fechar() }
                                QQC2.Button {
                                    text: formSenha.nova ? "Criar e trancar" : (formSenha.acao.indexOf("destrancar") === 0 ? "Destrancar" : "Abrir")
                                    highlighted: true
                                    enabled: !formSenha.aVerificar
                                    onClicked: formSenha.enviar()
                                }
                            }
                        }
                    }
                    Rectangle {
                        id: formCartao
                        visible: false
                        z: 50
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 40, Math.round(420 * palco.u))
                        height: colCartao.height + Math.round(40 * palco.u)
                        radius: Math.round(22 * palco.u)
                        color: Qt.rgba(0.09, 0.07, 0.2, 0.96)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                        property string modo: "novo"
                        property string orig: ""
                        property bool propria: false
                        property var app: null
                        function abrir(m: string, o: string, p: bool, a: var): void {
                            modo = m; orig = o; propria = p; app = a;
                            nomeCartao.text = m === "nome" ? ((lp.cartoesCfg.nomes || {})[o] || o) : "";
                            visible = true;
                            focoNome.restart();
                        }
                        Timer { id: focoNome; interval: 80; onTriggered: { nomeCartao.forceActiveFocus(); nomeCartao.selectAll(); } }
                        function guardar(): void {
                            if (nomeCartao.text.trim() === "") return;
                            if (modo === "novo") lp.novoCartao(nomeCartao.text, app);
                            else lp.renomearCartao(orig, nomeCartao.text, propria);
                            visible = false;
                            busca.forceActiveFocus();
                        }
                        MouseArea { anchors.fill: parent }
                        Column {
                            id: colCartao
                            x: Math.round(20 * palco.u)
                            y: Math.round(20 * palco.u)
                            width: parent.width - Math.round(40 * palco.u)
                            spacing: Math.round(10 * palco.u)
                            Text {
                                text: formCartao.modo === "novo" ? "Novo ambiente" : "Mudar o nome do ambiente"
                                color: lp.texto; font.pixelSize: Math.round(18 * palco.u); font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.Wrap
                                visible: formCartao.modo === "novo"
                                text: formCartao.app ? "«" + formCartao.app.nome + "» vai para este ambiente. Depois, botão direito noutros aplicativos › Mover para."
                                                     : "Depois, botão direito num aplicativo › Mover para. Botão direito no ambiente › Colocar em primeiro."
                                color: lp.suave
                                font.pixelSize: Math.round(12 * palco.u)
                            }
                            QQC2.TextField { id: nomeCartao; width: parent.width; placeholderText: "Nome (ex.: Escritório)"; onAccepted: formCartao.guardar() }
                            Row {
                                spacing: 10
                                anchors.right: parent.right
                                QQC2.Button { text: "Cancelar"; onClicked: { formCartao.visible = false; busca.forceActiveFocus(); } }
                                QQC2.Button { text: formCartao.modo === "novo" ? "Criar" : "Salvar"; highlighted: true; onClicked: formCartao.guardar() }
                            }
                        }
                    }
                    // acrescentar ou editar um site do Deck
                    Rectangle {
                        id: formSite
                        visible: false
                        z: 60
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 40, Math.round(460 * palco.u))
                        height: colSite.height + Math.round(40 * palco.u)
                        radius: Math.round(22 * palco.u)
                        color: Qt.rgba(0.09, 0.07, 0.2, 0.96)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.2)
                        property var f: null
                        function abrir(fav: var): void {
                            f = fav;
                            nomeSite.text = fav ? fav.nome : "";
                            urlSite.text = fav ? fav.url : "";
                            visible = true;
                            (fav ? nomeSite : urlSite).forceActiveFocus();
                        }
                        function guardar(): void {
                            const u = urlSite.text.trim();
                            if (u === "") return;
                            if (f) lp.sites(["editar", f.url, nomeSite.text.trim(), u]);
                            else lp.sites(["adicionar", nomeSite.text.trim(), u]);
                            visible = false;
                            busca.forceActiveFocus();
                        }
                        MouseArea { anchors.fill: parent }
                        Column {
                            id: colSite
                            x: Math.round(20 * palco.u); y: Math.round(20 * palco.u)
                            width: parent.width - Math.round(40 * palco.u)
                            spacing: Math.round(10 * palco.u)
                            Text { text: formSite.f ? "Editar site" : "Adicionar site"; color: lp.texto; font.pixelSize: Math.round(18 * palco.u); font.weight: Font.DemiBold }
                            Text {
                                width: parent.width; wrapMode: Text.Wrap; color: lp.suave; font.pixelSize: Math.round(12 * palco.u)
                                text: formSite.f && !formSite.f.meu ? "É um favorito do navegador: aqui muda só no Deck (no navegador fica como está)."
                                    : "Fica só no Deck. Ex.: <i>youtube.com</i> ou <i>192.168.1.193:8123</i>."
                            }
                            QQC2.TextField { id: urlSite; width: parent.width; placeholderText: "Endereço (ex.: youtube.com)"; onAccepted: formSite.guardar() }
                            QQC2.TextField { id: nomeSite; width: parent.width; placeholderText: "Nome (opcional)"; onAccepted: formSite.guardar() }
                            Row {
                                spacing: 10
                                anchors.right: parent.right
                                QQC2.Button { text: "Cancelar"; onClicked: { formSite.visible = false; busca.forceActiveFocus(); } }
                                QQC2.Button { text: formSite.f ? "Salvar" : "Adicionar"; highlighted: true; onClicked: formSite.guardar() }
                            }
                        }
                    }

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
                                text: "Um comando (ex.: <i>kcalc</i>) ou um site (ex.: <i>https://youtube.com</i>). Para colocar um aplicativo, use o botão direito sobre ele › Adicionar ao Deck."
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
                cor: lp.corLp
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
                        text: lp.selecionado ? lp.descricaoDe(lp.selecionado) : ""
                        visible: text !== ""
                        color: lp.suave
                        font.pixelSize: Math.round(13 * palco.u)
                    }
                    Rectangle {   // categoria
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: lp.selecionado !== null
                        width: chip.implicitWidth + Math.round(20 * palco.u)
                        height: Math.round(24 * palco.u)
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.10)
                        Text { id: chip; anchors.centerIn: parent; text: lp.selecionado ? (lp.ambienteDe(lp.selecionado) || "Sem ambiente") : ""; color: lp.suave; font.pixelSize: Math.round(11 * palco.u) }
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
                        texto: lp.trancado(lp.selecionado) ? "Destrancar" : "Trancar com senha"
                        icone: lp.trancado(lp.selecionado) ? "object-unlocked" : "object-locked"
                        onEscolhido: lp.alternarTrancaApp(lp.selecionado)
                    }
                    ItemLado {
                        id: itemMover
                        u: palco.u
                        texto: "Mover para  ›"
                        icone: "folder-favorites"
                        numero: lp.selecionado ? (lp.ambienteDe(lp.selecionado) || "Sem ambiente") : ""
                        onEscolhido: {
                            menuMover.app = lp.selecionado;
                            menuMover.popup(itemMover, itemMover.width * 0.4, itemMover.height);
                        }
                    }

                    // o que foi aberto há pouco com este aplicativo: atalhos diretos
                    Text {
                        visible: lp.recentes.length > 0
                        text: "RECENTES"
                        color: lp.suave
                        font.pixelSize: Math.round(11 * palco.u)
                        font.letterSpacing: 1.2
                        topPadding: Math.round(10 * palco.u)
                    }
                    Repeater {
                        model: lp.recentes
                        delegate: ItemLado {
                            u: palco.u
                            required property var modelData
                            texto: modelData.t || ""
                            icone: modelData.i || "document-open-recent"
                            numero: modelData.q || ""
                            onEscolhido: lp.abrirRecente(lp.selecionado, modelData)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width
                    visible: lp.selecionado === null
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: "Passe o mouse por um aplicativo para ver os detalhes"
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
