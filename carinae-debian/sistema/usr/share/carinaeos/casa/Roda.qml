// CarinaeOS - Casa: a roda de cores das luzes (como a do Home Assistant)
// matiz = o ângulo, saturação = a distância ao centro (branco no meio)
import QtQuick

Item {
    id: r
    property real h: 0          // 0..360
    property real s: 0          // 0..100
    property bool ativa: true
    signal escolheu(real h, real s)

    property real ah: -1         // enquanto arrasta
    property real as_: 0
    readonly property real mh: ah >= 0 ? ah : h
    readonly property real ms: ah >= 0 ? as_ : s
    readonly property real raio: width / 2

    onHChanged: ah = -1
    onSChanged: ah = -1
    Timer { id: segura; interval: 6000; onTriggered: r.ah = -1 }
    implicitWidth: 240; implicitHeight: 240
    opacity: ativa ? 1 : 0.5

    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onPaint: {
            const g = getContext("2d"); g.reset()
            const cx = width / 2, cy = height / 2, R = width / 2
            for (let a = 0; a < 360; a++) {
                g.beginPath(); g.moveTo(cx, cy)
                g.arc(cx, cy, R, (a - 0.8) * Math.PI / 180, (a + 0.8) * Math.PI / 180)
                g.closePath(); g.fillStyle = Qt.hsla(a / 360, 1, 0.5, 1).toString(); g.fill()
            }
            const rg = g.createRadialGradient(cx, cy, 0, cx, cy, R)
            rg.addColorStop(0, "rgba(255,255,255,1)"); rg.addColorStop(1, "rgba(255,255,255,0)")
            g.beginPath(); g.arc(cx, cy, R, 0, 2 * Math.PI); g.fillStyle = rg; g.fill()
        }
    }
    Rectangle {     // o marcador da cor escolhida
        readonly property real ang: r.mh * Math.PI / 180
        readonly property real d: Math.min(1, r.ms / 100) * (r.raio - 4)
        x: r.raio + Math.cos(ang) * d - width / 2
        y: r.raio + Math.sin(ang) * d - height / 2
        width: 30; height: 30; radius: 15
        color: Qt.hsla(r.mh / 360, r.ms / 100, 1 - r.ms / 200, 1)
        border.width: 3; border.color: "white"
    }
    MouseArea {
        anchors.fill: parent; enabled: r.ativa; preventStealing: true; cursorShape: Qt.CrossCursor
        function ler(m) {
            const dx = m.x - r.raio, dy = m.y - r.raio
            r.ah = (Math.atan2(dy, dx) * 180 / Math.PI + 360) % 360
            r.as_ = Math.min(100, Math.sqrt(dx * dx + dy * dy) / r.raio * 100)
        }
        onPressed: (m) => ler(m)
        onPositionChanged: (m) => { if (pressed) ler(m) }
        onReleased: { r.escolheu(Math.round(r.ah), Math.round(r.as_)); segura.restart() }   // fica até o HA confirmar
    }
}
