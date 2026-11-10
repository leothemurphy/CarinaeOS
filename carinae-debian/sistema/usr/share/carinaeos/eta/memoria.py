# CarinaeOS - Eta: memória (aprende e lembra-se, tudo no próprio computador).
#  - documentos: o que lê (PDF, Word, texto...) fica guardado em pedaços, para responder
#    depois a perguntas sobre o assunto, mesmo que o arquivo já não exista;
#  - aplicativos: tudo o que é instalado (pela Eta, pela Órbita ou por outro lado) é estudado:
#    para que serve, como abrir, passo a passo para o mais comum e comandos do terminal;
#  - notas: "lembra-te que..." / "aprende que..." / "esquece...";
#  - respostas: as respostas da IA ficam em cache e a mesma pergunta responde-se na hora.
# Fica em ~/.local/share/carinaeos/eta/memoria/ (só o usuário a pode ler).
import glob
import hashlib
import json
import math
import os
import re
import subprocess
import time
import unicodedata
from collections import Counter

DADOS = os.path.join(os.environ.get('XDG_DATA_HOME', os.path.expanduser('~/.local/share')), 'carinaeos', 'eta', 'memoria')
DOCS = os.path.join(DADOS, 'docs')
RESPOSTAS = os.path.join(DADOS, 'respostas.json')
APPS_VISTOS = os.path.join(DADOS, 'apps-vistos.json')

VAZIAS = set('''a o as os um uma uns umas de da do das dos e é em no na nos nas para pra pro por pelo pela com sem que
se ao à às ou mais mas como seu sua seus suas meu minha este esta isso esse essa ele ela eles elas foi ser são ter tem
também eu voce você me te lhe nos qual quais quando onde porque quem sobre muito pouco já não sim vai vou faz fazer
the of and to in is for on with by an be this that are from as at it or'''.split())


# palavras de 2 letras que interessam (hd, ip, pc…) e sinonimos comuns
CURTAS = {'hd', 'ip', 'pc', 'tv', 'ia', 'vm', 'cd', 'dd', 'df', 'du', 'ls', 'ps', 'rm', 'cp', 'mv', 'id', 'os', 'ui', 'wi'}
SINONIMOS = {'ligo': 'conectar', 'ligar': 'conectar', 'liga': 'conectar', 'conecto': 'conectar', 'conecta': 'conectar',
             'nas': 'rede', 'compartilhada': 'partilha', 'compartilhadas': 'partilha', 'compartilhar': 'partilha',
             'partilhadas': 'partilha', 'partilhar': 'partilha', 'partilhada': 'partilha', 'smb': 'samba',
             'disco': 'hd', 'discos': 'hd', 'arquivos': 'arquivo', 'pastas': 'pasta'}


def simples(t):
    t = unicodedata.normalize('NFD', (t or '').lower())
    return ''.join(c for c in t if unicodedata.category(c) != 'Mn')


def fichas(texto):
    """Palavras-chave normalizadas (sem acentos, sem palavras vazias, raiz curta)."""
    res = []
    for w in re.findall(r'[a-z0-9]{2,}', simples(texto)):
        if w in VAZIAS or (len(w) == 2 and w not in CURTAS):
            continue
        w = SINONIMOS.get(w, w)
        res.append(w[:7])          # raiz grosseira: instalar/instalacao/instalado -> "instala"
    return res


def _gravar(caminho, dados):
    os.makedirs(os.path.dirname(caminho), mode=0o700, exist_ok=True)
    tmp = caminho + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(dados, f, ensure_ascii=False)
    os.replace(tmp, caminho)


def _ler(caminho, padrao):
    try:
        with open(caminho, encoding='utf-8') as f:
            return json.load(f)
    except (OSError, ValueError):
        return padrao


# ---- documentos -----------------------------------------------------------------------------
def _pedacos(texto, tamanho=700):
    paragrafos = [p.strip() for p in re.split(r'\n\s*\n|(?<=[.!?])\s{2,}', texto) if p.strip()]
    pedacos, atual = [], ''
    for p in paragrafos:
        p = re.sub(r'\s+', ' ', p)
        if len(atual) + len(p) < tamanho:
            atual = (atual + ' ' + p).strip()
        else:
            if atual:
                pedacos.append(atual)
            while len(p) > tamanho * 1.5:
                corte = p.rfind('. ', 0, tamanho) + 1 or tamanho
                pedacos.append(p[:corte].strip())
                p = p[corte:].strip()
            atual = p
    if atual:
        pedacos.append(atual)
    return pedacos[:600]


def aprender(ident, titulo, texto, origem, resumo='', extra=None):
    """Guarda (ou atualiza) um documento na memória."""
    if not texto.strip():
        return None
    doc = dict(id=ident, titulo=titulo, origem=origem, quando=int(time.time()), resumo=resumo,
               pedacos=[dict(t=p, f=fichas(p)) for p in _pedacos(texto)], **(extra or {}))
    nome = hashlib.sha1(ident.encode()).hexdigest()[:16] + '.json'
    _gravar(os.path.join(DOCS, nome), doc)
    return doc


def documentos():
    res = []
    for f in sorted(glob.glob(os.path.join(DOCS, '*.json'))):
        d = _ler(f, None)
        if d:
            d['_arquivo'] = f
            res.append(d)
    return res


def esquecer(texto):
    """Apaga da memória os documentos/notas cujo título casa com o texto. Devolve os títulos."""
    alvo = set(fichas(texto))
    apagados = []
    for d in documentos():
        if alvo and alvo <= set(fichas(d['titulo'] + ' ' + d.get('resumo', ''))):
            os.remove(d['_arquivo'])
            apagados.append(d['titulo'])
    return apagados


def lembrar(pergunta, n=4, origem=None):
    """Os pedaços da memória mais parecidos com a pergunta: [(pontos, titulo, texto, doc)]."""
    q = fichas(pergunta)
    if not q:
        return []
    docs = [d for d in documentos() if not origem or d['origem'] == origem]
    if origem in (None, 'manual'):
        try:
            import manual
            docs += manual.documentos()
        except Exception:
            pass
    todos = [(d, p) for d in docs for p in d['pedacos']]
    if not todos:
        return []
    df = Counter()
    for _, p in todos:
        df.update(set(p['f']))
    N = len(todos)
    med = sum(len(p['f']) for _, p in todos) / N or 1
    res = []
    for d, p in todos:
        tf = Counter(p['f'])
        cab = re.match(r'\[([^\]]+)\]', p['t'])           # pedacos do manual: "[Capitulo › Secao]"
        titulo = set(fichas(d['titulo'] + ' ' + (cab.group(1) if cab else '')))
        pontos = 0.0
        for w in set(q):
            if w in tf:
                idf = math.log(1 + (N - df[w] + 0.5) / (df[w] + 0.5))
                pontos += idf * tf[w] * 2.2 / (tf[w] + 1.2 * (0.25 + 0.75 * len(p['f']) / med))
            if w in titulo:
                pontos += 1.5
        if pontos > 0:
            res.append((pontos, d['titulo'], p['t'], d))
    res.sort(key=lambda x: -x[0])
    return res[:n]


# ---- cache de respostas --------------------------------------------------------------------------
def resposta_guardada(pergunta, minimo=0.82):
    q = set(fichas(pergunta))
    if len(q) < 2:
        return None
    melhor, sim = None, 0
    for r in _ler(RESPOSTAS, []):
        f = set(r['f'])
        j = len(q & f) / len(q | f) if q | f else 0
        if j > sim:
            melhor, sim = r, j
    return melhor['a'] if melhor and sim >= minimo else None


def guardar_resposta(pergunta, resposta):
    if len(resposta) < 20 or resposta.startswith('__erro__'):
        return
    lista = [r for r in _ler(RESPOSTAS, []) if r['q'] != pergunta]
    lista.append(dict(q=pergunta, f=fichas(pergunta), a=resposta, t=int(time.time())))
    _gravar(RESPOSTAS, lista[-500:])


def esquecer_respostas():
    _gravar(RESPOSTAS, [])


# ---- aplicativos: estudar o que esta instalado -----------------------------------------------------
PASTAS_APPS = ['/usr/share/applications', '/usr/local/share/applications',
               os.path.expanduser('~/.local/share/flatpak/exports/share/applications'),
               '/var/lib/flatpak/exports/share/applications']

# dicas por categoria (o passo a passo do mais comum)
DICAS = {
    'Office': ['Para criar: Arquivo › Novo. Para guardar: Ctrl+S (escolha a pasta Documentos).',
               'Para abrir um documento: Arquivo › Abrir, ou arraste o arquivo para a janela.',
               'Para exportar em PDF: Arquivo › Exportar como PDF.', 'Para imprimir: Ctrl+P.'],
    'Graphics': ['Para abrir uma imagem: Arquivo › Abrir (Ctrl+O) ou arraste a imagem para a janela.',
                 'Para guardar uma cópia noutro formato: Arquivo › Exportar.', 'Desfazer: Ctrl+Z; refazer: Ctrl+Shift+Z.'],
    'AudioVideo': ['Para abrir: arraste o vídeo ou a música para a janela, ou Arquivo › Abrir.',
                   'Espaço = tocar/pausar; setas = avançar/recuar; F = ecrã inteiro.'],
    'Network': ['Para entrar na sua conta, use o botão de iniciar sessão na primeira janela.',
                'Pode pôr o aplicativo na Dock: botão direito no ícone › Manter no Dock.'],
    'WebBrowser': ['Nova aba: Ctrl+T; fechar aba: Ctrl+W; reabrir aba fechada: Ctrl+Shift+T.',
                   'Favoritos: Ctrl+D. Navegação privada: Ctrl+Shift+N (ou Ctrl+Shift+P no Firefox).',
                   'Para o tornar o navegador padrão: Configurações do Sistema › Aplicativos padrão.'],
    'Game': ['Os jogos ficam no Launchpad. No Steam, entre na conta e vá à Biblioteca para instalar.'],
    'Development': ['Para abrir uma pasta de projeto: Arquivo › Abrir pasta.', 'Terminal integrado: normalmente Ctrl+`.'],
    'Utility': ['Procure as opções no menu ☰ ou na barra de cima do aplicativo (menu global).'],
    'System': ['Algumas ações pedem a sua senha de administrador.'],
}

GUIAS = {   # guias completos dos aplicativos mais pedidos
    'libreoffice': ['O LibreOffice é o pacote de escritório: Writer (textos, como o Word), Calc (folhas de cálculo, como o Excel), '
                    'Impress (apresentações, como o PowerPoint) e Draw (desenhos).',
                    'Abra pelo Launchpad (estrela) › “LibreOffice Writer” (ou Calc, Impress).',
                    'Abre e guarda documentos do Microsoft Office: ao guardar, escolha “Manter o formato atual” para .docx/.xlsx.',
                    'Exportar em PDF: Arquivo › Exportar como PDF.',
                    'Tema claro/escuro: Ferramentas › Opções › LibreOffice › Cores da aplicação (ou Ver › Interface do usuário).'],
    'gimp': ['O GIMP é um editor de imagens profissional (como o Photoshop).',
             'Abrir: Arquivo › Abrir. Recortar: ferramenta Recorte (Shift+C), arraste e carregue em Enter.',
             'Redimensionar: Imagem › Escalar imagem. Tirar o fundo: Camada › Transparência › Adicionar canal alfa, e use a Seleção difusa (U).',
             'Guardar como JPG/PNG: Arquivo › Exportar como (Ctrl+Shift+E). O “Guardar” cria um .xcf, o formato do GIMP.'],
    'vlc': ['O VLC toca quase todos os vídeos e músicas.', 'Arraste o arquivo para a janela, ou Mídia › Abrir arquivo.',
            'Legendas: Legendas › Adicionar arquivo de legendas. Ecrã inteiro: F. Velocidade: [ e ].'],
    'firefox': ['O Firefox é o navegador do CarinaeOS.', 'Nova aba: Ctrl+T. Favoritos: Ctrl+D. Janela privada: Ctrl+Shift+P.',
                'Importar favoritos de outro navegador: menu ☰ › Favoritos › Gerir › Importar.'],
    'chrome': ['O Google Chrome é o navegador da Google.', 'Na primeira vez, inicie sessão com a conta Google para trazer favoritos e senhas.',
               'Nova aba: Ctrl+T. Janela anónima: Ctrl+Shift+N.'],
    'spotify': ['O Spotify toca música por streaming.', 'Abra pelo Launchpad e entre na sua conta.', 'Espaço = tocar/pausar.'],
    'discord': ['O Discord é para conversar por texto, voz e vídeo.', 'Abra e entre na sua conta; o microfone escolhe-se em Definições › Voz e vídeo.'],
    'steam': ['O Steam é a loja e biblioteca de jogos.', 'Entre na conta › Biblioteca › escolha o jogo › Instalar.',
              'Jogos do Windows: Definições › Compatibilidade › “Ativar Steam Play para todos os títulos” (Proton).'],
    'obs': ['O OBS Studio grava o ecrã e faz transmissões em direto.', 'Em “Fontes” carregue em + › “Captura de ecrã”.',
            'Carregue em “Iniciar gravação”; os vídeos vão para a pasta Vídeos.'],
    'kdenlive': ['O Kdenlive é o editor de vídeo.', 'Arraste os vídeos para o “Repositório do projeto” e depois para a linha do tempo.',
                 'Cortar: coloque a agulha e carregue em Shift+R. Exportar: botão “Renderizar”.'],
    'audacity': ['O Audacity grava e edita áudio.', 'Gravar: botão vermelho. Cortar: selecione e Delete. Exportar: Arquivo › Exportar áudio.'],
    'krita': ['O Krita é para pintar e desenhar.', 'Novo desenho: Arquivo › Novo. Pincéis no painel à direita. Exportar: Arquivo › Exportar.'],
    'inkscape': ['O Inkscape faz desenho vetorial (logotipos, ilustrações, como o Illustrator).', 'Exportar PNG: Arquivo › Exportar (Shift+Ctrl+E).'],
    'thunderbird': ['O Thunderbird é o programa de e-mail.', 'Na primeira vez, escreva o seu e-mail e senha: ele configura sozinho (Gmail, Outlook...).'],
    'vscode': ['O Visual Studio Code é o editor de código.', 'Abrir uma pasta: Arquivo › Abrir pasta. Terminal: Ctrl+`. Extensões: Ctrl+Shift+X.'],
    'telegram': ['O Telegram é para mensagens.', 'Abra e entre com o seu número de telefone; o código chega pelo Telegram do telemóvel.'],
    'zoom': ['O Zoom é para videochamadas.', 'Para entrar numa reunião: “Join” e escreva o número da reunião.'],
    'blender': ['O Blender faz 3D, animação e vídeo.', 'Rodar a vista: botão do meio do rato. Renderizar: F12.'],
    'qbittorrent': ['O qBittorrent descarrega torrents.', 'Arquivo › Adicionar torrent, ou cole o link magnet com Ctrl+V.'],
    'marble': ['O app Mapas (Marble) mostra o globo e mapas do OpenStreetMap.', 'Procure uma cidade na barra de pesquisa. Rotas: separador “Rotas”.'],
    'merkuro': ['O Calendário (Merkuro) guarda eventos e liga à conta Google.',
                'Ligar a Google: menu ☰ › Configurações › Contas/Fontes › Adicionar › Google.',
                'Novo evento: botão + ou clique duas vezes no dia.'],
}


def _desktop(caminho):
    d = {}
    secao = ''
    try:
        with open(caminho, encoding='utf-8', errors='ignore') as f:
            for l in f:
                l = l.strip()
                if l.startswith('['):
                    secao = l
                    continue
                if secao == '[Desktop Entry]' and '=' in l:
                    k, v = l.split('=', 1)
                    if k in ('Name', 'GenericName', 'Comment', 'Keywords', 'Categories', 'Exec', 'Name[pt_BR]',
                             'Comment[pt_BR]', 'GenericName[pt_BR]', 'NoDisplay', 'Terminal', 'Type', 'X-Flatpak'):
                        d.setdefault(k, v)
    except OSError:
        pass
    return d


def _pacote_de(caminho):
    out = subprocess.run(['dpkg', '-S', caminho], capture_output=True, text=True).stdout
    return out.split(':')[0].strip() if out else ''


def _descricao_apt(pacote):
    out = subprocess.run(['apt-cache', 'show', '--no-all-versions', pacote], capture_output=True, text=True, timeout=30).stdout
    m = re.search(r'^Description(?:-[a-zA-Z_]+)?: (.*?)\n((?: .*\n?)*)', out, re.M)
    if not m:
        return ''
    longa = re.sub(r'^ \.?', '', m.group(2), flags=re.M).strip()
    return (m.group(1) + '. ' + re.sub(r'\s+', ' ', longa))[:1200]


def _descricao_flatpak(ident):
    for raiz in (os.path.expanduser('~/.local/share/flatpak'), '/var/lib/flatpak'):
        for f in glob.glob(os.path.join(raiz, 'app', ident, 'current', 'active', 'files', 'share', 'metainfo', '*.xml')):
            try:
                xml = open(f, encoding='utf-8', errors='ignore').read()
            except OSError:
                continue
            resumo = re.search(r'<summary>(.*?)</summary>', xml, re.S)
            desc = re.search(r'<description>(.*?)</description>', xml, re.S)
            txt = (resumo.group(1) if resumo else '') + '. ' + (re.sub(r'<[^>]+>', ' ', desc.group(1)) if desc else '')
            return re.sub(r'\s+', ' ', txt).strip()[:1200]
    return ''


def _ajuda_terminal(exe):
    try:
        out = subprocess.run(['man', '-P', 'cat', exe], capture_output=True, text=True, timeout=10,
                             env=dict(os.environ, MANWIDTH='100')).stdout
    except Exception:
        out = ''
    if out:
        m = re.search(r'(SYNOPSIS|SINOPSE)(.*?)(\n[A-Z][A-Z ]+\n)', out, re.S)
        return re.sub(r'\s+', ' ', m.group(2)).strip()[:600] if m else ''
    return ''


def estudar_app(caminho):
    """Aprende tudo o que dá sobre um aplicativo instalado (.desktop). Devolve o documento."""
    d = _desktop(caminho)
    if not d or d.get('Type', 'Application') != 'Application':
        return None
    nome = d.get('Name[pt_BR]') or d.get('Name', '')
    if not nome:
        return None
    base = os.path.basename(caminho).replace('.desktop', '')
    exe = (d.get('Exec', '').split() or [''])[0]
    flatpak = d.get('X-Flatpak') or (base if exe.endswith('flatpak') else '')
    descricao = _descricao_flatpak(flatpak) if flatpak else _descricao_apt(_pacote_de(caminho))
    comentario = d.get('Comment[pt_BR]') or d.get('Comment', '')
    generico = d.get('GenericName[pt_BR]') or d.get('GenericName', '')
    cats = [c for c in d.get('Categories', '').split(';') if c]
    chave = simples(nome).replace(' ', '')
    guia = next((g for k, g in GUIAS.items() if k in chave or k in simples(base)), None)
    linhas = ['%s%s' % (nome, (' — ' + generico) if generico else '') + (': ' + comentario if comentario else '.')]
    if guia:
        linhas += guia
    linhas.append('Como abrir: clique na estrela (Launchpad) e procure “%s”, ou diga à Eta “abre o %s”. '
                  'Para o ter sempre à mão: botão direito no ícone › Adicionar à Dock.' % (nome, nome))
    for c in cats:
        for dica in DICAS.get(c, []):
            if dica not in linhas:
                linhas.append(dica)
    if descricao:
        linhas.append('Descrição oficial: ' + descricao)
    if exe and not flatpak:
        sinopse = _ajuda_terminal(os.path.basename(exe))
        linhas.append('Pelo terminal: %s%s' % (os.path.basename(exe), ('  (uso: ' + sinopse + ')') if sinopse else ''))
    if flatpak:
        linhas.append('Pelo terminal: flatpak run %s' % flatpak)
    texto = '\n\n'.join(linhas)
    return aprender('app:' + base, nome, texto, 'app', resumo=comentario or generico,
                    extra=dict(desktop=caminho, palavras=d.get('Keywords', '')))


def apps_novos():
    """Aplicativos instalados desde a última vez (ou todos, na primeira vez)."""
    vistos = set(_ler(APPS_VISTOS, []))
    agora = []
    for pasta in PASTAS_APPS:
        agora += glob.glob(os.path.join(pasta, '*.desktop'))
    novos = [c for c in agora if os.path.basename(c) not in vistos]
    return novos, agora


def marcar_vistos(caminhos):
    vistos = set(_ler(APPS_VISTOS, []))
    vistos.update(os.path.basename(c) for c in caminhos)
    _gravar(APPS_VISTOS, sorted(vistos))


def guia_app(nome_ou_texto):
    """O guia de um aplicativo já estudado, pelo nome."""
    q = set(fichas(nome_ou_texto))
    melhor, pontos = None, 0
    for d in documentos():
        if d['origem'] != 'app':
            continue
        t = set(fichas(d['titulo'])) | set(fichas(d.get('palavras', '')))
        p = len(q & set(fichas(d['titulo']))) * 3 + len(q & t)
        if p > pontos:
            melhor, pontos = d, p
    return melhor if pontos >= 3 else None


def resumo_memoria():
    docs = documentos()
    return dict(apps=sum(1 for d in docs if d['origem'] == 'app'),
                arquivos=[d['titulo'] for d in docs if d['origem'] == 'arquivo'],
                notas=[d['titulo'] for d in docs if d['origem'] == 'nota'],
                respostas=len(_ler(RESPOSTAS, [])))
