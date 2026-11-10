# 3. A Eta, a assistente

A Eta é a assistente do CarinaeOS. Entende pedidos em português (escritos ou falados), faz tarefas
no computador e explica como fazer as coisas. A IA corre **no próprio computador**: nada do que
escreve sai daqui, a não ser que ligue um cérebro na nuvem ou a pesquisa na internet.

## Abrir

- **⊞+Espaço**, o ícone da Eta na Dock, ou o menu estrela.
- Na pesquisa (Ctrl+Espaço), escreva uma pergunta: aparece “Perguntar à Eta”.
- **Falar:** ⊞+Shift+Espaço ou o botão 🎤. Aparece uma nuvem no canto, a ouvir, como a Siri.

## O que pode pedir

| Pedido (exemplos) | O que a Eta faz |
|---|---|
| “abre o libre office em modo claro” | abre o LibreOffice **e** muda o tema |
| “instala o Spotify”, “quero um programa para editar fotos” | procura e instala (pede autorização) |
| “tira o GIMP do computador” | desinstala (pede autorização) |
| “põe o volume a 40”, “aumenta o brilho”, “liga a luz noturna” | ajusta na hora |
| “desliga o Bluetooth”, “liga o não perturbe” | ajusta na hora |
| “abre os Downloads”, “encontra o meu currículo” | abre a pasta / procura arquivos |
| “liguei um HD externo”, “tira o pen drive com segurança” | abre ou ejeta discos (também cifrados) |
| “conecta na pasta de rede 192.168.1.20/fotos” | liga ao NAS/PC da rede |
| “quero ligar a outra rede Wi-Fi” | mostra as redes e liga |
| “tem atualizações?”, “atualiza o sistema” | verifica e instala as atualizações |
| “qual é a minha placa de vídeo?”, “qual o meu IP?” | corre um comando que só lê e explica |
| “acende a luz da sala” | Home Assistant (Casa) |
| “lembra que a senha do Wi-Fi da praia é mar2024” | guarda na memória |
| “como uso o Kdenlive?” | guia passo a passo |
| “tranca a pasta Documentos” | tranca com senha |
| “mostra-me os comandos para ver o espaço livre” | mostra os comandos, sem os executar |

Se o pedido puder ser entendido de várias maneiras, a Eta pergunta com botões.
Lembra-se da conversa: depois de “abre o firefox”, “e agora o volume a 40” funciona.

## Fazer por mim ou dar-me os comandos

Para tarefas que mudam o sistema, a Eta mostra um cartão com três opções:
**Fazer por mim**, **Quero os comandos** (mostra os comandos para copiar ou abrir no terminal) e
**Agora não**. No ⚙ › *Modo* pode escolher que pergunte sempre, que faça sempre ou que mostre sempre os comandos.
Abrir aplicativos e pastas nunca pede autorização; instalar, remover e mudar o sistema pede.

O andamento aparece no cartão (barra e passo atual) e na nuvem da Eta; o botão **Parar** cancela.

## Enviar arquivos

Arraste um arquivo para a janela da Eta, use o 📎, ou nos Arquivos: botão direito › *Perguntar à Eta
sobre isto*. Ela lê PDF, Word, LibreOffice, texto, planilhas e imagens com texto (OCR), faz um resumo
e oferece **Guardar numa pasta** ou **Mandar para a Lixeira**. Depois pode perguntar sobre o arquivo.

## Memória

A Eta aprende e lembra-se, tudo no seu computador (`~/.local/share/carinaeos/eta/memoria`):

- **o manual do CarinaeOS** (este) — já vem com o sistema;
- os **arquivos** que lê (pode perguntar sobre eles meses depois);
- os **aplicativos** instalados: para que servem e como se usam;
- as suas **notas**: “lembra que…”, “aprende que…”; “o que sabes sobre a praia?”; “esquece a praia”;
- as **respostas** já dadas (a mesma pergunta responde-se na hora).

⚙ › *O que a Eta aprendeu* mostra a memória; ⚙ › *Esquecer as respostas guardadas* limpa a cache.

## Cérebro: leve, completo, desligado ou na nuvem

⚙ › **Cérebro da Eta**:

- **Completo** — Qwen3 4B, cerca de 3 GB de memória. Entende melhor pedidos complicados.
- **Leve** — Qwen3 1.7B, cerca de 1,5 GB. Bom para computadores com 8 GB ou menos.
- **Desligado** — a IA sai da memória e não volta a arrancar, nem em segundo plano. A Eta continua a
  fazer as tarefas simples (abrir, instalar, ajustar) com regras.
- **Na nuvem** — Claude, ChatGPT, Gemini, OpenRouter ou Groq, com a sua chave. Mais inteligente e
  rápido em computadores modestos, mas as conversas vão para esse serviço.

Ligada, a IA sai da memória sozinha ao fim de 5 minutos sem uso e volta no pedido seguinte
(o primeiro pedido depois disso demora alguns segundos).

## Pesquisa na internet

Quando não sabe a resposta (algo recente, um programa que não conhece, um erro específico), a Eta pode
pesquisar na internet e responder com base nas páginas que leu, dizendo de onde tirou a informação.
Desligar: ⚙ › *Pesquisar na internet*.

## Voz

Na primeira vez baixa o reconhecimento de voz (whisper.cpp, ~150 MB) e a voz (Piper, ~60 MB).
⚙ › *Ler as respostas em voz alta* liga ou desliga a fala.

## Copiar e colar

Selecione texto nas mensagens e Ctrl+C, ou passe o rato por cima de uma mensagem e use **Copiar**.
Os blocos de código têm **Copiar** e **Abrir no terminal**.
