# CarinaeOS - Eta: como fazer pelo terminal (Konsole).
# Cada entrada: palavras-chave (a primeira e o assunto principal), titulo e comandos comentados.
# As linhas que comecam por "#" sao explicacoes; as outras sao comandos para copiar.

COMANDOS = [
    dict(id='instalar', palavras='instalar instalo instala programa pacote apt app aplicativo',
         titulo='Instalar programas',
         cmd='''# procurar um programa nos repositórios do Debian
apt search gimp
# instalar (pede a sua senha)
sudo apt update && sudo apt install gimp
# ou pelo Flathub (sem senha, só para o seu usuário)
flatpak search spotify
flatpak install --user flathub com.spotify.Client'''),
    dict(id='remover', palavras='remover desinstalar desinstalo apagar programa pacote tirar',
         titulo='Remover programas',
         cmd='''sudo apt remove gimp
# remover também as configurações e o que ficou sem uso
sudo apt purge gimp && sudo apt autoremove
# programas do Flathub
flatpak uninstall com.spotify.Client'''),
    dict(id='atualizar', palavras='atualizar atualizacao atualizacoes update upgrade sistema',
         titulo='Atualizar o sistema',
         cmd='''sudo apt update            # baixa a lista de novidades
apt list --upgradable      # mostra o que há para atualizar
sudo apt full-upgrade      # instala tudo
flatpak update             # atualiza os aplicativos do Flathub'''),
    dict(id='espaco', palavras='espaco disco livre cheio armazenamento ocupa tamanho',
         titulo='Ver o espaço em disco',
         cmd='''df -h                       # espaço livre em cada disco
du -sh ~/* | sort -h        # o que ocupa mais na sua pasta
ncdu ~                      # explorar (instale com: sudo apt install ncdu)'''),
    dict(id='memoria', palavras='memoria ram processos lento travado cpu processador',
         titulo='Memória, processador e processos',
         cmd='''free -h                     # memória livre
top                         # processos em tempo real (q para sair)
ps aux --sort=-%mem | head  # os que gastam mais memória
kill 1234                   # fechar o processo número 1234
pkill firefox               # fechar pelo nome'''),
    dict(id='arquivos', palavras='procurar encontrar achar arquivo ficheiro find locate buscar',
         titulo='Procurar arquivos',
         cmd='''locate curriculo                       # rápido (índice do sistema)
find ~ -iname "*curriculo*"            # procura na sua pasta
find ~ -name "*.pdf" -mtime -7         # PDFs mudados nos últimos 7 dias
grep -ril "fatura" ~/Documentos        # arquivos que contêm a palavra'''),
    dict(id='copiar', palavras='copiar mover renomear pasta criar apagar arquivo cp mv mkdir rm',
         titulo='Copiar, mover, renomear e apagar',
         cmd='''mkdir ~/Projetos                 # criar uma pasta
cp foto.jpg ~/Imagens/           # copiar
cp -r Pasta ~/Backup/            # copiar uma pasta inteira
mv relatorio.pdf ~/Documentos/   # mover
mv nome-antigo.txt nome-novo.txt # renomear
gio trash arquivo.txt            # mandar para a lixeira (pode recuperar)
rm arquivo.txt                   # apagar de vez (cuidado!)'''),
    dict(id='compactar', palavras='compactar zip descompactar extrair tar rar 7z comprimir',
         titulo='Compactar e extrair',
         cmd='''zip -r fotos.zip Fotos/          # criar um .zip
unzip fotos.zip                  # extrair um .zip
tar -czf backup.tar.gz Pasta/    # criar um .tar.gz
tar -xf arquivo.tar.xz           # extrair .tar.gz / .tar.xz
7z x arquivo.7z                  # extrair .7z (sudo apt install 7zip)'''),
    dict(id='permissoes', palavras='permissao permissoes chmod chown executavel dono acesso negado',
         titulo='Permissões',
         cmd='''ls -l                            # ver permissões e donos
chmod +x script.sh               # tornar executável
chmod 600 segredo.txt            # só você pode ler e escrever
sudo chown $USER:$USER arquivo   # passar a ser seu'''),
    dict(id='wifi', palavras='wifi wi-fi rede internet sem fio conectar nmcli',
         titulo='Wi-Fi e rede',
         cmd='''nmcli device wifi list                       # redes à volta
nmcli device wifi connect "MinhaRede" --ask   # ligar (pede a senha)
nmcli radio wifi off                          # desligar o Wi-Fi
nmcli radio wifi on
nmcli connection show                         # ligações guardadas'''),
    dict(id='ip', palavras='ip endereco rede ping internet dns conexao ligacao',
         titulo='Endereço IP e testar a internet',
         cmd='''ip -br address               # o seu endereço IP
ping -c 4 google.com         # testar a ligação
resolvectl status            # servidores DNS
curl ifconfig.me             # IP público'''),
    dict(id='bluetooth', palavras='bluetooth fone auscultadores emparelhar bluetoothctl coluna',
         titulo='Bluetooth',
         cmd='''bluetoothctl
# dentro do bluetoothctl:
power on
scan on                      # espere o aparelho aparecer
pair AA:BB:CC:DD:EE:FF
connect AA:BB:CC:DD:EE:FF
exit'''),
    dict(id='som', palavras='som volume audio mudo silenciar coluna saida pactl wpctl',
         titulo='Som e volume',
         cmd='''wpctl status                              # aparelhos de som
wpctl set-volume @DEFAULT_AUDIO_SINK@ 50%  # volume a 50%
wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+  # aumentar
wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle # silenciar / voltar'''),
    dict(id='brilho', palavras='brilho tela ecra escurecer clarear luminosidade',
         titulo='Brilho da tela',
         cmd='''qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl brightness
# mudar (o número vai de 0 ao máximo indicado por brightnessMax)
qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl setBrightness 5000'''),
    dict(id='resolucao', palavras='resolucao tela monitor ecra escala tamanho rotacao kscreen',
         titulo='Resolução e monitores',
         cmd='''kscreen-doctor -o                              # ver monitores e modos
kscreen-doctor output.1.mode.1920x1080@60      # mudar a resolução
kscreen-doctor output.1.scale.1.25             # escala de 125%'''),
    dict(id='fundo', palavras='fundo papel parede wallpaper imagem',
         titulo='Papel de parede',
         cmd='''plasma-apply-wallpaperimage ~/Imagens/foto.jpg'''),
    dict(id='tema', palavras='tema escuro claro cores aparencia colorscheme',
         titulo='Tema claro / escuro',
         cmd='''plasma-apply-colorscheme --list-schemes
plasma-apply-colorscheme BreezeLight    # claro
plasma-apply-colorscheme CarinaeOS      # escuro (padrão)'''),
    dict(id='usuarios', palavras='usuario usuarios conta criar adicionar senha passwd adduser',
         titulo='Usuários e senhas',
         cmd='''passwd                          # mudar a sua senha
sudo adduser maria              # criar um usuário
sudo usermod -aG sudo maria     # dar-lhe poderes de administrador
sudo deluser maria              # apagar o usuário'''),
    dict(id='servicos', palavras='servico servicos systemctl iniciar parar arranque daemon',
         titulo='Serviços (programas de fundo)',
         cmd='''systemctl status ssh             # estado de um serviço
sudo systemctl start ssh          # iniciar
sudo systemctl stop ssh           # parar
sudo systemctl enable --now ssh   # ligar sempre ao arrancar
systemctl --failed                # serviços com problemas'''),
    dict(id='logs', palavras='log logs erro erros journalctl registo diagnostico problema',
         titulo='Ver erros e registos',
         cmd='''journalctl -b -p err          # erros desde que ligou o computador
journalctl -f                 # acompanhar em tempo real
sudo dmesg --level=err,warn   # avisos do kernel (hardware)'''),
    dict(id='discos', palavras='disco discos montar pen pendrive hd externo usb desmontar ejetar particao',
         titulo='Discos e pen drives',
         cmd='''lsblk -f                           # discos e partições
udisksctl mount -b /dev/sdb1        # abrir (montar) o pen drive
udisksctl unmount -b /dev/sdb1      # fechar
udisksctl power-off -b /dev/sdb     # desligar para tirar o cabo
udisksctl unlock -b /dev/sdb1       # desbloquear disco com senha (LUKS/BitLocker)'''),
    dict(id='formatar', palavras='formatar formatacao apagar disco pen mkfs particionar',
         titulo='Formatar um pen drive (apaga tudo!)',
         cmd='''lsblk                              # confirme qual é o pen (ex.: sdb)
sudo umount /dev/sdb1
sudo mkfs.exfat -n PEN /dev/sdb1    # exFAT: funciona no Windows e no Mac
# alternativa gráfica: sudo apt install partitionmanager'''),
    dict(id='desligar', palavras='desligar reiniciar suspender hibernar shutdown reboot',
         titulo='Desligar e reiniciar',
         cmd='''systemctl poweroff     # desligar
systemctl reboot       # reiniciar
systemctl suspend      # suspender
shutdown +30           # desligar daqui a 30 minutos (cancelar: shutdown -c)'''),
    dict(id='data', palavras='data hora fuso horario relogio timedatectl',
         titulo='Data, hora e fuso horário',
         cmd='''timedatectl                                 # ver
sudo timedatectl set-timezone Europe/Lisbon   # mudar o fuso
timedatectl list-timezones | grep America'''),
    dict(id='nome', palavras='nome computador hostname rede',
         titulo='Nome do computador',
         cmd='''hostnamectl
sudo hostnamectl set-hostname meu-pc'''),
    dict(id='teclado', palavras='teclado layout idioma teclas abnt',
         titulo='Teclado',
         cmd='''localectl status
# trocar o teclado (ex.: português do Brasil ABNT2)
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList br
kwriteconfig6 --file kxkbrc --group Layout --key Use true'''),
    dict(id='impressora', palavras='impressora imprimir cups lpstat scanner',
         titulo='Impressoras',
         cmd='''sudo apt install cups printer-driver-all   # suporte a impressoras
lpstat -p                                   # impressoras instaladas
lp -d NomeDaImpressora documento.pdf        # imprimir'''),
    dict(id='agendar', palavras='agendar tarefa cron automatico repetir crontab',
         titulo='Agendar tarefas',
         cmd='''crontab -e
# exemplo: todos os dias às 20h copiar Documentos para o pen
0 20 * * * rsync -a ~/Documentos/ /media/$USER/PEN/backup/'''),
    dict(id='backup', palavras='backup copia seguranca rsync guardar sincronizar',
         titulo='Cópia de segurança',
         cmd='''# copiar só o que mudou (rápido) para um disco externo
rsync -av --progress ~/Documentos/ /media/$USER/HD/Documentos/
# backup comprimido com data
tar -czf ~/backup-$(date +%F).tar.gz ~/Documentos'''),
    dict(id='ssh', palavras='ssh remoto acesso servidor ligar outro computador scp',
         titulo='Acesso remoto (SSH)',
         cmd='''sudo apt install openssh-server        # deixar este PC aceitar ligações
ssh usuario@192.168.1.20               # entrar noutro computador
scp foto.jpg usuario@192.168.1.20:~/   # enviar um arquivo'''),
    dict(id='firewall', palavras='firewall seguranca portas bloquear ufw',
         titulo='Firewall',
         cmd='''sudo apt install ufw
sudo ufw enable
sudo ufw allow ssh
sudo ufw status verbose'''),
    dict(id='rede_pasta', palavras='nas samba smb pasta rede compartilhada partilhada montar servidor',
         titulo='Pastas de rede (NAS, Windows)',
         cmd='''gio mount smb://192.168.1.20/fotos          # pede usuário e senha
ls /run/user/$UID/gvfs/                      # onde aparece
dolphin smb://192.168.1.20/fotos             # ou abrir direto nos Arquivos'''),
    dict(id='sistema', palavras='versao sistema informacao hardware placa video cpu kernel fastfetch',
         titulo='Informações do sistema',
         cmd='''cat /etc/os-release       # versão do CarinaeOS
uname -r                  # versão do kernel
lscpu                     # processador
lspci | grep -i vga       # placa de vídeo
inxi -Fxz                 # tudo (sudo apt install inxi)'''),
    dict(id='drivers', palavras='driver drivers nvidia placa video firmware',
         titulo='Drivers (ex.: NVIDIA)',
         cmd='''sudo apt install nvidia-detect && nvidia-detect   # diz o driver certo
sudo apt install nvidia-driver firmware-misc-nonfree
sudo reboot'''),
    dict(id='flatpak', palavras='flatpak flathub apps lista instalados',
         titulo='Aplicativos do Flathub',
         cmd='''flatpak list --app                 # instalados
flatpak update                     # atualizar
flatpak uninstall --unused         # limpar o que já não é usado'''),
    dict(id='limpar', palavras='limpar limpeza cache espaco liberar lixo temporarios',
         titulo='Libertar espaço',
         cmd='''sudo apt autoremove && sudo apt clean   # pacotes sem uso e downloads antigos
flatpak uninstall --unused
journalctl --vacuum-time=7d             # registos com mais de 7 dias (com sudo)
gio trash --empty                       # esvaziar a lixeira'''),
    dict(id='atalhos', palavras='atalho atalhos tecla teclas kglobalaccel',
         titulo='Atalhos de teclado',
         cmd='''# os atalhos ficam em ~/.config/kglobalshortcutsrc
systemsettings kcm_keys      # abrir a página dos atalhos'''),
    dict(id='terminal', palavras='terminal konsole comandos basicos cd ls pwd navegar',
         titulo='O básico do terminal',
         cmd='''pwd              # onde estou
ls -la           # o que há aqui (incluindo escondidos)
cd ~/Documentos  # entrar numa pasta
cd ..            # voltar uma pasta
man ls           # manual de um comando (q para sair)
history          # comandos que já usou'''),
    dict(id='casa', palavras='home assistant casa luz luzes cena domotica',
         titulo='Home Assistant pelo terminal',
         cmd='''# ligar uma luz (troque o token e a entidade)
curl -X POST -H "Authorization: Bearer SEU_TOKEN" -H "Content-Type: application/json" \\
  -d '{"entity_id": "light.sala"}' http://homeassistant.local:8123/api/services/light/turn_on'''),
    dict(id='ambiente', palavras='gnome xfce plasma ambiente desktop trocar sessao',
         titulo='Instalar outro ambiente de trabalho',
         cmd='''sudo apt install gnome-core          # GNOME
sudo apt install task-xfce-desktop   # XFCE
# depois termine a sessão e escolha o ambiente no canto da tela de entrada'''),
]
