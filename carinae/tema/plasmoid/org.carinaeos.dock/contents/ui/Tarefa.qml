/*
    CarinaeOS — Dock: um ícone de app
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

Item {
    id: tarefa

    required property var dock

    required property int index
    required property var model
    property int parte: 0

    readonly property bool naPrimeira: index < dock.meio
    readonly property bool mostrar: parte === 0 ? naPrimeira : !naPrimeira
    readonly property int slot: naPrimeira ? index : index + 1
    readonly property real s: dock.escala(slot)
    property real pulo: 0

    visible: mostrar
    width: mostrar ? dock.base * s : 0
    height: parent ? parent.height : 0

    function indice(): var {
        return dock.modelo.makeModelIndex(index);
    }
    function url(): url {
        return model.LauncherUrlWithoutIcon;
    }
    function publicarGeometria(): void {
        if (mostrar && !model.IsLauncher && !model.IsStartup) {
            const p = icone.mapToGlobal(0, 0);
            dock.modelo.requestPublishDelegateGeometry(indice(), Qt.rect(p.x, p.y, icone.width, icone.height), tarefa);
        }
    }

    Kirigami.Icon {
        id: icone
        source: tarefa.model.decoration
        width: dock.base * tarefa.s
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - height) / 2 - (height - dock.base) * 0.25 - tarefa.pulo
        active: rato.containsMouse
    }

    // ponto das apps abertas
    Rectangle {
        visible: !tarefa.model.IsLauncher && !tarefa.model.IsStartup
        width: Math.max(4, Math.round(dock.base / 11))
        height: width
        radius: width / 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        color: tarefa.model.IsActive ? "#FFB46E" : Qt.rgba(1, 1, 1, 0.7)
    }

    // salto ao abrir (como no macOS)
    SequentialAnimation {
        id: salto
        loops: 2
        NumberAnimation { target: tarefa; property: "pulo"; to: dock.base * 0.35; duration: 220; easing.type: Easing.OutQuad }
        NumberAnimation { target: tarefa; property: "pulo"; to: 0; duration: 260; easing.type: Easing.OutBounce }
    }
    Connections {
        target: tarefa.model
        function onIsStartupChanged(): void {
            if (tarefa.model.IsStartup && tarefa.mostrar) {
                salto.restart();
            }
        }
    }

    onSChanged: geoTimer.restart()
    Timer {
        id: geoTimer
        interval: 400
        onTriggered: tarefa.publicarGeometria()
    }
    Component.onCompleted: geoTimer.start()

    PlasmaCore.ToolTipArea {
        anchors.fill: parent
        mainText: tarefa.model.AppName || tarefa.model.display
        location: Plasmoid.location

        MouseArea {
            id: rato
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    menu.visualParent = tarefa;
                    menu.openRelative();
                    return;
                }
                if (mouse.button === Qt.MiddleButton) {
                    dock.modelo.requestNewInstance(tarefa.indice());
                    salto.restart();
                    return;
                }
                if (tarefa.model.IsLauncher) {
                    dock.modelo.requestActivate(tarefa.indice());
                    salto.restart();
                } else if (tarefa.model.IsMinimized) {
                    dock.modelo.requestToggleMinimized(tarefa.indice());
                    dock.modelo.requestActivate(tarefa.indice());
                } else if (tarefa.model.IsActive) {
                    dock.modelo.requestToggleMinimized(tarefa.indice());
                } else {
                    dock.modelo.requestActivate(tarefa.indice());
                }
            }
        }
    }

    PlasmaExtras.Menu {
        id: menu
        placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup

        PlasmaExtras.MenuItem {
            text: i18nc("@action:inmenu", "Nova janela")
            icon: "window-new"
            visible: !tarefa.model.IsLauncher
            onClicked: dock.modelo.requestNewInstance(tarefa.indice())
        }
        PlasmaExtras.MenuItem {
            readonly property bool fixada: dock.modelo.launcherPosition(tarefa.url()) !== -1
            text: fixada ? i18nc("@action:inmenu", "Remover do Dock") : i18nc("@action:inmenu", "Manter no Dock")
            icon: fixada ? "window-unpin" : "window-pin"
            onClicked: {
                if (fixada) {
                    dock.modelo.requestRemoveLauncher(tarefa.url());
                } else {
                    dock.modelo.requestAddLauncher(tarefa.url());
                }
            }
        }
        PlasmaExtras.MenuItem {
            text: i18nc("@action:inmenu", "Fechar")
            icon: "window-close"
            visible: !tarefa.model.IsLauncher
            onClicked: dock.modelo.requestClose(tarefa.indice())
        }
    }
}
