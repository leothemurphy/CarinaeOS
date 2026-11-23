/*
    CarinaeOS — o ecrã de desligar (botão de ligar do computador, "Desligar" na central, Alt+F4 na mesa):
    Bloquear · Terminar sessão · Suspender · Reiniciar · Desligar. Esc ou clicar fora fecha.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Window
import CarinaeOS.Base
import CarinaeOS.Compat as C

Window {
    id: ecra
    readonly property var monitor: Qt.application.screens[Sistema.indicePrincipal]
    screen: monitor
    x: monitor ? monitor.virtualX : 0
    y: monitor ? monitor.virtualY : 0
    width: monitor ? monitor.width : 1280
    height: monitor ? monitor.height : 720
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "CarinaeOS Desligar"
    visible: false

    property int escolhido: 4
    property real abertoEm: 0
    readonly property var opcoes: [
        { icone: "M7 11V8a5 5 0 0 1 10 0v3M6 11h12v9H6z", texto: "Bloquear", cmd: "carinae-sessao bloquear" },
        { icone: "M14 4.5H6.5v15H14M10 12h10M16.5 8.5L20 12l-3.5 3.5", texto: "Terminar sessão", cmd: "carinae-sessao sair --sem-perguntar" },
        { icone: "M19.5 14.5A8 8 0 1 1 9.5 4.5a6.5 6.5 0 0 0 10 10z", texto: "Suspender", cmd: "carinae-sessao suspender" },
        { icone: "M19.5 12a7.5 7.5 0 1 1-2.2-5.3M19.5 4.5v4h-4", texto: "Reiniciar", cmd: "carinae-sessao reiniciar --sem-perguntar" },
        { icone: "M12 3.5v8M7.2 6.7a7.5 7.5 0 1 0 9.6 0", texto: "Desligar", cmd: "carinae-sessao desligar --sem-perguntar" }
    ]

    function abrir(opcao) {
        const i = ["bloquear", "sair", "suspender", "reiniciar", "desligar"].indexOf(opcao);
        escolhido = i >= 0 ? i : 4;
        abertoEm = Date.now();
        fundo.opacity = 0;
        visible = true;
        requestActivate();
        entrada.start();
        foco.forceActiveFocus();
    }
    function fechar() { visible = false }
    function fazer(i) {
        visible = false;
        Sistema.executar(opcoes[i].cmd);
    }

    Connections { target: Sistema; function onDesligarPedido(opcao) { ecra.visible ? ecra.fechar() : ecra.abrir(opcao) } }

    Rectangle {
        id: fundo
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.03, 0.08, 0.82)
        NumberAnimation on opacity { id: entrada; running: false; from: 0; to: 1; duration: 180 }
        MouseArea { anchors.fill: parent; onClicked: ecra.fechar() }

        Column {
            anchors.centerIn: parent
            spacing: 40
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "O que quer fazer?"
                color: "#f6f2ff"; font.pixelSize: 26; font.weight: Font.Light
            }
            Row {
                id: foco
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 28
                focus: true
                Keys.onEscapePressed: ecra.fechar()
                Keys.onLeftPressed: ecra.escolhido = Math.max(0, ecra.escolhido - 1)
                Keys.onRightPressed: ecra.escolhido = Math.min(ecra.opcoes.length - 1, ecra.escolhido + 1)
                Keys.onReturnPressed: ecra.fazer(ecra.escolhido)
                Keys.onEnterPressed: ecra.fazer(ecra.escolhido)
                Repeater {
                    model: ecra.opcoes
                    delegate: Column {
                        id: op
                        required property var modelData
                        required property int index
                        readonly property bool ativo: ecra.escolhido === index
                        spacing: 12
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 84; height: 84; radius: 42
                            scale: rOp.pressed ? 0.94 : op.ativo ? 1.06 : 1
                            Behavior on scale { NumberAnimation { duration: 120 } }
                            color: op.index === 4 && op.ativo ? "#ff7a6e" : op.ativo ? "#ffb46e" : Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1; border.color: Qt.rgba(1, 1, 1, op.ativo ? 0 : 0.15)
                            Image {
                                anchors.centerIn: parent; width: 34; height: 34
                                sourceSize: Qt.size(68, 68)
                                source: "data:image/svg+xml;utf8," + encodeURIComponent(
                                    "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='"
                                    + (op.ativo ? "#1b1030" : "#f6f2ff") + "' stroke-width='1.6' stroke-linecap='round' stroke-linejoin='round'><path d='"
                                    + op.modelData.icone + "'/></svg>")
                            }
                            MouseArea {
                                id: rOp
                                anchors.fill: parent; hoverEnabled: true
                                // o rato que já estava parado ali ao abrir não muda a escolha; só se mexer
                                onPositionChanged: if (Date.now() - ecra.abertoEm > 500) ecra.escolhido = op.index
                                onClicked: ecra.fazer(op.index)
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: op.modelData.texto
                            color: op.ativo ? "#f6f2ff" : "#b9b0cc"; font.pixelSize: 14
                        }
                    }
                }
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Setas para escolher · Enter para confirmar · Esc para voltar"
                    color: "#8f87a3"; font.pixelSize: 12
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Opções de energia…"
                    color: rOpc.containsMouse ? "#ffc58c" : "#ffb46e"; font.pixelSize: 13
                    MouseArea { id: rOpc; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { ecra.fechar(); Sistema.executar("carinae-energia-ajustes") } }
                }
            }
        }
    }
}
