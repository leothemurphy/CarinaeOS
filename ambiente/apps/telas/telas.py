#!/usr/bin/env python3
# CarinaeOS — Telas: posição, resolução, frequência, rotação e tela principal (xrandr)
#   carinae-telas            abre a janela
#   carinae-telas --aplicar  repõe a configuração guardada para os monitores ligados (usado no arranque)
import json
import os
import re
import subprocess
import sys

CONFIG = os.path.join(os.environ.get('XDG_CONFIG_HOME') or os.path.expanduser('~/.config'),
                      'carinaeos', 'telas.json')
XRANDR = os.environ.get('CARINAE_XRANDR', 'xrandr')
ROTACOES = ('normal', 'left', 'inverted', 'right')


# ---------------------------------------------------------------- xrandr ----
def _nome_edid(hexa):
    try:
        b = bytes.fromhex(hexa)
    except ValueError:
        return ''
    for i in (54, 72, 90, 108):
        bloco = b[i:i + 18]
        if len(bloco) == 18 and bloco[0:3] == b'\0\0\0' and bloco[3] == 0xFC:
            return bloco[5:].split(b'\n')[0].decode('ascii', 'ignore').strip()
    return ''


def ler():
    """Lista de saídas ligadas (com modos) a partir de `xrandr --prop`."""
    try:
        txt = subprocess.run([XRANDR, '--prop'], capture_output=True, text=True, timeout=15).stdout
    except Exception:
        return []
    saidas, atual, edid = [], None, None
    cab = re.compile(r'^(\S+) (connected|disconnected)( primary)?(?: (\d+)x(\d+)\+(-?\d+)\+(-?\d+))?'
                     r'(?: (normal|left|inverted|right))?')
    for linha in txt.splitlines():
        m = cab.match(linha)
        if m:
            edid = None
            if m.group(2) != 'connected':
                atual = None
                continue
            atual = {
                'nome': m.group(1), 'principal': bool(m.group(3)),
                'ativo': m.group(4) is not None,
                'x': int(m.group(6) or 0), 'y': int(m.group(7) or 0),
                'rotacao': m.group(8) or 'normal',
                'modo': '', 'taxa': '', 'modos': [], 'monitor': '',
            }
            mm = re.search(r'(\d+)mm x (\d+)mm', linha)
            atual['mm'] = [int(mm.group(1)), int(mm.group(2))] if mm else [0, 0]
            saidas.append(atual)
            continue
        if atual is None:
            continue
        if edid is not None:
            if re.match(r'^\s+[0-9a-f]{32}$', linha):
                edid += linha.strip()
                continue
            atual['monitor'] = _nome_edid(edid)
            edid = None
        if re.match(r'^\s+EDID:\s*$', linha):
            edid = ''
            continue
        mm = re.match(r'^\s{2,3}(\d+x\d+i?)\s+(.*)$', linha)
        if mm and not linha.startswith('\t'):
            res, resto = mm.group(1), mm.group(2)
            taxas = []
            for t in re.finditer(r'(\d+\.\d+)([ *])?([ +])?', resto):
                v = t.group(1)
                if t.group(2) == '*':
                    atual['modo'], atual['taxa'] = res, v
                if t.group(3) == '+' or (t.group(2) == ' ' and resto[t.end() - 1:t.end()] == '+'):
                    atual.setdefault('preferido', res)
                if v not in taxas:
                    taxas.append(v)
            if '+' in resto and 'preferido' not in atual:
                atual['preferido'] = res
            existente = next((m for m in atual['modos'] if m['res'] == res), None)
            if existente:
                existente['taxas'] += [t for t in taxas if t not in existente['taxas']]
            else:
                atual['modos'].append({'res': res, 'taxas': taxas})
    for s in saidas:
        s.setdefault('preferido', s['modos'][0]['res'] if s['modos'] else '')
        if not s['modo']:
            s['modo'] = s['preferido']
            mod = next((m for m in s['modos'] if m['res'] == s['modo']), None)
            s['taxa'] = mod['taxas'][0] if mod and mod['taxas'] else ''
    return saidas


def tamanho(s):
    try:
        w, h = (int(v) for v in s['modo'].rstrip('i').split('x'))
    except ValueError:
        w, h = 1024, 768
    return (h, w) if s.get('rotacao') in ('left', 'right') else (w, h)


def comando(saidas):
    ativas = [s for s in saidas if s['ativo']]
    if not ativas:
        return None                      # nunca desligar todos os ecrãs
    x0 = min(s['x'] for s in ativas)
    y0 = min(s['y'] for s in ativas)
    cmd = [XRANDR]
    if not any(s['principal'] for s in ativas):
        ativas[0]['principal'] = True
    for s in saidas:
        cmd += ['--output', s['nome']]
        if not s['ativo']:
            cmd += ['--off']
            continue
        cmd += ['--mode', s['modo']]
        if s.get('taxa'):
            cmd += ['--rate', s['taxa']]
        cmd += ['--pos', '%dx%d' % (s['x'] - x0, s['y'] - y0), '--rotate', s.get('rotacao', 'normal')]
        if s['principal']:
            cmd += ['--primary']
    return cmd


def correr_xrandr(saidas):
    cmd = comando(saidas)
    if not cmd:
        return False, 'Tem de ficar pelo menos uma tela ligada.'
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    except Exception as e:
        return False, str(e)
    return r.returncode == 0, (r.stderr or r.stdout).strip()


def chave(saidas):
    return '+'.join(sorted(s['nome'] + ('=' + s['monitor'] if s.get('monitor') else '') for s in saidas))


def carregar():
    try:
        with open(CONFIG, encoding='utf-8') as f:
            return json.load(f)
    except Exception:
        return {}


def guardar(saidas):
    tudo = carregar()
    tudo[chave(saidas)] = [{k: s[k] for k in ('nome', 'ativo', 'principal', 'x', 'y', 'modo', 'taxa', 'rotacao')}
                           for s in saidas]
    os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
    tmp = CONFIG + '.tmp'
    with open(tmp, 'w', encoding='utf-8') as f:
        json.dump(tudo, f, indent=1, ensure_ascii=False)
    os.replace(tmp, CONFIG)


def aplicar_guardado():
    saidas = ler()
    if not saidas:
        return 1
    guardado = carregar().get(chave(saidas))
    if not guardado:
        return 0
    por_nome = {g['nome']: g for g in guardado}
    antes = [dict(x) for x in saidas]
    for s in saidas:
        g = por_nome.get(s['nome'])
        if not g:
            continue
        mod = next((m for m in s['modos'] if m['res'] == g.get('modo')), None)
        if g.get('ativo') and not mod:
            continue                      # o modo já não existe: deixa como está
        s.update({k: g[k] for k in ('ativo', 'principal', 'x', 'y', 'modo', 'rotacao') if k in g})
        s['taxa'] = g.get('taxa') if mod and g.get('taxa') in mod['taxas'] else (mod['taxas'][0] if mod else '')
    # já está tudo como guardado? então não se mexe nos monitores (o xrandr demora ~2 s com a NVIDIA)
    def chave_estado(x):
        try:
            taxa = round(float(x.get('taxa') or 0), 1)
        except ValueError:
            taxa = 0
        return (x['nome'], bool(x['ativo']), x['ativo'] and x['modo'], x['ativo'] and taxa, x['ativo'] and x['x'],
                x['ativo'] and x['y'], x['ativo'] and x.get('rotacao', 'normal'), x['ativo'] and bool(x['principal']))
    if [chave_estado(x) for x in antes] == [chave_estado(x) for x in saidas]:
        return 0
    ok, msg = correr_xrandr(saidas)
    if not ok:
        print('carinae-telas:', msg, file=sys.stderr)
    return 0 if ok else 1


# ------------------------------------------------------------------- GUI ----
def janela():
    sys.path.insert(0, os.environ.get('CARINAE_COMUM') or next((d for d in ('/usr/local/share/carinaeos/comum', '/usr/share/carinaeos/comum') if os.path.isdir(d)), '/usr/share/carinaeos/comum'))
    from base import iniciar
    from PySide6.QtCore import QObject, Property, Signal, Slot

    class Telas(QObject):
        mudou = Signal()

        def __init__(self):
            super().__init__()
            self._saidas = ler()
            self._anterior = None

        @Property('QVariantList', notify=mudou)
        def saidas(self):
            return self._saidas

        @Slot()
        def recarregar(self):
            self._saidas = ler()
            self.mudou.emit()

        @Slot('QVariantList', result=str)
        def aplicar(self, novas):
            novas = [dict(s) for s in novas]
            self._anterior = [dict(s) for s in ler()]
            ok, msg = correr_xrandr(novas)
            if not ok:
                return msg or 'O xrandr recusou esta configuração.'
            return ''

        @Slot()
        def manter(self):
            self._saidas = ler()
            guardar(self._saidas)
            self._anterior = None
            self.mudou.emit()

        @Slot()
        def reverter(self):
            if self._anterior:
                correr_xrandr(self._anterior)
            self._anterior = None
            self.recarregar()

    aqui = os.path.dirname(os.path.abspath(__file__))
    return iniciar('carinae-telas', 'Carinae Telas', 'preferences-desktop-display',
                   os.path.join(aqui, 'Main.qml'), {'telas': Telas})


if __name__ == '__main__':
    if '--aplicar' in sys.argv:
        sys.exit(aplicar_guardado())
    if '--listar' in sys.argv:
        print(json.dumps(ler(), indent=1, ensure_ascii=False))
        sys.exit(0)
    sys.exit(janela())
