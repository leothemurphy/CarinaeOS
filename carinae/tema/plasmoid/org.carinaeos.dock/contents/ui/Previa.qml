/*
    CarinaeOS — Dock: pré-visualização das janelas de uma app (como no Windows), ao passar o rato.
    Uma miniatura ao vivo por janela; clicar traz essa janela, o × fecha-a.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models

import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.kwindowsystem

Item {
    id: previa
    required property Item alvo
    required property var dock
    required property var tarefa          // o delegate (Tarefa.qml)
    property bool pedido: false            // o rato está no ícone
    readonly property bool sobre: hoverJanela.hovered
    readonly property bool aberta: janela.visible

    // grupo (várias janelas) ou uma só janela
    readonly property bool grupo: tarefa.model.IsGroupParent === true
    readonly property int quantas: grupo ? filhos.count : 1

    // abrir com um pequeno atraso; fechar só quando o rato saiu do ícone e da pré-visualização
    Timer { id: abrir; interval: 380; onTriggered: if (previa.pedido) janela.visible = true }
    Timer { id: fechar; interval: 260; onTriggered: if (!previa.pedido && !previa.sobre) janela.visible = false }
    onPedidoChanged: {
        if (pedido) {
            fechar.stop();
            if (!janela.visible) abrir.restart();
        } else {
            abrir.stop();
            fechar.restart();
        }
    }
    onSobreChanged: if (!sobre) fechar.restart(); else fechar.stop()
    function esconder(): void { abrir.stop(); janela.visible = false; }

    DelegateModel {
        id: filhos
        model: previa.grupo ? previa.dock.modelo : null
        rootIndex: previa.dock.modelo.makeModelIndex(previa.tarefa.index)
        delegate: Miniatura {
            required property var model
            required property int index
            titulo: model.display || ""
            winId: (model.WinIdList && model.WinIdList.length) ? model.WinIdList[0] : undefined
            minimizada: model.IsMinimized === true
            ativa: model.IsActive === true
            icone: model.decoration
            indice: previa.dock.modelo.makeModelIndex(previa.tarefa.index, index)
        }
    }

    component Miniatura: Rectangle {
        id: mini
        property string titulo
        property var winId
        property bool minimizada
        property bool ativa
        property var icone
        property var indice
        readonly property real larg: Math.round(previa.dock.base * 3.9)
        width: larg; height: Math.round(larg * 0.62) + 30
        radius: 10
        color: rm.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : (ativa ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
        Behavior on color { ColorAnimation { duration: 90 } }

        Row {
            id: cab
            x: 8; y: 6; spacing: 6; width: parent.width - 40
            Kirigami.Icon { source: mini.icone; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter }
            Text {
                width: parent.width - 22; anchors.verticalCenter: parent.verticalCenter
                text: mini.titulo; color: "white"; font.pixelSize: 12; elide: Text.ElideRight
            }
        }
        Item {
            id: quadro
            x: 8; y: 28; width: parent.width - 16; height: parent.height - 36
            Loader {
                anchors.fill: parent
                active: KWindowSystem.isPlatformX11 && !mini.minimizada && mini.winId !== undefined
                asynchronous: true
                sourceComponent: PlasmaCore.WindowThumbnail { winId: mini.winId }
            }
            Kirigami.Icon {      // minimizada (ou sem miniatura): o ícone grande
                visible: !KWindowSystem.isPlatformX11 || mini.minimizada || mini.winId === undefined
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.5; height: width
                source: mini.icone
            }
        }
        MouseArea {
            id: rm
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: m => {
                if (m.button === Qt.MiddleButton) {
                    previa.dock.modelo.requestClose(mini.indice);
                    return;
                }
                previa.dock.modelo.requestActivate(mini.indice);
                previa.esconder();
            }
        }
        Rectangle {      // fechar
            visible: rm.containsMouse || rx.containsMouse
            width: 22; height: 22; radius: 11
            anchors { right: parent.right; top: parent.top; margins: 4 }
            color: rx.containsMouse ? "#ff5f57" : Qt.rgba(1, 1, 1, 0.16)
            Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 11 }
            MouseArea { id: rx; anchors.fill: parent; hoverEnabled: true; onClicked: previa.dock.modelo.requestClose(mini.indice) }
        }
    }

    PlasmaCore.Dialog {
        id: janela
        visualParent: previa.alvo
        location: previa.dock.localizacao
        type: PlasmaCore.Dialog.Tooltip
        flags: Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: false
        visible: false

        mainItem: Rectangle {
            id: caixa
            width: fila.width + 16
            height: fila.height + 16
            radius: 14
            color: Qt.rgba(0.10, 0.09, 0.14, 0.94)
            border.color: Qt.rgba(1, 1, 1, 0.14)
            opacity: janela.visible ? 1 : 0
            scale: janela.visible ? 1 : 0.96
            Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            HoverHandler { id: hoverJanela }

            Row {
                id: fila
                x: 8; y: 8; spacing: 6
                Repeater { model: previa.grupo ? filhos : null }
                Loader {     // uma janela só: o próprio item da Dock
                    active: !previa.grupo
                    sourceComponent: Miniatura {
                        titulo: previa.tarefa.model.display || ""
                        winId: (previa.tarefa.model.WinIdList && previa.tarefa.model.WinIdList.length) ? previa.tarefa.model.WinIdList[0] : undefined
                        minimizada: previa.tarefa.model.IsMinimized === true
                        ativa: previa.tarefa.model.IsActive === true
                        icone: previa.tarefa.model.decoration
                        indice: previa.tarefa.indice()
                    }
                }
            }
        }
    }
}
