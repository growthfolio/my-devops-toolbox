#!/usr/bin/env bash
set -euo pipefail

# ============= CONFIGURAÇÃO =============
REMOTE_USER=""
REMOTE_IP=""
REMOTE_BASE_PATH="~/organized_transfer"
MIN_FILE_SIZE=1024          # 1KB - ignorar arquivos muito pequenos
MAX_FILE_SIZE=5368709120    # 5GB - ignorar arquivos gigantes (ISOs, etc)
RECENT_DAYS=365             # Considerar arquivos dos últimos X dias
DRY_RUN=false              # true = apenas simular, não transferir
ORGANIZE_BY_TYPE=true      # Organizar por tipo de arquivo no destino
BACKUP_WINDOWS=true        # Incluir arquivos da partição Windows
MAX_PARALLEL_JOBS=4        # Jobs paralelos para transferência

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============= DEFINIÇÕES DE TIPOS =============
declare -A FILE_CATEGORIES
FILE_CATEGORIES=(
    # Documentos importantes
    ["documentos"]="pdf,doc,docx,odt,rtf,txt,md,tex,pages"
    ["planilhas"]="xls,xlsx,ods,csv,numbers"
    ["apresentacoes"]="ppt,pptx,odp,key"
    
    # Mídia pessoal
    ["fotos"]="jpg,jpeg,png,tiff,tif,bmp,gif,webp,heic,raw,cr2,nef,arf"
    ["videos"]="mp4,avi,mov,mkv,wmv,flv,m4v,webm,3gp,mts"
    ["musicas"]="mp3,flac,wav,ogg,aac,m4a,wma"
    
    # Desenvolvimento
    ["codigo"]="py,js,html,css,cpp,c,java,php,rb,go,rs,kt,swift,sh"
    ["projetos"]="json,xml,yml,yaml,toml,ini,cfg,conf"
    
    # Arquivos comprimidos
    ["comprimidos"]="zip,rar,7z,tar,gz,xz,bz2"
    
    # Executáveis e instaladores
    ["programas"]="exe,msi,deb,rpm,dmg,pkg,app"
    
    # Dados e configurações
    ["dados"]="db,sql,sqlite,mdb"
    ["configs"]="config,settings,pref,reg"
)

# Diretórios especiais do Windows para verificar
WINDOWS_DIRS=(
    "/mnt/windows/Users/*/Documents"
    "/mnt/windows/Users/*/Desktop"
    "/mnt/windows/Users/*/Downloads" 
    "/mnt/windows/Users/*/Pictures"
    "/mnt/windows/Users/*/Videos"
    "/mnt/windows/Users/*/Music"
)

# Diretórios Linux importantes
LINUX_DIRS=(
    "$HOME/Documents"
    "$HOME/Desktop" 
    "$HOME/Downloads"
    "$HOME/Pictures"
    "$HOME/Videos"
    "$HOME/Music"
    "$HOME/Projects"
    "$HOME/workspace"
    "$HOME/dev"
    "$HOME/git"
    "$HOME"
)

# ============= FUNÇÕES UTILITÁRIAS =============
log() {
    echo -e "$(date '+%H:%M:%S') ${1}" >&2
}

info() { log "${BLUE}ℹ ${1}${NC}"; }
success() { log "${GREEN}✓ ${1}${NC}"; }
warning() { log "${YELLOW}⚠ ${1}${NC}"; }
error() { log "${RED}✗ ${1}${NC}"; }
debug() { log "${PURPLE}🔍 ${1}${NC}"; }

# Detectar partição Windows
detect_windows() {
    info "Procurando partição Windows..."
    
    local windows_partitions=()
    
    # Verificar partições montadas
    while IFS= read -r line; do
        if echo "$line" | grep -qi "ntfs\|fat32"; then
            local mount_point=$(echo "$line" | awk '{print $2}')
            if [[ -d "$mount_point/Users" || -d "$mount_point/Windows" ]]; then
                windows_partitions+=("$mount_point")
            fi
        fi
    done < <(mount | grep -E "(ntfs|vfat)")
    
    # Tentar auto-montar se não encontrou
    if [[ ${#windows_partitions[@]} -eq 0 ]]; then
        info "Tentando montar partições Windows automaticamente..."
        
        while IFS= read -r partition; do
            local mount_dir="/mnt/windows_auto_$(basename "$partition")"
            
            if sudo mkdir -p "$mount_dir" 2>/dev/null && \
               sudo mount "$partition" "$mount_dir" 2>/dev/null; then
                
                if [[ -d "$mount_dir/Users" || -d "$mount_dir/Windows" ]]; then
                    windows_partitions+=("$mount_dir")
                    success "Windows encontrado em: $mount_dir"
                else
                    sudo umount "$mount_dir" 2>/dev/null || true
                    sudo rmdir "$mount_dir" 2>/dev/null || true
                fi
            fi
        done < <(lsblk -rno NAME,FSTYPE | grep -E "ntfs|vfat" | awk '{print "/dev/"$1}')
    fi
    
    printf '%s\n' "${windows_partitions[@]}"
}

# Classificar arquivo por tipo
classify_file() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    local extension="${filename##*.}"
    extension=$(echo "$extension" | tr '[:upper:]' '[:lower:]')
    
    for category in "${!FILE_CATEGORIES[@]}"; do
        local extensions="${FILE_CATEGORIES[$category]}"
        if [[ ",$extensions," =~ ,$extension, ]]; then
            echo "$category"
            return
        fi
    done
    
    echo "outros"
}

# Verificar se arquivo é interessante
is_interesting_file() {
    local filepath="$1"
    local filename=$(basename "$filepath")
    
    # Pular arquivos de sistema/temporários
    local skip_patterns=(
        ".*"                    # Arquivos ocultos
        "*.tmp" "*.temp" "*.bak" "*.old"  # Temporários
        "*.cache" "*~" "*.swp"  # Cache/backup
        "Thumbs.db" "desktop.ini" ".DS_Store"  # Sistema
        "*.log" "*.pid"         # Logs
        "node_modules*" ".git*" # Desenvolvimento
    )
    
    for pattern in "${skip_patterns[@]}"; do
        if [[ "$filename" == $pattern ]]; then
            return 1
        fi
    done
    
    # Verificar tamanho
    local size=$(stat -c '%s' "$filepath" 2>/dev/null || echo 0)
    if [[ $size -lt $MIN_FILE_SIZE || $size -gt $MAX_FILE_SIZE ]]; then
        return 1
    fi
    
    # Verificar data (arquivos muito antigos podem ser irrelevantes)
    local mtime=$(stat -c '%Y' "$filepath" 2>/dev/null || echo 0)
    local cutoff_time=$(($(date +%s) - (RECENT_DAYS * 86400)))
    
    if [[ $mtime -lt $cutoff_time ]]; then
        # Exceção para documentos importantes mesmo que antigos
        local category=$(classify_file "$filepath")
        if [[ ! "$category" =~ ^(documentos|planilhas|fotos|videos|musicas)$ ]]; then
            return 1
        fi
    fi
    
    return 0
}

# Escanear diretório
scan_directory() {
    local base_dir="$1"
    local system_type="$2"  # "linux" ou "windows"
    
    info "Escaneando: $base_dir ($system_type)"
    
    declare -A found_files
    local total_count=0
    local total_size=0
    
    while IFS= read -r -d '' filepath; do
        if is_interesting_file "$filepath"; then
            local category=$(classify_file "$filepath")
            local size=$(stat -c '%s' "$filepath" 2>/dev/null || echo 0)
            
            found_files["$category,$filepath"]="$size"
            ((total_count++))
            ((total_size += size))
            
            if (( total_count % 100 == 0 )); then
                debug "Processados: $total_count arquivos..."
            fi
        fi
    done < <(find "$base_dir" -type f -readable -print0 2>/dev/null | head -z -n 50000)
    
    local human_size=$(numfmt --to=iec --suffix=B "$total_size" 2>/dev/null || echo "${total_size}B")
    success "Encontrados: $total_count arquivos ($human_size) em $base_dir"
    
    # Retornar dados via stdout
    for key in "${!found_files[@]}"; do
        echo "$system_type|$key|${found_files[$key]}"
    done
}

# Preparar estrutura no destino
prepare_remote_structure() {
    info "Preparando estrutura no destino..."
    
    local remote_dirs=()
    
    if [[ "$ORGANIZE_BY_TYPE" == true ]]; then
        for category in "${!FILE_CATEGORIES[@]}" "outros"; do
            remote_dirs+=("$REMOTE_BASE_PATH/$category")
        done
    else
        remote_dirs+=("$REMOTE_BASE_PATH/linux" "$REMOTE_BASE_PATH/windows")
    fi
    
    for dir in "${remote_dirs[@]}"; do
        if [[ "$DRY_RUN" == false ]]; then
            ssh "$REMOTE_USER@$REMOTE_IP" "mkdir -p '$dir'" || {
                error "Falha ao criar: $dir"
                return 1
            }
        fi
        debug "Preparado: $dir"
    done
}

# Transferir arquivo
transfer_file() {
    local source_file="$1"
    local category="$2"
    local system_type="$3"
    local size="$4"
    
    local dest_dir
    if [[ "$ORGANIZE_BY_TYPE" == true ]]; then
        dest_dir="$REMOTE_BASE_PATH/$category"
    else
        dest_dir="$REMOTE_BASE_PATH/$system_type"
    fi
    
    local filename=$(basename "$source_file")
    local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
    
    info "📦 $filename ($human_size) → $category/"
    
    if [[ "$DRY_RUN" == false ]]; then
        # Usar rsync para transferência robusta
        if rsync -az --partial --inplace \
           "$source_file" "$REMOTE_USER@$REMOTE_IP:$dest_dir/" 2>/dev/null; then
            return 0
        else
            warning "Falha na transferência: $filename"
            return 1
        fi
    fi
    
    return 0
}

# Função principal de descoberta
discover_files() {
    info "🔍 Iniciando descoberta inteligente de arquivos..."
    
    local temp_results=$(mktemp)
    
    # Escanear diretórios Linux
    for dir in "${LINUX_DIRS[@]}"; do
        if [[ -d "$dir" && -r "$dir" ]]; then
            scan_directory "$dir" "linux" >> "$temp_results"
        fi
    done
    
    # Escanear Windows se solicitado
    if [[ "$BACKUP_WINDOWS" == true ]]; then
        local windows_mounts
        mapfile -t windows_mounts < <(detect_windows)
        
        for mount_point in "${windows_mounts[@]}"; do
            # Expandir padrões de diretório
            for pattern in "${WINDOWS_DIRS[@]}"; do
                local actual_pattern="${pattern/\/mnt\/windows/$mount_point}"
                for dir in $actual_pattern; do
                    if [[ -d "$dir" && -r "$dir" ]]; then
                        scan_directory "$dir" "windows" >> "$temp_results"
                    fi
                done 2>/dev/null
            done
        done
    fi
    
    echo "$temp_results"
}

# Gerar relatório
generate_report() {
    local results_file="$1"
    
    info "📊 Gerando relatório..."
    
    declare -A stats_by_category
    declare -A stats_by_system
    local total_files=0
    local total_size=0
    
    while IFS='|' read -r system category filepath size; do
        stats_by_category["$category,count"]=$((${stats_by_category["$category,count"]:-0} + 1))
        stats_by_category["$category,size"]=$((${stats_by_category["$category,size"]:-0} + size))
        
        stats_by_system["$system,count"]=$((${stats_by_system["$system,count"]:-0} + 1))
        stats_by_system["$system,size"]=$((${stats_by_system["$system,size"]:-0} + size))
        
        ((total_files++))
        ((total_size += size))
    done < "$results_file"
    
    local report_file="transfer_plan_$(date +%Y%m%d_%H%M%S).txt"
    
    {
        echo "==============================================="
        echo "RELATÓRIO DE DESCOBERTA INTELIGENTE"
        echo "$(date '+%Y-%m-%d %H:%M:%S')"
        echo "==============================================="
        echo
        echo "RESUMO GERAL:"
        echo "  Total de arquivos: $total_files"
        echo "  Tamanho total: $(numfmt --to=iec --suffix=B "$total_size" 2>/dev/null || echo "${total_size}B")"
        echo
        echo "POR SISTEMA:"
        for system in "linux" "windows"; do
            local count=${stats_by_system["$system,count"]:-0}
            local size=${stats_by_system["$system,size"]:-0}
            local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
            printf "  %-8s: %6d arquivos (%s)\n" "$system" "$count" "$human_size"
        done
        echo
        echo "POR CATEGORIA:"
        for category in "${!FILE_CATEGORIES[@]}" "outros"; do
            local count=${stats_by_category["$category,count"]:-0}
            local size=${stats_by_category["$category,size"]:-0}
            
            if [[ $count -gt 0 ]]; then
                local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
                printf "  %-15s: %6d arquivos (%s)\n" "$category" "$count" "$human_size"
            fi
        done
        echo
        echo "DESTINO: $REMOTE_USER@$REMOTE_IP:$REMOTE_BASE_PATH"
        echo "ORGANIZAÇÃO: $([ "$ORGANIZE_BY_TYPE" == true ] && echo "Por tipo" || echo "Por sistema")"
        echo
    } > "$report_file"
    
    success "Relatório salvo: $report_file"
    echo "$report_file"
}

# Menu de configuração
configure_transfer() {
    echo "🚀 ORGANIZADOR INTELIGENTE DE ARQUIVOS"
    echo "======================================"
    echo
    
    # Configuração básica
    while [[ -z "$REMOTE_IP" ]]; do
        read -p "📡 IP do notebook destino: " REMOTE_IP
        if [[ ! "$REMOTE_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            error "IP inválido"
            REMOTE_IP=""
        fi
    done
    
    read -p "👤 Usuário no destino [$USER]: " REMOTE_USER
    [[ -z "$REMOTE_USER" ]] && REMOTE_USER="$USER"
    
    read -p "📁 Diretório base no destino [$REMOTE_BASE_PATH]: " input_path
    [[ -n "$input_path" ]] && REMOTE_BASE_PATH="$input_path"
    
    # Opções avançadas
    echo
    echo "⚙️  CONFIGURAÇÕES AVANÇADAS"
    
    read -p "📅 Dias para arquivos recentes [$RECENT_DAYS]: " input_days
    [[ -n "$input_days" && "$input_days" =~ ^[0-9]+$ ]] && RECENT_DAYS="$input_days"
    
    read -p "💾 Incluir arquivos do Windows? [Y/n]: " include_windows
    [[ "$include_windows" =~ ^[Nn] ]] && BACKUP_WINDOWS=false
    
    read -p "🗂️  Organizar por tipo de arquivo? [Y/n]: " organize_type
    [[ "$organize_type" =~ ^[Nn] ]] && ORGANIZE_BY_TYPE=false
    
    read -p "🔧 Modo teste (não transferir)? [y/N]: " dry_run
    [[ "$dry_run" =~ ^[Yy] ]] && DRY_RUN=true
    
    echo
}

# Função principal
main() {
    local start_time=$(date +%s)
    
    configure_transfer
    
    # Verificar conectividade
    if [[ "$DRY_RUN" == false ]]; then
        info "🔗 Testando conectividade..."
        if ! ssh -o ConnectTimeout=10 -o BatchMode=yes \
             "$REMOTE_USER@$REMOTE_IP" "echo 'OK'" &>/dev/null; then
            error "Não foi possível conectar ao destino"
            echo "💡 Certifique-se de que:"
            echo "   - SSH está habilitado no destino"
            echo "   - Você pode fazer login sem senha (ssh-copy-id)"
            echo "   - O IP está correto"
            exit 1
        fi
        success "Conectividade OK"
    fi
    
    # Descobrir arquivos
    local results_file
    results_file=$(discover_files)
    
    if [[ ! -s "$results_file" ]]; then
        warning "Nenhum arquivo interessante encontrado"
        exit 0
    fi
    
    # Gerar relatório
    local report_file
    report_file=$(generate_report "$results_file")
    
    # Mostrar resumo e confirmar
    echo
    cat "$report_file"
    echo
    
    if [[ "$DRY_RUN" == false ]]; then
        read -p "🚀 Iniciar transferência? [y/N]: " confirm
        [[ ! "$confirm" =~ ^[Yy] ]] && exit 0
        
        # Preparar destino
        prepare_remote_structure
    fi
    
    # Processar arquivos
    info "📦 Iniciando $([ "$DRY_RUN" == true ] && echo "simulação" || echo "transferência")..."
    
    local success_count=0
    local fail_count=0
    local processed=0
    local total_files=$(wc -l < "$results_file")
    
    while IFS='|' read -r system category filepath size; do
        ((processed++))
        
        printf "\r🔄 Progresso: %d/%d (%d%%) " \
               "$processed" "$total_files" "$((processed * 100 / total_files))"
        
        if transfer_file "$filepath" "$category" "$system" "$size"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        
    done < "$results_file"
    
    echo
    
    # Relatório final
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local duration_formatted=$(printf '%02d:%02d:%02d' $((duration/3600)) $((duration%3600/60)) $((duration%60)))
    
    echo
    echo "================ RESULTADO FINAL ================"
    success "$([ "$DRY_RUN" == true ] && echo "Simulação" || echo "Transferência") concluída em $duration_formatted"
    success "Sucessos: $success_count"
    [[ $fail_count -gt 0 ]] && warning "Falhas: $fail_count"
    info "Relatório: $report_file"
    
    if [[ "$DRY_RUN" == false && $success_count -gt 0 ]]; then
        echo
        echo "📱 Arquivos organizados em:"
        echo "   $REMOTE_USER@$REMOTE_IP:$REMOTE_BASE_PATH"
        echo
        echo "💡 Para acessar no destino:"
        echo "   ssh $REMOTE_USER@$REMOTE_IP"
        echo "   ls -la $REMOTE_BASE_PATH"
    fi
    
    echo "================================================="
    
    # Limpeza
    rm -f "$results_file"
}

# Executar se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
