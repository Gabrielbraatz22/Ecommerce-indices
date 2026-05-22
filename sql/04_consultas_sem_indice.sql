-- =============================================================================
-- SCRIPT 04: CONSULTAS SEM ÍNDICE
-- Projeto: Tuning de Consultas em PostgreSQL
-- Estudo de Caso: E-commerce com Controle de Estoque
-- Descrição: 6 consultas representativas do domínio, executadas ANTES da
--            criação de índices. Registre os tempos na planilha de resultados.
-- Compatibilidade: PostgreSQL 14+
-- =============================================================================

\timing on

\echo '============================================================'
\echo 'CONSULTAS SEM ÍNDICE — Registre os tempos abaixo'
\echo '============================================================'
\echo ''

-- =============================================================================
-- CONSULTA 1 — Busca de produtos por categoria e disponibilidade
-- Cenário de negócio: O cliente acessa o site, filtra pela categoria
--   "Eletrônicos" e quer ver apenas produtos em estoque.
--   Esta é a consulta mais frequente de qualquer e-commerce.
-- Sem índice: Sequential Scan em produtos + Sequential Scan em categorias
--   com filtro posterior (Hash Join). Para 2000 produtos, é rápido, mas
--   escala mal com crescimento do catálogo.
-- =============================================================================
\echo '--- CONSULTA 1: Produtos por categoria e disponibilidade ---'

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
-- CONSULTA 2 — Relatório de vendas por período
-- Cenário de negócio: O gestor acessa o painel de controle e quer ver
--   o faturamento diário do primeiro semestre de 2024.
--   Executada múltiplas vezes ao dia por diferentes gestores e dashboards.
-- Sem índice: Sequential Scan completo em pedidos (tabela mais crescente),
--   filtrando e agrupando. Com 1M de pedidos, o custo é catastrófico.
-- =============================================================================
\echo '--- CONSULTA 2: Relatório de vendas por período ---'

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
-- CONSULTA 3 — Produtos com estoque abaixo do mínimo
-- Cenário de negócio: O sistema de alerta do setor de compras executa
--   esta consulta periodicamente para identificar produtos que precisam
--   ser repostos. O contato do fornecedor é incluído para facilitar a
--   geração de ordem de compra.
-- Sem índice: Full Scan em produtos + Full Scan em fornecedores com JOIN.
--   O filtro estoque_atual <= estoque_minimo compara duas colunas da mesma
--   linha, impossibilitando uso de índice simples.
-- =============================================================================
\echo '--- CONSULTA 3: Produtos com estoque abaixo do mínimo ---'

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
-- CONSULTA 4 — Histórico de movimentações de um produto
-- Cenário de negócio: O operador de estoque precisa rastrear todas as
--   entradas e saídas de um produto específico para conciliar com o
--   saldo atual e investigar discrepâncias no inventário.
-- Sem índice: Sequential Scan completo em movimentacoes_estoque (tabela
--   MAIOR do sistema) para filtrar por produto_id. Com 3M+ de registros,
--   isso é extremamente lento — ilustra o caso mais crítico de tuning.
-- =============================================================================
\echo '--- CONSULTA 4: Histórico de movimentações de um produto ---'

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
-- CONSULTA 5 — Ranking de produtos mais vendidos
-- Cenário de negócio: Relatório de desempenho semanal para a equipe
--   comercial. Mostra quais produtos estão gerando mais receita e volume
--   de vendas. Envolve JOIN de 4 tabelas e agregação pesada.
-- Sem índice: Hash Join entre itens_pedido, produtos, categorias e pedidos,
--   todos com Sequential Scan. A agregação SUM/GROUP BY em milhões de
--   itens sem índice é uma das operações mais custosas do sistema.
-- =============================================================================
\echo '--- CONSULTA 5: Ranking de produtos mais vendidos ---'

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
-- CONSULTA 6 — Clientes VIP com maior volume de compras (CTE)
-- Cenário de negócio: O time de marketing precisa identificar os clientes
--   que gastaram mais de R$1.000 na plataforma para enviar cupons especiais
--   e incluir no programa de fidelidade. Esta consulta é executada
--   semanalmente para atualizar a base de clientes VIP.
-- Sem índice: CTE materializa resultado de pedidos com Sequential Scan,
--   depois faz Hash Join com clientes. Window function e filtro de VIP
--   operam sobre o conjunto completo de resultados.
-- =============================================================================
\echo '--- CONSULTA 6: Clientes VIP — maior volume de compras (CTE) ---'

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
\echo 'FIM DAS CONSULTAS SEM ÍNDICE'
\echo 'Registre os tempos na planilha resultados/tempos_execucao.xlsx'
\echo '============================================================'
