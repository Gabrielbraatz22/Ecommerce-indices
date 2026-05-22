-- =============================================================================
-- SCRIPT 09: OUTROS MÉTODOS DE OTIMIZAÇÃO
-- Projeto: Tuning de Consultas em PostgreSQL
-- Estudo de Caso: E-commerce com Controle de Estoque
-- Descrição: Demonstra 10 técnicas de otimização avançadas aplicadas
--            ao contexto de e-commerce com controle de estoque.
-- Compatibilidade: PostgreSQL 14+
-- =============================================================================

\timing on

\echo '============================================================'
\echo 'OUTROS MÉTODOS DE OTIMIZAÇÃO — E-commerce PostgreSQL'
\echo '============================================================'

-- =============================================================================
-- MÉTODO 1: VACUUM e ANALYZE
-- Em e-commerce, pedidos são inseridos, itens adicionados, status atualizado
-- e estoque_atual modificado constantemente. Cada UPDATE cria dead tuples
-- via MVCC. Sem VACUUM, as tabelas crescem desnecessariamente e as queries
-- ficam mais lentas por precisar ler mais páginas.
-- =============================================================================
\echo ''
\echo '=== MÉTODO 1: VACUUM e ANALYZE ==='

-- Ver saúde atual das tabelas (dead tuples acumuladas)
SELECT
    relname                  AS tabela,
    n_live_tup               AS linhas_vivas,
    n_dead_tup               AS dead_tuples,
    CASE WHEN (n_live_tup + n_dead_tup) = 0 THEN 0
         ELSE ROUND(n_dead_tup::numeric/(n_live_tup+n_dead_tup)*100, 2)
    END                      AS pct_dead,
    last_autovacuum          AS ultimo_autovacuum,
    last_autoanalyze         AS ultimo_autoanalyze
FROM pg_stat_user_tables
WHERE schemaname = 'public'
ORDER BY n_dead_tup DESC;

-- VACUUM ANALYZE em todas as tabelas do projeto
VACUUM ANALYZE fornecedores;
VACUUM ANALYZE categorias;
VACUUM ANALYZE produtos;
VACUUM ANALYZE clientes;
VACUUM ANALYZE pedidos;
VACUUM ANALYZE itens_pedido;
VACUUM ANALYZE movimentacoes_estoque;

\echo 'VACUUM ANALYZE concluído em todas as tabelas.'

-- =============================================================================
-- MÉTODO 2: PARTICIONAMENTO POR RANGE
-- movimentacoes_estoque é a tabela de maior crescimento no sistema.
-- Com particionamento por ano/mês, consultas de período específico usam
-- Partition Pruning e leem apenas as partições relevantes.
-- =============================================================================
\echo ''
\echo '=== MÉTODO 2: PARTICIONAMENTO DE movimentacoes_estoque ==='

DROP TABLE IF EXISTS movimentacoes_particionada CASCADE;

CREATE TABLE movimentacoes_particionada (
    id                 SERIAL,
    produto_id         INTEGER       NOT NULL,
    tipo               VARCHAR(20)   NOT NULL,
    quantidade         INTEGER       NOT NULL,
    data_movimentacao  TIMESTAMP     NOT NULL DEFAULT NOW(),
    pedido_id          INTEGER,
    observacao         TEXT
) PARTITION BY RANGE (data_movimentacao);

-- Partições por ano
CREATE TABLE mov_2022 PARTITION OF movimentacoes_particionada
    FOR VALUES FROM ('2022-01-01') TO ('2023-01-01');
CREATE TABLE mov_2023 PARTITION OF movimentacoes_particionada
    FOR VALUES FROM ('2023-01-01') TO ('2024-01-01');
CREATE TABLE mov_2024 PARTITION OF movimentacoes_particionada
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE mov_2025 PARTITION OF movimentacoes_particionada
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');

-- Criar índice em todas as partições automaticamente
CREATE INDEX ON movimentacoes_particionada (produto_id, data_movimentacao DESC);
CREATE INDEX ON movimentacoes_particionada (tipo);

-- Copiar dados existentes
INSERT INTO movimentacoes_particionada
    (produto_id, tipo, quantidade, data_movimentacao, pedido_id, observacao)
SELECT produto_id, tipo, quantidade, data_movimentacao, pedido_id, observacao
FROM movimentacoes_estoque
WHERE data_movimentacao >= '2022-01-01';

\echo 'Tabela particionada criada. Demonstrando Partition Pruning:'

-- Consulta de 2024 — lê APENAS a partição mov_2024
EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT COUNT(*), SUM(quantidade)
FROM movimentacoes_particionada
WHERE data_movimentacao BETWEEN '2024-01-01' AND '2024-12-31'
  AND tipo = 'saida';

-- Tamanho por partição
SELECT
    c.relname    AS particao,
    pg_size_pretty(pg_relation_size(c.oid)) AS tamanho
FROM pg_inherits
JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
JOIN pg_class c      ON pg_inherits.inhrelid  = c.oid
WHERE parent.relname = 'movimentacoes_particionada'
ORDER BY c.relname;

-- =============================================================================
-- MÉTODO 3: MATERIALIZED VIEW — Ranking de produtos (Consulta 5)
-- O ranking de produtos mais vendidos é consultado múltiplas vezes ao dia,
-- mas não precisa refletir dados de milissegundos atrás.
-- Pré-computar com Materialized View torna a resposta instantânea.
-- =============================================================================
\echo ''
\echo '=== MÉTODO 3: MATERIALIZED VIEW — mv_ranking_produtos ==='

DROP MATERIALIZED VIEW IF EXISTS mv_ranking_produtos;

CREATE MATERIALIZED VIEW mv_ranking_produtos AS
SELECT
    pr.id,
    pr.nome,
    pr.sku,
    c.nome                                     AS categoria,
    SUM(i.quantidade)                          AS total_vendido,
    SUM(i.quantidade * i.preco_unitario
        * (1 - i.desconto / 100))              AS receita_gerada,
    COUNT(DISTINCT i.pedido_id)                AS num_pedidos,
    NOW()                                      AS calculado_em
FROM itens_pedido i
JOIN produtos   pr ON pr.id = i.produto_id
JOIN categorias c  ON c.id  = pr.categoria_id
JOIN pedidos    p  ON p.id  = i.pedido_id
WHERE p.status = 'entregue'
GROUP BY pr.id, pr.nome, pr.sku, c.nome
ORDER BY total_vendido DESC
WITH DATA;

-- Criar índice único na Materialized View para REFRESH CONCURRENTLY
CREATE UNIQUE INDEX ON mv_ranking_produtos(id);
CREATE INDEX ON mv_ranking_produtos(categoria);

\echo 'Materialized View criada. Consultando ranking pré-computado:'

-- Esta consulta é instantânea — lê dados já aggregados em disco
SELECT * FROM mv_ranking_produtos LIMIT 10;

\echo ''
\echo 'Para atualizar: REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ranking_produtos;'
\echo 'Pode ser agendado via pg_cron: SELECT cron.schedule(''*/30 * * * *'', ...'');'

-- =============================================================================
-- MÉTODO 4: ÍNDICES PARCIAIS
-- Pedidos com status 'pendente' e 'confirmado' são os mais consultados
-- operacionalmente (precisam de ação imediata). Um índice parcial sobre
-- apenas esses status é menor, mais rápido para manter e igualmente eficaz.
-- =============================================================================
\echo ''
\echo '=== MÉTODO 4: ÍNDICES PARCIAIS ==='

-- Índice parcial: apenas pedidos ativos (pendente, confirmado, separando)
DROP INDEX IF EXISTS idx_pedidos_ativos_parcial;
CREATE INDEX idx_pedidos_ativos_parcial ON pedidos(data_pedido, cliente_id)
    WHERE status IN ('pendente','confirmado','separando');

COMMENT ON INDEX idx_pedidos_ativos_parcial IS
    'Índice parcial — cobre apenas pedidos em processamento ativo (~30% das linhas)';

\echo 'Índice parcial criado. Comparando tamanho com índice completo:'

SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexname::TEXT::REGCLASS)) AS tamanho
FROM pg_indexes
WHERE indexname IN ('idx_pedidos_data_pedido','idx_pedidos_ativos_parcial')
ORDER BY pg_relation_size(indexname::TEXT::REGCLASS) DESC;

-- Demonstrar que o otimizador usa o índice parcial
EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT id, cliente_id, data_pedido, valor_total
FROM pedidos
WHERE status = 'pendente'
  AND data_pedido > NOW() - INTERVAL '7 days';

-- =============================================================================
-- MÉTODO 5: ÍNDICES DE COBERTURA (INCLUDE)
-- A cláusula INCLUDE adiciona colunas ao índice sem indexá-las (não afetam
-- a ordem do índice). O otimizador pode usar Index-Only Scan para consultas
-- que precisam dessas colunas, evitando acesso às heap pages.
-- =============================================================================
\echo ''
\echo '=== MÉTODO 5: ÍNDICES DE COBERTURA (INCLUDE) ==='

-- Índice de cobertura para relatório de vendas: inclui valor_total e cliente_id
-- O otimizador pode usar Index-Only Scan sem acessar as heap pages de pedidos
DROP INDEX IF EXISTS idx_pedidos_status_data_cover;
CREATE INDEX idx_pedidos_status_data_cover
    ON pedidos(status, data_pedido)
    INCLUDE (valor_total, cliente_id);

COMMENT ON INDEX idx_pedidos_status_data_cover IS
    'Índice de cobertura — resolve Consulta 2 e 6 sem acessar heap pages de pedidos';

\echo 'Índice de cobertura criado. Verificando Index-Only Scan:'

EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT DATE(data_pedido), COUNT(*), SUM(valor_total)
FROM pedidos
WHERE status = 'entregue'
  AND data_pedido BETWEEN '2024-01-01' AND '2024-06-30'
GROUP BY DATE(data_pedido);

-- =============================================================================
-- MÉTODO 6: pg_stat_statements — Identificar queries lentas
-- Em produção, pg_stat_statements é a primeira ferramenta a verificar
-- ao investigar problemas de performance em e-commerce.
-- =============================================================================
\echo ''
\echo '=== MÉTODO 6: pg_stat_statements — Queries mais lentas ==='

-- Tentar criar a extensão
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Queries com maior tempo médio de execução
SELECT
    LEFT(query, 80)                             AS query_resumida,
    calls                                       AS execucoes,
    ROUND(mean_exec_time::numeric, 2)           AS media_ms,
    ROUND(total_exec_time::numeric, 2)          AS total_ms,
    ROUND(stddev_exec_time::numeric, 2)         AS desvio_ms,
    rows                                        AS linhas_retornadas
FROM pg_stat_statements
WHERE query NOT ILIKE '%pg_stat_statements%'
ORDER BY mean_exec_time DESC
LIMIT 10;

-- =============================================================================
-- MÉTODO 7: CLUSTER — Reorganização física de movimentacoes_estoque
-- Após anos de inserções, os dados físicos da tabela ficam desordenados.
-- CLUSTER reorganiza conforme o índice mais usado nas consultas de rastreamento.
-- =============================================================================
\echo ''
\echo '=== MÉTODO 7: CLUSTER em movimentacoes_estoque ==='

-- Reorganizar pela ordem de produto_id e data (alinha com Consulta 4)
CLUSTER movimentacoes_estoque USING idx_movimentacoes_produto_data;

\echo 'CLUSTER concluído. Consultas por produto e data terão I/O sequencial.'

EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT tipo, COUNT(*), SUM(quantidade)
FROM movimentacoes_estoque
WHERE produto_id BETWEEN 1 AND 50
  AND data_movimentacao >= NOW() - INTERVAL '1 year'
GROUP BY tipo;

-- =============================================================================
-- MÉTODO 8: CTEs vs SUBQUERIES na Consulta 6 (Clientes VIP)
-- No PostgreSQL 12+, CTEs não recursivas são inlineadas pelo otimizador.
-- Demonstrar a diferença e quando forçar materialização é vantajoso.
-- =============================================================================
\echo ''
\echo '=== MÉTODO 8: CTEs vs SUBQUERIES — Clientes VIP ==='

\echo 'Versão CTE (pode ser inlineada no PostgreSQL 12+):'
EXPLAIN (ANALYZE, FORMAT TEXT)
WITH totais AS (
    SELECT cliente_id, SUM(valor_total) AS total
    FROM pedidos WHERE status != 'cancelado'
    GROUP BY cliente_id
)
SELECT cl.nome, t.total
FROM totais t JOIN clientes cl ON cl.id = t.cliente_id
WHERE t.total > 1000 ORDER BY t.total DESC LIMIT 20;

\echo 'Versão CTE MATERIALIZADA (forçar pré-computação):'
EXPLAIN (ANALYZE, FORMAT TEXT)
WITH totais AS MATERIALIZED (
    SELECT cliente_id, SUM(valor_total) AS total
    FROM pedidos WHERE status != 'cancelado'
    GROUP BY cliente_id
)
SELECT cl.nome, t.total
FROM totais t JOIN clientes cl ON cl.id = t.cliente_id
WHERE t.total > 1000 ORDER BY t.total DESC LIMIT 20;

\echo 'Versão Subquery equivalente:'
EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT cl.nome, sub.total
FROM (
    SELECT cliente_id, SUM(valor_total) AS total
    FROM pedidos WHERE status != 'cancelado'
    GROUP BY cliente_id
) sub
JOIN clientes cl ON cl.id = sub.cliente_id
WHERE sub.total > 1000 ORDER BY sub.total DESC LIMIT 20;

-- =============================================================================
-- MÉTODO 9: CONFIGURAÇÕES DE MEMÓRIA — recomendações para e-commerce
-- =============================================================================
\echo ''
\echo '=== MÉTODO 9: CONFIGURAÇÕES DE MEMÓRIA ==='

SELECT name, setting, unit, short_desc
FROM pg_settings
WHERE name IN (
    'shared_buffers','work_mem','effective_cache_size',
    'maintenance_work_mem','max_connections',
    'random_page_cost','seq_page_cost','default_statistics_target',
    'max_parallel_workers_per_gather'
)
ORDER BY name;

\echo ''
\echo 'RECOMENDAÇÕES PARA E-COMMERCE (servidor 8GB RAM, SSD):'
\echo '  shared_buffers        = 2GB     (25% da RAM — cache de páginas)'
\echo '  work_mem              = 64MB    (por operação sort/hash)'
\echo '  effective_cache_size  = 6GB     (75% da RAM — informa o otimizador)'
\echo '  maintenance_work_mem  = 512MB   (para VACUUM e CREATE INDEX)'
\echo '  random_page_cost      = 1.1     (reduzir para SSD NVMe)'
\echo '  default_statistics_target = 200  (mais estatísticas = planos melhores)'
\echo '  max_parallel_workers_per_gather = 4  (paralelismo em queries analíticas)'

-- Demonstrar impacto do work_mem na Consulta 6 (evitar temp files)
SET work_mem = '128MB';
EXPLAIN (ANALYZE, FORMAT TEXT)
WITH totais AS (
    SELECT cliente_id, SUM(valor_total) AS total
    FROM pedidos WHERE status != 'cancelado'
    GROUP BY cliente_id
)
SELECT cl.nome, t.total
FROM totais t JOIN clientes cl ON cl.id = t.cliente_id
WHERE t.total > 1000 ORDER BY t.total DESC LIMIT 50;

-- =============================================================================
-- MÉTODO 10: EXPLAIN ANALYZE DETALHADO — interpretação para e-commerce
-- =============================================================================
\echo ''
\echo '=== MÉTODO 10: EXPLAIN ANALYZE DETALHADO ==='

\echo 'Analisando Consulta 4 com parâmetros avançados:'

-- BUFFERS mostra leituras de cache vs disco
-- FORMAT JSON permite uso em ferramentas como pgMustard e explain.depesz.com
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, FORMAT TEXT)
SELECT m.data_movimentacao, m.tipo, m.quantidade
FROM movimentacoes_estoque m
WHERE m.produto_id = 100
ORDER BY m.data_movimentacao DESC
LIMIT 50;

\echo ''
\echo 'GLOSSÁRIO DO EXPLAIN ANALYZE para e-commerce:'
\echo '  shared hit     = lido do cache (PostgreSQL shared_buffers) — rápido'
\echo '  shared read    = lido do disco — lento, considera aumentar shared_buffers'
\echo '  Rows Removed   = linhas descartadas pelo filtro — alto valor = índice faltando'
\echo '  actual time    = tempo real em ms (start..end) — comparar com cost'
\echo '  loops          = quantas vezes o nó foi executado (Nested Loop)'
\echo '  Planning Time  = tempo para gerar o plano — alto pode indicar estatísticas ruins'
\echo '  Execution Time = tempo de execução real — o que importa para o usuário'

-- =============================================================================
-- CLEANUP: Remover objetos temporários criados neste script
-- =============================================================================
DROP TABLE               IF EXISTS movimentacoes_particionada CASCADE;
DROP MATERIALIZED VIEW   IF EXISTS mv_ranking_produtos;
DROP INDEX               IF EXISTS idx_pedidos_ativos_parcial;
DROP INDEX               IF EXISTS idx_pedidos_status_data_cover;
ALTER TABLE pedidos SET (fillfactor = 100);  -- restaurar padrão

\echo ''
\echo '============================================================'
\echo 'FIM DOS OUTROS MÉTODOS DE OTIMIZAÇÃO'
\echo 'Objetos temporários removidos. Ambiente restaurado.'
\echo '============================================================'
