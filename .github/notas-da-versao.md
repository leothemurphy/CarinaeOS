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
- **Barra de cima escura**, sempre legível sobre qualquer papel de parede; os painéis e menus do sistema ficam sempre escuros.
- **Janelas maximizadas ocupam o ecrã todo**, também por baixo da Dock.
- **Launchpad atualiza-se sozinho**: o que instalar (Chrome, Flatpak, .deb, AppImage) aparece logo, com a secção **Instalados recentemente** e o botão *Fixar na Dock*.
- **Slides do instalador novos**, do tamanho certo, a mostrar o Launchpad, a Pesquisa, as Configurações e o Deck.

Da rc12: sem IA, Launchpad em vidro com Deck, Pesquisa como a do Windows (Ctrl+Espaço), Configurações, instalador e configuração inicial ao estilo do Fedora, só o estilo CarinaeOS, e a nebulosa do arranque ao ambiente de trabalho.

Guia completo no [README](https://github.com/leothemurphy/carinaeos#readme).

<sub>Desenvolvido por Leonardo Mendes e Claude (Anthropic).</sub>
