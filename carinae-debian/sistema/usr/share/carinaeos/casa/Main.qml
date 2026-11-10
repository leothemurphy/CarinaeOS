// CarinaeOS - Casa: painéis do Home Assistant que o usuário monta com cartões
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: janela
    width: 1180; height: 780
    minimumWidth: 820; minimumHeight: 560
    visible: true
    title: "Casa"
    color: "#0c0a14"
    font.family: "Inter"; font.pixelSize: 14

    readonly property color ambar: "#ffb46e"
    readonly property color rosa: "#ff6f91"
    readonly property color texto: "#f6f2ff"
    readonly property color textoSuave: "#b9b0cc"
    property string separador: "casa"
    property int painel: 0
    property bool editar: false

    Rectangle {
        anchors.fill: parent
        gradient: Gradient { GradientStop { position: 0; color: "#17122a" } GradientStop { position: 1; color: "#0a0812" } }
    }
    Image { anchors.fill: parent; source: "file:///usr/share/backgrounds/carinaeos/eta-carinae.jpg"; fillMode: Image.PreserveAspectCrop; opacity: 0.10; asynchronous: true }

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

        // barra lateral: os painéis
        Rectangle {
            id: lado
            width: 228; height: parent.height
            color: Qt.rgba(1, 1, 1, 0.035)
            Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Qt.rgba(1, 1, 1, 0.06) }
            Column {
                x: 16; y: 22; width: parent.width - 32; spacing: 6
                Row {
                    spacing: 10
                    Image { source: "image://icone/carinaeos-casa"; width: 38; height: 38; sourceSize: Qt.size(76, 76) }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: casa.nome; color: janela.texto; font.pixelSize: 18; font.weight: Font.Bold; width: 140; elide: Text.ElideRight }
                        Text { text: casa.erro !== "" ? "sem ligação" : "ligado"; color: casa.erro !== "" ? janela.rosa : "#8fe3a8"; font.pixelSize: 11 }
                    }
                }
                Item { width: 1; height: 14 }
                Text { text: "PAINÉIS"; color: janela.textoSuave; font.pixelSize: 11; font.weight: Font.DemiBold; leftPadding: 8 }
                Repeater {
                    model: casa.paineis
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool ativo: janela.separador === "casa" && janela.painel === index
                        width: parent.width; height: 38; radius: 10
                        color: ativo ? Qt.rgba(1, 0.65, 0.45, 0.22) : (pm.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "▦  " + modelData.nome; color: janela.texto; font.pixelSize: 14; width: parent.width - 24; elide: Text.ElideRight }
                        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { janela.separador = "casa"; janela.painel = index } }
                    }
                }
                Rectangle {
                    width: parent.width; height: 36; radius: 10; color: "transparent"; border.color: Qt.rgba(1, 1, 1, 0.12)
                    Text { anchors.centerIn: parent; text: "+  Novo painel"; color: janela.textoSuave; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dlgPainel.abrir(-1) }
                }
                Item { width: 1; height: 14 }
                Text { text: "MAIS"; color: janela.textoSuave; font.pixelSize: 11; font.weight: Font.DemiBold; leftPadding: 8 }
                Repeater {
                    model: [{ id: "pc", n: "🖥  Este computador" }, { id: "web", n: "🌐  Abrir no navegador" }]
                    delegate: Rectangle {
                        required property var modelData
                        width: parent.width; height: 36; radius: 10
                        color: janela.separador === modelData.id ? Qt.rgba(1, 0.65, 0.45, 0.22) : "transparent"
                        Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.n; color: janela.texto; font.pixelSize: 13 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.id === "web" ? casa.abrirNoNavegador() : janela.separador = modelData.id }
                    }
                }
            }
        }

        // cabecalho do painel
        Item {
            id: cab
            visible: janela.separador === "casa"
            x: lado.width + 28; y: 22; width: parent.width - lado.width - 56; height: 50
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: casa.paineis.length > janela.painel ? casa.paineis[janela.painel].nome : ""
                color: janela.texto; font.pixelSize: 28; font.weight: Font.Bold
            }
            Row {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                Rectangle {
                    visible: janela.editar
                    width: adTxt.implicitWidth + 30; height: 36; radius: 18
                    gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: janela.rosa } GradientStop { position: 1; color: janela.ambar } }
                    Text { id: adTxt; anchors.centerIn: parent; text: "+ Adicionar cartão"; color: "#1a0f14"; font.weight: Font.Bold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dlgCartao.abrir(-1) }
                }
                Rectangle {
                    visible: janela.editar
                    width: 120; height: 36; radius: 18; color: Qt.rgba(1, 1, 1, 0.07)
                    Text { anchors.centerIn: parent; text: "Renomear"; color: janela.texto; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: dlgPainel.abrir(janela.painel) }
                }
                Rectangle {
                    width: edTxt.implicitWidth + 30; height: 36; radius: 18
                    color: janela.editar ? "#8fe3a8" : Qt.rgba(1, 1, 1, 0.07)
                    Text { id: edTxt; anchors.centerIn: parent; text: janela.editar ? "✓ Concluído" : "✎ Editar painel"; color: janela.editar ? "#0f2a18" : janela.texto; font.weight: Font.DemiBold }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: janela.editar = !janela.editar }
                }
            }
        }

        // os cartoes
        ScrollView {
            id: rolar
            visible: janela.separador === "casa"
            anchors.top: cab.bottom; anchors.topMargin: 16; anchors.bottom: parent.bottom
            x: lado.width + 28; width: parent.width - lado.width - 40
            contentWidth: availableWidth; clip: true
            readonly property var cartoes: casa.paineis.length > janela.painel ? casa.paineis[janela.painel].cartoes : []
            readonly property int colunas: Math.max(1, Math.floor((availableWidth - 16) / 270))
            readonly property real unidade: (availableWidth - 16) / colunas

            Column {
                width: rolar.availableWidth
                spacing: 16
                Column {
                    visible: rolar.cartoes.length === 0
                    width: parent.width - 16; spacing: 14; topPadding: 60
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: casa.todas.length ? "Este painel está vazio" : "A carregar a casa…"; color: janela.texto; font.pixelSize: 20; font.weight: Font.DemiBold }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Monte-o como quiser: botões, luzes, gráficos, câmaras, clima, cenas…"; color: janela.textoSuave }
                    Row {
                        visible: casa.todas.length > 0
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
                        Rectangle {
                            width: 190; height: 40; radius: 20
                            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: janela.rosa } GradientStop { position: 1; color: janela.ambar } }
                            Text { anchors.centerIn: parent; text: "+ Adicionar cartão"; color: "#1a0f14"; font.weight: Font.Bold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { janela.editar = true; dlgCartao.abrir(-1) } }
                        }
                        Rectangle {
                            width: 190; height: 40; radius: 20; color: Qt.rgba(1, 1, 1, 0.08)
                            Text { anchors.centerIn: parent; text: "✦ Sugerir um painel"; color: janela.texto }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: casa.sugerirPainel(janela.painel) }
                        }
                    }
                }
                Flow {
                    width: parent.width - 16
                    spacing: 0
                    Repeater {
                        model: rolar.cartoes
                        delegate: Item {
                            required property var modelData
                            required property int index
                            width: Math.min(rolar.colunas, modelData.largura) * rolar.unidade
                            height: cartao.implicitHeight + 14
                            Cartao {
                                id: cartao
                                dados: modelData; indice: index; editar: janela.editar
                                width: parent.width - 14; height: parent.height - 14
                                onPedirApagar: casa.apagarCartao(janela.painel, index)
                                onPedirMover: (para) => casa.moverCartao(janela.painel, index, para)
                                onPedirEditar: dlgCartao.abrir(index)
                            }
                        }
                    }
                }
                Rectangle {
                    visible: janela.editar && casa.paineis.length > 1
                    width: 180; height: 34; radius: 17; color: Qt.rgba(1, 0.3, 0.4, 0.12)
                    Text { anchors.centerIn: parent; text: "Apagar este painel"; color: janela.rosa; font.pixelSize: 13 }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { casa.apagarPainel(janela.painel); janela.painel = 0 } }
                }
                Item { width: 1; height: 20 }
            }
        }

    // ---- este computador no Home Assistant --------------------------------------------------------
        Column {
            visible: janela.separador === "pc"
            y: 96
            x: 260; width: Math.min(640, parent.width - 300); spacing: 12
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

    // ---- novo painel / renomear ------------------------------------------------------------------
    Popup {
        id: dlgPainel
        property int indice: -1
        function abrir(i) { indice = i; nomeP.text = i >= 0 ? casa.paineis[i].nome : ""; open(); nomeP.forceActiveFocus() }
        modal: true; anchors.centerIn: parent; width: 380; padding: 22
        background: Rectangle { radius: 18; color: "#1d1630"; border.color: Qt.rgba(1, 1, 1, 0.12) }
        contentItem: Column {
            spacing: 12
            Text { text: dlgPainel.indice >= 0 ? "Renomear painel" : "Novo painel"; color: janela.texto; font.pixelSize: 18; font.weight: Font.Bold }
            TextField { id: nomeP; width: parent.width; placeholderText: "Ex.: Sala, Quarto, Energia"; onAccepted: ok.clicar() }
            Rectangle {
                id: ok
                function clicar() { if (dlgPainel.indice >= 0) casa.renomearPainel(dlgPainel.indice, nomeP.text); else { casa.novoPainel(nomeP.text); janela.painel = casa.paineis.length - 1; janela.editar = true } dlgPainel.close() }
                anchors.right: parent.right; width: 120; height: 36; radius: 18; color: janela.ambar
                Text { anchors.centerIn: parent; text: "Guardar"; color: "#1a0f14"; font.weight: Font.Bold }
                MouseArea { anchors.fill: parent; onClicked: ok.clicar() }
            }
        }
    }

    // ---- adicionar / editar cartao -----------------------------------------------------------------
    Popup {
        id: dlgCartao
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
        width: Math.min(parent.width - 60, 860); height: Math.min(parent.height - 60, 640); padding: 0
        background: Rectangle { radius: 22; color: "#1b1530"; border.color: Qt.rgba(1, 1, 1, 0.12) }
        contentItem: Item {
            // tipos
            Column {
                id: colTipos
                x: 20; y: 20; width: 250; spacing: 6
                Text { text: dlgCartao.indice >= 0 ? "Editar cartão" : "Novo cartão"; color: janela.texto; font.pixelSize: 20; font.weight: Font.Bold; bottomPadding: 6 }
                Repeater {
                    model: casa.tipos
                    delegate: Rectangle {
                        required property var modelData
                        width: 250; height: 40; radius: 10
                        color: dlgCartao.tipo === modelData.id ? Qt.rgba(1, 0.65, 0.45, 0.25) : (tm.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        Column {
                            x: 12; anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelData.nome; color: janela.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
                            Text { text: modelData.desc; color: janela.textoSuave; font.pixelSize: 10; width: 226; elide: Text.ElideRight }
                        }
                        MouseArea { id: tm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { dlgCartao.tipo = modelData.id; if (modelData.max === 1 && dlgCartao.escolhidas.length > 1) dlgCartao.escolhidas = dlgCartao.escolhidas.slice(0, 1) } }
                    }
                }
            }
            // entidades e opcoes
            Item {
                x: 290; y: 20; width: parent.width - 310; height: parent.height - 40
                Column {
                    id: opc
                    width: parent.width; spacing: 10
                    TextField { id: tituloC; width: parent.width; placeholderText: dlgCartao.tipo === "texto" ? "Texto do cartão" : "Título (opcional)" }
                    Row {
                        spacing: 8
                        Text { text: "Largura:"; color: janela.textoSuave; anchors.verticalCenter: parent.verticalCenter }
                        Repeater {
                            model: [1, 2, 3]
                            delegate: Rectangle {
                                required property int modelData
                                width: 44; height: 30; radius: 15
                                color: dlgCartao.largura === modelData ? janela.ambar : Qt.rgba(1, 1, 1, 0.08)
                                Text { anchors.centerIn: parent; text: modelData + "×"; color: dlgCartao.largura === modelData ? "#1a0f14" : janela.texto }
                                MouseArea { anchors.fill: parent; onClicked: dlgCartao.largura = modelData }
                            }
                        }
                    }
                    TextField { id: procura; visible: dlgCartao.info.max !== 0; width: parent.width; placeholderText: "Procurar aparelho ou sensor…" }
                    Text {
                        visible: dlgCartao.info.max !== 0; color: janela.textoSuave; font.pixelSize: 12
                        text: dlgCartao.info.max === 1 ? "Escolha um." : "Escolha até " + dlgCartao.info.max + " (" + dlgCartao.escolhidas.length + " escolhidos)."
                    }
                }
                ListView {
                    visible: dlgCartao.info.max !== 0
                    anchors.top: opc.bottom; anchors.topMargin: 8; anchors.bottom: botoes.top; anchors.bottomMargin: 10
                    width: parent.width; clip: true; spacing: 2
                    ScrollBar.vertical: ScrollBar {}
                    model: casa.todas.filter(e => (dlgCartao.info.dominios.length === 0 || dlgCartao.info.dominios.indexOf(e.dominio) !== -1)
                                              && (procura.text === "" || (e.nome + " " + e.id).toLowerCase().indexOf(procura.text.toLowerCase()) !== -1))
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool marcado: dlgCartao.escolhidas.indexOf(modelData.id) !== -1
                        width: ListView.view.width - 12; height: 40; radius: 8
                        color: marcado ? Qt.rgba(1, 0.65, 0.45, 0.22) : (em.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: (marcado ? "✓  " : "    ") + modelData.nome; color: janela.texto; width: parent.width - 160; elide: Text.ElideRight }
                        Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.id.split(".")[0]; color: janela.textoSuave; font.pixelSize: 11 }
                        MouseArea { id: em; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: dlgCartao.alternarEnt(modelData.id) }
                    }
                }
                Row {
                    id: botoes
                    anchors.bottom: parent.bottom; anchors.right: parent.right; spacing: 10
                    Rectangle {
                        width: 110; height: 38; radius: 19; color: Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "Cancelar"; color: janela.texto }
                        MouseArea { anchors.fill: parent; onClicked: dlgCartao.close() }
                    }
                    Rectangle {
                        readonly property bool pode: dlgCartao.info.max === 0 ? tituloC.text !== "" : dlgCartao.escolhidas.length > 0
                        width: 140; height: 38; radius: 19; opacity: pode ? 1 : 0.4
                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: janela.rosa } GradientStop { position: 1; color: janela.ambar } }
                        Text { anchors.centerIn: parent; text: dlgCartao.indice >= 0 ? "Guardar" : "Adicionar"; color: "#1a0f14"; font.weight: Font.Bold }
                        MouseArea {
                            anchors.fill: parent; enabled: parent.pode
                            onClicked: {
                                if (dlgCartao.indice >= 0) casa.editarCartao(janela.painel, dlgCartao.indice, dlgCartao.tipo, tituloC.text, dlgCartao.escolhidas, dlgCartao.largura)
                                else casa.adicionarCartao(janela.painel, dlgCartao.tipo, tituloC.text, dlgCartao.escolhidas, dlgCartao.largura)
                                dlgCartao.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
