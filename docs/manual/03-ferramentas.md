# 3. As ferramentas do CarinaeOS

Todas estão na **Central CarinaeOS** (ícone da estrela na Dock, ou menu estrela › Central).

## Central

Página inicial com todas as ferramentas e páginas próprias para Calendários, Janelas em zonas,
Cadeado, Histórico do Ctrl+C, Drivers e hardware, Acesso remoto (SSH), Privacidade e Tela de entrada.
Pelo terminal: `carinaeos-central [calendarios|janelas|drivers|ssh|privacidade|entrada]`.

## Supernova — personalização

Como o Windhawk: dezenas de ajustes, cada um com vários modelos para escolher.

- **Dock:** 13 estilos (Mac, escuro, transparente, bolhas, squircle, Rosé Pine, XP, Vista, translúcido,
  DockLike, Matter, Lucent, neon), tamanho, lupa, salto, visibilidade (sempre, esconder com janelas…),
  roda do mouse para o volume, clique do meio.
- **Janelas:** efeito ao abrir e minimizar (lâmpada mágica, gelatina, explosão…), Alt+Tab (Flip 3D,
  grade, lista), botões, sombras, transparência, desfoque, velocidade das animações, foco.
- **Área de trabalho:** clicar no papel de parede para mostrar a área de trabalho, cantos ativos, cursor, luz noturna.
- **Perfis prontos:** Mac, Vista, XP, Supernova, Rosé Pine, Leve. *Restaurar* volta ao original.


## Órbita — loja de aplicativos

Procura em todo o Debian e no Flathub, mostra o tamanho a baixar e o andamento (MB e passo),
instala e remove. Também atualiza tudo. Na sessão de teste avisa que o que instalar se perde ao desligar.

## Casa — Home Assistant

1. **Ligar:** endereço do Home Assistant (ex.: `http://192.168.1.193:8123`) e um *token de acesso
   de longa duração* (no Home Assistant: o seu perfil › Segurança › Tokens de acesso de longa duração › Criar).
2. **Painéis:** crie vários (Sala, Quarto, Energia…) na barra lateral. *✎ Editar painel* › *+ Adicionar cartão*.
3. **13 tipos de cartões:** Botão, Luz (com brilho), Lista, Sensor (valor grande), Gráfico (24 h),
   Clima (alvo, +/−), Cenas (fila de botões), Som e TV (tocar/pausa, volume), Câmera (imagem a cada 10 s),
   Persianas e portões (abrir/parar/fechar), Tempo (previsão), Número (deslizante ou escolha), Texto.
   Cada cartão pode ter largura 1×, 2× ou 3×; em modo de edição pode mover (‹ ›), editar (✎) e apagar (✕).
   *✦ Sugerir um painel* monta um primeiro painel com o que existe na casa.
4. **Este computador no Home Assistant:** com MQTT, o PC aparece como dispositivo (CPU, memória, bateria,
   botões para bloquear/desligar, volume e notificações).


## Música (e o MPD do Home Assistant)

O aplicativo **Música** (Launchpad › Música) é a porta de entrada do **MPD** (Music Player Daemon): na primeira vez
prepara e liga o servidor de música sozinho, e ele fica rodando sempre que entra no computador, mesmo com o
aplicativo fechado.

- **Biblioteca**: junte as pastas onde tem música (a pasta *Músicas*, um disco externo, uma pasta da rede). Nada é
  copiado nem mudado de lugar. Álbuns, Artistas e Músicas com pesquisa; duplo clique para tocar.
- **Capas**: primeiro a imagem dentro da própria música ou o `cover.jpg` da pasta; o que faltar vem do MusicBrainz /
  Cover Art Archive (gratuitos, sem conta). Pode desligar a internet em Biblioteca › Capas e letras.
- **Letras**: as guardadas na música ou do **LRCLIB**; quando a letra é sincronizada, a linha atual acompanha a
  música (clique numa linha para saltar para ela).
- **Listas e rádios**: *Fila › Salvar como lista*, ou ⋮ numa música › *Adicionar à lista*. Rádios da internet
  com o botão *Rádio*. **Cada lista é uma “fonte” no Home Assistant.**
- **Home Assistant**: separador *Home Assistant* › ligue *Deixar a rede de casa controlar a música* (pode colocar uma
  senha). No Home Assistant: Configurações › Dispositivos e serviços › Adicionar integração › **Music Player Daemon**,
  com o IP e a porta **6600** que o aplicativo mostra. O cartão do leitor no HA passa a ter as suas listas em *Fonte*.
  O som também pode sair pela rede em `http://IP:8000` (para outras colunas ou o Music Assistant).
- **mpc** e outros clientes MPD (Cantata, MALP no Android, MPDroid…) usam o mesmo servidor:
  `mpc -h IP status`, `mpc lsplaylists`, `mpc play`.

## Calendários

O Calendário (Merkuro) e o relógio da barra mostram os eventos de:

- **Endereço iCal** (o mais simples e confiável): cole o endereço em Central › Calendários e dê um nome.
  - **Google Calendar:** calendar.google.com › ⚙ Configurações › (o seu calendário) › *Integrar calendário* ›
    **Endereço secreto em formato iCal** (termina em `basic.ics`).
  - **iCloud:** na app Calendário do iPhone/Mac, toque no ⓘ do calendário › *Calendário público* › copie o link `webcal://…`.
  - **Outlook:** Configurações › Calendário › Calendários compartilhados › Publicar um calendário › ICS.
  - Feriados, escolas, clubes: qualquer link `.ics` ou `webcal://`.
  O calendário é baixado para o computador e atualizado a cada 30 minutos (só leitura).
  Pelo terminal: `carinaeos-calendarios sincronizar`.
- **Conta Google (ler e escrever):** Central › Calendários › Conta Google › Ligar; entra-se no Google numa janela.
- **iCloud com escrita (CalDAV):** servidor `https://caldav.icloud.com`, o seu Apple ID e uma
  *senha específica de app* (appleid.apple.com › Início de sessão e segurança › Senhas específicas de app).

## Cadeado

- **Pastas e arquivos:** botão direito › **Trancar com senha**. A pasta continua no mesmo lugar, com um
  cadeado, e só abre com a senha (duplo clique). Por dentro fica cifrada com AES-256 (GnuPG): sem a senha,
  ninguém lê nada — nem o administrador. Ao abrir, aparece um aviso com *Trancar de novo*.
  Arquivos trancados ficam com o nome `nome.ext.trancado`. Funciona também em pastas de rede.
- **Aplicativos:** Central › Cadeado › Aplicativos: marque os que devem pedir senha para abrir.
- **Cofres (Plasma Vault):** pastas cifradas que se abrem e fecham pelo cadeado da bandeja.
- Pelo terminal: `carinaeos-cadeado trancar <pasta>`, `carinaeos-cadeado abrir <pasta>`.

> **Salve bem a senha.** Não há forma de recuperar uma pasta trancada sem ela.

## Etiquetas

Botão direito num arquivo ou pasta › **Etiquetas** › uma das 7 cores (Vermelho, Laranja, Amarelo, Verde,
Azul, Roxo, Cinzento) ou *Outra etiqueta…*. Cada etiqueta aparece na barra lateral dos Arquivos e numa
pasta em `~/Etiquetas/<etiqueta>` com atalhos para tudo o que a tem — também arquivos em pastas de rede.
Pelo terminal: `carinaeos-etiquetas pôr Azul <arquivo>`, `carinaeos-etiquetas listar`.

## Drivers e hardware

Central › Drivers e hardware deteta a placa de vídeo (NVIDIA, AMD, Intel), Wi-Fi, Bluetooth, impressoras e
scanners, leitor de impressão digital, mouses Logitech e de jogos e controles de videogame, e instala o que falta
com um clique (capítulo 7).

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
  `carinaeos-fundo --proximo`.

## ArtCraft Launcher

Na **Órbita › Impressão 3D e CAD**: baixa e mantém atualizados os aplicativos da Craft App Suite (pede a senha para instalar).
