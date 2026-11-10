# 5. Arquivos e discos

## O gerenciador de arquivos (Arquivos / Dolphin)

- **Barra lateral:** Início, Área de trabalho, Documentos, Downloads, Música, Imagens, Vídeos, Lixeira,
  as etiquetas coloridas, **Rede** e os **Dispositivos** (discos, pen drives, telemóveis).
- **Ver:** ícones, detalhes ou colunas (botões no topo). **F3** divide a janela em duas (ótimo para copiar).
- **Ctrl+H** mostra/esconde arquivos ocultos (os que começam por `.`).
- **Ctrl+L** escreve um endereço: `/etc`, `~/Projetos`, `smb://nas/fotos`, `sftp://pc`, `trash:/`, `recentlyused:/`.
- **Ctrl+F** procura; **F4** abre um terminal embutido na pasta atual.
- **Pré-visualização:** espaço ou F11 (painel de informações).
- **Botão direito:** Comprimir/Extrair (Ark), Trancar com senha, Etiquetas, Perguntar à Eta, Adicionar à Dock,
  Abrir com…, Partilhar, Propriedades (permissões).
- **Abrir como administrador:** não abra o Dolphin com sudo; use o endereço `admin:/` (ex.: `admin:/etc`).

## Pen drives, HD externos e cartões

Ao ligar, aparece uma notificação e o disco surge em *Dispositivos*. Clique para o abrir (montar).
Antes de tirar, clique no ⏏ (ejetar) para gravar tudo com segurança. A Eta faz: “abre o HD externo”,
“tira o pen drive”.

- **HD cifrado (LUKS/BitLocker):** ao abrir pede a senha. BitLocker funciona se tiver a chave de recuperação ou a senha.
- **Formatos:** lê e escreve NTFS (Windows), exFAT e FAT32 (pen drives, câmaras), ext4 (Linux), Btrfs e XFS.
  HFS+ (Mac) só leitura. APFS precisa de ferramentas extra.
- **Formatar:** abra o **Gerenciador de partições** (KDE Partition Manager), escolha o disco, botão direito ›
  Formatar. Para usar em Windows e Mac: **exFAT**. Só em Linux: **ext4**.
- **Pelo terminal:**

```
$ lsblk -f                         # discos, partições, formatos e onde estão montados
$ udisksctl mount -b /dev/sdb1      # montar sem sudo (fica em /media/<usuario>/…)
$ udisksctl unmount -b /dev/sdb1
$ udisksctl power-off -b /dev/sdb   # desligar o disco para o tirar
$ udisksctl unlock -b /dev/sdb1     # abrir um disco cifrado (pede a senha)
$ sudo mkfs.exfat -n PEN /dev/sdb1  # formatar em exFAT (APAGA TUDO)
$ sudo mkfs.ext4 -L Dados /dev/sdb1 # formatar em ext4 (APAGA TUDO)
```

## Discos internos montados sempre (fstab)

Para um segundo disco interno aparecer sempre no mesmo sítio ao ligar:

```
$ sudo mkdir -p /mnt/dados
$ lsblk -f                    # copie o UUID da partição
$ sudo nano /etc/fstab        # acrescente uma linha:
UUID=1234-ABCD  /mnt/dados  ext4  defaults,nofail  0  2
$ sudo systemctl daemon-reload && sudo mount -a   # testar sem reiniciar
```

Para NTFS use `ntfs3 defaults,nofail,uid=1000,gid=1000` em vez de `ext4 defaults,nofail`.
**`nofail`** evita que o PC fique parado no arranque se o disco faltar.

## Espaço em disco

- *Filelight* (procure no Launchpad) mostra num gráfico o que ocupa espaço.
- Terminal: `df -h` (espaço por disco), `du -sh ~/* | sort -h` (tamanho das pastas),
  `ncdu ~` (navegar pelo espaço, instale com `sudo apt install ncdu`).
- Libertar: esvaziar a Lixeira, `sudo apt clean` (cache de pacotes), `flatpak uninstall --unused`,
  `journalctl --vacuum-size=200M` (registos antigos, com sudo).

## Lixeira

Apagar envia para a Lixeira; **Shift+Delete** apaga de vez. Restaurar: abra a Lixeira › botão direito › Restaurar.
Terminal: `gio trash arquivo` (para a lixeira), `gio trash --empty`.

## Cópias de segurança

- **Kup** (Configurações › Cópias de segurança): cópias automáticas para um disco externo, por versões.
- **Déjà Dup** ou **Pika Backup** (na Órbita) para quem prefere algo mais simples.
- Terminal: `rsync -aAXv --delete ~/Documentos/ /media/<usuario>/Backup/Documentos/` (espelho).
- Para o sistema inteiro: **Timeshift** (na Órbita) cria “pontos de restauro” antes de mudanças grandes.

## Arquivos comprimidos

Ark (botão direito › Comprimir / Extrair aqui) lida com zip, 7z, rar, tar.gz, tar.xz, zst…

```
$ tar -czf copia.tar.gz pasta/   # criar .tar.gz
$ tar -xf copia.tar.gz           # extrair (qualquer tar)
$ zip -r copia.zip pasta/        # criar zip
$ unzip copia.zip                # extrair zip
$ 7z x arquivo.7z                # extrair 7z (sudo apt install 7zip)
```

## Telemóveis

- **Android:** ligue por cabo e escolha *Transferência de arquivos* no telemóvel; aparece nos Dispositivos.
  Melhor ainda: **KDE Connect** (Órbita + app no telemóvel) para partilhar arquivos, notificações,
  área de transferência e controlar o PC pela rede.
- **iPhone:** fotos por cabo (aparece como câmara). Para arquivos, use a nuvem ou o KDE Connect.
