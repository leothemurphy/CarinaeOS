# CarinaeOS — brilho por software em todos os monitores (quando a tela não tem luz de fundo controlável,
# como num computador de mesa). O mesmo da central de ajustes da Aurora.
import os
import subprocess

CASA = os.path.expanduser('~')
CFG = os.path.join(CASA, '.config', 'carinaeos')


# brilho por software em todos os monitores (o mesmo da central de ajustes da Aurora)
def brilho():
    try:
        return max(0.3, min(1.0, float(open(os.path.join(CFG, 'brilho')).read().strip())))
    except (OSError, ValueError):
        return 1.0


def definir_brilho(v):
    v = max(0.3, min(1.0, v))
    try:
        luz = open(os.path.join(CFG, 'luz-noturna')).read().strip() == '1'
    except OSError:
        luz = False
    gama = '1.0:0.84:0.66' if luz else '1:1:1'
    os.makedirs(CFG, exist_ok=True)
    with open(os.path.join(CFG, 'brilho'), 'w') as f:
        f.write('%.2f\n' % v)
    subprocess.Popen(['sh', '-c', "for o in $(xrandr --query | awk '/ connected/{print $1}'); do "
                      "xrandr --output \"$o\" --gamma %s --brightness %.2f; done" % (gama, v)],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
