/*
    CarinaeOS — "A tocar": a música do MPD na barra de cima.
    Aparece só enquanto o MPD toca (ou está em pausa). Ao passar o rato abre os controlos:
    capa, música, tempo, anterior / tocar / seguinte, aleatório, repetir, volume, abrir o Música e parar.
    Lê o MPD pelo MPRIS (ponte mpDris2): sem processos a correr de segundo a segundo.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: raiz
    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    readonly property color ambar: "#ffb46e"

    // ---- o leitor MPD entre os leitores MPRIS ------------------------------------------------
    Mpris.Mpris2Model { id: leitores }
    property int indiceMpd: -1
    Instantiator {
        model: leitores
        delegate: QtObject {
            required property int index
            required property string identity
            readonly property bool eMpd: /music player daemon|mpd/i.test(identity)
            Component.onCompleted: if (eMpd) raiz.indiceMpd = index
            Component.onDestruction: if (eMpd && raiz.indiceMpd === index) raiz.indiceMpd = -1
        }
    }
    onIndiceMpdChanged: if (indiceMpd >= 0) leitores.currentIndex = indiceMpd
    readonly property var p: indiceMpd >= 0 ? leitores.currentPlayer : null

    readonly property int estado: p ? p.playbackStatus : 0
    readonly property bool tocando: estado === Mpris.PlaybackStatus.Playing
    readonly property bool ativo: estado === Mpris.PlaybackStatus.Playing || estado === Mpris.PlaybackStatus.Paused
    readonly property string titulo: p ? (p.track || "") : ""
    readonly property string artista: p ? (p.artist || "") : ""
    readonly property string album: p ? (p.album || "") : ""
    readonly property string capa: {
        if (p && p.artUrl) return p.artUrl;
        // capa guardada pelo aplicativo Música (vinda da internet)
        if (!artista && !album) return "";
        if (!casa) return "";
        return "file://" + casa + "/.cache/carinaeos/capas/"
            + Qt.md5((artista + "\u0000" + album).toLowerCase()) + ".jpg";
    }

    // ---- comandos que o MPRIS não faz (volume exato, aleatório, repetir): mpc -----------------------
    P5Support.DataSource { id: sh; engine: "executable"; connectedSources: []; onNewData: (f) => disconnectSource(f) }
    property string casa: ""
    P5Support.DataSource {
        engine: "executable"
        connectedSources: ["echo $HOME"]
        onNewData: (f, d) => { raiz.casa = (d["stdout"] || "").trim(); disconnectSource(f); }
    }
    function correr(c: string): void { sh.connectSource(c + " #" + Date.now()); }

    // ---- na barra: capa pequena, barras a mexer e o nome da música ---------------------------------
    visible: ativo
    Layout.fillHeight: true
    Layout.minimumWidth: ativo ? pilula.width + 6 : 0
    Layout.preferredWidth: Layout.minimumWidth
    Layout.maximumWidth: Layout.minimumWidth

    Rectangle {
        id: pilula
        anchors.centerIn: parent
        height: Math.max(16, parent.height - 6)
        width: linha.implicitWidth + 16
        radius: height / 2
        color: rato.containsMouse || janela.visible ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.07)
        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            id: linha
            anchors.centerIn: parent
            spacing: 7
            Rectangle {
                width: pilula.height - 6; height: width; radius: 4; clip: true
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(1, 1, 1, 0.12)
                Kirigami.Icon { anchors.fill: parent; anchors.margins: 2; source: "carinaeos-musica"; visible: capaMini.status !== Image.Ready }
                Image { id: capaMini; anchors.fill: parent; source: raiz.capa; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(64, 64) }
            }
            Row {      // equalizador: mexe enquanto toca
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: 2.5; radius: 1; color: raiz.ambar
                        anchors.bottom: parent.bottom
                        height: raiz.tocando ? altura : 4
                        property real altura: 6
                        SequentialAnimation on altura {
                            running: raiz.tocando; loops: Animation.Infinite
                            NumberAnimation { to: 11 - index * 2; duration: 260 + index * 90; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 4 + index; duration: 300 + index * 70; easing.type: Easing.InOutSine }
                        }
                    }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 260)
                elide: Text.ElideRight
                text: raiz.titulo + (raiz.artista ? "  ·  " + raiz.artista : "")
                color: "white"
                font.pixelSize: Math.round(pilula.height * 0.55)
                font.weight: Font.Medium
            }
        }
        MouseArea {
            id: rato
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: (m) => { if (raiz.p) raiz.p.PlayPause(); }
            onWheel: (w) => raiz.correr("mpc -q volume " + (w.angleDelta.y > 0 ? "+5" : "-5"))
        }
    }

    // ---- abrir/fechar ao passar o rato --------------------------------------------------------------
    Timer { id: abrir; interval: 250; onTriggered: if (rato.containsMouse) { janela.visible = true; raiz.p && raiz.p.updatePosition(); } }
    Timer { id: fechar; interval: 350; onTriggered: if (!rato.containsMouse && !sobreJanela.hovered) janela.visible = false }
    Connections {
        target: rato
        function onContainsMouseChanged(): void {
            if (rato.containsMouse) { fechar.stop(); abrir.restart(); } else { abrir.stop(); fechar.restart(); }
        }
    }
    onAtivoChanged: if (!ativo) janela.visible = false

    // tempo: o MPRIS só avisa quando se salta; enquanto a janela está aberta pede-se a posição
    Timer { interval: 1000; repeat: true; running: janela.visible && raiz.tocando; onTriggered: raiz.p && raiz.p.updatePosition() }
    function hms(us: real): string {
        const s = Math.max(0, Math.floor(us / 1000000)), m = Math.floor(s / 60), r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }

    component Botao: Rectangle {
        id: b
        property string icone
        property bool ligado: false
        property int lado: 34
        property bool grande: false
        signal clicado()
        width: lado; height: lado; radius: lado / 2
        color: grande ? (mb.containsMouse ? Qt.lighter(raiz.ambar, 1.1) : raiz.ambar)
                      : (mb.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent")
        Kirigami.Icon {
            anchors.centerIn: parent
            width: b.lado * (b.grande ? 0.46 : 0.52); height: width
            source: b.icone; isMask: true
            color: b.grande ? "#1a1208" : (b.ligado ? raiz.ambar : "white")
        }
        MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: b.clicado() }
    }

    PlasmaCore.Dialog {
        id: janela
        visualParent: pilula
        location: PlasmaCore.Types.TopEdge
        type: PlasmaCore.Dialog.Tooltip
        flags: Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint
        backgroundHints: PlasmaCore.Dialog.NoBackground
        hideOnWindowDeactivate: false
        visible: false

        mainItem: Rectangle {
            width: 320
            height: coluna.height + 32
            radius: 18
            color: Qt.rgba(0.09, 0.08, 0.13, 0.96)
            border.color: Qt.rgba(1, 1, 1, 0.14)
            opacity: janela.visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 140 } }
            HoverHandler { id: sobreJanela; onHoveredChanged: if (!hovered) fechar.restart(); else fechar.stop() }

            Column {
                id: coluna
                x: 16; y: 16; width: parent.width - 32; spacing: 12

                Rectangle {      // capa grande
                    width: parent.width; height: width; radius: 12; clip: true
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#3b2a55" }
                        GradientStop { position: 1; color: "#7a3550" }
                    }
                    Kirigami.Icon { anchors.centerIn: parent; width: parent.width * 0.35; height: width; source: "carinaeos-musica"; visible: capaGrande.status !== Image.Ready }
                    Image { id: capaGrande; anchors.fill: parent; source: raiz.capa; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize: Qt.size(600, 600) }
                }
                Column {
                    width: parent.width; spacing: 2
                    Text { width: parent.width; text: raiz.titulo || "—"; color: "white"; font.pixelSize: 17; font.weight: Font.Bold; elide: Text.ElideRight }
                    Text { width: parent.width; text: [raiz.artista, raiz.album].filter(x => x).join(" · "); color: "#b9b0cc"; font.pixelSize: 13; elide: Text.ElideRight }
                }
                // tempo
                Column {
                    width: parent.width; spacing: 4
                    Rectangle {
                        id: barraTempo
                        width: parent.width; height: 5; radius: 2.5; color: Qt.rgba(1, 1, 1, 0.15)
                        readonly property real fr: raiz.p && raiz.p.length > 0 ? Math.min(1, raiz.p.position / raiz.p.length) : 0
                        Rectangle { width: parent.width * barraTempo.fr; height: parent.height; radius: 2.5; color: raiz.ambar }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                            onClicked: (m) => {
                                if (!raiz.p || raiz.p.length <= 0) return;
                                const alvo = Math.max(0, Math.min(1, (m.x - 6) / barraTempo.width)) * raiz.p.length;
                                raiz.p.Seek(alvo - raiz.p.position);
                                raiz.p.updatePosition();
                            }
                        }
                    }
                    RowLayout {
                        width: parent.width
                        Text { text: raiz.p ? raiz.hms(raiz.p.position) : "0:00"; color: "#b9b0cc"; font.pixelSize: 11 }
                        Item { Layout.fillWidth: true }
                        Text { text: raiz.p ? raiz.hms(raiz.p.length) : "0:00"; color: "#b9b0cc"; font.pixelSize: 11 }
                    }
                }
                // controlos
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 10
                    Botao { icone: "media-playlist-shuffle"; ligado: raiz.p && raiz.p.shuffle === Mpris.ShuffleStatus.On; anchors.verticalCenter: parent.verticalCenter
                            onClicado: raiz.correr("mpc -q random") }
                    Botao { icone: "media-skip-backward"; anchors.verticalCenter: parent.verticalCenter; onClicado: raiz.p && raiz.p.Previous() }
                    Botao { grande: true; lado: 50; icone: raiz.tocando ? "media-playback-pause" : "media-playback-start"
                            onClicado: raiz.p && raiz.p.PlayPause() }
                    Botao { icone: "media-skip-forward"; anchors.verticalCenter: parent.verticalCenter; onClicado: raiz.p && raiz.p.Next() }
                    Botao { icone: "media-playlist-repeat"; ligado: raiz.p && raiz.p.loopStatus > Mpris.LoopStatus.None; anchors.verticalCenter: parent.verticalCenter
                            onClicado: raiz.correr("mpc -q repeat") }
                }
                // volume (do MPD)
                RowLayout {
                    width: parent.width; spacing: 10
                    Kirigami.Icon { source: "audio-volume-medium"; isMask: true; color: "white"; Layout.preferredWidth: 16; Layout.preferredHeight: 16 }
                    Rectangle {
                        id: barraVol
                        Layout.fillWidth: true; height: 5; radius: 2.5; color: Qt.rgba(1, 1, 1, 0.15)
                        property real v: raiz.p ? raiz.p.volume : 0
                        Rectangle { width: parent.width * Math.max(0, Math.min(1, barraVol.v)); height: parent.height; radius: 2.5; color: "white" }
                        MouseArea {
                            anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor
                            function por(x) {
                                const v = Math.round(Math.max(0, Math.min(1, (x - 8) / barraVol.width)) * 100);
                                barraVol.v = v / 100;
                                raiz.correr("mpc -q volume " + v);
                            }
                            onPressed: (m) => por(m.x)
                            onPositionChanged: (m) => { if (pressed) por(m.x); }
                        }
                    }
                }
                // abrir / parar
                RowLayout {
                    width: parent.width; spacing: 8
                    Rectangle {
                        Layout.fillWidth: true; height: 34; radius: 17
                        color: ma.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                        Text { anchors.centerIn: parent; text: "Abrir o Música"; color: "white"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { janela.visible = false; raiz.correr("carinaeos-musica"); } }
                    }
                    Rectangle {
                        Layout.fillWidth: true; height: 34; radius: 17
                        color: mp.containsMouse ? "#ff5f57" : Qt.rgba(1, 0.37, 0.34, 0.25)
                        Text { anchors.centerIn: parent; text: "Parar a música"; color: "white"; font.pixelSize: 13; font.weight: Font.DemiBold }
                        MouseArea { id: mp; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { janela.visible = false; raiz.correr("mpc -q stop"); } }
                    }
                }
            }
        }
    }
}
