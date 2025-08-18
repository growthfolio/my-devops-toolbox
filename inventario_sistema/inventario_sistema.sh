#!/usr/bin/env bash
set -euo pipefail

# ===== Configuração rápida =====
# Modo: HOME_ONLY (padrão) ou FULL_SYSTEM
MODE="${MODE:-HOME_ONLY}"
# Ativar verificação de duplicados por hash? (custa mais tempo/CPU)
DO_HASH="${DO_HASH:-0}"
# Considerar "recentes" = últimos N dias
RECENT_DAYS="${RECENT_DAYS:-14}"

# ===== Descobrir escopo =====
if [[ "$MODE" == "FULL_SYSTEM" ]]; then
  # Requer sudo para metadados completos
  if [[ $EUID -ne 0 ]]; then
    echo "→ Modo FULL_SYSTEM: reiniciando com sudo..."
    exec sudo MODE=FULL_SYSTEM DO_HASH="$DO_HASH" RECENT_DAYS="$RECENT_DAYS" bash "$0" "$@"
  fi
  ROOTS=("/")
  # Exclusões seguras p/ não travar em pseudo-FS/montagens
  PRUNE_EXPR='( -path /proc -o -path /sys -o -path /run -o -path /dev -o -path /lost+found -o -path /snap -o -path /var/snap -o -path /var/lib/snapd -o -path /tmp ) -prune'
else
  ROOTS=("$HOME")
  PRUNE_EXPR='-false'  # nada a podar na home
fi

# ===== Saída =====
STAMP="$(date +%Y%m%d_%H%M%S)"
OUTDIR="$HOME/inventario_$STAMP"
mkdir -p "$OUTDIR"

echo "📂 Saída: $OUTDIR"
echo "🔎 Modo : $MODE | Duplicados(hash): $DO_HASH | Recentes: ${RECENT_DAYS}d"

# ===== Funções utilitárias =====
tsv_header() {
  echo -e "$1" > "$2"
}

# Velocidade
export LC_ALL=C

# Base de busca (find) com prune seguro
find_base() {
  # shellcheck disable=SC2068
  find ${ROOTS[@]} \( $PRUNE_EXPR \) -o -print 2>/dev/null
}

# ===== Relatórios =====

# 1) Árvore superficial (até 3 níveis) — visão rápida
echo "→ Gerando árvore (nível 3)…"
{ 
  for r in "${ROOTS[@]}"; do
    echo "== $r =="
    # tree nem sempre está instalado; usamos find+awk
    find "$r" -maxdepth 3 -mindepth 1 -printf '%p\n' 2>/dev/null | awk -F/ '{
      indent="";
      for(i=1;i<NF;i++) indent=indent"  ";
      print indent $NF
    }'
    echo
  done
} > "$OUTDIR/arvore_n3.txt"

# 2) Listagem completa de ARQUIVOS (TSV)
FILES_TSV="$OUTDIR/arquivos.tsv"
echo "→ Listando arquivos…"
tsv_header "path\tsize_bytes\tmtime\tmode\tuser\tgroup" "$FILES_TSV"
find_base | while IFS= read -r p; do
  if [[ -f "$p" ]]; then
    # stat em formato estável
    SZ=$(stat -c '%s' -- "$p" 2>/dev/null || echo 0)
    MT=$(stat -c '%y' -- "$p" 2>/dev/null || echo "1970-01-01 00:00:00")
    MD=$(stat -c '%A' -- "$p" 2>/dev/null || echo "??????????")
    US=$(stat -c '%U' -- "$p" 2>/dev/null || echo "?")
    GR=$(stat -c '%G' -- "$p" 2>/dev/null || echo "?")
    echo -e "$p\t$SZ\t$MT\t$MD\t$US\t$GR"
  fi
done >> "$FILES_TSV"

# 3) Listagem completa de DIRETÓRIOS (TSV)
DIRS_TSV="$OUTDIR/diretorios.tsv"
echo "→ Listando diretórios…"
tsv_header "path\tmode\tuser\tgroup" "$DIRS_TSV"
find_base | while IFS= read -r p; do
  if [[ -d "$p" ]]; then
    MD=$(stat -c '%A' -- "$p" 2>/dev/null || echo "??????????")
    US=$(stat -c '%U' -- "$p" 2>/dev/null || echo "?")
    GR=$(stat -c '%G' -- "$p" 2>/dev/null || echo "?")
    echo -e "$p\t$MD\t$US\t$GR"
  fi
done >> "$DIRS_TSV"

# 4) Top 100 maiores arquivos
echo "→ Calculando maiores arquivos…"
awk -F'\t' 'NR>1 {print $2 "\t" $1}' "$FILES_TSV" | sort -nr | head -n 100 \
 | awk -F'\t' '{printf "%10d  %s\n", $1, $2}' > "$OUTDIR/maiores_arquivos.txt"

# 5) Arquivos por extensão (contagem e tamanho total)
echo "→ Agregando por extensão…"
awk -F'\t' '
  NR>1 {
    n=$1; sz=$2
    ext="";
    i=split(n, a, ".")
    if(i>1){ ext=tolower(a[i]) } else { ext="(sem_ext)" }
    c[ext]++; s[ext]+=sz
  }
  END{
    printf "ext\tcount\ttotal_bytes\n";
    for(e in c){ printf "%s\t%d\t%d\n", e, c[e], s[e] }
  }
' "$FILES_TSV" | sort -k3,3nr > "$OUTDIR/por_extensao.tsv"

# 6) Arquivos recentes (últimos N dias)
echo "→ Listando arquivos recentes (${RECENT_DAYS}d)…"
find_base | xargs -r -I{} -d '\n' bash -c '
  p="$1"
  [[ -f "$p" ]] || exit 0
  # mtime em dias
  MTSEC=$(date -d "$(stat -c "%y" -- "$p" 2>/dev/null || echo "1970-01-01")" +%s 2>/dev/null || echo 0)
  NOW=$(date +%s)
  DIFF=$(( (NOW - MTSEC) / 86400 ))
  if [[ $DIFF -le '"$RECENT_DAYS"' ]]; then
    echo "$p"
  fi
' _ {} > "$OUTDIR/recentes_${RECENT_DAYS}d.txt"

# 7) Links simbólicos quebrados
echo "→ Detectando symlinks quebrados…"
find_base | while IFS= read -r p; do
  if [[ -L "$p" && ! -e "$p" ]]; then
    echo "$p"
  fi
done > "$OUTDIR/symlinks_quebrados.txt"

# 8) Permissões potencialmente perigosas (world-writable)
echo "→ Checando permissões world-writable…"
find_base | while IFS= read -r p; do
  [[ -e "$p" ]] || continue
  MODE=$(stat -c '%a' -- "$p" 2>/dev/null || echo "")
  # world-writable se último dígito contém 2 ou 6 ou 7
  if [[ "$MODE" =~ [267]$ ]]; then
    echo "$p"
  fi
done > "$OUTDIR/world_writable.txt"

# 9) Duplicados por hash (opcional, pesado)
if [[ "$DO_HASH" == "1" ]]; then
  echo "→ Calculando hashes para detectar duplicados (isso pode demorar)…"
  HASH_TSV="$OUTDIR/hashes.tsv"
  tsv_header "hash\tbytes\tpath" "$HASH_TSV"
  # Para acelerar, ignoramos arquivos vazios e < 1KB (ajuste se quiser)
  awk -F'\t' 'NR>1 && $2>=1024 {print $1}' "$FILES_TSV" | while IFS=$'\t' read -r path; do
    if [[ -f "$path" ]]; then
      sz=$(stat -c '%s' -- "$path" 2>/dev/null || echo 0)
      # md5sum é suficiente pra deduplicação local
      h=$(md5sum -- "$path" 2>/dev/null | awk "{print \$1}")
      echo -e "$h\t$sz\t$path"
    fi
  done >> "$HASH_TSV"
  # Agrupar duplicados
  awk -F'\t' '
    NR>1 { arr[$1]=arr[$1] ? arr[$1] ORS $3 : $3; count[$1]++ }
    END {
      for(h in count){
        if(count[h]>1){
          print "=== HASH " h " ==="
          print arr[h]
          print ""
        }
      }
    }
  ' "$HASH_TSV" > "$OUTDIR/duplicados.txt"
fi

# 10) Resumo
echo "→ Gerando resumo…"
TOTAL_FILES=$(($(wc -l < "$FILES_TSV")-1))
TOTAL_DIRS=$(($(wc -l < "$DIRS_TSV")-1))
TOTAL_BYTES=$(awk -F'\t' 'NR>1{s+=$2} END{print s+0}' "$FILES_TSV")
HUMAN_BYTES=$(numfmt --to=iec --suffix=B --padding=7 "$TOTAL_BYTES" 2>/dev/null || echo "$TOTAL_BYTES B")

{
  echo "Resumo do Inventário - $STAMP"
  echo "Escopo          : $MODE"
  echo "Arquivos        : $TOTAL_FILES"
  echo "Diretórios      : $TOTAL_DIRS"
  echo "Tamanho total   : $HUMAN_BYTES"
  echo "Saída           : $OUTDIR"
  echo "Recentes        : últimos ${RECENT_DAYS} dias"
  echo "Duplicados(hash): $DO_HASH"
  echo
  echo "Arquivos gerados:"
  ls -1 "$OUTDIR"
} > "$OUTDIR/RESUMO.txt"

echo "✅ Inventário concluído!"
echo "Abra: $OUTDIR/RESUMO.txt"
