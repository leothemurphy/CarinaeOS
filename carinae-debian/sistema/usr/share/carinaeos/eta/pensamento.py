# CarinaeOS - Eta: a conversa com a IA e as ferramentas (misturado na classe Eta).
# Fluxo: pedido -> IA escolhe ferramentas -> a Eta executa. Ferramentas de consulta
# (info do sistema, memoria, comandos que so leem) devolvem o resultado a IA, que
# depois explica em palavras simples.
import difflib
import json
import os
import re
import shlex
import subprocess
import threading
import time
import uuid

import acoes as A
import ambiente as AMBI
import apps as APPS
import cerebro as CB
import memoria as MEM
from conhecimento import TOPICOS

HOME = os.path.expanduser('~')


def _eta():
    """O modulo principal da Eta (quando corre como programa e o __main__; nao o importar duas vezes)."""
    import sys
    m = sys.modules.get('__main__')
    if m is not None and hasattr(m, 'separar_codigo'):
        return m
    import eta
    return eta

CONFIGURACOES = {
    'tela': 'kcmshell6 kcm_kscreen', 'som': 'kcmshell6 kcm_pulseaudio', 'rede': 'kcmshell6 kcm_networkmanagement',
    'wifi': 'kcmshell6 kcm_networkmanagement', 'bluetooth': 'kcmshell6 kcm_bluetooth',
    'energia': 'kcmshell6 kcm_powerdevilprofilesconfig', 'aparencia': 'kcmshell6 kcm_lookandfeel',
    'cores': 'kcmshell6 kcm_colors', 'papel_de_parede': 'kcmshell6 kcm_wallpaper', 'teclado': 'kcmshell6 kcm_keyboard',
    'mouse': 'kcmshell6 kcm_mouse', 'touchpad': 'kcmshell6 kcm_touchpad', 'impressoras': 'kcmshell6 kcm_printer_manager',
    'usuarios': 'kcmshell6 kcm_users', 'data_hora': 'kcmshell6 kcm_clock', 'idioma': 'kcmshell6 kcm_regionandlang',
    'notificacoes': 'kcmshell6 kcm_notifications', 'atalhos': 'kcmshell6 kcm_keys',
    'aplicativos_padrao': 'kcmshell6 kcm_componentchooser', 'luz_noturna': 'kcmshell6 kcm_nightlight',
    'sobre': 'kcmshell6 kcm_about-distro', 'backups': 'kcmshell6 kcm_kup', 'inicio_automatico': 'kcmshell6 kcm_autostart',
    'acessibilidade': 'kcmshell6 kcm_access', 'geral': 'systemsettings',
}
NOMES_CONFIG = {'tela': 'de tela', 'som': 'de som', 'rede': 'de rede', 'wifi': 'de Wi-Fi', 'bluetooth': 'de Bluetooth',
                'energia': 'de energia', 'aparencia': 'de aparência', 'cores': 'de cores', 'papel_de_parede': 'do papel de parede',
                'teclado': 'do teclado', 'mouse': 'do mouse', 'touchpad': 'do touchpad', 'impressoras': 'de impressoras',
                'usuarios': 'de usuários', 'data_hora': 'de data e hora', 'idioma': 'de idioma', 'notificacoes': 'de notificações',
                'atalhos': 'de atalhos', 'aplicativos_padrao': 'de aplicativos padrão', 'luz_noturna': 'da luz noturna',
                'sobre': 'Sobre este computador', 'backups': 'de backups', 'inicio_automatico': 'de início automático',
                'acessibilidade': 'de acessibilidade', 'geral': 'do sistema'}

PASTAS = {'inicio': '~', 'casa': '~', 'pessoal': '~', 'documentos': '~/Documentos', 'downloads': '~/Downloads',
          'transferencias': '~/Downloads', 'imagens': '~/Imagens', 'fotos': '~/Imagens', 'musicas': '~/Músicas',
          'musica': '~/Músicas', 'videos': '~/Vídeos', 'area_de_trabalho': '~/Área de trabalho', 'desktop': '~/Área de trabalho',
          'lixeira': 'trash:/', 'lixo': 'trash:/', 'etiquetas': '~/Etiquetas', 'modelos': '~/Modelos', 'publico': '~/Público'}

# ferramentas do CarinaeOS (algumas nao aparecem no menu: vivem na Central)
FERR_CARINAE = [
    (r'central|ferramentas do carinae', 'carinaeos-central', 'a Central CarinaeOS'),
    (r'supernova|personaliz|dock', 'carinaeos-supernova', 'o Supernova'),
    (r'orbita|loja', 'carinaeos-orbita', 'a Órbita'),
    (r'\bcasa\b|home ?assistant', 'carinaeos-casa', 'a Casa'),
    (r'ambiente|estilo|gnome|xfce|windows|plasma', 'carinaeos-ambientes', 'a troca de ambiente e estilo'),
    (r'cadeado|tranc|bloque', 'carinaeos-cadeado aplicativos', 'o Cadeado'),
    (r'calendario|agenda', 'merkuro-calendar', 'o Calendário'),
    (r'\bmapas?\b', 'marble', 'os Mapas'),
    (r'terminal|konsole|consola|console', 'konsole', 'o terminal'),
    (r'boas.?vindas', 'carinaeos-boasvindas', 'as Boas-vindas'),
    (r'manual|ajuda|guia do sistema', 'carinaeos-manual', 'o Manual do CarinaeOS'),
    (r'eta|assistente', None, None),
]

# comandos que so leem informacao: correm logo e o resultado volta para a IA explicar
LEITURA = re.compile(r'^(ls|df|du|free|uname|lscpu|lspci|lsusb|lsblk|blkid|ip|hostname|hostnamectl|uptime|whoami|id|ps|'
                     r'top|pactl|wpctl|nmcli|ping|inxi|fastfetch|neofetch|sensors|date|timedatectl|cat|head|tail|wc|grep|'
                     r'which|whereis|type|apt|apt-cache|dpkg|dpkg-query|flatpak|find|lsmod|glxinfo|xrandr|kscreen-doctor|'
                     r'upower|acpi|bluetoothctl|systemctl|journalctl|locale|env|printenv|echo|stat|file|du|sort|uniq|awk|cut|'
                     r'tr|nproc|getconf|lshw|dmidecode|vainfo|nvidia-smi|smartctl|gio|udisksctl|loginctl|xdg-mime|'
                     r'plasmashell|kreadconfig6|gsettings|xfconf-query|resolvectl|ss|curl|dig|host|nslookup|traceroute)\b')
LEITURA_PROIBIDO = re.compile(r'(>|\brm\b|\bsudo\b|\bpkexec\b|-delete\b|-exec\b|\bkill|\bset\b|\binstall\b|\bremove\b|'
                              r'\bpurge\b|\bupgrade\b|\bupdate\b|\buninstall\b|\bstart\b|\bstop\b|\brestart\b|\benable\b|'
                              r'\bdisable\b|\bmask\b|\bmount\b|\bunmount\b|\bunlock\b|\bpower-off\b|\bconnect\b|\bdelete\b|'
                              r'\bdown\b|\bup\b|\bmodify\b|\b-[a-zA-Z]*o\b\s+\S+\s*$|--output)')


FINGIU = re.compile(r'^\W*(abri|liguei|desliguei|mudei|pus|coloquei|instalei|removi|desinstalei|ativei|desativei|tranquei|'
                    r'apaguei|acendi|aumentei|diminui|baixei|subi|troquei|fechei|conectei|liguei-me)\b', re.I)


def so_leitura(cmd):
    if not cmd or '`' in cmd or '$(' in cmd or LEITURA_PROIBIDO.search(cmd):
        return False
    for parte in re.split(r'\|\|?|&&|;', cmd):
        parte = parte.strip()
        if parte and not LEITURA.match(parte):
            return False
    return True


def topicos_relevantes(texto, n=2):
    simples = _eta().simples
    s = simples(texto)
    res = []
    for t in TOPICOS:
        if not t.get('resposta'):
            continue
        ws = [w for w in dict.fromkeys(t['palavras'].split()) if len(w) > 3]
        p = sum(1 for w in ws if re.search(r'\b' + re.escape(w), s))
        if p:
            res.append((p, t))
    res.sort(key=lambda x: -x[0])
    return [t for p, t in res[:n] if p >= 1]


class Pensamento:
    """Conversa com a IA (local ou nuvem) e executa as ferramentas que ela escolhe."""

    # ---- historico para a IA, montado a partir das mensagens visiveis ----------------------------
    def _conversa(self, ultimo_extra=''):
        """Historico para a IA. As acoes feitas entram como chamadas de ferramenta (o formato em que
        o modelo foi treinado), para ele nao as repetir nem as imitar em texto."""
        msgs = []
        for m in self._msgs[-16:]:
            p = m.get('papel')
            if p == 'eu':
                c = m.get('texto', '')
                if m.get('anexo'):
                    c = '[enviei o arquivo %s]' % c
                if msgs and msgs[-1]['role'] == 'user':
                    msgs[-1]['content'] += '\n' + c
                else:
                    msgs.append(dict(role='user', content=c))
                ch = m.get('chamadas') or []
                if ch:
                    ids = ['h%d_%d' % (m['id'], i) for i in range(len(ch))]
                    msgs.append(dict(role='assistant', content='', tool_calls=[
                        dict(id=i, type='function', function=dict(name=n, arguments=json.dumps(a, ensure_ascii=False)))
                        for i, (n, a) in zip(ids, ch)]))
                    for i in ids:
                        msgs.append(dict(role='tool', tool_call_id=i, content='feito'))
            elif p in ('eta', 'arquivos', 'escolhas'):
                c = m.get('texto', '')
                if m.get('codigo'):
                    c += '\n```\n%s\n```' % m['codigo']
                if not c.strip() or m.get('escrevendo'):
                    continue
                if msgs and msgs[-1]['role'] == 'assistant' and not msgs[-1].get('tool_calls'):
                    msgs[-1]['content'] += '\n' + c
                else:
                    msgs.append(dict(role='assistant', content=c))
        while msgs and msgs[0]['role'] != 'user':
            msgs.pop(0)
        if msgs and msgs[-1]['role'] == 'user' and ultimo_extra:
            msgs[-1] = dict(role='user', content=ultimo_extra + '\n\nPEDIDO: ' + msgs[-1]['content'])
        return msgs

    def _contexto(self, pergunta):
        partes = []
        for t in topicos_relevantes(pergunta):
            partes.append('- %s' % t['resposta'])
        lemb = [l for l in MEM.lembrar(pergunta, 3) if l[0] >= 3.0]
        for _, titulo, texto, _d in lemb:
            partes.append('- (%s) %s' % (titulo, texto[:1200]))
        if self._documento:
            partes.append('- ARQUIVO ENVIADO "%s":\n%s' % (self._documento[0], self._documento[1][:4000]))
        if not partes:
            return ''
        return 'CONTEXTO (use se ajudar a responder):\n' + '\n'.join(partes)

    def _sistema(self):
        return CB.PROMPT + '\nAmbiente de trabalho em uso: %s.' % AMBI.NOME

    def _cerebro_pronto(self):
        if bool(self._cerebro.nuvem()):
            return True
        if self._estado == 'pronta' and self._proc is not None and self._proc.poll() is not None:
            # o servidor fechou: voltar a arranca-lo e responder sem IA desta vez
            self._estado = 'a-iniciar'
            threading.Thread(target=self._iniciar_ia, daemon=True).start()
            return False
        return self._estado == 'pronta'

    # ---- pensar ---------------------------------------------------------------------------------
    def _pensar(self):
        pergunta = self._ultimo_pedido()
        self._pergunta_atual = pergunta
        geracao = self._geracao
        m = self._add(papel='eta', texto='', codigo='', escrevendo=True)
        ident = m['id']
        self._pensando = True
        self._definir_atividade('A pensar…')
        sem_pensar = bool((self._modelo or {}).get('sem_pensar'))
        msgs = [dict(role='system', content=self._sistema())] + self._conversa(self._contexto(pergunta))

        def parar():
            return geracao != self._geracao

        def ao_escrever(txt):
            if '<tool_call>' not in txt:
                self._parcial.emit(ident, txt)

        def tarefa():
            texto, chamadas = '', []
            try:
                for _volta in range(4):
                    texto, chamadas = self._cerebro.falar(msgs, ao_escrever, parar, sem_pensar=sem_pensar)
                    if parar():
                        return
                    if not chamadas and _volta == 0 and FINGIU.match(texto or ''):
                        # disse que fez, mas nao chamou nenhuma ferramenta: pedir que o faca de verdade
                        msgs.append(dict(role='assistant', content=texto))
                        msgs.append(dict(role='user', content='Você ainda não fez nada: chame a ferramenta certa para fazer o meu pedido.'))
                        continue
                    consulta = [(n, a) for n, a in chamadas if n in CB.DE_CONSULTA or
                                (n == 'executar_comando' and so_leitura(a.get('comando', '')))]
                    if not consulta or len(consulta) != len(chamadas):
                        break
                    # ferramentas de consulta: correr e devolver o resultado a IA
                    ids = [uuid.uuid4().hex[:12] for _ in chamadas]
                    msgs.append(dict(role='assistant', content=texto or '', tool_calls=[
                        dict(id=i, type='function', function=dict(name=n, arguments=json.dumps(a, ensure_ascii=False)))
                        for i, (n, a) in zip(ids, chamadas)]))
                    for i, (n, a) in zip(ids, chamadas):
                        self._fundo.emit(lambda d: self._definir_atividade(d), 'A pesquisar na internet: %s…' % a.get('consulta', '')
                                         if n == 'pesquisar_internet' else 'A ver: %s…' % (a.get('descricao') or n.replace('_', ' ')))
                        msgs.append(dict(role='tool', tool_call_id=i, content=self._consultar(n, a)[:3500]))
                        self._fundo.emit(lambda x: self._mostrar_consulta(*x), (n, a, ident))
                    chamadas = []
            except Exception as e:
                texto, chamadas = '__erro__' + str(e), []
            if not parar():
                self._fundo.emit(lambda r: self._fim_pensar(ident, *r), (texto, chamadas))
        threading.Thread(target=tarefa, daemon=True).start()

    def _mostrar_consulta(self, nome, args, ident=None):
        if nome == 'pesquisar_internet':
            self._add(papel='feito', texto='🌐 Pesquisei na internet: %s' % args.get('consulta', ''))
            resp = [m for m in self._msgs if m['id'] == ident]
            if resp:
                self._msgs = [m for m in self._msgs if m['id'] != ident] + resp
                self.mudou.emit()
            return
        if nome == 'executar_comando':
            self._add(papel='feito', texto='Consultei: %s' % (args.get('descricao') or 'o sistema'), codigo=args.get('comando', ''))
            # a resposta (que ainda esta a ser escrita) fica depois da consulta
            resp = [m for m in self._msgs if m['id'] == ident]
            if resp:
                self._msgs = [m for m in self._msgs if m['id'] != ident] + resp
                self.mudou.emit()

    def _consultar(self, nome, a):
        info_sistema = _eta().info_sistema
        if nome == 'info_sistema':
            return info_sistema()
        if nome == 'pesquisar_internet':
            if not self._cfg.get('internet', True):
                return 'A pesquisa na internet está desligada pelo usuário (⚙). Responda com o que sabe e diga isso.'
            import internet
            return internet.pesquisar(a.get('consulta', ''))
        if nome == 'consultar_memoria':
            lemb = MEM.lembrar(a.get('pergunta', ''), 3)
            if not lemb:
                return 'Nada sobre isso na memória.'
            return '\n'.join('[%s] %s' % (t, x[:900]) for _, t, x, _d in lemb)
        if nome == 'executar_comando':
            cmd = a['comando']
            if re.match(r'^\s*ping\b', cmd) and not re.search(r'\s-c\s*\d', cmd):
                cmd = re.sub(r'^\s*ping\b', 'ping -c 4', cmd)
            if re.match(r'^\s*top\b', cmd) and '-b' not in cmd:
                cmd = re.sub(r'^\s*top\b', 'top -b -n 1 | head -25 #', cmd)
            try:
                r = subprocess.run(['bash', '-c', cmd], capture_output=True, text=True, timeout=25,
                                   env=dict(os.environ, LC_ALL='C.UTF-8', COLUMNS='160'))
                saida = (r.stdout + ('\n' + r.stderr if r.stderr else '')).strip()
                return (saida or '(sem saída)')[-3400:] + ('' if r.returncode == 0 else '\n(código de saída %d)' % r.returncode)
            except subprocess.TimeoutExpired:
                return '(o comando demorou demais e foi parado)'
            except Exception as e:
                return 'erro: %s' % e
        return ''

    def _fim_pensar(self, ident, texto, chamadas):
        self._pensando = False
        if texto.startswith('__erro__'):
            erro = texto[8:]
            n = self._cerebro.nuvem()
            msg = ('Não consegui falar com %s (%s). Verifique a internet e a chave em ⚙ › Cérebro da Eta.' % (n['nome'], erro[:120])
                   if n else 'Desculpe, não consegui pensar agora. Tente de novo daqui a pouco.')
            self._trocar(ident, texto=msg, escrevendo=False)
            self.mudou.emit()
            return
        separar_codigo = _eta().separar_codigo
        if texto:
            vis, codigo = separar_codigo(texto)
            self._trocar(ident, texto=vis, codigo=codigo, escrevendo=False)
            if not chamadas:
                self._talvez_falar(vis)
        else:
            self._msgs = [x for x in self._msgs if x['id'] != ident]
        ultimo = next((m for m in reversed(self._msgs) if m.get('papel') == 'eu'), None)
        if ultimo is not None and chamadas:
            ultimo['chamadas'] = [(n, a) for n, a in chamadas]
        for nome, args in chamadas:
            try:
                self._executar(nome, args)
            except Exception as e:
                self._dizer('Algo correu mal ao fazer isso (%s).' % e)
        if not texto and not chamadas:
            self._dizer('Não percebi bem. Pode dizer de outra forma?')
        self.mudou.emit()

    # ---- executar as ferramentas ------------------------------------------------------------------
    def _executar(self, nome, a):
        simples = _eta().simples
        if nome == 'abrir_aplicativo':
            self._abrir_app(a.get('nome', ''))
        elif nome == 'abrir_pasta':
            self._abrir_pasta(a.get('pasta', ''))
        elif nome == 'abrir_configuracao':
            p = a.get('pagina', 'geral')
            self._fazer('abrir as configurações %s' % NOMES_CONFIG.get(p, ''), CONFIGURACOES.get(p, 'systemsettings'))
        elif nome == 'ajustar':
            self._ajustar(a.get('o_que', ''), str(a.get('valor', '')))
        elif nome == 'instalar_programa':
            self._instalar(a.get('nome', ''))
        elif nome == 'remover_programa':
            self._remover(a.get('nome', ''))
        elif nome == 'procurar_arquivos':
            self._mostrar_busca(a.get('palavras', ''))
        elif nome == 'info_sistema':
            info_sistema = _eta().info_sistema
            self._dizer(info_sistema())
        elif nome == 'discos':
            self._discos(ejetar=a.get('acao') == 'ejetar')
        elif nome == 'pasta_de_rede':
            self._rede_inicio(a.get('endereco', '') or '')
        elif nome == 'wifi':
            self._wifi()
        elif nome == 'atualizacoes':
            self._atualizacoes()
        elif nome == 'casa':
            p = a.get('pedido', '')
            if not self._casa:
                self._dizer('A Casa ainda não está ligada ao seu Home Assistant.',
                            botoes=[('Abrir a Casa', lambda: self._fazer('abrir a Casa', 'carinaeos-casa'))])
            elif not self._casa_pedido(p, simples(p)):
                self._dizer('Não encontrei esse aparelho na sua casa.')
        elif nome == 'executar_comando':
            cmd = a.get('comando', '')
            if cmd:
                precisa_permissao = _eta().precisa_permissao
                self._pedir(a.get('descricao') or 'executar um comando', cmd, confirmar=precisa_permissao(cmd))
        elif nome == 'lembrar':
            nota = a.get('nota', '').strip()
            if nota:
                MEM.aprender('nota:%d' % int(time.time() * 1000), nota[:70], nota, 'nota')
                self._add(papel='feito', texto='Guardado na minha memória ✓')
        elif nome == 'como_usar_aplicativo':
            if not self._guia(a.get('nome', '')):
                self._dizer('Ainda não conheço bem esse aplicativo. Quer que eu o procure para instalar?',
                            botoes=[('Instalar “%s”' % a.get('nome', ''), lambda n=a.get('nome', ''): self._instalar(n))])
        elif nome == 'trancar':
            self._trancar(a.get('o_que', ''))
        elif nome == 'perguntar':
            ops = [o for o in (a.get('opcoes') or []) if isinstance(o, str) and o.strip()][:4]
            self._dizer(a.get('pergunta') or 'O que prefere?',
                        botoes=[(o, lambda o=o: self.enviar(o)) for o in ops])
        else:
            self._dizer('Ainda não sei fazer isso.')

    def _abrir_app(self, nome):
        simples = _eta().simples
        s = simples(nome).strip()
        s = re.sub(r'^(o|a|os|as|app|aplicativo|programa)\s+', '', s)
        app = self._app_exato(s) or APPS.procurar(nome) or self._app_parecido(s)
        if app:
            self._fazer('abrir o %s' % app[1], APPS.comando_abrir(app[2]))
            return
        for padrao, cmd, desc in FERR_CARINAE:
            if re.search(padrao, s):
                if cmd:
                    self._fazer('abrir %s' % desc, cmd)
                else:
                    self._dizer('Já estou aqui ✦')
                return
        nome_cat = next((k for k in list(self.APT) + list(self.NOMES) if re.search(r'\b' + re.escape(k) + r'\b', APPS.normalizar(s))), None)
        self._dizer('O “%s” não está instalado. Quer que eu o procure e instale?' % (nome_cat or nome),
                    botoes=[('Instalar “%s”' % (nome_cat or nome), lambda n=(nome_cat or nome): self._instalar(n)),
                            ('Abrir a Órbita', lambda: self._fazer('abrir a Órbita', 'carinaeos-orbita'))])

    def _app_exato(self, s):
        """'libre office' -> o LibreOffice principal (e nao o Impress): exato, senao o nome mais curto que o contem."""
        s = APPS.normalizar(s).strip()
        if len(s) < 3:
            return None
        todos = APPS.instalados()
        for c in todos:
            if c[0] == s or c[3] == s:
                return (c[0], c[1], c[2])
        junto = s.replace(' ', '')
        cand = [c for c in todos if junto in c[0].replace(' ', '') or junto in c[3].replace(' ', '').replace('-', '')]
        if cand:
            c = min(cand, key=lambda c: len(c[0]))
            return (c[0], c[1], c[2])
        return None

    def _app_parecido(self, s):
        s = APPS.normalizar(s)
        todos = APPS.instalados()
        chaves = [c[0] for c in todos]
        perto = difflib.get_close_matches(s, chaves, n=1, cutoff=0.72)
        if perto:
            c = next(x for x in todos if x[0] == perto[0])
            return (c[0], c[1], c[2])
        junto = s.replace(' ', '')
        for c in todos:
            if c[0].replace(' ', '') == junto or (len(junto) >= 4 and c[0].replace(' ', '').startswith(junto)):
                return (c[0], c[1], c[2])
        # pelo que o aplicativo faz (ex.: "planilha" -> LibreOffice Calc)
        for c in todos:
            extra = APPS.descricao(c[2])
            if len(s) >= 5 and re.search(r'\b' + re.escape(s) + r'\b', extra):
                return (c[0], c[1], c[2])
        return None

    def _abrir_pasta(self, pasta):
        simples = _eta().simples
        s = simples(pasta).strip().replace(' ', '_')
        s = re.sub(r'^(a_|o_|minha_|meus_|minhas_|pasta_(de_|dos_|das_)?)', '', s)
        destino = PASTAS.get(s) or PASTAS.get(s.rstrip('s')) or pasta
        if destino != 'trash:/':
            destino = os.path.expanduser(destino)
            if not os.path.exists(destino):
                achado = [os.path.join(HOME, d) for d in os.listdir(HOME) if simples(d) == simples(pasta)]
                if achado:
                    destino = achado[0]
                else:
                    self._mostrar_busca(pasta)
                    return
        self._fazer('abrir a pasta %s' % (os.path.basename(destino.rstrip('/')) or destino), 'dolphin %s' % shlex.quote(destino))

    def _ajustar(self, o_que, valor):
        v = valor.lower().strip()
        ligar = not re.search(r'deslig|off|false|nao|desativ|0$', v)
        num = re.search(r'\d{1,3}', v)
        if o_que == 'tema':
            claro = bool(re.search(r'clar|light|branc', v))
            self._fazer('mudar para o modo %s' % ('claro' if claro else 'escuro'),
                        'plasma-apply-colorscheme %s' % ('BreezeLight' if claro else 'CarinaeOS'))
        elif o_que == 'luz_noturna':
            self._fazer('%s a luz noturna' % ('ligar' if ligar else 'desligar'),
                        'kwriteconfig6 --file kwinrc --group NightColor --key Active %s && qdbus6 org.kde.KWin /KWin reconfigure'
                        % ('true' if ligar else 'false'))
        elif o_que == 'volume':
            if 'mud' in v or 'silenc' in v:
                cmd, d = 'wpctl set-mute @DEFAULT_AUDIO_SINK@ 1', 'silenciar o som'
            elif num:
                cmd, d = 'wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ %d%%' % min(100, int(num.group())), \
                    'pôr o volume em %d%%' % min(100, int(num.group()))
            elif re.search(r'men|baix|diminu', v):
                cmd, d = 'wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-', 'baixar o volume'
            else:
                cmd, d = 'wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 10%+', 'aumentar o volume'
            self._fazer(d, cmd)
        elif o_que == 'brilho':
            base = 'qdbus6 org.kde.Solid.PowerManagement /org/kde/Solid/PowerManagement/Actions/BrightnessControl'
            if num:
                p = min(100, max(1, int(num.group())))
                cmd = 'm=$(%s brightnessMax); %s setBrightness $((m*%d/100))' % (base, base, p)
                d = 'pôr o brilho em %d%%' % p
            else:
                mais = not re.search(r'men|baix|diminu', v)
                cmd = 'm=$(%s brightnessMax); b=$(%s brightness); %s setBrightness $((b %s m/10))' % (base, base, base, '+' if mais else '-')
                d = 'aumentar o brilho' if mais else 'baixar o brilho'
            if AMBI.AMB != 'plasma':
                cmd = 'brightnessctl set %s' % (('%d%%' % p) if num else ('10%+' if mais else '10%-'))
            self._fazer(d, cmd)
        elif o_que == 'wifi':
            self._fazer('%s o Wi-Fi' % ('ligar' if ligar else 'desligar'), 'nmcli radio wifi %s' % ('on' if ligar else 'off'))
        elif o_que == 'bluetooth':
            self._fazer('%s o Bluetooth' % ('ligar' if ligar else 'desligar'),
                        'rfkill %s bluetooth; bluetoothctl power %s' % ('unblock' if ligar else 'block', 'on' if ligar else 'off'))
        elif o_que == 'nao_perturbe':
            if AMBI.AMB == 'gnome':
                cmd = 'gsettings set org.gnome.desktop.notifications show-banners %s' % ('false' if ligar else 'true')
            elif AMBI.AMB == 'xfce':
                cmd = 'xfconf-query -c xfce4-notifyd -p /do-not-disturb -n -t bool -s %s' % ('true' if ligar else 'false')
            else:
                cmd = ('kwriteconfig6 --file plasmanotifyrc --group DoNotDisturb --key Until %s && '
                       'qdbus6 org.freedesktop.Notifications /org/freedesktop/Notifications org.freedesktop.Notifications.Inhibit '
                       '"Eta" "Não perturbe" {} >/dev/null 2>&1 || true') % ('2099,12,31,0,0,0' if ligar else '""')
            self._fazer('%s o “Não perturbe”' % ('ligar' if ligar else 'desligar'), cmd)
        elif o_que == 'papel_de_parede':
            self._fazer('trocar o papel de parede', 'carinaeos-fundo --proximo')
        else:
            self._dizer('Não sei mudar isso ainda.')

    def _remover(self, nome):
        simples = _eta().simples
        chave = simples(nome).strip()

        def procurar():
            app = APPS.procurar(nome) or self._app_parecido(chave)
            if app:
                caminho = app[2]
                if '/flatpak/' in caminho:
                    return ('flatpak', os.path.basename(caminho)[:-8], app[1])
                r = subprocess.run(['dpkg', '-S', caminho], capture_output=True, text=True)
                if r.returncode == 0:
                    return ('apt', r.stdout.split(':')[0].strip(), app[1])
            pac = A.pacote_apt(self.APT.get(chave, chave))
            if pac and A.instalado_apt(pac):
                return ('apt', pac, pac)
            return None

        def depois(r):
            if isinstance(r, Exception) or not r:
                self._dizer('Não encontrei o “%s” instalado neste computador.' % nome)
                return
            tipo, ident, titulo = r
            if tipo == 'apt':
                cmd = "pkexec env DEBIAN_FRONTEND=noninteractive apt-get remove -y -o APT::Status-Fd=1 %s" % shlex.quote(ident)
                self._pedir('desinstalar o %s' % titulo, cmd, confirmar=True, demorado=True, mostrar='sudo apt remove %s' % ident)
            else:
                cmd = 'flatpak uninstall -y %s' % shlex.quote(ident)
                self._pedir('desinstalar o %s' % titulo, cmd, confirmar=True, demorado=True, mostrar=cmd)
        self._em_fundo(None, procurar, depois, atividade='A procurar “%s”…' % nome)

    def _trancar(self, o_que):
        caminho = os.path.expanduser(o_que.strip())
        if not caminho.startswith('/'):
            p = PASTAS.get(re.sub(r'\W+', '_', o_que.strip().lower()))
            if p and p != 'trash:/':
                caminho = os.path.expanduser(p)
            else:
                cand = os.path.join(HOME, o_que.strip())
                caminho = cand if os.path.exists(cand) else caminho
        if os.path.exists(caminho):
            self._fazer('trancar “%s” com senha' % os.path.basename(caminho), 'carinaeos-cadeado trancar %s' % shlex.quote(caminho))
            return
        app = APPS.procurar(o_que) or self._app_parecido(o_que.lower())
        if app:
            self._fazer('escolher os aplicativos trancados', 'carinaeos-cadeado aplicativos')
            return
        self._dizer('Não encontrei “%s”. Pode dizer o nome exato da pasta ou do arquivo?' % o_que)

    def _guia(self, nome):
        app = APPS.procurar(nome) or self._app_parecido(nome.lower())
        d = MEM.guia_app(app[1] if app else nome)
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
        simples = _eta().simples
        chave = next((k for k in MEM.GUIAS if k in simples(nome)), None)
        if chave:
            corpo = '\n'.join('%d. %s' % (i + 1, l) for i, l in enumerate(MEM.GUIAS[chave]))
            self._dizer('Como usar o %s:\n%s\n\n(Ainda não está instalado neste computador.)' % (chave, corpo),
                        botoes=[('Instalar o %s' % chave, lambda n=chave: self._instalar(n))])
            return True
        return False
