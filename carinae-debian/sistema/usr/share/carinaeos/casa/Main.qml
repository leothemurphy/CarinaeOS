// CarinaeOS - Casa: os painéis do Home Assistant, com o visual do próprio Home Assistant e
// cartões no estilo Mushroom. Os painéis são os separadores do topo, como as "vistas" do HA.
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: janela
    width: 1220; height: 800
    minimumWidth: 760; minimumHeight: 540
    visible: true
    title: "Carinae Casa"
    color: "#111111"
    font.family: "Inter"; font.pixelSize: 14

    readonly property color primaria: "#03a9f4"
    readonly property color texto: "#e1e1e1"
    readonly property color textoSuave: "#9b9b9b"
    readonly property color cartao: "#1c1c1c"
    readonly property color divisor: Qt.rgba(1, 1, 1, 0.12)
    property string separador: "casa"
    property int painel: 0
    property bool editar: false
    readonly property var est: JSON.parse(casa.estadosJson)
    readonly property var extras: JSON.parse(casa.extrasJson)
    readonly property var todas: JSON.parse(casa.todasJson)
    readonly property var mdi: JSON.parse(casa.iconesJson)

    FontLoader { source: "mdi.ttf" }

    // ---- ícones, cores e textos dos estados (as mesmas regras do Home Assistant) ---------------------
    function ic(n) {
        const k = (n || "").replace("mdi:", "")
        return String.fromCodePoint(mdi[k] || mdi["help-circle-outline"])
    }
    function ligadoE(e) {
        return e !== null && e !== undefined && ["on", "open", "opening", "closing", "playing", "buffering", "unlocked", "unlocking", "home",
                "heat", "cool", "heat_cool", "auto", "dry", "fan_only", "cleaning", "armed_home", "armed_away",
                "armed_night", "armed_vacation", "triggered"].indexOf(e.estado) !== -1
    }
    function alternavel(e) {
        return e && ["light", "switch", "fan", "input_boolean", "lock", "cover", "scene", "script", "button",
                     "input_button", "automation", "media_player", "humidifier"].indexOf(e.dominio) !== -1
    }
    // a cor de um aparelho ligado; "" quando está desligado (o cartão fica cinzento)
    function tinta(e) {
        if (!e || e.estado === "unavailable" || e.estado === "unknown") return ""
        const d = e.dominio, s = e.estado
        if (d === "sensor") return ({ temperature: "#ff7043", humidity: "#29b6f6", power: "#ffc107", energy: "#ffc107", battery: "#66bb6a",
                                      illuminance: "#ffc107", carbon_dioxide: "#9e9e9e", pressure: "#7e57c2" })[e.classe] || "#03a9f4"
        if (d === "weather") return "#ffb300"
        if (d === "lock") return s === "locked" ? "#4caf50" : s === "unlocked" ? "#f44336" : ""
        if (d === "climate") return ({ heat: "#ff7043", cool: "#29b6f6", heat_cool: "#4caf50", auto: "#4caf50", dry: "#ff9800", fan_only: "#00bcd4" })[s] || ""
        if (d === "alarm_control_panel") return s === "disarmed" ? "" : s === "triggered" ? "#f44336" : "#4caf50"
        if (d === "person") return s === "home" ? "#4caf50" : ""
        if (["scene", "script", "button", "input_button", "automation", "camera", "input_number", "number", "select", "input_select"].indexOf(d) !== -1) return "#03a9f4"
        if (!ligadoE(e)) return ""
        return ({ light: "#ffc107", switch: "#ffc107", input_boolean: "#ffc107", fan: "#00bcd4", cover: "#ab47bc", media_player: "#03a9f4",
                  binary_sensor: "#ffc107", vacuum: "#4caf50", humidifier: "#29b6f6", water_heater: "#ff7043" })[d] || "#03a9f4"
    }
    function tempoIcone(cond) {
        return "weather-" + (({ sunny: "sunny", "clear-night": "night", partlycloudy: "partly-cloudy", cloudy: "cloudy", rainy: "rainy",
                                 pouring: "pouring", lightning: "lightning", "lightning-rainy": "lightning-rainy", snowy: "snowy",
                                 "snowy-rainy": "snowy-rainy", fog: "fog", windy: "windy", "windy-variant": "windy-variant", hail: "hail" })[cond] || "cloudy")
    }
    function condicao(cond) {
        return ({ sunny: "Ensolarado", "clear-night": "Noite limpa", partlycloudy: "Parcialmente nublado", cloudy: "Nublado",
                  rainy: "Chuva", pouring: "Chuva forte", lightning: "Trovoadas", "lightning-rainy": "Trovoadas com chuva",
                  snowy: "Neve", "snowy-rainy": "Neve e chuva", fog: "Neblina", windy: "Vento", "windy-variant": "Vento e nuvens",
                  hail: "Granizo", exceptional: "Excepcional" })[cond] || cond
    }
    function iconeDe(e) {
        if (!e) return "help-circle-outline"
        if (e.icone) return e.icone
        const d = e.dominio, s = e.estado, on = ligadoE(e)
        switch (d) {
        case "light": return on ? "lightbulb" : "lightbulb-outline"
        case "switch": case "input_boolean": return on ? "toggle-switch-variant" : "toggle-switch-variant-off"
        case "fan": return on ? "fan" : "fan-off"
        case "cover": return e.classe === "garage" ? (on ? "garage-open" : "garage") : e.classe === "gate" ? (on ? "gate-open" : "gate")
                             : (on ? "window-shutter-open" : "window-shutter")
        case "lock": return s === "unlocked" ? "lock-open-variant" : "lock"
        case "climate": return "thermostat"
        case "media_player": return e.classe === "tv" ? "television" : "speaker"
        case "sensor": return ({ temperature: "thermometer", humidity: "water-percent", power: "flash", energy: "lightning-bolt",
                                 battery: "battery", illuminance: "brightness-5", carbon_dioxide: "molecule-co2", pressure: "gauge",
                                 voltage: "sine-wave", current: "current-ac" })[e.classe] || "eye"
        case "binary_sensor": return ({ door: on ? "door-open" : "door-closed", window: on ? "window-open" : "window-closed",
                                        motion: on ? "motion-sensor" : "motion-sensor-off", occupancy: on ? "home-account" : "home-outline",
                                        moisture: on ? "water" : "water-off", smoke: on ? "smoke-detector-alert" : "smoke-detector",
                                        connectivity: on ? "check-network" : "close-network" })[e.classe] || (on ? "checkbox-marked-circle" : "radiobox-blank")
        case "scene": return "palette"
        case "script": return "script-text-play"
        case "automation": return "robot"
        case "button": case "input_button": return "gesture-tap-button"
        case "camera": return "cctv"
        case "weather": return tempoIcone(s)
        case "person": return on ? "account" : "account-arrow-right"
        case "vacuum": return "robot-vacuum"
        case "alarm_control_panel": return s === "disarmed" ? "shield-off" : "shield-home"
        case "humidifier": return "air-humidifier"
        case "water_heater": return "water-boiler"
        case "input_number": case "number": return "ray-vertex"
        case "select": case "input_select": return "format-list-bulleted"
        }
        return "help-circle-outline"
    }
    function num(v) {
        const n = parseFloat(v)
        if (isNaN(n) || String(v).trim() === "") return v
        const dec = Math.min(2, (String(v).split(".")[1] || "").length)
        return n.toLocaleString(Qt.locale("pt_BR"), "f", dec)
    }
    function estadoTexto(e) {
        if (!e) return "Não encontrado"
        if (e.dominio === "sensor") return num(e.estado) + (e.unidade ? " " + e.unidade : "")
        if (e.dominio === "weather") return condicao(e.estado)
        const t = ({ on: "Ligado", off: "Desligado", open: "Aberto", closed: "Fechado", opening: "Abrindo", closing: "Fechando",
                     playing: "Tocando", paused: "Em pausa", idle: "Parado", standby: "Em espera", buffering: "Carregando",
                     locked: "Trancado", unlocked: "Destrancado", locking: "Trancando", unlocking: "Destrancando", jammed: "Encravado",
                     unavailable: "Indisponível", unknown: "Desconhecido", home: "Em casa", not_home: "Fora",
                     heat: "Aquecendo", cool: "Resfriando", heat_cool: "Automático", auto: "Automático", dry: "Desumidificando",
                     fan_only: "Só ventilação", cleaning: "Limpando", docked: "Na base", returning: "Voltando à base",
                     disarmed: "Desarmado", armed_home: "Armado em casa", armed_away: "Armado fora", armed_night: "Armado à noite",
                     triggered: "Disparado" })[e.estado]
        if (t) {
            if (e.dominio === "light" && e.estado === "on") return "Acesa"
            if (e.dominio === "light" && e.estado === "off") return "Apagada"
            if (e.dominio === "cover") return ({ open: "Aberta", closed: "Fechada" })[e.estado] || t
            if (e.dominio === "binary_sensor") {
                const on = e.estado === "on"
                return ({ door: on ? "Aberta" : "Fechada", window: on ? "Aberta" : "Fechada", motion: on ? "Movimento" : "Sem movimento",
                          occupancy: on ? "Ocupado" : "Livre", moisture: on ? "Molhado" : "Seco", smoke: on ? "Fumaça!" : "Normal",
                          connectivity: on ? "Conectado" : "Desconectado" })[e.classe] || t
            }
            return t
        }
        if (["scene", "script", "button", "input_button", "automation"].indexOf(e.dominio) !== -1) return "Toque para ativar"
        return e.estado
    }
    function saudar(t) {
        const h = new Date().getHours()
        return t.replace("{saudacao}", h < 5 ? "Boa noite" : h < 12 ? "Bom dia" : h < 19 ? "Boa tarde" : "Boa noite")
                .replace("{nome}", casa.usuario)
    }

    // ---- ligar ao Home Assistant -------------------------------------------------------------------
    Rectangle {
        visible: !casa.ligado
        anchors.centerIn: parent
        width: Math.min(460, parent.width - 60); height: ligar.implicitHeight + 64
        radius: 16; color: janela.cartao; border.color: Qt.rgba(1, 1, 1, 0.07)
        Column {
            id: ligar
            x: 32; y: 32; width: parent.width - 64
            spacing: 14
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: janela.ic("home-assistant"); font.family: "Material Design Icons"; font.pixelSize: 64; color: janela.primaria }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Conectar ao Home Assistant"; color: janela.texto; font.pixelSize: 22; font.weight: Font.DemiBold }
            Text {
                width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; color: janela.textoSuave; font.pixelSize: 13
                text: "No Home Assistant, abra o seu perfil › Segurança › “Tokens de acesso de longa duração” › Criar token, e cole-o aqui."
            }
            Campo { id: campoUrl; width: parent.width; placeholderText: "Endereço (ex.: homeassistant.local ou 192.168.1.20)"; text: casa.url }
            Campo { id: campoToken; width: parent.width; placeholderText: "Token de acesso"; echoMode: TextInput.Password
                    onAccepted: casa.conectar(campoUrl.text, campoToken.text) }
            Text { visible: casa.erro !== ""; width: parent.width; wrapMode: Text.WordWrap; text: casa.erro; color: "#ef5350"; font.pixelSize: 13 }
            Botao { anchors.right: parent.right; texto: casa.ocupado ? "Conectando…" : "Conectar"; principal: true; onClicado: casa.conectar(campoUrl.text, campoToken.text) }
        }
    }

    // ---- a casa ---------------------------------------------------------------------------------------
    Item {
        visible: casa.ligado
        anchors.fill: parent

        // barra lateral, como a do Home Assistant
        Rectangle {
            id: lado
            width: janela.width < 960 ? 64 : 236; height: parent.height
            readonly property bool estreita: width < 100
            color: janela.cartao
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.06) }
            Item {
                width: parent.width; height: 56
                Text { x: 20; anchors.verticalCenter: parent.verticalCenter; text: janela.ic("home-assistant"); font.family: "Material Design Icons"; font.pixelSize: 26; color: janela.primaria }
                Text { x: 64; anchors.verticalCenter: parent.verticalCenter; visible: !lado.estreita; text: casa.nome; color: janela.texto; font.pixelSize: 19; width: parent.width - 76; elide: Text.ElideRight }
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
            }
            Column {
                y: 64; width: parent.width
                Repeater {
                    model: [{ id: "casa", i: "view-dashboard", n: "Visão geral" },
                            { id: "pc", i: "monitor", n: "Este computador" },
                            { id: "web", i: "open-in-new", n: "Home Assistant" }]
                    delegate: Item {
                        required property var modelData
                        readonly property bool ativo: janela.separador === modelData.id
                        width: parent.width; height: 48
                        Rectangle {
                            x: 8; width: parent.width - 16; height: 40; anchors.verticalCenter: parent.verticalCenter; radius: 8
                            color: parent.ativo ? Qt.rgba(0.012, 0.663, 0.957, 0.14) : ml.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                        }
                        Text { x: 20; anchors.verticalCenter: parent.verticalCenter; text: janela.ic(modelData.i); font.family: "Material Design Icons"; font.pixelSize: 24
                               color: parent.ativo ? janela.primaria : janela.textoSuave }
                        Text { x: 64; anchors.verticalCenter: parent.verticalCenter; visible: !lado.estreita; text: modelData.n; font.pixelSize: 14; font.weight: Font.DemiBold
                               color: parent.ativo ? janela.primaria : janela.texto; width: parent.width - 76; elide: Text.ElideRight }
                        MouseArea { id: ml; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.id === "web" ? casa.abrirNoNavegador() : janela.separador = modelData.id }
                        ToolTip.visible: lado.estreita && ml.containsMouse; ToolTip.text: modelData.n
                    }
                }
            }
            Row {
                anchors.bottom: parent.bottom; anchors.bottomMargin: 18; x: 22; spacing: 10
                Rectangle { width: 10; height: 10; radius: 5; anchors.verticalCenter: parent.verticalCenter; color: casa.erro !== "" ? "#ef5350" : "#4caf50" }
                Text { visible: !lado.estreita; text: casa.erro !== "" ? "Sem conexão" : "Conectado"; color: janela.textoSuave; font.pixelSize: 12 }
            }
        }

        // barra do topo: título, os painéis em separadores e o lápis de editar
        Rectangle {
            id: topo
            x: lado.width; width: parent.width - lado.width; height: 56
            color: janela.editar ? "#2b2b2b" : "#111111"
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
            Text {
                id: tituloTopo
                x: 20; anchors.verticalCenter: parent.verticalCenter
                text: janela.separador === "pc" ? "Este computador" : janela.editar ? "Editar painel" : casa.nome
                color: janela.texto; font.pixelSize: 20
            }
            ListView {
                id: abas
                visible: janela.separador === "casa"
                x: tituloTopo.x + tituloTopo.width + 28; width: parent.width - x - direita.width - 24; height: parent.height
                orientation: ListView.Horizontal; clip: true; boundsBehavior: Flickable.StopAtBounds
                model: casa.paineis.length + (janela.editar ? 1 : 0)
                delegate: Item {
                    required property int index
                    readonly property bool mais: index >= casa.paineis.length
                    readonly property bool ativo: !mais && janela.painel === index
                    width: mais ? 48 : rot.implicitWidth + 32; height: abas.height
                    Text {
                        id: rot
                        anchors.centerIn: parent
                        text: parent.mais ? janela.ic("plus") : casa.paineis[index].nome
                        font.family: parent.mais ? "Material Design Icons" : "Inter"; font.pixelSize: parent.mais ? 22 : 14; font.weight: Font.DemiBold
                        color: parent.ativo ? janela.primaria : janela.textoSuave
                    }
                    Rectangle { visible: parent.ativo; anchors.bottom: parent.bottom; x: 8; width: parent.width - 16; height: 2; color: janela.primaria }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: parent.mais ? dlgPainel.abrir(-1) : (janela.editar && parent.ativo ? dlgPainel.abrir(index) : janela.painel = index)
                    }
                    ToolTip.visible: janela.editar && ativo && hov.hovered; ToolTip.text: "Clique para renomear"
                    HoverHandler { id: hov }
                }
            }
            Row {
                id: direita
                visible: janela.separador === "casa"
                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; spacing: 4
                Botao { visible: janela.editar && casa.paineis.length > 1; texto: "Apagar painel"; perigo: true
                        onClicado: { casa.apagarPainel(janela.painel); janela.painel = 0 } }
                Botao { visible: janela.editar; texto: "Concluído"; principal: true; onClicado: janela.editar = false }
                Rectangle {
                    visible: !janela.editar
                    width: 40; height: 40; radius: 20; color: lp.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                    Text { anchors.centerIn: parent; text: janela.ic("pencil"); font.family: "Material Design Icons"; font.pixelSize: 22; color: janela.texto }
                    MouseArea { id: lp; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: janela.editar = true }
                    ToolTip.visible: lp.containsMouse; ToolTip.text: "Editar painel"
                }
            }
        }

        // os cartões, em colunas como a vista "alvenaria" do Home Assistant
        Flickable {
            id: rolar
            visible: janela.separador === "casa"
            x: lado.width; y: topo.height; width: parent.width - lado.width; height: parent.height - topo.height
            contentHeight: Math.max(height, grade.height + 110); clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            readonly property var cartoes: casa.paineis.length > janela.painel ? casa.paineis[janela.painel].cartoes : []

            Item {
                id: grade
                x: 16; y: 16; width: rolar.width - 32; height: altura
                property real altura: 0
                readonly property int colunas: Math.max(1, Math.min(4, Math.floor((width + 8) / 318)))
                readonly property real col: (width - (colunas - 1) * 8) / colunas
                onColunasChanged: Qt.callLater(arrumar)
                onWidthChanged: Qt.callLater(arrumar)
                // cada cartão vai para a coluna mais baixa (os largos ocupam várias, onde ficam mais acima)
                function arrumar() {
                    const h = []
                    for (let j = 0; j < colunas; j++) h.push(0)
                    for (let i = 0; i < rep.count; i++) {
                        const it = rep.itemAt(i)
                        if (!it) continue
                        const w = Math.min(colunas, it.largura)
                        let melhor = 0, melhorY = Infinity
                        for (let j = 0; j + w <= colunas; j++) {
                            const y = Math.max.apply(null, h.slice(j, j + w))
                            if (y < melhorY - 0.5) { melhorY = y; melhor = j }
                        }
                        it.x = melhor * (col + 8); it.y = melhorY; it.width = w * col + (w - 1) * 8
                        for (let j = melhor; j < melhor + w; j++) h[j] = melhorY + it.height + 8
                    }
                    altura = Math.max.apply(null, h)
                }
                Repeater {
                    id: rep
                    model: rolar.cartoes
                    onItemAdded: Qt.callLater(grade.arrumar)
                    onItemRemoved: Qt.callLater(grade.arrumar)
                    delegate: Cartao {
                        required property var modelData
                        required property int index
                        dados: modelData; indice: index; editar: janela.editar
                        height: implicitHeight
                        onHeightChanged: Qt.callLater(grade.arrumar)
                        onPedirApagar: casa.apagarCartao(janela.painel, index)
                        onPedirMover: (para) => casa.moverCartao(janela.painel, index, para)
                        onPedirEditar: dlgCartao.abrir(index)
                    }
                }
            }

            Column {
                visible: rolar.cartoes.length === 0
                anchors.horizontalCenter: parent.horizontalCenter; y: 90; spacing: 14
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: janela.ic("view-dashboard-outline"); font.family: "Material Design Icons"; font.pixelSize: 56; color: janela.textoSuave }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: janela.todas.length ? "Este painel está vazio" : "Carregando a casa…"; color: janela.texto; font.pixelSize: 20 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Monte-o como quiser: luzes, chips, gráficos, câmeras, clima, cenas…"; color: janela.textoSuave }
                Row {
                    visible: janela.todas.length > 0
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
                    Botao { texto: "Adicionar cartão"; icone: "plus"; principal: true; onClicado: { janela.editar = true; dlgCartao.abrir(-1) } }
                    Botao { texto: "Sugerir um painel"; icone: "auto-fix"; onClicado: casa.sugerirPainel(janela.painel) }
                }
            }
        }

        // o botão flutuante de adicionar, como no Home Assistant
        Rectangle {
            visible: janela.editar && janela.separador === "casa"
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 24
            width: fab.implicitWidth + 40; height: 56; radius: 16; color: fabM.pressed ? "#0288d1" : janela.primaria
            Row {
                id: fab
                anchors.centerIn: parent; spacing: 10
                Text { text: janela.ic("plus"); font.family: "Material Design Icons"; font.pixelSize: 24; color: "white"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Adicionar cartão"; color: "white"; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { id: fabM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dlgCartao.abrir(-1) }
        }

        // ---- este computador no Home Assistant ----------------------------------------------------------
        Flickable {
            visible: janela.separador === "pc"
            x: lado.width; y: topo.height; width: parent.width - lado.width; height: parent.height - topo.height
            contentHeight: pcCol.height + 60; clip: true
            Column {
                id: pcCol
                x: 24; y: 24; width: Math.min(680, parent.width - 48); spacing: 16
                Rectangle {
                    width: parent.width; height: pcInt.implicitHeight + 40; radius: 12; color: janela.cartao; border.color: Qt.rgba(1, 1, 1, 0.07)
                    Column {
                        id: pcInt
                        x: 20; y: 20; width: parent.width - 40; spacing: 12
                        Row {
                            spacing: 12
                            Forma { icone: janela.ic("monitor"); tinta: casa.agente ? "#4caf50" : "" }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: "Este computador no Home Assistant"; color: janela.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
                                Text { text: casa.agente ? "Conectado pelo MQTT" : "Desligado"; color: casa.agente ? "#66bb6a" : janela.textoSuave; font.pixelSize: 12 }
                            }
                        }
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap; color: janela.textoSuave; font.pixelSize: 13
                            text: "Com o MQTT (Mosquitto) do Home Assistant, este computador aparece como um dispositivo: processador, memória, disco, volume e bateria, e botões para desligar, reiniciar, suspender, bloquear a tela ou silenciar — para usar em automações. Também pode mandar avisos para a tela."
                        }
                        Campo { id: mHost; width: parent.width; placeholderText: "Servidor MQTT (normalmente o endereço do Home Assistant)"; text: casa.mqttHost }
                        Campo { id: mUser; width: parent.width; placeholderText: "Usuário MQTT"; text: casa.mqttUsuario }
                        Campo { id: mSenha; width: parent.width; placeholderText: "Senha MQTT"; echoMode: TextInput.Password }
                        Row {
                            spacing: 10; anchors.right: parent.right
                            Botao { visible: casa.agente; texto: "Desligar"; onClicado: casa.definirAgente(false, "", "", "") }
                            Botao { texto: casa.agente ? "Salvar e reconectar" : "Conectar este computador"; principal: true; onClicado: casa.definirAgente(true, mHost.text, mUser.text, mSenha.text) }
                        }
                        Text { visible: casa.agente; width: parent.width; wrapMode: Text.WordWrap; text: "Procure “CarinaeOS” em Configurações › Dispositivos e serviços › MQTT, no Home Assistant."; color: janela.textoSuave; font.pixelSize: 12 }
                    }
                }
                Rectangle {
                    width: parent.width; height: 76; radius: 12; color: janela.cartao; border.color: Qt.rgba(1, 1, 1, 0.07)
                    Column {
                        x: 20; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 220
                        Text { text: "Conectado a " + casa.nome; color: janela.texto; font.pixelSize: 14; font.weight: Font.DemiBold; width: parent.width; elide: Text.ElideRight }
                        Text { text: casa.url; color: janela.textoSuave; font.pixelSize: 12; width: parent.width; elide: Text.ElideRight }
                    }
                    Botao { anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; texto: "Desconectar"; perigo: true; onClicado: casa.desconectar() }
                }
            }
        }
    }

    // ---- novo painel / renomear --------------------------------------------------------------------------
    Popup {
        id: dlgPainel
        property int indice: -1
        function abrir(i) { indice = i; nomeP.text = i >= 0 ? casa.paineis[i].nome : ""; open(); nomeP.forceActiveFocus() }
        function salvar() {
            if (indice >= 0) casa.renomearPainel(indice, nomeP.text)
            else { casa.novoPainel(nomeP.text); janela.painel = casa.paineis.length - 1; janela.editar = true }
            close()
        }
        modal: true; anchors.centerIn: parent; width: 400; padding: 24
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }
        background: Rectangle { radius: 24; color: "#262626" }
        contentItem: Column {
            spacing: 18
            Text { text: dlgPainel.indice >= 0 ? "Renomear painel" : "Novo painel"; color: janela.texto; font.pixelSize: 22 }
            Campo { id: nomeP; width: parent.width; placeholderText: "Ex.: Sala, Quarto, Energia"; onAccepted: dlgPainel.salvar() }
            Row {
                anchors.right: parent.right; spacing: 8
                Botao { texto: "Cancelar"; plano: true; onClicado: dlgPainel.close() }
                Botao { texto: "Salvar"; plano: true; onClicado: dlgPainel.salvar() }
            }
        }
    }

    // ---- adicionar / editar cartão (o seletor de cartões do Home Assistant) -----------------------------------
    Popup {
        id: dlgCartao
        objectName: "dlgCartao"
        property int indice: -1
        property string tipo: "botao"
        property var escolhidas: []
        property int largura: 1
        readonly property var info: casa.tipos.find(t => t.id === tipo) || casa.tipos[0]
        function abrir(i) {
            indice = i
            if (i >= 0) {
                const c = casa.paineis[janela.painel].cartoes[i]
                tipo = c.tipo; escolhidas = c.ents.slice(); largura = c.largura; tituloC.text = c.titulo
            } else { tipo = "botao"; escolhidas = []; largura = 1; tituloC.text = "" }
            procura.text = ""
            open()
        }
        function alternarEnt(eid) {
            const l = escolhidas.slice(), k = l.indexOf(eid)
            if (k >= 0) l.splice(k, 1)
            else if (info.max === 1) { l.length = 0; l.push(eid) }
            else if (info.max === 0 || l.length < info.max) l.push(eid)
            escolhidas = l
        }
        modal: true; anchors.centerIn: parent
        width: Math.min(parent.width - 60, 900); height: Math.min(parent.height - 60, 660); padding: 0
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.55) }
        background: Rectangle { radius: 24; color: "#262626" }
        contentItem: Item {
            Text { x: 24; y: 22; text: dlgCartao.indice >= 0 ? "Editar cartão" : "Adicionar cartão"; color: janela.texto; font.pixelSize: 22 }
            // os tipos de cartão
            ListView {
                id: colTipos
                x: 12; y: 66; width: 270; height: parent.height - 66 - 12; clip: true; spacing: 2
                model: casa.tipos
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool sel: dlgCartao.tipo === modelData.id
                    width: 262; height: 52; radius: 12
                    color: sel ? Qt.rgba(0.012, 0.663, 0.957, 0.16) : (tm.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                    Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: janela.ic(modelData.icone); font.family: "Material Design Icons"; font.pixelSize: 22
                           color: parent.sel ? janela.primaria : janela.textoSuave }
                    Column {
                        x: 48; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 56
                        Text { text: modelData.nome; color: parent.parent.sel ? janela.primaria : janela.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { text: modelData.desc; color: janela.textoSuave; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight }
                    }
                    MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { dlgCartao.tipo = modelData.id; if (modelData.max === 1 && dlgCartao.escolhidas.length > 1) dlgCartao.escolhidas = dlgCartao.escolhidas.slice(0, 1) } }
                }
            }
            Rectangle { x: 294; y: 66; width: 1; height: parent.height - 78; color: Qt.rgba(1, 1, 1, 0.08) }
            // entidades e opções
            Item {
                x: 312; y: 66; width: parent.width - 336; height: parent.height - 66 - 20
                Column {
                    id: opc
                    width: parent.width; spacing: 12
                    Campo { id: tituloC; width: parent.width
                            placeholderText: dlgCartao.tipo === "texto" ? "Título (use {saudacao} e {nome}; uma 2.ª linha vira subtítulo)" : "Nome ou título (opcional)" }
                    Row {
                        spacing: 8
                        Text { text: "Largura"; color: janela.textoSuave; anchors.verticalCenter: parent.verticalCenter; rightPadding: 4 }
                        Repeater {
                            model: [1, 2, 3, 4]
                            delegate: Rectangle {
                                required property int modelData
                                readonly property bool sel: dlgCartao.largura === modelData
                                width: 48; height: 32; radius: 16
                                color: sel ? Qt.rgba(0.012, 0.663, 0.957, 0.2) : Qt.rgba(1, 1, 1, 0.06)
                                border.width: sel ? 1 : 0; border.color: janela.primaria
                                Text { anchors.centerIn: parent; text: modelData + "×"; color: parent.sel ? janela.primaria : janela.texto; font.weight: Font.DemiBold }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dlgCartao.largura = modelData }
                            }
                        }
                    }
                    Campo { id: procura; visible: dlgCartao.info.max !== 0; width: parent.width; placeholderText: "Procurar aparelho ou sensor…" }
                    Text {
                        visible: dlgCartao.info.max !== 0; color: janela.textoSuave; font.pixelSize: 12
                        text: dlgCartao.info.max === 1 ? "Escolha um." : "Escolha até " + dlgCartao.info.max + " (" + dlgCartao.escolhidas.length + " escolhidos)."
                    }
                }
                ListView {
                    visible: dlgCartao.info.max !== 0
                    anchors.top: opc.bottom; anchors.topMargin: 6; anchors.bottom: botoes.top; anchors.bottomMargin: 12
                    width: parent.width; clip: true; spacing: 2
                    ScrollBar.vertical: ScrollBar {}
                    model: janela.todas.filter(e => (dlgCartao.info.dominios.length === 0 || dlgCartao.info.dominios.indexOf(e.dominio) !== -1)
                                              && (procura.text === "" || (e.nome + " " + e.id).toLowerCase().indexOf(procura.text.toLowerCase()) !== -1))
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool marcado: dlgCartao.escolhidas.indexOf(modelData.id) !== -1
                        width: ListView.view.width - 12; height: 48; radius: 10
                        color: marcado ? Qt.rgba(0.012, 0.663, 0.957, 0.16) : (em.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: janela.ic(marcado ? "checkbox-marked" : "checkbox-blank-outline")
                               font.family: "Material Design Icons"; font.pixelSize: 22; color: marcado ? janela.primaria : janela.textoSuave }
                        Column {
                            x: 46; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 56
                            Text { text: modelData.nome; color: janela.texto; width: parent.width; elide: Text.ElideRight }
                            Text { text: modelData.id; color: janela.textoSuave; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight }
                        }
                        MouseArea { id: em; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dlgCartao.alternarEnt(modelData.id) }
                    }
                }
                Row {
                    id: botoes
                    anchors.bottom: parent.bottom; anchors.right: parent.right; spacing: 8
                    Botao { texto: "Cancelar"; plano: true; onClicado: dlgCartao.close() }
                    Botao {
                        texto: dlgCartao.indice >= 0 ? "Salvar" : "Adicionar"; principal: true
                        ativo: dlgCartao.info.max === 0 ? tituloC.text !== "" : dlgCartao.escolhidas.length > 0
                        onClicado: {
                            if (dlgCartao.indice >= 0) casa.editarCartao(janela.painel, dlgCartao.indice, dlgCartao.tipo, tituloC.text, dlgCartao.escolhidas, dlgCartao.largura)
                            else casa.adicionarCartao(janela.painel, dlgCartao.tipo, tituloC.text, dlgCartao.escolhidas, dlgCartao.largura)
                            dlgCartao.close()
                        }
                    }
                }
            }
        }
    }

    // ---- peças comuns ---------------------------------------------------------------------------------------
    component Campo: TextField {
        color: janela.texto; placeholderTextColor: janela.textoSuave; selectByMouse: true
        leftPadding: 14; rightPadding: 14; topPadding: 14; bottomPadding: 14
        background: Rectangle {
            radius: 8; color: Qt.rgba(1, 1, 1, 0.05)
            Rectangle { anchors.bottom: parent.bottom; x: 0; width: parent.width; height: parent.parent.activeFocus ? 2 : 1
                        color: parent.parent.activeFocus ? janela.primaria : Qt.rgba(1, 1, 1, 0.3) }
        }
    }
    component Botao: Rectangle {
        id: bo
        property string texto: ""
        property string icone: ""
        property bool principal: false
        property bool plano: false
        property bool perigo: false
        property bool ativo: true
        signal clicado()
        implicitWidth: lb.implicitWidth + 32; implicitHeight: 40; radius: 20
        opacity: ativo ? 1 : 0.4
        color: principal ? (mb.pressed ? "#0288d1" : janela.primaria)
             : plano ? (mb.containsMouse ? Qt.rgba(0.012, 0.663, 0.957, 0.1) : "transparent")
             : (mb.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06))
        border.width: !principal && !plano ? 1 : 0; border.color: perigo ? Qt.rgba(0.94, 0.33, 0.31, 0.5) : Qt.rgba(1, 1, 1, 0.15)
        Row {
            id: lb
            anchors.centerIn: parent; spacing: 6
            Text { visible: bo.icone !== ""; text: janela.ic(bo.icone); font.family: "Material Design Icons"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter
                   color: bo.principal ? "white" : janela.primaria }
            Text { text: bo.texto; font.pixelSize: 14; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter
                   color: bo.principal ? "white" : bo.perigo ? "#ef5350" : bo.plano ? janela.primaria : janela.texto }
        }
        MouseArea { id: mb; anchors.fill: parent; enabled: bo.ativo; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bo.clicado() }
    }
}
