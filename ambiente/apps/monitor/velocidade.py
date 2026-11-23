#!/usr/bin/env python3
# CarinaeOS — teste de velocidade da internet (o mesmo método do speed.cloudflare.com, sem programas extra).
#   ping/jitter: 20 pedidos vazios na mesma ligação (tira o tempo que o servidor gastou)
#   download/upload: 4 ligações em paralelo durante ~10 s; o 1.º segundo não conta (arranque do TCP)
#   latência com carga: pings enquanto descarrega/envia (mostra se a ligação "engasga" — bufferbloat)
#   perda de pacotes: ping ICMP para 1.1.1.1 (se o sistema deixar)
# Sozinho: python3 velocidade.py   (CARINAE_VELOCIDADE_URL=http://localhost:8000 para testar com outro servidor)
import http.client
import json
import os
import re
import ssl
import statistics
import subprocess
import threading
import time
import urllib.parse

BASE = os.environ.get('CARINAE_VELOCIDADE_URL', 'https://speed.cloudflare.com')
LIGACOES = 4
DURACAO = 10.0
AQUECER = 1.0
BLOCO_DOWN = 25_000_000
BLOCO_UP = 8_000_000
UA = {'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) CarinaeOS-Monitor/1.0', 'Cache-Control': 'no-store'}


def _ligar():
    u = urllib.parse.urlsplit(BASE)
    if u.scheme == 'https':
        return http.client.HTTPSConnection(u.hostname, u.port or 443, timeout=15, context=ssl.create_default_context())
    return http.client.HTTPConnection(u.hostname, u.port or 80, timeout=15)


def _duracao_servidor(resp):
    # "Server-Timing: cfRequestDuration;dur=12.3" — o tempo que o servidor demorou, em ms
    m = re.search(r'dur=([\d.]+)', resp.getheader('Server-Timing') or '')
    return float(m.group(1)) if m else 0.0


def _rtt(con):
    t0 = time.perf_counter()
    con.request('GET', '/__down?bytes=0', headers=UA)
    r = con.getresponse()
    r.read()
    t = (time.perf_counter() - t0) * 1000 - _duracao_servidor(r)
    return max(0.1, t)


def info():
    """Onde está o servidor e quem é o fornecedor (o que a Cloudflare vê)."""
    try:
        con = _ligar()
        con.request('GET', '/meta', headers=UA)
        d = json.loads(con.getresponse().read() or b'{}')
        con.close()
        return dict(ip=d.get('clientIp', ''), isp=d.get('asOrganization', ''),
                    servidor=', '.join(x for x in (d.get('city'), d.get('colo')) if x),
                    pais=d.get('country', ''))
    except Exception:
        return dict(ip='', isp='', servidor='', pais='')


def medir_ping(n=20, parar=None):
    con = _ligar()
    _rtt(con)                      # a 1.ª inclui o aperto de mão TLS: não conta
    v = []
    for _ in range(n):
        if parar and parar.is_set():
            break
        v.append(_rtt(con))
        time.sleep(0.05)
    con.close()
    return v


def jitter(v):
    return statistics.mean(abs(a - b) for a, b in zip(v, v[1:])) if len(v) > 1 else 0.0


def perda_pacotes():
    try:
        r = subprocess.run(['ping', '-n', '-q', '-c', '20', '-i', '0.2', '-W', '1', '1.1.1.1'],
                           capture_output=True, text=True, timeout=15)
        m = re.search(r'([\d.]+)% packet loss', r.stdout)
        return float(m.group(1)) if m else None
    except Exception:
        return None


class _Contador:
    def __init__(self):
        self.lock = threading.Lock()
        self.amostras = []         # (instante, bytes acumulados)
        self.total = 0

    def somar(self, n):
        with self.lock:
            self.total += n
            self.amostras.append((time.perf_counter(), self.total))

    def mbps(self, desde):
        with self.lock:
            a = [x for x in self.amostras if x[0] >= desde]
        if len(a) < 2 or a[-1][0] - a[0][0] < 0.2:
            return 0.0
        return (a[-1][1] - a[0][1]) * 8 / (a[-1][0] - a[0][0]) / 1e6


def _descarregar(cont, fim, parar):
    while time.perf_counter() < fim and not parar.is_set():
        try:
            con = _ligar()
            con.request('GET', '/__down?bytes=%d' % BLOCO_DOWN, headers=UA)
            r = con.getresponse()
            while time.perf_counter() < fim and not parar.is_set():
                b = r.read(65536)
                if not b:
                    break
                cont.somar(len(b))
            con.close()
        except Exception:
            time.sleep(0.2)


def _enviar(cont, fim, parar):
    bloco = os.urandom(65536)
    while time.perf_counter() < fim and not parar.is_set():
        try:
            con = _ligar()
            con.putrequest('POST', '/__up')
            con.putheader('Content-Type', 'application/octet-stream')
            con.putheader('User-Agent', UA['User-Agent'])
            con.putheader('Content-Length', str(BLOCO_UP))
            con.endheaders()
            enviado = 0
            while enviado < BLOCO_UP and time.perf_counter() < fim and not parar.is_set():
                n = min(len(bloco), BLOCO_UP - enviado)
                con.send(bloco[:n])
                enviado += n
                cont.somar(n)
            if enviado >= BLOCO_UP:
                con.getresponse().read()
            con.close()
        except Exception:
            time.sleep(0.2)


def _fase_transferencia(funcao, aviso, nome, parar):
    """Corre download ou upload; devolve (mbps, latências com carga)."""
    cont = _Contador()
    inicio = time.perf_counter()
    fim = inicio + DURACAO
    fios = [threading.Thread(target=funcao, args=(cont, fim, parar), daemon=True) for _ in range(LIGACOES)]
    for f in fios:
        f.start()
    lat = []

    def pingar():
        try:
            con = _ligar()
            _rtt(con)
            while time.perf_counter() < fim - 0.3 and not parar.is_set():
                lat.append(_rtt(con))
                time.sleep(0.4)
            con.close()
        except Exception:
            pass
    pf = threading.Thread(target=pingar, daemon=True)
    pf.start()
    while time.perf_counter() < fim and not parar.is_set():
        time.sleep(0.2)
        agora = time.perf_counter()
        aviso(nome, cont.mbps(max(inicio + 0.3, agora - 2.0)), min(1.0, (agora - inicio) / DURACAO))
    for f in fios:
        f.join(2)
    pf.join(1)
    return cont.mbps(inicio + AQUECER), lat


def testar(aviso=lambda fase, valor, progresso: None, parar=None):
    """aviso(fase, valor, progresso) vai sendo chamado; devolve o resultado (dict)."""
    parar = parar or threading.Event()
    r = dict(quando=time.strftime('%Y-%m-%d %H:%M'), erro='')
    perda = {}
    fp = threading.Thread(target=lambda: perda.setdefault('v', perda_pacotes()), daemon=True)
    try:
        aviso('ligar', 0, 0)
        r.update(info())
        aviso('ping', 0, 0)
        fp.start()
        p = medir_ping(parar=parar)
        if not p:
            raise OSError('sem resposta do servidor')
        r['ping'] = statistics.median(p)
        r['jitter'] = jitter(p)
        aviso('ping', r['ping'], 1)
        r['download'], ld = _fase_transferencia(_descarregar, aviso, 'download', parar)
        r['latDown'] = statistics.median(ld) if ld else 0.0
        r['upload'], lu = _fase_transferencia(_enviar, aviso, 'upload', parar)
        r['latUp'] = statistics.median(lu) if lu else 0.0
        fp.join(16)
        r['perda'] = perda.get('v')
    except Exception as e:
        r['erro'] = str(e) or e.__class__.__name__
    if parar.is_set():
        r['erro'] = 'cancelado'
    aviso('fim', 0, 1)
    return r


if __name__ == '__main__':
    def mostrar(f, v, p):
        print('\r%-9s %8.1f  %3d%%' % (f, v, p * 100), end='', flush=True)
    res = testar(mostrar)
    print()
    print(json.dumps(res, indent=1, ensure_ascii=False))
