/*
    CarinaeOS — Dock
    Como no macOS: os ícones crescem numa onda suave à volta do rato e sobem
    acima do fundo de vidro, o nome da app aparece por cima, as apps abertas
    têm um ponto, os ícones saltam ao abrir. A estrela no centro abre o
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
    readonly property int espaco: Math.round(base * 0.16)
    readonly property int margem: Math.round(base * 0.16)        // dentro do vidro
    readonly property int baixo: Math.round(base * 0.14)         // vidro -> fundo do ecrã
    readonly property real sigma: base * 1.35                    // largura da onda
    readonly property int separador: Math.round(base * 0.5)
    readonly property bool lixeira: Plasmoid.configuration.showTrash

    readonly property int fixadas: tasksModel.launcherList.length
    readonly property int meio: Math.ceil(fixadas / 2)           // a estrela fica aqui
    // apps + estrela + [Downloads + lixeira]
    readonly property int slots: tasksModel.count + 1 + (lixeira ? 2 : 0)
    readonly property real larguraRepouso: slots * (base + espaco) + espaco + (lixeira ? separador : 0)
    // espaço reservado para a ampliação (o painel não muda de tamanho)
    readonly property real folga: base * (zoom - 1) * 2.6

    Layout.minimumWidth: larguraRepouso + folga
    Layout.preferredWidth: larguraRepouso + folga
    Layout.maximumWidth: larguraRepouso + folga
    Layout.fillHeight: true

    // ---- onda de ampliação -------------------------------------------------
    // calculada nas posições de repouso: o tamanho depende só do rato.
    readonly property real inicioRepouso: (width - larguraRepouso) / 2
    property real ratoAlvo: -10000
    property real ratoX: -10000
    // o rato é seguido com um pequeno atraso: a onda desliza em vez de saltar
    Behavior on ratoX {
        enabled: dock.forca > 0.02
        NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
    }
    // só amplia com o rato sobre a faixa da Dock (não no espaço vazio por cima)
    property bool sobre: false
    property real forca: sobre ? 1 : 0
    Behavior on forca { NumberAnimation { duration: dock.sobre ? 200 : 340; easing.type: Easing.OutCubic } }

    function centroRepouso(slot: int): real {
        let x = espaco + slot * (base + espaco) + base / 2;
        if (lixeira && slot >= slots - 2) {
            x += separador;
        }
        return x;
    }

    function escala(slot: int): real {
        const d = (ratoX - centroRepouso(slot)) / sigma;
        if (Math.abs(d) > 3) {
            return 1;
        }
        return 1 + (zoom - 1) * forca * Math.exp(-d * d);
    }

    HoverHandler {
        id: hover
        onHoveredChanged: if (!hovered) dock.sobre = false
        onPointChanged: {
            if (hovered) {
                const topo = dock.height - dock.baixo - dock.margem * 2 - dock.base * (1 + (dock.zoom - 1) * dock.forca) - dock.margem;
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
    property string estilo: "mac"
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
        neon:         { c1: Qt.rgba(0.07, 0.04, 0.12, 0.78), c2: Qt.rgba(0.10, 0.04, 0.12, 0.78), borda: "#ff6f91", raio: 0.34, sombra: 0.0, brilho: true }
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
                if (c.rodaVolume !== undefined) dock.rodaVolume = c.rodaVolume;
                if (c.passoVolume !== undefined) dock.passoVolume = c.passoVolume;
                if (c.cliqueMeio !== undefined) dock.cliqueMeio = c.cliqueMeio;
            } catch (e) {
                console.warn("carinaeos-dock.json inválido:", e);
            }
        }
    }
    Timer {
        interval: 1200
        running: true
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

    // ---- vidro por baixo dos ícones -------------------------------------------
    Rectangle {
        id: vidro
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
            width: dock.base * s
            height: fila.height

            Kirigami.Icon {
                id: estrelaIcone
                source: "carinaeos-estrela"
                width: dock.base * estrela.s
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - dock.baixo - dock.margem - height - estrela.pulo
                active: estrelaRato.containsMouse
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
                width: 1
                height: dock.base * 0.8
                color: Qt.rgba(1, 1, 1, 0.25)
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
            width: dock.base * s
            height: fila.height
            Kirigami.Icon {
                id: lixoIcone
                source: "user-trash"
                width: dock.base * lixo.s
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - dock.baixo - dock.margem - height
                active: lixoRato.containsMouse
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
}
