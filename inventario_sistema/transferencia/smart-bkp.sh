#!/usr/bin/env bash
# Backup Inteligente Express - Versão simplificada para uso rápido

set -euo pipefail

# Configuração rápida - apenas preencha estas 3 linhas:
REMOTE_IP=""        # Ex: "192.168.1.100"
REMOTE_USER=""      # Ex: "usuario" 
NOTEBOOK_PATH=""    # Ex: "~/backup_pc" (será criado automaticamente)

# =================== PRESETS INTELIGENTES ===================

# Preset 1: ESSENCIAIS - Apenas documentos e fotos importantes
backup_essentials() {
    echo "📋 BACKUP ESSENCIAL - Documentos e fotos pessoais"
    
    rsync -avz --progress \
        --include='*/' \
        --include='*.pdf' --include='*.doc' --include='*.docx' \
        --include='*.jpg' --include='*.jpeg' --include='*.png' \
        --include='*.mp4' --include='*.avi' \
        --exclude='*' \
        ~/ "$REMOTE_USER@$REMOTE_IP:$NOTEBOOK_PATH/essenciais/"
        
    # Windows (se montado em /mnt/)
    if [[ -d "/mnt" ]]; then
        find /mnt -name "Users" -type d 2>/dev/null | while read -r users_dir; do
            echo "🪟 Buscando arquivos essenciais no Windows: $users_dir"
            rsync -avz --progress \
                --include='*/' \
                --include='*.pdf' --include='*.doc' --include='*.docx' \
                --include='*.jpg' --include='*.jpeg' --include='*.png' \
                --include='*.mp4' --include='*.avi' \
                --exclude='*' \
                "$users_dir/" "$REMOTE_USER@$REMOTE_IP:$NOTEBOOK_PATH/essenciais_windows/" 2>/dev/null || true
        done
    fi
}

# Preset 2: DESENVOLVIMENTO - Projetos e código
backup_dev() {
    echo "💻 BACKUP DESENVOLVIMENTO - Código e projetos"
    
    # Diretórios comuns de desenvolvimento
    local dev_dirs=("~/Projects" "~/workspace" "~/dev" "~/git" "~/code")
    
    for dir in "${dev_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "📁 Fazendo backup: $dir"
            rsync -avz --progress \
                --exclude='node_modules/' --exclude='.git/' --exclude='target/' \
                --exclude='build/' --exclude='dist/' --exclude='*.log' \
                --exclude='*.tmp' --exclude='.cache/' \
                "$dir/" "$REMOTE_USER@$REMOTE_IP:$NOTEBOOK_PATH/desenvolvimento/"
        fi
    done
}

# Preset 3: MÍDIA - Fotos, vídeos e música
backup_media() {
    echo "🎬 BACKUP MÍDIA - Fotos, vídeos e música"
    
    local media_dirs=("~/Pictures" "~/Videos" "~/Music" "~/Downloads")
    
    for dir in "${media_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "🎵 Fazendo backup: $dir"
            rsync -avz --progress \
                --include='*.jpg' --include='*.jpeg' --include='*.png' --include='*.tiff' \
                --include='*.mp4' --include='*.avi' --include='*.mov' --include='*.mkv' \
                --include='*.mp3' --include='*.flac' --include='*.wav' \
                --include='*/' \
                --exclude='*' \
                "$dir/" "$REMOTE_USER@$REMOTE_IP:$NOTEBOOK_PATH/midia/"
        fi
    done
}

# Preset 4: COMPLETO - Tudo organizado automaticamente
backup_smart_complete() {
    echo "🧠 BACKUP INTELIGENTE COMPLETO"
    
    # Criar estrutura organizada no destino
    ssh "$REMOTE_USER@$REMOTE_IP" "mkdir -p $NOTEBOOK_PATH/{documentos,fotos,videos,musicas,downloads,desktop,codigo,outros}"
    
    # Documentos
    echo "📄 Organizando documentos..."
    find ~/ -type f \( -name "*.pdf" -o -name "*.doc" -o -name "*.docx" -o -name "*.odt" -o -name "*.txt" \) \
        -not -path "*/.*" -not -path "*/tmp/*" -not -path "*/cache/*" \
        -exec rsync -avz --relative {} "$REMOTE_USER@$REMOTE_IP:$NOTEBOOK_PATH/documentos/" \;
    
    # Fotos (últimos 2 anos)
    echo "📸 Organizando fotos recentes..."
    find ~/Pictures ~/Desktop ~/Downloads -type f \
        -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.tiff" \
        -newermt "$(date -d '2 years ago' '+%Y-%m-%d')" 2>/dev/null | \
        xargs -r -I {} rsync -avz {} "$REMOTE_USER@$REMOTE_IP:$NOTEBOOK_PATH/fotos/"
    
    # Vídeos importantes (não muito grandes)
    echo "🎥 Organizando vídeos..."
    find ~/Videos ~/Desktop ~/Downloads -type f \
        \( -name "*.mp4" -o -name "*.avi" -o -name "*.mov" \) \
        -size -500M 2>/dev/null | \
        xargs -r -I {} rsync -avz {} "$REMOTE_USER@$REMOTE_IP:$NOTEBOOK_PATH/videos/"
    
    # Desktop importante
    echo "🖥️ Backup do Desktop..."
    rsync -avz --progress ~/Desktop/ "$REMOTE_USER@$REMOTE_IP:$NOTEBOOK_PATH/desktop/" \
        --exclude="*.tmp" --exclude="*.cache"
}

# Auto-detectar e montar Windows
setup_windows_access() {
    echo "🔍 Procurando partição Windows..."
    
    # Verificar se já está montado
    if mount | grep -qi ntfs | head -1; then
        echo "✅ Windows já acessível"
        return 0
    fi
    
    # Tentar auto-montar
    local windows_part=$(lsblk -f | grep -i ntfs | head -1 | awk '{print $1}' | sed 's/[├└─│]//g' | tr -d ' ')
    
    if [[ -n "$windows_part" ]]; then
        echo "🔧 Tentando montar /dev/$windows_part"
        sudo mkdir -p /mnt/windows_auto
        
        if sudo mount "/dev/$windows_part" /mnt/windows_auto 2>/dev/null; then
            echo "✅ Windows montado em /mnt/windows_auto"
            return 0
        else
            echo "❌ Não foi possível montar Windows automaticamente"
            return 1
        fi
    fi
    
    echo "❌ Partição Windows não encontrada"
    return 1
}

# Menu principal
show_menu() {
    clear
    echo "🚀 BACKUP INTELIGENTE EXPRESS"
    echo "=============================="
    echo
    echo "Destino: $REMOTE_USER@$REMOTE_IP:$NOTEBOOK_PATH"
    echo
    echo "Escolha o tipo de backup:"
    echo
    echo "1) 📋 ESSENCIAIS      - Documentos e fotos importantes (~15 min)"
    echo "2) 💻 DESENVOLVIMENTO - Projetos e código fonte (~10 min)" 
    echo "3) 🎬 MÍDIA          - Fotos, vídeos e música (~30 min)"
    echo "4) 🧠 COMPLETO       - Tudo organizado automaticamente (~45 min)"
    echo "5) ⚙️  CUSTOMIZADO    - Configurar manualmente"
    echo "6) 🪟 SETUP WINDOWS  - Detectar e montar Windows"
    echo
    echo "0) ❌ Sair"
    echo
    read -p "Sua escolha: " choice
    echo
}

# Função de validação
validate_config() {
    if [[ -z "$REMOTE_IP" || -z "$REMOTE_USER" || -z "$NOTEBOOK_PATH" ]]; then
        echo "❌ Configure primeiro as variáveis no topo do script:"
        echo "   REMOTE_IP, REMOTE_USER, NOTEBOOK_PATH"
        exit 1
    fi
    
    # Testar conectividade
    echo "🔗 Testando conectividade com $REMOTE_IP..."
    if ! ping -c 1 -W 3 "$REMOTE_IP" &>/dev/null; then
        echo "❌ Host $REMOTE_IP não alcançável"
        exit 1
    fi
    
    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_USER@$REMOTE_IP" "echo 'OK'" &>/dev/null; then
        echo "❌ SSH não disponível. Configure com:"
        echo "   ssh-keygen -t rsa"
        echo "   ssh-copy-id $REMOTE_USER@$REMOTE_IP"
        exit 1
    fi
    
    # Criar diretório base
    ssh "$REMOTE_USER@$REMOTE_IP" "mkdir -p '$NOTEBOOK_PATH'"
    echo "✅ Conectividade OK"
}

# Backup customizado
backup_custom() {
    echo "⚙️ BACKUP CUSTOMIZADO"
    echo "===================="
    
    local source_dirs=()
    local file_patterns=""
    local exclude_patterns="*.tmp,*.cache,*.log,node_modules"
    local max_size="1G"
    local min_days="0"
    
    echo "📁 Selecione diretórios para backup:"
    echo "   (Enter vazio para finalizar)"
    
    local dir_options=(
        "~/Documents" "~/Desktop" "~/Downloads" "~/Pictures" 
        "~/Videos" "~/Music" "~/Projects" "~/workspace" "~/dev"
    )
    
    echo "Diretórios sugeridos:"
    for i in "${!dir_options[@]}"; do
        local dir="${dir_options[$i]}"
        if [[ -d "$dir" ]]; then
            echo "  $((i+1))) $dir"
        fi
    done
    echo
    
    while true; do
        read -p "Diretório (número ou caminho): " input
        [[ -z "$input" ]] && break
        
        if [[ "$input" =~ ^[0-9]+$ ]] && [[ $input -le ${#dir_options[@]} ]]; then
            local selected_dir="${dir_options[$((input-1))]}"
            if [[ -d "$selected_dir" ]]; then
                source_dirs+=("$selected_dir")
                echo "✅ Adicionado: $selected_dir"
            fi
        elif [[ -d "$input" ]]; then
            source_dirs+=("$input")
            echo "✅ Adicionado: $input"
        else
            echo "❌ Diretório não encontrado: $input"
        fi
    done
    
    if [[ ${#source_dirs[@]} -eq 0 ]]; then
        echo "❌ Nenhum diretório selecionado"
        return 1
    fi
    
    # Configurações adicionais
    echo
    read -p "🎯 Tipos de arquivo (ex: *.pdf,*.jpg) [todos]: " file_patterns
    read -p "🚫 Excluir padrões [$exclude_patterns]: " custom_exclude
    [[ -n "$custom_exclude" ]] && exclude_patterns="$custom_exclude"
    
    read -p "📏 Tamanho máximo de arquivo [$max_size]: " custom_max_size
    [[ -n "$custom_max_size" ]] && max_size="$custom_max_size"
    
    read -p "📅 Arquivos modificados nos últimos N dias (0=todos) [$min_days]: " custom_days
    [[ -n "$custom_days" ]] && min_days="$custom_days"
    
    # Executar backup customizado
    echo
    echo "🚀 Iniciando backup customizado..."
    
    for source_dir in "${source_dirs[@]}"; do
        echo "📦 Processando: $source_dir"
        
        local rsync_cmd="rsync -avz --progress"
        
        # Adicionar filtros
        if [[ -n "$file_patterns" ]]; then
            IFS=',' read -ra patterns <<< "$file_patterns"
            for pattern in "${patterns[@]}"; do
                rsync_cmd="$rsync_cmd --include='$pattern'"
            done
            rsync_cmd="$rsync_cmd --exclude='*'"
        fi
        
        # Exclusões
        IFS=',' read -ra excludes <<< "$exclude_patterns"
        for exclude in "${excludes[@]}"; do
            rsync_cmd="$rsync_cmd --exclude='$exclude'"
        done
        
        # Tamanho máximo
        [[ "$max_size" != "0" ]] && rsync_cmd="$rsync_cmd --max-size='$max_size'"
        
        # Data mínima (implementação básica)
        if [[ "$min_days" != "0" ]]; then
            # Para simplificar, usar find + rsync
            echo "  🔍 Filtrando arquivos dos últimos $min_days dias..."
            local temp_list=$(mktemp)
            find "$source_dir" -type f -mtime "-$min_days" > "$temp_list"
            
            rsync -avz --progress --files-from="$temp_list" \
                / "$REMOTE_USER@$REMOTE_IP:$NOTEBOOK_PATH/customizado/"
            
            rm "$temp_list"
        else
            # Comando rsync normal
            local dest_name=$(basename "$source_dir")
            eval "$rsync_cmd '$source_dir/' '$REMOTE_USER@$REMOTE_IP:$NOTEBOOK_PATH/customizado/$dest_name/'"
        fi
    done
    
    echo "✅ Backup customizado concluído"
}

# Estatísticas rápidas
show_stats() {
    echo "📊 ESTATÍSTICAS DO SISTEMA"
    echo "========================="
    
    # Espaço em disco
    echo "💾 Espaço em disco:"
    df -h ~/ | tail -1 | awk '{printf "   Usado: %s de %s (%s)\n", $3, $2, $5}'
    
    # Arquivos por tipo (estimativa rápida)
    echo
    echo "📁 Arquivos por tipo (estimativa):"
    
    declare -A file_counts
    declare -A file_sizes
    
    # Busca rápida nos diretórios principais
    for ext in pdf doc docx jpg jpeg png mp4 avi mp3 zip; do
        local count=$(find ~/Documents ~/Desktop ~/Downloads ~/Pictures ~/Videos ~/Music -name "*.$ext" 2>/dev/null | wc -l)
        local size=0
        
        if [[ $count -gt 0 ]]; then
            size=$(find ~/Documents ~/Desktop ~/Downloads ~/Pictures ~/Videos ~/Music -name "*.$ext" -exec stat -c '%s' {} + 2>/dev/null | awk '{sum+=$1} END{print sum+0}')
            local human_size=$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "${size}B")
            printf "   %-6s: %4d arquivos (%s)\n" "$ext" "$count" "$human_size"
        fi
    done
    
    # Windows stats se disponível
    if mount | grep -qi ntfs; then
        echo
        echo "🪟 Windows detectado e acessível"
        local win_users=$(find /mnt -name "Users" -type d 2>/dev/null | head -1)
        if [[ -n "$win_users" ]]; then
            local win_docs=$(find "$win_users" -name "*.pdf" -o -name "*.doc" -o -name "*.jpg" 2>/dev/null | wc -l)
            echo "   Arquivos importantes encontrados: $win_docs"
        fi
    fi
    
    echo
}

# Função principal
main() {
    validate_config
    
    while true; do
        show_menu
        
        case "$choice" in
            1)
                echo "⏱️  Tempo estimado: 15 minutos"
                read -p "Continuar? [Y/n]: " confirm
                [[ "$confirm" =~ ^[Nn] ]] || backup_essentials
                ;;
            2)
                echo "⏱️  Tempo estimado: 10 minutos"
                read -p "Continuar? [Y/n]: " confirm
                [[ "$confirm" =~ ^[Nn] ]] || backup_dev
                ;;
            3)
                echo "⏱️  Tempo estimado: 30 minutos"
                read -p "Continuar? [Y/n]: " confirm
                [[ "$confirm" =~ ^[Nn] ]] || backup_media
                ;;
            4)
                echo "⏱️  Tempo estimado: 45 minutos"
                read -p "Continuar? [Y/n]: " confirm
                [[ "$confirm" =~ ^[Nn] ]] || backup_smart_complete
                ;;
            5)
                backup_custom
                ;;
            6)
                setup_windows_access
                ;;
            7)
                show_stats
                read -p "Pressione Enter para continuar..."
                ;;
            0)
                echo "👋 Até mais!"
                exit 0
                ;;
            *)
                echo "❌ Opção inválida"
                sleep 2
                ;;
        esac
        
        echo
        read -p "✅ Pressione Enter para voltar ao menu principal..."
    done
}

# Modo linha de comando
if [[ $# -gt 0 ]]; then
    case "$1" in
        "essentials"|"1")
            validate_config
            backup_essentials
            ;;
        "dev"|"2")
            validate_config
            backup_dev
            ;;
        "media"|"3")
            validate_config
            backup_media
            ;;
        "complete"|"4")
            validate_config
            backup_smart_complete
            ;;
        "setup-windows"|"windows")
            setup_windows_access
            ;;
        "stats")
            show_stats
            ;;
        *)
            echo "Uso: $0 [essentials|dev|media|complete|setup-windows|stats]"
            echo "Ou execute sem parâmetros para o menu interativo"
            ;;
    esac
else
    main
fi
