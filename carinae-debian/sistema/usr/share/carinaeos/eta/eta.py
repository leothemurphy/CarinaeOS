#!/usr/bin/python3
# CarinaeOS - Eta: assistente do sistema.
# Conversa em portugues (escrita ou falada), sabe como o CarinaeOS funciona, encontra
# arquivos, le os arquivos que lhe enviam, controla a casa (Home Assistant) e faz tarefas.
# Abrir pastas, apps e configuracoes e imediato; instalar, atualizar ou mexer no sistema
# pede sempre "Permitir". Tudo o que esta a fazer aparece em tempo real, com "Parar".
# A IA corre no proprio computador (llama.cpp + Qwen2.5; voz: whisper.cpp + Piper).
import json
import os
import re
import shlex
import shutil
import signal
import subprocess
import sys
import threading
import time
import unicodedata
import urllib.request

sys.path.insert(0, '/usr/share/carinaeos/comum')
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from base import Icones, correr  # noqa: E402
from conhecimento import SISTEMA, TOPICOS  # noqa: E402
from terminal import COMANDOS  # noqa: E402
import acoes as A  # noqa: E402
import arquivos as ARQ  # noqa: E402
import voz as VOZ  # noqa: E402
import casa_ha as HA  # noqa: E402
import ambiente as AMBI  # noqa: E402
import apps as APPS  # noqa: E402
import memoria as MEM  # noqa: E402
import cerebro as CB  # noqa: E402
from pensamento import Pensamento  # noqa: E402

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot  # noqa: E402

AQUI = os.path.dirname(os.path.abspath(__file__))
DADOS = os.path.join(os.environ.get('XDG_DATA_HOME', os.path.expanduser('~/.local/share')), 'carinaeos', 'eta')
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




def terminal_para(texto):
    """A entrada de COMANDOS que melhor responde a "como faco X pelo terminal"."""
    s = re.sub(r'\b(pelo|no|via|na|do|da)?\s*(terminal|konsole|linha de comandos?|comandos?|bash|shell)\b', ' ', simples(texto))
    if not re.search(r'\w{4,}', re.sub(r'\b(como|uso|usar|faco|fazer|qual|quais|ensina|o|a|um|uma)\b', '', s)):
        s = 'terminal basicos'
    melhor, pontos = None, 0
    def casa(w):
        if len(w) > 5:
            w = w[:-2]                  # raiz: formatar ~ formato, compactar ~ compacto
        return re.search(r'\b' + re.escape(w) + (r'\b' if len(w) <= 3 else ''), s)
    for c in COMANDOS:
        ws = [w for w in dict.fromkeys(c['palavras'].split()) if len(w) >= 2]
        p = sum(1 for w in ws if casa(w))
        if ws and casa(ws[0]):
            p += 2
        if p > pontos:
            melhor, pontos = c, p
    return melhor if pontos >= 2 else None


# comandos que so abrem janelas: nunca pedem permissao
ABRIR = re.compile(r'^\s*(kcmshell6|systemsettings|carinaeos-(supernova|orbita|casa|ambientes)|xdg-open|dolphin|konsole(?!.*-e)|'
                   r'gio launch|gnome-control-center|xfce4-[\w-]*settings[\w-]*|xfce4-about|xfdesktop-settings|nm-connection-editor|'
                   r'blueman-manager|pavucontrol|nautilus|thunar|system-config-printer|'
                   r'plasma-discover|spectacle|kinfocenter|kate|okular|gwenview|firefox(-esr)?|marble|merkuro\S*|kcalc|'
                   r'gtk-launch|kioclient\d? exec|flatpak run)\b')
# comandos que mudam o sistema a serio: pedem sempre permissao
PERIGOSO = re.compile(r'\b(apt|apt-get|dpkg|aptitude|pkcon|pkexec|sudo|flatpak\s+(install|uninstall|update|remove)|'
                      r'rm|rmdir|shred|dd|mkfs\S*|fdisk|parted|wipefs|chmod|chown|userdel|deluser|useradd|adduser|'
                      r'passwd|systemctl\s+(stop|disable|mask|poweroff|reboot)|shutdown|reboot|poweroff|crontab|'
                      r'mv\s+/|kill|pkill|killall)\b')


def precisa_permissao(cmd, de_confianca=False):
    if ABRIR.match(cmd) and not PERIGOSO.search(cmd):
        return False
    if PERIGOSO.search(cmd):
        return True
    return not de_confianca          # comandos inventados pela IA: confirmar sempre


PROMPT = """Voce e a Eta, a assistente do sistema operacional CarinaeOS. Responda SEMPRE em portugues do Brasil,
de forma curta, simpatica e clara (no maximo 6 frases). Voce trata de assuntos do computador e do CarinaeOS.

O QUE VOCE SABE SOBRE O SISTEMA:
%s
GUIAS DE CONFIGURACAO (use-os para ensinar):
%s
%s
FERRAMENTAS: quando precisar agir, responda APENAS com um objeto JSON, sem mais nada:
{"ferramenta": "buscar_arquivos", "palavras": "curriculo"}      -> procurar arquivos pelo nome
{"ferramenta": "info_sistema"}                                    -> espaco em disco, memoria
{"ferramenta": "abrir", "comando": "kcmshell6 kcm_kscreen", "descricao": "as configuracoes de tela"}
{"ferramenta": "executar", "comando": "kwriteconfig6 ...", "descricao": "mudar X"}
{"ferramenta": "discos"}              -> ver e abrir discos externos / pen drives
{"ferramenta": "pasta_rede"}          -> ligar a uma pasta de rede (NAS)
{"ferramenta": "wifi"}                -> ligar a uma rede Wi-Fi
{"ferramenta": "atualizacoes"}        -> verificar e instalar atualizacoes
{"ferramenta": "instalar", "nome": "gimp"}   -> instalar um programa
{"ferramenta": "terminal", "comando": "sudo apt install -y htop", "descricao": "instalar o htop"}
{"ferramenta": "casa", "pedido": "acende a luz da sala"}   -> controlar a casa (Home Assistant)
"abrir" corre logo; "executar", "instalar" e "terminal" pedem Permitir ao usuario.
Responda SO ao ULTIMO pedido do usuario; nunca repita acoes de pedidos antigos.
Se o pedido nao for claro, NAO adivinhe: faca uma pergunta curta com 2 ou 3 opcoes.
O ambiente de trabalho em uso e o %s.
Quando perguntarem COMO fazer algo PELO TERMINAL, responda com os comandos num bloco ``` e explique cada um.
Nunca invente arquivos: para achar arquivos use buscar_arquivos. Nunca peca senhas no texto.
Nunca invente caminhos de menus: se o assunto nao estiver nos GUIAS, ofereca abrir as Configuracoes do Sistema
({"ferramenta": "abrir", "comando": "systemsettings", "descricao": "as Configuracoes do Sistema"}).
"""


class Tarefas:
    """Tarefas do sistema da Eta (misturadas na classe Eta)."""

    NOMES = {'chrome': 'com.google.Chrome', 'google chrome': 'com.google.Chrome', 'spotify': 'com.spotify.Client',
             'discord': 'com.discordapp.Discord', 'zoom': 'us.zoom.Zoom', 'steam': 'com.valvesoftware.Steam',
             'whatsapp': 'com.rtosta.zapzap', 'telegram': 'org.telegram.desktop', 'obs': 'com.obsproject.Studio',
             'vscode': 'com.visualstudio.code', 'code': 'com.visualstudio.code', 'brave': 'com.brave.Browser',
             'edge': 'com.microsoft.Edge', 'teams': 'com.github.IsmaelMartinez.teams_for_linux',
             'netflix': 'com.netflix.Netflix', 'minecraft': 'com.mojang.Minecraft'}
    APT = {'libreoffice': 'libreoffice', 'office': 'libreoffice', 'gimp': 'gimp', 'vlc': 'vlc', 'inkscape': 'inkscape',
           'chromium': 'chromium', 'thunderbird': 'thunderbird', 'krita': 'krita', 'kdenlive': 'kdenlive',
           'htop': 'htop', 'git': 'git', 'python': 'python3', 'java': 'default-jre', 'nano': 'nano',
           'audacity': 'audacity', 'blender': 'blender', 'firefox': 'firefox-esr', 'transmission': 'transmission-qt',
           'qbittorrent': 'qbittorrent', 'okular': 'okular', 'kate': 'kate', 'neofetch': 'fastfetch', 'fastfetch': 'fastfetch',
           'mapas': 'marble', 'calendario': 'merkuro'}

    def _tarefa_sistema(self, texto, s):
        verbo_ligar = r'\b(conect|lig|abr|abre|mont|acess|desbloque|entr|us[ae]|ver|mostr|plug)\w*'
        verbo_tirar = r'\b(ejet|ejecta|desmont|desconect|tir[ae]|remov|retir)\w*'
        disco = r'\b(hd|hdd|ssd|disco|discos|pen ?drive|pendrive|pen|usb|cartao|sd|unidade|externo|externa|bitlocker|luks)\b'
        rede = r'\b(nas|smb|samba|cifs|servidor|compartilhad\w*|partilhad\w*|pasta (de|da|na) rede|unidade de rede|outro computador)\b'
        # casa (Home Assistant)
        if self._casa_pedido(texto, s):
            return True
        if re.search(r'\b(home ?assistant|casa inteligente|domotica)\b', s) and not self._casa:
            self._fazer('abrir a Casa', 'carinaeos-casa')
            return True
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
            self._fazer('abrir o terminal', 'konsole')
            return True
        if re.search(r'\b(abr\w*|abre|mostra)\b.{0,10}\b(mapa|mapas)\b', s):
            self._fazer('abrir os Mapas', 'marble')
            return True
        if re.search(r'\b(abr\w*|abre|mostra)\b.{0,10}\b(calendario|agenda)\b', s):
            self._fazer('abrir o Calendário', 'merkuro-calendar')
            return True
        if re.search(r'\b(gnome|xfce|ambiente de trabalho|outro ambiente|trocar de ambiente)\b', s):
            self._fazer('abrir a troca de ambiente de trabalho', 'carinaeos-ambientes')
            return True
        m = re.search(r'\b(instal\w*|(?:baix\w*|descarreg\w*)(?=\s+(?:o |a |um |uma )?(?:programa|aplicativo|app|jogo|navegador)))\b\s+'
                      r'(?:o |a |os |as |um |uma )?(?:programa |aplicativo |app |pacote |navegador |jogo )?([\w.+-]+)', s)
        if m and not re.search(r'\b(atualiz|como|onde|tema|fundo|papel|impressora)\w*', s) and \
                m.group(2) not in ('o', 'a', 'um', 'uma', 'programa', 'aplicativo', 'app', 'pacote', 'pelo', 'no', 'na', 'isso', 'algo'):
            self._instalar(m.group(2), terminal=bool(re.search(r'\b(terminal|apt|sudo|comando)\b', s)))
            return True
        if re.search(r'\b(atualiz\w*|update|upgrade|atualizacoes)\b', s) and not re.search(r'\b(pagina|navegador|lista de arquivos)\b', s):
            self._atualizacoes()
            return True
        return False

    # ---- casa (Home Assistant) -------------------------------------------------------------
    def _atualizar_casa(self):
        try:
            self._casa = HA.entidades()
            self._casa_quando = time.time()
        except Exception:
            pass

    def _casa_pedido(self, texto, s):
        if not self._casa:
            return False
        if time.time() - self._casa_quando > 120:
            threading.Thread(target=self._atualizar_casa, daemon=True).start()
        acao_ligar = re.search(r'\b(liga|ligue|ligar|acende|acenda|acender|abre|abra|abrir|ativa|ative|ativar|poe|ponha)\b', s)
        acao_desligar = re.search(r'\b(desliga|desligue|desligar|apaga|apague|apagar|fecha|feche|fechar|desativa|desative)\b', s)
        pergunta = re.search(r'\b(qual|quanto|quantos|como esta|esta ligad|esta acesa|temperatura|humidade|umidade)\b', s)
        if not (acao_ligar or acao_desligar or pergunta or re.search(r'\b(cena|modo)\b', s)):
            return False
        e = HA.procurar(texto, self._casa)
        if not e:
            return False
        nome = e['nome']
        if pergunta and e['dominio'] in ('sensor', 'binary_sensor', 'climate', 'light', 'switch', 'cover', 'lock'):
            if e['dominio'] == 'climate':
                v = 'está a %s°' % e['temperatura'] if e['temperatura'] != '' else 'está %s' % e['estado']
            elif e['dominio'] == 'sensor':
                v = 'marca %s %s' % (e['estado'], e['unidade'])
            else:
                v = {'on': 'está ligado', 'off': 'está desligado', 'open': 'está aberto', 'closed': 'está fechado',
                     'locked': 'está trancado', 'unlocked': 'está destrancado'}.get(e['estado'], 'está “%s”' % e['estado'])
            self._dizer('%s %s.' % (nome, v))
            return True
        m_pct = re.search(r'(\d{1,3})\s*(%|por cento)', s)
        m_graus = re.search(r'(\d{1,2}(?:[.,]\d)?)\s*(graus|°)', s)
        ligar = True if acao_ligar else (False if acao_desligar else None)

        def trabalho():
            if e['dominio'] == 'light' and m_pct:
                HA.brilho(e['id'], int(m_pct.group(1)))
                return 'Pus %s a %s%% ✓' % (nome, m_pct.group(1))
            if e['dominio'] == 'climate' and m_graus:
                HA.temperatura(e['id'], m_graus.group(1).replace(',', '.'))
                return 'Pus %s nos %s° ✓' % (nome, m_graus.group(1))
            HA.alternar(e['id'], ligar)
            if e['dominio'] in ('scene', 'script'):
                return 'Ativei “%s” ✓' % nome
            verbo = {True: 'Liguei', False: 'Desliguei', None: 'Alternei'}[ligar]
            if e['dominio'] == 'light':
                verbo = {True: 'Acendi', False: 'Apaguei', None: 'Alternei'}[ligar]
            if e['dominio'] == 'cover':
                verbo = {True: 'Abri', False: 'Fechei', None: 'Mexi em'}[ligar]
            return '%s %s ✓' % (verbo, nome)

        def depois(r):
            if isinstance(r, Exception):
                self._dizer('O Home Assistant não respondeu (%s).' % r)
            else:
                self._add(papel='feito', texto=r)
                self._talvez_falar(r.replace(' ✓', ''))
            threading.Thread(target=self._atualizar_casa, daemon=True).start()
        self._em_fundo(None, trabalho, depois, atividade='A falar com a casa…')
        return True

    # ---- discos externos ---------------------------------------------------------------------
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
                    self._fazer('ejetar o disco “%s”' % d['nome'], A.cmd_ejetar(d))
                    return
            opcoes = []
            for d in lista:
                b = []
                if d['montado']:
                    b.append(('Abrir', lambda d=d: correr(['dolphin', d['montado']], espera=False)))
                else:
                    b.append(('Conectar', lambda d=d: self._conectar_disco(d)))
                b.append(('Ejetar', lambda d=d: self._fazer('ejetar o disco “%s”' % d['nome'], A.cmd_ejetar(d))))
                opcoes.append(dict(icone='drive-removable-media-usb' if not d['cifrado'] else 'drive-removable-media-encrypted',
                                   nome=d['nome'], detalhe=A.descrever_disco(d), botoes=b))
            if len(lista) == 1 and not lista[0]['montado'] and not ejetar:
                self._conectar_disco(lista[0])
                return
            self._mostrar_escolhas('Encontrei %d %s. O que quer fazer?' % (len(lista), 'disco' if len(lista) == 1 else 'discos'), opcoes)
        self._em_fundo(None, A.discos_externos, depois, atividade='A procurar discos…')

    def _conectar_disco(self, d):
        if d['cifrado'] and not d['desbloqueado']:
            tipo = 'BitLocker (Windows)' if d['sistema'] == 'BitLocker' else 'senha'
            self._perguntar('O disco “%s” (%s) está protegido com %s. Qual é a senha dele? '
                            'Ela fica só neste computador: não aparece na conversa nem vai para a IA.'
                            % (d['nome'], d['tamanho'], tipo),
                            senha=True, dica='Senha do disco (ou “cancelar”)',
                            seguinte=lambda senha: self._fazer(
                                'desbloquear e abrir o disco “%s”' % d['nome'], A.cmd_desbloquear(d), segredo=senha,
                                mostrar='udisksctl unlock -b %s  (senha: ••••••)  →  abrir nos Arquivos' % d['dispositivo']))
            return
        self._fazer('abrir o disco “%s” (%s)' % (d['nome'], d['tamanho']), A.cmd_montar(d),
                    mostrar='udisksctl mount -b %s  →  abrir nos Arquivos' % (d['aberto_dev'] or d['dispositivo']))

    # ---- pastas de rede ----------------------------------------------------------------------
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
            self._fazer('ligar à pasta de rede %s' % url, A.cmd_rede(url, True))
            return
        self._perguntar('E a senha do usuário “%s”? Fica só neste computador.' % usuario,
                        senha=True, dica='Senha da pasta de rede',
                        seguinte=lambda senha: self._fazer(
                            'ligar à pasta de rede %s como “%s”' % (url, usuario), A.cmd_rede(url, False),
                            segredo=A.stdin_rede(usuario, senha),
                            mostrar='gio mount %s  (usuário %s, senha: ••••••)' % (url, usuario)))

    # ---- Wi-Fi --------------------------------------------------------------------------------
    def _wifi(self):
        def depois(redes):
            if isinstance(redes, Exception) or not redes:
                self._dizer('Não encontrei redes Wi-Fi. Este computador tem Wi-Fi ligado?')
                self._fazer('abrir as configurações de rede', 'kcmshell6 kcm_networkmanagement')
                return
            opcoes = []
            for r in redes:
                det = 'sinal %d%%%s%s' % (r['sinal'], ' · com senha' if r['segura'] else ' · aberta',
                                          ' · ligada agora' if r['ligada'] else '')
                opcoes.append(dict(icone='network-wireless-signal-%s' % ('excellent' if r['sinal'] > 75 else 'good' if r['sinal'] > 50 else 'ok' if r['sinal'] > 25 else 'weak'),
                                   nome=r['ssid'], detalhe=det,
                                   botoes=[] if r['ligada'] else [('Ligar', lambda r=r: self._wifi_ligar(r))]))
            self._mostrar_escolhas('Estas são as redes Wi-Fi que encontrei. A qual quer ligar?', opcoes)
        self._em_fundo(None, A.redes_wifi, depois, atividade='A procurar redes Wi-Fi…')

    def _wifi_ligar(self, r):
        if not r['segura']:
            self._fazer('ligar à rede “%s”' % r['ssid'], A.cmd_wifi(r['ssid'], False))
            return
        self._perguntar('Qual é a senha da rede “%s”?' % r['ssid'], senha=True, dica='Senha do Wi-Fi',
                        seguinte=lambda senha: self._fazer(
                            'ligar à rede “%s”' % r['ssid'], A.cmd_wifi(r['ssid'], True), segredo=senha + '\n',
                            mostrar='nmcli device wifi connect "%s"  (senha: ••••••)' % r['ssid']))

    # ---- atualizacoes ----------------------------------------------------------------------------
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
            self._historico.append(dict(role='user', content='RESULTADO: ' + txt))
            self._dizer(txt)
            self._pedir('instalar as atualizações agora', A.cmd_atualizar(sistema, apps), demorado=True, confirmar=True)
        self._em_fundo(None, A.verificar_atualizacoes, depois,
                       atividade='A ver se há atualizações… (pode levar um minuto)')

    # ---- instalar programas -----------------------------------------------------------------------
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
                self._fazer('abrir a loja Órbita', 'carinaeos-orbita')
                return
            tipo, ident, extra = r
            aviso = (' Como está a usar o CarinaeOS sem instalar, o programa some ao desligar.' if A.AO_VIVO else '')
            if tipo == 'apt':
                if extra:
                    self._dizer('O “%s” já está instalado ✓' % ident)
                    return
                if terminal:
                    cmd = 'sudo apt-get update && sudo apt-get install -y %s' % shlex.quote(ident)
                    self._dizer('Vou instalar o “%s” pelo terminal: abro o Konsole para ver tudo, e o sistema pede lá a sua senha.%s'
                                % (ident, aviso))
                    self._pedir('instalar o “%s” pelo terminal' % ident, A.no_terminal(cmd, 'Instalar ' + ident),
                                mostrar=cmd, confirmar=True)
                else:
                    self._dizer('Encontrei o “%s” no Debian. Posso instalá-lo por si (o sistema pede a sua senha e eu '
                                'mostro aqui o andamento) ou dar-lhe os comandos para fazer no terminal.%s' % (ident, aviso))
                    self._pedir('instalar o “%s”' % ident, A.cmd_instalar_apt(ident), demorado=True, confirmar=True,
                                mostrar='sudo apt install %s' % ident)
            else:
                cmd = 'flatpak install --user -y flathub %s' % shlex.quote(ident)
                self._dizer('Encontrei “%s” no Flathub (%s).%s' % (extra, ident, aviso))
                if terminal:
                    self._pedir('instalar “%s” pelo terminal' % extra, A.no_terminal(cmd, 'Instalar ' + str(extra)),
                                mostrar=cmd, confirmar=True)
                else:
                    self._pedir('instalar “%s”' % extra, A.cmd_instalar_flatpak(ident), demorado=True, confirmar=True,
                                mostrar=cmd)
        self._em_fundo(None, procurar, depois, atividade='A procurar “%s”…' % nome)


class Eta(QObject, Pensamento, Tarefas):
    mudou = Signal()
    _chegou = Signal(str, int)       # texto final da IA, id da mensagem
    _parcial = Signal(int, str)      # texto a chegar da IA (streaming)
    _progresso = Signal(float)
    _fundo = Signal(object, object)
    _linha = Signal(int, str, float)
    _fim_execucao = Signal(int, bool, str)
    _ouvido = Signal(str)
    pedirJanela = Signal()           # mostrar a janela principal

    def __init__(self):
        super().__init__()
        self._msgs = []
        self._historico = []
        self._pensando = False
        self._cfg = self._ler_cfg()
        self._cerebro = CB.Cerebro(self._cfg)
        self._modelo = CB.modelo_no_disco(DADOS, self._cfg.get('modelo', ''))
        self._estado = ('desligada' if self._cfg.get('ia_desligada') else
                        'a-iniciar' if self._modelo else 'sem-modelo')
        self._baixado = 0.0
        self._baixar_o_que = ''
        self._proc = None
        self._n = 0
        self._segredos = {}
        self._cmd_real = {}
        self._escolhas = {}
        self._espera = None
        self._a_correr = {}            # id do pedido -> Popen
        self._geracao = 0              # muda quando se carrega em Parar: respostas antigas sao ignoradas
        self._atividade = ''
        self._desde = 0.0
        self._ouvindo = False
        self._por_voz = False
        self._nuvem = False
        self._resposta_nuvem = ''
        self._documento = None         # (nome, texto) do ultimo arquivo enviado
        self._casa = []                # entidades do Home Assistant (cache)
        self._casa_quando = 0
        self._gravador = VOZ.Gravador()
        self._falante = VOZ.Falante()

        self._parcial.connect(self._resposta_parcial)
        self._fundo.connect(lambda f, r: f(r))
        self._progresso.connect(self._atualizar_download)
        self._linha.connect(self._linha_comando)
        self._fim_execucao.connect(self._terminou)
        self._ouvido.connect(self._depois_de_ouvir)

        self._relogio = QTimer(self)
        self._relogio.setInterval(250)
        self._relogio.timeout.connect(self._tique)
        self._relogio.start()
        self._fecha_nuvem = QTimer(self)
        self._fecha_nuvem.setSingleShot(True)
        self._fecha_nuvem.timeout.connect(self._esconder_nuvem)

        self._dizer('Olá! Eu sou a Eta ✦ Posso encontrar e ler arquivos, explicar e mudar configurações, '
                    'instalar programas e controlar a sua casa. Pode escrever ou falar comigo (🎤). '
                    'Antes de instalar ou mexer no sistema, peço sempre a sua permissão.')
        if self._estado == 'a-iniciar':
            threading.Thread(target=self._iniciar_ia, daemon=True).start()
        if HA.ligado():
            threading.Thread(target=self._atualizar_casa, daemon=True).start()
        self._lembrancas = []          # pedacos da memoria para a pergunta atual
        self._pergunta_atual = ''
        threading.Thread(target=self._estudar_apps, daemon=True).start()

    # ---- preferencias ------------------------------------------------------------------
    CFG = os.path.join(DADOS, 'preferencias.json')

    def _ler_cfg(self):
        try:
            with open(self.CFG, encoding='utf-8') as f:
                return json.load(f)
        except (OSError, ValueError):
            return {'falar': True}

    def _gravar_cfg(self):
        os.makedirs(DADOS, exist_ok=True)
        with open(self.CFG, 'w', encoding='utf-8') as f:
            json.dump(self._cfg, f)

    # ---- propriedades para a interface ------------------------------------------------------
    mensagens = Property('QVariantList', lambda s: s._msgs, notify=mudou)
    pensando = Property(bool, lambda s: s._pensando, notify=mudou)
    estado = Property(str, lambda s: s._estado, notify=mudou)
    baixado = Property(float, lambda s: s._baixado, notify=mudou)
    baixarOQue = Property(str, lambda s: s._baixar_o_que, notify=mudou)
    pedeSenha = Property(bool, lambda s: bool(s._espera and s._espera.get('senha')), notify=mudou)
    dicaEntrada = Property(str, lambda s: (s._espera or {}).get('dica', 'Pergunte ou peça algo à Eta…'), notify=mudou)
    atividade = Property(str, lambda s: s._atividade, notify=mudou)
    ocupada = Property(bool, lambda s: s._pensando or s._ouvindo or bool(s._a_correr), notify=mudou)
    ouvindo = Property(bool, lambda s: s._ouvindo, notify=mudou)
    nivelVoz = Property(float, lambda s: s._gravador.nivel, notify=mudou)
    podeOuvir = Property(bool, lambda s: VOZ.pode_ouvir(), notify=mudou)
    nuvem = Property(bool, lambda s: s._nuvem, notify=mudou)
    respostaNuvem = Property(str, lambda s: s._resposta_nuvem, notify=mudou)
    falar = Property(bool, lambda s: bool(s._cfg.get('falar', True)), notify=mudou)
    faltaVoz = Property(bool, lambda s: not os.path.exists(VOZ.MODELO_VOZ), notify=mudou)
    casaLigada = Property(bool, lambda s: HA.ligado(), notify=mudou)

    def _tamanho_falta(self):
        t = sum(x[2] for x in self._o_que_falta())
        return ('%.1f GB' % (t / 1e9)).replace('.', ',') if t > 9e8 else '%d MB' % (t / 1e6)

    tamanhoFalta = Property(str, lambda s: s._tamanho_falta(), notify=mudou)
    cerebroAntigo = Property(bool, lambda s: bool((s._modelo or {}).get('antigo')) and not s._cerebro.nuvem(), notify=mudou)
    nomeCerebro = Property(str, lambda s: (s._cerebro.nuvem() or {}).get('nome') or (s._modelo or {}).get('nome', ''), notify=mudou)
    provedores = Property('QVariantList', lambda s: [dict(id=k, nome=v['nome'], modelo=v['modelo'], chaveEm=v['chave_em'])
                                                     for k, v in CB.NUVENS.items()], constant=True)
    nuvemCfg = Property('QVariantMap', lambda s: dict({k: v for k, v in (s._cfg.get('nuvem') or {}).items() if k != 'chave'},
                                                      temChave=bool((s._cfg.get('nuvem') or {}).get('chave'))), notify=mudou)

    @Slot(str, str, str, bool)
    def definirNuvem(self, provedor, chave, modelo, ligada):
        n = dict(self._cfg.get('nuvem') or {})
        if provedor != n.get('provedor'):
            n.pop('chave', None)
        n['provedor'] = provedor
        if chave.strip():
            n['chave'] = chave.strip()
        n['modelo'] = modelo.strip() or CB.NUVENS.get(provedor, {}).get('modelo', '')
        n['ligada'] = bool(ligada) and bool(n.get('chave'))
        self._cfg['nuvem'] = n
        self._gravar_cfg()
        try:
            os.chmod(self.CFG, 0o600)       # a chave fica so para este usuario
        except OSError:
            pass
        if n['ligada']:
            self._add(papel='feito', texto='Cérebro na nuvem ligado: %s ✓ As conversas passam a ir para esse serviço.' % CB.NUVENS[provedor]['nome'])
        else:
            self._add(papel='feito', texto='A usar o cérebro deste computador (nada sai daqui) ✓')
        self.mudou.emit()

    @Slot(bool)
    def definirFalar(self, sim):
        self._cfg['falar'] = bool(sim)
        self._gravar_cfg()
        if not sim:
            self._falante.parar()
        self.mudou.emit()

    # ---- mensagens ---------------------------------------------------------------------
    def _add(self, **m):
        self._n += 1
        m['id'] = self._n
        self._msgs = self._msgs + [m]
        self.mudou.emit()
        return m

    def _dizer(self, texto, codigo='', falar=True, botoes=None):
        """botoes: [(rotulo, funcao)] -> pilulas por baixo da mensagem."""
        bs, funcs = [], []
        for rot, f in (botoes or []):
            bs.append(dict(rotulo=rot, n=len(funcs), especial=''))
            funcs.append(f)
        m = self._add(papel='eta', texto=texto, codigo=codigo, botoes=bs)
        if funcs:
            self._escolhas[m['id']] = funcs
        if falar:
            self._talvez_falar(texto)
        return m

    def _talvez_falar(self, texto):
        if self._por_voz:
            self._resposta_nuvem = texto
            self._mostrar_nuvem(9000)
            if self._cfg.get('falar', True):
                self._falante.falar(texto)

    def _trocar(self, ident, **campos):
        self._msgs = [dict(m, **campos) if m['id'] == ident else m for m in self._msgs]
        self.mudou.emit()

    def _msg(self, ident):
        return next((m for m in self._msgs if m['id'] == ident), None)

    def _definir_atividade(self, texto):
        self._atividade = texto
        self._desde = time.time()
        if texto:
            self._mostrar_nuvem()
        self.mudou.emit()

    def _tique(self):
        # atualiza o "a pensar… 5 s", o nivel do microfone, e fecha a nuvem quando acaba
        if self._ouvindo or self._pensando or self._a_correr:
            self.mudou.emit()
        elif self._atividade:
            self._atividade = ''
            self._fecha_nuvem.start(1500 if not self._resposta_nuvem else 9000)
            self.mudou.emit()

    def _mostrar_nuvem(self, fechar_em=0):
        self._nuvem = True
        self._fecha_nuvem.stop()
        if fechar_em:
            self._fecha_nuvem.start(fechar_em)
        self.mudou.emit()

    def _esconder_nuvem(self):
        if self._ouvindo or self._pensando or self._a_correr:
            return
        self._nuvem = False
        self._resposta_nuvem = ''
        self.mudou.emit()

    @Slot()
    def fecharNuvem(self):
        self._fecha_nuvem.stop()
        self._nuvem = False
        self._resposta_nuvem = ''
        self.mudou.emit()

    def _em_fundo(self, aviso, trabalho, depois, atividade=None):
        """Corre trabalho() numa thread e depois(resultado) na janela. 'Parar' cancela."""
        if aviso:
            self._dizer(aviso)
        geracao = self._geracao
        self._pensando = True
        self._definir_atividade(atividade or aviso or 'A trabalhar…')

        def t():
            try:
                r = trabalho()
            except Exception as e:
                r = e

            def fim(x):
                if geracao != self._geracao:
                    return                      # cancelado entretanto
                self._pensando = False
                depois(x)
                self.mudou.emit()
            self._fundo.emit(fim, r)
        threading.Thread(target=t, daemon=True).start()

    def _perguntar(self, texto, **espera):
        espera.setdefault('dica', 'Escreva aqui… (ou “cancelar”)')
        self._espera = espera
        self._dizer(texto)

    def _mostrar_escolhas(self, texto, opcoes):
        """opcoes: [dict(icone, nome, detalhe, resumo=[...], botoes=[(rotulo, funcao | 'pasta:<caminho>'), ...])]"""
        itens, funcs = [], []
        for o in opcoes:
            b = []
            for rot, f in o.get('botoes', []):
                if isinstance(f, str):
                    b.append(dict(rotulo=rot, n=-1, especial=f))
                else:
                    b.append(dict(rotulo=rot, n=len(funcs), especial=''))
                    funcs.append(f)
            itens.append(dict(icone=o.get('icone', 'drive-removable-media'), nome=o['nome'],
                              detalhe=o.get('detalhe', ''), resumo=o.get('resumo', []), botoes=b))
        m = self._add(papel='escolhas', texto=texto, opcoes=itens)
        self._escolhas[m['id']] = funcs
        self._talvez_falar(texto)
        return m

    @Slot(int, int)
    def escolher(self, ident, n):
        funcs = self._escolhas.get(ident, [])
        if 0 <= n < len(funcs):
            funcs[n]()

    # ---- PARAR -----------------------------------------------------------------------
    @Slot()
    def parar(self):
        """Para tudo: a IA a pensar, a gravacao, a fala e os comandos em curso."""
        self._geracao += 1
        self._gravador.parar()
        self._falante.parar()
        for ident in list(self._a_correr):
            self.cancelar(ident)
        if self._pensando:
            self._pensando = False
            self._dizer('Parei. ✋', falar=False)
        self._ouvindo = False
        self._espera = None
        self._definir_atividade('')
        self.mudou.emit()

    @Slot(int)
    def cancelar(self, ident):
        p = self._a_correr.pop(ident, None)
        if p and p.poll() is None:
            try:
                os.killpg(p.pid, signal.SIGTERM)
            except OSError:
                pass
            threading.Timer(3, lambda: p.poll() is None and _matar(p)).start()
        m = self._msg(ident)
        if m and m.get('estado') in ('a-executar', 'pendente'):
            self._trocar(ident, estado='cancelado')
        self.mudou.emit()

    # ---- IA local ------------------------------------------------------------------------
    @staticmethod
    def _saude():
        try:
            with urllib.request.urlopen('http://127.0.0.1:%d/health' % PORTA, timeout=2) as r:
                return r.status == 200
        except Exception:
            return False

    def _aquecer(self):
        """Le ja o prompt e as ferramentas (ficam em cache): o primeiro pedido responde muito mais depressa."""
        try:
            self._cerebro.falar([dict(role='system', content=self._sistema()), dict(role='user', content='olá')],
                                max_tokens=1, sem_pensar=bool((self._modelo or {}).get('sem_pensar')))
        except Exception:
            pass

    def _iniciar_ia(self):
        if self._cfg.get('ia_desligada'):
            self._estado = 'desligada'
            self.mudou.emit()
            return
        if self._saude():
            self._estado = 'pronta'
            self.mudou.emit()
            return
        self._modelo = CB.modelo_no_disco(DADOS, self._cfg.get('modelo', ''))
        if not (os.path.exists(SERVIDOR) and self._modelo):
            self._estado = 'sem-modelo'
            self.mudou.emit()
            return
        threads = max(1, (os.cpu_count() or 2))
        base = [SERVIDOR, '-m', os.path.join(DADOS, self._modelo['arquivo']), '-np', '1',
                '-t', str(threads), '--host', '127.0.0.1', '--port', str(PORTA), '--no-webui', '--jinja']
        # pouca memoria: contexto de 8k com cache comprimida, sem cache extra de prompts, e o modelo
        # sai da memoria sozinho ao fim de 5 minutos parado (volta a carregar no pedido seguinte)
        leve = ['-c', '8192', '-fa', 'on', '-ctk', 'q8_0', '-ctv', 'q8_0', '--cache-ram', '0',
                '--sleep-idle-seconds', '300']
        for extra in (leve, ['-c', '8192']):
            try:
                self._proc = subprocess.Popen(base + extra, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except Exception:
                self._estado = 'erro'
                self.mudou.emit()
                return
            for _ in range(240):
                if self._saude():
                    self._estado = 'pronta'
                    self.mudou.emit()
                    self._aquecer()
                    return
                if self._proc.poll() is not None:
                    break
                time.sleep(0.5)
            if self._proc.poll() is None:
                break
        self._estado = 'erro'
        self.mudou.emit()

    def _parar_ia(self):
        if self._proc and self._proc.poll() is None:
            self._proc.terminate()
            try:
                self._proc.wait(5)
            except Exception:
                self._proc.kill()
        self._proc = None

    @Slot(bool)
    def definirIA(self, ligada):
        """Desligar a IA: o modelo sai da memoria e nao volta a arrancar (nem em segundo plano)."""
        self._cfg['ia_desligada'] = not ligada
        self._gravar_cfg()
        if ligada:
            self._estado = 'a-iniciar' if CB.modelo_no_disco(DADOS) else 'sem-modelo'
            self._add(papel='feito', texto='IA ligada ✓')
            if self._estado == 'a-iniciar':
                threading.Thread(target=self._iniciar_ia, daemon=True).start()
        else:
            self._parar_ia()
            self._estado = 'desligada'
            self._add(papel='feito', texto='IA desligada ✓ A memória foi libertada. Continuo a fazer as tarefas simples '
                                           '(abrir, instalar, ajustes) sem IA.')
        self.mudou.emit()

    @Slot(str)
    def definirModelo(self, qual):
        """'leve' ou 'completo'."""
        self._cfg['modelo'] = qual
        self._gravar_cfg()
        rec = CB.modelo_recomendado(qual)
        if os.path.exists(os.path.join(DADOS, rec['arquivo'])):
            self._parar_ia()
            self._estado = 'a-iniciar'
            threading.Thread(target=self._iniciar_ia, daemon=True).start()
            self._add(papel='feito', texto='A usar o cérebro %s (%s) ✓' % ('completo' if qual == 'completo' else 'leve', rec['nome']))
        else:
            self._add(papel='feito', texto='Vou baixar o cérebro %s (%s, %.1f GB).' % (
                'completo' if qual == 'completo' else 'leve', rec['nome'], rec['tamanho'] / 1e9))
            self.baixarCerebro()
        self.mudou.emit()

    iaLigada = Property(bool, lambda s: not s._cfg.get('ia_desligada'), notify=mudou)
    modeloEscolhido = Property(str, lambda s: s._cfg.get('modelo') or ('completo' if CB.ram_gb() >= 12 else 'leve'), notify=mudou)
    segundoPlano = Property(bool, lambda s: bool(s._cfg.get('segundo_plano')), notify=mudou)

    @Slot()
    def abrirManual(self):
        subprocess.Popen(['carinaeos-manual'], start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    internetLigada = Property(bool, lambda s: bool(s._cfg.get('internet', True)), notify=mudou)

    @Slot(bool)
    def definirInternet(self, sim):
        self._cfg['internet'] = bool(sim)
        self._gravar_cfg()
        self._add(papel='feito', texto='Pesquisa na internet %s ✓' % ('ligada' if sim else 'desligada'))
        self.mudou.emit()

    @Slot(bool)
    def definirSegundoPlano(self, sim):
        self._cfg['segundo_plano'] = bool(sim)
        self._gravar_cfg()
        self.mudou.emit()

    @Slot(int, str)
    def _resposta_parcial(self, ident, texto):
        texto_vis, codigo = separar_codigo(texto)
        self._trocar(ident, texto=texto_vis, codigo=codigo)
        self._atividade = 'A escrever…'

    # ---- ferramentas -----------------------------------------------------------------------
    def _executar_ferramenta(self, acao):
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
            pedido = APPS.normalizar(simples(self._ultimo_pedido()))
            nome = APPS.normalizar(simples(acao['nome']))
            if nome and (nome in pedido or any(w in pedido for w in re.findall(r'\w{4,}', nome))):
                self._instalar(acao['nome'])
            else:                     # a IA inventou um programa que o usuario nao pediu
                self._esclarecer(self._ultimo_pedido(), simples(self._ultimo_pedido()), forcar=True)
        elif f == 'casa' and acao.get('pedido'):
            if not self._casa_pedido(acao['pedido'], simples(acao['pedido'])):
                self._dizer('Não encontrei esse aparelho na sua casa.')
        elif f == 'terminal' and acao.get('comando'):
            self._pedir((acao.get('descricao') or 'executar no terminal') + ' (no terminal)',
                        A.no_terminal(acao['comando']), mostrar=acao['comando'], confirmar=True)
        elif f in ('abrir', 'executar') and acao.get('comando'):
            self._pedir(acao.get('descricao') or 'executar um comando', acao['comando'],
                        confirmar=precisa_permissao(acao['comando']))
        else:
            self._dizer('Não sei fazer isso ainda. Pode explicar de outra forma?')

    def _mostrar_busca(self, palavras):
        chaves, res = buscar_arquivos(palavras)
        if not res:
            self._historico.append(dict(role='user', content='RESULTADO: nenhum arquivo encontrado.'))
            self._dizer('Não encontrei nenhum arquivo com “%s” na sua pasta pessoal.' % (' '.join(chaves) or palavras))
            return
        self._historico.append(dict(role='user', content='RESULTADO: %d arquivos encontrados: %s' %
                                    (len(res), ', '.join(r['nome'] for r in res[:10]))))
        txt = 'Encontrei %d %s com “%s”. O que quer fazer?' % (
            len(res), 'item' if len(res) == 1 else 'itens', ' '.join(chaves) or palavras)
        self._add(papel='arquivos', texto=txt, arquivos=res)
        self._talvez_falar(txt)

    # ---- executar comandos (com o andamento a vista) ------------------------------------------
    def _pedir(self, descricao, comando, segredo=None, mostrar=None, demorado=False, confirmar=None):
        """Cartao do comando. confirmar=None: decide sozinho (abrir = logo; instalar = Permitir)."""
        adaptado = AMBI.adaptar(comando)
        if adaptado is None:
            self._dizer('Isso só existe no KDE Plasma. No %s, procure nas Definições do sistema.' % AMBI.NOME,
                        botoes=[('Abrir as Definições', lambda: self._fazer('abrir as Definições', 'systemsettings'))])
            return None
        if adaptado != comando:
            comando, mostrar = adaptado, None
        if confirmar is None:
            confirmar = precisa_permissao(comando, de_confianca=True)
        if not confirmar and ABRIR.match(comando):
            subprocess.Popen(['bash', '-lc', comando], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
            self._add(papel='feito', texto='Abri %s ✓' % re.sub(r'^(abrir|abri)\s+', '', descricao))
            self._historico.append(dict(role='user', content='RESULTADO: aberto.'))
            return None
        modo = self._cfg.get('modo', 'perguntar')
        if confirmar and modo == 'comandos':
            self._mostrar_comandos(descricao, mostrar or comando)
            return None
        if confirmar and modo == 'fazer':
            confirmar = False
        m = self._add(papel='pedido', texto=('Posso %s?' % descricao) if confirmar else descricao[:1].upper() + descricao[1:],
                      comando=mostrar or comando, estado='pendente' if confirmar else 'a-executar',
                      demorado=demorado, saida='', progresso=-1.0, etapa='')
        self._cmd_real[m['id']] = comando
        if segredo is not None:
            self._segredos[m['id']] = segredo
        if confirmar:
            self._talvez_falar('Quer que eu %s por si, ou prefere os comandos para fazer você mesmo?' % descricao)
        else:
            self._correr(m['id'])
        return m['id']

    def _fazer(self, descricao, comando, **k):
        """Mudancas simples (luz noturna, volume, Wi-Fi...): faz logo, sem perguntar."""
        k['confirmar'] = False
        return self._pedir(descricao, comando, **k)

    @Slot(int)
    def permitir(self, ident):
        m = self._msg(ident)
        if not m or m.get('estado') != 'pendente':
            return
        self._trocar(ident, estado='a-executar')
        self._correr(ident)

    def _correr(self, ident):
        m = self._msg(ident)
        comando = self._cmd_real.get(ident, m['comando'])
        segredo = self._segredos.pop(ident, None)
        if ABRIR.match(comando) and not PERIGOSO.search(comando):
            subprocess.Popen(['bash', '-lc', comando], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                             start_new_session=True)
            self._fim_execucao.emit(ident, True, '')
            return
        self._definir_atividade(m['texto'].replace('Posso ', '').rstrip('?') + '…')
        try:
            p = subprocess.Popen(['bash', '-lc', comando], stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 stdin=subprocess.PIPE if segredo is not None else subprocess.DEVNULL,
                                 start_new_session=True, env=dict(os.environ, LC_ALL='C.UTF-8', COLUMNS='120'))
        except Exception as e:
            self._fim_execucao.emit(ident, False, str(e))
            return
        self._a_correr[ident] = p
        self.mudou.emit()

        def ler():
            if segredo is not None:
                try:
                    p.stdin.write(segredo.encode())
                    p.stdin.close()
                except OSError:
                    pass
            linhas, atual, prog, ultimo = [], b'', -1.0, 0.0
            while True:
                b = p.stdout.read1(4096) if hasattr(p.stdout, 'read1') else p.stdout.read(1)
                if not b:
                    break
                atual += b
                partes = re.split(rb'[\r\n]', atual)
                atual = partes.pop()
                for parte in partes:
                    t = re.sub(r'\x1b\[[0-9;?]*[A-Za-z]', '', parte.decode('utf-8', 'ignore')).strip()
                    if not t:
                        continue
                    pr = progresso_de(t)
                    if pr is not None:
                        prog = pr
                    if t.startswith(('pmstatus:', 'dlstatus:')):
                        t = t.split(':', 3)[-1]
                    if linhas and t == linhas[-1]:
                        continue
                    linhas.append(t)
                    linhas = linhas[-14:]
                if time.time() - ultimo > 0.25:
                    ultimo = time.time()
                    self._linha.emit(ident, '\n'.join(linhas), prog)
            p.wait()
            if ident in self._a_correr:
                self._fim_execucao.emit(ident, p.returncode == 0, '\n'.join(linhas)[-1500:])
        threading.Thread(target=ler, daemon=True).start()

    @Slot(int, str, float)
    def _linha_comando(self, ident, saida, prog):
        etapa = saida.splitlines()[-1] if saida else ''
        self._trocar(ident, saida=saida, progresso=prog, etapa=etapa)
        m = self._msg(ident)
        if m:
            nome = m['texto'].replace('Posso ', '').rstrip('?')
            self._atividade = '%s… %s' % (nome[:40], ('%d%%' % (prog * 100)) if prog >= 0 else '')

    @Slot(int, bool, str)
    def _terminou(self, ident, ok, saida):
        self._a_correr.pop(ident, None)
        m = self._msg(ident)
        if not m or m.get('estado') == 'cancelado':
            return
        self._trocar(ident, estado='feito' if ok else 'falhou', saida=saida, progresso=1.0 if ok else m.get('progresso', -1))
        if ok and re.search(r'\b(apt-get install|flatpak install|apt install|pkcon)\b', self._cmd_real.get(ident, '')):
            APPS._cache = None
            threading.Thread(target=self._estudar_apps, args=(True,), daemon=True).start()
        self._historico.append(dict(role='user', content='RESULTADO: %s. %s' % ('feito' if ok else 'falhou', saida[:400])))
        if self._por_voz:
            self._talvez_falar('Pronto, está feito.' if ok else 'Não funcionou, veja os detalhes na janela.')
        self.mudou.emit()

    def _mostrar_comandos(self, descricao, comando):
        cmd = comando
        if 'pkexec bash -c' in cmd or 'script -qfec' in cmd:
            cmd = re.sub(r'.*apt-get install -y -o APT::Status-Fd=1 ([\w.+-]+).*', r'sudo apt update && sudo apt install \1', cmd)
            cmd = re.sub(r".*flatpak install --user -y flathub ([\w.]+).*", r'flatpak install --user flathub \1', cmd)
        self._dizer('Aqui estão os comandos para %s. Abra o terminal, cole-os e carregue em Enter '
                    '(se pedir, escreva a sua senha):' % descricao, codigo=cmd, falar=False,
                    botoes=[('Abrir o terminal', lambda: self._fazer('abrir o terminal', 'konsole'))])
        self._talvez_falar('Escrevi os comandos na janela.')

    @Slot(int)
    def comandos(self, ident):
        """'Quero os comandos': em vez de fazer, mostra o que escrever no terminal."""
        m = self._msg(ident)
        if not m or m.get('estado') != 'pendente':
            return
        self._segredos.pop(ident, None)
        self._trocar(ident, estado='comandos')
        self._mostrar_comandos(m['texto'].replace('Posso ', '').rstrip('?'), m['comando'])

    modo = Property(str, lambda s: s._cfg.get('modo', 'perguntar'), notify=mudou)

    @Slot(str)
    def definirModo(self, modo):
        if modo in ('perguntar', 'fazer', 'comandos'):
            self._cfg['modo'] = modo
            self._gravar_cfg()
            self.mudou.emit()

    @Slot(int)
    def recusar(self, ident):
        self._segredos.pop(ident, None)
        self._trocar(ident, estado='recusado')
        self._historico.append(dict(role='user', content='RESULTADO: o usuario recusou.'))

    @Slot(str)
    def abrirNoTerminal(self, codigo):
        """Abre o Konsole com os comandos ja escritos (sem os executar)."""
        linhas = [l for l in codigo.splitlines() if l.strip() and not l.strip().startswith('#')]
        tmp = os.path.join(DADOS, 'comandos.sh')
        os.makedirs(DADOS, exist_ok=True)
        with open(tmp, 'w', encoding='utf-8') as f:
            f.write('echo "Comandos sugeridos pela Eta (copie e cole os que quiser):"; echo\n')
            for l in linhas:
                f.write('echo %s\n' % shlex.quote('  ' + l))
            f.write('echo; exec bash\n')
        subprocess.Popen(['konsole', '-e', 'bash', tmp], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    # ---- conversa ----------------------------------------------------------------------------
    # ---- memoria ---------------------------------------------------------------------------------
    def _estudar_apps(self, avisar=False):
        """Estuda os aplicativos instalados que ainda nao conhece (no arranque e depois de instalar algo)."""
        try:
            primeira = not os.path.exists(MEM.APPS_VISTOS)
            novos, todos = MEM.apps_novos()
            aprendidos = []
            for c in novos:
                d = MEM.estudar_app(c)
                if d:
                    aprendidos.append(d['titulo'])
            MEM.marcar_vistos(todos)
            if aprendidos and (avisar or not primeira):
                self._fundo.emit(lambda nomes: self._dizer(
                    'Estudei %s: já sei para que serve%s e como se usa. Pergunte-me, por exemplo, “como uso o %s?”.'
                    % (', '.join(nomes[:3]) + ('…' if len(nomes) > 3 else ''), 'm' if len(nomes) > 1 else '', nomes[0]),
                    falar=False), aprendidos)
        except Exception:
            pass

    def _memoria_pedido(self, texto, s, so_comandos=False):
        m = re.match(r'^(aprende|aprenda|lembra(-te)?|lembre(-se)?|memoriza|memorize|guarda na (tua |sua )?memoria|anota|anote)'
                     r'( que| isto| isso|:)?\s+(?P<nota>.+)', texto.strip(), re.I)
        if m and len(m.group('nota')) > 3:
            nota = m.group('nota').strip()
            MEM.aprender('nota:%d' % int(time.time() * 1000), nota[:70], nota, 'nota')
            self._add(papel='feito', texto='Guardado na minha memória ✓ Vou lembrar-me disso.')
            return True
        m = re.match(r'^(esquece|esqueca|esqueça|apaga da (tua |sua )?memoria)\s+(.+)', s)
        if m:
            if re.search(r'\b(tudo|todas as respostas|respostas)\b', m.group(3)):
                MEM.esquecer_respostas()
                self._add(papel='feito', texto='Esqueci as respostas guardadas ✓')
                return True
            fora = MEM.esquecer(m.group(3))
            self._dizer('Esqueci: %s ✓' % ', '.join(fora) if fora else 'Não encontrei nada com isso na minha memória.')
            return True
        if re.search(r'\bo que (voce|tu|vc) (sabe|aprendeu|lembra|guardou)|\b(sua|tua) memoria\b|\bo que aprendeste\b', s):
            r = MEM.resumo_memoria()
            partes = ['Sei usar %d aplicativos deste computador' % r['apps']]
            if r['arquivos']:
                partes.append('li %d arquivo(s): %s' % (len(r['arquivos']), ', '.join(r['arquivos'][:6])))
            if r['notas']:
                partes.append('tenho %d nota(s) suas: %s' % (len(r['notas']), '; '.join(r['notas'][:5])))
            if r['respostas']:
                partes.append('e guardei %d respostas para responder mais rápido' % r['respostas'])
            self._dizer('; '.join(partes) + '. Para eu esquecer algo, diga “esquece …”.')
            return True
        if so_comandos:
            return False
        # "como uso o GIMP", "o que é o Krita", "passo a passo do OBS", "ensina-me o LibreOffice"
        if re.search(r'\b(como (uso|usar|utilizo|funciona|mexo|trabalho)|o que (e|faz)|para que serve|ensina\w*|passo a passo|tutorial|guia)\b', s):
            app = APPS.procurar(texto)
            d = MEM.guia_app(app[1] if app else texto)
            if not d and app:
                d = MEM.estudar_app(app[2])
            if d:
                passos = [p['t'] for p in d['pedacos']]
                texto_guia = '\n\n'.join(passos)
                linhas = [l for l in re.split(r'\n\n|(?<=\.)\s+(?=Para |Como |Abr|Guard|Export|Nova |Novo |Ligar |Pelo terminal)', texto_guia) if l.strip()]
                corpo = '\n'.join('%d. %s' % (i + 1, l.strip()) for i, l in enumerate(linhas[:9]))
                bot = [('Abrir o %s' % d['titulo'], lambda c=d.get('desktop'), n=d['titulo']: self._fazer('abrir o %s' % n, APPS.comando_abrir(c)))] \
                    if d.get('desktop') else None
                self._dizer('Como usar o %s:\n%s' % (d['titulo'], corpo), botoes=bot)
                return True
            # ainda nao instalado, mas e um dos aplicativos conhecidos: ensinar e oferecer instalar
            chave = next((k for k in MEM.GUIAS if re.search(r'\b' + re.escape(k) + r'\b', s)), None)
            if chave:
                corpo = '\n'.join('%d. %s' % (i + 1, l) for i, l in enumerate(MEM.GUIAS[chave]))
                self._dizer('Como usar o %s:\n%s\n\n(Ainda não está instalado neste computador.)' % (chave, corpo),
                            botoes=[('Instalar o %s' % chave, lambda n=chave: self._instalar(n))])
                return True
        # perguntas sobre o que a pessoa me pediu para lembrar
        notas = [l for l in MEM.lembrar(texto, 1, origem='nota') if l[0] >= 2.0]
        if notas and re.search(r'\b(onde|qual|quando|quem|como|o que|lembras?|lembra-te|sabes)\b', s):
            self._dizer('Lembro-me disto: “%s”' % notas[0][2])
            return True
        return False

    def _responder_da_memoria(self, texto):
        lembr = [l for l in MEM.lembrar(texto, 2) if l[0] >= 2.5]
        if not lembr:
            return False
        pontos, titulo, trecho, d = lembr[0]
        frases = re.split(r'(?<=[.!?])\s+', trecho)
        q = set(MEM.fichas(texto))
        frases.sort(key=lambda f: -len(q & set(MEM.fichas(f))))
        resposta = ' '.join(frases[:3])[:600]
        self._dizer('Do que aprendi em “%s”: %s' % (titulo, resposta))
        return True

    def _ultimo_pedido(self):
        for m in reversed(self._msgs):
            if m.get('papel') == 'eu' and not m.get('anexo'):
                return m.get('texto', '')
        return ''

    VERBOS = re.compile(r'\b(abr\w*|abre|instal\w*|desinstal\w*|remov\w*|tir\w*|lig\w*|deslig\w*|acend\w*|apag\w*|'
                        r'mud\w*|troc\w*|poe|ponha|por|coloc\w*|ativ\w*|desativ\w*|aument\w*|diminu\w*|baix\w*|'
                        r'procur\w*|encontr\w*|ach\w*|mostr\w*|ve|ver|vej\w*|fech\w*|atualiz\w*|configur\w*|'
                        r'como|qual|quais|onde|quando|porque|o que|quero|queria|preciso|pode|podes|consegue|ajuda\w*|'
                        r'explic\w*|ensin\w*|faz\w*|faca|faço|conect\w*|desconect\w*|ejet\w*|resum\w*|le|ler|'
                        r'escrev\w*|cri\w*|guard\w*|copi\w*|mov\w*|exclu\w*|deixa|deixe|usa|usar|mete|sobe|desce)\b')

    def _esclarecer(self, texto, s, forcar=False):
        """Pedido curto/sem verbo ("libre office claro"): perguntar com opcoes em vez de adivinhar."""
        if not forcar and (self.VERBOS.search(s) or len(s.split()) > 6):
            return False
        opcoes = []
        app = APPS.procurar(texto)
        nome_cat = next((k for k in list(self.APT) + list(self.NOMES) if re.search(r'\b' + re.escape(k) + r'\b', APPS.normalizar(s))), None)
        if app:
            opcoes.append(('Abrir o %s' % app[1], lambda a=app: self._fazer('abrir o %s' % a[1], APPS.comando_abrir(a[2]))))
        elif nome_cat:
            opcoes.append(('Instalar o %s' % nome_cat, lambda n=nome_cat: self._instalar(n)))
        if re.search(r'\b(claro|branco|light)\b', s):
            opcoes.append(('Pôr o sistema em tema claro', lambda: self._fazer('mudar para o modo claro', 'plasma-apply-colorscheme BreezeLight')))
        if re.search(r'\b(escuro|preto|dark)\b', s):
            opcoes.append(('Pôr o sistema em tema escuro', lambda: self._fazer('voltar ao modo escuro', 'plasma-apply-colorscheme CarinaeOS')))
        t, pontos = topico_para(texto, com_pontos=True)
        if t and pontos >= 2 and not re.search(r'\b(claro|escuro)\b', s):
            for k in ('faz', 'desfaz'):
                if t.get(k) and len(opcoes) < 4:
                    opcoes.append((t[k][0][:1].upper() + t[k][0][1:], lambda a=t[k]: self._fazer(a[0], a[1])))
        if t and pontos >= 2 and t.get('acao') and len(opcoes) < 4:
            opcoes.append((t['acao'][0][:1].upper() + t['acao'][0][1:], lambda a=t['acao']: self._fazer(a[0], a[1])))
        if t and t.get('resposta') and len(opcoes) < 4:
            opcoes.append(('Explicar como fazer', lambda tt=t: self._dizer(tt['resposta'])))
        if not opcoes:
            if not forcar:
                return False
            self._dizer('Não percebi bem o que quer. Pode dizer de outra forma? Por exemplo: “abre o LibreOffice”, '
                        '“instala o GIMP” ou “como mudo o tema para claro?”.')
            return True
        self._dizer('Não tenho a certeza do que quer. É uma destas?', botoes=opcoes)
        return True

    @Slot(str)
    def enviar(self, texto):
        self._enviar(texto, por_voz=False)

    def _enviar(self, texto, por_voz):
        texto = texto.strip()
        if not texto:
            return
        if self._pensando and not self._espera:
            return
        self._por_voz = por_voz
        if not por_voz:
            self._falante.parar()
        if self._espera:
            self._continuar(texto)
            return
        self._add(papel='eu', texto=texto, voz=por_voz)
        self._historico.append(dict(role='user', content=texto))
        s = APPS.normalizar(simples(texto))
        if re.fullmatch(r'(para|pare|parar|cancela|cancelar|chega|silencio|cala(-te)?)', s):
            self.parar()
            return
        # com o cerebro (local ou nuvem): a IA entende o pedido e escolhe as ferramentas
        if self._cerebro_pronto():
            if self._memoria_pedido(texto, s, so_comandos=True):
                eu = next((m for m in reversed(self._msgs) if m.get('papel') == 'eu'), None)
                if eu is not None and not any(m.get('papel') == 'eta' and m['id'] > eu['id'] for m in self._msgs):
                    eu['chamadas'] = [('lembrar', {'nota': texto})]
                return
            m = re.match(r'^(abr\w*|abre|inicia\w*|lanca|executa)\s+(o |a |os |as )?(.+?)[.!]?$', s)
            if m:                                   # "abre o firefox": logo, sem esperar pela IA
                app = next((a for a in APPS.instalados() if a[0] == m.group(3).strip() or a[3] == m.group(3).strip()), None)
                if app:
                    self._msgs[-1]['chamadas'] = [('abrir_aplicativo', {'nome': app[1]})]
                    self._fazer('abrir o %s' % app[1], APPS.comando_abrir(app[2]))
                    return
            self._pensar()
            return
        # sem IA: regras
        # 0a) memoria: aprender, esquecer, o que sabe, como usar um aplicativo
        if self._memoria_pedido(texto, s):
            return
        # 0) como fazer pelo terminal
        if re.search(r'\b(terminal|konsole|linha de comandos?|comandos?|bash|shell|via cli)\b', s) and \
                re.search(r'\b(como|qual|quais|ensina|mostra|explica|faco|fazer|posso|consigo|existe|ha|comandos? (para|de|pra))\b', s) and \
                not re.search(r'^(abre|abrir|abra|liga|inicia)\b', s):
            c = terminal_para(texto)
            if c:
                self._dizer('%s — pelo terminal (abra o Konsole e escreva):' % c['titulo'], codigo=c['cmd'], falar=False,
                            botoes=[('Abrir o terminal', lambda: self._fazer('abrir o terminal', 'konsole'))])
                self._talvez_falar('Escrevi os comandos para %s na janela.' % c['titulo'].lower())
                return
            if self._estado == 'pronta':
                self._historico[-1]['content'] += ' (responda com os comandos de terminal num bloco ```)'
                self._pensar()
                return
        # 1) tarefas do sistema: casa, discos, rede, Wi-Fi, instalar, atualizar, terminal
        if self._tarefa_sistema(texto, s):
            return
        # 1b) "abre o LibreOffice": abrir um aplicativo instalado
        if re.match(r'^(abr\w*|abre|inicia\w*|lanca|executa|corre|liga)\b', s):
            app = APPS.procurar(texto)
            if app and not re.search(r'\b(configurac\w*|definic\w*|pasta|arquivo|disco|hd|pen)\b', s):
                self._fazer('abrir o %s' % app[1], APPS.comando_abrir(app[2]))
                return
            nome_cat = next((k for k in list(self.APT) + list(self.NOMES) if re.search(r'\b' + re.escape(k) + r'\b', s)), None)
            if not app and nome_cat:
                self._dizer('O %s não está instalado. Quer que eu o instale?' % nome_cat,
                            botoes=[('Instalar o %s' % nome_cat, lambda n=nome_cat: self._instalar(n))])
                return
        # 1c) pedido curto e sem verbo: perguntar o que quer (em vez de adivinhar)
        if self._esclarecer(texto, s):
            return
        # 2) procurar arquivos
        if re.search(r'\b(procur|encontr|ach[ae]|acho|localiz|busc|onde (esta|estao|fica|ficam|guardei)|cade)\w*', s):
            self._mostrar_busca(texto)
            return
        # 3) espaco / memoria
        if re.search(r'\b(espaco|memoria|armazenamento)\b', s) and not re.search(r'\bcomo\b', s):
            self._executar_ferramenta(dict(ferramenta='info_sistema'))
            return
        # 4) perguntas sobre o arquivo enviado
        if self._documento and self._estado == 'pronta' and re.search(
                r'\b(arquivo|documento|pdf|texto|ele|ela|isso|resum\w*|diz|fala|explica|quem|quando|quanto|valor|data)\b', s):
            self._pensar()
            return
        # 5) assunto conhecido: guia, ou a acao pedida
        t, pontos = topico_para(texto, com_pontos=True)
        if t and (pontos >= 3 or self._estado != 'pronta'):
            negativo = NEGATIVO.search(s) and t.get('desfaz')
            ensinar = PERGUNTA.search(s) and not re.search(r'pra mim|para mim|voce (pode|consegue)', s)
            if not ensinar and (IMPERATIVO.search(s) or negativo) and (t.get('faz') or t.get('desfaz')):
                d, cmd = t['desfaz'] if negativo else t['faz']
                self._fazer(d, cmd)
                return
            if t['acao'] and re.match(r'^(abre|abra|abrir|mostra|mostre|leva-me|vai para)\b', s):
                self._fazer(t['acao'][0], t['acao'][1])          # "abre as configuracoes de tela": abre logo
                return
            if t['resposta'] and AMBI.AMB != 'plasma' and t['acao']:
                acao = t['acao']
                self._dizer('No %s isso fica nas Definições do sistema. Posso abrir já a página certa:' % AMBI.NOME,
                            botoes=[(acao[0][:1].upper() + acao[0][1:], lambda a=acao: self._fazer(a[0], a[1]))])
                return
            if t['resposta']:
                c = next((c for c in COMANDOS if c['id'] == t['id']), None)
                self._historico.append(dict(role='assistant', content=t['resposta']))
                acao = t['acao']
                self._dizer(t['resposta'], codigo=(c['cmd'] if c else ''),
                            botoes=[(acao[0][:1].upper() + acao[0][1:], lambda a=acao: self._fazer(a[0], a[1]))] if acao else None)
                return
        # 6) o resto: a IA responde (com a memoria), ou a memoria sozinha
        if self._estado == 'pronta':
            self._pensar()
            return
        if self._responder_da_memoria(texto):
            return
        extra = (' Para conversar sobre qualquer assunto, ative a IA completa no aviso lá em cima.'
                 if self._estado == 'sem-modelo' else '')
        self._dizer('Ainda não sei responder a isso. Experimente, por exemplo, “como mudo o fundo?”, '
                    '“encontre o meu currículo” ou “como vejo o espaço livre pelo terminal?”.' + extra)

    @Slot()
    def limpar(self):
        self.parar()
        self._espera = None
        self._documento = None
        self._msgs = []
        self._historico = []
        self._dizer('Conversa limpa. Em que posso ajudar?', falar=False)

    def _continuar(self, texto):
        e, self._espera = self._espera, None
        self._add(papel='eu', texto='•' * min(len(texto), 12) if e.get('senha') else texto)
        if simples(texto).strip() in ('cancelar', 'cancela', 'deixa', 'esquece', 'nao', 'sair', 'parar', 'para'):
            self._dizer('Ok, cancelei. Em que mais posso ajudar?')
            self.mudou.emit()
            return
        e['seguinte'](texto)
        self.mudou.emit()

    # ---- VOZ ----------------------------------------------------------------------------------
    @Slot()
    def ouvir(self):
        """Comeca a ouvir (botao do microfone ou atalho Meta+Shift+Espaco)."""
        if self._ouvindo:
            self._gravador.parar()
            return
        self._falante.parar()
        if not VOZ.pode_ouvir():
            self.pedirJanela.emit()
            self._dizer('Para falar comigo, preciso de baixar o meu “ouvido” (150 MB, uma única vez, '
                        'e depois funciona sem internet). Carregue em “Ativar a voz” no aviso lá em cima.', falar=False)
            self._baixar_o_que = 'voz'
            self.mudou.emit()
            return
        geracao = self._geracao
        self._ouvindo = True
        self._resposta_nuvem = ''
        self._definir_atividade('A ouvir…')

        def t():
            wav = self._gravador.ouvir()
            if geracao != self._geracao:
                return
            texto = ''
            if wav:
                self._atividade = 'A perceber…'
                texto = VOZ.transcrever(wav)
            if geracao == self._geracao:
                self._ouvido.emit(texto)
        threading.Thread(target=t, daemon=True).start()

    @Slot(str)
    def _depois_de_ouvir(self, texto):
        self._ouvindo = False
        self._definir_atividade('')
        if not texto:
            self._resposta_nuvem = 'Não ouvi nada. Carregue no microfone e fale comigo.'
            self._mostrar_nuvem(4000)
            self.mudou.emit()
            return
        self._enviar(texto, por_voz=True)

    # ---- ARQUIVOS enviados -------------------------------------------------------------------
    @Slot('QVariantList')
    def anexar(self, urls):
        for u in urls:
            caminho = QUrl(u).toLocalFile() if str(u).startswith('file:') else str(u)
            if caminho and os.path.exists(caminho):
                self._ler_arquivo(caminho)

    def _ler_arquivo(self, caminho):
        nome = os.path.basename(caminho)
        self._add(papel='eu', texto='📎 ' + nome, anexo=caminho)
        com_ia = self._cerebro_pronto()

        def trabalho():
            tipo, texto, det = ARQ.extrair(caminho)
            resumo, chaves = [], []
            if texto.strip():
                if com_ia:
                    try:
                        pedido = ('Resuma em portugues do Brasil, em 3 a 5 topicos curtos (comece cada um com "- "), '
                                  'o conteudo deste arquivo chamado "%s":\n\n%s' % (nome, texto[:6000]))
                        r, _ = self._cerebro.falar([dict(role='user', content=pedido)], ferramentas=False, max_tokens=350,
                                                   sem_pensar=bool((self._modelo or {}).get('sem_pensar')))
                        resumo = [re.sub(r'^[-•*\d.)\s]+', '', l).strip() for l in r.splitlines()
                                  if re.match(r'^\s*([-•*]|\d+[.)])\s+', l)]
                    except Exception:
                        resumo = []
                if not resumo:
                    resumo, chaves = ARQ.resumo_simples(texto)
            return tipo, texto, det, resumo, chaves

        def depois(r):
            if isinstance(r, Exception):
                self._dizer('Não consegui ler o “%s” (%s).' % (nome, r))
                return
            tipo, texto, det, resumo, chaves = r
            partes = [ARQ.tamanho_legivel(det.get('tamanho', 0))]
            if det.get('paginas'):
                partes.append('%d páginas' % det['paginas'])
            if det.get('slides'):
                partes.append('%d slides' % det['slides'])
            if det.get('dimensoes'):
                partes.append(det['dimensoes'])
            palavras = len(texto.split())
            if palavras:
                partes.append('%d palavras' % palavras)
            if texto.strip():
                self._documento = (nome, texto)
                threading.Thread(target=MEM.aprender, args=('arquivo:' + caminho, nome, texto, 'arquivo',
                                                            ' '.join(resumo[:2])), daemon=True).start()
                self._historico.append(dict(role='user', content='(enviei o arquivo "%s"; pode responder perguntas sobre ele)' % nome))
            if tipo == 'imagem' and not texto.strip():
                intro = 'É uma imagem (%s). Não encontrei texto nela.' % ', '.join(partes)
            elif tipo == 'midia':
                intro = 'É um arquivo de áudio ou vídeo (%s). Posso abri-lo ou guardá-lo.' % partes[0]
            elif not texto.strip():
                intro = 'Recebi o “%s” (%s), mas não consegui ler o conteúdo dele.' % (nome, partes[0])
            else:
                intro = 'Li o “%s”. Resumo:' % nome
                if chaves:
                    intro += ' (assuntos: %s)' % ', '.join(chaves[:5])
            pasta, nome_pasta = ARQ.pasta_sugerida(caminho)
            ja_la = os.path.dirname(os.path.abspath(caminho)) == os.path.abspath(pasta)
            botoes = [('Abrir', lambda: correr(['xdg-open', caminho], espera=False))]
            if not ja_la:
                botoes.append(('Guardar em %s' % nome_pasta, lambda: self._guardar(caminho, pasta)))
            botoes.append(('Escolher pasta…', 'pasta:' + caminho))
            botoes.append(('Mandar para a lixeira', lambda: self._lixeira(caminho)))
            self._mostrar_escolhas(intro, [dict(icone=icone_arquivo(caminho), nome=nome, detalhe=' · '.join(partes),
                                                resumo=resumo, botoes=botoes)])
            if texto.strip():
                self._dizer('Guardei o que aprendi deste arquivo na minha memória: pode perguntar-me sobre ele quando quiser, '
                            'mesmo depois. Quer que eu guarde o arquivo em alguma pasta ou que o mande para a lixeira?')
        self._em_fundo(None, trabalho, depois, atividade='A ler “%s”…' % nome)

    def _guardar(self, caminho, pasta):
        try:
            novo = ARQ.mover(caminho, pasta)
            self._add(papel='feito', texto='Guardei em %s ✓' % novo.replace(HOME, '~', 1))
        except Exception as e:
            self._dizer('Não consegui mover o arquivo (%s).' % e)

    @Slot(str, str)
    def guardarEm(self, caminho, pasta_url):
        pasta = QUrl(pasta_url).toLocalFile() if pasta_url.startswith('file:') else pasta_url
        if pasta:
            self._guardar(caminho, pasta)

    def _lixeira(self, caminho):
        if ARQ.para_lixeira(caminho):
            self._add(papel='feito', texto='Mandei “%s” para a lixeira ✓ (pode recuperá-lo de lá)' % os.path.basename(caminho))
            if self._documento and self._documento[0] == os.path.basename(caminho):
                self._documento = None
        else:
            self._dizer('Não consegui mandar o arquivo para a lixeira.')

    # ---- arquivos da busca -------------------------------------------------------------------
    @Slot(str)
    def abrirArquivo(self, caminho):
        correr(['xdg-open', caminho], espera=False)

    @Slot(str)
    def mostrarNaPasta(self, caminho):
        correr(['dolphin', '--select', caminho], espera=False)

    @Slot(str)
    def bloquearArquivo(self, caminho):
        correr(['carinaeos-cadeado', 'trancar', caminho], espera=False)

    @Slot(str)
    def resumirArquivo(self, caminho):
        self._ler_arquivo(caminho)

    # ---- descarregar o cerebro e a voz ---------------------------------------------------------
    def _o_que_falta(self):
        falta = []
        rec = CB.modelo_recomendado(self._cfg.get('modelo', ''))
        atual = CB.modelo_no_disco(DADOS, self._cfg.get('modelo', ''))
        if self._cfg.get('ia_desligada') or self._cerebro.nuvem():
            pass
        elif not atual or atual.get('antigo') or (self._cfg.get('modelo') and atual is not rec):
            falta.append((rec['url'], os.path.join(DADOS, rec['arquivo']), rec['tamanho']))
        if not os.path.exists(VOZ.MODELO_VOZ):
            falta.append((VOZ.URL_MODELO_VOZ, VOZ.MODELO_VOZ, VOZ.TAMANHO_MODELO_VOZ))
        if shutil.which('piper') and not os.path.exists(VOZ.VOZ_PIPER):
            falta.append((VOZ.URL_VOZ_PIPER_JSON, VOZ.VOZ_PIPER + '.json', 4855))
            falta.append((VOZ.URL_VOZ_PIPER, VOZ.VOZ_PIPER, VOZ.TAMANHO_VOZ_PIPER))
        return falta

    @Slot()
    def baixarCerebro(self):
        if self._estado == 'a-baixar':
            return
        falta = self._o_que_falta()
        if not falta:
            return
        estado_antes = self._estado
        self._estado = 'a-baixar'
        self._baixado = 0.0
        self.mudou.emit()
        total = sum(t for _, _, t in falta)

        def tarefa():
            os.makedirs(DADOS, exist_ok=True)
            feito_total = 0
            try:
                for url, destino, tam in falta:
                    parte = destino + '.parte'
                    inicio = os.path.getsize(parte) if os.path.exists(parte) else 0
                    pedido = urllib.request.Request(url, headers={'Range': 'bytes=%d-' % inicio} if inicio else {})
                    with urllib.request.urlopen(pedido, timeout=60) as r, open(parte, 'ab' if inicio else 'wb') as f:
                        feito = inicio
                        while True:
                            bloco = r.read(1 << 20)
                            if not bloco:
                                break
                            f.write(bloco)
                            feito += len(bloco)
                            self._progresso.emit(min(0.999, (feito_total + feito) / total))
                    if os.path.getsize(parte) < tam * 0.98:
                        raise IOError('download incompleto')
                    os.replace(parte, destino)
                    feito_total += tam
                self._progresso.emit(2.0 if any(d.endswith('.gguf') for _, d, _t in falta) or not self._saude() else 3.0)
            except Exception:
                self._progresso.emit(-1.0)
        threading.Thread(target=tarefa, daemon=True).start()

    @Slot(float)
    def _atualizar_download(self, v):
        if v < 0:
            self._estado = 'sem-modelo' if not CB.modelo_no_disco(DADOS) else ('pronta' if self._saude() else 'a-iniciar')
            self._dizer('O download foi interrompido. Verifique a internet e tente outra vez (continua de onde parou).')
        elif v >= 2.0:
            self._baixar_o_que = ''
            if v == 3.0:
                self._estado = 'pronta'
                self._dizer('Pronto! Já posso ouvir e falar ✦ Carregue no 🎤 (ou Meta+Shift+Espaço) e fale comigo.')
            else:
                self._estado = 'a-iniciar'
                if self._proc and self._proc.poll() is None:
                    self._proc.terminate()       # estava com o modelo antigo
                    try:
                        self._proc.wait(5)
                    except Exception:
                        pass
                novo = CB.modelo_no_disco(DADOS)
                antigo = os.path.join(DADOS, 'modelo.gguf')
                if novo and not novo.get('antigo') and os.path.exists(antigo):
                    os.remove(antigo)            # o cerebro antigo da Eta ja nao e preciso
                self._dizer('Pronto! A IA e a voz foram instaladas. Já pode conversar comigo por escrito ou a falar ✦')
                threading.Thread(target=self._iniciar_ia, daemon=True).start()
        else:
            self._baixado = v
        self.mudou.emit()

    def fechar(self):
        self._gravador.parar()
        self._falante.parar()
        for ident in list(self._a_correr):
            self.cancelar(ident)
        if self._proc and self._proc.poll() is None:
            self._proc.terminate()


def _matar(p):
    try:
        os.killpg(p.pid, signal.SIGKILL)
    except OSError:
        pass


def separar_codigo(texto):
    """Tira o primeiro bloco ``` do texto da IA para o mostrar a parte (com Copiar)."""
    m = re.search(r'```[a-zA-Z]*\n?(.*?)(```|$)', texto, re.S)
    if not m:
        return texto, ''
    return (texto[:m.start()] + texto[m.end():]).strip(), m.group(1).strip()


def progresso_de(linha):
    """Percentagem (0..1) numa linha do apt, pkcon, flatpak, wget..."""
    m = re.match(r'^(pm|dl)status:[^:]*:([\d.]+):', linha)
    if m:
        v = float(m.group(2)) / 100
        return v * 0.5 if m.group(1) == 'dl' else 0.5 + v * 0.5
    m = re.search(r'Percentage:\s*(\d+)', linha)
    if m:
        return int(m.group(1)) / 100
    m = re.findall(r'(\d{1,3})(?:[.,]\d+)?\s?%', linha)
    if m:
        v = int(m[-1])
        if 0 <= v <= 100:
            return v / 100
    return None


def principal():
    from PySide6.QtGui import QGuiApplication, QIcon
    from PySide6.QtNetwork import QLocalServer, QLocalSocket
    from PySide6.QtQml import QQmlApplicationEngine
    from PySide6.QtQuickControls2 import QQuickStyle

    args = sys.argv[1:]
    nome_canal = 'carinaeos-eta-%d' % os.getuid()

    # uma so Eta: se ja estiver aberta, entrega-lhe o pedido e sai
    s = QLocalSocket()
    s.connectToServer(nome_canal)
    if s.waitForConnected(400):
        s.write(json.dumps(args).encode() + b'\n')
        s.flush()
        s.waitForBytesWritten(1000)
        s.disconnectFromServer()
        return 0

    QQuickStyle.setStyle('Basic')
    app = QGuiApplication(sys.argv[:1])
    app.setApplicationName('carinaeos-eta')
    app.setApplicationDisplayName('Eta')
    app.setDesktopFileName('carinaeos-eta')
    app.setWindowIcon(QIcon.fromTheme('carinaeos-eta'))
    app.setQuitOnLastWindowClosed(False)

    eta = Eta()
    motor = QQmlApplicationEngine()
    motor.addImageProvider('icone', Icones())
    motor.rootContext().setContextProperty('eta', eta)
    motor.rootContext().setContextProperty('arranqueSoNuvem', '--ouvir' in args)
    motor.load(os.path.join(AQUI, 'Main.qml'))
    if not motor.rootObjects():
        return 1
    janela = motor.rootObjects()[0]

    def tratar(lista):
        arquivos = [a for a in lista if not a.startswith('--') and os.path.exists(a)]
        perguntas = [a for a in lista if not a.startswith('--') and a not in arquivos]
        if arquivos and '--arquivo' not in lista:
            lista = lista + ['--arquivo'] + arquivos
        if '--ouvir' in lista:
            eta.ouvir()
        else:
            janela.setProperty('visible', True)
            janela.raise_()
            janela.requestActivate()
        if '--arquivo' in lista:
            i = lista.index('--arquivo')
            for c in lista[i + 1:]:
                if not c.startswith('--'):
                    eta._ler_arquivo(os.path.abspath(c))
            perguntas = []
        elif perguntas:
            QTimer.singleShot(300, lambda: eta.enviar(' '.join(perguntas)))

    servidor = QLocalServer()
    QLocalServer.removeServer(nome_canal)
    servidor.listen(nome_canal)

    def nova_ligacao():
        c = servidor.nextPendingConnection()

        def ler():
            try:
                tratar(json.loads(bytes(c.readAll()).decode() or '[]'))
            except ValueError:
                pass
        c.readyRead.connect(ler)
    servidor.newConnection.connect(nova_ligacao)
    eta.pedirJanela.connect(lambda: tratar([]))
    # sem janela, sem nuvem e sem nada a decorrer: a Eta fecha-se e liberta a memoria da IA
    vigia = QTimer()
    vigia.setInterval(3000)
    vigia.timeout.connect(lambda: (not janela.property('visible') and not eta.nuvem and not eta.ocupada) and app.quit())
    vigia.start()
    QTimer.singleShot(200, lambda: tratar(args))
    try:
        codigo = app.exec()
    finally:
        eta.fechar()
        servidor.close()
    return codigo


if __name__ == '__main__':
    sys.exit(principal())
