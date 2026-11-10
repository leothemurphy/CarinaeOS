# CarinaeOS - Eta: ler arquivos que a pessoa envia (PDF, Word, LibreOffice, texto,
# planilhas simples, imagens com texto) para os resumir e responder a perguntas.
import os
import re
import shutil
import subprocess
import zipfile
from collections import Counter
from xml.etree import ElementTree

HOME = os.path.expanduser('~')
TEXTO = ('.txt', '.md', '.csv', '.tsv', '.log', '.json', '.xml', '.html', '.htm', '.py', '.sh', '.ini', '.conf', '.yaml', '.yml', '.srt')
IMAGEM = ('.png', '.jpg', '.jpeg', '.webp', '.bmp', '.tif', '.tiff', '.gif', '.heic')
VIDEO = ('.mp4', '.mkv', '.webm', '.mov', '.avi')
AUDIO = ('.mp3', '.flac', '.ogg', '.m4a', '.wav', '.opus')

VAZIAS = set('''a o as os um uma de da do das dos e é em no na nos nas para por com sem que se ao à às
ou mais mas como seu sua seus suas este esta isso esse essa ele ela eles elas foi ser são ter tem também
the of and to in is for on with by an be this that are from as at it or'''.split())


def pasta_xdg(nome, padrao):
    try:
        r = subprocess.run(['xdg-user-dir', nome], capture_output=True, text=True, timeout=5)
        p = r.stdout.strip()
        if p and p != HOME:
            return p
    except Exception:
        pass
    return os.path.join(HOME, padrao)


def pasta_sugerida(caminho):
    e = os.path.splitext(caminho)[1].lower()
    if e in IMAGEM:
        return pasta_xdg('PICTURES', 'Imagens'), 'Imagens'
    if e in VIDEO:
        return pasta_xdg('VIDEOS', 'Vídeos'), 'Vídeos'
    if e in AUDIO:
        return pasta_xdg('MUSIC', 'Música'), 'Música'
    return pasta_xdg('DOCUMENTS', 'Documentos'), 'Documentos'


def _xml_texto(dados, etiquetas):
    raiz = ElementTree.fromstring(dados)
    partes = []
    for el in raiz.iter():
        nome = el.tag.split('}')[-1]
        if nome in etiquetas and el.text:
            partes.append(el.text)
        if nome in ('p', 'br', 'tab', 'h') and partes and not partes[-1].endswith('\n'):
            partes.append('\n')
    return ''.join(partes)


def extrair(caminho, limite=60000):
    """Devolve (tipo, texto, detalhes). Nunca levanta excecao."""
    e = os.path.splitext(caminho)[1].lower()
    det = {}
    try:
        det['tamanho'] = os.path.getsize(caminho)
    except OSError:
        return 'erro', '', {'erro': 'não consegui abrir o arquivo'}
    try:
        if e == '.pdf':
            r = subprocess.run(['pdftotext', '-layout', '-l', '40', caminho, '-'], capture_output=True, text=True, timeout=60)
            info = subprocess.run(['pdfinfo', caminho], capture_output=True, text=True, timeout=20).stdout
            m = re.search(r'Pages:\s+(\d+)', info)
            if m:
                det['paginas'] = int(m.group(1))
            texto = r.stdout
            if len(texto.strip()) < 40 and shutil.which('pdftoppm') and shutil.which('tesseract'):
                texto = _ocr_pdf(caminho)          # PDF digitalizado
                det['ocr'] = True
            return 'pdf', texto[:limite], det
        if e in ('.docx',):
            with zipfile.ZipFile(caminho) as z:
                return 'documento', _xml_texto(z.read('word/document.xml'), ('t',))[:limite], det
        if e in ('.odt', '.ods', '.odp'):
            with zipfile.ZipFile(caminho) as z:
                return 'documento', _xml_texto(z.read('content.xml'), ('p', 'span', 'h', 's'))[:limite], det
        if e in ('.pptx',):
            with zipfile.ZipFile(caminho) as z:
                nomes = sorted(n for n in z.namelist() if re.match(r'ppt/slides/slide\d+\.xml', n))
                det['slides'] = len(nomes)
                return 'apresentacao', '\n\n'.join(_xml_texto(z.read(n), ('t',)) for n in nomes)[:limite], det
        if e in ('.xlsx',):
            with zipfile.ZipFile(caminho) as z:
                txt = _xml_texto(z.read('xl/sharedStrings.xml'), ('t',)) if 'xl/sharedStrings.xml' in z.namelist() else ''
                return 'planilha', txt[:limite], det
        if e in TEXTO or (det['tamanho'] < 2_000_000 and _parece_texto(caminho)):
            with open(caminho, encoding='utf-8', errors='replace') as f:
                return 'texto', f.read(limite), det
        if e in IMAGEM:
            try:
                r = subprocess.run(['identify', '-format', '%w×%h', caminho + '[0]'], capture_output=True, text=True, timeout=20)
                if r.stdout.strip():
                    det['dimensoes'] = r.stdout.strip()
            except Exception:
                pass
            texto = ''
            if shutil.which('tesseract'):
                r = subprocess.run(['tesseract', caminho, '-', '-l', 'por+eng'], capture_output=True, text=True, timeout=120)
                texto = r.stdout
            return 'imagem', texto[:limite], det
        if e in VIDEO + AUDIO:
            return 'midia', '', det
    except Exception as ex:
        return 'erro', '', {'erro': str(ex)[:120], **det}
    return 'outro', '', det


def _parece_texto(caminho):
    try:
        with open(caminho, 'rb') as f:
            b = f.read(4096)
        return b and b'\0' not in b
    except OSError:
        return False


def _ocr_pdf(caminho):
    import tempfile
    pasta = tempfile.mkdtemp(prefix='eta-ocr-')
    try:
        subprocess.run(['pdftoppm', '-r', '150', '-l', '5', '-png', caminho, os.path.join(pasta, 'p')], timeout=120)
        partes = []
        for n in sorted(os.listdir(pasta)):
            r = subprocess.run(['tesseract', os.path.join(pasta, n), '-', '-l', 'por+eng'], capture_output=True, text=True, timeout=120)
            partes.append(r.stdout)
        return '\n'.join(partes)
    finally:
        shutil.rmtree(pasta, ignore_errors=True)


def frases(texto):
    t = re.sub(r'\s+', ' ', texto).strip()
    return [f.strip() for f in re.split(r'(?<=[.!?])\s+(?=[A-ZÁÉÍÓÚÂÊÔÃÕÇ0-9"“])', t) if len(f.strip()) > 25]


def resumo_simples(texto, n=4):
    """Resumo sem IA: escolhe as frases com as palavras mais frequentes do documento."""
    fs = frases(texto)[:400]
    if not fs:
        return [], []
    palavras = [w for w in re.findall(r'[a-záéíóúâêôãõçà]{4,}', texto.lower()) if w not in VAZIAS]
    freq = Counter(palavras)
    chave = [w for w, _ in freq.most_common(8)]
    pont = []
    for i, f in enumerate(fs):
        ws = re.findall(r'[a-záéíóúâêôãõçà]{4,}', f.lower())
        if not ws:
            continue
        p = sum(freq[w] for w in ws) / (len(ws) ** 0.6) + (3 if i < 3 else 0)
        pont.append((p, i, f))
    escolhidas = sorted(sorted(pont, reverse=True)[:n], key=lambda x: x[1])
    return [f if len(f) < 260 else f[:257] + '…' for _, _, f in escolhidas], chave


def tamanho_legivel(b):
    for u in ('B', 'KB', 'MB', 'GB'):
        if b < 1024:
            return ('%.0f %s' if u == 'B' else '%.1f %s') % (b, u)
        b /= 1024.0
    return '%.1f TB' % b


def mover(caminho, pasta):
    os.makedirs(pasta, exist_ok=True)
    destino = os.path.join(pasta, os.path.basename(caminho))
    if os.path.abspath(destino) == os.path.abspath(caminho):
        return destino
    base, ext = os.path.splitext(destino)
    n = 2
    while os.path.exists(destino):
        destino = '%s (%d)%s' % (base, n, ext)
        n += 1
    shutil.move(caminho, destino)
    return destino


def para_lixeira(caminho):
    r = subprocess.run(['gio', 'trash', caminho], capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        r = subprocess.run(['kioclient', 'move', caminho, 'trash:/'], capture_output=True, text=True, timeout=30)
    return r.returncode == 0
