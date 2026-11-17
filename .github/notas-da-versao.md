## CarinaeOS — 1.0-rc18

**Em partes** (GitHub não aceita arquivos com mais de 2 GB): baixe **todas as partes** (`.parte00`, `.parte01`, …) para a mesma pasta e junte-as:

**Windows** (Prompt de Comando, dentro da pasta):
```
copy /b CarinaeOS-1.0-amd64.iso.parte00 + CarinaeOS-1.0-amd64.iso.parte01 CarinaeOS-1.0-amd64.iso
```
No PowerShell, coloque `cmd /c` antes do mesmo comando.

**macOS / Linux:**
```
cat CarinaeOS-1.0-amd64.iso.parte* > CarinaeOS-1.0-amd64.iso
```

**Confirmar que é a original:** `sha256sum -c SHA256SUMS` e, com a [chave do CarinaeOS](https://raw.githubusercontent.com/leothemurphy/CarinaeOS/main/carinaeos-chave.asc) importada, `gpg --verify SHA256SUMS.asc SHA256SUMS` (tem de dizer *Good signature*).

Depois, use a ISO numa máquina virtual ou grave-a em um pen drive (balenaEtcher ou Rufus).
A sessão de teste entra sozinha, sem senha. Para instalar, abra **Instalar o CarinaeOS** na área de trabalho.

### Novidades desta versão (1.0-rc18)

Versão de **congelamento**: daqui até a 1.0 entram só correções.

- **Carinae Casa com o visual do Home Assistant**: barra lateral, separadores e cartões no estilo **Mushroom**, com os ícones do HA. **Copiar do Home Assistant** traz os seus painéis para o Casa, onde pode mudar o visual à vontade (aparelhos e automações continuam no HA). Cartões **arrastáveis**, 19 modelos, luzes com **cor, branco e efeitos**, **fonte** no Som e TV.
- **Desinstalar aplicativos como no Windows** (Configurações › Aplicativos): Flathub, Debian, AppImage e programas do Windows juntos, com tamanho e data. O que é do sistema — e o **driver de vídeo, os firmwares e o núcleo** — nunca sai.
- **Ctrl+Alt+Del** abre **Forçar o encerramento** (também Ctrl+Shift+Esc e o botão direito da Dock), com Bloquear, Sair e Desligar.
- **Deck em seções**: em cima os **favoritos do seu navegador** (Chrome com conta Google, Brave, Edge, Firefox…) ou os sites mais visitados; acrescente sites pelo endereço, edite e oculte com o botão direito. Embaixo, os atalhos.
- **Sem travamentos com pouca memória**: memória comprimida (**zram**) e a proteção do kernel contra travamentos (Multi-Gen LRU) de fábrica. Em **disco mecânico**, ajuste automático (BFQ, menos gravações, navegador na memória).
- **Música**: a barra de cima mostra o que toca também quando se dá play pelo Casa ou pelo Home Assistant; acabou a falsa pressão de disco do MPD.
- **Driver NVIDIA protegido**: os pacotes do driver ficam marcados para não saírem numa limpeza de pacotes.
- **Tudo em português do Brasil**, conferido automaticamente; a ISO também é **conferida automaticamente** (memória, atalhos, permissões, driver) antes de cada publicação.
- Também desde a rc17: programas do Windows (.exe) com duplo clique e apps Electron na versão nativa; 16 modelos de Dock; Central com Celular, Vindo do Windows, Jogos (só se pedir) e Firewall; **modo leve** para computadores antigos; firewall e correções de segurança automáticas; atualizações com ponto de restauração (Timeshift); Secure Boot com NVIDIA sem terminal; inicialização sem esperar pela rede.

Guia completo no [README](https://github.com/leothemurphy/carinaeos#readme).

<sub>Desenvolvido por Leonardo Mendes e Claude (Anthropic).</sub>
