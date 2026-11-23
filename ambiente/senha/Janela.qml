// CarinaeOS — a janela "Autorizar" (pedido de senha de administrador)
import QtQuick
import QtQuick.Window

Window {
    id: janela
    visible: pedido.ativo
    flags: Qt.Dialog | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"
    title: "Autorização — CarinaeOS"
    width: 440
    height: cartao.height + 40
    x: Screen.virtualX + (Screen.width - width) / 2
    y: Screen.virtualY + (Screen.height - height) / 2 - 60

    readonly property color ambar: "#ffb46e"
    readonly property color texto: "#f6f2ff"
    readonly property color suave: "#b9b0cc"
    property bool detalhes: false

    onVisibleChanged: if (visible) { campo.text = ""; detalhes = false; requestActivate(); focoTimer.start() }
    Timer { id: focoTimer; interval: 60; onTriggered: { janela.requestActivate(); campo.forceActiveFocus() } }

    Connections {
        target: pedido
        function onFalhou() { campo.text = ""; abanar.start(); campo.forceActiveFocus() }
        function onMudou() { if (!pedido.ocupado && pedido.pergunta !== "") campo.forceActiveFocus() }
    }

    Rectangle {
        id: cartao
        x: 20; y: 20
        width: parent.width - 40
        height: col.implicitHeight + 48
        radius: 22
        color: Qt.rgba(0.10, 0.09, 0.14, 0.98)
        border.color: Qt.rgba(1, 1, 1, 0.12)

        SequentialAnimation {
            id: abanar
            NumberAnimation { target: cartao; property: "x"; to: 34; duration: 50 }
            NumberAnimation { target: cartao; property: "x"; to: 6; duration: 70 }
            NumberAnimation { target: cartao; property: "x"; to: 28; duration: 60 }
            NumberAnimation { target: cartao; property: "x"; to: 14; duration: 60 }
            NumberAnimation { target: cartao; property: "x"; to: 20; duration: 50 }
        }

        // arrastar a janela pelo fundo
        MouseArea {
            anchors.fill: parent
            property point inicio
            onPressed: (r) => inicio = Qt.point(r.x, r.y)
            onPositionChanged: (r) => { janela.x += r.x - inicio.x; janela.y += r.y - inicio.y }
        }

        Column {
            id: col
            x: 28; y: 26
            width: parent.width - 56
            spacing: 14

            // cadeado com brilho âmbar
            Item {
                width: parent.width; height: 64
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64; height: 64; radius: 32
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#ffcf9a" }
                        GradientStop { position: 1; color: "#ff8a5c" }
                    }
                    // cadeado desenhado (não depende do tema de ícones)
                    Item {
                        anchors.centerIn: parent
                        width: 26; height: 30
                        Rectangle { x: 5; y: 0; width: 16; height: 18; radius: 8; color: "transparent"; border.width: 3.5; border.color: "#1b1030" }
                        Rectangle { x: 0; y: 12; width: 26; height: 18; radius: 5; color: "#1b1030" }
                        Rectangle { x: 11.5; y: 18; width: 3; height: 6; radius: 1.5; color: "#ffb46e" }
                    }
                }
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: "Autorização necessária"
                color: janela.texto
                font.pixelSize: 19; font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: pedido.mensagem
                color: janela.suave
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }

            // quem autoriza (só aparece se houver mais do que uma pessoa que pode)
            Flow {
                width: parent.width
                visible: pedido.utilizadores.length > 1
                spacing: 6
                Repeater {
                    model: pedido.utilizadores
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        readonly property bool sel: index === pedido.escolhido
                        width: tu.implicitWidth + 22; height: 28; radius: 14
                        color: sel ? Qt.rgba(1, 0.71, 0.43, 0.22) : Qt.rgba(1, 1, 1, ur.containsMouse ? 0.12 : 0.06)
                        border.width: sel ? 1 : 0; border.color: janela.ambar
                        Text { id: tu; anchors.centerIn: parent; text: parent.modelData; color: janela.texto; font.pixelSize: 12 }
                        MouseArea { id: ur; anchors.fill: parent; hoverEnabled: true; onClicked: pedido.escolher(parent.index) }
                    }
                }
            }
            Text {
                width: parent.width
                visible: pedido.utilizadores.length === 1
                horizontalAlignment: Text.AlignHCenter
                text: "Como " + (pedido.utilizadores[0] || "")
                color: janela.suave; font.pixelSize: 12
            }

            // a senha
            Rectangle {
                width: parent.width; height: 46; radius: 14
                color: Qt.rgba(1, 1, 1, 0.07)
                border.width: campo.activeFocus ? 1.5 : 1
                border.color: pedido.erro !== "" ? "#ff7a6e" : campo.activeFocus ? janela.ambar : Qt.rgba(1, 1, 1, 0.16)
                TextInput {
                    id: campo
                    anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 44
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: pedido.mostrarTexto || ver.ligado ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    color: janela.texto; selectionColor: janela.ambar; selectedTextColor: "#1b1030"
                    font.pixelSize: 15
                    enabled: !pedido.ocupado
                    focus: true
                    onAccepted: if (text.length) pedido.responder(text)
                    Keys.onEscapePressed: pedido.cancelar()
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: campo.text.length === 0
                        text: pedido.ocupado ? "A verificar…" : (pedido.pergunta || "Senha")
                        color: Qt.rgba(1, 1, 1, 0.35); font.pixelSize: 15
                    }
                }
                // mostrar/esconder a senha
                Item {
                    id: ver
                    property bool ligado: false
                    anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter
                    width: 26; height: 26
                    Rectangle { anchors.centerIn: parent; width: 18; height: 11; radius: 6; color: "transparent"; border.width: 1.6
                                border.color: ver.ligado ? janela.ambar : Qt.rgba(1, 1, 1, 0.5) }
                    Rectangle { anchors.centerIn: parent; width: 5; height: 5; radius: 2.5; color: ver.ligado ? janela.ambar : Qt.rgba(1, 1, 1, 0.5) }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ver.ligado = !ver.ligado; campo.forceActiveFocus() } }
                }
            }
            Text {
                width: parent.width
                visible: text !== ""
                text: pedido.erro !== "" ? pedido.erro : pedido.info
                color: pedido.erro !== "" ? "#ff9d94" : janela.suave
                font.pixelSize: 12
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
            }

            // detalhes (para quem quer saber o que está a pedir)
            Text {
                text: (janela.detalhes ? "▾ " : "▸ ") + "Detalhes"
                color: dr.containsMouse ? janela.texto : janela.suave; font.pixelSize: 12
                MouseArea { id: dr; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: janela.detalhes = !janela.detalhes }
            }
            Column {
                visible: janela.detalhes
                width: parent.width
                spacing: 4
                Text { width: parent.width; visible: pedido.programa !== ""; text: "Programa: " + pedido.programa
                       color: janela.suave; font.pixelSize: 11; wrapMode: Text.WrapAnywhere }
                Text { width: parent.width; text: "Ação: " + pedido.acao; color: janela.suave; font.pixelSize: 11; wrapMode: Text.WrapAnywhere }
            }

            // botões
            Row {
                anchors.right: parent.right
                spacing: 10
                Botao { texto: "Cancelar"; onClicado: pedido.cancelar() }
                Botao { texto: pedido.ocupado ? "A verificar…" : "Autorizar"; destaque: true; ativo: campo.text.length > 0 && !pedido.ocupado
                        onClicado: pedido.responder(campo.text) }
            }
        }
    }

    component Botao: Rectangle {
        id: b
        property string texto
        property bool destaque: false
        property bool ativo: true
        signal clicado()
        width: Math.max(110, t.implicitWidth + 32); height: 38; radius: 19
        opacity: ativo ? 1 : 0.5
        color: destaque ? (br.containsMouse ? "#ffc58c" : "#ffb46e") : Qt.rgba(1, 1, 1, br.containsMouse ? 0.14 : 0.08)
        Text { id: t; anchors.centerIn: parent; text: b.texto; color: b.destaque ? "#1b1030" : "#f6f2ff"; font.pixelSize: 13; font.weight: Font.DemiBold }
        MouseArea { id: br; anchors.fill: parent; hoverEnabled: true; enabled: b.ativo; onClicked: b.clicado() }
    }
}
