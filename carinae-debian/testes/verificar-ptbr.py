#!/usr/bin/env python3
"""CarinaeOS - verificador de português do Brasil: procura palavras de Portugal no texto que o
usuário vê (textos entre aspas no QML/JS/Python/shell, nome e descrição dos .desktop, README e
manual). Os comentários do código ficam de fora; os identificadores internos ("partilha", "rato")
também. Uma linha com "ptbr-ok" é aceita como está (para citações, nomes próprios…).

  verificar-ptbr.py [raiz do repositório]      sai com 1 se encontrar alguma coisa (a CI para)
"""
import io
import os
import re
import sys
import tokenize

# palavra de Portugal -> como se diz no Brasil (o que aparece no relatório)
PALAVRAS = {
    r'ecrãs?': 'tela(s)', r'ficheiros?': 'arquivo(s)', r'utilizador(es)?': 'usuário(s)', r'telemóve(l|is)': 'celular(es)',
    r'palavras?-passe': 'senha(s)', r'transferências': 'downloads', r'contactos?': 'contato(s)', r'equipas?': 'equipe(s)',
    r'registos?': 'registro(s)', r'ratos?': 'mouse', r'definições': 'configurações', r'predefinid[oa]s?': 'padrão',
    r'predefiniç(ão|ões)': 'padrão', r'ligaç(ão|ões)': 'conexão/conexões', r'aplicaç(ão|ões)': 'aplicativo(s)',
    r'sem fios': 'sem fio', r'câmaras?': 'câmera(s)', r'connosco': 'conosco', r'de facto': 'de fato', r'secç(ão|ões)': 'seção/seções',
    r'arranque': 'inicialização', r'arranca(r|m)?': 'inicia(r)', r'descarrega(r|do|da)?': 'baixar', r'carregue (em|no|na)': 'clique em',
    r'prima|premir': 'pressione', r'sítio': 'lugar', r'mostrar a mesa': 'mostrar a área de trabalho', r'actual(izar|izado)?': 'atual(izar)',
    r'acç(ão|ões)': 'ação/ações', r'óptim[oa]': 'ótimo', r'objectos?': 'objeto(s)', r'direcç(ão|ões)': 'direção',
    r'colecç(ão|ões)': 'coleção', r'percentagem': 'porcentagem', r'guarda-redes': 'goleiro', r'autocarro': 'ônibus',
    r'combinámos|fizemos-lhe|apanh(ou|ar|a)': '(pt-PT)', r'detet(a|ar|ado|ada|am)|deteç(ão|ões)': 'detecta(r)',
    r'contentor(es)?': 'contêiner', r'correm (pelo|no|na|em)': 'rodam', r'partilh(a|ar|ada|adas|ado|ados|e)': 'compartilhar',
}
# "está a fazer" (pt-PT) em vez de "está fazendo"; "A tocar" no início de um texto
GERUNDIO = re.compile(r'\b(est(á|ão|ou|ava|avam|eja|ar)|fic(a|am|ar)|anda(m)?|continua(m)?)\s+a\s+[a-zçãé]+(ar|er|ir)\b', re.I)
ROTULO = re.compile(r'^\s*A (tocar|carregar|procurar|verificar|instalar|transferir|ligar|desligar|atualizar|gravar|correr|abrir|copiar)\b')
PADRAO = re.compile(r'(?<![\w-])(' + '|'.join(PALAVRAS) + r')(?![\w-])', re.I)
IDENT = re.compile(r'^[a-z0-9_:./@+-]*$')          # 'partilha', 'sis:dnd', caminhos: não é texto

PASTAS = ['carinae-debian/sistema', 'carinae/tema']   # (config/includes.chroot é gerada pelo construir.sh)
FORA = ('/chroot/', '/.git/', 'mdi.json', '/node_modules/', '/locale/')
EXT_CODIGO = ('.qml', '.js', '.py')


def literais_qml(texto):
    for n, linha in enumerate(texto.splitlines(), 1):
        for m in re.finditer(r'"((?:[^"\\]|\\.)*)"', linha):
            yield n, m.group(1)


def literais_py(texto):
    try:
        for t in tokenize.generate_tokens(io.StringIO(texto).readline):
            if t.type == tokenize.STRING:
                corpo = re.sub(r'^[rbuf]*("""|\'\'\'|"|\')|("""|\'\'\'|"|\')$', '', t.string, flags=re.I)
                for k, l in enumerate(corpo.splitlines() or [''], 0):
                    yield t.start[0] + k, l
    except (tokenize.TokenError, IndentationError, SyntaxError):
        yield from literais_qml(texto)


def literais_sh(texto):
    for n, linha in enumerate(texto.splitlines(), 1):
        if linha.lstrip().startswith('#'):
            continue
        for m in re.finditer(r'"((?:[^"\\]|\\.)*)"|\'([^\']*)\'', linha):
            yield n, m.group(1) if m.group(1) is not None else m.group(2)


def texto_desktop(texto):
    for n, linha in enumerate(texto.splitlines(), 1):
        if re.match(r'^(Name|GenericName|Comment|Keywords)(\[pt_BR\])?=', linha):
            yield n, linha.split('=', 1)[1]


def texto_md(texto):
    dentro = False
    for n, linha in enumerate(texto.splitlines(), 1):
        if linha.strip().startswith('```'):
            dentro = not dentro
            continue
        if not dentro:
            yield n, re.sub(r'`[^`]*`', '', linha)


def arquivos(raiz):
    for p in PASTAS:
        for d, _, fs in os.walk(os.path.join(raiz, p)):
            for f in fs:
                yield os.path.join(d, f)
    yield os.path.join(raiz, 'README.md')
    yield os.path.join(raiz, '.github', 'notas-da-versao.md')
    man = os.path.join(raiz, 'docs', 'manual')
    if os.path.isdir(man):
        for f in sorted(os.listdir(man)):
            if f.endswith('.md'):
                yield os.path.join(man, f)


def verificar(raiz):
    achados = []
    for c in arquivos(raiz):
        if any(x in c for x in FORA) or not os.path.isfile(c):
            continue
        try:
            with open(c, encoding='utf-8') as f:
                texto = f.read()
        except (UnicodeDecodeError, OSError):
            continue
        if c.endswith(('.qml', '.js')):
            itens = literais_qml(texto)
        elif c.endswith('.py') or texto.startswith('#!/usr/bin/python') or texto.startswith('#!/usr/bin/env python'):
            itens = literais_py(texto)
        elif c.endswith('.desktop'):
            itens = texto_desktop(texto)
        elif c.endswith('.md'):
            itens = texto_md(texto)
        elif texto.startswith('#!/bin/sh') or texto.startswith('#!/bin/bash') or c.endswith('.sh'):
            itens = literais_sh(texto)
        else:
            continue
        linhas = texto.splitlines()
        for n, s in itens:
            if IDENT.match(s.strip()) or (0 < n <= len(linhas) and 'ptbr-ok' in linhas[n - 1]):
                continue
            for m in PADRAO.finditer(s):
                chave = next((k for k in PALAVRAS if re.fullmatch(k, m.group(0), re.I)), None)
                achados.append((c, n, m.group(0), PALAVRAS.get(chave, ''), s.strip()))
            for m in list(GERUNDIO.finditer(s)) + list(ROTULO.finditer(s)):
                achados.append((c, n, m.group(0), 'gerúndio (ex.: "está fazendo")', s.strip()))
    return achados


if __name__ == '__main__':
    raiz = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    achados = verificar(raiz)
    for c, n, palavra, troca, s in achados:
        print('%s:%d: «%s» → %s   | %s' % (os.path.relpath(c, raiz), n, palavra, troca, s[:110]))
    print('%d ocorrência(s) de português de Portugal no texto que o usuário vê.' % len(achados) if achados
          else 'Português do Brasil: tudo certo.')
    sys.exit(1 if achados else 0)
