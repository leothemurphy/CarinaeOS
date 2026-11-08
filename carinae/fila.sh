#!/bin/bash
# CarinaeOS - instala, em ordem, as paginas de /root/blfs-fila.txt com blfs.sh.
# Os blocos que nao se aplicam estao em carinae/decisoes.txt (revistos no livro).
# Linhas carinae:<nome> rodam carinae/extra/<nome>.sh (passos proprios do CarinaeOS).
#
# Para a noite render: se um pacote falhar (mesmo depois da 2a tentativa com
# -j1), a fila NAO para. Marca-o como falhado, salta os pacotes que dependem
# dele (carinae/fila-deps.txt) e continua com todos os outros. No fim mostra
# o resumo. Rodar de novo refaz so o que ficou por fazer.
cd /root
exec > >(tee -a /root/blfs-fila.log) 2>&1
declare -A DEPS FALHOU
while read -r p d; do [[ $p == \#* ]] || DEPS[$p]="$d"; done < /root/carinae/fila-deps.txt
total=$(grep -c . blfs-fila.txt); n=0; ok=0; falhas=(); saltados=()
mapfile -t FILA < blfs-fila.txt
for P in "${FILA[@]}"; do
  [ -n "$P" ] || continue; n=$((n+1))
  N=$(basename "$P" | tr '#' '-')
  [ -f /root/blfs-logs/$N.ok ] && { echo "[$n/$total] ja instalado: $P"; continue; }
  culpado=
  for d in ${DEPS[$P]}; do [ -n "${FALHOU[$d]}" ] && { culpado=$d; break; }; done
  if [ -n "$culpado" ]; then
    echo "[$n/$total] SALTADO $P (depende de $culpado, que falhou)"
    FALHOU[$P]=1; saltados+=("$P"); continue
  fi
  echo "[$n/$total] $(date +%H:%M) instalando $P"
  if [[ $P == carinae:* ]]; then
    if bash /root/carinae/extra/${P#carinae:}.sh < /dev/null > /root/blfs-logs/$N.log 2>&1; then
      touch /root/blfs-logs/$N.ok
    else
      echo "!! FALHOU $P"; tail -15 /root/blfs-logs/$N.log; FALHOU[$P]=1; falhas+=("$P")
    fi
    continue
  fi
  if bash /root/carinae/blfs.sh "$P" sim < /dev/null > /dev/null 2>&1; then continue; fi
  cp /root/blfs-logs/$N.log /root/blfs-logs/$N.tentativa1.log
  echo "   falhou; nova tentativa de $P com -j1"
  if MAKEFLAGS=-j1 NINJAJOBS=1 bash /root/carinae/blfs.sh "$P" sim < /dev/null > /dev/null 2>&1; then continue; fi
  echo "!! FALHOU $P - ultimas linhas do log (/root/blfs-logs/$N.log):"
  tail -15 /root/blfs-logs/$N.log
  FALHOU[$P]=1; falhas+=("$P")
done
echo
if [ ${#falhas[@]} -eq 0 ]; then
  echo "== FILA CONCLUIDA sem falhas"
else
  echo "== FILA TERMINADA COM FALHAS"
  echo "   falharam (${#falhas[@]}): ${falhas[*]}"
  echo "   saltados por dependerem deles (${#saltados[@]}): ${saltados[*]}"
  { for p in "${falhas[@]}"; do n=$(basename "$p" | tr '#' '-'); echo "########## $p"
      grep -nE 'error|Error|ERROR|not found|No such|inexistente|nao consegui|falhou' /root/blfs-logs/$n.log | tail -8
      echo '--- fim do log:'; tail -15 /root/blfs-logs/$n.log; echo; done; } > /root/falhas.txt
  echo "   detalhes de cada falha em /root/falhas.txt (manda esse ficheiro ao Claude)"
fi
