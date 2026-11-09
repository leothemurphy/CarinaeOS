/*
    CarinaeOS — Dock: pilha de Downloads (ao lado da lixeira, como no macOS)
    Clicar abre um painel com os últimos arquivos baixados.
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtCore
import Qt.labs.folderlistmodel

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

Item {
    id: pilha

    required property var dock
    required property int slot
    readonly property real s: dock.escala(slot)
    readonly property url pasta: StandardPaths.writableLocation(StandardPaths.DownloadLocation)

    width: dock.base * s
    height: parent ? parent.height : 0

    FolderListModel {
        id: arquivos
        folder: pilha.pasta
        showDirs: true
        showDirsFirst: false
        showHidden: false
        sortField: FolderListModel.Time
        sortReversed: false
        // arquivos de download ainda a meio ficam de fora
        nameFilters: ["*"]
    }

    function iconePara(nome: string, pastaQ: bool): string {
        if (pastaQ) return "folder";
        const e = nome.toLowerCase().split(".").pop();
        const mapa = {
            pdf: "application-pdf", jpg: "image-jpeg", jpeg: "image-jpeg", png: "image-png",
            gif: "image-gif", webp: "image-x-generic", svg: "image-svg+xml",
            mp3: "audio-x-generic", ogg: "audio-x-generic", flac: "audio-x-generic", wav: "audio-x-generic",
            mp4: "video-x-generic", mkv: "video-x-generic", webm: "video-x-generic", avi: "video-x-generic",
            zip: "application-zip", gz: "application-x-compressed-tar", xz: "application-x-compressed-tar",
            "7z": "application-x-7z-compressed", rar: "application-x-rar", deb: "application-x-deb",
            iso: "application-x-cd-image", txt: "text-plain", odt: "x-office-document",
            doc: "x-office-document", docx: "x-office-document", ods: "x-office-spreadsheet",
            xls: "x-office-spreadsheet", xlsx: "x-office-spreadsheet", odp: "x-office-presentation",
            ppt: "x-office-presentation", pptx: "x-office-presentation", html: "text-html",
            exe: "application-x-ms-dos-executable", appimage: "application-x-executable",
            flatpakref: "application-vnd.flatpak.ref"
        };
        return mapa[e] || "text-x-generic";
    }

    Kirigami.Icon {
        id: icone
        source: "folder-downloads"
        width: dock.base * pilha.s
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - dock.baixo - dock.margem - height
        active: rato.containsMouse
    }
    Rotulo {
        alvo: icone
        texto: "Downloads"
        mostrar: rato.containsMouse && !janela.visible
        dock: pilha.dock
    }
    MouseArea {
        id: rato
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: dock.baixo + dock.margem * 2 + icone.height
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                Qt.openUrlExternally(pilha.pasta);
                return;
            }
            janela.visible = !janela.visible;
        }
    }

    PlasmaCore.Dialog {
        id: janela
        visualParent: icone
        location: PlasmaCore.Types.BottomEdge
        type: PlasmaCore.Dialog.PopupMenu
        flags: Qt.WindowStaysOnTopHint
        hideOnWindowDeactivate: true

        mainItem: ColumnLayout {
            width: Kirigami.Units.gridUnit * 21
            height: Kirigami.Units.gridUnit * 19
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                Kirigami.Icon { source: "folder-downloads"; implicitWidth: Kirigami.Units.iconSizes.smallMedium; implicitHeight: implicitWidth }
                PlasmaComponents.Label {
                    text: "Downloads"
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: arquivos.count === 1 ? "1 item" : arquivos.count + " itens"
                    opacity: 0.6
                }
            }

            GridView {
                id: grade
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: arquivos
                cellWidth: Math.floor(width / 4)
                cellHeight: Kirigami.Units.gridUnit * 5.4
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                    id: item
                    required property string fileName
                    required property url fileUrl
                    required property bool fileIsDir
                    width: grade.cellWidth
                    height: grade.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 2
                        radius: Kirigami.Units.cornerRadius
                        color: Kirigami.Theme.highlightColor
                        opacity: itemRato.containsMouse ? 0.25 : 0
                    }
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Kirigami.Units.smallSpacing
                        spacing: 2
                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: Kirigami.Units.iconSizes.large
                            implicitHeight: implicitWidth
                            source: pilha.iconePara(item.fileName, item.fileIsDir)
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: item.fileName
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            elide: Text.ElideMiddle
                            maximumLineCount: 2
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }
                    MouseArea {
                        id: itemRato
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            Qt.openUrlExternally(item.fileUrl);
                            janela.visible = false;
                        }
                    }
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    visible: arquivos.count === 0
                    text: "Nenhum arquivo baixado ainda"
                    opacity: 0.6
                }
            }

            PlasmaComponents.Button {
                Layout.fillWidth: true
                Layout.margins: Kirigami.Units.smallSpacing
                icon.name: "system-file-manager"
                text: "Abrir no Arquivos"
                onClicked: {
                    Qt.openUrlExternally(pilha.pasta);
                    janela.visible = false;
                }
            }
        }
    }
}
