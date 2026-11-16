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

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.plasma5support as P5Support

PlasmoidItem {
    id: dock

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    // ---- medidas -----------------------------------------------------------
    readonly property int base: Plasmoid.configuration.iconSize
    readonly property real zoom: Plasmoid.configuration.zoom
    readonly property int espaco: Math.round(base * (e.espaco !== undefined ? e.espaco : 0.16))
    readonly property int margem: Math.round(base * (e.margem !== undefined ? e.margem : 0.16))        // dentro do vidro
    readonly property int baixo: Math.round(base * 0.14)         // vidro -> fundo do ecrã
    readonly property real sigma: base * 1.35                    // largura da onda
    readonly property int separador: Math.round(base * 0.5)
    readonly property bool lixeira: Plasmoid.configuration.showTrash

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
    // ampliação: "dentro" (padrão) = só o ícone debaixo do rato cresce um pouco, sem sair da Dock;
    // "onda" = como no macOS, os ícones crescem numa onda e sobem acima do vidro
    property string ampliacao: "dentro"
    readonly property bool dentro: ampliacao !== "onda"
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
    onDentroChanged: ajustarPainel()
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
        onTriggered: cliques.connectSource("carinaeos-dock-cliques --teste")
    }
    function pontoNaDock(): point {
        return vidro.mapToGlobal(vidro.width / 2, vidro.height / 2);
    }
    function enviarForma(): void {
        if (!modoFixo || !painel) {
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
    readonly property var estilos: ({
        mac:          { c1: Qt.rgba(1, 1, 1, 0.26), c2: Qt.rgba(1, 1, 1, 0.16), borda: Qt.rgba(1, 1, 1, 0.38), raio: 0.30, sombra: 0.12 },
        escuro:       { c1: Qt.rgba(0.12, 0.11, 0.15, 0.62), c2: Qt.rgba(0.08, 0.07, 0.10, 0.70), borda: Qt.rgba(1, 1, 1, 0.14), raio: 0.30, sombra: 0.2 },
        transparente: { c1: "transparent", c2: "transparent", borda: "transparent", raio: 0.3, sombra: 0 },
        bolhas:       { c1: Qt.rgba(1, 1, 1, 0.34), c2: Qt.rgba(0.85, 0.92, 1, 0.20), borda: Qt.rgba(1, 1, 1, 0.65), raio: 0.5, sombra: 0.15 },
        squircle:     { c1: Qt.rgba(0.20, 0.20, 0.22, 0.80), c2: Qt.rgba(0.16, 0.16, 0.18, 0.85), borda: Qt.rgba(1, 1, 1, 0.10), raio: 0.38, sombra: 0.25 },
        rosepine:     { c1: "#e6191724", c2: "#e61f1d2e", borda: "#ebbcba", raio: 0.32, sombra: 0.2 },
        xp:           { c1: "#3a81f3", c2: "#245edb", borda: "#9ec2ff", raio: 0.14, sombra: 0.3 },
        vista:        { c1: Qt.rgba(0.35, 0.45, 0.55, 0.45), c2: Qt.rgba(0.02, 0.03, 0.05, 0.75), borda: Qt.rgba(1, 1, 1, 0.45), raio: 0.16, sombra: 0.35 },
        translucido:  { c1: Qt.rgba(1, 1, 1, 0.08), c2: Qt.rgba(1, 1, 1, 0.05), borda: Qt.rgba(1, 1, 1, 0.12), raio: 0.30, sombra: 0 },
        docklike:     { c1: Qt.rgba(0.14, 0.14, 0.14, 0.72), c2: Qt.rgba(0.10, 0.10, 0.10, 0.72), borda: Qt.rgba(1, 1, 1, 0.18), raio: 0.26, sombra: 0.2 },
        matter:       { c1: "#2b2930", c2: "#25232a", borda: "transparent", raio: 0.5, sombra: 0.3 },
        lucent:       { c1: Qt.rgba(1, 1, 1, 0.50), c2: Qt.rgba(1, 1, 1, 0.36), borda: Qt.rgba(1, 1, 1, 0.85), raio: 0.34, sombra: 0.1 },
        neon:         { c1: Qt.rgba(0.07, 0.04, 0.12, 0.78), c2: Qt.rgba(0.10, 0.04, 0.12, 0.78), borda: "#ff6f91", raio: 0.34, sombra: 0.0, brilho: true },
        // ---- modelos novos (fundo: barra|nenhum; item: por trás de cada ícone; ind: indicador das apps abertas)
        vidro:        { c1: Qt.rgba(1, 1, 1, 0.22), c2: Qt.rgba(0.75, 0.82, 1, 0.12), borda: Qt.rgba(1, 1, 1, 0.48), raio: 0.42, sombra: 0.16,
                        reflexo: true, ind: "barra" },
        fluent:       { c1: Qt.rgba(0.10, 0.10, 0.13, 0.84), c2: Qt.rgba(0.07, 0.07, 0.10, 0.88), borda: Qt.rgba(1, 1, 1, 0.10), raio: 0.26, sombra: 0.25,
                        item: "tile", ind: "barra" },
        minimalista:  { c1: "transparent", c2: "transparent", borda: "transparent", raio: 0, sombra: 0, fundo: "nenhum", linha: true, ind: "barra", margem: 0.2 },
        colorida:     { c1: Qt.rgba(0.05, 0.07, 0.20, 0.86), c2: Qt.rgba(0.09, 0.06, 0.24, 0.90), borda: "transparent", raio: 0.5, sombra: 0.2,
                        bordaGrad: ["#4f8bff", "#a66bff", "#ff6f91", "#ffb46e"], item: "circulo", ind: "ponto", margem: 0.22 },
        orbital:      { c1: "transparent", c2: "transparent", borda: "transparent", raio: 0, sombra: 0, fundo: "nenhum",
                        item: "bolha", ind: "brilho", espaco: 0.34, margem: 0.24 },
        hexagonal:    { c1: "transparent", c2: "transparent", borda: "transparent", raio: 0, sombra: 0, fundo: "nenhum",
                        item: "hex", ind: "brilho", espaco: 0.06, margem: 0.24, afastar: 0.5 },
        icones:       { c1: "transparent", c2: "transparent", borda: "transparent", raio: 0, sombra: 0, fundo: "nenhum",
                        ind: "brilho", espaco: 0.08, margem: 0.2, afastar: 0.45 },
        redondos:     { c1: "transparent", c2: "transparent", borda: "transparent", raio: 0, sombra: 0, fundo: "nenhum",
                        item: "disco", icone: 0.72, ind: "brilho", espaco: 0.1, margem: 0.2, afastar: 0.45 },
        aereo:        { c1: Qt.rgba(0.60, 0.70, 1, 0.18), c2: Qt.rgba(0.35, 0.45, 0.95, 0.12), borda: Qt.rgba(0.78, 0.86, 1, 0.55), raio: 0.5, sombra: 0.1,
                        brilhoBase: true, ind: "brilho", margem: 0.22 }
    })
    readonly property var e: estilos[estilo] || estilos.mac

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
                if (c.ampliacao !== undefined) dock.ampliacao = c.ampliacao;
                if (c.rodaVolume !== undefined) dock.rodaVolume = c.rodaVolume;
                if (c.passoVolume !== undefined) dock.passoVolume = c.passoVolume;
                if (c.cliqueMeio !== undefined) dock.cliqueMeio = c.cliqueMeio;
            } catch (e) {
                console.warn("carinaeos-dock.json inválido:", e);
            }
        }
    }
    Timer {
        // lê as definições do Supernova e a fila de "Adicionar à Dock": cada leitura arranca um processo,
        // por isso só de 4 em 4 s e nunca enquanto o rato está na Dock (era um dos solavancos da ampliação)
        interval: 4000
        running: !dock.ampliado
        repeat: true
        triggeredOnStart: true
        // a fila (~/.cache/carinaeos/dock-adicionar) e lida e apagada de uma vez
        onTriggered: leitor.connectSource("cat \"$HOME/.config/carinaeos-dock.json\" 2>/dev/null; echo; echo ===FILA===; "
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

    // ---- vidro por baixo dos ícones -------------------------------------------
    // Colorida: contorno em degradê (fica por trás do vidro, 2 px maior)
    Rectangle {
        visible: !!dock.e.bordaGrad && dock.e.fundo !== "nenhum"
        anchors.fill: vidro; anchors.margins: -2
        radius: vidro.radius + 2
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: dock.e.bordaGrad ? dock.e.bordaGrad[0] : "transparent" }
            GradientStop { position: 0.35; color: dock.e.bordaGrad ? dock.e.bordaGrad[1] : "transparent" }
            GradientStop { position: 0.7; color: dock.e.bordaGrad ? dock.e.bordaGrad[2] : "transparent" }
            GradientStop { position: 1.0; color: dock.e.bordaGrad ? dock.e.bordaGrad[3] : "transparent" }
        }
    }
    // Orbital: anel de luz por baixo das bolhas
    Rectangle {
        visible: dock.e.anel === true
        anchors.horizontalCenter: fila.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: dock.baixo
        width: fila.width + dock.base * 0.3; height: dock.base * 0.42
        radius: height / 2
        color: Qt.rgba(0.35, 0.6, 1, 0.07)
        border.width: 2; border.color: Qt.rgba(0.45, 0.72, 1, 0.75)
        Rectangle {
            anchors.fill: parent; anchors.margins: -3; radius: height / 2
            color: "transparent"; border.width: 3; border.color: Qt.rgba(0.45, 0.72, 1, 0.18)
        }
    }
    // Minimalista: só uma linha fina por baixo dos ícones
    Rectangle {
        visible: dock.e.linha === true
        anchors.horizontalCenter: fila.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: dock.baixo + Math.max(2, dock.margem * 0.25) - 1
        width: fila.width; height: 2; radius: 1
        color: Qt.rgba(1, 1, 1, 0.35)
    }
    Rectangle {
        id: vidro
        visible: dock.e.fundo !== "nenhum"
        anchors.horizontalCenter: fila.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dock.baixo
        width: fila.width + dock.espaco
        height: dock.base + dock.margem * 2
        radius: Math.round(height * dock.e.raio)
        // o vidro muda com o estilo escolhido no Supernova (Mac claro por omissão)
        gradient: Gradient {
            GradientStop { position: 0; color: dock.e.c1 }
            GradientStop { position: 1; color: dock.e.c2 }
        }
        border.color: dock.e.borda
        border.width: dock.e.brilho ? 2 : 1
        Behavior on radius { NumberAnimation { duration: 200 } }
        Rectangle {     // sombra suave por baixo do vidro
            z: -1
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: -2
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, dock.e.sombra)
        }
        Rectangle {     // neon: segunda borda a brilhar
            visible: dock.e.brilho === true
            anchors.fill: parent; anchors.margins: -3
            radius: parent.radius + 3; color: "transparent"
            border.width: 2; border.color: "#ffb46e"; opacity: 0.45
            SequentialAnimation on opacity {
                running: dock.e.brilho === true; loops: Animation.Infinite
                NumberAnimation { to: 0.15; duration: 1600; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.55; duration: 1600; easing.type: Easing.InOutSine }
            }
        }
        // Vidro: reflexo na metade de cima
        Rectangle {
            visible: dock.e.reflexo === true
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 1
            height: parent.height * 0.5; radius: parent.radius
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.20) }
                GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
        // Aéreo: linha de luz azul por baixo, dentro do vidro
        Rectangle {
            visible: dock.e.brilhoBase === true
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 2
            width: parent.width - parent.radius * 2; height: 2; radius: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Qt.rgba(0.4, 0.7, 1, 0) }
                GradientStop { position: 0.5; color: Qt.rgba(0.5, 0.8, 1, 0.9) }
                GradientStop { position: 1.0; color: Qt.rgba(0.4, 0.7, 1, 0) }
            }
        }
        // brilho do topo (XP e Vista)
        Rectangle {
            visible: dock.estilo === "xp" || dock.estilo === "vista"
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 2
            height: parent.height * 0.45; radius: parent.radius
            color: Qt.rgba(1, 1, 1, dock.estilo === "xp" ? 0.18 : 0.12)
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

    Row {
        id: fila
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        height: parent.height
        spacing: dock.espaco
        leftPadding: dock.espaco / 2
        rightPadding: dock.espaco / 2

        // primeira metade das apps
        Repeater {
            model: tasksModel
            delegate: Tarefa {
                dock: dock
                parte: 0
            }
        }

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
            FundoIcone { dock: dock; alvo: estrelaIcone; ativo: estrelaRato.containsMouse }
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
            FundoIcone { dock: dock; alvo: lixoIcone; ativo: lixoRato.containsMouse }
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
    }
}
