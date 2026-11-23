import os


def procurar(texto, ctx):
    t = texto.strip().lower()
    uid = os.getuid()
    junto = {}
    for pid in os.listdir('/proc'):
        if not pid.isdigit():
            continue
        try:
            if os.stat('/proc/' + pid).st_uid != uid:
                continue
            nome = open('/proc/%s/comm' % pid).read().strip()
            rss = int(open('/proc/%s/statm' % pid).read().split()[1]) * os.sysconf('SC_PAGE_SIZE')
        except OSError:
            continue
        if t and t not in nome.lower():
            continue
        j = junto.setdefault(nome, [0, []])
        j[0] += rss
        j[1].append(pid)
    r = []
    for nome, (rss, pids) in sorted(junto.items(), key=lambda kv: -kv[1][0])[:10]:
        r.append(dict(titulo='Fechar %s' % nome, sub='%d MB de memória · %d processo(s) · Enter fecha à força' % (rss // 1048576, len(pids)),
                      icone='process-stop', acao='correr', valor='kill -9 ' + ' '.join(pids)))
    return r
