#!/bin/bash
# CarinaeOS - instala um pacote seguindo a pagina do livro BLFS 13.1-systemd.
# Uso:  bash blfs.sh <secao/pagina>        ex.: bash blfs.sh general/libtasn1
#       bash blfs.sh <secao/pagina> sim    (nao pergunta antes de compilar)
# O script baixa a pagina do livro, mostra cada bloco de comandos e se vai
# RODAR ou PULAR (testes e exemplos com valores a substituir), baixa o
# pacote, confere o MD5 do livro e executa os blocos na ordem do livro.
set -e
PAG=${1:?uso: bash blfs.sh secao/pagina}
NOME=$(basename $PAG)
B=https://www.linuxfromscratch.org/blfs/view/13.1-systemd
W=/sources/blfs/$NOME
mkdir -p $W /root/blfs-logs && cd $W
LOG=/root/blfs-logs/$NOME.log
exec > >(tee $LOG) 2>&1
export MAKEFLAGS=-j$(nproc) NINJAJOBS=$(nproc)

baixa(){ python3 - "$1" "$2" <<'PY'
import sys,ssl,urllib.request as r
u,f=sys.argv[1],sys.argv[2]
try: d=r.urlopen(u,timeout=300).read()
except Exception: d=r.urlopen(u,context=ssl._create_unverified_context(),timeout=300).read()
open(f,'wb').write(d)
PY
}

echo "== pagina do livro: $B/$PAG.html"
baixa $B/$PAG.html pagina.html
baixa $B/introduction/systemd-units.html units.html

python3 - <<'PY'
import re,html
def txt(x): return html.unescape(re.sub(r'<[^>]+>','',x))
s=open('pagina.html',encoding='utf-8').read()
# area de downloads: do inicio ate as dependencias
fim=s.find('Dependencies'); area=s[:fim if fim>0 else len(s)]
urls=[]
for u in re.findall(r'href=\s*"((?:https?|ftp)://[^"]+)"',area):
    if re.search(r'\.(tar\.(gz|xz|bz2|zst|lz)|tgz|zip|patch)$',u) and u not in urls and not u.startswith('ftp'):
        urls.append(u)
md5=re.findall(r'MD5 sum:\s*([0-9a-f]{32})',txt(area))
open('downloads.txt','w').write('\n'.join(urls)+'\n')
open('md5.txt','w').write((md5[0] if md5 else '-')+'\n')
print('== downloads:'); [print('   ',u) for u in urls]
print('== MD5 do pacote principal:', md5[0] if md5 else '(nao encontrado)')
TESTE=re.compile(r'\b(make|ninja)\b[^\n]*\b(check|test|tests)\b|\bctest\b|\bpytest\b|tests?/run')
blocos=re.findall(r'<pre\s+class="(root|userinput)"\s*>(.*?)</pre>',s,re.S)
usar=[]; unid=[]
for i,(cl,raw) in enumerate(blocos):
    b=txt(raw).strip(); l1=b.splitlines()[0][:90]
    if 'replaceable' in raw: print(f'   PULADO (exemplo) #{i}: {l1}')
    elif TESTE.search(b): print(f'   PULADO (teste)   #{i}: {l1}')
    elif re.match(r'make install-[a-z]',b) and 'systemd-units' in s:
        print(f'   RODA (unidade)   #{i}: {l1}'); unid.append(b)
    else: print(f'   RODA             #{i}: {l1}'); usar.append(b)
open('build.sh','w').write('\n'.join(usar)+'\n')
open('unidades.sh','w').write('\n'.join(unid)+'\n')
u=txt(open('units.html',encoding='utf-8').read())
m=re.search(r'(https://\S+blfs-systemd-units-\S+?\.tar\.xz)',u)
open('units.url','w').write((m.group(1) if m else '')+'\n')
PY

if [ "$2" != sim ]; then
  read -p "Confere a lista acima. Compilar? (s/n) " R < /dev/tty
  [ "$R" = s ] || { echo "cancelado"; exit 1; }
fi

M=$(cat md5.txt); PRIMEIRO=1
while read U; do
  [ -n "$U" ] || continue
  F=$(basename $U); [ -f $F ] || baixa $U $F
  if [ $PRIMEIRO = 1 ]; then
    T=$F; PRIMEIRO=0
    [ "$M" = "-" ] || echo "$M  $F" | md5sum -c -
  fi
done < downloads.txt

D=$(tar -tf $T | sed -n 1p | cut -d/ -f1); rm -rf $D; tar -xf $T; cd $D
echo "== compilando $D (comandos do livro)"
bash -e ../build.sh
if [ -s ../unidades.sh ]; then
  UU=$(cat ../units.url); UT=/sources/blfs/$(basename $UU)
  [ -f $UT ] || baixa $UU $UT
  cd /sources/blfs; UD=$(tar -tf $UT | sed -n 1p | cut -d/ -f1)
  [ -d $UD ] || tar -xf $UT; cd $UD
  bash -e $W/unidades.sh
fi
cd $W && rm -rf $D
touch /root/blfs-logs/$NOME.ok
echo "== $NOME INSTALADO (log: $LOG)"
