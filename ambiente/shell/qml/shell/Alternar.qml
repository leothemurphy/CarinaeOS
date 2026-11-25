/*
    CarinaeOS — o painel do Alt+Tab e a Visão geral (canto ativo).
    • Alt+Tab: a Gravidade publica as janelas e a escolhida (_CARINAE_ALTERNAR); aqui só se desenha.
      O modelo escolhe-se na Supernova (carinaeos-shell.json "altTab"):
      grade · icones · lista · compacto · coverflow · flip
    • Visão geral: todas as janelas lado a lado; clicar numa traz essa janela; Esc ou clicar fora fecha.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Window
import CarinaeOS.Base
import CarinaeOS.Compat as PlasmaCore
import CarinaeOS.Compat as Kirigami

Window {
    id: painel
    readonly property var monitor: Qt.application.screens[Sistema.indicePrincipal]
    screen: monitor
    x: monitor ? monitor.virtualX : 0
    y: monitor ? monitor.virtualY : 0
    width: monitor ? monitor.width : 1280
    height: monitor ? monitor.height : 720
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | (visao ? 0 : Qt.WindowDoesNotAcceptFocus)
    color: "transparent"
    title: "CarinaeOS Alternar"

    readonly property string estilo: (Sistema.shell || {}).altTab || ""
    property bool visao: false                    // Visão geral (aberta pelo canto ativo)
    property var janelasVisao: []
    property int indiceVisao: 0
    readonly property bool emAltTab: Sistema.alternando && estilo !== "" && estilo !== "simples"
    readonly property var janelas: visao ? janelasVisao : Sistema.alternarJanelas
    readonly property int indice: visao ? indiceVisao : Sistema.alternarIndice
    readonly property string modelo: visao ? "grade" : estilo
    visible: emAltTab || visao

    readonly property color ouro: "#ffb35a"

    function abrirVisao() {
        janelasVisao = Sistema.janelasAbertas();
        if (janelasVisao.length === 0) return;
        indiceVisao = 0;
        visao = true;
        requestActivate();
        Sistema.focarTeclado(painel);
        teclas.forceActiveFocus();
    }
    function fecharVisao() { visao = false; }
    function escolher(i) {
        if (!visao || i < 0 || i >= janelas.length) return;
        const id = janelas[i].id;
        visao = false;
        Sistema.ativarJanela(id);
    }

    // fundo escurecido
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0.04, 0.03, 0.06, painel.modelo === "compacto" || painel.modelo === "lista" ? 0.25 : 0.55)
        MouseArea { anchors.fill: parent; enabled: painel.visao; onClicked: painel.fecharVisao() }
    }

    Item {
        id: teclas
        focus: painel.visao
        Keys.onEscapePressed: painel.fecharVisao()
        Keys.onReturnPressed: painel.escolher(painel.indiceVisao)
        Keys.onRightPressed: painel.indiceVisao = Math.min(painel.janelas.length - 1, painel.indiceVisao + 1)
        Keys.onLeftPressed: painel.indiceVisao = Math.max(0, painel.indiceVisao - 1)
        Keys.onTabPressed: painel.indiceVisao = (painel.indiceVisao + 1) % Math.max(1, painel.janelas.length)
    }

    // ---- miniatura de uma janela (com o ícone e o título por baixo) ----
    component Miniatura: Item {
        id: mini
        required property var janela
        required property int indice
        property bool escolhida: indice === painel.indice
        property bool mostrarTitulo: true
        Rectangle {
            id: moldura
            anchors.fill: parent
            anchors.bottomMargin: mini.mostrarTitulo ? 34 : 0
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.05)
            border.width: mini.escolhida ? 3 : 1
            border.color: mini.escolhida ? painel.ouro : Qt.rgba(1, 1, 1, 0.12)
            PlasmaCore.WindowThumbnail {
                anchors.fill: parent
                anchors.margins: 8
                winId: mini.janela.id
            }
            Kirigami.Icon {
                width: 40; height: 40
                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: -8
                source: mini.janela.icone
            }
        }
        Text {
            visible: mini.mostrarTitulo
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            height: 26
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: mini.janela.titulo
            color: mini.escolhida ? "#ffffff" : "#d6cfc8"
            font.pixelSize: 13; font.weight: mini.escolhida ? Font.DemiBold : Font.Normal
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: painel.visao
            onEntered: if (painel.visao) painel.indiceVisao = mini.indice
            onClicked: painel.escolher(mini.indice)
        }
    }

    // ---- grade (Mac) e Visão geral ----
    Flow {
        visible: painel.modelo === "grade"
        readonly property int n: painel.janelas.length
        readonly property int colunas: Math.max(1, Math.ceil(Math.sqrt(n * 1.4)))
        readonly property real largura: Math.min(420, (painel.width * 0.86) / colunas - spacing)
        width: Math.min(painel.width * 0.9, colunas * (largura + spacing))
        anchors.centerIn: parent
        spacing: 26
        Repeater {
            model: painel.modelo === "grade" ? painel.janelas : []
            delegate: Miniatura {
                required property var modelData
                required property int index
                janela: modelData; indice: index
                width: parent.largura; height: width * 0.62 + 34
            }
        }
    }

    // ---- ícones grandes ----
    Rectangle {
        visible: painel.modelo === "icones"
        anchors.centerIn: parent
        width: linhaIcones.width + 48; height: 190
        radius: 26
        color: Qt.rgba(0.09, 0.08, 0.12, 0.92)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        Row {
            id: linhaIcones
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -12
            spacing: 14
            Repeater {
                model: painel.modelo === "icones" ? painel.janelas : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: 112; height: 112; radius: 22
                    color: index === painel.indice ? Qt.rgba(1, 0.7, 0.35, 0.22) : "transparent"
                    border.width: index === painel.indice ? 2 : 0
                    border.color: painel.ouro
                    Kirigami.Icon { anchors.centerIn: parent; width: 84; height: 84; source: parent.modelData.icone }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 16
            width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
            text: painel.janelas.length ? painel.janelas[Math.min(painel.indice, painel.janelas.length - 1)].titulo : ""
            color: "white"; font.pixelSize: 15; font.weight: Font.DemiBold
        }
    }

    // ---- lista lateral ----
    Rectangle {
        visible: painel.modelo === "lista"
        x: 0; y: 0; width: 380; height: parent.height
        color: Qt.rgba(0.08, 0.07, 0.11, 0.94)
        Column {
            x: 16; y: 70; width: parent.width - 32
            spacing: 6
            Repeater {
                model: painel.modelo === "lista" ? painel.janelas : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: parent.width; height: 58; radius: 12
                    color: index === painel.indice ? Qt.rgba(1, 0.7, 0.35, 0.20) : "transparent"
                    border.width: index === painel.indice ? 1 : 0
                    border.color: painel.ouro
                    Kirigami.Icon { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 36; height: 36; source: parent.modelData.icone }
                    Column {
                        x: 60; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 72
                        Text { width: parent.width; elide: Text.ElideRight; text: modelData.nomeApp; color: "white"; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { width: parent.width; elide: Text.ElideRight; text: modelData.titulo; color: "#bdb4ad"; font.pixelSize: 12 }
                    }
                }
            }
        }
    }

    // ---- compacto ----
    Rectangle {
        visible: painel.modelo === "compacto"
        anchors.centerIn: parent
        width: 460; height: colunaCompacta.height + 24
        radius: 14
        color: Qt.rgba(0.09, 0.08, 0.12, 0.95)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        Column {
            id: colunaCompacta
            x: 12; y: 12; width: parent.width - 24
            Repeater {
                model: painel.modelo === "compacto" ? painel.janelas : []
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: parent.width; height: 34; radius: 8
                    color: index === painel.indice ? painel.ouro : "transparent"
                    Kirigami.Icon { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; source: parent.modelData.icone }
                    Text {
                        x: 38; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 48; elide: Text.ElideRight
                        text: modelData.titulo
                        color: index === painel.indice ? "#1d130b" : "white"; font.pixelSize: 13
                    }
                }
            }
        }
    }

    // ---- Cover Flow e Flip 3D: as miniaturas em perspetiva ----
    Item {
        id: palco
        visible: painel.modelo === "coverflow" || painel.modelo === "flip"
        anchors.fill: parent
        readonly property real lw: Math.min(painel.width * 0.42, 720)
        readonly property real lh: lw * 0.62
        Repeater {
            model: palco.visible ? painel.janelas : []
            delegate: Miniatura {
                id: carta
                required property var modelData
                required property int index
                janela: modelData; indice: index
                mostrarTitulo: escolhida
                readonly property int d: index - painel.indice                  // distância à escolhida
                readonly property int pos: (index - painel.indice + painel.janelas.length) % Math.max(1, painel.janelas.length)
                width: palco.lw; height: palco.lh + 34
                z: painel.modelo === "flip" ? 100 - pos : 100 - Math.abs(d)
                // Cover Flow: a escolhida de frente, as outras viradas para os lados
                // Flip 3D: pilha em diagonal, todas viradas, a escolhida à frente
                x: painel.modelo === "coverflow"
                   ? (palco.width - width) / 2 + (d === 0 ? 0 : Math.sign(d) * (width * 0.55 + (Math.abs(d) - 1) * width * 0.22))
                   : palco.width * 0.32 - width / 2 + pos * 70
                y: painel.modelo === "coverflow"
                   ? (palco.height - height) / 2
                   : palco.height * 0.46 - height / 2 - pos * 46
                scale: painel.modelo === "coverflow" ? (d === 0 ? 1.0 : 0.78)
                       : 1.0 - pos * 0.06
                opacity: painel.modelo === "flip" ? Math.max(0.25, 1.0 - pos * 0.12) : 1
                transform: Rotation {
                    origin.x: carta.width / 2; origin.y: carta.height / 2
                    axis { x: 0; y: 1; z: 0 }
                    angle: painel.modelo === "coverflow" ? (carta.d === 0 ? 0 : (carta.d > 0 ? -55 : 55)) : -32
                }
                Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 180 } }
            }
        }
    }
}
