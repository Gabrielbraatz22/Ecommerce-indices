# Metodologia de Replicação dos Testes
## E-commerce com Controle de Estoque — PostgreSQL Tuning

**Projeto:** Otimização (Tuning) de Consultas em PostgreSQL
**Estudo de Caso:** E-commerce com Controle de Estoque
**Versão:** 1.0 — 22 de maio de 2025

---

## 1. Pré-requisitos

### Software Necessário

| Componente | Versão Mínima | Observação |
|---|---|---|
| PostgreSQL | 14.0+ | Versão 16.x recomendada |
| psql (cliente CLI) | 14.0+ | Incluído na instalação |
| Python | 3.8+ | Para geração de arquivos auxiliares |

### Configuração do postgresql.conf

Antes de iniciar os testes, adicione ao `postgresql.conf`:

```ini
# Habilitar monitoramento de queries (requer reinicialização)
shared_preload_libraries = 'pg_stat_statements'

# Configurações recomendadas para os testes (ajuste para seu hardware)
shared_buffers = 256MB          # 25-40% da RAM
work_mem = 64MB                 # Para operações de sort/hash
effective_cache_size = 4GB      # ~75% da RAM total
```

Após editar, reinicie o PostgreSQL:
```bash
# Linux
sudo systemctl restart postgresql

# Windows (PowerShell como Administrador)
Restart-Service postgresql-x64-16
```

### Configurações Mínimas de Hardware

- **RAM:** 4 GB mínimo (8 GB recomendado para testes com 1M de pedidos)
- **Disco:** 10 GB livres (tabela de movimentações com 1M de pedidos pode chegar a 5+ GB)
- **CPU:** Qualquer processador moderno (tempos absolutos variarão, mas comparativos serão válidos)

---

## 2. Criação do Banco de Dados

Conecte-se ao PostgreSQL e execute:

```bash
psql -U postgres
```

Dentro do psql:

```sql
-- Criar o banco dedicado
CREATE DATABASE ecommerce_tuning;

-- Conectar
\c ecommerce_tuning

-- Habilitar a extensão de monitoramento
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Verificar versão
SELECT version();
```

---

## 3. Passo a Passo de Execução

Execute os scripts na ordem exata abaixo. Todos os comandos assumem que o diretório atual é `projeto_tuning_ecommerce/`.

### Passo 1 — Criar as Tabelas

```bash
psql -U postgres -d ecommerce_tuning -f sql/01_criar_tabelas.sql
```

**Verificação:**
```sql
\c ecommerce_tuning
\dt
-- Deve listar: categorias, clientes, fornecedores, itens_pedido,
--              movimentacoes_estoque, pedidos, produtos
```

### Passo 2 — Popular com 10.000 Pedidos

```bash
psql -U postgres -d ecommerce_tuning -f sql/02_popular_dados.sql
```

**Verificação:**
```sql
SELECT
    'fornecedores'         AS tabela, COUNT(*) FROM fornecedores UNION ALL
    SELECT 'categorias',              COUNT(*) FROM categorias   UNION ALL
    SELECT 'produtos',                COUNT(*) FROM produtos      UNION ALL
    SELECT 'clientes',                COUNT(*) FROM clientes      UNION ALL
    SELECT 'pedidos',                 COUNT(*) FROM pedidos       UNION ALL
    SELECT 'itens_pedido',            COUNT(*) FROM itens_pedido  UNION ALL
    SELECT 'movimentacoes_estoque',   COUNT(*) FROM movimentacoes_estoque;
```

**Tempo estimado:** 1 a 5 minutos dependendo do hardware.

### Passo 3 — Executar Consultas SEM Índices (10.000 pedidos)

```bash
psql -U postgres -d ecommerce_tuning -f sql/04_consultas_sem_indice.sql \
     2>&1 | tee resultados/output_sem_indice_10k.txt
```

**O que registrar na planilha:**
- Tempo reportado pelo `\timing` após cada consulta
- "Execution Time" do `EXPLAIN ANALYZE` de cada consulta
- Tipo de scan utilizado (Seq Scan, Index Scan, etc.)

### Passo 4 — Criar Índices

```bash
psql -U postgres -d ecommerce_tuning -f sql/05_criar_indices.sql
```

**Verificação:**
```sql
SELECT indexname, tablename, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND indexname LIKE 'idx_%'
ORDER BY tablename, indexname;
```

### Passo 5 — Executar Consultas COM Índices (10.000 pedidos)

```bash
psql -U postgres -d ecommerce_tuning -f sql/06_consultas_com_indice.sql \
     2>&1 | tee resultados/output_com_indice_10k.txt
```

### Passo 6 — Repetir para 20.000 Pedidos

Limpar dados e repopular:

```bash
psql -U postgres -d ecommerce_tuning -c "
TRUNCATE movimentacoes_estoque, itens_pedido, pedidos, clientes,
         produtos, categorias, fornecedores RESTART IDENTITY CASCADE;
CALL popular_dados(20000);
"
```

Depois repita os Passos 3 e 5, salvando outputs com sufixo `_20k`.

### Passo 7 — Repetir para 30.000 Pedidos

```bash
psql -U postgres -d ecommerce_tuning -c "
TRUNCATE movimentacoes_estoque, itens_pedido, pedidos, clientes,
         produtos, categorias, fornecedores RESTART IDENTITY CASCADE;
CALL popular_dados(30000);
"
```

### Passo 8 — Carregar 1.000.000 de Pedidos

```bash
psql -U postgres -d ecommerce_tuning -f sql/03_popular_dados_1M.sql
```

**Atenção:** Este processo pode levar de 15 a 90 minutos dependendo do hardware.

Após a carga, repita os Passos 3 e 5 com sufixo `_1M`.

### Passo 9 — Simular Ausência de Índices (opcional)

Para simular ausência de índices com os índices ainda existindo fisicamente:

```bash
psql -U postgres -d ecommerce_tuning -f sql/07_desabilitar_indices.sql
```

Execute as consultas do script 04. Depois restaure:

```bash
psql -U postgres -d ecommerce_tuning -f sql/08_habilitar_indices.sql
```

### Passo 10 — Explorar Outros Métodos

```bash
psql -U postgres -d ecommerce_tuning -f sql/09_outros_metodos_otimizacao.sql
```

---

## 4. Como Medir os Tempos

### Método 1 — \timing no psql

```sql
\timing on

-- Execute a consulta normalmente
SELECT p.nome, p.estoque_atual
FROM produtos p
JOIN categorias c ON c.id = p.categoria_id
WHERE c.nome = 'Eletrônicos' AND p.estoque_atual > 0;

-- Saída: Time: 8.234 ms
```

### Método 2 — EXPLAIN ANALYZE (recomendado para comparações)

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.nome, p.estoque_atual
FROM produtos p
JOIN categorias c ON c.id = p.categoria_id
WHERE c.nome = 'Eletrônicos' AND p.estoque_atual > 0;

-- Registrar: "Execution Time: X.XXX ms" ao final do output
```

### Método 3 — pg_stat_statements (ambiente de produção)

```sql
-- Resetar estatísticas antes dos testes
SELECT pg_stat_statements_reset();

-- Executar as consultas...

-- Consultar resultados
SELECT
    LEFT(query, 60)                         AS query_resumida,
    calls,
    ROUND(mean_exec_time::numeric, 2)       AS media_ms,
    ROUND(total_exec_time::numeric, 2)      AS total_ms
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

---

## 5. Protocolo de Coleta de Dados

Para garantir resultados consistentes e comparáveis:

1. **Execute cada consulta 3 vezes** por cenário
2. **Descarte a primeira execução** (pode ter cache frio)
3. **Registre a média das execuções 2 e 3**
4. **Aguarde pelo menos 5 segundos** entre execuções consecutivas da mesma consulta
5. **Feche outros aplicativos** durante os testes para minimizar interferência
6. Execute `ANALYZE <tabela>;` após cada carga de dados para garantir estatísticas atualizadas

**Usando pg_prewarm para controle de cache (opcional):**
```sql
-- Habilitar extensão
CREATE EXTENSION IF NOT EXISTS pg_prewarm;

-- Carregar tabela no cache antes do teste (simula cache quente)
SELECT pg_prewarm('pedidos');
SELECT pg_prewarm('itens_pedido');

-- Limpar cache do SO (requer superuser + reinicialização — apenas em ambiente de teste)
-- Linux: echo 3 > /proc/sys/vm/drop_caches
```

---

## 6. Como Registrar os Resultados na Planilha

1. Abra `resultados/tempos_execucao.xlsx`
2. Para cada consulta, preencha:
   - Coluna **"Tempo Sem Índice (ms)"**: valor de "Execution Time" do EXPLAIN ANALYZE executado ANTES do script 05
   - Coluna **"Tempo Com Índice (ms)"**: valor de "Execution Time" executado APÓS o script 05
   - Coluna **"Tipo de Scan"**: anote o tipo observado no plano (Seq Scan, Index Scan, Bitmap Index Scan)
3. A fórmula de redução `=(SemIndice-ComIndice)/SemIndice*100` já está inserida
4. Adicione observações sobre diferenças nos planos de execução

---

## 7. Comandos para Limpar e Reiniciar os Testes

### Limpar apenas dados (mantendo estrutura e índices)

```sql
TRUNCATE movimentacoes_estoque, itens_pedido, pedidos, clientes,
         produtos, categorias, fornecedores RESTART IDENTITY CASCADE;
```

### Remover todos os índices customizados

```sql
DROP INDEX IF EXISTS idx_fornecedores_ativo;
DROP INDEX IF EXISTS idx_fornecedores_estado;
DROP INDEX IF EXISTS idx_produtos_categoria_id;
DROP INDEX IF EXISTS idx_produtos_fornecedor_id;
DROP INDEX IF EXISTS idx_produtos_ativo;
DROP INDEX IF EXISTS idx_produtos_estoque_atual;
DROP INDEX IF EXISTS idx_produtos_sku;
DROP INDEX IF EXISTS idx_produtos_categoria_ativo_estoque;
DROP INDEX IF EXISTS idx_clientes_estado;
DROP INDEX IF EXISTS idx_clientes_ativo;
DROP INDEX IF EXISTS idx_pedidos_cliente_id;
DROP INDEX IF EXISTS idx_pedidos_data_pedido;
DROP INDEX IF EXISTS idx_pedidos_status;
DROP INDEX IF EXISTS idx_pedidos_status_data;
DROP INDEX IF EXISTS idx_itens_pedido_pedido_id;
DROP INDEX IF EXISTS idx_itens_pedido_produto_id;
DROP INDEX IF EXISTS idx_movimentacoes_produto_id;
DROP INDEX IF EXISTS idx_movimentacoes_data;
DROP INDEX IF EXISTS idx_movimentacoes_tipo;
DROP INDEX IF EXISTS idx_movimentacoes_pedido_id;
DROP INDEX IF EXISTS idx_movimentacoes_produto_data;
```

### Reiniciar completamente (dropar e recriar banco)

```bash
psql -U postgres -c "DROP DATABASE IF EXISTS ecommerce_tuning;"
psql -U postgres -c "CREATE DATABASE ecommerce_tuning;"
psql -U postgres -d ecommerce_tuning -c "CREATE EXTENSION pg_stat_statements;"
psql -U postgres -d ecommerce_tuning -f sql/01_criar_tabelas.sql
psql -U postgres -d ecommerce_tuning -f sql/02_popular_dados.sql
```

---

## 8. Variações Esperadas nos Resultados

| Fator | Impacto | Mitigação |
|---|---|---|
| SSD vs HDD | Muito alto — Index Scans são muito mais rápidos em SSD | Documentar o tipo de disco |
| RAM disponível | Alto — shared_buffers maior mantém mais dados em cache | Documentar e comparar configurações |
| Cache do SO | Médio — primeira execução sempre mais lenta | Descartar primeira execução |
| Versão do PostgreSQL | Baixo a médio — otimizador melhora a cada versão | Usar PostgreSQL 14+ |
| Dados sintéticos | Baixo — random() gera distribuição uniforme, pode diferir de produção | Usar TABLESAMPLE em dados reais |
| Carga paralela | Médio — outros processos usando CPU/disco | Fechar aplicativos durante testes |

---

## 9. Troubleshooting

### Erro: "FK violation" durante popular_dados()

**Causa:** A procedure tentou referenciar um produto, pedido ou cliente que não existe (offset incorreto).
**Solução:** Este erro indica que a tabela referenciada pode estar vazia. Verifique a ordem de inserção e se `v_total_produtos` > 0 antes dos pedidos.

### Timeout em volumes grandes (1M pedidos)

**Causa:** `statement_timeout` configurado muito baixo.
**Solução:**
```sql
SET statement_timeout = 0;  -- Sem limite para esta sessão
CALL popular_dados(1000000);
```

### Erro: "out of memory" durante 1M pedidos

**Causa:** `work_mem` ou RAM insuficiente para as operações internas da procedure.
**Solução:**
```sql
SET work_mem = '256MB';
CALL popular_dados(1000000);
```
Ou aumentar a RAM disponível / dividir a carga em batches menores.

### EXPLAIN ANALYZE ainda mostra Seq Scan após criar índices

**Possíveis causas:**
1. Estatísticas desatualizadas → Execute `ANALYZE nome_da_tabela;`
2. Tabela pequena → O otimizador prefere Seq Scan para tabelas com < ~1000 páginas
3. Parâmetros de sessão desabilitados → Execute o script `08_habilitar_indices.sql`
4. Consulta retorna muitas linhas → Índice não é eficiente para alta seletividade negativa

### Erro de encoding em Windows

```bash
psql -U postgres -d ecommerce_tuning --set=client_encoding=UTF8 -f sql/01_criar_tabelas.sql
```

### pg_stat_statements não encontrado

Verifique se `shared_preload_libraries = 'pg_stat_statements'` está no `postgresql.conf` e se o PostgreSQL foi reiniciado após a alteração.

---

## Ordem Correta de Execução (Resumo)

```
SETUP:
  01_criar_tabelas.sql          → Cria as 7 tabelas

CICLO PARA CADA VOLUME (10k, 20k, 30k, 1M):
  02_popular_dados.sql          → Define procedure + carga 10k
  OU: CALL popular_dados(N)     → Para demais volumes após TRUNCATE
  04_consultas_sem_indice.sql   → Registrar tempos SEM índice
  05_criar_indices.sql          → Criar todos os índices (uma única vez)
  06_consultas_com_indice.sql   → Registrar tempos COM índice

OPCIONAL:
  07_desabilitar_indices.sql    → Simular ausência de índices
  08_habilitar_indices.sql      → Restaurar uso de índices
  09_outros_metodos_otimizacao.sql → Explorar técnicas avançadas
```
