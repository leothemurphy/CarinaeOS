# 9. O Debian por baixo

O CarinaeOS é o **Debian 13 “trixie”** com outro visual, ferramentas e a Eta. Tudo o que vale para o
Debian vale aqui: os mesmos pacotes, repositórios, comandos e documentação (wiki.debian.org).

## Versões do Debian

| Versão | Nome | Situação |
|---|---|---|
| 11 | bullseye | antiga (oldoldstable, só suporte LTS) |
| 12 | bookworm | oldstable |
| **13** | **trixie** | **stable — a do CarinaeOS** |
| 14 | forky | testing (em preparação) |
| — | sid | unstable (sempre em desenvolvimento) |

A *stable* recebe atualizações de segurança e correções durante cerca de 3 anos, mais 2 de LTS.
Ver a versão: `cat /etc/debian_version`, `cat /etc/os-release`, `lsb_release -a`.

## Repositórios

Os programas vêm dos repositórios definidos em `/etc/apt/sources.list` e/ou `/etc/apt/sources.list.d/*.sources`.
No formato novo (deb822):

```
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
```

- **main**: software livre. **contrib**: livre mas depende de não livre. **non-free**: proprietário
  (ex.: driver NVIDIA). **non-free-firmware**: firmwares (Wi-Fi, placas de vídeo).
- **trixie-updates**: correções que não esperam pela próxima versão pontual.
- **trixie-security**: atualizações de segurança.
- **trixie-backports**: versões mais novas de alguns programas, recompiladas para a stable
  (acrescente `trixie-backports` em *Suites* e instale com `sudo apt install -t trixie-backports pacote`).

Repositórios de terceiros (Chrome, VS Code…) ficam em `/etc/apt/sources.list.d/` com a chave em
`/usr/share/keyrings/` ou `/etc/apt/keyrings/`. **Não misture** repositórios de Ubuntu ou de outra versão
do Debian: é a causa número um de sistemas partidos.

## apt, dpkg e companhia

- **apt** — instala, remove e atualiza resolvendo dependências (capítulo 7).
- **dpkg** — a base: instala `.deb` sem resolver dependências e consulta o que está instalado.

```
$ dpkg -l | grep firefox            # está instalado? que versão?
$ dpkg -L firefox-esr               # que arquivos o pacote instalou
$ dpkg -S /usr/bin/konsole          # que pacote tem este arquivo
$ apt-cache policy firefox-esr      # versões disponíveis e de onde vêm
$ apt-cache depends gimp            # de que depende
$ apt-cache rdepends gimp           # quem depende dele
$ apt-mark hold pacote              # impedir que seja atualizado
$ apt-mark unhold pacote
$ apt-mark showmanual               # pacotes instalados à mão
$ sudo apt-get changelog pacote     # o que mudou
$ zcat /usr/share/doc/pacote/changelog.Debian.gz | head
$ less /var/log/apt/history.log     # histórico do que foi instalado/removido
```

## Atualizações

- A Eta e a Órbita avisam e instalam (“tem atualizações?”). Também Configurações › Atualizações (Discover em modo atualização).
- Terminal: `sudo apt update && sudo apt full-upgrade && flatpak update`.
- **Automáticas de segurança:** `sudo apt install unattended-upgrades && sudo dpkg-reconfigure unattended-upgrades`.
- **Mudança de versão** (13 → 14, quando sair): trocar `trixie` por `forky` nas fontes e `full-upgrade`.
  No CarinaeOS espere pela ISO/instruções do CarinaeOS, que acompanham essa mudança.

## Arquivos de configuração importantes

| Arquivo | Para quê |
|---|---|
| `/etc/fstab` | discos montados no arranque |
| `/etc/hostname`, `/etc/hosts` | nome do computador e nomes locais |
| `/etc/default/grub` | opções de arranque (depois `sudo update-grub`) |
| `/etc/apt/` | repositórios e preferências do apt |
| `/etc/samba/smb.conf` | partilhas SMB |
| `/etc/sudoers` | quem pode usar sudo (edite só com `sudo visudo`) |
| `/etc/systemd/` | serviços e configurações do systemd |
| `/etc/sddm.conf.d/` | tela de entrada |
| `/etc/os-release` | identificação do sistema |
| `~/.config/` | configurações dos seus aplicativos |
| `~/.local/share/` | dados dos seus aplicativos |
| `~/.bashrc` | o seu terminal (aliases, PATH) |

## systemd: serviços, arranque e registos

```
$ systemctl status ssh                 # estado de um serviço
$ sudo systemctl start|stop|restart ssh
$ sudo systemctl enable --now ssh      # ligar e arrancar sempre
$ sudo systemctl disable --now ssh
$ systemctl list-units --type=service --state=running
$ systemctl --failed                   # o que falhou
$ systemctl --user status pipewire     # serviços do seu usuário
$ systemd-analyze blame                # o que atrasa o arranque
$ journalctl -b                        # registos deste arranque
$ journalctl -b -1 -p err              # erros do arranque anterior
$ journalctl -u NetworkManager -f      # seguir os registos de um serviço
$ journalctl --vacuum-time=2weeks      # limpar registos antigos (sudo)
$ hostnamectl set-hostname novo-nome   # mudar o nome do computador
$ timedatectl                          # data, hora e fuso
$ localectl                            # idioma e teclado do sistema
```

## Usuários, grupos e sudo

```
$ id                                  # o seu usuário e grupos
$ sudo adduser maria                  # novo usuário
$ sudo usermod -aG sudo maria         # dar permissões de administrador
$ sudo usermod -aG dialout,lp maria   # porta série (impressoras 3D/Arduino), impressoras
$ sudo deluser --remove-home maria
$ passwd                              # mudar a sua senha
$ sudo -i                             # terminal como root (cuidado)
```

## Documentação

`man comando` (manual completo; `q` para sair), `comando --help`, `tldr comando` (exemplos;
`sudo apt install tldr`), `/usr/share/doc/<pacote>/`, wiki.debian.org, debian-handbook.info
(livro oficial *The Debian Administrator’s Handbook*), e este manual em `/usr/share/doc/carinaeos/manual`.
