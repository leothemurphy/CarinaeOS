# 8. Hardware e drivers

O Linux traz os drivers dentro do kernel: quase tudo funciona sem instalar nada. As exceções
são algumas placas NVIDIA, firmwares de Wi-Fi/Bluetooth muito recentes e periféricos com software
próprio. **Central › Drivers e hardware** deteta e instala o que falta.

## Ver o que o computador tem

```
$ inxi -Fxz            # resumo completo (sudo apt install inxi)
$ fastfetch            # resumo bonito com a estrela do CarinaeOS
$ lspci -k             # placas internas e o driver em uso
$ lsusb                # aparelhos USB
$ lscpu                # processador
$ free -h              # memória
$ sudo dmidecode -t memory   # módulos de memória
$ lsblk                # discos
$ sensors              # temperaturas (lm-sensors)
$ upower -i $(upower -e | grep BAT)   # bateria (saúde e ciclos)
```

Graficamente: Configurações › Sobre este sistema, e o *Centro de informações* (kinfocenter).

## Placa de vídeo

- **Intel e AMD:** funcionam logo (drivers Mesa). Vulkan também (jogos).
- **NVIDIA:** o driver livre *nouveau* funciona, mas é lento. Para o driver oficial:
  Central › Drivers › NVIDIA › Instalar, ou:

```
$ sudo apt install nvidia-detect && nvidia-detect     # que driver serve
$ sudo apt install nvidia-driver firmware-misc-nonfree
$ sudo reboot
$ nvidia-smi                                          # confirmar
```

  Com *Secure Boot* ligado é preciso inscrever a chave (o instalador pede uma senha e, no arranque
  seguinte, escolhe-se *Enroll MOK*). Placas muito antigas (antes da série 900) usam drivers legados ou o nouveau.
- **Portátil com duas placas (híbrido):** botão direito num aplicativo › *Executar com a placa dedicada*,
  ou `prime-run programa`.

## Monitores

Configurações › Tela: resolução, escala (100–200%), frequência (Hz), HDR, posição, monitor principal,
luz noturna. Teclas de função de projetar costumam funcionar. Terminal: `kscreen-doctor -o`.

## Som

Ícone do som na barra: volume por aplicativo e escolha de saída (colunas, auscultadores, HDMI, Bluetooth).
Configurações › Som para perfis (ex.: HDMI/estéreo/5.1). O sistema de som é o **PipeWire**.

```
$ wpctl status                        # saídas e entradas
$ wpctl set-volume @DEFAULT_AUDIO_SINK@ 50%
$ wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
$ systemctl --user restart pipewire wireplumber   # reiniciar o som se ficar mudo
```

## Bluetooth

Ícone do Bluetooth › Adicionar dispositivo; ponha o aparelho em modo de emparelhamento.
Terminal: `bluetoothctl` → `scan on`, `pair XX:XX…`, `connect XX:XX…`, `trust XX:XX…`.

## Impressoras e scanners

- Impressoras de rede e USB modernas aparecem sozinhas (IPP Everywhere / AirPrint, sem driver).
  Configurações › Impressoras › Adicionar.
- **HP:** `hplip` já vem; `hp-setup` para assistente. **Epson, Canon, Brother:** `printer-driver-all` já vem;
  alguns modelos precisam do driver do site do fabricante (`.deb`).
- **Página web do CUPS:** `http://localhost:631` (gestão avançada de filas).
- **Scanners:** abra o **Skanlite**; os de rede (eSCL/AirScan) funcionam com `sane-airscan`.
  Terminal: `scanimage -L`.

## Impressão digital

Central › Drivers instala `fprintd`; depois Configurações › Usuários › Configurar autenticação por impressão digital.
Serve para entrar, desbloquear e autorizar (sudo/polkit).

## Teclado, rato e touchpad

- Configurações › Teclado (disposição pt / br-abnt2, NumLock ao iniciar, atalhos).
- Configurações › Rato e touchpad (velocidade, rolagem natural, toque para clicar, gestos).
- Gestos do touchpad (Plasma): 3 dedos para cima = Visão geral; 4 dedos para os lados = áreas de trabalho.
- **Logitech:** *Solaar* (Central › Drivers) — bateria, receptor Unifying/Bolt, botões.
- **Ratos de jogo:** *Piper* (libratbag) — DPI, botões, luzes.

## Comandos de jogos

Xbox, PlayStation e 8BitDo funcionam por USB e Bluetooth. Pacote `steam-devices` para o Steam reconhecer tudo.

## Energia

Configurações › Gestão de energia: suspender, brilho, perfis (*Desempenho*, *Equilibrado*, *Poupança*,
também no ícone da bateria). Limite de carga da bateria em portáteis compatíveis (protege a bateria).
