// CarinaeOS - janela de senha com a marca (cadeado, permissões do sistema)
import QtQuick
import QtQuick.Controls
import QtQuick.Window

Window {
    id: j
    width: 460; height: banner.height + col.implicitHeight + 110
    visible: true
    flags: Qt.Dialog | Qt.WindowStaysOnTopHint
    title: pedido.titulo
    color: "#120e1f"

    readonly property color ambar: "#ffb46e"
    readonly property color rosa: "#ff6f91"

    function confirmar() {
        if (senha.text === "") return
        if (pedido.nova && senha.text !== senha2.text) { erroTxt.text = "As senhas não coincidem."; senha2.selectAll(); senha2.forceActiveFocus(); return }
        pedido.responder(senha.text)
    }
    Connections {
        target: pedido
        function onErroChanged() { senha.text = ""; senha.forceActiveFocus(); abanar.start() }
    }

    // banner
    Rectangle {
        id: banner
        width: parent.width; height: 132
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "#2a1d5c" }
            GradientStop { position: 0.55; color: "#5b2a73" }
            GradientStop { position: 1; color: "#a8456b" }
        }
        Image { anchors.fill: parent; source: "file:///usr/share/carinaeos/marca/banner-senha.jpg"; fillMode: Image.PreserveAspectCrop; opacity: 0.85; asynchronous: true }
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0.4; color: "transparent" } GradientStop { position: 1; color: "#120e1f" } } }
        Row {
            x: 24; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; spacing: 14
            Image { source: "file:///usr/share/carinaeos/marca/logo-128.png"; width: 56; height: 56; sourceSize: Qt.size(112, 112) }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "CarinaeOS"; color: "white"; font.pixelSize: 22; font.weight: Font.Bold; font.family: "Inter" }
                Text { text: pedido.subtitulo; color: "#e8dcff"; font.pixelSize: 12; font.family: "Inter" }
            }
        }
    }

    Column {
        id: col
        x: 26; anchors.top: banner.bottom; anchors.topMargin: 18
        width: parent.width - 52; spacing: 12
        Text { width: parent.width; wrapMode: Text.WordWrap; text: pedido.titulo; color: "white"; font.pixelSize: 17; font.weight: Font.DemiBold; font.family: "Inter" }
        Text { width: parent.width; wrapMode: Text.WordWrap; text: pedido.mensagem; color: "#bdb3d1"; font.pixelSize: 13; font.family: "Inter"; visible: text !== "" }
        Text { width: parent.width; wrapMode: Text.WordWrap; text: pedido.detalhe; color: "#8e84a6"; font.pixelSize: 11; font.family: "monospace"; visible: text !== "" }
        Item {
            width: parent.width; height: campos.implicitHeight
            Column {
                id: campos
                width: parent.width; spacing: 8
                TextField {
                    id: senha
                    width: parent.width; height: 42; echoMode: TextInput.Password; focus: true
                    placeholderText: pedido.rotulo; color: "white"; font.pixelSize: 15
                    background: Rectangle { radius: 12; color: Qt.rgba(1, 1, 1, 0.07); border.color: senha.activeFocus ? j.ambar : Qt.rgba(1, 1, 1, 0.16) }
                    onAccepted: pedido.nova ? senha2.forceActiveFocus() : j.confirmar()
                    Component.onCompleted: forceActiveFocus()
                }
                TextField {
                    id: senha2
                    visible: pedido.nova
                    width: parent.width; height: 42; echoMode: TextInput.Password
                    placeholderText: "Repita a senha"; color: "white"; font.pixelSize: 15
                    background: Rectangle { radius: 12; color: Qt.rgba(1, 1, 1, 0.07); border.color: senha2.activeFocus ? j.ambar : Qt.rgba(1, 1, 1, 0.16) }
                    onAccepted: j.confirmar()
                }
            }
            SequentialAnimation {
                id: abanar
                NumberAnimation { target: campos; property: "x"; to: -10; duration: 50 }
                NumberAnimation { target: campos; property: "x"; to: 10; duration: 70 }
                NumberAnimation { target: campos; property: "x"; to: -6; duration: 60 }
                NumberAnimation { target: campos; property: "x"; to: 0; duration: 50 }
            }
        }
        Text { id: erroTxt; text: pedido.erro; color: j.rosa; font.pixelSize: 13; visible: text !== ""; font.family: "Inter" }
    }

    Row {
        anchors.right: parent.right; anchors.rightMargin: 26; anchors.top: col.bottom; anchors.topMargin: 22
        spacing: 10
        Rectangle {
            width: 120; height: 40; radius: 20; color: Qt.rgba(1, 1, 1, 0.08)
            Text { anchors.centerIn: parent; text: "Cancelar"; color: "white"; font.family: "Inter" }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: pedido.cancelar() }
        }
        Rectangle {
            width: 140; height: 40; radius: 20; opacity: senha.text !== "" ? 1 : 0.5
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: j.rosa } GradientStop { position: 1; color: j.ambar } }
            Text { anchors.centerIn: parent; text: pedido.botao; color: "#1a0f14"; font.weight: Font.Bold; font.family: "Inter" }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: j.confirmar() }
        }
    }
    Shortcut { sequence: "Escape"; onActivated: pedido.cancelar() }
}
