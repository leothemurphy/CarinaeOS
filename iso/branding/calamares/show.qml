/* AtriumOS — apresentação durante a instalação */
import QtQuick 2.5
import calamares.slideshow 1.0

Presentation {
    id: presentation

    function nextSlide() { presentation.goToNextSlide(); }

    Timer {
        id: advanceTimer
        interval: 7000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }

    Slide {
        Image { id: i1; source: "slide-brasa.png"; width: 640; height: 360; fillMode: Image.PreserveAspectFit; anchors.centerIn: parent; anchors.verticalCenterOffset: -30 }
        Text { anchors.top: i1.bottom; anchors.topMargin: 16; anchors.horizontalCenter: parent.horizontalCenter; width: 640; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.pixelSize: 17
               text: "Bem-vindo ao AtriumOS.<br/>Bonito como você gosta, leve no seu computador." }
    }
    Slide {
        Image { id: i2; source: "slide-ecos.png"; width: 640; height: 360; fillMode: Image.PreserveAspectFit; anchors.centerIn: parent; anchors.verticalCenterOffset: -30 }
        Text { anchors.top: i2.bottom; anchors.topMargin: 16; anchors.horizontalCenter: parent.horizontalCenter; width: 640; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.pixelSize: 17
               text: "Apps do Linux, do Android e do Windows no mesmo lugar.<br/>É só clicar duas vezes no arquivo .exe." }
    }
    Slide {
        Image { id: i3; source: "slide-mosaico.png"; width: 640; height: 360; fillMode: Image.PreserveAspectFit; anchors.centerIn: parent; anchors.verticalCenterOffset: -30 }
        Text { anchors.top: i3.bottom; anchors.topMargin: 16; anchors.horizontalCenter: parent.horizontalCenter; width: 640; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.pixelSize: 17
               text: "Antes de cada atualização, o AtriumOS cria um ponto de restauração.<br/>Se algo der errado, dá para voltar." }
    }

    function onActivate() { }
    function onLeave() { }
}
