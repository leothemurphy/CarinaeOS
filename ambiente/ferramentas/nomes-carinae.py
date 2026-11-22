#!/usr/bin/env python3
# CarinaeOS — todos os nossos apps com o nome "Carinae …" (Carinae Calculadora, Carinae Notas…).
# Corre sobre os atalhos (.desktop) que já estão instalados e que são nossos.
#   python3 nomes-carinae.py [--ver] PASTA…     (--ver só mostra o que mudaria)
import os
import re
import sys

# atalhos que embrulham programas de outros (não são nossos): não se mexe
DE_OUTROS = re.compile(r'electron|windows|appimage|vault3d|wine|web-|chrome|steam', re.I)


# nomes já pensados (o resto fica "Carinae " + o nome de antes)
NOMES = {
    'Central CarinaeOS': 'Carinae Central',
    'Manual do CarinaeOS': 'Carinae Manual',
    'Forçar o encerramento': 'Carinae Forçar encerramento',
    'Aparência do Terminal': 'Aparência do Carinae Terminal',
    'Monitor do sistema': 'Carinae Monitor',
    'Leitor de PDF': 'Carinae PDF',
    'Pulsar Player': 'Carinae Pulsar',
}


def nosso(nome, txt):
    if not re.match(r'carinae(os)?[-_.]', nome) or DE_OUTROS.search(nome):
        return False
    m = re.search(r'^Exec=(.*)$', txt, re.M)
    exe = m.group(1) if m else ''
    return bool(re.search(r'carinae|aurora|/carinaeos/', exe)) and not DE_OUTROS.search(exe)


def tratar(caminho, so_ver):
    try:
        txt = open(caminho, encoding='utf-8').read()
    except (OSError, UnicodeDecodeError):
        return
    nome = os.path.basename(caminho)
    principal, _, resto = txt.partition('\n[Desktop Action')
    if not nosso(nome, principal) or re.search(r'^NoDisplay=true', principal, re.M | re.I):
        return
    m = re.search(r'^Name=(.*)$', principal, re.M)
    if not m:
        return
    atual = m.group(1).strip()
    if atual in NOMES:
        novo = NOMES[atual]
    elif 'carinae' in atual.lower():
        return
    else:
        novo = 'Carinae ' + atual
    if novo == atual:
        return
    principal = principal[:m.start()] + 'Name=' + novo + principal[m.end():]
    # as traduções antigas do nome (Name[pt_BR]=…) também passam a ter o prefixo
    principal = re.sub(r'^Name\[[^\]]+\]=.*\n?', '', principal, flags=re.M)
    print('  %s: %s → %s' % (nome, atual, novo))
    if not so_ver:
        with open(caminho, 'w', encoding='utf-8') as f:
            f.write(principal + ('\n[Desktop Action' + resto if resto else ''))


def main():
    so_ver = '--ver' in sys.argv
    for pasta in [a for a in sys.argv[1:] if not a.startswith('--')]:
        try:
            nomes = sorted(os.listdir(pasta))
        except OSError:
            continue
        for n in nomes:
            if n.endswith('.desktop'):
                tratar(os.path.join(pasta, n), so_ver)


if __name__ == '__main__':
    main()
