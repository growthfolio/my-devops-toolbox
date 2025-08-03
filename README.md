# 🧰 My DevOps Toolbox - Ferramentas e Automações

## 🎯 Objetivo de Aprendizado
Coleção de ferramentas e scripts desenvolvidos para estudar **DevOps practices** e **automação de infraestrutura**. Inclui configurações para **CI/CD**, **containerização**, **monitoramento** e **deployment**, aplicando as melhores práticas de DevOps e SRE.

## 🛠️ Tecnologias Utilizadas
- **Containerização:** Docker, Docker Compose
- **Orquestração:** Kubernetes, Helm
- **CI/CD:** GitHub Actions, GitLab CI, Jenkins
- **Infraestrutura:** Terraform, Ansible
- **Monitoramento:** Prometheus, Grafana, ELK Stack
- **Cloud:** AWS, GCP, Azure

## 🚀 Demonstração
```bash
# Estrutura da toolbox
my-devops-toolbox/
├── docker/                    # Containers e compose files
├── kubernetes/                # Manifests e Helm charts
├── ci-cd/                     # Pipelines e workflows
├── monitoring/                # Configurações de observabilidade
├── infrastructure/            # IaC com Terraform
├── scripts/                   # Automações e utilitários
└── gitlab/                    # Configurações GitLab específicas
```

## 📁 Componentes Principais

### 🐳 **Docker & Containerização**
- Dockerfiles otimizados
- Multi-stage builds
- Docker Compose para desenvolvimento
- Registry management
- Security scanning

### ☸️ **Kubernetes & Orquestração**
- Deployment manifests
- Service configurations
- Ingress controllers
- Helm charts
- Resource management

### 🔄 **CI/CD Pipelines**
- GitHub Actions workflows
- GitLab CI configurations
- Jenkins pipelines
- Automated testing
- Deployment strategies

### 📊 **Monitoring & Observability**
- Prometheus configurations
- Grafana dashboards
- Log aggregation
- Alerting rules
- SLI/SLO definitions

## 💡 Principais Aprendizados

### 🏗️ Infrastructure as Code
- **Terraform:** Provisionamento declarativo
- **Ansible:** Configuração e automação
- **Version control:** Versionamento de infraestrutura
- **State management:** Gerenciamento de estado
- **Modularização:** Componentes reutilizáveis

### 🔄 CI/CD Best Practices
- **Pipeline design:** Fluxos eficientes de deploy
- **Testing automation:** Testes automatizados
- **Security scanning:** Análise de vulnerabilidades
- **Artifact management:** Gestão de artefatos
- **Rollback strategies:** Estratégias de reversão

### 📈 Observability & Monitoring
- **Metrics collection:** Coleta de métricas
- **Log aggregation:** Centralização de logs
- **Distributed tracing:** Rastreamento distribuído
- **Alerting:** Sistemas de alerta inteligentes
- **SRE practices:** Práticas de Site Reliability

## 🧠 Conceitos Técnicos Estudados

### 1. **Docker Multi-stage Build**
```dockerfile
# Build stage
FROM golang:1.19-alpine AS builder
WORKDIR /app
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -o main .

# Production stage
FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 8080
CMD ["./main"]
```

### 2. **Kubernetes Deployment**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
      - name: myapp
        image: myapp:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

### 3. **GitHub Actions Workflow**
```yaml
name: CI/CD Pipeline
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Setup Go
      uses: actions/setup-go@v2
      with:
        go-version: 1.19
    - name: Run tests
      run: go test ./...
    
  deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
    - name: Deploy to production
      run: |
        docker build -t myapp:${{ github.sha }} .
        docker push myapp:${{ github.sha }}
```

## 🚧 Desafios Enfrentados
1. **Complexity management:** Gerenciamento de configurações complexas
2. **Security:** Implementação de práticas seguras
3. **Scalability:** Soluções que escalam com demanda
4. **Cost optimization:** Otimização de custos de infraestrutura
5. **Team collaboration:** Ferramentas para colaboração eficiente

## 📚 Recursos Utilizados
- [The DevOps Handbook](https://itrevolution.com/the-devops-handbook/)
- [Site Reliability Engineering](https://sre.google/books/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Docker Best Practices](https://docs.docker.com/develop/best-practices/)

## 📈 Próximos Passos
- [ ] Implementar GitOps com ArgoCD
- [ ] Adicionar service mesh (Istio)
- [ ] Criar templates Terraform modulares
- [ ] Implementar chaos engineering
- [ ] Adicionar security scanning automatizado
- [ ] Criar dashboards de business metrics

## 🔗 Projetos Relacionados
- [Dev Cloud Challenge](../dev-cloud-challenge/) - Deploy em nuvem
- [Go PriceGuard API](../go-priceguard-api/) - Aplicação containerizada
- [AMQP Transactions MS](../amqp-transactions-ms/) - Microserviços

---

**Desenvolvido por:** Felipe Macedo  
**Contato:** contato.dev.macedo@gmail.com  
**GitHub:** [FelipeMacedo](https://github.com/felipemacedo1)  
**LinkedIn:** [felipemacedo1](https://linkedin.com/in/felipemacedo1)

> 💡 **Reflexão:** Esta toolbox representa a evolução do conhecimento em DevOps e automação. A criação de ferramentas reutilizáveis demonstrou como a padronização e automação impactam positivamente a produtividade e confiabilidade dos sistemas.