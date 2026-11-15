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
    // o lançador fixado correspondente (para os separadores e para arrastar)
    readonly property int posLancador: dock.modelo.launcherPosition(url())
    readonly property string lancador: posLancador !== -1 ? dock.modelo.launcherList[posLancador] : ""
    readonly property bool separadorDepois: mostrar && dock.temSeparador(lancador)
    property bool arrastando: false

    visible: mostrar
    width: mostrar ? dock.base * s + (separadorDepois ? dock.largSep + dock.espaco : 0) : 0
    z: arrastando ? 10 : 0
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

    Item {      // os ícones desenham-se uma vez no tamanho máximo e só mudam de escala (sem redesenhar a cada movimento do rato)
        id: icone
        rotation: -dock.angulo
        width: dock.base * tarefa.s
        height: width
        x: (dock.base * tarefa.s - width) / 2
        opacity: tarefa.arrastando ? 0.75 : 1
        y: parent.height - dock.baixo - dock.margem - height - tarefa.pulo
        Kirigami.Icon {
            source: tarefa.model.decoration
            active: rato.containsMouse
            width: Math.round(dock.base * Math.max(1, dock.zoom))
            height: width
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            transformOrigin: Item.Bottom
            scale: parent.width / width
            smooth: true
        }
    }
    // separador escolhido pela pessoa, à direita do ícone
    Rectangle {
        visible: tarefa.separadorDepois
        x: dock.base * tarefa.s + (dock.largSep + dock.espaco) / 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dock.baixo + dock.margem * 1.3
        width: dock.grossuraSeparador
        height: dock.base * 0.8
        radius: width / 2
        color: dock.corSeparador
    }
    Rotulo {
        alvo: icone
        texto: tarefa.model.AppName || tarefa.model.display || ""
        mostrar: rato.containsMouse && !previa.aberta && !previa.pedido
        dock: tarefa.dock
    }
    // pré-visualização das janelas abertas (como no Windows); as apps só fixadas mostram só o nome
    Previa {
        id: previa
        alvo: icone
        dock: tarefa.dock
        tarefa: tarefa
        pedido: rato.containsMouse && !rato.pressed && !tarefa.arrastando
                && !tarefa.model.IsLauncher && !tarefa.model.IsStartup
    }

    // ponto das apps abertas
    Rectangle {
        visible: !tarefa.model.IsLauncher && !tarefa.model.IsStartup
        width: Math.max(4, Math.round(dock.base / 11))
        height: width
        radius: width / 2
        x: (dock.base * tarefa.s - width) / 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dock.baixo + Math.max(2, dock.margem * 0.25)
        color: tarefa.model.IsActive ? "#FFB46E" : Qt.rgba(1, 1, 1, 0.7)
    }

    // salto ao abrir (como no macOS): sobe e desce suave, enquanto a app abre
    SequentialAnimation {
        id: salto
        loops: 3
        NumberAnimation { target: tarefa; property: "pulo"; to: dock.base * 0.55; duration: 300; easing.type: Easing.OutCubic }
        NumberAnimation { target: tarefa; property: "pulo"; to: 0; duration: 300; easing.type: Easing.InCubic }
    }
    Connections {
        target: tarefa.model
        function onIsStartupChanged(): void {
            if (tarefa.model.IsStartup && tarefa.mostrar && Plasmoid.configuration.bounce) {
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

    Item {
        anchors.left: parent.left
        width: dock.base * tarefa.s
        anchors.bottom: parent.bottom
        height: dock.baixo + dock.margem * 2 + icone.height

        MouseArea {
            id: rato
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            preventStealing: true

            // arrastar para os lados reorganiza os ícones fixados (como no Mac)
            property real inicioX: 0
            property bool moveu: false
            onPressed: mouse => {
                inicioX = mapToItem(dock.palcoItem, mouse.x, 0).x;
                moveu = false;
            }
            onPositionChanged: mouse => {
                if (!pressed || !(pressedButtons & Qt.LeftButton) || tarefa.posLancador === -1) return;
                const gx = mapToItem(dock.palcoItem, mouse.x, 0).x;
                const dx = gx - inicioX;
                if (!tarefa.arrastando && Math.abs(dx) > dock.base * 0.35) tarefa.arrastando = true;
                if (!tarefa.arrastando) return;
                const passo = dock.base + dock.espaco;
                if (dx > passo * 0.6 && tarefa.index < dock.fixadas - 1) {
                    dock.modelo.move(tarefa.index, tarefa.index + 1);
                    inicioX += passo;
                    moveu = true;
                } else if (dx < -passo * 0.6 && tarefa.index > 0) {
                    dock.modelo.move(tarefa.index, tarefa.index - 1);
                    inicioX -= passo;
                    moveu = true;
                }
            }
            onReleased: {
                if (tarefa.arrastando) {
                    tarefa.arrastando = false;
                    if (moveu) dock.modelo.syncLaunchers();
                }
            }
            onCanceled: tarefa.arrastando = false

            onClicked: mouse => {
                previa.esconder();
                if (moveu) { moveu = false; return; }
                if (mouse.button === Qt.RightButton) {
                    menu.visualParent = tarefa;
                    menu.openRelative();
                    return;
                }
                if (mouse.button === Qt.MiddleButton) {
                    if (dock.cliqueMeio === "fechar" && !tarefa.model.IsLauncher) {
                        dock.modelo.requestClose(tarefa.indice());     // como o mod "Middle click to close" do Windhawk
                    } else {
                        dock.modelo.requestNewInstance(tarefa.indice());
                        salto.restart();
                    }
                    return;
                }
                if (tarefa.model.IsLauncher) {
                    dock.modelo.requestActivate(tarefa.indice());
                    if (Plasmoid.configuration.bounce) salto.restart();
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
            text: fixada ? i18nc("@action:inmenu", "Remover da Dock") : i18nc("@action:inmenu", "Manter na Dock")
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
            visible: tarefa.lancador !== ""
            text: tarefa.separadorDepois ? "Tirar o separador" : "Adicionar separador à direita"
            icon: "distribute-horizontal-x"
            onClicked: dock.alternarSeparador(tarefa.lancador)
        }
        PlasmaExtras.MenuItem {
            text: i18nc("@action:inmenu", "Fechar")
            icon: "window-close"
            visible: !tarefa.model.IsLauncher
            onClicked: dock.modelo.requestClose(tarefa.indice())
        }
    }
}
