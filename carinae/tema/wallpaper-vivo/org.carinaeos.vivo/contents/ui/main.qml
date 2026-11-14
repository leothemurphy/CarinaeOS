/*
    CarinaeOS — papel de parede animado: a nebulosa sobre o lago, viva.
    Aproximação lenta (efeito Ken Burns), a nebulosa a respirar, estrelas a cintilar,
    uma estrela cadente de vez em quando e reflexos a correr no lago.
    Tudo com transformações e opacidades (leve para a placa gráfica).
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import org.kde.plasma.plasmoid

WallpaperItem {
    id: raiz

    readonly property int variante: raiz.configuration.Variante === 2 ? 2 : 1
    readonly property string pasta: "/usr/share/wallpapers/CarinaeOS-NebulosaSobreOLago" + (variante === 2 ? "2" : "")
    // brilho principal da nebulosa (fração do ecrã) e linha do horizonte de cada cena
    readonly property point nucleo: variante === 2 ? Qt.point(0.50, 0.30) : Qt.point(0.53, 0.33)
    readonly property real horizonte: 0.72

    Rectangle { anchors.fill: parent; color: "#0b0a24" }

    Item {
        id: cena
        anchors.fill: parent
        clip: true

        Image {
            id: imagem
            anchors.fill: parent
            source: "file://" + raiz.pasta + "/contents/images/" + (raiz.width > 2000 ? "3840x2160.jpg" : "2560x1440.jpg")
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            smooth: true
            transformOrigin: Item.Center
            property real deriva: 0
            scale: 1.06 + 0.05 * deriva
            x: (deriva - 0.5) * raiz.width * 0.018
            y: (0.5 - deriva) * raiz.height * 0.010
            SequentialAnimation on deriva {
                loops: Animation.Infinite
                NumberAnimation { from: 0; to: 1; duration: 75000; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1; to: 0; duration: 75000; easing.type: Easing.InOutSine }
            }
        }

        // a nebulosa a "respirar": um brilho suave sobre o núcleo
        Image {
            id: brilho
            source: "../images/brilho.png"
            width: raiz.width * 0.55
            height: width
            x: raiz.width * raiz.nucleo.x - width / 2 + imagem.x
            y: raiz.height * raiz.nucleo.y - height / 2 + imagem.y
            opacity: 0.4
            scale: 0.9
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.9; duration: 9000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.35; duration: 9000; easing.type: Easing.InOutSine }
            }
            SequentialAnimation on scale {
                loops: Animation.Infinite
                NumberAnimation { to: 1.05; duration: 13000; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.9; duration: 13000; easing.type: Easing.InOutSine }
            }
        }

        // estrelas a cintilar (posições fixas, ritmos diferentes)
        Repeater {
            model: 46
            delegate: Item {
                id: estrela
                required property int index
                function aleatorio(k: int): real {
                    const v = Math.sin((index + 1) * 12.9898 + k * 78.233) * 43758.5453;
                    return v - Math.floor(v);
                }
                readonly property real tam: 1.2 + aleatorio(3) * (aleatorio(5) > 0.85 ? 3.2 : 1.4)
                x: aleatorio(1) * raiz.width + imagem.x
                y: aleatorio(2) * raiz.height * (raiz.horizonte - 0.12) + imagem.y
                width: tam * 6; height: width
                opacity: 0.2
                Rectangle {           // halo
                    anchors.centerIn: parent
                    width: estrela.tam * 4; height: width; radius: width / 2
                    color: Qt.rgba(0.85, 0.85, 1, 0.18)
                }
                Rectangle {           // ponto
                    anchors.centerIn: parent
                    width: estrela.tam; height: width; radius: width / 2
                    color: estrela.aleatorio(7) > 0.7 ? "#ffe9f4" : "#e9efff"
                }
                Rectangle {           // raios em cruz nas maiores
                    visible: estrela.tam > 3
                    anchors.centerIn: parent
                    width: estrela.tam * 6; height: 1; color: Qt.rgba(1, 1, 1, 0.5)
                }
                Rectangle {
                    visible: estrela.tam > 3
                    anchors.centerIn: parent
                    width: 1; height: estrela.tam * 6; color: Qt.rgba(1, 1, 1, 0.5)
                }
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    PauseAnimation { duration: estrela.aleatorio(4) * 4000 }
                    NumberAnimation { to: 1; duration: 1200 + estrela.aleatorio(6) * 2600; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.15; duration: 1200 + estrela.aleatorio(8) * 2600; easing.type: Easing.InOutSine }
                }
            }
        }

        // estrela cadente, de vez em quando
        Item {
            id: cadente
            property real t: 0
            property real x0: 0.2
            property real y0: 0.08
            visible: t > 0 && t < 1
            x: raiz.width * (x0 + t * 0.22)
            y: raiz.height * (y0 + t * 0.12)
            rotation: 28
            opacity: t < 0.15 ? t / 0.15 : (1 - t) / 0.85
            Rectangle {
                width: raiz.width * 0.09; height: 2; radius: 1
                anchors.right: parent.right
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Qt.rgba(1, 0.95, 1, 0.95) }
                }
            }
            SequentialAnimation {
                running: true
                loops: Animation.Infinite
                PauseAnimation { duration: 14000 }
                ScriptAction { script: { cadente.x0 = 0.1 + Math.random() * 0.55; cadente.y0 = 0.04 + Math.random() * 0.2; } }
                NumberAnimation { target: cadente; property: "t"; from: 0; to: 1; duration: 1300; easing.type: Easing.OutQuad }
                PropertyAction { target: cadente; property: "t"; value: 0 }
                PauseAnimation { duration: 9000 }
            }
        }

        // o lago: reflexos de luz a correr na água
        Item {
            id: lago
            x: 0
            y: raiz.height * raiz.horizonte + raiz.height * 0.03
            width: raiz.width
            height: raiz.height - y
            clip: true
            Repeater {
                model: 18
                delegate: Rectangle {
                    id: onda
                    required property int index
                    function aleatorio(k: int): real {
                        const v = Math.sin((index + 11) * 91.345 + k * 47.853) * 24634.6345;
                        return v - Math.floor(v);
                    }
                    readonly property real base: 0.36 + aleatorio(1) * 0.28      // perto do reflexo central
                    height: 1 + Math.round(aleatorio(2) * 1.5)
                    width: raiz.width * (0.03 + aleatorio(3) * 0.08)
                    y: lago.height * (0.05 + aleatorio(4) * 0.9)
                    x: raiz.width * base - width / 2
                    radius: height
                    readonly property color tom: aleatorio(5) > 0.5 ? Qt.rgba(1, 0.75, 0.95, 0.55) : Qt.rgba(0.75, 0.8, 1, 0.5)
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 0.5; color: onda.tom }
                        GradientStop { position: 1; color: "transparent" }
                    }
                    opacity: 0
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PauseAnimation { duration: onda.aleatorio(6) * 5000 }
                        NumberAnimation { to: 0.9; duration: 1600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0; duration: 2200; easing.type: Easing.InOutSine }
                    }
                    SequentialAnimation on x {
                        loops: Animation.Infinite
                        NumberAnimation { to: raiz.width * onda.base - onda.width / 2 + raiz.width * 0.015; duration: 5000 + onda.aleatorio(7) * 3000; easing.type: Easing.InOutSine }
                        NumberAnimation { to: raiz.width * onda.base - onda.width / 2 - raiz.width * 0.015; duration: 5000 + onda.aleatorio(8) * 3000; easing.type: Easing.InOutSine }
                    }
                }
            }
        }

        // névoa a passar devagar sobre as montanhas
        Rectangle {
            width: raiz.width * 0.6
            height: raiz.height * 0.07
            radius: height / 2
            y: raiz.height * (raiz.horizonte - 0.11)
            opacity: 0.18
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.5; color: Qt.rgba(0.85, 0.85, 1, 0.6) }
                GradientStop { position: 1; color: "transparent" }
            }
            SequentialAnimation on x {
                loops: Animation.Infinite
                NumberAnimation { from: -raiz.width * 0.6; to: raiz.width; duration: 140000 }
            }
        }
    }
}
