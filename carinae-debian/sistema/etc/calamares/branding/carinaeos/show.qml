/* CarinaeOS - apresentacao durante a instalacao (Calamares, slideshowAPI 2) */
import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: apresentacao
    function nextSlide() { apresentacao.goToNextSlide() }
    Timer {
        id: avancar
        interval: 6000
        running: apresentacao.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }
    Slide { Image { anchors.centerIn: parent; source: "calamares-slide1.png"; width: parent.width; height: parent.height; fillMode: Image.PreserveAspectFit; smooth: true } }
    Slide { Image { anchors.centerIn: parent; source: "calamares-slide2.png"; width: parent.width; height: parent.height; fillMode: Image.PreserveAspectFit; smooth: true } }
    Slide { Image { anchors.centerIn: parent; source: "calamares-slide3.png"; width: parent.width; height: parent.height; fillMode: Image.PreserveAspectFit; smooth: true } }
    function onActivate() { avancar.running = true }
    function onLeave() { avancar.running = false }
}
