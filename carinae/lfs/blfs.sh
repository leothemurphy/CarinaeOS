#!/bin/bash
# CarinaeOS - instala um pacote seguindo a pagina do livro BLFS 13.1-systemd.
# Uso:  bash blfs.sh <secao/pagina[#pacote]>     ex.: bash blfs.sh general/libtasn1
#       bash blfs.sh <pagina> sim                (nao pergunta antes de compilar)
#       bash blfs.sh <pagina> ver                (so mostra os blocos completos)
#       PULAR=4,5 bash blfs.sh <pagina>          (pula mais blocos opcionais)
# Le a pagina do livro com analisa.py (mesma pasta), mostra cada bloco como
# RODA/PULADO, baixa o pacote, confere o MD5 do livro e executa os blocos na
# ordem do livro. Paginas com varios pacotes (Python Modules etc.) aceitam
# #pacote para instalar so aquela secao.
set -e
NO=${1:?uso: bash blfs.sh secao/pagina[#pacote]}
PAG=${NO%%#*}
NOME=$(basename "$NO" | tr '#' '-')
DIR=$(cd "$(dirname "$0")" && pwd)
B=https://www.linuxfromscratch.org/blfs/view/13.1-systemd
W=/sources/blfs/$NOME
mkdir -p $W /root/blfs-logs && cd $W
LOG=/root/blfs-logs/$NOME.log
[ "$2" = ver ] || exec > >(tee $LOG) 2>&1
set +e; source /etc/profile > /dev/null 2>&1; set -e   # ambiente de login (xorg.sh, qt6.sh, kf6.sh, rustc.sh...)
export MAKEFLAGS=${MAKEFLAGS:--j$(nproc)} NINJAJOBS=${NINJAJOBS:-$(nproc)}

MD5ESPERADO=
baixa1(){  # um URL: wget (segue redirecionamentos) e, se falhar, python
  wget -q --tries=2 --timeout=120 -O "$2.part" "$1" && mv "$2.part" "$2" && return 0
  rm -f "$2.part"
  python3 - "$1" "$2" <<'PY'
import sys,ssl,urllib.request as r
u,f=sys.argv[1],sys.argv[2]
req=r.Request(u,headers={'User-Agent':'Wget/1.25 (linux-gnu)'})
for ctx in (None, ssl._create_unverified_context()):
    try:
        d=r.urlopen(req,context=ctx,timeout=300).read(); open(f,'wb').write(d); sys.exit(0)
    except Exception as e: erro=e
print(f'   ({u}: {erro})',file=sys.stderr); sys.exit(1)
PY
}
baixa(){  # baixa <ficheiro> <url> [url alternativo...]: varias rondas por todos
  local f=$1; shift
  local stem; stem=$(echo "$f" | sed -E 's/[-_]v?[0-9][0-9.]*.*$//')
  for ronda in 1 2 3; do
    for u in "$@" "https://ftp.osuosl.org/pub/blfs/conglomeration/$stem/$f"; do
      baixa1 "$u" "$f" || continue
      # com MD5 do livro: so aceita o ficheiro certo; senao tenta o URL seguinte
      # (ex.: arquivos gerados na hora pelo GitLab mudam ou chegam cortados)
      if [ -n "$MD5ESPERADO" ] && ! echo "$MD5ESPERADO  $f" | md5sum -c - >/dev/null 2>&1; then
        echo "   $u: MD5 diferente do livro ($(md5sum < "$f" | cut -c1-32), $(stat -c %s "$f") bytes); a tentar outro" >&2
        rm -f "$f"; continue
      fi
      return 0
    done
    echo "   download de $f falhou (ronda $ronda/3); a tentar de novo" >&2; sleep $((20*ronda))
  done
  echo "nao consegui baixar $f" >&2; return 1
}

echo "== pagina do livro: $B/$PAG.html ${NO#$PAG}"
CACHE=/sources/blfs/paginas/$(echo $PAG | tr / _)_.html
[ -s $CACHE ] || { mkdir -p /sources/blfs/paginas; baixa1 $B/$PAG.html $CACHE || baixa1 $B/$PAG.html $CACHE; }
cp $CACHE pagina.html
python3 $DIR/analisa.py pagina.html "$NO" $([ "$2" = ver ] && echo ver)
[ "$2" = ver ] && exit 0

if [ "$2" != sim ]; then
  read -p "Confere a lista acima. Compilar? (s/n) " R < /dev/tty
  [ "$R" = s ] || { echo "cancelado"; exit 1; }
fi

M=$(cat md5.txt); T=
# downloads agrupados por nome de ficheiro (o livro da HTTP e FTP/espelhos)
python3 -c "
import collections,os
g=collections.OrderedDict()
for u in open('downloads.txt').read().split(): g.setdefault(os.path.basename(u),[]).append(u)
for f,us in g.items(): print(f,*us)
" > grupos.txt
while read F URLS; do
  [ -n "$F" ] || continue
  if [ -z "$T" ]; then
    T=$F
    if [ "$M" != "-" ] && [ -s $F ] && ! echo "$M  $F" | md5sum -c - >/dev/null 2>&1; then rm -f $F; fi
    [ "$M" = "-" ] || MD5ESPERADO=$M
    [ -s $F ] || baixa $F $URLS
    MD5ESPERADO=
    [ "$M" = "-" ] || echo "$M  $F" | md5sum -c -
  else
    # adicionais (patches, testes, documentacao): uma falha so pesa se o livro
    # usar o ficheiro; nesse caso o passo seguinte acusa
    [ -s $F ] || baixa $F $URLS || echo "   AVISO: nao consegui baixar $F (adicional)"
  fi
done < grupos.txt

D=
if [ -n "$T" ] && [[ "$T" == *.zip ]]; then
  # o livro: "python3 -m zipfile -e <name>.zip <name>"
  D=${T%.zip}; rm -rf $D; python3 -m zipfile -e $T $D; cd $D
  echo "== compilando $D (comandos do livro)"
  bash -e $W/build.sh
elif [ -n "$T" ] && [[ "$T" != *.patch ]]; then
  D=$(tar -tf $T | sed -n 1p | cut -d/ -f1); rm -rf $D; tar -xf $T; cd $D
  echo "== compilando $D (comandos do livro)"
  bash -e $W/build.sh
else
  # paginas sem pacote unico (Xorg Libraries, KF6, Plasma...): o livro baixa
  echo "== sem pacote unico: rodando os comandos do livro em $W/trabalho"
  rm -rf $W/trabalho; mkdir $W/trabalho; cd $W/trabalho
  for f in $W/*.patch; do [ -e "$f" ] && cp "$f" .; done
  bash -e $W/build.sh
  D=trabalho
fi
if [ -s $W/unidades.sh ]; then
  baixa1 $B/introduction/systemd-units.html $W/units.html
  UU=$(python3 -c "import re,sys;print(re.search(r'href=\s*\"(https://[^\"]*blfs-systemd-units-[^\"]*\.tar\.xz)\"',open('$W/units.html').read()).group(1))")
  UT=/sources/blfs/$(basename $UU); [ -s $UT ] || (cd /sources/blfs && baixa $(basename $UU) $UU)
  cd /sources/blfs; UD=$(tar -tf $UT | sed -n 1p | cut -d/ -f1)
  [ -d $UD ] || tar -xf $UT; cd $UD
  bash -e $W/unidades.sh
fi
cd $W; [ -z "$D" ] || rm -rf $W/$D
/sbin/ldconfig
touch /root/blfs-logs/$NOME.ok
echo "== $NOME INSTALADO (log: $LOG)"
