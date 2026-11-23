/*
    CarinaeOS — Dialog: uma janelinha flutuante junto de um item (substitui PlasmaCore.Dialog).
    Usa-se como no Plasma: visualParent, location, type, mainItem, visible.
    O próprio "Dialog" é um Item invisível sem tamanho; a janela de verdade está lá dentro.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
import QtQuick
import QtQuick.Window

Item {
    id: d

    enum WindowType { Normal = 0, Dock = 1, DialogWindow = 2, PopupMenu = 3, Tooltip = 4, Notification = 5, OnScreenDisplay = 6, CriticalNotification = 7, AppletPopup = 8 }
    enum BackgroundHints { NoBackground = 0, StandardBackground = 1, SolidBackground = 2 }

    visible: false
    width: 0
    height: 0

    property Item visualParent: null
    property int location: 4                  // Types.BottomEdge
    property int type: 0
    property int flags: 0
    property int backgroundHints: 1
    property bool hideOnWindowDeactivate: false
    property bool outputOnly: false
    property Item mainItem: null
    property int margem: 6
    readonly property int folga: backgroundHints === 0 ? 0 : 8
    readonly property alias janela: w
    readonly property bool active: w.active

    onMainItemChanged: if (mainItem) { mainItem.parent = conteudo; mainItem.x = 0; mainItem.y = 0; }

    Window {
        id: w
        visible: false
        color: "transparent"
        flags: (d.type === 4 ? Qt.ToolTip : (Qt.Tool | Qt.WindowStaysOnTopHint))
               | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
               | (d.outputOnly ? Qt.WindowTransparentForInput : 0)
               | (d.type === 4 ? Qt.WindowDoesNotAcceptFocus : 0)
               | d.flags
        width: Math.max(1, (d.mainItem ? Math.max(d.mainItem.width, d.mainItem.implicitWidth) : 1) + d.folga * 2)
        height: Math.max(1, (d.mainItem ? Math.max(d.mainItem.height, d.mainItem.implicitHeight) : 1) + d.folga * 2)
        onWidthChanged: if (visible) d.posicionar()
        onHeightChanged: if (visible) d.posicionar()
        onActiveChanged: if (!active && d.hideOnWindowDeactivate && visible) fechar.restart()

        Rectangle {
            visible: d.backgroundHints !== 0
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(0.11, 0.10, 0.14, 0.97)
            border.color: Qt.rgba(1, 1, 1, 0.12)
        }
        Item {
            id: conteudo
            x: d.folga
            y: d.folga
            width: parent.width - d.folga * 2
            height: parent.height - d.folga * 2
        }
    }
    // pequeno atraso: um clique no próprio botão que abriu o diálogo não o volta a abrir logo
    Timer { id: fechar; interval: 120; onTriggered: if (!w.active) d.visible = false }

    onVisibleChanged: atualizar()
    Component.onCompleted: atualizar()

    function atualizar(): void {
        if (d.visible && d.mainItem) {
            posicionar();
            w.visible = true;
            w.raise();
            if (d.hideOnWindowDeactivate || d.type === 3) w.requestActivate();
        } else {
            w.visible = false;
        }
    }

    function posicionar(): void {
        const vp = d.visualParent;
        if (!vp || !vp.Window.window) return;
        const p = vp.mapToGlobal(0, 0);
        const vw = vp.width, vh = vp.height;
        let x = p.x + vw / 2 - w.width / 2, y = p.y - w.height - d.margem;
        if (d.location === 3) y = p.y + vh + d.margem;                                   // em cima: abre para baixo
        else if (d.location === 5) { x = p.x + vw + d.margem; y = p.y + vh / 2 - w.height / 2; }   // à esquerda
        else if (d.location === 6) { x = p.x - w.width - d.margem; y = p.y + vh / 2 - w.height / 2; }
        const s = vp.Window.window.screen;
        if (s) {
            x = Math.max(s.virtualX + 4, Math.min(x, s.virtualX + s.width - w.width - 4));
            y = Math.max(s.virtualY + 2, Math.min(y, s.virtualY + s.height - w.height - 2));
        }
        w.x = Math.round(x);
        w.y = Math.round(y);
    }
}
