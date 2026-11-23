<p align="center">
  <img src="docs/imagens/banner.jpg" alt="CarinaeOS — um ambiente de trabalho novo, feito de raiz" width="100%">
</p>

<p align="center">
  <a href="../../releases"><b>⬇ Baixar a ISO (1.0 beta)</b></a> ·
  <a href="#-instalar-só-o-ambiente-noutra-distribuição"><b>🐧 Instalar noutra distribuição</b></a> ·
  <a href="#-roteiro-uma-volta-pelo-carinaeos">Roteiro</a> ·
  <a href="#-os-apps-carinae">Apps Carinae</a> ·
  <a href="#-como-é-feito">Como é feito</a>
</p>

---

**CarinaeOS** é um sistema operacional com um **ambiente de trabalho novo, criado do zero**:
o gestor de janelas **Gravidade**, o shell **Aurora** e a família de **apps Carinae**.
Foi feito para quem quer um Linux **bonito e fácil desde o primeiro minuto**, sem precisar abrir o terminal.

## ✦ Um ambiente novo, não um tema

O ambiente do CarinaeOS **não é construído em cima de outro ambiente**. Não é um fork, um tema nem uma
extensão do KDE Plasma, do GNOME, do XFCE ou de qualquer outro. Cada peça foi escrita para o CarinaeOS:

| Peça | O que é | Feito em |
|---|---|---|
| **Gravidade** | O **gestor de janelas**: molduras com os botões à esquerda, mover e redimensionar, encaixar nas metades e em zonas 25/50/25, 4 áreas de trabalho, vários monitores, <kbd>Alt</kbd>+<kbd>Tab</kbd> e todos os atalhos de teclado. | C++ sobre XCB e cairo, de raiz |
| **Aurora** | O **shell**: papel de parede, a barra de cima com o menu da estrela, relógio, agenda e bandeja, a **Dock** com pré-visualização das janelas e o efeito de luz dourada, e o **Launchpad** com ambientes. | C++ e Qt 6 / QML, de raiz |
| **Apps Carinae** | Documentos, Terminal, Configurações, Comando, Monitor, Fotos, PDF, Notas, Calculadora, Compactador, Emojis… | Python + PySide6 / QML, e C++ no Terminal |
| **Sessão** | Arranque da sessão, bloqueio de ecrã, janela de senha (polkit), energia e atalhos. | C++ e shell |

São perto de **40 mil linhas de código próprio**. O ambiente só usa bibliotecas comuns a qualquer programa Linux
(Qt 6, XCB, cairo, PAM, polkit, libvterm), e não precisa de nenhum pedaço do KDE nem do GNOME para funcionar.
A **ISO** usa a base sólida do **Debian 13**. O **ambiente** pode ser instalado também noutras distribuições
([ver abaixo](#-instalar-só-o-ambiente-noutra-distribuição)).

O nome vem de **Eta Carinae**, uma das estrelas mais brilhantes e instáveis da nossa galáxia.
A estrela de quatro pontas com a órbita é o símbolo do sistema.

> **Estado: 1.0 beta.** Já dá para usar e instalar, mas ainda pode ter arestas.
> Encontrou alguma coisa? Abra uma [*issue*](../../issues). Fica publicada **só a versão mais recente**.

## 🧭 Roteiro: uma volta pelo CarinaeOS

Tudo o que aparece nesta página é o **ambiente do próprio CarinaeOS**, tal como fica depois de instalar.

### 1. A área de trabalho

<p align="center"><img src="docs/imagens/00-mesa.jpg" alt="A área de trabalho do CarinaeOS com o papel de parede Fusão" width="100%"></p>

Uma tela limpa: a **barra de cima** com o menu da estrela, o nome do aplicativo ativo, a bandeja e o relógio;
a **Dock** em baixo; e o papel de parede **Fusão**, criado para o CarinaeOS, em resolução até **8K**.

### 2. A Dock e o menu da estrela

<table>
  <tr>
    <td width="50%"><img src="docs/imagens/11-dock.jpg" alt="Dock com a luz dourada"></td>
    <td width="50%"><img src="docs/imagens/12-estrela.jpg" alt="Menu da estrela"></td>
  </tr>
  <tr>
    <td>A <b>Dock</b>: uma <b>luz dourada</b> desliza de ícone em ícone por baixo do rato, um traço por baixo dos
    aplicativos abertos, <b>pré-visualização das janelas</b>, separadores coloridos, Transferências e Lixo.
    Seis modelos: Padrão, Sem efeitos, Só ícones, Órbita, Vidro e Windows 11.</td>
    <td>A <b>estrela</b> no canto, como a maçã do Mac: sobre este computador, Comando, Configurações,
    personalizar, loja de aplicativos, forçar encerramento, suspender, reiniciar, desligar e bloquear.</td>
  </tr>
</table>

### 3. O Launchpad: os seus aplicativos, por ambientes

<table>
  <tr>
    <td width="50%"><img src="docs/imagens/02a-ambientes.jpg" alt="Launchpad com ambientes"></td>
    <td width="50%"><img src="docs/imagens/02-launchpad.jpg" alt="Um ambiente aberto no Launchpad"></td>
  </tr>
  <tr>
    <td>Tecla <kbd>⊞</kbd> ou a estrela da Dock. Os aplicativos vivem em <b>ambientes</b> que monta como quiser:
    crie, mude o nome e a cor e <b>tranque com senha</b>. Os aplicativos que <b>instalar depois</b> aparecem soltos
    no cartão <b>Novos aplicativos</b>, à espera de que escolha o ambiente deles.</td>
    <td>Abra um ambiente para ver os aplicativos. Escreva para pesquisar; setas e Enter também funcionam.
    O botão direito fixa na Dock, move para outro ambiente ou tranca.</td>
  </tr>
</table>

### 4. O Comando: pesquisar e fazer

<p align="center"><img src="docs/imagens/03-comando.jpg" alt="Comando a fazer uma conta" width="100%"></p>

<kbd>Ctrl</kbd>+<kbd>Espaço</kbd> em qualquer lugar. Encontra **aplicativos**, **arquivos** e **configurações**,
faz **contas** (Enter copia o resultado), corre **ações** do sistema e tem **extensões**: `emoji`, `cor`, `senha`,
`matar`, `g`/`yt`/`wiki`, `~/` para arquivos e `smb://` para pastas de rede. Escreva `?` para ver todas.

### 5. Documentos e Terminal

<p align="center"><img src="docs/imagens/01-ambiente.jpg" alt="Carinae Documentos e Carinae Terminal" width="100%"></p>

O **Carinae Documentos** tem abas, barra lateral, galeria, miniaturas, etiquetas coloridas, **pastas de rede (SMB)**
e o **Cofre** com senha. O **Carinae Terminal** tem abas, temas de cores e transparência, e é o terminal do sistema
(<kbd>⊞</kbd>+<kbd>Enter</kbd> ou <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>T</kbd>).

<table>
  <tr>
    <td width="50%"><img src="docs/imagens/08-documentos.jpg" alt="Carinae Documentos"></td>
    <td width="50%"><img src="docs/imagens/09-compactador.jpg" alt="Carinae Compactador"></td>
  </tr>
  <tr>
    <td>No botão direito: compactar, abrir com, bloquear com senha, abrir o terminal aqui…</td>
    <td><b>Carinae Compactador</b>: ZIP, 7z, TAR e muitos outros formatos; navegar por dentro, extrair e criar.</td>
  </tr>
</table>

### 6. Fotos e PDF

<table>
  <tr>
    <td width="50%"><img src="docs/imagens/06-fotos.jpg" alt="Carinae Fotos"></td>
    <td width="50%"><img src="docs/imagens/10-pdf.jpg" alt="Carinae PDF"></td>
  </tr>
  <tr>
    <td><b>Carinae Fotos</b>: a pasta inteira em miniaturas, zoom, rodar, apresentação, informações (EXIF) e apagar
    para o Lixo com <i>Desfazer</i>.</td>
    <td><b>Carinae PDF</b>: miniaturas das páginas, índice, pesquisa no texto, PDFs com senha, zoom com
    <kbd>Ctrl</kbd>+roda e imprimir.</td>
  </tr>
</table>

### 7. Notas, Calculadora e Emojis

<p align="center"><img src="docs/imagens/05-apps.jpg" alt="Carinae Notas, Calculadora e Emojis" width="100%"></p>

**Carinae Notas** guarda as abas abertas de uma vez para a outra; a **Calculadora** tem os modos padrão e científico,
histórico e memória; os **Emojis** (<kbd>⊞</kbd>+<kbd>.</kbd>) escrevem o emoji direto onde está o cursor.

### 8. Configurações

<table>
  <tr>
    <td width="50%"><img src="docs/imagens/07-configuracoes.jpg" alt="Configurações: aparência"></td>
    <td width="50%"><img src="docs/imagens/07b-dock-config.jpg" alt="Configurações: Dock"></td>
  </tr>
  <tr>
    <td><b>Carinae Configurações</b>: Wi-Fi, rede, Bluetooth, telas, som, energia, aparência, Dock, notificações,
    pesquisa, aplicativos, privacidade, compartilhamento e teclado. Tudo num só lugar.</td>
    <td>A <b>Dock</b> à sua maneira: o modelo, a animação ao passar o rato, o tamanho dos ícones e a posição
    (em baixo, à esquerda, à direita ou em cima).</td>
  </tr>
</table>

### 9. Monitor

<p align="center"><img src="docs/imagens/04-monitor.jpg" alt="Carinae Monitor" width="100%"></p>

**Carinae Monitor**: processos, gráficos de desempenho do processador, memória, discos e rede, aplicativos de
inicialização e um **teste de velocidade da internet** (download, upload, ping, latência e perda de pacotes).

### 10. E ainda, na ISO

A loja **Órbita** (Flathub), a **Central** de drivers e hardware (incluindo NVIDIA antigas, como a série Kepler),
o **Carinae 3D** (a biblioteca dos seus modelos STL, 3MF e SVG para impressão 3D), o **Carinae Casa** (Home Assistant),
a **Música** (MPD), o **Cadeado** para pastas e aplicativos, o **Manual** e as **Boas-vindas** depois de instalar.

## 🐧 Instalar só o ambiente noutra distribuição

A Gravidade, a Aurora e os apps Carinae podem ser instalados **na distribuição que já usa**, ao lado do ambiente
que lá tem. A instalação é testada automaticamente em cada mudança:

| Distribuição | Estado |
|---|---|
| Debian 13 (trixie) | ✅ testado |
| Ubuntu 25.10 | ✅ testado |
| Fedora | ✅ testado |
| Arch Linux (e Manjaro, EndeavourOS) | ✅ testado |
| openSUSE Tumbleweed | ✅ testado |

1. Em [**Releases**](../../releases), baixe `carinaeos-ambiente-….tar.gz` (ou clone este repositório e entre em `ambiente/`).
2. No terminal:
   ```bash
   tar xf carinaeos-ambiente-*.tar.gz
   cd carinaeos-ambiente-*
   ./instalar-universal.sh
   ```
   O script reconhece a distribuição, instala o que falta (pede a senha), compila e instala em `/usr/local`.
3. Termine a sessão e, na tela de entrada, escolha **CarinaeOS (Gravidade)**. É uma sessão X11
   (no GDM a escolha fica na roda dentada, no SDDM no canto de baixo).

Para desinstalar: `./instalar-universal.sh --remover`. O seu ambiente atual nunca é tocado.

> Algumas ferramentas extra (Órbita, Central, Música, Carinae Casa) vêm só na ISO, porque dependem do Debian.
> O ambiente funciona sem elas.

## 🪐 Os apps Carinae

| App | Para quê |
|---|---|
| **Carinae Documentos** | Explorador de arquivos com abas, barra lateral, galeria, etiquetas coloridas, pastas de rede, cofre com senha e compactar/extrair no botão direito. |
| **Carinae Terminal** | Terminal com abas e temas, também como terminal do sistema. |
| **Carinae Fotos** | Ver, rodar, apresentar e arrumar as suas imagens. |
| **Carinae PDF** | Ler, pesquisar e imprimir PDFs. |
| **Carinae Notas** | Bloco de notas com abas, codificações, procurar e substituir, ir para a linha. |
| **Carinae Calculadora** | Padrão e científica, com histórico e memória, em formato brasileiro (1.250,50). |
| **Carinae Monitor** | Processos, desempenho, velocidade da internet e aplicativos de inicialização. |
| **Carinae Emojis** | Todos os emojis em português, com pesquisa e tons de pele. |
| **Carinae Compactador** | ZIP, 7z, TAR e muitos outros formatos pelo 7-Zip. |
| **Carinae Configurações** | Todas as configurações do sistema num só lugar. |
| **Comando** | A pesquisa e as ações rápidas do <kbd>Ctrl</kbd>+<kbd>Espaço</kbd>. |

## ✨ Novidades da 1.0 beta

- **Papel de parede Fusão**, criado para o CarinaeOS, até **8K**, com a marca no canto.
- **Instalação noutras distribuições**: Debian, Ubuntu, Fedora, Arch e openSUSE, testada automaticamente.
- **Launchpad**: os aplicativos instalados depois ficam soltos em **Novos aplicativos** até escolher o ambiente deles.
- **Dock**: o modelo muda logo nas Configurações, e o efeito de **luz dourada** vem ligado de origem.
- **Sem restos do KDE**: o Plasma, o KWin e as Definições do Sistema saíram da ISO; tudo abre os apps Carinae.
- **Placas NVIDIA antigas** (Kepler, como a GT 710) instalam pela Central sem ficar com a tela preta.
- **Pastas de rede**: um computador desligado na rede já não deixa o sistema lento à espera dele.

## 📖 Manual

O **[Manual do CarinaeOS](docs/manual/00-indice.md)** explica tudo: a área de trabalho, as ferramentas,
arquivos e discos, **HD na rede e pastas partilhadas** (SMB/NAS, NFS, SSH), programas (apt, Flatpak, AppImage),
hardware e drivers, o Debian, o kernel Linux e uma referência grande de **comandos do terminal**.
Vem dentro do sistema como o aplicativo *Manual*, com pesquisa.

## ⌨️ Atalhos úteis

| Atalho | O que faz |
|---|---|
| <kbd>⊞</kbd> (tecla Windows / ⌘) | Abre o Launchpad |
| <kbd>Ctrl</kbd>+<kbd>Espaço</kbd> | Comando: aplicativos, arquivos, contas e ações |
| <kbd>Alt</kbd>+<kbd>Tab</kbd> | Troca de janela |
| <kbd>⊞</kbd>+<kbd>←</kbd> / <kbd>→</kbd> | Encaixa a janela na metade esquerda / direita |
| <kbd>⊞</kbd>+<kbd>↑</kbd> / <kbd>↓</kbd> | Maximiza / repõe ou minimiza |
| <kbd>⊞</kbd>+<kbd>Alt</kbd>+<kbd>1</kbd>…<kbd>3</kbd> | Põe a janela numa zona (25/50/25) |
| <kbd>Ctrl</kbd>+<kbd>⊞</kbd>+<kbd>←</kbd> / <kbd>→</kbd> | Área de trabalho anterior / seguinte |
| <kbd>⊞</kbd>+<kbd>1</kbd>…<kbd>9</kbd> | Abre ou mostra o aplicativo nessa posição da Dock |
| <kbd>⊞</kbd>+<kbd>D</kbd> | Mostra a área de trabalho |
| <kbd>⊞</kbd>+<kbd>E</kbd> | Abre a pasta pessoal |
| <kbd>⊞</kbd>+<kbd>Enter</kbd> ou <kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>T</kbd> | Carinae Terminal |
| <kbd>⊞</kbd>+<kbd>.</kbd> | Carinae Emojis |
| <kbd>⊞</kbd>+<kbd>L</kbd> | Bloqueia o ecrã |
| <kbd>Print</kbd> | Captura de uma região (<kbd>Shift</kbd>: ecrã inteiro, <kbd>Alt</kbd>: janela) |

Todos os atalhos ficam em `~/.config/carinaeos/atalhos.conf` e podem ser mudados.

## 🚀 Experimentar em 5 minutos

1. Em [**Releases**](../../releases), abra a **1.0 beta** e baixe **todas as partes**
   (`CarinaeOS-1.0-amd64.iso.parte00`, `parte01`, …) e o arquivo `.sha256` para a mesma pasta.
   A ISO vem em partes porque o GitHub não aceita arquivos com mais de 2 GB.
2. Junte as partes numa única ISO:

   - **Windows**: abra a pasta, clique na barra de endereço, escreva `cmd` e Enter. Depois:
     ```
     copy /b CarinaeOS-1.0-amd64.iso.parte00 + CarinaeOS-1.0-amd64.iso.parte01 CarinaeOS-1.0-amd64.iso
     ```
     No **PowerShell**, ponha `cmd /c` antes do mesmo comando.
   - **macOS / Linux**:
     ```
     cat CarinaeOS-1.0-amd64.iso.parte* > CarinaeOS-1.0-amd64.iso
     ```

   Para confirmar que veio inteira: `sha256sum -c CarinaeOS-1.0-amd64.iso.sha256` (Linux),
   `shasum -a 256 CarinaeOS-1.0-amd64.iso` (Mac) ou `certutil -hashfile CarinaeOS-1.0-amd64.iso SHA256` (Windows).
   O código tem de ser igual ao do `.sha256`.

3. **Numa máquina virtual** (VirtualBox, VMware, GNOME Boxes…): crie uma máquina
   *Linux → Debian 64-bit* com **4 GB de memória**, **2 processadores**, **30 GB de disco** e vídeo
   **VMSVGA com 128 MB**. Use a ISO como disco de arranque.
   No VirtualBox, marque *“Pular instalação desassistida”*.

   **Num computador de verdade**: grave a ISO num pen drive de 4 GB ou mais com o
   [balenaEtcher](https://etcher.balena.io/) ou o [Rufus](https://rufus.ie/) (modo *DD*) e arranque por ele.

4. A sessão de experimentar entra **sozinha** no ambiente do CarinaeOS.
5. Gostou? Clique em **Instalar o CarinaeOS**, o primeiro ícone da Dock.
   O instalador é guiado, aceita senhas simples e sabe instalar ao lado do Windows.

> **Dica:** na sessão de experimentar, tudo o que instala ou muda fica na memória e
> desaparece quando desliga. Para guardar, instale o CarinaeOS no disco.

**Requisitos:** processador de 64 bits (x86-64), 4 GB de memória e 30 GB de disco. Funciona com e sem UEFI.

## 🛠 Como é feito

O CarinaeOS é montado com o [live-build](https://live-team.pages.debian.net/live-manual/) do
Debian. A ISO é gerada automaticamente pelo **GitHub Actions** sempre que o arquivo
[`carinae-debian/VERSAO`](carinae-debian/VERSAO) muda, e é publicada em *Releases*.
O ambiente é compilado dentro da própria ISO, a partir da pasta `ambiente/`.

```
ambiente/                    o ambiente do CarinaeOS
├── wm/                      Gravidade, o gestor de janelas (C++ / XCB)
├── shell/                   Aurora: papel de parede, barra de cima, Dock e Launchpad (Qt 6 / QML)
├── terminal/                Carinae Terminal (Qt Quick + libvterm)
├── apps/                    os apps Carinae (Python + PySide6 + QML)
│   ├── arquivos/  fotos/  pdf/  notas/  calculadora/
│   ├── monitor/  emojis/  compactador/  configuracoes/
│   └── comando/             o Comando e as suas extensões
├── senha/  bloqueio/        janela de senha (polkit) e bloqueio de ecrã
├── sessao/                  startcarinae, atalhos, picom
├── icones/                  os ícones dos apps Carinae
├── instalar-universal.sh    instala o ambiente em Debian, Ubuntu, Fedora, Arch ou openSUSE
└── instalar.sh              instala no Debian 13 do autor (com a migração do Plasma)

carinae-debian/              a receita da ISO
├── construir.sh             monta tudo e chama o live-build
├── VERSAO                   mudar este arquivo gera uma nova ISO
├── auto/config              opções do live-build (Debian 13, arranque, idioma)
├── config/
│   ├── package-lists/       os pacotes que vão no sistema
│   └── hooks/               compilar o ambiente (8000) e os ajustes finais (9000)
└── sistema/                 arquivos copiados para dentro do sistema
    └── usr/share/carinaeos/ Órbita, Casa, Música, Central, Manual, Boas-vindas…

carinae/tema/                tela de entrada (SDDM), arranque (Plymouth, GRUB), ícones e papéis de parede
carinae/apps/carinae-3d/     o Carinae 3D (Rust), compilado durante a construção da ISO
carinae/lfs/                 a primeira versão, feita do zero com Linux From Scratch (arquivo histórico)
```

### Gerar a ISO você mesmo

- **No GitHub:** aba **Actions → CarinaeOS ISO → Run workflow**. Leva cerca de 25 minutos e a ISO
  aparece em *Releases*.
- **No seu computador**, dentro de um Debian 13 (ou de um contentor `debian:trixie` com
  `--privileged`), como root:
  ```
  apt install live-build librsvg2-bin fonts-dejavu-core apt-utils git cmake g++ make
  cd carinae-debian && ./construir.sh
  ```

### Só o ambiente, noutra distribuição

Veja [Instalar só o ambiente noutra distribuição](#-instalar-só-o-ambiente-noutra-distribuição).
A verificação automática está em [`.github/workflows/ambiente-distros.yml`](.github/workflows/ambiente-distros.yml).

## 👥 Autores

O CarinaeOS foi idealizado e desenvolvido por **Leonardo Mendes**, em parceria com o
**Claude**, a IA da [Anthropic](https://www.anthropic.com/), do primeiro rascunho em
Linux From Scratch à versão atual: o visual, a Gravidade, a Aurora, a Dock, o Launchpad, o Comando,
os apps Carinae, a Órbita e a receita da ISO.

## 🙏 Créditos

O CarinaeOS existe graças a projetos livres incríveis:
[Debian](https://www.debian.org/), [Qt](https://www.qt.io/) e [PySide6](https://doc.qt.io/qtforpython-6/),
[libvterm](https://www.leonerd.org.uk/code/libvterm/), [picom](https://github.com/yshui/picom),
[SDDM](https://github.com/sddm/sddm), [Calamares](https://calamares.io/), [Flathub](https://flathub.org/),
[KDE Connect](https://kdeconnect.kde.org/),
os ícones [WhiteSur](https://github.com/vinceliuice/WhiteSur-icon-theme) de Vince Liuice (GPL-3.0), recoloridos para o CarinaeOS,
os dados de emojis do [Emojibase](https://emojibase.dev/) (MIT),
as fotografias do [ESO](https://www.eso.org/public/images/) (Y. Beletsky, J. Colosimo, D. Malin, J. Busqué; CC BY 4.0)
e do [ESA/Webb e ESA/Hubble](https://esawebb.org/images/) (CC BY 4.0),
o [ArtCraft Launcher](https://github.com/storytold/craft-launcher)
e a fonte [Inter](https://rsms.me/inter/) (SIL OFL).
O papel de parede **Fusão** foi criado para o CarinaeOS (gerador em [`arte/papeis`](arte/papeis)).
O código próprio do CarinaeOS (Gravidade, Aurora, apps Carinae, Comando, Órbita, tema) é distribuído sob a
**GPL-2.0-or-later**.

<p align="center"><sub>Desenvolvido com ✦ por <b>Leonardo Mendes</b> e <b>Claude</b> (Anthropic)</sub></p>
