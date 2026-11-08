#!/bin/bash
# CarinaeOS - instala, em ordem, as paginas de /root/blfs-fila.txt com blfs.sh.
# Para no primeiro erro; rodar de novo continua de onde parou (pula as .ok).
# Os blocos que nao se aplicam estao em carinae/decisoes.txt (revistos no livro).
# Linhas carinae:<nome> rodam carinae/extra/<nome>.sh (passos proprios do CarinaeOS).
cd /root
exec > >(tee -a /root/blfs-fila.log) 2>&1
total=$(grep -c . blfs-fila.txt); n=0
while read P; do
  [ -n "$P" ] || continue; n=$((n+1))
  N=$(basename "$P" | tr '#' '-')
  [ -f /root/blfs-logs/$N.ok ] && { echo "[$n/$total] ja instalado: $P"; continue; }
  echo "[$n/$total] $(date +%H:%M) instalando $P"
  if [[ $P == carinae:* ]]; then
    bash /root/carinae/extra/${P#carinae:}.sh < /dev/null > /root/blfs-logs/$N.log 2>&1 && touch /root/blfs-logs/$N.ok || {
      echo "!! FALHOU em $P"; tail -25 /root/blfs-logs/$N.log; exit 1; }
  elif ! bash /root/carinae/blfs.sh "$P" sim < /dev/null > /dev/null 2>&1; then
    echo "!! FALHOU em $P - ultimas linhas do log:"; tail -25 /root/blfs-logs/$N.log
    exit 1
  fi
done < blfs-fila.txt
echo "== FILA CONCLUIDA"
