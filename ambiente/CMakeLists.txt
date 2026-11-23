# CarinaeOS — o ambiente gráfico próprio (carinae-wm + carinae-shell + sessão)
cmake_minimum_required(VERSION 3.16)
project(carinaeos-ambiente VERSION 0.1 LANGUAGES CXX)
include(GNUInstallDirs)

add_subdirectory(wm)
add_subdirectory(shell)
add_subdirectory(bloqueio)
add_subdirectory(senha)
add_subdirectory(terminal)

install(PROGRAMS
    sessao/startcarinae sessao/carinae-sessao sessao/carinae-autostart
    sessao/carinae-experimentar sessao/carinae-voltar sessao/carinae-captura sessao/carinae-preaquecer sessao/carinae-aparencia-gtk sessao/carinae-aparencia-qt sessao/carinae-entrada sessao/carinae-escolher sessao/carinaeos-modo-leve
    DESTINATION ${CMAKE_INSTALL_BINDIR})
# substitutos dos programas do KDE (kdialog, kcmshell6, spectacle...): no fim do PATH da sessão, só valem
# quando o programa verdadeiro não está instalado
install(PROGRAMS compat/kcmshell6 compat/kbuildsycoca6 compat/spectacle compat/plasma-apply-wallpaperimage
        compat/systemsettings compat/dolphin compat/konsole DESTINATION ${CMAKE_INSTALL_LIBDIR}/carinaeos/compat)
install(PROGRAMS ferramentas/portar-do-plasma.py DESTINATION ${CMAKE_INSTALL_BINDIR} RENAME carinae-portar)
install(FILES sessao/atalhos.conf sessao/picom.conf sessao/sessao.conf.exemplo
    DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos)
install(FILES icones/carinaeos-pulsar.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
# Pulsar Player (substitui o Música; usa o motor do Música em /usr/share/carinaeos/musica)
install(FILES apps/pulsar/pulsar.py apps/pulsar/Main.qml DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/pulsar)
install(PROGRAMS apps/pulsar/carinaeos-pulsar DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES apps/pulsar/carinaeos-pulsar.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
# Telas (monitores: posição, resolução, frequência, rotação, principal)
install(FILES apps/telas/telas.py apps/telas/Main.qml DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/telas)
install(PROGRAMS apps/telas/carinae-telas DESTINATION ${CMAKE_INSTALL_BINDIR})
# peças comuns dos apps em Python (janela, ícones)
install(FILES apps/comum/base.py apps/comum/senha.py apps/comum/Senha.qml apps/comum/instalados.py apps/comum/casa_ha.py DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/comum)
# Energia (os ajustes do carinae-energia)
install(FILES apps/energia/energia.py apps/energia/Main.qml DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/energia)
install(PROGRAMS apps/energia/carinae-energia-ajustes DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES apps/energia/carinae-energia-ajustes.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
# Documentos (Carinae Arquivos): o gestor de ficheiros ao estilo do Windows 11
install(FILES apps/arquivos/arquivos.py apps/arquivos/Main.qml apps/arquivos/Ico.qml DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/arquivos)
install(PROGRAMS apps/arquivos/carinaeos-arquivos DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES apps/arquivos/carinaeos-arquivos.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES apps/arquivos/carinaeos-arquivos-religar.desktop DESTINATION /etc/xdg/autostart)
install(FILES apps/telas/carinae-telas.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
# prévias dos modelos novos da Dock (para a página Dock das Configurações)
# Configurações (as páginas de Wi-Fi, Rede, Som e Energia já não usam os módulos do KDE)
install(FILES apps/configuracoes/configuracoes.py apps/configuracoes/Main.qml apps/configuracoes/rede_som.py apps/configuracoes/sistema_pags.py apps/configuracoes/padroes.py apps/configuracoes/outras_pags.py
    DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/configuracoes)
install(PROGRAMS apps/configuracoes/carinaeos-configuracoes DESTINATION ${CMAKE_INSTALL_BINDIR})

# Fotos e Leitor de PDF (no lugar do Gwenview e do Okular)
install(FILES apps/fotos/fotos.py apps/fotos/Main.qml DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/fotos)
install(FILES apps/pdf/pdf.py apps/pdf/Main.qml DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/pdf)
install(PROGRAMS apps/fotos/carinaeos-fotos apps/pdf/carinaeos-pdf DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES apps/fotos/carinaeos-fotos.desktop apps/pdf/carinaeos-pdf.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES icones/carinaeos-fotos.svg icones/carinaeos-pdf.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)

# Carinae Calculadora e Carinae Notas (no lugar do KCalc e do Kate/KWrite)
install(FILES apps/calculadora/calculadora.py apps/calculadora/Main.qml DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/calculadora)
install(FILES apps/notas/notas.py apps/notas/Main.qml DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/notas)
install(PROGRAMS apps/calculadora/carinaeos-calculadora apps/notas/carinaeos-notas DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES apps/calculadora/carinaeos-calculadora.desktop apps/notas/carinaeos-notas.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES icones/carinaeos-calculadora.svg icones/carinaeos-notas.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)

# Carinae Compactador e Carinae Emojis (no lugar do Ark e do seletor de emojis do Plasma)
install(FILES apps/compactador/compactador.py apps/compactador/motor.py apps/compactador/Main.qml DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/compactador)
install(FILES apps/emojis/emojis.py apps/emojis/Main.qml apps/emojis/emojis.json apps/emojis/LICENSE-emojibase DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/emojis)
install(PROGRAMS apps/compactador/carinaeos-compactador apps/emojis/carinaeos-emojis DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES apps/compactador/carinaeos-compactador.desktop apps/emojis/carinaeos-emojis.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES icones/carinaeos-compactador.svg icones/carinaeos-emojis.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)

# Monitor do sistema (processos, desempenho, velocidade da internet, inicialização)
install(FILES apps/monitor/monitor.py apps/monitor/velocidade.py apps/monitor/Main.qml DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/monitor)
install(PROGRAMS apps/monitor/carinaeos-monitor DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES apps/monitor/carinaeos-monitor.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)

# Comando (Ctrl+Espaço) com as extensões
install(FILES apps/comando/comando.py apps/comando/Main.qml apps/comando/acoes.py apps/comando/rapido.py apps/comando/paises.json
    apps/comando/extensoes.py apps/comando/carinae_compat.py DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/comando)
install(DIRECTORY apps/comando/extensoes DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/comando
    PATTERN "__pycache__" EXCLUDE)
install(PROGRAMS apps/comando/carinaeos-comando DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES apps/comando/carinaeos-comando-fundo.desktop DESTINATION /etc/xdg/autostart)
install(FILES marca/dock-estilos/orbita.png marca/dock-estilos/glass.png marca/dock-estilos/windows.png
    marca/dock-estilos/fluent.png marca/dock-estilos/icones.png marca/dock-estilos/simples.png
    DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/configuracoes/dock-estilos)
# Terminal Carinae (o Konsole com nome, ícone, temas e perfil próprios) e a janela de aparência
install(FILES apps/terminal/aparencia.py apps/terminal/Main.qml DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/terminal)
install(PROGRAMS apps/terminal/carinae-terminal-aparencia DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES apps/terminal/carinae-terminal-aparencia.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES icones/carinaeos-terminal.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
# papéis de parede do CarinaeOS (Nebulosa, Aurora, Órbita) para a troca rápida na central de ajustes
install(FILES marca/papeis/nebulosa.jpg marca/papeis/aurora.jpg marca/papeis/orbita.jpg DESTINATION ${CMAKE_INSTALL_DATADIR}/carinaeos/papeis)
# pré-aquecer a sessão no arranque (ligado pelo ferramentas/otimizar-arranque.sh)
install(FILES sessao/carinae-preaquecer.service sessao/carinae-adiar.service sessao/carinae-adiar.timer
    DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/systemd/system)
# fastfetch: o logo da estrela em cores verdadeiras
install(FILES marca/fastfetch-logo.ans DESTINATION /usr/share/carinaeos/marca)
install(FILES marca/fastfetch.jsonc DESTINATION /etc/xdg/fastfetch RENAME config.jsonc)
# os diálogos de abrir/salvar e o tema escuro dos apps GTK/Electron/Flatpak: portal GTK (sem o KDE)
install(FILES sessao/carinaeos-portals.conf DESTINATION /usr/share/xdg-desktop-portal)
# a sessão tem de estar onde o SDDM a procura (fora do prefixo)
install(FILES sessao/carinae.desktop DESTINATION /usr/share/xsessions)
# sessão sem rastro (convidado): o script fica onde o PAM e o polkit o procuram
install(PROGRAMS sessao/carinae-convidado DESTINATION /usr/lib/carinaeos RENAME convidado)
install(PROGRAMS sessao/carinae-remover-pacote DESTINATION /usr/lib/carinaeos RENAME remover-pacote)
install(FILES sessao/org.carinaeos.convidado.policy DESTINATION /usr/share/polkit-1/actions)
install(FILES sessao/convidado-leia-me.txt DESTINATION /usr/share/carinaeos)
