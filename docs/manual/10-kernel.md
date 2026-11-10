# 10. O kernel Linux

O **kernel** (núcleo) é o programa que fala diretamente com o hardware: gere a memória, os processos,
os discos e sistemas de arquivos, a rede, o som, a energia, e traz os drivers. Tudo o resto (systemd,
o Plasma, os aplicativos) corre por cima dele. O CarinaeOS usa o kernel **Linux 6.12 LTS** do Debian 13
(suporte longo, atualizações de segurança regulares).

```
$ uname -r            # versão em uso (ex.: 6.12.116+deb13-amd64)
$ uname -a            # tudo: versão, data, arquitetura
$ cat /proc/version
$ ls /boot            # kernels instalados (vmlinuz-*) e initramfs (initrd.img-*)
```

## O que o kernel faz (e onde se vê)

| Função | Como ver / mexer |
|---|---|
| **Processos e escalonamento** (quem usa o processador) | `ps aux`, `top`/`htop`, `nice`, `renice`, `chrt` |
| **Memória** (RAM, swap, cache) | `free -h`, `cat /proc/meminfo`, `vmstat 1`, `swapon --show` |
| **Drivers / módulos** | `lsmod`, `modinfo`, `modprobe`, `lspci -k` |
| **Sistemas de arquivos** (ext4, Btrfs, XFS, NTFS3, exFAT, FAT, ISO…) | `mount`, `findmnt`, `cat /proc/filesystems` |
| **Rede** (TCP/IP, Wi-Fi, firewall nftables) | `ip`, `ss`, `nft list ruleset` |
| **Dispositivos** (udev cria `/dev/*`) | `ls /dev`, `udevadm monitor`, `udevadm info /dev/sda` |
| **Energia** (suspender, frequência do CPU) | `cat /sys/power/state`, `cpupower frequency-info` |
| **Segurança** (permissões, namespaces, cgroups, AppArmor, seccomp) | `aa-status` (sudo), `cat /proc/self/cgroup` |
| **Mensagens** | `sudo dmesg -T`, `journalctl -k` |

## Módulos (drivers)

Os drivers são **módulos** carregados quando o hardware aparece.

```
$ lsmod                          # módulos carregados
$ modinfo iwlwifi                # informação de um módulo (parâmetros, firmware)
$ sudo modprobe nome             # carregar
$ sudo modprobe -r nome          # descarregar
$ lspci -k                       # que driver usa cada placa
```

- **Impedir um módulo** (ex.: o nouveau com a NVIDIA oficial): criar `/etc/modprobe.d/blacklist-nome.conf`
  com `blacklist nome` e depois `sudo update-initramfs -u`.
- **Opções de um módulo:** `/etc/modprobe.d/opcoes.conf` com `options snd_hda_intel power_save=0`.
- **Carregar sempre no arranque:** uma linha com o nome em `/etc/modules-load.d/meus.conf`.
- **Firmware** (código que alguns aparelhos precisam): em `/lib/firmware`, dos pacotes `firmware-*`.
  `sudo dmesg | grep -i firmware` mostra se falta algum.

## /proc e /sys — o kernel como arquivos

```
$ cat /proc/cpuinfo              # processador
$ cat /proc/meminfo              # memória
$ cat /proc/cmdline              # parâmetros com que o kernel arrancou
$ cat /proc/partitions
$ cat /proc/<PID>/status         # um processo
$ ls /sys/class/net              # interfaces de rede
$ cat /sys/class/power_supply/BAT0/capacity          # bateria em %
$ cat /sys/class/backlight/*/brightness               # brilho
$ cat /sys/block/sda/queue/rotational                 # 1 = disco rígido, 0 = SSD
```

## sysctl — ajustes do kernel em funcionamento

```
$ sysctl -a | less                       # todos
$ sysctl vm.swappiness                   # quanto o sistema usa a swap (padrão 60)
$ sudo sysctl vm.swappiness=10           # mudar até reiniciar
# permanente: criar /etc/sysctl.d/99-meu.conf com:
vm.swappiness = 10
$ sudo sysctl --system                   # aplicar os arquivos
```

Exemplos úteis: `fs.inotify.max_user_watches = 524288` (programas que vigiam muitos arquivos, como o VS Code),
`net.ipv4.ip_forward = 1` (encaminhar tráfego, routers/VPN), `kernel.sysrq = 1` (teclas mágicas).

## Parâmetros de arranque (GRUB)

Editar `/etc/default/grub`, linha `GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"`, e depois `sudo update-grub`.
Exemplos:

| Parâmetro | Para quê |
|---|---|
| `quiet splash` | arranque silencioso com o logotipo (padrão) |
| `nomodeset` | arrancar com vídeo básico quando a placa dá tela preta |
| `nvidia-drm.modeset=1` | NVIDIA no Wayland (o driver Debian já liga) |
| `mem_sleep_default=deep` | suspensão mais profunda em portáteis que gastam bateria suspensos |
| `amd_pstate=active` | gestão de energia moderna nos AMD Ryzen |
| `i915.enable_psr=0` | corrigir cintilação em ecrãs Intel |
| `pcie_aspm=off` | resolver alguns problemas de Wi-Fi/NVMe a desligar |

Também se pode editar só para um arranque: no menu do GRUB carregue **e**, mude a linha `linux` e **Ctrl+X**.
`GRUB_TIMEOUT=5` no mesmo arquivo define quanto tempo o menu fica visível.

## initramfs

Pequeno sistema que o kernel usa no arranque para encontrar o disco (também o cifrado). Atualiza-se sozinho;
à mão: `sudo update-initramfs -u` (o kernel atual) ou `-u -k all`.

## Kernels instalados, mais novos e remover antigos

- O Debian mantém o kernel atual e o anterior; escolha outro no GRUB › *Opções avançadas*.
- **Kernel mais novo** (hardware muito recente): `sudo apt install -t trixie-backports linux-image-amd64`
  (depois de ligar os backports, capítulo 9).
- Remover antigos: `sudo apt autoremove --purge`.

## Swap e zram

- `swapon --show` mostra a swap. Num SSD com pouca RAM, a **zram** (swap comprimida na memória) ajuda:
  `sudo apt install systemd-zram-generator` e reiniciar.
- Arquivo de swap: `sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`
  (e no fstab: `/swapfile none swap sw 0 0`).

## Teclas mágicas (SysRq) — quando tudo congela

Com `kernel.sysrq=1`: segure **Alt+PrintScreen** e escreva devagar **R E I S U B** — devolve o teclado,
termina os programas, grava os discos, desmonta e reinicia, sem estragar arquivos.
Antes disso, tente **Ctrl+Alt+F3** (consola de texto) e `htop` para matar o programa culpado.

## Informação sobre o kernel

`man 7 kernel-command-line`, `/usr/share/doc/linux-image-*/`, docs.kernel.org, kernelnewbies.org (o que muda em cada versão).
