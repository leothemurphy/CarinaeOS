// CarinaeOS — Leitor de PDF
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Pdf

ApplicationWindow {
    id: janela
    width: 1100; height: 780
    minimumWidth: 560; minimumHeight: 380
    visible: true
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"
    title: leitor.nome ? (doc.title || leitor.nome) + " — Carinae PDF" : "Carinae PDF"
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
    readonly property bool pronto: doc.status === PdfDocument.Ready
    property bool lateral: width > 900
    property string ajuste: "largura"       // largura | pagina | livre

    function aviso(t) { toast.texto = t; toast.opacity = 1; esconderToast.restart(); }
    Connections { target: leitor; function onAviso(t) { janela.aviso(t); } }

    PdfDocument {
        id: doc
        source: leitor.url
        onPasswordRequired: senha.abrir()
        onStatusChanged: if (doc.status === PdfDocument.Ready) Qt.callLater(janela.reajustar)
    }

    function reajustar() {
        if (ajuste === "largura") vista.scaleToWidth(vista.width - 20, vista.height);
        else if (ajuste === "pagina") vista.scaleToPage(vista.width, vista.height);
    }
    function zoom(f) {
        ajuste = "livre";
        vista.renderScale = Math.max(0.1, Math.min(8, vista.renderScale * f));
    }

    Shortcut { sequence: "Ctrl+O"; onActivated: leitor.escolher() }
    Shortcut { sequence: "Ctrl+F"; onActivated: { busca.forceActiveFocus(); busca.selectAll(); } }
    Shortcut { sequences: ["F3", "Ctrl+G"]; onActivated: vista.searchForward() }
    Shortcut { sequences: ["Shift+F3", "Ctrl+Shift+G"]; onActivated: vista.searchBack() }
    Shortcut { sequences: ["Ctrl+=", "Ctrl++"]; onActivated: janela.zoom(1.2) }
    Shortcut { sequence: "Ctrl+-"; onActivated: janela.zoom(1 / 1.2) }
    Shortcut { sequence: "Ctrl+0"; onActivated: { janela.ajuste = "largura"; janela.reajustar(); } }
    Shortcut { sequence: "Ctrl+P"; onActivated: if (janela.pronto) impressao.abrir() }
    Shortcut { sequence: "Ctrl+C"; enabled: !busca.activeFocus && !pagCampo.activeFocus; onActivated: vista.copySelectionToClipboard() }
    Shortcut { sequence: "Ctrl+A"; enabled: !busca.activeFocus && !pagCampo.activeFocus; onActivated: vista.selectAll() }
    Shortcut { sequence: "F9"; onActivated: janela.lateral = !janela.lateral }
    Shortcut { sequence: "F11"; onActivated: janela.visibility = janela.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen }
    Shortcut { sequence: "Escape"; onActivated: { if (janela.visibility === Window.FullScreen) janela.visibility = Window.Windowed; else if (busca.text) busca.text = ""; } }
    Shortcut { sequences: ["Ctrl+Home"]; onActivated: vista.goToPage(0) }
    Shortcut { sequences: ["Ctrl+End"]; onActivated: vista.goToPage(doc.pageCount - 1) }
    Shortcut { sequence: "Alt+Left"; onActivated: vista.back() }
    Shortcut { sequence: "Alt+Right"; onActivated: vista.forward() }
    Shortcut { sequence: "Ctrl+R"; onActivated: vista.pageRotation = (vista.pageRotation + 90) % 360 }

    Rectangle {
        id: moldura
        anchors.fill: parent
        radius: janela.maximizada ? 0 : 10
        color: janela.fundo
        border.width: janela.maximizada ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.09)
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: moldura.border.width
            spacing: 0

            // ---- título --------------------------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 40
                visible: janela.visibility !== Window.FullScreen
                color: janela.barra
                topLeftRadius: moldura.radius; topRightRadius: moldura.radius
                MouseArea {
                    anchors.fill: parent
                    onPressed: janela.startSystemMove()
                    onDoubleClicked: janela.visibility = janela.maximizada ? Window.Windowed : Window.Maximized
                }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 14; spacing: 8
                    Text { text: "Carinae PDF"; color: janela.suave }
                    Text { text: doc.title || leitor.nome; color: janela.texto; elide: Text.ElideMiddle; Layout.fillWidth: true; font.weight: Font.DemiBold }
                    BotaoJanela { texto: "—"; onClicado: janela.showMinimized() }
                    BotaoJanela { texto: janela.maximizada ? "❐" : "☐"; onClicado: janela.visibility = janela.maximizada ? Window.Windowed : Window.Maximized }
                    BotaoJanela { texto: "✕"; perigo: true; onClicado: janela.close() }
                }
            }
            // ---- ferramentas ---------------------------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 46
                color: janela.barra
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.06) }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 8; anchors.rightMargin: 8; spacing: 4
                    Ferramenta { glifo: "☰"; dica: "Miniaturas e índice (F9)"; ativo: janela.lateral; onClicado: janela.lateral = !janela.lateral }
                    Separador {}
                    // página atual / total
                    Rectangle {
                        Layout.preferredWidth: 54; Layout.preferredHeight: 30; radius: 6
                        color: Qt.rgba(1, 1, 1, 0.06); border.color: pagCampo.activeFocus ? janela.realce : "transparent"
                        TextInput {
                            id: pagCampo
                            anchors.fill: parent; anchors.margins: 4
                            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            color: janela.texto; selectByMouse: true
                            validator: IntValidator { bottom: 1; top: Math.max(1, doc.pageCount) }
                            text: janela.pronto ? String(vista.currentPage + 1) : "–"
                            onAccepted: { vista.goToPage(parseInt(text) - 1); vista.forceActiveFocus(); }
                        }
                    }
                    Text { text: "de " + (janela.pronto ? doc.pageCount : "–"); color: janela.suave; Layout.rightMargin: 4 }
                    Separador {}
                    Ferramenta { glifo: "−"; dica: "Diminuir (Ctrl+−)"; onClicado: janela.zoom(1 / 1.2) }
                    Rectangle {
                        Layout.preferredWidth: 60; Layout.preferredHeight: 30; radius: 6
                        color: mz.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
                        Text { anchors.centerIn: parent; text: Math.round(vista.renderScale * 100) + "%"; color: janela.texto }
                        MouseArea { id: mz; anchors.fill: parent; hoverEnabled: true; onClicked: menuZoom.popup() }
                    }
                    Ferramenta { glifo: "+"; dica: "Aumentar (Ctrl+=)"; onClicado: janela.zoom(1.2) }
                    Ferramenta { glifo: "↔"; dica: "Ajustar à largura (Ctrl+0)"; ativo: janela.ajuste === "largura"; onClicado: { janela.ajuste = "largura"; janela.reajustar(); } }
                    Ferramenta { glifo: "▯"; dica: "Página inteira"; ativo: janela.ajuste === "pagina"; onClicado: { janela.ajuste = "pagina"; janela.reajustar(); } }
                    Ferramenta { glifo: "↻"; dica: "Girar (Ctrl+R)"; onClicado: vista.pageRotation = (vista.pageRotation + 90) % 360 }
                    Item { Layout.fillWidth: true }
                    // pesquisa
                    Rectangle {
                        Layout.preferredWidth: Math.min(300, janela.width * 0.28); Layout.preferredHeight: 30; radius: 6
                        color: Qt.rgba(1, 1, 1, 0.06); border.color: busca.activeFocus ? janela.realce : "transparent"
                        Text { x: 9; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: janela.suave; font.pixelSize: 15 }
                        TextField {
                            id: busca
                            anchors.left: parent.left; anchors.leftMargin: 22; anchors.right: contagem.left
                            anchors.verticalCenter: parent.verticalCenter
                            placeholderText: "Procurar no documento (Ctrl+F)"; placeholderTextColor: janela.suave
                            color: janela.texto; background: null
                            onAccepted: vista.searchForward()
                            Keys.onPressed: (ev) => { if (ev.key === Qt.Key_Return && (ev.modifiers & Qt.ShiftModifier)) { vista.searchBack(); ev.accepted = true; } }
                        }
                        Text {
                            id: contagem
                            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                            visible: busca.text.length > 0
                            text: vista.searchModel.count > 0 ? (vista.searchModel.currentResult + 1) + "/" + vista.searchModel.count : "0"
                            color: janela.suave; font.pixelSize: 12
                        }
                    }
                    Ferramenta { glifo: "⌃"; dica: "Anterior (Shift+F3)"; visible: busca.text.length > 0; onClicado: vista.searchBack() }
                    Ferramenta { glifo: "⌄"; dica: "Seguinte (F3)"; visible: busca.text.length > 0; onClicado: vista.searchForward() }
                    Separador {}
                    Ferramenta { glifo: "⎙"; dica: "Imprimir (Ctrl+P)"; enabled: janela.pronto; onClicado: impressao.abrir() }
                    Ferramenta { glifo: "⋯"; dica: "Mais"; onClicado: menuMais.popup() }
                }
            }

            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
                // ---- miniaturas e índice -----------------------------------------------------------
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: janela.lateral && janela.pronto ? 230 : 0
                    visible: Layout.preferredWidth > 0
                    color: janela.barra
                    ColumnLayout {
                        anchors.fill: parent; spacing: 0
                        RowLayout {
                            Layout.fillWidth: true; Layout.margins: 8; spacing: 4
                            Aba { texto: "Páginas"; ativo: lado.currentIndex === 0; onClicado: lado.currentIndex = 0 }
                            Aba { texto: "Índice"; ativo: lado.currentIndex === 1; onClicado: lado.currentIndex = 1; visible: marcadores.rowCount() > 0 }
                        }
                        StackLayout {
                            id: lado
                            Layout.fillWidth: true; Layout.fillHeight: true
                            ListView {
                                id: miniaturas
                                clip: true; spacing: 10
                                model: janela.pronto ? doc.pageCount : 0
                                currentIndex: vista.currentPage
                                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                                ScrollBar.vertical: ScrollBar {}
                                delegate: Item {
                                    width: miniaturas.width; height: img.height + 26
                                    Rectangle {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 2; width: img.width + 8; height: img.height + 8; radius: 4
                                        color: "transparent"; border.width: 2
                                        border.color: index === vista.currentPage ? janela.realce : "transparent"
                                    }
                                    Rectangle { x: img.x; y: img.y; width: img.width; height: img.height; color: "white" }
                                    PdfPageImage {
                                        id: img
                                        document: doc
                                        currentFrame: index
                                        asynchronous: true
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        y: 6
                                        readonly property size tam: doc.pagePointSize(index)
                                        width: 150; height: tam.width > 0 ? 150 * tam.height / tam.width : 200
                                        sourceSize.width: 300
                                        fillMode: Image.PreserveAspectFit
                                    }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; text: index + 1; color: janela.suave; font.pixelSize: 11 }
                                    MouseArea { anchors.fill: parent; onClicked: vista.goToPage(index) }
                                }
                            }
                            TreeView {
                                id: indice
                                clip: true
                                model: PdfBookmarkModel { id: marcadores; document: doc }
                                ScrollBar.vertical: ScrollBar {}
                                delegate: Item {
                                    id: nodo
                                    required property TreeView treeView
                                    required property bool isTreeNode
                                    required property bool expanded
                                    required property bool hasChildren
                                    required property int depth
                                    required property int row
                                    required property var model
                                    implicitWidth: indice.width; implicitHeight: 30
                                    Text {
                                        x: 6 + nodo.depth * 14; width: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: nodo.hasChildren; text: nodo.expanded ? "▾" : "▸"; color: janela.suave
                                        MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: nodo.treeView.toggleExpanded(nodo.row) }
                                    }
                                    Text {
                                        x: 22 + nodo.depth * 14; width: parent.width - x - 8
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: nodo.model.title; color: janela.texto; elide: Text.ElideRight
                                    }
                                    MouseArea {
                                        anchors.fill: parent; anchors.leftMargin: 20 + nodo.depth * 14
                                        onClicked: vista.goToLocation(nodo.model.page, nodo.model.location, nodo.model.zoom)
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- as páginas -------------------------------------------------------------------
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    PdfMultiPageView {
                        id: vista
                        anchors.fill: parent
                        document: doc
                        searchString: busca.text
                        visible: janela.pronto
                        onWidthChanged: if (janela.ajuste !== "livre") Qt.callLater(janela.reajustar)
                    }
                    // Ctrl + roda: zoom (a roda sozinha rola as páginas)
                    WheelHandler {
                        target: null
                        acceptedModifiers: Qt.ControlModifier
                        onWheel: (ev) => janela.zoom(ev.angleDelta.y > 0 ? 1.1 : 1 / 1.1)
                    }
                    // sem documento
                    Column {
                        anchors.centerIn: parent; spacing: 14
                        visible: !janela.pronto
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "📄"; font.pixelSize: 54; opacity: 0.6 }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter; color: janela.suave; horizontalAlignment: Text.AlignHCenter
                            text: doc.status === PdfDocument.Error && leitor.arquivo ? "Não foi possível abrir este arquivo." :
                                  doc.status === PdfDocument.Loading ? "A abrir…" : "Arraste um PDF para aqui ou"
                        }
                        Botao { anchors.horizontalCenter: parent.horizontalCenter; text: "Abrir um PDF…"; highlighted: true; onClicked: leitor.escolher() }
                    }
                    DropArea {
                        anchors.fill: parent
                        keys: ["text/uri-list"]
                        onDropped: (ev) => { if (ev.hasUrls) leitor.abrir(decodeURIComponent(String(ev.urls[0]).replace("file://", ""))); }
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

        Rectangle {
            id: toast
            property string texto
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 40
            width: tt.implicitWidth + 32; height: 42; radius: 10
            color: "#2f2d38"; border.color: Qt.rgba(1, 1, 1, 0.1)
            opacity: 0; visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Timer { id: esconderToast; interval: 4500; onTriggered: toast.opacity = 0 }
            Text { id: tt; anchors.centerIn: parent; text: toast.texto; color: janela.texto }
        }
    }

    Menu {
        id: menuZoom
        Repeater {
            model: [50, 75, 100, 125, 150, 200, 300]
            ItemMenu { text: modelData + "%"; onTriggered: { janela.ajuste = "livre"; vista.renderScale = modelData / 100; } }
        }
        MenuSeparator {}
        ItemMenu { text: "Ajustar à largura"; onTriggered: { janela.ajuste = "largura"; janela.reajustar(); } }
        ItemMenu { text: "Página inteira"; onTriggered: { janela.ajuste = "pagina"; janela.reajustar(); } }
    }
    Menu {
        id: menuMais
        ItemMenu { text: "Abrir…"; atalho: "Ctrl+O"; onTriggered: leitor.escolher() }
        ItemMenu { text: "Imprimir…"; atalho: "Ctrl+P"; enabled: janela.pronto; onTriggered: impressao.abrir() }
        MenuSeparator {}
        ItemMenu { text: "Copiar o texto selecionado"; atalho: "Ctrl+C"; onTriggered: vista.copySelectionToClipboard() }
        ItemMenu { text: "Selecionar tudo"; atalho: "Ctrl+A"; onTriggered: vista.selectAll() }
        MenuSeparator {}
        ItemMenu { text: "Mostrar na pasta"; enabled: !!leitor.arquivo; onTriggered: leitor.mostrarNaPasta() }
        ItemMenu { text: "Copiar o caminho"; enabled: !!leitor.arquivo; onTriggered: leitor.copiarCaminho() }
        ItemMenu { text: "Propriedades"; enabled: janela.pronto; onTriggered: propriedades.open() }
        MenuSeparator {}
        ItemMenu { text: "Ecrã inteiro"; atalho: "F11"; onTriggered: janela.visibility = janela.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen }
    }

    // ---- senha --------------------------------------------------------------------------------------
    Dialogo {
        id: senha
        titulo: "Este PDF tem senha"
        function abrir() { campoSenha.text = ""; open(); campoSenha.forceActiveFocus(); }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 10
            Text { text: "Escreva a senha para abrir \"" + leitor.nome + "\"."; color: janela.suave; wrapMode: Text.Wrap; Layout.fillWidth: true }
            Campo { id: campoSenha; Layout.fillWidth: true; echoMode: TextInput.Password; onAccepted: okSenha.clicked() }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                Botao { text: "Cancelar"; onClicked: senha.close() }
                Botao { id: okSenha; text: "Abrir"; highlighted: true; onClicked: { doc.password = campoSenha.text; senha.close(); } }
            }
        }
    }

    // ---- imprimir -----------------------------------------------------------------------------------
    Dialogo {
        id: impressao
        titulo: "Imprimir"
        function abrir() { leitor.lerImpressoras(); paginas.text = ""; copias.value = 1; open(); }
        GridLayout {
            Layout.fillWidth: true; columns: 2; columnSpacing: 14; rowSpacing: 10
            Text { text: "Impressora"; color: janela.suave }
            ComboBox {
                id: impressora
                Layout.fillWidth: true
                model: leitor.impressoras
                currentIndex: Math.max(0, leitor.impressoras.indexOf(leitor.impressoraPadrao))
                displayText: count ? currentText : "Nenhuma impressora encontrada"
            }
            Text { text: "Páginas"; color: janela.suave }
            Campo { id: paginas; Layout.fillWidth: true; placeholderText: "Todas  (ou por ex. 1-3, 5)" }
            Text { text: "Cópias"; color: janela.suave }
            SpinBox { id: copias; from: 1; to: 99; value: 1 }
            Item { width: 1 }
            CheckBox { id: frenteVerso; text: "Frente e verso" }
            Item { width: 1 }
            CheckBox { id: cores; text: "A cores"; checked: true }
        }
        RowLayout {
            Layout.alignment: Qt.AlignRight
            Botao { text: "Cancelar"; onClicked: impressao.close() }
            Botao {
                text: "Imprimir"; highlighted: true; enabled: impressora.count > 0
                onClicked: { leitor.imprimir(impressora.currentText, paginas.text, copias.value, frenteVerso.checked, cores.checked); impressao.close(); }
            }
        }
    }

    Dialogo {
        id: propriedades
        titulo: "Propriedades"
        GridLayout {
            Layout.fillWidth: true; columns: 2; columnSpacing: 14; rowSpacing: 8
            Repeater {
                model: [["Arquivo", leitor.nome], ["Título", doc.title], ["Autor", doc.author], ["Assunto", doc.subject],
                        ["Criado com", doc.creator], ["Produtor", doc.producer], ["Páginas", String(doc.pageCount)],
                        ["Criado em", doc.creationDate ? doc.creationDate.toLocaleString(Qt.locale(), Locale.ShortFormat) : ""],
                        ["Modificado em", doc.modificationDate ? doc.modificationDate.toLocaleString(Qt.locale(), Locale.ShortFormat) : ""]]
                delegate: Item {
                    required property var modelData
                    Layout.columnSpan: 2; Layout.fillWidth: true
                    implicitHeight: modelData[1] ? linha.implicitHeight : 0
                    visible: !!modelData[1]
                    RowLayout {
                        id: linha; width: parent.width; spacing: 14
                        Text { text: modelData[0]; color: janela.suave; Layout.preferredWidth: 110 }
                        Text { text: modelData[1] || ""; color: janela.texto; Layout.fillWidth: true; wrapMode: Text.WrapAnywhere }
                    }
                }
            }
        }
        Botao { Layout.alignment: Qt.AlignRight; text: "Fechar"; onClicked: propriedades.close() }
    }

    component Dialogo: Popup {
        id: dl
        property string titulo
        default property alias conteudo: col.data
        anchors.centerIn: parent
        width: Math.min(440, janela.width - 40); modal: true; padding: 22
        background: Rectangle { radius: 10; color: "#2b2a32"; border.color: Qt.rgba(1, 1, 1, 0.1) }
        ColumnLayout {
            id: col
            anchors.fill: parent; spacing: 14
            Text { text: dl.titulo; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold }
        }
    }
    component Campo: TextField {
        color: janela.texto; placeholderTextColor: janela.suave
        background: Rectangle { radius: 6; color: Qt.rgba(1, 1, 1, 0.06); border.color: parent.activeFocus ? janela.realce : Qt.rgba(1, 1, 1, 0.1) }
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
        Layout.preferredWidth: 36; Layout.preferredHeight: 32; radius: 6
        opacity: enabled ? 1 : 0.4
        color: ativo ? Qt.rgba(0.48, 0.65, 1, 0.22) : (mfe.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
        Text { anchors.centerIn: parent; text: fe.glifo; color: janela.texto; font.pixelSize: 16 }
        MouseArea { id: mfe; anchors.fill: parent; hoverEnabled: true; onClicked: fe.clicado() }
        ToolTip.visible: mfe.containsMouse; ToolTip.text: dica; ToolTip.delay: 500
    }
    component Separador: Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 22; color: Qt.rgba(1, 1, 1, 0.12); Layout.leftMargin: 4; Layout.rightMargin: 4 }
    component Aba: Rectangle {
        id: ab
        property string texto
        property bool ativo
        signal clicado()
        Layout.fillWidth: true; Layout.preferredHeight: 30; radius: 6
        color: ativo ? Qt.rgba(1, 1, 1, 0.09) : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
        Text { anchors.centerIn: parent; text: ab.texto; color: ab.ativo ? janela.texto : janela.suave }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: ab.clicado() }
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
