# 5. Rede, HD na rede e pastas compartilhadas

> **O mais fácil:** Configurações › **Rede** › *Ligar a um servidor* — escreva `192.168.1.20/fotos` (ou `\\nas\fotos`, como no Windows) e clique em *Ligar*. Fica na barra lateral de **Meus documentos**. Para compartilhar uma pasta deste computador: Configurações › **Compartilhamento** › *Ativar* e *Compartilhar uma pasta*.

## Internet: Wi-Fi e cabo

- **Wi-Fi:** ícone de rede na barra de cima › escolha a rede › senha.
- **Cabo:** liga sozinho.
- **Ver o seu IP:** passe o mouse no ícone de rede, ou `ip -br a` no terminal. IP público: `curl ifconfig.me`.
- **IP fixo:** Configurações › Wi-Fi e Internet › (a rede) › IPv4 › Método *Manual*: endereço, máscara
  (`255.255.255.0` ou `/24`), gateway (o router, ex. `192.168.1.1`) e DNS (ex. `1.1.1.1, 8.8.8.8`).
- **Compartilhar a internet (hotspot):** Configurações › Wi-Fi e Internet › ⋮ › *Criar ponto de acesso*.
- **VPN:** Configurações › Wi-Fi e Internet › + › OpenVPN / WireGuard / … (importe o arquivo `.ovpn` ou `.conf`).

Terminal (NetworkManager):

```
$ nmcli device wifi list                       # redes à volta
$ nmcli device wifi connect "Rede" password "senha"
$ nmcli connection show                        # ligações guardadas
$ nmcli radio wifi off / on
$ ping -c 4 google.com                         # testar a ligação
```

## HD na rede (NAS) e pastas compartilhadas do Windows — SMB

A maioria dos NAS (Synology, QNAP, WD My Cloud, TrueNAS, router com disco USB, Raspberry Pi com Samba)
e as pastas compartilhadas do Windows falam **SMB** (também chamado CIFS ou “compartilhamento do Windows”).

### Pelos Arquivos (o mais fácil)

1. Abra os **Arquivos** › **Rede** na barra lateral › *Rede Windows (SMB)* — aparecem os computadores e NAS
   que se anunciam na rede. Ou escreva diretamente o endereço com **Ctrl+L**:
    - `smb://192.168.1.20/` (lista as pastas compartilhadas do aparelho)
    - `smb://192.168.1.20/fotos` (uma pasta)
    - `smb://nas.local/fotos` ou `smb://NOME-DO-PC/Documentos`
2. Quando pedir, escreva **usuário e senha** do NAS (ou do Windows: a conta da Microsoft/local do PC
   que compartilhamento). Marque *Lembrar* para salvar na carteira (KWallet).
3. Para ficar sempre à mão: botão direito na pasta › **Adicionar aos Locais** (aparece na barra lateral),
   ou **Adicionar à Dock**.


### Montar como uma pasta normal (para todos os programas)

Os endereços `smb://` funcionam nos programas do KDE e, graças ao *kio-fuse*, também nos outros quando
abertos a partir dos Arquivos. Para que **qualquer** programa veja o NAS como uma pasta, sempre, desde a inicialização:

```
$ sudo mkdir -p /mnt/nas
$ sudo nano /etc/samba/credenciais-nas        # crie com 3 linhas:
username=SEU_USUARIO
password=SUA_SENHA
domain=WORKGROUP
$ sudo chmod 600 /etc/samba/credenciais-nas    # só o root lê a senha
$ sudo nano /etc/fstab                          # acrescente (uma linha):
//192.168.1.20/fotos  /mnt/nas  cifs  credentials=/etc/samba/credenciais-nas,uid=1000,gid=1000,iocharset=utf8,vers=3.0,_netdev,nofail,x-systemd.automount  0  0
$ sudo systemctl daemon-reload
$ ls /mnt/nas                                   # monta no primeiro acesso
```

- `uid=1000,gid=1000` faz com que os arquivos sejam seus (veja os seus números com `id`).
- `x-systemd.automount` monta só quando a pasta é usada; se a rede faltar, a inicialização não fica parada.
- **Montar só agora, sem fstab:** `sudo mount -t cifs //192.168.1.20/fotos /mnt/nas -o username=SEU_USUARIO,uid=$(id -u),gid=$(id -g)`
- **Sem sudo (como os Arquivos):** `gio mount smb://192.168.1.20/fotos` → fica em `/run/user/1000/gvfs/`.
- **Ver os compartilhamentos de um aparelho:** `smbclient -L //192.168.1.20 -U SEU_USUARIO`

### Quando não liga

| Sintoma | Solução |
|---|---|
| “Não foi possível conectar”, NAS antigo | Muitos NAS antigos só falam **SMB1**. O CarinaeOS já aceita SMB1 (`client min protocol = NT1` em `/etc/samba/smb.conf`); no fstab use `vers=1.0`. Melhor: ative SMB2/3 no NAS. |
| Pede senha sem parar | Confirme usuário/senha no NAS. No Windows use a conta local ou o e-mail da conta Microsoft; compartilhamentos “sem senha” precisam de *Convidado* ativo no Windows. |
| O NAS não aparece em Rede | Escreva o IP diretamente (`smb://192.168.1.20`). Descobrir o IP: na app do router, ou `avahi-browse -art` / `nmap -sn 192.168.1.0/24` (instale `nmap`). |
| “Permission denied” num programa | Monte com `uid=` e `gid=` (acima) ou ajuste as permissões do compartilhamento no NAS. |
| Lento | Prefira cabo; no fstab use `vers=3.1.1`; desative SMB1 no NAS. |
| Funcionou, mas falha na inicialização | Use `_netdev,nofail,x-systemd.automount` no fstab. |

## NFS (NAS com Linux, TrueNAS, Synology com NFS)

```
$ sudo apt install nfs-common
$ showmount -e 192.168.1.20                     # o que o servidor partilha
$ sudo mount -t nfs 192.168.1.20:/volume1/fotos /mnt/nas
# no /etc/fstab:
192.168.1.20:/volume1/fotos  /mnt/nas  nfs  defaults,_netdev,nofail,x-systemd.automount  0  0
```

No NFS as permissões vêm do servidor (o seu uid tem de existir lá ou estar mapeado).

## SSH e SFTP (outro computador Linux, servidor, Raspberry Pi)

- **Nos Arquivos:** `sftp://usuario@192.168.1.30/home/usuario` — pede a senha e mostra as pastas.
- **Terminal remoto:** `ssh usuario@192.168.1.30`
- **Copiar:** `scp arquivo usuario@pc:/destino/` ou `rsync -avP pasta/ usuario@pc:/destino/`
- **Montar como pasta:** `sudo apt install sshfs` e `sshfs usuario@pc:/home/usuario ~/remoto` (desmontar: `fusermount3 -u ~/remoto`).
- **Entrar sem senha (chaves):** `ssh-keygen -t ed25519` e depois `ssh-copy-id usuario@pc`.
- **Ligar o servidor SSH neste PC:** Central › **Acesso remoto (SSH)** › ligar (instala-o se faltar e
  mostra o comando para entrar, ex.: `ssh leo@192.168.1.20`). No terminal: `sudo apt install openssh-server`
  e `sudo systemctl enable --now ssh` (porta 22). Desligue quando não precisar. A senha só se escreve
  no pedido do próprio SSH — nunca numa conversa ou num site.

## WebDAV e nuvens (Nextcloud, ownCloud, Box…)

- Arquivos › Ctrl+L › `webdavs://servidor/remote.php/dav/files/usuario/` (Nextcloud).
- **Nextcloud** e **ownCloud** têm cliente de sincronização (Órbita).
- **Google Drive, OneDrive, Dropbox:** Configurações › Contas online (Google Drive aparece nos Arquivos), ou
  as apps da Órbita (Dropbox, *OneDriver* para o OneDrive), ou **rclone** para tudo
  (`sudo apt install rclone`, `rclone config`, `rclone mount gdrive: ~/GoogleDrive`).

## Compartilhar pastas deste computador

### Para Windows, Mac, celulares e TVs (Configurações › Compartilhamento)

1. **Configurações › Compartilhamento** › ligue **Compartilhar pastas deste computador** (pede a senha de administrador uma vez).
2. Abre-se logo a janela para **escolher a pasta**; escolha também se os outros podem só ver ou também mudar.
3. A pasta aparece na lista, com o endereço para os outros aparelhos:
   `\\NOME-DO-PC\Pasta` (Windows), `smb://IP/Pasta` (Mac: Finder › Ir › Ligar ao servidor; Android: um gestor de
   arquivos com SMB). Também pode compartilhar com o botão direito numa pasta em Meus documentos › *Compartilhar*.

O Windows encontra este PC em *Rede* (o **wsdd2** já vem instalado, e o Avahi para Macs). As pastas abrem sem senha,
como “convidado”. O Windows 11 recente bloqueia convidados; nesse caso, no Windows: *Editar política de grupo* ›
Configuração do computador › Modelos administrativos › Rede › Estação de trabalho Lanman › *Ativar inícios de sessão
de convidado não seguros*. Para usar senha em vez disso: `sudo smbpasswd -a $USER`.

### Acesso remoto por SSH

Configurações › Compartilhamento › **Permitir entrar neste computador por SSH**. Ao ligar, aparecem o **endereço IP**, o
**usuário**, a senha (a mesma com que entra no computador) e os comandos prontos a copiar:
`ssh usuario@IP` (terminal, PowerShell) e `sftp://usuario@IP` (Meus documentos, FileZilla, WinSCP).

### Sem configurar nada

- **KDE Connect** para o celular; **LocalSend** (Órbita) para enviar arquivos entre PC, Mac, Android e iPhone na mesma rede.
- **Servidor rápido de uma pasta** (só leitura, temporário): na pasta, `python3 -m http.server 8000`
  e abra `http://IP-DESTE-PC:8000` no outro aparelho. Ctrl+C para parar.

## Impressoras e scanners na rede

Impressoras modernas (AirPrint/IPP Everywhere) aparecem sozinhas em Configurações › Impressoras.
Ver o capítulo 7.

## Firewall

O Debian não liga uma firewall por padrão. Para ligar uma simples:

```
$ sudo apt install ufw
$ sudo ufw allow from 192.168.1.0/24   # confiar na rede de casa (partilhas, KDE Connect)
$ sudo ufw enable
$ sudo ufw status verbose
```

Para uma página gráfica nas Configurações: `sudo apt install plasma-firewall` (aparece em Configurações › Firewall).

## Diagnóstico de rede

```
$ ip -br a                 # interfaces e IPs
$ ip r                     # rotas (gateway)
$ resolvectl status        # DNS em uso (ou: cat /etc/resolv.conf)
$ ping -c 4 1.1.1.1        # há internet? (por IP)
$ ping -c 4 debian.org     # e DNS?
$ traceroute debian.org    # caminho até lá (sudo apt install traceroute)
$ ss -tulpn                # portas abertas neste PC (sudo para ver os programas)
$ nmcli general status     # estado do NetworkManager
$ sudo systemctl restart NetworkManager
```
