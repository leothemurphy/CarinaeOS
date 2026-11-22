// CarinaeOS — Monitor do sistema (no jeito do Gerenciador de Tarefas do Windows 11)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: janela
    width: 1080; height: 720
    minimumWidth: 820; minimumHeight: 560
    visible: true
    title: "Carinae Monitor"
    color: "#1e1d24"
    font.family: "Inter"; font.pixelSize: 13
    // as cores dos controlos padrão (menus, caixas, listas) no tema escuro do CarinaeOS
    palette.window: "#2b2a32"; palette.windowText: "#f2f0f6"; palette.base: "#24232a"; palette.alternateBase: "#2b2a32"
    palette.text: "#f2f0f6"; palette.button: "#3a3942"; palette.buttonText: "#f2f0f6"; palette.brightText: "#ffffff"
    palette.highlight: "#7aa7ff"; palette.highlightedText: "#10131c"; palette.light: "#4a4952"; palette.midlight: "#3f3e47"
    palette.mid: "#55535f"; palette.dark: "#1c1b21"; palette.shadow: "#000000"; palette.toolTipBase: "#2f2e37"; palette.toolTipText: "#f2f0f6"
    palette.placeholderText: "#8a8597"

    readonly property color fundoLado: "#25232c"
    readonly property color cartao: "#2d2b35"
    readonly property color linha: Qt.rgba(1, 1, 1, 0.07)
    readonly property color texto: "#f2f0f6"
    readonly property color suave: "#a8a3b6"
    readonly property color realce: "#7aa7ff"
    property string pagina: monitor.paginaInicial
    property bool lateralAberta: width > 900

    function num(v, casas) { return Number(v).toFixed(casas === undefined ? 1 : casas).replace(".", ","); }
    function mbps(v) { return v >= 100 ? num(v, 0) : num(v, v >= 10 ? 1 : 2); }
    function irPara(p) { pagina = p; monitor.mudarPagina(p); }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ---- navegação da esquerda ---------------------------------------------------------------
        Rectangle {
            Layout.fillHeight: true
            Layout.preferredWidth: janela.lateralAberta ? 232 : 56
            color: janela.fundoLado
            Behavior on Layout.preferredWidth { NumberAnimation { duration: 140 } }
            Column {
                anchors.fill: parent; anchors.topMargin: 10; anchors.leftMargin: 6; anchors.rightMargin: 6
                spacing: 2
                BotaoNav { glifo: "≡"; rotulo: ""; onClicado: janela.lateralAberta = !janela.lateralAberta; ativo: false }
                Item { width: 1; height: 6 }
                BotaoNav { glifo: "▦"; rotulo: "Processos"; ativo: janela.pagina === "processos"; onClicado: janela.irPara("processos") }
                BotaoNav { glifo: "∿"; rotulo: "Desempenho"; ativo: janela.pagina === "desempenho"; onClicado: janela.irPara("desempenho") }
                BotaoNav { glifo: "⇅"; rotulo: "Velocidade da internet"; ativo: janela.pagina === "velocidade"; onClicado: janela.irPara("velocidade") }
                BotaoNav { glifo: "⏻"; rotulo: "Aplicativos de inicialização"; ativo: janela.pagina === "arranque"; onClicado: janela.irPara("arranque") }
            }
        }

        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: ["processos", "desempenho", "velocidade", "arranque"].indexOf(janela.pagina)
            PaginaProcessos {}
            PaginaDesempenho {}
            PaginaVelocidade {}
            PaginaArranque {}
        }
    }

    component BotaoNav: Rectangle {
        id: bn
        property string glifo
        property string rotulo
        property bool ativo
        signal clicado()
        width: parent.width; height: 40; radius: 6
        color: ativo ? Qt.rgba(1, 1, 1, 0.08) : (ma.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
        Rectangle { visible: bn.ativo; x: 0; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 16; radius: 2; color: janela.realce }
        Text { x: 14; width: 18; anchors.verticalCenter: parent.verticalCenter; text: bn.glifo; color: janela.texto; font.pixelSize: 17; horizontalAlignment: Text.AlignHCenter }
        Text { x: 46; anchors.verticalCenter: parent.verticalCenter; visible: janela.lateralAberta; text: bn.rotulo; color: janela.texto; width: parent.width - 52; elide: Text.ElideRight }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: bn.clicado() }
        ToolTip.visible: !janela.lateralAberta && ma.containsMouse && bn.rotulo !== ""
        ToolTip.text: bn.rotulo
    }

    component Botao: Rectangle {
        id: bt
        property string texto
        property bool principal: false
        signal clicado()
        implicitWidth: tt.implicitWidth + 28; implicitHeight: 32; radius: 6
        opacity: enabled ? 1 : 0.4
        color: principal ? (mb.containsMouse ? Qt.lighter(janela.realce, 1.1) : janela.realce)
                         : (mb.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.07))
        Text { id: tt; anchors.centerIn: parent; text: bt.texto; color: bt.principal ? "#10131c" : janela.texto; font.weight: Font.DemiBold }
        MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: bt.clicado() }
    }

    // gráfico de linha com área (o do Gerenciador de Tarefas)
    component Grafico: Canvas {
        id: gr
        property var valores: []
        property color cor: janela.realce
        property bool grelha: true
        onValoresChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const w = width, h = height, n = valores.length;
            if (grelha) {
                c.strokeStyle = Qt.rgba(1, 1, 1, 0.06); c.lineWidth = 1;
                for (let i = 1; i < 10; i++) { const x = Math.round(w * i / 10) + 0.5; c.beginPath(); c.moveTo(x, 0); c.lineTo(x, h); c.stroke(); }
                for (let i = 1; i < 5; i++) { const y = Math.round(h * i / 5) + 0.5; c.beginPath(); c.moveTo(0, y); c.lineTo(w, y); c.stroke(); }
            }
            if (n < 2) return;
            c.beginPath();
            for (let i = 0; i < n; i++) {
                const x = w * i / (n - 1), y = h - h * Math.max(0, Math.min(100, valores[i])) / 100;
                if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
            }
            c.strokeStyle = cor; c.lineWidth = 1.6; c.stroke();
            c.lineTo(w, h); c.lineTo(0, h); c.closePath();
            c.fillStyle = Qt.rgba(cor.r, cor.g, cor.b, 0.16); c.fill();
        }
    }

    // =========================================================================================
    component PaginaProcessos: Item {
        id: pp
        property string ordem: "cpu"
        property bool desc: true
        property string selecionado: ""       // tipo/exe
        property var sel: null
        readonly property var totais: {
            const d = monitor.dispositivos;
            const r = { cpu: 0, mem: 0, disco: 0 };
            for (const x of d) {
                if (x.id === "cpu") r.cpu = x.valor;
                else if (x.id === "mem") r.mem = x.valor;
                else if (x.id.startsWith("disco:")) r.disco = Math.max(r.disco, x.valor);
            }
            return r;
        }

        function refazer() {
            const f = busca.text.toLowerCase();
            const grupos = { app: [], fundo: [], sistema: [] };
            for (const p of monitor.processos) {
                if (f && p.nome.toLowerCase().indexOf(f) < 0 && p.exe.toLowerCase().indexOf(f) < 0) continue;
                grupos[p.tipo].push(p);
            }
            const k = ordem, s = desc ? -1 : 1;
            const cmp = (a, b) => k === "nome" ? s * -a.nome.localeCompare(b.nome) : s * (a[k] - b[k]) || a.nome.localeCompare(b.nome);
            const lista = [];
            const titulos = { app: "Aplicativos", fundo: "Processos em segundo plano", sistema: "Processos do sistema" };
            let achou = null;
            for (const t of ["app", "fundo", "sistema"]) {
                if (!grupos[t].length) continue;
                grupos[t].sort(cmp);
                lista.push({ cabecalho: true, nome: titulos[t] + " (" + grupos[t].length + ")", chave: "#" + t, icone: "", n: 0, cpu: 0, mem: 0, disco: 0, cpuTxt: "", memTxt: "", discoTxt: "", pidsTxt: "", meu: false, exe: "", tipo: t });
                for (const p of grupos[t]) {
                    const o = Object.assign({ cabecalho: false, chave: t + "/" + p.exe }, p);
                    if (o.chave === selecionado) achou = o;
                    lista.push(o);
                }
            }
            sel = achou;
            // atualiza no lugar (não perde o deslocamento nem a seleção)
            for (let i = 0; i < lista.length; i++) {
                if (i < modelo.count) modelo.set(i, lista[i]); else modelo.append(lista[i]);
            }
            if (modelo.count > lista.length) modelo.remove(lista.length, modelo.count - lista.length);
        }
        Connections { target: monitor; function onProcessosMudaram() { pp.refazer(); } }
        Component.onCompleted: refazer()
        onOrdemChanged: refazer()
        onDescChanged: refazer()
        ListModel { id: modelo }

        function calor(v, max) {  // fundo amarelado como no Windows, mais forte quanto mais gasta
            const a = Math.min(1, v / max);
            return a < 0.02 ? "transparent" : Qt.rgba(1, 0.78, 0.35, 0.05 + a * 0.35);
        }

        ColumnLayout {
            anchors.fill: parent; anchors.margins: 20; spacing: 12
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Text { text: "Processos"; color: janela.texto; font.pixelSize: 22; font.weight: Font.DemiBold }
                Item { Layout.fillWidth: true }
                Rectangle {
                    Layout.preferredWidth: 260; height: 32; radius: 6; color: Qt.rgba(1, 1, 1, 0.06); border.color: janela.linha
                    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: janela.suave; font.pixelSize: 16 }
                    TextField {
                        id: busca; anchors.fill: parent; leftPadding: 30; placeholderText: "Pesquisar um processo"
                        color: janela.texto; placeholderTextColor: janela.suave; background: null
                        onTextChanged: pp.refazer()
                    }
                }
                Botao { texto: "Finalizar tarefa"; enabled: pp.sel !== null && pp.sel.meu; onClicado: monitor.finalizar(pp.sel.pidsTxt, false) }
            }

            // cabeçalho das colunas (clique ordena; o total por cima, como no Windows)
            Rectangle {
                Layout.fillWidth: true; height: 46; color: "transparent"
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: janela.linha }
                RowLayout {
                    anchors.fill: parent; spacing: 0
                    Coluna { pg: pp; Layout.fillWidth: true; titulo: "Nome"; total: ""; chave: "nome"; alinhar: Text.AlignLeft }
                    Coluna { pg: pp; Layout.preferredWidth: 110; titulo: "CPU"; total: Math.round(pp.totais.cpu) + "%"; chave: "cpu" }
                    Coluna { pg: pp; Layout.preferredWidth: 120; titulo: "Memória"; total: Math.round(pp.totais.mem) + "%"; chave: "mem" }
                    Coluna { pg: pp; Layout.preferredWidth: 120; titulo: "Disco"; total: Math.round(pp.totais.disco) + "%"; chave: "disco" }
                }
            }

            ListView {
                id: lista
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; model: modelo; boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    id: lin
                    width: lista.width; height: model.cabecalho ? 38 : 34
                    readonly property bool escolhido: model.chave === pp.selecionado
                    color: escolhido ? Qt.rgba(0.48, 0.65, 1, 0.18) : (lm.containsMouse && !model.cabecalho ? Qt.rgba(1, 1, 1, 0.04) : "transparent")
                    RowLayout {
                        anchors.fill: parent; spacing: 0
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Image {
                                id: ico; visible: !model.cabecalho; x: 8; anchors.verticalCenter: parent.verticalCenter
                                width: 18; height: 18; sourceSize: Qt.size(36, 36)
                                source: model.icone ? "image://icone/" + model.icone : "image://icone/application-x-executable"
                            }
                            Text {
                                x: model.cabecalho ? 8 : 36; anchors.verticalCenter: parent.verticalCenter; width: parent.width - x - 8
                                text: model.cabecalho ? model.nome : model.nome + (model.n > 1 ? "  (" + model.n + ")" : "")
                                color: model.cabecalho ? janela.realce : janela.texto; elide: Text.ElideRight
                                font.weight: model.cabecalho ? Font.DemiBold : Font.Normal
                            }
                        }
                        Celula { Layout.preferredWidth: 110; visible: !model.cabecalho; valor: model.cpuTxt; fundo: pp.calor(model.cpu, 50) }
                        Celula { Layout.preferredWidth: 120; visible: !model.cabecalho; valor: model.memTxt; fundo: pp.calor(model.mem, 2e9) }
                        Celula { Layout.preferredWidth: 120; visible: !model.cabecalho; valor: model.discoTxt; fundo: pp.calor(model.disco, 5e7) }
                    }
                    MouseArea {
                        id: lm; anchors.fill: parent; hoverEnabled: true; enabled: !model.cabecalho
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (ev) => {
                            pp.selecionado = model.chave; pp.refazer();
                            if (ev.button === Qt.RightButton) menu.popup();
                        }
                    }
                }
            }
            Text { color: janela.suave; font.pixelSize: 12
                   text: "Processos de outros usuários e do sistema só podem ser vistos. Clique com o botão direito para mais opções." }
        }

        Menu {
            id: menu
            MenuItem { text: "Finalizar tarefa"; enabled: pp.sel && pp.sel.meu; onTriggered: monitor.finalizar(pp.sel.pidsTxt, false) }
            MenuItem { text: "Forçar o fechamento"; enabled: pp.sel && pp.sel.meu; onTriggered: monitor.finalizar(pp.sel.pidsTxt, true) }
            MenuSeparator {}
            MenuItem { text: "Copiar o nome"; onTriggered: monitor.copiar(pp.sel ? pp.sel.exe : "") }
            MenuItem { text: "Copiar os PIDs"; onTriggered: monitor.copiar(pp.sel ? pp.sel.pidsTxt : "") }
        }

    }

    // =========================================================================================
    component PaginaDesempenho: Item {
        id: pd
        property string escolhido: "cpu"
        readonly property var atual: {
            for (const d of monitor.dispositivos) if (d.id === escolhido) return d;
            return monitor.dispositivos.length ? monitor.dispositivos[0] : null;
        }
        RowLayout {
            anchors.fill: parent; anchors.margins: 20; spacing: 18
            // lista de dispositivos com o mini-gráfico
            ListView {
                Layout.preferredWidth: 240; Layout.fillHeight: true; spacing: 4; clip: true
                model: monitor.dispositivos
                header: Text { text: "Desempenho"; color: janela.texto; font.pixelSize: 22; font.weight: Font.DemiBold; bottomPadding: 14 }
                delegate: Rectangle {
                    width: 240; height: 70; radius: 8
                    readonly property bool ativo: pd.atual && modelData.id === pd.atual.id
                    color: ativo ? Qt.rgba(1, 1, 1, 0.09) : (dm.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent")
                    Rectangle {
                        x: 10; anchors.verticalCenter: parent.verticalCenter; width: 70; height: 50; color: "transparent"
                        border.color: modelData.cor; border.width: 1
                        Grafico { anchors.fill: parent; anchors.margins: 1; valores: modelData.hist; cor: modelData.cor; grelha: false }
                    }
                    Column {
                        x: 92; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 100; spacing: 2
                        Text { text: modelData.titulo; color: janela.texto; font.weight: Font.DemiBold; width: parent.width; elide: Text.ElideRight }
                        Text { text: modelData.resumo; color: janela.suave; font.pixelSize: 12; width: parent.width; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.NoWrap }
                    }
                    MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; onClicked: pd.escolhido = modelData.id }
                }
            }
            // o escolhido, em grande
            Flickable {
                Layout.fillWidth: true; Layout.fillHeight: true
                contentHeight: det.implicitHeight; clip: true; boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                ColumnLayout {
                    id: det
                    width: parent.width; spacing: 14
                    visible: pd.atual !== null
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: pd.atual ? pd.atual.titulo : ""; color: janela.texto; font.pixelSize: 26; font.weight: Font.DemiBold }
                        Item { Layout.fillWidth: true }
                        Text { text: pd.atual ? pd.atual.nome : ""; color: janela.texto; font.pixelSize: 15; elide: Text.ElideLeft; Layout.maximumWidth: 420 }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: pd.atual && pd.atual.id === "cpu" ? "% de utilização nos últimos 60 segundos" : pd.atual && pd.atual.id.startsWith("rede:") ? "Taxa de transferência" : pd.atual && pd.atual.id.startsWith("disco:") ? "Tempo ativo" : "Uso"; color: janela.suave; font.pixelSize: 12 }
                        Item { Layout.fillWidth: true }
                        Text { text: pd.atual ? pd.atual.escala : ""; color: janela.suave; font.pixelSize: 12 }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 260; color: "transparent"
                        border.color: pd.atual ? pd.atual.cor : "gray"; border.width: 1
                        Grafico { anchors.fill: parent; anchors.margins: 1; valores: pd.atual ? pd.atual.hist : []; cor: pd.atual ? pd.atual.cor : "white" }
                    }
                    // CPU: um tracinho por núcleo
                    Flow {
                        Layout.fillWidth: true; spacing: 4
                        visible: pd.atual && pd.atual.nucleos.length > 0
                        Repeater {
                            model: pd.atual ? pd.atual.nucleos : []
                            Rectangle {
                                width: 26; height: 40; radius: 3; color: Qt.rgba(1, 1, 1, 0.05)
                                Rectangle { anchors.bottom: parent.bottom; width: parent.width; radius: 3; height: parent.height * modelData / 100; color: pd.atual.cor; opacity: 0.75 }
                                ToolTip.visible: nm.containsMouse; ToolTip.text: "Núcleo " + index + ": " + Math.round(modelData) + "%"
                                MouseArea { id: nm; anchors.fill: parent; hoverEnabled: true }
                            }
                        }
                    }
                    // memória: a barra da composição
                    Rectangle {
                        Layout.fillWidth: true; height: 28; radius: 4; color: Qt.rgba(1, 1, 1, 0.05); border.color: janela.linha
                        visible: pd.atual && pd.atual.memoria !== undefined
                        Rectangle { height: parent.height; radius: 4; width: parent.width * (pd.atual && pd.atual.memoria ? pd.atual.memoria.usada : 0); color: Qt.rgba(0.77, 0.54, 1, 0.55) }
                        Rectangle { height: parent.height; x: parent.width * (pd.atual && pd.atual.memoria ? pd.atual.memoria.usada : 0)
                                    width: parent.width * (pd.atual && pd.atual.memoria ? Math.min(pd.atual.memoria.cache, 1 - pd.atual.memoria.usada) : 0); color: Qt.rgba(0.77, 0.54, 1, 0.2) }
                    }
                    GridLayout {
                        Layout.fillWidth: true; columns: 4; columnSpacing: 28; rowSpacing: 10
                        Repeater {
                            model: pd.atual ? pd.atual.grandes : []
                            Column {
                                Text { text: modelData[0]; color: janela.suave; font.pixelSize: 12 }
                                Text { text: modelData[1]; color: janela.texto; font.pixelSize: 20 }
                            }
                        }
                    }
                    GridLayout {
                        Layout.fillWidth: true; columns: 2; columnSpacing: 24; rowSpacing: 6
                        Repeater {
                            model: pd.atual ? pd.atual.detalhes : []
                            delegate: Text {
                                required property var modelData
                                required property int index
                                text: modelData[0] + ":   " + modelData[1]; color: janela.texto; font.pixelSize: 13
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================================
    component PaginaVelocidade: Item {
        id: pv
        readonly property var v: monitor.vel
        readonly property var r: v.resultado || ({})
        readonly property bool aCorrer: v.aCorrer
        readonly property string fase: v.fase
        function temValor(k) { return r[k] !== undefined && r[k] !== null; }
        // escala do mostrador como nos sites de teste: 0 5 10 50 100 250 500 1000
        readonly property var marcas: [0, 5, 10, 50, 100, 250, 500, 1000]
        function fracao(x) {
            const m = marcas;
            if (x <= 0) return 0;
            for (let i = 1; i < m.length; i++)
                if (x <= m[i]) return (i - 1 + (x - m[i - 1]) / (m[i] - m[i - 1])) / (m.length - 1);
            return 1;
        }
        readonly property string avaliacao: {
            if (fase !== "fim" || !temValor("download")) return "";
            const d = r.download, u = r.upload, p = r.ping;
            const bom = [];
            if (d >= 25) bom.push("vídeo 4K");
            else if (d >= 5) bom.push("vídeo em HD");
            if (p < 40 && r.jitter < 15) bom.push("jogos online");
            if (u >= 3 && p < 80) bom.push("chamadas de vídeo");
            if (u >= 20) bom.push("enviar arquivos grandes");
            let txt = bom.length ? "Boa para " + bom.join(", ") + "." : "Conexão lenta: páginas e mensagens funcionam, vídeo pode travar.";
            if (r.latDown > r.ping * 3 + 60 || r.latUp > r.ping * 3 + 60)
                txt += "  A latência sobe muito com carga (bufferbloat): jogos e chamadas podem travar enquanto alguém baixa algo.";
            return txt;
        }

        Flickable {
            anchors.fill: parent; contentHeight: col.implicitHeight + 40; clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            ColumnLayout {
                id: col
                x: 20; y: 20; width: parent.width - 40; spacing: 16
                Text { text: "Velocidade da internet"; color: janela.texto; font.pixelSize: 22; font.weight: Font.DemiBold }

                RowLayout {
                    Layout.fillWidth: true; spacing: 24
                    // mostrador
                    Item {
                        Layout.preferredWidth: 320; Layout.preferredHeight: 290
                        Canvas {
                            id: mostrador
                            anchors.fill: parent
                            property real alvo: pv.fase === "download" || pv.fase === "upload" ? pv.fracao(pv.v.valor) : (pv.fase === "fim" && pv.temValor("download") ? pv.fracao(pv.r.download) : 0)
                            property real f: alvo
                            Behavior on f { NumberAnimation { duration: 250 } }
                            onFChanged: requestPaint()
                            onPaint: {
                                const c = getContext("2d"); c.reset();
                                const cx = width / 2, cy = height / 2 + 10, raio = 120;
                                const a0 = Math.PI * 0.75, a1 = Math.PI * 2.25;
                                c.lineCap = "round"; c.lineWidth = 16;
                                c.strokeStyle = Qt.rgba(1, 1, 1, 0.08);
                                c.beginPath(); c.arc(cx, cy, raio, a0, a1); c.stroke();
                                if (f > 0.001) {
                                    c.strokeStyle = pv.fase === "upload" ? "#c58aff" : "#7aa7ff";
                                    c.beginPath(); c.arc(cx, cy, raio, a0, a0 + (a1 - a0) * f); c.stroke();
                                }
                                c.fillStyle = "#a8a3b6"; c.font = "12px Inter"; c.textAlign = "center"; c.textBaseline = "middle";
                                for (let i = 0; i < pv.marcas.length; i++) {
                                    const a = a0 + (a1 - a0) * i / (pv.marcas.length - 1);
                                    c.fillText(String(pv.marcas[i]), cx + Math.cos(a) * (raio - 30), cy + Math.sin(a) * (raio - 30));
                                }
                            }
                        }
                        Column {
                            anchors.centerIn: parent; anchors.verticalCenterOffset: 22; spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: pv.fase === "download" || pv.fase === "upload" ? janela.mbps(pv.v.valor)
                                      : pv.fase === "ping" ? (pv.temValor("ping") ? janela.num(pv.r.ping, 0) : "…")
                                      : pv.fase === "fim" && pv.temValor("download") ? janela.mbps(pv.r.download) : "—"
                                color: janela.texto; font.pixelSize: 44; font.weight: Font.Light
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: pv.fase === "ping" ? "ms · latência" : pv.fase === "download" ? "Mbps · ↓ download" : pv.fase === "upload" ? "Mbps · ↑ upload"
                                      : pv.fase === "ligar" ? "conectando ao servidor…" : pv.fase === "fim" ? "Mbps · download" : ""
                                color: janela.suave
                            }
                        }
                        Botao {
                            anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                            principal: !pv.aCorrer
                            texto: pv.aCorrer ? "Parar" : (pv.fase === "fim" || pv.fase === "erro" ? "Testar de novo" : "Iniciar o teste")
                            onClicado: monitor.testarVelocidade()
                        }
                    }
                    // resultados
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 10
                        GridLayout {
                            Layout.fillWidth: true; columns: 2; columnSpacing: 10; rowSpacing: 10
                            Cartao { titulo: "↓  Download"; valor: pv.temValor("download") ? janela.mbps(pv.r.download) : (pv.fase === "download" ? janela.mbps(pv.v.valor) : "—"); unidade: "Mbps"; cor: "#7aa7ff"; vivo: pv.fase === "download" }
                            Cartao { titulo: "↑  Upload"; valor: pv.temValor("upload") ? janela.mbps(pv.r.upload) : (pv.fase === "upload" ? janela.mbps(pv.v.valor) : "—"); unidade: "Mbps"; cor: "#c58aff"; vivo: pv.fase === "upload" }
                            Cartao { titulo: "Ping (latência)"; valor: pv.temValor("ping") ? janela.num(pv.r.ping, 0) : "—"; unidade: "ms"; cor: "#5fd39a"
                                     sub: pv.temValor("jitter") ? "Jitter (variação): " + janela.num(pv.r.jitter, 1) + " ms" : "" }
                            Cartao { titulo: "Latência com carga"; unidade: "ms"; cor: "#ffb46e"
                                     valor: pv.temValor("latDown") ? "↓ " + janela.num(pv.r.latDown, 0) + "   ↑ " + janela.num(pv.r.latUp || 0, 0) : "—"
                                     sub: "Ping enquanto baixa / envia" }
                            Cartao { titulo: "Perda de pacotes"; cor: "#ff7a9a"; unidade: pv.temValor("perda") ? "%" : ""
                                     valor: pv.temValor("perda") ? janela.num(pv.r.perda, 1) : (pv.fase === "fim" ? "não medida" : "—") }
                            Cartao { titulo: "Servidor"; cor: janela.suave; unidade: ""
                                     valor: pv.r.servidor || "—"; sub: (pv.r.isp || "") + (pv.r.ip ? "  ·  " + pv.r.ip : "") }
                        }
                        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; visible: text !== ""; color: janela.texto; text: pv.avaliacao }
                        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; visible: pv.fase === "erro"; color: "#ff8a8a"
                               text: pv.r.erro === "cancelado" ? "Teste parado." : "Não foi possível testar: " + (pv.r.erro || "") + ". Está conectado à internet?" }
                        // a velocidade ao vivo da fase atual
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 70; color: "transparent"; border.color: janela.linha
                            visible: pv.aCorrer && (pv.fase === "download" || pv.fase === "upload")
                            Grafico {
                                anchors.fill: parent; anchors.margins: 1; grelha: false
                                cor: pv.fase === "upload" ? "#c58aff" : "#7aa7ff"
                                valores: { const a = pv.v.ao_vivo || []; const m = Math.max(1, ...a) * 1.15; return a.map(x => 100 * x / m); }
                            }
                        }
                    }
                }
                Text { Layout.fillWidth: true; wrapMode: Text.Wrap; color: janela.suave; font.pixelSize: 12
                       text: "O teste usa o servidor mais próximo da Cloudflare (speed.cloudflare.com), com 4 conexões em paralelo durante cerca de 10 segundos para cada sentido. Gasta perto de " + "100–500 MB numa conexão rápida." }

                Text { text: "Testes anteriores"; color: janela.texto; font.pixelSize: 16; font.weight: Font.DemiBold; visible: monitor.historicoVel.length > 0; Layout.topMargin: 8 }
                Repeater {
                    model: monitor.historicoVel
                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 6; color: index % 2 ? "transparent" : Qt.rgba(1, 1, 1, 0.03)
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
                            Text { Layout.preferredWidth: 140; text: modelData.quando; color: janela.suave }
                            Text { Layout.preferredWidth: 140; text: "↓ " + janela.mbps(modelData.download) + " Mbps"; color: janela.texto }
                            Text { Layout.preferredWidth: 140; text: "↑ " + janela.mbps(modelData.upload) + " Mbps"; color: janela.texto }
                            Text { Layout.preferredWidth: 110; text: janela.num(modelData.ping, 0) + " ms"; color: janela.texto }
                            Text { Layout.fillWidth: true; text: modelData.servidor || ""; color: janela.suave; elide: Text.ElideRight }
                        }
                    }
                }
            }
        }

    }

    // =========================================================================================
    component PaginaArranque: Item {
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 20; spacing: 12
            Text { text: "Aplicativos de inicialização"; color: janela.texto; font.pixelSize: 22; font.weight: Font.DemiBold }
            Text { Layout.fillWidth: true; wrapMode: Text.Wrap; color: janela.suave
                   text: "O que inicia sozinho quando você entra na sessão. Desligar aqui deixa a entrada mais rápida; vale a partir da próxima vez que você entrar." }
            ListView {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true; spacing: 2
                model: monitor.arranque
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    width: ListView.view.width; height: 52; radius: 6; color: am.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
                    MouseArea { id: am; anchors.fill: parent; hoverEnabled: true }
                    Image { x: 10; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; sourceSize: Qt.size(48, 48)
                            source: "image://icone/" + (modelData.icone || "application-x-executable") }
                    Column {
                        x: 46; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 140
                        Text { text: modelData.nome; color: janela.texto; width: parent.width; elide: Text.ElideRight }
                        Text { text: modelData.comando + (modelData.sistema ? "   ·   do sistema" : ""); color: janela.suave; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight }
                    }
                    Rectangle {
                        id: chave
                        anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                        width: 40; height: 20; radius: 10
                        color: modelData.ligado ? janela.realce : Qt.rgba(1, 1, 1, 0.15)
                        Rectangle { width: 14; height: 14; radius: 7; y: 3; x: modelData.ligado ? 23 : 3; color: modelData.ligado ? "#10131c" : janela.texto
                                    Behavior on x { NumberAnimation { duration: 120 } } }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: monitor.ligarArranque(modelData.ficheiro, !modelData.ligado) }
                    }
                }
            }
        }
    }

    component Coluna: Rectangle {
        id: col
        property var pg
        property string titulo; property string total; property string chave
        property int alinhar: Text.AlignRight
        Layout.fillHeight: true
        color: cm.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
        Column {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: col.alinhar === Text.AlignLeft ? parent.left : undefined
            anchors.right: col.alinhar === Text.AlignRight ? parent.right : undefined
            anchors.leftMargin: 8; anchors.rightMargin: 12
            Text { anchors.right: col.alinhar === Text.AlignRight ? parent.right : undefined; text: col.total; color: janela.texto; font.pixelSize: 15; visible: col.total !== "" }
            Text {
                anchors.right: col.alinhar === Text.AlignRight ? parent.right : undefined
                text: col.titulo + (col.pg.ordem === col.chave ? (col.pg.desc ? "  ˅" : "  ˄") : "")
                color: col.pg.ordem === col.chave ? janela.texto : janela.suave; font.pixelSize: 12
            }
        }
        MouseArea { id: cm; anchors.fill: parent; hoverEnabled: true
                    onClicked: { if (col.pg.ordem === col.chave) col.pg.desc = !col.pg.desc; else { col.pg.ordem = col.chave; col.pg.desc = col.chave !== "nome"; } } }
    }

    component Celula: Rectangle {
        property string valor
        property color fundo
        Layout.fillHeight: true; color: fundo
        Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: parent.valor; color: janela.texto }
    }

    component Cartao: Rectangle {
        id: ca
        property string titulo; property string valor; property string unidade; property string sub
        property color cor; property bool vivo: false
        Layout.fillWidth: true; Layout.preferredHeight: 88; radius: 8; color: janela.cartao
        border.color: vivo ? cor : janela.linha
        Rectangle { x: 0; y: 14; width: 3; height: 20; radius: 2; color: ca.cor }
        Column {
            x: 16; y: 12; width: parent.width - 28; spacing: 3
            Text { text: ca.titulo; color: janela.suave; font.pixelSize: 12 }
            Row {
                spacing: 6
                Text { text: ca.valor; color: janela.texto; font.pixelSize: 24 }
                Text { text: ca.unidade; visible: ca.valor !== "—"; color: janela.suave; anchors.baseline: parent.children[0].baseline }
            }
            Text { text: ca.sub; color: janela.suave; font.pixelSize: 11; visible: ca.sub !== ""; width: parent.width; elide: Text.ElideRight }
        }
    }
}
