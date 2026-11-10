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
- Eta: IA pode ser desligada (liberta a memória) ou usar o cérebro leve; sai da memória sozinha quando parada.
- Casa sem travar, mesmo com centenas de aparelhos.
- AppImage com duplo clique (ex.: Elegoo Slicer): instala no menu e na Dock.
- Calendários por endereço iCal (Google, iCloud, Outlook) sincronizados a cada 30 minutos.
- Botões do Mac à esquerda em todas as janelas, também GTK, Chrome e Firefox.
- Barra de cima com o nome do aplicativo e o seu menu em todos os estilos, também no Windows 11.
- Dock do GNOME com as animações do Mac; NumLock ligado ao entrar; foto e fundo da tela de entrada.
- Slides do instalador corrigidos; atalho “Instalar o CarinaeOS” de volta na área de trabalho.
- Estilo Windows 11 com barra de tarefas escura e a barra de cima; nome do aplicativo sempre certo.

Guia completo no [README](https://github.com/leothemurphy/carinaeos#readme).

<sub>Desenvolvido por Leonardo Mendes e Claude (Anthropic).</sub>
