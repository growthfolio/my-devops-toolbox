# GitLab CE via Docker Compose

## Visão Geral

Este projeto fornece uma configuração completa e profissional do GitLab Community Edition (CE) usando Docker Compose, adequada para ambientes de desenvolvimento, teste e pequenas implementações de produção.

### Principais Características

- **Arquitetura Multi-Container**: PostgreSQL, Redis e GitLab CE
- **Alta Disponibilidade**: Health checks e restart automático
- **Segurança**: Hardening e isolamento de rede
- **Performance**: Otimizações de memória e CPU
- **Backup Automático**: Scripts completos de backup/restore
- **Monitoramento**: Health checks e métricas
- **Escalabilidade**: Perfis para diferentes cenários

## Pré-requisitos

- Docker 20.10+
- Docker Compose v2.0+
- 8GB RAM (mínimo recomendado)
- 50GB de armazenamento livre
- Ubuntu 20.04+ ou sistema compatível

## Instalação Rápida

```bash
# 1. Clonar o repositório
git clone git@github.com:growthfolio/my-devops-toolbox.git my-devops-toolbox
cd my-devops-toolbox/gitlab/install/docker

# 2. Executar o setup inicial
./scripts/setup.sh

# 3. Editar configurações (opcional)
nano .env

# 4. Iniciar serviços
docker compose up -d

# 5. Verificar status dos serviços
./scripts/health-check.sh
```

## Configuração

### Arquivo `.env`

Principais variáveis de configuração:

```env
# URLs e Portas
GITLAB_EXTERNAL_URL=http://localhost:8080
GITLAB_HTTP_PORT=8080
GITLAB_SSH_PORT=2222

# Recursos
GITLAB_MEMORY_LIMIT=6G
GITLAB_CPU_LIMIT=2.0

# Database
POSTGRES_PASSWORD=sua_senha_segura
```

### Perfis Disponíveis (Profiles)

```bash
# Apenas GitLab básico
docker compose up -d

# Com GitLab Runner
docker compose --profile runner up -d

# Com Nginx Proxy
docker compose --profile proxy up -d

# Tudo habilitado
docker compose --profile runner --profile proxy up -d
```

## Operações Comuns

### Backup

```bash
# Backup completo
./scripts/backup.sh
# Backups são salvos em: ./backups/
```

### Restore

```bash
# Listar backups disponíveis
ls -la backups/

# Restaurar backup específico
./scripts/restore.sh <TIMESTAMP>
```

### Monitoramento

```bash
# Status dos serviços
./scripts/health-check.sh

# Logs em tempo real
docker compose logs -f gitlab

# Métricas de recursos
docker stats
```

### Manutenção

```bash
# Parar serviços
docker compose down

# Reiniciar apenas o GitLab
docker compose restart gitlab

# Atualizar imagens
docker compose pull
docker compose up -d
```

## Estrutura de Diretórios

```
gitlab/install/docker/
├── docker-compose-gitlab.yml         # Compose principal
├── docker-compose.override.yml       # Configurações extras
├── .env                             # Variáveis de ambiente
├── scripts/                         # Scripts utilitários
│   ├── setup.sh
│   ├── backup.sh
│   ├── restore.sh
│   └── health-check.sh
└── backups/                         # Backups locais
```

## Segurança

- Rede isolada para containers
- Configurações de segurança hardening
- Senhas geradas automaticamente
- Volumes com permissões adequadas
- Headers de segurança configurados

## Solução de Problemas (Troubleshooting)

### Problemas Comuns

1. **GitLab não inicia**: Verifique recursos disponíveis e logs.
2. **Erro de permissão**: Execute `sudo chown -R 998:998 volumes/gitlab/`.
3. **Porta ocupada**: Altere as portas no arquivo `.env`.
4. **Lentidão**: Aumente recursos no arquivo `.env`.

### Logs Úteis

```bash
# Logs do GitLab
docker compose logs gitlab

# Logs do PostgreSQL
docker compose logs gitlab-postgresql

# Logs do sistema
tail -f volumes/gitlab/logs/gitlab-rails/production.log
```

## Limitações

- Não recomendado para produção de alta escala
- Backup local apenas (sem cloud)
- SSL/TLS básico (recomenda-se Let's Encrypt para produção)

## Suporte

Em caso de problemas:
1. Verifique os logs dos containers
2. Execute o health check
3. Consulte a [documentação oficial do GitLab](https://docs.gitlab.com/ee/install/docker.html)
4. Verifique recursos do sistema

---
Este projeto faz parte do My DevOps Toolbox, uma coleção de soluções práticas e reutilizáveis para ambientes corporativos, laboratórios e aprendizado contínuo.
>  Mantido por: Felipe Macedo — contribuições da comunidade são bem-vindas!


