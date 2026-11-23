/*
    CarinaeOS — DashboardWindow: janela de ecrã inteiro do Launchpad (substitui Kicker.DashboardWindow)
    toggle() abre/fecha no ecrã do visualParent; Esc emite keyEscapePressed.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Window
import CarinaeOS.Base

Window {
    id: dw

    property Item mainItem: null
    property Item visualParent: null
    property color backgroundColor: "black"
    property Item keyEventProxy: null
    signal keyEscapePressed()

    visible: false
    color: backgroundColor
    title: "CarinaeOS Launchpad"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

    onMainItemChanged: if (mainItem) mainItem.parent = dw.contentItem

    function toggle(): void {
        if (visible) {
            close();
            return;
        }
        const w = visualParent && visualParent.Window.window ? visualParent.Window.window : null;
        const s = w && w.screen ? w.screen : Qt.application.screens[0];
        dw.screen = s;
        dw.x = s.virtualX;
        dw.y = s.virtualY;
        dw.width = s.width;
        dw.height = s.height;
        dw.showFullScreen();
        dw.raise();
        dw.requestActivate();
        focar.restart();
    }
    // o teclado: pede-se ao gestor de janelas e, se ao fim de pouco a janela ainda não estiver ativa,
    // a Aurora dá-o ela própria (houve casos em que o Launchpad abria sem receber as teclas)
    property int tentativas: 0
    Timer {
        id: focar; interval: 60
        onTriggered: {
            if (!dw.active && dw.visible) Sistema.focarTeclado(dw);
            if (dw.keyEventProxy) dw.keyEventProxy.forceActiveFocus();
            if (!dw.active && dw.visible && ++dw.tentativas < 6) { interval = 120; restart(); }
            else { dw.tentativas = 0; interval = 60; }
        }
    }
    // clicar em qualquer sítio do Launchpad também lhe dá o teclado
    TapHandler { onTapped: if (!dw.active) { Sistema.focarTeclado(dw); focar.restart(); } }

    Shortcut {
        sequences: [StandardKey.Cancel]
        context: Qt.WindowShortcut
        onActivated: dw.keyEscapePressed()
    }
    onActiveChanged: if (active && keyEventProxy && !activeFocusItem) keyEventProxy.forceActiveFocus()
}
