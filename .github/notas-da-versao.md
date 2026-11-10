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
- Eta com um cérebro novo (Qwen3 4B, ou na nuvem com a sua chave) que entende pedidos com várias ações e contexto.
- Visual Vidro: janelas translúcidas, ícones coloridos e o céu real do Atacama com a estrela do CarinaeOS.
- Central CarinaeOS com todas as ferramentas; Casa com painéis montáveis; Calendários Google, iCloud e iCal.
- Cadeado que tranca a própria pasta; etiquetas na barra lateral; menus no GNOME e no XFCE.
- Janelas em zonas, histórico do Ctrl+C, drivers e hardware, sessão sem rastro, modo escuro forçado.
- Fim do retângulo cinzento atrás da Dock; fastfetch com a estrela; janelas de senha com a marca CarinaeOS.

Guia completo no [README](https://github.com/leothemurphy/carinaeos#readme).

<sub>Desenvolvido por Leonardo Mendes e Claude (Anthropic).</sub>
