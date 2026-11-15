## CarinaeOS — ISO de testes

Baixe **todas as partes** (`.parte00`, `.parte01`, …) e o arquivo `.sha256` para a mesma pasta e junte-as:

**Windows** (Prompt de Comando, dentro da pasta):
```
copy /b CarinaeOS-1.0-amd64.iso.parte00 + CarinaeOS-1.0-amd64.iso.parte01 CarinaeOS-1.0.iso
```
No PowerShell, ponha `cmd /c` antes do mesmo comando.

**macOS / Linux:**
```
cat CarinaeOS-1.0-amd64.iso.parte* > CarinaeOS-1.0.iso
```

Depois, use a ISO numa máquina virtual ou grave-a num pen drive (balenaEtcher ou Rufus).
A sessão de teste entra sozinha, sem senha. Para instalar, abra **Instalar o CarinaeOS** na área de trabalho.

### Novidades desta versão
- **Música** (novo): leitor e biblioteca ligados ao **MPD**. Junte as pastas de música, veja os álbuns com capa e as letras (a linha atual acompanha a música), crie listas e rádios. Cada lista aparece como **fonte** no Home Assistant (integração *Music Player Daemon*, porta 6600) e no `mpc`.
- **Configurações › Dock** (novo): tamanho, ampliação, posição (em baixo, à esquerda, à direita, em cima), esconder automaticamente, e espessura e cor dos separadores.
- **Partilha de pastas** a funcionar: o interruptor liga o Samba e abre logo a escolha da pasta; aparece o endereço para Windows/Mac. O **SSH** ligado mostra IP, utilizador, senha e os comandos `ssh`/`sftp`.
- **Som**: o volume mudado pela Pesquisa (ou pelas teclas) já aparece na barra das Configurações.
- **Energia**: os modos mudam de verdade; os que o computador não tem aparecem como “não disponível” (numa máquina virtual, normalmente não há *Desempenho*).
- **Contas online** sem erro: Google e iCloud pelos Calendários, Nextcloud/ownCloud com entrada na conta, Google Drive em Meus documentos.
- A janela para **escolher foto** da Tela de entrada é a do sistema, com o mesmo visual.

Da rc15: instalação em português de ponta a ponta, janelas maximizadas por baixo da Dock, barra de cima escura, Dock reorganizável com separadores, Pesquisa instantânea, papel de parede animado, Meus documentos como o Explorador, rede como no Fedora.

Da rc12: sem IA, Launchpad em vidro com Deck, Pesquisa como a do Windows (Ctrl+Espaço), Configurações, instalador e configuração inicial ao estilo do Fedora, só o estilo CarinaeOS, e a nebulosa do arranque ao ambiente de trabalho.

Guia completo no [README](https://github.com/leothemurphy/carinaeos#readme).

<sub>Desenvolvido por Leonardo Mendes e Claude (Anthropic).</sub>
