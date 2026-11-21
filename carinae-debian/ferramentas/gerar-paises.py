#!/usr/bin/python3
# CarinaeOS - gera /usr/share/carinaeos/comando/paises.json (dados dos países para a Pesquisa, sem internet).
#   Países: mledoze/countries (ODbL 1.0)  ·  População: Banco Mundial, SP.POP.TOTL (CC BY 4.0)
#   Fusos: o tzdata do sistema (zone.tab), com o fuso principal dos países com vários.
# Uso: gerar-paises.py countries.json populacao-bancomundial.json saida.json
import json
import sys
import unicodedata

IDIOMAS = {
    'por': 'português', 'eng': 'inglês', 'spa': 'espanhol', 'fra': 'francês', 'deu': 'alemão', 'ita': 'italiano',
    'nld': 'holandês', 'rus': 'russo', 'zho': 'chinês', 'jpn': 'japonês', 'kor': 'coreano', 'ara': 'árabe',
    'hin': 'híndi', 'ben': 'bengali', 'urd': 'urdu', 'tur': 'turco', 'pol': 'polonês', 'ukr': 'ucraniano',
    'ell': 'grego', 'swe': 'sueco', 'nor': 'norueguês', 'nno': 'norueguês', 'nob': 'norueguês', 'dan': 'dinamarquês',
    'fin': 'finlandês', 'isl': 'islandês', 'gle': 'irlandês', 'cym': 'galês', 'cat': 'catalão', 'glg': 'galego',
    'eus': 'basco', 'ron': 'romeno', 'hun': 'húngaro', 'ces': 'tcheco', 'slk': 'eslovaco', 'slv': 'esloveno',
    'hrv': 'croata', 'srp': 'sérvio', 'bos': 'bósnio', 'bul': 'búlgaro', 'mkd': 'macedônio', 'sqi': 'albanês',
    'lit': 'lituano', 'lav': 'letão', 'est': 'estoniano', 'heb': 'hebraico', 'fas': 'persa', 'pus': 'pashto',
    'tha': 'tailandês', 'vie': 'vietnamita', 'ind': 'indonésio', 'msa': 'malaio', 'fil': 'filipino', 'tgl': 'tagalo',
    'swa': 'suaíli', 'amh': 'amárico', 'afr': 'africâner', 'zul': 'zulu', 'xho': 'xhosa', 'hau': 'hauçá',
    'yor': 'iorubá', 'ibo': 'igbo', 'som': 'somali', 'mlg': 'malgaxe', 'kin': 'kinyarwanda', 'grn': 'guarani',
    'que': 'quíchua', 'aym': 'aimará', 'hat': 'crioulo haitiano', 'tet': 'tétum', 'ltz': 'luxemburguês',
    'mlt': 'maltês', 'kat': 'georgiano', 'hye': 'armênio', 'aze': 'azeri', 'kaz': 'cazaque', 'uzb': 'uzbeque',
    'tuk': 'turcomeno', 'kir': 'quirguiz', 'tgk': 'tadjique', 'mon': 'mongol', 'nep': 'nepalês', 'sin': 'cingalês',
    'tam': 'tâmil', 'khm': 'khmer', 'lao': 'laosiano', 'mya': 'birmanês', 'bel': 'bielorrusso', 'smo': 'samoano',
    'ton': 'tonganês', 'fij': 'fijiano', 'mri': 'maori', 'lat': 'latim', 'roh': 'romanche', 'gsw': 'alemão suíço',
}
REGIOES = {'Africa': 'África', 'Americas': 'Américas', 'Asia': 'Ásia', 'Europe': 'Europa', 'Oceania': 'Oceania',
           'Antarctic': 'Antártida'}
SUB = {'South America': 'América do Sul', 'North America': 'América do Norte', 'Central America': 'América Central',
       'Caribbean': 'Caribe', 'Southern Europe': 'Sul da Europa', 'Northern Europe': 'Norte da Europa',
       'Western Europe': 'Europa Ocidental', 'Eastern Europe': 'Europa Oriental', 'Central Europe': 'Europa Central',
       'Southeast Europe': 'Sudeste da Europa', 'Western Asia': 'Ásia Ocidental', 'Southern Asia': 'Sul da Ásia',
       'Eastern Asia': 'Leste da Ásia', 'South-Eastern Asia': 'Sudeste Asiático', 'Central Asia': 'Ásia Central',
       'Northern Africa': 'Norte da África', 'Western Africa': 'África Ocidental', 'Eastern Africa': 'África Oriental',
       'Middle Africa': 'África Central', 'Southern Africa': 'África Austral', 'Australia and New Zealand':
       'Austrália e Nova Zelândia', 'Melanesia': 'Melanésia', 'Micronesia': 'Micronésia', 'Polynesia': 'Polinésia'}
# o fuso "principal" dos países com vários (o da capital ou da maior cidade)
FUSO = {'BR': 'America/Sao_Paulo', 'US': 'America/New_York', 'CA': 'America/Toronto', 'MX': 'America/Mexico_City',
        'RU': 'Europe/Moscow', 'AU': 'Australia/Sydney', 'CN': 'Asia/Shanghai', 'ID': 'Asia/Jakarta',
        'AR': 'America/Argentina/Buenos_Aires', 'CL': 'America/Santiago', 'PT': 'Europe/Lisbon', 'ES': 'Europe/Madrid',
        'KZ': 'Asia/Almaty', 'MN': 'Asia/Ulaanbaatar', 'CD': 'Africa/Kinshasa', 'EC': 'America/Guayaquil',
        'NZ': 'Pacific/Auckland', 'GL': 'America/Nuuk', 'FR': 'Europe/Paris', 'GB': 'Europe/London',
        'DE': 'Europe/Berlin', 'UA': 'Europe/Kyiv', 'MY': 'Asia/Kuala_Lumpur', 'PG': 'Pacific/Port_Moresby',
        'KI': 'Pacific/Tarawa', 'FM': 'Pacific/Pohnpei', 'PF': 'Pacific/Tahiti', 'UZ': 'Asia/Tashkent',
        'CY': 'Asia/Nicosia', 'NL': 'Europe/Amsterdam', 'DK': 'Europe/Copenhagen', 'NO': 'Europe/Oslo'}


CAPITAIS = {
    'Lisbon': 'Lisboa', 'Tokyo': 'Tóquio', 'London': 'Londres', 'Washington D.C.': 'Washington, D.C.',
    'Moscow': 'Moscou', 'Beijing': 'Pequim', 'Rome': 'Roma', 'Athens': 'Atenas', 'Brussels': 'Bruxelas',
    'Copenhagen': 'Copenhague', 'Stockholm': 'Estocolmo', 'Warsaw': 'Varsóvia', 'Vienna': 'Viena',
    'Prague': 'Praga', 'Bern': 'Berna', 'Mexico City': 'Cidade do México', 'Seoul': 'Seul',
    'New Delhi': 'Nova Délhi', 'Bangkok': 'Bangcoc', 'Jakarta': 'Jacarta', 'Tehran': 'Teerã', 'Baghdad': 'Bagdá',
    'Riyadh': 'Riade', 'Jerusalem': 'Jerusalém', 'Ankara': 'Ancara', 'Kyiv': 'Kiev', 'Bucharest': 'Bucareste',
    'Budapest': 'Budapeste', 'Belgrade': 'Belgrado', 'Reykjavik': 'Reykjavík', 'Dili': 'Díli',
    'Pretoria': 'Pretória', 'Nairobi': 'Nairóbi', 'Addis Ababa': 'Adis Abeba', 'Montevideo': 'Montevidéu',
    'Asunción': 'Assunção', 'Havana': 'Havana', 'Cairo': 'Cairo', 'Algiers': 'Argel', 'Tunis': 'Túnis',
    'Rabat': 'Rabat', 'Damascus': 'Damasco', 'Beirut': 'Beirute', 'Amman': 'Amã', 'Kabul': 'Cabul',
    'Islamabad': 'Islamabad', 'Dhaka': 'Daca', 'Kathmandu': 'Catmandu', 'Manila': 'Manila', 'Hanoi': 'Hanói',
    'Singapore': 'Singapura', 'Kuala Lumpur': 'Kuala Lumpur', 'Taipei': 'Taipé', 'Ulan Bator': 'Ulan Bator',
    'Tbilisi': 'Tbilisi', 'Yerevan': 'Erevan', 'Baku': 'Baku', 'Minsk': 'Minsk', 'Vilnius': 'Vilnius',
    'Riga': 'Riga', 'Tallinn': 'Talin', 'Helsinki': 'Helsinque', 'Oslo': 'Oslo', 'Dublin': 'Dublin',
    'Amsterdam': 'Amsterdã', 'Luxembourg': 'Luxemburgo', 'Monaco': 'Mônaco', 'Valletta': 'Valeta',
    'Nicosia': 'Nicósia', 'Sofia': 'Sófia', 'Skopje': 'Escópia', 'Tirana': 'Tirana', 'Zagreb': 'Zagreb',
    'Ljubljana': 'Liubliana', 'Sarajevo': 'Sarajevo', 'Podgorica': 'Podgorica', 'Bratislava': 'Bratislava',
    'Chișinău': 'Chisinau', 'Ottawa': 'Ottawa', 'Canberra': 'Camberra', 'Wellington': 'Wellington',
    'Panama City': 'Cidade do Panamá', 'Guatemala City': 'Cidade da Guatemala', 'Kingston': 'Kingston',
    'Port-au-Prince': 'Porto Príncipe', 'Santo Domingo': 'São Domingos', 'Georgetown': 'Georgetown',
    'Paramaribo': 'Paramaribo', 'Cape Town': 'Cidade do Cabo', 'Kinshasa': 'Kinshasa', 'Abuja': 'Abuja',
    'Accra': 'Acra', 'Dakar': 'Dacar', 'Khartoum': 'Cartum', 'Tripoli': 'Trípoli', 'Doha': 'Doha',
    'Abu Dhabi': 'Abu Dhabi', 'Muscat': 'Mascate', 'Kuwait City': 'Cidade do Kuwait', 'Manama': 'Manama',
    'Sana\'a': 'Saná', 'Tashkent': 'Tashkent', 'Astana': 'Astana', 'Pyongyang': 'Pyongyang',
    'Vatican City': 'Cidade do Vaticano', 'San Marino': 'San Marino', 'Andorra la Vella': 'Andorra-a-Velha',
    'São Tomé': 'São Tomé', 'Praia': 'Praia', 'Bissau': 'Bissau', 'Luanda': 'Luanda', 'Maputo': 'Maputo',
    'Edinburgh': 'Edimburgo', 'Cardiff': 'Cardiff', 'Belfast': 'Belfast'}


def sem_acentos(t):
    return ''.join(c for c in unicodedata.normalize('NFD', t) if unicodedata.category(c) != 'Mn').lower()


def fusos_do_tzdata():
    r = {}
    for l in open('/usr/share/zoneinfo/zone.tab', encoding='utf-8'):
        if l.startswith('#') or not l.strip():
            continue
        p = l.rstrip('\n').split('\t')
        r.setdefault(p[0], []).append(p[2])
    return r


def main():
    paises = json.load(open(sys.argv[1], encoding='utf-8'))
    wb = json.load(open(sys.argv[2], encoding='utf-8'))[1]
    pop = {x['countryiso3code']: (x['value'], x['date']) for x in wb if x.get('value')}
    tz = fusos_do_tzdata()
    saida = []
    for c in paises:
        tr = c.get('translations', {}).get('por', {})
        nome = tr.get('common') or c['name']['common']
        nativo = c['name'].get('native', {}).get('por', {})
        oficial = nativo.get('official') or tr.get('official') or c['name'].get('official', '')
        if c['cca2'] == 'PT':
            oficial = 'República Portuguesa'       # (o conjunto de dados traz "República português")
        idd = c.get('idd', {})
        ddi = ''
        if idd.get('root'):
            suf = idd.get('suffixes') or ['']
            ddi = idd['root'] + (suf[0] if len(suf) == 1 else '')
        busca = {sem_acentos(nome), sem_acentos(c['name']['common']), sem_acentos(tr.get('official', '')),
                 sem_acentos(c['name'].get('official', ''))}
        for n in c['name'].get('native', {}).values():
            busca.add(sem_acentos(n.get('common', '')))
        busca |= {sem_acentos(a) for a in c.get('altSpellings', []) if len(a) > 3}
        busca |= {sem_acentos(x) for x in ('Holanda', 'Inglaterra', 'Escócia', 'EUA', 'USA', 'Reino Unido')
                  if (x in ('Holanda',) and c['cca2'] == 'NL') or (x in ('EUA', 'USA') and c['cca2'] == 'US')
                  or (x in ('Inglaterra', 'Escócia', 'Reino Unido') and c['cca2'] == 'GB')}
        busca.discard('')
        p, ano = pop.get(c.get('cca3'), (None, ''))
        zonas = tz.get(c['cca2'], [])
        saida.append(dict(
            cca2=c['cca2'], nome=nome, oficial=oficial,
            capital=[CAPITAIS.get(x, x) for x in c.get('capital', [])], populacao=p, ano=ano, area=c.get('area'),
            moedas=[[k, v.get('symbol', '')] for k, v in c.get('currencies', {}).items()],
            idiomas=[IDIOMAS.get(k, v) for k, v in c.get('languages', {}).items()],
            ddi=ddi, regiao=REGIOES.get(c.get('region', ''), c.get('region', '')),
            sub=SUB.get(c.get('subregion', ''), c.get('subregion', '')), bandeira=c.get('flag', ''),
            fuso=FUSO.get(c['cca2'], zonas[0] if zonas else ''), nfusos=len(zonas), busca=sorted(busca)))
    saida.sort(key=lambda x: x['nome'])
    json.dump(saida, open(sys.argv[3], 'w', encoding='utf-8'), ensure_ascii=False, separators=(',', ':'))
    print(len(saida), 'países')


if __name__ == '__main__':
    main()
