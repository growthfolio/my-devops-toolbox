#!/usr/bin/env bash
set -euo pipefail

# ===== Configuração rápida =====
MODE="${MODE:-HOME_ONLY}"
DO_HASH="${DO_HASH:-0}"
RECENT_DAYS="${RECENT_DAYS:-14}"
MAX_DEPTH="${MAX_DEPTH:-0}"  # 0 = sem limite
MIN_SIZE_HASH="${MIN_SIZE_HASH:-1048576}"  # 1MB mínimo para hash por padrão
PARALLEL_JOBS="${PARALLEL_JOBS:-4}"  # Jobs paralelos para hashing
EXCLUDE_PATTERNS="${EXCLUDE_PATTERNS:-*.tmp,*.swp,*~,*.bak}"  # Padrões para ignorar
LOG_LEVEL="${LOG_LEVEL:-INFO}"  # DEBUG, INFO, WARN, ERROR

# ===== Logging =====
log() {
    local level="$1"
    shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$LOG_LEVEL" in
        DEBUG) [[ "$level" =~ ^(DEBUG|INFO|WARN|ERROR)$ ]] && echo "[$timestamp $level] $*" ;;
        INFO)  [[ "$level" =~ ^(INFO|WARN|ERROR)$ ]] && echo "[$timestamp $level] $*" ;;
        WARN)  [[ "$level" =~ ^(WARN|ERROR)$ ]] && echo "[$timestamp $level] $*" ;;
        ERROR) [[ "$level" == "ERROR" ]] && echo "[$timestamp $level] $*" ;;
    esac
}

# ===== Validação de dependências =====
check_dependencies() {
    local missing=()
    
    for cmd in find stat awk sort head; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ "$DO_HASH" == "1" ]] && ! command -v md5sum &> /dev/null; then
        missing+=("md5sum")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log ERROR "Dependências faltando: ${missing[*]}"
        exit 1
    fi
}

# ===== Tratamento de sinais =====
cleanup() {
    log WARN "Interrompido! Limpando arquivos temporários..."
    [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    exit 130
}
trap cleanup SIGINT SIGTERM

# ===== Descobrir escopo =====
setup_scope() {
    if [[ "$MODE" == "FULL_SYSTEM" ]]; then
        if [[ $EUID -ne 0 ]]; then
            log INFO "Modo FULL_SYSTEM: reiniciando com sudo..."
            exec sudo \
                MODE=FULL_SYSTEM \
                DO_HASH="$DO_HASH" \
                RECENT_DAYS="$RECENT_DAYS" \
                MAX_DEPTH="$MAX_DEPTH" \
                MIN_SIZE_HASH="$MIN_SIZE_HASH" \
                PARALLEL_JOBS="$PARALLEL_JOBS" \
                EXCLUDE_PATTERNS="$EXCLUDE_PATTERNS" \
                LOG_LEVEL="$LOG_LEVEL" \
                bash "$0" "$@"
        fi
        ROOTS=("/")
        PRUNE_EXPR='( -path /proc -o -path /sys -o -path /run -o -path /dev -o -path /lost+found -o -path /snap -o -path /var/snap -o -path /var/lib/snapd -o -path /tmp -o -path /var/tmp -o -path /mnt -o -path /media ) -prune'
    else
        ROOTS=("$HOME")
        # Excluir cache comum em home
        PRUNE_EXPR='( -path */\.cache -o -path */\.local/share/Trash -o -path */snap -o -path */\.snapshots ) -prune'
    fi
}

# ===== Saída e estrutura =====
setup_output() {
    STAMP="$(date +%Y%m%d_%H%M%S)"
    OUTDIR="$HOME/inventario_$STAMP"
    TEMP_DIR=$(mktemp -d)
    
    mkdir -p "$OUTDIR"
    
    log INFO "Saída: $OUTDIR"
    log INFO "Modo: $MODE | Hash: $DO_HASH | Recentes: ${RECENT_DAYS}d | Jobs: $PARALLEL_JOBS"
}

# ===== Funções utilitárias =====
tsv_header() {
    echo -e "$1" > "$2"
}

export LC_ALL=C

# Construção da expressão find com exclusões
build_find_expr() {
    local depth_expr=""
    [[ "$MAX_DEPTH" -gt 0 ]] && depth_expr="-maxdepth $MAX_DEPTH"
    
    # Converter padrões de exclusão para find
    local exclude_expr=""
    if [[ -n "$EXCLUDE_PATTERNS" ]]; then
        IFS=',' read -ra patterns <<< "$EXCLUDE_PATTERNS"
        local name_exprs=()
        for pattern in "${patterns[@]}"; do
            name_exprs+=("-name '$pattern'")
        done
        exclude_expr="! \\( $(IFS=' -o '; echo "${name_exprs[*]}") \\)"
    fi
    
    echo "$depth_expr $exclude_expr"
}

# Base de busca otimizada
find_base() {
    local extra_expr=$(build_find_expr)
    
    # shellcheck disable=SC2068,SC2086
    find ${ROOTS[@]} \( $PRUNE_EXPR \) -o $extra_expr -print 2>/dev/null
}

# ===== Relatórios aprimorados =====

# 1) Árvore com melhor formatação
generate_tree() {
    log INFO "Gerando árvore (nível 3)…"
    
    for r in "${ROOTS[@]}"; do
        echo "== $r ==" >> "$OUTDIR/arvore_n3.txt"
        find "$r" -maxdepth 3 -mindepth 1 2>/dev/null | \
        sort | \
        sed "s|$r/||g" | \
        awk -F/ '{
            depth = NF - 1
            indent = ""
            for(i=0; i<depth; i++) indent = indent "  "
            print indent "├── " $NF
        }' >> "$OUTDIR/arvore_n3.txt"
        echo >> "$OUTDIR/arvore_n3.txt"
    done
}

# 2) Listagem de arquivos com informações estendidas
generate_files_list() {
    local files_tsv="$OUTDIR/arquivos.tsv"
    log INFO "Listando arquivos…"
    
    tsv_header "path\tsize_bytes\tmtime\tatime\tmode\tuser\tgroup\tinode\tlinks" "$files_tsv"
    
    find_base | while IFS= read -r p; do
        if [[ -f "$p" ]]; then
            # Usar stat uma única vez para eficiência
            local stat_info
            if stat_info=$(stat -c '%s\t%y\t%x\t%A\t%U\t%G\t%i\t%h' -- "$p" 2>/dev/null); then
                echo -e "$p\t$stat_info"
            fi
        fi
    done >> "$files_tsv"
}

# 3) Listagem de diretórios com tamanho
generate_dirs_list() {
    local dirs_tsv="$OUTDIR/diretorios.tsv"
    log INFO "Listando diretórios…"
    
    tsv_header "path\tmode\tuser\tgroup\tfiles_count\ttotal_size" "$dirs_tsv"
    
    find_base | while IFS= read -r p; do
        if [[ -d "$p" ]]; then
            local stat_info
            if stat_info=$(stat -c '%A\t%U\t%G' -- "$p" 2>/dev/null); then
                local file_count=0
                local dir_size=0
                
                # Contar arquivos e calcular tamanho (apenas 1 nível)
                if [[ -r "$p" ]]; then
                    while IFS= read -r -d '' file; do
                        if [[ -f "$file" ]]; then
                            ((file_count++))
                            local size=$(stat -c '%s' -- "$file" 2>/dev/null || echo 0)
                            ((dir_size += size))
                        fi
                    done < <(find "$p" -maxdepth 1 -type f -print0 2>/dev/null || true)
                fi
                
                echo -e "$p\t$stat_info\t$file_count\t$dir_size"
            fi
        fi
    done >> "$dirs_tsv"
}

# 4) Análise de tipos de arquivo aprimorada
generate_file_analysis() {
    log INFO "Analisando tipos de arquivo…"
    
    # Por extensão (melhorado)
    awk -F'\t' '
        NR>1 {
            path=$1; size=$2
            # Extrair extensão
            n=split(path, parts, "/")
            filename=parts[n]
            ext_pos=match(filename, /\.([^.]+)$/, arr)
            ext = ext_pos ? tolower(arr[1]) : "(sem_ext)"
            
            count[ext]++
            total_size[ext] += size
            if (size > max_size[ext]) max_size[ext] = size
            if (min_size[ext] == 0 || size < min_size[ext]) min_size[ext] = size
        }
        END {
            printf "ext\tcount\ttotal_bytes\tavg_bytes\tmin_bytes\tmax_bytes\n"
            for (e in count) {
                avg = total_size[e] / count[e]
                printf "%s\t%d\t%d\t%d\t%d\t%d\n", e, count[e], total_size[e], avg, min_size[e], max_size[e]
            }
        }
    ' "$OUTDIR/arquivos.tsv" | sort -k3,3nr > "$OUTDIR/por_extensao.tsv"
    
    # Por tamanho (faixas)
    awk -F'\t' '
        NR>1 {
            size = $2
            if (size == 0) range = "vazio"
            else if (size < 1024) range = "< 1KB"
            else if (size < 1024*1024) range = "1KB-1MB"
            else if (size < 1024*1024*100) range = "1MB-100MB"
            else if (size < 1024*1024*1024) range = "100MB-1GB"
            else range = "> 1GB"
            
            count[range]++
            total[range] += size
        }
        END {
            printf "faixa\tcount\ttotal_bytes\n"
            for (r in count) printf "%s\t%d\t%d\n", r, count[r], total[r]
        }
    ' "$OUTDIR/arquivos.tsv" | sort -k3,3nr > "$OUTDIR/por_tamanho.tsv"
}

# 5) Detecção de duplicados otimizada
generate_duplicates() {
    if [[ "$DO_HASH" != "1" ]]; then
        return
    fi
    
    log INFO "Calculando hashes (min: $(numfmt --to=iec $MIN_SIZE_HASH)B, jobs: $PARALLEL_JOBS)…"
    
    local hash_tsv="$OUTDIR/hashes.tsv"
    local temp_files="$TEMP_DIR/files_to_hash.txt"
    
    tsv_header "hash\tbytes\tpath" "$hash_tsv"
    
    # Filtrar arquivos por tamanho mínimo
    awk -F'\t' -v min_size="$MIN_SIZE_HASH" '
        NR>1 && $2 >= min_size {print $1 "\t" $2}
    ' "$OUTDIR/arquivos.tsv" > "$temp_files"
    
    # Processar em paralelo
    export -f hash_file
    parallel -j "$PARALLEL_JOBS" --colsep '\t' hash_file {1} {2} :::: "$temp_files" >> "$hash_tsv"
    
    # Encontrar duplicados
    awk -F'\t' '
        NR>1 { 
            files[$1] = files[$1] ? files[$1] ORS $3 : $3
            count[$1]++
            sizes[$1] = $2
        }
        END {
            total_duplicates = 0
            wasted_space = 0
            for (hash in count) {
                if (count[hash] > 1) {
                    total_duplicates += count[hash]
                    wasted_space += sizes[hash] * (count[hash] - 1)
                    print "=== HASH " hash " (" count[hash] " arquivos, " sizes[hash] " bytes cada) ==="
                    print files[hash]
                    print ""
                }
            }
            print "TOTAL: " total_duplicates " arquivos duplicados"
            print "ESPAÇO DESPERDIÇADO: " wasted_space " bytes"
        }
    ' "$hash_tsv" > "$OUTDIR/duplicados.txt"
}

# Função auxiliar para hash (para parallel)
hash_file() {
    local path="$1"
    local size="$2"
    
    if [[ -f "$path" && -r "$path" ]]; then
        local hash=$(md5sum -- "$path" 2>/dev/null | awk '{print $1}' || echo "ERROR")
        echo -e "$hash\t$size\t$path"
    fi
}
export -f hash_file

# ===== Relatórios de segurança =====
generate_security_reports() {
    log INFO "Gerando relatórios de segurança…"
    
    # SUID/SGID files
    find_base | while IFS= read -r p; do
        if [[ -f "$p" ]]; then
            local mode=$(stat -c '%a' -- "$p" 2>/dev/null || echo "")
            # SUID (4xxx) ou SGID (2xxx)
            if [[ "$mode" =~ ^[42] ]]; then
                echo "$p (mode: $mode)"
            fi
        fi
    done > "$OUTDIR/suid_sgid.txt"
    
    # World-writable (melhorado)
    find_base | while IFS= read -r p; do
        [[ -e "$p" ]] || continue
        local mode=$(stat -c '%a' -- "$p" 2>/dev/null || echo "")
        local perms=$(stat -c '%A' -- "$p" 2>/dev/null || echo "")
        # World-writable
        if [[ "$mode" =~ [2367]$ ]]; then
            echo "$p (mode: $mode, perms: $perms)"
        fi
    done > "$OUTDIR/world_writable.txt"
}

# ===== Resumo detalhado =====
generate_summary() {
    log INFO "Gerando resumo…"
    
    local total_files=$(($(wc -l < "$OUTDIR/arquivos.tsv")-1))
    local total_dirs=$(($(wc -l < "$OUTDIR/diretorios.tsv")-1))
    local total_bytes=$(awk -F'\t' 'NR>1{s+=$2} END{print s+0}' "$OUTDIR/arquivos.tsv")
    local human_bytes=$(numfmt --to=iec --suffix=B --padding=7 "$total_bytes" 2>/dev/null || echo "$total_bytes B")
    
    # Estatísticas adicionais
    local largest_file=$(awk -F'\t' 'NR>1 {if($2>max){max=$2;file=$1}} END{print file " (" max " bytes)"}' "$OUTDIR/arquivos.tsv")
    local most_common_ext=$(awk -F'\t' 'NR>1 {print $1}' "$OUTDIR/por_extensao.tsv" | head -n1)
    local recent_count=$(wc -l < "$OUTDIR/recentes_${RECENT_DAYS}d.txt" 2>/dev/null || echo 0)
    
    {
        echo "==============================================="
        echo "RESUMO DO INVENTÁRIO - $STAMP"
        echo "==============================================="
        echo
        echo "CONFIGURAÇÃO:"
        echo "  Escopo              : $MODE"
        echo "  Profundidade máxima : $([[ $MAX_DEPTH -eq 0 ]] && echo "ilimitada" || echo "$MAX_DEPTH")"
        echo "  Padrões excluídos   : $EXCLUDE_PATTERNS"
        echo "  Hash de duplicados  : $DO_HASH"
        echo "  Tamanho mín. p/hash : $(numfmt --to=iec $MIN_SIZE_HASH)B"
        echo
        echo "ESTATÍSTICAS:"
        echo "  Total de arquivos   : $total_files"
        echo "  Total de diretórios : $total_dirs"
        echo "  Tamanho total       : $human_bytes"
        echo "  Maior arquivo       : $largest_file"
        echo "  Ext. mais comum     : $most_common_ext"
        echo "  Arquivos recentes   : $recent_count (últimos ${RECENT_DAYS} dias)"
        echo
        echo "SAÍDA: $OUTDIR"
        echo
        echo "ARQUIVOS GERADOS:"
        ls -la "$OUTDIR" | tail -n +2 | awk '{printf "  %-25s %10s %s %s\n", $9, $5, $6, $7}'
        echo
        echo "TEMPO DE EXECUÇÃO: $(($(date +%s) - START_TIME)) segundos"
    } > "$OUTDIR/RESUMO.txt"
}

# ===== Main =====
main() {
    START_TIME=$(date +%s)
    
    log INFO "Iniciando inventário de sistema..."
    
    check_dependencies
    setup_scope "$@"
    setup_output
    
    # Executar relatórios
    generate_tree
    generate_files_list
    generate_dirs_list
    generate_file_analysis
    
    # Top maiores arquivos
    log INFO "Calculando maiores arquivos…"
    awk -F'\t' 'NR>1 {print $2 "\t" $1}' "$OUTDIR/arquivos.tsv" | \
        sort -nr | head -n 100 | \
        awk -F'\t' '{printf "%15s  %s\n", $1, $2}' > "$OUTDIR/maiores_arquivos.txt"
    
    # Arquivos recentes
    log INFO "Listando arquivos recentes (${RECENT_DAYS}d)…"
    find_base | xargs -r -I{} -d '\n' bash -c '
        p="$1"
        [[ -f "$p" ]] || exit 0
        mtime_sec=$(stat -c "%Y" -- "$p" 2>/dev/null || echo 0)
        now_sec=$(date +%s)
        days_old=$(( (now_sec - mtime_sec) / 86400 ))
        if [[ $days_old -le '"$RECENT_DAYS"' ]]; then
            echo "$p"
        fi
    ' _ {} > "$OUTDIR/recentes_${RECENT_DAYS}d.txt"
    
    # Links simbólicos quebrados
    log INFO "Detectando symlinks quebrados…"
    find_base | while IFS= read -r p; do
        if [[ -L "$p" && ! -e "$p" ]]; then
            echo "$p -> $(readlink "$p" 2>/dev/null || echo "?")"
        fi
    done > "$OUTDIR/symlinks_quebrados.txt"
    
    generate_security_reports
    generate_duplicates
    generate_summary
    
    log INFO "✅ Inventário concluído!"
    log INFO "Abra: $OUTDIR/RESUMO.txt"
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
