# 13. Resolver problemas

Primeiro passo, sempre: **pergunte à Eta** descrevendo o problema (ou cole a mensagem de erro). Ela consulta
este manual, corre comandos que só leem para diagnosticar e, se não souber, pesquisa na internet.

## Um aplicativo congelou

Clique no X; se não fechar, menu estrela › *Forçar saída*, ou **Ctrl+Esc** (Monitor do sistema) › Terminar.
Terminal: `pkill nome` ou `kill -9 PID`.

## O ecrã inteiro congelou

1. Espere 30 s (pode ser falta de memória).
2. **Ctrl+Alt+F3** → consola de texto. Entre e use `htop` para matar o culpado. **Ctrl+Alt+F2** (ou F1) volta ao gráfico.
3. Reiniciar o ambiente gráfico (Plasma): `systemctl --user restart plasma-plasmashell`.
4. Último recurso: **Alt+PrintScreen + R E I S U B** (capítulo 10).

## A barra de cima ou a Dock desapareceram / estão estranhas

`systemctl --user restart plasma-plasmashell`. Para repor o estilo: Central › Ambiente e estilo › Estilo Mac › Usar este.

## Não arranca / tela preta

- No GRUB, escolha *Opções avançadas* › o kernel anterior.
- Tela preta com NVIDIA: no GRUB carregue **e**, acrescente `nomodeset` à linha `linux`, Ctrl+X; depois instale o driver (capítulo 8).
- Disco com erros: arranque com a pen drive do CarinaeOS e corra `sudo e2fsck -f /dev/sdXN`.
- Recuperar o GRUB (Windows por cima): arranque a pen drive, monte o sistema e reinstale o grub, ou peça ajuda à Eta com a mensagem exata.

## Sem internet

`ping -c 4 1.1.1.1` (há ligação?) e `ping -c 4 debian.org` (há DNS?). Desligue e ligue o Wi-Fi,
`sudo systemctl restart NetworkManager`, reinicie o router. Wi-Fi não aparece: `lspci -k | grep -A3 -i net` e
`sudo dmesg | grep -i firmware` — Central › Drivers instala firmwares em falta.

## Sem som

Ícone do som: a saída certa está escolhida? Não está em mudo? `systemctl --user restart pipewire wireplumber`.
HDMI: Configurações › Som › perfil *HDMI*.

## Não consigo instalar / “apt” dá erro

```
sudo dpkg --configure -a
sudo apt -f install
sudo apt update
```

- “Could not get lock”: outra instalação está a correr (Órbita, Discover, atualizações automáticas); espere ou feche-as.
- Erros de assinatura/repositório: veja os arquivos em `/etc/apt/sources.list.d/` de terceiros (capítulo 9).
- Falta espaço: `df -h`, `sudo apt clean`, esvazie a Lixeira.

## O HD da rede / NAS não liga

Veja a tabela do capítulo 6 (SMB1, senha, IP, permissões).

## O AppImage não abre

Capítulo 7 (FUSE, WebKit, `--appimage-extract-and-run`, correr no terminal para ver o erro).

## A Eta está lenta ou ocupa muita memória

⚙ › Cérebro da Eta › **Leve**, ou **Desligado**, ou um cérebro **na nuvem**. Ela sai da memória sozinha ao fim de 5 minutos sem uso.

## A Casa não liga ao Home Assistant

Confirme o endereço (com `http://` e a porta `:8123`) e crie um token novo. O computador e o Home Assistant
têm de estar na mesma rede (ou use o endereço externo/Nabu Casa).

## O calendário não aparece

Central › Calendários: o endereço iCal tem de ser o **secreto**/público e terminar em `.ics` (ou começar por `webcal://`).
`carinaeos-calendarios sincronizar` no terminal mostra se a transferência falha.

## Esqueci a senha

- **Do usuário:** no GRUB carregue **e**, acrescente `init=/bin/bash` à linha `linux`, Ctrl+X; depois
  `mount -o remount,rw /`, `passwd <usuario>`, e `exec /sbin/init`. (Com o disco cifrado precisa da senha do disco.)
- **De uma pasta trancada (Cadeado):** não há forma de recuperar — é o que a torna segura.

## Recolher informação para pedir ajuda

```
fastfetch
inxi -Fxz
journalctl -b -p err --no-pager | tail -50
sudo dmesg -T | tail -50
```

Cole o resultado na Eta, ou num pedido de ajuda (fórum/issue no GitHub do CarinaeOS).
