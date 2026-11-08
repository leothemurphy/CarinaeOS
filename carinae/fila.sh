#!/bin/bash
# CarinaeOS - instala, em ordem, as paginas de /root/blfs-fila.txt com blfs.sh.
# Para no primeiro erro; rodar de novo continua de onde parou (pula as .ok).
# Blocos opcionais a pular por pagina: /root/blfs-pular.txt  (linha: pagina 4,5)
cd /root
total=$(grep -c . blfs-fila.txt); n=0
while read P; do
  [ -n "$P" ] || continue; n=$((n+1))
  [ -f /root/blfs-logs/$(basename $P).ok ] && { echo "[$n/$total] ja instalado: $P"; continue; }
  PUL=$(awk -v p="$P" '$1==p{print $2}' /root/blfs-pular.txt 2>/dev/null)
  echo "[$n/$total] $(date +%H:%M) instalando $P"
  if ! PULAR=$PUL bash /root/blfs.sh $P sim < /dev/null > /dev/null 2>&1; then
    echo "!! FALHOU em $P - ultimas linhas do log:"; tail -25 /root/blfs-logs/$(basename $P).log
    exit 1
  fi
done < blfs-fila.txt
echo "== FILA CONCLUIDA"
