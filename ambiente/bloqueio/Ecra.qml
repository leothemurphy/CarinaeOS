// CarinaeOS — ecrã de bloqueio (uma janela por monitor; o principal tem o campo de senha)
import QtQuick
import QtQuick.Window
import QtQuick.Effects

Window {
    id: janela
    required property var ecra
    required property bool principal
    flags: Qt.X11BypassWindowManagerHint | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "#120f1c"
    title: "Bloqueio CarinaeOS"

    property bool acordado: true
    property date agora: new Date()
    readonly property color ambar: "#ffb347"

    Timer { interval: 1000; running: true; repeat: true; onTriggered: janela.agora = new Date() }
    // sem mexer durante uns segundos: só o relógio
    Timer { id: sono; interval: 15000; running: true; onTriggered: if (campo.text.length === 0) janela.acordado = false }
    function acordar() { janela.acordado = true; sono.restart(); }

    // fundo: o papel de parede, desfocado e escurecido
    Item {
        anchors.fill: parent
        Image {
            id: papel
            anchors.fill: parent
            source: bloqueio.papel
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 960
            asynchronous: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: papel
            visible: papel.status === Image.Ready
            blurEnabled: true; blurMax: 64; blur: 1.0
            brightness: -0.25; saturation: 0.1
        }
        Rectangle {
            anchors.fill: parent
            visible: papel.status !== Image.Ready
            gradient: Gradient {
                GradientStop { position: 0; color: "#2a1356" }
                GradientStop { position: 1; color: "#120f1c" }
            }
        }
        Rectangle { anchors.fill: parent; color: "black"; opacity: janela.acordado ? 0.25 : 0.45
            Behavior on opacity { NumberAnimation { duration: 400 } } }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onPositionChanged: janela.acordar()
        onPressed: { janela.acordar(); campo.forceActiveFocus(); }
    }

    // relógio
    Column {
        id: relogio
        anchors.horizontalCenter: parent.horizontalCenter
        y: janela.principal && janela.acordado ? parent.height * 0.16 : parent.height * 0.36
        Behavior on y { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        spacing: 4
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(janela.agora, "HH:mm")
            color: "white"; font.pixelSize: Math.min(janela.height * 0.13, 128); font.weight: Font.Light
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: { const s = janela.agora.toLocaleDateString(Qt.locale(), "dddd, d 'de' MMMM"); return s.charAt(0).toUpperCase() + s.slice(1); }
            color: "#e8e2f4"; font.pixelSize: 22
        }
    }

    // utilizador + senha (só no ecrã principal)
    Column {
        id: cartao
        visible: janela.principal
        opacity: janela.acordado ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 300 } }
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.5
        spacing: 16

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 112; height: 112
            Rectangle { anchors.fill: parent; radius: width / 2; color: "#3a2a66"; border.color: "#40ffffff"; border.width: 2 }
            Text {
                anchors.centerIn: parent
                visible: foto.status !== Image.Ready
                text: bloqueio.nome.charAt(0).toUpperCase()
                color: "white"; font.pixelSize: 48
            }
            Image { id: foto; anchors.fill: parent; anchors.margins: 2; source: bloqueio.avatar
                fillMode: Image.PreserveAspectCrop; visible: false; sourceSize: Qt.size(224, 224) }
            Rectangle { id: mascara; anchors.fill: foto; radius: width / 2; visible: false; layer.enabled: true }
            MultiEffect { anchors.fill: foto; source: foto; maskEnabled: true; maskSource: mascara
                visible: foto.status === Image.Ready }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: bloqueio.nome; color: "white"; font.pixelSize: 24; font.weight: Font.DemiBold
        }

        Rectangle {
            id: caixa
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300; height: 46; radius: 23
            color: "#22ffffff"
            border.width: 1.5
            border.color: campo.activeFocus ? janela.ambar : "#55ffffff"
            property real desvio: 0
            transform: Translate { x: caixa.desvio }
            SequentialAnimation {
                id: abanar
                NumberAnimation { target: caixa; property: "desvio"; to: -14; duration: 50 }
                NumberAnimation { target: caixa; property: "desvio"; to: 12; duration: 70 }
                NumberAnimation { target: caixa; property: "desvio"; to: -8; duration: 70 }
                NumberAnimation { target: caixa; property: "desvio"; to: 0; duration: 60 }
            }
            TextInput {
                id: campo
                anchors.fill: parent
                anchors.leftMargin: 20; anchors.rightMargin: 52
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: "white"; font.pixelSize: 18
                selectionColor: janela.ambar
                enabled: !bloqueio.ocupado
                focus: janela.principal
                clip: true
                onTextChanged: { janela.acordar(); erro.visible = false; }
                Keys.onPressed: (e) => { janela.acordar(); }
                Keys.onReturnPressed: entrar()
                Keys.onEnterPressed: entrar()
                Keys.onEscapePressed: text = ""
                function entrar() { if (text.length > 0) bloqueio.desbloquear(text); }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: campo.text.length === 0
                    text: bloqueio.teclado ? "Senha" : "A preparar o teclado…"
                    color: "#a0ffffff"; font.pixelSize: 17
                }
            }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36; radius: 18
                color: campo.text.length > 0 ? janela.ambar : "#30ffffff"
                Text {
                    anchors.centerIn: parent
                    text: bloqueio.ocupado ? "…" : "→"
                    color: campo.text.length > 0 ? "#1b1030" : "white"; font.pixelSize: 20; font.bold: true
                }
                MouseArea { anchors.fill: parent; onClicked: campo.entrar() }
            }
        }
        Text {
            id: erro
            anchors.horizontalCenter: parent.horizontalCenter
            visible: false
            text: "Senha incorreta"
            color: "#ff8a8a"; font.pixelSize: 16
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: !erro.visible
            text: "Escreva a sua senha e carregue Enter"
            color: "#90ffffff"; font.pixelSize: 14
        }
    }

    // a dormir: dica discreta
    Text {
        visible: janela.principal && !janela.acordado
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 48
        text: "Bloqueado — mexa o rato ou carregue numa tecla"
        color: "#b0ffffff"; font.pixelSize: 16
    }

    Connections {
        target: bloqueio
        function onErrou() { campo.text = ""; erro.visible = true; abanar.start(); campo.forceActiveFocus(); }
    }
    Component.onCompleted: if (janela.principal) campo.forceActiveFocus()
}
