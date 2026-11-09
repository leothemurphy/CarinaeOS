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
    readonly property int slots: tasksModel.count + 1 + (lixeira ? 1 : 0)
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
        if (lixeira && slot === slots - 1) {
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

    // ---- Launchpad: estrela da Dock e tecla Meta ----------------------------
    Lancador {
        id: lancador
        dock: dock
        visualParent: estrela
    }
    function abrirMenu(): void {
        lancador.toggle();
    }
    Plasmoid.onActivated: lancador.toggle()

    // ---- vidro por baixo dos ícones -------------------------------------------
    Rectangle {
        id: vidro
        anchors.horizontalCenter: fila.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dock.baixo
        width: fila.width + dock.espaco
        height: dock.base + dock.margem * 2
        radius: Math.round(height * 0.3)
        color: Qt.rgba(0.09, 0.08, 0.13, 0.58)
        border.color: Qt.rgba(1, 1, 1, 0.16)
        border.width: 1
        Rectangle {     // brilho subtil na aresta de cima, como vidro
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
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
