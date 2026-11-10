# 12. Segurança e privacidade

## O que já vem protegido

- **Usuário normal + senha de administrador:** nada muda o sistema sem a sua autorização. A janela de
  senha do CarinaeOS (com o banner e a estrela) diz exatamente o que vai ser feito.
- **Atualizações de segurança** do Debian (a Eta e a Órbita avisam).
- **Flatpak isolados** do resto do sistema; **AppArmor** ativo para vários serviços.
- **A IA corre no computador:** as conversas com a Eta não saem daqui (a não ser que ligue o cérebro na nuvem
  ou a pesquisa na internet, e só o que for pesquisado).

## Boas práticas

- Instale programas da Órbita, do Debian ou do Flathub; desconfie de scripts `curl … | sudo bash`.
- Mantenha o sistema atualizado (“atualiza o sistema”).
- Use senhas diferentes e um gestor: **KeePassXC** ou **Bitwarden** (Órbita).
- Ative a **cifra do disco** ao instalar, sobretudo em portáteis.
- Faça cópias de segurança (capítulo 5).

## Cifrar

- **Disco inteiro:** opção *Cifrar o sistema* no instalador (LUKS2).
- **Pastas e arquivos:** Cadeado (botão direito › Trancar com senha), AES-256.
- **Cofres:** Plasma Vault (cadeado da bandeja).
- **Pen drives:** Gerenciador de partições › Nova tabela/partição › *Cifrar com LUKS*; ou use VeraCrypt
  (Órbita) para abrir também no Windows/Mac.
- **Arquivos soltos:** `gpg -c arquivo` (cifra com senha), `gpg arquivo.gpg` (abre).

## Sessão sem rastro

Central › Privacidade › **Sessão sem rastro**: na tela de entrada aparece *Convidado (sem rastro)*, sem senha.
A pasta pessoal do convidado vive só na memória: arquivos, downloads, histórico, senhas e definições
desaparecem ao terminar a sessão. Ótimo para emprestar o computador.

## Bloqueio e privacidade da tela

- ⊞+L bloqueia. Configurações › Bloqueio de tela: bloquear automaticamente, ao suspender.
- Notificações no ecrã de bloqueio: Configurações › Notificações.
- Câmara e microfone: o ícone aparece na bandeja quando um aplicativo os usa.

## Firewall

`sudo apt install ufw plasma-firewall && sudo ufw enable` (capítulo 6).

## Navegadores

O Firefox ESR vem com proteção contra rastreio. Extensões recomendadas: uBlock Origin. Para o Chrome:
Definições › Privacidade e segurança. O *Modo escuro em todo o lado* (Central › Privacidade) força o escuro nas páginas.
