#!/usr/bin/python3
# CarinaeOS - os papeis de parede (4K), no estilo do Ubuntu: uma cor so, em degradê com profundidade,
# e a estrela e o nome CarinaeOS afundados no meio. Gerados por codigo (a marca vem de marca-mascara.png).
#   2 escuros (Ameixa, Grafite) e 2 claros (Pessego, Nevoa). O padrao e o "Ameixa".
# Uso: fundos.py PASTA_RAIZ_DO_SISTEMA
# Cria /usr/share/wallpapers/CarinaeOS-*/ (Plasma), /usr/share/wallpapers/CarinaeOS (o padrao, usado tambem
# na entrada, no arranque e no GRUB), /usr/share/backgrounds/carinaeos/ e o XML do GNOME.
import json
import os
import sys

import numpy as np
from PIL import Image, ImageFilter

W, H = 3840, 2160
PADRAO = 'Ameixa'
AQUI = os.path.dirname(os.path.abspath(__file__))

# (pasta, nome, descricao, cor, escuro)
FUNDOS = [
    ('Ameixa', 'Ameixa', 'Escuro: ameixa.', '#4a1a45', True),
    ('Grafite', 'Grafite', 'Escuro: grafite.', '#2a2c33', True),
    ('Pessego', 'Pêssego', 'Claro: pêssego.', '#f2c9a6', False),
    ('Nevoa', 'Névoa', 'Claro: cinza-azulado.', '#dde1ea', False),
]


def _cor(h):
    h = h.lstrip('#')
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255


def _caixa(a, k, eixo):
    """media movel de largura 2k+1 ao longo de um eixo (com cumsum: rapido para qualquer k)."""
    p = [(0, 0), (0, 0)]
    p[eixo] = (k + 1, k)
    c = np.cumsum(np.pad(a, p, mode='edge'), axis=eixo, dtype=np.float64)
    n = a.shape[eixo]
    fim = np.take(c, np.arange(2 * k + 1, 2 * k + 1 + n), axis=eixo)
    ini = np.take(c, np.arange(0, n), axis=eixo)
    return ((fim - ini) / (2 * k + 1)).astype(np.float32)


def _borrar(a, r):
    """desfoque quase gaussiano (tres caixas) de raio r, em ponto flutuante (sem degraus no relevo)."""
    k = max(1, int(round(r * 0.9)))
    for _ in range(3):
        a = _caixa(_caixa(a, k, 0), k, 1)
    return a


def desenhar(cor, escuro, w=W, h=H):
    """uma cor so, em degradê, com a estrela e o nome CarinaeOS afundados no meio (como os fundos do Ubuntu)."""
    c = _cor(cor)
    # degradê da mesma cor, com profundidade: mais clara no centro (um pouco acima), escurecendo
    # para os cantos e para baixo, e um véu diagonal suave (dá a sensação de superfície curva)
    q = 4
    y, x = np.mgrid[0:h // q, 0:w // q].astype(np.float32)
    x /= w // q
    y /= h // q
    r = np.sqrt(((x - 0.5) * 1.25) ** 2 + (y - 0.40) ** 2)
    prof = 1.16 - 0.55 * np.clip(r, 0, 1) ** 1.4 - 0.10 * y
    prof += 0.06 * np.exp(-((x - y * 0.9 - 0.15) / 0.22) ** 2)
    if not escuro:
        prof = 1 + (prof - 1) * 0.45          # nos claros, o degradê é mais leve
    prof = np.asarray(Image.fromarray(prof.astype(np.float32), 'F').resize((w, h), Image.BICUBIC), dtype=np.float32)
    img = np.clip(c[None, None, :] * prof[..., None], 0, 1)
    mk = Image.open(os.path.join(AQUI, 'marca-mascara.png'))
    lw = int(w * 0.30)
    lh = int(mk.size[1] * lw / mk.size[0])
    m = np.asarray(mk.resize((lw, lh), Image.LANCZOS), dtype=np.float32) / 255
    pad = lh // 2
    M = np.zeros((lh + 2 * pad, lw + 2 * pad), np.float32)
    M[pad:pad + lh, pad:pad + lw] = m
    x0 = w // 2 - M.shape[1] // 2
    y0 = h // 2 - M.shape[0] // 2
    reg = img[y0:y0 + M.shape[0], x0:x0 + M.shape[1]]
    # afundado: a face um pouco mais escura; por dentro, sombra na borda de cima/esquerda
    # e um fio claro na de baixo/direita (sem brilho nem luz no resto do fundo)
    alt = _borrar(M, lh * 0.020)
    gy, gx = np.gradient(alt)
    borda = np.clip((gx + gy) * lh * 0.05, -1, 1) * M
    sombra = np.clip(borda, 0, 1)[..., None]
    fio = np.clip(-borda, 0, 1)[..., None]
    face = reg * (0.86 if escuro else 0.93)
    reg = reg * (1 - M[..., None]) + face * M[..., None]
    reg = reg * (1 - sombra * (0.60 if escuro else 0.30))
    reg = reg + (1 - reg) * fio * (0.16 if escuro else 0.45)
    img[y0:y0 + M.shape[0], x0:x0 + M.shape[1]] = reg
    img = np.clip(img, 0, 1) * 255
    grao = np.random.default_rng(7).normal(0, 1.2, (h, w, 1)).astype(np.float32)   # sem faixas no degradê
    return Image.fromarray(np.clip(img + grao, 0, 255).round().astype(np.uint8))


def _gravar(base, im, ident, nome, desc):
    imgs = os.path.join(base, 'contents/images')
    os.makedirs(imgs, exist_ok=True)
    for n in os.listdir(imgs):
        os.remove(os.path.join(imgs, n))
    for (lw, lh) in ((3840, 2160), (2560, 1440), (1920, 1080)):
        (im if lw == W else im.resize((lw, lh), Image.LANCZOS)).save(
            os.path.join(imgs, '%dx%d.jpg' % (lw, lh)), quality=93, optimize=True)
    im.resize((400, 225), Image.LANCZOS).save(os.path.join(base, 'contents/screenshot.jpg'), quality=88)
    with open(os.path.join(base, 'metadata.json'), 'w', encoding='utf-8') as f:
        json.dump({'KPackageStructure': 'Wallpaper/Images',
                   'KPlugin': {'Id': ident, 'Name': nome, 'Description': desc, 'License': 'CC-BY-SA-4.0',
                               'Authors': [{'Name': 'CarinaeOS'}]}}, f, ensure_ascii=False, indent=2)


def main():
    raiz = sys.argv[1]
    papeis = os.path.join(raiz, 'usr/share/wallpapers')
    bg = os.path.join(raiz, 'usr/share/backgrounds/carinaeos')
    marca = os.path.join(raiz, 'usr/share/carinaeos/marca')
    os.makedirs(bg, exist_ok=True)
    os.makedirs(marca, exist_ok=True)
    lista = []
    for pasta, nome, desc, cor, escuro in FUNDOS:
        im = desenhar(cor, escuro)
        _gravar(os.path.join(papeis, 'CarinaeOS-' + pasta), im, 'CarinaeOS-' + pasta, nome, desc)
        lig = os.path.join(bg, pasta + '.jpg')
        if os.path.lexists(lig):
            os.remove(lig)
        os.symlink('/usr/share/wallpapers/CarinaeOS-%s/contents/images/3840x2160.jpg' % pasta, lig)
        lista.append((nome, '/usr/share/backgrounds/carinaeos/%s.jpg' % pasta))
        if pasta == PADRAO:
            # o padrao do CarinaeOS (area de trabalho, bloqueio, entrada, arranque e GRUB)
            _gravar(os.path.join(papeis, 'CarinaeOS'), im, 'CarinaeOS', 'CarinaeOS — ' + nome, desc)
            im.resize((1920, 1080), Image.LANCZOS).save(os.path.join(marca, 'grub.png'), optimize=True)
            # banner das janelas de senha e fundo desfocado da tela de entrada
            im.crop((0, int(H * 0.42), W, int(H * 0.42) + 1102)).resize((920, 264), Image.LANCZOS).save(
                os.path.join(marca, 'banner-senha.jpg'), quality=88)
            im.resize((1920, 1080), Image.LANCZOS).filter(ImageFilter.GaussianBlur(28)).save(
                os.path.join(marca, 'fundo-desfocado.jpg'), quality=85)
        print('fundo', pasta, flush=True)
    gbp = os.path.join(raiz, 'usr/share/gnome-background-properties')
    os.makedirs(gbp, exist_ok=True)
    with open(os.path.join(gbp, 'carinaeos.xml'), 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">\n<wallpapers>\n')
        for nome, cam in lista:
            f.write('  <wallpaper deleted="false">\n    <name>%s</name>\n    <filename>%s</filename>\n'
                    '    <options>zoom</options>\n    <shade_type>solid</shade_type>\n  </wallpaper>\n' % (nome, cam))
        f.write('</wallpapers>\n')


if __name__ == '__main__':
    main()
