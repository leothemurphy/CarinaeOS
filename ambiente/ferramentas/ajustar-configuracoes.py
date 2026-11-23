#!/usr/bin/env python3
# CarinaeOS — liga o app Configurações às peças do ambiente próprio (idempotente; guarda cópia)
#   - "Telas" abre o carinae-telas (em vez do kcm_kscreen do KDE)
#   - "Feito a partir de" diz CarinaeOS (Gravidade + Aurora) quando é essa a sessão
#   - "Placa gráfica" mostra todas as placas
#   - Dock: os modelos novos (Órbita, Vidro, Windows 11), a animação à parte; no CarinaeOS o tamanho
#     e os separadores vão para a Dock nova (e a posição, que ela ainda não tem, fica escondida)
import os
import shutil
import sys
import time

PASTA = sys.argv[1] if len(sys.argv) > 1 else '/usr/share/carinaeos/configuracoes'
ESTILOS = "('fluent', 'simples', 'icones', 'orbita', 'glass', 'windows')"
ANIMS = "('', 'luz', 'orbita', 'onda', 'inclinar', 'nenhuma')"


def ajustar(F, trocas, extra=None):
    try:
        s = open(F, encoding='utf-8').read()
    except OSError:
        print('  (não encontrei %s — nada a ajustar)' % F)
        return
    orig = s
    for a, b in trocas:
        if b in s:
            continue
        if a in s:
            s = s.replace(a, b, 1)
        else:
            print('  aviso: não encontrei um trecho a ajustar em', os.path.basename(F))
    if extra:
        s = extra(s)
    if s != orig and F.endswith('.py'):
        try:
            compile(s, F, 'exec')
        except SyntaxError as e:
            print('  ERRO: o ajuste a %s não ficou válido (%s) — não mexi no ficheiro' % (os.path.basename(F), e))
            return
    if s != orig:
        shutil.copy2(F, F + '.antes-carinae-' + time.strftime('%Y%m%d-%H%M%S'))
        open(F, 'w', encoding='utf-8').write(s)
        print('  %s ajustado' % os.path.basename(F))
    else:
        print('  %s já estava ajustado' % os.path.basename(F))


TROCAS_PY = [
    ("""            if s[0] == ident and s[3]:
                bg(['kcmshell6', s[3]])""",
     """            if s[0] == ident and s[0] == 'ecras' and shutil.which('carinae-telas'):
                bg(['carinae-telas'])
            elif s[0] == ident and s[3]:
                bg(['kcmshell6', s[3]])"""),
    ("""grep -iE 'vga|3d|display' | head -1 | cut -d: -f3"])
    info['grafica'] = gpu.strip() or '—'""",
     """grep -iE 'vga|3d|display' | cut -d: -f3"])
    info['grafica'] = ' + '.join(l.strip() for l in gpu.splitlines() if l.strip()) or '—'"""),
    # Dock: os modelos novos, a animação à parte e, no CarinaeOS, o tamanho e os separadores
    ("""                d['estilo'] = j.get('estilo') if j.get('estilo') in ('fluent', 'simples', 'icones') else 'fluent'""",
     """                d['estilo'] = j.get('estilo') if j.get('estilo') in %s else 'fluent'
                d['animacao'] = j.get('animacao') if j.get('animacao') in %s else ''
                d['carinae'] = os.environ.get('XDG_CURRENT_DESKTOP', '').startswith('CarinaeOS')
                if d['carinae']:
                    try:
                        dj = json.load(open(os.path.join(HOME, '.config/carinaeos/dock.json'), encoding='utf-8'))
                        for k in ('iconSize', 'separatorWidth', 'separatorColor'):
                            if k in dj:
                                d[k] = dj[k]
                        for k in ('iconSize', 'separatorWidth', 'separatorColor'):
                            if k in j:
                                d[k] = j[k]
                    except (OSError, ValueError):
                        pass""" % (ESTILOS, ANIMS)),
    ("""        if chave != 'estilo' or valor not in ('fluent', 'simples', 'icones'):
            return""",
     """        if not ((chave == 'estilo' and valor in %s) or (chave == 'animacao' and valor in %s)):
            return""" % (ESTILOS, ANIMS)),
    ("""    def definirDock(self, chave, valor):
        if chave == 'posicao':""",
     """    def definirDock(self, chave, valor):
        if os.environ.get('XDG_CURRENT_DESKTOP', '').startswith('CarinaeOS') and chave in ('iconSize', 'separatorWidth', 'separatorColor'):
            # a Dock do CarinaeOS (Aurora) lê ~/.config/carinaeos-dock.json
            try:
                j = json.load(open(DOCK_JSON, encoding='utf-8'))
            except (OSError, ValueError):
                j = {}
            j[chave] = {'iconSize': int, 'separatorWidth': int}.get(chave, str)(valor)
            tmp = DOCK_JSON + '.tmp'
            with open(tmp, 'w', encoding='utf-8') as f:
                json.dump(j, f)
            os.replace(tmp, DOCK_JSON)
            self._aviso('Dock atualizada ✓')
            return
        if chave == 'posicao':"""),
]

TROCAS_QML = [
    # textos dos cartões (para quem já tinha a primeira versão)
    ('["fluent", "Padrão", "Holofote que desliza e o ícone sobe"]', '["fluent", "Padrão", "Holofote que desliza"]'),
    ('["glass", "Vidro", "O ícone inclina-se para o mouse"]', '["glass", "Vidro", "O ícone inclina para o mouse"]'),
    ('["windows", "Windows 11", "Barra inteira, Iniciar e Pesquisa ao centro"]', '["windows", "Windows 11", "Barra inteira, como no Windows"]'),
    ("""                                    ["fluent", "Padrão", "O ícone cresce e salta ao abrir"],
                                    ["simples", "Sem efeitos", "O ícone só acende ao passar o mouse"],
                                    ["icones", "Só ícones", "Sem o fundo da Dock"]""",
     """                                    ["fluent", "Padrão", "Holofote que desliza"],
                                    ["simples", "Sem efeitos", "O ícone só acende ao passar o mouse"],
                                    ["icones", "Só ícones", "Sem fundo; ondas como um sonar"],
                                    ["orbita", "Órbita", "Um anel gira à volta do ícone"],
                                    ["glass", "Vidro", "O ícone inclina para o mouse"],
                                    ["windows", "Windows 11", "Barra inteira, como no Windows"]"""),
    ("""                Grupo {
                    visible: janela.pagina === "dock"
                    titulo: "Tamanho\"""",
     """                Grupo {
                    visible: janela.pagina === "dock" && janela.e.estilo !== "windows"
                    titulo: "Animação ao passar o mouse"
                    Item {
                        width: parent.width; height: 64
                        Flow {
                            x: 14; width: parent.width - 28
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8
                            Repeater {
                                model: [["", "A do modelo"], ["luz", "Holofote"], ["orbita", "Órbita"], ["onda", "Ondas"], ["inclinar", "Inclinação 3D"], ["nenhuma", "Nenhuma"]]
                                delegate: Botao {
                                    required property var modelData
                                    texto: modelData[1]
                                    principal: (janela.e.animacao || "") === modelData[0]
                                    onCarregado: ajustes.definirModeloDock("animacao", modelData[0])
                                }
                            }
                        }
                    }
                }
                Grupo {
                    visible: janela.pagina === "dock"
                    titulo: "Tamanho\""""),
    ("""                Grupo {
                    visible: janela.pagina === "dock"
                    titulo: "Posição\"""",
     """                Grupo {
                    visible: janela.pagina === "dock" && !janela.e.carinae
                    titulo: "Posição\""""),
]


BLOCO_BASE = """    if os.environ.get('XDG_CURRENT_DESKTOP', '').startswith('CarinaeOS'):
        info['base'] = 'Debian %s · CarinaeOS (Gravidade + Aurora)' % (deb or '13')
    else:
        info['base'] = 'Debian %s · KDE Plasma %s' % (deb or '13', pl or '6')
"""


def reparar_base(s):
    """deixa o "Feito a partir de" sempre no mesmo bloco limpo (uma versão antiga deste script
    encaixava um bloco dentro do outro e o Configurações deixava de abrir)"""
    import re
    return re.sub(r"(    pl = cmd\(\['plasmashell', '--version'\]\)[^\n]*\n)(?:.*\n)*?(?=    info\['nucleo'\])",
                  lambda m: m.group(1) + BLOCO_BASE, s, count=1)


def mais_py(s):
    s = reparar_base(s)
    if 'import shutil' not in s:
        s = s.replace('import os\n', 'import os\nimport shutil\n', 1)
    return s


ajustar(os.path.join(PASTA, 'configuracoes.py'), TROCAS_PY, mais_py)
ajustar(os.path.join(PASTA, 'Main.qml'), TROCAS_QML)
