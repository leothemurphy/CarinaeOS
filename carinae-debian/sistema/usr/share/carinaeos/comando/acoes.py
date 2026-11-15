# CarinaeOS - Pesquisa: "acoes" que se fazem direto dos resultados (como a nova pesquisa do Windows):
# "diminuir volume" mostra o volume com um controlo deslizante e o botao Diminuir;
# "ativar modo claro" muda o tema com o botao Aplicar; "desligar o wi-fi", "brilho", "lado a lado"…
# Cada acao: id, titulo, frases (para reconhecer o pedido, com tolerancia a erros), icone,
# botao, controlo ('deslizante' | 'interruptor' | None) e as funcoes ler/fazer/definir.
import difflib
import re
import shutil
import subprocess
import threading
import time
import unicodedata


def norm(t):
    t = ''.join(c for c in unicodedata.normalize('NFD', (t or '').lower()) if unicodedata.category(c) != 'Mn')
    return re.sub(r'[^a-z0-9%\s-]', ' ', t).strip()


def _cmd(args, timeout=5):
    try:
        r = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
        return r.stdout.strip()
    except Exception:
        return ''


def _bg(args, atraso=0.0):
    def t():
        if atraso:
            time.sleep(atraso)
        try:
            subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        except Exception:
            pass
    threading.Thread(target=t, daemon=True).start()


def _kwin(atalho, atraso=0.35):
    # atalhos do KWin aplicam-se a janela ativa: espera que a Pesquisa feche primeiro
    _bg(['qdbus6', 'org.kde.kglobalaccel', '/component/kwin', 'org.kde.kglobalaccel.Component.invokeShortcut', atalho],
        atraso)


# ---- volume (PipeWire) ------------------------------------------------------------------
SINK = '@DEFAULT_AUDIO_SINK@'


def volume():
    m = re.search(r'([\d.]+)', _cmd(['wpctl', 'get-volume', SINK]))
    return min(1.0, float(m.group(1))) if m else 0.5


def definir_volume(v):
    _bg(['wpctl', 'set-volume', '-l', '1.0', SINK, '%.2f' % max(0.0, min(1.0, v))])


def mudo():
    return 'MUTED' in _cmd(['wpctl', 'get-volume', SINK])


# ---- brilho ---------------------------------------------------------------------------------
def brilho():
    if shutil.which('brightnessctl'):
        a, m = _cmd(['brightnessctl', 'g']), _cmd(['brightnessctl', 'm'])
        if a.isdigit() and m.isdigit() and int(m):
            return int(a) / int(m)
    return 0.8


def definir_brilho(v):
    if shutil.which('brightnessctl'):
        _bg(['brightnessctl', '-q', 's', '%d%%' % max(1, round(v * 100))])


# ---- rede, bluetooth, tema --------------------------------------------------------------------
def wifi():
    return _cmd(['nmcli', 'radio', 'wifi']) == 'enabled'


def bluetooth():
    return 'Powered: yes' in _cmd(['bluetoothctl', 'show'])


def tema_claro():
    return 'Light' in _cmd(['kreadconfig6', '--group', 'General', '--key', 'ColorScheme'])


def aplicar_tema(claro):
    _bg(['plasma-apply-colorscheme', 'BreezeLight' if claro else 'CarinaeOS'])
    _bg(['gsettings', 'set', 'org.gnome.desktop.interface', 'color-scheme', 'default' if claro else 'prefer-dark'])


def nao_incomodar(ligar):
    _bg(['qdbus6', 'org.freedesktop.Notifications', '/org/freedesktop/Notifications',
         'org.freedesktop.Notifications.' + ('Inhibit' if ligar else 'UnInhibit')])


A = []


def acao(**k):
    k.setdefault('controlo', None)
    k.setdefault('botao', 'Aplicar')
    k.setdefault('descricao', '')
    A.append(k)


# volume
acao(id='vol-menos', titulo='Reduzir volume', icone='audio-volume-low', botao='Diminuir',
     frases=['diminuir volume', 'baixar volume', 'reduzir volume', 'menos volume', 'baixar o som', 'diminuir som', 'volume mais baixo'],
     controlo='deslizante', rotulo='Volume de saída',
     descricao='Ajustar o volume dos alto-falantes, fones de ouvido e outros dispositivos de saída',
     ler=volume, definir=definir_volume, fazer=lambda: definir_volume(volume() - 0.10))
acao(id='vol-mais', titulo='Aumentar volume', icone='audio-volume-high', botao='Aumentar',
     frases=['aumentar volume', 'subir volume', 'mais volume', 'aumentar som', 'subir o som', 'volume mais alto'],
     controlo='deslizante', rotulo='Volume de saída',
     descricao='Ajustar o volume dos alto-falantes, fones de ouvido e outros dispositivos de saída',
     ler=volume, definir=definir_volume, fazer=lambda: definir_volume(volume() + 0.10))
acao(id='vol-mudo', titulo='Silenciar o som', icone='audio-volume-muted', botao='Silenciar',
     frases=['silenciar', 'mudo', 'tirar o som', 'sem som', 'mute', 'silenciar som'],
     controlo='interruptor', rotulo='Som silenciado', ler=mudo,
     definir=lambda v: _bg(['wpctl', 'set-mute', SINK, '1' if v else '0']),
     fazer=lambda: _bg(['wpctl', 'set-mute', SINK, '1']))
# brilho
acao(id='brilho-menos', titulo='Reduzir o brilho', icone='brightness-low', botao='Diminuir',
     frases=['diminuir brilho', 'baixar brilho', 'menos brilho', 'reduzir brilho', 'escurecer ecra', 'escurecer tela'],
     controlo='deslizante', rotulo='Brilho da tela', descricao='Ajustar o brilho da tela integrada',
     ler=brilho, definir=definir_brilho, fazer=lambda: definir_brilho(brilho() - 0.15))
acao(id='brilho-mais', titulo='Aumentar o brilho', icone='brightness-high', botao='Aumentar',
     frases=['aumentar brilho', 'subir brilho', 'mais brilho', 'clarear ecra', 'clarear tela'],
     controlo='deslizante', rotulo='Brilho da tela', descricao='Ajustar o brilho da tela integrada',
     ler=brilho, definir=definir_brilho, fazer=lambda: definir_brilho(brilho() + 0.15))
# tema
acao(id='tema-claro', titulo='Alterar o tema atual para Claro', icone='color-management', botao='Aplicar',
     frases=['ativar modo claro', 'modo claro', 'tema claro', 'mudar para claro', 'light mode', 'desativar modo escuro'],
     fazer=lambda: aplicar_tema(True))
acao(id='tema-escuro', titulo='Alterar o tema atual para Escuro', icone='color-management', botao='Aplicar',
     frases=['ativar modo escuro', 'modo escuro', 'tema escuro', 'mudar para escuro', 'dark mode', 'desativar modo claro'],
     fazer=lambda: aplicar_tema(False))
# rede e bluetooth
acao(id='wifi-ligar', titulo='Ligar o Wi-Fi', icone='network-wireless', botao='Ligar',
     frases=['ligar wifi', 'ativar wifi', 'ligar wi-fi', 'ativar wi-fi', 'ligar a internet sem fios'],
     controlo='interruptor', rotulo='Wi-Fi', ler=wifi,
     definir=lambda v: _bg(['nmcli', 'radio', 'wifi', 'on' if v else 'off']),
     fazer=lambda: _bg(['nmcli', 'radio', 'wifi', 'on']))
acao(id='wifi-desligar', titulo='Desligar o Wi-Fi', icone='network-wireless-disconnected', botao='Desligar',
     frases=['desligar wifi', 'desativar wifi', 'desligar wi-fi', 'modo aviao', 'desativar wi-fi'],
     controlo='interruptor', rotulo='Wi-Fi', ler=wifi,
     definir=lambda v: _bg(['nmcli', 'radio', 'wifi', 'on' if v else 'off']),
     fazer=lambda: _bg(['nmcli', 'radio', 'wifi', 'off']))
acao(id='bt-ligar', titulo='Ligar o Bluetooth', icone='preferences-system-bluetooth', botao='Ligar',
     frases=['ligar bluetooth', 'ativar bluetooth'], controlo='interruptor', rotulo='Bluetooth', ler=bluetooth,
     definir=lambda v: _bg(['bluetoothctl', 'power', 'on' if v else 'off']),
     fazer=lambda: _bg(['bluetoothctl', 'power', 'on']))
acao(id='bt-desligar', titulo='Desligar o Bluetooth', icone='preferences-system-bluetooth', botao='Desligar',
     frases=['desligar bluetooth', 'desativar bluetooth'], controlo='interruptor', rotulo='Bluetooth', ler=bluetooth,
     definir=lambda v: _bg(['bluetoothctl', 'power', 'on' if v else 'off']),
     fazer=lambda: _bg(['bluetoothctl', 'power', 'off']))
acao(id='nao-incomodar', titulo='Ativar o modo Não incomodar', icone='notifications-disabled', botao='Ativar',
     frases=['nao incomodar', 'silenciar notificacoes', 'modo foco', 'sem notificacoes'],
     fazer=lambda: nao_incomodar(True))
# janelas
acao(id='janela-esq', titulo='Encostar a janela à esquerda', icone='view-split-left-right', botao='Encostar',
     frases=['janela a esquerda', 'encostar a esquerda', 'lado a lado', 'dividir ecra', 'metade esquerda', 'snap esquerda'],
     fazer=lambda: _kwin('Window Quick Tile Left'))
acao(id='janela-dir', titulo='Encostar a janela à direita', icone='view-split-left-right', botao='Encostar',
     frases=['janela a direita', 'encostar a direita', 'metade direita', 'snap direita'],
     fazer=lambda: _kwin('Window Quick Tile Right'))
acao(id='janela-max', titulo='Maximizar a janela', icone='window-maximize', botao='Maximizar',
     frases=['maximizar janela', 'tela cheia', 'janela grande', 'maximizar'],
     fazer=lambda: _kwin('Window Maximize'))
acao(id='janela-min', titulo='Minimizar todas as janelas', icone='user-desktop', botao='Minimizar',
     frases=['minimizar tudo', 'minimizar janelas', 'mostrar a área de trabalho', 'mostrar area de trabalho', 'ver o ambiente de trabalho'],
     fazer=lambda: _kwin('Show Desktop'))
acao(id='janelas-todas', titulo='Ver todas as janelas', icone='view-grid', botao='Ver',
     frases=['todas as janelas', 'ver janelas', 'visao geral', 'alternar janelas'],
     fazer=lambda: _kwin('Overview'))
# sistema
acao(id='bloquear', titulo='Bloquear a tela', icone='system-lock-screen', botao='Bloquear',
     frases=['bloquear', 'bloquear ecra', 'bloquear tela', 'trancar computador'],
     fazer=lambda: _bg(['loginctl', 'lock-session'], 0.3))
acao(id='suspender', titulo='Suspender o computador', icone='system-suspend', botao='Suspender',
     frases=['suspender', 'dormir', 'hibernar', 'pausar computador'],
     fazer=lambda: _bg(['systemctl', 'suspend'], 0.3))
acao(id='reiniciar', titulo='Reiniciar o computador', icone='system-reboot', botao='Reiniciar',
     frases=['reiniciar', 'reiniciar computador', 'reboot'],
     fazer=lambda: _bg(['qdbus6', 'org.kde.LogoutPrompt', '/LogoutPrompt', 'promptReboot']))
acao(id='desligar', titulo='Desligar o computador', icone='system-shutdown', botao='Desligar',
     frases=['desligar', 'desligar computador', 'encerrar', 'shutdown'],
     fazer=lambda: _bg(['qdbus6', 'org.kde.LogoutPrompt', '/LogoutPrompt', 'promptShutDown']))
acao(id='captura', titulo='Fazer uma captura de tela', icone='spectacle', botao='Capturar',
     frases=['captura de ecra', 'print', 'screenshot', 'tirar foto da tela', 'capturar tela', 'print screen'],
     fazer=lambda: _bg(['spectacle'], 0.4))
acao(id='captura-regiao', titulo='Capturar uma região da tela', icone='spectacle', botao='Capturar',
     frases=['recortar ecra', 'captura de regiao', 'recorte', 'capturar parte da tela'],
     fazer=lambda: _bg(['spectacle', '-r'], 0.4))
acao(id='lixo', titulo='Abrir a lixeira', icone='user-trash', botao='Abrir',
     frases=['lixeira', 'lixo', 'reciclagem'], fazer=lambda: _bg(['dolphin', 'trash:/']))

VOCABULARIO = sorted({p for a in A for f in a['frases'] for p in norm(f).split() if len(p) > 2})


def _parecido(a, b):
    return difflib.SequenceMatcher(None, a, b).ratio()


def reconhecer(texto, n=2):
    """As acoes que correspondem ao pedido, com pontuacao (tolera erros de escrita)."""
    q = norm(texto)
    if len(q) < 3:
        return []
    qp = q.split()
    res = []
    for a in A:
        melhor = 0.0
        for f in a['frases'] + [norm(a['titulo'])]:
            f = norm(f)
            if q == f:
                s = 1.0
            elif f.startswith(q) or q.startswith(f):
                s = 0.9 * min(len(q), len(f)) / max(len(q), len(f)) + 0.1
            else:
                fp = f.split()
                # cada palavra pedida tem de existir (ou quase) na frase
                acertos = sum(max((_parecido(w, x) for x in fp), default=0) for w in qp) / len(qp)
                s = 0.6 * acertos + 0.4 * _parecido(q, f)
            melhor = max(melhor, s)
        if melhor >= 0.72:
            res.append((melhor, a))
    res.sort(key=lambda x: -x[0])
    if not res:
        return []
    topo = res[0][0]
    return [a for p, a in res[:n] if p >= topo - 0.03]


def correcoes(texto, extra=()):
    """Palavras parecidas com a ultima escrita (os botoezinhos por cima da caixa de pesquisa)."""
    q = norm(texto).split()
    if not q or len(q[-1]) < 3:
        return []
    ultima = q[-1]
    vocab = list(VOCABULARIO) + [norm(x) for x in extra]
    c = [w for w in difflib.get_close_matches(ultima, vocab, n=4, cutoff=0.72) if w != ultima]
    vistos = []
    for w in c:
        if w not in vistos:
            vistos.append(w)
    return vistos[:3]
