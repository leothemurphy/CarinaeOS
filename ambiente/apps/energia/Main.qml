// CarinaeOS — Energia
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: janela
    width: 620; height: 560
    minimumWidth: 520; minimumHeight: 480
    visible: true
    title: "Energia"
    color: "#0c0a14"
    font.family: "Inter"; font.pixelSize: 14

    readonly property color ambar: "#ffb46e"
    readonly property color texto: "#f6f2ff"
    readonly property color suave: "#b9b0cc"
    readonly property var v: energia.valores

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 28
        spacing: 14

        Text { text: "Energia"; color: janela.texto; font.pixelSize: 26; font.weight: Font.DemiBold }
        Text { Layout.fillWidth: true; wrapMode: Text.Wrap; color: janela.suave
               text: "Quando o computador fica parado. Enquanto um vídeo está a tocar (Firefox, Chrome, Pulsar, VLC…) o ecrã nunca se apaga." }

        Linha {
            titulo: "Desligar o ecrã depois de"
            Escolha {
                opcoes: [[0, "Nunca"], [1, "1 minuto"], [2, "2 minutos"], [5, "5 minutos"], [10, "10 minutos"], [15, "15 minutos"], [30, "30 minutos"], [60, "1 hora"]]
                valor: janela.v.desligarEcra; onEscolhido: (x) => energia.mudar("desligarEcra", x)
            }
        }
        Linha {
            titulo: "Bloquear quando o ecrã se desliga"
            sub: "Pede a senha para voltar"
            Interruptor { ligado: !!janela.v.bloquear; enabled: janela.v.desligarEcra > 0; onMudou: (x) => energia.mudar("bloquear", x) }
        }
        Linha {
            titulo: "Suspender depois de"
            sub: "Não suspende durante cópias, transferências ou vídeos"
            Escolha {
                opcoes: [[0, "Nunca"], [15, "15 minutos"], [30, "30 minutos"], [60, "1 hora"], [120, "2 horas"], [240, "4 horas"]]
                valor: janela.v.suspender; onEscolhido: (x) => energia.mudar("suspender", x)
            }
        }
        Linha {
            titulo: "Bloquear ao suspender"
            Interruptor { ligado: janela.v.bloquearAoSuspender !== false; onMudou: (x) => energia.mudar("bloquearAoSuspender", x) }
        }
        Linha {
            titulo: "Botão de ligar do computador"
            Escolha {
                opcoes: [["perguntar", "Perguntar o que fazer"], ["desligar", "Desligar"], ["suspender", "Suspender"], ["nada", "Não fazer nada"]]
                valor: janela.v.botao; onEscolhido: (x) => energia.mudar("botao", x)
            }
        }
        Item { Layout.fillHeight: true }
    }

    component Linha: Rectangle {
        id: l
        property string titulo
        property string sub: ""
        default property alias conteudo: canto.data
        Layout.fillWidth: true
        Layout.preferredHeight: sub ? 66 : 56
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.05)
        Column {
            anchors.left: parent.left; anchors.leftMargin: 18; anchors.verticalCenter: parent.verticalCenter
            anchors.right: canto.left; anchors.rightMargin: 12
            spacing: 3
            Text { text: l.titulo; color: janela.texto; font.pixelSize: 14 }
            Text { visible: l.sub !== ""; text: l.sub; color: janela.suave; font.pixelSize: 12; width: parent.width; elide: Text.ElideRight }
        }
        Item { id: canto; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
               width: childrenRect.width; height: childrenRect.height }
    }

    component Interruptor: Rectangle {
        id: sw
        property bool ligado
        signal mudou(bool v)
        width: 46; height: 24; radius: 12
        opacity: enabled ? 1 : 0.4
        color: ligado ? janela.ambar : Qt.rgba(1, 1, 1, 0.14)
        Rectangle { width: 18; height: 18; radius: 9; y: 3; x: sw.ligado ? 25 : 3; color: sw.ligado ? "#1b1030" : "#f6f2ff"
                    Behavior on x { NumberAnimation { duration: 120 } } }
        MouseArea { anchors.fill: parent; enabled: sw.enabled; onClicked: sw.mudou(!sw.ligado) }
    }

    component Escolha: ComboBox {
        id: cb
        property var opcoes: []
        property var valor
        signal escolhido(var v)
        width: 210; height: 34
        model: opcoes.map(o => o[1])
        currentIndex: Math.max(0, opcoes.findIndex(o => o[0] === valor))
        onActivated: (i) => cb.escolhido(opcoes[i][0])
        contentItem: Text { leftPadding: 12; text: cb.displayText; color: janela.texto; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13 }
        background: Rectangle { radius: 8; color: Qt.rgba(1, 1, 1, cb.hovered ? 0.12 : 0.08); border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.12) }
        indicator: Text { x: cb.width - 24; anchors.verticalCenter: parent.verticalCenter; text: "▾"; color: janela.suave }
        popup: Popup {
            y: cb.height + 4; width: cb.width; padding: 4
            implicitHeight: contentItem.implicitHeight + 8
            background: Rectangle { radius: 10; color: "#1b1828"; border.color: Qt.rgba(1, 1, 1, 0.12) }
            contentItem: ListView {
                implicitHeight: contentHeight; clip: true
                model: cb.popup.visible ? cb.delegateModel : null
            }
        }
        delegate: ItemDelegate {
            required property int index
            required property var modelData
            width: cb.width - 8; height: 32
            contentItem: Text { text: modelData; color: index === cb.currentIndex ? janela.ambar : janela.texto; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { radius: 6; color: hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent" }
        }
    }
}
