# 6. Programas

Há quatro formas de instalar programas. Por ordem de preferência:

1. **Órbita** — procura no Debian e no Flathub e instala com um clique.
2. **apt** (pacotes do Debian) — integrados no sistema, atualizados com ele.
3. **Flatpak** (Flathub) — versões recentes, isoladas do sistema.
4. **.deb** ou **AppImage** baixados do site do fabricante — quando não há nas outras.

## apt — os pacotes do Debian

```
$ sudo apt update                    # atualiza a lista de pacotes (faça antes de instalar)
$ apt search editor de video         # procurar
$ apt show kdenlive                  # descrição, versão, tamanho
$ sudo apt install kdenlive          # instalar (pode pôr vários nomes)
$ sudo apt remove kdenlive           # remover (mantém configurações)
$ sudo apt purge kdenlive            # remover tudo, também configurações do sistema
$ sudo apt autoremove                # remover dependências que ficaram sem uso
$ sudo apt upgrade                   # atualizar tudo
$ sudo apt full-upgrade              # atualizar, permitindo trocar/remover pacotes
$ apt list --installed | grep -i gimp
$ apt list --upgradable
$ sudo apt install ./programa.deb    # instalar um .deb baixado (resolve dependências)
$ sudo apt -f install                # corrigir instalações a meio / dependências partidas
$ sudo dpkg --configure -a           # terminar instalações interrompidas
```

## Flatpak — o Flathub

```
$ flatpak search spotify
$ flatpak install flathub com.spotify.Client
$ flatpak run com.spotify.Client
$ flatpak list --app
$ flatpak update
$ flatpak uninstall com.spotify.Client
$ flatpak uninstall --unused         # limpar bibliotecas sem uso
$ flatpak override --user --filesystem=home com.exemplo.App   # dar acesso à pasta pessoal
```

Para gerenciar permissões dos Flatpak graficamente: Configurações › Aplicativos › Permissões do Flatpak
(ou instale o **Flatseal**).

## .deb baixados

Duplo clique abre a instalação; ou `sudo apt install ./arquivo.deb`. Programas como Google Chrome,
VS Code, Discord, Zoom, Steam e AnyDesk distribuem `.deb` e acrescentam o seu próprio repositório,
por isso atualizam-se com o resto do sistema.

## AppImage (ex.: Elegoo Slicer, Orca Slicer, Cura, Bambu Studio, Obsidian, Etcher)

Um AppImage é um programa num só arquivo. No CarinaeOS basta **duplo clique**: o sistema torna-o
executável, guarda-o em `~/Aplicativos`, cria a entrada no menu com o ícone e pergunta se quer pô-lo na Dock.

Pelo terminal:

```
$ chmod +x ~/Downloads/ElegooSlicer_Linux_V1.5.3.5.AppImage
$ ~/Downloads/ElegooSlicer_Linux_V1.5.3.5.AppImage
```

Se não abrir:

- **“dlopen(): error loading libfuse.so.2”** → `sudo apt install libfuse2t64` (já vem no CarinaeOS).
- **Erros sobre WebKit / libwebkit2gtk** (slicers baseados no OrcaSlicer/PrusaSlicer) →
  `sudo apt install libwebkit2gtk-4.1-0 gstreamer1.0-plugins-good gstreamer1.0-libav` (já vêm).
- Correr com `--appimage-extract-and-run` evita o FUSE por completo.
- Corra-o no terminal para ver a mensagem de erro.
- **Impressora 3D por USB:** junte o usuário ao grupo *dialout* para aceder à porta série:
  `sudo usermod -aG dialout $USER` e termine a sessão.

## Programas do Windows

- **Bottles** (Órbita): cria “garrafas” do Wine com tudo configurado; ideal para programas e jogos `.exe`.
- **Wine** direto: `sudo apt install wine` e duplo clique no `.exe`.
- **Steam** (Órbita): jogos do Windows rodam com o Proton (Steam › Configurações › Compatibilidade).
- **Máquina virtual com Windows:** *GNOME Boxes* ou *virt-manager* (Órbita).
- Alternativas livres: LibreOffice (Office), GIMP/Krita (Photoshop), Inkscape (Illustrator),
  Kdenlive/Shotcut/DaVinci Resolve (vídeo), Audacity (áudio), Blender (3D), FreeCAD (CAD), OBS (gravar e transmitir).

## Remover

**Configurações › Aplicativos** junta todos os aplicativos instalados — Flathub, Debian, AppImage, apps de
`~/Aplicativos` e programas do Windows — com tamanho e data, procura, ordem e filtros. *Desinstalar* pede
confirmação (nos Flatpak, pode apagar também os dados). Também no botão direito do Launchpad › *Desinstalar…*.

- O que faz parte do sistema aparece como *Do sistema* e não sai; o **driver de vídeo, os firmwares e o núcleo**
  nunca são removidos por aqui.
- Um pacote do Debian que levaria outras partes do sistema junto não é removido (a confirmação diz porquê); só
  saem junto as peças do próprio aplicativo, como as traduções.
- Programas do Windows: o atalho sai do Launchpad e abre-se o desinstalador do Wine para apagar os arquivos.

No terminal: `apt remove` / `flatpak uninstall` (acima). **Nunca use `apt autoremove`** num PC com placa NVIDIA
antiga sem olhar a lista: o CarinaeOS protege os pacotes do driver (`placa-video proteger`), mas confirme sempre.

## Programas que iniciam com o sistema

Configurações › Sistema › Inicialização automática (adicionar ou remover programas e scripts).
