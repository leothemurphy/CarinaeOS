#!/usr/bin/python3
# CarinaeOS - gera a colecao de papeis de parede (8K, 7680x4320) para a ISO:
#  - fotografias reais dos telescopios James Webb e Hubble (ESA/Webb e ESA/Hubble, licenca CC BY 4.0),
#    baixadas na construcao, recortadas em 16:9 e reduzidas a 8K;
#  - desenhos originais do CarinaeOS (arte.py), gerados por codigo.
# Uso: fundos.py PASTA_RAIZ_DO_SISTEMA PASTA_CACHE
# Cria /usr/share/wallpapers/CarinaeOS-*/ (Plasma), /usr/share/backgrounds/carinaeos/ (GNOME/XFCE)
# e /usr/share/gnome-background-properties/carinaeos.xml.
import json
import os
import sys
import urllib.request

from PIL import Image

import arte

Image.MAX_IMAGE_PIXELS = None
W, H = 7680, 4320
CREDITO_WEBB = 'NASA, ESA, CSA, STScI (ESA/Webb, CC BY 4.0)'
CREDITO_HUBBLE = 'NASA, ESA, N. Smith (University of California, Berkeley) e The Hubble Heritage Team (STScI/AURA) (ESA/Hubble, CC BY 4.0)'

# (pasta, nome, url, foco x, foco y, credito)
FOTOS = [
    ('PenhascosCosmicos', 'Penhascos Cósmicos (Nebulosa de Carina)', 'https://cdn.esawebb.org/archives/images/large/weic2205a.jpg', 0.5, 0.55, CREDITO_WEBB),
    ('NebulosaDeCarina', 'Nebulosa de Carina, onde vive a Eta Carinae', 'https://cdn.esahubble.org/archives/images/large/heic0707a.jpg', 0.5, 0.5, CREDITO_HUBBLE),
    ('PilaresDaCriacao', 'Pilares da Criação', 'https://cdn.esawebb.org/archives/images/large/weic2216b.jpg', 0.5, 0.42, CREDITO_WEBB),
    ('QuintetoDeStephan', 'Quinteto de Stephan', 'https://cdn.esawebb.org/archives/images/large/weic2208a.jpg', 0.5, 0.5, CREDITO_WEBB),
    ('RhoOphiuchi', 'Rho Ophiuchi', 'https://cdn.esawebb.org/archives/images/large/weic2316a.jpg', 0.5, 0.45, CREDITO_WEBB),
    ('AglomeradoDePandora', 'Aglomerado de Pandora', 'https://cdn.esawebb.org/archives/images/large/weic2305a.jpg', 0.5, 0.5, CREDITO_WEBB),
    ('NGC602', 'NGC 602', 'https://cdn.esawebb.org/archives/images/large/weic2425a.jpg', 0.5, 0.5, CREDITO_WEBB),
    ('NGC346', 'NGC 346', 'https://cdn.esawebb.org/archives/images/large/weic2301a.jpg', 0.5, 0.45, CREDITO_WEBB),
]


def baixar(url, cache):
    os.makedirs(cache, exist_ok=True)
    destino = os.path.join(cache, os.path.basename(url))
    if not os.path.exists(destino):
        tmp = destino + '.parte'
        req = urllib.request.Request(url, headers={'User-Agent': 'CarinaeOS-build'})
        with urllib.request.urlopen(req, timeout=300) as r, open(tmp, 'wb') as f:
            while True:
                b = r.read(1 << 20)
                if not b:
                    break
                f.write(b)
        os.replace(tmp, destino)
    return destino


def recortar_8k(caminho, fx, fy):
    im = Image.open(caminho)
    im.draft('RGB', (W, H))                      # JPEG: descodificar ja reduzido (poupa memoria)
    im = im.convert('RGB')
    w, h = im.size
    if w / h > W / H:
        cw, ch = int(h * W / H), h
    else:
        cw, ch = w, int(w * H / W)
    x = int(min(max(0, fx * w - cw / 2), w - cw))
    y = int(min(max(0, fy * h - ch / 2), h - ch))
    im = im.crop((x, y, x + cw, y + ch))
    if im.size != (W, H):
        im = im.resize((W, H), Image.LANCZOS)
    return im


def pacote(raiz, pasta, nome, im, autor, licenca, descricao):
    base = os.path.join(raiz, 'usr/share/wallpapers', 'CarinaeOS-' + pasta)
    imgs = os.path.join(base, 'contents/images')
    os.makedirs(imgs, exist_ok=True)
    im.save(os.path.join(imgs, '%dx%d.jpg' % (W, H)), quality=90, optimize=True, progressive=True)
    im.resize((3840, 2160), Image.LANCZOS).save(os.path.join(imgs, '3840x2160.jpg'), quality=90, optimize=True)
    im.resize((1920, 1080), Image.LANCZOS).save(os.path.join(imgs, '1920x1080.jpg'), quality=90, optimize=True)
    im.resize((400, 225), Image.LANCZOS).save(os.path.join(base, 'contents/screenshot.jpg'), quality=85)
    meta = {'KPlugin': {'Id': 'CarinaeOS-' + pasta, 'Name': nome, 'Description': descricao,
                        'Authors': [{'Name': autor}], 'License': licenca}}
    with open(os.path.join(base, 'metadata.json'), 'w', encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    # GNOME e XFCE: a mesma imagem 8K
    bg = os.path.join(raiz, 'usr/share/backgrounds/carinaeos')
    os.makedirs(bg, exist_ok=True)
    ligacao = os.path.join(bg, pasta + '.jpg')
    if os.path.lexists(ligacao):
        os.remove(ligacao)
    os.symlink('/usr/share/wallpapers/CarinaeOS-%s/contents/images/%dx%d.jpg' % (pasta, W, H), ligacao)
    return nome, '/usr/share/backgrounds/carinaeos/%s.jpg' % pasta


def main():
    raiz, cache = sys.argv[1], sys.argv[2]
    lista = []
    # 1) fotografias reais do Atacama com a estrela do CarinaeOS (as principais)
    import fotos_estrela as FE
    from PIL import ImageFilter
    for f in FE.FOTOS:
        try:
            im = FE.compor(FE.baixar(cache, f['id']), f, W)
        except Exception as e:
            print('AVISO: sem a foto %s (%s)' % (f['id'], e), flush=True)
            continue
        pasta = 'Estrela-' + f['nome'].replace(' ', '')
        lista.append(pacote(raiz, pasta, 'Estrela · ' + f['nome'], im, 'Foto: %s · Estrela: CarinaeOS' % f['credito'],
                            'CC-BY-4.0', 'Céu real do deserto do Atacama com a estrela do CarinaeOS. Foto: ' + f['credito']))
        print('estrela', pasta, flush=True)
        if f['id'] == FE.FOTOS[0]['id']:
            # o papel de parede padrao do CarinaeOS passa a ser este (o desenho antigo fica como "Original")
            orig = os.path.join(raiz, 'usr/share/wallpapers/CarinaeOS')
            velho = os.path.join(raiz, 'usr/share/wallpapers/CarinaeOS-Original')
            if os.path.isdir(orig) and not os.path.isdir(velho):
                import shutil
                shutil.copytree(orig, velho)
                with open(os.path.join(velho, 'metadata.json'), 'w', encoding='utf-8') as m:
                    json.dump({'KPlugin': {'Id': 'CarinaeOS-Original', 'Name': 'Eta Carinae (original)',
                                           'Authors': [{'Name': 'CarinaeOS'}], 'License': 'CC-BY-SA-4.0'}}, m)
            if os.path.isdir(orig):
                imgs = os.path.join(orig, 'contents/images')
                for n in os.listdir(imgs):
                    os.remove(os.path.join(imgs, n))
                for (lw, lh) in ((W, H), (3840, 2160), (2560, 1440), (1920, 1080)):
                    (im if lw == W else im.resize((lw, lh), Image.LANCZOS)).save(
                        os.path.join(imgs, '%dx%d.jpg' % (lw, lh)), quality=90, optimize=True)
                im.resize((400, 225), Image.LANCZOS).save(os.path.join(orig, 'contents/screenshot.jpg'), quality=85)
            # banner das janelas de senha e fundo desfocado da tela de entrada
            marca = os.path.join(raiz, 'usr/share/carinaeos/marca')
            os.makedirs(marca, exist_ok=True)
            cx, cy = int(f['pos'][0] * W), int(f['pos'][1] * H)
            bw, bh = 3680, 1056
            x0 = max(0, min(W - bw, cx - int(bw * 0.62)))
            y0 = max(0, min(H - bh, cy - bh // 2))
            im.crop((x0, y0, x0 + bw, y0 + bh)).resize((920, 264), Image.LANCZOS).save(
                os.path.join(marca, 'banner-senha.jpg'), quality=88)
            im.resize((1920, 1080), Image.LANCZOS).filter(ImageFilter.GaussianBlur(28)).save(
                os.path.join(marca, 'fundo-desfocado.jpg'), quality=85)
    for nome_arte, (_, desc) in arte.DESENHOS.items():
        im = arte.desenhar(nome_arte, W, H)
        lista.append(pacote(raiz, nome_arte, nome_arte, im, 'CarinaeOS (Leonardo Mendes e Claude)', 'CC-BY-SA-4.0', desc))
        print('desenho', nome_arte, flush=True)
    for pasta, nome, url, fx, fy, credito in FOTOS:
        try:
            im = recortar_8k(baixar(url, cache), fx, fy)
        except Exception as e:                       # sem internet: segue sem esta foto
            print('AVISO: sem a foto %s (%s)' % (nome, e), flush=True)
            continue
        lista.append(pacote(raiz, pasta, nome, im, credito, 'CC-BY-4.0', 'Fotografia do espaço. Crédito: ' + credito))
        print('foto', nome, flush=True)
    # o fundo original do CarinaeOS (Eta Carinae) tambem para GNOME/XFCE
    bg = os.path.join(raiz, 'usr/share/backgrounds/carinaeos')
    os.makedirs(bg, exist_ok=True)
    eta = os.path.join(bg, 'eta-carinae.jpg')
    if not os.path.lexists(eta):
        os.symlink('/usr/share/wallpapers/CarinaeOS/contents/images/3840x2160.jpg', eta)
    lista.insert(0, ('Eta Carinae (CarinaeOS)', '/usr/share/backgrounds/carinaeos/eta-carinae.jpg'))
    gbp = os.path.join(raiz, 'usr/share/gnome-background-properties')
    os.makedirs(gbp, exist_ok=True)
    with open(os.path.join(gbp, 'carinaeos.xml'), 'w', encoding='utf-8') as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">\n<wallpapers>\n')
        for nome, cam in lista:
            f.write('  <wallpaper deleted="false">\n    <name>%s</name>\n    <filename>%s</filename>\n'
                    '    <filename-dark>%s</filename-dark>\n    <options>zoom</options>\n    <shade_type>solid</shade_type>\n'
                    '  </wallpaper>\n' % (nome.replace('&', '&amp;'), cam, cam))
        f.write('</wallpapers>\n')


if __name__ == '__main__':
    main()
