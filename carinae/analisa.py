#!/usr/bin/env python3
# CarinaeOS - le uma pagina do livro BLFS e separa o que instalar.
#   analisa.py <pagina.html> <secao/pagina[#ancora]> [ver]
# Grava no diretorio atual: downloads.txt, md5.txt, build.sh, unidades.sh
# Regras (sempre mostradas na tela):
#   - testes (make check/test, ninja test, ...) ficam de fora (opcionais no livro)
#   - blocos com valores a substituir ficam de fora, exceto os prefixos que o
#     CarinaeOS escolheu (ESCOLHAS)
#   - decisoes.txt: blocos que o livro marca como alternativos/opcionais para o
#     nosso caso, revistos um a um (pagina  blocos  motivo)
import re, html, os, sys

ESCOLHAS = {'<PREFIX>': '/usr', '<$KF6_PREFIX>': '/usr', '$(nproc)': '$(nproc)'}
# bloco de teste: a primeira linha util executa a suite de testes
TESTE = re.compile(r'^\s*(\w+=\S+\s+)*(make|ninja)(\s+-\S+)*(\s+-C\s+\S+)?\s+(-k\s+)?(check|test|tests|test-suite)\b'
                   r'|^\s*(\w+=\S+\s+)*(ctest|pytest|python3 -m pytest|\S*/pytest)\b'
                   r'|testenv|^\s*(\w+=\S+\s+)*(\./)?(run-?tests?|tests?/run)')
# o livro anuncia os blocos de teste no texto logo antes deles
TESTE_PROSA = re.compile(r'(^|\b)(to test|if you (want|wish|desire) to (test|run the test)|to run the (test|unit)|'
                         r'if running the test|run the test ?suite|optionally,? (test|run the test)|'
                         r'to (build|compile) the tests?|to check the results)', re.I)

def frase_antes(html_trecho):
    """o ultimo paragrafo antes do bloco (ex.: "To test the results, issue:")"""
    ps = re.findall(r'<p[^>]*>(.*?)</p>', html_trecho, re.S)
    return re.sub(r'\s+', ' ', txt(ps[-1])).strip() if ps else ''

# testes encadeados no fim de um comando de compilacao (ex.: "make && make test")
TESTE_ENCADEADO = re.compile(r'\s*&&\s*(\w+=\S+\s+)*(make|ninja)(\s+-k)?\s+(test|check|tests)\b[^\n&|;]*')
def tira_testes(b):
    tirou = [m.group(0).strip() for m in TESTE_ENCADEADO.finditer(b)]
    return TESTE_ENCADEADO.sub('', b), ', '.join(tirou)

def eh_teste(b):
    linhas = [l for l in b.splitlines() if l.strip() and not l.strip().startswith('#')]
    return bool(linhas) and (bool(TESTE.search(linhas[0])) or 'testenv' in b)

# valores a substituir escritos sem marcacao (ex.: ldd <application or library>)
MARCADOR = re.compile(r'<[a-z]+(?: [a-z]+)+>|<(?:username|user|version|theme path)>')

def normaliza(s):
    # o HTML publicado passa pelo tidy, que quebra atributos em varias linhas
    # (ex.: class=\n"replaceable"); normalizamos antes de procurar
    s = re.sub(r'=\s+"', '="', s)
    s = re.sub(r'<(\w+)\s+', r'<\1 ', s)
    s = re.sub(r'(<h2 class="sect2">)\s+', r'\1', s)
    return s

def txt(x): return html.unescape(re.sub(r'<[^>]+>', '', x))

def decisoes(no):
    f = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'decisoes.txt')
    if not os.path.exists(f): f = '/root/decisoes.txt'
    pul, por = set(), ''
    if os.path.exists(f):
        for l in open(f, encoding='utf-8'):
            c = l.split(None, 2)
            if len(c) >= 2 and c[0] == no:
                pul |= set(c[1].split(',')); por = c[2].strip() if len(c) > 2 else ''
    return pul, por

def trecho(s, anc):
    if not anc: return s
    marcas = [(m.start(), m.group(1)) for m in re.finditer(r'<h2 class="sect2"><a id="([^"]+)"', s)]
    for i, (ini, a) in enumerate(marcas):
        if a == anc:
            return s[ini:(marcas[i + 1][0] if i + 1 < len(marcas) else len(s))]
    sys.exit(f'secao #{anc} nao encontrada na pagina')

def analisa(arquivo, no, ver=False, saida='.'):
    pg, _, anc = no.partition('#')
    s = trecho(normaliza(open(arquivo, encoding='utf-8').read()), anc)
    fim = s.find('Dependencies'); area = s[:fim if fim > 0 else len(s)]
    urls = []
    for u in re.findall(r'href=\s*"((?:https?)://[^"]+)"', area):
        if re.search(r'\.(tar\.(gz|xz|bz2|zst|lz)|tgz|zip|patch)$', u) and u not in urls:
            urls.append(u)
    md5 = re.findall(r'MD5 sum:\s*([0-9a-f]{32})', txt(area))
    pul, por = decisoes(no)
    pul |= {x for x in os.environ.get('PULAR', '').split(',') if x}
    print('== downloads:'); [print('   ', u) for u in urls]
    print('== MD5 do pacote principal:', md5[0] if md5 else '(nao encontrado)')
    if por: print('== revisao:', por)
    usar, unid = [], []
    fim_ant = 0
    for i, m in enumerate(re.finditer(r'<pre\s+class="(root|userinput)"\s*>(.*?)</pre>', s, re.S)):
        cl, raw = m.group(1), m.group(2)
        intro = frase_antes(s[fim_ant:m.start()]); fim_ant = m.end()
        b = txt(raw).strip(); l1 = b.splitlines()[0][:90] if b else ''
        b, tirou = tira_testes(b)
        if tirou: print(f'   (#{i}: retirado o teste encadeado: {tirou})')
        rep = [txt(x) for x in re.findall(r'class="replaceable"[^>]*>(.*?)</(?:em|code|span)>', raw, re.S)]
        if rep and all(x in ESCOLHAS for x in rep):
            for x in rep: b = b.replace(x, ESCOLHAS[x])
            raw = raw.replace('replaceable', 'escolhido'); l1 = b.splitlines()[0][:90]
        if ver: print(f'----- bloco #{i} ({cl}) -----'); print(b)
        if str(i) in pul:                print(f'   PULADO (revisto)  #{i}: {l1}')
        elif b.strip() in ('bash -e', 'exit'): print(f'   PULADO (shell)    #{i}: {l1}')
        elif 'replaceable' in raw or MARCADOR.search(b): print(f'   PULADO (exemplo)  #{i}: {l1}')
        elif eh_teste(b) or TESTE_PROSA.search(intro): print(f'   PULADO (teste)    #{i}: {l1}')
        elif re.match(r'make install-[a-z]', b) and 'systemd-units' in s:
            print(f'   RODA (unidade)    #{i}: {l1}'); unid.append(b)
        else:                            print(f'   RODA              #{i}: {l1}'); usar.append(b)
    j = lambda n: os.path.join(saida, n)
    open(j('downloads.txt'), 'w').write('\n'.join(urls) + '\n')
    open(j('md5.txt'), 'w').write((md5[0] if md5 else '-') + '\n')
    open(j('build.sh'), 'w').write('\n'.join(usar) + '\n')
    open(j('unidades.sh'), 'w').write('\n'.join(unid) + '\n')

if __name__ == '__main__':
    analisa(sys.argv[1], sys.argv[2], len(sys.argv) > 3 and sys.argv[3] == 'ver')
