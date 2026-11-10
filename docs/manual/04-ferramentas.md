# 4. As ferramentas do CarinaeOS

Todas estão na **Central CarinaeOS** (ícone da estrela na Dock, ou menu estrela › Central).

## Central

Página inicial com todas as ferramentas e páginas próprias para Calendários, Janelas em zonas,
Cadeado, Histórico do Ctrl+C, Drivers e hardware, Privacidade e Tela de entrada.
Pelo terminal: `carinaeos-central [calendarios|janelas|drivers|privacidade|entrada]`.

## Supernova — personalização

Como o Windhawk: dezenas de ajustes, cada um com vários modelos para escolher.

- **Dock:** 13 estilos (Mac, escuro, transparente, bolhas, squircle, Rosé Pine, XP, Vista, translúcido,
  DockLike, Matter, Lucent, neon), tamanho, lupa, salto, visibilidade (sempre, esconder com janelas…),
  roda do rato para o volume, clique do meio.
- **Janelas:** efeito ao abrir e minimizar (lâmpada mágica, gelatina, explosão…), Alt+Tab (Flip 3D,
  grade, lista), botões, sombras, transparência, desfoque, velocidade das animações, foco.
- **Mesa:** clicar no papel de parede para mostrar a mesa, cantos ativos, cursor, luz noturna.
- **Perfis prontos:** Mac, Vista, XP, Supernova, Rosé Pine, Leve. *Restaurar* volta ao original.

Funciona no Plasma, no GNOME e no XFCE (cada ajuste usa o mecanismo de cada ambiente).

## Órbita — loja de aplicativos

Procura em todo o Debian e no Flathub, mostra o tamanho a baixar e o andamento (MB e passo),
instala e remove. Também atualiza tudo. Na sessão de teste avisa que o que instalar se perde ao desligar.

## Casa — Home Assistant

1. **Ligar:** endereço do Home Assistant (ex.: `http://192.168.1.193:8123`) e um *token de acesso
   de longa duração* (no Home Assistant: o seu perfil › Segurança › Tokens de acesso de longa duração › Criar).
2. **Painéis:** crie vários (Sala, Quarto, Energia…) na barra lateral. *✎ Editar painel* › *+ Adicionar cartão*.
3. **13 tipos de cartões:** Botão, Luz (com brilho), Lista, Sensor (valor grande), Gráfico (24 h),
   Clima (alvo, +/−), Cenas (fila de botões), Som e TV (tocar/pausa, volume), Câmara (imagem a cada 10 s),
   Estores e portões (abrir/parar/fechar), Tempo (previsão), Número (deslizante ou escolha), Texto.
   Cada cartão pode ter largura 1×, 2× ou 3×; em modo de edição pode mover (‹ ›), editar (✎) e apagar (✕).
   *✦ Sugerir um painel* monta um primeiro painel com o que existe na casa.
4. **Este computador no Home Assistant:** com MQTT, o PC aparece como dispositivo (CPU, memória, bateria,
   botões para bloquear/desligar, volume e notificações).

A Eta também comanda a casa: “acende a luz da sala”, “desliga o ar condicionado”, “qual a temperatura do quarto?”.

## Calendários

O Calendário (Merkuro) e o relógio da barra mostram os eventos de:

- **Endereço iCal** (o mais simples e fiável): cole o endereço em Central › Calendários e dê um nome.
  - **Google Calendar:** calendar.google.com › ⚙ Definições › (o seu calendário) › *Integrar calendário* ›
    **Endereço secreto em formato iCal** (termina em `basic.ics`).
  - **iCloud:** na app Calendário do iPhone/Mac, toque no ⓘ do calendário › *Calendário público* › copie o link `webcal://…`.
  - **Outlook:** Definições › Calendário › Calendários partilhados › Publicar um calendário › ICS.
  - Feriados, escolas, clubes: qualquer link `.ics` ou `webcal://`.
  O calendário é baixado para o computador e atualizado a cada 30 minutos (só leitura).
  Pelo terminal: `carinaeos-calendarios sincronizar`.
- **Conta Google (ler e escrever):** Central › Calendários › Conta Google › Ligar; entra-se no Google numa janela.
- **iCloud com escrita (CalDAV):** servidor `https://caldav.icloud.com`, o seu Apple ID e uma
  *senha específica de app* (appleid.apple.com › Início de sessão e segurança › Senhas específicas de app).

## Cadeado

- **Pastas e arquivos:** botão direito › **Trancar com senha**. A pasta continua no mesmo sítio, com um
  cadeado, e só abre com a senha (duplo clique). Por dentro fica cifrada com AES-256 (GnuPG): sem a senha,
  ninguém lê nada — nem a Eta, nem o administrador. Ao abrir, aparece um aviso com *Trancar de novo*.
  Arquivos trancados ficam com o nome `nome.ext.trancado`. Funciona no Plasma, GNOME e XFCE, e em pastas de rede.
- **Aplicativos:** Central › Cadeado › Aplicativos: marque os que devem pedir senha para abrir.
- **Cofres (Plasma Vault):** pastas cifradas que se abrem e fecham pelo cadeado da bandeja.
- Pelo terminal: `carinaeos-cadeado trancar <pasta>`, `carinaeos-cadeado abrir <pasta>`.

> **Guarde bem a senha.** Não há forma de recuperar uma pasta trancada sem ela.

## Etiquetas

Botão direito num arquivo ou pasta › **Etiquetas** › uma das 7 cores (Vermelho, Laranja, Amarelo, Verde,
Azul, Roxo, Cinzento) ou *Outra etiqueta…*. Cada etiqueta aparece na barra lateral dos Arquivos e numa
pasta em `~/Etiquetas/<etiqueta>` com atalhos para tudo o que a tem — também arquivos em pastas de rede.
Pelo terminal: `carinaeos-etiquetas pôr Azul <arquivo>`, `carinaeos-etiquetas listar`.

## Drivers e hardware

Central › Drivers e hardware deteta a placa de vídeo (NVIDIA, AMD, Intel), Wi-Fi, Bluetooth, impressoras e
scanners, leitor de impressão digital, ratos Logitech e de jogos e comandos de consola, e instala o que falta
com um clique (capítulo 8).

## Privacidade

- **Sessão sem rastro:** cria o usuário *Convidado (sem rastro)* na tela de entrada, sem senha. Tudo o que
  se fizer lá vive na memória e é apagado ao sair.
- **Modo escuro em todo o lado:** força o escuro no Chrome, Chromium, Brave, Edge e apps Electron
  (também nas páginas), no Firefox, nos aplicativos GTK e nos Flatpak.

## Tela de entrada

A sua **foto** (aparece no login, no bloqueio de tela e no menu) e a **imagem de fundo** do login.

## Boas-vindas, Céu vivo e papéis de parede

- **Boas-vindas:** o passeio por tudo o que o sistema tem (`carinaeos-boasvindas`).
- **Papéis de parede:** fotos 8K reais do Atacama com a estrela do CarinaeOS, do James Webb e do Hubble,
  e desenhos originais. **Céu vivo** troca o fundo sozinho ao longo do dia (`carinaeos-ceu-vivo`).
  “Muda o papel de parede” à Eta, ou `carinaeos-fundo --proximo`.

## ArtCraft Launcher

Já vem instalado: baixa e mantém atualizados os aplicativos da Craft App Suite.
