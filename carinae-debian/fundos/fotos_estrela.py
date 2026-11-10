#!/usr/bin/python3
# CarinaeOS - papeis de parede "Estrela": fotografias reais do ceu do deserto do Atacama
# (ESO, CC BY 4.0) com a estrela do CarinaeOS a brilhar no ceu, como uma estrela de verdade.
#
#   fotos_estrela.py <pasta destino> <cache> [--previa]
#
# A estrela e desenhada fisicamente (nucleo, halo, raios de difracao e o anel orbital do
# logotipo como um halo de luz) e misturada com a foto em modo "ecra" (screen), por isso
# fica com o grao, as cores e a luz da propria fotografia.
import os
import sys
import urllib.request

import numpy as np
from PIL import Image, ImageFilter

FOTOS = [
    # id ESO, nome, posicao da estrela (x, y em fracao), tamanho, rotacao do anel, credito, ajuste de cor
    dict(id='uhd_beletsky_alma_04', nome='Atacama', pos=(0.70, 0.30), tam=0.11, anel=-22,
         credito='ESO/Y. Beletsky', tom=(1.00, 1.00, 1.08), corte=(0.0, 0.10)),
    dict(id='colosimo-130704-004', nome='Paranal', pos=(0.30, 0.20), tam=0.10, anel=-18,
         credito='John Colosimo (colosimophotography.com)/ESO', tom=(1.00, 0.99, 1.06), corte=(0.0, 0.0)),
    dict(id='uhd_malin3_cc', nome='Via Lactea', pos=(0.76, 0.22), tam=0.10, anel=-28,
         credito='ESO/D. Malin', tom=(1.02, 1.00, 1.04), corte=(0.0, 0.08)),
    dict(id='jordibusque_4220-cc', nome='Observatorio', pos=(0.78, 0.18), tam=0.09, anel=-20,
         credito='J. Busqué/ESO', tom=(1.00, 1.00, 1.07), corte=(0.0, 0.10)),
]
URL = 'https://cdn.eso.org/images/large/%s.jpg'


def baixar(cache, ident):
    os.makedirs(cache, exist_ok=True)
    f = os.path.join(cache, 'eso-%s.jpg' % ident)
    if not os.path.exists(f) or os.path.getsize(f) < 100000:
        urllib.request.urlretrieve(URL % ident, f + '.parte')
        os.replace(f + '.parte', f)
    return f


def cortar_16_9(im, corte):
    w, h = im.size
    alvo = w * 9 / 16
    if alvo <= h:
        sobra = h - alvo
        top = int(sobra * (0.5 + corte[1]))
        top = max(0, min(int(sobra), top))
        return im.crop((0, top, w, top + int(alvo)))
    nw = h * 16 / 9
    left = int((w - nw) / 2)
    return im.crop((left, 0, left + int(nw), h))


def graduar(a, tom):
    """Cor de cinema: pretos profundos, ceu ligeiramente azul-violeta, horizonte quente."""
    a = a / 255.0
    h = a.shape[0]
    y = np.linspace(0, 1, h)[:, None, None]
    # curva em S suave
    a = np.clip(a, 0, 1)
    a = a ** 1.06
    a = a * a * (3 - 2 * a) * 0.35 + a * 0.65
    # ceu (em cima) mais frio, chao (em baixo) mais quente
    frio = np.array([0.97, 0.99, 1.10]) * np.array(tom)
    quente = np.array([1.07, 1.00, 0.92])
    mistura = np.clip((y - 0.45) / 0.4, 0, 1)
    a = a * (frio * (1 - mistura) + quente * mistura)
    # saturacao um pouco maior
    cinza = a.mean(axis=2, keepdims=True)
    a = cinza + (a - cinza) * 1.18
    # vinheta discreta
    hh, ww = a.shape[:2]
    yy, xx = np.mgrid[0:hh, 0:ww]
    d = ((xx / ww - 0.5) ** 2 * 1.2 + (yy / hh - 0.45) ** 2) ** 0.5
    a = a * (1 - 0.28 * np.clip(d - 0.3, 0, 1) ** 1.5)[:, :, None]
    return np.clip(a, 0, 1)


def estrela(w, h, cx, cy, r, anel_graus):
    """Luz da estrela CarinaeOS (RGB, 0..alguns) para somar em modo ecra."""
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx, dy = (xx - cx) / r, (yy - cy) / r
    d = np.sqrt(dx * dx + dy * dy) + 1e-6
    luz = np.zeros((h, w, 3), np.float32)
    branco = np.array([1.0, 0.97, 0.92])
    ambar = np.array([1.0, 0.70, 0.43])
    rosa = np.array([0.88, 0.27, 0.49])
    # nucleo e halo
    luz += np.exp(-(d / 0.035) ** 2)[..., None] * branco * 2.2
    luz += np.exp(-(d / 0.11) ** 2)[..., None] * (branco * 0.5 + ambar * 0.6)
    luz += (0.22 / (1 + (d / 0.18) ** 2.2))[..., None] * ambar
    luz += (0.10 / (1 + (d / 0.55) ** 2))[..., None] * rosa
    # os 4 raios principais (forma da estrela do logotipo): finos e longos
    for ang, comp, forca in ((0, 1.0, 1.0), (90, 1.15, 1.0), (45, 0.42, 0.45), (135, 0.42, 0.45)):
        t = np.deg2rad(ang)
        u = dx * np.cos(t) + dy * np.sin(t)
        v = -dx * np.sin(t) + dy * np.cos(t)
        largura = 0.010 + 0.012 * np.exp(-np.abs(u) / 0.08)
        raio = np.exp(-(v / largura) ** 2) * np.exp(-np.abs(u) / (0.33 * comp)) * forca
        cor = branco * np.exp(-np.abs(u) / 0.25)[..., None] + ambar * (1 - np.exp(-np.abs(u) / 0.25))[..., None]
        luz += raio[..., None] * cor * 1.3
    # o anel orbital do logotipo, como um halo de luz inclinado (azul-verde -> violeta)
    t = np.deg2rad(anel_graus)
    u = dx * np.cos(t) + dy * np.sin(t)
    v = -dx * np.sin(t) + dy * np.cos(t)
    A, B = 0.95, 0.21
    e = np.sqrt((u / A) ** 2 + (v / B) ** 2)
    banda = np.exp(-((e - 1.0) / 0.035) ** 2)
    frente = np.clip(0.5 + v / B * 0.6, 0.15, 1.0)         # metade da frente mais brilhante
    s = np.clip((u / A + 1) / 2, 0, 1)[..., None]
    cor_anel = (1 - s) * np.array([0.22, 0.83, 0.78]) + s * np.array([0.48, 0.36, 1.0])
    luz += (banda * frente * 0.55)[..., None] * cor_anel
    luz += (np.exp(-((e - 1.0) / 0.12) ** 2) * frente * 0.10)[..., None] * cor_anel
    return luz


def compor(foto, f, largura):
    im = cortar_16_9(Image.open(foto).convert('RGB'), f['corte'])
    altura = largura * 9 // 16
    if im.width < largura:
        im = im.resize((largura, altura), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=2, percent=40, threshold=2))
    else:
        im = im.resize((largura, altura), Image.LANCZOS)
    a = graduar(np.asarray(im, dtype=np.float32), f['tom'])
    cx, cy = f['pos'][0] * largura, f['pos'][1] * altura
    r = f['tam'] * largura
    # so calcula a luz num quadrado a volta da estrela (rapido em 8K)
    m = int(r * 1.6)
    x0, x1 = max(0, int(cx - m)), min(largura, int(cx + m))
    y0, y1 = max(0, int(cy - m)), min(altura, int(cy + m))
    luz = estrela(x1 - x0, y1 - y0, cx - x0, cy - y0, r, f['anel'])
    # escurecer um pouco o ceu a volta: a estrela destaca-se
    sub = a[y0:y1, x0:x1]
    sub = 1 - (1 - sub) * (1 - np.clip(luz, 0, 1))                # ecra
    sub = np.clip(sub + np.clip(luz - 1, 0, None) * 0.25, 0, 1)
    a[y0:y1, x0:x1] = sub
    # grao fino para nao parecer colado
    a += np.random.default_rng(7).normal(0, 0.006, a.shape[:2])[..., None]
    return Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8))


def principal():
    destino, cache = sys.argv[1], sys.argv[2]
    previa = '--previa' in sys.argv
    os.makedirs(destino, exist_ok=True)
    for f in FOTOS:
        try:
            foto = baixar(cache, f['id'])
        except Exception as e:
            print('AVISO: sem a foto %s (%s)' % (f['id'], e))
            continue
        largura = 1920 if previa else 7680
        im = compor(foto, f, largura)
        nome = 'Estrela-' + f['nome'].replace(' ', '')
        im.save(os.path.join(destino, nome + '.jpg'), quality=93 if not previa else 88)
        with open(os.path.join(destino, nome + '.credito'), 'w') as c:
            c.write('Foto: %s (CC BY 4.0). Estrela: CarinaeOS.\n' % f['credito'])
        print('fundo', nome, im.size)


if __name__ == '__main__':
    principal()
