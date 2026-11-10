/* CarinaeOS - apresentacao durante a instalacao (Calamares, slideshowAPI 2).
   Sem o modulo calamares.slideshow: so QtQuick, para funcionar em qualquer versao. */
import QtQuick

Item {
    id: raiz
    width: 800; height: 440
    property int atual: 0
    readonly property var slides: ["calamares-slide1.jpg", "calamares-slide2.jpg", "calamares-slide3.jpg",
                                    "calamares-slide4.jpg", "calamares-slide5.jpg"]
    property bool ativo: false

    Rectangle { anchors.fill: parent; color: "#0c0a14" }
    Repeater {
        model: raiz.slides
        delegate: Image {
            required property string modelData
            required property int index
            anchors.fill: parent
            source: modelData
            fillMode: Image.PreserveAspectCrop
            smooth: true; mipmap: true; asynchronous: true
            opacity: index === raiz.atual ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.InOutQuad } }
        }
    }
    Row {
        anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 14
        spacing: 8
        Repeater {
            model: raiz.slides.length
            delegate: Rectangle {
                required property int index
                width: index === raiz.atual ? 22 : 8; height: 8; radius: 4
                color: index === raiz.atual ? "#ffb46e" : Qt.rgba(1, 1, 1, 0.4)
                Behavior on width { NumberAnimation { duration: 250 } }
            }
        }
    }
    MouseArea { anchors.fill: parent; onClicked: raiz.atual = (raiz.atual + 1) % raiz.slides.length }
    Timer {
        interval: 7000; repeat: true; running: true
        onTriggered: raiz.atual = (raiz.atual + 1) % raiz.slides.length
    }
    function onActivate() { raiz.ativo = true }
    function onLeave() { raiz.ativo = false }
}
