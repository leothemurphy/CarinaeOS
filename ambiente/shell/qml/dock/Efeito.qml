/*
    CarinaeOS — Dock: a animação de cada ícone ao passar o mouse (uma por modelo, nenhuma é a lupa do Mac)
      luz      — Holofote: o ícone sobe com um pequeno ressalto (a luz que desliza é da Dock)
      orbita   — Órbita: um anel inclinado (como no logo) aparece e um ponto gira à volta do ícone
      onda     — Ondas: dois anéis saem do ícone como um sonar e o ícone dá um pulinho elástico
      inclinar — Inclinação 3D: o ícone inclina-se para o lado onde está o mouse
      windows  — como no Windows 11: o ícone encolhe ao carregar e volta com mola
      nenhuma  — nada (só o quadrado por trás, se o modelo o tiver)
    O ícone usa `transform: efeito.transformacoes`; este Item desenha por cima dele (anéis, ponto).
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick

Item {
    id: ef
    required property var dock
    required property Item alvo
    property bool ativo: false          // o mouse está em cima
    property bool pressionado: false
    readonly property string tipo: dock.animacao

    z: 3
    width: alvo.width; height: alvo.height
    x: alvo.x; y: alvo.y

    // ---- o que se aplica ao ícone -----------------------------------------------------------------
    property real subir: 0
    property real escala: 1
    property real girarY: 0
    property real girarX: 0
    property real deslocX: 0            // paralaxe: o ícone vai um pouco atrás do mouse
    property real deslocY: 0
    Behavior on deslocX { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
    Behavior on deslocY { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
    readonly property var transformacoes: [tEscala, tGirarY, tGirarX, tSubir]
    Scale {
        id: tEscala
        origin.x: ef.width / 2; origin.y: ef.height / 2
        xScale: ef.escala; yScale: ef.escala
    }
    Rotation {
        id: tGirarY
        origin.x: ef.width / 2; origin.y: ef.height / 2
        axis { x: 0; y: 1; z: 0 }
        angle: ef.girarY
    }
    Rotation {
        id: tGirarX
        origin.x: ef.width / 2; origin.y: ef.height / 2
        axis { x: 1; y: 0; z: 0 }
        angle: ef.girarX
    }
    Translate { id: tSubir; x: ef.deslocX; y: -ef.subir + ef.deslocY }

    Behavior on escala { NumberAnimation { duration: ef.pressionado ? 70 : 260; easing.type: ef.pressionado ? Easing.OutQuad : Easing.OutBack; easing.overshoot: 2.2 } }
    Behavior on girarY { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
    Behavior on girarX { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }

    function atualizar() {
        switch (tipo) {
        case "luz":
            subirAnim.para(ativo ? dock.base * 0.13 : 0);
            escala = 1;
            break;
        case "orbita":
            subirAnim.para(ativo ? dock.base * 0.05 : 0);
            escala = ativo ? 1.06 : 1;
            break;
        case "onda":
            escala = ativo ? 1.05 : 1;
            if (ativo) { pulinho.restart(); disparar(); }
            break;
        case "inclinar":
            escala = ativo ? 1.08 : 1;
            if (!ativo) { girarY = 0; girarX = 0; deslocX = 0; deslocY = 0; }
            break;
        case "windows":
            escala = pressionado ? 0.82 : 1;
            break;
        default:
            escala = 1;
            subirAnim.para(0);
        }
    }
    onAtivoChanged: atualizar()
    onPressionadoChanged: atualizar()
    onTipoChanged: { girarX = 0; girarY = 0; deslocX = 0; deslocY = 0; subir = 0; atualizar(); }

    NumberAnimation {
        id: subirAnim
        target: ef; property: "subir"
        duration: 300; easing.type: Easing.OutBack; easing.overshoot: 2.4
        function para(v) { if (Math.abs(ef.subir - v) < 0.1) return; stop(); to = v; easing.type = v > 0 ? Easing.OutBack : Easing.OutCubic; start(); }
    }

    // ---- Ondas: pulinho elástico + sonar ---------------------------------------------------------
    SequentialAnimation {
        id: pulinho
        NumberAnimation { target: ef; property: "subir"; to: ef.dock.base * 0.20; duration: 130; easing.type: Easing.OutQuad }
        NumberAnimation { target: ef; property: "subir"; to: 0; duration: 650; easing.type: Easing.OutElastic; easing.amplitude: 1.1; easing.period: 0.35 }
    }
    Repeater {
        model: 2
        Rectangle {
            id: anel
            required property int index
            anchors.centerIn: parent
            width: ef.width; height: width; radius: width / 2
            color: "transparent"
            border.width: Math.max(1.5, ef.dock.base * 0.04)
            border.color: index === 0 ? "#ffb46e" : "#ff6f91"
            opacity: 0; scale: 0.6
            visible: ef.tipo === "onda"
            Connections {
                target: ef
                function onDisparar() { ondaAnim.restart() }
            }
            SequentialAnimation {
                id: ondaAnim
                PauseAnimation { duration: anel.index * 170 }
                ParallelAnimation {
                    NumberAnimation { target: anel; property: "scale"; from: 0.6; to: 1.55; duration: 720; easing.type: Easing.OutCubic }
                    NumberAnimation { target: anel; property: "opacity"; from: 0.75; to: 0; duration: 720; easing.type: Easing.InQuad }
                }
            }
        }
    }
    signal disparar()

    // ---- Órbita: anel inclinado e um ponto a girar -------------------------------------------------
    Item {
        id: orbita
        visible: ef.tipo === "orbita" && opacity > 0.01
        opacity: ef.ativo ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 220 } }
        anchors.centerIn: parent
        width: ef.width * 1.55; height: ef.width * 0.46
        rotation: -24
        property real angulo: 0
        NumberAnimation on angulo {
            running: orbita.visible
            from: 0; to: 360; duration: 1700; loops: Animation.Infinite
        }
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: "transparent"
            border.width: Math.max(1.5, ef.dock.base * 0.035)
            border.color: Qt.rgba(0.31, 0.78, 0.86, 0.75)
        }
        Rectangle {    // o ponto: maior e mais vivo quando passa à frente do ícone
            readonly property real a: orbita.angulo * Math.PI / 180
            readonly property real frente: Math.sin(a)     // > 0: à frente
            width: ef.dock.base * (0.11 + 0.04 * frente); height: width; radius: width / 2
            x: orbita.width / 2 + Math.cos(a) * orbita.width / 2 - width / 2
            y: orbita.height / 2 + Math.sin(a) * orbita.height / 2 - height / 2
            color: "#bff4ee"
            opacity: 0.45 + 0.55 * (frente + 1) / 2
        }
    }

    // ---- Inclinação 3D: segue o mouse dentro do ícone ----------------------------------------------
    // a posição do mouse dentro do ícone (vem da MouseArea do ícone; um HoverHandler aqui roubava o hover)
    property point ponto: Qt.point(-1, -1)
    onPontoChanged: {
        if (tipo !== "inclinar") return;
        if (!ativo || ponto.x < -0.5) { girarY = 0; girarX = 0; deslocX = 0; deslocY = 0; return; }
        const px = ponto.x / Math.max(1, width) - 0.5;
        const py = ponto.y / Math.max(1, height) - 0.5;
        girarY = Math.max(-1, Math.min(1, px * 2)) * 32;
        girarX = -Math.max(-1, Math.min(1, py * 2)) * 24;
        deslocX = Math.max(-1, Math.min(1, px * 2)) * dock.base * 0.10;
        deslocY = Math.max(-1, Math.min(1, py * 2)) * dock.base * 0.07;
    }
    Rectangle {     // reflexo que acompanha a inclinação
        visible: ef.tipo === "inclinar"
        anchors.fill: parent
        radius: width * 0.22
        opacity: ef.ativo ? 0.9 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: Math.max(0, Math.min(1, 0.5 + ef.girarY / 64 - 0.25)); color: "transparent" }
            GradientStop { position: Math.max(0, Math.min(1, 0.5 + ef.girarY / 64)); color: Qt.rgba(1, 1, 1, 0.16) }
            GradientStop { position: Math.max(0, Math.min(1, 0.5 + ef.girarY / 64 + 0.25)); color: "transparent" }
        }
    }
}
