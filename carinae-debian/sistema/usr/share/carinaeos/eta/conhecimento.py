# CarinaeOS - o que a Eta sabe sobre o sistema.
# Cada topico: palavras-chave (para a busca sem IA), resposta (passo a passo)
# e, quando existe, uma acao que a Eta pode fazer pelo usuario (com permissao).

SISTEMA = """\
O CarinaeOS 1.0 "Eta" e um sistema operacional baseado no Debian 13 com o ambiente KDE Plasma 6,
com visual inspirado no macOS. Partes principais:
- Barra de cima (transparente): a estrela no canto esquerdo abre o MENU ESTRELA (Sobre este computador,
  Configuracoes do Sistema, Supernova, Orbita, Forcar encerramento, Suspender, Reiniciar, Desligar,
  Bloquear tela, Terminar sessao). No meio aparecem os menus do aplicativo ativo (Arquivo, Editar...).
  A direita: rede, som, bateria, notificacoes, relogio.
- Dock (em baixo): os icones crescem ao passar o mouse; a estrela no centro abre o LAUNCHPAD (todos os
  aplicativos em tela cheia, com pesquisa). Clique direito num icone: Manter no Dock / Remover do Dock /
  Fechar. Um ponto por baixo indica app aberto. Lixeira no fim.
- Tecla Meta (a do Windows) abre o Launchpad. Meta+Espaco abre a Eta.
- Alt+Tab alterna janelas no estilo Flip 3D (muda-se no Supernova).
- SUPERNOVA: app de personalizacao (efeitos de janela, estilos de Alt+Tab, tamanho e lupa da Dock,
  perfis "Mac classico", "Vista retro", "Supernova total", "Leve e rapido", e ideias exclusivas:
  Ceu vivo, Foco estelar, Supernova ao fechar, Pulso estelar).
- ORBITA: loja de aplicativos (Flathub). Instala Chrome, Firefox, LibreOffice, Spotify, Discord, Steam,
  WhatsApp, VS Code e muito mais, sem senha de administrador.
- Arquivos (o gerenciador de arquivos, programa Dolphin).
- CADEADO: clique direito num arquivo ou pasta > "Bloquear com senha". Pasta bloqueada fica com icone de
  cadeado; para abrir, duplo clique em "Conteudo bloqueado.bloqueado" dentro dela. Para bloquear
  aplicativos: abrir "Bloquear aplicativos" no Launchpad.
- COFRES (Plasma Vault): pastas cifradas que abrem e fecham pelo icone de cadeado na barra de cima.
- Configuracoes do Sistema: todas as opcoes (tela, rede, som, usuarios, idioma, teclado, energia...).
- Atualizacoes do sistema: app "Discover" > Atualizacoes.
- Capturas de tela: tecla Print (app Spectacle).
- A Eta (eu) tambem sabe: abrir HDs externos e pen drives (inclusive protegidos com senha ou BitLocker),
  ejetar discos, ligar a pastas de rede (NAS, outro computador) com usuario e senha, ligar ao Wi-Fi,
  verificar e instalar atualizacoes, instalar programas (apt ou Flathub) e correr comandos no terminal
  (Konsole) a vista do usuario. A busca rapida abre com Ctrl+Espaco.
"""

TOPICOS = [
    dict(id='resolucao', palavras='resolucao tela monitor tamanho escala ecra display hdpi nitidez',
         resposta='Para mudar a resolução: Configurações do Sistema > Monitor e Tela > Configuração de tela. '
                  'Escolha a resolução (a maior costuma ser a melhor) e, se tudo ficar pequeno, aumente a "Escala" (125% ou 150%). Clique em Aplicar.',
         acao=('abrir as configurações de tela', 'kcmshell6 kcm_kscreen')),
    dict(id='fundo', palavras='fundo papel parede wallpaper imagem area trabalho',
         resposta='Para trocar o fundo: clique com o botão direito na área de trabalho > "Configurar área de trabalho e papel de parede". '
                  'Escolha uma imagem ou clique em "Adicionar…" para usar uma sua. Dica: no Supernova, o "Céu vivo" muda o tom do fundo ao longo do dia.',
         acao=('abrir as configurações do papel de parede', 'kcmshell6 kcm_wallpaper')),
    dict(id='wifi', palavras='wifi wi-fi internet rede conectar ligar senha rede sem fio',
         resposta='Para ligar ao Wi-Fi: clique no ícone de rede na barra de cima (à direita), escolha a rede e digite a senha. '
                  'Nas Configurações do Sistema > Wi-Fi e Internet estão as opções avançadas.',
         acao=('abrir as configurações de rede', 'kcmshell6 kcm_networkmanagement'),
         faz=('ligar o Wi-Fi', 'nmcli radio wifi on'),
         desfaz=('desligar o Wi-Fi', 'nmcli radio wifi off')),
    dict(id='bluetooth', palavras='bluetooth fone fones caixa som sem fio parear emparelhar',
         resposta='Para ligar um dispositivo Bluetooth: Configurações do Sistema > Bluetooth > "Adicionar dispositivo". '
                  'Ponha o fone/caixa em modo de emparelhamento e escolha-o na lista.',
         acao=('abrir as configurações de Bluetooth', 'kcmshell6 kcm_bluetooth')),
    dict(id='som', palavras='som volume audio alto falante microfone saida entrada mudo',
         resposta='O volume muda no ícone de som da barra de cima (role a roda do mouse por cima dele). '
                  'Para escolher a saída ou o microfone: Configurações do Sistema > Som.',
         acao=('abrir as configurações de som', 'kcmshell6 kcm_pulseaudio')),
    dict(id='usuarios', palavras='usuario conta senha mudar senha foto perfil avatar nome',
         resposta='Para mudar a sua senha, foto ou nome: Configurações do Sistema > Usuários. '
                  'A senha pode ser simples, como um PIN de 4 a 6 números.',
         acao=('abrir as configurações de usuários', 'kcmshell6 kcm_users')),
    dict(id='idioma', palavras='idioma lingua portugues ingles regiao formato data moeda',
         resposta='Idioma e formatos (data, moeda): Configurações do Sistema > Região e idioma.',
         acao=('abrir Região e idioma', 'kcmshell6 kcm_regionandlang')),
    dict(id='teclado', palavras='teclado layout acento cedilha abnt atalho tecla',
         resposta='Para mudar o layout do teclado (ex.: Português do Brasil ABNT2): Configurações do Sistema > Teclado > Layouts > Adicionar.',
         acao=('abrir as configurações do teclado', 'kcmshell6 kcm_keyboard')),
    dict(id='mouse', palavras='mouse rato touchpad velocidade cursor rolagem clique',
         resposta='Velocidade e botões do mouse: Configurações do Sistema > Mouse e Touchpad.',
         acao=('abrir as configurações do mouse', 'kcmshell6 kcm_mouse')),
    dict(id='energia', palavras='energia bateria suspender hibernar desligar tela economia',
         resposta='Quando a tela apaga e o computador suspende: Configurações do Sistema > Energia.',
         acao=('abrir as configurações de energia', 'kcmshell6 kcm_powerdevilprofilesconfig')),
    dict(id='data', palavras='data hora relogio fuso horario',
         resposta='Data, hora e fuso horário: Configurações do Sistema > Data e hora.',
         acao=('abrir Data e hora', 'kcmshell6 kcm_clock')),
    dict(id='impressora', palavras='impressora imprimir scanner',
         resposta='O suporte a impressoras ainda não vem instalado nesta versão. Posso instalá-lo para você (pacotes cups e print-manager); depois aparece em Configurações do Sistema > Impressoras.',
         acao=('instalar o suporte a impressoras', 'pkexec apt-get install -y cups print-manager system-config-printer')),
    dict(id='notificacoes', palavras='notificacoes avisos nao perturbe',
         resposta='Notificações e "Não perturbe": ícone de sino na barra de cima, ou Configurações do Sistema > Notificações.',
         acao=('abrir as configurações de notificações', 'kcmshell6 kcm_notifications')),
    dict(id='padrao', palavras='aplicativo padrao navegador padrao abrir com programa padrao',
         resposta='Para escolher o navegador ou outros apps padrão: Configurações do Sistema > Aplicativos padrão.',
         acao=('abrir Aplicativos padrão', 'kcmshell6 kcm_componentchooser')),
    dict(id='efeitos', palavras='efeito efeitos animacao alt tab dock lupa gelatina lampada personalizar visual tema',
         resposta='Efeitos, Alt+Tab, tamanho e lupa da Dock e perfis visuais estão no app Supernova (menu estrela > Supernova).',
         acao=('abrir o Supernova', 'carinaeos-supernova')),
    dict(id='instalar', palavras='instalar baixar programa aplicativo app chrome libreoffice spotify discord steam whatsapp loja',
         resposta='Para instalar aplicativos use a Órbita (ícone do planeta na Dock ou menu estrela > Órbita): procure o app e clique em Instalar. '
                  'Ele aparece logo no Launchpad.',
         acao=('abrir a Órbita', 'carinaeos-orbita')),
    dict(id='atualizar', palavras='atualizar atualizacao atualizacoes update sistema',
         resposta='As atualizações do sistema ficam no Discover > Atualizações. Também pode pedir para eu verificar.',
         acao=('abrir as atualizações', 'plasma-discover --mode update')),
    dict(id='bloquear', palavras='bloquear senha cadeado proteger esconder privado pasta arquivo cofre',
         resposta='Para bloquear um arquivo ou pasta: clique com o botão direito > "Bloquear com senha". '
                  'Para aplicativos: abra "Bloquear aplicativos" no Launchpad. Para uma pasta cifrada que abre e fecha: use os Cofres (ícone de cadeado na barra de cima).',
         acao=('abrir "Bloquear aplicativos"', 'carinaeos-cadeado aplicativos')),
    dict(id='captura', palavras='captura print screenshot foto da tela gravar tela',
         resposta='Tecla Print tira uma captura (app Spectacle). No Spectacle também pode gravar a tela.',
         acao=('abrir o Spectacle', 'spectacle')),
    dict(id='espaco', palavras='espaco disco armazenamento livre cheio memoria',
         resposta='Posso ver quanto espaço livre tem: é só pedir "quanto espaço tenho livre?".',
         acao=None),
    dict(id='luznoturna', palavras='noturna luz noturna noite cores quentes olhos azul cansaco',
         resposta='A luz noturna deixa as cores mais quentes à noite. Fica em Configurações do Sistema > Cores e temas > Luz noturna. '
                  'Também posso ligá-la ou desligá-la para você.',
         acao=('abrir a Luz noturna', 'kcmshell6 kcm_nightlight'),
         faz=('ligar a luz noturna', 'kwriteconfig6 --file kwinrc --group NightColor --key Active true && qdbus6 org.kde.KWin /KWin reconfigure'),
         desfaz=('desligar a luz noturna', 'kwriteconfig6 --file kwinrc --group NightColor --key Active false && qdbus6 org.kde.KWin /KWin reconfigure')),
    dict(id='escuro', palavras='escuro claro tema cores modo escuro modo claro dark light branco preto',
         resposta='O CarinaeOS já vem no modo escuro. Para trocar: Configurações do Sistema > Cores e temas > Cores, escolha "Breeze Claro" (claro) ou "CarinaeOS" (escuro). '
                  'Posso trocar para você.',
         acao=('abrir as configurações de cores', 'kcmshell6 kcm_colors'),
         faz=('mudar para o modo claro', 'plasma-apply-colorscheme BreezeLight'),
         desfaz=('voltar ao modo escuro do CarinaeOS', 'plasma-apply-colorscheme CarinaeOS')),
    dict(id='volume', palavras='volume alto baixo aumentar diminuir som mais som menos mudo silenciar',
         resposta='Para mudar o volume, role a roda do mouse sobre o ícone de som na barra de cima. Posso aumentar ou diminuir para você.',
         acao=None,
         faz=('aumentar o volume', 'pactl set-sink-volume @DEFAULT_SINK@ +10%'),
         desfaz=('diminuir o volume', 'pactl set-sink-volume @DEFAULT_SINK@ -10%')),
    dict(id='backup', palavras='backup copia seguranca salvar guardar copias recuperar perder arquivos',
         resposta='Para fazer cópias de segurança automáticas: Configurações do Sistema > Backups (programa Kup). '
                  'Ligue um disco externo, ative os backups e escolha as pastas (por exemplo, a sua pasta pessoal). '
                  'Também pode simplesmente copiar as pastas para um disco externo no app Arquivos.',
         acao=('abrir as configurações de Backups', 'kcmshell6 kcm_kup')),
    dict(id='calendario', palavras='calendario agenda google eventos compromissos lembrete reuniao conta',
         resposta='O Calendário do CarinaeOS (Merkuro) liga à sua conta Google: abra o Calendário > menu ☰ > '
                  'Configurações > Contas (ou "Fontes de calendário") > Adicionar > Google, entre na sua conta e autorize. '
                  'Os eventos aparecem no Calendário e também ao clicar no relógio da barra de cima.',
         acao=('abrir o Calendário', 'merkuro-calendar')),
    dict(id='mapas', palavras='mapa mapas globo rota caminho localizacao cidade endereco',
         resposta='O app Mapas mostra o globo e os mapas do OpenStreetMap: procure uma cidade ou morada na barra de pesquisa, '
                  'e use o separador "Rotas" para calcular um caminho.',
         acao=('abrir os Mapas', 'marble')),
    dict(id='casa', palavras='casa home assistant luzes domotica inteligente cena',
         resposta='O app Casa liga ao seu Home Assistant: escreva o endereço e um token de acesso (no Home Assistant: '
                  'perfil > Segurança > Tokens de acesso de longa duração). Depois pode pedir-me, por exemplo, '
                  '"acende a luz da sala" ou "ativa a cena cinema". No separador "Este computador", o PC aparece no Home Assistant por MQTT.',
         acao=('abrir a Casa', 'carinaeos-casa')),
    dict(id='ambiente', palavras='ambiente gnome xfce plasma desktop trocar sessao interface',
         resposta='Pode usar o CarinaeOS com KDE Plasma, GNOME ou XFCE: abra "Ambiente de trabalho" (no Launchpad ou no Supernova), '
                  'escolha um e carregue em Instalar. Depois termine a sessão: a tela de entrada abre no ambiente escolhido, '
                  'com a Dock, o tema e os papéis de parede do CarinaeOS.',
         acao=('abrir a troca de ambiente de trabalho', 'carinaeos-ambientes')),
    dict(id='dock', palavras='dock adicionar fixar pasta aplicativo app icone barra baixo',
         resposta='Para pôr algo na Dock: arraste um aplicativo, pasta ou arquivo para a Dock; ou, no Launchpad, botão direito > '
                  '"Adicionar à Dock"; ou, nos Arquivos, botão direito numa pasta > "Adicionar à Dock". Para tirar: botão direito '
                  'no ícone da Dock > "Remover do Dock". O estilo da Dock muda-se no Supernova.',
         acao=('abrir o Supernova', 'carinaeos-supernova')),
    dict(id='etiquetas', palavras='etiqueta etiquetas tag tags cor marcar marcador organizar',
         resposta='Para pôr uma etiqueta (como no Mac): nos Arquivos, botão direito no arquivo ou pasta > Etiquetas > escolha a cor '
                  '(Vermelho, Laranja, Amarelo, Verde, Azul, Roxo, Cinzento) ou "Outra etiqueta…". Funciona também em pastas de rede '
                  '(NAS, Windows). Tudo o que tem etiqueta aparece em "Etiquetas", na barra lateral dos Arquivos, separado por etiqueta.',
         acao=('abrir as Etiquetas', 'dolphin ~/Etiquetas')),
    dict(id='estilo', palavras='estilo windows mac barra tarefas iniciar menu aparencia layout',
         resposta='O CarinaeOS tem dois estilos: Mac (barra em cima e Dock em baixo) e Windows 11 (barra de tarefas em baixo com o menu '
                  'Iniciar e a estrela). Para trocar: abra "Ambiente de trabalho" e escolha "Estilo Windows 11" ou "CarinaeOS (estilo Mac)".',
         acao=('abrir a troca de ambiente e estilo', 'carinaeos-ambientes')),
]
