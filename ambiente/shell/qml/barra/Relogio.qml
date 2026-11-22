// CarinaeOS — relógio da barra de cima ("dom. 22 nov.  18:47"); clicar abre o calendário
// com os eventos (Agenda.qml: lembretes que só saem do ecrã depois de confirmar que foram lidos)
import QtQuick
import QtQuick.Layouts
import CarinaeOS.Compat as C

Item {
    id: relogio
    implicitWidth: texto.implicitWidth + 12
    property date agora: new Date()
    property date dia: new Date()          // o dia escolhido no calendário
    property var editando: null            // o evento no formulário (null = fechado)
    function novoEvento() {
        editando = { id: "", titulo: "", data: Agenda.chaveDia(dia), hora: "", aviso: 0, repetir: "", nota: "" };
    }

    readonly property color ambar: "#ffb46e"
    readonly property color claro: "#f6f2ff"
    readonly property color suave: "#b9b0cc"

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: relogio.agora = new Date()
    }
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        radius: 6
        color: Qt.rgba(1, 1, 1, rato.containsMouse || cal.visible ? 0.14 : 0)
    }
    Text {
        id: texto
        anchors.centerIn: parent
        text: Qt.locale().toString(relogio.agora, "ddd d MMM") + "   " + Qt.locale().toString(relogio.agora, "HH:mm")
        color: relogio.claro
        font.pixelSize: 13
        font.weight: Font.Medium
    }
    MouseArea {
        id: rato
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            if (!cal.visible) {
                folha.ano = relogio.agora.getFullYear(); folha.mes = relogio.agora.getMonth();
                relogio.dia = new Date(); relogio.editando = null;
            }
            cal.visible = !cal.visible;
        }
    }

    // ---- o calendário -------------------------------------------------------------------------
    QtObject {
        id: folha
        property int ano: new Date().getFullYear()
        property int mes: new Date().getMonth()
        function andar(n) {
            let m = mes + n, a = ano;
            while (m < 0) { m += 12; a--; }
            while (m > 11) { m -= 12; a++; }
            ano = a; mes = m;
        }
        // 42 dias (6 semanas) a começar no domingo
        readonly property var dias: {
            const primeiro = new Date(ano, mes, 1);
            const inicio = new Date(ano, mes, 1 - primeiro.getDay());
            const l = [];
            for (let i = 0; i < 42; i++) l.push(new Date(inicio.getFullYear(), inicio.getMonth(), inicio.getDate() + i).getTime());
            return l;
        }
    }

    C.Dialog {
        id: cal
        visualParent: relogio
        location: 3
        hideOnWindowDeactivate: true
        backgroundHints: 0
        mainItem: Rectangle {
            id: fundoCal
            width: 340
            height: coluna.implicitHeight + 32
            radius: 20
            color: Qt.rgba(0.09, 0.08, 0.13, 0.98)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            clip: true
            // um brilho de nebulosa atrás das horas
            Rectangle {
                width: parent.width; height: 120; radius: 20
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Qt.rgba(1, 0.71, 0.43, 0.22) }
                    GradientStop { position: 0.55; color: Qt.rgba(1, 0.44, 0.57, 0.16) }
                    GradientStop { position: 1; color: Qt.rgba(0.48, 0.36, 1, 0.20) }
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: Qt.rgba(0.09, 0.08, 0.13, 1) }
                    }
                }
            }

            ColumnLayout {
                id: coluna
                x: 16; y: 16
                width: parent.width - 32
                spacing: 10

                // hoje, em grande
                Column {
                    Text {
                        text: Qt.locale().toString(relogio.agora, "HH:mm")
                        color: relogio.claro; font.pixelSize: 44; font.weight: Font.Light
                    }
                    Text {
                        text: { const s = Qt.locale().toString(relogio.agora, "dddd, d 'de' MMMM 'de' yyyy"); return s.charAt(0).toUpperCase() + s.slice(1); }
                        color: relogio.suave; font.pixelSize: 13
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                // mês e setas
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: { const s = Qt.locale().standaloneMonthName(folha.mes, Locale.LongFormat); return s.charAt(0).toUpperCase() + s.slice(1) + " " + folha.ano; }
                        color: relogio.claro; font.pixelSize: 15; font.weight: Font.DemiBold
                    }
                    Seta { texto: "‹"; onClicado: folha.andar(-1) }
                    Rectangle {
                        width: hojeT.implicitWidth + 18; height: 26; radius: 13
                        color: Qt.rgba(1, 1, 1, hojeRato.containsMouse ? 0.14 : 0.07)
                        Text { id: hojeT; anchors.centerIn: parent; text: "Hoje"; color: relogio.claro; font.pixelSize: 12 }
                        MouseArea { id: hojeRato; anchors.fill: parent; hoverEnabled: true
                                    onClicked: { folha.ano = relogio.agora.getFullYear(); folha.mes = relogio.agora.getMonth(); } }
                    }
                    Seta { texto: "›"; onClicado: folha.andar(1) }
                }

                // dias da semana
                GridLayout {
                    columns: 7; columnSpacing: 0; rowSpacing: 2
                    Layout.fillWidth: true
                    Repeater {
                        model: 7
                        Text {
                            required property int index
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: Qt.locale().dayName(index, Locale.ShortFormat).charAt(0).toUpperCase()
                            color: index === 0 ? "#ff9ab2" : relogio.suave; font.pixelSize: 11; font.weight: Font.DemiBold
                        }
                    }
                    Repeater {
                        model: folha.dias
                        delegate: Item {
                            id: celula
                            required property var modelData       // ms
                            required property int index
                            readonly property var d: new Date(modelData)
                            readonly property bool doMes: d.getMonth() === folha.mes
                            readonly property bool hoje: d.toDateString() === relogio.agora.toDateString()
                            readonly property bool domingo: index % 7 === 0
                            Layout.fillWidth: true
                            height: 38
                            readonly property bool escolhido: d.toDateString() === relogio.dia.toDateString()
                            Rectangle {
                                anchors.centerIn: parent
                                width: 34; height: 34; radius: 17
                                color: diaRato.containsMouse && !celula.hoje ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                                border.width: celula.escolhido && !celula.hoje ? 1.5 : 0
                                border.color: relogio.ambar
                            }
                            Rectangle {      // hoje: círculo em degradê âmbar -> rosa
                                visible: celula.hoje
                                anchors.centerIn: parent
                                width: 34; height: 34; radius: 17
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: "#ffb46e" }
                                    GradientStop { position: 1; color: "#ff6f91" }
                                }
                            }
                            Rectangle {      // tem eventos
                                visible: Agenda.temEvento(celula.d)
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom; anchors.bottomMargin: 1
                                width: 4; height: 4; radius: 2
                                color: celula.hoje ? relogio.claro : relogio.ambar
                            }
                            Text {
                                anchors.centerIn: parent
                                text: celula.d.getDate()
                                color: celula.hoje ? "#1b1030" : !celula.doMes ? Qt.rgba(1, 1, 1, 0.25)
                                     : celula.domingo ? "#ff9ab2" : relogio.claro
                                font.pixelSize: 13
                                font.weight: celula.hoje ? Font.Bold : Font.Normal
                            }
                            MouseArea { id: diaRato; anchors.fill: parent; hoverEnabled: true
                                        onClicked: { relogio.dia = celula.d; relogio.editando = null; } }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                // ---- eventos do dia escolhido -------------------------------------------------
                RowLayout {
                    Layout.fillWidth: true
                    visible: relogio.editando === null
                    Text {
                        Layout.fillWidth: true
                        text: { const s = Qt.locale().toString(relogio.dia, "dddd, d 'de' MMMM"); return s.charAt(0).toUpperCase() + s.slice(1); }
                        color: relogio.claro; font.pixelSize: 13; font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Rectangle {
                        width: novoT.implicitWidth + 22; height: 28; radius: 14
                        color: novoRato.containsMouse ? "#ffc58c" : relogio.ambar
                        Text { id: novoT; anchors.centerIn: parent; text: "+ Novo evento"; color: "#1b1030"; font.pixelSize: 12; font.weight: Font.DemiBold }
                        MouseArea { id: novoRato; anchors.fill: parent; hoverEnabled: true; onClicked: relogio.novoEvento() }
                    }
                }
                Column {
                    Layout.fillWidth: true
                    visible: relogio.editando === null
                    spacing: 6
                    Text {
                        visible: Agenda.eventosDoDia(relogio.dia).length === 0
                        text: "Sem eventos neste dia"
                        color: relogio.suave; font.pixelSize: 12
                    }
                    Repeater {
                        model: Agenda.eventosDoDia(relogio.dia)
                        delegate: Rectangle {
                            id: linhaEv
                            required property var modelData
                            width: parent.width; height: 46; radius: 10
                            color: Qt.rgba(1, 1, 1, evRato.containsMouse ? 0.09 : 0.05)
                            Rectangle { x: 0; width: 4; height: parent.height; radius: 2; color: relogio.ambar }
                            Column {
                                x: 14; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 54
                                Text { text: linhaEv.modelData.titulo; color: relogio.claro; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
                                Text {
                                    width: parent.width; elide: Text.ElideRight
                                    color: relogio.suave; font.pixelSize: 11
                                    text: (linhaEv.modelData.hora || "Dia todo")
                                          + (linhaEv.modelData.repetir ? "  ·  ↻ " + Agenda.repeticoes.find(function (r) { return r[0] === linhaEv.modelData.repetir })[1] : "")
                                          + "  ·  🔔 " + Agenda.avisos.find(function (a) { return a[0] === (linhaEv.modelData.aviso || 0) })[1]
                                }
                            }
                            MouseArea { id: evRato; anchors.fill: parent; hoverEnabled: true
                                        onClicked: relogio.editando = Object.assign({}, linhaEv.modelData) }
                            Rectangle {      // apagar
                                anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
                                width: 26; height: 26; radius: 13
                                color: Qt.rgba(1, 0.43, 0.57, apagarRato.containsMouse ? 0.35 : 0)
                                Text { anchors.centerIn: parent; text: "🗑"; font.pixelSize: 12; color: relogio.claro }
                                MouseArea { id: apagarRato; anchors.fill: parent; hoverEnabled: true; onClicked: Agenda.apagarEvento(linhaEv.modelData.id) }
                            }
                        }
                    }
                }

                // ---- formulário (novo / editar) -------------------------------------------------
                Column {
                    id: formulario
                    Layout.fillWidth: true
                    visible: relogio.editando !== null
                    spacing: 8
                    readonly property var ev: relogio.editando || ({})
                    function mudar(k, v) { const e = Object.assign({}, relogio.editando); e[k] = v; relogio.editando = e; }

                    Text { text: formulario.ev.id ? "Editar evento" : "Novo evento"; color: relogio.claro; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Campo {
                        id: campoTitulo
                        width: parent.width
                        dica: "Título (ex.: Consulta no dentista)"
                        texto: formulario.ev.titulo || ""
                        onEditado: (t) => formulario.mudar("titulo", t)
                        Component.onCompleted: focar()
                    }
                    Row {
                        spacing: 8
                        Campo {
                            width: 86
                            dica: "Hora"
                            mascara: "99:99"
                            texto: formulario.ev.hora || ""
                            enabled: !diaTodo.ligado
                            onEditado: (t) => {
                                const m = t.match(/^(\d\d):(\d\d)$/);
                                if (m && +m[1] < 24 && +m[2] < 60) formulario.mudar("hora", t);
                            }
                        }
                        Escolha {
                            id: diaTodo
                            texto: "Dia todo"
                            ligado: !formulario.ev.hora
                            onClicado: formulario.mudar("hora", ligado ? "09:00" : "")
                        }
                    }
                    Text { text: "Avisar"; color: relogio.suave; font.pixelSize: 11 }
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: Agenda.avisos
                            Escolha { required property var modelData; texto: modelData[1]; ligado: (formulario.ev.aviso || 0) === modelData[0]
                                      onClicado: formulario.mudar("aviso", modelData[0]) }
                        }
                    }
                    Text { text: "Repetir"; color: relogio.suave; font.pixelSize: 11 }
                    Flow {
                        width: parent.width; spacing: 6
                        Repeater {
                            model: Agenda.repeticoes
                            Escolha { required property var modelData; texto: modelData[1]; ligado: (formulario.ev.repetir || "") === modelData[0]
                                      onClicado: formulario.mudar("repetir", modelData[0]) }
                        }
                    }
                    Campo {
                        width: parent.width
                        dica: "Nota (opcional)"
                        texto: formulario.ev.nota || ""
                        onEditado: (t) => formulario.mudar("nota", t)
                    }
                    Row {
                        anchors.right: parent.right
                        spacing: 8
                        Escolha { texto: "Cancelar"; onClicado: relogio.editando = null }
                        Escolha {
                            texto: "Guardar"; ligado: true
                            opacity: (formulario.ev.titulo || "").trim() !== "" ? 1 : 0.4
                            onClicado: {
                                if ((formulario.ev.titulo || "").trim() === "") { campoTitulo.focar(); return; }
                                const e = Object.assign({}, relogio.editando);
                                e.titulo = e.titulo.trim();
                                Agenda.guardarEvento(e);
                                relogio.editando = null;
                            }
                        }
                    }
                }
            }
        }
    }

    // caixa de texto
    component Campo: Rectangle {
        id: c
        property string dica
        property string texto
        property string mascara: ""
        signal editado(string t)
        function focar() { entrada.forceActiveFocus() }
        height: 34; radius: 10
        color: Qt.rgba(1, 1, 1, 0.07)
        border.color: entrada.activeFocus ? relogio.ambar : Qt.rgba(1, 1, 1, 0.12)
        opacity: enabled ? 1 : 0.4
        TextInput {
            id: entrada
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: relogio.claro; font.pixelSize: 13
            selectionColor: relogio.ambar
            clip: true
            inputMask: c.mascara
            text: c.texto
            onTextEdited: c.editado(text)
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: entrada.text === "" || (c.mascara !== "" && entrada.text === ":")
                text: c.dica; color: Qt.rgba(1, 1, 1, 0.4); font.pixelSize: 13
            }
        }
    }
    // botão-pílula que pode estar "ligado"
    component Escolha: Rectangle {
        id: e
        property string texto
        property bool ligado: false
        signal clicado()
        width: et.implicitWidth + 20; height: 28; radius: 14
        color: ligado ? relogio.ambar : Qt.rgba(1, 1, 1, eRato.containsMouse ? 0.14 : 0.07)
        Text { id: et; anchors.centerIn: parent; text: e.texto; color: e.ligado ? "#1b1030" : relogio.claro; font.pixelSize: 12; font.weight: e.ligado ? Font.DemiBold : Font.Normal }
        MouseArea { id: eRato; anchors.fill: parent; hoverEnabled: true; onClicked: e.clicado() }
    }

    component Seta: Rectangle {
        id: s
        property string texto
        signal clicado()
        width: 26; height: 26; radius: 13
        color: Qt.rgba(1, 1, 1, setaRato.containsMouse ? 0.14 : 0.07)
        Text { anchors.centerIn: parent; anchors.verticalCenterOffset: -1; text: s.texto; color: relogio.claro; font.pixelSize: 18 }
        MouseArea { id: setaRato; anchors.fill: parent; hoverEnabled: true; onClicked: s.clicado() }
    }
}
