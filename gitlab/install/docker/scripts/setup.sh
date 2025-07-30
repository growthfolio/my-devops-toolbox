#!/bin/bash

#==============================================================================
# GitLab Docker Setup Script
# Prepara ambiente para execução do GitLab via Docker Compose
#==============================================================================

set -euo pipefail

# Cores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

info() { echo -e "${BLUE}ℹ️  $*${NC}"; }
success() { echo -e "${GREEN}✅ $*${NC}"; }
warning() { echo -e "${YELLOW}⚠️  $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}"; }

#==============================================================================
# VERIFICAÇÕES
#==============================================================================

check_requirements() {
    info "Verificando pré-requisitos..."
    
    # Docker
    if ! command -v docker >/dev/null; then
        error "Docker não está instalado"
        exit 1
    fi
    
    # Docker Compose
    if ! docker compose version >/dev/null 2>&1; then
        error "Docker Compose v2 não está disponível"
        exit 1
    fi
    
    # Recursos do sistema
    local ram_gb=$(awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo)
    if [[ $ram_gb -lt 8 ]]; then
        warning "RAM recomendada: 8GB+. Atual: ${ram_gb}GB"
    fi
    
    local disk_gb=$(df . | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $disk_gb -lt 50 ]]; then
        warning "Espaço em disco recomendado: 50GB+. Disponível: ${disk_gb}GB"
    fi
    
    success "Pré-requisitos verificados"
}

#==============================================================================
# CONFIGURAÇÃO DO AMBIENTE
#==============================================================================

create_directories() {
    info "Criando estrutura de diretórios..."
    
    local dirs=(
        "volumes/gitlab/config"
        "volumes/gitlab/logs"
        "volumes/gitlab/data"
        "volumes/gitlab/backups"
        "volumes/gitlab-runner/config"
        "volumes/nginx/logs"
        "volumes/postgres/data"
        "config/nginx"
        "config/nginx/ssl"
        "scripts"
        "backups"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        info "Criado: $dir"
    done
    
    # Permissões especiais para GitLab
    sudo chown -R 998:998 volumes/gitlab/ 2>/dev/null || true
    
    success "Estrutura de diretórios criada"
}

create_env_file() {
    if [[ ! -f .env ]]; then
        info "Criando arquivo .env..."
        
        # Gerar senhas seguras
        local postgres_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        local runner_token=$(openssl rand -hex 16)
        
        cat > .env <<EOF
# GitLab Docker Compose Environment
# Gerado automaticamente em $(date)

# Versões
GITLAB_VERSION=16.11.1-ce.0
RUNNER_VERSION=v16.11.0

# URLs e Hostname
GITLAB_HOSTNAME=gitlab.local
GITLAB_EXTERNAL_URL=http://localhost:8080
REGISTRY_EXTERNAL_URL=http://localhost:5005

# Portas
GITLAB_HTTP_PORT=8080
GITLAB_HTTPS_PORT=8443
GITLAB_SSH_PORT=2222

# Database
POSTGRES_DB=gitlabhq_production
POSTGRES_USER=gitlab
POSTGRES_PASSWORD=${postgres_password}

# Recursos
GITLAB_MEMORY_LIMIT=6G
GITLAB_CPU_LIMIT=2.0
GITLAB_MEMORY_RESERVATION=4G
GITLAB_CPU_RESERVATION=1.0

# Funcionalidades
EMAIL_ENABLED=false
SMTP_ENABLED=false
REGISTRY_ENABLED=false
PAGES_ENABLED=false
GRAFANA_ENABLED=false

# Runner
RUNNER_REGISTRATION_TOKEN=${runner_token}
RUNNER_NAME=docker-runner-dev
RUNNER_EXECUTOR=docker

# Sistema
TZ=America/Sao_Paulo
COMPOSE_PROFILES=
EOF
        
        success "Arquivo .env criado com senhas seguras"
        warning "Edite o arquivo .env conforme necessário"
    else
        info "Arquivo .env já existe"
    fi
}

create_config_files() {
    info "Criando arquivos de configuração..."
    
    # Nginx config
    cat > config/nginx/nginx.conf <<'EOF'
events {
    worker_connections 1024;
}

http {
    upstream gitlab {
        server gitlab-ce:80;
    }
    
    server {
        listen 80;
        server_name _;
        
        location / {
            proxy_pass http://gitlab;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF
    
    # Redis config
    cat > config/redis.conf <<'EOF'
# Redis Configuration for GitLab
maxmemory 512mb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
appendonly yes
appendfsync everysec
tcp-keepalive 60
timeout 300
EOF
    
    # PostgreSQL init script
    cat > scripts/postgres-init.sql <<'EOF'
-- GitLab PostgreSQL Initialization
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;
EOF
    
    success "Arquivos de configuração criados"
}

    # Script de backup
    cat > scripts/backup.sh <<'EOF'
#!/bin/bash
# GitLab Docker Backup Script

set -euo pipefail

BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "Iniciando backup GitLab Docker..."

# Criar backup dos dados GitLab
docker compose exec -T gitlab gitlab-backup create CRON=1

# Copiar backup do container
docker compose cp gitlab:/var/opt/gitlab/backups/. "$BACKUP_DIR/"

# Backup da configuração
docker compose exec -T gitlab tar czf /tmp/gitlab-config-$TIMESTAMP.tar.gz -C /etc/gitlab .
docker compose cp gitlab:/tmp/gitlab-config-$TIMESTAMP.tar.gz "$BACKUP_DIR/"

# Backup dos segredos
docker compose exec -T gitlab tar czf /tmp/gitlab-secrets-$TIMESTAMP.tar.gz -C /etc/gitlab gitlab-secrets.json
docker compose cp gitlab:/tmp/gitlab-secrets-$TIMESTAMP.tar.gz "$BACKUP_DIR/"

# Limpeza
docker compose exec -T gitlab rm -f /tmp/gitlab-*-$TIMESTAMP.tar.gz

echo "Backup concluído: $BACKUP_DIR/"
EOF
    
    # Script de restore
    cat > scripts/restore.sh <<'EOF'
#!/bin/bash
# GitLab Docker Restore Script

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Uso: $0 <timestamp_backup>"
    exit 1
fi

TIMESTAMP="$1"
BACKUP_DIR="./backups"

echo "⚠️  Esta operação irá sobrescrever os dados atuais!"
read -p "Digite 'CONFIRMO' para continuar: " confirm

if [[ "$confirm" != "CONFIRMO" ]]; then
    echo "Operação cancelada"
    exit 1
fi

echo "Parando serviços..."
docker compose stop gitlab

echo "Restaurando backup..."
docker compose start gitlab-postgresql gitlab-redis
sleep 30

# Copiar arquivos de backup
docker compose cp "$BACKUP_DIR/gitlab-config-$TIMESTAMP.tar.gz" gitlab:/tmp/
docker compose cp "$BACKUP_DIR/gitlab-secrets-$TIMESTAMP.tar.gz" gitlab:/tmp/

# Restaurar configuração
docker compose exec gitlab tar xzf /tmp/gitlab-config-$TIMESTAMP.tar.gz -C /etc/gitlab/
docker compose exec gitlab tar xzf /tmp/gitlab-secrets-$TIMESTAMP.tar.gz -C /etc/gitlab/

# Iniciar GitLab
docker compose start gitlab

echo "Aguardando GitLab inicializar..."
sleep 60

# Restaurar dados
docker compose exec gitlab gitlab-backup restore BACKUP="$TIMESTAMP" force=yes

echo "Restore concluído!"
EOF
    
    # Script de monitoramento
    cat > scripts/health-check.sh <<'EOF'
#!/bin/bash
# GitLab Docker Health Check

check_service() {
    local service="$1"
    if docker compose ps --services --filter "status=running" | grep -q "^$service$"; then
        echo "✅ $service: Running"
        return 0
    else
        echo "❌ $service: Not running"
        return 1
    fi
}

echo "=== GitLab Docker Health Check ==="
echo "Data: $(date)"
echo

status=0

check_service "gitlab-postgresql" || status=1
check_service "gitlab-redis" || status=1
check_service "gitlab" || status=1

# Verificar conectividade web
if curl -sf http://localhost:8080 >/dev/null 2>&1; then
    echo "✅ Web: Accessible"
else
    echo "❌ Web: Not accessible"
    status=1
fi

# Verificar uso de recursos
echo
echo "=== Resource Usage ==="
docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"

echo
if [[ $status -eq 0 ]]; then
    echo "✅ All systems operational"
else
    echo "❌ Issues detected"
fi

exit $status
EOF
    
    # Script de runner
    cat > scripts/runner-register.sh <<'EOF'
#!/bin/bash
# GitLab Runner Registration Script

if [[ -z "${GITLAB_URL:-}" || -z "${REGISTRATION_TOKEN:-}" ]]; then
    echo "GITLAB_URL e REGISTRATION_TOKEN são obrigatórios"
    exit 1
fi

gitlab-runner register \
    --non-interactive \
    --url "${GITLAB_URL}" \
    --registration-token "${REGISTRATION_TOKEN}" \
    --executor "${RUNNER_EXECUTOR:-docker}" \
    --docker-image "alpine:latest" \
    --description "${RUNNER_NAME:-docker-runner}" \
    --tag-list "docker,linux" \
    --run-untagged="true" \
    --locked="false" \
    --access-level="not_protected"
EOF
    
    # Tornar scripts executáveis
    chmod +x scripts/*.sh
    
    success "Scripts utilitários criados"
}

#==============================================================================
# EXECUÇÃO PRINCIPAL
#==============================================================================

main() {
    echo "======================================================================"
    echo "🐳 GitLab Docker Compose - Setup Profissional"
    echo "======================================================================"
    echo
    
    check_requirements
    create_directories
    create_env_file
    create_config_files
    create_scripts
    
    echo
    success "Setup concluído com sucesso!"
    echo
    info "Próximos passos:"
    info "1. Edite o arquivo .env conforme necessário"
    info "2. Execute: docker compose up -d"
    info "3. Aguarde alguns minutos para inicialização"
    info "4. Acesse: http://localhost:8080"
    echo
    info "Scripts disponíveis:"
    info "• ./scripts/backup.sh - Backup completo"
    info "• ./scripts/restore.sh <timestamp> - Restaurar backup"
    info "• ./scripts/health-check.sh - Verificar status"
    echo
    warning "Primeira execução pode demorar 10-15 minutos"
    echo "======================================================================"
}

main "$@"