#!/usr/bin/env python3
# CarinaeOS — Monitor do sistema: processos, desempenho (CPU, memória, discos, rede, GPU) e o teste de
# velocidade da internet. Parecido com o Gerenciador de Tarefas do Windows 11.
#   carinaeos-monitor [processos|desempenho|velocidade]
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import threading
import time

import psutil

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import velocidade as VEL  # noqa: E402

HIST = 60
HISTORICO_VEL = os.path.expanduser('~/.local/share/carinaeos/velocidade.json')
PAGINAS = ('processos', 'desempenho', 'velocidade', 'arranque')


def tamanho(n, sufixo='B'):
    for u in ('', 'K', 'M', 'G', 'T'):
        if abs(n) < 1024 or u == 'T':
            return ('%.0f %s%s' if u in ('', 'K') else '%.1f %s%s') % (n, u, sufixo)
        n /= 1024.0


def bits(bps):
    # rede: em bits por segundo, como os fornecedores anunciam
    for u in ('bps', 'Kbps', 'Mbps', 'Gbps'):
        if bps < 1000 or u == 'Gbps':
            return ('%.0f %s' if u == 'bps' else '%.1f %s') % (bps, u)
        bps /= 1000.0


def _tempo(seg):
    d, r = divmod(int(seg), 86400)
    h, r = divmod(r, 3600)
    m, s = divmod(r, 60)
    return ('%d:' % d if d else '') + '%02d:%02d:%02d' % (h, m, s)


# ---- ícones: o nome do processo -> o ícone do aplicativo (pelos .desktop, sem precisar do Gio) ----------
def _mapa_icones():
    mapa = {}
    pastas = [os.path.expanduser('~/.local/share/applications'), '/usr/local/share/applications',
              '/usr/share/applications', '/var/lib/flatpak/exports/share/applications']
    for p in reversed(pastas):
        try:
            nomes = os.listdir(p)
        except OSError:
            continue
        for n in nomes:
            if not n.endswith('.desktop'):
                continue
            try:
                txt = open(os.path.join(p, n), encoding='utf-8', errors='ignore').read().split('\n[', 1)[0]
            except OSError:
                continue
            ico = re.search(r'^Icon=(.+)$', txt, re.M)
            nome = re.search(r'^Name=(.+)$', txt, re.M)
            exe = re.search(r'^Exec=(\S+)', txt, re.M)
            wm = re.search(r'^StartupWMClass=(.+)$', txt, re.M)
            if not ico:
                continue
            d = dict(icone=ico.group(1).strip(), nome=nome.group(1).strip() if nome else '')
            for chave in (exe and os.path.basename(exe.group(1).strip('"')), wm and wm.group(1).strip(), n[:-8]):
                if chave and chave not in ('env', 'sh', 'flatpak', 'python3', 'bash'):
                    mapa[chave.lower()] = d
    return mapa


SISTEMA = {'systemd', 'dbus-daemon', 'dbus-broker', 'pipewire', 'pipewire-pulse', 'wireplumber', 'at-spi-bus-launcher',
           'at-spi2-registryd', 'gvfsd', 'xdg-desktop-portal', 'xdg-document-portal', 'xdg-permission-store',
           'gnome-keyring-daemon', 'Xorg', 'picom', 'sd-pam', 'gvfsd-fuse', 'gvfs-udisks2-volume-monitor',
           'dconf-service', 'obexd', 'xdg-desktop-portal-gtk', 'ssh-agent', 'gpg-agent', 'kworker'}


class Coletor:
    """Lê o estado do computador. Corre na thread principal a cada segundo (é barato)."""

    def __init__(self):
        self.cpu = [0.0] * HIST
        self.mem = [0.0] * HIST
        self.discos = {}      # nome -> dict(hist, ...)
        self.redes = {}
        self.gpu = None
        self._io_disco = psutil.disk_io_counters(perdisk=True) or {}
        self._io_rede = psutil.net_io_counters(pernic=True) or {}
        self._t = time.monotonic()
        self._gpu_fio = None
        self._modelo_cpu = self._ler_modelo_cpu()
        self._boot = psutil.boot_time()
        psutil.cpu_percent(None)
        self.nucleos = [0.0] * (psutil.cpu_count() or 1)
        psutil.cpu_percent(None, percpu=True)

    @staticmethod
    def _ler_modelo_cpu():
        try:
            for l in open('/proc/cpuinfo'):
                if l.startswith('model name'):
                    return re.sub(r'\s+', ' ', l.split(':', 1)[1]).strip()
        except OSError:
            pass
        return 'Processador'

    @staticmethod
    def _discos_fisicos():
        # sda, nvme0n1, mmcblk0 (sem as partições nem os loop/zram)
        r = {}
        for n in os.listdir('/sys/block'):
            if n.startswith(('loop', 'ram', 'zram', 'dm-', 'sr', 'fd')):
                continue
            try:
                modelo = open('/sys/block/%s/device/model' % n).read().strip()
            except OSError:
                modelo = ''
            try:
                rot = open('/sys/block/%s/queue/rotational' % n).read().strip() == '1'
            except OSError:
                rot = False
            tipo = 'HDD' if rot else ('SSD (NVMe)' if n.startswith('nvme') else 'SSD')
            try:
                tam = int(open('/sys/block/%s/size' % n).read()) * 512
            except (OSError, ValueError):
                tam = 0
            r[n] = dict(modelo=modelo, tipo=tipo, tamanho=tam)
        return r

    def _ler_gpu(self):
        # NVIDIA (nvidia-smi) ou AMD/Intel (/sys/class/drm/card*/device/gpu_busy_percent)
        if shutil.which('nvidia-smi'):
            try:
                o = subprocess.run(['nvidia-smi', '--query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu',
                                    '--format=csv,noheader,nounits'], capture_output=True, text=True, timeout=3).stdout
                n, u, mu, mt, t = [x.strip() for x in o.splitlines()[0].split(',')]
                return dict(nome=n, uso=float(u), memUsada=float(mu) * 1048576, memTotal=float(mt) * 1048576, temp=t)
            except Exception:
                pass
        for c in sorted(os.listdir('/sys/class/drm')) if os.path.isdir('/sys/class/drm') else []:
            f = '/sys/class/drm/%s/device/gpu_busy_percent' % c
            if re.fullmatch(r'card\d+', c) and os.path.exists(f):
                try:
                    u = float(open(f).read())
                    mu = int(open('/sys/class/drm/%s/device/mem_info_vram_used' % c).read())
                    mt = int(open('/sys/class/drm/%s/device/mem_info_vram_total' % c).read())
                except (OSError, ValueError):
                    mu = mt = 0
                return dict(nome='Placa gráfica (%s)' % c, uso=u, memUsada=mu, memTotal=mt, temp='')
        return None

    def atualizar(self):
        agora = time.monotonic()
        dt = max(0.2, agora - self._t)
        self._t = agora
        self.cpu = self.cpu[1:] + [psutil.cpu_percent(None)]
        self.nucleos = psutil.cpu_percent(None, percpu=True)
        vm = psutil.virtual_memory()
        self.mem = self.mem[1:] + [vm.percent]
        self.vm = vm
        self.swap = psutil.swap_memory()

        io = psutil.disk_io_counters(perdisk=True) or {}
        fis = self._discos_fisicos() if not hasattr(self, '_fis') or int(agora) % 30 == 0 else self._fis
        self._fis = fis
        for n, info in fis.items():
            a, b = self._io_disco.get(n), io.get(n)
            d = self.discos.setdefault(n, dict(hist=[0.0] * HIST, ler=0, escrever=0))
            if a and b:
                d['ler'] = (b.read_bytes - a.read_bytes) / dt
                d['escrever'] = (b.write_bytes - a.write_bytes) / dt
                ativo = min(100.0, (b.busy_time - a.busy_time) / (dt * 10)) if hasattr(b, 'busy_time') else 0.0
                d['hist'] = d['hist'][1:] + [ativo]
            d.update(info)
        for n in list(self.discos):
            if n not in fis:
                del self.discos[n]
        self._io_disco = io

        rede = psutil.net_io_counters(pernic=True) or {}
        est = psutil.net_if_stats()
        for n, b in rede.items():
            if n == 'lo' or n.startswith(('veth', 'docker', 'br-', 'virbr', 'tun', 'tap')) or not (est.get(n) and est[n].isup):
                self.redes.pop(n, None)
                continue
            a = self._io_rede.get(n)
            r = self.redes.setdefault(n, dict(hist=[0.0] * HIST, envio=0, rececao=0))
            if a:
                r['envio'] = (b.bytes_sent - a.bytes_sent) * 8 / dt
                r['rececao'] = (b.bytes_recv - a.bytes_recv) * 8 / dt
            r['hist'] = r['hist'][1:] + [r['envio'] + r['rececao']]
            r['wifi'] = os.path.isdir('/sys/class/net/%s/wireless' % n) or n.startswith('wl')
            r['velocidade'] = est[n].speed
        self._io_rede = rede

        # a GPU numa thread (o nvidia-smi pode demorar)
        if self._gpu_fio is None or not self._gpu_fio.is_alive():
            def g():
                novo = self._ler_gpu()
                if novo:
                    h = (self.gpu or {}).get('hist', [0.0] * HIST)
                    novo['hist'] = h[1:] + [novo['uso']]
                self.gpu = novo
            self._gpu_fio = threading.Thread(target=g, daemon=True)
            self._gpu_fio.start()

    def dispositivos(self):
        """A lista da esquerda da página Desempenho, com os detalhes de cada um."""
        r = []
        freq = psutil.cpu_freq()
        try:
            temps = psutil.sensors_temperatures()
            t = next((x.current for k in ('k10temp', 'coretemp', 'zenpower', 'cpu_thermal', 'acpitz') for x in temps.get(k, [])), None)
        except Exception:
            t = None
        try:
            carga = os.getloadavg()
        except OSError:
            carga = (0, 0, 0)
        procs = len(psutil.pids())
        r.append(dict(id='cpu', titulo='CPU', nome=self._modelo_cpu, resumo='%d%%  %.2f GHz' % (self.cpu[-1], (freq.current if freq else 0) / 1000),
                      valor=self.cpu[-1], hist=self.cpu, maximo=100, cor='#7aa7ff', escala='100%', nucleos=self.nucleos,
                      grandes=[['Utilização', '%d%%' % self.cpu[-1]], ['Velocidade', '%.2f GHz' % ((freq.current if freq else 0) / 1000)],
                               ['Processos', str(procs)], ['Ligado há', _tempo(time.time() - self._boot)]],
                      detalhes=[['Núcleos lógicos', str(psutil.cpu_count())], ['Núcleos físicos', str(psutil.cpu_count(False) or '?')],
                                ['Carga média (1/5/15 min)', '%.2f  %.2f  %.2f' % carga]] +
                               ([['Velocidade máxima', '%.2f GHz' % (freq.max / 1000)]] if freq and freq.max else []) +
                               ([['Temperatura', '%.0f °C' % t]] if t else [])))
        vm, sw = self.vm, self.swap
        r.append(dict(id='mem', titulo='Memória', nome=tamanho(vm.total),
                      resumo='%.1f/%.1f GB (%d%%)' % ((vm.total - vm.available) / 2**30, vm.total / 2**30, vm.percent),
                      valor=vm.percent, hist=self.mem, maximo=100, cor='#c58aff', escala=tamanho(vm.total), nucleos=[],
                      grandes=[['Em uso', tamanho(vm.total - vm.available)], ['Disponível', tamanho(vm.available)],
                               ['Em cache', tamanho(getattr(vm, 'cached', 0) + getattr(vm, 'buffers', 0))],
                               ['Troca (swap)', '%s de %s' % (tamanho(sw.used), tamanho(sw.total))]],
                      detalhes=[['Total', tamanho(vm.total)], ['Compartilhada', tamanho(getattr(vm, 'shared', 0))]],
                      memoria=dict(usada=(vm.total - vm.available) / vm.total, cache=(getattr(vm, 'cached', 0) + getattr(vm, 'buffers', 0)) / vm.total)))
        for i, (n, d) in enumerate(sorted(self.discos.items())):
            uso = []
            for p in psutil.disk_partitions():
                if os.path.basename(p.device).startswith(n):
                    try:
                        u = psutil.disk_usage(p.mountpoint)
                        uso.append('%s  %s livres de %s' % (p.mountpoint, tamanho(u.free), tamanho(u.total)))
                    except OSError:
                        pass
            r.append(dict(id='disco:' + n, titulo='Disco %d (%s)' % (i, n), nome=d['modelo'] or n,
                          resumo='%s\n%d%%' % (d['tipo'], d['hist'][-1]), valor=d['hist'][-1], hist=d['hist'], maximo=100,
                          cor='#5fd39a', escala='100%', nucleos=[],
                          grandes=[['Tempo ativo', '%d%%' % d['hist'][-1]], ['Leitura', tamanho(d['ler'], 'B/s')],
                                   ['Escrita', tamanho(d['escrever'], 'B/s')], ['Tipo', d['tipo']]],
                          detalhes=[['Capacidade', tamanho(d['tamanho'])]] + [['Montado', x] for x in uso[:4]]))
        for n, d in sorted(self.redes.items()):
            topo = max(max(d['hist']), 100_000)
            addrs = psutil.net_if_addrs().get(n, [])
            ip4 = next((a.address for a in addrs if a.family.name == 'AF_INET'), '')
            ip6 = next((a.address.split('%')[0] for a in addrs if a.family.name == 'AF_INET6'), '')
            r.append(dict(id='rede:' + n, titulo='Wi-Fi' if d['wifi'] else 'Ethernet', nome=n,
                          resumo='E: %s  R: %s' % (bits(d['envio']), bits(d['rececao'])),
                          valor=100 * (d['hist'][-1] / topo), hist=[100 * x / topo for x in d['hist']], maximo=100,
                          cor='#ffb46e', escala=bits(topo), nucleos=[],
                          grandes=[['Enviar', bits(d['envio'])], ['Receber', bits(d['rececao'])]],
                          detalhes=[['Adaptador', n], ['Velocidade da conexão', ('%d Mbps' % d['velocidade']) if d['velocidade'] else '—'],
                                    ['Endereço IPv4', ip4 or '—'], ['Endereço IPv6', ip6 or '—']]))
        if self.gpu:
            g = self.gpu
            r.append(dict(id='gpu', titulo='GPU 0', nome=g['nome'], resumo='%d%%' % g['uso'] + (' (%s °C)' % g['temp'] if g['temp'] else ''),
                          valor=g['uso'], hist=g.get('hist', [0.0] * HIST), maximo=100, cor='#ff7a9a', escala='100%', nucleos=[],
                          grandes=[['Utilização', '%d%%' % g['uso']], ['Memória dedicada', '%s/%s' % (tamanho(g['memUsada']), tamanho(g['memTotal']))]] +
                                  ([['Temperatura', '%s °C' % g['temp']]] if g['temp'] else []),
                          detalhes=[]))
        return r


class Processos:
    """Agrupa por aplicativo (como o Windows): "Firefox (12)" em vez de 12 linhas iguais."""

    def __init__(self):
        self._mapa = _mapa_icones()
        self._cache = {}
        self._io = {}
        self.uid = os.getuid()
        self.ncpu = psutil.cpu_count() or 1

    def ler(self):
        grupos = {}
        agora = time.monotonic()
        vivos = set()
        for p in psutil.process_iter(['pid', 'name', 'exe', 'cmdline', 'uids', 'memory_info', 'ppid']):
            try:
                pid = p.info['pid']
                vivos.add(pid)
                if pid not in self._cache:
                    self._cache[pid] = p
                    p.cpu_percent(None)
                    cpu = 0.0
                else:
                    cpu = self._cache[pid].cpu_percent(None) / self.ncpu
                nome = p.info['name'] or '?'
                cmd = p.info['cmdline'] or []
                # scripts: "python3 /…/comando.py" -> comando
                if nome.startswith(('python', 'node', 'gjs', 'perl', 'ruby')) and len(cmd) > 1 and '-c' not in cmd:
                    for a in cmd[1:]:
                        if not a.startswith('-'):
                            if a.endswith(('.py', '.js', '.pl', '.rb')) or '/' in a:
                                nome = os.path.splitext(os.path.basename(a))[0] or nome
                            break
                mem = p.info['memory_info'].rss if p.info['memory_info'] else 0
                try:
                    io = self._cache[pid].io_counters()
                    tot = io.read_bytes + io.write_bytes
                    antes = self._io.get(pid)
                    disco = (tot - antes[0]) / max(0.2, agora - antes[1]) if antes else 0.0
                    self._io[pid] = (tot, agora)
                except (psutil.Error, OSError):
                    disco = 0.0
                meu = p.info['uids'] and p.info['uids'].real == self.uid
                chave = nome.lower()
                m = self._mapa.get(chave) or self._mapa.get(chave.split('-')[0])
                if not cmd or p.info['ppid'] == 2 or pid == 2:      # fios do núcleo (kworker, irq/…)
                    tipo = 'sistema'
                elif meu and m and nome not in SISTEMA:
                    tipo = 'app'
                elif meu:
                    tipo = 'fundo'
                else:
                    tipo = 'sistema'
                g = grupos.setdefault((tipo, chave), dict(nome=(m['nome'] if m and m['nome'] else nome), icone=m['icone'] if m else '',
                                                          tipo=tipo, cpu=0.0, mem=0, disco=0.0, pids=[], meu=bool(meu), exe=nome))
                g['cpu'] += cpu
                g['mem'] += mem
                g['disco'] += disco
                g['pids'].append(pid)
            except (psutil.Error, OSError, TypeError):
                continue
        for pid in list(self._cache):
            if pid not in vivos:
                self._cache.pop(pid, None)
                self._io.pop(pid, None)
        r = []
        for g in grupos.values():
            g['n'] = len(g['pids'])
            g['memTxt'] = tamanho(g['mem'])
            g['discoTxt'] = tamanho(g['disco'], 'B/s') if g['disco'] >= 1024 else '0 MB/s'
            g['cpuTxt'] = '%.1f%%' % g['cpu']
            g['pidsTxt'] = ','.join(map(str, g['pids']))
            del g['pids']
            r.append(g)
        return r


def finalizar(pids_txt, forca=False):
    pids = [int(x) for x in pids_txt.split(',') if x.strip().isdigit()]
    for pid in pids:
        try:
            os.kill(pid, signal.SIGKILL if forca else signal.SIGTERM)
        except OSError:
            pass
    if not forca:
        # o que não fechar em 3 s fecha-se à força
        def depois():
            time.sleep(3)
            for pid in pids:
                try:
                    os.kill(pid, signal.SIGKILL)
                except OSError:
                    pass
        threading.Thread(target=depois, daemon=True).start()


# ---- programas que arrancam com a sessão (~/.config/autostart e /etc/xdg/autostart) -------------------------
def arranque():
    r = {}
    for base in ('/etc/xdg/autostart', os.path.expanduser('~/.config/autostart')):
        try:
            nomes = sorted(os.listdir(base))
        except OSError:
            continue
        for n in nomes:
            if not n.endswith('.desktop'):
                continue
            try:
                txt = open(os.path.join(base, n), encoding='utf-8', errors='ignore').read().split('\n[', 1)[0]
            except OSError:
                continue
            g = lambda k: (re.search(r'^%s=(.*)$' % k, txt, re.M) or [None, ''])[1].strip()
            so = g('OnlyShowIn')
            if so and 'CarinaeOS' not in so:
                r.pop(n, None)
                continue
            if 'CarinaeOS' in g('NotShowIn'):
                continue
            ligado = g('Hidden').lower() != 'true' and g('X-GNOME-Autostart-enabled').lower() != 'false'
            r[n] = dict(ficheiro=n, nome=g('Name') or n[:-8], icone=g('Icon'), comando=g('Exec'), ligado=ligado,
                        sistema=base.startswith('/etc'))
    return sorted(r.values(), key=lambda x: x['nome'].lower())


def ligar_arranque(ficheiro, ligar):
    pessoal = os.path.expanduser('~/.config/autostart/' + ficheiro)
    os.makedirs(os.path.dirname(pessoal), exist_ok=True)
    origem = pessoal if os.path.exists(pessoal) else '/etc/xdg/autostart/' + ficheiro
    try:
        txt = open(origem, encoding='utf-8').read()
    except OSError:
        return
    linhas = [l for l in txt.split('\n') if not l.startswith(('Hidden=', 'X-GNOME-Autostart-enabled='))]
    i = next((k for k, l in enumerate(linhas) if l.strip() == '[Desktop Entry]'), 0)
    linhas.insert(i + 1, 'Hidden=%s' % ('false' if ligar else 'true'))
    open(pessoal, 'w', encoding='utf-8').write('\n'.join(linhas))


def main():
    sys.path.insert(0, os.environ.get('CARINAE_COMUM') or next(
        (d for d in ('/usr/local/share/carinaeos/comum', '/usr/share/carinaeos/comum') if os.path.isdir(d)),
        '/usr/share/carinaeos/comum'))
    from base import iniciar
    from PySide6.QtCore import QObject, Property, QTimer, Signal, Slot

    class Monitor(QObject):
        mudou = Signal()
        processosMudaram = Signal()
        velMudou = Signal()
        arranqueMudou = Signal()
        _aviso = Signal(str, float, float)
        _resultado = Signal('QVariantMap')

        def __init__(self):
            super().__init__()
            pag = next((a for a in sys.argv[1:] if a in PAGINAS), 'processos')
            self._pagina = pag
            self._col = Coletor()
            self._proc = Processos()
            self._disp = []
            self._procs = []
            self._arr = []
            self._vel = dict(fase='', valor=0.0, progresso=0.0, aCorrer=False, resultado={}, ao_vivo=[])
            try:
                self._hist_vel = json.load(open(HISTORICO_VEL, encoding='utf-8'))
            except (OSError, ValueError):
                self._hist_vel = []
            self._parar = None
            self._aviso.connect(self._no_aviso)
            self._resultado.connect(self._no_resultado)
            self._relogio = QTimer(self)
            self._relogio.setInterval(1000)
            self._relogio.timeout.connect(self._tique)
            self._relogio.start()
            self._n = 0
            if pag == 'arranque':
                self._arr = arranque()
            self._tique()

        def _tique(self):
            self._col.atualizar()
            self._disp = self._col.dispositivos()
            self.mudou.emit()
            self._n += 1
            if self._pagina == 'processos' and (self._n % 2 == 1 or not self._procs):
                self._procs = self._proc.ler()
                self.processosMudaram.emit()

        @Property('QVariantList', notify=mudou)
        def dispositivos(self):
            return self._disp

        @Property('QVariantList', notify=processosMudaram)
        def processos(self):
            return self._procs

        @Property(str, constant=True)
        def paginaInicial(self):
            return self._pagina

        @Slot(str)
        def mudarPagina(self, p):
            self._pagina = p
            if p == 'processos':
                self._procs = self._proc.ler()
                self.processosMudaram.emit()
            elif p == 'arranque':
                self._arr = arranque()
                self.arranqueMudou.emit()

        @Slot(str, bool)
        def finalizar(self, pids, forca):
            finalizar(pids, forca)
            QTimer.singleShot(600, lambda: self.mudarPagina(self._pagina))

        # ---- arranque
        @Property('QVariantList', notify=arranqueMudou)
        def arranque(self):
            return self._arr

        @Slot(str, bool)
        def ligarArranque(self, ficheiro, ligar):
            ligar_arranque(ficheiro, ligar)
            self._arr = arranque()
            self.arranqueMudou.emit()

        # ---- velocidade
        @Property('QVariantMap', notify=velMudou)
        def vel(self):
            return self._vel

        @Property('QVariantList', notify=velMudou)
        def historicoVel(self):
            return list(reversed(self._hist_vel[-20:]))

        @Slot()
        def testarVelocidade(self):
            if self._vel['aCorrer']:
                self._parar.set()
                return
            self._parar = threading.Event()
            self._vel = dict(fase='ligar', valor=0.0, progresso=0.0, aCorrer=True, resultado={}, ao_vivo=[])
            self.velMudou.emit()
            parar = self._parar
            threading.Thread(target=lambda: self._resultado.emit(VEL.testar(self._aviso.emit, parar)), daemon=True).start()

        def _no_aviso(self, fase, valor, progresso):
            v = dict(self._vel)
            res = dict(v['resultado'])
            if fase != v['fase']:
                if v['fase'] in ('download', 'upload'):
                    res[v['fase']] = v['valor']      # provisório; o valor final chega no fim do teste
                v['ao_vivo'] = []
            if fase == 'ping' and progresso >= 1:
                res['ping'] = valor
            elif fase in ('download', 'upload'):
                v['ao_vivo'] = (v['ao_vivo'] + [valor])[-60:]
            v.update(fase=fase, valor=valor, progresso=progresso, resultado=res)
            self._vel = v
            self.velMudou.emit()

        def _no_resultado(self, r):
            v = dict(self._vel, aCorrer=False, fase='fim' if not r.get('erro') else 'erro', resultado=r, progresso=1.0)
            self._vel = v
            if not r.get('erro'):
                self._hist_vel.append(r)
                self._hist_vel = self._hist_vel[-50:]
                try:
                    os.makedirs(os.path.dirname(HISTORICO_VEL), exist_ok=True)
                    json.dump(self._hist_vel, open(HISTORICO_VEL, 'w', encoding='utf-8'), ensure_ascii=False)
                except OSError:
                    pass
            self.velMudou.emit()

        @Slot(str)
        def copiar(self, t):
            from PySide6.QtGui import QGuiApplication
            QGuiApplication.clipboard().setText(t)

    return iniciar('carinaeos-monitor', 'Carinae Monitor', 'utilities-system-monitor',
                   os.path.join(AQUI, 'Main.qml'), {'monitor': Monitor})


if __name__ == '__main__':
    sys.exit(main())
