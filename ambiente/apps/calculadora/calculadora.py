#!/usr/bin/env python3
# CarinaeOS — Carinae Calculadora (no jeito da Calculadora do Windows 11): Padrão e Científica,
# histórico e memória. As contas são feitas em decimal (0,1 + 0,2 dá 0,3).
import json
import math
import os
import sys
from decimal import Decimal, DivisionByZero, InvalidOperation, getcontext

AQUI = os.path.dirname(os.path.abspath(__file__))
for _p in ('/usr/local/share/carinaeos/comum', '/usr/share/carinaeos/comum', os.path.join(AQUI, '..', 'comum')):
    if os.path.isdir(_p):
        sys.path.insert(0, _p)
        break

from PySide6.QtCore import QObject, Property, Signal, Slot  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402

getcontext().prec = 34
ESTADO = os.path.expanduser('~/.local/share/carinaeos/calculadora.json')
MAX_DIGITOS = 16
OPS = {'+': 1, '-': 1, '×': 2, '÷': 2, 'mod': 2, '^': 3}


class Erro(Exception):
    pass


# ---- números ------------------------------------------------------------------------------------------
def formatar(d, agrupar=True):
    """Decimal -> "1.234.567,89" (como no Brasil); notação científica para os muito grandes/pequenos."""
    if not isinstance(d, Decimal):
        d = Decimal(d)
    if d.is_nan() or d.is_infinite():
        raise Erro('Resultado indefinido')
    if d == 0:
        return '0'
    a = abs(d)
    if a >= Decimal('1e16') or a < Decimal('1e-15'):
        m = '{:.15e}'.format(d)                   # 1.234560000000000e+20
        mant, exp = m.split('e')
        mant = mant.rstrip('0').rstrip('.')
        return mant.replace('.', ',') + 'e' + ('+' if int(exp) > 0 else '') + str(int(exp))
    q = d.quantize(Decimal(1).scaleb(-(MAX_DIGITOS - len(str(int(a))) if a >= 1 else MAX_DIGITOS)))
    t = format(q.normalize(), 'f')
    if '.' in t:
        t = t.rstrip('0').rstrip('.')
    neg = t.startswith('-')
    t = t.lstrip('-')
    inteira, _, frac = t.partition('.')
    if agrupar:
        inteira = '{:,}'.format(int(inteira)).replace(',', '.')
    return ('-' if neg else '') + inteira + (',' + frac if frac else '')


def ler_numero(t):
    t = t.replace('.', '').replace(',', '.') if ',' in t else t
    t = t.replace(' ', '').replace(' ', '')
    return Decimal(t)


def potencia(a, b):
    if b == b.to_integral_value() and abs(b) <= 10000:
        return a ** int(b)
    if a < 0:
        raise Erro('Entrada inválida')
    return Decimal(repr(math.pow(float(a), float(b))))


def calcular(tokens, imediato=False):
    """tokens: Decimal, operadores, '(' e ')'. Respeita a precedência (× antes de +); no modo Padrão
    (imediato) faz como uma calculadora de bolso e a do Windows: da esquerda para a direita."""
    prec = (lambda o: 1) if imediato else (lambda o: OPS[o])
    saida, pilha = [], []
    for t in tokens:
        if isinstance(t, Decimal):
            saida.append(t)
        elif t == '(':
            pilha.append(t)
        elif t == ')':
            while pilha and pilha[-1] != '(':
                saida.append(pilha.pop())
            if pilha:
                pilha.pop()
        else:
            while pilha and pilha[-1] != '(' and (prec(pilha[-1]) > prec(t) or (prec(pilha[-1]) == prec(t) and t != '^')):
                saida.append(pilha.pop())
            pilha.append(t)
    while pilha:
        p = pilha.pop()
        if p != '(':
            saida.append(p)
    st = []
    for t in saida:
        if isinstance(t, Decimal):
            st.append(t)
            continue
        if len(st) < 2:
            raise Erro('Entrada inválida')
        b, a = st.pop(), st.pop()
        try:
            if t == '+':
                st.append(a + b)
            elif t == '-':
                st.append(a - b)
            elif t == '×':
                st.append(a * b)
            elif t == '÷':
                if b == 0:
                    raise Erro('Não é possível dividir por zero')
                st.append(a / b)
            elif t == 'mod':
                if b == 0:
                    raise Erro('Não é possível dividir por zero')
                st.append(a % b)
            elif t == '^':
                st.append(potencia(a, b))
        except (InvalidOperation, DivisionByZero, OverflowError, ValueError):
            raise Erro('Entrada inválida')
    if len(st) != 1:
        raise Erro('Entrada inválida')
    return st[0]


def texto_tokens(tokens):
    r = []
    for t in tokens:
        r.append(formatar(t) if isinstance(t, Decimal) else ('^' if t == '^' else t))
    return ' '.join(r).replace('( ', '(').replace(' )', ')')


class Calculadora(QObject):
    mudou = Signal()
    historicoMudou = Signal()
    memoriaMudou = Signal()

    def __init__(self):
        super().__init__()
        self._tokens = []          # o que já foi escrito (números e operadores)
        self._rotulos = {}         # índice do token -> como aparece ("√(9)")
        self._entrada = '0'        # o número a ser escrito (como texto, com ponto)
        self._nova = True          # o próximo dígito começa um número novo
        self._expressao = ''
        self._erro = ''
        self._graus = True
        self._modo = 'padrao'
        self._historico = []
        self._memoria = []
        self._func_rotulo = ''     # "sqr(5)" mostrado enquanto a entrada vem de uma função
        try:
            d = json.load(open(ESTADO, encoding='utf-8'))
            self._historico = d.get('historico', [])[:100]
            self._memoria = [str(x) for x in d.get('memoria', [])][:50]
            self._modo = d.get('modo', 'padrao')
            self._graus = d.get('graus', True)
        except (OSError, ValueError):
            pass

    def _gravar(self):
        try:
            os.makedirs(os.path.dirname(ESTADO), exist_ok=True)
            json.dump(dict(historico=self._historico, memoria=self._memoria, modo=self._modo, graus=self._graus),
                      open(ESTADO, 'w', encoding='utf-8'), ensure_ascii=False)
        except OSError:
            pass

    # ---- propriedades
    @Property(str, notify=mudou)
    def visor(self):
        if self._erro:
            return self._erro
        if not self._nova or self._entrada.endswith('.'):
            # a ser escrito: mostra exatamente o que se escreveu (com o separador de milhares)
            neg = self._entrada.startswith('-')
            e = self._entrada.lstrip('-')
            inteira, ponto, frac = e.partition('.')
            inteira = '{:,}'.format(int(inteira or '0')).replace(',', '.')
            return ('-' if neg else '') + inteira + (',' + frac if ponto else '')
        try:
            return formatar(Decimal(self._entrada))
        except Erro as x:
            return str(x)

    @Property(str, notify=mudou)
    def expressao(self):
        return self._expressao

    @Property(bool, notify=mudou)
    def temErro(self):
        return bool(self._erro)

    @Property(str, notify=mudou)
    def modo(self):
        return self._modo

    @Property(bool, notify=mudou)
    def graus(self):
        return self._graus

    @Property('QVariantList', notify=historicoMudou)
    def historico(self):
        return self._historico

    @Property('QVariantList', notify=memoriaMudou)
    def memoria(self):
        return [formatar(Decimal(m)) for m in self._memoria]

    @Slot(str)
    def mudarModo(self, m):
        self._modo = m
        self._gravar()
        self.mudou.emit()

    @Slot()
    def alternarGraus(self):
        self._graus = not self._graus
        self._gravar()
        self.mudou.emit()

    # ---- entrada
    def _valor(self):
        return Decimal(self._entrada)

    def _definir(self, d, rotulo=''):
        self._entrada = format(d.normalize(), 'f') if d == d.to_integral_value() or abs(d) >= Decimal('1e-15') else str(d)
        if self._entrada in ('-0',):
            self._entrada = '0'
        self._nova = True
        self._func_rotulo = rotulo

    def _limpar_erro(self):
        if self._erro:
            self._erro = ''
            self._tokens = []
            self._entrada = '0'
            self._nova = True
            self._expressao = ''

    def _mostrar_parcial(self):
        self._expressao = texto_tokens_rot(self._tokens, self._rotulos)
        # o resultado até aqui (sem o operador do fim), como a Calculadora do Windows
        t = list(self._tokens)
        while t and not isinstance(t[-1], Decimal) and t[-1] != ')':
            t.pop()
        abertos = t.count('(') - t.count(')')
        if t and abertos == 0:
            try:
                self._definir(calcular(t, self._modo == 'padrao'))
            except Erro:
                pass

    def _falhou(self, msg):
        self._erro = msg
        self._tokens = []
        self._rotulos = {}
        self.mudou.emit()

    @Slot(str)
    def tecla(self, k):
        try:
            self._tecla(k)
        except Erro as e:
            self._falhou(str(e))
            return
        except (InvalidOperation, DivisionByZero, OverflowError, ValueError):
            self._falhou('Entrada inválida')
            return
        self.mudou.emit()

    def _ultimo_e_operador(self):
        return self._tokens and not isinstance(self._tokens[-1], Decimal) and self._tokens[-1] not in ('(', ')')

    def _tecla(self, k):
        if k in '0123456789':
            self._limpar_erro()
            if self._nova:
                if self._expressao.endswith('='):
                    self._expressao = ''
                self._entrada = k
                self._nova = False
                self._func_rotulo = ''
            elif len(self._entrada.replace('-', '').replace('.', '')) < MAX_DIGITOS:
                self._entrada = k if self._entrada == '0' else (self._entrada[:-1] + k if self._entrada == '-0' else self._entrada + k)
            return
        if k in (',', '.'):
            self._limpar_erro()
            if self._nova:
                self._entrada = '0.'
                self._nova = False
                if self._expressao.endswith('='):
                    self._expressao = ''
            elif '.' not in self._entrada:
                self._entrada += '.'
            return
        if k == 'C':
            self._erro = ''
            self._tokens, self._rotulos = [], {}
            self._entrada, self._nova, self._expressao, self._func_rotulo = '0', True, '', ''
            return
        if k == 'CE':
            self._limpar_erro()
            self._entrada, self._nova, self._func_rotulo = '0', True, ''
            if self._expressao.endswith('='):
                self._expressao = ''
            return
        if k == '⌫':
            if self._erro:
                self._limpar_erro()
                return
            if self._nova:
                if self._expressao.endswith('='):
                    self._expressao = ''
                return
            self._entrada = self._entrada[:-1]
            if self._entrada in ('', '-'):
                self._entrada, self._nova = '0', True
            return
        if self._erro:
            self._limpar_erro()
            if k not in ('(',):
                return
        if k in OPS:
            if self._ultimo_e_operador() and self._nova:
                self._tokens[-1] = k                         # trocar o operador
            else:
                if not (self._tokens and self._tokens[-1] == ')' and self._nova):
                    self._empurrar_entrada()
                self._tokens.append(k)
            self._mostrar_parcial()
            self._expressao = texto_tokens_rot(self._tokens, self._rotulos)
            return
        if k == '(':
            if self._expressao.endswith('='):
                self._expressao = ''
            if self._tokens and (isinstance(self._tokens[-1], Decimal) or self._tokens[-1] == ')'):
                self._tokens.append('×')
            self._tokens.append('(')
            self._entrada, self._nova = '0', True
            self._expressao = texto_tokens_rot(self._tokens, self._rotulos)
            return
        if k == ')':
            if self._tokens.count('(') <= self._tokens.count(')'):
                return
            self._empurrar_entrada()
            self._tokens.append(')')
            self._mostrar_parcial()
            self._expressao = texto_tokens_rot(self._tokens, self._rotulos)
            return
        if k == '=':
            if self._expressao.endswith('=') and not self._tokens:
                return
            if not (self._tokens and self._tokens[-1] == ')' and self._nova):
                self._empurrar_entrada()
            self._tokens += [')'] * (self._tokens.count('(') - self._tokens.count(')'))
            expr = texto_tokens_rot(self._tokens, self._rotulos)
            r = calcular(self._tokens, self._modo == 'padrao')
            self._tokens, self._rotulos = [], {}
            self._definir(r)
            self._expressao = expr + ' ='
            self._historico.insert(0, dict(expressao=self._expressao, resultado=formatar(r)))
            del self._historico[100:]
            self._gravar()
            self.historicoMudou.emit()
            return
        if k == '±':
            if self._entrada.startswith('-'):
                self._entrada = self._entrada[1:]
            elif self._entrada != '0':
                self._entrada = '-' + self._entrada
            return
        if k == '%':
            x = self._valor()
            # em "a + b%", b% é b por cento de a (como no Windows); senão, b/100
            if len(self._tokens) >= 2 and self._tokens[-1] in ('+', '-') and isinstance(self._tokens[-2], Decimal):
                self._definir(self._tokens[-2] * x / 100, formatar(self._tokens[-2] * x / 100))
            else:
                self._definir(x / 100, formatar(x / 100))
            self._expressao = (texto_tokens_rot(self._tokens, self._rotulos) + ' ' + self._func_rotulo).strip()
            return
        if k == 'π':
            self._definir(Decimal('3.141592653589793238462643383279503'), 'π')
            return
        if k == 'e':
            self._definir(Decimal(1).exp(), 'e')
            return
        # funções de um número
        x = self._valor()
        base = self._func_rotulo or formatar(x)
        f = FUNCOES.get(k)
        if not f:
            return
        rot, fn = f
        r = fn(self, x)
        self._definir(r, rot % base)
        self._expressao = (texto_tokens_rot(self._tokens, self._rotulos) + ' ' + self._func_rotulo).strip()

    def _empurrar_entrada(self):
        v = self._valor()
        if self._func_rotulo:
            self._rotulos[len(self._tokens)] = self._func_rotulo
        self._tokens.append(v)
        self._func_rotulo = ''
        self._nova = True

    def _ang(self, x):
        return math.radians(float(x)) if self._graus else float(x)

    # ---- histórico, memória, área de transferência
    @Slot()
    def limparHistorico(self):
        self._historico = []
        self._gravar()
        self.historicoMudou.emit()

    @Slot(int)
    def usarHistorico(self, i):
        if 0 <= i < len(self._historico):
            self._erro = ''
            self._tokens, self._rotulos = [], {}
            self._entrada = format(ler_numero(self._historico[i]['resultado']).normalize(), 'f')
            self._nova = True
            self._expressao = self._historico[i]['expressao']
            self.mudou.emit()

    @Slot(str)
    def mem(self, acao):
        try:
            v = self._valor()
        except InvalidOperation:
            return
        if acao == 'MS':
            self._memoria.insert(0, str(v))
        elif acao in ('M+', 'M-'):
            if not self._memoria:
                self._memoria.insert(0, '0')
            m = Decimal(self._memoria[0])
            self._memoria[0] = str(m + v if acao == 'M+' else m - v)
        elif acao == 'MR' and self._memoria:
            self._definir(Decimal(self._memoria[0]))
            self.mudou.emit()
        elif acao == 'MC':
            self._memoria = []
        self._nova = True
        self._gravar()
        self.memoriaMudou.emit()

    @Slot(int, str)
    def memItem(self, i, acao):
        if not (0 <= i < len(self._memoria)):
            return
        if acao == 'usar':
            self._definir(Decimal(self._memoria[i]))
            self.mudou.emit()
            return
        if acao == 'apagar':
            del self._memoria[i]
        else:
            v = self._valor()
            m = Decimal(self._memoria[i])
            self._memoria[i] = str(m + v if acao == '+' else m - v)
        self._gravar()
        self.memoriaMudou.emit()

    @Slot()
    def copiar(self):
        QGuiApplication.clipboard().setText(self.visor)

    @Slot()
    def colar(self):
        t = QGuiApplication.clipboard().text().strip()
        try:
            d = ler_numero(t)
        except (InvalidOperation, ValueError):
            return
        self._erro = ''
        self._definir(d)
        self._nova = False
        self._entrada = format(d.normalize(), 'f')
        self.mudou.emit()


def texto_tokens_rot(tokens, rotulos):
    r = []
    for i, t in enumerate(tokens):
        if i in rotulos:
            r.append(rotulos[i])
        elif isinstance(t, Decimal):
            r.append(formatar(t))
        else:
            r.append(t)
    return ' '.join(r).replace('( ', '(').replace(' )', ')')


def _fat(c, x):
    if x < 0 or x != x.to_integral_value() or x > 3000:
        raise Erro('Entrada inválida')
    return Decimal(math.factorial(int(x)))


def _inv(c, x):
    if x == 0:
        raise Erro('Não é possível dividir por zero')
    return 1 / x


def _raiz(c, x):
    if x < 0:
        raise Erro('Entrada inválida')
    return x.sqrt()


def _log(c, x, f):
    if x <= 0:
        raise Erro('Entrada inválida')
    return f(x)


def _trig(nome):
    def f(c, x):
        v = getattr(math, nome)(c._ang(x))
        if nome == 'tan' and abs(math.cos(c._ang(x))) < 1e-15:
            raise Erro('Entrada inválida')
        r = Decimal(repr(round(v, 15)))
        return Decimal(0) if abs(r) < Decimal('1e-15') else r
    return f


def _arco(nome):
    def f(c, x):
        if nome in ('asin', 'acos') and abs(x) > 1:
            raise Erro('Entrada inválida')
        v = getattr(math, nome)(float(x))
        return Decimal(repr(round(math.degrees(v) if c._graus else v, 15)))
    return f


FUNCOES = {
    '1/x': ('1/(%s)', _inv),
    'x²': ('sqr(%s)', lambda c, x: x * x),
    'x³': ('cube(%s)', lambda c, x: x * x * x),
    '√x': ('√(%s)', _raiz),
    '∛x': ('cuberoot(%s)', lambda c, x: (-1 if x < 0 else 1) * Decimal(repr(abs(float(x)) ** (1 / 3))).quantize(Decimal('1e-14')).normalize()),
    '10ˣ': ('10^(%s)', lambda c, x: potencia(Decimal(10), x)),
    'eˣ': ('e^(%s)', lambda c, x: x.exp()),
    'log': ('log(%s)', lambda c, x: _log(c, x, lambda v: v.log10())),
    'ln': ('ln(%s)', lambda c, x: _log(c, x, lambda v: v.ln())),
    'n!': ('fact(%s)', _fat),
    '|x|': ('abs(%s)', lambda c, x: abs(x)),
    'sin': ('sin(%s)', _trig('sin')),
    'cos': ('cos(%s)', _trig('cos')),
    'tan': ('tan(%s)', _trig('tan')),
    'sin⁻¹': ('sin⁻¹(%s)', _arco('asin')),
    'cos⁻¹': ('cos⁻¹(%s)', _arco('acos')),
    'tan⁻¹': ('tan⁻¹(%s)', _arco('atan')),
}


def main():
    from base import iniciar
    return iniciar('carinaeos-calculadora', 'Carinae Calculadora', 'carinaeos-calculadora',
                   os.path.join(AQUI, 'Main.qml'), {'calc': Calculadora})


if __name__ == '__main__':
    sys.exit(main())
