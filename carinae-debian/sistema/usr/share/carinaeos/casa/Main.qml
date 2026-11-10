// CarinaeOS - Casa: o Home Assistant no computador
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: janela
    width: 1040; height: 720
    minimumWidth: 760; minimumHeight: 540
    visible: true
    title: "Casa"
    color: "#0d0a13"
    font.family: "Inter"; font.pixelSize: 14

    readonly property color ambar: "#ffb46e"
    readonly property color rosa: "#ff6f91"
    readonly property color texto: "#f4eee8"
    readonly property color textoSuave: "#b9aec4"
    readonly property color cartao: "#1a1524"
    property string separador: "casa"

    readonly property var grupos: [
        { dom: ["scene", "script"], nome: "Cenas e rotinas" },
        { dom: ["light"], nome: "Luzes" },
        { dom: ["switch", "input_boolean", "fan"], nome: "Interruptores" },
        { dom: ["cover", "lock"], nome: "Estores, portões e fechaduras" },
        { dom: ["climate"], nome: "Clima" },
        { dom: ["media_player"], nome: "Som e TV" },
        { dom: ["sensor", "binary_sensor"], nome: "Sensores" }
    ]

    function icone(e) {
        const ligado = ["on", "open", "playing", "unlocked", "heat", "cool", "auto"].indexOf(e.estado) !== -1;
        return ({ light: ligado ? "⬤" : "◯", scene: "✦", script: "▶", switch: "⏻", input_boolean: "⏻", fan: "✲",
                  cover: ligado ? "▤" : "▦", lock: ligado ? "🔓" : "🔒", climate: "🌡", media_player: "♫",
                  sensor: "◔", binary_sensor: ligado ? "●" : "○" })[e.dominio] || "•";
    }
    function ligado(e) { return ["on", "open", "playing", "unlocked"].indexOf(e.estado) !== -1 }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient { GradientStop { position: 0; color: "#141022" } GradientStop { position: 1; color: "#0a0810" } }
    }

    // ---- ligar ao Home Assistant ----------------------------------------------------------------
    Column {
        visible: !casa.ligado
        anchors.centerIn: parent
        width: Math.min(520, parent.width - 80)
        spacing: 14
        Image { anchors.horizontalCenter: parent.horizontalCenter; source: "image://icone/carinaeos-casa"; width: 84; height: 84; sourceSize: Qt.size(168, 168) }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Ligar ao Home Assistant"; color: janela.texto; font.pixelSize: 26; font.weight: Font.Bold }
        Text {
            width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; color: janela.textoSuave; font.pixelSize: 13
            text: "Controle luzes, cenas e aparelhos daqui e pela Eta (“acende a luz da sala”). No Home Assistant, abra o seu perfil › Segurança › “Tokens de acesso de longa duração” › Criar token, e cole-o aqui."
        }
        TextField { id: campoUrl; width: parent.width; placeholderText: "Endereço (ex.: homeassistant.local ou 192.168.1.20)"; text: casa.url; color: janela.texto
                    background: Rectangle { radius: 10; color: Qt.rgba(1, 1, 1, 0.06); border.color: Qt.rgba(1, 1, 1, 0.15) } }
        TextField { id: campoToken; width: parent.width; placeholderText: "Token de acesso"; echoMode: TextInput.Password; color: janela.texto
                    background: Rectangle { radius: 10; color: Qt.rgba(1, 1, 1, 0.06); border.color: Qt.rgba(1, 1, 1, 0.15) }
                    onAccepted: casa.conectar(campoUrl.text, campoToken.text) }
        Text { visible: casa.erro !== ""; width: parent.width; wrapMode: Text.WordWrap; text: casa.erro; color: janela.rosa; font.pixelSize: 13 }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 200; height: 42; radius: 21; opacity: casa.ocupado ? 0.6 : 1
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: janela.rosa } GradientStop { position: 1; color: janela.ambar } }
            Text { anchors.centerIn: parent; text: casa.ocupado ? "A ligar…" : "Ligar"; color: "#1a0f14"; font.weight: Font.Bold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: casa.conectar(campoUrl.text, campoToken.text) }
        }
    }

    // ---- a casa ------------------------------------------------------------------------------------
    Item {
        visible: casa.ligado
        anchors.fill: parent

        Row {
            id: topo
            x: 32; y: 24; spacing: 14
            Image { source: "image://icone/carinaeos-casa"; width: 48; height: 48; sourceSize: Qt.size(96, 96) }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: casa.nome; color: janela.texto; font.pixelSize: 26; font.weight: Font.Bold }
                Text { text: casa.erro !== "" ? casa.erro : casa.url + " · ligado"; color: casa.erro !== "" ? janela.rosa : janela.textoSuave; font.pixelSize: 12 }
            }
        }
        Row {
            anchors.right: parent.right; anchors.rightMargin: 32; y: 34; spacing: 8
            Repeater {
                model: [{ id: "casa", n: "A casa" }, { id: "pc", n: "Este computador" }]
                delegate: Rectangle {
                    required property var modelData
                    width: sepTxt.implicitWidth + 28; height: 32; radius: 16
                    color: janela.separador === modelData.id ? Qt.rgba(1, 0.7, 0.43, 0.2) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: janela.separador === modelData.id ? janela.ambar : Qt.rgba(1, 1, 1, 0.1)
                    Text { id: sepTxt; anchors.centerIn: parent; text: modelData.n; color: janela.texto; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: janela.separador = modelData.id }
                }
            }
            Rectangle {
                width: 32; height: 32; radius: 16; color: Qt.rgba(1, 1, 1, 0.05)
                Image { anchors.centerIn: parent; width: 16; height: 16; source: "image://icone/internet-web-browser"; sourceSize: Qt.size(32, 32) }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: casa.abrirNoNavegador() }
                ToolTip.text: "Abrir o Home Assistant no navegador"; ToolTip.visible: false
            }
        }

        ScrollView {
            visible: janela.separador === "casa"
            anchors.top: topo.bottom; anchors.topMargin: 20; anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            contentWidth: availableWidth; clip: true
            Column {
                width: parent.width; leftPadding: 32; rightPadding: 32; bottomPadding: 32; spacing: 24
                Text { visible: casa.entidades.length === 0; text: "A carregar a casa…"; color: janela.textoSuave }
                Repeater {
                    model: janela.grupos
                    delegate: Column {
                        id: grupo
                        required property var modelData
                        readonly property var itens: casa.entidades.filter(e => grupo.modelData.dom.indexOf(e.dominio) !== -1)
                        visible: itens.length > 0
                        width: parent.width - 64
                        spacing: 10
                        Text { text: grupo.modelData.nome; color: janela.textoSuave; font.pixelSize: 13; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase }
                        Flow {
                            width: parent.width; spacing: 12
                            Repeater {
                                model: grupo.itens
                                delegate: Rectangle {
                                    id: cart
                                    required property var modelData
                                    readonly property var e: modelData
                                    readonly property bool aceso: janela.ligado(e)
                                    width: e.dominio === "scene" || e.dominio === "script" ? cenaTxt.implicitWidth + 64 : 230
                                    height: e.dominio === "scene" || e.dominio === "script" ? 44 : (e.dominio === "light" || e.dominio === "climate" ? 118 : 86)
                                    radius: e.dominio === "scene" || e.dominio === "script" ? 22 : 18
                                    color: aceso ? Qt.rgba(1, 0.75, 0.4, 0.18) : janela.cartao
                                    border.color: aceso ? Qt.rgba(1, 0.7, 0.43, 0.6) : Qt.rgba(1, 1, 1, 0.08)
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    // cenas: pílula
                                    Row {
                                        visible: cart.e.dominio === "scene" || cart.e.dominio === "script"
                                        anchors.centerIn: parent; spacing: 8
                                        Text { text: janela.icone(cart.e); color: janela.ambar; font.pixelSize: 15 }
                                        Text { id: cenaTxt; text: cart.e.nome; color: janela.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
                                    }
                                    // aparelhos: cartão
                                    Column {
                                        visible: !(cart.e.dominio === "scene" || cart.e.dominio === "script")
                                        x: 16; y: 14; width: parent.width - 32; spacing: 6
                                        Row {
                                            width: parent.width; spacing: 10
                                            Rectangle {
                                                width: 34; height: 34; radius: 17
                                                color: cart.aceso ? "#ffd27a" : Qt.rgba(1, 1, 1, 0.08)
                                                Text { anchors.centerIn: parent; text: janela.icone(cart.e); color: cart.aceso ? "#5a3300" : janela.textoSuave; font.pixelSize: 15 }
                                            }
                                            Column {
                                                width: parent.width - 44
                                                Text { width: parent.width; elide: Text.ElideRight; text: cart.e.nome; color: janela.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
                                                Text {
                                                    width: parent.width; elide: Text.ElideRight; color: janela.textoSuave; font.pixelSize: 12
                                                    text: cart.e.dominio === "sensor" ? cart.e.estado + " " + cart.e.unidade
                                                        : cart.e.dominio === "climate" ? (cart.e.temperatura !== "" ? cart.e.temperatura + "° agora · alvo " + cart.e.alvo + "°" : cart.e.estado)
                                                        : cart.e.dominio === "light" && cart.aceso && cart.e.brilho >= 0 ? "acesa · " + cart.e.brilho + "%"
                                                        : ({ on: "ligado", off: "desligado", open: "aberto", closed: "fechado", playing: "a tocar", paused: "em pausa", idle: "parado", locked: "trancado", unlocked: "destrancado", unavailable: "indisponível" })[cart.e.estado] || cart.e.estado
                                                }
                                            }
                                        }
                                        Slider {
                                            visible: cart.e.dominio === "light"
                                            width: parent.width; from: 1; to: 100; stepSize: 1
                                            value: cart.e.brilho > 0 ? cart.e.brilho : 0
                                            onPressedChanged: if (!pressed) casa.brilho(cart.e.id, Math.round(value))
                                        }
                                        Row {
                                            visible: cart.e.dominio === "climate"
                                            spacing: 8
                                            Repeater {
                                                model: ["−", "+"]
                                                delegate: Rectangle {
                                                    required property string modelData
                                                    width: 40; height: 30; radius: 15; color: Qt.rgba(1, 1, 1, 0.08)
                                                    Text { anchors.centerIn: parent; text: modelData; color: janela.texto; font.pixelSize: 18 }
                                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                                onClicked: casa.temperatura(cart.e.id, (parseFloat(cart.e.alvo) || 20) + (modelData === "+" ? 0.5 : -0.5)) }
                                                }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; z: -1
                                        enabled: ["sensor", "binary_sensor", "climate"].indexOf(cart.e.dominio) === -1
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: casa.alternar(cart.e.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---- este computador no Home Assistant --------------------------------------------------------
        Column {
            visible: janela.separador === "pc"
            anchors.top: topo.bottom; anchors.topMargin: 24
            x: 32; width: Math.min(640, parent.width - 64); spacing: 12
            Text { text: "Este computador no Home Assistant"; color: janela.texto; font.pixelSize: 20; font.weight: Font.DemiBold }
            Text {
                width: parent.width; wrapMode: Text.WordWrap; color: janela.textoSuave; font.pixelSize: 13
                text: "Com o MQTT (Mosquitto) do Home Assistant, este computador aparece como um dispositivo: processador, memória, disco, volume e bateria, e botões para desligar, reiniciar, suspender, bloquear o ecrã ou silenciar — para usar em automações. Também pode mandar avisos para o ecrã."
            }
            TextField { id: mHost; width: parent.width; placeholderText: "Servidor MQTT (normalmente o endereço do Home Assistant)"; text: casa.mqttHost; color: janela.texto
                        background: Rectangle { radius: 10; color: Qt.rgba(1, 1, 1, 0.06); border.color: Qt.rgba(1, 1, 1, 0.15) } }
            TextField { id: mUser; width: parent.width; placeholderText: "Usuário MQTT"; text: casa.mqttUsuario; color: janela.texto
                        background: Rectangle { radius: 10; color: Qt.rgba(1, 1, 1, 0.06); border.color: Qt.rgba(1, 1, 1, 0.15) } }
            TextField { id: mSenha; width: parent.width; placeholderText: "Senha MQTT"; echoMode: TextInput.Password; color: janela.texto
                        background: Rectangle { radius: 10; color: Qt.rgba(1, 1, 1, 0.06); border.color: Qt.rgba(1, 1, 1, 0.15) } }
            Row {
                spacing: 10
                Rectangle {
                    width: 220; height: 40; radius: 20
                    gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: janela.rosa } GradientStop { position: 1; color: janela.ambar } }
                    Text { anchors.centerIn: parent; text: casa.agente ? "Guardar e religar" : "Ligar este computador"; color: "#1a0f14"; font.weight: Font.Bold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: casa.definirAgente(true, mHost.text, mUser.text, mSenha.text) }
                }
                Rectangle {
                    visible: casa.agente
                    width: 120; height: 40; radius: 20; color: Qt.rgba(1, 1, 1, 0.08)
                    Text { anchors.centerIn: parent; text: "Desligar"; color: janela.texto }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: casa.definirAgente(false, "", "", "") }
                }
            }
            Text { text: casa.agente ? "✓ Ligado: procure “CarinaeOS” em Definições › Dispositivos no Home Assistant." : ""; color: "#8fe3a8"; font.pixelSize: 13 }
            Item { width: 1; height: 20 }
            Rectangle {
                width: 220; height: 36; radius: 18; color: Qt.rgba(1, 1, 1, 0.06)
                Text { anchors.centerIn: parent; text: "Desligar do Home Assistant"; color: janela.textoSuave; font.pixelSize: 13 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: casa.desconectar() }
            }
        }
    }
}
