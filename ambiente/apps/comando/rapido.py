#!/usr/bin/python3
# CarinaeOS - Pesquisa (Ctrl+Espaço): respostas rápidas em cartões pequenos.
#   Sem internet: a hora (daqui ou de qualquer cidade ou país) e os dados dos países (paises.json).
#   Com internet, só quando o texto tem a forma certa, e guardado para não repetir:
#     moedas (Frankfurter), criptomoedas (CoinGecko), CEP (ViaCEP), código postal de Portugal (GEO API PT),
#     endereços (Photon, do OpenStreetMap; Nominatim se falhar) e próximos jogos de times (dados da ESPN).
# local(texto) -> cartões na hora; rede(texto) -> função que busca o cartão (ou None se não for nada disto).
import json
import os
import re
import threading
import time
import unicodedata
import urllib.parse
import urllib.request
from datetime import datetime, timezone

try:
    from zoneinfo import ZoneInfo, available_timezones
except ImportError:  # pragma: no cover
    ZoneInfo = None

AQUI = os.path.dirname(os.path.abspath(__file__))
CACHE = os.path.join(os.path.expanduser('~'), '.cache/carinaeos/pesquisa')
UA = 'CarinaeOS-Pesquisa/1.0 (+https://github.com/leothemurphy/CarinaeOS)'
DIAS = ['segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado', 'domingo']
DIAS_CURTOS = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom']
MESES = ['janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho', 'agosto', 'setembro', 'outubro',
         'novembro', 'dezembro']


def sem_acentos(t):
    return ''.join(c for c in unicodedata.normalize('NFD', t) if unicodedata.category(c) != 'Mn').lower().strip()


def numero(v, casas=2):
    """1234.5 -> '1.234,50' (como no Brasil)."""
    s = ('{:,.%df}' % casas).format(v)
    return s.replace(',', '§').replace('.', ',').replace('§', '.')


def _get(url, timeout=6, cabecalhos=None):
    h = {'User-Agent': UA, 'Accept': 'application/json'}
    h.update(cabecalhos or {})
    with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=timeout) as f:
        return json.load(f)


_mem = {}
_trava = threading.Lock()


def guardado(chave, segundos, fn):
    """o resultado de fn(), guardado na memória por uns segundos (a Pesquisa fica aberta em segundo plano)."""
    with _trava:
        v = _mem.get(chave)
        if v and v[0] > time.time():
            return v[1]
    r = fn()
    with _trava:
        _mem[chave] = (time.time() + segundos, r)
    return r


def cartao(modelo, grande, linha1='', linha2='', linhas=None, emoji='', url='', copiar='', imagem=''):
    return dict(modelo=modelo, grande=grande, linha1=linha1, linha2=linha2, linhas=linhas or [], emoji=emoji,
                url=url, copiar=copiar or grande, imagem=imagem)


# ==== hora ===================================================================================
CIDADES = {
    'lisboa': 'Europe/Lisbon', 'porto': 'Europe/Lisbon', 'coimbra': 'Europe/Lisbon', 'braga': 'Europe/Lisbon',
    'faro': 'Europe/Lisbon', 'acores': 'Atlantic/Azores', 'ponta delgada': 'Atlantic/Azores',
    'madeira': 'Atlantic/Madeira', 'funchal': 'Atlantic/Madeira',
    'sao paulo': 'America/Sao_Paulo', 'rio de janeiro': 'America/Sao_Paulo', 'rio': 'America/Sao_Paulo',
    'brasilia': 'America/Sao_Paulo', 'belo horizonte': 'America/Sao_Paulo', 'curitiba': 'America/Sao_Paulo',
    'porto alegre': 'America/Sao_Paulo', 'florianopolis': 'America/Sao_Paulo', 'goiania': 'America/Sao_Paulo',
    'salvador': 'America/Bahia', 'recife': 'America/Recife', 'fortaleza': 'America/Fortaleza',
    'natal': 'America/Fortaleza', 'joao pessoa': 'America/Fortaleza', 'maceio': 'America/Maceio',
    'aracaju': 'America/Maceio', 'sao luis': 'America/Fortaleza', 'teresina': 'America/Fortaleza',
    'belem': 'America/Belem', 'macapa': 'America/Belem', 'palmas': 'America/Araguaina',
    'manaus': 'America/Manaus', 'boa vista': 'America/Boa_Vista', 'porto velho': 'America/Porto_Velho',
    'cuiaba': 'America/Cuiaba', 'campo grande': 'America/Campo_Grande', 'rio branco': 'America/Rio_Branco',
    'fernando de noronha': 'America/Noronha', 'noronha': 'America/Noronha',
    'nova york': 'America/New_York', 'nova iorque': 'America/New_York', 'washington': 'America/New_York',
    'boston': 'America/New_York', 'miami': 'America/New_York', 'orlando': 'America/New_York',
    'chicago': 'America/Chicago', 'texas': 'America/Chicago', 'houston': 'America/Chicago',
    'denver': 'America/Denver', 'los angeles': 'America/Los_Angeles', 'sao francisco': 'America/Los_Angeles',
    'las vegas': 'America/Los_Angeles', 'seattle': 'America/Los_Angeles', 'california': 'America/Los_Angeles',
    'honolulu': 'Pacific/Honolulu', 'havai': 'Pacific/Honolulu', 'anchorage': 'America/Anchorage',
    'toronto': 'America/Toronto', 'montreal': 'America/Toronto', 'vancouver': 'America/Vancouver',
    'cidade do mexico': 'America/Mexico_City', 'cancun': 'America/Cancun', 'buenos aires': 'America/Argentina/Buenos_Aires',
    'santiago': 'America/Santiago', 'lima': 'America/Lima', 'bogota': 'America/Bogota', 'caracas': 'America/Caracas',
    'montevideu': 'America/Montevideo', 'assuncao': 'America/Asuncion', 'la paz': 'America/La_Paz',
    'quito': 'America/Guayaquil', 'havana': 'America/Havana', 'panama': 'America/Panama',
    'londres': 'Europe/London', 'edimburgo': 'Europe/London', 'dublin': 'Europe/Dublin', 'paris': 'Europe/Paris',
    'madri': 'Europe/Madrid', 'madrid': 'Europe/Madrid', 'barcelona': 'Europe/Madrid', 'canarias': 'Atlantic/Canary',
    'roma': 'Europe/Rome', 'milao': 'Europe/Rome', 'berlim': 'Europe/Berlin', 'munique': 'Europe/Berlin',
    'amsterda': 'Europe/Amsterdam', 'amsterdam': 'Europe/Amsterdam', 'bruxelas': 'Europe/Brussels',
    'zurique': 'Europe/Zurich', 'genebra': 'Europe/Zurich', 'viena': 'Europe/Vienna', 'praga': 'Europe/Prague',
    'varsovia': 'Europe/Warsaw', 'atenas': 'Europe/Athens', 'helsinque': 'Europe/Helsinki',
    'estocolmo': 'Europe/Stockholm', 'oslo': 'Europe/Oslo', 'copenhague': 'Europe/Copenhagen',
    'kiev': 'Europe/Kyiv', 'moscou': 'Europe/Moscow', 'istambul': 'Europe/Istanbul', 'cairo': 'Africa/Cairo',
    'joanesburgo': 'Africa/Johannesburg', 'cidade do cabo': 'Africa/Johannesburg', 'luanda': 'Africa/Luanda',
    'maputo': 'Africa/Maputo', 'praia': 'Atlantic/Cape_Verde', 'cabo verde': 'Atlantic/Cape_Verde',
    'dubai': 'Asia/Dubai', 'abu dhabi': 'Asia/Dubai', 'doha': 'Asia/Qatar', 'telavive': 'Asia/Jerusalem',
    'tel aviv': 'Asia/Jerusalem', 'jerusalem': 'Asia/Jerusalem', 'nova delhi': 'Asia/Kolkata',
    'mumbai': 'Asia/Kolkata', 'bangcoc': 'Asia/Bangkok', 'jacarta': 'Asia/Jakarta', 'bali': 'Asia/Makassar',
    'singapura': 'Asia/Singapore', 'hong kong': 'Asia/Hong_Kong', 'pequim': 'Asia/Shanghai',
    'xangai': 'Asia/Shanghai', 'taipe': 'Asia/Taipei', 'seul': 'Asia/Seoul', 'toquio': 'Asia/Tokyo',
    'osaka': 'Asia/Tokyo', 'manila': 'Asia/Manila', 'macau': 'Asia/Macau', 'timor': 'Asia/Dili',
    'dili': 'Asia/Dili', 'sydney': 'Australia/Sydney', 'melbourne': 'Australia/Melbourne',
    'perth': 'Australia/Perth', 'auckland': 'Pacific/Auckland',
}

_paises = None
_zonas = None


def paises():
    global _paises
    if _paises is None:
        try:
            _paises = json.load(open(os.path.join(AQUI, 'paises.json'), encoding='utf-8'))
        except (OSError, ValueError):
            _paises = []
    return _paises


def _zonas_iana():
    global _zonas
    if _zonas is None:
        _zonas = {}
        try:
            for z in available_timezones():
                if '/' in z and not z.startswith(('Etc/', 'SystemV/', 'US/')):
                    _zonas.setdefault(sem_acentos(z.rsplit('/', 1)[1].replace('_', ' ')), z)
        except Exception:
            pass
    return _zonas


def zona_de(nome):
    """'tóquio' -> ('Tóquio', 'Asia/Tokyo'); também países e capitais."""
    n = sem_acentos(nome)
    n = re.sub(r'^(o|a|os|as)\s+', '', n)
    if n in CIDADES:
        return _titulo(nome), CIDADES[n]
    for p in paises():
        if n in p['busca'] and p['fuso']:
            return p['nome'], p['fuso']
    for p in paises():
        if p['fuso'] and any(sem_acentos(c) == n for c in p['capital']):
            return p['capital'][0] + ' · ' + p['nome'], p['fuso']
    z = _zonas_iana().get(n)
    if z:
        return _titulo(nome), z
    return None


def _titulo(nome):
    pequenas = {'de', 'do', 'da', 'dos', 'das', 'e'}
    return ' '.join(p if p in pequenas and i else p[:1].upper() + p[1:] for i, p in enumerate(nome.strip().lower().split()))


def _diferenca(agora_la, agora_aqui):
    d = (agora_la.utcoffset() - agora_aqui.utcoffset()).total_seconds() / 3600
    if abs(d) < 0.01:
        return 'mesma hora que aqui'
    h = ('%+.1f' % d).rstrip('0').rstrip('.').replace('.', ',')
    return '%s h em relação a você' % h


def cartao_hora(rotulo, zona):
    aqui = datetime.now().astimezone()
    la = datetime.now(ZoneInfo(zona)) if zona else aqui
    data = '%s, %d de %s' % (DIAS[la.weekday()], la.day, MESES[la.month - 1])
    sub = data + ' · ' + (_diferenca(la, aqui) if zona else 'fuso ' + (aqui.tzname() or ''))
    return cartao('hora', la.strftime('%H:%M'), rotulo, sub, emoji='🕒', copiar=la.strftime('%H:%M'))


def hora(texto):
    original = re.sub(r'[?!.]+$', '', texto.strip()).strip()
    t = sem_acentos(original)
    if re.fullmatch(r'(que )?(horas?|hora atual|hora agora|horas agora)( (sao|e|agora))?( agora)?', t):
        aqui = datetime.now().astimezone()
        nome = ''
        try:
            nome = os.path.realpath('/etc/localtime').split('zoneinfo/', 1)[1].rsplit('/', 1)[1].replace('_', ' ')
        except (IndexError, OSError):
            pass
        return cartao_hora('Agora' + (' · ' + {'Lisbon': 'Lisboa', 'Sao Paulo': 'São Paulo'}.get(nome, nome) if nome else ''), None) \
            if aqui else None
    m = re.fullmatch(r'(?:que )?(?:horas?|fuso(?: horario)?)(?: sao| e)?(?: agora)?\s+(?:em|no|na|nos|nas|de|do|da|dos|das)\s+(.+)', t) \
        or re.fullmatch(r'(.+?)\s+(?:horas?|hora atual|fuso(?: horario)?)', t)
    if not m:
        return None
    # o nome como foi escrito (com os acentos): sem_acentos não muda o comprimento do texto
    nome = original[m.start(1):m.end(1)] if len(original) == len(t) else m.group(1)
    z = zona_de(nome)
    return cartao_hora(z[0], z[1]) if z else None


# ==== países =================================================================================
def pais(texto):
    t = sem_acentos(texto)
    t = re.sub(r'^(pais|dados (do|da|de|dos|das)|sobre (o|a|os|as))\s+', '', t).strip()
    if len(t) < 3:
        return None
    p = next((x for x in paises() if t in x['busca']), None)
    if not p:
        return None
    linhas = []
    if p['capital']:
        linhas.append(['Capital', ', '.join(p['capital'])])
    if p.get('populacao'):
        v = p['populacao']
        txt = (numero(v / 1e6, 1) + ' milhões') if v >= 1e6 else numero(v, 0)
        linhas.append(['População', txt + (' (%s)' % p['ano'] if p.get('ano') else '')])
    if p.get('area'):
        linhas.append(['Área', numero(p['area'], 0) + ' km²'])
    if p['moedas']:
        linhas.append(['Moeda', ', '.join(('%s (%s)' % (c, s)) if s else c for c, s in p['moedas'])])
    if p['idiomas']:
        linhas.append(['Idioma' + ('s' if len(p['idiomas']) > 1 else ''), ', '.join(p['idiomas'][:3])])
    if p['ddi']:
        linhas.append(['DDI', p['ddi']])
    if p['fuso'] and ZoneInfo:
        h = datetime.now(ZoneInfo(p['fuso'])).strftime('%H:%M')
        linhas.append(['Hora', h + (' (na capital; %d fusos)' % p['nfusos'] if p['nfusos'] > 1 else '')])
    regiao = p['regiao'] + (' · ' + p['sub'] if p['sub'] else '')
    url = 'https://pt.wikipedia.org/wiki/' + urllib.parse.quote(p['nome'].replace(' ', '_'))
    return cartao('pais', p['nome'], p['oficial'] if p['oficial'] != p['nome'] else regiao,
                  regiao if p['oficial'] != p['nome'] else '', linhas, p['bandeira'], url, p['nome'])


def local(texto):
    r = []
    for f in (hora, pais):
        try:
            c = f(texto)
        except Exception:
            c = None
        if c:
            r.append(c)
    return r


# ==== moedas e criptomoedas ===================================================================
FIAT = {
    'brl': ['real', 'reais', 'brl', 'r$'], 'eur': ['euro', 'euros', 'eur', '€'],
    'usd': ['dolar', 'dolares', 'usd', 'us$', '$', 'dolar americano', 'dolares americanos'],
    'gbp': ['libra', 'libras', 'gbp', '£', 'libra esterlina', 'libras esterlinas'],
    'jpy': ['iene', 'ienes', 'jpy', 'yen'], 'chf': ['franco suico', 'francos suicos', 'chf'],
    'cad': ['dolar canadense', 'dolares canadenses', 'cad'], 'aud': ['dolar australiano', 'dolares australianos', 'aud'],
    'cny': ['yuan', 'renminbi', 'cny'], 'ars': ['peso argentino', 'pesos argentinos', 'ars'],
    'mxn': ['peso mexicano', 'pesos mexicanos', 'mxn'], 'clp': ['peso chileno', 'pesos chilenos', 'clp'],
    'cop': ['peso colombiano', 'pesos colombianos', 'cop'], 'uyu': ['peso uruguaio', 'pesos uruguaios', 'uyu'],
    'pyg': ['guarani', 'guaranis', 'pyg'], 'aoa': ['kwanza', 'kwanzas', 'aoa'], 'mzn': ['metical', 'meticais', 'mzn'],
    'cve': ['escudo cabo-verdiano', 'escudos cabo-verdianos', 'cve'], 'inr': ['rupia', 'rupias', 'inr'],
    'krw': ['won', 'krw'], 'try': ['lira turca', 'liras turcas', 'try'], 'sek': ['coroa sueca', 'coroas suecas', 'sek'],
    'nok': ['coroa norueguesa', 'coroas norueguesas', 'nok'], 'dkk': ['coroa dinamarquesa', 'dkk'],
    'pln': ['zloty', 'pln'], 'zar': ['rand', 'zar'], 'aed': ['dirham', 'aed'],
}
CRIPTO = {
    'bitcoin': ['bitcoin', 'bitcoins', 'btc', '₿'], 'ethereum': ['ethereum', 'ether', 'eth'],
    'solana': ['solana', 'sol'], 'ripple': ['xrp', 'ripple'], 'dogecoin': ['dogecoin', 'doge'],
    'litecoin': ['litecoin', 'ltc'], 'cardano': ['cardano', 'ada'], 'tether': ['tether', 'usdt'],
    'binancecoin': ['bnb'], 'tron': ['tron', 'trx'], 'polkadot': ['polkadot', 'dot'], 'usd-coin': ['usdc'],
}
CRIPTO_SIGLA = {'bitcoin': 'BTC', 'ethereum': 'ETH', 'solana': 'SOL', 'ripple': 'XRP', 'dogecoin': 'DOGE',
                'litecoin': 'LTC', 'cardano': 'ADA', 'tether': 'USDT', 'binancecoin': 'BNB', 'tron': 'TRX',
                'polkadot': 'DOT', 'usd-coin': 'USDC'}
# sozinhas (sem um valor), estas palavras não chegam para mostrar o cartão (são palavras comuns)
AMBIGUAS = {'real', 'sol', 'ada', 'dot', 'libra', 'won', 'rand', '$', 'rupia', 'guarani', 'escudo'}
SIMBOLO = {'brl': 'R$', 'eur': '€', 'usd': 'US$', 'gbp': '£', 'jpy': '¥', 'cny': 'CN¥', 'chf': 'CHF', 'cad': 'C$',
           'aud': 'A$'}
_ALIAS = {}
for _c, _l in FIAT.items():
    for _a in _l:
        _ALIAS[_a] = ('fiat', _c)
for _c, _l in CRIPTO.items():
    for _a in _l:
        _ALIAS[_a] = ('cripto', _c)


def _valor(s):
    s = s.strip()
    if not s:
        return None
    if ',' in s:
        s = s.replace('.', '').replace(',', '.')
    elif re.fullmatch(r'\d{1,3}(\.\d{3})+', s):
        s = s.replace('.', '')
    try:
        return float(s)
    except ValueError:
        return None


def _moeda(palavra):
    p = sem_acentos(palavra).strip()
    p = re.sub(r'^(o|a|os|as|um|uma|1)\s+', '', p)
    return _ALIAS.get(p)


def _fmt(v, tipo, cod):
    if tipo == 'cripto':
        casas = 8 if v < 1 else 6 if v < 100 else 4
        s = numero(v, casas).rstrip('0').rstrip(',')
        return s + ' ' + CRIPTO_SIGLA.get(cod, cod.upper())
    casas = 0 if cod in ('jpy', 'krw', 'clp', 'pyg') or v >= 100000 else 2
    s = numero(v, casas)
    sim = SIMBOLO.get(cod)
    return (sim + ' ' + s) if sim else (s + ' ' + cod.upper())


def entender_moeda(texto):
    t = sem_acentos(texto).replace('×', 'x')
    # "R$ 50 em euros", "€50", "$10" -> "50 r$ em euros"
    t = re.sub(r'^(r\$|us\$|€|£|\$|¥|₿)\s*([\d.,]+)', r'\2 \1', t)
    t = re.sub(r'^([\d.,]+)\s*(r\$|us\$|€|£|\$|¥|₿)', r'\1 \2', t)
    m = re.fullmatch(r'(?:quanto (?:e|vale|custa|esta|sao)\s+)?(?:o |a |um |uma )?([\d.,]+\s+)?([^\d=]+?)'
                     r'(?:\s+(?:em|para|pra|to|in|=|->|>)\s+([^\d]+?))?\s*(?:hoje|agora)?\??', t)
    if not m:
        return None
    v = _valor(m.group(1) or '')
    a = _moeda(m.group(2))
    if not a:
        return None
    b = _moeda(m.group(3)) if m.group(3) else None
    if m.group(3) and not b:
        return None
    if v is None:
        if sem_acentos(m.group(2)).strip() in AMBIGUAS and not b:
            return None
        v = 1.0
    if b:
        alvos = [b]
    elif a[0] == 'cripto':
        alvos = [('fiat', 'eur'), ('fiat', 'brl'), ('fiat', 'usd')]
    else:
        alvos = [x for x in (('fiat', 'eur'), ('fiat', 'brl'), ('fiat', 'usd')) if x != a][:2]
    return v, a, alvos


def _taxa(a, b):
    """quanto vale 1 de a em b (e de onde veio)."""
    if a == b:
        return 1.0, '', None
    if a[0] == 'fiat' and b[0] == 'fiat':
        def busca():
            l = _get('https://api.frankfurter.dev/v2/rates?base=%s&quotes=%s' % (a[1], b[1]))
            return l[0]['rate'], l[0]['date']
        r, d = guardado('fx:%s:%s' % (a[1], b[1]), 3600, busca)
        return r, 'cotação de %s/%s · Frankfurter' % (d[8:10], d[5:7]), None

    def preco(cripto, fiat):
        j = guardado('cg:%s:%s' % (cripto, fiat), 60, lambda: _get(
            'https://api.coingecko.com/api/v3/simple/price?ids=%s&vs_currencies=%s&include_24hr_change=true'
            % (cripto, fiat)))
        return j[cripto][fiat], j[cripto].get(fiat + '_24h_change')
    if a[0] == 'cripto' and b[0] == 'fiat':
        p, var = preco(a[1], b[1])
        return p, 'agora · CoinGecko', var
    if a[0] == 'fiat' and b[0] == 'cripto':
        p, var = preco(b[1], a[1])
        return 1 / p, 'agora · CoinGecko', None
    pa, _ = preco(a[1], 'usd')
    pb, _ = preco(b[1], 'usd')
    return pa / pb, 'agora · CoinGecko', None


def cartao_moeda(texto):
    e = entender_moeda(texto)
    if not e:
        return None
    v, a, alvos = e
    res, fonte, variacao = [], '', None
    for b in alvos:
        try:
            r, f, var = _taxa(a, b)
        except Exception:
            continue
        res.append((b, v * r))
        fonte = fonte or f
        if variacao is None:
            variacao = var
    if not res:
        return None
    (b0, x0), resto = res[0], res[1:]
    sub = fonte
    if variacao is not None:
        sub += ' · 24 h: %s%%' % numero(variacao, 1).replace('-', '−') if variacao < 0 else ' · 24 h: +%s%%' % numero(variacao, 1)
    linhas = [[b[1].upper(), _fmt(x, b[0], b[1])] for b, x in resto]
    if a[0] == 'cripto' or b0[0] == 'cripto':
        url = 'https://www.coingecko.com/pt/moedas/' + (a[1] if a[0] == 'cripto' else b0[1])
    else:
        url = 'https://www.google.com/finance/quote/%s-%s' % (a[1].upper(), b0[1].upper())
    grande = _fmt(x0, b0[0], b0[1])
    return cartao('moeda', grande, _fmt(v, a[0], a[1]) + ' =', sub, linhas,
                  '🪙' if a[0] == 'cripto' or b0[0] == 'cripto' else '💱', url, grande)


# ==== CEP, código postal e endereços ===========================================================
def cartao_cep(texto):
    t = sem_acentos(texto)
    m = re.fullmatch(r'(?:cep\s*)?(\d{5})-(\d{3})', t) or re.fullmatch(r'cep\s*(\d{5})(\d{3})', t)
    if not m:
        return None
    cep = m.group(1) + m.group(2)
    j = guardado('cep:' + cep, 86400, lambda: _get('https://viacep.com.br/ws/%s/json/' % cep))
    if not j or j.get('erro'):
        return cartao('endereco', 'CEP não encontrado', 'CEP %s-%s' % (cep[:5], cep[5:]), emoji='📮')
    cidade = '%s - %s' % (j.get('localidade', ''), j.get('uf', ''))
    linhas = [x for x in (['Bairro', j.get('bairro', '')], ['Cidade', cidade], ['DDD', j.get('ddd', '')],
                          ['Complemento', j.get('complemento', '')]) if x[1]]
    rua = j.get('logradouro') or j.get('localidade', '')
    url = 'https://www.google.com/maps/search/?api=1&query=' + urllib.parse.quote('%s, %s, %s' % (rua, cidade, j['cep']))
    return cartao('endereco', rua, 'CEP ' + j['cep'], j.get('bairro', '') or cidade, linhas, '📮', url,
                  '%s, %s - %s, %s' % (rua, j.get('bairro', ''), cidade, j['cep']))


def cartao_cp(texto):
    t = sem_acentos(texto)
    m = re.fullmatch(r'(?:cp|codigo postal)?\s*(\d{4})-(\d{3})', t)
    if not m:
        return None
    cp = m.group(1) + '-' + m.group(2)
    try:
        j = guardado('cp:' + cp, 86400, lambda: _get('https://json.geoapi.pt/cp/' + cp))
    except Exception:
        return None
    if not j or not j.get('Localidade'):
        return cartao('endereco', 'Código postal não encontrado', 'Código postal ' + cp, emoji='📮')
    ruas = [p.get('Artéria', '') for p in j.get('partes', []) if p.get('Artéria')]
    linhas = [x for x in (['Ruas', ', '.join(ruas[:3]) + ('…' if len(ruas) > 3 else '')],
                          ['Concelho', j.get('Concelho', '')], ['Distrito', j.get('Distrito', '')]) if x[1]]
    loc = j.get('Localidade', '')
    url = 'https://www.google.com/maps/search/?api=1&query=' + urllib.parse.quote('%s %s, Portugal' % (cp, loc))
    return cartao('endereco', ruas[0] if len(ruas) == 1 else loc, 'Código postal ' + cp,
                  '%s · %s' % (j.get('Designação Postal', loc).title(), j.get('Distrito', '')), linhas, '📮', url,
                  '%s %s' % (cp, j.get('Designação Postal', loc)))


ENDERECO = re.compile(r'^(rua|r\.|avenida|av\.?|travessa|tv\.|praca|largo|alameda|estrada|rodovia|calcada|beco|'
                      r'rotunda|cais|quinta|endereco|onde fica|mapa)\s+\S', re.I)


def _perto():
    """um ponto perto de onde a pessoa está (pelo fuso), para os endereços daqui virem primeiro."""
    try:
        z = os.path.realpath('/etc/localtime').split('zoneinfo/', 1)[1]
    except (IndexError, OSError):
        return None
    return {'Europe/Lisbon': (38.72, -9.14), 'America/Sao_Paulo': (-23.55, -46.63), 'Atlantic/Madeira': (32.65, -16.91),
            'Atlantic/Azores': (37.74, -25.67)}.get(z)


def cartao_endereco(texto):
    if not ENDERECO.match(sem_acentos(texto)) or len(texto) < 8:
        return None
    q = re.sub(r'^(endereço|endereco|onde fica|mapa)\s+', '', texto.strip(), flags=re.I)
    perto = _perto()
    lat = lon = None
    p = {}
    try:
        u = 'https://photon.komoot.io/api/?limit=1&q=' + urllib.parse.quote(q)
        if perto:
            u += '&lat=%s&lon=%s' % perto
        j = guardado('ph:' + q, 3600, lambda: _get(u, timeout=5))
        f = (j.get('features') or [None])[0]
        if f:
            p = f['properties']
            lon, lat = f['geometry']['coordinates']
    except Exception:
        pass
    if lat is None:
        try:
            j = guardado('nm:' + q, 3600, lambda: _get(
                'https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&limit=1&accept-language=pt&q='
                + urllib.parse.quote(q), timeout=6))
            if j:
                a = j[0].get('address', {})
                p = dict(street=a.get('road', ''), housenumber=a.get('house_number', ''), postcode=a.get('postcode', ''),
                         city=a.get('city') or a.get('town') or a.get('village', ''), district=a.get('suburb', ''),
                         state=a.get('state', ''), country=a.get('country', ''), name=j[0].get('name', ''))
                lat, lon = j[0]['lat'], j[0]['lon']
        except Exception:
            return None
    if lat is None:
        return None
    rua = ' '.join(x for x in (p.get('street') or p.get('name', ''), p.get('housenumber', '')) if x)
    linhas = [x for x in (['Bairro', p.get('district', '')], ['Cidade', p.get('city', '')],
                          ['Região', p.get('state', '')], ['País', p.get('country', '')]) if x[1]]
    sub = ' '.join(x for x in (p.get('postcode', ''), p.get('city', '')) if x)
    url = 'https://www.google.com/maps/search/?api=1&query=%s,%s' % (lat, lon)
    return cartao('endereco', rua or q, 'Endereço', sub, linhas, '📍', url, ', '.join(x for x in (rua, sub) if x))


# ==== times e próximos jogos (dados públicos da ESPN) ===========================================
LIGAS = [('bra.1', 'Brasileirão'), ('bra.2', 'Série B'), ('por.1', 'Liga Portugal'), ('eng.1', 'Premier League'),
         ('esp.1', 'La Liga'), ('ita.1', 'Serie A'), ('ger.1', 'Bundesliga'), ('fra.1', 'Ligue 1'),
         ('arg.1', 'Argentina'), ('ned.1', 'Eredivisie'), ('usa.1', 'MLS'), ('ksa.1', 'Arábia Saudita')]
ESPN = 'https://site.api.espn.com/apis/site/v2/sports/soccer/'
# apelidos e nomes como se diz no Brasil e em Portugal
APELIDOS = {'mengao': 'flamengo', 'timao': 'corinthians', 'verdao': 'palmeiras', 'galo': 'atletico-mg',
            'atletico mineiro': 'atletico-mg', 'colorado': 'internacional', 'inter': 'internacional',
            'tricolor paulista': 'sao paulo', 'peixe': 'santos', 'fogao': 'botafogo', 'raposa': 'cruzeiro',
            'furacao': 'athletico-pr', 'athletico paranaense': 'athletico-pr', 'vascao': 'vasco da gama',
            'porto': 'fc porto', 'sporting lisboa': 'sporting cp', 'sporting': 'sporting cp', 'leoes': 'sporting cp',
            'aguias': 'benfica', 'dragoes': 'fc porto', 'sl benfica': 'benfica', 'sc braga': 'braga',
            'vitoria de guimaraes': 'vitoria guimaraes', 'barca': 'barcelona', 'real': 'real madrid',
            'atletico de madrid': 'atletico madrid', 'inter de milao': 'internazionale', 'milan': 'ac milan',
            'juve': 'juventus', 'bayern': 'bayern munich', 'bayern de munique': 'bayern munich', 'psg': 'paris saint-germain',
            'manchester united': 'manchester united', 'man united': 'manchester united', 'city': 'manchester city',
            'boca': 'boca juniors', 'river': 'river plate'}
LIGAS_PT = {'Brazil Serie A': 'Brasileirão', 'Brazilian Serie A': 'Brasileirão', 'Brazil Serie B': 'Série B',
            'Portuguese Liga': 'Liga Portugal', 'Taca de Portugal': 'Taça de Portugal', 'UEFA Champions League': 'Champions',
            'UEFA Europa League': 'Liga Europa', 'UEFA Conference League': 'Liga Conferência', 'LALIGA': 'La Liga',
            'Spanish LALIGA': 'La Liga', 'English Premier League': 'Premier League', 'Italian Serie A': 'Serie A',
            'German Bundesliga': 'Bundesliga', 'French Ligue 1': 'Ligue 1', 'CONMEBOL Libertadores': 'Libertadores',
            'CONMEBOL Sudamericana': 'Sul-Americana', 'Copa do Brasil': 'Copa do Brasil', 'FA Cup': 'Copa da Inglaterra',
            'Copa del Rey': 'Copa do Rei', 'FIFA Club World Cup': 'Mundial de Clubes'}
TIMES = os.path.join(CACHE, 'times.json')
_times = None
_lendo_times = threading.Lock()


def _ler_times():
    """a lista dos times (renovada uma vez por semana, em segundo plano)."""
    global _times
    if _times is not None:
        return _times
    try:
        j = json.load(open(TIMES, encoding='utf-8'))
        _times = j['times']
        if time.time() - j.get('feito', 0) < 7 * 86400:
            return _times
    except (OSError, ValueError, KeyError):
        _times = []
    threading.Thread(target=_renovar_times, daemon=True).start()
    return _times


def _renovar_times():
    global _times
    if not _lendo_times.acquire(blocking=False):
        return
    try:
        lista = []
        for liga, nome_liga in LIGAS:
            try:
                j = _get(ESPN + liga + '/teams', timeout=8)
            except Exception:
                continue
            for x in j['sports'][0]['leagues'][0]['teams']:
                t = x['team']
                chaves = {sem_acentos(t.get(k) or '') for k in ('displayName', 'shortDisplayName', 'name', 'nickname',
                                                                'location')}
                chaves.discard('')
                for k in list(chaves):
                    b = re.sub(r'^(fc|cf|ac|sc|cd|c\.d\.|sl|ss|as|us|rc|rcd|ud|sd|ca)\s+|\s+(fc|cf|cp|sc|ac)$', '', k)
                    if b != k and len(b) > 3:
                        chaves.add(b)
                    if '-' in k:
                        chaves.add(k.replace('-', ' '))
                chaves -= set(CIDADES) - {sem_acentos(t.get('displayName', ''))}   # "miami" é a cidade, não o time
                logo = (t.get('logos') or [{}])[0].get('href', '')
                lista.append(dict(id=t['id'], liga=liga, nomeLiga=nome_liga, nome=t.get('displayName', ''),
                                  chaves=sorted(chaves), logo=logo))
        if lista:
            os.makedirs(CACHE, exist_ok=True)
            tmp = TIMES + '.tmp'
            json.dump(dict(feito=time.time(), times=lista), open(tmp, 'w', encoding='utf-8'), ensure_ascii=False)
            os.replace(tmp, TIMES)
            _times = lista
    finally:
        _lendo_times.release()


def preparar():
    """chamado ao abrir a Pesquisa: garante a lista dos times (sem atrasar nada)."""
    threading.Thread(target=_ler_times, daemon=True).start()


def _time(texto):
    t = sem_acentos(texto)
    t = re.sub(r'^((proximos )?jogos? (do|da|de|dos|das)|time|clube)\s+', '', t)
    t = re.sub(r'\s+(jogos?|proximos jogos)$', '', t).strip()
    if len(t) < 3:
        return None
    t = APELIDOS.get(t, t)
    for x in _ler_times():
        if t in x['chaves']:
            return x
    return None


def cartao_jogos(texto):
    tm = _time(texto)
    if not tm:
        return None
    j = guardado('jogos:' + tm['id'], 1800, lambda: _get(
        ESPN + 'all/teams/%s/schedule?fixture=true' % tm['id'], timeout=8))
    linhas = []
    for e in (j.get('events') or [])[:4]:
        try:
            quando = datetime.strptime(e['date'], '%Y-%m-%dT%H:%MZ').replace(tzinfo=timezone.utc).astimezone()
            c = e['competitions'][0]['competitors']
            casa = next((x for x in c if x.get('homeAway') == 'home'), c[0])['team']
            fora = next((x for x in c if x.get('homeAway') == 'away'), c[-1])['team']
            lg = e.get('league', {}) if isinstance(e.get('league'), dict) else {}
            liga = LIGAS_PT.get(lg.get('name', ''), LIGAS_PT.get(lg.get('abbreviation', ''), lg.get('abbreviation', '')))
            linhas.append(['%s %s · %s' % (DIAS_CURTOS[quando.weekday()], quando.strftime('%d/%m'), quando.strftime('%H:%M')),
                           '%s × %s' % (casa.get('shortDisplayName') or casa.get('displayName', ''),
                                        fora.get('shortDisplayName') or fora.get('displayName', ''))
                           + (' · ' + liga if liga else '')])
        except Exception:
            continue
    url = 'https://www.espn.com.br/futebol/time/_/id/%s' % tm['id']
    if not linhas:
        return cartao('jogos', tm['nome'], 'Próximos jogos', 'Nenhum jogo marcado por agora', [], '⚽', url,
                      imagem=tm.get('logo', ''))
    return cartao('jogos', tm['nome'], 'Próximos jogos · horário daqui', tm['nomeLiga'], linhas, '⚽', url,
                  linhas[0][0] + ' ' + linhas[0][1], imagem=tm.get('logo', ''))


def rede(texto):
    """a função que busca o cartão na internet, se o texto tiver a forma de uma destas perguntas."""
    t = texto.strip()
    if not t or len(t) > 80:
        return None
    if entender_moeda(t):
        return lambda: cartao_moeda(t)
    s = sem_acentos(t)
    if re.fullmatch(r'(?:cep\s*)?\d{5}-\d{3}|cep\s*\d{8}', s):
        return lambda: cartao_cep(t)
    if re.fullmatch(r'(?:cp|codigo postal)?\s*\d{4}-\d{3}', s):
        return lambda: cartao_cp(t)
    if ENDERECO.match(s) and len(t) >= 8:
        return lambda: cartao_endereco(t)
    if _time(t):
        return lambda: cartao_jogos(t)
    return None
