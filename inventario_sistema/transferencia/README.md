# 📦 Sistema de Transferência Inteligente Ubuntu

Conjunto de ferramentas para transferir arquivos entre sistemas Ubuntu de forma inteligente e automatizada, incluindo detecção e acesso automático a partições Windows em dual-boot.

## 🌟 Visão Geral

Este repositório contém duas ferramentas complementares:

1. **🧠 Organizador Inteligente** (`smart_organizer.sh`) - Análise completa e transferência organizada
2. **⚡ Backup Express** (`backup_express.sh`) - Presets rápidos para uso imediato

**Ideal para**: Migração de sistemas, limpeza de dual-boot, backup organizado, transferência em massa.

## 🎯 Casos de Uso

- 📱 **Migrar para notebook novo** - Transferir tudo organizadamente
- 🧹 **Limpar sistema dual-boot** - Backup antes de formatar
- 📁 **Organizar arquivos** - Classificar automaticamente por tipo
- 💾 **Backup inteligente** - Apenas arquivos importantes
- 🔄 **Sincronização seletiva** - Diferentes presets para diferentes necessidades

## 📋 Pré-requisitos

### No Sistema Origem (PC com arquivos)
```bash
# Ferramentas básicas (geralmente já instaladas)
sudo apt install rsync openssh-client findutils coreutils

# Para processamento paralelo (opcional, melhora performance)
sudo apt install parallel
```

### No Sistema Destino (Notebook)
```bash
# SSH Server para receber arquivos
sudo apt install openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh

# Verificar IP do notebook
ip addr show | grep "inet " | grep -v 127.0.0.1
# Anote o IP para configurar no PC
```

### Configuração SSH (Recomendado)
```bash
# No PC origem, configurar acesso sem senha
ssh-keygen -t rsa -b 4096 -C "transferencia_arquivos"
ssh-copy-id usuario@IP_DO_NOTEBOOK

# Testar conexão
ssh usuario@IP_DO_NOTEBOOK "echo 'Conexão OK'"
```

## 🚀 Instalação

```bash
# Clonar repositório
git clone https://github.com/growthfolio/my-devops-toolbox.git
cd my-devops-toolbox/inventario_sistema/transferencia

# Dar permissões de execução
chmod +x smart_organizer.sh backup_express.sh

# Verificar se tudo está funcionando
./backup_express.sh --help
```

## ⚡ Guia Rápido - Backup Express

### Configuração Inicial (1 minuto)

Edite o arquivo `backup_express.sh` e altere apenas estas 3 linhas:

```bash
# Abrir editor
nano backup_express.sh

# Configurar no topo do arquivo:
REMOTE_IP="192.168.1.100"        # IP do seu notebook (obtido acima)
REMOTE_USER="seu_usuario"        # Seu usuário no notebook
NOTEBOOK_PATH="~/backup_pc"      # Onde salvar no notebook
```

### Execução - Menu Interativo

```bash
./backup_express.sh
```

Você verá:
```
🚀 BACKUP INTELIGENTE EXPRESS
==============================

Destino: usuario@192.168.1.100:~/backup_pc

Escolha o tipo de backup:

1) 📋 ESSENCIAIS      - Documentos e fotos importantes (~15 min)
2) 💻 DESENVOLVIMENTO - Projetos e código fonte (~10 min) 
3) 🎬 MÍDIA          - Fotos, vídeos e música (~30 min)
4) 🧠 COMPLETO       - Tudo organizado automaticamente (~45 min)
5) ⚙️  CUSTOMIZADO    - Configurar manualmente
6) 🪟 SETUP WINDOWS  - Detectar e montar Windows
```

### Execução - Linha de Comando

```bash
# Backup essencial (mais rápido)
./backup_express.sh essentials

# Backup completo (recomendado)
./backup_express.sh complete

# Backup de desenvolvimento
./backup_express.sh dev

# Backup de mídia
./backup_express.sh media

# Ver estatísticas do sistema
./backup_express.sh stats
```

### 📊 Detalhes dos Presets

#### 1️⃣ ESSENCIAIS (~15 minutos)
**O que inclui:**
- 📄 Documentos: PDF, DOC, DOCX, ODT, TXT
- 📸 Fotos: JPG, JPEG, PNG, TIFF
- 🎬 Vídeos pequenos: MP4, AVI (prioritários)
- 🪟 Arquivos importantes do Windows

**Onde busca:**
- `~/Documents`, `~/Desktop`, `~/Downloads`
- Windows: `Users/*/Documents`, `Users/*/Desktop`

#### 2️⃣ DESENVOLVIMENTO (~10 minutos)
**O que inclui:**
- 💻 Código fonte: Python, JavaScript, HTML, CSS, etc.
- 📁 Projetos completos (exceto node_modules, .git)
- ⚙️ Configurações: JSON, YAML, INI

**Onde busca:**
- `~/Projects`, `~/workspace`, `~/dev`, `~/git`, `~/code`

#### 3️⃣ MÍDIA (~30 minutos)
**O que inclui:**
- 📸 Todas as fotos: JPG, PNG, TIFF, RAW
- 🎬 Vídeos: MP4, AVI, MOV, MKV
- 🎵 Música: MP3, FLAC, WAV, OGG

**Onde busca:**
- `~/Pictures`, `~/Videos`, `~/Music`, `~/Downloads`

#### 4️⃣ COMPLETO (~45 minutos) - **RECOMENDADO**
**O que faz:**
- 🧠 **Análise inteligente** de todo o sistema
- 📁 **Organização automática** por tipo no destino
- 📅 **Filtragem por data** (prioriza arquivos recentes)
- 🪟 **Inclusão automática** do Windows
- 📊 **Relatório detalhado** do que foi transferido

**Estrutura criada no destino:**
```
~/backup_pc/
├── documentos/     # PDFs, DOCs, etc.
├── fotos/         # Imagens
├── videos/        # Vídeos
├── musicas/       # Áudio
├── codigo/        # Desenvolvimento
├── desktop/       # Área de trabalho
├── downloads/     # Downloads importantes
└── outros/        # Demais arquivos
```

## 🧠 Guia Completo - Organizador Inteligente

Para casos mais complexos ou quando precisa de controle total:

### Execução Básica

```bash
./smart_organizer.sh
```

### Configuração Avançada

O script apresentará um menu interativo:

```
🚀 ORGANIZADOR INTELIGENTE DE ARQUIVOS
======================================

📡 IP do notebook destino: 192.168.1.100
👤 Usuário no destino [usuario]: 
📁 Diretório base no destino [~/organized_transfer]: 

⚙️  CONFIGURAÇÕES AVANÇADAS
📅 Dias para arquivos recentes [365]: 180
💾 Incluir arquivos do Windows? [Y/n]: Y
🗂️  Organizar por tipo de arquivo? [Y/n]: Y
🔧 Modo teste (não transferir)? [y/N]: n
```

### Variáveis de Ambiente

Para automação, você pode configurar via variáveis:

```bash
# Configuração básica
export REMOTE_IP="192.168.1.100"
export REMOTE_USER="usuario"
export REMOTE_BASE_PATH="~/organized_transfer"

# Configurações avançadas
export RECENT_DAYS="180"              # Considerar arquivos dos últimos 6 meses
export MIN_FILE_SIZE="10240"          # Ignorar arquivos < 10KB
export MAX_FILE_SIZE="2147483648"     # Ignorar arquivos > 2GB
export BACKUP_WINDOWS="true"          # Incluir Windows
export ORGANIZE_BY_TYPE="true"        # Organizar por tipo
export DRY_RUN="false"                # false = transferir, true = apenas simular
export MAX_PARALLEL_JOBS="8"          # Jobs paralelos para hash

# Executar
./smart_organizer.sh
```

### Relatórios Gerados

O Organizador Inteligente gera relatórios detalhados:

```
transfer_plan_20250818_143022.txt
===============================================
RELATÓRIO DE DESCOBERTA INTELIGENTE
2025-08-18 14:30:22
===============================================

RESUMO GERAL:
  Total de arquivos: 8,247
  Tamanho total: 23.4GB

POR SISTEMA:
  linux   :   5,891 arquivos (15.2GB)
  windows :   2,356 arquivos (8.2GB)

POR CATEGORIA:
  fotos          :   3,421 arquivos (12.1GB)
  documentos     :   1,247 arquivos (2.3GB)
  videos         :     156 arquivos (5.8GB)
  musicas        :     892 arquivos (1.9GB)
  codigo         :     531 arquivos (245MB)
```

## 🪟 Suporte ao Windows (Dual Boot)

### Detecção Automática

Ambos os scripts detectam automaticamente partições Windows:

1. **Verificam partições montadas** NTFS
2. **Tentam montar automaticamente** partições não montadas
3. **Escaneiam diretórios** `Users/*/Documents`, `Desktop`, etc.
4. **Incluem arquivos importantes** na transferência

### Montagem Manual (se necessário)

```bash
# Listar partições
lsblk -f | grep -i ntfs

# Montar manualmente (substitua sdX1 pela partição correta)
sudo mkdir -p /mnt/windows
sudo mount /dev/sdX1 /mnt/windows

# Verificar se montou
ls /mnt/windows/Users
```

### Executar Setup do Windows

```bash
# Usar o preset específico
./backup_express.sh setup-windows

# Ou no menu interativo, opção 6
./backup_express.sh
```

## 🔧 Configuração Avançada

### Personalização de Filtros

Edite os arrays no `smart_organizer.sh`:

```bash
# Adicionar novos tipos de arquivo
FILE_CATEGORIES["planilhas"]="xls,xlsx,ods,csv,numbers,gnumeric"
FILE_CATEGORIES["ebooks"]="epub,mobi,pdf,djvu,azw3"

# Adicionar novos diretórios Windows
WINDOWS_DIRS+=(
    "/mnt/windows/Users/*/OneDrive"
    "/mnt/windows/ProgramData/Important"
)

# Adicionar novos diretórios Linux
LINUX_DIRS+=(
    "$HOME/.local/share/applications"
    "$HOME/Nextcloud"
)
```

### Otimização de Performance

```bash
# Para SSDs rápidos
export MAX_PARALLEL_JOBS=16

# Para conexões lentas
export MAX_PARALLEL_JOBS=2

# Para redes gigabit
export RSYNC_OPTIONS="-avz --compress-level=3"

# Para WiFi lento
export RSYNC_OPTIONS="-avz --compress-level=9 --bwlimit=10m"
```

### Exclusões Personalizadas

```bash
# No backup_express.sh, editar os comandos rsync:
rsync -avz --progress \
    --exclude='*.iso' --exclude='*.dmg' \
    --exclude='VirtualBox*' --exclude='VMware*' \
    --exclude='*.ova' --exclude='*.vmdk' \
    ~/Documents/ user@host:~/backup/
```

## 📊 Monitoramento e Logs

### Ver Progresso em Tempo Real

```bash
# Em outro terminal, monitorar transferência
watch -n 5 "ssh usuario@IP_NOTEBOOK 'du -sh ~/backup_pc/*'"

# Ver conexões ativas
netstat -an | grep :22

# Monitor de rede
iftop  # ou nload
```

### Logs Detalhados

```bash
# Executar com log detalhado
./smart_organizer.sh 2>&1 | tee transfer.log

# Analisar estatísticas do rsync
grep "speedup" transfer.log
grep "transferred" transfer.log
```

## 🚨 Resolução de Problemas

### Problema: "Conexão recusada"

```bash
# No notebook destino
sudo systemctl status ssh
sudo systemctl start ssh
sudo ufw allow ssh

# Testar conectividade
ping IP_NOTEBOOK
telnet IP_NOTEBOOK 22
```

### Problema: "Partição Windows não encontrada"

```bash
# Listar todas as partições
lsblk -f
sudo fdisk -l

# Montar manualmente
sudo mkdir -p /mnt/windows
sudo mount -t ntfs-3g /dev/sdX1 /mnt/windows

# Verificar se é Windows
ls /mnt/windows/Users 2>/dev/null && echo "Windows encontrado"
```

### Problema: "Sem espaço no destino"

```bash
# Verificar espaço no destino
ssh usuario@IP_NOTEBOOK "df -h"

# Limpar espaço se necessário
ssh usuario@IP_NOTEBOOK "sudo apt autoremove && sudo apt autoclean"

# Usar compressão máxima
export RSYNC_OPTIONS="-avz --compress-level=9"
```

### Problema: "Transferência muito lenta"

```bash
# Usar cabo ethernet em vez de WiFi
# Reduzir paralelismo
export MAX_PARALLEL_JOBS=2

# Desabilitar compressão se CPU for gargalo
export RSYNC_OPTIONS="-av"

# Limitar largura de banda se necessário
export RSYNC_OPTIONS="-avz --bwlimit=50m"
```

### Problema: "Muitos arquivos duplicados"

```bash
# Usar o organizador inteligente com hash
export DO_HASH="1"
./smart_organizer.sh

# Ver relatório de duplicados
cat ~/organized_transfer_*/duplicados.txt
```

## 📈 Otimizações de Performance

### Para Redes Rápidas (Gigabit+)
```bash
# Configuração otimizada
export MAX_PARALLEL_JOBS=8
export RSYNC_OPTIONS="-avz --compress-level=1 --whole-file"
```

### Para Muitos Arquivos Pequenos
```bash
# Usar compressão tar
tar -czf - ~/Documents | ssh user@host "cd ~/backup && tar -xzf -"
```

### Para Arquivos Grandes
```bash
# Usar rsync com progresso
rsync -avz --progress --partial ~/Videos/ user@host:~/backup/videos/
```

## 🔄 Automação e Agendamento

### Crontab para Backup Automático
```bash
# Editar crontab
crontab -e

# Backup semanal aos domingos 2h
0 2 * * 0 /path/to/backup_express.sh essentials

# Backup mensal completo
0 3 1 * * /path/to/backup_express.sh complete
```

### Script Wrapper para Automação
```bash
#!/bin/bash
# auto_backup.sh

# Configurar variáveis
export REMOTE_IP="192.168.1.100"
export REMOTE_USER="usuario"
export NOTEBOOK_PATH="~/auto_backup_$(date +%Y%m%d)"

# Executar backup
/path/to/backup_express.sh complete

# Enviar notificação
echo "Backup concluído em $(date)" | mail -s "Backup OK" user@email.com
```

## 📚 Exemplos Práticos

### Cenário 1: Migração Completa para Notebook Novo
```bash
# 1. Preparar notebook
ssh usuario@192.168.1.100 "mkdir -p ~/migração_completa"

# 2. Configurar e executar
export REMOTE_IP="192.168.1.100"
export REMOTE_USER="usuario"
export NOTEBOOK_PATH="~/migração_completa"
./backup_express.sh complete

# 3. Verificar resultado
ssh usuario@192.168.1.100 "du -sh ~/migração_completa/*"
```

### Cenário 2: Backup Antes de Formatar Dual Boot
```bash
# Backup completo incluindo Windows
export BACKUP_WINDOWS="true"
export REMOTE_BASE_PATH="~/backup_pre_format"
./smart_organizer.sh

# Verificar se pegou tudo importante
ssh usuario@host "find ~/backup_pre_format -name '*.pdf' | wc -l"
```

### Cenário 3: Sincronização de Desenvolvimento
```bash
# Apenas projetos de código
./backup_express.sh dev

# Ou configurar sync contínuo
while true; do
    rsync -avz --delete ~/Projects/ user@host:~/sync_projects/
    sleep 300  # 5 minutos
done
```

### Cenário 4: Backup Seletivo por Data
```bash
# Arquivos dos últimos 30 dias
export RECENT_DAYS="30"
export MIN_FILE_SIZE="1024"
./smart_organizer.sh
```

## 📋 Checklist Pré-Transferência

- [ ] SSH configurado no destino
- [ ] Chaves SSH copiadas (sem senha)
- [ ] Espaço suficiente no destino
- [ ] Rede estável (cabo ethernet recomendado)
- [ ] Windows montado (se dual boot)
- [ ] Backup teste com poucos arquivos
- [ ] Scripts com permissão de execução

## 🆘 Suporte

- **Issues**: [GitHub Issues](https://github.com/growthfolio/my-devops-toolbox/issues)
- **Documentação**: [Wiki do Projeto](https://github.com/growthfolio/my-devops-toolbox/wiki)
- **Exemplos**: [Pasta examples/](./examples/)

## 📄 Licença

MIT License - veja [LICENSE](../../../LICENSE) para detalhes.

---

**💡 Dica Final**: Para primeira vez, sempre use o **Backup Express** no modo **COMPLETO**. É a forma mais segura e organizada de transferir tudo importante automaticamente!

**⚠️ Importante**: Sempre teste primeiro com poucos arquivos para validar que tudo está funcionando corretamente.
