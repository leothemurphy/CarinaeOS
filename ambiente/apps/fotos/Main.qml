// CarinaeOS — Fotos (no jeito do Fotos do Windows 11)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: janela
    width: 1100; height: 720
    minimumWidth: 520; minimumHeight: 360
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: fotos.info.nome ? fotos.info.nome + " — Carinae Fotos" : "Carinae Fotos"
    font.family: "Inter"; font.pixelSize: 13
    // as cores dos controlos padrão (menus, caixas, listas) no tema escuro do CarinaeOS
    palette.window: "#2b2a32"; palette.windowText: "#f2f0f6"; palette.base: "#24232a"; palette.alternateBase: "#2b2a32"
    palette.text: "#f2f0f6"; palette.button: "#3a3942"; palette.buttonText: "#f2f0f6"; palette.brightText: "#ffffff"
    palette.highlight: "#7aa7ff"; palette.highlightedText: "#10131c"; palette.light: "#4a4952"; palette.midlight: "#3f3e47"
    palette.mid: "#55535f"; palette.dark: "#1c1b21"; palette.shadow: "#000000"; palette.toolTipBase: "#2f2e37"; palette.toolTipText: "#f2f0f6"
    palette.placeholderText: "#8a8597"

    readonly property color fundo: "#1c1b21"
    readonly property color barra: "#24232a"
    readonly property color texto: "#f2f0f6"
    readonly property color suave: "#a8a3b6"
    readonly property color realce: "#7aa7ff"
    readonly property bool maximizada: visibility === Window.Maximized || visibility === Window.FullScreen
    readonly property bool cheia: visibility === Window.FullScreen
    property bool mostrarInfo: false
    property bool mostrarTira: true
    property bool apresentacao: false
    property bool barrasVisiveis: !cheia || ratoPorPerto

    property bool ratoPorPerto: false
    // a versão muda quando a imagem é gravada (girar): obriga a recarregar o ficheiro
    property int versao: 0
    function url(c) { return c ? "file://" + c.split("/").map(encodeURIComponent).join("/") + (versao ? "?v=" + versao : "") : ""; }
    Connections { target: fotos; function onGravada() { janela.versao++; } }
    function aviso(t, podeDesfazer) { toast.texto = t; toast.desfazer = podeDesfazer; toast.opacity = 1; esconderToast.restart(); }
    Connections { target: fotos; function onAviso(t, d) { janela.aviso(t, d); } }

    // ---- atalhos ----------------------------------------------------------------------------------------
    Shortcut { sequences: ["Right", "Space"]; enabled: !renomear.visible; onActivated: fotos.seguinte() }
    Shortcut { sequence: "Left"; enabled: !renomear.visible; onActivated: fotos.anterior() }
    Shortcut { sequence: "Home"; onActivated: fotos.ir(0) }
    Shortcut { sequence: "End"; onActivated: fotos.ir(fotos.lista.length - 1) }
    Shortcut { sequence: "Delete"; enabled: !renomear.visible; onActivated: fotos.apagar() }
    Shortcut { sequences: ["Ctrl+R", "R"]; enabled: !renomear.visible; onActivated: fotos.girar(90) }
    Shortcut { sequence: "Ctrl+Shift+R"; onActivated: fotos.girar(-90) }
    Shortcut { sequences: ["Ctrl+=", "Ctrl++", "+"]; enabled: !renomear.visible; onActivated: vista.zoomPor(1.25) }
    Shortcut { sequences: ["Ctrl+-", "-"]; enabled: !renomear.visible; onActivated: vista.zoomPor(0.8) }
    Shortcut { sequence: "Ctrl+0"; onActivated: vista.ajustar() }
    Shortcut { sequence: "Ctrl+1"; onActivated: vista.tamanhoReal() }
    Shortcut { sequence: "Ctrl+C"; onActivated: fotos.copiarImagem() }
    Shortcut { sequence: "Ctrl+O"; onActivated: fotos.escolher() }
    Shortcut { sequence: "Ctrl+P"; onActivated: fotos.imprimir() }
    Shortcut { sequence: "Ctrl+Z"; onActivated: fotos.desfazer() }
    Shortcut { sequences: ["Alt+Return", "Ctrl+I"]; onActivated: janela.mostrarInfo = !janela.mostrarInfo }
    Shortcut { sequence: "F2"; onActivated: renomear.abrir() }
    Shortcut { sequence: "F11"; onActivated: janela.alternarCheia() }
    Shortcut { sequence: "F5"; onActivated: janela.alternarApresentacao() }
    Shortcut { sequence: "Escape"; onActivated: { if (janela.apresentacao) janela.alternarApresentacao(); else if (janela.cheia) janela.alternarCheia(); } }

    function alternarCheia() { visibility = cheia ? Window.Windowed : Window.FullScreen; }
    function alternarApresentacao() {
        apresentacao = !apresentacao;
        if (apresentacao && !cheia) visibility = Window.FullScreen;
        if (!apresentacao && cheia) visibility = Window.Windowed;
    }
    Timer { running: janela.apresentacao; interval: 4000; repeat: true; onTriggered: fotos.seguinte() }

    Rectangle {
        id: moldura
        anchors.fill: parent
        radius: janela.maximizada ? 0 : 10
        color: janela.apresentacao || janela.cheia ? "black" : janela.fundo
        border.width: janela.maximizada ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.09)
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: moldura.border.width
            spacing: 0

            // ---- título --------------------------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: janela.barrasVisiveis && !janela.apresentacao ? 40 : 0
                visible: Layout.preferredHeight > 0
                color: janela.barra
                topLeftRadius: moldura.radius; topRightRadius: moldura.radius
                MouseArea {
                    anchors.fill: parent
                    onPressed: janela.startSystemMove()
                    onDoubleClicked: janela.visibility = janela.maximizada ? Window.Windowed : Window.Maximized
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 14; spacing: 8
                    Image { source: "image://icone/carinaeos-fotos"; sourceSize: Qt.size(32, 32); Layout.preferredWidth: 18; Layout.preferredHeight: 18 }
                    Text { text: "Carinae Fotos"; color: janela.suave }
                    Text { text: fotos.info.nome || ""; color: janela.texto; elide: Text.ElideMiddle; Layout.fillWidth: true; font.weight: Font.DemiBold }
                    BotaoJanela { texto: "—"; onClicado: janela.showMinimized() }
                    BotaoJanela { texto: janela.maximizada ? "❐" : "☐"; onClicado: janela.visibility = janela.maximizada ? Window.Windowed : Window.Maximized }
                    BotaoJanela { texto: "✕"; perigo: true; onClicado: janela.close() }
                }
            }
            // ---- ferramentas ---------------------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: janela.barrasVisiveis && !janela.apresentacao ? 48 : 0
                visible: Layout.preferredHeight > 0
                color: janela.barra
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                RowLayout {
                    anchors.centerIn: parent; spacing: 4
                    Ferramenta { glifo: "−"; dica: "Diminuir (Ctrl+−)"; onClicado: vista.zoomPor(0.8) }
                    Rectangle {
                        Layout.preferredWidth: 62; Layout.preferredHeight: 32; radius: 6; color: mz.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        Text { anchors.centerIn: parent; text: Math.round(vista.escala * 100) + "%"; color: janela.texto }
                        MouseArea { id: mz; anchors.fill: parent; hoverEnabled: true; onClicked: vista.ajustado ? vista.tamanhoReal() : vista.ajustar() }
                        ToolTip.visible: mz.containsMouse; ToolTip.text: vista.ajustado ? "Tamanho real (Ctrl+1)" : "Ajustar à janela (Ctrl+0)"; ToolTip.delay: 500
                    }
                    Ferramenta { glifo: "+"; dica: "Aumentar (Ctrl+=)"; onClicado: vista.zoomPor(1.25) }
                    Separador {}
                    Ferramenta { glifo: "↻"; dica: "Girar (Ctrl+R)"; onClicado: fotos.girar(90) }
                    Ferramenta { glifo: "🗑"; dica: "Apagar (Delete)"; onClicado: fotos.apagar() }
                    Ferramenta { glifo: "▶"; dica: "Apresentação (F5)"; onClicado: janela.alternarApresentacao() }
                    Ferramenta { glifo: "ⓘ"; dica: "Informações (Alt+Enter)"; ativo: janela.mostrarInfo; onClicado: janela.mostrarInfo = !janela.mostrarInfo }
                    Ferramenta { glifo: "⋯"; dica: "Mais"; onClicado: menuMais.popup() }
                }
            }

            // ---- a imagem ------------------------------------------------------------------------------
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
                Item {
                    id: vista
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    readonly property var img: fotos.info.animada ? animada : estatica
                    readonly property real iw: img.implicitWidth > 0 ? img.implicitWidth : 1
                    readonly property real ih: img.implicitHeight > 0 ? img.implicitHeight : 1
                    readonly property real escalaAjuste: Math.min(1, (width - 40) / iw, (height - 40) / ih)
                    property real escala: escalaAjuste
                    property bool ajustado: true
                    onEscalaAjusteChanged: if (ajustado) escala = escalaAjuste
                    function ajustar() { ajustado = true; escala = escalaAjuste; }
                    function tamanhoReal() { zoomEm(1 / escala, width / 2, height / 2); }
                    function zoomPor(f) { zoomEm(f, width / 2, height / 2); }
                    function zoomEm(f, px, py) {
                        const nova = Math.max(Math.min(0.05, escalaAjuste), Math.min(16, escala * f));
                        // o ponto debaixo do rato fica no mesmo sítio
                        const cx = (fl.contentX + px - fl.margemX) / escala, cy = (fl.contentY + py - fl.margemY) / escala;
                        escala = nova;
                        ajustado = Math.abs(nova - escalaAjuste) < 0.001;
                        fl.returnToBounds();
                        fl.contentX = Math.max(0, cx * nova + fl.margemX - px);
                        fl.contentY = Math.max(0, cy * nova + fl.margemY - py);
                    }
                    Connections { target: fotos; function onMudou() { vista.ajustar(); fl.contentX = 0; fl.contentY = 0; } }

                    Flickable {
                        id: fl
                        anchors.fill: parent
                        readonly property real largura: vista.iw * vista.escala
                        readonly property real altura: vista.ih * vista.escala
                        readonly property real margemX: Math.max(0, (width - largura) / 2)
                        readonly property real margemY: Math.max(0, (height - altura) / 2)
                        contentWidth: Math.max(width, largura)
                        contentHeight: Math.max(height, altura)
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: largura > width || altura > height
                        ScrollBar.vertical: ScrollBar { policy: fl.altura > fl.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
                        ScrollBar.horizontal: ScrollBar { policy: fl.largura > fl.width ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
                        Image {
                            id: estatica
                            visible: !fotos.info.animada
                            x: fl.margemX; y: fl.margemY
                            width: fl.largura; height: fl.altura
                            source: fotos.info.animada ? "" : janela.url(fotos.atual)
                            sourceSize: /\.svgz?$/i.test(fotos.atual) ? Qt.size(2400, 2400) : undefined
                            asynchronous: true; autoTransform: true; cache: false
                            smooth: true; mipmap: vista.escala < 1
                            fillMode: Image.Stretch
                        }
                        AnimatedImage {
                            id: animada
                            visible: !!fotos.info.animada
                            x: fl.margemX; y: fl.margemY
                            width: fl.largura; height: fl.altura
                            source: fotos.info.animada ? janela.url(fotos.atual) : ""
                            playing: true; smooth: true; cache: false
                        }
                    }
                    // a roda aumenta e diminui (como no Fotos do Windows); duplo clique alterna ajustar/100%
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        hoverEnabled: true
                        onWheel: (ev) => {
                            if (ev.modifiers & Qt.ShiftModifier) { ev.angleDelta.y > 0 ? fotos.anterior() : fotos.seguinte(); return; }
                            vista.zoomEm(ev.angleDelta.y > 0 ? 1.15 : 1 / 1.15, ev.x, ev.y);
                        }
                        onPositionChanged: (ev) => { janela.ratoPorPerto = ev.y < 100 || ev.y > height - 110; mostrarSetas.restart(); setas.opacity = 1; }
                    }
                    TapHandler {
                        onDoubleTapped: vista.ajustado ? vista.tamanhoReal() : vista.ajustar()
                    }
                    // setas para a anterior/seguinte (aparecem com o rato)
                    Item {
                        id: setas
                        anchors.fill: parent
                        opacity: 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Timer { id: mostrarSetas; interval: 1800; onTriggered: setas.opacity = 0 }
                        Seta { anchors.left: parent.left; anchors.leftMargin: 14; glifo: "‹"; onClicado: fotos.anterior(); visible: fotos.lista.length > 1 }
                        Seta { anchors.right: parent.right; anchors.rightMargin: 14; glifo: "›"; onClicado: fotos.seguinte(); visible: fotos.lista.length > 1 }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !fotos.atual || (vista.img.status === Image.Error)
                        color: janela.suave; horizontalAlignment: Text.AlignHCenter
                        text: !fotos.atual ? "Não há imagens nesta pasta.\nCtrl+O para abrir outra." : "Não foi possível mostrar esta imagem."
                    }
                    BusyIndicator { anchors.centerIn: parent; running: vista.img.status === Image.Loading; visible: running }
                }
                // ---- informações --------------------------------------------------------------------
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: janela.mostrarInfo && !janela.apresentacao ? 300 : 0
                    visible: Layout.preferredWidth > 0
                    color: janela.barra
                    Flickable {
                        anchors.fill: parent; anchors.margins: 18
                        contentHeight: infoCol.implicitHeight; clip: true
                        ColumnLayout {
                            id: infoCol
                            width: parent.width; spacing: 14
                            Text { text: "Informações"; color: janela.texto; font.pixelSize: 18; font.weight: Font.DemiBold }
                            Repeater {
                                model: [["Nome", fotos.info.nome], ["Pasta", fotos.info.pasta], ["Data", fotos.info.data],
                                        ["Dimensões", (fotos.info.dimensoes || "") + (fotos.info.megapixeis ? "  ·  " + fotos.info.megapixeis : "")],
                                        ["Tamanho", fotos.info.tamanho], ["Tipo", fotos.info.tipo]].concat(fotos.info.camera || [])
                                Column {
                                    Layout.fillWidth: true; spacing: 2
                                    visible: !!modelData[1]
                                    Text { text: modelData[0]; color: janela.suave; font.pixelSize: 12 }
                                    Text { text: modelData[1] || ""; color: janela.texto; width: parent.width; wrapMode: Text.WrapAnywhere }
                                }
                            }
                            Botao { text: "Mostrar na pasta"; onClicked: fotos.mostrarNaPasta() }
                        }
                    }
                }
            }

            // ---- tira de miniaturas --------------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: janela.mostrarTira && janela.barrasVisiveis && !janela.apresentacao && fotos.lista.length > 1 ? 78 : 0
                visible: Layout.preferredHeight > 0
                color: janela.barra
                bottomLeftRadius: moldura.radius; bottomRightRadius: moldura.radius
                ListView {
                    id: tira
                    anchors.fill: parent; anchors.margins: 8
                    orientation: ListView.Horizontal
                    spacing: 6
                    model: fotos.lista
                    currentIndex: fotos.indice
                    highlightMoveDuration: 150
                    preferredHighlightBegin: width / 2 - 34; preferredHighlightEnd: width / 2 + 34
                    highlightRangeMode: ListView.ApplyRange
                    clip: true
                    delegate: Rectangle {
                        width: 68; height: 62; radius: 6
                        color: "transparent"
                        border.width: index === fotos.indice ? 2 : 0
                        border.color: janela.realce
                        Image {
                            anchors.fill: parent; anchors.margins: 3
                            source: janela.url(modelData)
                            sourceSize: Qt.size(136, 124)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; autoTransform: true
                            opacity: index === fotos.indice || mt.containsMouse ? 1 : 0.7
                        }
                        MouseArea { id: mt; anchors.fill: parent; hoverEnabled: true; onClicked: fotos.ir(index) }
                    }
                }
            }
        }

        // ---- bordas para redimensionar ----------------------------------------------------------------
        Repeater {
            model: janela.maximizada ? [] : [
                { b: Qt.LeftEdge, x: 0, y: 8, w: 5, h: -16, c: Qt.SizeHorCursor },
                { b: Qt.RightEdge, x: -5, y: 8, w: 5, h: -16, c: Qt.SizeHorCursor },
                { b: Qt.TopEdge, x: 8, y: 0, w: -16, h: 4, c: Qt.SizeVerCursor },
                { b: Qt.BottomEdge, x: 8, y: -5, w: -16, h: 5, c: Qt.SizeVerCursor },
                { b: Qt.LeftEdge | Qt.TopEdge, x: 0, y: 0, w: 8, h: 8, c: Qt.SizeFDiagCursor },
                { b: Qt.RightEdge | Qt.BottomEdge, x: -8, y: -8, w: 8, h: 8, c: Qt.SizeFDiagCursor },
                { b: Qt.RightEdge | Qt.TopEdge, x: -8, y: 0, w: 8, h: 8, c: Qt.SizeBDiagCursor },
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

        // ---- aviso em baixo ---------------------------------------------------------------------------
        Rectangle {
            id: toast
            property string texto
            property bool desfazer
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 100
            width: tr.implicitWidth + 32; height: 42; radius: 10
            color: "#2f2d38"; border.color: Qt.rgba(1, 1, 1, 0.1)
            opacity: 0; visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Timer { id: esconderToast; interval: 5000; onTriggered: toast.opacity = 0 }
            RowLayout {
                id: tr; anchors.centerIn: parent; spacing: 14
                Text { text: toast.texto; color: janela.texto }
                Text {
                    visible: toast.desfazer; text: "Desfazer"; color: janela.realce; font.weight: Font.DemiBold
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { fotos.desfazer(); toast.opacity = 0; } }
                }
            }
        }
    }

    Menu {
        id: menuMais
        ItemMenu { text: "Abrir…"; atalho: "Ctrl+O"; onTriggered: fotos.escolher() }
        ItemMenu { text: "Renomear"; atalho: "F2"; onTriggered: renomear.abrir() }
        ItemMenu { text: "Girar para a esquerda"; onTriggered: fotos.girar(-90) }
        MenuSeparator {}
        ItemMenu { text: "Copiar a imagem"; atalho: "Ctrl+C"; onTriggered: fotos.copiarImagem() }
        ItemMenu { text: "Copiar o caminho"; onTriggered: fotos.copiarCaminho() }
        ItemMenu { text: "Definir como papel de parede"; onTriggered: fotos.definirPapel() }
        ItemMenu { text: "Mostrar na pasta"; onTriggered: fotos.mostrarNaPasta() }
        ItemMenu { text: "Imprimir"; atalho: "Ctrl+P"; onTriggered: fotos.imprimir() }
        MenuSeparator {}
        ItemMenu { text: janela.mostrarTira ? "Esconder as miniaturas" : "Mostrar as miniaturas"; onTriggered: janela.mostrarTira = !janela.mostrarTira }
        ItemMenu { text: "Ecrã inteiro"; atalho: "F11"; onTriggered: janela.alternarCheia() }
    }

    Popup {
        id: renomear
        anchors.centerIn: parent
        width: 380; modal: true; padding: 20
        function abrir() {
            campo.text = (fotos.info.nome || "").replace(/\.[^.]+$/, "");
            erro.text = "";
            open();
            campo.forceActiveFocus(); campo.selectAll();
        }
        background: Rectangle { radius: 10; color: "#2b2a32"; border.color: Qt.rgba(1, 1, 1, 0.1) }
        ColumnLayout {
            anchors.fill: parent; spacing: 12
            Text { text: "Renomear"; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
            TextField {
                id: campo; Layout.fillWidth: true; color: janela.texto
                background: Rectangle { radius: 6; color: Qt.rgba(1, 1, 1, 0.06); border.color: campo.activeFocus ? janela.realce : Qt.rgba(1, 1, 1, 0.1) }
                onAccepted: okRen.clicked()
            }
            Text { id: erro; color: "#ff8a8a"; visible: text !== "" }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                Botao { text: "Cancelar"; onClicked: renomear.close() }
                Botao { id: okRen; text: "Renomear"; highlighted: true
                         onClicked: { const e = fotos.renomear(campo.text); if (e) erro.text = e; else renomear.close(); } }
            }
        }
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
    component Ferramenta: Rectangle {
        id: fe
        property string glifo
        property string dica
        property bool ativo
        signal clicado()
        Layout.preferredWidth: 40; Layout.preferredHeight: 34; radius: 6
        color: ativo ? Qt.rgba(0.48, 0.65, 1, 0.22) : (mfe.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
        Text { anchors.centerIn: parent; text: fe.glifo; color: janela.texto; font.pixelSize: 16 }
        MouseArea { id: mfe; anchors.fill: parent; hoverEnabled: true; onClicked: fe.clicado() }
        ToolTip.visible: mfe.containsMouse; ToolTip.text: dica; ToolTip.delay: 500
    }
    component Separador: Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 22; color: Qt.rgba(1, 1, 1, 0.12); Layout.leftMargin: 6; Layout.rightMargin: 6 }
    component Seta: Rectangle {
        id: se
        property string glifo
        signal clicado()
        anchors.verticalCenter: parent.verticalCenter
        width: 40; height: 64; radius: 8
        color: ms.containsMouse ? Qt.rgba(0, 0, 0, 0.6) : Qt.rgba(0, 0, 0, 0.35)
        Text { anchors.centerIn: parent; text: se.glifo; color: "white"; font.pixelSize: 30 }
        MouseArea { id: ms; anchors.fill: parent; hoverEnabled: true; onClicked: se.clicado() }
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
        MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bt.clicked() }
    }

    component ItemMenu: MenuItem {
        id: im
        property string atalho
        implicitHeight: 32
        contentItem: RowLayout {
            spacing: 24
            Text { text: im.text; color: im.enabled ? "#f2f0f6" : "#77737f"; Layout.fillWidth: true; leftPadding: im.checkable ? 22 : 4 }
            Text { text: im.atalho; color: "#a8a3b6"; font.pixelSize: 12; visible: im.atalho !== ""; rightPadding: 4 }
        }
    }
}
