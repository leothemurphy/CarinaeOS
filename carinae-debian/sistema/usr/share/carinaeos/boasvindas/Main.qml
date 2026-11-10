// CarinaeOS - Boas-vindas
import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: janela
    width: 960; height: 640
    minimumWidth: 820; minimumHeight: 580
    visible: true
    title: "Bem-vindo ao CarinaeOS"
    color: "#0d0a13"
    font.family: "Inter"; font.pixelSize: 14
    onClosing: bv.concluir()

    readonly property color ambar: "#ffb46e"
    readonly property color rosa: "#ff6f91"
    readonly property color texto: "#f4eee8"
    readonly property color textoSuave: "#b9aec4"
    property int pagina: 0

    readonly property var paginas: [
        { titulo: "Bem-vindo ao CarinaeOS", icone: "carinaeos", grande: true,
          texto: "Um sistema bonito, simples e só seu. Em poucos passos mostramos tudo o que tem à mão. Pode rever isto quando quiser no Launchpad › “Bem-vindo”.",
          itens: [] },
        { titulo: "Eta, a sua assistente", icone: "carinaeos-eta",
          texto: "Converse por escrito ou por voz. A IA corre no seu computador, sem enviar nada para fora, e aprende com o que lê e com o que instala.",
          itens: [ "Meta+Espaço abre a Eta; Meta+Shift+Espaço fala com ela",
                   "“Encontre o meu currículo”, “abre o HD externo”, “instala o GIMP”",
                   "Arraste um PDF para ela: resume, responde e guarda o que aprendeu",
                   "“Como uso o LibreOffice?”: passo a passo de qualquer aplicativo instalado",
                   "Pergunta antes de instalar e mostra os comandos, se preferir fazer você" ],
          botao: "Abrir a Eta", cmd: "carinaeos-eta" },
        { titulo: "Dock, Launchpad e Busca", icone: "carinaeos-estrela",
          texto: "Como no Mac: a Dock em baixo, sempre à vista, e a barra em cima com o menu do aplicativo aberto.",
          itens: [ "Clique na estrela (ou na tecla ⊞/⌘) para ver todos os aplicativos",
                   "Ctrl+Espaço: a busca rápida — aplicativos, arquivos, contas e “Perguntar à Eta”",
                   "Arraste aplicativos ou pastas para a Dock; ao lado da lixeira estão os Downloads",
                   "Clicar no papel de parede afasta as janelas; Alt+Tab em Flip 3D" ],
          botao: "Abrir o Launchpad", cmd: "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.activateLauncherMenu" },
        { titulo: "Supernova", icone: "carinaeos-supernova",
          texto: "Personalize tudo, com modelos inspirados no Windhawk: 13 estilos de Dock, animações, Alt+Tab, botões das janelas, cursor, luz noturna, papel de parede vivo e perfis prontos (Mac, Vista, XP…).",
          itens: [], botao: "Abrir o Supernova", cmd: "carinaeos-supernova" },
        { titulo: "Órbita, a loja", icone: "carinaeos-orbita",
          texto: "Chrome, LibreOffice, Spotify, Discord, Steam, VS Code e muito mais, com um clique e sem senha.",
          itens: [], botao: "Abrir a Órbita", cmd: "carinaeos-orbita" },
        { titulo: "Casa, Calendário e Mapas", icone: "carinaeos-casa",
          texto: "Ligue o seu Home Assistant e controle luzes e cenas (também pela Eta: “acende a luz da sala”). O Calendário liga à conta Google e os eventos aparecem ao clicar no relógio. E os Mapas mostram o mundo inteiro.",
          itens: [], botao: "Abrir a Casa", cmd: "carinaeos-casa" },
        { titulo: "Segurança e privacidade", icone: "object-locked",
          texto: "Bloqueie pastas, arquivos e aplicativos com senha: botão direito › “Bloquear com senha”. O que está bloqueado aparece com um cadeado.",
          itens: [], botao: "", cmd: "" },
        { titulo: "Ao seu gosto", icone: "preferences-desktop-wallpaper",
          texto: "Mais de 14 papéis de parede em 8K (fotos do James Webb e do Hubble e desenhos do CarinaeOS). E pode usar o CarinaeOS com KDE Plasma, GNOME ou XFCE — sempre com a mesma Dock e os mesmos fundos.",
          itens: [], botao: "Trocar de ambiente", cmd: "carinaeos-ambientes" },
        { titulo: "Tudo pronto ✦", icone: "carinaeos", grande: true,
          texto: "Bom proveito! Se tiver alguma dúvida, é só perguntar à Eta.",
          itens: [], botao: "Perguntar à Eta", cmd: "carinaeos-eta" }
    ]
    readonly property var p: paginas[pagina]

    Rectangle {
        anchors.fill: parent
        gradient: Gradient { GradientStop { position: 0; color: "#1b1230" } GradientStop { position: 1; color: "#0a0810" } }
    }
    Image {   // o ceu de Eta Carinae, muito suave, por tras
        anchors.fill: parent; fillMode: Image.PreserveAspectCrop; opacity: 0.18
        source: "file:///usr/share/wallpapers/CarinaeOS/contents/images/1920x1080.jpg"
    }

    Item {
        id: palco
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: rodape.top
        Column {
            id: col
            anchors.centerIn: parent
            width: Math.min(680, parent.width - 80)
            spacing: 18
            opacity: 1
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                source: "image://icone/" + janela.p.icone
                width: janela.p.grande ? 120 : 84; height: width; sourceSize: Qt.size(240, 240)
            }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: janela.p.titulo; color: janela.texto; font.pixelSize: 32; font.weight: Font.Bold; wrapMode: Text.WordWrap }
            Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: janela.p.texto; color: janela.textoSuave; font.pixelSize: 15; wrapMode: Text.WordWrap; lineHeight: 1.2 }
            Column {
                width: parent.width; spacing: 8
                Repeater {
                    model: janela.p.itens
                    delegate: Row {
                        required property string modelData
                        width: parent.width; spacing: 10
                        Text { text: "✦"; color: janela.ambar; font.pixelSize: 14 }
                        Text { width: parent.width - 30; text: modelData; color: janela.texto; font.pixelSize: 14; wrapMode: Text.WordWrap }
                    }
                }
            }
            Rectangle {
                visible: (janela.p.botao || "") !== ""
                anchors.horizontalCenter: parent.horizontalCenter
                width: bt.implicitWidth + 40; height: 40; radius: 20
                color: Qt.rgba(1, 1, 1, 0.08); border.color: Qt.rgba(1, 0.7, 0.43, 0.5)
                Text { id: bt; anchors.centerIn: parent; text: janela.p.botao || ""; color: janela.texto; font.weight: Font.DemiBold }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: bv.abrir(janela.p.cmd) }
            }
        }
    }

    Item {
        id: rodape
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: 80
        Row {
            anchors.centerIn: parent; spacing: 8
            Repeater {
                model: janela.paginas.length
                delegate: Rectangle {
                    required property int index
                    width: index === janela.pagina ? 22 : 8; height: 8; radius: 4
                    color: index === janela.pagina ? janela.ambar : Qt.rgba(1, 1, 1, 0.25)
                    Behavior on width { NumberAnimation { duration: 200 } }
                    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: janela.pagina = index }
                }
            }
        }
        Text {
            anchors.left: parent.left; anchors.leftMargin: 32; anchors.verticalCenter: parent.verticalCenter
            visible: janela.pagina > 0
            text: "← Voltar"; color: janela.textoSuave
            MouseArea { anchors.fill: parent; anchors.margins: -8; cursorShape: Qt.PointingHandCursor; onClicked: janela.pagina-- }
        }
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 32; anchors.verticalCenter: parent.verticalCenter
            width: seg.implicitWidth + 40; height: 42; radius: 21
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: janela.rosa } GradientStop { position: 1; color: janela.ambar } }
            Text { id: seg; anchors.centerIn: parent; text: janela.pagina === janela.paginas.length - 1 ? "Começar" : "Seguinte →"; color: "#1a0f14"; font.weight: Font.Bold }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { if (janela.pagina < janela.paginas.length - 1) janela.pagina++; else { bv.concluir(); Qt.quit() } }
            }
        }
    }
    Shortcut { sequences: ["Right"]; onActivated: if (janela.pagina < janela.paginas.length - 1) janela.pagina++ }
    Shortcut { sequences: ["Left"]; onActivated: if (janela.pagina > 0) janela.pagina-- }
}
