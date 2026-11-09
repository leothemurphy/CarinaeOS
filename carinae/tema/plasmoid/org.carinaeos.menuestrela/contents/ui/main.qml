/*
    CarinaeOS — Menu estrela (canto superior esquerdo), como o menu da maçã
    do macOS.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: raiz

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

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

        PlasmaExtras.MenuItem { text: "Sobre este computador"; icon: "carinaeos"; onClicked: raiz.correr("kinfocenter") }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem { text: "Configurações do Sistema…"; icon: "preferences-system"; onClicked: raiz.correr("systemsettings") }
        PlasmaExtras.MenuItem { text: "Supernova — personalizar…"; icon: "carinaeos-supernova"; onClicked: raiz.correr("carinaeos-supernova") }
        PlasmaExtras.MenuItem { text: "Órbita — loja de aplicativos…"; icon: "carinaeos-orbita"; onClicked: raiz.correr("carinaeos-orbita") }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem { text: "Forçar encerramento…"; icon: "process-stop"; onClicked: raiz.correr("qdbus6 org.kde.KWin /KWin killWindow") }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem { text: "Suspender"; icon: "system-suspend"; onClicked: raiz.correr("systemctl suspend") }
        PlasmaExtras.MenuItem { text: "Reiniciar…"; icon: "system-reboot"; onClicked: raiz.correr("qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptReboot") }
        PlasmaExtras.MenuItem { text: "Desligar…"; icon: "system-shutdown"; onClicked: raiz.correr("qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptShutDown") }
        PlasmaExtras.MenuItem { separator: true }
        PlasmaExtras.MenuItem { text: "Bloquear tela"; icon: "system-lock-screen"; onClicked: raiz.correr("loginctl lock-session") }
        PlasmaExtras.MenuItem { text: "Terminar sessão…"; icon: "system-log-out"; onClicked: raiz.correr("qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptLogout") }
    }
}
