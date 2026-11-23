// CarinaeOS — Carinae Calculadora (no jeito da Calculadora do Windows 11)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: janela
    width: 340; height: 560
    minimumWidth: 320; minimumHeight: 500
    visible: true
    property bool fixa: false
    flags: Qt.Window | Qt.FramelessWindowHint | (fixa ? Qt.WindowStaysOnTopHint : 0)
    color: "transparent"
    title: "Carinae Calculadora"
    font.family: "Inter"; font.pixelSize: 14
    // as cores dos controlos padrão (menus, caixas, listas) no tema escuro do CarinaeOS
    palette.window: "#2b2a32"; palette.windowText: "#f2f0f6"; palette.base: "#24232a"; palette.alternateBase: "#2b2a32"
    palette.text: "#f2f0f6"; palette.button: "#3a3942"; palette.buttonText: "#f2f0f6"; palette.brightText: "#ffffff"
    palette.highlight: "#7aa7ff"; palette.highlightedText: "#10131c"; palette.light: "#4a4952"; palette.midlight: "#3f3e47"
    palette.mid: "#55535f"; palette.dark: "#1c1b21"; palette.shadow: "#000000"; palette.toolTipBase: "#2f2e37"; palette.toolTipText: "#f2f0f6"
    palette.placeholderText: "#8a8597"

    readonly property color fundo: "#1f1e25"
    readonly property color teclaNum: "#3a3942"
    readonly property color teclaOp: "#2d2c34"
    readonly property color texto: "#f2f0f6"
    readonly property color suave: "#a8a3b6"
    readonly property color realce: "#7aa7ff"
    readonly property bool cientifica: calc.modo === "cientifica"
    readonly property bool maximizada: visibility === Window.Maximized
    readonly property bool lateral: width >= 600
    property bool segunda: false
    property bool menuAberto: false

    Component.onCompleted: if (cientifica) { width = 400; height = 640; }

    // ---- teclado -------------------------------------------------------------------------------------
    Item {
        id: teclas
        focus: true
        Keys.onPressed: (ev) => {
            const t = ev.text;
            const ctrl = ev.modifiers & Qt.ControlModifier;
            if (ctrl && ev.key === Qt.Key_C) calc.copiar();
            else if (ctrl && ev.key === Qt.Key_V) calc.colar();
            else if (ctrl && ev.key === Qt.Key_H) janela.width = janela.lateral ? (janela.cientifica ? 400 : 340) : 680;
            else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter || t === "=") calc.tecla("=");
            else if (ev.key === Qt.Key_Backspace) calc.tecla("⌫");
            else if (ev.key === Qt.Key_Escape) calc.tecla("C");
            else if (ev.key === Qt.Key_Delete) calc.tecla("CE");
            else if (ev.key === Qt.Key_F9) calc.tecla("±");
            else if (/^[0-9]$/.test(t)) calc.tecla(t);
            else if (t === "," || t === ".") calc.tecla(",");
            else if (t === "+") calc.tecla("+");
            else if (t === "-") calc.tecla("-");
            else if (t === "*" || t === "x") calc.tecla("×");
            else if (t === "/") calc.tecla("÷");
            else if (t === "%") calc.tecla("%");
            else if (t === "^") calc.tecla("^");
            else if (t === "(") calc.tecla("(");
            else if (t === ")") calc.tecla(")");
            else if (t === "r") calc.tecla("1/x");
            else if (t === "@") calc.tecla("√x");
            else if (t === "q") calc.tecla("x²");
            else if (t === "!") calc.tecla("n!");
            else if (t === "p") calc.tecla("π");
            else return;
            ev.accepted = true;
        }
    }
    onActiveChanged: if (active) teclas.forceActiveFocus()

    Rectangle {
        id: moldura
        anchors.fill: parent
        radius: janela.maximizada ? 0 : 10
        color: janela.fundo
        border.width: janela.maximizada ? 0 : 1
        border.color: Qt.rgba(1, 1, 1, 0.09)
        clip: true

        RowLayout {
            anchors.fill: parent; anchors.margins: moldura.border.width; spacing: 0

            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                Layout.preferredWidth: janela.lateral ? janela.width - 300 : janela.width
                spacing: 0

                // ---- título --------------------------------------------------------------------------
                Item {
                    Layout.fillWidth: true; Layout.preferredHeight: 40
                    MouseArea { anchors.fill: parent; onPressed: janela.startSystemMove() }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 4; spacing: 2
                        Pequeno { glifo: "☰"; onClicado: janela.menuAberto = !janela.menuAberto }
                        Text { text: janela.cientifica ? "Científica" : "Padrão"; color: janela.texto; font.pixelSize: 18; font.weight: Font.DemiBold; Layout.leftMargin: 4 }
                        Pequeno { glifo: "⧉"; dica: janela.fixa ? "Deixar de ficar por cima" : "Ficar sempre por cima"; ativo: janela.fixa; onClicado: janela.fixa = !janela.fixa }
                        Item { Layout.fillWidth: true }
                        Pequeno { glifo: "↺"; dica: "Histórico (Ctrl+H)"; visible: !janela.lateral; onClicado: painelHist.open() }
                        BotaoJanela { texto: "—"; onClicado: janela.showMinimized() }
                        BotaoJanela { texto: "✕"; perigo: true; onClicado: janela.close() }
                    }
                }

                // ---- visor ----------------------------------------------------------------------------
                Text {
                    Layout.fillWidth: true; Layout.rightMargin: 16; Layout.leftMargin: 16; Layout.topMargin: 6
                    horizontalAlignment: Text.AlignRight
                    text: calc.expressao; color: janela.suave; font.pixelSize: 14; elide: Text.ElideLeft
                }
                Text {
                    id: visor
                    Layout.fillWidth: true; Layout.rightMargin: 14; Layout.leftMargin: 14
                    Layout.preferredHeight: 70
                    horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                    text: calc.visor; color: janela.texto
                    font.weight: Font.DemiBold
                    font.pixelSize: calc.temErro ? 24 : 48
                    fontSizeMode: Text.HorizontalFit; minimumPixelSize: 18
                    MouseArea {
                        anchors.fill: parent; acceptedButtons: Qt.RightButton
                        onClicked: menuVisor.popup()
                    }
                }

                // ---- memória ---------------------------------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true; Layout.leftMargin: 4; Layout.rightMargin: 4; spacing: 0
                    Repeater {
                        model: ["MC", "MR", "M+", "M-", "MS"]
                        TextoBotao {
                            Layout.fillWidth: true; texto: modelData
                            enabled: !calc.temErro && ((modelData !== "MC" && modelData !== "MR") || calc.memoria.length > 0)
                            onClicado: calc.mem(modelData)
                        }
                    }
                    TextoBotao { Layout.fillWidth: true; texto: "M˅"; enabled: calc.memoria.length > 0 && !janela.lateral; onClicado: { lado.aba = 1; painelHist.open(); } }
                }

                // ---- científica: graus e trigonometria ------------------------------------------------
                RowLayout {
                    visible: janela.cientifica
                    Layout.fillWidth: true; Layout.leftMargin: 4; Layout.rightMargin: 4; spacing: 0
                    TextoBotao { texto: calc.graus ? "DEG" : "RAD"; onClicado: calc.alternarGraus(); Layout.preferredWidth: 60 }
                    TextoBotao { texto: janela.segunda ? "sin⁻¹" : "sin"; onClicado: calc.tecla(texto); Layout.fillWidth: true }
                    TextoBotao { texto: janela.segunda ? "cos⁻¹" : "cos"; onClicado: calc.tecla(texto); Layout.fillWidth: true }
                    TextoBotao { texto: janela.segunda ? "tan⁻¹" : "tan"; onClicado: calc.tecla(texto); Layout.fillWidth: true }
                }

                // ---- teclas ---------------------------------------------------------------------------
                GridLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    Layout.margins: 4
                    columns: janela.cientifica ? 5 : 4
                    rowSpacing: 2; columnSpacing: 2
                    Repeater {
                        model: janela.cientifica ? [
                            [janela.segunda ? "2ⁿᵈ" : "2ⁿᵈ", "f"], ["π", "f"], ["e", "f"], ["C", "f"], ["⌫", "f"],
                            [janela.segunda ? "x³" : "x²", "f"], ["1/x", "f"], ["|x|", "f"], ["(", "f"], [")", "f"],
                            [janela.segunda ? "∛x" : "√x", "f"], ["n!", "f"], ["mod", "f"], ["%", "f"], ["÷", "op"],
                            ["xʸ", "f"], ["7", "n"], ["8", "n"], ["9", "n"], ["×", "op"],
                            ["10ˣ", "f"], ["4", "n"], ["5", "n"], ["6", "n"], ["−", "op"],
                            ["log", "f"], ["1", "n"], ["2", "n"], ["3", "n"], ["+", "op"],
                            [janela.segunda ? "eˣ" : "ln", "f"], ["±", "n"], ["0", "n"], [",", "n"], ["=", "igual"]
                        ] : [
                            ["%", "f"], ["CE", "f"], ["C", "f"], ["⌫", "f"],
                            ["1/x", "f"], ["x²", "f"], ["√x", "f"], ["÷", "op"],
                            ["7", "n"], ["8", "n"], ["9", "n"], ["×", "op"],
                            ["4", "n"], ["5", "n"], ["6", "n"], ["−", "op"],
                            ["1", "n"], ["2", "n"], ["3", "n"], ["+", "op"],
                            ["±", "n"], ["0", "n"], [",", "n"], ["=", "igual"]
                        ]
                        Tecla {
                            required property var modelData
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Layout.preferredWidth: 10; Layout.preferredHeight: 10
                            texto: modelData[0]; tipo: modelData[1]
                            ativo: texto === "2ⁿᵈ" && janela.segunda
                            onClicado: {
                                if (texto === "2ⁿᵈ") { janela.segunda = !janela.segunda; return; }
                                const mapa = { "−": "-", "xʸ": "^" };
                                calc.tecla(mapa[texto] || texto);
                                if (janela.segunda && tipo === "f") janela.segunda = false;
                            }
                        }
                    }
                }
            }

            // ---- histórico e memória (ao lado, quando a janela é larga) -------------------------------
            Rectangle {
                Layout.fillHeight: true; Layout.preferredWidth: 300
                visible: janela.lateral
                color: Qt.rgba(0, 0, 0, 0.12)
                Lado { id: ladoFixo; anchors.fill: parent; anchors.topMargin: 40 }
                RowLayout {
                    anchors.top: parent.top; anchors.right: parent.right; height: 40; spacing: 0
                    MouseArea { Layout.fillWidth: true; Layout.fillHeight: true; onPressed: janela.startSystemMove() }
                }
            }
        }

        // menu dos modos
        Rectangle {
            visible: janela.menuAberto
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.4)
            MouseArea { anchors.fill: parent; onClicked: janela.menuAberto = false }
            Rectangle {
                width: 240; height: parent.height; color: "#27262e"
                Column {
                    anchors.fill: parent; anchors.topMargin: 48; anchors.margins: 6; spacing: 2
                    Text { text: "Calculadora"; color: janela.suave; font.pixelSize: 12; leftPadding: 12; bottomPadding: 6 }
                    Repeater {
                        model: [["padrao", "▦  Padrão"], ["cientifica", "∑  Científica"]]
                        Rectangle {
                            width: parent.width; height: 40; radius: 6
                            color: calc.modo === modelData[0] ? Qt.rgba(1, 1, 1, 0.09) : (mm.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                            Rectangle { visible: calc.modo === modelData[0]; width: 3; height: 16; radius: 2; color: janela.realce; anchors.verticalCenter: parent.verticalCenter }
                            Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: modelData[1]; color: janela.texto }
                            MouseArea {
                                id: mm; anchors.fill: parent; hoverEnabled: true
                                onClicked: {
                                    calc.mudarModo(modelData[0]); janela.menuAberto = false;
                                    if (modelData[0] === "cientifica" && janela.width < 400) { janela.width = 400; janela.height = Math.max(janela.height, 640); }
                                }
                            }
                        }
                    }
                }
            }
        }

        // as bordas para redimensionar
        Repeater {
            model: janela.maximizada ? [] : [
                { b: Qt.RightEdge, x: -5, y: 8, w: 5, h: -16, c: Qt.SizeHorCursor },
                { b: Qt.LeftEdge, x: 0, y: 8, w: 5, h: -16, c: Qt.SizeHorCursor },
                { b: Qt.BottomEdge, x: 8, y: -5, w: -16, h: 5, c: Qt.SizeVerCursor },
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

    // histórico/memória por cima (janela estreita)
    Popup {
        id: painelHist
        x: 0; y: janela.height * 0.35; width: janela.width; height: janela.height * 0.65
        padding: 0; modal: true
        background: Rectangle { color: "#27262e"; radius: 10 }
        Lado { id: lado; anchors.fill: parent }
        onClosed: teclas.forceActiveFocus()
    }

    Menu {
        id: menuVisor
        MenuItem { text: "Copiar   (Ctrl+C)"; onTriggered: calc.copiar() }
        MenuItem { text: "Colar   (Ctrl+V)"; onTriggered: calc.colar() }
    }

    component Lado: Item {
        id: ld
        property int aba: 0
        ColumnLayout {
            anchors.fill: parent; spacing: 0
            RowLayout {
                Layout.fillWidth: true; Layout.margins: 10; spacing: 16
                Repeater {
                    model: ["Histórico", "Memória"]
                    Text {
                        text: modelData; color: ld.aba === index ? janela.texto : janela.suave; font.weight: Font.DemiBold
                        Rectangle { visible: ld.aba === index; anchors.top: parent.bottom; anchors.topMargin: 3; width: parent.width * 0.6; height: 3; radius: 2; color: janela.realce }
                        MouseArea { anchors.fill: parent; onClicked: ld.aba = index }
                    }
                }
            }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                model: ld.aba === 0 ? calc.historico : calc.memoria
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    width: ListView.view.width; height: ld.aba === 0 ? 64 : 70
                    color: hm.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"
                    MouseArea {
                        id: hm; anchors.fill: parent; hoverEnabled: true
                        onClicked: { if (ld.aba === 0) calc.usarHistorico(index); else calc.memItem(index, "usar"); painelHist.close(); }
                    }
                    Column {
                        anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                        Text { anchors.right: parent.right; visible: ld.aba === 0; text: ld.aba === 0 ? modelData.expressao : ""; color: janela.suave; font.pixelSize: 12 }
                        Text { anchors.right: parent.right; text: ld.aba === 0 ? modelData.resultado : modelData; color: janela.texto; font.pixelSize: 20; font.weight: Font.DemiBold }
                        Row {
                            anchors.right: parent.right; spacing: 4
                            visible: ld.aba === 1 && hm.containsMouse
                            TextoBotao { texto: "MC"; onClicado: calc.memItem(index, "apagar") }
                            TextoBotao { texto: "M+"; onClicado: calc.memItem(index, "+") }
                            TextoBotao { texto: "M-"; onClicado: calc.memItem(index, "-") }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent; visible: parent.count === 0; color: janela.suave
                    text: ld.aba === 0 ? "Ainda não há histórico" : "Não há nada guardado na memória"
                }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.margins: 8
                Item { Layout.fillWidth: true }
                Pequeno { glifo: "🗑"; dica: "Limpar"; visible: (ld.aba === 0 ? calc.historico.length : calc.memoria.length) > 0
                          onClicado: ld.aba === 0 ? calc.limparHistorico() : calc.mem("MC") }
            }
        }
    }

    component Tecla: Rectangle {
        id: tc
        property string texto
        property string tipo: "n"
        property bool ativo
        signal clicado()
        radius: 6
        readonly property color base: tipo === "igual" ? janela.realce : (tipo === "n" ? janela.teclaNum : janela.teclaOp)
        color: ativo ? Qt.rgba(0.48, 0.65, 1, 0.35) : (mt.pressed ? Qt.darker(base, 1.15) : (mt.containsMouse ? Qt.lighter(base, 1.12) : base))
        opacity: enabled ? 1 : 0.4
        enabled: !calc.temErro || ["C", "CE", "⌫"].indexOf(texto) >= 0 || tipo === "n"
        Text {
            anchors.centerIn: parent; text: tc.texto
            color: tc.tipo === "igual" ? "#10131c" : janela.texto
            font.pixelSize: tc.tipo === "n" && /[0-9]/.test(tc.texto) ? 20 : 16
            font.weight: tc.tipo === "n" ? Font.DemiBold : Font.Normal
        }
        MouseArea { id: mt; anchors.fill: parent; hoverEnabled: true; onClicked: { tc.clicado(); teclas.forceActiveFocus(); } }
    }
    component TextoBotao: Rectangle {
        id: tb
        property string texto
        signal clicado()
        implicitWidth: 44; implicitHeight: 32; radius: 6
        opacity: enabled ? 1 : 0.35
        color: mtb.containsMouse && enabled ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
        Text { anchors.centerIn: parent; text: tb.texto; color: janela.texto; font.pixelSize: 13 }
        MouseArea { id: mtb; anchors.fill: parent; hoverEnabled: true; onClicked: { tb.clicado(); teclas.forceActiveFocus(); } }
    }
    component Pequeno: Rectangle {
        id: pq
        property string glifo
        property string dica
        property bool ativo
        signal clicado()
        Layout.preferredWidth: 36; Layout.preferredHeight: 32; implicitWidth: 36; implicitHeight: 32; radius: 6
        color: ativo ? Qt.rgba(0.48, 0.65, 1, 0.22) : (mp.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
        Text { anchors.centerIn: parent; text: pq.glifo; color: janela.texto; font.pixelSize: 16 }
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
}
