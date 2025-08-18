Sim! Abaixo vai um script “inventário” que você roda a partir da sua **home** e ele mapeia **tudo**. Tem dois modos:

* **HOME\_ONLY (padrão):** analisa só sua home (`$HOME`).
* **FULL\_SYSTEM:** analisa o sistema inteiro (pede `sudo`), ignorando pontos sensíveis como `/proc`, `/sys`, etc.

Ele gera uma pasta `~/inventario_<data>` com vários relatórios úteis (TSV/TXT): lista de arquivos e diretórios, maiores arquivos, duplicados (opcional), por extensão, links quebrados, permissões “suspeitas”, arquivos recentes, etc.

---

### 1)

* **Dê permissão de execução:**

```bash
chmod +x inventario_sistema.sh
```

---

### 2) Como executar

* **Só sua home (rápido):**

```bash
./inventario_sistema.sh
```

* **Sistema inteiro (mais completo):**

```bash
MODE=FULL_SYSTEM ./inventario_sistema.sh
```

* **Incluir detecção de duplicados (lento, por hash):**

```bash
DO_HASH=1 ./inventario_sistema.sh
# ou no sistema inteiro:
MODE=FULL_SYSTEM DO_HASH=1 ./inventario_sistema.sh
```

* **Ajustar a janela de “recentes” (ex.: 30 dias):**

```bash
RECENT_DAYS=30 ./inventario_sistema.sh
```

---

### 3) O que você recebe

Na pasta `~/inventario_<data>`:

* `RESUMO.txt` — visão geral e índice.
* `arvore_n3.txt` — árvore superficial (3 níveis).
* `arquivos.tsv` — **todos os arquivos** com: caminho, bytes, mtime, modo, dono, grupo.
* `diretorios.tsv` — **todos os diretórios** com permissões/dono/grupo.
* `maiores_arquivos.txt` — top 100 por tamanho.
* `por_extensao.tsv` — agregação por extensão (contagem e bytes).
* `recentes_<Nd>.txt` — arquivos modificados nos últimos N dias.
* `symlinks_quebrados.txt` — links simbólicos que apontam para nada.
* `world_writable.txt` — caminhos com permissão “world-writable”.
* `hashes.tsv` e `duplicados.txt` (se `DO_HASH=1`) — possíveis duplicatas.

---

Se quiser, eu adapto os **filtros** (excluir `node_modules`, `.git`, vídeos, etc.) ou já deixo um **rsync** em seguida que copia só o que interessa para o notebook com base nesse inventário.
