#!/usr/bin/env python3
# CarinaeOS — liga o Comando (Ctrl+Espaço) ao ambiente próprio, sem mudar nada no Plasma:
# na sessão CarinaeOS, cada coisa que o Comando pedia ao KDE passa a ir para a peça nossa equivalente
# (desligar/reiniciar/sair, encostar janelas, mostrar a área de trabalho, Wi-Fi/Som/Telas, brilho,
# não incomodar, papel de parede seguinte, lixeira). Idempotente; guarda cópia; confere que compila.
import os
import shutil
import sys
import time

PASTA = sys.argv[1] if len(sys.argv) > 1 else '/usr/share/carinaeos/comando'

COMPAT = r'''# CarinaeOS — o Comando na sessão CarinaeOS (Gravidade + Aurora): o que era do KDE vai para as peças nossas.
# (escrito pelo ferramentas/ajustar-comando.py do carinaeos-ambiente)
import os
import subprocess

CASA = os.path.expanduser('~')
CFG = os.path.join(CASA, '.config', 'carinaeos')


def carinae():
    return os.environ.get('XDG_CURRENT_DESKTOP', '').startswith('CarinaeOS')


_KG = 'qdbus6 org.kde.kglobalaccel /component/kwin org.kde.kglobalaccel.Component.invokeShortcut '
TABELA = {
    'qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptReboot': 'carinae-sessao reiniciar',
    'qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptShutDown': 'carinae-sessao desligar',
    'qdbus6 org.kde.LogoutPrompt /LogoutPrompt promptLogout': 'carinae-sessao sair',
    'loginctl lock-session': 'carinae-sessao bloquear',
    _KG + 'Overview': 'aurora --enviar lancador',
    _KG + "'Show Desktop'": 'aurora --enviar mesa',
    _KG + 'Show Desktop': 'aurora --enviar mesa',
    'kcmshell6 kcm_networkmanagement': 'carinaeos-configuracoes wifi',
    'kcmshell6 kcm_bluetooth': 'carinaeos-configuracoes bluetooth',
    'kcmshell6 kcm_pulseaudio': 'carinaeos-configuracoes som',
    'kcmshell6 kcm_kscreen': 'carinae-telas',
    'carinaeos-fundo --proximo': 'aurora --enviar papel-seguinte',
    'dolphin trash:/': 'carinaeos-arquivos "$HOME/.local/share/Trash/files"',
    # captura de tela: a nossa (carinae-captura), não o Spectacle
    'spectacle': 'carinae-captura',
    'spectacle -r': 'carinae-captura regiao',
}
# os atalhos do KWin que o Comando usava -> o mesmo na Gravidade
KWIN = {
    'Window Quick Tile Left': 'xdotool key --clearmodifiers super+Left',
    'Window Quick Tile Right': 'xdotool key --clearmodifiers super+Right',
    'Window Maximize': 'xdotool key --clearmodifiers super+Up',
    'Show Desktop': 'aurora --enviar mesa',
    'Overview': 'aurora --enviar lancador',
}


def traduzir(cmd):
    if not carinae():
        return cmd
    if isinstance(cmd, (list, tuple)):
        s = cmd[2] if len(cmd) == 3 and list(cmd[:2]) == ['sh', '-c'] else ' '.join(cmd)
        novo = TABELA.get(s)
        return ['sh', '-c', novo] if novo else cmd
    return TABELA.get(cmd, cmd)


# brilho por software em todos os monitores (o mesmo da central de ajustes da Aurora)
def brilho():
    try:
        return max(0.3, min(1.0, float(open(os.path.join(CFG, 'brilho')).read().strip())))
    except (OSError, ValueError):
        return 1.0


def definir_brilho(v):
    v = max(0.3, min(1.0, v))
    try:
        luz = open(os.path.join(CFG, 'luz-noturna')).read().strip() == '1'
    except OSError:
        luz = False
    gama = '1.0:0.84:0.66' if luz else '1:1:1'
    os.makedirs(CFG, exist_ok=True)
    with open(os.path.join(CFG, 'brilho'), 'w') as f:
        f.write('%.2f\n' % v)
    subprocess.Popen(['sh', '-c', "for o in $(xrandr --query | awk '/ connected/{print $1}'); do "
                      "xrandr --output \"$o\" --gamma %s --brightness %.2f; done" % (gama, v)],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def nao_incomodar(ligar):
    os.makedirs(CFG, exist_ok=True)
    f = os.path.join(CFG, 'nao-incomodar')
    if ligar:
        open(f, 'w').close()
    elif os.path.exists(f):
        os.remove(f)
'''

BLOCO_COMANDO = '''
# CarinaeOS: na sessão CarinaeOS os comandos do KDE vão para as peças nossas (carinae_compat.py)
try:
    import carinae_compat as _CC
    _correr_kde = correr

    def correr(cmd):
        _correr_kde(_CC.traduzir(cmd))
except ImportError:
    pass

'''

BLOCO_ACOES = '''# CarinaeOS: na sessão CarinaeOS o que era do KDE vai para as peças nossas (carinae_compat.py)
try:
    import carinae_compat as _CC
    if _CC.carinae():
        _bg_kde = _bg

        def _bg(args, atraso=0.0):
            _bg_kde(_CC.traduzir(args), atraso)

        def _kwin(atalho, atraso=0.35):
            c = _CC.KWIN.get(atalho)
            if c:
                _bg_kde(['sh', '-c', c], atraso)

        brilho = _CC.brilho
        definir_brilho = _CC.definir_brilho
        nao_incomodar = _CC.nao_incomodar
except ImportError:
    pass


'''


def ajustar(F, marca, antes_de, bloco):
    try:
        s = open(F, encoding='utf-8').read()
    except OSError:
        print('  (não encontrei %s)' % F)
        return
    if marca in s:
        print('  %s já estava ajustado' % os.path.basename(F))
        return
    if antes_de not in s:
        print('  aviso: não encontrei onde ajustar %s' % os.path.basename(F))
        return
    n = s.replace(antes_de, bloco + antes_de, 1)
    try:
        compile(n, F, 'exec')
    except SyntaxError as e:
        print('  ERRO: o ajuste a %s não ficou válido (%s) — não mexi' % (os.path.basename(F), e))
        return
    shutil.copy2(F, F + '.antes-carinae-' + time.strftime('%Y%m%d-%H%M%S'))
    open(F, 'w', encoding='utf-8').write(n)
    print('  %s ajustado' % os.path.basename(F))


def corrigir_qml(F):
    """o Qt só aceita tamanhos de letra inteiros em pixelSize (12.5 impedia a janela de abrir)"""
    import re
    try:
        q = open(F, encoding='utf-8').read()
    except OSError:
        return
    n = re.sub(r'(pixelSize:\s*)(\d+)\.\d+', r'\1\2', q)
    if n != q:
        shutil.copy2(F, F + '.antes-carinae-' + time.strftime('%Y%m%d-%H%M%S'))
        open(F, 'w', encoding='utf-8').write(n)
        print('  Main.qml do Comando corrigido (tamanho de letra que impedia a janela de abrir)')


def pesquisa_sem_baloo(F):
    """A pesquisa de ficheiros do Comando usava o Baloo (o indexador do KDE): passa a usar o plocate."""
    try:
        s = open(F, encoding='utf-8').read()
    except OSError:
        return
    antes = """            if shutil.which('baloosearch6'):
                out = subprocess.run(['baloosearch6', '-l', '8', texto], capture_output=True, text=True,
                                     timeout=3).stdout
                achados = [l.strip() for l in out.splitlines() if l.strip().startswith('/')]"""
    depois = """            loc = shutil.which('plocate') or shutil.which('locate')
            if loc:
                # o índice do sistema (plocate): só o que está na pasta pessoal e não é escondido
                out = subprocess.run([loc, '-i', '-l', '400', texto], capture_output=True, text=True, timeout=3).stdout
                achados = [l for l in out.splitlines() if l.startswith(HOME + '/') and '/.' not in l[len(HOME):]][:8]
            elif shutil.which('baloosearch6'):
                out = subprocess.run(['baloosearch6', '-l', '8', texto], capture_output=True, text=True,
                                     timeout=3).stdout
                achados = [l.strip() for l in out.splitlines() if l.strip().startswith('/')]"""
    if depois in s:
        print('  pesquisa do Comando já usa o plocate')
        return
    if antes not in s:
        print('  aviso: não encontrei a pesquisa de ficheiros do Comando')
        return
    n = s.replace(antes, depois, 1)
    try:
        compile(n, F, 'exec')
    except SyntaxError as e:
        print('  ERRO na pesquisa do Comando (%s) — não mexi' % e)
        return
    shutil.copy2(F, F + '.antes-carinae-' + time.strftime('%Y%m%d-%H%M%S'))
    open(F, 'w', encoding='utf-8').write(n)
    print('  pesquisa do Comando passa a usar o plocate (sem o Baloo do KDE)')


if not os.path.isdir(PASTA):
    print('  (não encontrei o Comando em %s — nada a ajustar)' % PASTA)
    sys.exit(0)
with open(os.path.join(PASTA, 'carinae_compat.py'), 'w', encoding='utf-8') as f:
    f.write(COMPAT)
ajustar(os.path.join(PASTA, 'comando.py'), 'import carinae_compat as _CC', '\ndef kglobal(', BLOCO_COMANDO)
ajustar(os.path.join(PASTA, 'acoes.py'), 'import carinae_compat as _CC', 'A = []\n', BLOCO_ACOES)
corrigir_qml(os.path.join(PASTA, 'Main.qml'))
pesquisa_sem_baloo(os.path.join(PASTA, 'comando.py'))
