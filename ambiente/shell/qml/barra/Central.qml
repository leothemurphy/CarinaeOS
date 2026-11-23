// CarinaeOS — central de ajustes (ao lado do relógio): rede, Bluetooth, não incomodar, luz noturna,
// som, brilho e atalhos. Tudo com as ferramentas normais do sistema (nmcli, bluetoothctl, wpctl, xrandr).
import QtQuick
import QtQuick.Layouts
import CarinaeOS.Base
import CarinaeOS.Compat as C

Item {
    id: central
    implicitWidth: 30

    readonly property color ambar: "#ffb46e"
    readonly property color texto: "#f6f2ff"
    readonly property color suave: "#b9b0cc"
    readonly property string pastaCfg: Sistema.casa + "/.config/carinaeos"

    // ---- estado ------------------------------------------------------------------------------
    property bool temWifi: false
    property bool wifiLigado: false
    property string redeNome: ""
    property string redeTipo: ""          // "wifi", "cabo" ou ""
    property bool temBt: false
    property bool btLigado: false
    property string btDispositivo: ""
    property bool naoIncomodar: false
    property bool luzNoturna: false
    property real brilho: 1.0
    property real volume: 0.5
    property bool mudo: false
    property string saida: ""

    // ---- papéis de parede para trocar rápido (a lista pode ser mudada em ~/.config/carinaeos/papeis.json)
    readonly property var papeisPadrao: [
        Sistema.casa + "/.local/share/carinaeos/papeis/tigre.jpg",
        Sistema.casa + "/.local/share/carinaeos/papeis/abstrato.jpg",
        "/usr/share/wallpapers/CarinaeOS-Fusao/contents/images/3840x2160.jpg",
        "/usr/share/backgrounds/carinaeos/eta-carinae.jpg",
        "/usr/local/share/carinaeos/papeis/nebulosa.jpg",
        "/usr/local/share/carinaeos/papeis/aurora.jpg",
        "/usr/local/share/carinaeos/papeis/orbita.jpg"
    ]
    property var papeis: papeisPadrao
    function lerPapeis() {
        try {
            const l = JSON.parse(Sistema.lerTexto(pastaCfg + "/papeis.json") || "null");
            papeis = Array.isArray(l) && l.length ? l.slice(0, 6) : papeisPadrao;
        } catch (e) { papeis = papeisPadrao; }
    }
    function usarPapel(caminho) {
        const c = Object.assign({}, Sistema.shell);
        c.papel = caminho;
        c.papel2 = caminho;
        Sistema.gravarTexto(Sistema.casa + "/.config/carinaeos-shell.json", JSON.stringify(c));
    }

    function q(t) { return "'" + String(t).replace(/'/g, "'\\''") + "'" }

    function atualizar() {
        Sistema.correr("LC_ALL=C nmcli -t -f TYPE,STATE,CONNECTION device 2>/dev/null; echo ===; LC_ALL=C nmcli radio wifi 2>/dev/null", function (s) {
            const partes = s.split("===");
            let wifi = false, nome = "", tipo = "";
            for (const l of partes[0].split("\n")) {
                const c = l.split(":");
                if (c.length < 3) continue;
                if (c[0] === "wifi") wifi = true;
                if (c[1] === "connected" && !tipo) {
                    if (c[0] === "wifi") { tipo = "wifi"; nome = c.slice(2).join(":"); }
                    else if (c[0] === "ethernet") { tipo = "cabo"; nome = c.slice(2).join(":"); }
                }
            }
            central.temWifi = wifi;
            central.wifiLigado = (partes[1] || "").trim() === "enabled";
            central.redeNome = nome;
            central.redeTipo = tipo;
        });
        Sistema.correr("LC_ALL=C bluetoothctl show 2>/dev/null | grep -E 'Controller|Powered'; echo ===; LC_ALL=C bluetoothctl devices Connected 2>/dev/null | head -1", function (s) {
            const partes = s.split("===");
            central.temBt = partes[0].indexOf("Controller") !== -1;
            central.btLigado = /Powered:\s*yes/.test(partes[0]);
            const m = (partes[1] || "").match(/Device\s+\S+\s+(.+)/);
            central.btDispositivo = m ? m[1].trim() : "";
        });
        Sistema.correr("test -e " + q(pastaCfg + "/nao-incomodar") + " && echo s; echo ===; cat " + q(pastaCfg + "/luz-noturna") + " 2>/dev/null; echo ===; cat " + q(pastaCfg + "/brilho") + " 2>/dev/null", function (s) {
            const p = s.split("===");
            central.naoIncomodar = p[0].trim() === "s";
            central.luzNoturna = (p[1] || "").trim() === "1";
            const b = parseFloat((p[2] || "").trim());
            central.brilho = isNaN(b) ? 1 : Math.max(0.3, Math.min(1, b));
        });
        lerSom();
    }
    function lerSom() {
        Sistema.correr("wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null; echo ===; wpctl inspect @DEFAULT_AUDIO_SINK@ 2>/dev/null | grep -m1 'node.description'", function (s) {
            const p = s.split("===");
            const m = p[0].match(/Volume:\s*([\d.]+)/);
            if (m) central.volume = parseFloat(m[1]);
            central.mudo = p[0].indexOf("MUTED") !== -1;
            const d = (p[1] || "").match(/node\.description\s*=\s*"(.*)"/);
            central.saida = d ? d[1] : "";
        });
    }

    // brilho e luz noturna: gama/brilho em todos os monitores (funciona com qualquer placa)
    function aplicarTela() {
        const gama = luzNoturna ? "1.0:0.84:0.66" : "1:1:1";
        Sistema.correr("for o in $(xrandr --query | awk '/ connected/{print $1}'); do xrandr --output \"$o\" --gamma " + gama
                       + " --brightness " + brilho.toFixed(2) + "; done; mkdir -p " + q(pastaCfg) + "; echo " + (luzNoturna ? 1 : 0)
                       + " > " + q(pastaCfg + "/luz-noturna") + "; echo " + brilho.toFixed(2) + " > " + q(pastaCfg + "/brilho"), null);
    }
    // ao arrancar a Aurora: repor a luz noturna e o brilho que estavam
    Component.onCompleted: Sistema.correr("cat " + q(pastaCfg + "/luz-noturna") + " 2>/dev/null; echo ===; cat " + q(pastaCfg + "/brilho") + " 2>/dev/null", function (s) {
        const p = s.split("===");
        central.luzNoturna = p[0].trim() === "1";
        const b = parseFloat((p[1] || "").trim());
        central.brilho = isNaN(b) ? 1 : Math.max(0.3, Math.min(1, b));
        if (central.luzNoturna || central.brilho < 0.99) central.aplicarTela();
    })
    Timer { id: brilhoTimer; interval: 120; onTriggered: central.aplicarTela() }
    Timer { id: volumeTimer; interval: 60; property real alvo: 0; onTriggered: Sistema.correr("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ " + alvo.toFixed(2), null) }

    // ---- o botão na barra (dois interruptores, como num painel de controlo) -----------------------
    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 3; anchors.bottomMargin: 3
        radius: 6
        color: Qt.rgba(1, 1, 1, rato.containsMouse || painel.visible ? 0.14 : 0)
    }
    Column {
        anchors.centerIn: parent
        spacing: 3
        Repeater {
            model: [true, false]
            Rectangle {
                required property bool modelData
                width: 16; height: 6; radius: 3
                color: "transparent"; border.color: "#f6f2ff"; border.width: 1.4
                Rectangle { width: 4; height: 4; radius: 2; y: 1; x: parent.modelData ? 10 : 2; color: "#f6f2ff" }
            }
        }
    }
    MouseArea {
        id: rato
        anchors.fill: parent
        hoverEnabled: true
        onClicked: { if (!painel.visible) { central.atualizar(); central.lerPapeis(); } painel.visible = !painel.visible }
    }

    // ---- o painel -----------------------------------------------------------------------------------
    C.Dialog {
        id: painel
        visualParent: central
        location: 3
        hideOnWindowDeactivate: true
        backgroundHints: 0
        mainItem: Rectangle {
            width: 360
            height: col.implicitHeight + 32
            radius: 18
            color: Qt.rgba(0.10, 0.09, 0.14, 0.97)
            border.color: Qt.rgba(1, 1, 1, 0.12)

            ColumnLayout {
                id: col
                x: 16; y: 16
                width: parent.width - 32
                spacing: 12

                GridLayout {
                    columns: 2; columnSpacing: 10; rowSpacing: 10
                    Layout.fillWidth: true
                    Bloco {
                        icone: central.redeTipo === "cabo" ? "network-wired" : (central.wifiLigado ? "network-wireless" : "network-wireless-disconnected")
                        titulo: central.temWifi ? "Wi-Fi" : "Rede"
                        sub: central.redeTipo === "cabo" ? "Cabo ligado"
                           : central.redeTipo === "wifi" ? central.redeNome
                           : central.temWifi ? (central.wifiLigado ? "Sem ligação" : "Desligado") : "Sem ligação"
                        ligado: central.temWifi ? central.wifiLigado : central.redeTipo !== ""
                        onAlternar: {
                            if (!central.temWifi) { painel.visible = false; Sistema.executar("carinaeos-configuracoes rede"); return; }
                            central.wifiLigado = !central.wifiLigado;
                            Sistema.correr("nmcli radio wifi " + (central.wifiLigado ? "on" : "off"), function () { central.atualizar() });
                        }
                        onDetalhes: { painel.visible = false; Sistema.executar("carinaeos-configuracoes " + (central.temWifi ? "wifi" : "rede")) }
                    }
                    Bloco {
                        icone: "preferences-system-bluetooth"
                        titulo: "Bluetooth"
                        sub: !central.temBt ? "Não encontrado" : !central.btLigado ? "Desligado" : (central.btDispositivo || "Ligado")
                        ligado: central.btLigado
                        enabled: central.temBt
                        onAlternar: {
                            central.btLigado = !central.btLigado;
                            Sistema.correr(central.btLigado ? "rfkill unblock bluetooth 2>/dev/null; bluetoothctl power on" : "bluetoothctl power off",
                                           function () { central.atualizar() });
                        }
                        onDetalhes: { painel.visible = false; Sistema.executar("carinaeos-configuracoes bluetooth") }
                    }
                    Bloco {
                        icone: "notifications-disabled"
                        titulo: "Não incomodar"
                        sub: Notificacoes.naoIncomodar ? "Avisos em silêncio" : "Desligado"
                        ligado: Notificacoes.naoIncomodar
                        onAlternar: Notificacoes.naoIncomodar = !Notificacoes.naoIncomodar
                        onDetalhes: Notificacoes.naoIncomodar = !Notificacoes.naoIncomodar
                    }
                    Bloco {
                        icone: "redshift-status-on"
                        iconeAlt: "weather-clear-night"
                        titulo: "Luz noturna"
                        sub: central.luzNoturna ? "Cores mais quentes" : "Desligada"
                        ligado: central.luzNoturna
                        onAlternar: { central.luzNoturna = !central.luzNoturna; central.aplicarTela() }
                        onDetalhes: { central.luzNoturna = !central.luzNoturna; central.aplicarTela() }
                    }
                }

                // notificações recentes
                Rectangle {
                    id: recentes
                    property bool todas: false
                    readonly property var itens: Notificacoes.historico.slice(0, todas ? 8 : 3)
                    visible: Notificacoes.historico.length > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: colHist.implicitHeight + 20
                    height: Layout.preferredHeight; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                    Column {
                        id: colHist
                        x: 14; y: 10; width: parent.width - 28; spacing: 8
                        Item {
                            width: parent.width; height: 16
                            Text { text: "Notificações" + (Notificacoes.historico.length > 3 ? "  ·  " + Notificacoes.historico.length : "")
                                   color: central.suave; font.pixelSize: 12 }
                            Text {
                                anchors.right: parent.right
                                text: "Limpar"; color: limparRato.containsMouse ? central.texto : central.ambar; font.pixelSize: 12
                                MouseArea { id: limparRato; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor; onClicked: Notificacoes.limparHistorico() }
                            }
                        }
                        Repeater {
                            model: recentes.itens
                            delegate: Item {
                                id: linhaHist
                                required property var modelData
                                width: colHist.width; height: 38
                                C.Icon { id: icHist; width: 26; height: 26; anchors.verticalCenter: parent.verticalCenter
                                         source: linhaHist.modelData.icone || "dialog-information" }
                                Column {
                                    anchors.left: icHist.right; anchors.leftMargin: 10
                                    anchors.right: tempoHist.left; anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                                           text: linhaHist.modelData.titulo || linhaHist.modelData.app
                                           color: central.texto; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    Text { width: parent.width; elide: Text.ElideRight; textFormat: Text.PlainText
                                           text: String(linhaHist.modelData.corpo || "").replace(/<[^>]*>/g, " ")
                                           color: central.suave; font.pixelSize: 11 }
                                }
                                Text {
                                    id: tempoHist
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    color: "#8f87a3"; font.pixelSize: 10
                                    text: {
                                        const m = Math.floor((Date.now() - linhaHist.modelData.hora) / 60000);
                                        return m < 1 ? "agora" : m < 60 ? m + " min" : m < 1440 ? Math.floor(m / 60) + " h"
                                             : Qt.formatDate(new Date(linhaHist.modelData.hora), "d/M");
                                    }
                                }
                                MouseArea { anchors.fill: parent; acceptedButtons: Qt.RightButton | Qt.MiddleButton
                                            onClicked: Notificacoes.apagarDoHistorico(linhaHist.modelData.id) }
                            }
                        }
                        Text {
                            visible: Notificacoes.historico.length > 3
                            text: recentes.todas ? "Mostrar menos" : "Ver mais"
                            color: maisRato.containsMouse ? central.texto : central.ambar; font.pixelSize: 12
                            MouseArea { id: maisRato; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor; onClicked: recentes.todas = !recentes.todas }
                        }
                    }
                }
                // som
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 74
                    height: 74; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                    Column {
                        x: 14; y: 10; width: parent.width - 28; spacing: 6
                        Text { text: "Som" + (central.saida ? "  ·  " + central.saida : ""); color: central.suave; font.pixelSize: 12; elide: Text.ElideRight; width: parent.width }
                        Linha {
                            icone: central.mudo || central.volume === 0 ? "audio-volume-muted" : central.volume < 0.34 ? "audio-volume-low" : central.volume < 0.67 ? "audio-volume-medium" : "audio-volume-high"
                            valor: central.volume
                            onIconeClicado: { central.mudo = !central.mudo; Sistema.correr("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle", null) }
                            onMovido: (v) => { central.volume = v; volumeTimer.alvo = v; volumeTimer.restart() }
                        }
                    }
                }
                // brilho
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 74
                    height: 74; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                    Column {
                        x: 14; y: 10; width: parent.width - 28; spacing: 6
                        Text { text: "Brilho das telas"; color: central.suave; font.pixelSize: 12 }
                        Linha {
                            icone: "brightness-high"
                            iconeAlt: "display-brightness"
                            valor: (central.brilho - 0.3) / 0.7
                            onIconeClicado: { central.brilho = 1; central.aplicarTela() }
                            onMovido: (v) => { central.brilho = 0.3 + v * 0.7; brilhoTimer.restart() }
                        }
                    }
                }
                // papel de parede
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: grelhaPapeis.height + 42
                    height: Layout.preferredHeight; radius: 14
                    color: Qt.rgba(1, 1, 1, 0.05)
                    Text { x: 14; y: 10; text: "Papel de parede"; color: central.suave; font.pixelSize: 12 }
                    Grid {
                        id: grelhaPapeis
                        x: 12; y: 30
                        columns: 3; spacing: 8
                        readonly property real lado: (parent.width - 24 - 16) / 3
                        Repeater {
                            model: central.papeis
                            delegate: Rectangle {
                                id: miniatura
                                required property string modelData
                                readonly property bool atual: (Sistema.shell.papel || "") === modelData
                                width: grelhaPapeis.lado; height: width * 9 / 16
                                radius: 10
                                color: Qt.rgba(1, 1, 1, 0.06)
                                visible: foto.status !== Image.Error
                                Image {
                                    id: foto
                                    anchors.fill: parent; anchors.margins: miniatura.atual ? 3 : 0
                                    source: "file://" + miniatura.modelData
                                    sourceSize: Qt.size(240, 135)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    clip: true
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 10
                                    color: "transparent"
                                    border.width: miniatura.atual ? 2 : (papelRato.containsMouse ? 1 : 0)
                                    border.color: miniatura.atual ? central.ambar : Qt.rgba(1, 1, 1, 0.5)
                                }
                                MouseArea { id: papelRato; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: central.usarPapel(miniatura.modelData) }
                            }
                        }
                    }
                }
                // atalhos
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: [["video-display", "Telas", "carinae-telas"],
                                ["configure", "Ajustes", "carinaeos-configuracoes"],
                                ["camera-photo", "Captura", "sleep 0.3; carinae-captura regiao"],
                                ["system-lock-screen", "Bloquear", "carinae-sessao bloquear"],
                                ["system-shutdown", "Desligar", "aurora --enviar desligar || carinae-sessao desligar"]]
                        delegate: Item {
                            required property var modelData
                            Layout.fillWidth: true
                            height: 62
                            Rectangle {
                                id: bola
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 40; height: 40; radius: 20
                                color: Qt.rgba(1, 1, 1, atalhoRato.pressed ? 0.20 : atalhoRato.containsMouse ? 0.14 : 0.07)
                                C.Icon { anchors.centerIn: parent; source: modelData[0]; width: 20; height: 20; isMask: true; color: "#f6f2ff" }
                            }
                            Text { anchors.top: bola.bottom; anchors.topMargin: 5; anchors.horizontalCenter: parent.horizontalCenter
                                   text: modelData[1]; color: central.suave; font.pixelSize: 11 }
                            MouseArea {
                                id: atalhoRato
                                anchors.fill: parent; hoverEnabled: true
                                onClicked: { painel.visible = false; Sistema.executar(modelData[2]) }
                            }
                        }
                    }
                }
            }
        }
    }

    // um bloco redondo com interruptor (clicar no ícone liga/desliga; no resto abre os detalhes)
    component Bloco: Rectangle {
        id: b
        property string icone
        property string iconeAlt: ""
        property string titulo
        property string sub
        property bool ligado
        signal alternar()
        signal detalhes()
        Layout.fillWidth: true
        height: 64; radius: 16
        opacity: enabled ? 1 : 0.45
        color: Qt.rgba(1, 1, 1, blocoRato.containsMouse ? 0.09 : 0.05)
        Rectangle {
            id: circulo
            x: 10; anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 40; radius: 20
            color: b.ligado ? central.ambar : Qt.rgba(1, 1, 1, 0.12)
            Behavior on color { ColorAnimation { duration: 150 } }
            C.Icon { anchors.centerIn: parent; source: b.icone; width: 20; height: 20; isMask: true; color: b.ligado ? "#1b1030" : "#f6f2ff" }
            MouseArea { anchors.fill: parent; enabled: b.enabled; onClicked: b.alternar() }
        }
        Column {
            anchors.left: circulo.right; anchors.leftMargin: 10
            anchors.right: parent.right; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            Text { text: b.titulo; color: central.texto; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
            Text { text: b.sub; color: central.suave; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
        }
        MouseArea { id: blocoRato; anchors.fill: parent; anchors.leftMargin: 54; hoverEnabled: true; enabled: b.enabled; onClicked: b.detalhes() }
    }

    // ícone + barra deslizante
    component Linha: Item {
        id: l
        property string icone
        property string iconeAlt: ""
        property real valor
        signal iconeClicado()
        signal movido(real v)
        width: parent ? parent.width : 300
        height: 30
        C.Icon {
            id: ico
            anchors.verticalCenter: parent.verticalCenter
            source: l.icone; width: 20; height: 20; isMask: true; color: "#f6f2ff"
            MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: l.iconeClicado() }
        }
        Item {
            id: trilho
            anchors.left: ico.right; anchors.leftMargin: 12; anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 22
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.14) }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: Math.max(6, parent.width * Math.max(0, Math.min(1, l.valor))); height: 6; radius: 3; color: central.ambar }
            Rectangle {
                x: (parent.width - width) * Math.max(0, Math.min(1, l.valor))
                anchors.verticalCenter: parent.verticalCenter
                width: 18; height: 18; radius: 9; color: "white"
            }
            MouseArea {
                anchors.fill: parent
                function mover(x) { l.movido(Math.max(0, Math.min(1, x / width))) }
                onPressed: (ev) => mover(ev.x)
                onPositionChanged: (ev) => { if (pressed) mover(ev.x) }
                onWheel: (ev) => l.movido(Math.max(0, Math.min(1, l.valor + (ev.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }
    }
}
