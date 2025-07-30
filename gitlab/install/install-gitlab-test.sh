#!/bin/bash

#==============================================================================
# GitLab CE - Instalação Automatizada para Ambiente de Testes
# Sistema: Ubuntu Server 22.04 LTS
# Requisitos: 2 vCPU, 4 GB RAM, 50+ GB de armazenamento
# Autor: DevOps Team
# Versão: 2.0
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Configurações
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/var/log/gitlab-install-test.log"
readonly GITLAB_CONFIG_DIR="/etc/gitlab"
readonly BACKUP_DIR="/opt/gitlab/backups"
readonly MIN_RAM_GB=4
readonly MIN_DISK_GB=50

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

#==============================================================================
# FUNÇÕES UTILITÁRIAS
#==============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

info() { log "INFO" "${BLUE}ℹ️  $*${NC}"; }
success() { log "SUCCESS" "${GREEN}✅ $*${NC}"; }
warning() { log "WARNING" "${YELLOW}⚠️  $*${NC}"; }
error() { log "ERROR" "${RED}❌ $*${NC}"; }

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        error "Instalação falhou. Verifique o log em: ${LOG_FILE}"
        error "Para limpeza manual: sudo apt remove --purge gitlab-ce && sudo rm -rf /etc/gitlab /var/opt/gitlab"
    fi
    exit $exit_code
}

trap cleanup EXIT

#==============================================================================
# VERIFICAÇÕES DE PRÉ-REQUISITOS
#==============================================================================

check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        error "Este script não deve ser executado como root. Use um usuário com sudo."
        exit 1
    fi
    
    if ! sudo -n true 2>/dev/null; then
        error "Usuário atual não possui privilégios sudo ou senha é necessária."
        exit 1
    fi
}

check_system_requirements() {
    info "Verificando requisitos do sistema..."
    
    # Verificar distribuição
    if ! grep -q "Ubuntu 22.04" /etc/os-release; then
        warning "Sistema não é Ubuntu 22.04 LTS. Continuando, mas pode haver incompatibilidades."
    fi
    
    # Verificar RAM
    local ram_gb=$(awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo)
    if [[ $ram_gb -lt $MIN_RAM_GB ]]; then
        warning "RAM disponível (${ram_gb}GB) é menor que o recomendado (${MIN_RAM_GB}GB)"
    fi
    
    # Verificar espaço em disco
    local disk_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $disk_gb -lt $MIN_DISK_GB ]]; then
        error "Espaço em disco insuficiente. Disponível: ${disk_gb}GB, Necessário: ${MIN_DISK_GB}GB"
        exit 1
    fi
    
    success "Requisitos do sistema verificados"
}

check_existing_installation() {
    info "Verificando instalações existentes..."
    
    if command -v gitlab-ctl >/dev/null 2>&1; then
        error "GitLab já está instalado. Para reinstalar:"
        error "sudo apt remove --purge gitlab-ce && sudo rm -rf /etc/gitlab /var/opt/gitlab"
        exit 1
    fi
    
    if systemctl is-active --quiet nginx apache2 2>/dev/null; then
        warning "Servidor web detectado. Pode haver conflito de portas."
        read -p "Continuar mesmo assim? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    success "Nenhuma instalação conflitante encontrada"
}

check_network() {
    info "Verificando conectividade de rede..."
    
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        error "Sem conectividade com a internet"
        exit 1
    fi
    
    if ! curl -s --connect-timeout 10 https://packages.gitlab.com >/dev/null; then
        error "Não foi possível acessar o repositório do GitLab"
        exit 1
    fi
    
    success "Conectividade verificada"
}

#==============================================================================
# CONFIGURAÇÃO INTERATIVA
#==============================================================================

get_configuration() {
    info "Configuração do ambiente de teste..."
    
    # Detectar IP local
    local default_ip=$(ip route get 8.8.8.8 | awk '{print $7}' | head -1)
    
    echo
    read -p "Digite o IP ou hostname para acesso [${default_ip}]: " external_url
    external_url=${external_url:-$default_ip}
    
    # Validar formato
    if [[ ! $external_url =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ && ! $external_url =~ ^[a-zA-Z0-9.-]+$ ]]; then
        error "Formato de IP/hostname inválido"
        exit 1
    fi
    
    export EXTERNAL_URL="http://${external_url}"
    
    echo
    read -p "Configurar backup automático? (y/N): " -n 1 -r setup_backup
    echo
    setup_backup=${setup_backup:-n}
    
    info "Configuração definida:"
    info "  URL Externa: ${EXTERNAL_URL}"
    info "  Backup automático: ${setup_backup}"
}

#==============================================================================
# INSTALAÇÃO
#==============================================================================

update_system() {
    info "Atualizando sistema..."
    
    export DEBIAN_FRONTEND=noninteractive
    sudo apt update -qq
    sudo apt upgrade -y -qq
    
    success "Sistema atualizado"
}

install_dependencies() {
    info "Instalando dependências..."
    
    local packages=(
        "curl"
        "openssh-server"
        "ca-certificates"
        "tzdata"
        "perl"
        "postfix"
        "ufw"
        "fail2ban"
        "htop"
        "nano"
    )
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            info "Instalando: $package"
            sudo apt install -y -qq "$package"
        fi
    done
    
    success "Dependências instaladas"
}

configure_security() {
    info "Configurando segurança básica..."
    
    # Configurar fail2ban
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    
    # Configurar SSH (apenas se não estiver em ambiente automatizado)
    if [[ -t 0 ]]; then
        sudo sed -i 's/#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        sudo systemctl reload sshd
    fi
    
    success "Configurações de segurança aplicadas"
}

install_gitlab() {
    info "Adicionando repositório do GitLab..."
    
    curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
    
    info "Instalando GitLab CE..."
    info "URL Externa configurada: ${EXTERNAL_URL}"
    
    sudo EXTERNAL_URL="${EXTERNAL_URL}" apt install -y gitlab-ce
    
    success "GitLab CE instalado"
}

configure_gitlab() {
    info "Configurando GitLab..."
    
    # Criar backup do arquivo de configuração original
    sudo cp "${GITLAB_CONFIG_DIR}/gitlab.rb" "${GITLAB_CONFIG_DIR}/gitlab.rb.backup.$(date +%Y%m%d)"
    
    # Configurações básicas para ambiente de teste
    sudo tee -a "${GITLAB_CONFIG_DIR}/gitlab.rb" >/dev/null <<EOF

## Configurações Ambiente de Teste - $(date)
external_url '${EXTERNAL_URL}'

## Configurações de Performance (Ambiente de Teste)
puma['worker_processes'] = 2
sidekiq['max_concurrency'] = 10

## Configurações de Email (Desabilitado para teste)
gitlab_rails['gitlab_email_enabled'] = false

## Configurações de Backup
gitlab_rails['backup_path'] = "${BACKUP_DIR}"
gitlab_rails['backup_keep_time'] = 604800

## Configurações de Segurança
nginx['custom_gitlab_server_config'] = "add_header X-Frame-Options DENY;"
gitlab_rails['rack_attack_git_basic_auth'] = {
  'enabled' => true,
  'ip_whitelist' => ["127.0.0.1", "::1"],
  'maxretry' => 10,
  'findtime' => 60,
  'bantime' => 3600
}

## Monitoramento
prometheus_monitoring['enable'] = true
EOF
    
    # Reconfigurar GitLab
    info "Reconfigurando GitLab (isso pode demorar alguns minutos)..."
    sudo gitlab-ctl reconfigure
    
    # Criar diretório de backup
    sudo mkdir -p "${BACKUP_DIR}"
    sudo chown git:git "${BACKUP_DIR}"
    
    success "GitLab configurado"
}

setup_firewall() {
    info "Configurando firewall..."
    
    sudo ufw --force reset
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow ssh
    sudo ufw allow http
    sudo ufw allow https
    sudo ufw --force enable
    
    success "Firewall configurado"
}

setup_backup_automation() {
    if [[ $setup_backup =~ ^[Yy]$ ]]; then
        info "Configurando backup automático..."
        
        # Script de backup
        sudo tee /opt/gitlab-backup.sh >/dev/null <<'EOF'
#!/bin/bash
# GitLab Backup Script - Ambiente de Teste

LOG_FILE="/var/log/gitlab-backup.log"
BACKUP_DIR="/opt/gitlab/backups"
RETENTION_DAYS=7

echo "$(date): Iniciando backup do GitLab" >> "$LOG_FILE"

# Executar backup
gitlab-backup create CRON=1 >> "$LOG_FILE" 2>&1

# Limpar backups antigos
find "$BACKUP_DIR" -name "*gitlab_backup.tar" -mtime +$RETENTION_DAYS -delete

echo "$(date): Backup concluído" >> "$LOG_FILE"
EOF
        
        sudo chmod +x /opt/gitlab-backup.sh
        
        # Cron job (backup diário às 2h)
        echo "0 2 * * * root /opt/gitlab-backup.sh" | sudo tee -a /etc/crontab
        
        success "Backup automático configurado (diário às 2h)"
    fi
}

#==============================================================================
# VERIFICAÇÃO PÓS-INSTALAÇÃO
#==============================================================================

verify_installation() {
    info "Verificando instalação..."
    
    # Aguardar serviços iniciarem
    local max_wait=300
    local wait_time=0
    
    while ! sudo gitlab-ctl status >/dev/null 2>&1 && [[ $wait_time -lt $max_wait ]]; do
        info "Aguardando serviços iniciarem... (${wait_time}s/${max_wait}s)"
        sleep 10
        wait_time=$((wait_time + 10))
    done
    
    # Verificar status dos serviços
    if ! sudo gitlab-ctl status | grep -q "run:"; then
        error "Alguns serviços do GitLab não estão rodando"
        sudo gitlab-ctl status
        exit 1
    fi
    
    # Testar conectividade HTTP
    if command -v curl >/dev/null; then
        if curl -s -o /dev/null -w "%{http_code}" "${EXTERNAL_URL}" | grep -q "200\|302"; then
            success "GitLab está respondendo em ${EXTERNAL_URL}"
        else
            warning "GitLab pode não estar acessível externamente"
        fi
    fi
    
    success "Verificação concluída"
}

show_final_info() {
    echo
    echo "======================================================================"
    success "GitLab CE instalado com sucesso no ambiente de TESTE!"
    echo "======================================================================"
    echo
    info "🌐 URL de Acesso: ${EXTERNAL_URL}"
    info "👤 Usuário inicial: root"
    info "🔐 Senha inicial: Execute 'sudo gitlab-rake gitlab:password:reset' para definir"
    echo
    info "📁 Arquivos importantes:"
    info "  • Configuração: ${GITLAB_CONFIG_DIR}/gitlab.rb"
    info "  • Logs: /var/log/gitlab/"
    info "  • Backups: ${BACKUP_DIR}"
    info "  • Log desta instalação: ${LOG_FILE}"
    echo
    info "🔧 Comandos úteis:"
    info "  • Status: sudo gitlab-ctl status"
    info "  • Restart: sudo gitlab-ctl restart"
    info "  • Reconfigurar: sudo gitlab-ctl reconfigure"
    info "  • Backup manual: sudo gitlab-backup create"
    echo
    warning "⚠️  Este é um ambiente de TESTE. Não use em produção!"
    echo "======================================================================"
}

#==============================================================================
# EXECUÇÃO PRINCIPAL
#==============================================================================

main() {
    info "Iniciando instalação do GitLab CE - Ambiente de Teste"
    info "Log será salvo em: ${LOG_FILE}"
    
    # Criar log file
    sudo touch "${LOG_FILE}"
    sudo chmod 666 "${LOG_FILE}"
    
    # Verificações
    check_privileges
    check_system_requirements
    check_existing_installation
    check_network
    
    # Configuração
    get_configuration
    
    # Instalação
    update_system
    install_dependencies
    configure_security
    install_gitlab
    configure_gitlab
    setup_firewall
    setup_backup_automation
    
    # Verificação
    verify_installation
    show_final_info
}

# Executar apenas se chamado diretamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi