// CarinaeOS - Ambiente de trabalho: KDE Plasma, GNOME ou XFCE
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: janela
    width: 1180; height: 640
    minimumWidth: 760; minimumHeight: 520
    visible: true
    title: "Ambiente de trabalho"
    color: "#0d0a13"
    font.family: "Inter"; font.pixelSize: 14

    readonly property color ambar: "#ffb46e"
    readonly property color rosa: "#ff6f91"
    readonly property color texto: "#f4eee8"
    readonly property color textoSuave: "#b9aec4"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient { GradientStop { position: 0; color: "#150f1f" } GradientStop { position: 1; color: "#0a0810" } }
    }

    Column {
        x: 36; y: 30; width: parent.width - 72; spacing: 8
        Text { text: "Ambiente de trabalho"; color: janela.texto; font.pixelSize: 30; font.weight: Font.Bold }
        Text {
            width: parent.width; wrapMode: Text.WordWrap; color: janela.textoSuave
            text: "Escolha como quer o seu CarinaeOS. Pode ter os três instalados e trocar quando quiser: os seus arquivos, aplicativos e papéis de parede ficam iguais."
        }
        Text {
            visible: amb.aoVivo; width: parent.width; wrapMode: Text.WordWrap; color: janela.ambar; font.pixelSize: 13
            text: "Está a usar o CarinaeOS sem instalar: o que instalar aqui desaparece ao desligar. Para guardar, instale primeiro o CarinaeOS no disco."
        }
    }

    Row {
        id: cartoes
        x: 36; y: 160
        spacing: 18
        Repeater {
            model: amb.ambientes
            delegate: Rectangle {
                id: c
                required property var modelData
                readonly property bool aInstalar: amb.aInstalar === modelData.id
                width: (janela.width - 72 - 54) / 4; height: 380; radius: 20
                color: "#1a1524"
                border.color: modelData.atual ? janela.ambar : Qt.rgba(1, 1, 1, 0.08)
                border.width: modelData.atual ? 2 : 1
                Column {
                    x: 22; y: 22; width: parent.width - 44; spacing: 10
                    Image { source: "image://icone/" + c.modelData.icone; width: 56; height: 56; sourceSize: Qt.size(112, 112) }
                    Text { text: c.modelData.nome; color: janela.texto; font.pixelSize: 22; font.weight: Font.Bold }
                    Text {
                        text: c.modelData.atual ? "● em uso agora" : c.modelData.instalado ? "instalado" : "não instalado · " + c.modelData.tamanho
                        color: c.modelData.atual ? janela.ambar : janela.textoSuave; font.pixelSize: 12
                    }
                    Text { width: parent.width; wrapMode: Text.WordWrap; color: janela.textoSuave; font.pixelSize: 13; text: c.modelData.desc; lineHeight: 1.15 }
                }
                // andamento da instalação
                Column {
                    visible: c.aInstalar
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: botao.top
                    anchors.margins: 22; spacing: 6
                    Rectangle {
                        width: parent.width; height: 8; radius: 4; color: Qt.rgba(1, 1, 1, 0.1)
                        Rectangle {
                            width: parent.width * Math.max(0.02, amb.progresso); height: parent.height; radius: 4
                            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: janela.rosa } GradientStop { position: 1; color: janela.ambar } }
                            Behavior on width { NumberAnimation { duration: 300 } }
                        }
                    }
                    Text { width: parent.width; elide: Text.ElideRight; color: janela.ambar; font.pixelSize: 12
                           text: Math.round(Math.max(0, amb.progresso) * 100) + "% · " + amb.etapa }
                }
                Rectangle {
                    id: botao
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 22
                    height: 40; radius: 20
                    readonly property string acao: c.aInstalar ? "cancelar" : c.modelData.atual ? "" : c.modelData.instalado ? "usar" : "instalar"
                    visible: acao !== ""
                    opacity: amb.aInstalar !== "" && !c.aInstalar ? 0.4 : 1
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: botao.acao === "cancelar" ? "#3a3246" : janela.rosa }
                        GradientStop { position: 1; color: botao.acao === "cancelar" ? "#3a3246" : janela.ambar }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: botao.acao === "cancelar" ? "Parar" : botao.acao === "usar" ? (c.modelData.id === "windows" || c.modelData.id === "plasma" ? "Usar este" : "Usar este (terminar sessão)") : "Instalar"
                        color: botao.acao === "cancelar" ? janela.texto : "#1a0f14"; font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        enabled: amb.aInstalar === "" || c.aInstalar
                        onClicked: botao.acao === "cancelar" ? amb.cancelar() : botao.acao === "usar" ? amb.usar(c.modelData.id) : amb.instalar(c.modelData.id)
                    }
                }
            }
        }
    }

    Text {
        anchors.top: cartoes.bottom; anchors.topMargin: 18
        x: 36; width: parent.width - 72; wrapMode: Text.WordWrap
        text: amb.mensagem !== "" ? amb.mensagem : "Dica: na tela de entrada, o canto inferior esquerdo também deixa escolher o ambiente antes de entrar."
        color: amb.mensagem !== "" ? janela.ambar : janela.textoSuave; font.pixelSize: 13
    }
}
