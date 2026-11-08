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

baixa(){ python3 - "$1" "$2" <<'PY'
import sys,ssl,time,urllib.request as r
u,f=sys.argv[1],sys.argv[2]
req=r.Request(u,headers={'User-Agent':'Wget/1.25 (linux-gnu)'})
for tentativa in range(1,6):
    for ctx in (None, ssl._create_unverified_context()):
        try:
            d=r.urlopen(req,context=ctx,timeout=300).read(); open(f,'wb').write(d); sys.exit(0)
        except Exception as e: erro=e
    print(f'   download falhou ({erro}); tentativa {tentativa}/5',file=sys.stderr); time.sleep(10*tentativa)
sys.exit(f'nao consegui baixar {u}')
PY
}

echo "== pagina do livro: $B/$PAG.html ${NO#$PAG}"
CACHE=/sources/blfs/paginas/$(echo $PAG | tr / _)_.html
[ -s $CACHE ] || { mkdir -p /sources/blfs/paginas; baixa $B/$PAG.html $CACHE; }
cp $CACHE pagina.html
python3 $DIR/analisa.py pagina.html "$NO" $([ "$2" = ver ] && echo ver)
[ "$2" = ver ] && exit 0

if [ "$2" != sim ]; then
  read -p "Confere a lista acima. Compilar? (s/n) " R < /dev/tty
  [ "$R" = s ] || { echo "cancelado"; exit 1; }
fi

M=$(cat md5.txt); T=
while read U; do
  [ -n "$U" ] || continue
  F=$(basename $U)
  if [ -z "$T" ]; then
    [ -s $F ] || baixa $U $F
  else
    # downloads adicionais (patches, testes, documentacao): uma falha aqui so
    # pesa se o livro usar o ficheiro; nesse caso o passo seguinte acusa
    [ -s $F ] || baixa $U $F || echo "   AVISO: nao consegui baixar $F (adicional)"
  fi
  if [ -z "$T" ]; then
    T=$F; [ "$M" = "-" ] || echo "$M  $F" | md5sum -c -
  fi
done < downloads.txt

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
  baixa $B/introduction/systemd-units.html $W/units.html
  UU=$(python3 -c "import re,sys;print(re.search(r'href=\s*\"(https://[^\"]*blfs-systemd-units-[^\"]*\.tar\.xz)\"',open('$W/units.html').read()).group(1))")
  UT=/sources/blfs/$(basename $UU); [ -s $UT ] || baixa $UU $UT
  cd /sources/blfs; UD=$(tar -tf $UT | sed -n 1p | cut -d/ -f1)
  [ -d $UD ] || tar -xf $UT; cd $UD
  bash -e $W/unidades.sh
fi
cd $W; [ -z "$D" ] || rm -rf $W/$D
/sbin/ldconfig
touch /root/blfs-logs/$NOME.ok
echo "== $NOME INSTALADO (log: $LOG)"
