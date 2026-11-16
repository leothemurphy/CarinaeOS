// CarinaeOS - Configuracoes (ao estilo das Definicoes do Fedora)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: janela
    Connections { target: ajustes; function onEscolherPastaPedida() { ajustes.escolherPastaPartilhar("ro") } }
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
    property bool maisModelos: false        // Configurações › Dock: mostrar os modelos clássicos
    readonly property color linha: Qt.rgba(1, 1, 1, 0.07)
    property string pagina: ajustes.inicio
    readonly property var e: ajustes.estado
    readonly property var seccao: {
        for (const s of ajustes.seccoes) if (s.id === pagina) return s;
        return ajustes.seccoes[0];
    }
    onPaginaChanged: { ajustes.ler(pagina); if (pagina === "contas") prepararContas(); }

    // ---- contas online (KDE Online Accounts) --------------------------------
    property var contasModelo: null
    property string contasErro: ""
    property string contasAviso: ""
    property bool gAvancado: false
    property string gId: ""
    property string gSegredo: ""
    readonly property string kaImport: "import org.kde.kaccounts 1.2 as KA\n"
    function prepararContas(): void {
        if (contasModelo || contasErro !== "") return;
        try {
            contasModelo = Qt.createQmlObject(kaImport + "KA.AccountsModel {}", janela, "contas");
        } catch (e) {
            contasErro = "Falta instalar: sudo apt install kaccounts-integration signon-ui-qt signon-ui-service";
            console.warn("kaccounts:", e);
        }
    }
    function adicionarConta(provedor: string): void {
        prepararContas();
        if (contasErro !== "") return;
        try {
            const j = Qt.createQmlObject(kaImport + "KA.CreateAccountJob {}", janela, "criar");
            j.providerName = provedor;
            contasAviso = "Abrindo a página de entrada… termine o login na janela que aparece.";
            j.finished.connect(() => {
                if (j.error === 0) contasAviso = "";
                else if (j.error === 1) contasAviso = "";          // cancelado
                else contasAviso = "Não foi possível ligar a conta: " + (j.errorText || ("erro " + j.error));
                j.destroy(1000);
            });
            j.start();
        } catch (e) {
            contasAviso = "Não foi possível começar: " + e;
        }
    }
    function removerConta(id: string, nome: string): void {
        try {
            const j = Qt.createQmlObject(kaImport + "KA.RemoveAccountJob {}", janela, "remover");
            j.accountId = id;
            j.finished.connect(() => j.destroy(1000));
            j.start();
        } catch (e) {
            contasAviso = "Não foi possível remover " + nome + ": " + e;
        }
    }
    Timer {
        interval: 2000; repeat: true
        running: janela.active && ["som", "ecras", "energia", "wifi", "bluetooth", "partilha"].indexOf(janela.pagina) !== -1
        onTriggered: ajustes.ler(janela.pagina)
    }
    Component.onCompleted: { ajustes.ler(pagina); if (pagina === "contas") prepararContas(); }

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
        // o valor vem do sistema e é relido de 2 em 2 s; enquanto se arrasta, manda a pessoa
        property real alvo: 0
        onAlvoChanged: if (!pressed) value = alvo
        Component.onCompleted: value = alvo
        width: 220
        height: 30
        padding: 0
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
                    Linha { visible: (janela.e.redes || []).length === 0; titulo: "Procurando redes…"; sub: "Se não aparecer nenhuma, confirme que o Wi-Fi do computador está ligado." }
                }
                Grupo {
                    visible: janela.pagina === "rede"
                    titulo: "Conexões ativas"
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

                // pastas partilhadas na rede: como "Outros locais › Ligar ao servidor" do Fedora
                Grupo {
                    visible: janela.pagina === "rede"
                    titulo: "Pastas compartilhadas na rede"
                    Linha {
                        titulo: "Procurar computadores e NAS na rede"
                        sub: "Windows, Mac, discos de rede (NAS) e impressoras compartilhadas"
                        icone: "network-workgroup"
                        clicavel: true
                        onCarregado: ajustes.abrir("dolphin --new-window smb:/")
                        Seta {}
                    }
                    Item {
                        width: parent.width; height: 92
                        Text { x: 16; y: 12; text: "Ligar a um servidor"; color: janela.texto; font.pixelSize: 14 }
                        Rectangle {
                            id: caixaSrv
                            x: 16; y: 40; width: parent.width - 32 - btLigar.width - 10; height: 36; radius: 8
                            color: Qt.rgba(1, 1, 1, 0.07)
                            border.color: endSrv.activeFocus ? janela.realce : janela.linha
                            TextField {
                                id: endSrv
                                anchors.fill: parent; anchors.leftMargin: 6
                                background: Item {}
                                color: janela.texto
                                placeholderText: "ex.: 192.168.1.20/fotos, \\\\nas\\fotos, sftp://pi@10.0.0.5"
                                placeholderTextColor: janela.suave
                                font.pixelSize: 13
                                onAccepted: { ajustes.ligarServidor(text); text = ""; }
                            }
                        }
                        Botao {
                            id: btLigar
                            x: caixaSrv.x + caixaSrv.width + 10; y: 41
                            texto: "Ligar"; principal: true
                            onCarregado: { ajustes.ligarServidor(endSrv.text); endSrv.text = ""; }
                        }
                    }
                    Repeater {
                        model: janela.e.servidores || []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.nome
                            sub: modelData.url
                            icone: "folder-remote"
                            clicavel: true
                            onCarregado: ajustes.abrir("dolphin --new-window '" + modelData.url.replace(/'/g, "") + "'")
                            Botao { texto: "Esquecer"; onCarregado: ajustes.esquecerServidor(modelData.url) }
                        }
                    }
                }
                Text {
                    visible: janela.pagina === "rede"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    color: janela.suave; font.pixelSize: 12
                    text: "Os servidores ligados ficam também na barra lateral de Meus documentos. Endereços aceites: smb:// (Windows, NAS, Mac), sftp:// (Linux, servidores), nfs://, ftp:// e webdav://."
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
                    titulo: "Telas ligadas"
                    Repeater { model: janela.e.ecras || []; delegate: Linha { required property string modelData; titulo: modelData.replace(/^Output:\s*\d+\s*/, ""); icone: "video-display" } }
                    Linha { titulo: "Resolução, escala e posição…"; clicavel: true; onCarregado: ajustes.completo("ecras"); Seta {} }
                }
                Grupo {
                    visible: janela.pagina === "ecras"
                    Linha { visible: (janela.e.brilho || -1) >= 0; titulo: "Brilho"
                            Deslizante { alvo: janela.e.brilho || 0; onMoved: ajustes.definirBrilho(value) } }
                    Linha { titulo: "Luz noturna"; sub: "Cores mais quentes à noite, para descansar a vista"
                            Switch { onToggled: ajustes.luzNoturna(checked) } }
                }

                // ===== Som =====
                Grupo {
                    visible: janela.pagina === "som"
                    titulo: "Saída"
                    Linha { titulo: "Volume"; icone: "audio-volume-high"
                            Deslizante { alvo: janela.e.volume || 0; onMoved: ajustes.definirVolume(value) } }
                }
                Grupo {
                    visible: janela.pagina === "som"
                    titulo: "Entrada"
                    Linha { titulo: "Microfone"; icone: "audio-input-microphone"
                            Deslizante { alvo: janela.e.microfone || 0; onMoved: ajustes.definirMicrofone(value) } }
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
                            readonly property bool existe: (janela.e.perfis || []).indexOf(modelData[0]) !== -1
                            titulo: modelData[1]
                            sub: existe ? (modelData[0] === "performance" && (janela.e.degradado || "") !== "" ? modelData[2] + " (limitado agora: computador quente ou em bateria)" : modelData[2])
                                        : "Não disponível neste computador"
                            opacity: existe ? 1 : 0.5
                            clicavel: existe && janela.e.perfil !== modelData[0]
                            onCarregado: ajustes.definirPerfil(modelData[0])
                            // só um indicador (quem muda é o clique na linha)
                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: "transparent"
                                border.width: 2
                                border.color: janela.e.perfil === modelData[0] ? janela.realce : Qt.rgba(1, 1, 1, 0.3)
                                Rectangle { anchors.centerIn: parent; width: 10; height: 10; radius: 5; color: janela.realce; visible: janela.e.perfil === modelData[0] }
                            }
                        }
                    }
                }
                Grupo {
                    visible: janela.pagina === "energia"
                    Linha { titulo: "Suspender e desligar a tela…"; clicavel: true; onCarregado: ajustes.completo("energia"); Seta {} }
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
                    titulo: "Desempenho"
                    Linha {
                        titulo: "Modo leve"
                        sub: (janela.e.leve || {}).ligado
                             ? "Ligado: papel de parede parado, sem desfoque nas janelas, animações curtas e sem indexar o conteúdo dos arquivos."
                             : (janela.e.leve || {}).recomendado
                               ? "Recomendado para este computador (" + (janela.e.leve || {}).motivo + "). Deixa tudo mais rápido."
                               : "Para computadores mais antigos: papel de parede parado, sem desfoque, animações curtas."
                        Switch { checked: !!(janela.e.leve || {}).ligado; onToggled: ajustes.definirModoLeve(checked) }
                    }
                }
                Grupo {
                    visible: janela.pagina === "aparencia"
                    titulo: "Papel de parede"
                    Flow {
                        width: parent.width
                        padding: 14
                        spacing: 12
                        // as duas cenas em movimento
                        Repeater {
                            model: [1, 2]
                            delegate: Rectangle {
                                required property int modelData
                                width: 182; height: 104; radius: 10
                                color: "transparent"
                                border.width: ma1.containsMouse ? 2 : 0
                                border.color: janela.realce
                                Image { anchors.fill: parent; anchors.margins: 2; fillMode: Image.PreserveAspectCrop; asynchronous: true
                                        source: "file:///usr/share/wallpapers/CarinaeOS-NebulosaSobreOLago" + (parent.modelData === 2 ? "2" : "") + "/contents/screenshot.jpg" }
                                Rectangle {
                                    x: 8; y: 8; height: 22; width: rotAn.implicitWidth + 16; radius: 11
                                    color: Qt.rgba(0, 0, 0, 0.55)
                                    Text { id: rotAn; anchors.centerIn: parent; text: "▶ Animado"; color: "white"; font.pixelSize: 11 }
                                }
                                MouseArea { id: ma1; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ajustes.definirAnimado(parent.modelData) }
                            }
                        }
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
                    Linha {
                        titulo: "Mostrar recentes no Launchpad"
                        sub: "Ao passar o mouse num aplicativo: os últimos documentos, sites ou conversas (lidos só neste computador)"
                        Switch { checked: janela.e.recentes !== false; onToggled: ajustes.definirRecentes(checked) }
                    }
                    Linha { titulo: "Sessão sem rastro, modo escuro forçado"; sub: "Na Central do CarinaeOS"; clicavel: true; onCarregado: ajustes.abrir("carinaeos-central privacidade"); Seta {} }
                    Linha { titulo: "Pastas, arquivos e aplicativos com senha"; sub: "Cadeado"; clicavel: true; onCarregado: ajustes.abrir("carinaeos-central cadeado"); Seta {} }
                    Linha { titulo: "Bloqueio da tela…"; clicavel: true; onCarregado: ajustes.abrir("kcmshell6 kcm_screenlocker"); Seta {} }
                }

                // ===== Partilha =====
                Grupo {
                    visible: janela.pagina === "partilha"
                    titulo: "Compartilhamento de pastas"
                    Linha {
                        titulo: "Compartilhar pastas deste computador"
                        sub: janela.e.samba ? ("Ligada · noutros computadores aparece como “" + (janela.e.nomePc || "") + "” na Rede (no Windows: \\\\" + ((janela.e.ip || [])[0] || "") + ")")
                                            : "Outros computadores da casa (Windows, Mac, celulares) passam a ver as pastas que escolher."
                        Switch { checked: !!janela.e.samba; onToggled: ajustes.definirPartilha(checked) }
                    }
                    Repeater {
                        model: janela.e.partilhas || []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.nome
                            sub: modelData.caminho + (modelData.livre ? " · sem senha, só leitura" : modelData.escrita ? " · com senha, podem alterar" : " · com senha, só leitura")
                            icone: "folder-publicshare"
                            Botao { texto: "Deixar de compartilhar"; onCarregado: ajustes.deixarDePartilhar(modelData.nome) }
                        }
                    }
                    Linha {
                        visible: !!janela.e.samba
                        titulo: "Compartilhar uma pasta…"
                        sub: livrePart.checked ? "Qualquer pessoa da rede vê os arquivos, sem senha (só leitura)."
                                               : "Os outros entram com o seu usuário e a senha da rede."
                        icone: "list-add"
                        CheckBox { id: livrePart; text: "Sem senha"; palette.windowText: janela.texto; onToggled: if (checked) escritaPart.checked = false }
                        CheckBox { id: escritaPart; text: "Podem alterar"; palette.windowText: janela.texto; enabled: !livrePart.checked }
                        Botao { texto: "Escolher pasta"; principal: true
                                onCarregado: ajustes.escolherPastaPartilhar(livrePart.checked ? "livre" : escritaPart.checked ? "rw" : "ro") }
                    }
                    Linha {
                        visible: !!janela.e.samba
                        titulo: "Senha da rede"
                        sub: janela.e.senhaRede ? ("Definida · nos outros computadores entre com “" + (janela.e.usuario || "") + "” e essa senha")
                                                : "Ainda não definida: escolha uma para os outros entrarem nas pastas com senha"
                        icone: "dialog-password"
                        Botao { texto: janela.e.senhaRede ? "Mudar…" : "Definir…"; principal: !janela.e.senhaRede; onCarregado: senhaRede.open() }
                    }
                }
                Grupo {
                    visible: janela.pagina === "partilha"
                    titulo: "Acesso remoto (SSH)"
                    Linha {
                        titulo: "Permitir entrar neste computador por SSH"
                        sub: janela.e.ssh === 1 ? "Ligado" : janela.e.ssh === 0 ? "Desligado" : "Desligado (é instalado ao ligar)"
                        Switch { checked: janela.e.ssh === 1; onToggled: ajustes.definirSSH(checked) }
                    }
                    Linha { visible: janela.e.ssh === 1; titulo: "Endereço deste computador"; sub: (janela.e.ip || []).join("  ·  ") || "—"; icone: "network-wired" }
                    Linha { visible: janela.e.ssh === 1; titulo: "Usuário"; sub: janela.e.usuario || ""; icone: "user-identity" }
                    Linha { visible: janela.e.ssh === 1; titulo: "Senha"; sub: "A mesma com que entra neste computador (por segurança não é mostrada aqui)"; icone: "dialog-password" }
                    Item {
                        visible: janela.e.ssh === 1
                        width: parent.width; height: colSsh.implicitHeight + 24
                        Column {
                            id: colSsh
                            x: 16; y: 12; width: parent.width - 32; spacing: 6
                            Text { text: "Para entrar a partir de outro computador"; color: janela.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
                            Text { width: parent.width; wrapMode: Text.WordWrap; color: janela.suave; font.pixelSize: 12
                                   text: "Windows (PowerShell), Mac ou Linux (Terminal): escreva o comando abaixo e, quando pedir, a sua senha. Para copiar arquivos, num gestor de arquivos use o endereço sftp://." }
                            Repeater {
                                model: janela.e.ip || []
                                delegate: Column {
                                    required property string modelData
                                    spacing: 2
                                    TextEdit { readOnly: true; selectByMouse: true; color: "#ffd6a8"; font.family: "monospace"; font.pixelSize: 15
                                               text: "ssh " + (janela.e.usuario || "") + "@" + modelData }
                                    TextEdit { readOnly: true; selectByMouse: true; color: janela.suave; font.family: "monospace"; font.pixelSize: 13
                                               text: "sftp://" + (janela.e.usuario || "") + "@" + modelData }
                                }
                            }
                        }
                    }
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
                    Linha { titulo: "Feito a partir de"; sub: janela.e.base || "" }
                }
                Grupo {
                    visible: janela.pagina === "sistema"
                    Linha { titulo: "Atualizações e aplicativos"; sub: "Órbita"; clicavel: true; onCarregado: ajustes.abrir("carinaeos-orbita"); Seta {} }
                    Linha { titulo: "Drivers e hardware"; sub: "Central do CarinaeOS"; clicavel: true; onCarregado: ajustes.abrir("carinaeos-central drivers"); Seta {} }
                    Linha { titulo: "Manual do CarinaeOS"; clicavel: true; onCarregado: ajustes.abrir("carinaeos-manual"); Seta {} }
                }

                // ===== Contas online =====
                // usa o KDE Online Accounts (kaccounts): o provedor abre a página de entrada dele, e depois
                // a conta (o email) aparece aqui. Carregado à mão para a página não partir se faltar o módulo.
                Grupo {
                    visible: janela.pagina === "contas"
                    titulo: "Contas ligadas"
                    Repeater {      // contas Google (login do CarinaeOS)
                        id: rptGoogle
                        model: (janela.e.google || {}).contas || []
                        delegate: Linha {
                            id: lGoogle
                            required property var modelData
                            property bool confirmar: false
                            titulo: modelData.email
                            sub: "Google" + (modelData.nome ? " · " + modelData.nome : "") + (modelData.calendario ? " · calendário atualizado " + (modelData.sincronizado || "") : "")
                            icone: "im-google"
                            Row {
                                spacing: 8
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "Calendário"; color: janela.suave; font.pixelSize: 12 }
                                Switch { anchors.verticalCenter: parent.verticalCenter; checked: !!lGoogle.modelData.calendario; onToggled: ajustes.calendarioGoogle(lGoogle.modelData.email, checked) }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: "Drive"; color: janela.suave; font.pixelSize: 12 }
                                Switch { anchors.verticalCenter: parent.verticalCenter; checked: !!lGoogle.modelData.drive; onToggled: ajustes.driveGoogle(lGoogle.modelData.email, checked) }
                                Botao {
                                    texto: lGoogle.confirmar ? "Desligar mesmo?" : "Desligar"
                                    onCarregado: {
                                        if (!lGoogle.confirmar) { lGoogle.confirmar = true; return; }
                                        ajustes.removerGoogle(lGoogle.modelData.email);
                                    }
                                }
                            }
                        }
                    }
                    Repeater {
                        id: rptContas
                        model: janela.contasModelo
                        delegate: Linha {
                            id: lConta
                            required property var model
                            property bool confirmar: false
                            titulo: model.displayName || "(sem nome)"
                            // a conta Google pelo KDE nunca chega a acabar o login: avisa para a remover
                            sub: model.providerName === "google" ? "Login antigo pelo KDE, que não terminou — pode remover"
                               : (model.providerDisplayName || model.providerName || "") + (model.enabled === false ? " · desligada" : "")
                            icone: model.iconName || "user-identity"
                            Botao {
                                texto: lConta.confirmar ? "Remover mesmo?" : "Remover"
                                onCarregado: {
                                    if (!lConta.confirmar) { lConta.confirmar = true; return; }
                                    janela.removerConta(String(lConta.model.id), lConta.model.displayName || "");
                                }
                            }
                        }
                    }
                    Linha {
                        visible: rptContas.count === 0 && rptGoogle.count === 0
                        titulo: janela.contasErro !== "" ? "As contas online não estão disponíveis" : "Ainda não há contas ligadas"
                        sub: janela.contasErro !== "" ? janela.contasErro : "Escolha um provedor abaixo e entre com a sua conta."
                        icone: "user-identity"
                    }
                }
                Grupo {
                    visible: janela.pagina === "contas"
                    titulo: "Adicionar uma conta"
                    Linha {     // só aparece com o cliente Google configurado (Avançado, mais abaixo)
                        visible: !!(janela.e.google || {}).configurado
                        titulo: "Google"
                        sub: "Abre o Google no navegador para entrar e autorizar o CarinaeOS"
                        icone: "im-google"
                        clicavel: true
                        onCarregado: ajustes.entrarGoogle()
                        Seta {}
                    }
                    Linha { titulo: "Nextcloud"; sub: "Arquivos, calendário e contatos — entra no seu servidor Nextcloud"; icone: "folder-cloud"; clicavel: true; onCarregado: janela.adicionarConta("nextcloud"); Seta {} }
                    Linha { titulo: "ownCloud"; sub: "Arquivos — entra no seu servidor ownCloud"; icone: "folder-cloud"; clicavel: true; onCarregado: janela.adicionarConta("owncloud"); Seta {} }
                    Linha {
                        visible: janela.contasAviso !== ""
                        titulo: janela.contasAviso
                        icone: "dialog-information"
                    }
                }
                Grupo {     // avançado: quem quiser usar a própria app do Google Cloud
                    visible: janela.pagina === "contas" && janela.e.google !== undefined && !janela.e.google.configurado
                    Linha {
                        titulo: "Avançado: conta Google com a sua própria app"
                        sub: janela.gAvancado ? "Para quem tem um projeto no Google Cloud" : "Drive e calendários do Google com uma app do Google Cloud criada por você"
                        icone: "configure"
                        clicavel: true
                        onCarregado: janela.gAvancado = !janela.gAvancado
                        Text { text: janela.gAvancado ? "⌄" : "›"; color: janela.suave; font.pixelSize: 20 }
                    }
                }
                Grupo {
                    visible: janela.pagina === "contas" && janela.gAvancado && janela.e.google !== undefined && !janela.e.google.configurado
                    titulo: "Configurar o login do Google (uma vez)"
                    Linha { titulo: "1. Crie o cliente no Google Cloud"; sub: "Tipo «App para computador», com o nome CarinaeOS"; icone: "internet-web-browser"; clicavel: true; onCarregado: ajustes.abrir("xdg-open https://console.cloud.google.com/auth/clients"); Seta {} }
                    Linha { titulo: "2. Escolha o arquivo JSON que baixou"; sub: "client_secret_….json, na pasta Downloads"; icone: "document-open"; clicavel: true; onCarregado: ajustes.ficheiroGoogle(); Seta {} }
                    Item {
                        width: parent.width; height: 132
                        Text { x: 16; y: 10; text: "… ou cole o ID e o segredo do cliente"; color: janela.texto; font.pixelSize: 13 }
                        Repeater {
                            model: [["ID do cliente (….apps.googleusercontent.com)", false], ["Segredo do cliente (GOCSPX-…)", true]]
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                x: 16; y: 36 + index * 44; width: parent.width - 32 - (index === 1 ? btGuardarG.width + 10 : 0); height: 36; radius: 8
                                color: Qt.rgba(1, 1, 1, 0.07)
                                border.color: campoG.activeFocus ? janela.realce : janela.linha
                                TextField {
                                    id: campoG
                                    anchors.fill: parent; anchors.leftMargin: 6
                                    background: Item {}
                                    color: janela.texto
                                    echoMode: parent.modelData[1] ? TextInput.Password : TextInput.Normal
                                    placeholderText: parent.modelData[0]
                                    placeholderTextColor: janela.suave
                                    font.pixelSize: 13
                                    onTextChanged: { if (parent.index === 0) janela.gId = text; else janela.gSegredo = text; }
                                }
                            }
                        }
                        Botao { id: btGuardarG; x: parent.width - width - 16; y: 37 + 44; texto: "Salvar"; principal: true; onCarregado: ajustes.configurarGoogle(janela.gId, janela.gSegredo) }
                    }
                }
                Grupo {
                    visible: janela.pagina === "contas"
                    titulo: "Calendários pelo endereço (iCal)"
                    Linha { titulo: "Google, iCloud ou Outlook"; sub: "Mostrar um calendário no relógio pelo endereço secreto iCal"; icone: "view-calendar"; clicavel: true; onCarregado: ajustes.abrir("carinaeos-central calendarios"); Seta {} }
                    Linha { visible: ((janela.e.google || {}).contas || []).some(c => c.drive); titulo: "Abrir o Google Drive"; sub: "A pasta Google Drive (ligue o Drive na conta, em cima)"; icone: "folder-gdrive"; clicavel: true; onCarregado: ajustes.abrir("dolphin --new-window \"$HOME/Google Drive\""); Seta {} }
                }

                // ===== Dock =====
                Grupo {
                    visible: janela.pagina === "dock"
                    titulo: "Modelo"
                    Item {
                        width: parent.width
                        height: gradeModelos.implicitHeight + 28 + 44
                        Flow {
                            id: gradeModelos
                            x: 14; y: 14; width: parent.width - 28
                            spacing: 12
                            Repeater {
                                model: [
                                    ["fluent", "Fluent", "Padrão do CarinaeOS"], ["vidro", "Vidro", "Transparente com reflexo"],
                                    ["minimalista", "Minimalista", "Só uma linha fina"], ["colorida", "Colorida", "Borda em degradê"],
                                    ["orbital", "Orbital", "Bolhas de vidro"], ["hexagonal", "Hexagonal", "Afastam-se ao passar o mouse"],
                                    ["icones", "Só ícones", "Sem fundo, afastam-se"], ["redondos", "Redondos", "Círculos, afastam-se"],
                                    ["aereo", "Aéreo", "Vidro azulado com luzes"], ["mac", "Mac", "Vidro claro, como no macOS"]
                                ].concat(janela.maisModelos ? [
                                    ["escuro", "Mac escuro", "Clássico"], ["transparente", "Transparente", "Clássico"],
                                    ["bolhas", "Bubbles", "Clássico"], ["squircle", "Squircle", "Clássico"], ["rosepine", "Rosé Pine", "Clássico"],
                                    ["xp", "Windows XP", "Clássico"], ["vista", "Vista", "Clássico"], ["translucido", "Translúcido", "Clássico"],
                                    ["docklike", "DockLike", "Clássico"], ["matter", "Matter", "Clássico"], ["lucent", "Lucent", "Clássico"],
                                    ["neon", "Neon", "Clássico"]
                                ] : [])
                                delegate: Rectangle {
                                    id: cartaoModelo
                                    required property var modelData
                                    readonly property bool escolhido: (janela.e.estilo || "fluent") === modelData[0]
                                    width: Math.floor((gradeModelos.width - 24) / 3); height: width * 0.24 + 50
                                    radius: 14
                                    color: escolhido ? Qt.rgba(1, 0.7, 0.43, 0.12) : Qt.rgba(1, 1, 1, ratoModelo.containsMouse ? 0.07 : 0.03)
                                    border.width: escolhido ? 2 : 1
                                    border.color: escolhido ? janela.realce : Qt.rgba(1, 1, 1, 0.10)
                                    Image {
                                        x: 8; y: 8; width: parent.width - 16; height: parent.width * 0.24 - 4
                                        source: "file://" + (janela.e.pastaEstilos || "") + "/" + cartaoModelo.modelData[0] + ".png"
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        smooth: true
                                    }
                                    Column {
                                        x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                                        Text { text: cartaoModelo.modelData[1]; color: janela.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
                                        Text { text: cartaoModelo.modelData[2]; color: janela.suave; font.pixelSize: 11 }
                                    }
                                    MouseArea {
                                        id: ratoModelo
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: ajustes.definirModeloDock("estilo", cartaoModelo.modelData[0])
                                    }
                                }
                            }
                        }
                        Botao {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                            texto: janela.maisModelos ? "Menos modelos" : "Mais modelos (clássicos)…"
                            onCarregado: janela.maisModelos = !janela.maisModelos
                        }
                    }
                }
                Grupo {
                    visible: janela.pagina === "dock"
                    titulo: "Tamanho e efeito"
                    Linha { titulo: "Tamanho dos ícones"; sub: Math.round(janela.e.iconSize || 56) + " px"
                            Deslizante { from: 32; to: 96; stepSize: 2; alvo: janela.e.iconSize || 56; onMoved: ajustes.definirDock("iconSize", Math.round(value)) } }
                    Linha {
                        titulo: "Ao passar o mouse"
                        sub: (janela.e.ampliacao || "dentro") === "onda" ? "Os ícones crescem numa onda e sobem acima da Dock (como no Mac)"
                                                                       : "Só o ícone cresce um pouco, sem sair da Dock"
                        Row {
                            spacing: 8
                            Botao { texto: "Dentro da Dock"; principal: (janela.e.ampliacao || "dentro") !== "onda"; onCarregado: ajustes.definirModeloDock("ampliacao", "dentro") }
                            Botao { texto: "Onda"; principal: (janela.e.ampliacao || "dentro") === "onda"; onCarregado: ajustes.definirModeloDock("ampliacao", "onda") }
                        }
                    }
                    Linha { visible: janela.e.ampliacao === "onda"
                            titulo: "Tamanho da onda"; sub: (janela.e.zoom || 1.6) <= 1.01 ? "Desligada" : Math.round(((janela.e.zoom || 1.6) - 1) * 100) + "%"
                            Deslizante { from: 1; to: 2.2; stepSize: 0.1; alvo: janela.e.zoom || 1.6; onMoved: ajustes.definirDock("zoom", value) } }
                }
                Grupo {
                    visible: janela.pagina === "dock"
                    titulo: "Posição"
                    Item {
                        width: parent.width; height: 70
                        Row {
                            anchors.centerIn: parent
                            spacing: 10
                            Repeater {
                                model: [["bottom", "Embaixo"], ["left", "À esquerda"], ["right", "À direita"], ["top", "Em cima"]]
                                delegate: Botao {
                                    required property var modelData
                                    texto: modelData[1]
                                    principal: (janela.e.posicao || "bottom") === modelData[0]
                                    onCarregado: { ajustes.definirDock("posicao", modelData[0]); ajustes.ler("dock"); }
                                }
                            }
                        }
                    }
                    Linha { titulo: "Esconder automaticamente"; sub: "Aparece quando o mouse chega à beira da tela"
                            Switch { checked: !!janela.e.esconder; onToggled: ajustes.definirDock("esconder", checked) } }
                }
                Grupo {
                    visible: janela.pagina === "dock"
                    titulo: "Separadores"
                    Linha { titulo: "Espessura"; sub: (janela.e.separatorWidth || 1) + " px"
                            Deslizante { from: 1; to: 6; stepSize: 1; alvo: janela.e.separatorWidth || 1; onMoved: ajustes.definirDock("separatorWidth", Math.round(value)) } }
                    Item {
                        width: parent.width; height: 64
                        Text { x: 16; anchors.verticalCenter: parent.verticalCenter; text: "Cor"; color: janela.texto; font.pixelSize: 14 }
                        Row {
                            anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Repeater {
                                model: ["#59ffffff", "#ffffffff", "#ffb46e", "#7aa7ff", "#a35bff", "#3ee0b0", "#ff6f91", "#000000"]
                                delegate: Rectangle {
                                    required property string modelData
                                    width: 26; height: 26; radius: 13
                                    color: modelData
                                    border.width: (janela.e.separatorColor || "#59ffffff") === modelData ? 3 : 1
                                    border.color: (janela.e.separatorColor || "#59ffffff") === modelData ? janela.realce : Qt.rgba(1, 1, 1, 0.3)
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ajustes.definirDock("separatorColor", parent.modelData); ajustes.ler("dock"); } }
                                }
                            }
                        }
                    }
                    Linha { titulo: "Colocar um separador"; sub: "Na Dock: botão direito num ícone › Adicionar separador à direita. Arraste os ícones para os reorganizar." }
                }

                // ===== secções que abrem o módulo completo =====
                Grupo {
                    visible: ["notificacoes", "aplicativos", "teclado", "rato", "impressoras", "regiao", "acessibilidade"].indexOf(janela.pagina) !== -1
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
                    visible: janela.seccao.completo && ["notificacoes", "aplicativos", "teclado", "rato", "impressoras", "regiao", "acessibilidade"].indexOf(janela.pagina) === -1
                    Layout.alignment: Qt.AlignHCenter
                    texto: "Mais opções…"
                    onCarregado: ajustes.completo(janela.pagina)
                }
                Item { Layout.preferredHeight: 40 }
            }
        }
    }

    // senha da rede (pastas compartilhadas)
    Dialog {
        id: senhaRede
        anchors.centerIn: parent
        modal: true
        title: "Senha da rede"
        standardButtons: Dialog.Cancel | Dialog.Ok
        onOpened: { sr1.text = ""; sr2.text = ""; sr1.forceActiveFocus(); }
        onAccepted: if (sr1.text.length >= 4 && sr1.text === sr2.text) ajustes.definirSenhaRede(sr1.text)
        ColumnLayout {
            Text { text: "Os outros computadores pedem o seu usuário (" + (janela.e.usuario || "") + ") e esta senha.\nPode ser diferente da senha com que entra no CarinaeOS."; color: janela.suave }
            TextField { id: sr1; echoMode: TextInput.Password; placeholderText: "Senha"; Layout.preferredWidth: 300 }
            TextField { id: sr2; echoMode: TextInput.Password; placeholderText: "Repita a senha"; Layout.preferredWidth: 300; onAccepted: senhaRede.accept() }
            Text { visible: sr2.text.length > 0 && sr1.text !== sr2.text; text: "As senhas não são iguais."; color: "#ff7a9a" }
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
