## Gravidade + Aurora — o ambiente do CarinaeOS para a sua distribuição

O ambiente gráfico do CarinaeOS, escrito de raiz: a **Gravidade** (gestor de janelas, C++/XCB) e a **Aurora** (barra, Dock, Launchpad e área de trabalho, Qt 6/QML), mais os apps Carinae (Documentos, Configurações, Terminal, Comando, Monitor, Fotos, PDF, Notas, Calculadora, Compactador, Emojis).

Testado automaticamente em **Debian 13, Ubuntu 25.10, Fedora, Arch Linux e openSUSE Tumbleweed**.

```bash
tar xf carinaeos-ambiente-*.tar.gz
cd carinaeos-ambiente-*
./instalar-universal.sh
```

Depois termine a sessão e escolha **CarinaeOS (Gravidade)** na tela de entrada. O seu ambiente atual continua lá.
Para desinstalar: `./instalar-universal.sh --remover`.

Sessão X11. Licença GPL-2.0-or-later.
