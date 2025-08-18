# 📁 Sistema de Inventário de Arquivos

Um script bash robusto e eficiente para catalogar, analisar e auditar sistemas de arquivos Linux/Unix. Gera relatórios detalhados sobre arquivos, diretórios, duplicatas, permissões e muito mais.

## 🌟 Características Principais

- **🔍 Análise Abrangente**: Catalogação completa de arquivos e diretórios
- **⚡ Performance Otimizada**: Processamento paralelo e filtros inteligentes
- **🛡️ Auditoria de Segurança**: Detecção de permissões perigosas e arquivos SUID/SGID
- **📊 Relatórios Ricos**: Estatísticas detalhadas, análise por extensão e tamanho
- **🎯 Detecção de Duplicatas**: Hash MD5 paralelo com controle de recursos
- **⚙️ Altamente Configurável**: Múltiplas opções de personalização
- **📝 Logging Estruturado**: Sistema de logs com diferentes níveis

## 📋 Pré-requisitos

### Obrigatórios
```bash
find stat awk sort head wc date mkdir
```

### Opcionais (para funcionalidades avançadas)
```bash
# Para processamento paralelo de hashes
sudo apt install parallel    # Ubuntu/Debian
sudo yum install parallel    # CentOS/RHEL
brew install parallel        # macOS

# Para formatação de números (geralmente já incluso)
numfmt
```

## 🚀 Instalação Rápida

```bash
# Download do script
curl -O https://exemplo.com/inventario.sh
chmod +x inventario.sh

# Ou clone o repositório
git clone https://repo.com/inventario-sistema
cd inventario-sistema
chmod +x inventario.sh
```

## 📖 Guia de Uso

### Execução Básica

```bash
# Inventário da home do usuário atual
./inventario.sh

# Sistema completo (requer sudo)
MODE=FULL_SYSTEM ./inventario.sh
```

### Configurações Principais

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `MODE` | `HOME_ONLY` | `HOME_ONLY` ou `FULL_SYSTEM` |
| `DO_HASH` | `0` | `1` para detectar duplicatas via hash |
| `RECENT_DAYS` | `14` | Definir "arquivos recentes" (dias) |
| `MAX_DEPTH` | `0` | Profundidade máxima (0 = ilimitado) |
| `MIN_SIZE_HASH` | `1048576` | Tamanho mínimo para hash (bytes) |
| `PARALLEL_JOBS` | `4` | Jobs paralelos para hashing |
| `EXCLUDE_PATTERNS` | `*.tmp,*.swp,*~,*.bak` | Padrões para ignorar |
| `LOG_LEVEL` | `INFO` | `DEBUG`, `INFO`, `WARN`, `ERROR` |

## 🎛️ Exemplos Práticos

### Cenário 1: Auditoria Rápida da Home
```bash
# Análise básica sem hash de duplicatas
./inventario.sh
```

### Cenário 2: Limpeza de Sistema Completo
```bash
# Sistema completo com detecção de duplicatas
sudo MODE=FULL_SYSTEM DO_HASH=1 PARALLEL_JOBS=8 ./inventario.sh
```

### Cenário 3: Análise de Projeto
```bash
# Análise limitada em profundidade, excluindo node_modules
MAX_DEPTH=3 \
EXCLUDE_PATTERNS="node_modules,*.log,*.cache" \
RECENT_DAYS=30 \
./inventario.sh
```

### Cenário 4: Auditoria de Segurança
```bash
# Foco em segurança com logs detalhados
MODE=FULL_SYSTEM \
LOG_LEVEL=DEBUG \
EXCLUDE_PATTERNS="" \
./inventario.sh
```

### Cenário 5: Detecção Agressiva de Duplicatas
```bash
# Hash de arquivos pequenos também (>10KB)
DO_HASH=1 \
MIN_SIZE_HASH=10240 \
PARALLEL_JOBS=12 \
./inventario.sh
```

## 📊 Relatórios Gerados

### 📁 Estrutura de Saída
```
inventario_20250818_143022/
├── RESUMO.txt                 # ← COMECE AQUI
├── arquivos.tsv              # Listagem completa de arquivos
├── diretorios.tsv            # Listagem completa de diretórios  
├── arvore_n3.txt             # Estrutura visual (3 níveis)
├── maiores_arquivos.txt      # Top 100 maiores arquivos
├── por_extensao.tsv          # Análise por tipo de arquivo
├── por_tamanho.tsv           # Análise por faixas de tamanho
├── recentes_14d.txt          # Arquivos modificados recentemente
├── symlinks_quebrados.txt    # Links simbólicos inválidos
├── world_writable.txt        # Arquivos com permissões perigosas
├── suid_sgid.txt             # Arquivos SUID/SGID
├── hashes.tsv                # Hashes MD5 (se DO_HASH=1)
└── duplicados.txt            # Duplicatas encontradas
```

### 📋 Detalhes dos Relatórios

#### `RESUMO.txt` - Visão Geral
```
===============================================
RESUMO DO INVENTÁRIO - 20250818_143022
===============================================

CONFIGURAÇÃO:
  Escopo              : HOME_ONLY
  Profundidade máxima : ilimitada
  Padrões excluídos   : *.tmp,*.swp,*~,*.bak
  Hash de duplicados  : 1
  Tamanho mín. p/hash : 1.0MB

ESTATÍSTICAS:
  Total de arquivos   : 12,847
  Total de diretórios : 1,293
  Tamanho total       : 45.2GB
  Maior arquivo       : /home/user/video.mkv (2.1GB)
  Ext. mais comum     : jpg
  Arquivos recentes   : 156 (últimos 14 dias)
```

#### `arquivos.tsv` - Dados Completos
```
path    size_bytes    mtime    atime    mode    user    group    inode    links
/home/user/doc.pdf    2048576    2025-08-15 10:30:00    2025-08-18 09:15:23    -rw-r--r--    user    user    524234    1
```

#### `por_extensao.tsv` - Análise por Tipo
```
ext    count    total_bytes    avg_bytes    min_bytes    max_bytes
jpg    1247     125830394      100900       1024         2048576
pdf    89       45923847       515998       10240        5242880
```

#### `duplicados.txt` - Arquivos Duplicados
```
=== HASH 5d41402abc4b2a76b9719d911017c592 (3 arquivos, 2048576 bytes cada) ===
/home/user/Documents/backup/file.pdf
/home/user/Downloads/file.pdf
/home/user/Desktop/file.pdf

TOTAL: 156 arquivos duplicados
ESPAÇO DESPERDIÇADO: 2.3GB
```

## 🔧 Configuração Avançada

### Personalização de Exclusões
```bash
# Excluir diretórios específicos para desenvolvimento
EXCLUDE_PATTERNS="node_modules,vendor,*.pyc,__pycache__,target,.git"

# Excluir apenas temporários
EXCLUDE_PATTERNS="*.tmp,*.swp,*.bak"

# Não excluir nada
EXCLUDE_PATTERNS=""
```

### Otimização de Performance
```bash
# Para SSDs rápidos - mais jobs paralelos
PARALLEL_JOBS=16

# Para HDDs ou sistemas limitados
PARALLEL_JOBS=2

# Hash apenas arquivos grandes (>10MB)
MIN_SIZE_HASH=10485760

# Hash mais agressivo (>100KB)
MIN_SIZE_HASH=102400
```

### Configuração de Logs
```bash
# Debug completo
LOG_LEVEL=DEBUG ./inventario.sh 2>&1 | tee inventario.log

# Apenas erros
LOG_LEVEL=ERROR ./inventario.sh

# Silencioso (apenas output final)
LOG_LEVEL=ERROR ./inventario.sh 2>/dev/null
```

## 🛠️ Resolução de Problemas

### Problema: "Comando não encontrado"
```bash
# Verificar dependências
which find stat awk sort head

# Instalar ferramentas faltando (Ubuntu/Debian)
sudo apt update
sudo apt install coreutils gawk parallel
```

### Problema: "Permissão negada"
```bash
# Para sistema completo, sempre use sudo
sudo MODE=FULL_SYSTEM ./inventario.sh

# Para análise da home, verifique permissões
ls -la ~/
```

### Problema: Script muito lento
```bash
# Limitar profundidade
MAX_DEPTH=5 ./inventario.sh

# Desabilitar hash de duplicatas
DO_HASH=0 ./inventario.sh

# Aumentar exclusões
EXCLUDE_PATTERNS="*.cache,*.tmp,node_modules,*.log" ./inventario.sh
```

### Problema: Sem espaço em disco
```bash
# Verificar espaço disponível
df -h ~/

# Usar diretório temporário alternativo
TMPDIR=/outro/local ./inventario.sh
```

## ⚠️ Considerações de Segurança

### Modo FULL_SYSTEM
- **Requer sudo**: Acesso de administrador necessário
- **Dados sensíveis**: Pode catalogar arquivos confidenciais
- **Performance**: Pode impactar sistema em produção

### Proteção de Dados
```bash
# Limitar saída para usuário atual apenas
chmod 700 ~/inventario_*

# Excluir diretórios sensíveis
EXCLUDE_PATTERNS="*.key,*.pem,wallet.dat,.ssh,.gnupg"
```

## 📈 Interpretação dos Resultados

### Identificar Oportunidades de Limpeza

1. **Arquivos Grandes**: Verifique `maiores_arquivos.txt`
2. **Duplicatas**: Analise `duplicados.txt` para economizar espaço
3. **Arquivos Antigos**: Compare datas em `arquivos.tsv`
4. **Tipos Inúteis**: Procure extensões como `.tmp`, `.bak` em `por_extensao.tsv`

### Auditoria de Segurança

1. **Permissões Perigosas**: Revise `world_writable.txt`
2. **Arquivos SUID/SGID**: Analise `suid_sgid.txt`
3. **Links Quebrados**: Limpe `symlinks_quebrados.txt`

### Análise de Performance

1. **Fragmentação**: Muitos arquivos pequenos em um diretório
2. **Hotspots**: Diretórios com muitos arquivos (`diretorios.tsv`)
3. **Crescimento**: Compare relatórios ao longo do tempo

## 🔄 Automatização

### Crontab - Inventário Semanal
```bash
# Editar crontab
crontab -e

# Adicionar linha (todo domingo às 2:00)
0 2 * * 0 /path/to/inventario.sh MODE=HOME_ONLY DO_HASH=1
```

### Script Wrapper
```bash
#!/bin/bash
# wrapper_inventario.sh

# Configurações padrão do ambiente
export MODE=HOME_ONLY
export DO_HASH=1
export PARALLEL_JOBS=8
export RECENT_DAYS=30
export LOG_LEVEL=INFO

# Executar inventário
./inventario.sh

# Enviar resumo por email (opcional)
mail -s "Inventário $(date +%Y-%m-%d)" user@email.com < ~/inventario_*/RESUMO.txt
```

## 📚 Casos de Uso Avançados

### 1. Migração de Sistema
```bash
# Antes da migração - catalogar tudo
MODE=FULL_SYSTEM DO_HASH=1 ./inventario.sh
cp -r ~/inventario_* /backup/pre-migration/

# Após migração - comparar
MODE=FULL_SYSTEM DO_HASH=1 ./inventario.sh
# Compare os arquivos .tsv para validar migração
```

### 2. Forense Digital
```bash
# Catalogação completa com timestamps precisos
MODE=FULL_SYSTEM \
LOG_LEVEL=DEBUG \
EXCLUDE_PATTERNS="" \
MAX_DEPTH=0 \
./inventario.sh 2>&1 | tee forense_$(date +%Y%m%d).log
```

### 3. Otimização de Backup
```bash
# Identificar o que realmente precisa de backup
DO_HASH=1 \
MIN_SIZE_HASH=0 \
RECENT_DAYS=90 \
./inventario.sh

# Use duplicados.txt para deduplicar backups
# Use recentes_90d.txt para backup incremental
```

## 🤝 Contribuição

Encontrou um bug ou tem uma sugestão? 

1. **Issues**: Relate problemas ou solicite funcionalidades
2. **Pull Requests**: Contribua com melhorias
3. **Documentação**: Ajude a melhorar este README

## 📄 Licença

MIT License - veja o arquivo LICENSE para detalhes.

## 🆘 Suporte

- **GitHub Issues**: Para bugs e funcionalidades  
- **Wiki**: Documentação adicional e exemplos
- **Discussions**: Perguntas e dicas da comunidade

---

**💡 Dica**: Comece sempre com um inventário básico da sua home (`./inventario.sh`) antes de partir para análises mais complexas!
