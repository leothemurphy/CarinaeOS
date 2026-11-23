// CarinaeOS — volume na barra de cima (PipeWire, via wpctl): clique = silenciar, roda = mais/menos
import QtQuick
import CarinaeOS.Compat as C

Item {
    id: volume
    implicitWidth: 26
    property real nivel: -1
    property bool mudo: false

    C.DataSource {
        id: ler
        engine: "executable"
        onNewData: (fonte, dados) => {
            disconnectSource(fonte);
            const s = String(dados["stdout"] || "");
            const m = s.match(/Volume:\s*([\d.]+)/);
            volume.nivel = m ? parseFloat(m[1]) : -1;
            volume.mudo = s.indexOf("MUTED") !== -1;
        }
    }
    C.DataSource { id: mudar; engine: "executable"; onNewData: (f) => { disconnectSource(f); volume.atualizar(); } }
    function atualizar(): void { ler.connectSource("wpctl get-volume @DEFAULT_AUDIO_SINK@ #" + Date.now()); }
    Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: volume.atualizar() }

    visible: nivel >= 0
    C.Icon {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: volume.mudo || volume.nivel === 0 ? "audio-volume-muted"
              : volume.nivel < 0.34 ? "audio-volume-low"
              : volume.nivel < 0.67 ? "audio-volume-medium" : "audio-volume-high"
        isMask: true
        color: "#f6f2ff"
    }
    MouseArea {
        anchors.fill: parent
        onClicked: mudar.connectSource("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle #" + Date.now())
        onWheel: (ev) => mudar.connectSource("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%" + (ev.angleDelta.y > 0 ? "+" : "-") + " #" + Date.now())
    }
}
