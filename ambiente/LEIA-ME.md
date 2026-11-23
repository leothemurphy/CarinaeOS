# CarinaeOS — o nosso ambiente gráfico

Sem Plasma e sem KWin: um gestor de janelas e um shell próprios. **A sua Dock e o seu Launchpad continuam os mesmos** (o mesmo QML).

## As peças

| Peça | O que faz | Onde |
|---|---|---|
| `carinae-wm` | Gestor de janelas X11 (C++/XCB + cairo). Molduras com os botões à macOS, mover/redimensionar, encaixar nas metades e nas zonas 25/50/25, 4 áreas de trabalho, 3 monitores, ecrã inteiro, Alt+Tab, atalhos. Fala EWMH/ICCCM. | `wm/carinae-wm.cpp` |
| `carinae-shell` | Papel de parede, barra de cima, Dock e Launchpad (Qt 6/QML). | `shell/` |
| `CarinaeOS.Compat` | Substitui o que a Dock usava do Plasma, **com os mesmos nomes**: `Icon` (Kirigami), `Dialog`/`Types` (PlasmaCore), `DataSource` (Plasma5Support), `TasksModel` (TaskManager), `RootModel`/`RecentUsageModel`/`DashboardWindow` (Kicker), `Menu`/`MenuItem` (PlasmaExtras), `WindowThumbnail`. | `shell/src/compat`, `shell/qml-modulos/Compat` |
| `CarinaeOS.Base` | `Plasmoid` (configuração da Dock em `~/.config/carinaeos/dock.json`, importada sozinha do Plasma na 1.ª vez), `Sistema`, `KWindowSystem`. | `shell/src/base` |
| A sua Dock | `Dock.qml` (era `main.qml`), `Lancador.qml`, `Tarefa.qml`, `Previa.qml`, `Pilha.qml`, `Rotulo.qml`, `FundoIcone.qml` | `shell/qml/dock` |
| Barra de cima | `MenuEstrela.qml` (o seu menu estrela) + `Relogio.qml` + `Volume.qml` | `shell/qml/barra` |
| Sessão | `startcarinae`, `carinae-sessao`, `carinae-autostart`, `picom.conf`, `atalhos.conf`, `carinaeos.desktop` | `sessao/` |

## Instalar

```bash
./instalar.sh
```

Depois:

- **Experimentar sem sair do Plasma:** `carinae-experimentar`. Para voltar: `carinae-voltar`.
- **A sessão inteira:** termine a sessão e escolha **CarinaeOS (carinae-wm)** no SDDM.

## Mexer na Dock e no Launchpad

O QML fica em `/usr/local/share/carinaeos/shell` e **não precisa de compilar**. Depois de editar:

```bash
carinae-shell --enviar recarregar
```

Se continuar a mexer na versão Plasma (`/usr/share/plasma/plasmoids/org.carinaeos.dock`), traga as mudanças com `./instalar.sh --so-qml` (ou `carinae-portar`). O porte só troca os imports e os comandos `qdbus` do Plasma.

## Atalhos (`~/.config/carinaeos/atalhos.conf`)

| Tecla | Ação |
|---|---|
| Super (sozinha) / Alt+F1 | Launchpad |
| Super+1…9 | ícone N da Dock |
| Alt+Tab / Alt+Shift+Tab | alternar janelas |
| Super+↑ / Super+↓ | maximizar / repor ou minimizar |
| Super+← / Super+→ | metade esquerda / direita |
| Super+Alt+1/2/3 | zonas 25 % / 50 % / 25 % |
| Super+F | ecrã inteiro |
| Super+D | mostrar a área de trabalho |
| Super+Ctrl+← / → | área de trabalho anterior / seguinte |
| Super+L | bloquear |
| Ctrl+Espaço | Comando (`carinaeos-comando`) |
| Ctrl+Alt+T, Super+Enter | terminal |
| Alt+F4 | fechar |

Com o rato: duplo clique no título maximiza, arrastar até ao topo maximiza e arrastar até às bordas encaixa. Alt+arrastar move a janela e Alt+botão direito redimensiona. O botão do meio no título manda a janela para trás.

## Se algo correr mal

- O registo da sessão fica em `~/.cache/carinaeos/sessao.log`.
- Ecrã preto ou tremido: em `~/.config/carinaeos/sessao.conf` ponha `PICOM_BACKEND=xrender`.
- Se o `carinae-shell` cair 3 vezes, a sessão passa sozinha para desenho por software. Se o `carinae-wm` cair sempre, a sessão volta ao `kwin_x11` para não ficar sem janelas.
- O Plasma continua instalado e pode ser escolhido no SDDM.

## Por que X11 (e não Wayland) por agora

A placa usa o driver NVIDIA **470 (Kepler)**, que não tem GBM. Os compositores Wayland (wlroots, Smithay, KWin Wayland) não funcionam bem com ele, e por isso o KWin estava com `Backend=Software`. No X11 com o picom em GLX, a placa trabalha a sério. O QML da Dock e do Launchpad não depende disto: quando houver placa ou driver novos, ele passa para Wayland quase sem mudanças.

## O que ainda falta (próximas etapas)

- **Bandeja do sistema** (StatusNotifierItem), **notificações** (`org.freedesktop.Notifications`) e os applets da barra antiga (`agoratoca`, `bandeja`, `pesquisa`, `nomeapp`).
- **Ecrã de bloqueio próprio**. Por enquanto é o i3lock com o papel desfocado.
- **Ícones de janelas sem `.desktop`** (`_NET_WM_ICON`).
- **Ícones na área de trabalho** (o `org.kde.plasma.folder`).
- **Atalhos globais de apps** que usavam o KGlobalAccel (ex.: Ctrl+Alt+Espaço do Claude): passam a ir para `atalhos.conf`.
