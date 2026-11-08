/*
    CarinaeOS — Dock
    Ícones que crescem ao passar o rato (como no macOS), estrela de menu no
    centro, ponto por baixo das apps abertas, salto ao abrir e lixeira no fim.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: dock

    preferredRepresentation: fullRepresentation

    // ---- medidas -----------------------------------------------------------
    readonly property int base: Plasmoid.configuration.iconSize
    readonly property real zoom: Plasmoid.configuration.zoom
    readonly property int espaco: Math.round(base * 0.2)
    readonly property real alcance: base * 2.4          // até onde a onda chega
    readonly property int separador: Math.round(base * 0.45)
    readonly property bool lixeira: Plasmoid.configuration.showTrash

    readonly property int fixadas: tasksModel.launcherList.length
    readonly property int meio: Math.ceil(fixadas / 2)  // a estrela fica aqui
    readonly property int slots: tasksModel.count + 1 + (lixeira ? 1 : 0)
    readonly property real larguraRepouso: slots * (base + espaco) + espaco + (lixeira ? separador : 0)
    // espaço reservado para a ampliação: assim o painel não muda de tamanho
    // enquanto o rato passa (evita tremores)
    readonly property real folga: base * (zoom - 1) * 2.2

    Layout.minimumWidth: larguraRepouso + folga
    Layout.preferredWidth: larguraRepouso + folga
    Layout.maximumWidth: larguraRepouso + folga
    Layout.fillHeight: true

    // ---- onda de ampliação -------------------------------------------------
    // calculada nas posições de repouso: o tamanho depende só do rato
    readonly property real inicioRepouso: (width - larguraRepouso) / 2
    property real ratoX: -10000
    property real forca: hover.hovered ? 1 : 0
    Behavior on forca { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    function centroRepouso(slot: int): real {
        let x = espaco + slot * (base + espaco) + base / 2;
        if (lixeira && slot === slots - 1) {
            x += separador;
        }
        return x;
    }

    function escala(slot: int): real {
        const d = Math.abs(ratoX - centroRepouso(slot));
        if (d >= alcance) {
            return 1;
        }
        const c = Math.cos(d / alcance * Math.PI / 2);
        return 1 + (zoom - 1) * forca * c * c;
    }

    HoverHandler {
        id: hover
        onPointChanged: {
            if (hovered) {
                dock.ratoX = point.position.x - dock.inicioRepouso;
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

    function abrirMenu(): void {
        // o mesmo atalho da tecla Meta: abre o lançador da barra de cima
        DBus.SessionBus.asyncCall({
            service: "org.kde.kglobalaccel",
            path: "/component/plasmashell",
            iface: "org.kde.kglobalaccel.Component",
            member: "invokeShortcut",
            arguments: ["activate application launcher"],
            signature: "(s)"
        });
    }

    // ---- fundo subtil por baixo dos ícones -----------------------------------
    Rectangle {
        anchors.centerIn: fila
        width: fila.width + dock.espaco
        height: dock.base + dock.espaco * 1.6
        radius: height * 0.32
        color: Qt.rgba(1, 1, 1, 0.06)
        border.color: Qt.rgba(1, 1, 1, 0.10)
        border.width: 1
    }

    Row {
        id: fila
        anchors.centerIn: parent
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

        // estrela do menu, no meio
        Item {
            id: estrela
            readonly property real s: dock.escala(dock.meio)
            width: dock.base * s
            height: fila.height

            Kirigami.Icon {
                source: "carinaeos-estrela"
                width: dock.base * estrela.s
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2 - (height - dock.base) * 0.25
                active: estrelaRato.containsMouse
            }
            PlasmaCore.ToolTipArea {
                anchors.fill: parent
                mainText: i18nc("@info:tooltip", "Aplicações")
                location: Plasmoid.location
                MouseArea {
                    id: estrelaRato
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: dock.abrirMenu()
                }
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
                anchors.centerIn: parent
                width: 1
                height: dock.base * 0.75
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
                source: "user-trash"
                width: dock.base * lixo.s
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                y: (parent.height - height) / 2 - (height - dock.base) * 0.25
                active: lixoRato.containsMouse
            }
            PlasmaCore.ToolTipArea {
                anchors.fill: parent
                mainText: i18nc("@info:tooltip", "Lixeira")
                location: Plasmoid.location
                MouseArea {
                    id: lixoRato
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Qt.openUrlExternally("trash:/")
                }
            }
        }
    }
}
