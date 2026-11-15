// CarinaeOS - Atualizações (com ponto de restauro antes, e voltar atrás)
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: janela
    width: 820; height: 760
    minimumWidth: 640; minimumHeight: 520
    visible: true
    title: "Atualizações"
    color: "#0f0c18"
    font.family: "Inter"; font.pixelSize: 14
    readonly property color texto: "#f2ecfa"
    readonly property color suave: "#b9b0cc"
    readonly property color ambar: "#ffb46e"
    readonly property color cartao: Qt.rgba(1, 1, 1, 0.05)
    readonly property color linha: Qt.rgba(1, 1, 1, 0.08)
    property bool verLista: false
    property var aRestaurar: null

    component Botao: Rectangle {
        property string texto: ""
        property bool principal: false
        property bool ativo: true
        signal carregado()
        implicitWidth: tb.implicitWidth + 30; implicitHeight: 36; radius: 18
        opacity: ativo ? 1 : 0.45
        color: principal ? (mb.containsMouse && ativo ? Qt.lighter(janela.ambar, 1.08) : janela.ambar)
                         : (mb.containsMouse && ativo ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.08))
        Text { id: tb; anchors.centerIn: parent; text: parent.texto; color: parent.principal ? "#1a1208" : janela.texto; font.pixelSize: 13; font.weight: Font.DemiBold }
        MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; enabled: parent.ativo; cursorShape: Qt.PointingHandCursor; onClicked: parent.carregado() }
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        ColumnLayout {
            width: parent.width
            spacing: 18
            Item { Layout.preferredHeight: 6 }

            // ---- cabeçalho -------------------------------------------------------------------
            RowLayout {
                Layout.leftMargin: 28; Layout.rightMargin: 28
                spacing: 14
                Image { source: "image://icone/system-software-update"; Layout.preferredWidth: 52; Layout.preferredHeight: 52; sourceSize: Qt.size(104, 104) }
                ColumnLayout {
                    spacing: 2
                    Text { text: "Atualizações"; color: janela.texto; font.pixelSize: 24; font.weight: Font.Bold }
                    Text { text: "Antes de cada atualização, o CarinaeOS cria um ponto de restauro para poder voltar atrás."
                           color: janela.suave; font.pixelSize: 13; wrapMode: Text.Wrap; Layout.fillWidth: true }
                }
            }

            // ---- estado -----------------------------------------------------------------------
            Rectangle {
                Layout.leftMargin: 28; Layout.rightMargin: 28; Layout.fillWidth: true
                implicitHeight: colEstado.implicitHeight + 40
                radius: 18; color: janela.cartao; border.width: 1; border.color: janela.linha
                ColumnLayout {
                    id: colEstado
                    x: 22; y: 20; width: parent.width - 44
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        BusyIndicator { running: atu.lendo || atu.ocupado; visible: running; Layout.preferredWidth: 34; Layout.preferredHeight: 34 }
                        Text {
                            visible: !atu.lendo && !atu.ocupado
                            text: atu.lista.length === 0 ? "✓" : "↻"
                            color: atu.lista.length === 0 ? "#7dffb0" : janela.ambar; font.pixelSize: 30; font.weight: Font.Bold
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true; wrapMode: Text.Wrap
                                color: janela.texto; font.pixelSize: 18; font.weight: Font.DemiBold
                                text: atu.ocupado ? (atu.passo || "Trabalhando…")
                                    : atu.lendo ? "Procurando atualizações…"
                                    : atu.lista.length === 0 ? "O sistema está atualizado"
                                    : atu.lista.length + (atu.lista.length === 1 ? " atualização disponível" : " atualizações disponíveis")
                            }
                            Text {
                                Layout.fillWidth: true; wrapMode: Text.Wrap; color: janela.suave; font.pixelSize: 12
                                visible: text !== ""
                                text: atu.ocupado ? "Pode continuar a usar o computador. Não o desligue até acabar."
                                    : (!atu.lendo && atu.lista.length > 0)
                                      ? atu.lista.filter(a => a.origem === "Sistema").length + " do sistema · " + atu.lista.filter(a => a.origem === "Flatpak").length + " aplicativos Flatpak"
                                      : ""
                            }
                        }
                        Botao {
                            visible: !atu.ocupado && atu.lista.length > 0
                            texto: "Atualizar agora"; principal: true; ativo: !atu.lendo
                            onCarregado: atu.atualizar()
                        }
                        Botao { visible: !atu.ocupado && atu.lista.length === 0; texto: "Procurar de novo"; ativo: !atu.lendo; onCarregado: atu.ler() }
                    }
                    Text {
                        visible: atu.erro !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap
                        text: atu.erro; color: "#ff8a8a"; font.pixelSize: 13
                    }
                    RowLayout {
                        visible: atu.feito && !atu.ocupado
                        spacing: 12
                        Text { text: atu.reiniciar ? "Pronto ✓ Reinicie para acabar de aplicar as atualizações." : "Pronto ✓"; color: "#7dffb0"; font.pixelSize: 14 }
                        Botao { visible: atu.reiniciar; texto: "Reiniciar agora"; principal: true; onCarregado: atu.reiniciarAgora() }
                    }
                    // o que está a acontecer (as últimas linhas)
                    Rectangle {
                        visible: atu.registo !== ""
                        Layout.fillWidth: true; implicitHeight: 150; radius: 10
                        color: Qt.rgba(0, 0, 0, 0.25)
                        ScrollView {
                            anchors.fill: parent; anchors.margins: 10
                            TextArea {
                                readOnly: true; text: atu.registo; color: janela.suave; wrapMode: Text.Wrap
                                font.family: "monospace"; font.pixelSize: 11; background: Item {}
                                onTextChanged: cursorPosition = length
                            }
                        }
                    }
                    // a lista do que vai ser atualizado
                    Text {
                        visible: !atu.ocupado && atu.lista.length > 0
                        text: janela.verLista ? "Esconder a lista ⌃" : "Ver o que vai ser atualizado ⌄"
                        color: janela.ambar; font.pixelSize: 13
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: janela.verLista = !janela.verLista }
                    }
                    Column {
                        visible: janela.verLista && !atu.ocupado
                        Layout.fillWidth: true
                        Repeater {
                            model: atu.lista
                            delegate: RowLayout {
                                required property var modelData
                                width: parent.width
                                Text { text: modelData.nome; color: janela.texto; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: modelData.versao; color: janela.suave; font.pixelSize: 12 }
                                Text { text: modelData.origem; color: modelData.origem === "Flatpak" ? "#9fb4ff" : janela.suave; font.pixelSize: 11; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignRight }
                            }
                        }
                    }
                }
            }

            // ---- pontos de restauro ---------------------------------------------------------
            RowLayout {
                Layout.leftMargin: 28; Layout.rightMargin: 28; Layout.topMargin: 8
                Text { text: "Pontos de restauro"; color: janela.texto; font.pixelSize: 17; font.weight: Font.DemiBold; Layout.fillWidth: true }
                Botao { texto: "Criar um ponto agora"; ativo: !atu.ocupado && atu.temTimeshift; onCarregado: atu.criarPonto() }
            }
            Text {
                Layout.leftMargin: 28; Layout.rightMargin: 28; Layout.fillWidth: true; wrapMode: Text.Wrap
                color: janela.suave; font.pixelSize: 12
                text: atu.temTimeshift
                      ? "Voltar a um ponto devolve o sistema (programas e configurações do sistema) ao estado desse dia. Os seus arquivos e a sua pasta pessoal não mudam. São guardados os 5 mais recentes."
                      : "Falta o Timeshift para criar pontos de restauro: sudo apt install timeshift"
            }
            Rectangle {
                Layout.leftMargin: 28; Layout.rightMargin: 28; Layout.fillWidth: true; Layout.bottomMargin: 28
                implicitHeight: Math.max(64, colPontos.implicitHeight + 8)
                radius: 18; color: janela.cartao; border.width: 1; border.color: janela.linha
                Text {
                    visible: atu.pontosRestauro.length === 0
                    anchors.centerIn: parent
                    text: "Ainda não há pontos de restauro. O primeiro é criado na próxima atualização."
                    color: janela.suave; font.pixelSize: 13
                }
                Column {
                    id: colPontos
                    y: 4; width: parent.width
                    Repeater {
                        model: atu.pontosRestauro
                        delegate: Item {
                            id: pt
                            required property var modelData
                            required property int index
                            width: colPontos.width; height: 62
                            Rectangle { visible: pt.index > 0; x: 18; width: parent.width - 36; height: 1; color: janela.linha }
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 16
                                spacing: 12
                                Image { source: "image://icone/document-revert"; Layout.preferredWidth: 26; Layout.preferredHeight: 26; sourceSize: Qt.size(52, 52) }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 1
                                    Text { text: pt.modelData.comentario; color: janela.texto; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                                    Text { text: pt.modelData.quando; color: janela.suave; font.pixelSize: 12 }
                                }
                                Botao { texto: "Voltar a este ponto"; ativo: !atu.ocupado; onCarregado: janela.aRestaurar = pt.modelData }
                                Botao { texto: "Apagar"; ativo: !atu.ocupado; onCarregado: atu.apagar(pt.modelData.nome) }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- confirmar antes de voltar atrás ------------------------------------------------------
    Rectangle {
        visible: janela.aRestaurar !== null
        anchors.fill: parent; z: 10
        color: Qt.rgba(0, 0, 0, 0.6)
        MouseArea { anchors.fill: parent }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 60, 520); height: colConf.implicitHeight + 48; radius: 20
            color: "#211a33"; border.color: Qt.rgba(1, 0.7, 0.45, 0.4)
            ColumnLayout {
                id: colConf
                x: 26; y: 24; width: parent.width - 52; spacing: 12
                Text { text: "Voltar a este ponto de restauro?"; color: janela.texto; font.pixelSize: 19; font.weight: Font.DemiBold }
                Text {
                    Layout.fillWidth: true; wrapMode: Text.Wrap; color: janela.suave; font.pixelSize: 13
                    text: janela.aRestaurar ? ("O sistema volta ao estado de " + janela.aRestaurar.quando + " («" + janela.aRestaurar.comentario
                          + "»). Os seus arquivos não mudam. No fim o computador reinicia sozinho: salve o que estiver fazendo.") : ""
                }
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 10
                    Botao { texto: "Cancelar"; onCarregado: janela.aRestaurar = null }
                    Botao { texto: "Voltar e reiniciar"; principal: true; onCarregado: { const n = janela.aRestaurar.nome; janela.aRestaurar = null; atu.restaurar(n) } }
                }
            }
        }
    }
}
