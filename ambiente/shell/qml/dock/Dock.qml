// Portado do Plasma pelo portar-do-plasma.py (CarinaeOS). Original: /home/claude/orig/plasmoids/org.carinaeos.dock/contents/ui/main.qml
/*
    CarinaeOS — Dock
    Como no macOS: os ícones crescem numa onda suave à volta do rato e sobem
    acima do fundo de vidro, o nome da app aparece por cima, as apps abertas
    têm um ponto, os ícones saltam ao abrir. A estrela (sempre em primeiro) abre o
    Launchpad (ecrã de aplicativos). Lixeira no fim.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import CarinaeOS.Base
import CarinaeOS.Compat as PlasmaCore
import CarinaeOS.Compat as Kirigami
import CarinaeOS.Compat as TaskManager
import CarinaeOS.Compat as P5Support

PlasmoidItem {
    id: dock

    preferredRepresentation: fullRepresentation

    // ---- medidas -----------------------------------------------------------
    // Windows 11: medidas fixas como no Windows (barra de 48 px, ícones de 24 px em quadrados de 40)
    readonly property bool win: e.win === true
    readonly property int base: win ? 40 : Plasmoid.configuration.iconSize
    readonly property real zoom: Plasmoid.configuration.zoom
    readonly property int espaco: Math.round(base * (e.espaco !== undefined ? e.espaco : 0.16))
    readonly property int margem: Math.round(base * (e.margem !== undefined ? e.margem : 0.16))        // dentro do vidro
    readonly property int baixo: win ? 0 : Math.round(base * 0.14)         // vidro -> fundo do ecrã
    readonly property real sigma: base * 1.35                    // largura da onda
    readonly property int separador: Math.round(base * 0.5)
    readonly property bool lixeira: !win && Plasmoid.configuration.showTrash
    readonly property int larguraPesquisa: win ? 188 : 0

    readonly property int fixadas: tasksModel.launcherList.length
    // separadores escolhidos pela pessoa (botão direito › Adicionar separador): ficam à direita destes lançadores
    readonly property var separadores: Plasmoid.configuration.separators
    readonly property int largSep: Math.round(base * 0.42)
    readonly property var slotsComSep: {
        const r = [];
        const l = tasksModel.launcherList;
        for (const u of separadores) {
            const i = l.indexOf(u);
            if (i !== -1) r.push(i < meio ? i : i + 1);
        }
        return r;
    }
    function sepAntes(slot: int): int {
        let n = 0;
        for (const s of slotsComSep) if (s < slot) n++;
        return n;
    }
    function temSeparador(lancador: string): bool {
        return lancador !== "" && separadores.indexOf(lancador) !== -1;
    }
    function alternarSeparador(lancador: string): void {
        if (lancador === "") return;
        const l = separadores.slice();
        const i = l.indexOf(lancador);
        if (i === -1) l.push(lancador); else l.splice(i, 1);
        Plasmoid.configuration.separators = l;
    }
    readonly property int meio: 0
    // apps + estrela + [Downloads + lixeira]
    readonly property int slots: tasksModel.count + 1 + (lixeira ? 2 : 0)
    readonly property real larguraRepouso: slots * (base + espaco) + espaco + (lixeira ? separador : 0) + slotsComSep.length * largSep
                                           + (win ? larguraPesquisa + espaco : 0)
    // ampliação: "dentro" (padrão) = só o ícone debaixo do rato cresce um pouco, sem sair da Dock;
    // "onda" = como no macOS, os ícones crescem numa onda e sobem acima do vidro
    // (a "onda" saiu: só existe a ampliação dentro da Dock, e só no modelo com efeito)
    readonly property string ampliacao: "dentro"
    readonly property bool dentro: true
    readonly property real zoomDentro: 1.2
    // espaço reservado para a ampliação (o painel não muda de tamanho)
    readonly property real folga: dentro ? base * (e.afastar || 0) * 2 : base * (zoom - 1) * 2.6
    // largura de cada lugar e altura do ícone (no modo "dentro" o lugar não muda: o ícone cresce no sítio)
    function larguraSlot(s: real): real {
        return base * (dentro ? 1 : s);
    }
    function yIcone(alturaFila: real, h: real, pulo: real): real {
        return dentro ? alturaFila - baixo - margem - base / 2 - h / 2 - pulo
                      : alturaFila - baixo - margem - h - pulo;
    }
    // Hexagonal: os ícones ficam encostados; ao passar o rato, os vizinhos afastam-se do ícone ampliado
    function desvio(slot: int): real {
        const a = e.afastar || 0;
        if (!a || forca < 0.01) {
            return 0;
        }
        const d = (centroRepouso(slot) - ratoX) / base;
        return base * a * forca * Math.tanh(d * 1.6) * Math.exp(-d * d / 40);
    }
    readonly property real alturaPulo: dentro ? margem * 0.7 : base * 0.55

    // a Dock pode ficar em baixo, em cima, à esquerda ou à direita: desenha-se sempre "deitada"
    // dentro de "palco", que roda para o lado certo (e os ícones rodam ao contrário)
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property real angulo: Plasmoid.location === PlasmaCore.Types.LeftEdge ? 90
        : Plasmoid.location === PlasmaCore.Types.RightEdge ? -90
        : Plasmoid.location === PlasmaCore.Types.TopEdge ? 180 : 0
    readonly property real comprimento: larguraRepouso + folga
    readonly property Item palcoItem: palco
    readonly property int localizacao: Plasmoid.location
    // aparência do separador (Configurações › Dock)
    readonly property color corSeparador: Plasmoid.configuration.separatorColor
    readonly property int grossuraSeparador: Math.max(1, Plasmoid.configuration.separatorWidth)

    Layout.minimumWidth: vertical ? -1 : comprimento
    Layout.preferredWidth: vertical ? -1 : comprimento
    Layout.maximumWidth: vertical ? -1 : comprimento
    Layout.minimumHeight: vertical ? comprimento : -1
    Layout.preferredHeight: vertical ? comprimento : -1
    Layout.maximumHeight: vertical ? comprimento : -1
    Layout.fillHeight: !vertical
    Layout.fillWidth: vertical

    // ---- onda de ampliação -------------------------------------------------
    // calculada nas posições de repouso: o tamanho depende só do rato.
    readonly property real inicioRepouso: (palco.width - larguraRepouso) / 2
    property real ratoAlvo: -10000
    property real ratoX: -10000
    // o rato é seguido com um pequeno atraso: a onda desliza em vez de saltar
    Behavior on ratoX {
        enabled: dock.forca > 0.02
        NumberAnimation { duration: 45; easing.type: Easing.OutQuad }
    }
    // só amplia com o rato sobre a faixa da Dock (não no espaço vazio por cima)
    property bool sobre: false
    property real forca: sobre ? 1 : 0
    Behavior on forca { NumberAnimation { duration: dock.sobre ? 200 : 340; easing.type: Easing.OutCubic } }

    // ---- como no Mac: em repouso o painel tem só a altura do vidro (nada invisível por cima a
    // apanhar cliques, e as janelas maximizadas param na borda de cima dela); ao passar o rato
    // cresce para caber a ampliação, por cima das janelas, e volta a encolher quando o rato sai.
    // O espaço reservado para as janelas é de um painel-espaçador à parte (ver carinaeos-ambiente-inicio).
    readonly property int alturaVidro: baixo + base + margem * 2
    readonly property int alturaRepouso: alturaVidro
    readonly property int alturaAmpliada: Math.ceil(base * (0.62 + zoom)) + 2
    readonly property var painel: palco.Window.window
    // cresce logo que o rato entra; só encolhe quando o rato saiu de vez e a onda já desceu.
    // (sem isto o painel mudava de tamanho debaixo do rato, perdia-o e voltava a crescer: tremia)
    property bool ampliado: false
    onAmpliadoChanged: {
        ajustarPainel();
        enviarForma();
    }
    // no modo fixo a área por cima dos ícones é transparente: assim que o rato sai da zona dos
    // ícones (mesmo sem sair da janela) a Dock volta a aceitar cliques só no vidro.
    onSobreChanged: {
        if (!modoFixo) {
            return;
        }
        if (sobre) {
            ratoEntrou();
        } else {
            encolher.restart();
        }
    }
    Timer {
        id: encolher
        interval: 450
        onTriggered: {
            if ((dock.modoFixo ? dock.sobre : hover.hovered) || dock.forca > 0.03) {
                restart();
            } else {
                dock.ampliado = false;
            }
        }
    }
    function ratoEntrou(): void {
        encolher.stop();
        ampliado = true;
    }
    onAlturaRepousoChanged: ajustarPainel()
    onAlturaAmpliadaChanged: ajustarPainel()
    onDentroChanged: {
        ultimaForma = "";
        ajustarPainel();
    }
    // o painel-espaçador (reserva o espaço das janelas) lê esta altura ao entrar na sessão
    onAlturaVidroChanged: if (Plasmoid.configuration.glassHeight !== alturaVidro) Plasmoid.configuration.glassHeight = alturaVidro
    Component.onCompleted: if (Plasmoid.configuration.glassHeight !== alturaVidro) Plasmoid.configuration.glassHeight = alturaVidro
    onPainelChanged: ajustarPainel()
    function ajustarPainel(): void {
        if (!painel || painel.thickness === undefined) {
            return;
        }
        // modo fixo (X11): o painel fica sempre com a altura da lupa e não muda de tamanho
        // (era isso que engasgava ao entrar e sair); só o vidro aceita cliques em repouso.
        // "dentro": nada sai do vidro, o painel tem sempre só a altura dele
        const t = dentro ? alturaVidro : (modoFixo || ampliado) ? alturaAmpliada : alturaRepouso;
        if (painel.thickness !== t) {
            painel.thickness = t;
        }
        if (modoFixo) {
            formaCliques.restart();
        }
    }

    // ---- cliques só no vidro (X11) -------------------------------------------
    // carinaeos-dock-cliques põe a "forma de entrada" da janela da Dock: em repouso só o vidro
    // apanha o rato; a parte transparente por cima deixa os cliques passar para as janelas de trás.
    // Se não houver X11 (Wayland) ou o programa falhar, a Dock volta a encolher como antes.
    property bool modoFixo: false
    P5Support.DataSource {
        id: cliques
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            const ok = (dados["exit code"] || 0) === 0;
            if (fonte.indexOf("--teste") !== -1) {
                dock.modoFixo = ok && (dados["stdout"] || "").trim() === "ok";
                dock.ajustarPainel();
            } else if (!ok && dock.modoFixo) {
                dock.modoFixo = false;      // falhou: volta ao modo antigo
                dock.ajustarPainel();
            }
        }
    }
    Timer {
        interval: 3000
        running: true
        onTriggered: {}    // CarinaeOS: a janela da Dock já é só o vidro
    }
    function pontoNaDock(): point {
        return vidro.mapToGlobal(vidro.width / 2, vidro.height / 2);
    }
    property string ultimaForma: ""
    function enviarForma(): void {
        if (!modoFixo || !painel) {
            return;
        }
        // "dentro": a janela é só o vidro e aceita cliques toda; basta dizê-lo uma vez
        // (antes lançava-se um processo a cada entrada e saída do rato)
        if (dentro && ultimaForma === "tudo") {
            return;
        }
        const c = pontoNaDock();
        let cmd;
        if (ampliado || dentro) {
            cmd = "carinaeos-dock-cliques tudo " + Math.round(c.x) + " " + Math.round(c.y);
        } else {
            const a = vidro.mapToGlobal(0, 0);
            const b = vidro.mapToGlobal(vidro.width, vidro.height);
            const x0 = Math.floor(Math.min(a.x, b.x)), y0 = Math.floor(Math.min(a.y, b.y));
            const x1 = Math.ceil(Math.max(a.x, b.x)), y1 = Math.ceil(Math.max(a.y, b.y));
            cmd = "carinaeos-dock-cliques " + x0 + " " + y0 + " " + (x1 - x0) + " " + (y1 - y0)
                + " " + Math.round(c.x) + " " + Math.round(c.y);
        }
        ultimaForma = (ampliado || dentro) ? "tudo" : "vidro";
        // o mesmo comando duas vezes seguidas seria ignorado pelo DataSource
        cliques.connectSource(cmd + " #" + Date.now());
    }
    Timer {
        // junta várias mudanças (apps a abrir, tamanho, ecrã) num único pedido
        id: formaCliques
        interval: 120
        onTriggered: dock.enviarForma()
    }
    onLarguraRepousoChanged: if (modoFixo) formaCliques.restart()
    onWidthChanged: if (modoFixo) formaCliques.restart()
    onHeightChanged: if (modoFixo) formaCliques.restart()

    function centroRepouso(slot: int): real {
        let x = espaco + slot * (base + espaco) + base / 2 + sepAntes(slot) * largSep;
        if (lixeira && slot >= slots - 2) {
            x += separador;
        }
        return x;
    }

    function escala(slot: int): real {
        return 1;       // a lupa saiu: cada modelo tem a sua animação (Efeito.qml)
        if (!e.efeito) {
            return 1;
        }
        if (dentro) {
            // "planalto": o ícone debaixo do rato cresce quase todo, os vizinhos não
            const q = (ratoX - centroRepouso(slot)) / (base * 0.75);
            if (Math.abs(q) > 2) {
                return 1;
            }
            return 1 + (zoomDentro - 1) * forca * Math.exp(-Math.pow(q, 6));
        }
        const d = (ratoX - centroRepouso(slot)) / sigma;
        if (Math.abs(d) > 3) {
            return 1;
        }
        return 1 + (zoom - 1) * forca * Math.exp(-d * d);
    }

    // ---- modelo de tarefas (o mesmo do gestor de tarefas do Plasma) ---------
    TaskManager.ActivityInfo { id: activityInfo }

    readonly property TaskManager.TasksModel modelo: tasksModel

    TaskManager.TasksModel {
        id: tasksModel

        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity
        filterByActivity: true
        groupMode: TaskManager.TasksModel.GroupApplications
        sortMode: TaskManager.TasksModel.SortManual
        launchInPlace: true
        separateLaunchers: true
        hideActivatedLaunchers: true

        onLauncherListChanged: Plasmoid.configuration.launchers = launcherList
        Component.onCompleted: launcherList = Plasmoid.configuration.launchers
    }

    Connections {
        target: Plasmoid.configuration
        function onLaunchersChanged(): void {
            if (tasksModel.launcherList.toString() !== Plasmoid.configuration.launchers.toString()) {
                tasksModel.launcherList = Plasmoid.configuration.launchers;
            }
        }
    }

    // ---- estilos da Dock (escolhidos no Supernova) -----------------------------
    // inspirados nos temas do "Windows 11 Taskbar Styler" do Windhawk e no macOS
    property string estilo: "fluent"          // padrão do CarinaeOS (os outros ficam no Supernova)
    property bool rodaVolume: true          // roda do rato sobre a Dock muda o volume
    property int passoVolume: 5
    property string cliqueMeio: "nova"      // "nova" janela ou "fechar"
    // três modelos (os antigos caem no "fluent"):
    //   fluent  — escura; o ícone cresce um pouco e salta ao abrir (com efeito)
    //   simples — igual, sem efeitos: só o quadrado que acende debaixo do mouse
    //   icones  — sem fundo, só os ícones, com o mesmo quadrado ao passar o mouse
    readonly property var estilos: ({
        // Padrão: escura; holofote que desliza de ícone em ícone e o ícone sobe
        fluent:  { c1: Qt.rgba(0.10, 0.10, 0.13, 0.84), c2: Qt.rgba(0.07, 0.07, 0.10, 0.88), borda: Qt.rgba(1, 1, 1, 0.10), raio: 0.26, sombra: 0.25,
                   item: "tile", ind: "barra", efeito: true, anim: "luz" },
        // Sem efeitos: só o quadrado que acende
        simples: { c1: Qt.rgba(0.10, 0.10, 0.13, 0.84), c2: Qt.rgba(0.07, 0.07, 0.10, 0.88), borda: Qt.rgba(1, 1, 1, 0.10), raio: 0.26, sombra: 0.25,
                   item: "tile", ind: "barra", efeito: false, anim: "nenhuma" },
        // Só ícones: sem fundo; ondas como um sonar
        icones:  { c1: "transparent", c2: "transparent", borda: "transparent", raio: 0, sombra: 0, fundo: "nenhum",
                   item: "tile", ind: "barra", margem: 0.2, efeito: true, anim: "onda" },
        // Órbita: escura com um toque azul-esverdeado (as cores do logo); anel a girar à volta do ícone
        orbita:  { c1: Qt.rgba(0.09, 0.08, 0.17, 0.86), c2: Qt.rgba(0.05, 0.05, 0.11, 0.90), borda: Qt.rgba(0.31, 0.78, 0.86, 0.22), raio: 0.5, sombra: 0.25,
                   item: "tile", ind: "ponto", efeito: true, anim: "orbita" },
        // Vidro: translúcido, com brilho em cima; o ícone inclina-se para o mouse
        glass:   { c1: Qt.rgba(1, 1, 1, 0.12), c2: Qt.rgba(1, 1, 1, 0.03), borda: Qt.rgba(1, 1, 1, 0.45),
                   raio: 0.42, sombra: 0.14, item: "tile", ind: "barra", efeito: true, brilho: true, anim: "inclinar" },
        // Windows 11: barra a toda a largura, ícones ao centro com o Iniciar e a Pesquisa, relógio à direita
        windows: { c1: Qt.rgba(0.125, 0.125, 0.125, 0.86), c2: Qt.rgba(0.11, 0.11, 0.11, 0.90), borda: "transparent",
                   raio: 0, sombra: 0, item: "tile", ind: "linha", efeito: true, total: true, win: true, anim: "windows",
                   espaco: 0.1, margem: 0.1, icone: 0.6 },
        // GNOME: pílula, mais transparente, ponto por baixo da app aberta
        gnome:   { c1: Qt.rgba(0.10, 0.10, 0.12, 0.52), c2: Qt.rgba(0.10, 0.10, 0.12, 0.60), borda: Qt.rgba(1, 1, 1, 0.08),
                   raio: 0.5, sombra: 0.10, item: "tile", ind: "ponto", efeito: true, anim: "onda" }
    })
    property bool semEfeitos: false        // sem zoom, sem sombra, sem salto
    readonly property var e: {
        const base = estilos[estilo] || estilos.fluent;
        return semEfeitos ? Object.assign({}, base, { efeito: false, sombra: 0 }) : base;
    }
    // a animação ao passar o mouse: a do modelo, ou a escolhida à parte nas Configurações
    property string animacaoEscolhida: ""
    readonly property var animacoesValidas: ["luz", "orbita", "onda", "inclinar", "nenhuma"]
    readonly property string animacao: semEfeitos ? (win ? "windows" : "nenhuma")
        : win ? "windows"
        : (animacoesValidas.indexOf(animacaoEscolhida) !== -1 ? animacaoEscolhida : (e.anim || "nenhuma"))

    // ---- holofote (animação "luz"): desliza para o ícone debaixo do mouse ------------------------
    property Item foco: null
    property real focoX: 0
    function focar(item: Item, sim: bool): void {
        if (sim) {
            largar.stop();
            foco = item;
            focoX = item.mapToItem(palco, item.width / 2, 0).x;
        } else if (foco === item) {
            largar.restart();
        }
    }
    Timer { id: largar; interval: 140; onTriggered: dock.foco = null }

    // ---- definições vindas do Supernova -------------------------------------
    // o Supernova escreve ~/.config/carinaeos-dock.json; a Dock lê-o e aplica.
    property string ultimaConfig: ""
    P5Support.DataSource {
        id: leitor
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            const txt = (dados["stdout"] || "").trim();
            const partes = txt.split("\n===FILA===\n");
            const fila = (partes[1] || "").split("\n").filter(l => l.trim() !== "");
            for (const url of fila) {
                if (tasksModel.launcherPosition(url) === -1) tasksModel.requestAddLauncher(url);
            }
            const cfg = (partes[0] || "").replace("===FILA===", "").trim();
            if (!cfg || cfg === dock.ultimaConfig) return;
            dock.ultimaConfig = cfg;
            try {
                const c = JSON.parse(cfg);
                const conf = Plasmoid.configuration;
                if (c.iconSize !== undefined && conf.iconSize !== c.iconSize) conf.iconSize = c.iconSize;
                if (c.zoom !== undefined && Math.abs(conf.zoom - c.zoom) > 0.001) conf.zoom = c.zoom;
                if (c.bounce !== undefined && conf.bounce !== c.bounce) conf.bounce = c.bounce;
                if (c.showTrash !== undefined && conf.showTrash !== c.showTrash) conf.showTrash = c.showTrash;
                if (c.estilo !== undefined) dock.estilo = c.estilo;
                if (c.semEfeitos !== undefined) dock.semEfeitos = c.semEfeitos;
                if (c.rodaVolume !== undefined) dock.rodaVolume = c.rodaVolume;
                if (c.passoVolume !== undefined) dock.passoVolume = c.passoVolume;
                if (c.cliqueMeio !== undefined) dock.cliqueMeio = c.cliqueMeio;
                dock.animacaoEscolhida = c.animacao || "";
                if (c.separatorWidth !== undefined && conf.separatorWidth !== c.separatorWidth) conf.separatorWidth = c.separatorWidth;
                if (c.separatorColor !== undefined && conf.separatorColor !== c.separatorColor) conf.separatorColor = c.separatorColor;
            } catch (e) {
                console.warn("carinaeos-dock.json inválido:", e);
            }
        }
    }
    // 1,5 s: só o ficheiro de configuração (é minúsculo) -> mudar de estilo é quase imediato
    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: leitor.connectSource("cat \"$HOME/.config/carinaeos-dock.json\" 2>/dev/null; true")
    }
    // 30 s: a fila de "Adicionar à Dock" (mexe em ficheiros e arranca processos)
    Timer {
        interval: 30000
        running: !dock.ampliado
        repeat: true
        onTriggered: leitor.connectSource("echo; echo ===FILA===; "
            + "f=\"$HOME/.cache/carinaeos/dock-adicionar\"; [ -s \"$f\" ] && { cat \"$f\"; rm -f \"$f\"; }; true")
    }

    // ---- Launchpad: estrela da Dock e tecla Meta ----------------------------
    Lancador {
        id: lancador
        dock: dock
        visualParent: estrela
    }
    function abrirMenu(): void {
        lancador.toggle();
    }
    Connections {
        target: Plasmoid
        function onActivated(): void {
            lancador.toggle();
        }
    }

    // cadeado: aplicativos trancados com senha (carinaeos-cadeado)
    property var trancados: []
    P5Support.DataSource {
        id: lerTrancados
        engine: "executable"
        connectedSources: []
        onNewData: (f, d) => {
            disconnectSource(f);
            try { dock.trancados = JSON.parse((d["stdout"] || "").trim()).apps || []; } catch (e) {}
        }
    }
    P5Support.DataSource { id: cadeadoDock; engine: "executable"; connectedSources: []; onNewData: (f) => { disconnectSource(f); dock.lerCadeado(); } }
    function lerCadeado(): void {
        lerTrancados.connectSource("carinaeos-cadeado estado #" + Date.now());
    }
    // forçar o encerramento de um aplicativo travado (menu do botão direito)
    P5Support.DataSource {
        id: encerrador
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => disconnectSource(fonte)
    }
    function forcarEncerramento(pid: int, appId: string): void {
        encerrador.connectSource("carinaeos-encerrar --pid " + Math.max(0, pid || 0) + " --app '" + String(appId || "").replace(/[^A-Za-z0-9._-]/g, "") + "' #" + Date.now());
    }

    function alternarTranca(appId: string): void {
        if (appId === "") return;
        const acao = trancados.indexOf(appId) !== -1 ? "destrancar-app" : "trancar-app";
        cadeadoDock.connectSource("carinaeos-cadeado " + acao + " '" + appId.replace(/'/g, "") + "' #" + Date.now());
    }

    Item {
    id: palco
    width: dock.vertical ? dock.height : dock.width
    height: dock.vertical ? dock.width : dock.height
    anchors.centerIn: parent
    rotation: dock.angulo

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) {
                dock.ratoEntrou();
            } else {
                dock.sobre = false;
                encolher.restart();
            }
        }
        onPointChanged: {
            if (hovered) {
                const topo = palco.height - dock.baixo - dock.margem * 2 - dock.base * (1 + (dock.zoom - 1) * dock.forca) - dock.margem;
                dock.sobre = point.position.y >= topo;
                const x = point.position.x - dock.inicioRepouso;
                if (dock.forca < 0.02) {
                    dock.ratoX = x;     // entrada: começa logo no sítio certo
                }
                dock.ratoAlvo = x;
                dock.ratoX = x;
            }
        }
    }

    // ---- halo difuso (Liquid Glass) -------------------------------------------
    Item {
        id: halo
        visible: false
        anchors.horizontalCenter: vidro.horizontalCenter
        anchors.verticalCenter: vidro.verticalCenter
        width: vidro.width + 28
        height: vidro.height + 28
        Rectangle {
            id: haloForma
            anchors.fill: parent
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.16)
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: parent
            source: haloForma
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            opacity: 0.85
        }
    }

    // ---- vidro por baixo dos ícones -------------------------------------------
    Rectangle {
        id: vidro
        visible: dock.e.fundo !== "nenhum"
        anchors.horizontalCenter: fila.horizontalCenter
        anchors.bottom: parent.bottom
        readonly property bool total: dock.e.total === true
        anchors.bottomMargin: total ? 0 : dock.baixo
        width: total ? parent.width : fila.width + dock.espaco
        height: dock.base + dock.margem * 2
        radius: total ? 0 : Math.round(height * dock.e.raio)
        gradient: Gradient {
            GradientStop { position: 0; color: dock.e.c1 }
            GradientStop { position: 1; color: dock.e.c2 }
        }
        border.color: dock.e.borda
        border.width: total ? 0 : 1
        Rectangle {     // a barra a toda a largura tem só uma linha fina em cima (como no Windows 11)
            visible: vidro.total
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }
        Rectangle {     // sombra suave por baixo do vidro
            z: -1
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: -2
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, dock.e.sombra)
        }
        Rectangle {     // brilho de vidro (só no estilo glass)
            visible: dock.e.brilho === true
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0;    color: Qt.rgba(1, 1, 1, 0.16) }
                GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, 0.02) }
                GradientStop { position: 1;    color: Qt.rgba(1, 1, 1, 0.00) }
            }
        }
    }

    // ---- arrastar para a Dock: aplicativos (.desktop), pastas ou arquivos -------
    P5Support.DataSource {
        id: ajudante
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            for (const l of (dados["stdout"] || "").split("\n")) {
                const url = l.trim();
                if (url !== "" && tasksModel.launcherPosition(url) === -1) tasksModel.requestAddLauncher(url);
            }
        }
    }
    function citar(t: string): string {
        return "'" + t.replace(/'/g, "'\\''") + "'";
    }
    DropArea {
        id: soltar
        anchors.fill: vidro
        anchors.topMargin: -dock.base
        keys: ["text/uri-list"]
        onDropped: (d) => {
            if (!d.hasUrls) return;
            const caminhos = [];
            for (const u of d.urls) {
                const s = u.toString();
                if (s.endsWith(".desktop")) {
                    tasksModel.requestAddLauncher(s);
                } else if (s.startsWith("file://")) {
                    caminhos.push(dock.citar(decodeURIComponent(s.substring(7))));
                }
            }
            if (caminhos.length) ajudante.connectSource("carinaeos-dock-adicionar --imprimir " + caminhos.join(" "));
            d.accept(Qt.CopyAction);
        }
    }
    Rectangle {
        anchors.fill: vidro
        radius: vidro.radius
        visible: soltar.containsDrag
        color: Qt.rgba(1, 0.7, 0.43, 0.18)
        border.color: "#ffb46e"; border.width: 2
    }

    // roda do rato sobre a Dock: volume (como o mod "Taskbar Volume Control" do Windhawk)
    P5Support.DataSource { id: som; engine: "executable"; connectedSources: []; onNewData: (f) => disconnectSource(f) }
    WheelHandler {
        enabled: dock.rodaVolume
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (ev) => {
            const sobe = ev.angleDelta.y > 0;
            som.connectSource("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + dock.passoVolume + "%" + (sobe ? "+" : "-") + " #" + Date.now());
        }
    }
    Item {
        id: _fimVidro
        visible: false
    }

    // ---- holofote: um brilho por baixo do ícone que desliza de um para o outro ------------------
    Item {
        id: holofote
        readonly property bool ligado: dock.animacao === "luz"
        visible: ligado && opacity > 0.01
        opacity: ligado && dock.foco ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 260 } }
        width: dock.base * 1.6; height: dock.base * 1.25
        y: palco.height - dock.baixo - dock.margem - dock.base / 2 - height / 2
        x: dock.focoX - width / 2
        Behavior on x { enabled: holofote.opacity > 0.05; SpringAnimation { spring: 3.2; damping: 0.28; epsilon: 0.3 } }
        Rectangle {
            id: brilhoHolofote
            anchors.centerIn: parent
            width: parent.width * 0.7; height: parent.height * 0.62
            radius: height / 2
            color: Qt.rgba(1, 0.71, 0.43, 0.55)
            visible: false
            layer.enabled: true
        }
        MultiEffect {
            anchors.fill: brilhoHolofote
            anchors.margins: -dock.base * 0.35
            source: brilhoHolofote
            blurEnabled: true; blur: 1.0; blurMax: 40
            opacity: 0.85
        }
        Rectangle {     // a linha de luz no fundo do vidro
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 + dock.base / 2 + dock.margem * 0.55
            width: dock.base * 0.62; height: Math.max(2, dock.base * 0.05); radius: height / 2
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: Qt.rgba(1, 0.71, 0.43, 0) }
                GradientStop { position: 0.5; color: "#ffd2a0" }
                GradientStop { position: 1; color: Qt.rgba(1, 0.71, 0.43, 0) }
            }
        }
    }

    Row {
        id: fila
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        height: parent.height
        spacing: dock.espaco
        leftPadding: dock.espaco / 2
        rightPadding: dock.espaco / 2

        // estrela do Launchpad, no meio
        Item {
            id: estrela
            readonly property real s: dock.escala(dock.meio)
            property real pulo: 0
            width: dock.larguraSlot(s)
            height: fila.height

            Item {      // os ícones desenham-se uma vez no tamanho máximo e só mudam de escala (sem redesenhar a cada movimento do rato)
                id: estrelaIcone
                rotation: -dock.angulo
                transform: estrelaEfeito.transformacoes
                width: dock.base * estrela.s
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: dock.desvio(dock.meio)
                y: dock.yIcone(parent.height, height, estrela.pulo)
                Kirigami.Icon {
                    source: "carinaeos-estrela"
                    active: estrelaRato.containsMouse
                    width: Math.round(dock.base * Math.max(1, dock.dentro ? dock.zoomDentro : dock.zoom))
                    height: width
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: parent.height * (1 - (dock.e.icone || 1)) / 2
                    transformOrigin: Item.Bottom
                    scale: parent.width / width * (dock.e.icone || 1)
                    smooth: true
                }
            }
            FundoIcone { dock: dock; alvo: estrelaIcone; ativo: estrelaRato.containsMouse; pressionado: estrelaRato.pressed }
            Efeito {
                id: estrelaEfeito
                ponto: estrelaRato.containsMouse ? estrelaRato.mapToItem(estrelaIcone, estrelaRato.mouseX, estrelaRato.mouseY) : Qt.point(-1, -1)
                dock: dock; alvo: estrelaIcone
                ativo: estrelaRato.containsMouse; pressionado: estrelaRato.pressed
                onAtivoChanged: dock.focar(estrelaIcone, ativo)
            }
            Rotulo {
                alvo: estrelaIcone
                texto: "Aplicativos"
                mostrar: estrelaRato.containsMouse
                dock: dock
            }
            MouseArea {
                id: estrelaRato
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: dock.baixo + dock.margem * 2 + estrelaIcone.height
                hoverEnabled: true
                onClicked: dock.abrirMenu()
            }
        }

        // Windows 11: a caixa "Pesquisar" logo a seguir ao Iniciar (abre o Comando, como o Ctrl+Espaço)
        Item {
            visible: dock.win
            width: visible ? dock.larguraPesquisa : 0
            height: fila.height
            Rectangle {
                anchors.verticalCenter: parent.bottom
                anchors.verticalCenterOffset: -(dock.margem + dock.base / 2)
                width: parent.width; height: 32; radius: 16
                color: pesquisaRato.pressed ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, pesquisaRato.containsMouse ? 0.10 : 0.065)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.07)
                IconeBranco {
                    id: lupa
                    nome: "search"
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: lupa.right; anchors.leftMargin: 10
                    text: "Pesquisar"
                    color: Qt.rgba(1, 1, 1, 0.72)
                    font.pixelSize: 13
                }
                // a mesma pesquisa do Ctrl+Espaço (o Comando); se não houver, abre o Launchpad
                MouseArea { id: pesquisaRato; anchors.fill: parent; hoverEnabled: true
                            onClicked: Sistema.executar("command -v carinaeos-comando >/dev/null && carinaeos-comando || aurora --enviar lancador") }
            }
        }

        // segunda metade das apps (e as abertas que não estão fixadas)
        Repeater {
            model: tasksModel
            delegate: Tarefa {
                dock: dock
                parte: 1
            }
        }

        // separador + lixeira
        Item {
            visible: dock.lixeira
            width: dock.separador - dock.espaco
            height: fila.height
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: dock.baixo + dock.margem * 1.3
                width: dock.grossuraSeparador
                height: dock.base * 0.8
                radius: width / 2
                color: dock.corSeparador
            }
        }
        Pilha {
            visible: dock.lixeira
            dock: dock
            slot: dock.slots - 2
        }
        Item {
            id: lixo
            visible: dock.lixeira
            readonly property real s: dock.escala(dock.slots - 1)
            width: dock.larguraSlot(s)
            height: fila.height
            Item {      // os ícones desenham-se uma vez no tamanho máximo e só mudam de escala (sem redesenhar a cada movimento do rato)
                id: lixoIcone
                rotation: -dock.angulo
                transform: lixoEfeito.transformacoes
                width: dock.base * lixo.s
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: dock.desvio(dock.slots - 1)
                y: dock.yIcone(parent.height, height, 0)
                Kirigami.Icon {
                    source: "user-trash"
                    active: lixoRato.containsMouse
                    width: Math.round(dock.base * Math.max(1, dock.dentro ? dock.zoomDentro : dock.zoom))
                    height: width
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: parent.height * (1 - (dock.e.icone || 1)) / 2
                    transformOrigin: Item.Bottom
                    scale: parent.width / width * (dock.e.icone || 1)
                    smooth: true
                }
            }
            FundoIcone { dock: dock; alvo: lixoIcone; ativo: lixoRato.containsMouse; pressionado: lixoRato.pressed }
            Efeito {
                id: lixoEfeito
                ponto: lixoRato.containsMouse ? lixoRato.mapToItem(lixoIcone, lixoRato.mouseX, lixoRato.mouseY) : Qt.point(-1, -1)
                dock: dock; alvo: lixoIcone
                ativo: lixoRato.containsMouse; pressionado: lixoRato.pressed
                onAtivoChanged: dock.focar(lixoIcone, ativo)
            }
            Rotulo {
                alvo: lixoIcone
                texto: "Lixeira"
                mostrar: lixoRato.containsMouse
                dock: dock
            }
            MouseArea {
                id: lixoRato
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: dock.baixo + dock.margem * 2 + lixoIcone.height
                hoverEnabled: true
                onClicked: Qt.openUrlExternally("trash:/")
            }
        }
    }

    // ---- Windows 11: bandeja à direita (ícones, relógio, notificações, mostrar a área de trabalho) ----
    Row {
        id: bandeja
        visible: dock.win
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: dock.alturaVidro
        spacing: 2
        property date agora: new Date()
        Timer { interval: 5000; running: bandeja.visible; repeat: true; triggeredOnStart: true; onTriggered: bandeja.agora = new Date() }

        BotaoBandeja {
            largura: 32
            dica: "Mostrar ícones ocultos"
            IconeBranco { anchors.centerIn: parent; nome: "go-up" }
            onClicado: Sistema.executar("carinaeos-configuracoes")
        }
        BotaoBandeja {
            largura: 74
            dica: "Rede e som"
            Row {
                anchors.centerIn: parent
                spacing: 10
                IconeBranco { nome: "network-wired" }
                IconeBranco { nome: "audio-volume-high" }
            }
            onClicado: Sistema.executar("carinaeos-configuracoes som")
        }
        BotaoBandeja {
            largura: horas.implicitWidth + 22
            dica: bandeja.agora.toLocaleDateString(Qt.locale(), "dddd, d 'de' MMMM 'de' yyyy")
            Column {
                id: horas
                anchors.centerIn: parent
                spacing: 1
                Text { anchors.right: parent.right; text: Qt.formatTime(bandeja.agora, "HH:mm"); color: "white"; font.pixelSize: 12 }
                Text { anchors.right: parent.right; text: Qt.formatDate(bandeja.agora, "dd/MM/yyyy"); color: "white"; font.pixelSize: 12 }
            }
            onClicado: Sistema.executar("carinaeos-configuracoes datahora")
        }
        BotaoBandeja {
            largura: 32
            dica: "Notificações"
            IconeBranco { anchors.centerIn: parent; nome: "notifications" }
            onClicado: Sistema.executar("carinaeos-configuracoes notificacoes")
        }
        Item {      // a faixa fina no canto: mostrar a área de trabalho
            width: 12
            height: parent.height
            Rectangle {
                anchors.left: parent.left; anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                width: 1; height: 16
                color: Qt.rgba(1, 1, 1, mesaRato.containsMouse ? 0.45 : 0.22)
            }
            MouseArea { id: mesaRato; anchors.fill: parent; hoverEnabled: true; onClicked: Sistema.alternarMesa() }
        }
    }
    }

    component BotaoBandeja: Item {
        id: bb
        property int largura: 32
        property string dica: ""
        default property alias conteudo: dentro.data
        signal clicado()
        width: largura
        height: parent ? parent.height : 48
        Rectangle {
            id: dentro
            anchors.centerIn: parent
            width: parent.width; height: 40; radius: 5
            color: bbRato.pressed ? Qt.rgba(1, 1, 1, 0.045) : Qt.rgba(1, 1, 1, bbRato.containsMouse ? 0.075 : 0)
            border.width: bbRato.containsMouse ? 1 : 0
            border.color: Qt.rgba(1, 1, 1, 0.06)
        }
        MouseArea { id: bbRato; anchors.fill: parent; hoverEnabled: true; onClicked: bb.clicado() }
        Rotulo { alvo: dentro; texto: bb.dica; mostrar: bbRato.containsMouse; dock: dock }
    }
    component IconeBranco: Item {
        id: ib
        property string nome
        width: 16; height: 16
        Kirigami.Icon { id: ibFonte; anchors.fill: parent; source: ib.nome; visible: false; layer.enabled: true }
        MultiEffect {
            anchors.fill: parent
            source: ibFonte
            brightness: 1.0
            colorization: 1.0
            colorizationColor: "white"
        }
    }
}
