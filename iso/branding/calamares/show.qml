/* AtriumOS — apresentação durante a instalação (a vitrine do sistema) */
import QtQuick 2.5
import calamares.slideshow 1.0

Presentation {
    id: presentation
    function nextSlide() { presentation.goToNextSlide(); }
    Timer { interval: 9000; running: presentation.activatedInCalamares; repeat: true; onTriggered: nextSlide() }

    Slide {
        id: s0
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#1a1240" } GradientStop { position: 1; color: "#0b0a1a" } } }
        Item {
            id: q0; clip: true
            x: parent.width*0.44; y: parent.height*0.12; width: parent.width*0.53; height: width*0.625
            Rectangle { anchors.fill: parent; radius: 10; color: "#000" }
            Image { id: im0; source: "tela-entrada.jpg"; anchors.centerIn: parent; width: parent.width; height: parent.height; fillMode: Image.PreserveAspectCrop; smooth: true
                SequentialAnimation on scale { running: s0.visible; loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.12; duration: 9000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.12; to: 1.0; duration: 9000; easing.type: Easing.InOutQuad } } }
        }
        Column {
            id: c0; x: parent.width*0.04; y: parent.height*0.14; spacing: 12; width: parent.width*0.38
            opacity: 0
            NumberAnimation on opacity { running: s0.visible; from: 0; to: 1; duration: 900 }
            Text { text: "1 / 9"; color: "#a78bfa"; font.pixelSize: 12 }
            Text { text: "Bem-vindo ao AtriumOS"; color: "#ffffff"; font.pixelSize: 24; font.bold: true; wrapMode: Text.WordWrap; width: parent.width }
            Text { text: "Bonito, leve e seu. Uma área de trabalho elegante sobre o Debian 13, estável e seguro."; color: "#d4ccff"; font.pixelSize: 14; wrapMode: Text.WordWrap; width: parent.width }
            Item { width: 1; height: 4 }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Feito para quem quer um computador que simplesmente funciona"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s0.width*0.38 }
                }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Sem anúncios, sem conta obrigatória, sem telemetria"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s0.width*0.38 }
                }
        }
        Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter; color: "#6b6390"; font.pixelSize: 11
               text: "AtriumOS 0.1 “Pátio” · baseado no Debian 13 · criado com Claude (Anthropic)" }
    }
    Slide {
        id: s1
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#1a1240" } GradientStop { position: 1; color: "#0b0a1a" } } }
        Item {
            id: q1; clip: true
            x: parent.width*0.44; y: parent.height*0.12; width: parent.width*0.53; height: width*0.625
            Rectangle { anchors.fill: parent; radius: 10; color: "#000" }
            Image { id: im1; source: "tela-mesa.jpg"; anchors.centerIn: parent; width: parent.width; height: parent.height; fillMode: Image.PreserveAspectCrop; smooth: true
                SequentialAnimation on scale { running: s1.visible; loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.12; duration: 9000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.12; to: 1.0; duration: 9000; easing.type: Easing.InOutQuad } } }
        }
        Column {
            id: c1; x: parent.width*0.04; y: parent.height*0.14; spacing: 12; width: parent.width*0.38
            opacity: 0
            NumberAnimation on opacity { running: s1.visible; from: 0; to: 1; duration: 900 }
            Text { text: "2 / 9"; color: "#a78bfa"; font.pixelSize: 12 }
            Text { text: "Uma mesa que você já sabe usar"; color: "#ffffff"; font.pixelSize: 24; font.bold: true; wrapMode: Text.WordWrap; width: parent.width }
            Text { text: "Dock, barra de menus, Launchpad e Busca: tudo no lugar onde você espera."; color: "#d4ccff"; font.pixelSize: 14; wrapMode: Text.WordWrap; width: parent.width }
            Item { width: 1; height: 4 }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Busca em tudo com Ctrl + Espaço"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s1.width*0.38 }
                }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Launchpad com F4 e Mission Control com F3"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s1.width*0.38 }
                }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Encaixe janelas arrastando até as bordas"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s1.width*0.38 }
                }
        }
        Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter; color: "#6b6390"; font.pixelSize: 11
               text: "AtriumOS 0.1 “Pátio” · baseado no Debian 13 · criado com Claude (Anthropic)" }
    }
    Slide {
        id: s2
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#1a1240" } GradientStop { position: 1; color: "#0b0a1a" } } }
        Item {
            id: q2; clip: true
            x: parent.width*0.44; y: parent.height*0.12; width: parent.width*0.53; height: width*0.625
            Rectangle { anchors.fill: parent; radius: 10; color: "#000" }
            Image { id: im2; source: "tela-launchpad.jpg"; anchors.centerIn: parent; width: parent.width; height: parent.height; fillMode: Image.PreserveAspectCrop; smooth: true
                SequentialAnimation on scale { running: s2.visible; loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.12; duration: 9000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.12; to: 1.0; duration: 9000; easing.type: Easing.InOutQuad } } }
        }
        Column {
            id: c2; x: parent.width*0.04; y: parent.height*0.14; spacing: 12; width: parent.width*0.38
            opacity: 0
            NumberAnimation on opacity { running: s2.visible; from: 0; to: 1; duration: 900 }
            Text { text: "3 / 9"; color: "#a78bfa"; font.pixelSize: 12 }
            Text { text: "Milhares de apps numa loja só"; color: "#ffffff"; font.pixelSize: 24; font.bold: true; wrapMode: Text.WordWrap; width: parent.width }
            Text { text: "A Loja traz os apps do Flathub: Spotify, Discord, OBS, GIMP, Steam e muito mais."; color: "#d4ccff"; font.pixelSize: 14; wrapMode: Text.WordWrap; width: parent.width }
            Item { width: 1; height: 4 }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Apps Android com a loja Aurora"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s2.width*0.38 }
                }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Programas do Windows (.exe) com dois cliques"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s2.width*0.38 }
                }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Google Chrome oficial em um clique"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s2.width*0.38 }
                }
        }
        Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter; color: "#6b6390"; font.pixelSize: 11
               text: "AtriumOS 0.1 “Pátio” · baseado no Debian 13 · criado com Claude (Anthropic)" }
    }
    Slide {
        id: s3
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#1a1240" } GradientStop { position: 1; color: "#0b0a1a" } } }
        Item {
            id: q3; clip: true
            x: parent.width*0.44; y: parent.height*0.12; width: parent.width*0.53; height: width*0.625
            Rectangle { anchors.fill: parent; radius: 10; color: "#000" }
            Image { id: im3; source: "tela-arquivos.jpg"; anchors.centerIn: parent; width: parent.width; height: parent.height; fillMode: Image.PreserveAspectCrop; smooth: true
                SequentialAnimation on scale { running: s3.visible; loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.12; duration: 9000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.12; to: 1.0; duration: 9000; easing.type: Easing.InOutQuad } } }
        }
        Column {
            id: c3; x: parent.width*0.04; y: parent.height*0.14; spacing: 12; width: parent.width*0.38
            opacity: 0
            NumberAnimation on opacity { running: s3.visible; from: 0; to: 1; duration: 900 }
            Text { text: "4 / 9"; color: "#a78bfa"; font.pixelSize: 12 }
            Text { text: "Escritório completo, em português"; color: "#ffffff"; font.pixelSize: 24; font.bold: true; wrapMode: Text.WordWrap; width: parent.width }
            Text { text: "LibreOffice Writer, Calc e Impress já instalados."; color: "#d4ccff"; font.pixelSize: 14; wrapMode: Text.WordWrap; width: parent.width }
            Item { width: 1; height: 4 }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Abre e salva .docx, .xlsx e .pptx"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s3.width*0.38 }
                }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Fontes compatíveis com documentos do Office"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s3.width*0.38 }
                }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Corretor ortográfico pt-PT e pt-BR"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s3.width*0.38 }
                }
        }
        Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter; color: "#6b6390"; font.pixelSize: 11
               text: "AtriumOS 0.1 “Pátio” · baseado no Debian 13 · criado com Claude (Anthropic)" }
    }
    Slide {
        id: s4
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#1a1240" } GradientStop { position: 1; color: "#0b0a1a" } } }
        Item {
            id: q4; clip: true
            x: parent.width*0.44; y: parent.height*0.12; width: parent.width*0.53; height: width*0.625
            Rectangle { anchors.fill: parent; radius: 10; color: "#000" }
            Image { id: im4; source: "tela-busca.jpg"; anchors.centerIn: parent; width: parent.width; height: parent.height; fillMode: Image.PreserveAspectCrop; smooth: true
                SequentialAnimation on scale { running: s4.visible; loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.12; duration: 9000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.12; to: 1.0; duration: 9000; easing.type: Easing.InOutQuad } } }
        }
        Column {
            id: c4; x: parent.width*0.04; y: parent.height*0.14; spacing: 12; width: parent.width*0.38
            opacity: 0
            NumberAnimation on opacity { running: s4.visible; from: 0; to: 1; duration: 900 }
            Text { text: "5 / 9"; color: "#a78bfa"; font.pixelSize: 12 }
            Text { text: "Sua rede, de verdade"; color: "#ffffff"; font.pixelSize: 24; font.bold: true; wrapMode: Text.WordWrap; width: parent.width }
            Text { text: "Pastas do NAS, do PC com Windows ou do Mac aparecem sozinhas."; color: "#d4ccff"; font.pixelSize: 14; wrapMode: Text.WordWrap; width: parent.width }
            Item { width: 1; height: 4 }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Conecte a smb://, sftp:// e WebDAV"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s4.width*0.38 }
                }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Compartilhe a sua pasta Público com a casa"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s4.width*0.38 }
                }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Impressoras da rede configuradas automaticamente"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s4.width*0.38 }
                }
        }
        Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter; color: "#6b6390"; font.pixelSize: 11
               text: "AtriumOS 0.1 “Pátio” · baseado no Debian 13 · criado com Claude (Anthropic)" }
    }
    Slide {
        id: s5
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#1a1240" } GradientStop { position: 1; color: "#0b0a1a" } } }
        Item {
            id: q5; clip: true
            x: parent.width*0.44; y: parent.height*0.12; width: parent.width*0.53; height: width*0.625
            Rectangle { anchors.fill: parent; radius: 10; color: "#000" }
            Image { id: im5; source: "tela-remoto.jpg"; anchors.centerIn: parent; width: parent.width; height: parent.height; fillMode: Image.PreserveAspectCrop; smooth: true
                SequentialAnimation on scale { running: s5.visible; loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.12; duration: 9000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.12; to: 1.0; duration: 9000; easing.type: Easing.InOutQuad } } }
        }
        Column {
            id: c5; x: parent.width*0.04; y: parent.height*0.14; spacing: 12; width: parent.width*0.38
            opacity: 0
            NumberAnimation on opacity { running: s5.visible; from: 0; to: 1; duration: 900 }
            Text { text: "6 / 9"; color: "#a78bfa"; font.pixelSize: 12 }
            Text { text: "Seu computador, de onde você estiver em casa"; color: "#ffffff"; font.pixelSize: 24; font.bold: true; wrapMode: Text.WordWrap; width: parent.width }
            Text { text: "Acesso Remoto pronto: controle pelo Mac, por outro PC ou pelo celular."; color: "#d4ccff"; font.pixelSize: 14; wrapMode: Text.WordWrap; width: parent.width }
            Item { width: 1; height: 4 }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Protegido por senha e criptografia"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s5.width*0.38 }
                }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Veja e desconecte quem está conectado"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s5.width*0.38 }
                }
        }
        Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter; color: "#6b6390"; font.pixelSize: 11
               text: "AtriumOS 0.1 “Pátio” · baseado no Debian 13 · criado com Claude (Anthropic)" }
    }
    Slide {
        id: s6
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#1a1240" } GradientStop { position: 1; color: "#0b0a1a" } } }
        Item {
            id: q6; clip: true
            x: parent.width*0.44; y: parent.height*0.12; width: parent.width*0.53; height: width*0.625
            Rectangle { anchors.fill: parent; radius: 10; color: "#000" }
            Image { id: im6; source: "tela-ajustes.jpg"; anchors.centerIn: parent; width: parent.width; height: parent.height; fillMode: Image.PreserveAspectCrop; smooth: true
                SequentialAnimation on scale { running: s6.visible; loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.12; duration: 9000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.12; to: 1.0; duration: 9000; easing.type: Easing.InOutQuad } } }
        }
        Column {
            id: c6; x: parent.width*0.04; y: parent.height*0.14; spacing: 12; width: parent.width*0.38
            opacity: 0
            NumberAnimation on opacity { running: s6.visible; from: 0; to: 1; duration: 900 }
            Text { text: "7 / 9"; color: "#a78bfa"; font.pixelSize: 12 }
            Text { text: "Do seu jeito"; color: "#ffffff"; font.pixelSize: 24; font.bold: true; wrapMode: Text.WordWrap; width: parent.width }
            Text { text: "Temas claro e escuro, papéis de parede, cores e estilos de área de trabalho."; color: "#d4ccff"; font.pixelSize: 14; wrapMode: Text.WordWrap; width: parent.width }
            Item { width: 1; height: 4 }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Modo leve para computadores mais simples"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s6.width*0.38 }
                }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Teclado, idioma e região em português de verdade"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s6.width*0.38 }
                }
        }
        Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter; color: "#6b6390"; font.pixelSize: 11
               text: "AtriumOS 0.1 “Pátio” · baseado no Debian 13 · criado com Claude (Anthropic)" }
    }
    Slide {
        id: s7
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#1a1240" } GradientStop { position: 1; color: "#0b0a1a" } } }
        Item {
            id: q7; clip: true
            x: parent.width*0.44; y: parent.height*0.12; width: parent.width*0.53; height: width*0.625
            Rectangle { anchors.fill: parent; radius: 10; color: "#000" }
            Image { id: im7; source: "tela-mc.jpg"; anchors.centerIn: parent; width: parent.width; height: parent.height; fillMode: Image.PreserveAspectCrop; smooth: true
                SequentialAnimation on scale { running: s7.visible; loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.12; duration: 9000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.12; to: 1.0; duration: 9000; easing.type: Easing.InOutQuad } } }
        }
        Column {
            id: c7; x: parent.width*0.04; y: parent.height*0.14; spacing: 12; width: parent.width*0.38
            opacity: 0
            NumberAnimation on opacity { running: s7.visible; from: 0; to: 1; duration: 900 }
            Text { text: "8 / 9"; color: "#a78bfa"; font.pixelSize: 12 }
            Text { text: "Seus dados protegidos"; color: "#ffffff"; font.pixelSize: 24; font.bold: true; wrapMode: Text.WordWrap; width: parent.width }
            Text { text: "Pasta Segura criptografada, cópia de segurança em pendrive e pontos de restauração."; color: "#d4ccff"; font.pixelSize: 14; wrapMode: Text.WordWrap; width: parent.width }
            Item { width: 1; height: 4 }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Antes de cada atualização, um ponto para voltar atrás"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s7.width*0.38 }
                }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Casa inteligente: Home Assistant com atalhos de teclado"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s7.width*0.38 }
                }
        }
        Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter; color: "#6b6390"; font.pixelSize: 11
               text: "AtriumOS 0.1 “Pátio” · baseado no Debian 13 · criado com Claude (Anthropic)" }
    }
    Slide {
        id: s8
        Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#1a1240" } GradientStop { position: 1; color: "#0b0a1a" } } }
        Item {
            id: q8; clip: true
            x: parent.width*0.44; y: parent.height*0.12; width: parent.width*0.53; height: width*0.625
            Rectangle { anchors.fill: parent; radius: 10; color: "#000" }
            Image { id: im8; source: "tela-monitor.jpg"; anchors.centerIn: parent; width: parent.width; height: parent.height; fillMode: Image.PreserveAspectCrop; smooth: true
                SequentialAnimation on scale { running: s8.visible; loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 1.12; duration: 9000; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 1.12; to: 1.0; duration: 9000; easing.type: Easing.InOutQuad } } }
        }
        Column {
            id: c8; x: parent.width*0.04; y: parent.height*0.14; spacing: 12; width: parent.width*0.38
            opacity: 0
            NumberAnimation on opacity { running: s8.visible; from: 0; to: 1; duration: 900 }
            Text { text: "9 / 9"; color: "#a78bfa"; font.pixelSize: 12 }
            Text { text: "Pronto para o seu hardware"; color: "#ffffff"; font.pixelSize: 24; font.bold: true; wrapMode: Text.WordWrap; width: parent.width }
            Text { text: "Wi‑Fi, Bluetooth, vídeo e som funcionam desde o primeiro minuto."; color: "#d4ccff"; font.pixelSize: 14; wrapMode: Text.WordWrap; width: parent.width }
            Item { width: 1; height: 4 }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Ajustes › Drivers encontra o que falta e instala"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s8.width*0.38 }
                }
                Row { spacing: 8
                    Rectangle { width: 7; height: 7; radius: 4; color: "#c084fc"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Placas NVIDIA com o driver oficial em um clique"; color: "#e9e5ff"; font.pixelSize: 13; wrapMode: Text.WordWrap; width: s8.width*0.38 }
                }
        }
        Text { anchors.bottom: parent.bottom; anchors.bottomMargin: 10; anchors.horizontalCenter: parent.horizontalCenter; color: "#6b6390"; font.pixelSize: 11
               text: "AtriumOS 0.1 “Pátio” · baseado no Debian 13 · criado com Claude (Anthropic)" }
    }
    function onActivate() { }
    function onLeave() { }
}
