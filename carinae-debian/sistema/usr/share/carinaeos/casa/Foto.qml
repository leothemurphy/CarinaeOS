// CarinaeOS - Casa: uma imagem com cantos arredondados (fotos das pessoas, imagens, câmeras)
import QtQuick
import QtQuick.Effects

Item {
    id: f
    property string fonte: ""
    property real raio: width / 2
    property int preencher: Image.PreserveAspectCrop
    readonly property alias imagem: img
    // sem placa de vídeo (renderizador por software) não há máscaras: a imagem fica de cantos retos
    readonly property bool mascarar: GraphicsInfo.api !== GraphicsInfo.Software
    Item {
        anchors.fill: parent
        layer.enabled: f.mascarar
        layer.effect: MultiEffect { maskEnabled: true; maskSource: mascara; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
        Image { id: img; anchors.fill: parent; source: f.fonte; fillMode: f.preencher; asynchronous: true; cache: false
                sourceSize.width: Math.max(64, Math.round(f.width * 2)) }    // nunca carrega mais do que o necessário
    }
    Item {
        id: mascara
        anchors.fill: parent; visible: false; layer.enabled: f.mascarar; layer.smooth: true
        Rectangle { anchors.fill: parent; radius: f.raio; color: "black"; antialiasing: true }
    }
}
