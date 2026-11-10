// CarinaeOS - Casa: um cartão do painel (o tipo escolhe o desenho)
import QtQuick
import QtQuick.Controls

Rectangle {
    id: c
    required property var dados           // {tipo, titulo, ents, largura}
    required property int indice
    property bool editar: false
    signal pedirEditar()
    signal pedirApagar()
    signal pedirMover(int para)

    readonly property var est: janela.est
    readonly property var e0: dados.ents.length ? (est[dados.ents[0]] || null) : null
    readonly property color texto: "#f6f2ff"
    readonly property color suave: "#b9b0cc"
    readonly property color ambar: "#ffb46e"
    readonly property bool aceso: e0 !== null && ["on", "open", "playing", "unlocked", "heat", "cool", "heat_cool", "auto", "home"].indexOf(e0.estado) !== -1

    function nome(e) { return e ? e.nome : "—" }
    function estadoTexto(e) {
        if (!e) return "não encontrado"
        if (e.dominio === "sensor") return e.estado + (e.unidade ? " " + e.unidade : "")
        if (e.dominio === "light" && e.estado === "on" && e.brilho >= 0) return "acesa · " + e.brilho + "%"
        if (e.dominio === "climate") return (e.temperatura !== "" ? e.temperatura + "° · " : "") + (e.alvo !== "" ? "alvo " + e.alvo + "°" : e.estado)
        return ({ on: "ligado", off: "desligado", open: "aberto", closed: "fechado", opening: "a abrir", closing: "a fechar",
                  playing: "a tocar", paused: "em pausa", idle: "parado", standby: "em espera", locked: "trancado",
                  unlocked: "destrancado", unavailable: "indisponível", unknown: "desconhecido", home: "em casa",
                  not_home: "fora", heat: "a aquecer", cool: "a arrefecer", auto: "automático" })[e.estado] || e.estado
    }
    function simbolo(e) {
        if (!e) return "•"
        const l = ["on", "open", "playing", "unlocked"].indexOf(e.estado) !== -1
        return ({ light: "💡", switch: "⏻", input_boolean: "⏻", fan: "❋", cover: l ? "▤" : "▦", lock: l ? "🔓" : "🔒",
                  climate: "🌡", media_player: "♫", sensor: e.classe === "temperature" ? "🌡" : e.classe === "humidity" ? "💧" :
                  e.classe === "power" || e.classe === "energy" ? "⚡" : e.classe === "battery" ? "🔋" : "◔",
                  binary_sensor: l ? "●" : "○", scene: "✦", script: "▶", button: "◉", input_button: "◉", automation: "⚙",
                  camera: "📷", weather: "☀", person: "👤", water_heater: "♨", humidifier: "💧" })[e.dominio] || "•"
    }
    function tempoIcone(cond) {
        return ({ sunny: "☀", "clear-night": "☾", partlycloudy: "⛅", cloudy: "☁", rainy: "🌧", pouring: "🌧", lightning: "⛈",
                  "lightning-rainy": "⛈", snowy: "❄", fog: "🌫", windy: "🌬", exceptional: "!" })[cond] || "☁"
    }

    radius: 22
    color: aceso && (dados.tipo === "botao" || dados.tipo === "luz") ? Qt.rgba(1, 0.74, 0.42, 0.20) : Qt.rgba(1, 1, 1, 0.055)
    border.color: aceso && (dados.tipo === "botao" || dados.tipo === "luz") ? Qt.rgba(1, 0.72, 0.45, 0.55) : Qt.rgba(1, 1, 1, 0.09)
    Behavior on color { ColorAnimation { duration: 220 } }
    implicitHeight: Math.max(118, corpo.item ? corpo.item.implicitHeight + 36 : 118)

    Text {
        id: tit
        visible: dados.titulo !== "" && dados.tipo !== "texto"
        x: 18; y: 14; width: parent.width - 36; elide: Text.ElideRight
        text: dados.titulo; color: c.suave; font.pixelSize: 12; font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase
    }

    Loader {
        id: corpo
        x: 18; y: tit.visible ? 38 : 18; width: parent.width - 36
        sourceComponent: ({ botao: botao, luz: luz, entidades: lista, sensor: sensor, grafico: grafico, clima: clima,
                            cenas: cenas, media: media, camera: camera, estores: estores, tempo: tempo, numero: numero,
                            texto: textoC })[dados.tipo] || lista
    }

    // ---- botao ----------------------------------------------------------------------------------
    Component {
        id: botao
        Item {
            implicitHeight: 80
            Rectangle {
                width: 48; height: 48; radius: 24
                color: c.aceso ? "#ffd27a" : Qt.rgba(1, 1, 1, 0.09)
                Text { anchors.centerIn: parent; text: c.simbolo(c.e0); font.pixelSize: 21; color: c.aceso ? "#5a3300" : c.suave }
            }
            Column {
                y: 54; width: parent.width
                Text { width: parent.width; elide: Text.ElideRight; text: c.nome(c.e0); color: c.texto; font.pixelSize: 15; font.weight: Font.DemiBold }
                Text { text: c.estadoTexto(c.e0); color: c.suave; font.pixelSize: 12 }
            }
            MouseArea { anchors.fill: parent; enabled: !c.editar && c.e0 !== null; cursorShape: Qt.PointingHandCursor; onClicked: casa.alternar(c.e0.id) }
        }
    }
    // ---- luz ------------------------------------------------------------------------------------
    Component {
        id: luz
        Column {
            spacing: 10
            Row {
                width: parent.width; spacing: 12
                Rectangle {
                    width: 44; height: 44; radius: 22
                    color: c.aceso ? "#ffd27a" : Qt.rgba(1, 1, 1, 0.09)
                    Text { anchors.centerIn: parent; text: "💡"; font.pixelSize: 19; opacity: c.aceso ? 1 : 0.55 }
                    MouseArea { anchors.fill: parent; enabled: !c.editar && c.e0 !== null; cursorShape: Qt.PointingHandCursor; onClicked: casa.alternar(c.e0.id) }
                }
                Column {
                    width: parent.width - 56; anchors.verticalCenter: parent.verticalCenter
                    Text { width: parent.width; elide: Text.ElideRight; text: c.nome(c.e0); color: c.texto; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Text { text: c.estadoTexto(c.e0); color: c.suave; font.pixelSize: 12 }
                }
            }
            Slider {
                width: parent.width; from: 1; to: 100; stepSize: 1; enabled: !c.editar && c.e0 !== null
                value: c.e0 && c.e0.estado === "on" ? Math.max(1, c.e0.brilho) : 1
                onPressedChanged: if (!pressed) casa.brilho(c.e0.id, Math.round(value))
            }
        }
    }
    // ---- lista de entidades -------------------------------------------------------------------------
    Component {
        id: lista
        Column {
            spacing: 4
            Repeater {
                model: c.dados.ents
                delegate: Item {
                    required property string modelData
                    readonly property var e: c.est[modelData] || null
                    readonly property bool liga: e !== null && ["light", "switch", "fan", "input_boolean", "lock", "cover", "scene", "script", "button", "input_button", "automation", "media_player"].indexOf(e.dominio) !== -1
                    readonly property bool on: e !== null && ["on", "open", "playing", "unlocked"].indexOf(e.estado) !== -1
                    width: parent.width; height: 40
                    Text { x: 0; anchors.verticalCenter: parent.verticalCenter; text: c.simbolo(e); font.pixelSize: 16; color: on ? c.ambar : c.suave; width: 26 }
                    Text { x: 28; width: parent.width - 130; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: c.nome(e); color: c.texto; font.pixelSize: 14 }
                    Text { visible: !liga || ["scene", "script", "button", "input_button", "automation"].indexOf(e ? e.dominio : "") !== -1
                           anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: e && ["scene", "script", "button", "input_button", "automation"].indexOf(e.dominio) !== -1 ? "Ativar ›" : c.estadoTexto(e)
                           color: c.suave; font.pixelSize: 13 }
                    Switch {
                        visible: liga && ["scene", "script", "button", "input_button", "automation"].indexOf(e ? e.dominio : "") === -1
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        checked: on; enabled: !c.editar
                        onToggled: casa.alternar(e.id)
                    }
                    MouseArea { anchors.fill: parent; z: -1; enabled: liga && !c.editar; onClicked: casa.alternar(e.id) }
                }
            }
        }
    }
    // ---- sensor ----------------------------------------------------------------------------------
    Component {
        id: sensor
        Column {
            spacing: 2
            Text { text: c.simbolo(c.e0) + "  " + c.nome(c.e0); color: c.suave; font.pixelSize: 13; width: parent.width; elide: Text.ElideRight }
            Row {
                spacing: 6
                Text { text: c.e0 ? (c.e0.dominio === "binary_sensor" ? c.estadoTexto(c.e0) : c.e0.estado) : "—"; color: c.texto; font.pixelSize: 40; font.weight: Font.Light }
                Text { text: c.e0 && c.e0.dominio === "sensor" ? c.e0.unidade : ""; color: c.suave; font.pixelSize: 18; anchors.baseline: parent.children[0].baseline }
            }
        }
    }
    // ---- grafico ---------------------------------------------------------------------------------
    Component {
        id: grafico
        Column {
            spacing: 6
            Row {
                width: parent.width
                Text { width: parent.width - valor.width; elide: Text.ElideRight; text: c.simbolo(c.e0) + "  " + c.nome(c.e0); color: c.suave; font.pixelSize: 13 }
                Text { id: valor; text: c.e0 ? c.e0.estado + " " + c.e0.unidade : ""; color: c.texto; font.pixelSize: 18; font.weight: Font.DemiBold }
            }
            Canvas {
                id: tela
                width: parent.width; height: 90
                readonly property var pts: janela.extras.hist[c.dados.ents[0]] || []
                onPtsChanged: requestPaint()
                onWidthChanged: requestPaint()
                onPaint: {
                    const g = getContext("2d"); g.reset()
                    if (pts.length < 2) { g.fillStyle = "#7d7590"; g.font = "12px Inter"; g.fillText("A juntar o histórico…", 0, 50); return }
                    let mx = pts[pts.length - 1].x || 1, lo = Infinity, hi = -Infinity
                    for (const p of pts) { lo = Math.min(lo, p.y); hi = Math.max(hi, p.y) }
                    if (hi - lo < 0.001) { hi += 1; lo -= 1 }
                    const X = p => p.x / mx * width, Y = p => height - 6 - (p.y - lo) / (hi - lo) * (height - 16)
                    const grad = g.createLinearGradient(0, 0, 0, height)
                    grad.addColorStop(0, "rgba(255,170,110,0.45)"); grad.addColorStop(1, "rgba(224,69,124,0.0)")
                    g.beginPath(); g.moveTo(0, height)
                    for (const p of pts) g.lineTo(X(p), Y(p))
                    g.lineTo(width, height); g.closePath(); g.fillStyle = grad; g.fill()
                    g.beginPath(); for (let i = 0; i < pts.length; i++) (i ? g.lineTo : g.moveTo).call(g, X(pts[i]), Y(pts[i]))
                    g.strokeStyle = "#ffb46e"; g.lineWidth = 2; g.stroke()
                    g.fillStyle = "#9b93ad"; g.font = "11px Inter"
                    g.fillText(hi.toFixed(1), width - 34, 12); g.fillText(lo.toFixed(1), width - 34, height - 2)
                }
            }
            Text { text: "últimas 24 horas"; color: c.suave; font.pixelSize: 11 }
        }
    }
    // ---- clima -----------------------------------------------------------------------------------
    Component {
        id: clima
        Column {
            spacing: 8
            Text { width: parent.width; elide: Text.ElideRight; text: "🌡  " + c.nome(c.e0); color: c.suave; font.pixelSize: 13 }
            Row {
                spacing: 16
                Text { text: c.e0 && c.e0.alvo !== "" ? c.e0.alvo + "°" : "—"; color: c.texto; font.pixelSize: 44; font.weight: Font.Light }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: c.e0 && c.e0.temperatura !== "" ? "agora " + c.e0.temperatura + "°" : ""; color: c.suave; font.pixelSize: 13 }
                    Text { text: c.e0 ? (({ off: "desligado", heat: "a aquecer", cool: "a arrefecer", heat_cool: "automático", auto: "automático", dry: "desumidificar", fan_only: "só ventilação" })[c.e0.estado] || c.e0.estado) : ""; color: c.ambar; font.pixelSize: 13 }
                }
            }
            Row {
                spacing: 8
                Repeater {
                    model: ["−", "+", "⏻"]
                    delegate: Rectangle {
                        required property string modelData
                        width: 52; height: 34; radius: 17; color: Qt.rgba(1, 1, 1, 0.09)
                        Text { anchors.centerIn: parent; text: modelData; color: c.texto; font.pixelSize: 18 }
                        MouseArea {
                            anchors.fill: parent; enabled: !c.editar && c.e0 !== null; cursorShape: Qt.PointingHandCursor
                            onClicked: modelData === "⏻" ? casa.alternar(c.e0.id) : casa.temperatura(c.e0.id, (parseFloat(c.e0.alvo) || 21) + (modelData === "+" ? 0.5 : -0.5))
                        }
                    }
                }
            }
        }
    }
    // ---- cenas -----------------------------------------------------------------------------------
    Component {
        id: cenas
        Flow {
            spacing: 8
            Repeater {
                model: c.dados.ents
                delegate: Rectangle {
                    required property string modelData
                    readonly property var e: c.est[modelData] || null
                    width: cn.implicitWidth + 40; height: 42; radius: 21
                    color: ma.pressed ? Qt.rgba(1, 0.7, 0.43, 0.4) : Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 0.72, 0.45, 0.35)
                    Text { id: cn; anchors.centerIn: parent; text: "✦  " + c.nome(e); color: c.texto; font.pixelSize: 14; font.weight: Font.DemiBold }
                    MouseArea { id: ma; anchors.fill: parent; enabled: !c.editar && e !== null; cursorShape: Qt.PointingHandCursor; onClicked: casa.alternar(e.id) }
                }
            }
        }
    }
    // ---- som e TV --------------------------------------------------------------------------------
    Component {
        id: media
        Column {
            spacing: 8
            Text { width: parent.width; elide: Text.ElideRight; text: "♫  " + c.nome(c.e0) + " · " + c.estadoTexto(c.e0); color: c.suave; font.pixelSize: 13 }
            Text { width: parent.width; elide: Text.ElideRight; text: c.e0 && c.e0.titulo_media ? c.e0.titulo_media : "Nada a tocar"; color: c.texto; font.pixelSize: 18; font.weight: Font.DemiBold }
            Text { width: parent.width; elide: Text.ElideRight; text: c.e0 ? c.e0.artista : ""; color: c.suave; font.pixelSize: 13; visible: text !== "" }
            Row {
                spacing: 10
                Repeater {
                    model: [["⏮", "anterior"], [c.e0 && c.e0.estado === "playing" ? "⏸" : "▶", "pausa"], ["⏭", "seguinte"]]
                    delegate: Rectangle {
                        required property var modelData
                        width: 46; height: 46; radius: 23; color: modelData[1] === "pausa" ? "#ffb46e" : Qt.rgba(1, 1, 1, 0.09)
                        Text { anchors.centerIn: parent; text: modelData[0]; color: modelData[1] === "pausa" ? "#3a1d00" : c.texto; font.pixelSize: 18 }
                        MouseArea { anchors.fill: parent; enabled: !c.editar && c.e0 !== null; cursorShape: Qt.PointingHandCursor; onClicked: casa.media(c.e0.id, modelData[1]) }
                    }
                }
                Slider {
                    width: Math.max(80, c.width - 220); anchors.verticalCenter: parent.verticalCenter
                    from: 0; to: 100; value: c.e0 ? c.e0.volume : 0; enabled: !c.editar && c.e0 !== null
                    onPressedChanged: if (!pressed) casa.valor(c.e0.id, String(Math.round(value)))
                }
            }
        }
    }
    // ---- camara ----------------------------------------------------------------------------------
    Component {
        id: camera
        Column {
            spacing: 6
            Text { width: parent.width; elide: Text.ElideRight; text: "📷  " + c.nome(c.e0); color: c.suave; font.pixelSize: 13 }
            Rectangle {
                width: parent.width; height: width * 9 / 16; radius: 14; color: "#000"; clip: true
                Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; asynchronous: true; cache: false
                        source: janela.extras.cams[c.dados.ents[0]] || "" }
                Text { anchors.centerIn: parent; visible: !janela.extras.cams[c.dados.ents[0]]; text: "A carregar a imagem…"; color: c.suave }
            }
        }
    }
    // ---- estores ---------------------------------------------------------------------------------
    Component {
        id: estores
        Column {
            spacing: 10
            Text { width: parent.width; elide: Text.ElideRight; text: c.nome(c.e0); color: c.texto; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text { text: c.estadoTexto(c.e0) + (c.e0 && c.e0.posicao >= 0 ? " · " + c.e0.posicao + "%" : ""); color: c.suave; font.pixelSize: 12 }
            Row {
                spacing: 8
                Repeater {
                    model: [["▲ Abrir", 1], ["■ Parar", 0], ["▼ Fechar", -1]]
                    delegate: Rectangle {
                        required property var modelData
                        width: (c.width - 36 - 16) / 3; height: 36; radius: 18; color: Qt.rgba(1, 1, 1, 0.09)
                        Text { anchors.centerIn: parent; text: modelData[0]; color: c.texto; font.pixelSize: 13 }
                        MouseArea { anchors.fill: parent; enabled: !c.editar && c.e0 !== null; cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData[1] === 0 ? casa.pararEstore(c.e0.id) : casa.estore(c.e0.id, modelData[1] > 0) }
                    }
                }
            }
        }
    }
    // ---- tempo -----------------------------------------------------------------------------------
    Component {
        id: tempo
        Column {
            spacing: 8
            Row {
                spacing: 14
                Text { text: c.tempoIcone(c.e0 ? c.e0.estado : ""); font.pixelSize: 44; color: c.ambar }
                Column {
                    Text { text: c.e0 ? c.e0.temperatura + "°" : "—"; color: c.texto; font.pixelSize: 34; font.weight: Font.Light }
                    Text { text: (c.e0 ? c.nome(c.e0) : "") + (c.e0 && c.e0.humidade !== "" ? " · 💧 " + c.e0.humidade + "%" : ""); color: c.suave; font.pixelSize: 12 }
                }
            }
            Row {
                spacing: 16; visible: c.e0 && c.e0.previsao.length > 0
                Repeater {
                    model: c.e0 ? c.e0.previsao : []
                    delegate: Column {
                        required property var modelData
                        spacing: 2
                        Text { text: modelData.d ? new Date(modelData.d).toLocaleDateString(Qt.locale("pt_BR"), "ddd") : ""; color: c.suave; font.pixelSize: 11 }
                        Text { text: c.tempoIcone(modelData.c); font.pixelSize: 18; color: c.texto }
                        Text { text: Math.round(modelData.t) + "°" + (modelData.m !== undefined && modelData.m !== null ? " " + Math.round(modelData.m) + "°" : ""); color: c.texto; font.pixelSize: 12 }
                    }
                }
            }
        }
    }
    // ---- numero / escolha ---------------------------------------------------------------------------
    Component {
        id: numero
        Column {
            spacing: 8
            Text { width: parent.width; elide: Text.ElideRight; text: c.nome(c.e0) + " · " + (c.e0 ? c.e0.estado + " " + c.e0.unidade : ""); color: c.texto; font.pixelSize: 14 }
            Slider {
                visible: c.e0 && (c.e0.dominio === "input_number" || c.e0.dominio === "number")
                width: parent.width; from: c.e0 ? c.e0.minimo : 0; to: c.e0 ? c.e0.maximo : 100; stepSize: c.e0 ? c.e0.passo : 1
                value: c.e0 ? parseFloat(c.e0.estado) || 0 : 0; enabled: !c.editar
                onPressedChanged: if (!pressed) casa.valor(c.e0.id, String(value))
            }
            ComboBox {
                visible: c.e0 && (c.e0.dominio === "select" || c.e0.dominio === "input_select")
                width: parent.width; model: c.e0 ? c.e0.opcoes : []
                currentIndex: c.e0 ? c.e0.opcoes.indexOf(c.e0.estado) : -1; enabled: !c.editar
                onActivated: casa.valor(c.e0.id, currentText)
            }
        }
    }
    // ---- texto -----------------------------------------------------------------------------------
    Component {
        id: textoC
        Text { width: parent.width; wrapMode: Text.WordWrap; text: c.dados.titulo || "Texto"; color: c.texto; font.pixelSize: 22; font.weight: Font.DemiBold; textFormat: Text.MarkdownText }
    }

    // ---- barra de edicao ---------------------------------------------------------------------------
    Row {
        visible: c.editar
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
        spacing: 4
        Repeater {
            model: [["‹", "m-"], ["›", "m+"], ["✎", "e"], ["✕", "x"]]
            delegate: Rectangle {
                required property var modelData
                width: 28; height: 28; radius: 14; color: modelData[1] === "x" ? "#d9466e" : "#3b3152"
                Text { anchors.centerIn: parent; text: modelData[0]; color: "white"; font.pixelSize: 14 }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: modelData[1] === "x" ? c.pedirApagar() : modelData[1] === "e" ? c.pedirEditar() : c.pedirMover(modelData[1] === "m+" ? 1 : -1)
                }
            }
        }
    }
}
