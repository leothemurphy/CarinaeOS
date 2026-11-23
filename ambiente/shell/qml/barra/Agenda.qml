// CarinaeOS — Agenda: os eventos do calendário da barra de cima e os lembretes deles.
// Os eventos ficam em ~/.config/carinaeos/agenda.json. Na hora marcada (ou X minutos antes) sobe um
// aviso no canto da tela que NÃO desaparece sozinho: só sai quando se confirma que foi lido.
// Se o computador estava desligado na hora, o aviso aparece ao entrar (até 7 dias depois).
pragma Singleton
import QtQuick
import QtQuick.Window
import CarinaeOS.Base
import CarinaeOS.Compat as C

QtObject {
    id: agenda

    readonly property string arquivo: Sistema.casa + "/.config/carinaeos/agenda.json"
    property var eventos: []         // { id, titulo, data "AAAA-MM-DD", hora "HH:MM" ou "", aviso (min antes), repetir, nota }
    property var lidos: ({})         // "id|AAAA-MM-DD" -> data em que foi lido
    property var adiados: ({})       // "id|AAAA-MM-DD" -> ms até quando está adiado
    property var pendentes: []       // os avisos no ecrã
    property int versao: 0           // muda sempre que os eventos mudam (para o calendário se redesenhar)

    readonly property var avisos: [[0, "Na hora"], [5, "5 min antes"], [15, "15 min antes"], [60, "1 hora antes"], [1440, "1 dia antes"]]
    readonly property var repeticoes: [["", "Não repete"], ["diario", "Todos os dias"], ["semanal", "Toda semana"], ["mensal", "Todo mês"], ["anual", "Todo ano"]]

    // ---- datas ---------------------------------------------------------------------------------
    function chaveDia(d) {
        return d.getFullYear() + "-" + String(d.getMonth() + 1).padStart(2, "0") + "-" + String(d.getDate()).padStart(2, "0");
    }
    function lerDia(s) {
        const p = String(s).split("-");
        return new Date(+p[0], +p[1] - 1, +p[2]);
    }
    function ocorreEm(ev, dia) {
        const base = lerDia(ev.data);
        const d = new Date(dia.getFullYear(), dia.getMonth(), dia.getDate());
        if (d < base) return false;
        switch (ev.repetir) {
        case "diario": return true;
        case "semanal": return d.getDay() === base.getDay();
        case "mensal": return d.getDate() === base.getDate();
        case "anual": return d.getDate() === base.getDate() && d.getMonth() === base.getMonth();
        default: return d.getTime() === base.getTime();
        }
    }
    function momento(ev, dia) {          // a hora do evento nesse dia (sem hora = 9:00)
        const h = (ev.hora || "09:00").split(":");
        return new Date(dia.getFullYear(), dia.getMonth(), dia.getDate(), +h[0] || 0, +h[1] || 0);
    }
    function eventosDoDia(dia) {
        void versao;
        return eventos.filter(function (e) { return ocorreEm(e, dia) })
                      .sort(function (a, b) { return (a.hora || "99").localeCompare(b.hora || "99") });
    }
    function temEvento(dia) {
        void versao;
        for (let i = 0; i < eventos.length; i++) if (ocorreEm(eventos[i], dia)) return true;
        return false;
    }
    function quando(ev, dia) {
        const agora = new Date();
        const hoje = new Date(agora.getFullYear(), agora.getMonth(), agora.getDate());
        const dif = Math.round((new Date(dia.getFullYear(), dia.getMonth(), dia.getDate()) - hoje) / 86400000);
        const dTxt = dif === 0 ? "Hoje" : dif === 1 ? "Amanhã" : dif === -1 ? "Ontem"
                   : Qt.locale().toString(dia, "dddd, d 'de' MMMM");
        return dTxt.charAt(0).toUpperCase() + dTxt.slice(1) + (ev.hora ? " às " + ev.hora : " (dia todo)");
    }

    // ---- guardar ----------------------------------------------------------------------------------
    function carregar() {
        try {
            const j = JSON.parse(Sistema.lerTexto(arquivo) || "{}");
            eventos = j.eventos || [];
            lidos = j.lidos || {};
            adiados = j.adiados || {};
        } catch (e) {
            console.warn("agenda.json inválido:", e);
        }
        versao++;
    }
    function gravar() {
        // esquece o que foi lido há mais de 90 dias
        const limite = Date.now() - 90 * 86400000;
        const l = {};
        for (const k in lidos) if (lidos[k] > limite) l[k] = lidos[k];
        lidos = l;
        Sistema.gravarTexto(arquivo, JSON.stringify({ eventos: eventos, lidos: lidos, adiados: adiados }, null, 1));
        versao++;
    }
    function guardarEvento(ev) {
        const l = eventos.slice();
        if (!ev.id) ev.id = Date.now().toString(36) + Math.floor(Math.random() * 1000).toString(36);
        const i = l.findIndex(function (e) { return e.id === ev.id });
        if (i === -1) l.push(ev); else l[i] = ev;
        eventos = l;
        gravar();
        verificar();
    }
    function apagarEvento(id) {
        eventos = eventos.filter(function (e) { return e.id !== id });
        pendentes = pendentes.filter(function (p) { return p.id !== id });
        gravar();
    }

    // ---- lembretes --------------------------------------------------------------------------------
    function verificar() {
        const agora = new Date();
        const novos = pendentes.slice();
        let tocar = false;
        for (const ev of eventos) {
            // de 7 dias atrás (avisos perdidos com o PC desligado) até amanhã (avisos "1 dia antes")
            for (let n = -7; n <= 1; n++) {
                const dia = new Date(agora.getFullYear(), agora.getMonth(), agora.getDate() + n);
                if (!ocorreEm(ev, dia)) continue;
                const chave = ev.id + "|" + chaveDia(dia);
                if (lidos[chave]) continue;
                if ((adiados[chave] || 0) > agora.getTime()) continue;
                const disparo = new Date(momento(ev, dia).getTime() - (ev.aviso || 0) * 60000);
                if (disparo > agora) continue;
                if (novos.some(function (p) { return p.chave === chave })) continue;
                novos.push({ chave: chave, id: ev.id, titulo: ev.titulo, nota: ev.nota || "", quando: quando(ev, dia) });
                tocar = true;
            }
        }
        if (novos.length !== pendentes.length) pendentes = novos;
        if (tocar) {
            // som (a não ser em "não incomodar": aí o aviso aparece, mas calado)
            Sistema.executar("test -e \"$HOME/.config/carinaeos/nao-incomodar\" || "
                             + "paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || "
                             + "canberra-gtk-play -i message-new-instant 2>/dev/null");
        }
    }
    function marcarLido(chave) {
        const l = Object.assign({}, lidos);
        l[chave] = Date.now();
        lidos = l;
        pendentes = pendentes.filter(function (p) { return p.chave !== chave });
        gravar();
    }
    function adiar(chave, minutos) {
        const a = Object.assign({}, adiados);
        a[chave] = Date.now() + minutos * 60000;
        adiados = a;
        pendentes = pendentes.filter(function (p) { return p.chave !== chave });
        gravar();
    }

    property Timer relogio: Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: agenda.verificar()
    }
    property Timer arranque: Timer {
        interval: 4000
        running: true
        onTriggered: agenda.verificar()
    }
    Component.onCompleted: carregar()

    // ---- a janela dos avisos (canto de cima à direita do ecrã principal) -------------------------
    property Window janela: Window {
        readonly property var ecra: Qt.application.screens[Sistema.indicePrincipal]
        screen: ecra
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
        color: "transparent"
        title: "CarinaeOS Lembretes"
        visible: agenda.pendentes.length > 0
        width: 380
        height: Math.max(1, lista.implicitHeight)
        x: ecra ? ecra.virtualX + ecra.width - width - 14 : 0
        y: ecra ? ecra.virtualY + 40 : 40

        Column {
            id: lista
            width: parent.width
            spacing: 10
            Repeater {
                model: agenda.pendentes
                delegate: Rectangle {
                    id: cartao
                    required property var modelData
                    property bool confirmar: false
                    width: lista.width
                    height: corpo.implicitHeight + 28
                    radius: 16
                    color: Qt.rgba(0.10, 0.09, 0.14, 0.97)
                    border.width: 1.5
                    border.color: Qt.rgba(1, 0.71, 0.43, brilho.valor)
                    // a borda respira devagar: é um lembrete que está à espera
                    QtObject { id: brilho; property real valor: 0.5 }
                    SequentialAnimation {
                        running: true; loops: Animation.Infinite
                        NumberAnimation { target: brilho; property: "valor"; to: 0.95; duration: 1100; easing.type: Easing.InOutSine }
                        NumberAnimation { target: brilho; property: "valor"; to: 0.35; duration: 1100; easing.type: Easing.InOutSine }
                    }

                    Column {
                        id: corpo
                        x: 16; y: 14
                        width: parent.width - 32
                        spacing: 8
                        Row {
                            spacing: 8
                            width: parent.width
                            C.Icon { source: "view-calendar-day"; width: 18; height: 18; isMask: true; color: "#ffb46e" }
                            Text { text: "LEMBRETE"; color: "#ffb46e"; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.2
                                   anchors.verticalCenter: parent.verticalCenter }
                        }
                        Text { width: parent.width; text: cartao.modelData.titulo; color: "#f6f2ff"; font.pixelSize: 16; font.weight: Font.DemiBold; wrapMode: Text.Wrap }
                        Text { width: parent.width; text: cartao.modelData.quando; color: "#b9b0cc"; font.pixelSize: 13 }
                        Text { width: parent.width; visible: text !== ""; text: cartao.modelData.nota; color: "#e3dcf0"; font.pixelSize: 13; wrapMode: Text.Wrap }

                        // os botões normais…
                        Row {
                            visible: !cartao.confirmar
                            spacing: 8
                            anchors.right: parent.right
                            Botao { texto: "Lembrar daqui a 10 min"; onClicado: agenda.adiar(cartao.modelData.chave, 10) }
                            Botao { texto: "Marcar como lido"; destaque: true; onClicado: cartao.confirmar = true }
                        }
                        // …e a confirmação: só sai depois de dizer que leu
                        Rectangle {
                            visible: cartao.confirmar
                            width: parent.width; height: 44; radius: 12
                            color: Qt.rgba(1, 0.71, 0.43, 0.12)
                            Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "Já leu este lembrete?"; color: "#f6f2ff"; font.pixelSize: 13 }
                            Row {
                                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Botao { texto: "Ainda não"; onClicado: cartao.confirmar = false }
                                Botao { texto: "Sim, li"; destaque: true; onClicado: agenda.marcarLido(cartao.modelData.chave) }
                            }
                        }
                    }
                    // o X também pede a confirmação
                    Rectangle {
                        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10
                        width: 24; height: 24; radius: 12
                        color: Qt.rgba(1, 1, 1, xRato.containsMouse ? 0.16 : 0.06)
                        Text { anchors.centerIn: parent; text: "✕"; color: "#f6f2ff"; font.pixelSize: 11 }
                        MouseArea { id: xRato; anchors.fill: parent; hoverEnabled: true; onClicked: cartao.confirmar = true }
                    }
                }
            }
        }
    }

    component Botao: Rectangle {
        id: b
        property string texto
        property bool destaque: false
        signal clicado()
        width: t.implicitWidth + 24; height: 30; radius: 15
        color: destaque ? (bRato.containsMouse ? "#ffc58c" : "#ffb46e") : Qt.rgba(1, 1, 1, bRato.containsMouse ? 0.14 : 0.08)
        Text { id: t; anchors.centerIn: parent; text: b.texto; color: b.destaque ? "#1b1030" : "#f6f2ff"; font.pixelSize: 12; font.weight: Font.DemiBold }
        MouseArea { id: bRato; anchors.fill: parent; hoverEnabled: true; onClicked: b.clicado() }
    }
}
