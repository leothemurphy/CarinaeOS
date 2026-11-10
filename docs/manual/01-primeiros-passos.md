# 1. Primeiros passos

## Baixar e preparar a pen drive

A ISO é publicada no GitHub em duas partes (o GitHub não aceita arquivos com mais de 2 GB).
Junte-as num só arquivo:

- **Windows (PowerShell):** `cmd /c copy /b CarinaeOS-1.0-amd64.iso.parte00 + CarinaeOS-1.0-amd64.iso.parte01 CarinaeOS-1.0.iso`
- **Windows (Linha de comandos):** `copy /b CarinaeOS-1.0-amd64.iso.parte00 + CarinaeOS-1.0-amd64.iso.parte01 CarinaeOS-1.0.iso`
- **Linux / macOS:** `cat CarinaeOS-1.0-amd64.iso.parte* > CarinaeOS-1.0.iso`

Confira a soma (deve ser igual à do arquivo `.sha256`):

```
$ sha256sum CarinaeOS-1.0.iso                 # Linux
> certutil -hashfile CarinaeOS-1.0.iso SHA256  # Windows
$ shasum -a 256 CarinaeOS-1.0.iso             # macOS
```

Grave a ISO numa pen drive de 8 GB ou mais com o **balenaEtcher**, o **Rufus** (modo “DD”) ou,
no Linux, `sudo dd if=CarinaeOS-1.0.iso of=/dev/sdX bs=4M status=progress oflag=sync`
(troque `sdX` pela pen drive; **tudo o que lá estiver é apagado**).

## Arrancar e experimentar

Ligue o computador com a pen drive e escolha-a no menu de arranque (normalmente F12, F11, F8,
Esc ou F2, depende da marca). Em alguns PCs é preciso desligar o *Secure Boot* na BIOS/UEFI.

A sessão de teste entra sozinha, sem senha. Nada é gravado no disco: pode explorar à vontade.
Na sessão de teste, a senha de administrador (se algo a pedir) é `live`.

## Instalar no disco

Dê duplo clique em **Instalar o CarinaeOS** na área de trabalho. O instalador pergunta:

1. **Idioma e local** (fuso horário).
2. **Teclado** (pt-PT, pt-BR ABNT2…; pode testar escrevendo na caixa).
3. **Partições**:
    - *Apagar o disco*: usa o disco inteiro (o mais simples).
    - *Instalar ao lado*: mantém o Windows e permite escolher qual arranca.
    - *Substituir uma partição* ou *Particionamento manual*: para quem sabe o que faz.
    - Pode marcar **Cifrar o sistema** (pede uma senha ao ligar o PC; protege tudo se o PC for roubado).
4. **Usuário**: nome, nome de entrada e senha. Pode escolher entrar sem senha.
5. **Resumo** e **Instalar**. Durante a instalação passam slides com as novidades.

No fim, reinicie e tire a pen drive.

## O primeiro arranque

- Aparece a tela de entrada (com o NumLock já ligado) e depois as **Boas-vindas**, um passeio por
  tudo o que o CarinaeOS tem. Pode voltar a abri-las em Central › Boas-vindas.
- A **Eta** pergunta se quer ativar a IA completa (baixa uma vez 1,1 a 2,5 GB). Pode também deixá-la
  desligada ou ligar um cérebro na nuvem (capítulo 3).
- Ligue-se à internet pelo ícone de rede na barra de cima e faça as atualizações (a Eta faz:
  “atualiza o sistema”).

## Contas e senhas

- **Mudar a senha:** Configurações › Usuários, ou no terminal `passwd`.
- **Criar outro usuário:** Configurações › Usuários › Adicionar novo usuário.
- **Entrar sem senha (automático):** Configurações › Cores e temas › Tela de entrada (SDDM) › Comportamento.
- **Sessão sem rastro (convidado):** Central › Privacidade (capítulo 12).
- **A sua foto e o fundo do login:** Central › Tela de entrada.

## Ligar, desligar, suspender

Menu estrela (canto superior esquerdo) › Suspender / Reiniciar / Desligar / Terminar sessão.
Bloquear a tela: ⊞+L. No terminal: `systemctl suspend`, `systemctl reboot`, `systemctl poweroff`.
