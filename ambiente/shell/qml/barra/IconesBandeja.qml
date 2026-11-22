// CarinaeOS — bandeja da barra de cima: primeiro os apps abertos (com janela), depois o ícone real
// de cada app em segundo plano (Claude, Discord, Steam, KDE Connect…).
// Apps abertos: clique = trazer para a frente (ou minimizar, se já está à frente), meio = fechar.
// Segundo plano: Clique = abrir o app, botão direito = o menu dele, meio = ação secundária,
// roda = o que o app quiser (volume, por exemplo). Os "passivos" ficam atrás da setinha.
import QtQuick
import CarinaeOS.Base
import CarinaeOS.Compat as C

Row {
    id: bandeja
    spacing: 2
    readonly property var ativos: Bandeja.itens.filter(function (i) { return i.estado !== "Passive" })
    readonly property var passivos: Bandeja.itens.filter(function (i) { return i.estado === "Passive" })

    // ---- apps abertos ----
    C.TasksModel {
        id: tarefas
        groupMode: C.TasksModel.GroupApplications
        sortMode: C.TasksModel.SortManual
        separateLaunchers: true
        hideActivatedLaunchers: true
    }
    Repeater {
        model: tarefas
        delegate: Item {
            id: aberto
            required property var model
            required property int index
            readonly property bool mostrar: !model.IsLauncher && !model.IsStartup
            visible: mostrar
            width: mostrar ? 26 : 0
            height: bandeja.height
            Rectangle {
                anchors.centerIn: parent
                width: 24; height: 24; radius: 6
                color: Qt.rgba(1, 1, 1, abertoRato.pressed ? 0.18 : abertoRato.containsMouse ? 0.12 : aberto.model.IsActive ? 0.08 : 0)
            }
            C.Icon {
                anchors.centerIn: parent
                source: aberto.model.decoration
                width: 18; height: 18
                opacity: aberto.model.IsMinimized ? 0.55 : 1
            }
            Rectangle {     // a app à frente: um tracinho âmbar por baixo
                visible: aberto.model.IsActive === true
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom; anchors.bottomMargin: 2
                width: 10; height: 2; radius: 1
                color: "#ffb46e"
            }
            MouseArea {
                id: abertoRato
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                onClicked: (ev) => {
                    const i = tarefas.makeModelIndex(aberto.index);
                    if (ev.button === Qt.MiddleButton) { tarefas.requestClose(i); return; }
                    if (aberto.model.IsActive && !aberto.model.IsMinimized) { tarefas.requestToggleMinimized(i); return; }
                    if (aberto.model.IsMinimized) tarefas.requestToggleMinimized(i);
                    tarefas.requestActivate(i);
                }
            }
            C.Dialog {
                visualParent: aberto
                location: 3
                type: 4
                outputOnly: true
                backgroundHints: 0
                visible: abertoRato.containsMouse
                mainItem: Rectangle {
                    width: nomeAberto.implicitWidth + 18; height: nomeAberto.implicitHeight + 10
                    radius: height / 2
                    color: Qt.rgba(0.10, 0.09, 0.14, 0.94)
                    border.color: Qt.rgba(1, 1, 1, 0.14)
                    Text { id: nomeAberto; anchors.centerIn: parent; text: aberto.model.AppName || aberto.model.display || ""; color: "white"; font.pixelSize: 12 }
                }
            }
        }
    }
    // separador entre os abertos e os de segundo plano
    Item {
        visible: bandeja.ativos.length > 0 && tarefas.count > 0
        width: visible ? 9 : 0
        height: parent.height
        Rectangle { anchors.centerIn: parent; width: 1; height: 14; color: Qt.rgba(1, 1, 1, 0.22) }
    }

    Repeater {
        model: bandeja.ativos
        delegate: Icone { required property var modelData; item: modelData }
    }

    // a setinha com os que estão quietos
    Item {
        id: seta
        visible: bandeja.passivos.length > 0
        width: visible ? 22 : 0
        height: parent.height
        Rectangle {
            anchors.centerIn: parent
            width: 22; height: 22; radius: 6
            color: Qt.rgba(1, 1, 1, setaRato.containsMouse || mais.visible ? 0.12 : 0)
        }
        Text { anchors.centerIn: parent; text: mais.visible ? "⌃" : "⌄"; color: "#f6f2ff"; font.pixelSize: 14 }
        MouseArea { id: setaRato; anchors.fill: parent; hoverEnabled: true; onClicked: mais.visible = !mais.visible }
        C.Dialog {
            id: mais
            visualParent: seta
            location: 3
            hideOnWindowDeactivate: true
            backgroundHints: 0
            mainItem: Rectangle {
                width: grade.width + 16; height: grade.height + 16
                radius: 12
                color: Qt.rgba(0.11, 0.10, 0.14, 0.97)
                border.color: Qt.rgba(1, 1, 1, 0.12)
                Grid {
                    id: grade
                    x: 8; y: 8
                    columns: 5; spacing: 4
                    Repeater {
                        model: bandeja.passivos
                        delegate: Icone { required property var modelData; item: modelData; height: 30 }
                    }
                }
            }
        }
    }

    component Icone: Item {
        id: ic
        property var item
        width: 26
        height: bandeja.height
        Rectangle {
            anchors.centerIn: parent
            width: 24; height: 24; radius: 6
            color: Qt.rgba(1, 1, 1, rato.pressed ? 0.18 : rato.containsMouse ? 0.12 : 0)
        }
        Image {
            anchors.centerIn: parent
            visible: ic.item.iconeUrl !== ""
            source: ic.item.iconeUrl
            sourceSize: Qt.size(36, 36)
            width: 18; height: 18
            smooth: true
            fillMode: Image.PreserveAspectFit
        }
        C.Icon {
            anchors.centerIn: parent
            visible: ic.item.iconeUrl === ""
            source: ic.item.iconeNome || "application-x-executable"
            width: 18; height: 18
        }
        Rectangle {     // a pedir atenção: um pontinho âmbar
            visible: ic.item.estado === "NeedsAttention"
            width: 6; height: 6; radius: 3
            color: "#ffb46e"
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 3
        }
        MouseArea {
            id: rato
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: (ev) => {
                const p = ic.mapToGlobal(0, ic.height + 4);
                mais.visible = false;
                if (ev.button === Qt.RightButton) Bandeja.menu(ic.item.chave, p.x, p.y);
                else if (ev.button === Qt.MiddleButton) Bandeja.secundario(ic.item.chave, p.x, p.y);
                else Bandeja.ativar(ic.item.chave, p.x, p.y);
            }
            onWheel: (ev) => Bandeja.rodar(ic.item.chave, ev.angleDelta.y)
        }
        C.Dialog {
            visualParent: ic
            location: 3
            type: 4
            outputOnly: true
            backgroundHints: 0
            visible: rato.containsMouse && ic.item.dica !== ""
            mainItem: Rectangle {
                width: dicaTexto.implicitWidth + 18; height: dicaTexto.implicitHeight + 10
                radius: height / 2
                color: Qt.rgba(0.10, 0.09, 0.14, 0.94)
                border.color: Qt.rgba(1, 1, 1, 0.14)
                Text { id: dicaTexto; anchors.centerIn: parent; text: ic.item.dica; color: "white"; font.pixelSize: 12 }
            }
        }
    }
}
