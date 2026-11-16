# CarinaeOS - Casa: traduz um painel do Home Assistant (Lovelace) para os cartões do Casa.
# Só a parte visual: aparelhos, automações e o resto continuam no Home Assistant.
# Entende os cartões do HA, os Mushroom e os mais usados da comunidade; os que não
# têm equivalente são contados e ficam de fora (o painel original não muda).
import re

LARGO = 4    # cartões que ocupam a linha inteira (títulos, chips)


def _ents(lista):
    r = []
    for x in lista or []:
        if isinstance(x, str):
            r.append(x)
        elif isinstance(x, dict) and isinstance(x.get('entity'), str):
            r.append(x['entity'])
    return r


def _dom(eid):
    return eid.split('.')[0] if eid else ''


def _largura(c, padrao=1):
    g = c.get('grid_options') or {}
    col = g.get('columns') or c.get('layout_options', {}).get('grid_columns')
    if isinstance(col, int):          # a grelha das secções tem 12 colunas
        return max(1, min(LARGO, round(col / 3)))
    if col == 'full':
        return LARGO
    return padrao


def _limpar_html(t):
    """Markdown do HA com HTML: fica o texto (o <center> vira alinhamento ao centro)."""
    centro = '<center>' in (t or '').lower()
    t = re.sub(r'<ha-icon[^>]*>(</ha-icon>)?', '', t or '', flags=re.I)
    t = re.sub(r'<br\s*/?>', '\n', t, flags=re.I)
    t = re.sub(r'</?(center|div|span|font|p|b|i|big|small)[^>]*>', '', t, flags=re.I)
    return t.strip(), centro


def cartao(c, n=None, ign=None):
    """Um cartão do HA -> lista de cartões do Casa (as pilhas e grelhas desfazem-se)."""
    if not isinstance(c, dict):
        return []
    t = str(c.get('type', '')).replace('custom:', '')
    tit = c.get('title') or c.get('name') or ''
    tit = tit if isinstance(tit, str) else ''
    ent = c.get('entity') if isinstance(c.get('entity'), str) else ''
    larg = _largura(c)
    C = lambda tipo, ents, titulo='', largura=larg, **k: [dict(tipo=tipo, titulo=titulo, ents=ents, largura=largura, **k)]  # noqa: E731

    if t in ('vertical-stack', 'horizontal-stack', 'grid', 'layout-card', 'stack-in-card', 'mod-card',
             'vertical-stack-in-card', 'swipe-card', 'expander-card'):
        r = []
        if tit and t != 'grid':
            r += C('texto', [], tit, LARGO, estilo='titulo')
        for x in c.get('cards') or ([c['card']] if isinstance(c.get('card'), dict) else []):
            r += cartao(x, n, ign)
        return r
    if t in ('conditional', 'state-switch', 'auto-entities') and isinstance(c.get('card'), dict):
        inner = dict(c['card'])
        if t == 'auto-entities' and not inner.get('entities'):
            inner['entities'] = [f.get('entity_id') for f in (c.get('filter') or {}).get('include', []) if isinstance(f, dict) and f.get('entity_id') and '*' not in f.get('entity_id')]
        return cartao(inner, n, ign)
    if t == 'heading':
        return C('texto', [], c.get('heading', ''), LARGO, estilo='titulo')
    if t in ('markdown',):
        txt, centro = _limpar_html(c.get('content', ''))
        if tit:
            txt = '## ' + tit + '\n' + txt
        return C('texto', [], txt, LARGO if centro else larg, estilo='markdown', alinhar='centro' if centro else '')
    if t == 'mushroom-title-card':
        txt = (c.get('title') or '') + ('\n' + c['subtitle'] if c.get('subtitle') else '')
        return C('texto', [], txt.strip(), LARGO, estilo='titulo', alinhar={'center': 'centro', 'end': 'direita'}.get(c.get('alignment'), ''))
    if t == 'mushroom-chips-card':
        ents = [x.get('entity') for x in c.get('chips', []) if isinstance(x, dict) and isinstance(x.get('entity'), str)]
        return C('chips', ents, '', LARGO, alinhar={'center': 'centro', 'end': 'direita'}.get(c.get('alignment'), '')) if ents else []
    if t == 'glance':
        ents = _ents(c.get('entities'))
        return C('chips', ents, tit, max(larg, 2), estilo='duas') if ents else []
    if t == 'entities':
        ents = _ents(c.get('entities'))
        return C('entidades', ents[:12], tit) if ents else []
    if t in ('light', 'mushroom-light-card') and ent:
        return C('luz', [ent], c.get('name', '') if isinstance(c.get('name'), str) else '')
    if t in ('thermostat', 'mushroom-climate-card', 'simple-thermostat', 'better-thermostat-ui-card') and ent:
        return C('clima', [ent], c.get('name', '') if isinstance(c.get('name'), str) else '')
    if t in ('media-control', 'mushroom-media-player-card', 'mini-media-player') and ent:
        return C('media', [ent], c.get('name', '') if isinstance(c.get('name'), str) else '')
    if t in ('picture-entity', 'picture-glance', 'webrtc-camera', 'advanced-camera-card', 'frigate-card'):
        cam = c.get('camera_image') or (ent if _dom(ent) == 'camera' else '')
        if cam:
            return C('camera', [cam], tit)
        if c.get('image'):
            return C('imagem', [], c['image'])
    if t == 'picture' and c.get('image'):
        return C('imagem', [], c['image'] if isinstance(c['image'], str) else '')
    if t in ('weather-forecast', 'mushroom-weather-card', 'clock-weather-card') and ent:
        return C('tempo', [ent])
    if t in ('sensor', 'mini-graph-card') and (ent or c.get('entities')):
        e = ent or (_ents(c.get('entities')) or [''])[0]
        return C('grafico', [e], c.get('name', '') if isinstance(c.get('name'), str) else '')
    if t in ('history-graph', 'statistics-graph', 'apexcharts-card'):
        return [x for e in _ents(c.get('entities') or c.get('series'))[:4] for x in C('grafico', [e])]
    if t == 'statistic' and ent:
        return C('sensor', [ent], tit)
    if t in ('gauge', 'dial-card') and ent:
        return C('medidor', [ent], tit, minimo=c.get('min', 0), maximo=c.get('max', 100))
    if t in ('mushroom-person-card',) and ent:
        return C('pessoa', [ent], tit, estilo='vertical' if c.get('layout') == 'vertical' else '')
    if t in ('mushroom-cover-card',) and ent:
        return C('estores', [ent], tit)
    if t in ('mushroom-number-card', 'mushroom-select-card') and ent:
        return C('numero', [ent], tit)
    if t == 'clock':
        return C('relogio', [], tit)
    if t == 'button' and ent:
        return C('botao_grande', [ent], tit if isinstance(c.get('name'), str) else '')
    if t in ('tile', 'entity', 'mushroom-entity-card', 'mushroom-template-card', 'mushroom-fan-card',
             'mushroom-lock-card', 'mushroom-alarm-control-panel-card', 'mushroom-vacuum-card', 'mushroom-humidifier-card',
             'button-card', 'alarm-panel', 'bubble-card', 'big-number-card') and ent:
        d = _dom(ent)
        nome = c.get('name') if isinstance(c.get('name'), str) and '{' not in c.get('name') and '[[' not in c.get('name') else ''
        if d == 'person':
            return C('pessoa', [ent], nome)
        if d == 'light' and t in ('tile', 'bubble-card'):
            return C('luz', [ent], nome)
        if d == 'media_player':
            return C('media', [ent], nome)
        if d == 'climate':
            return C('clima', [ent], nome)
        if d == 'cover':
            return C('estores', [ent], nome)
        if t in ('entity', 'big-number-card') and d in ('sensor', 'input_number', 'number'):
            return C('sensor', [ent], nome)
        vertical = c.get('vertical') is True or c.get('layout') == 'vertical'
        return C('botao', [ent], nome, estilo='vertical' if vertical else '')
    if t == 'mushroom-template-card' and c.get('primary'):
        return C('texto', [], c.get('primary', '') + ('\n' + c['secondary'] if c.get('secondary') else ''), larg, estilo='titulo')
    if ign is not None:
        ign.append(t or '?')
    return []


def vista(v):
    """Uma vista (separador) do HA -> {nome, cartoes} e os tipos que não deu para trazer."""
    ign = []
    cart = []
    for c in v.get('cards') or []:
        cart += cartao(c, ign=ign)
    for sec in v.get('sections') or []:          # vistas em secções (HA 2024+)
        for c in sec.get('cards') or []:
            cart += cartao(c, ign=ign)
    for b in v.get('badges') or []:              # os emblemas do topo viram chips
        e = b if isinstance(b, str) else (b.get('entity') if isinstance(b, dict) else None)
        if isinstance(e, str):
            if cart and cart[0]['tipo'] == 'chips' and cart[0].get('_emblemas'):
                cart[0]['ents'].append(e)
            else:
                cart.insert(0, dict(tipo='chips', titulo='', ents=[e], largura=LARGO, _emblemas=True))
    for c in cart:
        c.pop('_emblemas', None)
    nome = v.get('title') or v.get('path') or 'Painel'
    return {'nome': nome, 'cartoes': cart}, ign


def painel(cfg):
    """A configuração inteira de um painel do HA -> ([painéis do Casa], [tipos ignorados])."""
    res, ign = [], []
    for v in (cfg or {}).get('views') or []:
        if v.get('type') == 'panel' and len(v.get('cards') or []) == 1 and (v['cards'][0].get('type') in ('map', 'iframe')):
            ign.append(v['cards'][0].get('type'))
            continue
        p, i = vista(v)
        if p['cartoes']:
            res.append(p)
        ign += i
    return res, ign
