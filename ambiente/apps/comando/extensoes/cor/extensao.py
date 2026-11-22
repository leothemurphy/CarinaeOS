import colorsys
import re


def procurar(texto, ctx):
    t = texto.strip()
    m = re.fullmatch(r'#?([0-9a-fA-F]{6}|[0-9a-fA-F]{3})', t)
    if m:
        h = m.group(1)
        if len(h) == 3:
            h = ''.join(c * 2 for c in h)
        r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    else:
        n = [int(x) for x in re.findall(r'\d+', t)][:3]
        if len(n) != 3 or max(n) > 255:
            return [dict(titulo='Escreva uma cor: #ffb46e ou 255 180 110', icone='color-picker', acao='completar', valor='cor ')]
        r, g, b = n
    hx = '#%02x%02x%02x' % (r, g, b)
    hh, ll, ss = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    hsl = 'hsl(%d, %d%%, %d%%)' % (hh * 360, ss * 100, ll * 100)
    rgb = 'rgb(%d, %d, %d)' % (r, g, b)
    return [dict(titulo=v, sub='Enter copia', icone='color-picker', acao='copiar', valor=v) for v in (hx, rgb, hsl)]
