// CarinaeOS - Configuracoes (ao estilo das Definicoes do Fedora)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Dialogs

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
    property string msgVista: ""             // a mensagem de baixo some sozinha passados uns segundos        // Configurações › Dock: mostrar os modelos clássicos
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
        interval: ["wifi", "rede"].indexOf(janela.pagina) !== -1 ? 8000 : 2500; repeat: true
        running: janela.active && ["som", "ecras", "energia", "wifi", "rede", "bluetooth", "partilha", "impressoras", "rato"].indexOf(janela.pagina) !== -1
        onTriggered: ajustes.ler(janela.pagina)
    }
    Component.onCompleted: { ajustes.ler(pagina); if (pagina === "contas") prepararContas(); }

    // ---- aplicativos instalados ---------------------------------------------------------------------
    property string procuraApps: ajustes.procuraInicial
    property bool padroesAberto: false
    property var tipoVisto: ({})
    Connections { target: ajustes; function onTipoPronto(d) { janela.tipoVisto = d } }
    property string origemApps: ""
    property string ordemApps: "nome"
    readonly property var appsFiltrados: {
        const p = sem(procuraApps)
        const l = (e.apps || []).filter(a => (origemApps === "" || a.origem === origemApps) && (p === "" || sem(a.nome + " " + a.detalhe).indexOf(p) !== -1))
        if (ordemApps === "tamanho") l.sort((a, b) => b.tamanho - a.tamanho)
        else if (ordemApps === "data") l.sort((a, b) => b.data - a.data)
        return l
    }
    function tamanho(b) {
        if (!b) return ""
        const u = ["B", "KB", "MB", "GB", "TB"]; let i = 0
        while (b >= 1000 && i < u.length - 1) { b /= 1000; i++ }
        return b.toLocaleString(Qt.locale("pt_BR"), "f", b < 10 && i > 1 ? 1 : 0) + " " + u[i]
    }
    function origemNome(o) { return ({ Flathub: "Flathub", Debian: "Debian", AppImage: "AppImage", Aplicativo: "Aplicativo", Windows: "Programa do Windows" })[o] || o }

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
    component BotaoMudo: Rectangle {
        property bool mudo: false
        signal carregado()
        width: 34; height: 34; radius: 17
        color: mm.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.06)
        Image { anchors.centerIn: parent; width: 18; height: 18; sourceSize: Qt.size(36, 36)
                source: "image://icone/" + (parent.mudo ? "audio-volume-muted" : "audio-volume-high"); opacity: parent.mudo ? 0.6 : 1 }
        MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.carregado() }
    }
    component Combo: ComboBox {
        id: cb
        width: 220; height: 34
        contentItem: Text { leftPadding: 12; rightPadding: 28; text: cb.displayText; color: janela.texto; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13; elide: Text.ElideRight }
        background: Rectangle { radius: 8; color: Qt.rgba(1, 1, 1, cb.hovered ? 0.12 : 0.07); border.width: 1; border.color: janela.linha }
        indicator: Text { x: cb.width - 22; anchors.verticalCenter: parent.verticalCenter; text: "▾"; color: janela.suave }
        popup: Popup {
            y: cb.height + 4; width: cb.width; padding: 4
            implicitHeight: Math.min(contentItem.implicitHeight + 8, 320)
            background: Rectangle { radius: 10; color: janela.cartao; border.color: Qt.rgba(1, 1, 1, 0.12) }
            contentItem: ListView { implicitHeight: contentHeight; clip: true; model: cb.popup.visible ? cb.delegateModel : null }
        }
        delegate: ItemDelegate {
            required property int index
            required property var modelData
            width: cb.width - 8; height: 32
            contentItem: Text { text: modelData; color: index === cb.currentIndex ? janela.realce : janela.texto; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
            background: Rectangle { radius: 6; color: parent.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent" }
        }
    }
    component EscolhaE: Combo {
        id: ee
        property string chave
        property var opcoes: []
        width: 220
        model: opcoes.map(o => o[1])
        currentIndex: Math.max(0, opcoes.findIndex(o => o[0] === (janela.e.energia || {})[chave]))
        onActivated: (i) => ajustes.energiaMudar(chave, opcoes[i][0])
    }
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
        Timer { id: tempoMsg; interval: 6000; onTriggered: janela.msgVista = ajustes.mensagem }
        Connections { target: ajustes; function onMudou() { if (ajustes.mensagem !== janela.msgVista && ajustes.mensagem !== "Desinstalando…") tempoMsg.restart() } }
        Rectangle {
            visible: ajustes.mensagem !== "" && ajustes.mensagem !== janela.msgVista
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

                // ===== Wi-Fi =====
                Grupo {
                    visible: janela.pagina === "wifi"
                    Linha {
                        titulo: "Wi-Fi"
                        sub: !janela.e.temWifi && janela.e.temWifi !== undefined ? "Este computador não tem Wi-Fi (use o cabo: veja Rede)"
                           : (janela.e.redes || []).filter(r => r.ligada).map(r => "Ligado a " + r.ssid).join("") || (janela.e.wifi ? "Não ligado" : "Desligado")
                        icone: "network-wireless"
                        Switch { enabled: janela.e.temWifi !== false; checked: !!janela.e.wifi; onToggled: { ajustes.definirWifi(checked); ajustes.ler("wifi"); } }
                    }
                }
                Grupo {
                    visible: janela.pagina === "wifi" && !!janela.e.wifi
                    titulo: "Redes disponíveis"
                    Repeater {
                        model: janela.e.redes || []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.ssid
                            sub: (modelData.ligada ? "Ligada" : modelData.conhecida ? "Guardada" : (modelData.segura ? "Protegida" : "Aberta — não protegida"))
                                 + "  ·  " + modelData.banda + (modelData.seguranca ? "  ·  " + modelData.seguranca : "")
                            clicavel: !modelData.ligada
                            onCarregado: {
                                const g = (janela.e.guardadas || []).find(c => c.nome === modelData.ssid);
                                if (g) ajustes.ligarGuardada(g.uuid, "wifi");
                                else if (modelData.segura) senhaWifi.abrir(modelData.ssid, false);
                                else ajustes.ligarWifiNova(modelData.ssid, "", false);
                            }
                            // as barras do sinal
                            Row {
                                spacing: 2
                                Repeater {
                                    model: 4
                                    Rectangle {
                                        required property int index
                                        anchors.bottom: parent.bottom
                                        width: 4; height: 5 + index * 4; radius: 1
                                        color: modelData.sinal > index * 25 ? (modelData.ligada ? janela.realce : janela.texto) : Qt.rgba(1, 1, 1, 0.18)
                                    }
                                }
                            }
                            Text { visible: modelData.segura; text: "🔒"; font.pixelSize: 11 }
                            Botao { visible: modelData.ligada; texto: "Desligar"
                                    onCarregado: { const g = (janela.e.guardadas || []).find(c => c.nome === modelData.ssid); if (g) ajustes.desligarLigacao(g.uuid, "wifi") } }
                        }
                    }
                    Linha { visible: (janela.e.redes || []).length === 0; titulo: "A procurar redes…"; sub: "Se não aparecer nenhuma, confirme que o Wi-Fi do computador está ligado." }
                    Linha { titulo: "Procurar outra vez"; icone: "view-refresh"; clicavel: true; onCarregado: ajustes.procurarWifi(); Seta {} }
                    Linha { titulo: "Ligar a uma rede oculta…"; icone: "network-wireless-hidden"; clicavel: true; onCarregado: senhaWifi.abrir("", true); Seta {} }
                }
                Grupo {
                    visible: janela.pagina === "wifi" && (janela.e.guardadas || []).length > 0
                    titulo: "Redes guardadas"
                    Repeater {
                        model: janela.e.guardadas || []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.nome
                            sub: modelData.ativa ? "Ligada agora" : (modelData.automatica ? "Liga sozinha quando estiver perto" : "Só liga quando pedir")
                            Botao { texto: "Ver senha"; onCarregado: ajustes.verSenhaWifi(modelData.uuid) }
                            Botao { texto: "Esquecer"; onCarregado: ajustes.esquecerLigacao(modelData.uuid, "wifi") }
                        }
                    }
                }

                // ===== Rede =====
                Repeater {
                    model: janela.pagina === "rede" ? (janela.e.dispositivos || []) : []
                    delegate: Grupo {
                        id: gDisp
                        required property var modelData
                        readonly property var lig: (janela.e.ligacoes || []).find(c => c.nome === modelData.ligacao) || null
                        titulo: (modelData.tipo === "cabo" ? "Cabo" : modelData.tipo === "wifi" ? "Wi-Fi" : modelData.tipo) + "  (" + modelData.nome + ")"
                        Linha {
                            titulo: modelData.ligado ? (modelData.ligacao || "Ligado") : "Desligado"
                            sub: modelData.ligado ? ("Ligado" + (modelData.velocidade ? "  ·  " + modelData.velocidade : "")) : (modelData.tipo === "cabo" ? "O cabo não está ligado" : modelData.estado)
                            icone: modelData.tipo === "cabo" ? "network-wired" : "network-wireless"
                            Botao { visible: !!gDisp.lig && modelData.ligado; texto: "Desligar"; onCarregado: ajustes.desligarLigacao(gDisp.lig.uuid, "rede") }
                            Botao { visible: !!gDisp.lig && !modelData.ligado; texto: "Ligar"; principal: true; onCarregado: ajustes.ligarGuardada(gDisp.lig.uuid, "rede") }
                        }
                        Linha { visible: modelData.ligado; titulo: "Endereço IP"; sub: (modelData.ipv4 || []).join("  ·  ") || "—" }
                        Linha { visible: modelData.ligado && !!modelData.gateway; titulo: "Router (gateway)"; sub: modelData.gateway || "" }
                        Linha { visible: modelData.ligado; titulo: "DNS"; sub: (modelData.dns || []).join("  ·  ") || "—" }
                        Linha { visible: (modelData.ipv6 || []).length > 0; titulo: "IPv6"; sub: (modelData.ipv6 || []).join("\n") }
                        Linha { titulo: "Endereço físico (MAC)"; sub: modelData.mac || "—" }
                        Linha {
                            visible: !!gDisp.lig
                            titulo: "Configurar o IP e o DNS…"
                            sub: gDisp.lig ? (gDisp.lig.metodo === "manual" ? "IP fixo: " + gDisp.lig.enderecos : "Automático (DHCP)") + (gDisp.lig.dnsManual ? "  ·  DNS: " + gDisp.lig.dnsManual : "") : ""
                            clicavel: true; onCarregado: dlgIp.abrir(gDisp.lig)
                            Seta {}
                        }
                    }
                }
                Grupo {
                    visible: janela.pagina === "rede"
                    titulo: "VPN"
                    Repeater {
                        model: janela.pagina === "rede" ? (janela.e.vpns || []) : []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.nome
                            sub: modelData.ativa ? "Ligada" : "Desligada"
                            icone: "network-vpn"
                            Switch { checked: modelData.ativa; onToggled: checked ? ajustes.ligarGuardada(modelData.uuid, "rede") : ajustes.desligarLigacao(modelData.uuid, "rede") }
                            Botao { texto: "Remover"; onCarregado: ajustes.esquecerLigacao(modelData.uuid, "rede") }
                        }
                    }
                    Linha { titulo: "Adicionar VPN a partir de um ficheiro…"; sub: "OpenVPN (.ovpn) ou WireGuard (.conf)"; icone: "list-add"
                            clicavel: true; onCarregado: escolherVpn.open(); Seta {} }
                }
                Grupo {
                    visible: janela.pagina === "rede"
                    Linha { titulo: "Nome deste computador na rede"; sub: janela.e.nomePc || "" ; icone: "computer" }
                }

                // pastas partilhadas na rede (abrem no Documentos)
                Grupo {
                    visible: janela.pagina === "rede"
                    titulo: "Pastas compartilhadas na rede"
                    Linha {
                        titulo: "Procurar computadores e NAS na rede"
                        sub: "Windows, Mac, discos de rede (NAS) — abre a página Rede do Documentos"
                        icone: "network-workgroup"
                        clicavel: true
                        onCarregado: ajustes.abrir("carinaeos-arquivos carinae:rede")
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
                                placeholderText: "ex.: \\\\nas\\fotos  ou  smb://192.168.1.20/fotos"
                                placeholderTextColor: janela.suave
                                font.pixelSize: 13
                                onAccepted: { ajustes.abrir("carinaeos-arquivos '" + text.replace(/'/g, "") + "'"); text = ""; }
                            }
                        }
                        Botao {
                            id: btLigar
                            x: caixaSrv.x + caixaSrv.width + 10; y: 41
                            texto: "Ligar"; principal: true
                            onCarregado: { ajustes.abrir("carinaeos-arquivos '" + endSrv.text.replace(/'/g, "") + "'"); endSrv.text = ""; }
                        }
                    }
                    Repeater {
                        model: janela.pagina === "rede" ? (janela.e.servidores || []) : []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.nome
                            sub: modelData.url
                            icone: "folder-remote"
                            clicavel: true
                            onCarregado: ajustes.abrir("carinaeos-arquivos '" + modelData.url.replace(/'/g, "") + "'")
                            Botao { texto: "Esquecer"; onCarregado: ajustes.esquecerServidor(modelData.url) }
                        }
                    }
                }

                // ===== Bluetooth =====
                Grupo {
                    visible: janela.pagina === "bluetooth"
                    Linha {
                        titulo: "Bluetooth"
                        sub: janela.e.temBt === false ? "Este computador não tem Bluetooth (pode usar uma pen Bluetooth USB)"
                           : janela.e.bluetooth ? "Ligado" : "Desligado"
                        icone: "preferences-system-bluetooth"
                        Switch { enabled: janela.e.temBt !== false; checked: !!janela.e.bluetooth; onToggled: { ajustes.definirBluetooth(checked); ajustes.ler("bluetooth"); } }
                    }
                }
                Grupo {
                    visible: janela.pagina === "bluetooth" && !!janela.e.bluetooth
                    titulo: "Os meus aparelhos"
                    Repeater {
                        model: janela.pagina === "bluetooth" ? (janela.e.aparelhos || []) : []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.nome
                            sub: (modelData.ligado ? "Ligado" : "Não ligado") + (modelData.bateria >= 0 ? "  ·  bateria " + modelData.bateria + "%" : "")
                            icone: modelData.icone
                            Botao { texto: modelData.ligado ? "Desligar" : "Ligar"; principal: !modelData.ligado
                                    onCarregado: ajustes.btAcao(modelData.ligado ? "disconnect" : "connect", modelData.mac) }
                            Botao { texto: "Esquecer"; onCarregado: ajustes.btAcao("remove", modelData.mac) }
                        }
                    }
                    Linha { visible: (janela.e.aparelhos || []).length === 0; titulo: "Ainda não há aparelhos emparelhados" }
                }
                Grupo {
                    visible: janela.pagina === "bluetooth" && !!janela.e.bluetooth
                    titulo: "Adicionar um aparelho"
                    Linha { titulo: "Procurar aparelhos"; sub: "Ponha os fones, o rato ou o comando em modo de emparelhar"; icone: "view-refresh"
                            clicavel: true; onCarregado: ajustes.btProcurar(); Seta {} }
                    Repeater {
                        model: janela.pagina === "bluetooth" ? (janela.e.novos || []) : []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.nome
                            sub: modelData.mac
                            Botao { texto: "Emparelhar"; principal: true; onCarregado: ajustes.btAcao("emparelhar", modelData.mac) }
                        }
                    }
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
                    titulo: "Saída — onde se ouve"
                    Repeater {
                        model: janela.pagina === "som" ? (janela.e.saidas || []) : []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.descricao
                            sub: modelData.padrao ? (modelData.mudo ? "Em uso · sem som" : "Em uso") : "Clique para usar este"
                            icone: modelData.icone
                            clicavel: !modelData.padrao
                            onCarregado: ajustes.somPadrao("saida", modelData.nome)
                            BotaoMudo { visible: modelData.padrao; mudo: modelData.mudo; onCarregado: ajustes.somMudo("saida", modelData.nome) }
                            Deslizante { visible: modelData.padrao; width: 180; alvo: modelData.volume; onMoved: ajustes.somVolume("saida", modelData.nome, value) }
                            Botao { texto: "Testar"; onCarregado: ajustes.somTestar(modelData.nome) }
                        }
                    }
                    Linha { visible: (janela.e.saidas || []).length === 0; titulo: "Nenhuma saída de som encontrada"; sub: "Confirme que o PipeWire está a correr (pipewire-pulse)." }
                }
                Grupo {
                    visible: janela.pagina === "som" && (janela.e.apps || []).length > 0
                    titulo: "Misturador — o volume de cada aplicação"
                    Repeater {
                        model: janela.pagina === "som" ? (janela.e.apps || []) : []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.nome
                            sub: modelData.media
                            icone: modelData.icone
                            BotaoMudo { mudo: modelData.mudo; onCarregado: ajustes.somMudo("app", String(modelData.id)) }
                            Deslizante { width: 180; alvo: modelData.volume; onMoved: ajustes.somVolume("app", String(modelData.id), value) }
                        }
                    }
                }
                Grupo {
                    visible: janela.pagina === "som"
                    titulo: "Entrada — o microfone"
                    Repeater {
                        model: janela.pagina === "som" ? (janela.e.entradas || []) : []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.descricao
                            sub: modelData.padrao ? (modelData.mudo ? "Em uso · desligado" : "Em uso") : "Clique para usar este"
                            icone: "audio-input-microphone"
                            clicavel: !modelData.padrao
                            onCarregado: ajustes.somPadrao("entrada", modelData.nome)
                            BotaoMudo { visible: modelData.padrao; mudo: modelData.mudo; onCarregado: ajustes.somMudo("entrada", modelData.nome) }
                            Deslizante { visible: modelData.padrao; width: 180; alvo: modelData.volume; onMoved: ajustes.somVolume("entrada", modelData.nome, value) }
                        }
                    }
                    Linha { visible: (janela.e.entradas || []).length === 0; titulo: "Nenhum microfone encontrado" }
                }
                Grupo {
                    visible: janela.pagina === "som" && (janela.e.placas || []).length > 0
                    titulo: "Placas de som — o modo de cada uma"
                    Repeater {
                        model: janela.pagina === "som" ? (janela.e.placas || []) : []
                        delegate: Linha {
                            id: lPlaca
                            required property var modelData
                            titulo: modelData.descricao
                            sub: "HDMI, analógico, estéreo, surround…"
                            icone: "audio-card"
                            Combo {
                                width: 260
                                model: lPlaca.modelData.perfis.map(p => p.descricao)
                                currentIndex: lPlaca.modelData.perfis.findIndex(p => p.nome === lPlaca.modelData.perfil)
                                onActivated: (i) => ajustes.somPerfil(lPlaca.modelData.nome, lPlaca.modelData.perfis[i].nome)
                            }
                        }
                    }
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
                    titulo: "Quando o computador fica parado"
                    Linha {
                        titulo: "Desligar o ecrã depois de"
                        sub: "Enquanto um vídeo está a tocar, o ecrã não se apaga"
                        EscolhaE { chave: "desligarEcra"; opcoes: [[0, "Nunca"], [1, "1 minuto"], [2, "2 minutos"], [5, "5 minutos"], [10, "10 minutos"], [15, "15 minutos"], [30, "30 minutos"], [60, "1 hora"]] }
                    }
                    Linha {
                        titulo: "Bloquear quando o ecrã se desliga"
                        Switch { enabled: ((janela.e.energia || {}).desligarEcra || 0) > 0; checked: !!(janela.e.energia || {}).bloquear; onToggled: ajustes.energiaMudar("bloquear", checked) }
                    }
                    Linha {
                        titulo: "Suspender depois de"
                        sub: "Não suspende durante cópias, transferências ou vídeos"
                        EscolhaE { chave: "suspender"; opcoes: [[0, "Nunca"], [15, "15 minutos"], [30, "30 minutos"], [60, "1 hora"], [120, "2 horas"], [240, "4 horas"]] }
                    }
                    Linha {
                        titulo: "Bloquear ao suspender"
                        Switch { checked: (janela.e.energia || {}).bloquearAoSuspender !== false; onToggled: ajustes.energiaMudar("bloquearAoSuspender", checked) }
                    }
                }
                Grupo {
                    visible: janela.pagina === "energia"
                    titulo: "Botão de ligar do computador"
                    Linha {
                        titulo: "Ao carregar no botão"
                        EscolhaE { chave: "botao"; opcoes: [["perguntar", "Perguntar o que fazer"], ["desligar", "Desligar"], ["suspender", "Suspender"], ["nada", "Não fazer nada"]] }
                    }
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
                             ? "Ligado: sem desfoque nas janelas, animações curtas e sem indexar o conteúdo dos arquivos."
                             : (janela.e.leve || {}).recomendado
                               ? "Recomendado para este computador (" + (janela.e.leve || {}).motivo + "). Deixa tudo mais rápido."
                               : "Para computadores mais antigos: sem desfoque, animações curtas."
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
                        Repeater {
                            model: janela.pagina === "aparencia" ? (janela.e.papeis || []) : []
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool atual: janela.e.papel === modelData.caminho
                                width: 182; height: 104; radius: 10
                                color: Qt.rgba(1, 1, 1, 0.04)
                                border.width: atual ? 3 : (mf.containsMouse ? 2 : 0)
                                border.color: janela.realce
                                Image { anchors.fill: parent; anchors.margins: 3; source: "file://" + modelData.caminho; sourceSize: Qt.size(364, 208)
                                        fillMode: Image.PreserveAspectCrop; asynchronous: true }
                                MouseArea { id: mf; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ajustes.definirFundo(modelData.caminho) }
                            }
                        }
                    }
                    Linha { titulo: "Escolher outra imagem…"; icone: "folder-pictures"; clicavel: true; onCarregado: escolherPapel.open(); Seta {} }
                }
                Grupo {
                    visible: janela.pagina === "aparencia"
                    Linha { titulo: "Luz noturna"; sub: "Cores mais quentes, para descansar a vista à noite"
                            Switch { checked: !!janela.e.luzNoturna; onToggled: ajustes.luzNoturna(checked) } }
                }

                // ===== Notificações =====
                Grupo {
                    visible: janela.pagina === "notificacoes"
                    Linha { titulo: "Não incomodar"; sub: "Os avisos não aparecem nem fazem som; ficam guardados na central de ajustes. Os urgentes aparecem sempre."
                            icone: "notifications-disabled"
                            Switch { checked: !!janela.e.naoIncomodar; onToggled: ajustes.naoIncomodar(checked) } }
                    Linha { titulo: "Mostrar um aviso de teste"; icone: "preferences-desktop-notification"; clicavel: true; onCarregado: ajustes.avisoTeste(); Seta {} }
                    Linha { titulo: "Avisos guardados"; sub: (janela.e.historico || 0) + " — veja-os e limpe-os na central de ajustes (ao lado do relógio)" }
                    Linha { titulo: "Quem mostra os avisos"; sub: janela.e.servidor ? janela.e.servidor + " (CarinaeOS)" : "Ninguém — a Aurora não está a correr?" }
                }

                // ===== Pesquisa =====
                Grupo {
                    visible: janela.pagina === "pesquisa"
                    titulo: "Índice de ficheiros"
                    Linha { titulo: "Pesquisa de ficheiros pelo nome"
                            sub: janela.e.temPlocate ? ("O Comando (Ctrl+Espaço) usa o índice do sistema" + (janela.e.atualizado ? ", atualizado em " + janela.e.atualizado : "")
                                                       + (janela.e.automatico ? ". Atualiza-se sozinho todos os dias." : "."))
                                                    : "Falta o plocate (sudo apt install plocate). Sem ele, procura-se só um pouco na pasta pessoal."
                            icone: "search" }
                    Linha { visible: !!janela.e.temPlocate; titulo: "Atualizar o índice agora"; sub: "Para encontrar logo os ficheiros novos"; clicavel: true; onCarregado: ajustes.atualizarIndice(); Seta {} }
                }
                Grupo {
                    visible: janela.pagina === "pesquisa" && !!janela.e.baloo
                    titulo: "Baloo (o indexador do KDE)"
                    Linha { titulo: "Indexar o conteúdo dos ficheiros com o Baloo"
                            sub: "Já não é usado pelo CarinaeOS. Desligado, poupa disco e processador (e apaga o índice antigo)."
                            Switch { checked: !!janela.e.balooLigado; onToggled: ajustes.definirIndexacao(checked) } }
                }

                // ===== Região e idioma =====
                Grupo {
                    visible: janela.pagina === "regiao"
                    titulo: "Idioma e formatos"
                    Linha {
                        titulo: "Idioma do sistema"
                        sub: "Menus e mensagens (vale ao entrar de novo)"
                        Combo {
                            width: 300
                            model: (janela.e.disponiveis || []).map(d => d.nome)
                            currentIndex: (janela.e.disponiveis || []).findIndex(d => d.codigo === janela.e.idioma || d.codigo.replace(".utf8", ".UTF-8") === janela.e.idioma)
                            onActivated: (i) => ajustes.regiaoDefinir(janela.e.disponiveis[i].codigo, janela.e.formatos)
                        }
                    }
                    Linha {
                        titulo: "Formatos"
                        sub: "Datas, horas, números e moeda"
                        Combo {
                            width: 300
                            model: (janela.e.disponiveis || []).map(d => d.nome)
                            currentIndex: (janela.e.disponiveis || []).findIndex(d => d.codigo === janela.e.formatos || d.codigo.replace(".utf8", ".UTF-8") === janela.e.formatos)
                            onActivated: (i) => ajustes.regiaoDefinir(janela.e.idioma, janela.e.disponiveis[i].codigo)
                        }
                    }
                }
                Grupo {
                    visible: janela.pagina === "regiao" && (janela.e.porInstalar || []).length > 0
                    titulo: "Instalar outro idioma"
                    Linha {
                        titulo: "Idioma"
                        Combo { id: novaLingua; width: 300; model: (janela.e.porInstalar || []).map(d => d.nome); displayText: currentIndex < 0 ? "Escolher…" : currentText; currentIndex: -1 }
                        Botao { texto: "Instalar"; principal: true; onCarregado: if (novaLingua.currentIndex >= 0) ajustes.regiaoInstalar(janela.e.porInstalar[novaLingua.currentIndex].codigo) }
                    }
                }

                // ===== Acessibilidade =====
                Grupo {
                    visible: janela.pagina === "acessibilidade"
                    titulo: "Ver melhor"
                    Linha { titulo: "Tamanho do texto"; sub: (janela.e.texto || 100) + "% (vale a partir do próximo início de sessão)"
                            Combo {
                                readonly property var op: [100, 110, 125, 150, 175, 200]
                                model: op.map(x => x + "%")
                                currentIndex: Math.max(0, op.indexOf(janela.e.texto || 100))
                                onActivated: (i) => ajustes.acessMudar("texto", op[i])
                            } }
                    Linha { titulo: "Tamanho do cursor"
                            Combo {
                                readonly property var op: [[24, "Normal"], [32, "Grande"], [48, "Muito grande"], [64, "Enorme"]]
                                model: op.map(x => x[1])
                                currentIndex: Math.max(0, op.findIndex(x => x[0] === (janela.e.cursor || 24)))
                                onActivated: (i) => ajustes.acessMudar("cursor", op[i][0])
                            } }
                    Linha { titulo: "Animações"; sub: "Desligue se os movimentos no ecrã o incomodarem"
                            Switch { checked: janela.e.animacoes !== false; onToggled: ajustes.acessMudar("animacoes", checked) } }
                }
                Grupo {
                    visible: janela.pagina === "acessibilidade"
                    titulo: "Teclado"
                    Linha { titulo: "Repetição das teclas, Num Lock…"; clicavel: true; onCarregado: janela.pagina = "teclado"; Seta {} }
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
                    Linha { titulo: "Bloqueio da tela…"; sub: "Energia: bloquear quando o ecrã se desliga e ao suspender"; clicavel: true; onCarregado: janela.pagina = "energia"; Seta {} }
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
                    Linha { titulo: "Acertar a data e a hora automaticamente"; sub: (janela.e.agora || "") + (janela.e.auto ? (janela.e.sincronizado ? "  ·  sincronizada pela Internet" : "  ·  à espera da Internet") : "")
                            Switch { checked: !!janela.e.auto; onToggled: ajustes.dataHora("auto", checked) } }
                    Linha {
                        visible: !janela.e.auto
                        titulo: "Mudar a data e a hora"
                        TextField { id: campoHora; width: 190; placeholderText: "2026-11-22 15:30"; color: janela.texto
                                    background: Rectangle { radius: 8; color: Qt.rgba(1, 1, 1, 0.07); border.color: janela.linha } }
                        Botao { texto: "Aplicar"; principal: true; onCarregado: ajustes.dataHora("hora", campoHora.text.length === 16 ? campoHora.text + ":00" : campoHora.text) }
                    }
                }
                Grupo {
                    visible: janela.pagina === "datahora"
                    titulo: "Fuso horário"
                    Linha {
                        titulo: janela.e.fuso || "—"
                        sub: "Escreva uma cidade para procurar (ex.: Lisboa, Sao_Paulo)"
                        icone: "preferences-system-time"
                        TextField {
                            id: procuraFuso
                            width: 220; color: janela.texto; placeholderText: "Procurar…"
                            background: Rectangle { radius: 8; color: Qt.rgba(1, 1, 1, 0.07); border.color: janela.linha }
                        }
                    }
                    Repeater {
                        model: procuraFuso.text.length < 2 ? [] : (janela.e.fusos || []).filter(f => janela.sem(f.replace(/_/g, " ")).indexOf(janela.sem(procuraFuso.text.replace(/_/g, " "))) !== -1).slice(0, 8)
                        delegate: Linha {
                            required property string modelData
                            titulo: modelData.replace(/_/g, " ")
                            clicavel: modelData !== janela.e.fuso
                            onCarregado: { ajustes.dataHora("fuso", modelData); procuraFuso.text = "" }
                            Text { visible: modelData === janela.e.fuso; text: "✓"; color: janela.realce; font.pixelSize: 16 }
                        }
                    }
                }
                Grupo {
                    visible: janela.pagina === "datahora"
                    titulo: "Com o Windows no mesmo computador"
                    Linha { titulo: "Relógio do computador em hora local"; sub: "Ligue se o Windows mostrar a hora errada depois de usar o CarinaeOS"
                            Switch { checked: !!janela.e.relogioLocal; onToggled: ajustes.dataHora("rtc", checked) } }
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
                    Linha { titulo: "Nome"; sub: janela.e.nome || ""
                            TextField { id: campoNome; width: 200; placeholderText: "Novo nome"; color: janela.texto
                                        background: Rectangle { radius: 8; color: Qt.rgba(1, 1, 1, 0.07); border.color: janela.linha } }
                            Botao { texto: "Mudar"; onCarregado: if (campoNome.text.trim()) { ajustes.mudarNome(campoNome.text.trim()); campoNome.text = "" } } }
                    Linha { titulo: "Foto"; sub: "Aparece na tela de entrada e no bloqueio"; clicavel: true; onCarregado: escolherFoto.open(); Seta {} }
                    Linha { titulo: "Mudar a senha"; clicavel: true; onCarregado: dlgSenhaConta.abrir(janela.e.usuario, true); Seta {} }
                    Linha { titulo: "Entrar sem pedir a senha"; sub: "Liga logo ao CarinaeOS quando o computador arranca"
                            Switch { checked: !!janela.e.entradaAuto; onToggled: ajustes.entradaAutomatica(checked) } }
                }
                Grupo {
                    visible: janela.pagina === "utilizadores"
                    titulo: "Outras contas neste computador"
                    Repeater {
                        model: janela.pagina === "utilizadores" ? (janela.e.contas || []).filter(c => !c.eu) : []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.nome
                            sub: modelData.convidado ? "Sessão sem rastro (sem senha, apaga tudo ao sair)" : modelData.utilizador + (modelData.admin ? "  ·  administrador" : "  ·  normal")
                            icone: modelData.convidado ? "user-identity" : "system-users"
                            Botao { visible: !modelData.convidado && !!janela.e.euAdmin; texto: modelData.admin ? "Tirar de admin" : "Tornar admin"
                                    onCarregado: ajustes.mudarAdmin(modelData.utilizador, !modelData.admin) }
                            Botao { visible: !modelData.convidado && !!janela.e.euAdmin; texto: "Senha"; onCarregado: dlgSenhaConta.abrir(modelData.utilizador, false) }
                            Botao { visible: !modelData.convidado && !!janela.e.euAdmin; texto: "Apagar"; onCarregado: { dlgApagarConta.conta = modelData; dlgApagarConta.open() } }
                        }
                    }
                    Linha { visible: !!janela.e.euAdmin; titulo: "Adicionar uma conta…"; icone: "list-add"; clicavel: true; onCarregado: dlgNovaConta.open(); Seta {} }
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

                // ===== Aplicativos (como o "Aplicativos instalados" do Windows) =====
                Grupo {
                    visible: janela.pagina === "aplicativos"
                    Linha { titulo: "Aplicativos padrão"; sub: "Navegador, e-mail, música… e com que aplicativo abrir cada tipo de arquivo"
                            clicavel: true; onCarregado: janela.padroesAberto = !janela.padroesAberto
                            Text { text: janela.padroesAberto ? "⌄" : "›"; color: janela.suave; font.pixelSize: 20 } }
                    Linha { titulo: "Instalar mais aplicativos"; sub: "Órbita"; clicavel: true; onCarregado: ajustes.abrir("carinaeos-orbita"); Seta {} }
                }
                Grupo {
                    visible: janela.pagina === "aplicativos" && janela.padroesAberto
                    titulo: "Aplicativos padrão"
                    Repeater {
                        model: janela.pagina === "aplicativos" ? (janela.e.padroes || []) : []
                        delegate: Linha {
                            id: lp
                            required property var modelData
                            titulo: modelData.nome
                            sub: modelData.atual ? modelData.atual.nome : "Nenhum escolhido"
                            icone: modelData.atual ? modelData.atual.icone : modelData.icone
                            Combo {
                                width: 240
                                model: lp.modelData.opcoes.map(o => o.nome)
                                currentIndex: lp.modelData.atual ? lp.modelData.opcoes.findIndex(o => o.id === lp.modelData.atual.id) : -1
                                displayText: currentIndex < 0 ? "Escolher…" : currentText
                                onActivated: (i) => ajustes.definirPadrao(lp.modelData.chave, lp.modelData.opcoes[i].id)
                            }
                        }
                    }
                    Linha {
                        titulo: "Por tipo de ficheiro"
                        sub: janela.tipoVisto.mime ? (janela.tipoVisto.descricao + "  (." + janela.tipoVisto.extensao + ")") : "Escreva a extensão: pdf, mp3, docx, png…"
                        TextField {
                            width: 130; color: janela.texto; placeholderText: ".extensão"
                            background: Rectangle { radius: 8; color: Qt.rgba(1, 1, 1, 0.07); border.color: janela.linha }
                            onAccepted: ajustes.procurarTipo(text)
                            onTextEdited: if (text.length >= 2) ajustes.procurarTipo(text)
                        }
                        Combo {
                            visible: !!janela.tipoVisto.mime
                            width: 220
                            model: (janela.tipoVisto.opcoes || []).map(o => o.nome)
                            currentIndex: janela.tipoVisto.atual ? (janela.tipoVisto.opcoes || []).findIndex(o => o.id === janela.tipoVisto.atual.id) : -1
                            displayText: currentIndex < 0 ? ((janela.tipoVisto.opcoes || []).length ? "Escolher…" : "Nenhum programa") : currentText
                            onActivated: (i) => ajustes.definirPadraoMime(janela.tipoVisto.mime, janela.tipoVisto.opcoes[i].id)
                        }
                    }
                }
                RowLayout {
                    visible: janela.pagina === "aplicativos"
                    Layout.fillWidth: true; spacing: 8
                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 8; color: Qt.rgba(1, 1, 1, 0.07)
                        Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: janela.suave; font.pixelSize: 16 }
                        TextField {
                            x: 30; width: parent.width - 36; anchors.verticalCenter: parent.verticalCenter
                            background: Item {}
                            color: janela.texto; font.pixelSize: 13
                            placeholderText: "Procurar aplicativo"; placeholderTextColor: janela.suave
                            text: janela.procuraApps; onTextEdited: janela.procuraApps = text
                        }
                    }
                    Repeater {
                        model: [["nome", "Nome"], ["tamanho", "Tamanho"], ["data", "Data"]]
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: to.implicitWidth + 24; height: 32; radius: 16
                            color: janela.ordemApps === modelData[0] ? Qt.rgba(0.48, 0.65, 1, 0.22) : Qt.rgba(1, 1, 1, 0.07)
                            Text { id: to; anchors.centerIn: parent; text: modelData[1]; color: janela.ordemApps === modelData[0] ? janela.realce : janela.texto; font.pixelSize: 12; font.weight: Font.DemiBold }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: janela.ordemApps = modelData[0] }
                        }
                    }
                }
                Flow {
                    visible: janela.pagina === "aplicativos"
                    Layout.fillWidth: true; spacing: 6
                    Repeater {
                        model: [["", "Todos"], ["Flathub", "Flathub"], ["Debian", "Debian"], ["AppImage", "AppImage"], ["Aplicativo", "Apps"], ["Windows", "Windows"]]
                        delegate: Rectangle {
                            required property var modelData
                            readonly property int n: modelData[0] === "" ? (janela.e.apps || []).length : (janela.e.apps || []).filter(a => a.origem === modelData[0]).length
                            visible: modelData[0] === "" || n > 0
                            width: tf.implicitWidth + 24; height: 28; radius: 14
                            color: janela.origemApps === modelData[0] ? Qt.rgba(0.48, 0.65, 1, 0.22) : "transparent"
                            border.width: 1; border.color: janela.origemApps === modelData[0] ? janela.realce : janela.linha
                            Text { id: tf; anchors.centerIn: parent; text: modelData[1] + "  " + n; color: janela.origemApps === modelData[0] ? janela.realce : janela.suave; font.pixelSize: 12 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: janela.origemApps = modelData[0] }
                        }
                    }
                }
                Grupo {
                    visible: janela.pagina === "aplicativos"
                    titulo: janela.e.apps === undefined ? "Procurando os aplicativos…"
                          : janela.appsFiltrados.length + (janela.appsFiltrados.length === 1 ? " aplicativo" : " aplicativos")
                            + " · " + janela.tamanho(janela.appsFiltrados.reduce((t, a) => t + a.tamanho, 0))
                    Repeater {
                        model: janela.pagina === "aplicativos" ? janela.appsFiltrados : []
                        delegate: Linha {
                            id: la
                            required property var modelData
                            titulo: modelData.nome
                            icone: modelData.icone || "application-x-executable"
                            sub: [janela.origemNome(modelData.origem), modelData.versao ? "versão " + modelData.versao.replace(/^\d+:/, "").split(/[-+~]/)[0] : "",
                                  janela.tamanho(modelData.tamanho), modelData.data ? "instalado em " + new Date(modelData.data * 1000).toLocaleDateString(Qt.locale("pt_BR"), "dd/MM/yyyy") : ""]
                                 .filter(x => x).join(" · ")
                            Text { visible: !la.modelData.removivel; anchors.verticalCenter: parent.verticalCenter; text: "Do sistema"; color: janela.suave; font.pixelSize: 12 }
                            Botao {
                                visible: la.modelData.removivel
                                texto: ajustes.aRemover === la.modelData.id ? "Desinstalando…" : "Desinstalar"
                                onCarregado: if (ajustes.aRemover === "") { dlgDesinstalar.app = la.modelData; ajustes.previaApp(la.modelData.id); dlgDesinstalar.open() }
                            }
                        }
                    }
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
                        height: gradeModelos.implicitHeight + 28
                        Flow {
                            id: gradeModelos
                            x: 14; y: 14; width: parent.width - 28
                            spacing: 12
                            Repeater {
                                model: [
                                    ["fluent", "Padrão", "Holofote que desliza"],
                                    ["simples", "Sem efeitos", "O ícone só acende ao passar o mouse"],
                                    ["icones", "Só ícones", "Sem fundo; ondas como um sonar"],
                                    ["orbita", "Órbita", "Um anel gira à volta do ícone"],
                                    ["glass", "Vidro", "O ícone inclina para o mouse"],
                                    ["windows", "Windows 11", "Barra inteira, como no Windows"]
                                ]
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
                                        source: janela.e.pastaEstilos ? "file://" + janela.e.pastaEstilos + "/" + cartaoModelo.modelData[0] + ".png" : ""
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
                    }
                }
                Grupo {
                    visible: janela.pagina === "dock" && janela.e.estilo !== "windows"
                    titulo: "Animação ao passar o mouse"
                    Item {
                        width: parent.width; height: 64
                        Flow {
                            x: 14; width: parent.width - 28
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Repeater {
                                model: [["", "A do modelo"], ["luz", "Holofote"], ["orbita", "Órbita"], ["onda", "Ondas"], ["inclinar", "Inclinação 3D"], ["nenhuma", "Nenhuma"]]
                                delegate: Botao {
                                    required property var modelData
                                    texto: modelData[1]
                                    principal: (janela.e.animacao || "") === modelData[0]
                                    onCarregado: ajustes.definirModeloDock("animacao", modelData[0])
                                }
                            }
                        }
                    }
                }
                Grupo {
                    visible: janela.pagina === "dock"
                    titulo: "Tamanho"
                    Linha { titulo: "Tamanho dos ícones"; sub: Math.round(janela.e.iconSize || 56) + " px"
                            Deslizante { from: 32; to: 96; stepSize: 2; alvo: janela.e.iconSize || 56; onMoved: ajustes.definirDock("iconSize", Math.round(value)) } }
                }
                Grupo {
                    visible: janela.pagina === "dock" && !janela.e.carinae
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

                // ===== Teclado =====
                Grupo {
                    visible: janela.pagina === "teclado"
                    titulo: "Disposições do teclado"
                    Repeater {
                        model: janela.pagina === "teclado" ? (janela.e.ativas || []) : []
                        delegate: Linha {
                            required property var modelData
                            required property int index
                            titulo: modelData.nome
                            sub: index === 0 ? "Principal" : "Alternativa"
                            icone: "preferences-desktop-keyboard"
                            Botao { visible: index > 0; texto: "Tornar principal"; onCarregado: ajustes.tecladoDisposicao("primeira", modelData.codigo, modelData.variante) }
                            Botao { visible: (janela.e.ativas || []).length > 1; texto: "Tirar"; onCarregado: ajustes.tecladoDisposicao("tirar", modelData.codigo, modelData.variante) }
                        }
                    }
                    Linha {
                        titulo: "Juntar outra disposição"
                        TextField {
                            id: procuraTec
                            width: 240; color: janela.texto; placeholderText: "Procurar (ex.: Brasil, Inglês)…"
                            background: Rectangle { radius: 8; color: Qt.rgba(1, 1, 1, 0.07); border.color: janela.linha }
                        }
                    }
                    Repeater {
                        model: {
                            if (procuraTec.text.length < 2) return [];
                            const p = janela.sem(procuraTec.text), saida = [];
                            for (const d of (janela.e.todas || [])) {
                                if (janela.sem(d.nome + " " + d.codigo).indexOf(p) !== -1) saida.push({ codigo: d.codigo, variante: "", nome: d.nome });
                                for (const v of ((janela.e.variantesDe || {})[d.codigo] || []))
                                    if (janela.sem(v.nome + " " + d.nome).indexOf(p) !== -1) saida.push({ codigo: d.codigo, variante: v.codigo, nome: d.nome + " — " + v.nome });
                                if (saida.length > 10) break;
                            }
                            return saida.slice(0, 10);
                        }
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.nome
                            clicavel: true
                            onCarregado: { ajustes.tecladoDisposicao("juntar", modelData.codigo, modelData.variante); procuraTec.text = "" }
                            Text { text: "+"; color: janela.realce; font.pixelSize: 18 }
                        }
                    }
                    Linha {
                        visible: (janela.e.ativas || []).length > 1
                        titulo: "Trocar de disposição com"
                        Combo {
                            readonly property var op: [["grp:alt_shift_toggle", "Alt + Shift"], ["grp:win_space_toggle", "Super + Espaço"], ["grp:ctrl_shift_toggle", "Ctrl + Shift"], ["grp:caps_toggle", "Caps Lock"], ["", "Nenhum atalho"]]
                            model: op.map(o => o[1])
                            currentIndex: Math.max(0, op.findIndex(o => o[0] === janela.e.trocar))
                            onActivated: (i) => ajustes.tecladoMudar("trocar", op[i][0])
                        }
                    }
                }
                Grupo {
                    visible: janela.pagina === "teclado"
                    titulo: "Teclas"
                    Linha { titulo: "Ligar o Num Lock ao entrar"
                            Switch { checked: !!janela.e.numlock; onToggled: ajustes.tecladoMudar("numlock", checked) } }
                    Linha { titulo: "Caps Lock funciona como Ctrl"; sub: "Para quem escreve muito com atalhos"
                            Switch { checked: !!janela.e.capsCtrl; onToggled: ajustes.tecladoMudar("capsCtrl", checked) } }
                    Linha { titulo: "Espera até repetir uma tecla"; sub: (janela.e.atraso || 600) + " ms"
                            Deslizante { from: 150; to: 1000; alvo: janela.e.atraso || 600; onMoved: ajustes.tecladoMudar("atraso", Math.round(value)) } }
                    Linha { titulo: "Velocidade da repetição"; sub: (janela.e.ritmo || 25) + " por segundo"
                            Deslizante { from: 5; to: 60; alvo: janela.e.ritmo || 25; onMoved: ajustes.tecladoMudar("ritmo", Math.round(value)) } }
                    Item {
                        width: parent.width; height: 60
                        TextField { x: 16; y: 12; width: parent.width - 32; placeholderText: "Experimente aqui o teclado…"; color: janela.texto
                                    background: Rectangle { radius: 8; color: Qt.rgba(1, 1, 1, 0.07); border.color: janela.linha } }
                    }
                }
                Grupo {
                    visible: janela.pagina === "teclado"
                    Linha { titulo: "Atalhos de teclado"; sub: "~/.config/carinaeos/atalhos.conf (Super = Lançador, Ctrl+Espaço = Comando, Print = Captura…)"
                            icone: "preferences-desktop-keyboard-shortcuts"; clicavel: true
                            onCarregado: ajustes.abrir("xdg-open \"$HOME/.config/carinaeos/atalhos.conf\""); Seta {} }
                }

                // ===== Rato e touchpad =====
                Grupo {
                    visible: janela.pagina === "rato"
                    titulo: "Rato"
                    Linha { titulo: "Velocidade do ponteiro"
                            Deslizante { from: -1; to: 1; alvo: janela.e.velocidade || 0; onMoved: ajustes.ratoMudar("velocidade", value) } }
                    Linha { titulo: "Aceleração"; sub: "O ponteiro vai mais longe quando mexe o rato depressa (desligue para jogos)"
                            Switch { checked: janela.e.aceleracao !== false; onToggled: ajustes.ratoMudar("aceleracao", checked) } }
                    Linha { titulo: "Rolagem natural"; sub: "O conteúdo segue o dedo, como num telemóvel"
                            Switch { checked: !!janela.e.natural; onToggled: ajustes.ratoMudar("natural", checked) } }
                    Linha { titulo: "Botão principal à direita"; sub: "Para canhotos"
                            Switch { checked: !!janela.e.canhoto; onToggled: ajustes.ratoMudar("canhoto", checked) } }
                }
                Grupo {
                    visible: janela.pagina === "rato" && !!janela.e.temTouchpad
                    titulo: "Touchpad"
                    Linha { titulo: "Velocidade"
                            Deslizante { from: -1; to: 1; alvo: janela.e.tpVelocidade || 0; onMoved: ajustes.ratoMudar("tpVelocidade", value) } }
                    Linha { titulo: "Tocar para clicar"
                            Switch { checked: janela.e.tpTocar !== false; onToggled: ajustes.ratoMudar("tpTocar", checked) } }
                    Linha { titulo: "Rolagem natural"
                            Switch { checked: janela.e.tpNatural !== false; onToggled: ajustes.ratoMudar("tpNatural", checked) } }
                    Linha { titulo: "Desligar enquanto escreve"
                            Switch { checked: janela.e.tpDesligarAoEscrever !== false; onToggled: ajustes.ratoMudar("tpDesligarAoEscrever", checked) } }
                }
                Grupo {
                    visible: janela.pagina === "rato"
                    titulo: "Aparelhos ligados"
                    Repeater { model: janela.pagina === "rato" ? (janela.e.aparelhos || []) : []
                               delegate: Linha { required property var modelData; titulo: modelData.nome; sub: modelData.touchpad ? "Touchpad" : "Rato"
                                                 icone: modelData.touchpad ? "input-touchpad" : "input-mouse" } }
                }

                // ===== Impressoras =====
                Grupo {
                    visible: janela.pagina === "impressoras"
                    titulo: "Impressoras"
                    Repeater {
                        model: janela.pagina === "impressoras" ? (janela.e.impressoras || []) : []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.nome.replace(/_/g, " ")
                            sub: (modelData.padrao ? "Predefinida  ·  " : "") + (modelData.parada ? "Parada" : "Pronta")
                                 + (modelData.trabalhos ? "  ·  " + modelData.trabalhos + " na fila" : "")
                            icone: "printer"
                            Botao { visible: !modelData.padrao; texto: "Predefinir"; onCarregado: ajustes.impressoraAcao("padrao", modelData.nome) }
                            Botao { texto: "Página de teste"; onCarregado: ajustes.impressoraAcao("teste", modelData.nome) }
                            Botao { visible: modelData.trabalhos > 0; texto: "Cancelar fila"; onCarregado: ajustes.impressoraAcao("cancelar", modelData.nome) }
                            Botao { visible: modelData.parada; texto: "Retomar"; principal: true; onCarregado: ajustes.impressoraAcao("retomar", modelData.nome) }
                            Botao { texto: "Remover"; onCarregado: ajustes.impressoraAcao("remover", modelData.nome) }
                        }
                    }
                    Linha { visible: (janela.e.impressoras || []).length === 0; titulo: "Ainda não há impressoras" }
                }
                Grupo {
                    visible: janela.pagina === "impressoras"
                    titulo: "Adicionar uma impressora"
                    Linha { titulo: "Procurar impressoras"; sub: "Na rede (Wi-Fi ou cabo) e ligadas por USB"; icone: "view-refresh"
                            clicavel: true; onCarregado: ajustes.impressorasProcurar(); Seta {} }
                    Repeater {
                        model: janela.pagina === "impressoras" ? (janela.e.descobertas || []) : []
                        delegate: Linha {
                            required property var modelData
                            titulo: modelData.nome
                            sub: modelData.uri
                            icone: "printer-network"
                            Botao { texto: "Adicionar"; principal: true; onCarregado: ajustes.impressoraJuntar(modelData.uri, modelData.nome) }
                        }
                    }
                    Linha { titulo: "Opções avançadas (página do CUPS)"; sub: "http://localhost:631 — controladores, partilha, opções de papel"
                            icone: "preferences-other"; clicavel: true; onCarregado: Qt.openUrlExternally("http://localhost:631/printers/"); Seta {} }
                }

                // ===== secções que abrem o módulo completo =====
                Grupo {
                    visible: false
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
                    visible: janela.seccao.completo
                    Layout.alignment: Qt.AlignHCenter
                    texto: "Mais opções…"
                    onCarregado: ajustes.completo(janela.pagina)
                }
                Item { Layout.preferredHeight: 40 }
            }
        }
    }

    // desinstalar um aplicativo (confirmação, como no Windows)
    Popup {
        id: dlgDesinstalar
        objectName: "dlgDesinstalar"
        property var app: ({})
        readonly property var pv: ajustes.previa.ident === app.id ? ajustes.previa : ({ aCarregar: true })
        readonly property bool pode: !pv.aCarregar && !!pv.pode
        anchors.centerIn: parent
        modal: true; width: 460; padding: 24
        onOpened: apagarDados.ligado = false
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.5) }
        background: Rectangle { radius: 16; color: "#2d2b35"; border.color: janela.linha }
        contentItem: ColumnLayout {
            spacing: 14
            RowLayout {
                spacing: 14
                Image { source: "image://icone/" + (dlgDesinstalar.app.icone || "application-x-executable"); Layout.preferredWidth: 48; Layout.preferredHeight: 48; sourceSize: Qt.size(96, 96) }
                Text { Layout.fillWidth: true; text: "Desinstalar " + (dlgDesinstalar.app.nome || "") + "?"; color: janela.texto; font.pixelSize: 18; font.weight: Font.DemiBold; wrapMode: Text.WordWrap }
            }
            Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; color: dlgDesinstalar.pv.aCarregar || dlgDesinstalar.pode ? janela.texto : "#ff9db0"; font.pixelSize: 13
                   text: dlgDesinstalar.pv.aCarregar ? "Verificando…" : dlgDesinstalar.pode ? "Este aplicativo e suas informações serão desinstalados." : (dlgDesinstalar.pv.mensagem || "") }
            Text { visible: dlgDesinstalar.pode && (dlgDesinstalar.pv.mensagem || "") !== ""; Layout.fillWidth: true; wrapMode: Text.WordWrap
                   text: dlgDesinstalar.pv.mensagem || ""; color: janela.suave; font.pixelSize: 12 }
            Text { visible: dlgDesinstalar.pode && dlgDesinstalar.app.origem === "Debian"; Layout.fillWidth: true; wrapMode: Text.WordWrap
                   text: "Vai ser pedida a sua senha."; color: janela.suave; font.pixelSize: 12 }
            RowLayout {
                visible: !!dlgDesinstalar.pv.dados; spacing: 10
                Switch { id: apagarDados; property bool ligado: false; checked: ligado; onToggled: ligado = checked }
                Text { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Apagar também os dados e as configurações do aplicativo"; color: janela.texto; font.pixelSize: 13 }
            }
            RowLayout {
                Layout.alignment: Qt.AlignRight; spacing: 8
                Botao { texto: "Cancelar"; onCarregado: dlgDesinstalar.close() }
                Botao { visible: dlgDesinstalar.pode; texto: "Desinstalar"; principal: true
                        onCarregado: { ajustes.desinstalarApp(dlgDesinstalar.app.id, apagarDados.ligado); dlgDesinstalar.close() } }
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

    // senha do Wi-Fi (e rede oculta)
    Dialog {
        id: senhaWifi
        property string ssid: ""
        property bool oculta: false
        function abrir(nome, oc) { ssid = nome; oculta = oc; open() }
        anchors.centerIn: parent
        modal: true
        title: oculta ? "Ligar a uma rede oculta" : "Ligar a " + ssid
        standardButtons: Dialog.Cancel | Dialog.Ok
        onOpened: { campoSsid.text = ""; campoSenha.text = ""; if (oculta) campoSsid.forceActiveFocus(); else campoSenha.forceActiveFocus(); }
        onAccepted: ajustes.ligarWifiNova(oculta ? campoSsid.text : ssid, campoSenha.text, oculta)
        ColumnLayout {
            Text { visible: senhaWifi.oculta; text: "Nome da rede (SSID)"; color: janela.texto }
            TextField { id: campoSsid; visible: senhaWifi.oculta; Layout.preferredWidth: 280 }
            Text { text: "Senha da rede" + (senhaWifi.oculta ? " (vazia se for aberta)" : ""); color: janela.texto }
            TextField { id: campoSenha; echoMode: mostrarSenha.checked ? TextInput.Normal : TextInput.Password; Layout.preferredWidth: 280; onAccepted: senhaWifi.accept() }
            CheckBox { id: mostrarSenha; text: "Mostrar a senha" }
        }
    }
    Connections {
        target: ajustes
        function onPedeSenhaWifi(ssid, errada) { senhaWifi.abrir(ssid, false) }
        function onSenhaWifiVista(uuid, senha) { senhaVista.senha = senha; senhaVista.open() }
    }
    Dialog {
        id: senhaVista
        property string senha: ""
        anchors.centerIn: parent
        modal: true
        title: "Senha da rede"
        standardButtons: Dialog.Close
        ColumnLayout {
            TextField { text: senhaVista.senha; readOnly: true; selectByMouse: true; Layout.preferredWidth: 280; font.pixelSize: 16 }
            Text { text: "Pode copiá-la para ligar outro aparelho."; color: janela.suave }
        }
    }

    // IP e DNS de uma ligação
    Dialog {
        id: dlgIp
        property var lig: ({})
        function abrir(l) {
            lig = l;
            manual.checked = l.metodo === "manual";
            campoIp.text = (l.enderecos || "").split(",")[0];
            campoGw.text = l.gateway || "";
            campoDns.text = l.dnsManual || "";
            open();
        }
        anchors.centerIn: parent
        modal: true
        title: "IP e DNS — " + (lig.nome || "")
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: ajustes.configurarIp(lig.uuid, manual.checked ? "manual" : "auto", campoIp.text, campoGw.text, campoDns.text)
        ColumnLayout {
            spacing: 8
            RadioButton { text: "Automático (DHCP) — o router escolhe"; checked: !manual.checked }
            RadioButton { id: manual; text: "Manual — IP fixo" }
            GridLayout {
                columns: 2; enabled: manual.checked; opacity: enabled ? 1 : 0.5
                Text { text: "Endereço IP"; color: janela.texto }
                TextField { id: campoIp; placeholderText: "192.168.1.50/24"; Layout.preferredWidth: 220 }
                Text { text: "Router (gateway)"; color: janela.texto }
                TextField { id: campoGw; placeholderText: "192.168.1.1"; Layout.preferredWidth: 220 }
            }
            Text { text: "DNS (vazio = o do router)"; color: janela.texto }
            TextField { id: campoDns; placeholderText: "ex.: 1.1.1.1 9.9.9.9"; Layout.preferredWidth: 320 }
            Text { text: "Vai ser pedida a sua senha. A ligação desliga-se e volta por um instante."; color: janela.suave; font.pixelSize: 12 }
        }
    }
    FileDialog {
        id: escolherVpn
        title: "Escolher o ficheiro da VPN"
        nameFilters: ["VPN (*.ovpn *.conf)", "Todos os ficheiros (*)"]
        onAccepted: ajustes.importarVpn(selectedFile.toString())
    }
    // ---- contas ---------------------------------------------------------------------------------------
    FileDialog {
        id: escolherPapel
        title: "Escolher o papel de parede"
        nameFilters: ["Imagens (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: ajustes.definirFundo(selectedFile.toString())
    }
    FileDialog {
        id: escolherFoto
        title: "Escolher a foto"
        nameFilters: ["Imagens (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: ajustes.mudarFoto(selectedFile.toString())
    }
    Dialog {
        id: dlgSenhaConta
        property string conta: ""
        property bool propria: true
        function abrir(c, p) { conta = c; propria = p; s1.text = ""; s2.text = ""; open(); s1.forceActiveFocus() }
        anchors.centerIn: parent
        modal: true
        title: propria ? "Mudar a sua senha" : "Nova senha para " + conta
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: if (s1.text.length >= 4 && s1.text === s2.text) ajustes.mudarSenha(conta, s1.text)
        ColumnLayout {
            TextField { id: s1; echoMode: TextInput.Password; placeholderText: "Nova senha"; Layout.preferredWidth: 300 }
            TextField { id: s2; echoMode: TextInput.Password; placeholderText: "Repita a nova senha"; Layout.preferredWidth: 300; onAccepted: dlgSenhaConta.accept() }
            Text { visible: s2.text.length > 0 && s1.text !== s2.text; text: "As senhas não são iguais."; color: "#ff7a9a" }
            Text { text: "Vai ser pedida a senha de administrador."; color: janela.suave; font.pixelSize: 12 }
        }
    }
    Dialog {
        id: dlgNovaConta
        anchors.centerIn: parent
        modal: true
        title: "Nova conta"
        standardButtons: Dialog.Cancel | Dialog.Ok
        onOpened: { ncNome.text = ""; ncUser.text = ""; ncS1.text = ""; ncS2.text = ""; ncAdmin.checked = false; ncNome.forceActiveFocus() }
        onAccepted: if (ncUser.text && ncS1.text.length >= 4 && ncS1.text === ncS2.text) ajustes.novaConta(ncUser.text, ncNome.text || ncUser.text, ncS1.text, ncAdmin.checked)
        ColumnLayout {
            TextField { id: ncNome; placeholderText: "Nome (ex.: Ana Silva)"; Layout.preferredWidth: 300
                        onTextEdited: ncUser.text = janela.sem(text.split(" ")[0]).replace(/[^a-z0-9]/g, "") }
            TextField { id: ncUser; placeholderText: "Nome de utilizador (ex.: ana)"; Layout.preferredWidth: 300 }
            TextField { id: ncS1; echoMode: TextInput.Password; placeholderText: "Senha"; Layout.preferredWidth: 300 }
            TextField { id: ncS2; echoMode: TextInput.Password; placeholderText: "Repita a senha"; Layout.preferredWidth: 300 }
            CheckBox { id: ncAdmin; text: "Administrador (pode instalar programas e mudar o sistema)" }
        }
    }
    Dialog {
        id: dlgApagarConta
        property var conta: ({})
        anchors.centerIn: parent
        modal: true
        title: "Apagar a conta de " + (conta.nome || "")
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: ajustes.apagarConta(conta.utilizador, apagarFich.checked)
        ColumnLayout {
            CheckBox { id: apagarFich; text: "Apagar também os ficheiros dela (Documentos, Imagens…)" }
            Text { text: "Não dá para desfazer."; color: "#ff7a9a" }
        }
    }
}
