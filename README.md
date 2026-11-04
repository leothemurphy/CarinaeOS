# AtriumOS

Sistema operacional baseado no **Debian 13 (trixie)** com visual inspirado no macOS:
barra de menus no alto, Dock embaixo, Launchpad, Busca na tecla Super, apps do
Linux, do Android e do Windows, e pontos de restauração automáticos.

Este repositório gera **duas coisas de teste**, direto pelo GitHub:

| O quê | Onde fica | Como gerar |
|---|---|---|
| **ISO do AtriumOS 0.1** (pen drive / máquina virtual) | `iso/` | Actions › *Construir a ISO do AtriumOS* › Run workflow |
| **Pórtico compilado** (nome e ícone próprios) para Linux, Windows e Mac | `portico/compilar/` | Actions › *Compilar o Pórtico* › Run workflow |
| **Pórtico 0.1 prévia** (perfil sobre o Firefox instalado) | `portico/` | Actions › *Pórtico (prévia de teste)* › Run workflow |

Os arquivos prontos aparecem em **Releases** (lado direito da página do repositório).

> **A ISO não vem dentro deste zip.** Ela tem 2 a 3 GB e é **gerada pelo GitHub** a partir destes arquivos.
>
> **No Mac, a pasta `.github` fica escondida** (começa com ponto). No Finder, aperte
> **Cmd + Shift + .** para mostrar. Ela precisa ir para o GitHub junto com o resto.

---

## Passo a passo (primeira vez)

1. Crie uma conta em <https://github.com> (grátis).
2. Crie um repositório novo chamado `atriumos` (**Public**: as Actions são grátis em repositórios públicos).
3. Envie todos os arquivos desta pasta: na página do repositório, *Add file › Upload files*,
   arraste o conteúdo da pasta e clique em *Commit changes*.
   (A pasta `.github` precisa ir junto. Se o navegador não enviar pastas que começam com ponto,
   use o GitHub Desktop ou `git push`.)
4. Abra a aba **Actions**, clique em *Construir a ISO do AtriumOS* › **Run workflow**.
   Leva cerca de **1 a 2 horas**.
5. Quando terminar, a ISO estará em **Releases**. Se passar de 2 GB, ela vem dividida em
   partes, e as notas do lançamento explicam como juntar.

## Como testar a ISO

- **Máquina virtual (mais seguro):** VirtualBox, VMware ou GNOME Boxes com 4 GB de memória,
  2 processadores e 30 GB de disco; ative **EFI** nas opções.
- **Pen drive:** grave com o balenaEtcher ou o Rufus (modo DD), ligue o computador pelo pen drive
  e escolha **AtriumOS**. Dá para usar sem instalar; para instalar, clique em **Instalar o AtriumOS**.

## O que já vem na 0.1

- KDE Plasma 6 configurado como no protótipo: barra de menus no alto com o logo,
  Dock flutuante embaixo com Launchpad e Lixeira, botões das janelas à esquerda,
  áreas de trabalho **Pessoal** e **Trabalho**, minimizar com efeito "gênio"
- **Busca** (KRunner) no centro da tela: tecla **Super** ou **Alt + Espaço**
- **Escolha do estilo** no primeiro login: **AtriumOS** (parecido com o Mac), **KDE Plasma**
  (parecido com o Windows), **GNOME** ou **XFCE**. GNOME e XFCE são baixados na hora.
  Dá para trocar depois em *Estilo da área de trabalho*.
- Logo na tela de boot, login com o papel de parede **Portal**, 7 papéis de parede do AtriumOS
- **Pórtico** (prévia sobre o motor Gecko) como navegador padrão
- **Apps do Windows**: clique duas vezes num `.exe` ou `.msi`. O Wine fica escondido.
- **Apps Android**: ícone *Apps Android* na Dock (na primeira vez, baixa o Android com a Google Play)
- Instalador com a marca AtriumOS, disco em **Btrfs** e **ponto de restauração
  automático antes de cada atualização** (Snapper)
- **Modo leve**: memória comprimida (zram) ligada
- LibreOffice (Writer, Calc, Impress), Flathub na loja, português de Portugal e do Brasil

## Ainda só no protótipo (próximas versões)

Configuração inicial própria (o "átrio"), tela de login igual à do protótipo, ArtCraft,
Atrium Agent (Home Assistant), Acesso Remoto, Atrium Link, Pasta Segura, volta automática
quando uma atualização quebra o boot, Imagem do Sistema em pen drive e as lojas separadas
de apps Android e Windows.

## Construir no seu computador (opcional)

Num Debian 13, como root: `cd iso && ./build.sh`
(`ATRIUM_ANDROID=0` ou `ATRIUM_WINDOWS=0` deixam esses recursos de fora.)

## Estrutura

```
iso/auto/config            opções do live-build
iso/config/package-lists/  pacotes da ISO
iso/config/hooks/normal/   ajustes feitos durante o build
iso/config/includes.chroot arquivos copiados para o sistema (layout do KDE, Pórtico, scripts)
iso/branding/              tela de boot, instalador e menu do pen drive
portico/                   Pórtico: perfil, página inicial, extensão e instaladores
assets/                    logos, ícones e papéis de parede
```
