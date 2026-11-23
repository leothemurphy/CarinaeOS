#!/usr/bin/env python3
# CarinaeOS — Carinae Arquivos ("Meus documentos"): no CarinaeOS o papel de parede vai para a Aurora
# (antes chamava o plasma-apply-wallpaperimage, que só funciona no Plasma). Idempotente; guarda cópia.
import os
import shutil
import sys
import time

F = sys.argv[1] if len(sys.argv) > 1 else '/usr/share/carinaeos/arquivos/arquivos.py'
try:
    s = open(F, encoding='utf-8').read()
except OSError:
    print('  (não encontrei %s — nada a ajustar)' % F)
    sys.exit(0)
A = """        try:
            subprocess.Popen(['plasma-apply-wallpaperimage', imagem], start_new_session=True)"""
B = """        try:
            if os.environ.get('XDG_CURRENT_DESKTOP', '').startswith('CarinaeOS'):
                # a Aurora lê o papel de parede de ~/.config/carinaeos-shell.json (e vê a mudança na hora)
                cfg = os.path.join(HOME, '.config', 'carinaeos-shell.json')
                try:
                    j = json.load(open(cfg, encoding='utf-8'))
                except (OSError, ValueError):
                    j = {}
                j['papel'] = imagem
                with open(cfg + '.tmp', 'w', encoding='utf-8') as f:
                    json.dump(j, f, ensure_ascii=False, indent=1)
                os.replace(cfg + '.tmp', cfg)
            else:
                subprocess.Popen(['plasma-apply-wallpaperimage', imagem], start_new_session=True)"""
if B in s:
    print('  Carinae Arquivos já estava ajustado')
    sys.exit(0)
if A not in s:
    print('  aviso: não encontrei o trecho do papel de parede no Carinae Arquivos')
    sys.exit(0)
n = s.replace(A, B, 1)
try:
    compile(n, F, 'exec')
except SyntaxError as e:
    print('  ERRO: o ajuste ao Carinae Arquivos não ficou válido (%s) — não mexi' % e)
    sys.exit(0)
shutil.copy2(F, F + '.antes-carinae-' + time.strftime('%Y%m%d-%H%M%S'))
open(F, 'w', encoding='utf-8').write(n)
print('  Carinae Arquivos ajustado (papel de parede da Aurora)')
