# CarinaeOS - Eta: o manual do CarinaeOS como memoria de origem (so leitura).
# O manual (/usr/share/doc/carinaeos/manual/*.md) e partido por secoes; cada pedaco leva o titulo
# "Manual › Capitulo › Secao", para a Eta encontrar a parte certa e citar de onde tirou.
import glob
import json
import os
import re

PASTA = '/usr/share/doc/carinaeos/manual'
INDICE = '/usr/share/carinaeos/eta/manual.json'


def _partir(texto, tamanho=900):
    blocos, atual = [], ''
    for par in re.split(r'\n\s*\n', texto):
        par = par.strip()
        if not par:
            continue
        if len(atual) + len(par) > tamanho and atual:
            blocos.append(atual)
            atual = ''
        while len(par) > tamanho * 1.6:                 # tabelas e listas de comandos muito grandes
            corte = par.rfind('\n', 0, tamanho) or tamanho
            blocos.append(par[:corte])
            par = par[corte:].strip()
        atual = (atual + '\n\n' + par).strip()
    if atual:
        blocos.append(atual)
    return blocos


def construir(pasta=PASTA):
    import memoria as MEM
    docs = []
    for f in sorted(glob.glob(os.path.join(pasta, '*.md'))):
        if os.path.basename(f).startswith('00-'):
            continue                                # o indice so repete os titulos
        texto = open(f, encoding='utf-8').read()
        cap = re.search(r'^#\s+(.+)$', texto, re.M)
        capitulo = re.sub(r'^\d+\.\s*', '', cap.group(1)).strip() if cap else os.path.basename(f)
        secoes = re.split(r'^(#{2,3}\s+.+)$', texto, flags=re.M)
        pedacos = []
        titulo_secao = ''
        corpo = secoes[0]
        partes = [('', corpo)] + [(secoes[i], secoes[i + 1]) for i in range(1, len(secoes) - 1, 2)]
        for cab, corpo in partes:
            titulo_secao = re.sub(r'^#+\s*', '', cab).strip() or titulo_secao
            corpo = re.sub(r'^#\s+.+$', '', corpo, flags=re.M).strip()
            for b in _partir(corpo):
                t = '%s › %s' % (capitulo, titulo_secao) if titulo_secao else capitulo
                pedacos.append(dict(t='[%s]\n%s' % (t, b), f=MEM.fichas(t + ' ' + b)))
        docs.append(dict(id='manual:' + os.path.basename(f), titulo='Manual › ' + capitulo, origem='manual',
                         quando=0, resumo='', pedacos=pedacos, arquivo=f))
    return docs


_cache = None


def documentos():
    """Os capitulos do manual (do indice feito na construcao da ISO, ou feitos agora)."""
    global _cache
    if _cache is None:
        try:
            with open(INDICE, encoding='utf-8') as f:
                _cache = json.load(f)
        except (OSError, ValueError):
            try:
                _cache = construir()
            except Exception:
                _cache = []
    return _cache


if __name__ == '__main__':
    import sys
    pasta = sys.argv[1] if len(sys.argv) > 1 else PASTA
    saida = sys.argv[2] if len(sys.argv) > 2 else INDICE
    d = construir(pasta)
    os.makedirs(os.path.dirname(saida), exist_ok=True)
    with open(saida, 'w', encoding='utf-8') as f:
        json.dump(d, f, ensure_ascii=False)
    print('manual: %d capitulos, %d pedacos' % (len(d), sum(len(x['pedacos']) for x in d)))
