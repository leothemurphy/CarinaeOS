# 11. O terminal: guia e referência de comandos

O terminal (**Konsole**, Ctrl+Alt+T) é a forma mais direta de falar com o sistema. Não é obrigatório
no CarinaeOS — a Eta e as ferramentas gráficas fazem quase tudo — mas é rápido e poderoso.
Peça à Eta “mostra-me os comandos para…” e ela explica cada um.

## O básico

- Escreve-se um **comando**, opções (`-l`, `--help`) e argumentos, e Enter: `ls -l Documentos`
- **Tab** completa nomes de comandos e arquivos (duas vezes mostra as hipóteses). **↑/↓** histórico.
- **Ctrl+C** interrompe; **Ctrl+D** termina a entrada/fecha; **Ctrl+L** limpa; **Ctrl+R** procura no histórico;
  **Ctrl+A / Ctrl+E** início/fim da linha; **Ctrl+U** apaga até ao início; **Ctrl+Shift+C/V** copiar/colar no Konsole.
- `~` é a sua pasta pessoal; `.` a pasta atual; `..` a de cima; `/` a raiz do sistema.
- Nomes com espaços: entre aspas (`"Área de trabalho"`) ou com `\ ` (`Área\ de\ trabalho`).
- `sudo comando` executa como administrador (pede a **sua** senha; fica válida 15 minutos).
- `man comando`, `comando --help`, `tldr comando` (exemplos práticos) para aprender qualquer comando.

## Navegar e ver arquivos

```
pwd                          # onde estou
ls                           # o que há aqui
ls -la                       # tudo, com detalhes e ocultos
ls -lh --sort=size           # por tamanho, legível
ls -lt                       # por data
cd Documentos                # entrar
cd ..                        # subir
cd                           # voltar à pasta pessoal
cd -                         # voltar à pasta anterior
tree -L 2                    # árvore de pastas (sudo apt install tree)
cat arquivo.txt              # mostrar o conteúdo
less arquivo.txt             # ler com paginação (q para sair, / para procurar)
head -n 20 arq / tail -n 20 arq
tail -f /var/log/arq.log     # seguir um arquivo que cresce
file foto.jpg                # que tipo de arquivo é
stat arquivo                 # datas, tamanho, permissões
xdg-open arquivo_ou_pasta    # abrir com o programa padrão
```

## Criar, copiar, mover, apagar

```
mkdir pasta                  # criar pasta
mkdir -p a/b/c               # criar várias de uma vez
touch nota.txt               # criar arquivo vazio (ou atualizar a data)
cp origem destino            # copiar
cp -r pasta/ destino/        # copiar pasta
cp -a origem destino         # copiar mantendo permissões e datas
mv velho novo                # mover ou renomear
rm arquivo                   # apagar (de vez! não vai para a Lixeira)
rm -r pasta                  # apagar pasta e conteúdo (CUIDADO)
rm -i arquivo                # pedir confirmação
gio trash arquivo            # mandar para a Lixeira (mais seguro)
rmdir pasta_vazia
ln -s /destino atalho        # atalho (ligação simbólica)
rename 's/.jpeg$/.jpg/' *.jpeg   # renomear em massa (sudo apt install rename)
```

> **Nunca** corra `rm -rf /`, `rm -rf ~`, `sudo chmod -R 777 /`, `dd` para o disco errado, ou comandos
> copiados da internet que não percebe. A Eta pode explicar qualquer comando antes de o correr.

## Procurar

```
find ~ -name "*.pdf"                    # arquivos por nome
find ~ -iname "*curriculo*"             # sem distinguir maiúsculas
find . -size +500M                      # maiores que 500 MB
find . -mtime -7                        # mudados nos últimos 7 dias
find . -name "*.tmp" -delete            # procurar e apagar
locate nome                             # muito rápido (sudo apt install plocate; sudo updatedb)
grep "texto" arquivo                    # linhas com o texto
grep -ri "texto" pasta/                 # em todos os arquivos, sem maiúsculas
grep -rn --include="*.py" "def " .      # com número de linha, só .py
which firefox                           # onde está o comando
whereis bash
type ll                                 # o que é (alias, função, programa)
```

## Texto

```
echo "olá"                     # escrever
echo "linha" >> arq.txt        # acrescentar ao fim
nano arq.txt                   # editor simples (Ctrl+O grava, Ctrl+X sai)
kate arq.txt                   # editor gráfico
wc -l arq.txt                  # contar linhas (-w palavras, -c bytes)
sort arq | uniq -c | sort -rn  # contar repetidos
cut -d, -f2 dados.csv          # 2.ª coluna de um CSV
awk '{print $1, $3}' arq       # colunas 1 e 3
sed 's/velho/novo/g' arq       # substituir (mostra); sed -i ... grava no arquivo
tr 'a-z' 'A-Z' < arq           # maiúsculas
diff a.txt b.txt               # diferenças (diff -u, ou meld para gráfico)
column -t -s, dados.csv        # tabela alinhada
jq . dados.json                # formatar/consultar JSON (sudo apt install jq)
iconv -f latin1 -t utf-8 a > b # converter codificação
```

## Redirecionar e encadear

```
comando > arq          # saída para arquivo (substitui)
comando >> arq         # acrescenta
comando 2> erros.txt   # só os erros
comando &> tudo.txt    # saída e erros
comando < entrada.txt  # ler de um arquivo
a | b                  # a saída de a entra em b (pipe): ls | wc -l
a && b                 # b só se a correu bem
a || b                 # b só se a falhou
a ; b                  # um depois do outro
comando &              # em segundo plano (jobs, fg, bg para gerir)
nohup comando &        # continua mesmo fechando o terminal
$(comando)             # usar o resultado: echo "Hoje é $(date +%A)"
comando | tee arq      # ver e gravar ao mesmo tempo
xargs                  # passar linhas como argumentos: find . -name "*.log" | xargs rm
```

## Permissões e donos

Cada arquivo tem dono, grupo e permissões `r` (ler), `w` (escrever), `x` (executar) para
**u**suário, **g**rupo e **o**utros: `-rwxr-xr--`.

```
ls -l arquivo
chmod +x script.sh            # tornar executável
chmod u+w,go-w arq            # dono pode escrever, os outros não
chmod 644 arq                 # rw-r--r-- (arquivos normais)
chmod 755 pasta               # rwxr-xr-x (pastas e programas)
chmod 600 segredo             # só o dono
chmod -R u+rwX pasta          # recursivo
sudo chown $USER:$USER arq    # passar a ser seu
sudo chown -R $USER: pasta
getfacl / setfacl             # permissões finas (ACL)
lsattr / chattr +i arq        # atributo imutável (nem o root apaga)
```

## Processos e desempenho

```
htop                     # monitor interativo (F9 matar, F6 ordenar; sudo apt install htop)
top                      # o clássico
btop                     # monitor bonito (sudo apt install btop)
ps aux                   # todos os processos
ps aux | grep firefox
pgrep -a firefox         # PID e comando
kill PID                 # pedir para terminar
kill -9 PID              # forçar
pkill firefox            # por nome
killall firefox
xkill                    # clicar numa janela para a matar (X11)
nice -n 10 comando       # correr com menos prioridade
renice 10 -p PID
uptime                   # há quanto tempo está ligado e carga
free -h                  # memória
vmstat 1                 # memória/CPU a cada segundo
iostat -x 1              # discos (sudo apt install sysstat)
iotop                    # quem escreve no disco (sudo)
time comando             # quanto tempo demora
watch -n 2 comando       # repetir a cada 2 s
```

## Sistema e hardware

```
fastfetch                       # resumo com a estrela do CarinaeOS
uname -a; cat /etc/os-release
hostnamectl                     # nome, sistema, kernel
lscpu; nproc                    # processador; núcleos
free -h; lsblk; df -h
lspci; lsusb; inxi -Fxz
sensors                         # temperaturas
sudo dmesg -T | tail            # mensagens do kernel
journalctl -b -p err            # erros deste arranque
date; cal; timedatectl
whoami; id; groups; w; last     # usuários e sessões
env; echo $PATH                 # variáveis de ambiente
history | tail -20
```

## Discos

```
lsblk -f                         # discos, partições, sistemas, UUIDs
df -h                            # espaço
du -sh pasta; du -h --max-depth=1 | sort -h
ncdu                             # navegar pelo espaço (sudo apt install ncdu)
findmnt                          # o que está montado onde
sudo fdisk -l                    # tabelas de partições
sudo parted /dev/sdb print
udisksctl mount -b /dev/sdb1     # montar sem sudo
sudo mount /dev/sdb1 /mnt; sudo umount /mnt
sudo blkid                       # UUIDs
sudo e2fsck -f /dev/sdb1         # verificar ext4 (desmontado!)
sudo smartctl -a /dev/sda        # saúde do disco (sudo apt install smartmontools)
sudo fstrim -av                  # TRIM em SSD (o sistema já faz semanalmente)
sudo dd if=img.iso of=/dev/sdX bs=4M status=progress oflag=sync   # gravar ISO (APAGA o destino)
sudo cryptsetup luksOpen /dev/sdb1 cofre   # abrir disco cifrado
```

## Rede

```
ip -br a                          # IPs
ip r                              # gateway
nmcli device wifi list            # redes Wi-Fi
nmcli device wifi connect "Rede" password "senha"
ping -c 4 1.1.1.1
curl -I https://debian.org        # cabeçalhos de um site
curl -O https://site/arquivo.zip  # baixar
wget -c https://site/arquivo.iso  # baixar (retoma com -c)
dig debian.org / host debian.org  # DNS (sudo apt install dnsutils)
ss -tulpn                         # portas abertas
traceroute debian.org; mtr debian.org
nmap -sn 192.168.1.0/24           # aparelhos na rede (sudo apt install nmap)
ssh usuario@pc; scp; rsync -avP origem destino
smbclient -L //nas -U usuario     # partilhas SMB
gio mount smb://nas/pasta
curl ifconfig.me                  # IP público
speedtest-cli                     # velocidade (sudo apt install speedtest-cli)
```

## Pacotes e programas

```
sudo apt update && sudo apt full-upgrade
apt search termo; apt show pacote
sudo apt install pacote; sudo apt remove pacote; sudo apt autoremove
sudo apt install ./arquivo.deb
dpkg -l | grep nome; dpkg -L pacote; dpkg -S /caminho
flatpak search x; flatpak install flathub id; flatpak update; flatpak list
chmod +x app.AppImage && ./app.AppImage
```

## Serviços, arranque e registos (systemd)

```
systemctl status serviço
sudo systemctl restart serviço
sudo systemctl enable --now serviço
systemctl --failed
journalctl -u serviço -f
journalctl -b -1 -p err           # erros do arranque anterior
systemd-analyze blame
systemctl list-timers             # tarefas agendadas
```

## Usuários

```
sudo adduser nome; sudo deluser nome
sudo usermod -aG grupo nome       # sudo, dialout, lp, docker…
passwd; sudo passwd nome
su - nome                         # trocar de usuário
sudo -i                           # shell de root
```

## Comprimir e arquivar

```
tar -czf a.tar.gz pasta/          # criar gz
tar -cJf a.tar.xz pasta/          # criar xz (menor)
tar --zstd -cf a.tar.zst pasta/   # zstd (rápido)
tar -xf arquivo.tar.*             # extrair qualquer
tar -tf arquivo.tar.gz            # ver o conteúdo
zip -r a.zip pasta; unzip a.zip; unzip -l a.zip
7z a a.7z pasta; 7z x a.7z        # (sudo apt install 7zip)
unrar x a.rar                     # (sudo apt install unrar-free)
gzip / gunzip / xz / zstd arquivo
```

## Agendar tarefas

```
crontab -e                         # editar as suas tarefas
# min hora dia mês dia_semana comando
0 3 * * * rsync -a ~/Documentos /media/backup/   # todos os dias às 03:00
@reboot ~/meu-script.sh
crontab -l                         # listar
at 18:00                           # uma vez só (sudo apt install at)
systemd-run --user --on-calendar="*-*-* 09:00" notify-send "Bom dia"
```

## Imagem, som, vídeo e PDF

```
ffmpeg -i video.mov video.mp4                    # converter vídeo
ffmpeg -i video.mp4 -vn -c:a mp3 audio.mp3       # extrair o áudio
ffmpeg -i in.mp4 -ss 00:01:00 -t 30 -c copy corte.mp4   # cortar 30 s
ffmpeg -i in.mp4 -vf scale=1280:-2 menor.mp4     # reduzir
convert foto.png foto.jpg                        # ImageMagick: converter
convert foto.jpg -resize 50% menor.jpg
mogrify -resize 1920x1080 *.jpg                  # em massa
pdftotext doc.pdf                                # texto de um PDF
pdfunite a.pdf b.pdf junto.pdf                   # juntar PDFs
pdfseparate doc.pdf p-%d.pdf                     # separar páginas
qpdf --encrypt senha senha 256 -- in.pdf out.pdf # PDF com senha
tesseract imagem.png saida -l por                # OCR (texto de imagem)
yt-dlp URL                                       # baixar vídeo (sudo apt install yt-dlp)
```

## Git (programação)

```
git clone URL; git status; git add .; git commit -m "msg"; git push; git pull
git log --oneline; git diff; git branch; git switch -c nova
```

## Variáveis, aliases e o seu terminal

```
export NOME=valor                 # variável nesta sessão
echo $HOME $USER $PATH
alias ll='ls -lah'                # atalho (permanente: acrescente ao ~/.bashrc)
nano ~/.bashrc && source ~/.bashrc
export PATH="$HOME/bin:$PATH"     # os seus scripts em ~/bin
```

## O seu primeiro script

```bash
#!/bin/bash
# copia.sh — copia os Documentos para o disco externo
DESTINO="/media/$USER/Backup"
if [ -d "$DESTINO" ]; then
    rsync -a --delete ~/Documentos/ "$DESTINO/Documentos/"
    notify-send "Cópia feita ✓"
else
    notify-send "Ligue o disco Backup"
fi
```

`chmod +x copia.sh` e `./copia.sh`. Ciclos: `for f in *.png; do convert "$f" "${f%.png}.jpg"; done`.

## Comandos do CarinaeOS

| Comando | O que faz |
|---|---|
| `carinaeos-eta "pergunta"` | pergunta à Eta (abre a janela) |
| `carinaeos-eta --ouvir` | Eta a ouvir (voz) |
| `carinaeos-eta --arquivo doc.pdf` | enviar um arquivo à Eta |
| `carinaeos-central [página]` | Central (calendarios, janelas, drivers, privacidade, entrada) |
| `carinaeos-supernova` | personalização |
| `carinaeos-orbita` | loja de aplicativos |
| `carinaeos-casa` | Home Assistant |
| `carinaeos-ambientes` | estilos Mac/Windows, GNOME, XFCE |
| `carinaeos-cadeado trancar\|abrir <pasta>` | trancar/abrir com senha |
| `carinaeos-cadeado aplicativos` | aplicativos com senha |
| `carinaeos-etiquetas pôr <cor> <arquivo>` / `tirar` / `listar` | etiquetas |
| `carinaeos-calendarios sincronizar` | atualizar os calendários iCal |
| `carinaeos-fundo <imagem>` / `--proximo` | papel de parede (Plasma, GNOME, XFCE) |
| `carinaeos-ceu-vivo` | papel de parede que muda ao longo do dia |
| `carinaeos-appimage <arquivo.AppImage>` | instalar um AppImage no menu |
| `carinaeos-dock-adicionar <app ou pasta>` | fixar na Dock |
| `carinaeos-boasvindas` | o passeio de boas-vindas |
| `fastfetch` | resumo do sistema com a estrela |
