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

    readonly property int largura: dados.largura || 1
    readonly property var est: janela.est
    readonly property var e0: dados.ents.length ? (est[dados.ents[0]] || null) : null
    readonly property string t0: janela.tinta(e0)
    readonly property string nome0: dados.titulo !== "" ? dados.titulo : (e0 ? e0.nome : "Não encontrado")
    readonly property bool semFundo: dados.tipo === "texto" || dados.tipo === "chips"
    readonly property int pad: semFundo || dados.tipo === "camera" ? 0 : 12
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
                            texto: titulo, chips: chips, pessoa: pessoa })[c.dados.tipo] || lista
    }

    // ---- entidade (Mushroom entity card) -----------------------------------------------------------
    Component {
        id: botao
        Item {
            implicitHeight: 40
            Cabeca { anchors.fill: parent; icone: c.icE(c.e0); tinta: c.t0; primario: c.nome0; secundario: janela.estadoTexto(c.e0) }
            MouseArea {
                anchors.fill: parent; anchors.margins: -12
                enabled: !c.editar && c.e0 !== null && janela.alternavel(c.e0); cursorShape: Qt.PointingHandCursor
                onClicked: casa.alternar(c.e0.id)
            }
        }
    }
    // ---- pessoa (Mushroom person card) ---------------------------------------------------------------
    Component {
        id: pessoa
        Item {
            implicitHeight: 40
            Cabeca { anchors.fill: parent; icone: c.icE(c.e0); tinta: c.t0; primario: c.nome0; secundario: janela.estadoTexto(c.e0) }
            Rectangle {       // o selo: em casa / fora
                x: 26; y: 26; width: 16; height: 16; radius: 8; color: c.t0 !== "" ? "#4caf50" : "#616161"
                border.width: 2; border.color: "#1c1c1c"
                Text { anchors.centerIn: parent; text: c.ic(c.t0 !== "" ? "home" : "walk"); font.family: "Material Design Icons"; font.pixelSize: 9; color: "white" }
            }
        }
    }
    // ---- luz (Mushroom light card) -------------------------------------------------------------------
    Component {
        id: luz
        Column {
            spacing: 12
            readonly property bool on: c.ligado(c.e0)
            Cabeca {
                width: parent.width; icone: c.icE(c.e0); tinta: c.t0; primario: c.nome0
                secundario: c.e0 ? (parent.on ? (c.e0.brilho > 0 ? c.e0.brilho + "%" : "Acesa") : janela.estadoTexto(c.e0)) : ""
                formaClicavel: !c.editar && c.e0 !== null; onClicouForma: casa.alternar(c.e0.id)
            }
            Row {
                width: parent.width; spacing: 12
                Barra {
                    width: parent.width - 54; tinta: "#ffc107"; ativa: !c.editar && c.e0 !== null
                    valor: c.e0 && parent.parent.on ? Math.max(1, c.e0.brilho) : 0
                    onSoltou: (v) => { if (v < 1) { if (c.ligado(c.e0)) casa.alternar(c.e0.id) } else casa.brilho(c.e0.id, v) }
                }
                BotaoM { icone: c.ic("power"); tinta: parent.parent.on ? "#ffc107" : ""; ativo: !c.editar && c.e0 !== null; onClicado: casa.alternar(c.e0.id) }
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
                           text: e ? e.nome : modelData; color: c.texto; font.pixelSize: 14 }
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
                layer.enabled: true
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
                anchors.fill: parent; visible: false; layer.enabled: true
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
    // ---- titulo (Mushroom title card): sem fundo; {saudacao} vira "Bom dia"/"Boa tarde"/"Boa noite" ---------
    Component {
        id: titulo
        Column {
            spacing: 2; topPadding: 6; bottomPadding: 4
            readonly property var linhas: janela.saudar(c.dados.titulo || "Título").split("\n")
            Text { width: parent.width; wrapMode: Text.WordWrap; text: parent.linhas[0]; color: c.texto; font.pixelSize: 24; font.weight: Font.Bold }
            Text { width: parent.width; wrapMode: Text.WordWrap; text: parent.linhas.slice(1).join("\n"); color: c.suave; font.pixelSize: 14; visible: text !== "" }
        }
    }
    // ---- chips (Mushroom chips card): sem fundo, uma fila de pílulas ----------------------------------------
    Component {
        id: chips
        Flow {
            spacing: 8
            Repeater {
                model: c.dados.ents
                delegate: Rectangle {
                    required property string modelData
                    readonly property var e: c.est[modelData] || null
                    readonly property bool valor: e !== null && ["sensor", "weather", "climate", "person", "binary_sensor"].indexOf(e.dominio) !== -1
                    width: lin.implicitWidth + 24; height: 36; radius: 18
                    color: mc.containsMouse && mc.enabled ? "#262626" : "#1c1c1c"; border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.07)
                    Row {
                        id: lin
                        anchors.centerIn: parent; spacing: 6
                        Text { text: c.icE(e); font.family: "Material Design Icons"; font.pixelSize: 18; anchors.verticalCenter: parent.verticalCenter
                               color: janela.tinta(e) !== "" ? janela.tinta(e) : "#9e9e9e" }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter; color: c.texto; font.pixelSize: 13; font.weight: Font.DemiBold
                            text: !e ? modelData : e.dominio === "sensor" ? janela.num(e.estado) + (e.unidade ? " " + e.unidade : "")
                                 : e.dominio === "weather" ? (e.temperatura !== "" ? janela.num(e.temperatura) + " °C" : janela.condicao(e.estado))
                                 : e.dominio === "climate" ? (e.temperatura !== "" ? janela.num(e.temperatura) + " °C" : janela.estadoTexto(e))
                                 : valor ? janela.estadoTexto(e) : e.nome
                        }
                    }
                    MouseArea { id: mc; anchors.fill: parent; hoverEnabled: true; enabled: !c.editar && e !== null && janela.alternavel(e); cursorShape: Qt.PointingHandCursor; onClicked: casa.alternar(e.id) }
                }
            }
        }
    }

    // ---- modo de edição (como no Home Assistant: o cartão ganha uma barra de botões) ----------------------------
    Rectangle {
        visible: c.editar
        anchors.fill: parent; radius: c.radius; color: "transparent"
        border.width: 1; border.color: Qt.rgba(0.012, 0.663, 0.957, 0.6)
    }
    Rectangle {
        visible: c.editar
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: -6
        width: barraEd.implicitWidth + 8; height: 36; radius: 18; color: "#2b2b2b"
        border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.1)
        Row {
            id: barraEd
            anchors.centerIn: parent; spacing: 0
            Repeater {
                model: [["arrow-left", "m-"], ["arrow-right", "m+"], ["pencil", "e"], ["delete", "x"]]
                delegate: Rectangle {
                    required property var modelData
                    width: 32; height: 32; radius: 16; color: be.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                    Text { anchors.centerIn: parent; text: c.ic(modelData[0]); font.family: "Material Design Icons"; font.pixelSize: 18
                           color: modelData[1] === "x" ? "#ef5350" : "#e1e1e1" }
                    MouseArea {
                        id: be
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: modelData[1] === "x" ? c.pedirApagar() : modelData[1] === "e" ? c.pedirEditar() : c.pedirMover(modelData[1] === "m+" ? 1 : -1)
                    }
                }
            }
        }
    }
}
