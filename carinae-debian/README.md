# CarinaeOS — edição Debian

CarinaeOS 1.0 "Eta": Debian 13 (trixie) + KDE Plasma 6 com o visual CarinaeOS:

- menu de arranque e ecrã de carregamento com a estrela (Plymouth);
- ecrã de entrada ao estilo do macOS (SDDM);
- barra no topo com a estrela, Dock em baixo com ampliação, fundo de Eta Carinae,
  cores CarinaeOS, letra Inter e efeitos de janela;
- instalador gráfico (Calamares) com a marca CarinaeOS.

## Experimentar no VirtualBox (Windows, macOS ou Linux)

1. Descarregue todas as partes da ISO (`CarinaeOS-1.0-amd64.iso.parte00`, `parte01`, …)
   e o ficheiro `.sha256` da página de *releases*, para a mesma pasta.
2. Junte as partes:
   - **Windows (PowerShell)**, dentro da pasta:
     ```
     cmd /c copy /b "CarinaeOS-1.0-amd64.iso.parte*" CarinaeOS-1.0-amd64.iso
     (Get-FileHash CarinaeOS-1.0-amd64.iso).Hash
     ```
     O código tem de ser igual ao do ficheiro `.sha256`.
   - **macOS / Linux**: `cat CarinaeOS-1.0-amd64.iso.parte* > CarinaeOS-1.0-amd64.iso`
3. VirtualBox → **Novo**:
   - Nome: `CarinaeOS`; Imagem ISO: a ISO acima; marque **"Pular instalação desassistida"**.
   - Tipo: Linux, Versão: Debian (64-bit).
   - Memória: **4096 MB** (ou mais); Processadores: **2 ou mais**.
   - Disco: **30 GB**.
4. Antes de ligar, em **Configurações**:
   - **Tela**: Memória de vídeo **128 MB**, Controladora **VMSVGA**, marque *Habilitar aceleração 3D*.
   - **Sistema → Placa-mãe**: marque *Habilitar EFI* (opcional; funciona com e sem).
5. **Iniciar**. No menu escolha *Iniciar o CarinaeOS*.
   No ecrã de entrada: usuário **carinae**, senha **live**.
6. Para instalar no disco da VM, abra **"Instalar o CarinaeOS"** na área de trabalho.

Resolução: em *Configurações do Sistema → Monitor*, escolha a maior resolução da lista
(ou ponha a janela do VirtualBox em ecrã inteiro — Host+F — e volte a escolher).

## Gerar a ISO

Num Debian 13 (ou contentor `debian:trixie` com `--privileged`), como root:

```
apt install live-build librsvg2-bin fonts-dejavu-core apt-utils
./construir.sh
```

Ou no GitHub: separador **Actions → CarinaeOS ISO → Run workflow**; a ISO aparece em *Releases*.
