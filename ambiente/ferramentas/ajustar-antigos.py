#!/usr/bin/env python3
# CarinaeOS — os apps antigos (de /usr/share/carinaeos, do tempo do Plasma) deixam de chamar o KDE.
# Idempotente: só troca o que ainda lá estiver.
import os

TROCAS = {
    '/usr/share/carinaeos/atualizacoes/atualizacoes.py': [
        ("subprocess.Popen(['qdbus6', 'org.kde.LogoutPrompt', '/LogoutPrompt', 'promptReboot'], start_new_session=True)",
         "subprocess.Popen(['carinae-sessao', 'reiniciar'], start_new_session=True)"),
    ],
}

for f, trocas in TROCAS.items():
    try:
        s = open(f, encoding='utf-8').read()
    except OSError:
        continue
    novo = s
    for a, b in trocas:
        novo = novo.replace(a, b)
    if novo != s:
        open(f, 'w', encoding='utf-8').write(novo)
        print('  ajustado:', f)
