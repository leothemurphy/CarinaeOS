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
- **Janelas maximizadas ocupam o ecrã todo**, por baixo da Dock (agora a sério), e a **barra de cima é escura** e legível.
- **Dock reorganizável**: arraste os ícones para os lados; botão direito › *Adicionar separador à direita* para separar por tipos.
- **Pesquisa instantânea** com Ctrl+Espaço (fica pronta em segundo plano desde que entra).
- **Papel de parede animado** (padrão): a nebulosa com estrelas a cintilar, estrelas cadentes e reflexos no lago — duas cenas animadas e as duas fixas, em Configurações › Aparência.
- **Meus documentos** (o gestor de arquivos) com a barra lateral como a do Explorador do Windows: *Acesso rápido*, *Este computador*, *Rede*.
- **Rede como no Fedora**: Configurações › Rede › *Ligar a um servidor* (192.168.1.20/fotos, \\\\nas\\fotos, sftp://…) e *Procurar computadores e NAS*; Configurações › Partilha › *Partilhar uma pasta*.
- **Janela de senha** com uma frase simples (ex.: “Instalar o aplicativo gridcraft”) e os detalhes técnicos escondidos.
- Slides do instalador mais lentos (20 s cada) e janela do instalador mais pequena; nome do computador automático.

Da rc12: sem IA, Launchpad em vidro com Deck, Pesquisa como a do Windows (Ctrl+Espaço), Configurações, instalador e configuração inicial ao estilo do Fedora, só o estilo CarinaeOS, e a nebulosa do arranque ao ambiente de trabalho.

Guia completo no [README](https://github.com/leothemurphy/carinaeos#readme).

<sub>Desenvolvido por Leonardo Mendes e Claude (Anthropic).</sub>
