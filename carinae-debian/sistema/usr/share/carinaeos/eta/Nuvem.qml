// CarinaeOS - Eta: a "nuvem" — janela pequena e flutuante, sempre por cima, como a Siri.
// Mostra que a Eta está a ouvir, a pensar ou a fazer algo, e a resposta curta.
// O lugar no ecrã (canto inferior direito, acima da Dock) é dado pelo script do KWin "carinaeos-mesa".
import QtQuick
import QtQuick.Window

Window {
    id: nuvem
    signal abrir()
    title: "Eta — atividade"
    width: 380
    height: caixa.height + 24
    color: "transparent"
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus

    readonly property string texto: eta.respostaNuvem !== "" && eta.atividade === "" ? eta.respostaNuvem
                                   : eta.atividade !== "" ? eta.atividade : "Eta"

    Rectangle {
        id: caixa
        x: 12; y: 12
        width: parent.width - 24
        height: Math.max(76, col.implicitHeight + 28)
        radius: 28
        color: Qt.rgba(0.09, 0.07, 0.14, 0.94)
        border.color: Qt.rgba(1, 0.7, 0.43, 0.35)
        border.width: 1
        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // brilho a percorrer a borda enquanto está ativa
        Rectangle {
            anchors.fill: parent; radius: parent.radius; color: "transparent"
            border.width: 2; border.color: eta.ouvindo ? "#ff6f91" : "#ffb46e"
            opacity: eta.ocupada ? 0.25 + 0.35 * Math.abs(Math.sin(brilho.f)) : 0
            Item { id: brilho; property real f: 0; NumberAnimation on f { from: 0; to: Math.PI; duration: 1400; loops: Animation.Infinite; running: eta.ocupada } }
        }

        Orbe {
            id: orbe
            x: 16; anchors.verticalCenter: parent.verticalCenter
            width: 44; height: 44
            ativo: eta.ocupada
            nivel: eta.ouvindo ? eta.nivelVoz : 0
        }
        Column {
            id: col
            anchors.left: orbe.right; anchors.leftMargin: 14
            anchors.right: botoes.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Text {
                text: eta.ouvindo ? "A ouvir…" : eta.ocupada ? "Eta está a trabalhar" : "Eta"
                color: eta.ouvindo ? "#ff8fa6" : "#ffb46e"; font.pixelSize: 12; font.weight: Font.DemiBold; font.family: "Inter"
            }
            Text {
                width: parent.width
                text: eta.ouvindo ? "Fale agora — eu paro quando se calar" : nuvem.texto
                color: "#f4eee8"; font.pixelSize: 14; font.family: "Inter"
                wrapMode: Text.WordWrap; maximumLineCount: 5; elide: Text.ElideRight
            }
            // ondas da voz
            Row {
                visible: eta.ouvindo
                spacing: 3; height: 18
                Repeater {
                    model: 14
                    Rectangle {
                        required property int index
                        width: 4; radius: 2; color: "#ff8fa6"
                        height: 4 + 14 * Math.abs(Math.sin(index * 0.9 + onda.f)) * Math.min(1, eta.nivelVoz * 2 + 0.15)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                Item { id: onda; property real f: 0; NumberAnimation on f { from: 0; to: Math.PI * 2; duration: 900; loops: Animation.Infinite; running: eta.ouvindo } }
            }
        }
        Row {
            id: botoes
            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            BotaoRedondo { visible: eta.ocupada; tamanho: 32; destaque: true; icone: "media-playback-stop"; dica: "Parar"; onClicado: eta.parar() }
            BotaoRedondo { tamanho: 30; icone: "go-up"; dica: "Abrir a Eta"; onClicado: nuvem.abrir() }
            BotaoRedondo { visible: !eta.ocupada; tamanho: 30; icone: "window-close"; dica: "Fechar"; onClicado: eta.fecharNuvem() }
        }
        MouseArea { anchors.fill: col; onClicked: nuvem.abrir() }
    }
}
