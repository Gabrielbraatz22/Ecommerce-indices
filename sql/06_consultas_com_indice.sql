-- =============================================================================
-- SCRIPT 06: CONSULTAS COM ÍNDICE
-- Projeto: Tuning de Consultas em PostgreSQL
-- Estudo de Caso: E-commerce com Controle de Estoque
-- Descrição: Replicas das mesmas 6 consultas do script 04, após a criação
--            dos índices. Compare os planos e tempos para quantificar o ganho.
-- Compatibilidade: PostgreSQL 14+
-- =============================================================================

\timing on

-- Garantir uso de índices habilitado
SET enable_indexscan     = ON;
SET enable_bitmapscan    = ON;
SET enable_indexonlyscan = ON;

\echo '============================================================'
\echo 'CONSULTAS COM ÍNDICE — Compare com os tempos do script 04'
\echo '============================================================'
\echo ''

-- =============================================================================
-- CONSULTA 1 COM ÍNDICE — Produtos por categoria e disponibilidade
-- ÍNDICE UTILIZADO: idx_produtos_categoria_ativo_estoque (composto)
-- MUDANÇA NO PLANO:
--   ANTES: Hash Join (Seq Scan produtos × Seq Scan categorias)
--   DEPOIS: Index Scan using idx_produtos_categoria_ativo_estoque
--           → O índice composto resolve os três filtros em um único acesso
--           → Nested Loop com acesso direto à categoria pelo PK
-- GANHO ESPERADO: 90-97% de redução no tempo de execução
-- =============================================================================
\echo '--- CONSULTA 1 COM ÍNDICE: Produtos por categoria ---'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT p.id, p.nome, p.sku, p.preco_venda, p.estoque_atual,
       c.nome AS categoria
FROM produtos p
JOIN categorias c ON c.id = p.categoria_id
WHERE c.nome = 'Eletrônicos'
  AND p.estoque_atual > 0
  AND p.ativo = TRUE
ORDER BY p.preco_venda;

SELECT p.id, p.nome, p.sku, p.preco_venda, p.estoque_atual,
       c.nome AS categoria
FROM produtos p
JOIN categorias c ON c.id = p.categoria_id
WHERE c.nome = 'Eletrônicos'
  AND p.estoque_atual > 0
  AND p.ativo = TRUE
ORDER BY p.preco_venda;

\echo ''

-- =============================================================================
-- CONSULTA 2 COM ÍNDICE — Relatório de vendas por período
-- ÍNDICE UTILIZADO: idx_pedidos_status_data (composto) ou idx_pedidos_data_pedido
-- MUDANÇA NO PLANO:
--   ANTES: Seq Scan on pedidos (filtra 100% das linhas, descarta a maioria)
--   DEPOIS: Bitmap Index Scan on idx_pedidos_status_data
--           → Lê apenas as páginas com pedidos entregues no período
--           → O GroupAggregate opera sobre muito menos linhas
-- GANHO ESPERADO: 88-95% de redução
-- =============================================================================
\echo '--- CONSULTA 2 COM ÍNDICE: Relatório de vendas por período ---'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    DATE(p.data_pedido)    AS data,
    COUNT(*)               AS total_pedidos,
    SUM(p.valor_total)     AS receita_total,
    AVG(p.valor_total)     AS ticket_medio
FROM pedidos p
WHERE p.data_pedido BETWEEN '2024-01-01' AND '2024-06-30'
  AND p.status = 'entregue'
GROUP BY DATE(p.data_pedido)
ORDER BY data;

SELECT
    DATE(p.data_pedido)    AS data,
    COUNT(*)               AS total_pedidos,
    SUM(p.valor_total)     AS receita_total,
    AVG(p.valor_total)     AS ticket_medio
FROM pedidos p
WHERE p.data_pedido BETWEEN '2024-01-01' AND '2024-06-30'
  AND p.status = 'entregue'
GROUP BY DATE(p.data_pedido)
ORDER BY data;

\echo ''

-- =============================================================================
-- CONSULTA 3 COM ÍNDICE — Produtos com estoque abaixo do mínimo
-- ÍNDICE UTILIZADO: idx_produtos_estoque_atual + idx_produtos_fornecedor_id
-- MUDANÇA NO PLANO:
--   ANTES: Seq Scan em produtos + Seq Scan em fornecedores com Hash Join
--   DEPOIS: Bitmap Index Scan on idx_produtos_estoque_atual
--           → Pré-filtra produtos com estoque baixo antes do JOIN
--           → Nested Loop com Index Scan on idx_produtos_fornecedor_id
-- NOTA: O filtro estoque_atual <= estoque_minimo compara duas colunas da
--       mesma linha, limitando o uso do índice; o otimizador pode combinar
--       com idx_produtos_ativo via Bitmap AND.
-- GANHO ESPERADO: 85-93% de redução
-- =============================================================================
\echo '--- CONSULTA 3 COM ÍNDICE: Estoque abaixo do mínimo ---'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    p.id, p.nome, p.sku, p.estoque_atual, p.estoque_minimo,
    (p.estoque_minimo - p.estoque_atual) AS deficit,
    f.razao_social                        AS fornecedor,
    f.email                               AS contato_fornecedor,
    f.telefone
FROM produtos p
JOIN fornecedores f ON f.id = p.fornecedor_id
WHERE p.estoque_atual <= p.estoque_minimo
  AND p.ativo = TRUE
ORDER BY deficit DESC;

SELECT
    p.id, p.nome, p.sku, p.estoque_atual, p.estoque_minimo,
    (p.estoque_minimo - p.estoque_atual) AS deficit,
    f.razao_social                        AS fornecedor,
    f.email                               AS contato_fornecedor,
    f.telefone
FROM produtos p
JOIN fornecedores f ON f.id = p.fornecedor_id
WHERE p.estoque_atual <= p.estoque_minimo
  AND p.ativo = TRUE
ORDER BY deficit DESC;

\echo ''

-- =============================================================================
-- CONSULTA 4 COM ÍNDICE — Histórico de movimentações de um produto
-- ÍNDICE UTILIZADO: idx_movimentacoes_produto_data (composto) — O MAIS IMPACTANTE
-- MUDANÇA NO PLANO:
--   ANTES: Seq Scan on movimentacoes_estoque (varre TODOS os milhões de registros)
--   DEPOIS: Index Scan using idx_movimentacoes_produto_data on movimentacoes_estoque
--           → O índice composto (produto_id, data DESC) elimina o Seq Scan E o Sort
--           → O LIMIT 100 interrompe o scan após as 100 primeiras linhas
-- GANHO ESPERADO: 97-99% de redução — O MAIOR GANHO DE TODOS os testes
-- Esta é a consulta que mais beneficia de índice composto em e-commerce
-- =============================================================================
\echo '--- CONSULTA 4 COM ÍNDICE: Histórico de movimentações ---'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    m.id,
    m.data_movimentacao,
    m.tipo,
    m.quantidade,
    m.observacao,
    p.status AS status_pedido
FROM movimentacoes_estoque m
JOIN produtos pr ON pr.id = m.produto_id
LEFT JOIN pedidos p ON p.id = m.pedido_id
WHERE m.produto_id = 500
ORDER BY m.data_movimentacao DESC
LIMIT 100;

SELECT
    m.id,
    m.data_movimentacao,
    m.tipo,
    m.quantidade,
    m.observacao,
    p.status AS status_pedido
FROM movimentacoes_estoque m
JOIN produtos pr ON pr.id = m.produto_id
LEFT JOIN pedidos p ON p.id = m.pedido_id
WHERE m.produto_id = 500
ORDER BY m.data_movimentacao DESC
LIMIT 100;

\echo ''

-- =============================================================================
-- CONSULTA 5 COM ÍNDICE — Ranking de produtos mais vendidos
-- ÍNDICES UTILIZADOS: idx_pedidos_status + idx_itens_pedido_pedido_id
--                     + idx_itens_pedido_produto_id
-- MUDANÇA NO PLANO:
--   ANTES: múltiplos Hash Joins com Seq Scans em todas as tabelas
--   DEPOIS: Bitmap Index Scan on idx_pedidos_status para pré-filtrar pedidos entregues
--           → Nested Loop com Index Scans nas FKs de itens_pedido
--           → O HashAggregate opera sobre conjunto menor de linhas
-- GANHO ESPERADO: 70-80% de redução (JOINs de agregação têm menos ganho que filtros simples)
-- =============================================================================
\echo '--- CONSULTA 5 COM ÍNDICE: Ranking de produtos ---'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT
    pr.nome,
    pr.sku,
    c.nome                                 AS categoria,
    SUM(i.quantidade)                      AS total_vendido,
    SUM(i.quantidade * i.preco_unitario
        * (1 - i.desconto / 100))          AS receita_gerada,
    COUNT(DISTINCT i.pedido_id)            AS num_pedidos
FROM itens_pedido i
JOIN produtos   pr ON pr.id = i.produto_id
JOIN categorias c  ON c.id  = pr.categoria_id
JOIN pedidos    p  ON p.id  = i.pedido_id
WHERE p.status = 'entregue'
GROUP BY pr.id, pr.nome, pr.sku, c.nome
ORDER BY total_vendido DESC
LIMIT 20;

SELECT
    pr.nome,
    pr.sku,
    c.nome                                 AS categoria,
    SUM(i.quantidade)                      AS total_vendido,
    SUM(i.quantidade * i.preco_unitario
        * (1 - i.desconto / 100))          AS receita_gerada,
    COUNT(DISTINCT i.pedido_id)            AS num_pedidos
FROM itens_pedido i
JOIN produtos   pr ON pr.id = i.produto_id
JOIN categorias c  ON c.id  = pr.categoria_id
JOIN pedidos    p  ON p.id  = i.pedido_id
WHERE p.status = 'entregue'
GROUP BY pr.id, pr.nome, pr.sku, c.nome
ORDER BY total_vendido DESC
LIMIT 20;

\echo ''

-- =============================================================================
-- CONSULTA 6 COM ÍNDICE — Clientes VIP (CTE)
-- ÍNDICES UTILIZADOS: idx_pedidos_cliente_id + idx_pedidos_status
-- MUDANÇA NO PLANO:
--   ANTES: CTE materializada com Seq Scan em pedidos + Hash Join com clientes
--   DEPOIS: No PostgreSQL 12+, a CTE pode ser inlineada (sem materialização forçada)
--           O HashAggregate em pedidos é mais eficiente com idx_pedidos_status
--           para pré-filtrar não-cancelados antes da agregação.
-- GANHO ESPERADO: 60-70% de redução (CTEs com agregação total têm limitações)
-- =============================================================================
\echo '--- CONSULTA 6 COM ÍNDICE: Clientes VIP (CTE) ---'

EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH totais AS (
    SELECT
        p.cliente_id,
        COUNT(*)               AS total_pedidos,
        SUM(p.valor_total)     AS total_gasto,
        MAX(p.data_pedido)     AS ultima_compra,
        MIN(p.data_pedido)     AS primeira_compra
    FROM pedidos p
    WHERE p.status != 'cancelado'
    GROUP BY p.cliente_id
)
SELECT
    cl.nome,
    cl.email,
    cl.cidade,
    cl.estado,
    t.total_pedidos,
    ROUND(t.total_gasto, 2)    AS total_gasto,
    t.ultima_compra,
    RANK() OVER (ORDER BY t.total_gasto DESC) AS ranking_vip
FROM totais t
JOIN clientes cl ON cl.id = t.cliente_id
WHERE t.total_gasto > 1000
ORDER BY t.total_gasto DESC
LIMIT 50;

WITH totais AS (
    SELECT
        p.cliente_id,
        COUNT(*)               AS total_pedidos,
        SUM(p.valor_total)     AS total_gasto,
        MAX(p.data_pedido)     AS ultima_compra,
        MIN(p.data_pedido)     AS primeira_compra
    FROM pedidos p
    WHERE p.status != 'cancelado'
    GROUP BY p.cliente_id
)
SELECT
    cl.nome,
    cl.email,
    cl.cidade,
    cl.estado,
    t.total_pedidos,
    ROUND(t.total_gasto, 2)    AS total_gasto,
    t.ultima_compra,
    RANK() OVER (ORDER BY t.total_gasto DESC) AS ranking_vip
FROM totais t
JOIN clientes cl ON cl.id = t.cliente_id
WHERE t.total_gasto > 1000
ORDER BY t.total_gasto DESC
LIMIT 50;

\echo ''
\echo '============================================================'
\echo 'FIM DAS CONSULTAS COM ÍNDICE'
\echo 'Compare os tempos com os resultados do script 04!'
\echo '============================================================'

-- Estatísticas de uso dos índices nesta sessão
SELECT
    relname      AS tabela,
    indexrelname AS indice,
    idx_scan     AS vezes_usado,
    idx_tup_read AS tuplas_lidas_via_indice
FROM pg_stat_user_indexes
WHERE schemaname = 'public' AND indexrelname LIKE 'idx_%'
ORDER BY idx_scan DESC;
