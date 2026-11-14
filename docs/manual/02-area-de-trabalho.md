# 2. A área de trabalho

## A barra de cima

Da esquerda para a direita:

- **★ Menu estrela:** Sobre este computador, Comando, Configurações do Sistema, Órbita (loja), Central,
  Forçar saída, Suspender, Reiniciar, Desligar, Terminar sessão.
- **Nome do aplicativo ativo** em negrito. Clicar nele abre o menu da janela: nova janela, minimizar,
  ecrã inteiro, manter por cima e fechar. Funciona com todos os aplicativos, também os que não têm
  menus na barra, como o Chrome.
- **Menus do aplicativo** (Arquivo, Editar, Exibir…), como no Mac. Os aplicativos KDE e a maioria
  dos Qt e GTK mostram-nos aqui. O Chrome, o Firefox e os aplicativos Electron têm os menus na própria janela.
- À direita, a **bandeja**: rede, som, brilho, Bluetooth, bateria, área de transferência, notificações,
  teclado (PT), e o **relógio**. Clicar no relógio abre o calendário com os seus eventos.

## A Dock

- Os ícones crescem quando o rato passa por cima; um ponto por baixo indica que o aplicativo está aberto.
- **Fixar** um aplicativo ou pasta: arraste-o para a Dock, ou botão direito no aplicativo aberto › *Adicionar à Dock*,
  ou nos Arquivos: botão direito numa pasta › *Adicionar à Dock*.
- **Tirar:** botão direito › *Remover da Dock*.
- No fim estão os **Downloads** (abre uma pilha com os arquivos mais recentes) e a **Lixeira**.
- Roda do rato sobre a Dock muda o volume; clique do meio pode fechar (configurável no Supernova).
- Estilos, tamanho, lupa, salto ao abrir e visibilidade: Central › Supernova.

## Launchpad

**⊞** (sozinha) ou a estrela da Dock abrem o **Launchpad**, em vidro fosco sobre o papel de parede:

- **À esquerda**, as vistas e as categorias:
    - *Início* — um cartão colorido por categoria (Internet, Gráficos, Multimédia, Escritório, Jogos,
      Sistema…), com os seus aplicativos; clicar num cartão mostra a categoria inteira.
      Por cima, os aplicativos usados recentemente.
    - *Todos os aplicativos*, *Favoritos* (os que estão na Dock) e *Mais usados*.
    - *Deck* (ver abaixo).
    - Em baixo: Bloquear, Suspender, Reiniciar e Desligar.
- **Ao centro**, a pesquisa (basta começar a escrever) e os ícones. Setas para escolher, Enter para abrir.
- **À direita**, o detalhe do aplicativo por baixo do rato: descrição, categoria, **Abrir**, as
  **ações rápidas** do aplicativo (ex.: *Nova janela privada* no Firefox), *Fixar na Dock* e
  *Adicionar ao Deck*. Em ecrãs estreitos este painel esconde-se.
- Botão direito num ícone: Abrir, Adicionar/Remover da Dock, Adicionar ao Deck.
- Esc ou um clique fora fecha.

### O Deck

Uma grelha de botões grandes e coloridos para o que faz muitas vezes, como um Stream Deck:
captura de ecrã, terminal, transferências, monitor do sistema, todas as janelas, mostrar a mesa,
Central, Supernova, Manual, configurações, bloquear e suspender.

- **Pôr um aplicativo:** botão direito no aplicativo › *Adicionar ao Deck*.
- **Pôr um comando ou um site:** botão **+ Adicionar** › nome e comando (ex.: `kcalc`) ou endereço
  (ex.: `https://youtube.com`).
- **Tirar:** botão direito no botão › *Tirar do Deck*. *Repor o Deck original* volta ao início.
- Fica guardado em `~/.config/carinaeos-deck.json`.

## Comando (Ctrl+Espaço)

**Ctrl+Espaço** (ou ⊞+Espaço) abre o **Comando**, uma barra ao centro do ecrã inspirada no Raycast:

- Em cima, o **estado do computador**: CPU, memória usada, disco livre, e os programas que mais
  gastam CPU e memória.
- Sem escrever nada, **sugestões** (o que mais usa). Escrevendo, aparecem:
    - **Aplicativos** (também pelas iniciais: `gc` → Google Chrome);
    - **Comandos** do sistema: bloquear, suspender, desligar, captura de ecrã ou de uma região, gravar
      o ecrã, Wi-Fi, Bluetooth, som, ecrãs, impressoras, SSH, drivers, papel de parede seguinte…;
    - **Arquivos** da pasta pessoal (pelo índice de arquivos do KDE);
    - **Contas** (`2*3,5+1`, `(10+5)/3`, `2^10`) — Enter copia o resultado;
    - **Sites** (`youtube.com`) e **pesquisa na web**.
- **Histórico da área de transferência:** escolha-o na lista (ou escreva “histórico”) para ver e
  procurar tudo o que copiou; Enter copia de novo. Esc volta.
- Começar com **`>`** corre o resto num terminal (ex.: `> sudo apt update`).
- **Ctrl+1…9** abre o resultado com esse número; **Ctrl+K** mostra as ações do resultado (mostrar na
  pasta, copiar o caminho, ações do aplicativo, adicionar à Dock…). Esc fecha.
- A pesquisa clássica do KDE (KRunner) continua em **Alt+F2**.

## Janelas

- Botões à esquerda, como no Mac: **vermelho** fecha, **amarelo** minimiza, **verde** maximiza.
  São iguais em todos os aplicativos (KDE, GTK, Chrome, Firefox).
- **Encostar a meio ecrã:** arraste para a borda, ou ⊞+← / ⊞+→. ⊞+↑ maximiza, ⊞+↓ restaura/minimiza.
- **Zonas (como o FancyZones):** Central › Janelas em zonas › escolha um esquema (duas ou três colunas,
  grade 2×2, principal + duas…). Depois arraste uma janela **com Shift carregado** e solte-a numa zona.
  ⊞+T desenha as suas próprias zonas.
- **Clicar no papel de parede** afasta todas as janelas para mostrar a mesa (como no macOS Sonoma);
  clicar numa janela ou na Dock trá-las de volta. Desligar: Supernova › Mesa.
- **Alt+Tab** troca de janela (Flip 3D ou grade, à escolha no Supernova). **Alt+F4** fecha.
- **⊞+W** mostra todas as janelas e áreas de trabalho (Visão geral).

## Áreas de trabalho (Spaces)

O CarinaeOS começa com 4 áreas de trabalho. **Ctrl+⊞+← / →** muda de área; na Visão geral (⊞+W)
arraste janelas entre áreas. Mudar o número: Central › Janelas em zonas › Áreas de trabalho.

## Histórico do Ctrl+C

Tudo o que copia (texto e imagens) fica guardado. **⊞+V** mostra a lista junto ao rato para escolher
o que colar. No ícone da prancheta da bandeja pode fixar itens, editar e limpar o histórico.

## Atalhos principais

| Atalho | O que faz |
|---|---|
| ⊞ | Launchpad |
| Ctrl+Espaço / ⊞+Espaço | Comando (aplicativos, arquivos, contas, área de transferência) |
| Alt+F2 | KRunner |
| ⊞+V | Histórico do Ctrl+C |
| ⊞+W | Todas as janelas e áreas de trabalho |
| ⊞+T | Desenhar zonas de janelas |
| ⊞+D | Mostrar a área de trabalho |
| ⊞+L | Bloquear a tela |
| ⊞+E | Arquivos |
| ⊞+← → ↑ ↓ | Encostar / maximizar janelas |
| Ctrl+⊞+← → | Mudar de área de trabalho |
| Alt+Tab | Trocar de janela |
| Alt+F4 | Fechar a janela |
| Print | Captura de tela (Spectacle, com opções) |
| Shift+Print | Captura da tela inteira |
| ⊞+Shift+Print | Captura de uma região retangular |
| ⊞+Print | Captura da janela ativa |
| Ctrl+Alt+T | Terminal |
| Ctrl+Esc | Monitor do sistema (forçar saída de programas) |

Todos os atalhos podem ser mudados em Configurações › Teclado › Atalhos.

## Estilos e ambientes

Central › **Ambiente e estilo** troca o visual inteiro:

- **Estilo Mac** (padrão): barra de cima + Dock em baixo.
- **Estilo Windows 11**: barra de cima + barra de tarefas em baixo com os ícones ao centro e o menu
  Iniciar com a estrela.
- **GNOME** (baixa cerca de 900 MB): barra de cima com o menu estrela e Dock com as animações do Mac.
- **XFCE** (baixa cerca de 300 MB): leve, para computadores antigos, com barra em cima e Dock (Plank).

Os ambientes GNOME e XFCE aparecem na tela de entrada (botão da sessão, no canto). Os papéis de parede,
os ícones e os botões das janelas do CarinaeOS vêm com eles.

## Aparência

- **Papel de parede:** botão direito na área de trabalho › Configurar papel de parede, ou Central ›
  Papéis de parede (fotos 8K do céu do Atacama, Webb e Hubble, e o *Céu vivo*, que muda sozinho).
- **Modo claro/escuro:** Configurações › Cores e temas.
- **Luz noturna:** Configurações › Tela › Luz noturna (“liga a luz noturna”).
- **Tamanho do texto:** Configurações › Texto e fontes. **Escala da tela:** Configurações › Tela.
- **Personalização avançada** (efeitos, lâmpada mágica, gelatina, Alt+Tab, cantos, transparências):
  Central › Supernova, com perfis prontos (Mac, Vista, XP, Rosé Pine…).
