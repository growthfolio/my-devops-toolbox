#!/usr/bin/env bash
# GitLab CE installer and management script for Ubuntu Server LTS
# Compatible with 20.04, 22.04, 24.04

set -euo pipefail

LOG_FILE="/var/log/gitlab_installer.log"
REPORT_TXT="gitlab-install-report.txt"
REPORT_HTML="report.html"
SUPPORTED_UBUNTU="20.04 22.04 24.04"

auto_mode=false
DOMAIN=""
HTTP_PORT=80
HTTPS_PORT=443
GIT_DATA_DIR="/var/opt/gitlab/git-data"
ADMIN_EMAIL=""
INSTALL_DURATION=0

#--------------- Utility functions ---------------#
color_green="\033[0;32m"
color_red="\033[0;31m"
color_yellow="\033[1;33m"
color_reset="\033[0m"

log() {
    local msg="$1"
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') : $msg" | tee -a "$LOG_FILE"
}

echo_color() {
    local color="$1"; shift
    echo -e "${color}$*${color_reset}"
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo_color "$color_red" "Este script deve ser executado como root." >&2
        exit 1
    fi
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

#--------------- Environment checks ---------------#
check_environment() {
    echo_color "$color_yellow" "Verificando ambiente..."
    require_root

    if [ ! -f "$LOG_FILE" ]; then
        touch "$LOG_FILE"
    fi

    local ubuntu_version
    # shellcheck source=/dev/null
    ubuntu_version=$(. /etc/os-release && echo "$VERSION_ID")
    log "Versão do Ubuntu detectada: $ubuntu_version"

    if ! [[ " $SUPPORTED_UBUNTU " == *" $ubuntu_version "* ]]; then
        echo_color "$color_red" "Ubuntu $ubuntu_version não é suportado. Versões suportadas: $SUPPORTED_UBUNTU"
        exit 1
    fi

    local disk_mb
    disk_mb=$(df -Pm / | awk 'NR==2 {print $4}')
    local mem_mb
    mem_mb=$(free -m | awk '/Mem:/ {print $2}')
    log "Espaço livre em disco: ${disk_mb}MB"
    log "Memória disponível: ${mem_mb}MB"
    if (( disk_mb < 6000 )); then
        echo_color "$color_red" "Necessário pelo menos 6GB de espaço em disco." >&2
        exit 1
    fi
    if (( mem_mb < 4000 )); then
        echo_color "$color_red" "Necessário pelo menos 4GB de memória." >&2
        exit 1
    fi
    echo_color "$color_green" "Ambiente verificado com sucesso."
}

#--------------- Dependency installation ---------------#
install_dependencies() {
    echo_color "$color_yellow" "Instalando dependências..."
    apt-get update >>"$LOG_FILE" 2>&1
    apt-get install -y curl openssh-server ca-certificates tzdata perl >>"$LOG_FILE" 2>&1
    echo_color "$color_green" "Dependências instaladas."
}

#--------------- Configure GitLab repository ---------------#
configure_repos() {
    echo_color "$color_yellow" "Configurando repositórios do GitLab..."
    curl -fsSL https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | bash >>"$LOG_FILE" 2>&1
    echo_color "$color_green" "Repositório configurado."
}

#--------------- Install GitLab CE ---------------#
install_gitlab_ce() {
    echo_color "$color_yellow" "Instalando GitLab CE..."
    EXTERNAL_URL="http://${DOMAIN}:${HTTP_PORT}"
    apt-get install -y gitlab-ce >>"$LOG_FILE" 2>&1
    echo "external_url '${EXTERNAL_URL}'" > /etc/gitlab/gitlab.rb
    gitlab-ctl reconfigure >>"$LOG_FILE" 2>&1
    echo_color "$color_green" "GitLab instalado."
}

#--------------- Configure GitLab after installation ---------------#
configure_gitlab() {
    echo_color "$color_yellow" "Aplicando configurações personalizadas do GitLab..."
    {
        echo "external_url 'http://${DOMAIN}:${HTTP_PORT}'"
        echo "gitlab_rails['gitlab_email_from'] = '${ADMIN_EMAIL}'"
        echo "git_data_dirs({ \"default\" => { \"path\" => '${GIT_DATA_DIR}' } })"
        echo "nginx['listen_port'] = ${HTTP_PORT}"
        echo "nginx['listen_https'] = ${HTTPS_PORT}"
    } >> /etc/gitlab/gitlab.rb
    gitlab-ctl reconfigure >>"$LOG_FILE" 2>&1
    echo_color "$color_green" "Configurações aplicadas."
}

#--------------- Reports ---------------#
generate_reports() {
    echo_color "$color_yellow" "Gerando relatórios..."
    local version access_url disk_usage mem_usage cpu_usage duration
    version=$(dpkg-query -W -f='${Version}' gitlab-ce 2>/dev/null || echo 'desconhecida')
    access_url="http://${DOMAIN}:${HTTP_PORT}"
    disk_usage=$(df -h / | awk 'NR==2 {print $4}')
    mem_usage=$(free -m | awk '/Mem:/ {print $3"MB usados de "$2"MB"}')
    cpu_usage=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage "%"}')
    duration="${INSTALL_DURATION}s"

    {
        echo "Resumo da Instalação"
        echo "GitLab versão: $version"
        echo "URL de acesso: $access_url"
        echo "Tempo de instalação: $duration"
        echo "Uso de disco: $disk_usage"
        echo "Uso de memória: $mem_usage"
        echo "Uso de CPU: $cpu_usage"
    } > "$REPORT_TXT"

    cat > "$REPORT_HTML" <<HTML
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>GitLab Installation Report</title></head>
<body>
<h1>GitLab Installation Report</h1>
<ul>
<li><strong>Version:</strong> $version</li>
<li><strong>Access URL:</strong> $access_url</li>
<li><strong>Installation Time:</strong> $duration</li>
<li><strong>Disk Usage:</strong> $disk_usage</li>
<li><strong>Memory Usage:</strong> $mem_usage</li>
<li><strong>CPU Usage:</strong> $cpu_usage</li>
</ul>
</body>
</html>
HTML
    echo_color "$color_green" "Relatórios gerados: $REPORT_TXT e $REPORT_HTML"
}

#--------------- GitLab management ---------------#
backup_config() {
    echo_color "$color_yellow" "Realizando backup da configuração..."
    gitlab-ctl backup-etc >>"$LOG_FILE" 2>&1
    echo_color "$color_green" "Backup concluído."
}

update_gitlab() {
    echo_color "$color_yellow" "Atualizando GitLab..."
    {
        apt-get update
        apt-get install -y gitlab-ce
        gitlab-ctl reconfigure
    } >>"$LOG_FILE" 2>&1
    echo_color "$color_green" "GitLab atualizado."
}


restart_services() {
    echo_color "$color_yellow" "Reiniciando serviços do GitLab..."
    gitlab-ctl restart >>"$LOG_FILE" 2>&1
    echo_color "$color_green" "Serviços reiniciados."
}

status_report() {
    echo_color "$color_yellow" "Gerando relatório de status..."
    gitlab-ctl status >>"$LOG_FILE" 2>&1
    df -h >>"$LOG_FILE" 2>&1
    echo_color "$color_green" "Relatório salvo em $LOG_FILE"
}

manage_gitlab() {
    PS3="Selecione uma opção: "
    options=("Backup" "Atualizar" "Reiniciar" "Status" "Voltar")
    select opt in "${options[@]}"; do
        case $opt in
            "Backup") backup_config ;;
            "Atualizar") update_gitlab ;;
            "Reiniciar") restart_services ;;
            "Status") status_report ;;
            "Voltar") break ;;
            *) echo "Opção inválida" ;;
        esac
    done
}


#--------------- Installation flow ---------------#
interactive_config() {
    read -rp "Domínio ou host [$(hostname -f)]: " DOMAIN
    DOMAIN=${DOMAIN:-$(hostname -f)}
    read -rp "Porta HTTP [80]: " HTTP_PORT
    HTTP_PORT=${HTTP_PORT:-80}
    read -rp "Porta HTTPS [443]: " HTTPS_PORT
    HTTPS_PORT=${HTTPS_PORT:-443}
    read -rp "Diretório de armazenamento [/var/opt/gitlab/git-data]: " GIT_DATA_DIR
    GIT_DATA_DIR=${GIT_DATA_DIR:-/var/opt/gitlab/git-data}
    read -rp "Email do admin inicial [admin@example.com]: " ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}
}

auto_defaults() {
    DOMAIN=${DOMAIN:-$(hostname -f)}
    ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}
}

install_flow() {
    local start end
    start=$(date +%s)
    check_environment
    install_dependencies
    configure_repos
    install_gitlab_ce
    configure_gitlab
    end=$(date +%s)
    INSTALL_DURATION=$((end - start))
    generate_reports
}


#--------------- Command line parsing ---------------#
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto) auto_mode=true; shift ;;
        --domain) DOMAIN=$2; shift 2 ;;
        --email) ADMIN_EMAIL=$2; shift 2 ;;
        --http-port) HTTP_PORT=$2; shift 2 ;;
        --https-port) HTTPS_PORT=$2; shift 2 ;;
        --storage) GIT_DATA_DIR=$2; shift 2 ;;
        *) echo "Opção desconhecida $1"; exit 1 ;;
    esac
done

main_menu() {
    PS3="Escolha uma opção: "
    options=("Instalar GitLab" "Gerenciar GitLab" "Gerar Relatórios" "Sair")
    select opt in "${options[@]}"; do
        case $opt in
            "Instalar GitLab")
                if $auto_mode; then auto_defaults; else interactive_config; fi
                install_flow ;;
            "Gerenciar GitLab") manage_gitlab ;;
            "Gerar Relatórios") generate_reports ;;
            "Sair") break ;;
            *) echo "Opção inválida" ;;
        esac
    done
}


if [[ -t 0 ]] && [[ -z "$auto_mode" || $auto_mode = false ]]; then
    main_menu
else
    auto_defaults
    install_flow
fi

