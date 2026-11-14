// CarinaeOS - Configuracao inicial (como a do Fedora): uma pagina de cada vez, com
// "Anterior" e "Seguinte" na barra de cima, e no fim "Comecar a usar o CarinaeOS".
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: janela
    width: 960
    height: 680
    minimumWidth: 760
    minimumHeight: 560
    visible: true
    title: "Configuração inicial"
    color: "#1e1d24"

    readonly property color cartao: "#2d2b35"
    readonly property color texto: "#f2f0f6"
    readonly property color suave: "#a8a3b6"
    readonly property color realce: "#7aa7ff"
    readonly property color linha: Qt.rgba(1, 1, 1, 0.07)
    readonly property var paginas: ["boasvindas", "wifi", "privacidade", "aparencia", "contas", "pronto"]
    readonly property var titulos: ["Boas-vindas", "Wi-Fi", "Privacidade", "Aparência", "Contas online", "Tudo pronto"]
    property int pagina: 0
    readonly property string atual: paginas[pagina]
    readonly property var e: ajustes.estado
    property bool localizacao: true
    property bool relatorios: false

    onAtualChanged: {
        if (atual === "wifi") ajustes.ler("wifi");
        if (atual === "aparencia") ajustes.ler("aparencia");
    }
    function seguinte() {
        if (atual === "privacidade") bv.privacidade(localizacao, relatorios);
        if (pagina < paginas.length - 1) pagina++;
        else { bv.concluir(); Qt.quit(); }
    }

    // ---- barra de cima, como no GNOME: Anterior · título · Seguinte -----------------------------------
    header: Rectangle {
        height: 52
        color: "#25232c"
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: janela.linha }
        Rectangle {
            visible: janela.pagina > 0 && janela.atual !== "pronto"
            x: 12; anchors.verticalCenter: parent.verticalCenter
            width: ta.implicitWidth + 26; height: 34; radius: 8
            color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08)
            Text { id: ta; anchors.centerIn: parent; text: "Anterior"; color: janela.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: janela.pagina-- }
        }
        Text { anchors.centerIn: parent; text: janela.titulos[janela.pagina]; color: janela.texto; font.pixelSize: 15; font.weight: Font.DemiBold }
        Rectangle {
            visible: janela.atual !== "pronto"
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            width: ts.implicitWidth + 26; height: 34; radius: 8
            color: ms.containsMouse ? Qt.lighter(janela.realce, 1.08) : janela.realce
            Text { id: ts; anchors.centerIn: parent; text: janela.atual === "wifi" && !(janela.e.redes || []).some(r => r.ligada) ? "Ignorar" : "Seguinte"; color: "#0b1530"; font.pixelSize: 13; font.weight: Font.DemiBold }
            MouseArea { id: ms; anchors.fill: parent; hoverEnabled: true; onClicked: janela.seguinte() }
        }
    }

    component Grupo: Rectangle {
        default property alias linhas: col.data
        Layout.fillWidth: true
        implicitHeight: col.implicitHeight
        radius: 12
        color: janela.cartao
        border.width: 1
        border.color: janela.linha
        clip: true
        Column { id: col; width: parent.width }
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
        height: Math.max(58, cols.implicitHeight + 22)
        color: clicavel && ml.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
        Rectangle { anchors.bottom: parent.bottom; x: 16; width: parent.width - 32; height: 1; color: janela.linha }
        Image { id: ic; visible: lin.icone !== ""; x: 16; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; sourceSize: Qt.size(48, 48); source: lin.icone !== "" ? "image://icone/" + lin.icone : "" }
        Column {
            id: cols
            anchors.left: ic.visible ? ic.right : parent.left; anchors.leftMargin: ic.visible ? 14 : 16
            anchors.right: dir.left; anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            Text { width: parent.width; text: lin.titulo; color: janela.texto; font.pixelSize: 14; elide: Text.ElideRight }
            Text { visible: lin.sub !== ""; width: parent.width; text: lin.sub; color: janela.suave; font.pixelSize: 12; wrapMode: Text.WordWrap }
        }
        Row { id: dir; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 8 }
        MouseArea { id: ml; anchors.fill: parent; z: -1; enabled: lin.clicavel; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: lin.carregado() }
    }

    ScrollView {
        id: rolar
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: Math.min(rolar.availableWidth - 64, 600)
            x: (rolar.availableWidth - width) / 2
            spacing: 18

            Item { Layout.preferredHeight: 26 }

            // ===== 1. boas-vindas =====
            ColumnLayout {
                visible: janela.atual === "boasvindas"
                spacing: 16
                Layout.fillWidth: true
                Item { Layout.preferredHeight: 30 }
                Image { Layout.alignment: Qt.AlignHCenter; source: "image://icone/carinaeos"; sourceSize: Qt.size(280, 280); Layout.preferredWidth: 140; Layout.preferredHeight: 140 }
                Text { Layout.alignment: Qt.AlignHCenter; text: "Bem-vindo ao CarinaeOS"; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold }
                Text {
                    Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                    text: "Em poucos passos deixamos o computador pronto: internet, privacidade, aparência e as suas contas. Pode mudar tudo mais tarde em Configurações."
                    color: janela.suave; font.pixelSize: 15; lineHeight: 1.2
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 14
                    width: tc.implicitWidth + 40; height: 42; radius: 10
                    color: mc.containsMouse ? Qt.lighter(janela.realce, 1.08) : janela.realce
                    Text { id: tc; anchors.centerIn: parent; text: "Começar a configuração"; color: "#0b1530"; font.pixelSize: 15; font.weight: Font.DemiBold }
                    MouseArea { id: mc; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: janela.seguinte() }
                }
            }

            // ===== 2. Wi-Fi =====
            Text {
                visible: janela.atual === "wifi"
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                text: "Ligar-se à internet permite instalar atualizações, acertar o relógio e usar as contas online. Se não tiver uma rede agora, pode ignorar."
                color: janela.suave; font.pixelSize: 14
            }
            Grupo {
                visible: janela.atual === "wifi"
                Repeater {
                    model: janela.e.redes || []
                    delegate: Linha {
                        required property var modelData
                        titulo: modelData.ssid
                        sub: modelData.ligada ? "Ligada ✓" : (modelData.segura ? "Protegida com senha" : "Aberta")
                        icone: modelData.sinal > 66 ? "network-wireless-signal-excellent" : modelData.sinal > 33 ? "network-wireless-signal-good" : "network-wireless-signal-weak"
                        clicavel: !modelData.ligada
                        onCarregado: { senha.ssid = modelData.ssid; senha.segura = modelData.segura; senha.open(); }
                    }
                }
                Linha {
                    visible: (janela.e.redes || []).length === 0
                    titulo: (janela.e.ligacoes || []).length > 0 ? "Já está ligado à internet por cabo ✓" : "A procurar redes…"
                    sub: (janela.e.ligacoes || []).length > 0 ? "Pode seguir para o passo seguinte." : "Se não aparecer nenhuma, confirme que o Wi-Fi está ligado."
                }
            }
            Text { visible: janela.atual === "wifi" && ajustes.mensagem !== ""; Layout.alignment: Qt.AlignHCenter; text: ajustes.mensagem; color: janela.realce; font.pixelSize: 13 }

            // ===== 3. privacidade =====
            Grupo {
                visible: janela.atual === "privacidade"
                Linha {
                    titulo: "Serviços de localização"; icone: "find-location"
                    sub: "Os aplicativos que pedirem podem saber onde está, por exemplo para o tempo e para a luz noturna. Pode mudar isto quando quiser."
                    Switch { checked: janela.localizacao; onToggled: janela.localizacao = checked }
                }
                Linha {
                    titulo: "Relatórios de falhas"; icone: "tools-report-bug"
                    sub: "Quando um aplicativo fecha de repente, oferecer-se para enviar um relatório anónimo para ajudar a corrigir o problema."
                    Switch { checked: janela.relatorios; onToggled: janela.relatorios = checked }
                }
            }
            Text {
                visible: janela.atual === "privacidade"
                Layout.fillWidth: true; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                text: "O CarinaeOS não tem publicidade nem recolhe os seus dados."
                color: janela.suave; font.pixelSize: 12
            }

            // ===== 4. aparência =====
            Row {
                visible: janela.atual === "aparencia"
                Layout.alignment: Qt.AlignHCenter
                spacing: 28
                Repeater {
                    model: [[false, "Escuro", "#17151f", "#2d2b38"], [true, "Claro", "#f4f4f6", "#ffffff"]]
                    delegate: Column {
                        required property var modelData
                        spacing: 8
                        Rectangle {
                            width: 200; height: 124; radius: 12
                            color: modelData[2]
                            border.width: (!!janela.e.claro) === modelData[0] ? 3 : 1
                            border.color: (!!janela.e.claro) === modelData[0] ? janela.realce : janela.linha
                            Rectangle { x: 20; y: 20; width: 124; height: 74; radius: 8; color: modelData[3]; border.color: Qt.rgba(0.5, 0.5, 0.5, 0.3) }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ajustes.definirClaro(modelData[0]); ajustes.ler("aparencia"); } }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[1]; color: janela.texto; font.pixelSize: 14 }
                    }
                }
            }
            Text { visible: janela.atual === "aparencia"; Layout.topMargin: 8; text: "Papel de parede"; color: janela.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
            Flow {
                visible: janela.atual === "aparencia"
                Layout.fillWidth: true
                spacing: 12
                Repeater {
                    model: (janela.e.fundos || []).slice(0, 9)
                    delegate: Rectangle {
                        required property var modelData
                        width: 186; height: 106; radius: 10
                        color: "transparent"
                        border.width: mf.containsMouse ? 2 : 0
                        border.color: janela.realce
                        Image { anchors.fill: parent; anchors.margins: 2; source: modelData.miniatura; fillMode: Image.PreserveAspectCrop; asynchronous: true }
                        MouseArea { id: mf; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: ajustes.definirFundo(modelData.caminho) }
                    }
                }
            }

            // ===== 5. contas online =====
            Text {
                visible: janela.atual === "contas"
                Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap
                text: "Ligue as suas contas para ver o calendário e os contactos no CarinaeOS. Também pode fazê-lo mais tarde."
                color: janela.suave; font.pixelSize: 14
            }
            Grupo {
                visible: janela.atual === "contas"
                Linha { titulo: "Google"; sub: "Calendário e contactos"; icone: "view-calendar"; clicavel: true; onCarregado: bv.abrir("carinaeos-central calendarios"); Text { text: "›"; color: janela.suave; font.pixelSize: 20 } }
                Linha { titulo: "iCloud, Outlook e outros calendários"; sub: "Pelo endereço do calendário (iCal)"; icone: "view-calendar-day"; clicavel: true; onCarregado: bv.abrir("carinaeos-central calendarios"); Text { text: "›"; color: janela.suave; font.pixelSize: 20 } }
                Linha { titulo: "Nextcloud e outras contas"; icone: "preferences-online-accounts"; clicavel: true; onCarregado: bv.abrir("kcmshell6 kcm_kaccounts"); Text { text: "›"; color: janela.suave; font.pixelSize: 20 } }
            }

            // ===== 6. pronto =====
            ColumnLayout {
                visible: janela.atual === "pronto"
                Layout.fillWidth: true
                spacing: 14
                Item { Layout.preferredHeight: 20 }
                Text { Layout.alignment: Qt.AlignHCenter; text: "✦"; color: janela.realce; font.pixelSize: 64 }
                Text { Layout.alignment: Qt.AlignHCenter; text: "Tudo pronto!"; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold }
                Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; text: "Algumas dicas para começar:"; color: janela.suave; font.pixelSize: 14 }
                Grupo {
                    Linha { titulo: "Pesquisa"; sub: "Ctrl+Espaço ou a lupa da barra de cima: aplicativos, arquivos e ações como “diminuir volume”."; icone: "search" }
                    Linha { titulo: "Launchpad"; sub: "A estrela da Dock ou a tecla ⊞: todos os aplicativos por categoria, e o Deck."; icone: "carinaeos-estrela" }
                    Linha { titulo: "Configurações"; sub: "Wi-Fi, som, ecrãs, aparência e tudo o resto."; icone: "preferences-system" }
                    Linha { titulo: "Manual do CarinaeOS"; sub: "Tudo explicado, passo a passo."; icone: "help-contents" }
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    width: tf.implicitWidth + 44; height: 44; radius: 10
                    color: mfim.containsMouse ? Qt.lighter(janela.realce, 1.08) : janela.realce
                    Text { id: tf; anchors.centerIn: parent; text: "Começar a usar o CarinaeOS"; color: "#0b1530"; font.pixelSize: 15; font.weight: Font.DemiBold }
                    MouseArea { id: mfim; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: janela.seguinte() }
                }
            }
            Item { Layout.preferredHeight: 30 }
        }
    }

    // pontos do progresso, em baixo
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom; anchors.bottomMargin: 14
        spacing: 8
        Repeater {
            model: janela.paginas.length
            delegate: Rectangle {
                required property int index
                width: index === janela.pagina ? 20 : 8; height: 8; radius: 4
                color: index === janela.pagina ? janela.realce : Qt.rgba(1, 1, 1, 0.22)
                Behavior on width { NumberAnimation { duration: 180 } }
            }
        }
    }

    Dialog {
        id: senha
        property string ssid: ""
        property bool segura: true
        anchors.centerIn: parent
        modal: true
        title: "Ligar a " + ssid
        standardButtons: Dialog.Cancel | Dialog.Ok
        onOpened: { campo.text = ""; if (segura) campo.forceActiveFocus(); }
        onAccepted: ajustes.ligarWifi(ssid, campo.text)
        ColumnLayout {
            Text { visible: senha.segura; text: "Senha da rede"; color: janela.texto }
            TextField { id: campo; visible: senha.segura; echoMode: TextInput.Password; Layout.preferredWidth: 280; onAccepted: senha.accept() }
            Text { visible: !senha.segura; text: "Rede aberta."; color: janela.suave }
        }
    }
}
