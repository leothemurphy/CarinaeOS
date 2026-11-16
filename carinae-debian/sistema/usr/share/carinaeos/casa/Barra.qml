// CarinaeOS - Casa: a barra larga dos cartões Mushroom (brilho, volume, posição, número)
import QtQuick

Rectangle {
    id: b
    property real valor: 0              // 0..100
    property string tinta: "#ffc107"
    property bool ativa: true
    property string rotulo: ""           // texto opcional por cima ("21,5 °C")
    signal soltou(real v)

    property real arrasto: -1
    property real pendente: -1           // o valor escolhido, até o Home Assistant confirmar
    readonly property real mostrado: arrasto >= 0 ? arrasto : pendente >= 0 ? pendente : valor
    readonly property color cor: tinta
    onValorChanged: pendente = -1

    implicitHeight: 42; radius: 12
    color: Qt.rgba(cor.r, cor.g, cor.b, 0.2)
    opacity: ativa ? 1 : 0.5

    Rectangle {
        visible: b.mostrado > 0
        width: Math.max(b.radius * 2, Math.min(1, b.mostrado / 100) * b.width); height: parent.height
        radius: b.radius; color: b.cor
        Behavior on width { enabled: b.arrasto < 0; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }
    Rectangle {      // o traço que se arrasta (como no Mushroom)
        visible: b.mostrado > 0
        x: Math.max(b.radius * 2, Math.min(1, b.mostrado / 100) * b.width) - 10; y: 10
        width: 3; height: parent.height - 20; radius: 1.5; color: Qt.rgba(1, 1, 1, 0.75)
    }
    Text { anchors.centerIn: parent; text: b.rotulo; color: "#ffffff"; font.pixelSize: 13; font.weight: Font.DemiBold; visible: text !== "" }
    Timer { running: b.pendente >= 0; interval: 6000; onTriggered: b.pendente = -1 }

    MouseArea {
        anchors.fill: parent; enabled: b.ativa; preventStealing: true; cursorShape: Qt.PointingHandCursor
        function v(mx) { return Math.round(Math.max(0, Math.min(100, mx / width * 100))) }
        onPressed: (m) => b.arrasto = v(m.x)
        onPositionChanged: (m) => { if (pressed) b.arrasto = v(m.x) }
        onReleased: { b.pendente = b.arrasto; b.arrasto = -1; b.soltou(b.pendente) }
        onCanceled: b.arrasto = -1
    }
}
