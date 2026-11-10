# Manual do CarinaeOS

O CarinaeOS é um sistema operacional livre, feito sobre o **Debian 13 “trixie”** com o ambiente
**KDE Plasma 6**, com visual inspirado no macOS e uma assistente, a **Eta**, que faz e explica
quase tudo. Este manual cobre o CarinaeOS, o Debian por baixo dele, o kernel Linux e o terminal.

> A Eta conhece este manual inteiro. Em vez de procurar aqui, pode simplesmente perguntar-lhe
> (tecla ⊞+Espaço): “como ligo o HD da rede?”, “que comando mostra o espaço livre?”.

## Capítulos

1. [Primeiros passos](01-primeiros-passos.md) — experimentar, instalar, primeiro arranque, contas
2. [A área de trabalho](02-area-de-trabalho.md) — barra de cima, Dock, Launchpad, janelas, atalhos, estilos
3. [A Eta](03-eta.md) — a assistente: pedidos, voz, arquivos, memória, cérebro, internet
4. [As ferramentas do CarinaeOS](04-ferramentas.md) — Central, Supernova, Órbita, Casa, Calendários, Cadeado, Etiquetas…
5. [Arquivos e discos](05-arquivos-e-discos.md) — Arquivos, pen drives, HD externo, cifrados, partições, cópias
6. [Rede, HD na rede e pastas partilhadas](06-rede.md) — Wi-Fi, NAS, SMB/Windows, NFS, SSH, partilhar pastas
7. [Programas](07-programas.md) — Órbita, apt, Flatpak, .deb, AppImage, programas do Windows
8. [Hardware e drivers](08-hardware.md) — vídeo, impressoras, scanners, som, Bluetooth, monitores
9. [O Debian por baixo](09-debian.md) — versões, repositórios, apt e dpkg, atualizações
10. [O kernel Linux](10-kernel.md) — o que faz, módulos, parâmetros, /proc e /sys, sysctl
11. [O terminal: guia e referência de comandos](11-terminal.md)
12. [Segurança e privacidade](12-seguranca.md)
13. [Resolver problemas](13-problemas.md)

## Convenções

- **⊞** é a tecla Windows (ou ⌘ num teclado de Mac). Nas Configurações chama-se *Meta*.
- Linhas que começam por `$` são comandos para o terminal (não escreva o `$`).
  Os que começam por `sudo` pedem a sua senha: são tarefas de administrador.
- `<algo>` é para substituir pelo seu valor (por exemplo `<usuario>` → `leo`).
- Caminhos com `~` querem dizer “a sua pasta pessoal” (por exemplo `~/Documentos`).
