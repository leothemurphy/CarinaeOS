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
- **Launchpad novo**, em vidro fosco: categorias em cartões coloridos, Todos, Favoritos, Mais usados, e o detalhe de cada aplicativo (descrição, Abrir, ações rápidas, Fixar na Dock).
- **Deck**: botões grandes para as ações do dia a dia (captura, terminal, transferências, bloquear…), com os seus aplicativos, comandos e sites.
- **Pesquisa** (Ctrl+Espaço ou a lupa), no modelo da nova pesquisa do Windows: aplicativos, arquivos indexados, configurações e ações ali mesmo (volume, brilho, tema, Wi-Fi, janelas), com correção de erros.
- **Configurações** próprias, **instalador** e **configuração inicial** no estilo do Fedora.
- **Só o estilo CarinaeOS** (saíram GNOME, XFCE e Windows 11) e aplicativos com nomes simples, sem “KDE” nem “Debian”.
- **Acesso remoto (SSH)** com um interruptor na Central (desligado por omissão).
- **Novo papel de parede**: nebulosa violeta sobre um lago espelhado (duas versões), também na tela de entrada e nas janelas de senha.
- **A IA (Eta) saiu do sistema**: menos memória ocupada, ISO mais leve. O Manual continua, com pesquisa.

Guia completo no [README](https://github.com/leothemurphy/carinaeos#readme).

<sub>Desenvolvido por Leonardo Mendes e Claude (Anthropic).</sub>
