// CarinaeOS — Carinae Compactador
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: janela
    width: 900; height: 580
    minimumWidth: 420; minimumHeight: 160
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: comp.nome ? comp.nome + " — Carinae Compactador" : "Carinae Compactador"
    font.family: "Inter"; font.pixelSize: 13
    palette.window: "#2b2a32"; palette.windowText: "#f2f0f6"; palette.base: "#24232a"; palette.alternateBase: "#2b2a32"
    palette.text: "#f2f0f6"; palette.button: "#3a3942"; palette.buttonText: "#f2f0f6"; palette.brightText: "#ffffff"
    palette.highlight: "#7aa7ff"; palette.highlightedText: "#10131c"; palette.light: "#4a4952"; palette.midlight: "#3f3e47"
    palette.mid: "#55535f"; palette.dark: "#1c1b21"; palette.toolTipBase: "#2f2e37"; palette.toolTipText: "#f2f0f6"
    palette.placeholderText: "#8a8597"

    readonly property color fundo: "#1f1e25"
    readonly property color barra: "#2a2931"
    readonly property color texto: "#f2f0f6"
    readonly property color suave: "#a8a3b6"
    readonly property color realce: "#7aa7ff"
    readonly property bool maximizada: visibility === Window.Maximized
    readonly property bool aTrabalhar: comp.operacao.titulo !== undefined
    property var selecionados: ({})
    readonly property var listaSel: Object.keys(selecionados)

    Component.onCompleted: {
        if (comp.modo === "criar") { width = 500; height = 520; }
        else if (comp.modo === "extrair-aqui") { width = 460; height = 170; comp.extrairAqui(); }
    }
    Connections {
        target: comp
        function onAviso(t) { toast.texto = t; toast.opacity = 1; esconderToast.restart(); }
        function onPedeSenha() { senha.abrir(); }
        function onMudou() { janela.selecionados = ({}); }
    }

    Shortcut { sequence: "Ctrl+O"; onActivated: comp.escolherArquivo() }
    Shortcut { sequence: "Backspace"; enabled: comp.modo === "ver" && comp.pasta !== ""; onActivated: comp.subir() }
    Shortcut { sequence: "Alt+Up"; enabled: comp.modo === "ver" && comp.pasta !== ""; onActivated: comp.subir() }
    Shortcut { sequence: "Ctrl+E"; enabled: comp.modo === "ver" && comp.itens.length > 0; onActivated: extracao.abrir() }

    Rectangle {
        id: moldura
        anchors.fill: parent
        radius: janela.maximizada ? 0 : 10
        color: janela.fundo
        border.width: janela.maximizada ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.09)
        clip: true

        ColumnLayout {
            anchors.fill: parent; anchors.margins: moldura.border.width; spacing: 0

            // ---- título -----------------------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 40
                color: janela.barra
                topLeftRadius: moldura.radius; topRightRadius: moldura.radius
                MouseArea {
                    anchors.fill: parent
                    onPressed: janela.startSystemMove()
                    onDoubleClicked: if (comp.modo === "ver") janela.visibility = janela.maximizada ? Window.Windowed : Window.Maximized
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 14; spacing: 8
                    Image { source: "image://icone/carinaeos-compactador"; sourceSize: Qt.size(32, 32); Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
                    Text { text: "Carinae Compactador"; color: janela.suave }
                    Text { text: comp.nome; color: janela.texto; font.weight: Font.DemiBold; elide: Text.ElideMiddle; Layout.fillWidth: true }
                    BotaoJanela { texto: "—"; onClicado: janela.showMinimized() }
                    BotaoJanela { visible: comp.modo === "ver"; texto: janela.maximizada ? "❐" : "☐"; onClicado: janela.visibility = janela.maximizada ? Window.Windowed : Window.Maximized }
                    BotaoJanela { texto: "✕"; perigo: true; onClicado: { comp.cancelar(); Qt.quit(); } }
                }
            }

            // ================= ver um arquivo =================
            ColumnLayout {
                visible: comp.modo === "ver"
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 50
                    color: janela.barra
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 6
                        Botao { text: "Extrair tudo"; highlighted: true; enabled: comp.itens.length > 0 && !janela.aTrabalhar; onClicked: { janela.selecionados = ({}); extracao.abrir(); } }
                        Botao { text: "Extrair " + janela.listaSel.length + " selecionado" + (janela.listaSel.length > 1 ? "s" : "")
                                visible: janela.listaSel.length > 0; enabled: !janela.aTrabalhar; onClicked: extracao.abrir() }
                        Botao { text: "Abrir…"; flat: true; onClicked: comp.escolherArquivo() }
                        Item { Layout.fillWidth: true }
                        Text { text: comp.formato; color: janela.suave; visible: !!comp.arquivo }
                    }
                }
                // caminho dentro do arquivo
                RowLayout {
                    Layout.fillWidth: true; Layout.preferredHeight: 40; Layout.leftMargin: 10; Layout.rightMargin: 10; spacing: 4
                    visible: !!comp.arquivo && !comp.erro
                    Pequeno { glifo: "↑"; dica: "Subir (Backspace)"; enabled: comp.pasta !== ""; onClicado: comp.subir() }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 32; radius: 6; color: Qt.rgba(1, 1, 1, 0.05)
                        Row {
                            anchors.verticalCenter: parent.verticalCenter; x: 8; spacing: 2
                            Migalha { texto: comp.nome; onClicado: comp.entrar("") }
                            Repeater {
                                model: comp.pasta ? comp.pasta.split("/") : []
                                Row {
                                    spacing: 2
                                    Text { text: "›"; color: janela.suave; anchors.verticalCenter: parent.verticalCenter }
                                    Migalha { texto: modelData; onClicado: comp.entrar(comp.pasta.split("/").slice(0, index + 1).join("/")) }
                                }
                            }
                        }
                    }
                }
                // cabeçalho
                RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 20; Layout.rightMargin: 20; Layout.preferredHeight: 28
                    visible: comp.itens.length > 0
                    Text { text: "Nome"; color: janela.suave; font.pixelSize: 12; Layout.fillWidth: true }
                    Text { text: "Tamanho"; color: janela.suave; font.pixelSize: 12; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                    Text { text: "Compactado"; color: janela.suave; font.pixelSize: 12; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight; visible: janela.width > 640 }
                    Text { text: "Modificado"; color: janela.suave; font.pixelSize: 12; Layout.preferredWidth: 130; Layout.leftMargin: 14; visible: janela.width > 560 }
                }
                ListView {
                    id: lista
                    Layout.fillWidth: true; Layout.fillHeight: true; Layout.leftMargin: 10; Layout.rightMargin: 10
                    clip: true; model: comp.itens
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Rectangle {
                        width: lista.width; height: 34; radius: 6
                        readonly property bool sel: janela.selecionados[modelData.caminho] === true
                        color: sel ? Qt.rgba(0.48, 0.65, 1, 0.2) : (ml.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                            Image { source: "image://icone/" + modelData.icone; sourceSize: Qt.size(40, 40); Layout.preferredWidth: 20; Layout.preferredHeight: 20 }
                            Text { text: modelData.nome + (modelData.cifrado ? "  🔒" : ""); color: janela.texto; elide: Text.ElideMiddle; Layout.fillWidth: true }
                            Text { text: modelData.tamanho; color: janela.suave; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight }
                            Text { text: modelData.comprimido; color: janela.suave; Layout.preferredWidth: 90; horizontalAlignment: Text.AlignRight; visible: janela.width > 640 }
                            Text { text: modelData.data; color: janela.suave; Layout.preferredWidth: 130; Layout.leftMargin: 4; visible: janela.width > 560 }
                        }
                        MouseArea {
                            id: ml; anchors.fill: parent; hoverEnabled: true
                            onClicked: (ev) => {
                                const s = Object.assign({}, (ev.modifiers & Qt.ControlModifier) ? janela.selecionados : {});
                                if (s[modelData.caminho]) delete s[modelData.caminho]; else s[modelData.caminho] = true;
                                janela.selecionados = s;
                            }
                            onDoubleClicked: modelData.pasta ? comp.entrar(modelData.caminho) : comp.abrirItem(modelData.caminho)
                        }
                    }
                    // vazio / a ler / erro
                    Column {
                        anchors.centerIn: parent; spacing: 14
                        visible: lista.count === 0
                        BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: comp.aLer; visible: running }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter; color: comp.erro ? "#ff9aa9" : janela.suave
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; width: Math.min(420, lista.width - 40)
                            text: comp.aLer ? "A ler…" : comp.erro ? comp.erro : comp.arquivo ? "Este arquivo está vazio." : "Arraste para aqui um arquivo .zip, .rar, .7z, .tar…"
                        }
                        Botao { anchors.horizontalCenter: parent.horizontalCenter; visible: !comp.aLer && !comp.arquivo; text: "Abrir um arquivo compactado…"; highlighted: true; onClicked: comp.escolherArquivo() }
                    }
                    DropArea {
                        anchors.fill: parent; keys: ["text/uri-list"]
                        onDropped: (ev) => { if (ev.hasUrls) comp.abrir(decodeURIComponent(String(ev.urls[0]).replace("file://", ""))); }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 30; color: janela.barra
                    bottomLeftRadius: moldura.radius; bottomRightRadius: moldura.radius
                    Text { anchors.verticalCenter: parent.verticalCenter; x: 16; text: comp.itens.length ? comp.resumo + "   ·   duplo clique abre" : ""; color: janela.suave; font.pixelSize: 12 }
                }
            }

            // ================= criar =================
            ColumnLayout {
                visible: comp.modo === "criar"
                Layout.fillWidth: true; Layout.fillHeight: true; Layout.margins: 20; spacing: 12
                Text { text: "Compactar " + (comp.origens.length === 1 ? "\"" + comp.origens[0].nome + "\"" : comp.origens.length + " itens"); color: janela.texto; font.pixelSize: 18; font.weight: Font.DemiBold }
                Text { text: "Nome"; color: janela.suave }
                RowLayout {
                    Layout.fillWidth: true
                    Campo { id: nomeNovo; Layout.fillWidth: true; text: comp.nomeSugerido; Component.onCompleted: { forceActiveFocus(); selectAll(); } }
                    Text { text: "." + formatos.escolhido; color: janela.suave }
                }
                Text { text: "Formato"; color: janela.suave }
                Column {
                    id: formatos
                    property string escolhido: "zip"
                    Layout.fillWidth: true; spacing: 2
                    Repeater {
                        model: comp.formatos
                        RadioButton {
                            text: modelData.nome + (modelData.disponivel ? "" : "  (instale o 7zip)")
                            enabled: modelData.disponivel
                            checked: formatos.escolhido === modelData.id
                            onClicked: formatos.escolhido = modelData.id
                        }
                    }
                }
                RowLayout {
                    spacing: 10
                    Text { text: "Compactação"; color: janela.suave }
                    ComboBox { id: nivel; model: ["Rápida", "Normal", "Máxima"]; currentIndex: 1; Layout.preferredWidth: 140 }
                }
                RowLayout {
                    spacing: 10
                    visible: comp.tem7z && (formatos.escolhido === "zip" || formatos.escolhido === "7z")
                    CheckBox { id: comSenha; text: "Proteger com senha" }
                    Campo { id: senhaNova; visible: comSenha.checked; echoMode: TextInput.Password; placeholderText: "Senha"; Layout.preferredWidth: 180 }
                }
                CheckBox { id: mostrarFeito; text: "Mostrar na pasta quando terminar"; checked: false }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    Botao { text: "Cancelar"; onClicked: Qt.quit() }
                    Botao {
                        text: "Compactar"; highlighted: true; enabled: !janela.aTrabalhar && !(comSenha.checked && !senhaNova.text)
                        onClicked: comp.criar(nomeNovo.text, formatos.escolhido, [1, 6, 9][nivel.currentIndex],
                                              comSenha.checked ? senhaNova.text : "", mostrarFeito.checked)
                    }
                }
            }

            // ================= extrair aqui =================
            Item { visible: comp.modo === "extrair-aqui"; Layout.fillWidth: true; Layout.fillHeight: true }
        }

        // ---- progresso (por cima de tudo) -------------------------------------------------------------
        Rectangle {
            anchors.fill: parent; anchors.topMargin: 40
            visible: janela.aTrabalhar
            color: Qt.rgba(0.12, 0.12, 0.15, 0.92)
            bottomLeftRadius: moldura.radius; bottomRightRadius: moldura.radius
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                anchors.centerIn: parent; width: Math.min(400, parent.width - 40); spacing: 12
                Text { text: comp.operacao.titulo || ""; color: janela.texto; elide: Text.ElideMiddle; Layout.fillWidth: true }
                ProgressBar { Layout.fillWidth: true; value: comp.operacao.fracao || 0; indeterminate: (comp.operacao.fracao || 0) === 0 }
                RowLayout {
                    Text { text: Math.round((comp.operacao.fracao || 0) * 100) + "%"; color: janela.suave }
                    Item { Layout.fillWidth: true }
                    Botao { text: "Cancelar"; onClicked: comp.cancelar() }
                }
            }
        }

        Rectangle {
            id: toast
            property string texto
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 46
            width: Math.min(parent.width - 30, tt.implicitWidth + 32); height: 40; radius: 10
            color: "#34323d"; border.color: Qt.rgba(1, 1, 1, 0.1)
            opacity: 0; visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Timer { id: esconderToast; interval: 5000; onTriggered: toast.opacity = 0 }
            Text { id: tt; anchors.centerIn: parent; width: parent.width - 24; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; text: toast.texto; color: janela.texto }
        }

        Repeater {
            model: janela.maximizada ? [] : [
                { b: Qt.RightEdge, x: -5, y: 8, w: 5, h: -16, c: Qt.SizeHorCursor },
                { b: Qt.LeftEdge, x: 0, y: 8, w: 5, h: -16, c: Qt.SizeHorCursor },
                { b: Qt.BottomEdge, x: 8, y: -5, w: -16, h: 5, c: Qt.SizeVerCursor },
                { b: Qt.TopEdge, x: 8, y: 0, w: -16, h: 4, c: Qt.SizeVerCursor },
                { b: Qt.RightEdge | Qt.BottomEdge, x: -8, y: -8, w: 8, h: 8, c: Qt.SizeFDiagCursor },
                { b: Qt.LeftEdge | Qt.BottomEdge, x: 0, y: -8, w: 8, h: 8, c: Qt.SizeBDiagCursor }
            ]
            delegate: MouseArea {
                required property var modelData
                x: modelData.x < 0 ? moldura.width + modelData.x : modelData.x
                y: modelData.y < 0 ? moldura.height + modelData.y : modelData.y
                width: modelData.w <= 0 ? moldura.width + modelData.w : modelData.w
                height: modelData.h <= 0 ? moldura.height + modelData.h : modelData.h
                cursorShape: modelData.c
                onPressed: janela.startSystemResize(modelData.b)
            }
        }
    }

    // ---- extrair para… -----------------------------------------------------------------------------------
    Popup {
        id: extracao
        anchors.centerIn: parent; width: Math.min(480, janela.width - 40); modal: true; padding: 22
        function abrir() { destino.text = comp.destinoSugerido.replace(/^\/home\/[^/]+/, "~"); open(); }
        background: Rectangle { radius: 10; color: "#2b2a32"; border.color: Qt.rgba(1, 1, 1, 0.1) }
        Connections { target: comp; function onPastaEscolhida(p) { destino.text = p + "/" + comp.destinoSugerido.split("/").pop(); } }
        ColumnLayout {
            anchors.fill: parent; spacing: 14
            Text { text: janela.listaSel.length ? "Extrair os selecionados" : "Extrair tudo"; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
            Text { text: "Os arquivos vão para esta pasta:"; color: janela.suave }
            RowLayout {
                Layout.fillWidth: true
                Campo { id: destino; Layout.fillWidth: true }
                Botao { text: "Procurar…"; onClicked: comp.escolherPasta(destino.text) }
            }
            CheckBox { id: mostrar; text: "Mostrar os arquivos quando terminar"; checked: true }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                Botao { text: "Cancelar"; onClicked: extracao.close() }
                Botao { text: "Extrair"; highlighted: true
                        onClicked: { extracao.close(); comp.extrair(destino.text, janela.listaSel, mostrar.checked); } }
            }
        }
    }
    Popup {
        id: senha
        anchors.centerIn: parent; width: 380; modal: true; padding: 22
        function abrir() { campoSenha.text = ""; open(); campoSenha.forceActiveFocus(); }
        background: Rectangle { radius: 10; color: "#2b2a32"; border.color: Qt.rgba(1, 1, 1, 0.1) }
        ColumnLayout {
            anchors.fill: parent; spacing: 12
            Text { text: "Este arquivo tem senha"; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
            Campo { id: campoSenha; Layout.fillWidth: true; echoMode: TextInput.Password; onAccepted: okSenha.clicked() }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                Botao { text: "Cancelar"; onClicked: { senha.close(); if (comp.modo === "extrair-aqui") Qt.quit(); } }
                Botao { id: okSenha; text: "Continuar"; highlighted: true; onClicked: { senha.close(); comp.usarSenha(campoSenha.text); } }
            }
        }
    }

    component Migalha: Rectangle {
        id: mg
        property string texto
        signal clicado()
        width: tm.implicitWidth + 14; height: 26; radius: 5
        color: mm.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        Text { id: tm; anchors.centerIn: parent; text: mg.texto; color: janela.texto }
        MouseArea { id: mm; anchors.fill: parent; hoverEnabled: true; onClicked: mg.clicado() }
    }
    component Campo: TextField {
        color: janela.texto; placeholderTextColor: janela.suave
        background: Rectangle { radius: 6; color: Qt.rgba(1, 1, 1, 0.06); border.color: parent.activeFocus ? janela.realce : Qt.rgba(1, 1, 1, 0.1) }
    }
    component Pequeno: Rectangle {
        id: pq
        property string glifo
        property string dica
        signal clicado()
        Layout.preferredWidth: 32; Layout.preferredHeight: 30; radius: 6
        opacity: enabled ? 1 : 0.35
        color: mp.containsMouse && enabled ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
        Text { anchors.centerIn: parent; text: pq.glifo; color: janela.texto; font.pixelSize: 15 }
        MouseArea { id: mp; anchors.fill: parent; hoverEnabled: true; onClicked: pq.clicado() }
        ToolTip.visible: mp.containsMouse && dica !== ""; ToolTip.text: dica; ToolTip.delay: 500
    }
    component BotaoJanela: Rectangle {
        id: bj
        property string texto
        property bool perigo
        signal clicado()
        Layout.preferredWidth: 46; Layout.fillHeight: true
        color: mbj.containsMouse ? (perigo ? "#c42b1c" : Qt.rgba(1, 1, 1, 0.08)) : "transparent"
        Text { anchors.centerIn: parent; text: bj.texto; color: janela.texto }
        MouseArea { id: mbj; anchors.fill: parent; hoverEnabled: true; onClicked: bj.clicado() }
    }
    component Botao: Rectangle {
        id: bt
        property string text
        property bool highlighted: false
        property bool flat: false
        signal clicked()
        implicitWidth: Math.max(84, tb.implicitWidth + 28); implicitHeight: 32; radius: 6
        opacity: enabled ? 1 : 0.45
        color: highlighted ? (mb.pressed ? Qt.darker("#7aa7ff", 1.1) : mb.containsMouse ? Qt.lighter("#7aa7ff", 1.08) : "#7aa7ff")
                           : (mb.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, flat ? 0 : 0.08))
        border.color: highlighted ? "transparent" : Qt.rgba(1, 1, 1, 0.08)
        Text { id: tb; anchors.centerIn: parent; text: bt.text; color: bt.highlighted ? "#10131c" : "#f2f0f6"; font.weight: Font.DemiBold }
        MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: bt.enabled; onClicked: bt.clicked() }
    }
}
