import secrets
import string


def procurar(texto, ctx):
    try:
        n = max(6, min(128, int(texto.split()[0]))) if texto.strip() else 20
    except ValueError:
        n = 20
    letras = string.ascii_letters + string.digits
    forte = letras + '!@#$%&*-_=+?'
    s1 = ''.join(secrets.choice(forte) for _ in range(n))
    s2 = ''.join(secrets.choice(letras) for _ in range(n))
    palavras = ['estrela', 'nebulosa', 'cometa', 'aurora', 'orbita', 'galaxia', 'planeta', 'luar', 'carina', 'quasar',
                'pulsar', 'eclipse', 'zenite', 'vento', 'oceano', 'montanha', 'floresta', 'relampago']
    s3 = '-'.join(secrets.choice(palavras) for _ in range(4)) + str(secrets.randbelow(100))
    return [dict(titulo=s1, sub='%d caracteres com símbolos · Enter copia' % n, acao='copiar', valor=s1),
            dict(titulo=s2, sub='%d caracteres, só letras e números' % n, acao='copiar', valor=s2),
            dict(titulo=s3, sub='Fácil de lembrar', acao='copiar', valor=s3)]
