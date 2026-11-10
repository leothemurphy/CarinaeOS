# CarinaeOS - Eta: o cerebro.
# A IA recebe o pedido e escolhe FERRAMENTAS (chamadas de funcao nativas do modelo),
# em vez de a Eta tentar adivinhar com regras. Funciona com o modelo local (llama.cpp)
# ou, se o usuario quiser, com um modelo na nuvem com a chave dele (formato OpenAI).
#
# O prompt do sistema e as ferramentas nunca mudam durante a sessao: o llama.cpp guarda-os
# em cache e so processa as palavras novas de cada pedido (respostas bem mais rapidas).
import json
import os
import urllib.request

PORTA = 18765

# Modelos locais, do melhor para o mais leve. O primeiro que existir no disco e usado.
MODELOS = [
    dict(id='qwen3-4b', arquivo='cerebro-qwen3-4b.gguf', ram_gb=6, tamanho=2497281120,
         url='https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf',
         nome='Qwen3 4B'),
    dict(id='qwen3-1.7b', arquivo='cerebro-qwen3-1.7b.gguf', ram_gb=0, tamanho=1107409472, sem_pensar=True,
         url='https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf',
         nome='Qwen3 1.7B'),
    dict(id='qwen2.5-1.5b', arquivo='modelo.gguf', ram_gb=0, tamanho=1117320736, antigo=True,
         url='https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf',
         nome='Qwen2.5 1.5B'),
]

# IA na nuvem (opcional): o usuario cola a chave dele. Formato compativel com OpenAI.
NUVENS = {
    'anthropic': dict(nome='Claude (Anthropic)', url='https://api.anthropic.com/v1', modelo='claude-haiku-5-5',
                      chave_em='console.anthropic.com → API Keys'),
    'openai': dict(nome='ChatGPT (OpenAI)', url='https://api.openai.com/v1', modelo='gpt-4.1-mini',
                   chave_em='platform.openai.com → API keys'),
    'gemini': dict(nome='Gemini (Google)', url='https://generativelanguage.googleapis.com/v1beta/openai', modelo='gemini-2.5-flash',
                   chave_em='aistudio.google.com → Get API key'),
    'openrouter': dict(nome='OpenRouter (vários modelos)', url='https://openrouter.ai/api/v1', modelo='openrouter/auto',
                       chave_em='openrouter.ai → Keys'),
    'groq': dict(nome='Groq (muito rápido)', url='https://api.groq.com/openai/v1', modelo='llama-3.3-70b-versatile',
                 chave_em='console.groq.com → API Keys'),
}


def ram_gb():
    try:
        with open('/proc/meminfo') as f:
            for l in f:
                if l.startswith('MemTotal:'):
                    return int(l.split()[1]) / 1048576
    except OSError:
        pass
    return 4


def modelo_recomendado():
    r = ram_gb()
    for m in MODELOS:
        if not m.get('antigo') and r >= m['ram_gb']:
            return m
    return MODELOS[1]


def modelo_no_disco(pasta):
    for m in MODELOS:
        if os.path.exists(os.path.join(pasta, m['arquivo'])):
            return m
    return None


PROMPT = """Você é a Eta ✦, a assistente do CarinaeOS (sistema operacional baseado no Debian 13, visual inspirado no macOS).
Responda sempre em português do Brasil, curto, caloroso e claro.

COMO TRABALHAR
1. Se o pedido for uma AÇÃO no computador (abrir, instalar, remover, mudar, ligar, desligar, procurar, conectar, atualizar,
   lembrar...), CHAME A FERRAMENTA certa. Não explique o que vai fazer: faça.
2. Leia o pedido inteiro com atenção. Nomes de programas podem vir separados ou com erros: "libre office" = LibreOffice,
   "fire fox" = Firefox, "vs code" = Visual Studio Code. "claro"/"escuro" referem-se ao tema (ajustar tema).
3. Pedido com duas ações ("abre o libre office no modo claro") = chame as duas ferramentas.
4. Se o pedido for ambíguo e puder significar coisas diferentes, chame "perguntar" com 2 a 4 opções curtas.
   Nunca adivinhe quando a ação instala, remove ou apaga algo.
5. Se for uma PERGUNTA (como fazer, onde fica, o que é), responda em até 6 frases, com passos numerados quando ajudar.
   Use o CONTEXTO quando existir. Não invente menus nem caminhos; se não souber, ofereça abrir as configurações.
6. Para saber dados do computador (placa de vídeo, versão, IP, processos, espaço...), use executar_comando com um comando
   que só lê informação e depois explique o resultado em palavras simples.
7. Quando pedirem para VER, MOSTRAR ou ENSINAR comandos de terminal, NÃO execute nada: escreva-os num bloco ``` e
   explique cada um.
8. Nunca diga que fez algo sem ter chamado a ferramenta. Para perguntar, use SEMPRE a ferramenta "perguntar"
   (nunca escreva listas de opções em texto).
9. GNOME, XFCE, KDE Plasma e os estilos Mac/Windows 11 são AMBIENTES de trabalho: para os instalar ou trocar,
   abra o aplicativo "Ambiente" (abrir_aplicativo). Nunca use instalar_programa nem remover_programa para eles.
10. "Muda o papel de parede" = ajustar papel_de_parede proximo. "Não perturbe" = ajustar nao_perturbe ligar.
11. Nunca peça senhas na conversa: as ferramentas pedem-nas de forma segura.
12. Responda apenas ao ÚLTIMO pedido; os anteriores já foram tratados.

O CARINAEOS
- Barra de cima: a estrela à esquerda abre o menu estrela (Sobre, Configurações, Desligar...); menus do app ativo no meio;
  rede, som, relógio à direita. Dock em baixo (ícones crescem; arraste apps ou pastas para fixar; botão direito > Remover).
- Meta (tecla Windows) abre o Launchpad; Meta+Espaço abre a Eta; Ctrl+Espaço abre a pesquisa; Meta+V o histórico do Ctrl+C;
  Meta+T as zonas de janelas; Meta+W todas as janelas e áreas de trabalho.
- Central CarinaeOS: reúne as ferramentas do sistema (Supernova = personalização e Dock; Órbita = loja de aplicativos;
  Casa = Home Assistant; Ambiente = estilo Mac/Windows 11, GNOME, XFCE; Cadeado = trancar pastas, arquivos e apps;
  Etiquetas; Calendários (Google/iCloud); Drivers; Sessão sem rastro; Boas-vindas).
- Trancar: botão direito numa pasta ou arquivo > Trancar com senha; abre com duplo clique e a senha.
- Etiquetas: botão direito > Etiquetas > cor; aparecem na barra lateral dos Arquivos.
"""


def _f(nome, descricao, props=None, obrig=None):
    return dict(type='function', function=dict(
        name=nome, description=descricao,
        parameters=dict(type='object', properties=props or {}, required=obrig or [])))


S = lambda d, **k: dict(type='string', description=d, **k)  # noqa: E731

PAGINAS = ['tela', 'som', 'rede', 'wifi', 'bluetooth', 'energia', 'aparencia', 'cores', 'papel_de_parede', 'teclado',
           'mouse', 'touchpad', 'impressoras', 'usuarios', 'data_hora', 'idioma', 'notificacoes', 'atalhos',
           'aplicativos_padrao', 'luz_noturna', 'sobre', 'backups', 'inicio_automatico', 'acessibilidade', 'geral']

FERRAMENTAS = [
    _f('abrir_aplicativo', 'Abre um aplicativo instalado (ou uma ferramenta do CarinaeOS: Central, Supernova, Órbita, Casa, '
       'Ambiente, Cadeado, Calendário, Mapas, Terminal...).', dict(nome=S('Nome do aplicativo, como o usuário disse')), ['nome']),
    _f('abrir_pasta', 'Abre uma pasta no gerenciador de arquivos.',
       dict(pasta=S('inicio, documentos, downloads, imagens, musicas, videos, area_de_trabalho, lixeira, etiquetas, '
                    'ou um caminho como ~/Projetos')), ['pasta']),
    _f('abrir_configuracao', 'Abre uma página das Configurações do Sistema.',
       dict(pagina=S('Página', enum=PAGINAS)), ['pagina']),
    _f('ajustar', 'Muda na hora uma configuração simples.',
       dict(o_que=S('O que mudar', enum=['tema', 'luz_noturna', 'volume', 'brilho', 'wifi', 'bluetooth', 'nao_perturbe',
                                         'papel_de_parede']),
            valor=S('claro/escuro (tema); ligar/desligar; mais/menos/mudo ou um número de 0 a 100 (volume, brilho); '
                    'proximo (papel de parede)')), ['o_que', 'valor']),
    _f('instalar_programa', 'Procura e instala um programa (Debian ou Flathub). Pede permissão ao usuário antes.',
       dict(nome=S('Nome do programa')), ['nome']),
    _f('remover_programa', 'Desinstala um programa. Pede permissão ao usuário antes.',
       dict(nome=S('Nome do programa')), ['nome']),
    _f('procurar_arquivos', 'Procura arquivos e pastas do usuário pelo nome.',
       dict(palavras=S('Palavras do nome do arquivo')), ['palavras']),
    _f('info_sistema', 'Espaço livre no disco, memória e processadores.'),
    _f('discos', 'Mostra, abre (conecta) ou ejeta discos externos e pen drives, incluindo discos com senha.',
       dict(acao=S('abrir ou ejetar', enum=['abrir', 'ejetar'])), ['acao']),
    _f('pasta_de_rede', 'Conecta a uma pasta de rede (NAS, outro computador, SMB/Windows).',
       dict(endereco=S('Endereço, se o usuário disse (ex.: 192.168.1.20/fotos)'))),
    _f('wifi', 'Mostra as redes Wi-Fi para conectar.'),
    _f('atualizacoes', 'Verifica e instala as atualizações do sistema e dos aplicativos.'),
    _f('casa', 'Controla ou consulta a casa inteligente (Home Assistant): luzes, tomadas, ar condicionado, cenas, sensores.',
       dict(pedido=S('O pedido, ex.: "acende a luz da sala"')), ['pedido']),
    _f('executar_comando', 'Executa um comando de terminal (bash). Comandos que só leem informação correm logo e o resultado '
       'volta para você explicar; os que mudam o sistema pedem permissão ao usuário.',
       dict(comando=S('O comando bash'), descricao=S('O que o comando faz, em poucas palavras')), ['comando', 'descricao']),
    _f('lembrar', 'Guarda uma informação que o usuário pediu para lembrar.', dict(nota=S('O que guardar')), ['nota']),
    _f('consultar_memoria', 'Procura no que a Eta aprendeu (arquivos lidos, notas do usuário, guias dos aplicativos).',
       dict(pergunta=S('O que procurar')), ['pergunta']),
    _f('como_usar_aplicativo', 'Mostra o guia passo a passo de um aplicativo.', dict(nome=S('Nome do aplicativo')), ['nome']),
    _f('trancar', 'Tranca com senha uma pasta, um arquivo ou um aplicativo.',
       dict(o_que=S('Caminho da pasta/arquivo, ou nome do aplicativo')), ['o_que']),
    _f('perguntar', 'Faz uma pergunta curta ao usuário com botões de opções, quando o pedido é ambíguo.',
       dict(pergunta=S('A pergunta'), opcoes=dict(type='array', items=dict(type='string'), description='2 a 4 opções curtas')),
       ['pergunta', 'opcoes']),
]

# ferramentas que devolvem informacao para a IA continuar a resposta
DE_CONSULTA = {'info_sistema', 'consultar_memoria'}


class Cerebro:
    """Fala com o modelo (local ou nuvem) usando a API de chat do formato OpenAI."""

    def __init__(self, cfg):
        self.cfg = cfg                       # dicionario de preferencias da Eta (partilhado)

    def nuvem(self):
        n = self.cfg.get('nuvem') or {}
        if n.get('ligada') and n.get('chave') and n.get('provedor') in NUVENS:
            p = NUVENS[n['provedor']]
            return dict(url=n.get('url') or p['url'], modelo=n.get('modelo') or p['modelo'], chave=n['chave'], nome=p['nome'])
        return None

    def falar(self, mensagens, ao_escrever=None, parar=lambda: False, ferramentas=True, max_tokens=700, sem_pensar=False):
        """Devolve (texto, [chamadas]) onde cada chamada e (nome, argumentos)."""
        n = self.nuvem()
        corpo = dict(messages=mensagens, temperature=0.2, max_tokens=max_tokens, stream=True)
        if ferramentas:
            corpo['tools'] = FERRAMENTAS
        if n:
            url = n['url'].rstrip('/') + '/chat/completions'
            corpo['model'] = n['modelo']
            cab = {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + n['chave']}
            if 'anthropic.com' in url:
                cab['x-api-key'] = n['chave']
                cab['anthropic-version'] = '2023-06-01'
        else:
            url = 'http://127.0.0.1:%d/v1/chat/completions' % PORTA
            cab = {'Content-Type': 'application/json'}
            corpo['cache_prompt'] = True
            if sem_pensar:
                corpo['chat_template_kwargs'] = dict(enable_thinking=False)
        pedido = urllib.request.Request(url, data=json.dumps(corpo).encode(), headers=cab)
        texto, chamadas = '', {}
        with urllib.request.urlopen(pedido, timeout=300) as r:
            for linha in r:
                if parar():
                    break
                linha = linha.decode('utf-8', 'ignore').strip()
                if not linha.startswith('data:'):
                    continue
                dado = linha[5:].strip()
                if dado == '[DONE]':
                    break
                try:
                    escolha = json.loads(dado)['choices'][0]
                except (ValueError, KeyError, IndexError):
                    continue
                delta = escolha.get('delta') or {}
                if delta.get('content'):
                    texto += delta['content']
                    if ao_escrever:
                        ao_escrever(texto)
                for tc in delta.get('tool_calls') or []:
                    i = tc.get('index', 0)
                    c = chamadas.setdefault(i, dict(nome='', args=''))
                    fn = tc.get('function') or {}
                    if fn.get('name'):
                        c['nome'] += fn['name']
                    if fn.get('arguments'):
                        c['args'] += fn['arguments']
        lista = []
        for i in sorted(chamadas):
            c = chamadas[i]
            try:
                args = json.loads(c['args'] or '{}')
            except ValueError:
                args = {}
            if c['nome']:
                lista.append((c['nome'], args if isinstance(args, dict) else {}))
        # alguns modelos pequenos escrevem a chamada como texto <tool_call>{...}</tool_call>
        if not lista and '<tool_call>' in texto:
            import re
            for m in re.finditer(r'<tool_call>\s*(\{.*?\})\s*</tool_call>', texto, re.S):
                try:
                    d = json.loads(m.group(1))
                    lista.append((d.get('name', ''), d.get('arguments') or {}))
                except ValueError:
                    pass
            texto = re.sub(r'<tool_call>.*?(</tool_call>|$)', '', texto, flags=re.S).strip()
        return texto.strip(), lista
