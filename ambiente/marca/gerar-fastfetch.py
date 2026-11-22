import sys, subprocess
from PIL import Image
W=int(sys.argv[1]); H=W  # pixels (H/2 linhas de texto)
subprocess.run(['rsvg-convert','-w',str(W*4),'-h',str(H*4),'logo-ff.svg','-o','big.png'],check=True)
im=Image.open('big.png').convert('RGBA')
# recortar à caixa útil
bb=im.getbbox(); im=im.crop(bb)
w,h=im.size; esc=W/ max(w,h)
nw,nh=round(w*esc), round(h*esc)
# terminais: célula ~1:2 -> cada linha = 2 pixels; píxeis quadrados com meio-bloco
im=im.resize((nw, nh + nh%2), Image.LANCZOS)
px=im.load(); w,h=im.size
def cor(p):
    r,g,b,a=p
    if a<60: return None
    k=min(1,a/180); F=(22,19,32)   # misturar o meio-transparente com um fundo escuro
    return tuple(round(c*k+f*(1-k)) for c,f in zip((r,g,b),F))
linhas=[]
for y in range(0,h,2):
    l=''; ult=None
    for x in range(w):
        t=cor(px[x,y]); b=cor(px[x,y+1]) if y+1<h else None
        if t is None and b is None: l+='\x1b[0m '; continue
        if t and b: l+=f'\x1b[38;2;{t[0]};{t[1]};{t[2]}m\x1b[48;2;{b[0]};{b[1]};{b[2]}m▀\x1b[0m'
        elif t: l+=f'\x1b[38;2;{t[0]};{t[1]};{t[2]}m▀\x1b[0m'
        else: l+=f'\x1b[38;2;{b[0]};{b[1]};{b[2]}m▄\x1b[0m'
    linhas.append(l.rstrip()+'\x1b[0m')
open('fastfetch-logo.ans','w').write('\n'.join(linhas)+'\n')
print(w, len(linhas))
