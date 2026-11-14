// CarinaeOS - Configuracoes (ao estilo das Definicoes do Fedora)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: janela
    width: 1040
    height: 700
    minimumWidth: 760
    minimumHeight: 500
    visible: true
    title: "Configurações"
    color: "#1e1d24"

    readonly property color fundoLado: "#25232c"
    readonly property color cartao: "#2d2b35"
    readonly property color texto: "#f2f0f6"
    readonly property color suave: "#a8a3b6"
    readonly property color realce: "#7aa7ff"
    readonly property color linha: Qt.rgba(1, 1, 1, 0.07)
    property string pagina: ajustes.inicio
    readonly property var e: ajustes.estado
    readonly property var seccao: {
        for (const s of ajustes.seccoes) if (s.id === pagina) return s;
        return ajustes.seccoes[0];
    }
    onPaginaChanged: ajustes.ler(pagina)
    Component.onCompleted: ajustes.ler(pagina)

    function sem(t) { return (t || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, ""); }

    // ---- peças ------------------------------------------------------------------------------------
    component Grupo: Rectangle {      // cartão arredondado com linhas, como no libadwaita
        default property alias linhas: col.data
        property string titulo: ""
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight + (titulo !== "" ? 30 : 0)
        color: "transparent"
        Text { visible: parent.titulo !== ""; text: parent.titulo; color: janela.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
        Rectangle {
            y: parent.titulo !== "" ? 30 : 0
            width: parent.width
            height: col.implicitHeight
            radius: 12
            color: janela.cartao
            border.width: 1
            border.color: janela.linha
            clip: true
            Column { id: col; width: parent.width }
        }
    }
    component Linha: Rectangle {
        id: lin
        property string titulo: ""
        property string sub: ""
        property string icone: ""
        default property alias direita: dir.data
        property bool clicavel: false
        signal carregado()
        width: parent ? parent.width : 0
        height: Math.max(56, cols.implicitHeight + 22)
        color: clicavel && ml.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
        Rectangle { anchors.bottom: parent.bottom; x: 16; width: parent.width - 32; height: 1; color: janela.linha }
        Image {
            id: ic
            visible: lin.icone !== ""
            x: 16; anchors.verticalCenter: parent.verticalCenter
            width: 22; height: 22; sourceSize: Qt.size(44, 44)
            source: lin.icone !== "" ? "image://icone/" + lin.icone : ""
        }
        Column {
            id: cols
            anchors.left: ic.visible ? ic.right : parent.left
            anchors.leftMargin: ic.visible ? 14 : 16
            anchors.right: dir.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            Text { width: parent.width; text: lin.titulo; color: janela.texto; font.pixelSize: 14; elide: Text.ElideRight }
            Text { visible: lin.sub !== ""; width: parent.width; text: lin.sub; color: janela.suave; font.pixelSize: 12; wrapMode: Text.WordWrap }
        }
        Row { id: dir; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 8 }
        MouseArea { id: ml; anchors.fill: parent; enabled: lin.clicavel; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lin.carregado(); z: -1 }
    }
    component Seta: Text { text: "›"; color: janela.suave; font.pixelSize: 20 }
    component Botao: Rectangle {
        property string texto: ""
        property bool principal: false
        signal carregado()
        implicitWidth: tb.implicitWidth + 28; implicitHeight: 34; radius: 8
        color: principal ? (mb.containsMouse ? Qt.lighter(janela.realce, 1.08) : janela.realce) : (mb.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
        Text { id: tb; anchors.centerIn: parent; text: parent.texto; color: parent.principal ? "#0b1530" : janela.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
        MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.carregado() }
    }
    component Deslizante: Slider {
        id: ds
        width: 220
        from: 0; to: 1
        background: Rectangle {
            x: ds.leftPadding; y: ds.topPadding + ds.availableHeight / 2 - 2
            width: ds.availableWidth; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.2)
            Rectangle { width: ds.visualPosition * parent.width; height: 4; radius: 2; color: janela.realce }
        }
        handle: Rectangle {
            x: ds.leftPadding + ds.visualPosition * (ds.availableWidth - width)
            y: ds.topPadding + ds.availableHeight / 2 - 10
            width: 20; height: 20; radius: 10; color: "white"
        }
    }

    // ---- barra lateral ---------------------------------------------------------------------------
    Rectangle {
        id: lado
        width: 270
        height: parent.height
        color: janela.fundoLado
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: janela.linha }

        Text { x: 20; y: 18; text: "Configurações"; color: janela.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
        Rectangle {
            id: caixa
            x: 12; y: 52
            width: parent.width - 24; height: 36; radius: 8
            color: Qt.rgba(1, 1, 1, 0.07)
            Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: janela.suave; font.pixelSize: 16 }
            TextField {
                id: procura
                x: 30; width: parent.width - 36; anchors.verticalCenter: parent.verticalCenter
                background: Item {}
                color: janela.texto
                placeholderText: "Pesquisar nas configurações"
                placeholderTextColor: janela.suave
                font.pixelSize: 13
            }
        }
        ListView {
            id: listaLado
            anchors.top: caixa.bottom; anchors.topMargin: 10
            anchors.bottom: parent.bottom; anchors.bottomMargin: 8
            x: 8; width: parent.width - 16
            clip: true
            spacing: 2
            model: ajustes.seccoes.filter(s => procura.text === "" || janela.sem(s.nome + " " + s.palavras).indexOf(janela.sem(procura.text)) !== -1)
            ScrollBar.vertical: ScrollBar {}
            delegate: Rectangle {
                required property var modelData
                width: listaLado.width
                height: 40
                radius: 8
                color: janela.pagina === modelData.id ? Qt.rgba(1, 1, 1, 0.10) : (mr.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                Image { id: li; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; sourceSize: Qt.size(40, 40); source: "image://icone/" + parent.modelData.icone }
                Text { anchors.left: li.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.nome; color: janela.texto; font.pixelSize: 14 }
                MouseArea { id: mr; anchors.fill: parent; hoverEnabled: true; onClicked: janela.pagina = parent.modelData.id }
            }
        }
    }

    // ---- conteúdo ------------------------------------------------------------------------------------
    Item {
        anchors.left: lado.right
        anchors.right: parent.right
        height: parent.height

        Text { id: cab; anchors.horizontalCenter: parent.horizontalCenter; y: 18; text: janela.seccao.nome; color: janela.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
        Rectangle {
            visible: ajustes.mensagem !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 18
            z: 5
            width: tm.implicitWidth + 32; height: 36; radius: 18
            color: "#3a3846"
            Text { id: tm; anchors.centerIn: parent; text: ajustes.mensagem; color: janela.texto; font.pixelSize: 13 }
        }

        ScrollView {
            id: rolar
            anchors.top: cab.bottom; anchors.topMargin: 18
            anchors.bottom: parent.bottom
            width: parent.width
            contentWidth: availableWidth
            clip: true

            ColumnLayout {
                id: pag
                width: Math.min(rolar.availableWidth - 48, 640)
                x: (rolar.availableWidth - width) / 2
                spacing: 22

                // ===== Wi-Fi e Rede =====
                Grupo {
                    visible: janela.pagina === "wifi"
                    Linha { titulo: "Wi-Fi"; sub: (janela.e.redes || []).filter(r => r.ligada).map(r => "Ligado a " + r.ssid).join("") || "Não ligado"
                            Switch { checked: !!janela.e.wifi; onToggled: { ajustes.definirWifi(checked); ajustes.ler("wifi"); } } }
                }
                Grupo {
                    visible: janela.pagina === "wifi" && !!janela.e.wifi
                    titulo: "Redes visíveis"
                    Repeater {
                        model: janela.e.redes || []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.ssid
                            sub: modelData.ligada ? "Ligada" : (modelData.segura ? "Protegida" : "Aberta")
                            icone: modelData.sinal > 66 ? "network-wireless-signal-excellent" : modelData.sinal > 33 ? "network-wireless-signal-good" : "network-wireless-signal-weak"
                            clicavel: !modelData.ligada
                            onCarregado: { senhaWifi.ssid = modelData.ssid; senhaWifi.segura = modelData.segura; senhaWifi.open(); }
                            Text { visible: modelData.ligada; text: "✓"; color: janela.realce; font.pixelSize: 16 }
                            Text { visible: modelData.segura && !modelData.ligada; text: "🔒"; font.pixelSize: 12 }
                        }
                    }
                    Linha { visible: (janela.e.redes || []).length === 0; titulo: "A procurar redes…"; sub: "Se não aparecer nenhuma, confirme que o Wi-Fi do computador está ligado." }
                }
                Grupo {
                    visible: janela.pagina === "rede"
                    titulo: "Ligações ativas"
                    Repeater {
                        model: janela.e.ligacoes || []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.nome
                            sub: (modelData.tipo.indexOf("wireless") !== -1 ? "Wi-Fi" : modelData.tipo.indexOf("ethernet") !== -1 ? "Cabo" : modelData.tipo) + " · " + modelData.disp
                            icone: modelData.tipo.indexOf("wireless") !== -1 ? "network-wireless" : "network-wired"
                        }
                    }
                    Linha { titulo: "Endereço IP"; sub: (janela.e.ip || []).join("  ·  ") || "—" }
                }

                // ===== Bluetooth =====
                Grupo {
                    visible: janela.pagina === "bluetooth"
                    Linha { titulo: "Bluetooth"; sub: janela.e.bluetooth ? "Visível para emparelhar aparelhos" : "Desligado"
                            Switch { checked: !!janela.e.bluetooth; onToggled: { ajustes.definirBluetooth(checked); ajustes.ler("bluetooth"); } } }
                }
                Grupo {
                    visible: janela.pagina === "bluetooth"
                    titulo: "Aparelhos"
                    Repeater { model: janela.e.aparelhos || []; delegate: Linha { required property string modelData; titulo: modelData; icone: "preferences-system-bluetooth" } }
                    Linha { titulo: "Adicionar um aparelho…"; clicavel: true; onCarregado: ajustes.completo("bluetooth"); Seta {} }
                }

                // ===== Ecrãs =====
                Grupo {
                    visible: janela.pagina === "ecras"
                    titulo: "Ecrãs ligados"
                    Repeater { model: janela.e.ecras || []; delegate: Linha { required property string modelData; titulo: modelData.replace(/^Output:\s*\d+\s*/, ""); icone: "video-display" } }
                    Linha { titulo: "Resolução, escala e posição…"; clicavel: true; onCarregado: ajustes.completo("ecras"); Seta {} }
                }
                Grupo {
                    visible: janela.pagina === "ecras"
                    Linha { visible: (janela.e.brilho || -1) >= 0; titulo: "Brilho"
                            Deslizante { value: janela.e.brilho || 0; onMoved: ajustes.definirBrilho(value) } }
                    Linha { titulo: "Luz noturna"; sub: "Cores mais quentes à noite, para descansar a vista"
                            Switch { onToggled: ajustes.luzNoturna(checked) } }
                }

                // ===== Som =====
                Grupo {
                    visible: janela.pagina === "som"
                    titulo: "Saída"
                    Linha { titulo: "Volume"; icone: "audio-volume-high"
                            Deslizante { value: janela.e.volume || 0; onMoved: ajustes.definirVolume(value) } }
                }
                Grupo {
                    visible: janela.pagina === "som"
                    titulo: "Entrada"
                    Linha { titulo: "Microfone"; icone: "audio-input-microphone"
                            Deslizante { value: janela.e.microfone || 0; onMoved: ajustes.definirMicrofone(value) } }
                    Linha { titulo: "Aparelhos de som e sons do sistema…"; clicavel: true; onCarregado: ajustes.completo("som"); Seta {} }
                }

                // ===== Energia =====
                Grupo {
                    visible: janela.pagina === "energia"
                    Linha { visible: (janela.e.bateria || -1) >= 0; titulo: "Bateria"; sub: (janela.e.bateria || 0) + "%"; icone: "battery-good" }
                }
                Grupo {
                    visible: janela.pagina === "energia" && (janela.e.perfil || "") !== ""
                    titulo: "Modo de energia"
                    Repeater {
                        model: [["performance", "Desempenho", "Mais rápido, gasta mais energia"],
                                ["balanced", "Equilibrado", "O melhor para o dia a dia"],
                                ["power-saver", "Poupança", "A bateria dura mais"]]
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData[1]; sub: modelData[2]; clicavel: true
                            onCarregado: { ajustes.definirPerfil(modelData[0]); ajustes.ler("energia"); }
                            RadioButton { checked: janela.e.perfil === modelData[0]; onClicked: { ajustes.definirPerfil(modelData[0]); ajustes.ler("energia"); } }
                        }
                    }
                }
                Grupo {
                    visible: janela.pagina === "energia"
                    Linha { titulo: "Suspender e desligar o ecrã…"; clicavel: true; onCarregado: ajustes.completo("energia"); Seta {} }
                }

                // ===== Aparência =====
                Grupo {
                    visible: janela.pagina === "aparencia"
                    titulo: "Estilo"
                    Item {
                        width: parent.width; height: 170
                        Row {
                            anchors.centerIn: parent
                            spacing: 24
                            Repeater {
                                model: [[false, "Escuro", "#17151f", "#2d2b38"], [true, "Claro", "#f4f4f6", "#ffffff"]]
                                delegate: Column {
                                    required property var modelData
                                    spacing: 8
                                    Rectangle {
                                        width: 180; height: 110; radius: 12
                                        color: modelData[2]
                                        border.width: (!!janela.e.claro) === modelData[0] ? 3 : 1
                                        border.color: (!!janela.e.claro) === modelData[0] ? janela.realce : janela.linha
                                        Rectangle { x: 18; y: 18; width: 110; height: 66; radius: 8; color: modelData[3]; border.color: Qt.rgba(0.5, 0.5, 0.5, 0.3) }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ajustes.definirClaro(modelData[0]); ajustes.ler("aparencia"); } }
                                    }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[1]; color: janela.texto; font.pixelSize: 13 }
                                }
                            }
                        }
                    }
                }
                Grupo {
                    visible: janela.pagina === "aparencia"
                    titulo: "Papel de parede"
                    Flow {
                        width: parent.width
                        padding: 14
                        spacing: 12
                        Repeater {
                            model: janela.e.fundos || []
                            delegate: Rectangle {
                                required property var modelData
                                width: 182; height: 104; radius: 10
                                color: "transparent"
                                border.width: mf.containsMouse ? 2 : 0
                                border.color: janela.realce
                                Image { anchors.fill: parent; anchors.margins: 2; source: modelData.miniatura; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                MouseArea { id: mf; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ajustes.definirFundo(modelData.caminho) }
                            }
                        }
                    }
                }

                // ===== Pesquisa =====
                Grupo {
                    visible: janela.pagina === "pesquisa"
                    Linha { titulo: "Indexar os arquivos"; sub: "A Pesquisa (Ctrl+Espaço) encontra arquivos pelo nome e pelo conteúdo, num instante."
                            Switch { checked: janela.e.indexacao !== false; onToggled: ajustes.definirIndexacao(checked) } }
                    Linha { visible: (janela.e.indexados || "") !== ""; titulo: "Estado"; sub: janela.e.indexados || "" }
                    Linha { titulo: "Pastas a incluir ou excluir…"; clicavel: true; onCarregado: ajustes.completo("pesquisa"); Seta {} }
                }

                // ===== Privacidade =====
                Grupo {
                    visible: janela.pagina === "privacidade"
                    Linha { titulo: "Sessão sem rastro, modo escuro forçado"; sub: "Na Central do CarinaeOS"; clicavel: true; onCarregado: ajustes.abrir("carinaeos-central privacidade"); Seta {} }
                    Linha { titulo: "Pastas, arquivos e aplicativos com senha"; sub: "Cadeado"; clicavel: true; onCarregado: ajustes.abrir("carinaeos-central cadeado"); Seta {} }
                    Linha { titulo: "Bloqueio do ecrã…"; clicavel: true; onCarregado: ajustes.abrir("kcmshell6 kcm_screenlocker"); Seta {} }
                }

                // ===== Partilha =====
                Grupo {
                    visible: janela.pagina === "partilha"
                    Linha { titulo: "Acesso remoto (SSH)"; sub: janela.e.ssh === 1 ? ("ssh " + (janela.e.usuario || "") + "@" + ((janela.e.ip || [])[0] || "")) : "Desligado"
                            Switch { checked: janela.e.ssh === 1; onToggled: ajustes.definirSSH(checked) } }
                    Linha { titulo: "Partilhar uma pasta com a rede"; sub: "Nos Arquivos: botão direito na pasta › Propriedades › Partilha" }
                }

                // ===== Data e hora =====
                Grupo {
                    visible: janela.pagina === "datahora"
                    Linha { titulo: "Data e hora automáticas"; sub: janela.e.agora || ""
                            Switch { checked: !!janela.e.auto; onToggled: ajustes.definirHoraAuto(checked) } }
                    Linha { titulo: "Fuso horário"; sub: janela.e.fuso || ""; clicavel: true; onCarregado: ajustes.completo("datahora"); Seta {} }
                }

                // ===== Utilizadores =====
                Grupo {
                    visible: janela.pagina === "utilizadores"
                    Item {
                        width: parent.width; height: 170
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 96; height: 96; radius: 48; clip: true
                                color: janela.realce
                                Text { anchors.centerIn: parent; visible: (janela.e.foto || "") === ""; text: (janela.e.nome || "?").charAt(0).toUpperCase(); color: "#0b1530"; font.pixelSize: 40; font.weight: Font.DemiBold }
                                Image { anchors.fill: parent; visible: (janela.e.foto || "") !== ""; source: janela.e.foto || ""; fillMode: Image.PreserveAspectCrop }
                            }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: janela.e.nome || ""; color: janela.texto; font.pixelSize: 18; font.weight: Font.DemiBold }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: janela.e.usuario || ""; color: janela.suave; font.pixelSize: 12 }
                        }
                    }
                    Linha { titulo: "Foto da tela de entrada"; clicavel: true; onCarregado: ajustes.abrir("carinaeos-central entrada"); Seta {} }
                    Linha { titulo: "Mudar a senha, outras contas…"; clicavel: true; onCarregado: ajustes.completo("utilizadores"); Seta {} }
                }

                // ===== Sistema (sobre) =====
                Item {
                    visible: janela.pagina === "sistema"
                    Layout.fillWidth: true
                    implicitHeight: 190
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        Image { anchors.horizontalCenter: parent.horizontalCenter; width: 110; height: 110; sourceSize: Qt.size(220, 220); source: "image://icone/carinaeos" }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: janela.e.sistema || "CarinaeOS"; color: janela.texto; font.pixelSize: 22; font.weight: Font.DemiBold }
                    }
                }
                Grupo {
                    visible: janela.pagina === "sistema"
                    Linha { titulo: "Nome do computador"; sub: janela.e.nome || "" }
                    Linha { titulo: "Processador"; sub: (janela.e.processador || "") + (janela.e.nucleos ? " · " + janela.e.nucleos + " núcleos" : "") }
                    Linha { titulo: "Memória"; sub: janela.e.memoria || "" }
                    Linha { titulo: "Disco"; sub: janela.e.disco || "" }
                    Linha { titulo: "Placa gráfica"; sub: janela.e.grafica || "" }
                    Linha { titulo: "Sistema de janelas"; sub: janela.e.janelas || "" }
                    Linha { titulo: "Núcleo (kernel)"; sub: janela.e.nucleo || "" }
                }
                Grupo {
                    visible: janela.pagina === "sistema"
                    Linha { titulo: "Atualizações e aplicativos"; sub: "Órbita"; clicavel: true; onCarregado: ajustes.abrir("carinaeos-orbita"); Seta {} }
                    Linha { titulo: "Drivers e hardware"; sub: "Central do CarinaeOS"; clicavel: true; onCarregado: ajustes.abrir("carinaeos-central drivers"); Seta {} }
                    Linha { titulo: "Manual do CarinaeOS"; clicavel: true; onCarregado: ajustes.abrir("carinaeos-manual"); Seta {} }
                }

                // ===== secções que abrem o módulo completo =====
                Grupo {
                    visible: ["notificacoes", "aplicativos", "teclado", "rato", "impressoras", "contas", "regiao", "acessibilidade"].indexOf(janela.pagina) !== -1
                    Linha {
                        titulo: "Abrir " + janela.seccao.nome
                        sub: "As opções completas abrem numa janela própria."
                        icone: janela.seccao.icone
                        clicavel: true
                        onCarregado: ajustes.completo(janela.pagina)
                        Seta {}
                    }
                }

                // "mais opções" no fim das páginas que o têm
                Botao {
                    visible: janela.seccao.completo && ["notificacoes", "aplicativos", "teclado", "rato", "impressoras", "contas", "regiao", "acessibilidade"].indexOf(janela.pagina) === -1
                    Layout.alignment: Qt.AlignHCenter
                    texto: "Mais opções…"
                    onCarregado: ajustes.completo(janela.pagina)
                }
                Item { Layout.preferredHeight: 40 }
            }
        }
    }

    // senha do Wi-Fi
    Dialog {
        id: senhaWifi
        property string ssid: ""
        property bool segura: true
        anchors.centerIn: parent
        modal: true
        title: "Ligar a " + ssid
        standardButtons: Dialog.Cancel | Dialog.Ok
        onOpened: { campoSenha.text = ""; if (segura) campoSenha.forceActiveFocus(); }
        onAccepted: ajustes.ligarWifi(ssid, campoSenha.text)
        ColumnLayout {
            Text { visible: senhaWifi.segura; text: "Senha da rede"; color: janela.texto }
            TextField { id: campoSenha; visible: senhaWifi.segura; echoMode: TextInput.Password; Layout.preferredWidth: 280; onAccepted: senhaWifi.accept() }
            Text { visible: !senhaWifi.segura; text: "Rede aberta: qualquer pessoa pode ver o que envia."; color: janela.suave }
        }
    }
}
