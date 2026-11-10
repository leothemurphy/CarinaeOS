# CarinaeOS - ligacao ao Home Assistant (usada pela app Casa, pela Eta e pelo agente).
# A configuracao fica em ~/.config/carinaeos/casa.json (so o proprio usuario a pode ler).
import json
import os
import re
import unicodedata
import urllib.error
import urllib.request

CFG = os.path.join(os.environ.get('XDG_CONFIG_HOME', os.path.expanduser('~/.config')), 'carinaeos', 'casa.json')
DOMINIOS = ('light', 'switch', 'scene', 'script', 'fan', 'cover', 'climate', 'media_player', 'input_boolean',
            'automation', 'lock', 'vacuum', 'sensor', 'binary_sensor', 'button', 'weather', 'camera', 'input_number',
            'number', 'input_button', 'alarm_control_panel', 'humidifier', 'water_heater', 'person', 'select', 'input_select')
NOMES_DOMINIO = {'light': 'Luzes', 'switch': 'Interruptores', 'scene': 'Cenas', 'script': 'Rotinas', 'fan': 'Ventoinhas',
                 'cover': 'Estores e portões', 'climate': 'Clima', 'media_player': 'Som e TV', 'input_boolean': 'Interruptores',
                 'automation': 'Automações', 'lock': 'Fechaduras', 'vacuum': 'Aspiradores', 'sensor': 'Sensores',
                 'binary_sensor': 'Sensores', 'button': 'Botões', 'weather': 'Tempo', 'camera': 'Câmaras',
                 'input_number': 'Números', 'number': 'Números', 'input_button': 'Botões', 'alarm_control_panel': 'Alarme',
                 'humidifier': 'Humidificadores', 'water_heater': 'Esquentadores', 'person': 'Pessoas',
                 'select': 'Escolhas', 'input_select': 'Escolhas'}


def ler():
    try:
        with open(CFG, encoding='utf-8') as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def gravar(cfg):
    os.makedirs(os.path.dirname(CFG), exist_ok=True)
    tmp = CFG + '.tmp'
    with open(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), 'w', encoding='utf-8') as f:
        json.dump(cfg, f)
    os.replace(tmp, CFG)


def ligado(cfg=None):
    cfg = cfg if cfg is not None else ler()
    return bool(cfg.get('url') and cfg.get('token'))


def normalizar_url(url):
    url = (url or '').strip().rstrip('/')
    if url and not re.match(r'^https?://', url):
        url = 'http://' + url
    if url and ':' not in url.split('//', 1)[1].split('/')[0]:
        url += ':8123'
    return url


def pedido(cfg, caminho, dados=None, timeout=8):
    req = urllib.request.Request(cfg['url'].rstrip('/') + caminho,
                                 data=json.dumps(dados).encode() if dados is not None else None,
                                 headers={'Authorization': 'Bearer ' + cfg['token'], 'Content-Type': 'application/json'},
                                 method='POST' if dados is not None else 'GET')
    with urllib.request.urlopen(req, timeout=timeout) as r:
        corpo = r.read()
    return json.loads(corpo) if corpo else None


def conectar(url, token):
    """Testa e guarda. Devolve (ok, mensagem)."""
    cfg = ler()
    cfg.update(url=normalizar_url(url), token=(token or '').strip() or cfg.get('token', ''))
    try:
        info = pedido(cfg, '/api/config')
    except urllib.error.HTTPError as e:
        if e.code == 401:
            return False, 'O Home Assistant recusou o token. Crie um "token de acesso de longa duração" no seu perfil.'
        return False, 'O Home Assistant respondeu com o erro %s.' % e.code
    except Exception as e:
        return False, 'Não consegui chegar a %s (%s).' % (cfg['url'], getattr(e, 'reason', e))
    cfg['nome'] = info.get('location_name') or 'Casa'
    cfg['versao'] = info.get('version', '')
    gravar(cfg)
    return True, cfg['nome']


def entidades(cfg=None):
    cfg = cfg if cfg is not None else ler()
    estados = pedido(cfg, '/api/states', timeout=10) or []
    res = []
    for s in estados:
        eid = s.get('entity_id', '')
        dom = eid.split('.')[0]
        if dom not in DOMINIOS:
            continue
        at = s.get('attributes', {}) or {}
        e = dict(id=eid, dominio=dom, nome=at.get('friendly_name') or eid, estado=s.get('state', ''),
                 unidade=at.get('unit_of_measurement', ''), classe=at.get('device_class', ''),
                 brilho=round((at.get('brightness') or 0) * 100 / 255) if dom == 'light' else -1,
                 temperatura=at.get('current_temperature', at.get('temperature', '') if dom == 'weather' else ''),
                 alvo=at.get('temperature', '') if dom != 'weather' else '',
                 icone=at.get('icon', ''), humidade=at.get('humidity', at.get('current_humidity', '')),
                 titulo_media=at.get('media_title', ''), artista=at.get('media_artist', ''),
                 volume=round((at.get('volume_level') or 0) * 100), minimo=at.get('min', 0), maximo=at.get('max', 100),
                 passo=at.get('step', 1), opcoes=at.get('options', []), posicao=at.get('current_position', -1),
                 previsao=[dict(t=f.get('temperature'), m=f.get('templow'), c=f.get('condition', ''), d=f.get('datetime', ''))
                           for f in (at.get('forecast') or [])[:5]])
        res.append(e)
    res.sort(key=lambda e: (list(DOMINIOS).index(e['dominio']), e['nome'].lower()))
    return res


def servico(dom, nome, dados, cfg=None):
    cfg = cfg if cfg is not None else ler()
    return pedido(cfg, '/api/services/%s/%s' % (dom, nome), dados)


def alternar(eid, ligar=None, cfg=None):
    dom = eid.split('.')[0]
    if dom in ('scene', 'script'):
        return servico(dom, 'turn_on', {'entity_id': eid}, cfg)
    if dom == 'automation':
        return servico(dom, 'trigger', {'entity_id': eid}, cfg)
    if dom == 'button':
        return servico(dom, 'press', {'entity_id': eid}, cfg)
    if dom == 'lock':
        return servico(dom, 'unlock' if ligar else 'lock', {'entity_id': eid}, cfg)
    if dom == 'cover':
        return servico(dom, 'open_cover' if ligar else 'close_cover' if ligar is False else 'toggle', {'entity_id': eid}, cfg)
    if dom == 'media_player':
        return servico(dom, 'media_play_pause', {'entity_id': eid}, cfg)
    acao = 'toggle' if ligar is None else ('turn_on' if ligar else 'turn_off')
    return servico('homeassistant' if dom == 'input_boolean' else dom, acao, {'entity_id': eid}, cfg)


def brilho(eid, pct, cfg=None):
    return servico('light', 'turn_on', {'entity_id': eid, 'brightness_pct': int(pct)}, cfg)


def temperatura(eid, graus, cfg=None):
    return servico('climate', 'set_temperature', {'entity_id': eid, 'temperature': float(graus)}, cfg)


def _s(t):
    t = unicodedata.normalize('NFD', (t or '').lower())
    return ''.join(c for c in t if unicodedata.category(c) != 'Mn')


def procurar(texto, ents):
    """Entidade cujo nome melhor casa com o texto falado ("luz da sala" -> light.sala)."""
    s = _s(texto)
    palavras = set(re.findall(r'\w{3,}', s)) - {'luz', 'luzes', 'liga', 'ligar', 'desliga', 'desligar', 'acende',
                                                   'acender', 'apaga', 'apagar', 'cena', 'ativa', 'ativar', 'abre', 'fecha',
                                                   'por', 'favor', 'das', 'dos', 'para', 'com', 'qual', 'esta', 'temperatura'}
    quer_luz = bool(re.search(r'\b(luz|luzes|lampada|candeeiro|acende|apaga)\b', s))
    quer_cena = bool(re.search(r'\b(cena|modo|rotina)\b', s))
    melhor, pontos = None, 0
    for e in ents:
        nome = _s(e['nome'])
        ws = set(re.findall(r'\w{3,}', nome))
        p = len(palavras & ws) * 3
        if nome and nome in s:
            p += 6
        if p == 0:
            continue
        if quer_luz and e['dominio'] == 'light':
            p += 2
        if quer_cena and e['dominio'] in ('scene', 'script'):
            p += 2
        if e['dominio'] in ('sensor', 'binary_sensor') and not re.search(r'\b(temperatura|humidade|umidade|quanto|qual|esta)\b', s):
            p -= 2
        if p > pontos:
            melhor, pontos = e, p
    return melhor if pontos >= 3 else None


def historico(eid, horas=24, cfg=None):
    """Valores numericos de um sensor nas ultimas horas: [(segundos desde o inicio, valor)]."""
    import datetime
    cfg = cfg if cfg is not None else ler()
    inicio = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(hours=horas)).strftime('%Y-%m-%dT%H:%M:%S+00:00')
    dados = pedido(cfg, '/api/history/period/%s?filter_entity_id=%s&minimal_response&no_attributes' % (inicio, eid), timeout=15) or []
    pontos = []
    t0 = None
    for s in (dados[0] if dados else []):
        try:
            v = float(s.get('state'))
            t = datetime.datetime.fromisoformat(s.get('last_changed').replace('Z', '+00:00')).timestamp()
        except (TypeError, ValueError, AttributeError):
            continue
        t0 = t0 or t
        pontos.append((t - t0, v))
    return pontos


def imagem_camera(eid, destino, cfg=None):
    cfg = cfg if cfg is not None else ler()
    req = urllib.request.Request(cfg['url'].rstrip('/') + '/api/camera_proxy/' + eid,
                                 headers={'Authorization': 'Bearer ' + cfg['token']})
    with urllib.request.urlopen(req, timeout=10) as r, open(destino + '.parte', 'wb') as f:
        f.write(r.read())
    os.replace(destino + '.parte', destino)
    return destino


def valor(eid, v, cfg=None):
    dom = eid.split('.')[0]
    if dom in ('input_number', 'number'):
        return servico(dom, 'set_value', {'entity_id': eid, 'value': float(v)}, cfg)
    if dom in ('select', 'input_select'):
        return servico(dom, 'select_option', {'entity_id': eid, 'option': v}, cfg)
    if dom == 'media_player':
        return servico(dom, 'volume_set', {'entity_id': eid, 'volume_level': float(v) / 100}, cfg)
    if dom == 'cover':
        return servico(dom, 'set_cover_position', {'entity_id': eid, 'position': int(float(v))}, cfg)
    raise ValueError(dom)


def media(eid, acao, cfg=None):
    return servico('media_player', {'anterior': 'media_previous_track', 'seguinte': 'media_next_track',
                                    'pausa': 'media_play_pause'}[acao], {'entity_id': eid}, cfg)


def parar_estore(eid, cfg=None):
    return servico('cover', 'stop_cover', {'entity_id': eid}, cfg)
