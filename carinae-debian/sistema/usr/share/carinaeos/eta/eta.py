#!/usr/bin/python3
# CarinaeOS - Eta: assistente do sistema.
# Conversa em portugues, sabe como o CarinaeOS funciona, encontra arquivos por
# palavras-chave e faz tarefas -- mas so depois de o usuario carregar em
# "Permitir" (cada vez). A IA corre no proprio computador (llama.cpp + modelo
# Qwen2.5), descarregado na primeira vez; sem ele, a Eta responde por regras.
import json
import os
import re
import shlex
import shutil
import socket
import subprocess
import sys
import threading
import time
import unicodedata
import urllib.request

sys.path.insert(0, '/usr/share/carinaeos/comum')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base import correr, iniciar  # noqa: E402
from conhecimento import SISTEMA, TOPICOS  # noqa: E402
import acoes as A  # noqa: E402

from PySide6.QtCore import Property, QObject, QTimer, Signal, Slot  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
DADOS = os.path.join(os.environ.get('XDG_DATA_HOME', os.path.expanduser('~/.local/share')), 'carinaeos', 'eta')
MODELO = os.path.join(DADOS, 'modelo.gguf')
URL_MODELO = 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf'
TAMANHO_MODELO = 1117320736
SERVIDOR = '/opt/carinaeos/llama/llama-server'
PORTA = 18765
HOME = os.path.expanduser('~')

PALAVRAS_VAZIAS = set('''a o as os um uma uns umas de da do das dos em no na nos nas para pra pro por com
sem que e ou meu minha meus minhas seu sua teu tua me te se eu voce vc ai la aqui isso esse essa este esta
arquivo arquivos ficheiro ficheiros documento documentos pasta pastas foto fotos imagem imagens video videos
procura procure procurar encontra encontre encontrar acha ache achar localiza localize localizar onde esta
estao fica ficam busca busque buscar mostra mostre mostrar lista liste listar tenho tem chamado chamada
nome sobre quero queria gostaria favor por pode podes consegue'''.split())

EXTENSOES = {
    'foto': ('.jpg', '.jpeg', '.png', '.heic', '.webp', '.gif'), 'fotos': ('.jpg', '.jpeg', '.png', '.heic', '.webp', '.gif'),
    'imagem': ('.jpg', '.jpeg', '.png', '.webp', '.gif', '.svg'), 'imagens': ('.jpg', '.jpeg', '.png', '.webp', '.gif', '.svg'),
    'video': ('.mp4', '.mkv', '.webm', '.mov', '.avi'), 'videos': ('.mp4', '.mkv', '.webm', '.mov', '.avi'),
    'musica': ('.mp3', '.flac', '.ogg', '.m4a', '.wav'), 'musicas': ('.mp3', '.flac', '.ogg', '.m4a', '.wav'),
    'pdf': ('.pdf',), 'planilha': ('.xlsx', '.xls', '.ods', '.csv'), 'planilhas': ('.xlsx', '.xls', '.ods', '.csv'),
    'documento': ('.docx', '.doc', '.odt', '.pdf', '.txt', '.rtf'), 'documentos': ('.docx', '.doc', '.odt', '.pdf', '.txt', '.rtf'),
    'apresentacao': ('.pptx', '.ppt', '.odp'),
}


def simples(t):
    t = unicodedata.normalize('NFD', t.lower())
    return ''.join(c for c in t if unicodedata.category(c) != 'Mn')


def icone_arquivo(caminho):
    if os.path.isdir(caminho):
        return 'folder'
    e = os.path.splitext(caminho)[1].lower()
    for ext, ic in (((
        '.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.svg'), 'image-x-generic'),
            (('.mp4', '.mkv', '.webm', '.mov', '.avi'), 'video-x-generic'),
            (('.mp3', '.flac', '.ogg', '.m4a', '.wav'), 'audio-x-generic'),
            (('.pdf',), 'application-pdf'),
            (('.doc', '.docx', '.odt', '.rtf'), 'x-office-document'),
            (('.xls', '.xlsx', '.ods', '.csv'), 'x-office-spreadsheet'),
            (('.ppt', '.pptx', '.odp'), 'x-office-presentation'),
            (('.zip', '.tar', '.gz', '.7z', '.rar', '.xz'), 'package-x-generic'),
            (('.bloqueado',), 'object-locked')):
        if e in ext:
            return ic
    return 'text-x-generic'


def buscar_arquivos(texto, limite=40):
    """Procura no home por nomes que tenham todas as palavras-chave."""
    palavras = [p for p in re.findall(r'[\w.-]+', simples(texto)) if p not in PALAVRAS_VAZIAS and len(p) > 1]
    exts = ()
    for p in re.findall(r'\w+', simples(texto)):
        if p in EXTENSOES:
            exts = exts + EXTENSOES[p]
    achados = []
    if not palavras and not exts:
        return palavras, []
    for raiz, pastas, arquivos in os.walk(HOME):
        pastas[:] = [d for d in pastas if not d.startswith('.') and d not in ('node_modules', '__pycache__', 'snap')]
        candidatos = [(n, False) for n in arquivos] + ([(n, True) for n in pastas] if not exts else [])
        for nome, e_pasta in candidatos:
            n = simples(nome)
            if not all(p in n for p in palavras):
                continue
            if exts and os.path.splitext(n)[1] not in exts:
                continue
            c = os.path.join(raiz, nome)
            try:
                achados.append((os.path.getmtime(c), c))
            except OSError:
                pass
        if len(achados) > 400:
            break
    achados.sort(reverse=True)
    res = []
    for _, c in achados[:limite]:
        res.append(dict(caminho=c, nome=os.path.basename(c), pasta=os.path.dirname(c).replace(HOME, '~', 1),
                        icone=icone_arquivo(c)))
    return palavras, res


def info_sistema():
    t, u, l = shutil.disk_usage(HOME)
    mem = {}
    try:
        for linha in open('/proc/meminfo'):
            k, v = linha.split(':')
            mem[k] = int(v.split()[0])
    except Exception:
        pass
    gb = lambda b: '%.1f GB' % (b / 1e9)
    ram_total = mem.get('MemTotal', 0) * 1024
    ram_livre = mem.get('MemAvailable', 0) * 1024
    return ('Espaço no disco: %s livres de %s. Memória: %s livres de %s. Processadores: %d.'
            % (gb(l), gb(t), gb(ram_livre), gb(ram_total), os.cpu_count() or 1))


IMPERATIVO = re.compile(r'\b(liga|ligue|ligar|ativa|ative|ativar|poe|ponha|coloca|coloque|aumenta|aumente|aumentar|'
                        r'muda|mude|troca|troque|faz|faca|abre|abra|quero|deixa|deixe)\b|pra mim|para mim')
NEGATIVO = re.compile(r'\b(desliga|desligue|desligar|desativa|desative|desativar|tira|tire|diminui|diminua|diminuir|'
                      r'baixa|baixe|volta|volte|voltar|escuro|apaga|apague)\b')
PERGUNTA = re.compile(r'\b(como|onde|qual|quais|porque|por que|o que)\b')


def topico_para(texto, com_pontos=False):
    s = simples(texto)
    melhor, pontos = None, 0
    for t in TOPICOS:
        ws = [w for w in dict.fromkeys(t['palavras'].split()) if len(w) > 2]
        casa = lambda w: re.search(r'\b' + re.escape(w) + (r'\b' if len(w) <= 4 else ''), s)
        p = sum(1 for w in ws if casa(w))
        if ws and casa(ws[0]):
            p += 2                       # a primeira palavra e o assunto principal
        if not t['resposta'] and not (IMPERATIVO.search(s) or NEGATIVO.search(s)):
            p = 0                        # topicos so de acao
        if p > pontos:
            melhor, pontos = t, p
    if com_pontos:
        return (melhor, pontos) if pontos > 0 else (None, 0)
    return melhor if pontos > 0 else None


def resumo_topicos():
    linhas = []
    for t in TOPICOS:
        a = (' | acao: %s => %s' % t['acao']) if t['acao'] else ''
        if t['resposta']:
            linhas.append('- %s: %s%s' % (t['id'], t['resposta'], a))
    return '\n'.join(linhas)


PROMPT = """Voce e a Eta, a assistente do sistema operacional CarinaeOS. Responda SEMPRE em portugues do Brasil,
de forma curta, simpatica e clara (no maximo 6 frases). Voce so trata de assuntos do computador e do CarinaeOS.

O QUE VOCE SABE SOBRE O SISTEMA:
%s
GUIAS DE CONFIGURACAO (use-os para ensinar):
%s

FERRAMENTAS: quando precisar agir, responda APENAS com um objeto JSON, sem mais nada:
{"ferramenta": "buscar_arquivos", "palavras": "curriculo"}      -> procurar arquivos pelo nome
{"ferramenta": "info_sistema"}                                    -> espaco em disco, memoria
{"ferramenta": "executar", "comando": "kcmshell6 kcm_kscreen", "descricao": "abrir as configuracoes de tela"}
{"ferramenta": "discos"}                 -> ver e abrir discos externos / pen drives (pede a senha se o disco for protegido)
{"ferramenta": "pasta_rede"}             -> ligar a uma pasta de rede (NAS, outro computador), pede endereco, usuario e senha
{"ferramenta": "wifi"}                   -> ligar a uma rede Wi-Fi (mostra as redes e pede a senha)
{"ferramenta": "atualizacoes"}           -> verificar se ha atualizacoes e oferecer atualizar o sistema e os aplicativos
{"ferramenta": "instalar", "nome": "gimp"} -> instalar um programa (pelo terminal com apt, ou pelo Flathub)
{"ferramenta": "terminal", "comando": "sudo apt install -y htop", "descricao": "instalar o htop"}
     -> corre comandos numa janela do terminal (Konsole), a vista do usuario; o sudo pede la a senha.
        Use-o para configurar coisas pelo terminal (apt, systemctl, nano /etc/..., etc.).
O comando "executar" so corre depois de o usuario carregar em Permitir. Use comandos de Linux seguros
(kcmshell6 <modulo>, xdg-open, plasma-apply-wallpaperimage, pactl, kwriteconfig6, carinaeos-supernova,
carinaeos-orbita, systemsettings). Para ensinar, explique o passo a passo e ofereca-se para fazer.
Nunca invente arquivos: para achar arquivos use buscar_arquivos.
Nunca peca senhas no texto: as ferramentas discos, pasta_rede e wifi pedem a senha de forma segura.
Nunca invente caminhos de menus: se o assunto nao estiver nos GUIAS, diga que pode abrir as
Configuracoes do Sistema ({"ferramenta": "executar", "comando": "systemsettings", "descricao": "abrir as Configuracoes do Sistema"}).
"""


class Eta(QObject):
    mudou = Signal()
    _chegou = Signal(str)          # resposta da IA (vem de outra thread)
    _progresso = Signal(float)

    def __init__(self):
        super().__init__()
        self._msgs = []
        self._historico = []       # mensagens para a IA
        self._pensando = False
        self._estado = 'sem-modelo' if not os.path.exists(MODELO) else 'a-iniciar'
        self._baixado = 0.0
        self._proc = None
        self._n = 0
        self._segredos = {}        # id do pedido -> texto para o stdin (senhas): nunca vai para a IA
        self._escolhas = {}        # id da mensagem -> funcoes dos botoes
        self._espera = None        # conversa a meio: {'tipo':..., ...} (ex.: a pedir uma senha)
        self._chegou.connect(self._resposta)
        self._fundo.connect(lambda f, r: f(r))
        self._progresso.connect(self._atualizar_download)
        self._dizer('Olá! Eu sou a Eta ✦ Posso encontrar arquivos, explicar como o CarinaeOS funciona e '
                    'mudar configurações por você — sempre pedindo a sua permissão antes. Em que posso ajudar?')
        if self._estado == 'a-iniciar':
            threading.Thread(target=self._iniciar_ia, daemon=True).start()

    # ---- propriedades -------------------------------------------------------------
    mensagens = Property('QVariantList', lambda s: s._msgs, notify=mudou)
    pensando = Property(bool, lambda s: s._pensando, notify=mudou)
    estado = Property(str, lambda s: s._estado, notify=mudou)
    baixado = Property(float, lambda s: s._baixado, notify=mudou)
    pedeSenha = Property(bool, lambda s: bool(s._espera and s._espera.get('senha')), notify=mudou)
    dicaEntrada = Property(str, lambda s: (s._espera or {}).get('dica', 'Pergunte ou peça algo à Eta…'), notify=mudou)

    _fundo = Signal(object, object)

    def _em_fundo(self, aviso, trabalho, depois):
        """Corre trabalho() numa thread (sem bloquear a janela) e depois(resultado) na janela."""
        if aviso:
            self._dizer(aviso)
        self._pensando = True
        self.mudou.emit()

        def t():
            try:
                r = trabalho()
            except Exception as e:
                r = e
            self._fundo.emit(lambda x: (setattr(self, '_pensando', False), depois(x), self.mudou.emit()), r)
        threading.Thread(target=t, daemon=True).start()

    def _perguntar(self, texto, **espera):
        espera.setdefault('dica', 'Escreva aqui… (ou “cancelar”)')
        self._espera = espera
        self._dizer(texto)

    def _mostrar_escolhas(self, texto, opcoes):
        """opcoes: [dict(icone, nome, detalhe, botoes=[(rotulo, funcao), ...])]"""
        itens, funcs = [], []
        for o in opcoes:
            b = []
            for rot, f in o.get('botoes', []):
                b.append(dict(rotulo=rot, n=len(funcs)))
                funcs.append(f)
            itens.append(dict(icone=o.get('icone', 'drive-removable-media'), nome=o['nome'],
                              detalhe=o.get('detalhe', ''), botoes=b))
        m = self._add(papel='escolhas', texto=texto, opcoes=itens)
        self._escolhas[m['id']] = funcs

    @Slot(int, int)
    def escolher(self, ident, n):
        funcs = self._escolhas.get(ident, [])
        if 0 <= n < len(funcs):
            funcs[n]()

    def _add(self, **m):
        self._n += 1
        m['id'] = self._n
        self._msgs = self._msgs + [m]
        self.mudou.emit()
        return m

    def _dizer(self, texto):
        self._add(papel='eta', texto=texto)

    def _trocar(self, ident, **campos):
        self._msgs = [dict(m, **campos) if m['id'] == ident else m for m in self._msgs]
        self.mudou.emit()

    # ---- IA local ----------------------------------------------------------------------
    @staticmethod
    def _saude():
        try:
            with urllib.request.urlopen('http://127.0.0.1:%d/health' % PORTA, timeout=2) as r:
                return r.status == 200
        except Exception:
            return False

    def _iniciar_ia(self):
        if self._saude():                       # outra janela da Eta ja tem a IA ligada
            self._estado = 'pronta'
            self.mudou.emit()
            return
        if not (os.path.exists(SERVIDOR) and os.path.exists(MODELO)):
            self._estado = 'sem-modelo'
            self.mudou.emit()
            return
        threads = max(1, (os.cpu_count() or 2))
        try:
            self._proc = subprocess.Popen(
                [SERVIDOR, '-m', MODELO, '-c', '8192', '-t', str(threads), '--host', '127.0.0.1',
                 '--port', str(PORTA), '--no-webui'],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            self._estado = 'erro'
            self.mudou.emit()
            return
        for _ in range(240):
            if self._saude():
                self._estado = 'pronta'
                self.mudou.emit()
                return
            if self._proc.poll() is not None:
                break
            time.sleep(0.5)
        self._estado = 'erro'
        self.mudou.emit()

    def _perguntar_ia(self, mensagens):
        corpo = json.dumps(dict(messages=mensagens, temperature=0.3, max_tokens=500)).encode()
        pedido = urllib.request.Request('http://127.0.0.1:%d/v1/chat/completions' % PORTA, data=corpo,
                                        headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(pedido, timeout=180) as r:
            return json.load(r)['choices'][0]['message']['content'].strip()

    def _pensar(self):
        def tarefa():
            try:
                sistema = PROMPT % (SISTEMA, resumo_topicos())
                texto = self._perguntar_ia([dict(role='system', content=sistema)] + self._historico[-14:])
            except Exception as e:
                texto = '__erro__' + str(e)
            self._chegou.emit(texto)
        self._pensando = True
        self.mudou.emit()
        threading.Thread(target=tarefa, daemon=True).start()

    @Slot(str)
    def _resposta(self, texto):
        self._pensando = False
        if texto.startswith('__erro__'):
            self._dizer('Desculpe, não consegui pensar agora. Tente de novo daqui a pouco.')
            return
        acao = self._extrair_json(texto)
        if acao:
            self._historico.append(dict(role='assistant', content=json.dumps(acao, ensure_ascii=False)))
            self._executar_ferramenta(acao, depois_ia=True)
        else:
            self._historico.append(dict(role='assistant', content=texto))
            self._dizer(texto)

    @staticmethod
    def _extrair_json(texto):
        m = re.search(r'\{.*\}', texto, re.S)
        if not m:
            return None
        try:
            d = json.loads(m.group(0))
            return d if isinstance(d, dict) and d.get('ferramenta') else None
        except Exception:
            return None

    # ---- ferramentas ------------------------------------------------------------------
    def _executar_ferramenta(self, acao, depois_ia=False):
        f = acao.get('ferramenta')
        if f == 'buscar_arquivos':
            self._mostrar_busca(acao.get('palavras', ''))
        elif f == 'info_sistema':
            info = info_sistema()
            self._historico.append(dict(role='user', content='RESULTADO: ' + info))
            self._dizer(info)
        elif f == 'discos':
            self._discos()
        elif f == 'pasta_rede':
            self._rede_inicio('')
        elif f == 'wifi':
            self._wifi()
        elif f == 'atualizacoes':
            self._atualizacoes()
        elif f == 'instalar' and acao.get('nome'):
            self._instalar(acao['nome'])
        elif f == 'terminal' and acao.get('comando'):
            self._pedir((acao.get('descricao') or 'executar no terminal') + ' (no terminal)',
                        A.no_terminal(acao['comando']), mostrar=acao['comando'])
        elif f == 'executar' and acao.get('comando'):
            self._pedir(acao.get('descricao') or 'executar um comando', acao['comando'])
        else:
            self._dizer('Não sei fazer isso ainda. Pode explicar de outra forma?')

    def _mostrar_busca(self, palavras):
        chaves, res = buscar_arquivos(palavras)
        if not res:
            txt = 'Não encontrei nenhum arquivo com “%s” na sua pasta pessoal.' % (' '.join(chaves) or palavras)
            self._historico.append(dict(role='user', content='RESULTADO: nenhum arquivo encontrado.'))
            self._dizer(txt)
            return
        self._historico.append(dict(role='user', content='RESULTADO: %d arquivos encontrados: %s' %
                                    (len(res), ', '.join(r['nome'] for r in res[:10]))))
        self._add(papel='arquivos', texto='Encontrei %d %s com “%s”. O que quer fazer?' %
                  (len(res), 'item' if len(res) == 1 else 'itens', ' '.join(chaves) or palavras),
                  arquivos=res)

    def _pedir(self, descricao, comando, segredo=None, mostrar=None, demorado=False):
        m = self._add(papel='pedido', texto='Posso %s?' % descricao, comando=mostrar or comando,
                      estado='pendente', demorado=demorado)
        self._cmd_real = getattr(self, '_cmd_real', {})
        self._cmd_real[m['id']] = comando
        if segredo is not None:
            self._segredos[m['id']] = segredo

    @Slot(int)
    def permitir(self, ident):
        m = next((x for x in self._msgs if x['id'] == ident), None)
        if not m or m.get('estado') != 'pendente':
            return
        self._trocar(ident, estado='a-executar')
        comando = getattr(self, '_cmd_real', {}).get(ident, m['comando'])
        segredo = self._segredos.pop(ident, None)

        def tarefa():
            try:
                r = subprocess.run(['bash', '-lc', comando], capture_output=True, text=True,
                                   timeout=7200 if m.get('demorado') else 600, input=segredo,
                                   start_new_session=True)
                ok, saida = r.returncode == 0, (r.stdout + r.stderr).strip()
            except subprocess.TimeoutExpired:
                ok, saida = True, '(continua a correr)'
            except Exception as e:
                ok, saida = False, str(e)
            self._fim_execucao.emit(ident, ok, saida[-1500:])
        # comandos que abrem janelas ficam a correr: nao esperar por eles
        if re.match(r'^\s*(kcmshell6|systemsettings|carinaeos-(supernova|orbita|cadeado)|xdg-open|dolphin|plasma-discover|spectacle|kinfocenter|konsole)\b', comando):
            subprocess.Popen(['bash', '-lc', comando], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
            self._fim_execucao.emit(ident, True, '')
        else:
            threading.Thread(target=tarefa, daemon=True).start()

    _fim_execucao = Signal(int, bool, str)

    @Slot(int, bool, str)
    def _terminou(self, ident, ok, saida):
        self._trocar(ident, estado='feito' if ok else 'falhou', saida=saida)
        self._historico.append(dict(role='user', content='RESULTADO: %s. %s' % ('feito' if ok else 'falhou', saida[:400])))

    @Slot(int)
    def recusar(self, ident):
        self._segredos.pop(ident, None)
        self._trocar(ident, estado='recusado')
        self._historico.append(dict(role='user', content='RESULTADO: o usuario recusou.'))

    # ---- conversa ------------------------------------------------------------------------
    @Slot(str)
    def enviar(self, texto):
        texto = texto.strip()
        if not texto or self._pensando:
            return
        if self._espera:
            self._continuar(texto)
            return
        self._add(papel='eu', texto=texto)
        self._historico.append(dict(role='user', content=texto))
        s = simples(texto)
        # 0) tarefas do sistema: discos, pastas de rede, Wi-Fi, atualizacoes
        if self._tarefa_sistema(texto, s):
            return
        # 1) procurar arquivos: feito diretamente (mais rapido e fiavel)
        if re.search(r'\b(procur|encontr|ach[ae]|acho|localiz|busc|onde (esta|estao|fica|ficam|guardei)|cade)\w*', s):
            self._mostrar_busca(texto)
            return
        # 2) espaco / memoria
        if re.search(r'\b(espaco|memoria|disco|armazenamento)\b', s) and not re.search(r'\bcomo\b', s):
            self._executar_ferramenta(dict(ferramenta='info_sistema'))
            return
        # 3) assunto conhecido: resposta do guia (fiavel) ou a acao pedida
        t, pontos = topico_para(texto, com_pontos=True)
        if t and (pontos >= 3 or self._estado != 'pronta'):
            negativo = NEGATIVO.search(s) and t.get('desfaz')
            ensinar = PERGUNTA.search(s) and not re.search(r'pra mim|para mim|voce (pode|consegue)', s)
            if not ensinar and (IMPERATIVO.search(s) or negativo) and (t.get('faz') or t.get('desfaz')):
                d, cmd = t['desfaz'] if negativo else t['faz']
                self._dizer('Claro! Vou %s.' % d)
                self._pedir(d, cmd)
                return
            if t['resposta']:
                self._historico.append(dict(role='assistant', content=t['resposta']))
                self._dizer(t['resposta'])
                if t['acao']:
                    self._pedir(t['acao'][0], t['acao'][1])
                return
        # 4) o resto: a IA responde (se estiver ligada)
        if self._estado == 'pronta':
            self._pensar()
            return
        extra = (' Para conversar sobre qualquer assunto do sistema, ative a IA completa no aviso lá em cima.'
                 if self._estado == 'sem-modelo' else '')
        self._dizer('Ainda não sei responder a isso. Experimente perguntar, por exemplo, “como mudo o fundo?”, '
                    '“encontre o meu currículo” ou “quanto espaço tenho livre?”.' + extra)

    # ---- tarefas do sistema ---------------------------------------------------------------
    def _tarefa_sistema(self, texto, s):
        verbo_ligar = r'\b(conect|lig|abr|abre|mont|acess|desbloque|entr|us[ae]|ver|mostr|plug)\w*'
        verbo_tirar = r'\b(ejet|ejecta|desmont|desconect|tir[ae]|remov|retir)\w*'
        disco = r'\b(hd|hdd|ssd|disco|discos|pen ?drive|pendrive|pen|usb|cartao|sd|unidade|externo|externa|bitlocker|luks)\b'
        rede = r'\b(nas|smb|samba|cifs|servidor|compartilhad\w*|partilhad\w*|pasta (de|da|na) rede|unidade de rede|outro computador)\b'
        if re.search(rede, s) and (re.search(verbo_ligar, s) or PERGUNTA.search(s)):
            self._rede_inicio(texto)
            return True
        if re.search(disco, s) and not re.search(r'\b(espaco|livre|cheio|memoria|monitor|tela|ecra|teclado|rato|mouse|fone|colunas|impressora|camara|camera|webcam)\b', s) \
                and (re.search(verbo_ligar + '|' + verbo_tirar, s) or re.search(r'\bexterno|\bpen|\busb', s)):
            self._discos(ejetar=bool(re.search(verbo_tirar, s)))
            return True
        if re.search(r'\b(wi-?fi|wireless|rede sem fio|rede)\b', s) and re.search(r'\b(conect|entr|lig[ao]r? (a|na|no|ao)|outra rede|trocar de rede|mud\w* de rede|redes disponiveis)', s):
            self._wifi()
            return True
        if re.search(r'\b(abr\w*|abre|liga|lanca|inicia)\b.{0,12}\b(terminal|konsole|consola|console|linha de comandos?)\b', s) \
                and not re.search(r'\b(instal|configur|corr|execut|rod)\w*', s):
            self._dizer('Claro! Vou abrir o terminal. Se quiser, diga-me o que quer fazer e eu escrevo os comandos por si.')
            self._pedir('abrir o terminal', 'konsole')
            return True
        m = re.search(r'\b(instal\w*|(?:baix\w*|descarreg\w*)(?=\s+(?:o |a |um |uma )?(?:programa|aplicativo|app|jogo|navegador)))\b\s+(?:o |a |os |as |um |uma )?'
                      r'(?:programa |aplicativo |app |pacote |navegador |jogo )?([\w.+-]+)', s)
        if m and not re.search(r'\b(atualiz|como|onde|tema|fundo|papel|impressora)\w*', s) and \
                m.group(2) not in ('o', 'a', 'um', 'uma', 'programa', 'aplicativo', 'app', 'pacote', 'pelo', 'no', 'na', 'isso', 'algo'):
            self._instalar(m.group(2), terminal=bool(re.search(r'\b(terminal|apt|sudo|comando)\b', s)))
            return True
        if re.search(r'\b(atualiz\w*|update|upgrade|atualizacoes)\b', s) and not re.search(r'\b(pagina|navegador|lista de arquivos)\b', s):
            self._atualizacoes()
            return True
        return False

    def _continuar(self, texto):
        e, self._espera = self._espera, None
        if e.get('senha'):
            self._add(papel='eu', texto='•' * min(len(texto), 12))
        else:
            self._add(papel='eu', texto=texto)
        if simples(texto).strip() in ('cancelar', 'cancela', 'deixa', 'esquece', 'nao', 'sair'):
            self._dizer('Ok, cancelei. Em que mais posso ajudar?')
            self.mudou.emit()
            return
        e['seguinte'](texto)
        self.mudou.emit()

    # discos externos
    def _discos(self, ejetar=False, de_novo=False):
        def depois(lista):
            if isinstance(lista, Exception) or not lista:
                if ejetar:
                    self._dizer('Não há nenhum disco externo ligado: pode tirar o cabo à vontade.')
                elif de_novo:
                    self._dizer('Continuo sem ver nenhum disco. Experimente outra porta USB ou outro cabo; se o disco '
                                'tiver luz, veja se acende. Quando quiser, peça-me de novo.')
                else:
                    self._dizer('Não estou a ver nenhum disco externo ligado. Ligue o HD ou o pen drive na porta USB, '
                                'espere uns segundos e diga “pronto”.')
                    self._espera = dict(dica='Escreva “pronto” quando estiver ligado',
                                        seguinte=lambda t: self._discos(False, True))
                return
            if ejetar:
                montados = [d for d in lista if d['montado'] or d['desbloqueado']] or lista
                if len(montados) == 1:
                    d = montados[0]
                    self._dizer('Vou fechar o “%s” para poder tirar o cabo sem perder nada.' % d['nome'])
                    self._pedir('ejetar o disco “%s”' % d['nome'], A.cmd_ejetar(d))
                    return
            opcoes = []
            for d in lista:
                b = []
                if d['montado']:
                    b.append(('Abrir', lambda d=d: correr(['dolphin', d['montado']], espera=False)))
                else:
                    b.append(('Conectar', lambda d=d: self._conectar_disco(d)))
                b.append(('Ejetar', lambda d=d: self._pedir('ejetar o disco “%s”' % d['nome'], A.cmd_ejetar(d))))
                opcoes.append(dict(icone='drive-removable-media-usb' if not d['cifrado'] else 'drive-removable-media-encrypted',
                                   nome=d['nome'], detalhe=A.descrever_disco(d), botoes=b))
            if len(lista) == 1 and not lista[0]['montado'] and not ejetar:
                self._conectar_disco(lista[0])
                return
            self._mostrar_escolhas('Encontrei %d %s. O que quer fazer?' % (len(lista), 'disco' if len(lista) == 1 else 'discos'), opcoes)
        self._em_fundo(None, A.discos_externos, depois)

    def _conectar_disco(self, d):
        if d['cifrado'] and not d['desbloqueado']:
            tipo = 'BitLocker (Windows)' if d['sistema'] == 'BitLocker' else 'senha'
            self._perguntar('O disco “%s” (%s) está protegido com %s. Qual é a senha dele? '
                            'Ela fica só neste computador: não aparece na conversa nem vai para a IA.'
                            % (d['nome'], d['tamanho'], tipo),
                            senha=True, dica='Senha do disco (ou “cancelar”)',
                            seguinte=lambda senha: self._pedir(
                                'desbloquear e abrir o disco “%s”' % d['nome'], A.cmd_desbloquear(d), segredo=senha,
                                mostrar='udisksctl unlock -b %s  (senha: ••••••)  →  abrir nos Arquivos' % d['dispositivo']))
            return
        self._dizer('Encontrei o “%s” (%s). Posso abri-lo nos Arquivos.' % (d['nome'], A.descrever_disco(d)))
        self._pedir('abrir o disco “%s”' % d['nome'], A.cmd_montar(d),
                    mostrar='udisksctl mount -b %s  →  abrir nos Arquivos' % (d['aberto_dev'] or d['dispositivo']))

    # pastas de rede
    def _rede_inicio(self, texto):
        url = A.endereco_rede(texto, frase=True) if texto else None
        if url:
            return self._rede_usuario(url)
        self._perguntar('Qual é o endereço da pasta de rede? Por exemplo: 192.168.1.20/fotos, '
                        '\\\\SERVIDOR\\Documentos ou nas.local/backup.',
                        dica='Endereço da pasta de rede',
                        seguinte=lambda t: self._rede_usuario(A.endereco_rede(t)) if A.endereco_rede(t)
                        else self._rede_inicio(''))

    def _rede_usuario(self, url):
        self._perguntar('Vou ligar a %s. Qual é o nome de usuário? (Se a pasta for aberta a todos, escreva “nenhum”.)' % url,
                        dica='Usuário (ou “nenhum”)',
                        seguinte=lambda u: self._rede_senha(url, u.strip()))

    def _rede_senha(self, url, usuario):
        if simples(usuario) in ('nenhum', 'nenhuma', 'anonimo', 'convidado', 'sem usuario', '-'):
            self._pedir('ligar à pasta de rede %s' % url, A.cmd_rede(url, True))
            return
        self._perguntar('E a senha do usuário “%s”? Fica só neste computador.' % usuario,
                        senha=True, dica='Senha da pasta de rede',
                        seguinte=lambda senha: self._pedir(
                            'ligar à pasta de rede %s como “%s”' % (url, usuario), A.cmd_rede(url, False),
                            segredo=A.stdin_rede(usuario, senha),
                            mostrar='gio mount %s  (usuário %s, senha: ••••••)' % (url, usuario)))

    # Wi-Fi
    def _wifi(self):
        def depois(redes):
            if isinstance(redes, Exception) or not redes:
                self._dizer('Não encontrei redes Wi-Fi. Este computador tem Wi-Fi ligado? Posso abrir as configurações de rede.')
                self._pedir('abrir as configurações de rede', 'kcmshell6 kcm_networkmanagement')
                return
            opcoes = []
            for r in redes:
                det = 'sinal %d%%%s%s' % (r['sinal'], ' · com senha' if r['segura'] else ' · aberta',
                                          ' · ligada agora' if r['ligada'] else '')
                opcoes.append(dict(icone='network-wireless-signal-%s' % ('excellent' if r['sinal'] > 75 else 'good' if r['sinal'] > 50 else 'ok' if r['sinal'] > 25 else 'weak'),
                                   nome=r['ssid'], detalhe=det,
                                   botoes=[] if r['ligada'] else [('Ligar', lambda r=r: self._wifi_ligar(r))]))
            self._mostrar_escolhas('Estas são as redes Wi-Fi que encontrei. A qual quer ligar?', opcoes)
        self._em_fundo('Vou procurar as redes Wi-Fi à sua volta…', A.redes_wifi, depois)

    def _wifi_ligar(self, r):
        if not r['segura']:
            self._pedir('ligar à rede “%s”' % r['ssid'], A.cmd_wifi(r['ssid'], False))
            return
        self._perguntar('Qual é a senha da rede “%s”?' % r['ssid'], senha=True, dica='Senha do Wi-Fi',
                        seguinte=lambda senha: self._pedir(
                            'ligar à rede “%s”' % r['ssid'], A.cmd_wifi(r['ssid'], True), segredo=senha + '\n',
                            mostrar='nmcli device wifi connect "%s"  (senha: ••••••)' % r['ssid']))

    # atualizacoes
    def _atualizacoes(self):
        def depois(r):
            if isinstance(r, Exception):
                self._dizer('Não consegui verificar as atualizações (%s). Está ligado à internet?' % r)
                return
            sistema, apps, seguranca = r
            if not sistema and not apps:
                self._dizer('Está tudo em dia ✓ O sistema e os aplicativos já têm as versões mais recentes.')
                return
            partes = []
            if sistema:
                ex = ', '.join(sistema[:5]) + ('…' if len(sistema) > 5 else '')
                partes.append('%d %s do sistema (%s)' % (len(sistema), 'atualização' if len(sistema) == 1 else 'atualizações', ex))
            if apps:
                partes.append('%d de aplicativos (%s)' % (len(apps), ', '.join(apps[:4])))
            txt = 'Há ' + ' e '.join(partes) + '.'
            if seguranca:
                txt += ' %d %s de segurança: recomendo instalar já.' % (seguranca, 'é' if seguranca == 1 else 'são')
            if A.AO_VIVO:
                txt += ' Atenção: está a usar o CarinaeOS sem instalar, por isso as atualizações perdem-se ao desligar.'
            txt += ' Pode demorar uns minutos; o sistema pode pedir a sua senha.'
            self._historico.append(dict(role='user', content='RESULTADO: ' + txt))
            self._dizer(txt)
            self._pedir('instalar as atualizações agora', A.cmd_atualizar(sistema, apps), demorado=True)
        self._em_fundo('Vou ver se há atualizações para o sistema e para os aplicativos… (pode levar um minuto)',
                       A.verificar_atualizacoes, depois)

    # instalar programas: apt (no terminal, a vista) ou Flathub
    NOMES = {'chrome': 'com.google.Chrome', 'google chrome': 'com.google.Chrome', 'spotify': 'com.spotify.Client',
             'discord': 'com.discordapp.Discord', 'zoom': 'us.zoom.Zoom', 'steam': 'com.valvesoftware.Steam',
             'whatsapp': 'com.rtosta.zapzap', 'telegram': 'org.telegram.desktop', 'obs': 'com.obsproject.Studio',
             'vscode': 'com.visualstudio.code', 'code': 'com.visualstudio.code', 'brave': 'com.brave.Browser',
             'edge': 'com.microsoft.Edge', 'teams': 'com.github.IsmaelMartinez.teams_for_linux'}
    APT = {'libreoffice': 'libreoffice', 'office': 'libreoffice', 'gimp': 'gimp', 'vlc': 'vlc', 'inkscape': 'inkscape',
           'chromium': 'chromium', 'thunderbird': 'thunderbird', 'krita': 'krita', 'kdenlive': 'kdenlive',
           'htop': 'htop', 'git': 'git', 'python': 'python3', 'java': 'default-jre', 'nano': 'nano',
           'audacity': 'audacity', 'blender': 'blender', 'firefox': 'firefox-esr', 'transmission': 'transmission-qt',
           'qbittorrent': 'qbittorrent', 'okular': 'okular', 'kate': 'kate', 'neofetch': 'fastfetch', 'fastfetch': 'fastfetch'}

    def _instalar(self, nome, terminal=False):
        chave = simples(nome).strip().lower()

        def procurar():
            if chave in self.NOMES and not terminal:
                return ('flathub', self.NOMES[chave], nome)
            pac = A.pacote_apt(self.APT.get(chave, chave))
            if pac:
                return ('apt', pac, A.instalado_apt(pac))
            if chave in self.NOMES:
                return ('flathub', self.NOMES[chave], nome)
            f = A.app_flathub(nome)
            return ('flathub', f[0], f[1]) if f else None

        def depois(r):
            if isinstance(r, Exception) or not r:
                self._dizer('Não encontrei nenhum programa chamado “%s” nos repositórios do Debian nem no Flathub. '
                            'Pode verificar o nome? Também pode procurar na loja Órbita.' % nome)
                self._pedir('abrir a loja Órbita', 'carinaeos-orbita')
                return
            tipo, ident, extra = r
            aviso = (' Como está a usar o CarinaeOS sem instalar, o programa some ao desligar.' if A.AO_VIVO else '')
            if tipo == 'apt':
                if extra:
                    self._dizer('O “%s” já está instalado ✓' % ident)
                    return
                cmd = 'sudo apt-get update && sudo apt-get install -y %s' % shlex.quote(ident)
                self._dizer('Encontrei o pacote “%s” no Debian. Vou instalá-lo pelo terminal: abro uma janela do '
                            'Konsole para ver o progresso, e o sistema pede lá a sua senha.%s' % (ident, aviso))
                self._pedir('instalar o “%s” pelo terminal' % ident, A.no_terminal(cmd, 'Instalar ' + ident), mostrar=cmd)
            else:
                cmd = 'flatpak install --user -y flathub %s' % shlex.quote(ident)
                self._dizer('Encontrei “%s” no Flathub (%s). Vou instalá-lo pelo terminal, onde pode ver o progresso.%s'
                            % (extra, ident, aviso))
                self._pedir('instalar “%s”' % extra, A.no_terminal(cmd + ' && kbuildsycoca6 >/dev/null 2>&1', 'Instalar ' + str(extra)),
                            mostrar=cmd)
        self._em_fundo('Vou procurar o “%s”…' % nome, procurar, depois)

    @Slot()
    def limpar(self):
        self._espera = None
        self._msgs = []
        self._historico = []
        self._dizer('Conversa limpa. Em que posso ajudar?')

    # ---- arquivos -----------------------------------------------------------------------
    @Slot(str)
    def abrirArquivo(self, caminho):
        correr(['xdg-open', caminho], espera=False)

    @Slot(str)
    def mostrarNaPasta(self, caminho):
        correr(['dolphin', '--select', caminho], espera=False)

    @Slot(str)
    def bloquearArquivo(self, caminho):
        correr(['carinaeos-cadeado', 'bloquear', caminho], espera=False)

    # ---- descarregar o "cerebro" ------------------------------------------------------
    @Slot()
    def baixarCerebro(self):
        if self._estado == 'a-baixar':
            return
        self._estado = 'a-baixar'
        self._baixado = 0.0
        self.mudou.emit()

        def tarefa():
            os.makedirs(DADOS, exist_ok=True)
            parte = MODELO + '.parte'
            try:
                inicio = os.path.getsize(parte) if os.path.exists(parte) else 0
                pedido = urllib.request.Request(URL_MODELO, headers={'Range': 'bytes=%d-' % inicio} if inicio else {})
                with urllib.request.urlopen(pedido, timeout=60) as r, open(parte, 'ab' if inicio else 'wb') as f:
                    total = int(r.headers.get('Content-Length', 0)) + inicio or TAMANHO_MODELO
                    feito = inicio
                    while True:
                        bloco = r.read(1 << 20)
                        if not bloco:
                            break
                        f.write(bloco)
                        feito += len(bloco)
                        self._progresso.emit(feito / total)
                if os.path.getsize(parte) < TAMANHO_MODELO * 0.98:
                    raise IOError('download incompleto')
                os.replace(parte, MODELO)
                self._progresso.emit(2.0)       # sinal de "terminou"
            except Exception:
                self._progresso.emit(-1.0)
        threading.Thread(target=tarefa, daemon=True).start()

    @Slot(float)
    def _atualizar_download(self, v):
        if v < 0:
            self._estado = 'sem-modelo'
            self._dizer('O download foi interrompido. Verifique a internet e tente outra vez (continua de onde parou).')
        elif v >= 2.0:
            self._estado = 'a-iniciar'
            self._dizer('Pronto! O meu cérebro foi instalado. Agora posso conversar sobre tudo do sistema ✦')
            threading.Thread(target=self._iniciar_ia, daemon=True).start()
        else:
            self._baixado = v
        self.mudou.emit()

    def fechar(self):
        if self._proc and self._proc.poll() is None:
            self._proc.terminate()


if __name__ == '__main__':
    eta = Eta()
    eta._fim_execucao.connect(eta._terminou)
    # "carinaeos-eta pergunta..." (vindo da busca Ctrl+Espaço) já chega perguntado
    pergunta = ' '.join(sys.argv[1:]).strip()
    if pergunta:
        from PySide6.QtCore import QTimer as _T
        _T.singleShot(400, lambda: eta.enviar(pergunta))
    try:
        codigo = iniciar('carinaeos-eta', 'Eta', 'carinaeos-eta', os.path.join(AQUI, 'Main.qml'), {'eta': eta})
    finally:
        eta.fechar()
    sys.exit(codigo)
