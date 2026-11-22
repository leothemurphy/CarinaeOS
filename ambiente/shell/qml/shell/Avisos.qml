/*
    CarinaeOS — os avisos dos apps (notificações) no canto de cima à direita do ecrã principal,
    por baixo dos lembretes da Agenda. Rato por cima: o aviso espera. Clique: abre o app.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Window
import CarinaeOS.Base
import CarinaeOS.Compat as C
import "../barra"

Window {
    id: avisos

    readonly property var ecra: Qt.application.screens[Sistema.indicePrincipal]
    readonly property int largura: 380

    screen: ecra
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: "CarinaeOS Avisos"
    visible: Notificacoes.ativas.length > 0
    width: largura
    height: Math.max(1, lista.height)
    x: ecra ? ecra.virtualX + ecra.width - width - 14 : 0
    y: (ecra ? ecra.virtualY : 0) + 40 + (Agenda.janela.visible ? Agenda.janela.height + 10 : 0)

    Column {
        id: lista
        width: parent.width
        spacing: 10
        move: Transition { NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic } }

        Repeater {
            model: Notificacoes.ativas.slice(0, 4)
            delegate: Cartao {}
        }
    }

    component Cartao: Item {
        id: cartao
        required property var modelData
        readonly property bool urgente: modelData.urgencia >= 2
        width: lista.width
        height: fundo.height

        // entra a deslizar da direita
        opacity: 0
        // só os novos entram a deslizar (a lista é refeita a cada aviso)
        Component.onCompleted: { if (Date.now() - modelData.hora < 1500) entrada.start(); else opacity = 1 }
        ParallelAnimation {
            id: entrada
            NumberAnimation { target: cartao; property: "opacity"; from: 0; to: 1; duration: 200 }
            NumberAnimation { target: fundo; property: "x"; from: 60; to: 0; duration: 260; easing.type: Easing.OutCubic }
        }

        Rectangle {
            id: fundo
            width: parent.width
            height: corpo.implicitHeight + 28
            radius: 16
            color: Qt.rgba(0.10, 0.09, 0.14, 0.97)
            border.width: cartao.urgente ? 1.5 : 1
            border.color: cartao.urgente ? "#ff7a6e" : Qt.rgba(1, 1, 1, rato.containsMouse ? 0.22 : 0.12)

            MouseArea {
                id: rato
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: cartao.modelData.temPadrao ? Qt.PointingHandCursor : Qt.ArrowCursor
                onContainsMouseChanged: Notificacoes.segurar(cartao.modelData.id, containsMouse)
                onClicked: {
                    if (cartao.modelData.temPadrao) Notificacoes.acao(cartao.modelData.id, "default");
                    else Notificacoes.fechar(cartao.modelData.id);
                }
            }

            Row {
                id: corpo
                x: 14; y: 14
                width: parent.width - 28
                spacing: 12

                // a imagem do aviso (foto do contacto, capa…) ou o ícone do app
                Item {
                    width: 40; height: 40
                    Image {
                        id: foto
                        anchors.fill: parent
                        visible: status === Image.Ready
                        source: cartao.modelData.imagem || ""
                        sourceSize: Qt.size(80, 80)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    C.Icon {
                        anchors.fill: parent
                        visible: !foto.visible
                        source: cartao.modelData.icone || "dialog-information"
                    }
                }

                Column {
                    width: parent.width - 52
                    spacing: 4
                    Row {
                        width: parent.width - 26
                        spacing: 6
                        C.Icon {
                            visible: foto.visible
                            width: 14; height: 14
                            anchors.verticalCenter: parent.verticalCenter
                            source: cartao.modelData.icone || ""
                        }
                        Text {
                            text: (cartao.modelData.app || "Aviso").toUpperCase()
                            color: cartao.urgente ? "#ff9d94" : "#ffb46e"
                            font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.1
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width - 70)
                        }
                        Text {
                            text: "agora"
                            color: "#8f87a3"; font.pixelSize: 10
                        }
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: cartao.modelData.titulo
                        color: "#f6f2ff"
                        font.pixelSize: 14; font.weight: Font.DemiBold
                        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                        textFormat: Text.PlainText
                    }
                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: cartao.modelData.corpo
                        color: "#d9d2e8"
                        font.pixelSize: 13
                        wrapMode: Text.Wrap; maximumLineCount: rato.containsMouse ? 12 : 4; elide: Text.ElideRight
                        textFormat: Text.StyledText
                        linkColor: "#ffb46e"
                        onLinkActivated: (l) => Qt.openUrlExternally(l)
                    }
                    // os botões do app ("Responder", "Marcar como lido"…)
                    Flow {
                        width: parent.width
                        visible: cartao.modelData.acoes.length > 0
                        spacing: 6
                        topPadding: 6
                        Repeater {
                            model: cartao.modelData.acoes
                            delegate: Rectangle {
                                required property var modelData
                                width: t.implicitWidth + 24; height: 28; radius: 14
                                color: Qt.rgba(1, 1, 1, bRato.containsMouse ? 0.16 : 0.08)
                                Text { id: t; anchors.centerIn: parent; text: parent.modelData.texto; color: "#f6f2ff"; font.pixelSize: 12; font.weight: Font.DemiBold }
                                MouseArea { id: bRato; anchors.fill: parent; hoverEnabled: true
                                            onClicked: Notificacoes.acao(cartao.modelData.id, parent.modelData.chave) }
                            }
                        }
                    }
                }
            }

            // fechar
            Rectangle {
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
                width: 22; height: 22; radius: 11
                visible: rato.containsMouse || xRato.containsMouse
                color: Qt.rgba(1, 1, 1, xRato.containsMouse ? 0.18 : 0.08)
                Text { anchors.centerIn: parent; text: "✕"; color: "#f6f2ff"; font.pixelSize: 10 }
                MouseArea { id: xRato; anchors.fill: parent; hoverEnabled: true; onClicked: Notificacoes.fechar(cartao.modelData.id) }
            }
        }
    }
}
