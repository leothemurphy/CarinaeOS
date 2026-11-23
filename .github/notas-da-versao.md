## CarinaeOS 1.0 beta

Debian 13 com um **ambiente de trabalho novo, feito de raiz**: a **Gravidade** (gestor de janelas), a **Aurora**
(barra, Dock, Launchpad e área de trabalho) e os **apps Carinae**. Não é um tema do KDE nem do GNOME.

### Baixar e juntar
Baixe **todas as partes** (`.parte00`, `.parte01`, …) e o `.sha256` para a mesma pasta e junte-as:

**Windows** (no `cmd`, dentro da pasta):
```
copy /b CarinaeOS-1.0-amd64.iso.parte00 + CarinaeOS-1.0-amd64.iso.parte01 CarinaeOS-1.0-amd64.iso
```
No PowerShell, ponha `cmd /c` antes do mesmo comando.

**macOS / Linux:**
```
cat CarinaeOS-1.0-amd64.iso.parte* > CarinaeOS-1.0-amd64.iso
```

Depois, use a ISO numa máquina virtual ou grave-a num pen drive (balenaEtcher ou Rufus, modo DD).
A sessão de experimentar entra sozinha. Para instalar, abra **Instalar o CarinaeOS**, o primeiro ícone da Dock.
Funciona com UEFI e com BIOS antigo, e instala ao lado do Windows.

### Novidades
- Papel de parede **Fusão**, criado para o CarinaeOS, até 8K.
- **Launchpad**: aplicativos instalados depois ficam em **Novos aplicativos** até escolher o ambiente.
- **Dock**: troca de modelo nas Configurações e a luz dourada ligada de origem.
- **Sem restos do KDE**: tudo abre os apps Carinae.
- Placas **NVIDIA antigas** (Kepler) pela Central, sem tela preta no arranque.
- Pastas de rede que não deixam o sistema lento quando o outro computador está desligado.

Quer só o ambiente noutra distribuição (Debian, Ubuntu, Fedora, Arch, openSUSE)? Veja o pacote
`carinaeos-ambiente` nas Releases e o [README](https://github.com/leothemurphy/CarinaeOS#-instalar-só-o-ambiente-noutra-distribuição).
