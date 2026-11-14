# 2. A área de trabalho

## A barra de cima

Da esquerda para a direita:

- **★ Menu estrela:** Sobre este computador, Pesquisa, Configurações, Órbita (loja), Central,
  Forçar saída, Suspender, Reiniciar, Desligar, Terminar sessão.
- **Nome do aplicativo ativo** em negrito. Clicar nele abre o menu da janela: nova janela, minimizar,
  ecrã inteiro, manter por cima e fechar. Funciona com todos os aplicativos, também os que não têm
  menus na barra, como o Chrome.
- **Menus do aplicativo** (Arquivo, Editar, Exibir…), como no Mac. A maioria
  dos Qt e GTK mostram-nos aqui. O Chrome, o Firefox e os aplicativos Electron têm os menus na própria janela.
- À direita, a **bandeja**: rede, som, brilho, Bluetooth, bateria, área de transferência, notificações,
  teclado (PT), e o **relógio**. Clicar no relógio abre o calendário com os seus eventos.

## A Dock

- Os ícones crescem quando o rato passa por cima; um ponto por baixo indica que o aplicativo está aberto.
- **Fixar** um aplicativo ou pasta: arraste-o para a Dock, ou botão direito no aplicativo aberto › *Adicionar à Dock*,
  ou nos Arquivos: botão direito numa pasta › *Adicionar à Dock*.
- **Tirar:** botão direito › *Remover da Dock*.
- **Reorganizar:** arraste um ícone fixado para a esquerda ou para a direita.
- **Separadores:** botão direito num ícone › *Adicionar separador à direita* (para separar por tipos); o mesmo menu tira-o.
- No fim estão os **Downloads** (abre uma pilha com os arquivos mais recentes) e a **Lixeira**.
- Roda do rato sobre a Dock muda o volume; clique do meio pode fechar (configurável no Supernova).
- Estilos, tamanho, lupa, salto ao abrir e visibilidade: Central › Supernova.

## Launchpad

**⊞** (sozinha) ou a estrela da Dock abrem o **Launchpad**, em vidro fosco sobre o papel de parede:

- **À esquerda**, as vistas e as categorias:
    - *Início* — um cartão colorido por categoria (Internet, Gráficos, Multimédia, Escritório, Jogos,
      Sistema…), com os seus aplicativos; clicar num cartão mostra a categoria inteira.
      Por cima, os aplicativos usados recentemente.
    - *Todos os aplicativos*, *Instalados recentemente* (o que instalou nos últimos 30 dias, também do
      Flathub e AppImage), *Favoritos* (os que estão na Dock) e *Mais usados*.
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

## Pesquisa (Ctrl+Espaço)

**Ctrl+Espaço**, **⊞+Espaço** ou a **lupa** da barra de cima abrem a **Pesquisa**, no modelo da nova pesquisa
do Windows: a caixa fica em baixo, encostada à Dock, e os resultados aparecem por cima.

- **Aplicativos** (também pelas iniciais: `gc` → Google Chrome), **configurações** e **arquivos** — pelo nome
  e pelo conteúdo, porque a indexação vem ligada (Configurações › Pesquisa).
- **Ações feitas ali mesmo**, marcadas com *Ação*:
    - “diminuir volume” / “aumentar volume” mostram o volume com um controlo deslizante;
    - “brilho”, “ativar modo claro”, “modo escuro”, “desligar o wi-fi”, “ligar bluetooth”, “silenciar”;
    - “lado a lado”, “maximizar”, “minimizar tudo”, “todas as janelas”;
    - “bloquear”, “suspender”, “reiniciar”, “desligar”, “captura de ecrã”, “recortar ecrã”.
- **Erros de escrita** não fazem mal (“diminiuir volume” funciona) e aparecem sugestões da palavra certa
  por cima da caixa — Tab aceita a primeira.
- **Contas** (`2*3,5+1`), **o tempo** (“tempo em Lisboa”), **uso do computador** (“memória”, “cpu”),
  **sites** (`youtube.com`), **pesquisa na web** e o **histórico da área de transferência** (“histórico”).
- O botão azul em baixo faz o principal (*Abrir*, *Diminuir*, *Aplicar*…); **···** ou **Ctrl+K** mostram mais
  opções (mostrar na pasta, copiar o caminho, adicionar à Dock…). Começar com **`>`** corre um comando no terminal.

## Janelas

- Botões à esquerda, como no Mac: **vermelho** fecha, **amarelo** minimiza, **verde** maximiza.
  São iguais em todos os aplicativos, também no Chrome e no Firefox.
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
| Ctrl+Espaço / ⊞+Espaço | Pesquisa (aplicativos, arquivos, ações, configurações) |
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

## Configurações

**Configurações** (menu estrela, Launchpad, Deck ou a Pesquisa: “configurações”) reúne tudo, como no Fedora:
uma lista de secções à esquerda, com pesquisa, e páginas simples à direita.

- **Wi-Fi e Rede:** ligar e desligar, escolher a rede (pede a senha), ver o endereço IP.
- **Bluetooth:** ligar e desligar, aparelhos emparelhados, *Adicionar um aparelho*.
- **Ecrãs:** brilho, luz noturna; resolução, escala e posição em *Mais opções*.
- **Som:** volume de saída e do microfone.
- **Energia:** bateria e modo (Desempenho, Equilibrado, Poupança).
- **Aparência:** escuro ou claro, e o papel de parede.
- **Pesquisa:** ligar ou desligar a indexação dos arquivos.
- **Privacidade e segurança, Partilha (SSH), Data e hora, Utilizadores.**
- **Sistema:** sobre o computador — processador, memória, disco, placa gráfica — e atalhos para
  atualizações, drivers e este manual.

Cada página tem **Mais opções…** para os ajustes avançados.

## A configuração inicial

No primeiro arranque depois de instalar aparece a **Configuração inicial**: boas-vindas, Wi-Fi,
privacidade (localização e relatórios de falhas), aparência e contas online (Google, iCloud, Nextcloud).
Termina com *Começar a usar o CarinaeOS*.

## Aparência

- **Papel de parede:** botão direito na área de trabalho › Configurar papel de parede, ou Central ›
  Papéis de parede (fotos 8K do céu do Atacama, Webb e Hubble, e o *Céu vivo*, que muda sozinho).
- **Modo claro/escuro:** Configurações › Cores e temas.
- **Luz noturna:** Configurações › Tela › Luz noturna (“liga a luz noturna”).
- **Tamanho do texto:** Configurações › Texto e fontes. **Escala da tela:** Configurações › Tela.
- **Personalização avançada** (efeitos, lâmpada mágica, gelatina, Alt+Tab, cantos, transparências):
  Central › Supernova, com perfis prontos (Mac, Vista, XP, Rosé Pine…).
