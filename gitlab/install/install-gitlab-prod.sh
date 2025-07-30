#!/bin/bash

#==============================================================================
# GitLab CE - Instalação para Ambiente de Produção
# Sistema: Ubuntu Server 22.04 LTS
# Requisitos: 4+ vCPU, 8+ GB RAM, 100+ GB SSD NVMe, Domínio válido
# Autor: DevOps Team
# Versão: 2.0
#==============================================================================

set -euo pipefail
IFS=$'\n\t'

# Configurações
readonly SCRIPT_NAME="$(basename "$0")"
readonly LOG_FILE="/var/log/gitlab-install-prod.log"
readonly GITLAB_CONFIG_DIR="/etc/gitlab"
readonly BACKUP_DIR="/var/opt/gitlab/backups"
readonly SSL_DIR="/etc/gitlab/ssl"
readonly MIN_RAM_GB=8
readonly MIN_DISK_GB=100
readonly MIN_VCPU=4

# Cores para output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly NC='\033[0m'

#==============================================================================
# FUNÇÕES UTILITÁRIAS
#==============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

info() { log "INFO" "${BLUE}ℹ️  $*${NC}"; }
success() { log "SUCCESS" "${GREEN}✅ $*${NC}"; }
warning() { log "WARNING" "${YELLOW}⚠️  $*${NC}"; }
error() { log "ERROR" "${RED}❌ $*${NC}"; }
critical() { log "CRITICAL" "${PURPLE}🚨 $*${NC}"; }

cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        critical "Instalação falhou! Verifique o log: ${LOG_FILE}"
        error "Para limpeza: sudo apt remove --purge gitlab-ce && sudo rm -rf /etc/gitlab /var/opt/gitlab"
    fi
    exit $exit_code
}

trap cleanup EXIT

#==============================================================================
# VERIFICAÇÕES DE PRÉ-REQUISITOS PRODUÇÃO
#==============================================================================

check_privileges() {
    if [[ $EUID -eq 0 ]]; then
        error "Este script não deve ser executado como root. Use um usuário com sudo."
        exit 1
    fi

    if ! sudo -n true 2>/dev/null; then
        error "Usuário atual não possui privilégios sudo adequados."
        exit 1
    fi
}

check_production_requirements() {
    info "Verificando requisitos para ambiente de PRODUÇÃO..."

    if ! grep -q "Ubuntu 22.04" /etc/os-release; then
        error "Sistema deve ser Ubuntu 22.04 LTS para produção"
        exit 1
    fi

    local cpu_cores
    cpu_cores=$(nproc)
    if [[ $cpu_cores -lt $MIN_VCPU ]]; then
        error "CPU insuficiente. Atual: ${cpu_cores} cores, Mínimo: ${MIN_VCPU} cores"
        exit 1
    fi

    local ram_gb
    ram_gb=$(awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo)
    if [[ $ram_gb -lt $MIN_RAM_GB ]]; then
        error "RAM insuficiente. Atual: ${ram_gb}GB, Mínimo: ${MIN_RAM_GB}GB"
        exit 1
    fi

    local disk_gb
    disk_gb=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $disk_gb -lt $MIN_DISK_GB ]]; then
        error "Espaço em disco insuficiente. Disponível: ${disk_gb}GB, Mínimo: ${MIN_DISK_GB}GB"
        exit 1
    fi

    success "Requisitos de hardware verificados"
}

check_network_production() {
    info "Verificando configuração de rede para produção..."

    if ! ping -c 3 8.8.8.8 >/dev/null 2>&1; then
        error "Conectividade com internet é obrigatória"
        exit 1
    fi

    if ! nslookup google.com >/dev/null 2>&1; then
        error "Resolução DNS não está funcionando"
        exit 1
    fi

    if ! curl -s --connect-timeout 10 https://packages.gitlab.com >/dev/null; then
        error "Não foi possível acessar repositório do GitLab"
        exit 1
    fi

    success "Conectividade de rede verificada"
}

check_existing_services() {
    info "Verificando serviços conflitantes..."

    local conflicting_services=("nginx" "apache2" "httpd" "gitlab-ce")
    local conflicts_found=false

    for service in "${conflicting_services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            error "Serviço conflitante ativo: $service"
            conflicts_found=true
        fi
    done

    if [[ $conflicts_found == true ]]; then
        error "Pare os serviços conflitantes antes de continuar"
        exit 1
    fi

    success "Nenhum serviço conflitante encontrado"
}

#==============================================================================
# CONFIGURAÇÃO PRODUÇÃO
#==============================================================================

get_production_config() {
    info "Configuração para ambiente de PRODUÇÃO"
    echo

    while true; do
        read -p "Digite o domínio FQDN (ex: gitlab.empresa.com): " domain
        if [[ $domain =~ ^[a-zA-Z0-9.-]+$ ]]; then
            break
        else
            error "Formato de domínio inválido."
        fi
    done

    read -p "Usar HTTPS/SSL? (Y/n): " -n 1 -r use_ssl
    echo
    use_ssl=${use_ssl:-y}

    if [[ $use_ssl =~ ^[Yy]$ ]]; then
        export EXTERNAL_URL="https://${domain}"
        echo "Opções de SSL:"
        echo "1) Let's Encrypt (automático)"
        echo "2) Certificados próprios"
        echo "3) SSL terminado no load balancer"
        read -p "Escolha [1]: " ssl_option
        ssl_option=${ssl_option:-1}
    else
        export EXTERNAL_URL="http://${domain}"
        ssl_option=0
    fi

    read -p "Configurar SMTP para emails? (Y/n): " -n 1 -r setup_smtp
    echo
    setup_smtp=${setup_smtp:-y}

    if [[ $setup_smtp =~ ^[Yy]$ ]]; then
        read -p "Servidor SMTP: " smtp_server
        read -p "Porta SMTP [587]: " smtp_port
        smtp_port=${smtp_port:-587}
        read -p "Usuário SMTP: " smtp_user
        read -s -p "Senha SMTP: " smtp_pass
        echo
    fi

    read -p "Configurar backup automático? (Y/n): " -n 1 -r setup_backup
    echo
    setup_backup=${setup_backup:-y}

    if [[ $setup_backup =~ ^[Yy]$ ]]; then
        read -p "Diretório de backup [/backup/gitlab]: " backup_path
        backup_path=${backup_path:-/backup/gitlab}

        read -p "Dias de retenção [30]: " backup_retention
        backup_retention=${backup_retention:-30}
    fi

    echo
    info "=== CONFIGURAÇÃO DEFINIDA ==="
    info "URL Externa: ${EXTERNAL_URL}"
    info "SSL/TLS: $([ $use_ssl = 'y' ] && echo 'Habilitado' || echo 'Desabilitado')"
    info "SMTP: $([ $setup_smtp = 'y' ] && echo 'Configurado' || echo 'Não configurado')"
    info "Backup: $([ $setup_backup = 'y' ] && echo 'Automático' || echo 'Manual')"
    echo

    read -p "Confirma a configuração? (Y/n): " -n 1 -r confirm
    echo
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        error "Instalação cancelada pelo usuário"
        exit 1
    fi
}

optimize_system() {
    info "Otimizando sistema para produção..."
    sudo apt update -qq
    sudo apt upgrade -y -qq
    sudo sysctl -w vm.swappiness=1
    success "Sistema otimizado para produção"
}

install_dependencies() {
    info "Instalando dependências..."
    sudo apt install -y curl openssh-server ca-certificates tzdata perl postfix ufw fail2ban
    success "Dependências instaladas"
}

install_gitlab() {
    info "Instalando GitLab CE..."
    curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
    sudo EXTERNAL_URL="${EXTERNAL_URL}" apt install -y gitlab-ce
    success "GitLab CE instalado"
}

configure_gitlab_production() {
    info "Configurando GitLab..."

    sudo cp "${GITLAB_CONFIG_DIR}/gitlab.rb" "${GITLAB_CONFIG_DIR}/gitlab.rb.bkp"

    if [[ $ssl_option -eq 2 ]]; then
        sudo mkdir -p "${SSL_DIR}"
        read -p "Nome do certificado (ex: gitlab.crt): " ssl_cert
        read -p "Nome da chave (ex: gitlab.key): " ssl_key
        sudo tee -a "${GITLAB_CONFIG_DIR}/gitlab.rb" >/dev/null <<EOF
nginx['redirect_http_to_https'] = true
nginx['ssl_certificate'] = "${SSL_DIR}/${ssl_cert}"
nginx['ssl_certificate_key'] = "${SSL_DIR}/${ssl_key}"
EOF
    fi

    if [[ $setup_smtp =~ ^[Yy]$ ]]; then
        sudo tee -a "${GITLAB_CONFIG_DIR}/gitlab.rb" >/dev/null <<EOF
gitlab_rails['smtp_enable'] = true
gitlab_rails['smtp_address'] = "${smtp_server}"
gitlab_rails['smtp_port'] = ${smtp_port}
gitlab_rails['smtp_user_name'] = "${smtp_user}"
gitlab_rails['smtp_password'] = "${smtp_pass}"
gitlab_rails['smtp_domain'] = "${domain}"
gitlab_rails['smtp_authentication'] = "login"
gitlab_rails['smtp_enable_starttls_auto'] = true
EOF
    fi

    sudo gitlab-ctl reconfigure
    success "GitLab configurado"
}

configure_gitlab_backup() {
    if [[ $setup_backup =~ ^[Yy]$ ]]; then
        info "Configurando backup automático..."
        sudo mkdir -p "${backup_path}"
        sudo chown -R git:git "${backup_path}"

        sudo sed -i "s|^# gitlab_rails\['backup_path'\].*|gitlab_rails['backup_path'] = '${backup_path}'|" "${GITLAB_CONFIG_DIR}/gitlab.rb"
        sudo gitlab-ctl reconfigure

        sudo tee /etc/cron.d/gitlab-backup >/dev/null <<EOF
0 2 * * * git /opt/gitlab/bin/gitlab-backup create CRON=1 GZIP_RSYNCABLE=yes
0 3 * * * root find ${backup_path} -type f -mtime +${backup_retention} -delete
EOF

        sudo systemctl restart cron
        success "Backup diário às 2h configurado com retenção de ${backup_retention} dias"
    fi
}

main() {
    check_privileges
    check_production_requirements
    check_network_production
    check_existing_services
    get_production_config
    optimize_system
    install_dependencies
    install_gitlab
    configure_gitlab_production
    configure_gitlab_backup

    success "✅ GitLab CE instalado com sucesso!"
    info "🔗 Acesse: ${EXTERNAL_URL}"
    info "🔑 Senha inicial: sudo cat /etc/gitlab/initial_root_password"
    info "🗃️ Backups: ${backup_path:-/var/opt/gitlab/backups}"
    info "📄 Log da instalação: ${LOG_FILE}"
}

main "$@"
