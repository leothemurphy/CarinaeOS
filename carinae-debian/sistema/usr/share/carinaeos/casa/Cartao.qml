// CarinaeOS - Casa: um cartão do painel, no estilo do Home Assistant e dos cartões Mushroom
// (o tipo escolhe o desenho; as cores, ícones e textos dos estados vêm de Main.qml)
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Rectangle {
    id: c
    required property var dados           // {tipo, titulo, ents, largura}
    required property int indice
    property bool editar: false
    signal pedirEditar()
    signal pedirApagar()
    signal pedirMover(int para)
    signal pedirDuplicar()
    property bool alvo: false            // ao arrastar outro cartão por cima deste

    readonly property int largura: dados.largura || 1
    readonly property var est: janela.est
    readonly property var e0: dados.ents.length ? (est[dados.ents[0]] || null) : null
    readonly property string t0: janela.tinta(e0)
    readonly property string nome0: dados.titulo !== "" ? dados.titulo : (e0 ? e0.nome : "Não encontrado")
    readonly property string estilo: dados.estilo || ""
    readonly property bool semFundo: dados.tipo === "texto" || dados.tipo === "chips"
    readonly property int pad: semFundo || dados.tipo === "camera" || dados.tipo === "imagem" ? 0 : 12
    readonly property int alinhar: dados.alinhar === "centro" ? Text.AlignHCenter : dados.alinhar === "direita" ? Text.AlignRight : Text.AlignLeft
    readonly property color texto: "#e1e1e1"
    readonly property color suave: "#9b9b9b"
    function ic(n) { return janela.ic(n) }
    function icE(e) { return janela.ic(janela.iconeDe(e)) }
    function ligado(e) { return janela.ligadoE(e) }

    radius: 12
    color: semFundo ? "transparent" : "#1c1c1c"
    border.width: semFundo ? 0 : 1
    border.color: Qt.rgba(1, 1, 1, 0.07)
    implicitHeight: (corpo.item ? corpo.item.implicitHeight : 40) + 2 * pad

    Loader {
        id: corpo
        x: c.pad; y: c.pad; width: parent.width - 2 * c.pad
        sourceComponent: ({ botao: botao, luz: luz, entidades: lista, sensor: sensor, grafico: grafico, clima: clima,
                            cenas: cenas, media: media, camera: camera, estores: estores, tempo: tempo, numero: numero,
                            texto: titulo, chips: chips, pessoa: pessoa, botao_grande: botaoGrande, medidor: medidor,
                            relogio: relogio, imagem: imagem })[c.dados.tipo] || lista
    }

    // ---- entidade (Mushroom entity card) -----------------------------------------------------------
    Component {
        id: botao
        Item {
            implicitHeight: c.estilo === "vertical" ? 92 : 40
            Cabeca { visible: c.estilo !== "vertical"; anchors.fill: parent; icone: c.icE(c.e0); tinta: c.t0; primario: c.nome0; secundario: janela.estadoTexto(c.e0) }
            Column {
                visible: c.estilo === "vertical"; width: parent.width; spacing: 6
                Forma { anchors.horizontalCenter: parent.horizontalCenter; icone: c.icE(c.e0); tinta: c.t0 }
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: c.nome0; color: c.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: janela.estadoTexto(c.e0); color: c.suave; font.pixelSize: 12 }
            }
            MouseArea {
                anchors.fill: parent; anchors.margins: -12
                enabled: !c.editar && c.e0 !== null && janela.alternavel(c.e0); cursorShape: Qt.PointingHandCursor
                onClicked: casa.alternar(c.e0.id)
            }
        }
    }
    // ---- pessoa (Mushroom person card), com a foto do Home Assistant ----------------------------------------
    Component {
        id: pessoa
        Item {
            readonly property string foto: c.e0 ? (janela.extras.fotos[c.e0.id] || "") : ""
            readonly property bool vert: c.estilo === "vertical"
            implicitHeight: vert ? 112 : 40
            Item {
                id: av
                width: parent.vert ? 64 : 40; height: width
                x: parent.vert ? (parent.width - width) / 2 : 0
                Forma { anchors.fill: parent; tamanho: parent.width; icone: c.icE(c.e0); tinta: c.t0; visible: parent.parent.foto === "" }
                Foto { anchors.fill: parent; fonte: parent.parent.foto; visible: parent.parent.foto !== "" }
                Rectangle {       // o selo: em casa / fora
                    x: parent.width - 16; y: parent.height - 16; width: 18; height: 18; radius: 9; color: c.t0 !== "" ? "#4caf50" : "#616161"
                    border.width: 2; border.color: "#1c1c1c"
                    Text { anchors.centerIn: parent; text: c.ic(c.t0 !== "" ? "home" : "walk"); font.family: "Material Design Icons"; font.pixelSize: 10; color: "white" }
                }
            }
            Column {
                x: parent.vert ? 0 : 52; y: parent.vert ? 72 : (40 - height) / 2; width: parent.width - x
                Text { width: parent.width; horizontalAlignment: parent.parent.vert ? Text.AlignHCenter : Text.AlignLeft; elide: Text.ElideRight
                       text: c.nome0; color: c.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
                Text { width: parent.width; horizontalAlignment: parent.parent.vert ? Text.AlignHCenter : Text.AlignLeft; elide: Text.ElideRight
                       text: janela.estadoTexto(c.e0); color: c.suave; font.pixelSize: 12 }
            }
        }
    }
    // ---- botão grande (o cartão "Botão" do Home Assistant) ----------------------------------------------------
    Component {
        id: botaoGrande
        Item {
            implicitHeight: 112
            Column {
                anchors.centerIn: parent; width: parent.width; spacing: 8
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: c.icE(c.e0); font.family: "Material Design Icons"; font.pixelSize: 56
                       color: c.t0 !== "" ? c.t0 : "#9e9e9e"; Behavior on color { ColorAnimation { duration: 200 } } }
                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: c.nome0; color: c.texto; font.pixelSize: 15 }
            }
            MouseArea { anchors.fill: parent; anchors.margins: -12; enabled: !c.editar && c.e0 !== null && janela.alternavel(c.e0)
                        cursorShape: Qt.PointingHandCursor; onClicked: casa.alternar(c.e0.id) }
        }
    }
    // ---- medidor (o cartão "Medidor" do Home Assistant) -------------------------------------------------------
    Component {
        id: medidor
        Column {
            spacing: 2
            readonly property real lo: c.dados.minimo !== undefined ? Number(c.dados.minimo) : 0
            readonly property real hi: c.dados.maximo !== undefined ? Number(c.dados.maximo)
                                      : (c.e0 && c.e0.unidade === "%" ? 100 : c.e0 && /°/.test(c.e0.unidade) ? 40 : Math.max(100, (parseFloat(c.e0 ? c.e0.estado : 0) || 0) * 1.5))
            readonly property real v: c.e0 ? parseFloat(c.e0.estado) : NaN
            readonly property real frac: isNaN(v) || hi <= lo ? 0 : Math.max(0, Math.min(1, (v - lo) / (hi - lo)))
            Canvas {
                id: arco
                width: parent.width; height: Math.min(width / 2 + 14, 130)
                readonly property real f: parent.frac
                readonly property string cor: f < 0.6 ? "#43a047" : f < 0.85 ? "#ffa600" : "#db4437"
                onFChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d"); g.reset()
                    const R = Math.min(width / 2, height - 14) - 12, cx = width / 2, cy = height - 8
                    g.lineWidth = 22; g.lineCap = "butt"
                    g.beginPath(); g.arc(cx, cy, R, Math.PI, 2 * Math.PI); g.strokeStyle = "rgba(255,255,255,0.1)"; g.stroke()
                    if (f > 0) { g.beginPath(); g.arc(cx, cy, R, Math.PI, Math.PI + f * Math.PI); g.strokeStyle = cor; g.stroke() }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 8
                       text: c.e0 ? janela.num(c.e0.estado) + (c.e0.unidade ? " " + c.e0.unidade : "") : "—"; color: c.texto; font.pixelSize: 22 }
            }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: c.nome0; color: c.suave; font.pixelSize: 14 }
        }
    }
    // ---- relógio ------------------------------------------------------------------------------------------
    Component {
        id: relogio
        Column {
            spacing: 0
            property date agora: new Date()
            Timer { interval: 5000; running: true; repeat: true; triggeredOnStart: true; onTriggered: parent.agora = new Date() }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: c.dados.titulo; visible: text !== ""; color: c.suave; font.pixelSize: 13 }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: Qt.formatTime(parent.agora, "HH:mm"); color: c.texto; font.pixelSize: 52; font.weight: Font.Light }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; color: c.suave; font.pixelSize: 14
                   text: { const t = parent.agora.toLocaleDateString(Qt.locale("pt_BR"), "dddd, d 'de' MMMM"); return t.charAt(0).toUpperCase() + t.slice(1) } }
        }
    }
    // ---- imagem ---------------------------------------------------------------------------------------------
    Component {
        id: imagem
        Item {
            readonly property string url: !c.dados.titulo ? "" : c.dados.titulo.startsWith("/") && !c.dados.titulo.startsWith("//") ? casa.url + c.dados.titulo : c.dados.titulo
            implicitHeight: ft.imagem.status === Image.Ready && ft.imagem.implicitWidth > 0
                            ? Math.min(width * 1.5, width * ft.imagem.implicitHeight / ft.imagem.implicitWidth) : width * 9 / 16
            Foto { id: ft; anchors.fill: parent; raio: c.radius; fonte: parent.url }
            Text { anchors.centerIn: parent; visible: ft.imagem.status !== Image.Ready; text: ft.imagem.status === Image.Error ? "Não consegui abrir a imagem" : "Carregando…"; color: c.suave }
        }
    }
    // ---- luz (Mushroom light card): brilho, branco e cor na mesma barra; ⋮ abre os ajustes ---------------
    Component {
        id: luz
        Column {
            id: cl
            spacing: 12
            readonly property bool on: c.ligado(c.e0)
            property string modo: "brilho"
            readonly property var modos: ["brilho"].concat(janela.temBranco(c.e0) ? ["branco"] : []).concat(janela.temCor(c.e0) ? ["cor"] : [])
            readonly property int nBotoes: (modos.length > 1 ? modos.length : 0) + 1
            Item {
                width: parent.width; height: 40
                Cabeca {
                    anchors.fill: parent; icone: c.icE(c.e0); tinta: c.t0; primario: c.nome0
                    secundario: c.e0 ? (cl.on ? (c.e0.brilho > 0 ? c.e0.brilho + "%" : "Acesa") : janela.estadoTexto(c.e0)) : ""
                    formaClicavel: !c.editar && c.e0 !== null; onClicouForma: casa.alternar(c.e0.id)
                }
                MouseArea { x: 52; width: parent.width - 52; height: parent.height; enabled: !c.editar && c.e0 !== null
                            cursorShape: Qt.PointingHandCursor; onClicked: janela.abrirLuz(c.e0.id) }
            }
            Row {
                width: parent.width; spacing: 8
                Barra {
                    width: parent.width - cl.nBotoes * 50
                    ativa: !c.editar && c.e0 !== null && (cl.modo === "brilho" || cl.on)
                    paleta: cl.modo === "brilho" ? "" : cl.modo
                    tinta: c.t0 !== "" ? c.t0 : "#ffc107"
                    valor: !c.e0 ? 0 : cl.modo === "branco" ? janela.pctBranco(c.e0)
                         : cl.modo === "cor" ? (c.e0.hs.length ? c.e0.hs[0] / 3.6 : 0)
                         : (cl.on ? Math.max(1, c.e0.brilho) : 0)
                    onSoltou: (v) => {
                        if (cl.modo === "branco") casa.brancoLuz(c.e0.id, janela.kelvinDe(c.e0, v))
                        else if (cl.modo === "cor") casa.corLuz(c.e0.id, v * 3.6, c.e0.hs.length && c.e0.hs[1] > 30 ? c.e0.hs[1] : 100)
                        else if (v < 1) { if (cl.on) casa.alternar(c.e0.id) }
                        else casa.brilho(c.e0.id, v)
                    }
                }
                Repeater {
                    model: cl.modos.length > 1 ? cl.modos : []
                    delegate: BotaoM {
                        required property string modelData
                        icone: c.ic(({ brilho: "brightness-6", branco: "thermometer", cor: "palette" })[modelData])
                        tinta: cl.modo === modelData ? (c.t0 !== "" ? c.t0 : "#ffc107") : ""
                        ativo: !c.editar; onClicado: cl.modo = modelData
                    }
                }
                BotaoM { icone: c.ic("dots-vertical"); ativo: !c.editar && c.e0 !== null; onClicado: janela.abrirLuz(c.e0.id) }
            }
        }
    }
    // ---- lista (o cartão "Entidades" do Home Assistant) ---------------------------------------------------
    Component {
        id: lista
        Column {
            Text { visible: c.dados.titulo !== ""; text: c.dados.titulo; color: c.texto; font.pixelSize: 20; bottomPadding: 8; width: parent.width; elide: Text.ElideRight }
            Repeater {
                model: c.dados.ents
                delegate: Item {
                    required property string modelData
                    readonly property var e: c.est[modelData] || null
                    readonly property string d: e ? e.dominio : ""
                    readonly property bool acao: ["scene", "script", "button", "input_button", "automation"].indexOf(d) !== -1
                    readonly property bool troca: ["light", "switch", "fan", "input_boolean", "lock", "cover", "media_player", "humidifier"].indexOf(d) !== -1
                    width: parent.width; height: 44
                    Text { width: 40; anchors.verticalCenter: parent.verticalCenter; text: c.icE(e); font.family: "Material Design Icons"; font.pixelSize: 24
                           color: janela.tinta(e) !== "" && !acao ? janela.tinta(e) : "#9e9e9e" }
                    Text { x: 40; width: parent.width - 40 - dir.width - 8; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight
                           text: e ? e.nome : modelData; color: c.texto; font.pixelSize: 14
                           MouseArea { anchors.fill: parent; enabled: d === "light" && !c.editar; cursorShape: Qt.PointingHandCursor; onClicked: janela.abrirLuz(e.id) } }
                    Item {
                        id: dir
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: troca ? sw.width : acao ? exe.implicitWidth : st.implicitWidth; height: 30
                        Interruptor { id: sw; visible: troca; anchors.verticalCenter: parent.verticalCenter; ligado: c.ligado(e); ativo: !c.editar; onAlternado: casa.alternar(e.id) }
                        Text { id: exe; visible: acao; anchors.verticalCenter: parent.verticalCenter; text: d === "script" ? "EXECUTAR" : "ATIVAR"
                               color: "#03a9f4"; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 0.6
                               MouseArea { anchors.fill: parent; anchors.margins: -8; enabled: !c.editar && e !== null; cursorShape: Qt.PointingHandCursor; onClicked: casa.alternar(e.id) } }
                        Text { id: st; visible: !troca && !acao; anchors.verticalCenter: parent.verticalCenter; text: janela.estadoTexto(e); color: c.texto; font.pixelSize: 14 }
                    }
                }
            }
        }
    }
    // ---- sensor -------------------------------------------------------------------------------------------
    Component {
        id: sensor
        Column {
            spacing: 6
            Row {
                spacing: 10; width: parent.width
                Forma { tamanho: 32; icone: c.icE(c.e0); tinta: c.t0 }
                Text { anchors.verticalCenter: parent.verticalCenter; width: parent.width - 42; elide: Text.ElideRight; text: c.nome0; color: c.suave; font.pixelSize: 14 }
            }
            Row {
                spacing: 4
                Text { id: vs; text: c.e0 ? (c.e0.dominio === "binary_sensor" ? janela.estadoTexto(c.e0) : janela.num(c.e0.estado)) : "—"; color: c.texto; font.pixelSize: 38; font.weight: Font.Light }
                Text { text: c.e0 && c.e0.dominio === "sensor" ? c.e0.unidade : ""; color: c.suave; font.pixelSize: 18; anchors.baseline: vs.baseline }
            }
        }
    }
    // ---- grafico (o cartão "Sensor" com gráfico do Home Assistant) --------------------------------------------
    Component {
        id: grafico
        Column {
            spacing: 2
            Item {
                width: parent.width; height: 26
                Text { width: parent.width - 30; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: c.nome0; color: c.suave; font.pixelSize: 14 }
                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: c.icE(c.e0); font.family: "Material Design Icons"; font.pixelSize: 24; color: c.t0 !== "" ? c.t0 : c.suave }
            }
            Row {
                spacing: 4
                Text { id: vg; text: c.e0 ? janela.num(c.e0.estado) : "—"; color: c.texto; font.pixelSize: 32; font.weight: Font.Light }
                Text { text: c.e0 ? c.e0.unidade : ""; color: c.suave; font.pixelSize: 16; anchors.baseline: vg.baseline }
            }
            Canvas {
                id: tela
                width: parent.width; height: 80
                readonly property var pts: janela.extras.hist[c.dados.ents[0]] || []
                readonly property string cor: c.t0 !== "" ? c.t0 : "#03a9f4"
                onPtsChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d"); g.reset()
                    if (pts.length < 2) { g.fillStyle = "#7a7a7a"; g.font = "12px Inter"; g.fillText("Juntando o histórico das últimas 24 horas…", 0, 46); return }
                    let mx = pts[pts.length - 1].x || 1, lo = Infinity, hi = -Infinity
                    for (const p of pts) { lo = Math.min(lo, p.y); hi = Math.max(hi, p.y) }
                    if (hi - lo < 0.001) { hi += 1; lo -= 1 }
                    const X = p => p.x / mx * width, Y = p => height - 4 - (p.y - lo) / (hi - lo) * (height - 12)
                    const k = Qt.lighter(cor, 1.0), rgb = Math.round(k.r * 255) + "," + Math.round(k.g * 255) + "," + Math.round(k.b * 255)
                    const grad = g.createLinearGradient(0, 0, 0, height)
                    grad.addColorStop(0, "rgba(" + rgb + ",0.35)"); grad.addColorStop(1, "rgba(" + rgb + ",0)")
                    g.beginPath(); g.moveTo(0, height)
                    for (const p of pts) g.lineTo(X(p), Y(p))
                    g.lineTo(width, height); g.closePath(); g.fillStyle = grad; g.fill()
                    g.beginPath(); for (let i = 0; i < pts.length; i++) (i ? g.lineTo : g.moveTo).call(g, X(pts[i]), Y(pts[i]))
                    g.strokeStyle = cor; g.lineWidth = 2; g.lineJoin = "round"; g.stroke()
                }
            }
        }
    }
    // ---- clima (Mushroom climate card) -------------------------------------------------------------------
    Component {
        id: clima
        Column {
            spacing: 12
            Cabeca {
                width: parent.width; icone: c.icE(c.e0); tinta: c.t0; primario: c.nome0
                secundario: c.e0 ? janela.estadoTexto(c.e0) + (c.e0.temperatura !== "" ? " · " + janela.num(c.e0.temperatura) + " °C" : "") : ""
                formaClicavel: !c.editar && c.e0 !== null; onClicouForma: casa.alternar(c.e0.id)
            }
            Row {
                width: parent.width; spacing: 8
                readonly property real alvo: c.e0 ? parseFloat(c.e0.alvo) : NaN
                BotaoM { icone: c.ic("minus"); ativo: !c.editar && !isNaN(parent.alvo); onClicado: casa.temperatura(c.e0.id, parent.alvo - 0.5) }
                Rectangle {
                    width: parent.width - 3 * 42 - 3 * 8; height: 42; radius: 12; color: Qt.rgba(1, 1, 1, 0.05)
                    Text { anchors.centerIn: parent; text: isNaN(parent.parent.alvo) ? "—" : janela.num(parent.parent.alvo.toFixed(1)) + " °C"
                           color: c.t0 !== "" ? c.t0 : c.texto; font.pixelSize: 16; font.weight: Font.DemiBold }
                }
                BotaoM { icone: c.ic("plus"); ativo: !c.editar && !isNaN(parent.alvo); onClicado: casa.temperatura(c.e0.id, parent.alvo + 0.5) }
                BotaoM { icone: c.ic("power"); tinta: c.t0; ativo: !c.editar && c.e0 !== null; onClicado: casa.alternar(c.e0.id) }
            }
        }
    }
    // ---- cenas: uma grelha de cartões verticais Mushroom ---------------------------------------------------
    Component {
        id: cenas
        Column {
            spacing: 8
            Text { visible: c.dados.titulo !== ""; text: c.dados.titulo; color: c.texto; font.pixelSize: 20; bottomPadding: 2 }
            Flow {
                id: fl
                width: parent.width; spacing: 8
                readonly property int n: Math.max(1, Math.min(c.dados.ents.length, Math.floor((width + 8) / 118)))
                readonly property real lc: (width - (n - 1) * 8) / n
                Repeater {
                    model: c.dados.ents
                    delegate: Rectangle {
                        required property string modelData
                        readonly property var e: c.est[modelData] || null
                        width: fl.lc; height: 96; radius: 12
                        color: ma.pressed ? Qt.rgba(0.012, 0.663, 0.957, 0.18) : ma.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : Qt.rgba(1, 1, 1, 0.04)
                        Forma { anchors.horizontalCenter: parent.horizontalCenter; y: 12; icone: c.icE(e); tinta: janela.tinta(e) }
                        Text { x: 6; width: parent.width - 12; y: 60; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight
                               text: e ? e.nome : modelData; color: c.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: !c.editar && e !== null; cursorShape: Qt.PointingHandCursor; onClicked: casa.alternar(e.id) }
                    }
                }
            }
        }
    }
    // ---- som e TV (Mushroom media player card) -------------------------------------------------------------
    Component {
        id: media
        Column {
            spacing: 12
            readonly property bool toca: c.e0 !== null && c.e0.estado === "playing"
            Cabeca {
                width: parent.width; icone: c.icE(c.e0); tinta: c.t0
                primario: c.e0 && c.e0.titulo_media ? c.e0.titulo_media : c.nome0
                secundario: c.e0 && c.e0.artista ? c.e0.artista : janela.estadoTexto(c.e0)
            }
            Row {
                width: parent.width; spacing: 8
                BotaoM { icone: c.ic("skip-previous"); ativo: !c.editar && c.e0 !== null; onClicado: casa.media(c.e0.id, "anterior") }
                BotaoM { icone: c.ic(parent.parent.toca ? "pause" : "play"); tinta: parent.parent.toca ? "#03a9f4" : ""; ativo: !c.editar && c.e0 !== null; onClicado: casa.media(c.e0.id, "pausa") }
                BotaoM { icone: c.ic("skip-next"); ativo: !c.editar && c.e0 !== null; onClicado: casa.media(c.e0.id, "seguinte") }
                Barra {
                    width: parent.width - 3 * 42 - 3 * 8; tinta: "#03a9f4"; ativa: !c.editar && c.e0 !== null
                    valor: c.e0 ? c.e0.volume : 0
                    onSoltou: (v) => casa.valor(c.e0.id, String(Math.round(v)))
                }
            }
            BotaoM {     // a fonte: HDMI, Spotify, TV, rádio…
                visible: c.e0 !== null && (c.e0.fontes || []).length > 0
                width: parent.width; icone: c.ic("import"); texto: c.e0 && c.e0.fonte ? c.e0.fonte : "Escolher a fonte"
                ativo: !c.editar
                onClicado: janela.escolher("Fonte de " + c.e0.nome, c.e0.fontes, c.e0.fonte, (v) => casa.fonte(c.e0.id, v))
            }
        }
    }
    // ---- camera (o cartão "Imagem" do Home Assistant) --------------------------------------------------
    Component {
        id: camera
        Item {
            implicitHeight: width * 9 / 16
            Item {
                id: quadro
                anchors.fill: parent
                layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                layer.effect: MultiEffect { maskEnabled: true; maskSource: mascara }
                Rectangle { anchors.fill: parent; color: "#000" }
                Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false
                        source: janela.extras.cams[c.dados.ents[0]] || "" }
                Text { anchors.centerIn: parent; visible: !janela.extras.cams[c.dados.ents[0]]; text: "Carregando a imagem…"; color: c.suave }
                Rectangle {
                    anchors.bottom: parent.bottom; width: parent.width; height: 44; color: Qt.rgba(0, 0, 0, 0.45)
                    Text { x: 16; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 32; elide: Text.ElideRight
                           text: c.nome0; color: "white"; font.pixelSize: 15 }
                }
            }
            Item {
                id: mascara
                anchors.fill: parent; visible: false; layer.enabled: GraphicsInfo.api !== GraphicsInfo.Software
                Rectangle { anchors.fill: parent; radius: c.radius; color: "black" }
            }
        }
    }
    // ---- persianas e portões (Mushroom cover card) ----------------------------------------------------------
    Component {
        id: estores
        Column {
            spacing: 12
            Cabeca {
                width: parent.width; icone: c.icE(c.e0); tinta: c.t0; primario: c.nome0
                secundario: c.e0 ? janela.estadoTexto(c.e0) + (c.e0.posicao >= 0 ? " · " + c.e0.posicao + "%" : "") : ""
            }
            Row {
                width: parent.width; spacing: 8
                Barra {
                    visible: c.e0 !== null && c.e0.posicao >= 0
                    width: parent.width - 3 * 42 - 3 * 8; tinta: "#9c27b0"; ativa: !c.editar
                    valor: c.e0 ? Math.max(0, c.e0.posicao) : 0
                    onSoltou: (v) => casa.valor(c.e0.id, String(Math.round(v)))
                }
                Repeater {
                    model: [["arrow-down", -1], ["stop", 0], ["arrow-up", 1]]
                    delegate: BotaoM {
                        required property var modelData
                        width: c.e0 !== null && c.e0.posicao >= 0 ? 42 : (parent.width - 16) / 3
                        icone: c.ic(modelData[0]); ativo: !c.editar && c.e0 !== null
                        onClicado: modelData[1] === 0 ? casa.pararEstore(c.e0.id) : casa.estore(c.e0.id, modelData[1] > 0)
                    }
                }
            }
        }
    }
    // ---- tempo (o cartão "Previsão do tempo" do Home Assistant) ---------------------------------------------
    Component {
        id: tempo
        Column {
            spacing: 14
            Item {
                width: parent.width; height: 56
                Text { id: ti; anchors.verticalCenter: parent.verticalCenter; text: c.icE(c.e0); font.family: "Material Design Icons"; font.pixelSize: 52; color: "#ffb300" }
                Column {
                    x: ti.width + 14; anchors.verticalCenter: parent.verticalCenter; width: parent.width - x - tt.width - 8
                    Text { width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight; text: c.e0 ? janela.condicao(c.e0.estado) : "—"; color: c.texto; font.pixelSize: 16; lineHeight: 0.95 }
                    Text { width: parent.width; elide: Text.ElideRight; text: c.nome0; color: c.suave; font.pixelSize: 13 }
                }
                Column {
                    id: tt
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    Text { anchors.right: parent.right; text: c.e0 && c.e0.temperatura !== "" ? janela.num(c.e0.temperatura) + " °C" : ""; color: c.texto; font.pixelSize: 26; font.weight: Font.Light }
                    Text { anchors.right: parent.right; text: c.e0 && c.e0.humidade !== "" ? "Umidade " + c.e0.humidade + "%" : ""; color: c.suave; font.pixelSize: 12; visible: text !== "" }
                }
            }
            Row {
                visible: c.e0 !== null && c.e0.previsao.length > 0
                width: parent.width
                Repeater {
                    model: c.e0 ? c.e0.previsao : []
                    delegate: Column {
                        required property var modelData
                        width: parent.width / Math.max(1, c.e0.previsao.length); spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.d ? new Date(modelData.d).toLocaleDateString(Qt.locale("pt_BR"), "ddd") : ""; color: c.suave; font.pixelSize: 13 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: c.ic(janela.tempoIcone(modelData.c)); font.family: "Material Design Icons"; font.pixelSize: 26; color: c.texto }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.t) + "°"; color: c.texto; font.pixelSize: 14 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.m !== undefined && modelData.m !== null ? Math.round(modelData.m) + "°" : ""; color: c.suave; font.pixelSize: 13 }
                    }
                }
            }
        }
    }
    // ---- numero / escolha (Mushroom number e select) -------------------------------------------------------
    Component {
        id: numero
        Column {
            spacing: 12
            readonly property bool escolha: c.e0 !== null && (c.e0.dominio === "select" || c.e0.dominio === "input_select")
            Cabeca {
                width: parent.width; icone: c.icE(c.e0); tinta: c.t0; primario: c.nome0
                secundario: c.e0 ? (parent.escolha ? c.e0.estado : janela.num(c.e0.estado) + (c.e0.unidade ? " " + c.e0.unidade : "")) : ""
            }
            Barra {
                visible: !parent.escolha; width: parent.width; tinta: "#03a9f4"; ativa: !c.editar && c.e0 !== null
                readonly property real lo: c.e0 ? Number(c.e0.minimo) : 0
                readonly property real hi: c.e0 ? Number(c.e0.maximo) : 100
                valor: c.e0 && hi > lo ? (parseFloat(c.e0.estado) - lo) / (hi - lo) * 100 : 0
                onSoltou: (v) => {
                    const p = Number(c.e0.passo) || 1
                    casa.valor(c.e0.id, String(Math.round((lo + v / 100 * (hi - lo)) / p) * p))
                }
            }
            Flow {
                visible: parent.escolha; width: parent.width; spacing: 8
                Repeater {
                    model: parent.visible && c.e0 ? c.e0.opcoes : []
                    delegate: BotaoM {
                        required property string modelData
                        texto: modelData; tinta: c.e0 && c.e0.estado === modelData ? "#03a9f4" : ""; ativo: !c.editar
                        onClicado: casa.valor(c.e0.id, modelData)
                    }
                }
            }
        }
    }
    // ---- titulo (Mushroom title card) e texto (markdown do HA), sem fundo --------------------------------------
    // {saudacao} e {nome} são do Casa; {{ … }} e {% … %} são modelos que o próprio Home Assistant calcula
    Component {
        id: titulo
        Column {
            spacing: 2; topPadding: 6; bottomPadding: 4
            readonly property bool modelo: /\{\{|\{%/.test(c.dados.titulo || "")
            readonly property string bruto: modelo ? (janela.extras.tpl[c.dados.titulo] !== undefined ? janela.extras.tpl[c.dados.titulo] : "…") : (c.dados.titulo || "Título")
            readonly property string limpo: janela.saudar(bruto).replace(/<br\s*\/?>/gi, "\n").replace(/<\/?(center|div|span|font|p|b|i|big|small|ha-icon)[^>]*>/gi, "").trim()
            readonly property var linhas: limpo.split("\n").filter(l => l.trim() !== "").map(l => l.replace(/^#+\s*/, ""))
            Text { visible: c.estilo !== "markdown"; width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: c.alinhar
                   text: parent.linhas[0]; color: c.texto; font.pixelSize: 24; font.weight: Font.Bold }
            Text { visible: c.estilo !== "markdown" && text !== ""; width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: c.alinhar
                   text: parent.linhas.slice(1).join("\n"); color: c.suave; font.pixelSize: 14 }
            Text { visible: c.estilo === "markdown"; width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: c.alinhar
                   text: parent.limpo; textFormat: Text.MarkdownText; color: c.texto; font.pixelSize: 15; lineHeight: 1.15
                   onLinkActivated: (l) => Qt.openUrlExternally(l) }
        }
    }
    // ---- chips (Mushroom chips card): sem fundo, uma fila de pílulas; "duas" = nome por cima do estado -------------
    Component {
        id: chips
        Item {
            id: ch
            implicitHeight: fc.height
            property real usado: 0
            function medir() { let w = 0; for (let i = 0; i < rch.count; i++) { const it = rch.itemAt(i); if (it) w += it.width + 8 } usado = Math.max(0, w - 8) }
            Flow {
                id: fc
                spacing: 8
                width: c.alinhar === Text.AlignLeft || ch.usado > ch.width ? ch.width : ch.usado + 1
                x: c.alinhar === Text.AlignHCenter ? (ch.width - width) / 2 : c.alinhar === Text.AlignRight ? ch.width - width : 0
                Repeater {
                    id: rch
                    model: c.dados.ents
                    onItemAdded: Qt.callLater(ch.medir)
                    delegate: Rectangle {
                        required property string modelData
                        readonly property var e: c.est[modelData] || null
                        readonly property bool duas: c.estilo === "duas"
                        readonly property bool valor: e !== null && ["sensor", "weather", "climate", "person", "binary_sensor", "device_tracker"].indexOf(e.dominio) !== -1
                        readonly property string estado: !e ? modelData : e.dominio === "sensor" ? janela.num(e.estado) + (e.unidade ? " " + e.unidade : "")
                             : e.dominio === "weather" ? (e.temperatura !== "" ? janela.num(e.temperatura) + " °C" : janela.condicao(e.estado))
                             : e.dominio === "climate" ? (e.temperatura !== "" ? janela.num(e.temperatura) + " °C" : janela.estadoTexto(e))
                             : (valor || duas) ? janela.estadoTexto(e) : e.nome
                        width: lin.implicitWidth + 24; height: duas ? 42 : 36; radius: height / 2
                        onWidthChanged: Qt.callLater(ch.medir)
                        color: mc.containsMouse && mc.enabled ? "#262626" : "#1c1c1c"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)
                        Row {
                            id: lin
                            anchors.centerIn: parent; spacing: 6
                            Text { text: c.icE(e); font.family: "Material Design Icons"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter
                                   color: janela.tinta(e) !== "" ? janela.tinta(e) : "#9e9e9e" }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { visible: duas; text: e ? e.nome : ""; color: c.suave; font.pixelSize: 10; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: estado; color: c.texto; font.pixelSize: duas ? 12 : 13; font.weight: Font.DemiBold; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }
                        MouseArea { id: mc; anchors.fill: parent; hoverEnabled: true; enabled: !c.editar && e !== null && janela.alternavel(e); cursorShape: Qt.PointingHandCursor; onClicked: casa.alternar(e.id) }
                    }
                }
            }
        }
    }

    // ---- modo de edição (como no Home Assistant: o cartão ganha uma barra de botões) ----------------------------
    Rectangle {
        visible: c.editar
        anchors.fill: parent; radius: c.radius; z: 9
        color: c.alvo ? Qt.rgba(0.012, 0.663, 0.957, 0.18) : "transparent"
        border.width: c.alvo ? 2 : 1; border.color: Qt.rgba(0.012, 0.663, 0.957, c.alvo ? 1 : 0.6)
    }
    Rectangle {
        visible: c.editar; z: 11
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: -6
        width: barraEd.implicitWidth + 8; height: 36; radius: 18; color: "#2b2b2b"
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
        Row {
            id: barraEd
            anchors.centerIn: parent; spacing: 0
            Repeater {
                model: [["drag", "a"], ["content-copy", "d"], ["pencil", "e"], ["delete", "x"]]
                delegate: Rectangle {
                    required property var modelData
                    width: 32; height: 32; radius: 16; color: be.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Text { anchors.centerIn: parent; text: c.ic(modelData[0]); font.family: "Material Design Icons"; font.pixelSize: 18
                           color: modelData[1] === "x" ? "#ef5350" : "#e1e1e1" }
                    MouseArea {
                        id: be
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        enabled: modelData[1] !== "a"
                        onClicked: modelData[1] === "x" ? c.pedirApagar() : modelData[1] === "e" ? c.pedirEditar() : c.pedirDuplicar()
                    }
                }
            }
        }
    }
}
