# CarinaeOS - papeis de parede originais, desenhados por codigo em qualquer resolucao (8K por omissao).
# As formas sao calculadas suaves (a 1/4 da resolucao e ampliadas) e o grao fino e posto na resolucao final.
import math

import numpy as np
from PIL import Image, ImageFilter


def _grade(w, h):
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    return x / w, y / h


def _cor(hexa):
    hexa = hexa.lstrip('#')
    return np.array([int(hexa[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def _degrade(t, cores):
    """t (0..1) -> cor interpolada entre varias cores."""
    t = np.clip(t, 0, 1)
    n = len(cores) - 1
    i = np.minimum((t * n).astype(int), n - 1)
    f = (t * n - i)[..., None]
    c = np.array([_cor(x) for x in cores])
    return c[i] * (1 - f) + c[i + 1] * f


def _misturar(base, cor, alfa):
    return base * (1 - alfa[..., None]) + _cor(cor) * alfa[..., None] if isinstance(cor, str) else base * (1 - alfa[..., None]) + cor * alfa[..., None]


def _suave(x, borda):
    return np.clip(x / borda, 0, 1) ** 2 * (3 - 2 * np.clip(x / borda, 0, 1))


def dunas(w, h):
    x, y = _grade(w, h)
    img = _degrade(y * 0.9 + 0.05 * np.sin(x * 3), ['#2a1640', '#7a2f6b', '#e0647a', '#ffb46e'])
    camadas = [('#ffcf9a', 0.32, 0.06, 1.3, 0.0), ('#f08a6c', 0.45, 0.07, 1.7, 1.1), ('#c4507a', 0.58, 0.08, 1.1, 2.3),
               ('#7d2f78', 0.72, 0.07, 1.9, 0.7), ('#3b1d5c', 0.86, 0.06, 1.4, 3.1)]
    for cor, base, amp, freq, fase in camadas:
        borda = base + amp * np.sin(x * math.pi * freq + fase) + amp * 0.4 * np.sin(x * math.pi * freq * 2.7 + fase * 2)
        dentro = _suave(y - borda, 0.012)
        tom = _cor(cor) * (0.82 + 0.25 * (1 - np.clip((y - borda) * 4, 0, 1)))[..., None]
        img = img * (1 - dentro[..., None]) + tom * dentro[..., None]
    sol = np.exp(-(((x - 0.72) * 1.8) ** 2 + ((y - 0.22) * 3.2) ** 2) * 6)
    return _misturar(img, '#fff1d6', sol * 0.55)


def aurora(w, h):
    x, y = _grade(w, h)
    img = _degrade(y, ['#05060f', '#0a1030', '#101a3a', '#1a1033'])
    for cor, centro, larg, freq, fase, forca in [('#3dffb0', 0.38, 0.06, 2.2, 0.3, 0.75), ('#36d1ff', 0.30, 0.05, 1.6, 1.7, 0.5),
                                                  ('#b36bff', 0.46, 0.07, 1.3, 2.9, 0.55), ('#ff6f91', 0.52, 0.04, 2.8, 4.1, 0.3)]:
        c = centro + 0.12 * np.sin(x * math.pi * freq + fase) + 0.04 * np.sin(x * math.pi * freq * 3.1 + fase)
        d = (y - c) / larg
        fita = np.exp(-d ** 2) * (0.6 + 0.4 * np.sin(x * 13 + fase) ** 2)
        cortina = np.where(d < 0, np.exp(-(d / 4) ** 2), np.exp(-d ** 2))
        img = _misturar(img, cor, np.clip((fita * 0.7 + cortina * 0.25) * forca, 0, 1))
    chao = _suave(y - (0.86 + 0.03 * np.sin(x * 9) + 0.015 * np.sin(x * 27)), 0.004)
    return img * (1 - chao[..., None]) + _cor('#03040a') * chao[..., None]


def horizonte(w, h):
    x, y = _grade(w, h)
    img = _degrade(y * 1.15, ['#1c0f3a', '#5b2a86', '#d0567a', '#ff9f6b', '#ffd59a'])
    sol = np.sqrt(((x - 0.5) * (w / h)) ** 2 + ((y - 0.6) * 1.0) ** 2)
    img = _misturar(img, '#fff0c8', np.clip(1 - sol / 0.09, 0, 1) ** 0.6)
    img = _misturar(img, '#ffb46e', np.exp(-(sol / 0.35) ** 2) * 0.35)
    for cor, base, amp, freq, fase in [('#6a2c6e', 0.62, 0.05, 4.0, 0.4), ('#47205a', 0.70, 0.06, 3.0, 1.9),
                                       ('#2b1540', 0.79, 0.05, 5.0, 2.7), ('#170b24', 0.88, 0.04, 2.0, 0.9)]:
        serra = (0.55 * np.sin(x * math.pi * freq + fase) + 0.3 * np.sin(x * math.pi * freq * 2.7 + fase * 1.7)
                 + 0.15 * np.sin(x * math.pi * freq * 7.3 + fase * 3.1))
        borda = base - amp * (1 + serra)
        dentro = _suave(y - borda, 0.003)
        img = img * (1 - dentro[..., None]) + _cor(cor) * dentro[..., None]
    return img


def oceano(w, h):
    x, y = _grade(w, h)
    img = _degrade(y, ['#03122b', '#0a2f5c', '#0f5b8f', '#1e8fb5'])
    for i, (cor, base) in enumerate([('#5fd0e6', 0.35), ('#2fa3c9', 0.48), ('#1a77a8', 0.62), ('#0e4f85', 0.76), ('#082f57', 0.9)]):
        borda = base + 0.05 * np.sin(x * math.pi * (1.4 + i * 0.35) + i * 1.3) + 0.02 * np.sin(x * math.pi * 6 + i)
        dentro = _suave(y - borda, 0.01)
        brilho = np.exp(-((y - borda) / 0.01) ** 2) * 0.4
        img = img * (1 - dentro[..., None]) + _cor(cor) * dentro[..., None]
        img = _misturar(img, '#d7f6ff', brilho)
    return img


def lavanda(w, h):
    x, y = _grade(w, h)
    img = np.zeros((h, w, 3), np.float32) + _cor('#f3e9f7')
    for cor, cx, cy, r in [('#c9b6ff', 0.2, 0.25, 0.45), ('#ffc6d9', 0.8, 0.2, 0.40), ('#ffe2b8', 0.65, 0.8, 0.45),
                           ('#b8e1ff', 0.15, 0.85, 0.40), ('#e9c2ff', 0.5, 0.5, 0.35)]:
        d = np.sqrt(((x - cx) * (w / h)) ** 2 + (y - cy) ** 2) / r
        img = _misturar(img, cor, np.exp(-d ** 2) * 0.85)
    return img


def grafite(w, h):
    x, y = _grade(w, h)
    img = _degrade(y, ['#121016', '#18141f', '#0e0c12'])
    d = np.sqrt(((x - 0.7) * (w / h)) ** 2 + (y - 0.35) ** 2)
    img = _misturar(img, '#ff6f91', np.exp(-(d / 0.45) ** 2) * 0.22)
    img = _misturar(img, '#ffb46e', np.exp(-(d / 0.2) ** 2) * 0.18)
    return img


DESENHOS = {
    'Dunas': (dunas, 'Dunas de cor ao pôr do sol, nos tons do CarinaeOS.'),
    'Aurora': (aurora, 'Aurora boreal sobre a noite.'),
    'Horizonte': (horizonte, 'Montanhas em camadas e o sol a nascer.'),
    'Oceano': (oceano, 'Ondas em camadas, do turquesa ao azul profundo.'),
    'Lavanda': (lavanda, 'Tons pastel suaves (para quem prefere claro).'),
    'Grafite': (grafite, 'Escuro e minimalista, com um brilho rosado.'),
}


def desenhar(nome, w=7680, h=4320, estrelas=False):
    funcao = DESENHOS[nome][0]
    pw, ph = max(480, w // 4), max(270, h // 4)
    pequeno = np.clip(funcao(pw, ph), 0, 255).astype(np.uint8)
    img = Image.fromarray(pequeno, 'RGB').resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(radius=w / 3000))
    a = np.asarray(img).astype(np.int16)
    rng = np.random.default_rng(7)
    grao = rng.normal(0, 2.2, (h, w, 1)).astype(np.int16)    # grao fino: evita faixas no degrade
    a = np.clip(a + grao, 0, 255).astype(np.uint8)
    if nome in ('Aurora', 'Grafite'):                          # estrelas finas, na resolucao final
        n = int(w * h / 9000)
        ys = rng.integers(0, int(h * (0.8 if nome == 'Aurora' else 1.0)), n)
        xs = rng.integers(0, w, n)
        v = rng.uniform(90, 255, n).astype(np.uint8)
        a[ys, xs] = np.maximum(a[ys, xs], v[:, None])
    return Image.fromarray(a, 'RGB')
