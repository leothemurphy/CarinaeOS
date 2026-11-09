/*
    CarinaeOS — Launchpad
    Ecrã inteiro com todos os aplicativos, como no macOS: fundo desfocado,
    pesquisa no topo, grelha de ícones grandes em páginas (arrastar, roda do
    rato ou setas para mudar de página) e pontos de página em baixo.
    Abre com a estrela da Dock ou com a tecla Meta; fecha com Esc ou com um
    clique fora dos ícones.

    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker

Kicker.DashboardWindow {
    id: lp

    required property var dock

    backgroundColor: "transparent"
    keyEventProxy: busca

    // ---- todos os aplicativos (lista do menu do Plasma, por ordem alfabética)
    property var itens: []          // [{ nome, icone, linha }]
    property string filtro: ""
    readonly property var visiveis: {
        if (filtro === "") {
            return itens;
        }
        const f = semAcentos(filtro);
        return itens.filter(a => semAcentos(a.nome).indexOf(f) !== -1);
    }

    function semAcentos(t: string): string {
        return t.toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "");
    }

    readonly property Kicker.RootModel raiz: Kicker.RootModel {
        autoPopulate: false
        appletInterface: lp.dock
        flat: true
        sorted: true
        showSeparators: false
        showAllApps: true
        showAllAppsCategorized: false
        showTopLevelItems: false
        showRecentApps: false
        showRecentDocs: false
        onRefreshed: recolha.model = lp.raiz.modelForRow(0)
        Component.onCompleted: refresh()
    }

    function abrir(app: var): void {
        if (recolha.model) {
            recolha.model.trigger(app.linha, "", null);
        }
        lp.toggle();
    }

    onKeyEscapePressed: {
        if (busca.text !== "") {
            busca.text = "";
        } else {
            lp.toggle();
        }
    }

    onVisibleChanged: {
        if (visible) {
            busca.text = "";
            busca.forceActiveFocus();
            paginas.positionViewAtIndex(0, ListView.Beginning);
            paginas.currentIndex = 0;
            entrada.restart();
            lp.raiz.refresh();
        }
    }

    mainItem: Item {
        id: palco
        anchors.fill: parent

        // medidas: ícones grandes e grelha de 7 x 5 como no Mac (menos em ecrãs pequenos)
        readonly property int icone: Math.max(56, Math.min(128, Math.round(Math.min(width / 15, height / 9))))
        readonly property int celulaL: Math.round(icone * 2.05)
        readonly property int celulaA: Math.round(icone * 1.75)
        readonly property int colunas: Math.max(4, Math.min(7, Math.floor(width * 0.84 / celulaL)))
        readonly property int linhas: Math.max(3, Math.min(5, Math.floor((height - icone * 3.2) / celulaA)))
        readonly property int porPagina: colunas * linhas
        readonly property int nPaginas: Math.max(1, Math.ceil(lp.visiveis.length / porPagina))

        // lê nomes e ícones do modelo para uma lista simples
        Item {
            visible: false
            Repeater {
                id: recolha
                onCountChanged: juntar.restart()
                delegate: Item {
                    required property int index
                    required property var model
                    readonly property var dados: ({ nome: model.display, icone: model.decoration, linha: index })
                }
            }
            Timer {
                id: juntar
                interval: 50
                onTriggered: {
                    const l = [];
                    for (let i = 0; i < recolha.count; ++i) {
                        const it = recolha.itemAt(i);
                        if (it && it.dados.nome) {
                            l.push(it.dados);
                        }
                    }
                    lp.itens = l;
                }
            }
        }

        // fundo: a imagem da área de trabalho desfocada e escurecida
        Image {
            id: fundo
            anchors.fill: parent
            source: "file:///usr/share/wallpapers/CarinaeOS/contents/images/1920x1080.jpg"
            fillMode: Image.PreserveAspectCrop
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: fundo
            autoPaddingEnabled: false
            blurEnabled: true
            blurMax: 64
            blur: 1.0
            brightness: -0.18
            saturation: 0.1
            opacity: conteudo.opacity
        }

        // clique fora dos ícones fecha
        MouseArea {
            anchors.fill: parent
            onClicked: lp.toggle()
            onWheel: wheel => {
                if (wheel.angleDelta.y < 0 || wheel.angleDelta.x < 0) {
                    paginas.irPara(paginas.currentIndex + 1);
                } else {
                    paginas.irPara(paginas.currentIndex - 1);
                }
            }
        }

        Item {
            id: conteudo
            anchors.fill: parent
            opacity: 0
            scale: 1.08

            ParallelAnimation {
                id: entrada
                NumberAnimation { target: conteudo; property: "opacity"; from: 0; to: 1; duration: 260; easing.type: Easing.OutCubic }
                NumberAnimation { target: conteudo; property: "scale"; from: 1.08; to: 1; duration: 320; easing.type: Easing.OutCubic }
            }

            // ---- pesquisa ----------------------------------------------------
            Rectangle {
                id: caixaBusca
                anchors.horizontalCenter: parent.horizontalCenter
                y: palco.icone * 0.55
                width: Math.round(palco.icone * 3.4)
                height: Math.round(palco.icone * 0.42)
                radius: height / 2
                color: Qt.rgba(1, 1, 1, busca.activeFocus ? 0.20 : 0.14)
                border.color: Qt.rgba(1, 1, 1, 0.22)
                border.width: 1

                Kirigami.Icon {
                    id: lupa
                    source: "search"
                    color: "white"
                    isMask: true
                    width: parent.height * 0.5
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: parent.height * 0.35
                    opacity: 0.8
                }
                QQC2.TextField {
                    id: busca
                    anchors.left: lupa.right
                    anchors.leftMargin: parent.height * 0.2
                    anchors.right: parent.right
                    anchors.rightMargin: parent.height * 0.4
                    anchors.verticalCenter: parent.verticalCenter
                    placeholderText: "Pesquisar"
                    placeholderTextColor: Qt.rgba(1, 1, 1, 0.65)
                    color: "white"
                    font.pixelSize: Math.round(caixaBusca.height * 0.45)
                    background: Item {}
                    focus: true
                    onTextChanged: {
                        lp.filtro = text;
                        paginas.positionViewAtIndex(0, ListView.Beginning);
                        paginas.currentIndex = 0;
                    }
                    onAccepted: {
                        if (lp.visiveis.length > 0) {
                            lp.abrir(lp.visiveis[0]);
                        }
                    }
                    Keys.onRightPressed: event => { if (text === "") paginas.irPara(paginas.currentIndex + 1); else event.accepted = false; }
                    Keys.onLeftPressed: event => { if (text === "") paginas.irPara(paginas.currentIndex - 1); else event.accepted = false; }
                }
            }

            // ---- páginas de ícones -------------------------------------------
            ListView {
                id: paginas
                anchors.top: caixaBusca.bottom
                anchors.topMargin: palco.icone * 0.5
                anchors.bottom: pontos.top
                anchors.bottomMargin: palco.icone * 0.3
                anchors.left: parent.left
                anchors.right: parent.right
                orientation: ListView.Horizontal
                snapMode: ListView.SnapOneItem
                highlightRangeMode: ListView.StrictlyEnforceRange
                highlightMoveDuration: 380
                boundsBehavior: Flickable.StopAtBounds
                clip: false
                model: palco.nPaginas
                interactive: palco.nPaginas > 1

                function irPara(i: int): void {
                    currentIndex = Math.max(0, Math.min(count - 1, i));
                }

                delegate: Item {
                    id: pagina
                    required property int index
                    width: paginas.width
                    height: paginas.height

                    Grid {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        columns: palco.colunas
                        Repeater {
                            model: Math.max(0, Math.min(palco.porPagina, lp.visiveis.length - pagina.index * palco.porPagina))
                            delegate: Item {
                                id: celula
                                required property int index
                                readonly property var app: lp.visiveis[pagina.index * palco.porPagina + index]
                                width: palco.celulaL
                                height: palco.celulaA

                                Kirigami.Icon {
                                    id: icone
                                    source: celula.app ? celula.app.icone : ""
                                    width: palco.icone
                                    height: palco.icone
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    scale: rato.pressed ? 0.92 : (rato.containsMouse ? 1.07 : 1)
                                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                }
                                Text {
                                    anchors.top: icone.bottom
                                    anchors.topMargin: palco.icone * 0.1
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width - palco.icone * 0.15
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: celula.app ? celula.app.nome : ""
                                    color: "white"
                                    font.pixelSize: Math.max(11, Math.round(palco.icone * 0.17))
                                    style: Text.Raised
                                    styleColor: Qt.rgba(0, 0, 0, 0.45)
                                }
                                MouseArea {
                                    id: rato
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: if (celula.app) lp.abrir(celula.app)
                                }
                            }
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: paginas
                visible: lp.filtro !== "" && lp.visiveis.length === 0
                text: "Nenhum aplicativo encontrado"
                color: Qt.rgba(1, 1, 1, 0.75)
                font.pixelSize: Math.round(palco.icone * 0.22)
            }

            // ---- pontos das páginas ------------------------------------------
            Row {
                id: pontos
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: palco.icone * 1.9
                spacing: palco.icone * 0.16
                visible: palco.nPaginas > 1
                Repeater {
                    model: palco.nPaginas
                    delegate: Rectangle {
                        required property int index
                        width: Math.round(palco.icone * 0.11)
                        height: width
                        radius: width / 2
                        color: "white"
                        opacity: index === paginas.currentIndex ? 0.95 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            onClicked: paginas.irPara(parent.index)
                        }
                    }
                }
            }
        }
    }
}
