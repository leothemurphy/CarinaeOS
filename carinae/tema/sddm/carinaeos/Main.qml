// CarinaeOS - ecra de entrada (SDDM, Qt 6), ao estilo do macOS:
//   em cima a estrela, a data e as horas grandes; em baixo o(s) utilizador(es)
//   com a foto redonda, o nome e o campo da senha; no fundo os
//   botoes Suspender / Reiniciar / Desligar. Fundo de Eta Carinae desfocado.
// Tudo e medido a partir do tamanho do ecra (fica nitido ate em 4K).
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Rectangle {
    id: raiz
    width: 1920
    height: 1080
    color: "black"

    // escala: 1.0 num ecra de 1440x900 (pontos de referencia do macOS)
    readonly property real s: Math.max(0.6, Math.min(width / 1440, height / 900))
    readonly property string letra: config.font ? config.font : "Inter"
    property int indiceUtilizador: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int indiceSessao: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property var nomes: []        // nomes de login, por indice do userModel
    property var sessoes: []      // nomes das sessoes, por indice
    property date agora: new Date()
    property bool aEntrar: false

    function entrar() {
        if (raiz.aEntrar || raiz.nomes[raiz.indiceUtilizador] === undefined) return
        raiz.aEntrar = true
        aviso.text = ""
        sddm.login(raiz.nomes[raiz.indiceUtilizador], senha.text, raiz.indiceSessao)
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            raiz.aEntrar = false
            senha.text = ""
            aviso.text = "Senha incorreta"
            abanar.restart()
            senha.forceActiveFocus()
        }
        function onLoginSucceeded() { aviso.text = "" }
    }

    Timer { interval: 1000; running: true; repeat: true; onTriggered: raiz.agora = new Date() }

    // ---- fundo -------------------------------------------------------------
    Image {
        id: fundo
        anchors.fill: parent
        source: config.background ? config.background : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize.width: raiz.width
        sourceSize.height: raiz.height
        // fica visivel por baixo: se o desfoque nao funcionar, ve-se o fundo
    }
    MultiEffect {
        anchors.fill: parent
        source: fundo
        autoPaddingEnabled: false
        blurEnabled: true
        blurMax: 64
        blur: 0.55
        brightness: -0.12
        saturation: 0.15
    }

    // ---- topo: estrela, data e horas --------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 54 * raiz.s
        spacing: 2 * raiz.s

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: config.logo ? config.logo : ""
            width: 30 * raiz.s; height: width
            sourceSize.width: width * 2; sourceSize.height: height * 2
            smooth: true
            opacity: 0.95
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            property string d: (Qt.locale().name.indexOf("pt") === 0 ? Qt.locale() : Qt.locale("pt_BR")).toString(raiz.agora, "dddd, d 'de' MMMM")
            text: d.charAt(0).toUpperCase() + d.slice(1)
            color: "#f2ffffff"
            font.family: raiz.letra
            font.pixelSize: 20 * raiz.s
            font.weight: Font.DemiBold
            topPadding: 8 * raiz.s
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(raiz.agora, "HH:mm")
            color: "#ecffffff"
            font.family: raiz.letra
            font.pixelSize: 104 * raiz.s
            font.weight: Font.Bold
            font.letterSpacing: -2 * raiz.s
        }
    }

    // nomes das sessoes (Plasma Wayland, Plasma X11...), sem mostrar nada
    Repeater {
        model: sessionModel
        delegate: Item {
            Component.onCompleted: { var a = raiz.sessoes.slice(); a[index] = model.name; raiz.sessoes = a }
        }
    }

    // ---- baixo: usuarios, senha ---------------------------------
    Column {
        id: blocoEntrada
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: barraEnergia.top
        anchors.bottomMargin: 64 * raiz.s
        spacing: 14 * raiz.s

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 34 * raiz.s

            Repeater {
                model: userModel
                delegate: Column {
                    id: pessoa
                    readonly property bool escolhido: index === raiz.indiceUtilizador
                    readonly property real d: (escolhido ? 76 : 54) * raiz.s
                    spacing: 8 * raiz.s
                    opacity: escolhido ? 1 : 0.72
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                    Component.onCompleted: { var a = raiz.nomes.slice(); a[index] = model.name; raiz.nomes = a }

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: pessoa.d; height: pessoa.d
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

                        Image {
                            id: foto
                            anchors.fill: parent
                            source: model.icon ? model.icon : ""
                            fillMode: Image.PreserveAspectCrop
                            sourceSize.width: 256; sourceSize.height: 256
                            visible: false
                            layer.enabled: true
                        }
                        Rectangle {
                            id: mascara
                            anchors.fill: parent
                            radius: width / 2
                            visible: false
                            layer.enabled: true
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: foto
                            maskEnabled: true
                            maskSource: mascara
                            visible: foto.status === Image.Ready
                        }
                        Image {
                            anchors.fill: parent
                            source: "icones/utilizador.svg"
                            sourceSize.width: 256; sourceSize.height: 256
                            visible: foto.status !== Image.Ready
                        }
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: "transparent"
                            border.color: "#40ffffff"
                            border.width: Math.max(1, raiz.s)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { raiz.indiceUtilizador = index; senha.text = ""; aviso.text = ""; senha.forceActiveFocus() }
                        }
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: model.realName ? model.realName : model.name
                        color: "white"
                        font.family: raiz.letra
                        font.pixelSize: (pessoa.escolhido ? 17 : 14) * raiz.s
                        font.weight: Font.DemiBold
                        style: Text.Raised; styleColor: "#30000000"
                    }
                }
            }
        }

        // campo da senha (pilula translucida, seta a direita)
        Item {
            id: caixaSenha
            anchors.horizontalCenter: parent.horizontalCenter
            width: 226 * raiz.s
            height: 32 * raiz.s

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: senha.activeFocus ? "#4dffffff" : "#38ffffff"
                border.color: "#38ffffff"
                border.width: Math.max(1, raiz.s * 0.8)
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            TextField {
                id: senha
                anchors.fill: parent
                anchors.leftMargin: 15 * raiz.s
                anchors.rightMargin: 34 * raiz.s
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: "white"
                font.family: raiz.letra
                font.pixelSize: 13.5 * raiz.s
                font.letterSpacing: echoMode === TextInput.Password && text.length > 0 ? 2 * raiz.s : 0
                horizontalAlignment: TextInput.AlignLeft
                verticalAlignment: TextInput.AlignVCenter
                leftPadding: 0
                background: Item {}
                selectByMouse: true
                enabled: !raiz.aEntrar
                focus: true
                onAccepted: raiz.entrar()
                Keys.onEscapePressed: { text = ""; aviso.text = "" }
                Component.onCompleted: forceActiveFocus()
            }
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 15 * raiz.s
                anchors.verticalCenter: parent.verticalCenter
                visible: senha.text.length === 0
                text: "Digite a senha"
                color: "#c8ffffff"
                font.family: raiz.letra
                font.pixelSize: 13.5 * raiz.s
            }
            // seta (aparece quando ha texto)
            Rectangle {
                width: 22 * raiz.s; height: width
                radius: width / 2
                anchors.right: parent.right
                anchors.rightMargin: 5 * raiz.s
                anchors.verticalCenter: parent.verticalCenter
                color: "#40ffffff"
                border.color: "#70ffffff"
                border.width: Math.max(1, raiz.s * 0.8)
                opacity: senha.text.length > 0 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Image {
                    anchors.centerIn: parent
                    source: "icones/seta.svg"
                    width: parent.width * 0.62; height: width
                    sourceSize.width: 64; sourceSize.height: 64
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: raiz.entrar() }
            }
            // abanar quando a senha esta errada (como no Mac)
            SequentialAnimation {
                id: abanar
                property real a: 14 * raiz.s
                NumberAnimation { target: caixaSenha; property: "anchors.horizontalCenterOffset"; to: -abanar.a; duration: 50 }
                NumberAnimation { target: caixaSenha; property: "anchors.horizontalCenterOffset"; to: abanar.a; duration: 70 }
                NumberAnimation { target: caixaSenha; property: "anchors.horizontalCenterOffset"; to: -abanar.a * 0.7; duration: 70 }
                NumberAnimation { target: caixaSenha; property: "anchors.horizontalCenterOffset"; to: abanar.a * 0.5; duration: 70 }
                NumberAnimation { target: caixaSenha; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60 }
            }
        }

        Text {
            id: aviso
            anchors.horizontalCenter: parent.horizontalCenter
            text: ""
            color: "#ffffffff"
            font.family: raiz.letra
            font.pixelSize: 12.5 * raiz.s
            height: 16 * raiz.s
            opacity: text.length > 0 ? 0.9 : 0
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: keyboard.capsLock
            text: "Caps Lock ativado"
            color: "#d8ffffff"
            font.family: raiz.letra
            font.pixelSize: 12 * raiz.s
        }
    }

    // ---- fundo do ecra: Suspender / Reiniciar / Desligar --------------------
    Row {
        id: barraEnergia
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40 * raiz.s
        spacing: 46 * raiz.s

        Repeater {
            model: [
                { nome: "Suspender", icone: "icones/suspender.svg", acao: "suspender" },
                { nome: "Reiniciar", icone: "icones/reiniciar.svg", acao: "reiniciar" },
                { nome: "Desligar",  icone: "icones/desligar.svg",  acao: "desligar" }
            ]
            delegate: Column {
                visible: modelData.acao === "suspender" ? sddm.canSuspend : modelData.acao === "reiniciar" ? sddm.canReboot : sddm.canPowerOff
                spacing: 7 * raiz.s
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40 * raiz.s; height: width; radius: width / 2
                    color: botao.containsMouse ? "#40ffffff" : "#24ffffff"
                    border.color: "#30ffffff"
                    border.width: Math.max(1, raiz.s * 0.8)
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Image {
                        anchors.centerIn: parent
                        source: modelData.icone
                        width: parent.width * 0.5; height: width
                        sourceSize.width: 96; sourceSize.height: 96
                    }
                    MouseArea {
                        id: botao
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { if (modelData.acao === "suspender") sddm.suspend(); else if (modelData.acao === "reiniciar") sddm.reboot(); else sddm.powerOff() }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.nome
                    color: "#e6ffffff"
                    font.family: raiz.letra
                    font.pixelSize: 12 * raiz.s
                }
            }
        }
    }

    // ---- canto inferior esquerdo: sessao (clicar troca) --------------------
    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 22 * raiz.s
        visible: raiz.sessoes.length > 1
        text: (raiz.sessoes[raiz.indiceSessao] || "") + "  ▾"
        color: "#b8ffffff"
        font.family: raiz.letra
        font.pixelSize: 12 * raiz.s
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: raiz.indiceSessao = (raiz.indiceSessao + 1) % raiz.sessoes.length
        }
    }
}
