// Portado do Plasma pelo portar-do-plasma.py (CarinaeOS). Original: /home/claude/orig/plasmoids/org.carinaeos.menuestrela/contents/ui/main.qml
/*
    CarinaeOS — Menu estrela (canto superior esquerdo), como o menu da maçã
    do macOS.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window

import CarinaeOS.Base
import CarinaeOS.Compat as PlasmaCore
import CarinaeOS.Compat as PlasmaExtras
import CarinaeOS.Compat as P5Support
import CarinaeOS.Compat as Kirigami

PlasmoidItem {
    id: raiz

    preferredRepresentation: fullRepresentation

    Layout.minimumWidth: Kirigami.Units.iconSizes.medium + Kirigami.Units.smallSpacing * 2
    Layout.preferredWidth: Layout.minimumWidth
    Layout.fillHeight: true

    P5Support.DataSource {
        id: executar
        engine: "executable"
        connectedSources: []
        onNewData: (fonte, dados) => disconnectSource(fonte)
    }
    function correr(cmd: string): void {
        executar.connectSource(cmd);
    }

    // fundo escuro da barra de cima inteira (o tema deixa o painel transparente por causa da Dock):
    // este applet é o primeiro da barra, por isso desenha-se por trás de todos os outros
    Rectangle {
        id: fundoBarra
        z: -100
        color: Qt.rgba(0.07, 0.055, 0.11, 0.84)
        property point origem: Qt.point(0, 0)
        x: -origem.x
        y: -origem.y
        width: raiz.Window.window ? raiz.Window.window.width : 4000
        height: raiz.Window.window ? raiz.Window.window.height : raiz.height
        function medir(): void {
            const p = raiz.mapToItem(null, 0, 0);
            origem = Qt.point(p.x, p.y);
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1, 1, 1, 0.07) }
        Timer { interval: 2000; running: true; repeat: true; onTriggered: fundoBarra.medir() }
        Component.onCompleted: medir()
    }

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: Math.min(parent.height - 4, width)
        radius: height * 0.3
        color: Qt.rgba(1, 1, 1, rato.containsMouse || menu.status === PlasmaExtras.Menu.Open ? 0.16 : 0)
        Behavior on color { ColorAnimation { duration: 120 } }
    }

    Kirigami.Icon {
        anchors.centerIn: parent
        source: "carinaeos-estrela"
        width: Math.min(parent.width, parent.height) - Kirigami.Units.smallSpacing
        height: width
    }

    MouseArea {
        id: rato
        anchors.fill: parent
        hoverEnabled: true
        onClicked: menu.openRelative()
    }

    PlasmaExtras.Menu {
        id: menu
        visualParent: raiz
        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup

        PlasmaExtras.MenuItem { text: "Sobre este computador"; icon: "carinaeos"; onClicked: raiz.correr("carinaeos-configuracoes sistema") }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem { text: "Comando…  (Ctrl+Espaço)"; icon: "search"; onClicked: raiz.correr("carinaeos-comando") }
        PlasmaExtras.MenuItem { text: "Configurações…"; icon: "preferences-system"; onClicked: raiz.correr("carinaeos-configuracoes") }
        PlasmaExtras.MenuItem { text: "Supernova — personalizar…"; icon: "carinaeos-supernova"; onClicked: raiz.correr("command -v carinaeos-supernova >/dev/null && exec carinaeos-supernova || exec carinaeos-configuracoes aparencia") }
        PlasmaExtras.MenuItem { text: "Órbita — loja de aplicativos…"; icon: "carinaeos-orbita"; onClicked: raiz.correr("command -v carinaeos-orbita >/dev/null && exec carinaeos-orbita || command -v gnome-software >/dev/null && exec gnome-software || exec plasma-discover") }
        PlasmaExtras.MenuItem { text: "Recarregar o ambiente"; icon: "document-edit"; onClicked: raiz.correr("carinae-shell --enviar recarregar") }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem { text: "Forçar encerramento…"; icon: "process-stop"; onClicked: raiz.correr("xkill") }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem { text: "Suspender"; icon: "system-suspend"; onClicked: raiz.correr("systemctl suspend") }
        PlasmaExtras.MenuItem { text: "Reiniciar…"; icon: "system-reboot"; onClicked: raiz.correr("carinae-sessao reiniciar") }
        PlasmaExtras.MenuItem { text: "Desligar…"; icon: "system-shutdown"; onClicked: raiz.correr("carinae-sessao desligar") }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem { text: "Bloquear tela"; icon: "system-lock-screen"; onClicked: raiz.correr("loginctl lock-session") }
        PlasmaExtras.MenuItem { text: "Encerrar sessão…"; icon: "system-log-out"; onClicked: raiz.correr("carinae-sessao sair") }
    }
}
