# CarinaeOS — Carinae Compactador: o motor (ler, extrair e criar arquivos compactados).
# ZIP e TAR com o Python; 7Z, RAR, ISO e o resto com o 7-Zip (7z) ou, sem ele, com o bsdtar.
import os
import re
import shutil
import subprocess
import tarfile
import time
import zipfile

TAR = ('.tar', '.tar.gz', '.tgz', '.tar.bz2', '.tbz2', '.tbz', '.tar.xz', '.txz', '.tar.zst', '.tzst')
EXTENSOES = TAR + ('.zip', '.7z', '.rar', '.iso', '.cab', '.arj', '.lzh', '.cpio', '.deb', '.rpm', '.apk', '.jar',
                   '.xpi', '.epub', '.gz', '.bz2', '.xz', '.zst', '.wim', '.dmg', '.vhd', '.msi')


class Erro(Exception):
    pass


class PrecisaSenha(Exception):
    pass


def sete():
    return shutil.which('7z') or shutil.which('7zz') or shutil.which('7za')


def tipo(caminho):
    b = caminho.lower()
    if b.endswith('.tar.zst') or b.endswith('.tzst'):
        return '7z' if sete() else 'bsdtar'      # o tarfile não conhece o zstd
    if b.endswith(TAR):
        return 'tar'
    if b.endswith(('.zip', '.jar', '.xpi', '.epub', '.apk')):
        return 'zip'
    return '7z' if sete() else 'bsdtar'


def nome_formato(caminho):
    b = os.path.basename(caminho).lower()
    for e in sorted(EXTENSOES, key=len, reverse=True):
        if b.endswith(e):
            return e[1:].upper()
    return 'Arquivo'


def sem_extensao(nome):
    b = nome.lower()
    for e in sorted(EXTENSOES, key=len, reverse=True):
        if b.endswith(e):
            return nome[:-len(e)]
    return os.path.splitext(nome)[0]


# ---- listar -------------------------------------------------------------------------------------------
def listar(caminho, senha=''):
    """Lista de dict(caminho, pasta, tamanho, comprimido, data, cifrado)."""
    t = tipo(caminho)
    r = []
    if t == 'zip':
        try:
            with zipfile.ZipFile(caminho) as z:
                for i in z.infolist():
                    r.append(dict(caminho=i.filename.rstrip('/'), pasta=i.is_dir(), tamanho=i.file_size,
                                  comprimido=i.compress_size, data='%04d-%02d-%02d %02d:%02d' % i.date_time[:5],
                                  cifrado=bool(i.flag_bits & 1)))
        except zipfile.BadZipFile:
            raise Erro('O arquivo ZIP está danificado.')
    elif t == 'tar':
        try:
            with tarfile.open(caminho) as tf:
                for m in tf.getmembers():
                    r.append(dict(caminho=m.name.lstrip('./').rstrip('/'), pasta=m.isdir(), tamanho=m.size, comprimido=0,
                                  data=time.strftime('%Y-%m-%d %H:%M', time.localtime(m.mtime)), cifrado=False))
        except tarfile.TarError as e:
            raise Erro('Não foi possível ler: %s' % e)
    elif t == '7z':
        args = [sete(), 'l', '-slt', '-ba', '-p' + senha, caminho]
        p = subprocess.run(args, capture_output=True, text=True, errors='replace', stdin=subprocess.DEVNULL)
        saida = p.stdout + p.stderr
        if 'Wrong password' in saida or 'Can not open encrypted archive' in saida:
            raise PrecisaSenha()
        if p.returncode not in (0, 1) and 'Path =' not in p.stdout:
            raise Erro(ultima_linha(saida) or 'Não foi possível abrir.')
        for bloco in re.split(r'\n\s*\n', p.stdout):
            d = dict(re.findall(r'^(\w[\w ]*?) = (.*)$', bloco, re.M))
            if 'Path' not in d:
                continue
            r.append(dict(caminho=d['Path'].replace('\\', '/').rstrip('/'),
                          pasta=d.get('Folder') == '+' or d.get('Attributes', '').startswith('D'),
                          tamanho=int(d.get('Size') or 0), comprimido=int(d.get('Packed Size') or 0),
                          data=(d.get('Modified') or '')[:16], cifrado=d.get('Encrypted') == '+'))
    else:
        if not shutil.which('bsdtar'):
            raise Erro('Para este formato instale o 7-Zip (pacote 7zip).')
        p = subprocess.run(['bsdtar', '-tvf', caminho], capture_output=True, text=True, errors='replace')
        if p.returncode:
            raise Erro(ultima_linha(p.stderr) or 'Não foi possível abrir.')
        for l in p.stdout.splitlines():
            m = re.match(r'(\S+)\s+\S+\s+\S+\s+\S+\s+(\d+)\s+(\w+\s+\d+\s+[\d:]+)\s+(.*)$', l)
            if m:
                r.append(dict(caminho=m.group(4).rstrip('/'), pasta=m.group(1).startswith('d'), tamanho=int(m.group(2)),
                              comprimido=0, data=m.group(3), cifrado=False))
    # as pastas que só existem no caminho dos arquivos (muitos ZIP não as guardam)
    vistas = {x['caminho'] for x in r}
    for x in list(r):
        partes = x['caminho'].split('/')[:-1]
        for i in range(1, len(partes) + 1):
            p = '/'.join(partes[:i])
            if p and p not in vistas:
                vistas.add(p)
                r.append(dict(caminho=p, pasta=True, tamanho=0, comprimido=0, data='', cifrado=False))
    return [x for x in r if x['caminho'] and x['caminho'] != '.']


def ultima_linha(t):
    l = [x.strip() for x in t.splitlines() if x.strip() and not x.startswith(('7-Zip', 'p7zip', 'Scanning', '--'))]
    return l[-1] if l else ''


# ---- extrair ------------------------------------------------------------------------------------------
def _seguro(destino, nome):
    alvo = os.path.realpath(os.path.join(destino, nome))
    return alvo == os.path.realpath(destino) or alvo.startswith(os.path.realpath(destino) + os.sep)


def extrair(caminho, destino, entradas=None, senha='', progresso=lambda f, t: None, parar=None):
    """entradas: só estes caminhos (e o que estiver dentro das pastas); None = tudo."""
    os.makedirs(destino, exist_ok=True)
    t = tipo(caminho)

    def escolhido(nome):
        if entradas is None:
            return True
        nome = nome.rstrip('/')
        return any(nome == e or nome.startswith(e + '/') for e in entradas)

    if t == 'zip':
        with zipfile.ZipFile(caminho) as z:
            itens = [i for i in z.infolist() if escolhido(i.filename)]
            total = sum(i.file_size for i in itens) or 1
            feito = 0
            pwd = senha.encode() if senha else None
            for i in itens:
                if parar and parar.is_set():
                    raise Erro('cancelado')
                if not _seguro(destino, i.filename):
                    continue
                try:
                    z.extract(i, destino, pwd=pwd)
                except RuntimeError as e:
                    if 'password' in str(e).lower() or 'encrypted' in str(e).lower():
                        raise PrecisaSenha()
                    raise
                except NotImplementedError:
                    # cifra AES: só o 7-Zip sabe
                    if sete():
                        return _extrair_7z(caminho, destino, entradas, senha, progresso)
                    raise Erro('Este ZIP usa uma cifra que precisa do 7-Zip (pacote 7zip).')
                # a data original do arquivo
                try:
                    os.utime(os.path.join(destino, i.filename), (time.mktime(i.date_time + (0, 0, -1)),) * 2)
                except (OSError, OverflowError, ValueError):
                    pass
                feito += i.file_size
                progresso(feito, total)
        return
    if t == 'tar':
        with tarfile.open(caminho) as tf:
            itens = [m for m in tf.getmembers() if escolhido(m.name.lstrip('./'))]
            total = sum(m.size for m in itens) or 1
            feito = 0
            for m in itens:
                if parar and parar.is_set():
                    raise Erro('cancelado')
                try:
                    tf.extract(m, destino, filter='data')
                except (tarfile.FilterError, OSError):
                    continue
                feito += m.size
                progresso(feito, total)
        return
    if t == '7z':
        return _extrair_7z(caminho, destino, entradas, senha, progresso, parar)
    args = ['bsdtar', '-xf', caminho, '-C', destino] + (list(entradas) if entradas else [])
    p = subprocess.run(args, capture_output=True, text=True)
    if p.returncode:
        raise Erro(ultima_linha(p.stderr) or 'falhou')


def _extrair_7z(caminho, destino, entradas, senha, progresso, parar=None):
    args = [sete(), 'x', '-y', '-bsp1', '-bso0', '-p' + senha, '-o' + destino, caminho]
    if entradas:
        for e in entradas:
            args += [e, e + '/*']
        args.append('-r-')
    p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL, text=True, errors='replace')
    buf = ''
    while True:
        c = p.stdout.read(1)
        if not c:
            break
        if parar and parar.is_set():
            p.kill()
            raise Erro('cancelado')
        if c in '\r\n\b':
            m = re.search(r'(\d+)%', buf)
            if m:
                progresso(int(m.group(1)), 100)
            buf = ''
        else:
            buf += c
    erro = p.stderr.read()
    p.wait()
    if 'Wrong password' in erro or 'Can not open encrypted' in erro:
        raise PrecisaSenha()
    if p.returncode > 1:
        raise Erro(ultima_linha(erro) or 'falhou (código %d)' % p.returncode)


# ---- criar --------------------------------------------------------------------------------------------
FORMATOS = [('zip', 'ZIP (abre em qualquer computador)'), ('7z', '7Z (o mais pequeno)'),
            ('tar.gz', 'TAR.GZ (Linux)'), ('tar.xz', 'TAR.XZ (Linux, mais pequeno)')]


def _ficheiros(origens):
    base = os.path.commonpath([os.path.dirname(os.path.abspath(o)) for o in origens])
    r = []
    for o in origens:
        o = os.path.abspath(o)
        if os.path.isdir(o):
            r.append((o, os.path.relpath(o, base)))
            for d, ds, fs in os.walk(o):
                for x in ds:
                    r.append((os.path.join(d, x), os.path.relpath(os.path.join(d, x), base)))
                for x in fs:
                    r.append((os.path.join(d, x), os.path.relpath(os.path.join(d, x), base)))
        else:
            r.append((o, os.path.relpath(o, base)))
    return base, r


def criar(destino, origens, formato='zip', nivel=6, senha='', progresso=lambda f, t: None, parar=None):
    base, lista = _ficheiros(origens)
    total = sum(os.path.getsize(c) for c, _ in lista if os.path.isfile(c)) or 1
    feito = 0
    tmp = destino + '.carinae-parcial'
    try:
        if formato == '7z' or (formato == 'zip' and senha):
            if not sete():
                raise Erro('Para criar 7Z ou ZIP com senha instale o 7-Zip (pacote 7zip).')
            args = [sete(), 'a', '-bsp1', '-bso0', '-mx=%d' % nivel, '-t' + ('7z' if formato == '7z' else 'zip')]
            if senha:
                args += ['-p' + senha] + (['-mhe=on'] if formato == '7z' else ['-mem=AES256'])
            args += [tmp] + [os.path.relpath(os.path.abspath(o), base) for o in origens]
            p = subprocess.Popen(args, cwd=base, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, errors='replace')
            buf = ''
            while True:
                c = p.stdout.read(1)
                if not c:
                    break
                if parar and parar.is_set():
                    p.kill()
                    raise Erro('cancelado')
                if c in '\r\n\b':
                    m = re.search(r'(\d+)%', buf)
                    if m:
                        progresso(int(m.group(1)), 100)
                    buf = ''
                else:
                    buf += c
            erro = p.stderr.read()
            if p.wait() > 1:
                raise Erro(ultima_linha(erro) or 'falhou')
        elif formato == 'zip':
            with zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED, compresslevel=nivel) as z:
                for c, n in lista:
                    if parar and parar.is_set():
                        raise Erro('cancelado')
                    z.write(c, n)
                    if os.path.isfile(c):
                        feito += os.path.getsize(c)
                        progresso(feito, total)
        else:
            modo = 'w:gz' if formato == 'tar.gz' else 'w:xz'
            opc = dict(compresslevel=nivel) if formato == 'tar.gz' else dict(preset=min(9, nivel))
            with tarfile.open(tmp, modo, **opc) as tf:
                for o in origens:
                    def filtro(ti):
                        nonlocal feito
                        if parar and parar.is_set():
                            raise Erro('cancelado')
                        feito += ti.size
                        progresso(feito, total)
                        return ti
                    tf.add(o, os.path.relpath(os.path.abspath(o), base), filter=filtro)
        os.replace(tmp, destino)
    finally:
        if os.path.exists(tmp):
            os.remove(tmp)
