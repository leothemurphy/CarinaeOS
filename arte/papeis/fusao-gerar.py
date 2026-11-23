import numpy as np, math, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont
S=2; W,H=3840*S,2160*S; rng=np.random.default_rng(7); random.seed(7)
# fundo: grafite à esquerda, castanho quente à direita, vinheta
x=np.linspace(0,1,W,dtype=np.float32)[None,:]; y=np.linspace(0,1,H,dtype=np.float32)[:,None]
c1=np.array([18,18,26.],np.float32); c2=np.array([58,36,30.],np.float32)
t=np.clip((x*0.85+ (1-y)*0.15),0,1)**1.4
bg=c1*(1-t)[...,None]+c2*t[...,None]
vin=1-0.55*(((x-0.55)**2)*1.6+((y-0.5)**2)*2.2); bg*=np.clip(vin,0.35,1)[...,None]
# brilho do chão
floor=np.exp(-(((x-0.52)/0.22)**2+((y-0.9)/0.035)**2))[...,None]*np.array([255,150,60.],np.float32)*0.35
img=bg+floor; del bg, floor
CX,CY=0.53*W,0.53*H
def campo(px,py,k):
    u=(px-CX)/W; v=(py-CY)/H
    a=math.sin(u*7+k)*1.3+math.cos(v*9-k*0.7)+math.sin((u+v)*5+k*1.7)*0.8
    # espiral à volta do centro
    ang=math.atan2(v,u)+math.pi/2*0.75
    return a*0.9+ang
cores=[((255,176,90),0.40),((255,120,40),0.20),((70,170,255),0.20),((150,90,255),0.12),((255,225,180),0.08)]
def cor():
    r=random.random(); acc=0
    for c,p in cores:
        acc+=p
        if r<acc: return c
    return cores[0][0]
camadas={}
def camada(c):
    if c not in camadas: camadas[c]=Image.new('L',(W,H),0)
    return camadas[c]
k=1.3
for i in range(1100):
    r=0.05+abs(rng.normal(0,0.17)); a=rng.uniform(0,2*math.pi)
    px=CX+math.cos(a)*r*W*0.55; py=CY+math.sin(a)*r*H*0.6
    pts=[(px,py)]; n=int(rng.uniform(30,160)); passo=rng.uniform(6,14)*S
    for j in range(n):
        ang=campo(px,py,k)
        px+=math.cos(ang)*passo; py+=math.sin(ang)*passo
        if ((px-CX)/(0.36*W))**2+((py-CY)/(0.44*H))**2>1: break
        pts.append((px,py))
    if len(pts)<3: continue
    c=cor(); d=ImageDraw.Draw(camada(c))
    larg=max(1,int(rng.gamma(1.6,3))); inten=int(rng.uniform(40,200))
    d.line(pts,fill=inten,width=larg*S,joint='curve')
# fitas largas (as "formas" principais)
for i in range(38):
    a=rng.uniform(0,2*math.pi); r=rng.uniform(0.02,0.14)
    px=CX+math.cos(a)*r*W; py=CY+math.sin(a)*r*H
    pts=[]
    for j in range(int(rng.uniform(40,90))):
        ang=campo(px,py,k+0.4); px+=math.cos(ang)*12*S; py+=math.sin(ang)*12*S
        if ((px-CX)/(0.26*W))**2+((py-CY)/(0.36*H))**2>1: break
        pts.append((px,py))
    c=random.choice([(255,170,80),(200,120,70),(60,140,230),(130,80,230)])
    if len(pts)<3: continue
    d=ImageDraw.Draw(camada(c)); d.line(pts,fill=int(rng.uniform(70,140)),width=int(rng.uniform(10,28))*S,joint='curve')
acum=np.zeros((H,W,3),np.float32)
for c,L in camadas.items():
    a=np.asarray(L,dtype=np.float32)/255.
    g1=np.asarray(L.filter(ImageFilter.GaussianBlur(6*S)),dtype=np.float32)/255.
    g2=np.asarray(L.filter(ImageFilter.GaussianBlur(40*S)),dtype=np.float32)/255.
    acum+=(a*0.8+g1*0.7+g2*1.1)[...,None]*np.array(c,np.float32)
# núcleo de luz
nuc=np.exp(-(((x-0.53)/0.05)**2+((y-0.53)/0.07)**2))[...,None]*np.array([255,150,60.],np.float32)*0.5
light=acum*0.75+nuc
light=255*(1-np.exp(-light/260.))
img=img+light; del light, acum, nuc
# partículas (pequenas esferas)
img=np.clip(img,0,255)
im=Image.fromarray(img.astype(np.uint8)); d=ImageDraw.Draw(im,'RGBA')
for i in range(260):
    r=abs(rng.normal(0,0.24)); a=rng.uniform(0,2*math.pi)
    px=CX+math.cos(a)*r*W*0.7; py=CY+math.sin(a)*r*H*0.8
    s=(rng.gamma(1.4,4)+1)*S; c=random.choice([(255,170,80),(255,120,50),(80,170,255),(160,100,255),(230,200,170)])
    d.ellipse([px-s,py-s,px+s,py+s],fill=c+(230,))
    if s>6*S: d.ellipse([px-s*0.5,py-s*0.6,px-s*0.1,py-s*0.2],fill=(255,255,255,120))
glow=im.filter(ImageFilter.GaussianBlur(3*S))
im=Image.blend(im,glow,0.25)
im.save('base8k.png')
