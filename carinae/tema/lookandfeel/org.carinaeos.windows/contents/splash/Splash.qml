/*
    CarinaeOS — ecrã de arranque da sessão (KSplash)
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: root
    color: "#05060B"

    property int stage

    onStageChanged: {
        if (stage == 2) {
            entrada.running = true;
        }
    }

    Image {
        anchors.fill: parent
        source: "/usr/share/wallpapers/CarinaeOS/contents/images/3840x2160.jpg"
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0.35
    }

    Item {
        id: conteudo
        anchors.fill: parent
        opacity: 0

        Image {
            id: estrela
            readonly property real tamanho: Kirigami.Units.gridUnit * 7
            anchors.centerIn: parent
            source: "images/estrela.svg"
            sourceSize.width: tamanho
            sourceSize.height: tamanho

            // a estrela "respira" enquanto a sessão carrega
            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: Kirigami.Units.longDuration > 1
                NumberAnimation { from: 1.0; to: 1.08; duration: 1100; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.08; to: 1.0; duration: 1100; easing.type: Easing.InOutSine }
            }
        }

        Text {
            anchors.top: estrela.bottom
            anchors.topMargin: Kirigami.Units.gridUnit * 1.5
            anchors.horizontalCenter: parent.horizontalCenter
            text: "CarinaeOS"
            color: "#F3EDE4"
            font.pixelSize: Kirigami.Units.gridUnit * 1.6
            font.letterSpacing: Kirigami.Units.gridUnit * 0.25
            font.weight: Font.Light
        }
    }

    OpacityAnimator {
        id: entrada
        running: false
        target: conteudo
        from: 0
        to: 1
        duration: Kirigami.Units.veryLongDuration * 2
        easing.type: Easing.InOutQuad
    }
}
