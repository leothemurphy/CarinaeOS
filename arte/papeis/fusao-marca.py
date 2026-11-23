from PIL import Image, ImageDraw, ImageFont, ImageFilter
im=Image.open('base8k.png').convert('RGBA'); W,H=im.size
em=Image.open('emblema8k.png').convert('RGBA'); bb=em.getbbox(); em=em.crop(bb)
alt=300; em=em.resize((int(em.width*alt/em.height),alt),Image.LANCZOS)
f=ImageFont.truetype('/usr/share/fonts/opentype/inter/Inter-SemiBold.otf',184)
txt='CarinaeOS'; tb=f.getbbox(txt); tw=tb[2]-tb[0]; th=tb[3]-tb[1]
gap=56; total=em.width+gap+tw; mx=300; my=240
x0=W-mx-total; y0=my
camada=Image.new('RGBA',im.size,(0,0,0,0)); camada.alpha_composite(em,(x0,y0))
d=ImageDraw.Draw(camada); d.text((x0+em.width+gap, y0+(alt-th)//2-tb[1]), txt, font=f, fill=(245,236,225,255))
# marca d'água: translúcida, com uma sombra suave
a=camada.getchannel('A').point(lambda v:int(v*0.55)); camada.putalpha(a)
sombra=Image.new('RGBA',im.size,(0,0,0,0)); sa=a.filter(ImageFilter.GaussianBlur(20)).point(lambda v:int(v*0.6))
sombra.putalpha(sa)
im.alpha_composite(sombra); im.alpha_composite(camada)
out=im.convert('RGB'); out.save('CarinaeOS-Fusao-7680x4320.jpg',quality=94)
for w,h in ((5120,2880),(3840,2160),(2560,1440),(1920,1080),(1366,768)): out.resize((w,h),Image.LANCZOS).save('CarinaeOS-Fusao-%dx%d.jpg'%(w,h),quality=92)
out.resize((1280,720),Image.LANCZOS).save('prev2.jpg')
out.crop((W-3400,0,W,1120)).resize((850,280)).save('canto.jpg')
